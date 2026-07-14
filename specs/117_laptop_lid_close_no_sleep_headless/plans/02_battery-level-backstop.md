# Implementation Plan: Task #117 (Round 2) — Battery-Level Backstop

- **Task**: 117 - laptop_lid_close_no_sleep_headless
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: Round-1 implementation (plans/01, committed d82e669: logind lid `lock`, GNOME AC idle-suspend off, niri swayidle suspend removed) — build-verified, activation still pending
- **Research Inputs**: specs/117_laptop_lid_close_no_sleep_headless/reports/03_battery-level-backstop.md (primary, ground truth); reports/01, reports/02 (context only, not revisited)
- **Artifacts**: plans/02_battery-level-backstop.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The machine's only low-battery protection — UPower's "HybridSleep at 2%" — is an illusion while any Claude Code session is open: UPower 1.91.1 fires the legacy `HybridSleep(false)` exactly once, systemd v260 rejects it outright on any `--mode=block` inhibitor (no root exemption on that path), UPower discards the error and never retries, and nothing else stands between 2% and hard power loss (report 03 §1, corroborated by 7 live `BlockedByInhibitorLock` journal denials this boot). This plan adds the real protection: a root systemd timer that polls `/sys/class/power_supply/BAT*` every 60 s and calls `systemctl suspend -i` (= `SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS)`, polkit-authorized implicitly for uid 0, retried every tick so it cannot be raced) at ≤10% while Discharging. Supporting work: raise the GNOME battery idle-suspend to 1 hour with an explicit `suspend` type, fix the orphaned-inhibitor hazard in the Claude session hooks (dead sessions currently leave `sleep infinity` block inhibitors alive until reboot), one user-performed activation with concrete runtime checks, and proportionate doc updates. Done means: build-green config for all three change surfaces, activation checklist handed to the user, and docs that no longer imply the 2% backstop or the old 15-minute battery timeout protect anything.

### Research Integration

From `reports/03_battery-level-backstop.md` (every load-bearing claim below is VERIFIED in that report or re-verified live during planning — see "Planning-Time Verification" below):

- **Blocking chain**: strong (`--mode=block`) inhibitors ⇒ logind rejects all legacy sleep verbs outright, pre-polkit, root included; UPower's critical action is one-shot with a NULL error callback and never falls back (its `CanHybridSleep` pre-check answers "yes" to root via the same-UID short-circuit).
- **Bypass chain**: `systemctl suspend -i` ⇒ `SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS)` (v260 `systemctl-logind.c:95`) ⇒ skips the strong-blocker rejection ⇒ polkit `suspend-ignore-inhibit` implicitly authorizes uid 0. Degrades gracefully on older logind (systemctl retries without the flag bit on InvalidArgs).
- **Threshold 10%**: s2idle-only platform (`[s2idle]` in `/sys/power/mem_sleep`), drain ~1.5-3%/h suspended (INFERENCE from 7040-class Framework reports, flagged) ⇒ 2% ≈ under an hour of suspended survival; 10% ≈ 2-6 h.
- **Hibernate/HybridSleep ruled out**: 16 GiB swapfile vs 30 GiB RAM (~28 GiB routinely used); image allocation unreliable at entry under load. Suspend only.
- **Device topology**: internal battery is `BAT1`; a peripheral `hid-*-battery-144` reports perpetual `Discharging 100` — the glob MUST be `BAT*`, never `power_supply/*`.
- **Orphan hazard**: the hooks' detached `systemd-inhibit ... sleep infinity` processes reparent to `systemd --user` and survive missed SessionEnds (SIGKILL/crash/OOM — earlyoom `--prefer ... claude` on this host) until reboot.
- **GNOME battery timeout**: gsd's battery sleep watch is inert while logind block inhibitors are held (denial logged, no retry within the idle period) and live when they aren't — it delivers requirement (B) for the no-session-open case only.

### Prior Plan Reference

`plans/01_lid-close-no-sleep.md` (round 1, phases 1-3 and 5 completed): validated the `power.nix` banner-comment style and the build-verification loop (`nix flake check` + `nixos-rebuild build --flake .#hamsa`), and demonstrated the cost of unverified upstream option names — round 1 was initially burned by renamed logind options, which sets this plan's verification bar. Its "15-minute battery timeout as backstop" framing is superseded by report 03 and corrected here (Phase 5). Effort calibration: round 1's config phases ran ~30-45 min each including build verification.

### Roadmap Alignment

No ROADMAP.md found (no roadmap context provided for this task).

### User Decisions (fixed constraints — do not re-litigate)

1. **Claude inhibitor hooks stay SESSION-scoped** (SessionStart/SessionEnd). Turn-scoped hooks would risk suspending the machine while background Task agents are still working. **Accepted, documented limitation**: requirement (B) "sleep after an hour without agent activity" is only satisfied when NO Claude session is open. An open-but-idle Claude terminal blocks idle-suspend until the 10% backstop fires. Phase 5 documents this plainly.
2. **Orphaned inhibitors WILL be fixed** (Phase 3) — but only the dead-session-releases-its-lock part; the session-scoped lifetime itself is untouched.

### Planning-Time Verification (live, this session)

- `/sys/class/power_supply/` contains exactly `ACAD`, `BAT1`, `hid-CC22506023M1F42A9-battery-144`, `ucsi-source-psy-USBC000:00{1..4}`. `BAT1` exposes both `status` (live value: `Not charging`, on AC) and `capacity` (live: `100`) attributes. The `BAT*` glob matches only `BAT1`; the peripheral does not match. VERIFIED.
- `systemd.timers` and `systemd.services.<name>.serviceConfig` option paths exist on the pinned nixpkgs: `nix eval .#nixosConfigurations.hamsa.options.systemd.timers.description` succeeds, and `power.nix`'s existing `init-power-profile` proves the `systemd.services` + `serviceConfig` shape builds. VERIFIED.
- gsettings schema: `org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type` is an enum including `'suspend'`; live values right now: battery-type `'suspend'` (schema default, unmanaged), battery-timeout `900`, ac-type `'suspend'` — confirming the round-1 HM changes are committed but NOT yet activated. VERIFIED.
- Inhibitor state right now: 6 live `claude-code` `sleep:idle` block inhibitors alongside 7 live `claude` processes — **no orphaned inhibitor at planning time** (every inhibitor plausibly has a living session). 22 `/tmp/claude-inhibitor-*.pid` files exist, **16 pointing at dead PIDs** (stale files, harmless in themselves but evidence of missed SessionEnds). One-time cleanup is cosmetic-only today; see Phase 3. VERIFIED.
- Pinned nixpkgs: the root `nixpkgs` input resolves to rev `8f0500b9` on `nixos-26.05` (flake.lock). NOTE: report 03 cites rev `cf3ffa5d` for the pin — that rev is a *different* lock node (the naive `.nodes.nixpkgs` entry, which is the unstable node); the report's option-name verifications were done via `nix eval` against the hamsa configuration and therefore against the true pin, so they stand. Flagged so implementers aren't confused by the rev mismatch.
- `config/claude/settings.json` hooks (lines 64-87) are exactly the SessionStart/SessionEnd `systemd-inhibit ... sleep infinity` / pid-file-kill pair from report 03; deployed to `~/.claude/settings.json` via the `home.activation.claudeSettings` copy (not symlink) in `modules/home/core/dotfiles.nix`, so hook changes require a Home Manager activation and runtime drift of the deployed file is by design. VERIFIED.
- `docs/gnome-settings.md` never mentions UPower or "2%" — the doc text to correct is the "15-minute battery idle-suspend remains as a backstop" claims (lines 25, 45-46) and the inhibitor note (line 48), all of which either change value or are falsified by report 03's "inhibitors block gsd's battery suspend too" finding. VERIFIED.

## Goals & Non-Goals

**Goals**:
- A battery-level suspend backstop that fires at ≤10% while Discharging **regardless of sleep inhibitors**, retries every tick, and survives session/compositor/lid state (root timer, sysfs read, `systemctl suspend -i`).
- GNOME battery idle-suspend at 1 hour (3600 s) with `sleep-inactive-battery-type = "suspend"` set explicitly — delivering requirement (B) for the no-Claude-session case.
- Dead/crashed Claude sessions release their sleep inhibitors automatically (inhibitor lifetime tied to the owning process), with the existing SessionEnd release kept as belt-and-suspenders.
- One activation pass (user-performed) with concrete, safe runtime verification of every layer — including the lid-lock behavior from round 1.
- Docs reconciled: new backstop documented, the accepted decision-1 limitation stated plainly, stale "15-minute backstop" claims corrected.

**Non-Goals**:
- No change to the SessionStart/SessionEnd hook *scoping* (decision 1 — no UserPromptSubmit/Stop hooks).
- No hibernate, HybridSleep, or suspend-then-hibernate work (ruled out by report 03 §5; upgrade path noted in docs only).
- No change to `services.upower.*` (see Risks & Decisions — leave-alone recommendation).
- No custom retry-poller for GNOME's one-shot battery idle-suspend race (report 03 §3.3 residual gap accepted; bounded by the ~20% re-arm and the 10% backstop).
- No new standalone doc, no root README changes.
- No re-planning of the round-1 lid/AC work.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backstop suspends mid-flight agent turns at ≤10% | M | M (by design) | Requirement (C) by design; 60 s poll gives a plug-in grace window; escape hatch `systemctl stop battery-suspend-backstop.timer` documented for deliberate low-battery sessions |
| Wake at ≤10% still Discharging → re-suspend within ~60 s (suspend loop) | L | H (by design) | Intentional: the loop IS the protection; user plugs in to exit it. Documented explicitly (Phase 5). Worst-case cadence ~2 min with default timer `AccuracySec=1min` — still ≥6 Wh of headroom at 10% |
| Peripheral battery (`hid-*-battery-144`, perpetual `Discharging 100`) false-triggers the backstop | H | L | Glob is `BAT*` only (verified: matches only `BAT1` here; inert on desktop hosts like garuda); guard comment in the unit forbids widening the glob |
| `$PPID`/ancestor inside the hook shell is not the `claude` process → tether kills the inhibitor immediately or never | M | M | Phase 3 verifies the process ancestry empirically with a probe before finalizing; ancestor-walk fallback specified; SessionEnd kill retained regardless, so worst case equals today's behavior |
| systemd/UPower version bump changes `-i`/inhibitor semantics | L | L | `-i` degrades gracefully (v260 systemctl retries without the flag on InvalidArgs); banner comment cites the version-exact analysis and report path for future audits |
| logind/gsd not picking up new config at switch (stale `HandleLidSwitch`, dconf) | M | L | Phase 4 checks live values via `busctl`/`gsettings`; restart `systemd-logind` or re-login per check output |
| Hook edit drifts between repo and deployed `~/.claude/settings.json` | L | M | Deployment is an activation-script copy by design; Phase 4 diffs the deployed hook block against the repo after switch |
| Suspending with `-i` while another legitimate block inhibitor is held (e.g. a system update) | L | L | Accepted: at ≤10% discharging, power loss is strictly worse than any interrupted job; documented |

**UPower 2% setting — recommendation: LEAVE UNTOUCHED (no `services.upower.*` change).** Reasoning: (i) with the 10% timer active, an awake-and-discharging machine suspends at 10%, so the 2% ACTION level is practically unreachable while awake — the setting becomes moot, and s2idle drain below 10% happens *suspended*, where UPower's poll loop isn't running the show anyway; (ii) in the one path where it could still fire (user deliberately stopped the backstop timer for a low-battery session, no inhibitors held), HybridSleep-at-2% is a best-effort last resort whose failure mode (stays awake) is no worse than having disabled it; (iii) reconfiguring `criticalPowerAction = "PowerOff"` would trade that for a guaranteed hard shutdown — worse than the status quo behind a working 10% backstop; (iv) any change here is churn on a verified non-load-bearing path. The plan documents (Phase 5) that the 2% action is NOT protection, without touching its config.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 3 have no technical dependency on Phase 1 (different files), but Phase 1 lands and is committed first so the core protection is in the history independently. Phase 5 (docs) needs the final shape of Phases 1-3 but not the user activation in Phase 4; Phases 4 and 5 can proceed in parallel (Phase 4's runtime half is user-performed).

### Phase 1: Battery-level suspend backstop — root timer, `systemctl suspend -i` at ≤10% Discharging [COMPLETED]

**Goal**: Core requirement (C): a root systemd service + timer in `modules/system/power.nix` that polls the internal battery every 60 s and suspends — bypassing all sleep inhibitors — at ≤10% while genuinely Discharging. Build-verified; activation is Phase 4.

**Tasks**:
- [x] Add to `modules/system/power.nix`, in the file's established banner-comment style, a `systemd.services.battery-suspend-backstop` + `systemd.timers.battery-suspend-backstop` pair. Reference shape (report 03 §6, corrected for Nix string escaping — the report's `%%` is unnecessary for `echo` and `''${cap}` is the required indented-string escape for a literal shell `${cap}`):

  ```nix
  # ==========================================================================
  # Battery Suspend Backstop - fires REGARDLESS of sleep inhibitors
  # ==========================================================================
  # Claude Code sessions hold logind block inhibitors (sleep:idle). On systemd
  # 260 a strong block inhibitor makes logind reject ALL ordinary sleep
  # requests outright - including UPower's own 2% CriticalPowerAction (verified
  # from source; see specs/117_laptop_lid_close_no_sleep_headless/reports/
  # 03_battery-level-backstop.md). Without this unit, a lid-closed laptop with
  # active agents drains to 0% and hard-powers-off.
  # `systemctl suspend -i` = SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS),
  # which root is polkit-authorized to use; the timer retries every minute so
  # it cannot be raced by a freshly acquired inhibitor, and re-suspends after
  # any wake that is still <= threshold and discharging (plug in to escape,
  # or: systemctl stop battery-suspend-backstop.timer for a deliberate
  # low-battery session).
  # Glob BAT* ONLY - never power_supply/*: this host has a peripheral
  # hid-*-battery reporting perpetual "Discharging 100" that must not match.
  # ==========================================================================
  systemd.services.battery-suspend-backstop = {
    description = "Suspend at <=10% battery, bypassing sleep inhibitors";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "battery-suspend-backstop" ''
        threshold=10
        for bat in /sys/class/power_supply/BAT*; do
          [ -e "$bat/capacity" ] || continue
          status=$(cat "$bat/status")
          cap=$(cat "$bat/capacity")
          if [ "$status" = "Discharging" ] && [ "$cap" -le "$threshold" ]; then
            echo "battery at ''${cap}% and discharging: suspending (inhibitors bypassed)"
            exec ${pkgs.systemd}/bin/systemctl suspend -i
          fi
        done
      '';
    };
  };
  systemd.timers.battery-suspend-backstop = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "60s";
    };
  };
  ```
- [x] Discharging-only guard: the `status = "Discharging"` string comparison is the AC gate (live-verified strings on this host: `Not charging` and `Charging` on AC/dock, `Discharging` on battery). Do NOT add `ConditionACPower` — it would duplicate the gate with subtly different multi-supply semantics; the sysfs check is authoritative.
- [x] Hysteresis / repeated-fire behavior — make the chosen semantics explicit in the banner comment (they are intentional, not an oversight): on wake at ≤10% still Discharging, the next tick (≤60 s, worst case ~2 min under default timer `AccuracySec=1min` coalescing) re-suspends. This loop is the protection: each cycle costs little battery, and s2idle at ≤10% survives hours. The two escape hatches (plug in; stop the timer) go in the comment and in Phase 5's docs. No threshold-band hysteresis (e.g. suspend at 10, re-allow at 15) is added: it would only lengthen awake time below 10% with no benefit, since there is no user-visible flapping to damp (the machine is suspended, not cycling a service).
- [x] Update the file-header summary comment on line 1 of `power.nix` to mention the battery backstop.
- [x] Build-level verification (see below), then commit (`task 117 phase 1: battery suspend backstop timer`). *(verified: `nix flake check` green; `nixos-rebuild build --flake .#hamsa` green; ExecStart eval shows BAT* glob / threshold 10 / `suspend -i`; timerConfig shows OnBootSec=2min + OnUnitActiveSec=60s; store-script dry-run exits 0 silently on AC; branch logic additionally exercised against fake sysfs values — fires at 9 and 10 Discharging, silent at 11/Not charging/Charging)*

**Verification**:
- `nix flake check` passes.
- `nixos-rebuild build --flake .#hamsa` succeeds.
- Eval/inspection: `nix eval --raw .#nixosConfigurations.hamsa.config.systemd.services.battery-suspend-backstop.serviceConfig.ExecStart` shows the store-path script; `nix build` the script derivation or read it from the eval output and confirm the glob is `BAT*`, the threshold is 10, and `suspend -i` is the verb. `nix eval .#nixosConfigurations.hamsa.config.systemd.timers.battery-suspend-backstop.timerConfig` shows both timer keys.
- Dry-run the script logic outside systemd (safe, no suspend at current 100%/AC): `bash <store-script>` exits 0 silently.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `modules/system/power.nix` — add service + timer block, update header comment

---

### Phase 2: GNOME battery idle timeout — 3600 s + explicit suspend type [COMPLETED]

**Goal**: Requirement (B) for the no-session-open case: battery idle-suspend at 1 hour instead of 15 minutes, with the action type pinned explicitly instead of riding the schema default.

**Tasks**:
- [x] In `modules/home/desktop/gnome.nix`, `"org/gnome/settings-daemon/plugins/power"` block (lines 37-44):
  - `sleep-inactive-battery-timeout = 900` → `3600`, with the comment updated to say 60 minutes and to note it fires only when no block inhibitor is held (an open Claude session blocks it until the 10% backstop — decision 1).
  - Add `sleep-inactive-battery-type = "suspend";` explicitly (schema-verified enum value; currently implicit default). Rationale comment: after deliberately setting the AC type to `"nothing"`, leaving the battery type implicit invites drift.
- [x] Keep `sleep-inactive-ac-type = "nothing"` and the rest of the block untouched.
- [x] Build-level verification, then commit (`task 117 phase 2: gnome battery idle timeout 3600`). *(verified: flake check green; hamsa build green; HM dconf eval shows `sleep-inactive-battery-timeout = 3600` and `sleep-inactive-battery-type = "suspend"` with ac-type still `"nothing"`)*

**Verification**:
- `nix flake check` passes; `nixos-rebuild build --flake .#hamsa` succeeds (HM is a NixOS module in this flake, so the system build covers gnome.nix).
- Eval/inspection: `nix eval .#nixosConfigurations.hamsa.config.home-manager.users.benjamin.dconf.settings."org/gnome/settings-daemon/plugins/power"` shows `sleep-inactive-battery-timeout = 3600` and `sleep-inactive-battery-type = "suspend"` (adjust attr path if eval shape differs; the round-1 plan used the same check for the AC type).
- Note: live `gsettings` values change only after Phase 4 activation (they currently still show the pre-round-1 values).

**Timing**: 0.5 hours

**Depends on**: 1 (sequencing only — core protection lands first)

**Files to modify**:
- `modules/home/desktop/gnome.nix` — two-line change + comments

---

### Phase 3: Orphan inhibitor cleanup — tether inhibitor lifetime to the owning session process [COMPLETED]

**Goal**: A Claude session that dies without firing SessionEnd (SIGKILL, crash, earlyoom — which `--prefer`s claude) no longer leaves a `sleep infinity` block inhibitor alive until reboot. Hooks stay SESSION-scoped (decision 1); only the release path is hardened.

**Current state (verified at planning time)**: `config/claude/settings.json` hooks lines 64-87 — SessionStart backgrounds `systemd-inhibit --what=sleep:idle --who=claude-code --mode=block sleep infinity`, writes its PID to `/tmp/claude-inhibitor-${SESSION_ID}.pid`; SessionEnd kills that PID and removes the file. The detached inhibitor reparents to `systemd --user`, so nothing ties it to the session. Right now: **no orphaned inhibitors live** (6 inhibitors ↔ 7 claude processes), but **16 of 22 pid files point at dead PIDs** — evidence the SessionEnd path is routinely missed. One-time cleanup today is therefore cosmetic (stale pid files only), not urgent (no live orphan to kill).

**Mechanism (simplest robust)**: replace the inhibitor's payload `sleep infinity` with a waiter tethered to the owning `claude` process: `tail --pid=<claude-pid> -f /dev/null`. When the claude process dies — however it dies — `tail` exits, `systemd-inhibit` exits, the lock is released. The SessionEnd kill stays as belt-and-suspenders (releases faster than tail's poll and cleans the pid file). No reaper daemon, no new units.

**Tasks**:
- [x] **Verify the ancestry assumption first** (report 03 flags `$PPID` as unverified): determine what process the hook shell's parent actually is. Probe: temporarily add `ps -o pid=,comm= -p $$ $PPID >> /tmp/claude-hook-probe.txt` to a SessionStart hook in the DEPLOYED `~/.claude/settings.json` (runtime edits there are by-design overwritten at next switch), start a scratch session (`claude -p 'hi'` or interactive + exit), inspect the probe output. *(verified 2026-07-14: probe ancestry `sh(hook) <- claude <- ...` — the hook shell's `$PPID` IS the owning claude process directly; no intermediate wrapper, ancestor-walk fallback not needed. Deployed settings.json restored from backup after the probe. Additionally verified the tether mechanism end-to-end in isolation: `systemd-inhibit --mode=block tail --pid=<owner> -f /dev/null` acquired the lock, and `kill -9 <owner>` released it within ~1 s.)*
  - If `$PPID` is the `claude` process: use `tail --pid=$PPID -f /dev/null` directly (note: `$PPID` must be expanded by the hook shell itself, not inside a nested subshell that changes parentage — bash keeps `PPID` constant in `&` subshells, so plain `systemd-inhibit ... tail --pid=$PPID -f /dev/null &` is safe).
  - If there is an intermediate wrapper: use a short ancestor walk to find the nearest ancestor whose comm is `claude` (e.g. `p=$PPID; while [ "$p" -gt 1 ] && [ "$(ps -o comm= -p "$p")" != "claude" ]; do p=$(ps -o ppid= -p "$p" | tr -d ' '); done`), falling back to `$PPID` if the walk hits PID 1 (worst case = today's behavior, never worse).
- [x] Edit the SessionStart hook command in `config/claude/settings.json`: swap `sleep infinity` for the verified tether; keep the `SESSION_ID` extraction, pid-file write, `--what/--who/--why/--mode` flags, and `async: true` exactly as they are. *(tether: `tail --pid=$PPID -f /dev/null`, direct form per verified ancestry)*
- [x] In the same SessionStart command, prepend a cheap stale-pid-file reap (self-healing, no daemon): `for f in /tmp/claude-inhibitor-*.pid; do [ -f "$f" ] && ! kill -0 "$(cat "$f")" 2>/dev/null && rm -f "$f"; done` — removes files whose PID is dead. (It must NOT kill live PIDs it can't attribute — a live PID in a stale-looking file belongs to a running session's inhibitor.) *(reap loop exercised in isolation against live/dead/empty fake pid files: live kept, dead+empty removed, nothing killed)*
- [x] Leave the SessionEnd hook unchanged (it is correct and remains the fast-path release).
- [x] One-time manual step (document in the summary for the user; safe to run anytime): `for f in /tmp/claude-inhibitor-*.pid; do kill -0 "$(cat "$f")" 2>/dev/null || rm -f "$f"; done` to clear the 16 stale files. No orphaned *inhibitor* needs killing today; if one exists at implementation time, `systemd-inhibit --list` + cross-check against live claude sessions, then `kill <inhibitor-pid>`. *(documented in summaries/02; the new hook's built-in reap also self-heals this at every future SessionStart)*
- [x] Validate JSON (`jq . config/claude/settings.json`), then commit (`task 117 phase 3: tether claude inhibitors to session process`). *(verified: jq parses; extracted hook command passes `bash -n`; `nixos-rebuild build --flake .#hamsa` green)*

**Verification**:
- Build-level: `jq . config/claude/settings.json` parses; `nixos-rebuild build --flake .#hamsa` still succeeds (the file is deployed by an HM activation script — build proves nothing about the JSON beyond the copy existing, hence the explicit jq check).
- Runtime (after Phase 4 activation, listed there too): start a scratch Claude session, confirm `systemd-inhibit --list` gains a claude-code entry whose payload is `tail`, then `kill -9` the scratch claude process and confirm the inhibitor disappears within a few seconds without SessionEnd.

**Timing**: 1 hour

**Depends on**: 1 (sequencing only)

**Files to modify**:
- `config/claude/settings.json` — SessionStart hook command string only

---

### Phase 4: Activation + runtime verification (user-performed switch) [NOT STARTED]

**Goal**: One `sudo nixos-rebuild switch --flake .#hamsa` + reboot activates everything from both rounds (lid `lock`, AC no-suspend, battery timeout, backstop timer, hook fix), then each layer is verified live with safe checks — no battery draining, no stranding.

**Tasks**:
- [ ] Hand the user the activation step (interactive sudo is NOT available to agents): `sudo nixos-rebuild switch --flake .#hamsa`, then reboot (reboot also clears any pre-fix stale inhibitor state and guarantees fresh logind/gsd config).
- [ ] Post-activation checks (agent-runnable except where marked USER):
  1. **Backstop timer live**: `systemctl list-timers battery-suspend-backstop.timer --no-pager` shows the timer active with next elapse ≤60 s away; `systemctl status battery-suspend-backstop.service` shows clean oneshot runs; `journalctl -u battery-suspend-backstop.service -n 10` is silent at >10% (script exits 0 without output).
  2. **Suspend-bypass path works — SAFE A/B test, no battery drain** (USER, with a Claude session deliberately open so block inhibitors are held): first `sudo systemctl suspend` must be REFUSED with `BlockedByInhibitorLock` (proves inhibitors work); then `sudo systemctl suspend -i` must suspend the machine despite them (wake with lid/keypress; proves the exact call the backstop makes). This validates the whole §1/§6 chain without simulating low battery.
  3. **Threshold logic dry-run without suspending**: run the store script manually while on AC (`bash $(systemctl cat battery-suspend-backstop.service | sed -n 's/^ExecStart=//p')`) — must exit silently since status is not `Discharging`; optionally verify the decision inputs directly: `cat /sys/class/power_supply/BAT1/{status,capacity}`. Do NOT test by draining to 10%.
  4. **GNOME values live**: `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout` → `3600`; `... sleep-inactive-battery-type` → `'suspend'`; `... sleep-inactive-ac-type` → `'nothing'` (this last one is the round-1 change finally going live — it currently still reads `'suspend'`).
  5. **Lid behavior (round-1 activation)**: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → `"lock"` (and `HandleLidSwitchExternalPower` → `"lock"`); if stale, `systemctl restart systemd-logind` then re-check. USER: close lid undocked → session locks, panel powers off ~30 s later, machine stays awake.
  6. **Hook tether live**: deployed `~/.claude/settings.json` hook block matches the repo (`diff <(jq .hooks ~/.claude/settings.json) <(jq .hooks config/claude/settings.json)`); scratch-session kill test from Phase 3 passes; `systemd-inhibit --list` shows claude-code entries with `tail` payloads.
- [ ] Record outcomes in the implementation summary; any failed check stays [PARTIAL] with the failing layer named.
- [ ] Commit any follow-up fixes discovered (`task 117 phase 4: activation verification`).

**Timing**: 0.5 hours (agent side; user performs switch/reboot and the two USER checks)

**Depends on**: 1, 2, 3

**Files to modify**:
- None expected (verification only; fixes loop back into the owning phase's file)

---

### Phase 5: Documentation — proportionate updates, accepted limitation stated plainly [NOT STARTED]

**Goal**: Docs match the new reality: 10% backstop exists and is the only inhibitor-proof protection; battery idle-suspend is 1 hour and only fires with no session open; the old "15-minute backstop" and "inhibitors govern idle-suspend" framings are corrected. No new standalone doc, no root README changes.

**Tasks**:
- [ ] `modules/system/power.nix`: banner comments are written in Phases 1 (backstop) — this phase only cross-checks them against final behavior (threshold, escape hatches, re-suspend loop) after Phase 4 findings.
- [ ] `docs/gnome-settings.md` — Power Management section:
  - Line 25: "**Sleep timeout (Battery)**: 900 seconds (15 minutes) - retained as battery/thermal protection" → 3600 seconds (60 minutes), explicit `suspend` type, and the caveat that it fires only when no sleep inhibitor is held.
  - Add a short "Battery backstop" bullet: root timer suspends at ≤10% while discharging, **bypassing all sleep inhibitors** (`systemctl suspend -i`); re-suspends after wake until plugged in; escape hatch `systemctl stop battery-suspend-backstop.timer`; note that suspend on this platform is s2idle and still drains ~1.5-3%/h, so a bagged laptop at 10% survives hours, not days (hibernate upgrade path: grow swapfile ≥ RAM, test, then consider suspend-then-hibernate).
  - **Document the accepted limitation (decision 1), plainly**: Claude Code sessions hold a block inhibitor for their whole lifetime — an open-but-idle Claude terminal prevents battery idle-suspend entirely; such a machine sleeps only at the 10% backstop. Close sessions (or `exit` idle terminals) to let the 1-hour battery idle-suspend work.
  - Correct any residual text implying UPower's 2% critical action protects anything: state that under block inhibitors it is denied and never retried (it is left configured but is not load-bearing). (Planning-time grep found no explicit "2%"/UPower text in docs/ — the correction lands as part of the new backstop bullet rather than editing nonexistent text; the false claims actually present are the two "15-minute backstop" lines above.)
- [ ] `docs/gnome-settings.md` — Lid-Close Behavior section (lines 28-48):
  - Line 43-46 warning ("The 15-minute battery idle-suspend above remains as a backstop"): replace with the 10% backstop as the real bagged-laptop protection, keeping the "suspend explicitly before bagging" advice.
  - Line 48 note ("inhibitors ... still matter on battery, where they block the 15-minute idle-suspend"): update to 60 minutes and add that the 10% backstop deliberately bypasses inhibitors, including the Neovim `<leader>rz` one.
- [ ] Reconcile every touched doc line against the final config state (round-1 lesson: checklist each line).
- [ ] Commit (`task 117 phase 5: documentation`).

**Verification**:
- `grep -n "900\|15 minutes\|15-minute" docs/gnome-settings.md` returns no stale battery-timeout claims; `grep -n "backstop" docs/gnome-settings.md modules/system/power.nix` shows the new sections; a read-through of the Power Management + Lid-Close sections against `gnome.nix`/`power.nix` finds no contradiction.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3 (final config shape; can run in parallel with Phase 4)

**Files to modify**:
- `docs/gnome-settings.md` — Power Management + Lid-Close Behavior sections
- `modules/system/power.nix` — comment cross-check only (content written in Phase 1)

## Testing & Validation

- [ ] `nix flake check` green after each config phase (1, 2).
- [ ] `nixos-rebuild build --flake .#hamsa` green after each config phase (1, 2, 3).
- [ ] Eval checks: backstop `ExecStart`/`timerConfig` (Phase 1), dconf power block (Phase 2).
- [ ] `jq .` parses `config/claude/settings.json` (Phase 3).
- [ ] Safe A/B suspend test: plain `suspend` refused under inhibitors, `suspend -i` succeeds (Phase 4, USER).
- [ ] Backstop timer listed and ticking cleanly; script dry-run exits silently on AC (Phase 4).
- [ ] Live gsettings: battery timeout 3600 / type `suspend` / ac-type `nothing` (Phase 4).
- [ ] `HandleLidSwitch` live-reads `"lock"`; physical lid-close check (Phase 4, USER).
- [ ] Scratch-session `kill -9` releases its inhibitor without SessionEnd (Phase 4).
- [ ] Docs contain no stale 900 s/15-minute/backstop claims; accepted limitation documented (Phase 5).

## Artifacts & Outputs

- `plans/02_battery-level-backstop.md` (this file)
- Modified: `modules/system/power.nix`, `modules/home/desktop/gnome.nix`, `config/claude/settings.json`, `docs/gnome-settings.md`
- `summaries/02_battery-level-backstop-summary.md` (on implementation completion; must include the user activation checklist and the one-time stale-pid-file cleanup command)

## Rollback/Contingency

- Each phase is one scoped commit; revert with `git revert <sha>` per phase (no cross-file coupling between phases 1-3).
- Backstop misbehaving live (e.g. false trigger): immediate mitigation without rebuild — `sudo systemctl stop battery-suspend-backstop.timer && sudo systemctl disable battery-suspend-backstop.timer` (masks until next switch); then fix or revert Phase 1 and rebuild.
- Hook tether misbehaving (inhibitor dying early): revert Phase 3 commit and re-run the switch — deployed settings.json returns to the `sleep infinity` design (today's behavior); no state to migrate.
- GNOME values: revert Phase 2 commit; dconf keys return at next activation (or `gsettings reset` per key for an immediate live fix).
- Nothing in this plan touches the round-1 lid configuration; its rollback story is unchanged from plans/01.

## Flagged Unverified Items (high bar — round 2 disproved a round-1 source-level claim)

- **s2idle drain rate 1.5-3%/h**: INFERENCE from Framework 7040-class community reports (report 03); no measured figure for this Ryzen AI 300 board. Affects only the threshold *rationale* (10% vs 2%), not the mechanism.
- **Hook shell ancestry (`$PPID` = claude process)**: NOT verified at planning time; Phase 3 verifies empirically before finalizing, with an ancestor-walk fallback and a worst-case equal to today's behavior.
- **`suspend -i` end-to-end on THIS machine**: the chain is source-verified (v260) and polkit-verified, but has never been executed here; Phase 4 check 2 is the live proof, done safely before the backstop ever needs to fire for real.
- **Report 03's nixpkgs rev label (`cf3ffa5d`)**: does not match the root `nixpkgs` lock node (`8f0500b9`, nixos-26.05); the report's option verifications were made against the hamsa config (true pin) so they stand, but the rev citation itself is mislabeled. Re-verified `systemd.timers`/`systemd.services` shapes against the actual pin during planning.
- **HM eval attr path in Phase 2 verification** (`config.home-manager.users.benjamin.dconf.settings...`): shape assumed from the flake's HM-as-NixOS-module layout; adjust at implementation if the eval errors (the build check is the authoritative gate either way).
