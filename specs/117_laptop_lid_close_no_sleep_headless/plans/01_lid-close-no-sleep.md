# Implementation Plan: Task #117

- **Task**: 117 - laptop_lid_close_no_sleep_headless
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/117_laptop_lid_close_no_sleep_headless/reports/01_lid-close-no-sleep.md
- **Artifacts**: plans/01_lid-close-no-sleep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Make lid-close blank the internal screen but never suspend, so headless AI agents keep running with the lid shut and no external monitors. The core fix is a single logind change in `modules/system/power.nix` (lid handling is owned by systemd-logind, whose effective `HandleLidSwitch` is the stock default `suspend`; the repo currently sets NO logind options). Screen blanking needs no change (mutter disables eDP on lid close; the 5-minute `idle-delay = 300` in `modules/home/desktop/gnome.nix:34` stays untouched), and multi-monitor window distribution is untouched (`ignore` is strictly less aggressive than today's gsd-power inhibitor + `HandleLidSwitchDocked` default path). Two secondary auto-suspend paths that could still kill headless agents are resolved as explicit decision phases, and documentation is updated proportionately — small edits to existing files, no new standalone doc, no root README changes.

### Research Integration

Key findings from `reports/01_lid-close-no-sleep.md` integrated into this plan:

- **Canonical option path verified against the pinned nixpkgs (nixos-26.05, `flake.nix:8`)**: `services.logind.settings.Login.HandleLidSwitch` / `.HandleLidSwitchExternalPower`. The legacy `services.logind.lidSwitch*` options are renamed aliases (verified by `nix eval` rename-error naming the settings path). Use the canonical form.
- **Do NOT set `HandleLidSwitchDocked`**: it already defaults to `ignore` (docked = docking station OR >1 connected display); omitting it preserves today's external-monitor semantics byte-for-byte.
- **Claude Code's own `sleep:idle` inhibitors do NOT protect against lid-close suspend**: logind's `LidSwitchIgnoreInhibited` defaults to `yes`, so today lid close with no external monitor suspends regardless of running agents — the exact bug being fixed.
- **Secondary suspend paths** (decision points, Phases 2-3): GNOME AC idle-suspend after 60 min (`sleep-inactive-ac-timeout = 3600`, live type `'suspend'`) and the niri-session swayidle 10-minute `systemctl suspend` (`config/config.kdl:270`).
- **Live host is `hamsa`** (AMD laptop); flake hosts verified at `flake.nix:126-134` (`nandi`, `hamsa`, plus garuda/iso/usb-installer). `power.nix` is imported always-on (`modules/system/default.nix`), so both laptops get the fix; the options are inert on non-laptop hosts.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (no roadmap context provided for this task).

## Goals & Non-Goals

**Goals**:
- Lid close never suspends the machine, on battery or AC, with or without external monitors (logind `ignore`).
- Internal screen still goes dark on lid close (inherent — mutter/niri disable eDP; no config needed).
- Preserve existing multi-monitor behavior exactly: windows continue to distribute to external displays on lid close when docked.
- Close the secondary auto-suspend gaps with explicit, documented decisions (GNOME AC idle-suspend; niri swayidle suspend).
- Proportionate documentation: inline comment in `power.nix`, small edits to `docs/gnome-settings.md` (Power Management section), `docs/niri.md`, one-line touches to `modules/README.md` / `docs/configuration.md`.

**Non-Goals**:
- No new standalone documentation file; no root `README.md` or `hosts/*/README.md` changes (would over-represent a small change).
- No change to `idle-delay = 300` (5-minute screen blank stays).
- No change to `HandleLidSwitchDocked` (default `ignore` already correct).
- No change to battery idle-suspend (`sleep-inactive-battery-timeout = 900` kept as battery/thermal protection).
- No hibernation support, no repo-managed sleep inhibitors (the disabled unit in `modules/home/memory/services.nix:45-46` stays disabled).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Lid-shut laptop in a bag on battery no longer suspends (battery drain / heat) | M | M | Intentional per task; keep battery idle-suspend (900 s) as backstop; state the hazard plainly in `docs/gnome-settings.md` |
| logind does not pick up new `logind.conf` at `nixos-rebuild switch` (old `HandleLidSwitch` stays in memory) | M | L | Phase 4 runtime check via `busctl`; if stale, `systemctl restart systemd-logind` (verify session survives) or reboot |
| Disabling GNOME AC idle-suspend leaves machine on indefinitely when idle on AC | L | H | Intentional ("never sleep unless told" becomes declarative); screen still blanks at 5 min; explicit `systemctl suspend` unaffected; documented trade-off |
| Editing `config/config.kdl` breaks the niri session (raw file, not nix-checked) | M | L | Minimal token removal only; validate with `niri validate -c config/config.kdl` when the `niri` binary is available; niri session is not the active session, so breakage is not locked-out-of-desktop |
| Option path wrong on pinned channel (build failure) | L | L | Already verified by research `nix eval`; Phase 1 verification (`nix flake check`, `nixos-rebuild build`) catches regressions before activation |
| Docs drift from config (e.g. gnome-settings.md still says "Sleep timeout (AC): 60 minutes") | L | M | Phase 5 checklist explicitly reconciles every touched doc line against the final config state |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 have no technical dependency on Phase 1, but Phase 1 lands (and is committed) first so the essential behavior is in the history independently of the secondary decisions.

### Phase 1: Core lid fix — logind ignores the lid switch [COMPLETED]

**Goal**: Lid close never triggers a logind suspend, via one low-risk option block in `modules/system/power.nix`, verified at build/eval level (no activation yet).

**Tasks**:
- [x] Add to `modules/system/power.nix` (inside the existing `services = { ... }` attrset, alongside `power-profiles-daemon`/`fwupd`), with a banner comment block in the file's established style (cf. lines 15-28):

  ```nix
  # ==========================================================================
  # Lid-Close Behavior - Blank, Never Suspend
  # ==========================================================================
  # Lid close must never suspend: long-running headless workloads (AI agents,
  # builds) keep running with the lid shut and no external monitors. The
  # internal panel still goes dark (mutter/niri disable eDP on lid close),
  # and the 5-minute idle blank (GNOME idle-delay) is unaffected.
  #
  # - HandleLidSwitch: covers battery / unspecified power state.
  # - HandleLidSwitchExternalPower: covers AC (systemd default inherits
  #   HandleLidSwitch; set explicitly to be robust to upstream changes).
  # - HandleLidSwitchDocked is deliberately NOT set: it already defaults to
  #   "ignore" (docked = docking station OR >1 display), which together with
  #   gsd-power's handle-lid-switch inhibitor preserves today's
  #   external-monitor behavior exactly (windows stay on external displays).
  #
  # Note: sleep inhibitors (e.g. Claude Code's sleep:idle) do NOT block the
  # lid action (LidSwitchIgnoreInhibited=yes is the logind default), so this
  # config is the only reliable lid protection.
  # ==========================================================================
  logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
  ```

  Use the canonical `settings.Login` form, NOT the deprecated `services.logind.lidSwitch*` aliases. Do not reference task numbers in the comment (deliverables rule).
- [x] `nix flake check` passes.
- [x] `nixos-rebuild build --flake .#hamsa` succeeds (host attribute verified at `flake.nix:132-134`; optionally also `.#nandi` since `power.nix` is shared).
- [x] `nix eval --raw '.#nixosConfigurations.hamsa.config.environment.etc."systemd/logind.conf".text'` shows `HandleLidSwitch=ignore` and `HandleLidSwitchExternalPower=ignore` under `[Login]` (and retains `KillUserProcesses=false`).
- [x] Commit (`task 117 phase 1: ...`) once green.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `modules/system/power.nix` - add logind lid settings + explanatory banner comment (primary "why" documentation lives here)

**Verification**:
- `nix flake check` exits 0
- `nixos-rebuild build --flake .#hamsa` exits 0
- Generated `logind.conf` eval contains both `=ignore` lines

---

### Phase 2: GNOME AC idle-suspend decision — disable suspend-on-idle on AC [COMPLETED]

**Goal**: Close secondary suspend path (a): GNOME currently suspends after 60 idle minutes on AC (`sleep-inactive-ac-timeout = 3600` with live `sleep-inactive-ac-type = 'suspend'` — the type comes from the gsettings default, not the repo). Today this is masked only by Claude Code's own `sleep:idle` inhibitors, which exist only while the CLI runs; agents launched by other means (detached jobs, other tools) would be suspended after an hour.

**Decision (recommended and adopted by this plan)**: set `sleep-inactive-ac-type = "nothing"` in `modules/home/desktop/gnome.nix`, making "never sleep unless told" declarative on AC. Keep `sleep-inactive-battery-timeout = 900` with its default `'suspend'` type as battery/thermal protection.

**Trade-offs (accepted)**:
- On AC, an idle machine stays on indefinitely — acceptable: screen still blanks at 5 min (`idle-delay = 300`), and explicit `systemctl suspend` still works.
- On battery, idle-suspend after 15 min is retained — a headless agent on battery with no inhibitor may still be suspended; this is deliberate battery protection. If the user later wants battery-headless operation, flip `sleep-inactive-battery-type` in a follow-up (documented as such in the doc phase, not changed here).

**Tasks**:
- [x] In `modules/home/desktop/gnome.nix`, extend the `"org/gnome/settings-daemon/plugins/power"` block (lines 37-41): add `sleep-inactive-ac-type = "nothing";` with a short comment (e.g. "never auto-suspend on AC — headless agents keep running; battery timeout below is kept as protection"). Leave `sleep-inactive-ac-timeout` in place (harmless with type `nothing`; keeps the value documented) or remove it with a comment — prefer leaving it. *(left in place, annotated as inert)*
- [x] `nixos-rebuild build --flake .#hamsa` succeeds (Home Manager is part of the NixOS closure via `mkHost`).
- [x] Commit once green.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `modules/home/desktop/gnome.nix` - add `sleep-inactive-ac-type = "nothing"` to the power dconf block

**Verification**:
- `nixos-rebuild build --flake .#hamsa` exits 0
- (Deferred to Phase 4 post-activation) `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` returns `'nothing'`

---

### Phase 3: niri swayidle decision — drop the 10-minute auto-suspend [NOT STARTED]

**Goal**: Close secondary suspend path (b): the niri session (alternate GDM session, not currently active) spawns swayidle with `timeout 600 systemctl suspend` (`config/config.kdl:270`), which would suspend headless agents after 10 idle minutes if the user logs into niri.

**Decision (recommended and adopted by this plan)**: remove only the `"timeout" "600" "systemctl suspend"` argument pair from the swayidle spawn line, keeping the 5-minute `swaylock` timeout, `before-sleep` lock, and `lock` handler. This aligns niri with GNOME ("never sleep unless told") and avoids session-dependent surprise.

**Trade-offs (accepted)**:
- The niri session loses ALL idle auto-suspend, including on battery (swayidle has no AC/battery discrimination, unlike GNOME's split timeouts — so a GNOME-equivalent "AC only" carve-out is not available here without adding tooling). Battery-drain hazard is documented in Phase 5.
- Alternative considered and rejected: leave the line and document the divergence — rejected because a 10-minute silent suspend directly contradicts the task's intent whenever the niri session is used.

**Tasks**:
- [ ] Edit `config/config.kdl:268-270`: update the comment ("Lock after 5 min idle, lock before sleep" — drop "suspend after 10 min") and remove `"timeout" "600" "systemctl suspend"` from the swayidle spawn, preserving all other arguments (`-w`, 300s swaylock, before-sleep, lock).
- [ ] Validate: if the `niri` binary is on PATH, run `niri validate -c config/config.kdl` (exit 0); otherwise visually verify KDL token integrity (quoted-arg list remains well-formed).
- [ ] `nixos-rebuild build --flake .#hamsa` still succeeds (file is deployed by `modules/home/core/dotfiles.nix:28` as a raw source; build confirms nothing else broke).
- [ ] Commit once green.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `config/config.kdl` - remove the 10-minute `systemctl suspend` pair from the swayidle spawn line; fix the adjacent comment

**Verification**:
- `niri validate -c config/config.kdl` exits 0 (when available)
- `grep -c 'systemctl suspend' config/config.kdl` returns 0
- `nixos-rebuild build --flake .#hamsa` exits 0

---

### Phase 4: Activate and verify runtime behavior [NOT STARTED]

**Goal**: Apply all three config changes in one activation and prove the new behavior on the live system (hamsa). Activation requires sudo — coordinate with the user if the implementing agent cannot elevate; all checks below are read-only except the rebuild itself.

**Tasks**:
- [ ] `sudo nixos-rebuild switch --flake .#hamsa` (single activation for Phases 1-3).
- [ ] Logind picked up the config: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` returns `s "ignore"`. If it still shows `"suspend"` (stale in-memory config), run `systemctl restart systemd-logind`, confirm the graphical session survives, and re-check; otherwise schedule a reboot.
- [ ] `grep HandleLidSwitch /etc/systemd/logind.conf` shows both `ignore` lines.
- [ ] GNOME setting live: `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` returns `'nothing'` (may require logout/login for dconf re-read; note result either way).
- [ ] Functional lid test (headless case): with no external monitor, close the lid for ~2 minutes with a long-running process active; reopen. Verify no suspend gap: `journalctl -b -u systemd-logind --since '-10 min' | grep -i lid` shows "Lid closed." with NO subsequent suspend entry, and the process timeline (e.g. `journalctl -f` timestamps or the running agent) is continuous.
- [ ] Regression test (docked case): with an external monitor attached, close the lid — windows remain on the external display exactly as before; `systemd-inhibit --list` still shows gsd-power's `handle-lid-switch` inhibitor while the monitor is attached.
- [ ] Regression test (blank): with the lid open, leave the machine idle 5+ minutes — screen still dims/blanks (`idle-delay = 300` untouched).
- [ ] Commit any residual state changes (there should be none — this phase is verification-only) and mark phase complete.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Files to modify**:
- None (activation + verification only)

**Verification**:
- All busctl/gsettings/journalctl checks above pass
- Both functional tests (headless lid-close, docked lid-close) behave as specified

---

### Phase 5: Proportionate documentation updates [NOT STARTED]

**Goal**: Update existing docs to match the new behavior — small, accurate edits only. No new doc file, no root README changes, no task-number references in any file outside `specs/` (per the no-task-references-in-deliverables rule).

**Tasks**:
- [ ] `docs/gnome-settings.md` — Power Management section (lines 20-26): add a short "Lid-close behavior" bullet group stating: lid close blanks the internal screen but never suspends (logind `HandleLidSwitch*=ignore` in `modules/system/power.nix`); docked/external-monitor behavior unchanged; update the AC sleep line to reflect `sleep-inactive-ac-type = nothing` (AC idle-suspend disabled; battery idle-suspend after 15 min retained as protection); extend the existing inhibitor Note to state that inhibitors are no longer needed for lid protection but still govern idle-suspend on battery; add one plain-language warning that a lid-shut laptop on battery no longer suspends automatically (bag/heat/drain hazard).
- [ ] `docs/niri.md` — two matching touches for the Phase 3 change: the "Swaylock + Swayidle" bullet near line 75 (drop the auto-suspend mention, e.g. "screen locking, auto-lock after 5 min; no idle auto-suspend") and the swayidle-related snippet/description around lines 898-916 if it mentions the 10-minute suspend; add one sentence noting lid close never suspends in either session (logind-level setting).
- [ ] `modules/README.md` — one-line touch: where `power.nix` is characterized (hardware-enablement bullet near line 70), extend to mention lid/logind behavior (e.g. "power profiles, OOM, swap, lid/logind no-suspend"). Do not add a new section.
- [ ] `docs/configuration.md` — line ~33: at most adjust the `power.nix` phrase the same way. Skip entirely if the existing phrasing already covers it generically.
- [ ] Consistency pass: re-read each touched doc line against the final config (power.nix, gnome.nix, config.kdl) — no stale numbers, no over-claiming.
- [ ] Commit; write implementation summary at `specs/117_laptop_lid_close_no_sleep_headless/summaries/01_lid-close-no-sleep-summary.md`.

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `docs/gnome-settings.md` - Power Management section: lid behavior, AC idle-suspend change, battery hazard note
- `docs/niri.md` - swayidle bullet + snippet alignment; one lid-close sentence
- `modules/README.md` - one-line power.nix description touch
- `docs/configuration.md` - at most one phrase adjustment (optional)

**Verification**:
- Every statement in touched docs matches the actual final config values
- No new doc files created; root README untouched (`git status` shows only the four files above plus summary)
- No task-number references introduced outside `specs/`

## Testing & Validation

- [ ] `nix flake check` passes after each config phase
- [ ] `nixos-rebuild build --flake .#hamsa` passes after each config phase (Phases 1-3)
- [ ] Generated logind.conf eval contains `HandleLidSwitch=ignore` and `HandleLidSwitchExternalPower=ignore`
- [ ] Post-switch: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → `s "ignore"`
- [ ] Post-switch: `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` → `'nothing'`
- [ ] Functional: lid close with no external monitor → no suspend (journalctl shows "Lid closed." with no suspend entry); running process continues
- [ ] Regression: lid close with external monitor → windows stay on external display; gsd-power inhibitor still listed
- [ ] Regression: 5-minute idle blank with lid open still works
- [ ] `niri validate -c config/config.kdl` passes (when binary available); no `systemctl suspend` remains in config.kdl

## Artifacts & Outputs

- `specs/117_laptop_lid_close_no_sleep_headless/plans/01_lid-close-no-sleep.md` (this plan)
- Modified: `modules/system/power.nix`, `modules/home/desktop/gnome.nix`, `config/config.kdl`
- Modified docs: `docs/gnome-settings.md`, `docs/niri.md`, `modules/README.md`, optionally `docs/configuration.md`
- `specs/117_laptop_lid_close_no_sleep_headless/summaries/01_lid-close-no-sleep-summary.md` (written at Phase 5 completion)

## Rollback/Contingency

- Each phase is a separate scoped commit; revert with `git revert <sha>` per phase (docs and config revert independently).
- Behavior rollback = config rollback + `sudo nixos-rebuild switch --flake .#hamsa` (or `nixos-rebuild switch --rollback` to the previous generation for immediate relief).
- If `systemctl restart systemd-logind` misbehaves during Phase 4 (session loss), a reboot restores a clean state; the config itself is safe either way.
- If the niri edit causes validation failure, restore the single line from git (`git checkout -- config/config.kdl` is blocked on a dirty tree — use `git restore` after snapshotting per repo git-safety rules, or simply re-edit the one line).
