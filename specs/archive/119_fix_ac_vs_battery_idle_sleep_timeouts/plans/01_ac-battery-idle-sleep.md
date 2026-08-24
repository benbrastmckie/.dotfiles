# Implementation Plan: Task #119

- **Task**: 119 - fix_ac_vs_battery_idle_sleep_timeouts
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: task 117 (laptop_lid_close_no_sleep_headless), task 118
  (document_no_sleep_functionality) — both complete; this task revises the layer they built
- **Research Inputs**: specs/119_fix_ac_vs_battery_idle_sleep_timeouts/reports/01_ac-battery-idle-sleep.md
- **Artifacts**: plans/01_ac-battery-idle-sleep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  .claude/rules/nix.md, .claude/rules/artifact-formats.md,
  .claude/rules/plan-format-enforcement.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Replace the current unbounded `sleep-inactive-ac-type = "nothing"` in
`modules/home/desktop/gnome.nix` with an explicit, auditable 12-hour AC idle-suspend ceiling
(`"suspend"` + `43200`), leaving the existing 1-hour battery leg (`"suspend"` + `3600`)
untouched. GNOME's dconf schema natively supports the AC/battery split, so this is a two-value
change to an existing mechanism, not new infrastructure. The definition of done is not "the file
was edited": it is that `nix flake check` passes, both affected configurations build, the
repository documentation that currently states the old values is updated, and a post-activation
`gsettings get` on the **live** system reports `'suspend'` / `43200` — the activation-lag class
of bug this repo has already been bitten by once (task 118's `HandleLidSwitch` gap).

### Research Integration

The research report is live-verified and treated as the factual basis. Findings carried into
this plan:

- **The core fix is two dconf values**, at `modules/home/desktop/gnome.nix:40-41`, inside the
  existing `"org/gnome/settings-daemon/plugins/power"` block. All four
  `sleep-inactive-{ac,battery}-{type,timeout}` keys were confirmed live-present and
  independently AC/battery-scoped on this host's GNOME Shell 50.2 (`gsettings list-keys`).
- **`systemd-logind`'s `IdleAction`/`IdleActionSec` must NOT be used** for this split — it is a
  single value with no concept of power source. It is currently inert (`IdleAction=ignore`,
  live-confirmed) and stays that way. `modules/system/power.nix` is not edited by this task
  except that no edit is made at all; the constraint is instead recorded as an inline comment
  in `gnome.nix` so a future maintainer does not "fix" this by reaching for `IdleActionSec`.
- **"No Claude activity" reuses the existing session-scoped inhibitor** from tasks 117/118 —
  an open Claude Code session holds a `sleep:idle` block inhibitor for its whole lifetime
  (live-confirmed via `systemd-inhibit --list`). No new Claude-activity detection is built,
  and `config/claude/settings.json` is not touched.
- **The reported ~1h AC sleep is most likely an activation-lag / schema-default artifact**
  (GNOME's schema defaults are exactly `'suspend'` / `3600`). This cannot be proven from
  read-only forensics after the fact, and it does not need to be: the explicit 12h/1h values
  close both the schema-default fallback path and the `"nothing"`-vs-12h spec mismatch at once.
  The current live value being `'nothing'` (i.e. the bug not reproducing right now) is
  explicitly **not** treated as "nothing to fix".

### Prior Plan Reference

No prior plan. This is plan version 1 for task 119.

### Roadmap Alignment

`specs/ROADMAP.md` exists but contains only template placeholders (Phase 1 reads
"(No items yet -- add roadmap items here)"). There are no roadmap items to advance or annotate,
and this plan does not modify ROADMAP.md.

## Scope Decision: GNOME Only, niri Parity Deferred

This is the explicit scoping decision the research report asked the planner to make, recorded
here so the boundary is auditable and nothing is silently dropped.

**Decision: implement the fix for the GNOME session only. niri AC/battery parity is OUT of
scope for task 119 and is deferred to a follow-up task recommendation (Phase 5).**

Justification:

1. **GNOME is the live, active session.** `XDG_CURRENT_DESKTOP=GNOME` /
   `XDG_SESSION_DESKTOP=gnome` were confirmed live this session. The user's stated requirement
   ("the computer sleeps after roughly an hour ... even when plugged in") is an observation
   about their actual working session, and correctness there is what this task must deliver.
2. **GNOME needs no new mechanism.** The AC/battery split already exists as first-class dconf
   keys; only two values change. Risk is proportional to a two-line diff.
3. **niri needs genuinely new infrastructure.** `swayidle` has no AC/battery-conditional
   timeout — a single `timeout N command` clause applies unconditionally. Parity requires
   either a power-state-aware supervisor that respawns `swayidle` on `ACAD/online`
   transitions, or a pair of mutually-exclusive systemd user units. Both introduce new
   failure modes (respawn races, double-armed idle timers, a supervisor that dies silently
   and leaves the machine with no idle policy at all).
4. **Bundling them would delay the correct fix behind the risky one.** Blocking a verified
   two-value change on new supervisor infrastructure is the wrong trade.
5. **niri's current state is not what is causing the reported problem, and is fail-safe.**
   Task 117 deliberately removed niri's only idle-suspend clause, so niri has zero
   auto-suspend on any power state. That is a real, acknowledged gap versus the 12h/1h spec —
   but it errs toward "stays awake", not toward "sleeps too early", and niri is not the
   session exhibiting the bug.

**What being out of scope explicitly means** (so this is not silently dropped):

- After this task, a niri session still has **no** idle auto-suspend on AC or on battery. The
  only remaining protection on niri is the 10%-battery `battery-suspend-backstop` timer in
  `modules/system/power.nix` (unchanged by this task).
- `config/config.kdl` is **not** edited by this task.
- `modules/home/desktop/swaylock.nix`'s commented-out `services.swayidle` block (which contains
  a stale unconditional `timeout 600 -> systemctl suspend` example) is **not** resurrected. It
  predates the AC/battery split requirement and must not be reused verbatim.
- Phase 4 records the niri gap in `docs/no-sleep-agents.md` as a known, deliberate divergence
  rather than leaving the docs implying parity.
- Phase 5 produces a fully-described follow-up task recommendation for niri parity.

## Goals & Non-Goals

**Goals**:

- On AC with no Claude Code session open and no user input, the machine stays awake for 12
  hours and then idle-suspends (explicit bounded ceiling, not an implicit "never").
- On battery with no Claude Code session open and no user input, the machine idle-suspends
  after 1 hour (unchanged behavior, now the only 1-hour leg in the config).
- The committed Nix value and the **live** dconf value are proven to agree after activation.
- Repository documentation that currently asserts the old AC values is corrected in the same
  change, so `docs/` does not become a stale second source of truth.
- The "do not route this through logind `IdleAction`" constraint is recorded where the next
  maintainer will look.

**Non-Goals**:

- niri AC/battery parity (see Scope Decision; deferred to a follow-up task).
- Any change to `systemd-logind` settings, including `IdleAction`/`IdleActionSec` and the lid
  handlers (`HandleLidSwitch` / `HandleLidSwitchExternalPower` stay `"lock"`).
- Any change to the `battery-suspend-backstop` service/timer in `modules/system/power.nix`.
- Any change to Claude Code inhibitor logic or `config/claude/settings.json`.
- Any new Claude-activity detection, polling, CPU/IO monitoring, or per-keystroke tracking.
- Changing `idle-delay` (screen blank/dim at 300s) — that is not suspend and must not be
  conflated with it.
- Investigating the `BAT1/status = Discharging at 100%` charge-controller quirk (ruled out as a
  cause by direct `OnBattery` reads).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-enabling AC idle-suspend introduces a real suspend path where none currently fires; a 12h-idle unattended non-Claude workload would now be suspended | M | M | 12h is the explicit user requirement. Non-Claude unattended workloads should hold their own `systemd-inhibit` block, consistent with the existing inhibitor philosophy. Recorded in the docs update (Phase 4) so the expectation is written down, not folklore. |
| Committed Nix value does not match the live dconf value after rebuild (the task-118 activation-lag class of bug) | H | M | Phase 3 is a dedicated live-verification phase: it reads the running system with `gsettings get`, not the file. A mismatch fails the phase and triggers the documented remediation ladder rather than being reported as success. |
| Only one of the two Home Manager paths is activated, so `~/.nix-profile` and `/etc/profiles/per-user` disagree | M | M | Phase 2 builds both `nixosConfigurations.hamsa` and `homeConfigurations.benjamin`; Phase 3 verifies the live dconf value after whichever switch the user runs, and `scripts/update.sh` runs both in sequence. |
| `gsettings get` returning the right value proves the dconf DB, not that `gnome-settings-daemon` internalized it | M | L | gsd-power tracks GSettings change notifications live, so a DB match is sufficient in practice. Phase 3 records log-out/log-in as the escalation if behavior still disagrees with the DB, and states this limitation explicitly rather than overclaiming. |
| 43200 rejected or clamped by the schema/UI (uint32 range or GNOME Settings' own option list) | L | L | The Phase 3 live read is itself the check: if the DB reports anything other than `43200`, the phase fails loudly. No assumption is made that the value round-trips. |
| Docs (`docs/no-sleep-agents.md`, `docs/gnome-settings.md`) keep asserting `"nothing"` and become a contradictory second source of truth | M | H (if not handled) | Phase 4 updates both files, including the scenario-composition table and the "Activation & verification" expected-value block. |
| niri gap forgotten once this task closes | M | M | Recorded in three places: the Scope Decision above, the docs update (Phase 4), and the follow-up task recommendation (Phase 5). |
| `nix eval` attribute path for the dconf value does not resolve as written | L | M | Phase 2 treats the `nix eval` probe as best-effort with a documented fallback (grep the generated dconf keyfile in the build result). The authoritative check remains the Phase 3 live read. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Set the explicit 12h AC / 1h battery dconf values [COMPLETED]

**Goal**: Change the two AC keys in `modules/home/desktop/gnome.nix` to an explicit bounded
12-hour suspend ceiling, leave the battery leg untouched, and record the logind constraint
inline.

**Tasks**:

- [ ] Edit `modules/home/desktop/gnome.nix`, in the `"org/gnome/settings-daemon/plugins/power"`
      block (currently lines 37-53):
  - [ ] `sleep-inactive-ac-type = "suspend";` (was `"nothing"`)
  - [ ] `sleep-inactive-ac-timeout = 43200;` (was `3600`) with a comment stating `12 hours`
  - [ ] Leave `sleep-inactive-battery-type = "suspend"` and
        `sleep-inactive-battery-timeout = 3600` byte-for-byte unchanged
  - [ ] Leave `idle-dim = true` and the `"org/gnome/desktop/session"` `idle-delay = 300`
        unchanged (screen blank/dim, not suspend)
- [ ] Replace the now-false leading comment (`# Never auto-suspend on AC — headless agents keep
      running.`) with one that states the actual contract: an explicit 12h AC ceiling, which
      only elapses when no logind block inhibitor is held (i.e. no open Claude Code session)
      and the user is input-idle for the full window.
- [ ] Add a short inline comment recording the constraint that this split is deliberately
      expressed via GNOME's AC/battery-scoped dconf keys and must **not** be moved to
      `systemd-logind`'s `IdleAction`/`IdleActionSec`, which is a single non-AC-aware value.
- [ ] Confirm no other file in the repo is edited in this phase (`modules/system/power.nix`,
      `config/config.kdl`, `modules/home/desktop/swaylock.nix`, and
      `config/claude/settings.json` are all untouched).

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:

- `modules/home/desktop/gnome.nix` - two dconf values changed; two comments corrected/added

**Verification**:

- `git diff --stat` shows exactly one file changed.
- `git diff modules/home/desktop/gnome.nix` shows `sleep-inactive-ac-type` = `"suspend"` and
  `sleep-inactive-ac-timeout` = `43200`, with no change to either `sleep-inactive-battery-*`
  line.
- `nix fmt` (RFC 166 / `pkgs.nixfmt`, per this repo's formatter) leaves the file unchanged, and
  `statix check modules/home/desktop/gnome.nix` reports no new findings.

---

### Phase 2: Static verification — flake check, both builds, and evaluated-value probe [COMPLETED]

**Goal**: Prove the change evaluates and builds in both Home Manager paths, and that the built
configuration actually carries `43200` rather than merely that the source file was edited.

**Tasks**:

- [ ] Run `nix flake check` from the repository root; it must pass.
- [ ] Build the NixOS-integrated path: `nixos-rebuild build --flake .#hamsa` (build only, no
      `switch` in this phase).
- [ ] Build the standalone Home Manager path:
      `home-manager build --flake .#benjamin`.
- [ ] Probe the **evaluated** value (best-effort, not the authoritative check):
      `nix eval '.#homeConfigurations.benjamin.config.dconf.settings."org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-timeout'`
      and the corresponding `...sleep-inactive-ac-type`. Expected `43200` and `"suspend"`.
- [ ] If that attribute path does not resolve (module internals may differ), fall back to
      grepping the generated dconf keyfile inside the build result for
      `sleep-inactive-ac-timeout` and confirm it reads `43200`. Record which method was used.
- [ ] Record the exact commands run and their outcomes for the implementation summary.

**Timing**: 40 minutes (dominated by build time)

**Depends on**: 1

**Files to modify**: none (verification only)

**Verification**:

- `nix flake check` exits 0.
- Both `nixos-rebuild build --flake .#hamsa` and `home-manager build --flake .#benjamin` exit 0.
- The evaluated/generated value for `sleep-inactive-ac-timeout` is `43200` and
  `sleep-inactive-ac-type` is `suspend`, via either the `nix eval` probe or the keyfile-grep
  fallback. A build that succeeds without this value being confirmed does **not** satisfy this
  phase.

---

### Phase 3: Activation and LIVE dconf verification (activation-lag guard) [COMPLETED]

**Goal**: Prove the values are live on the running system by reading the running system, closing
the "committed but not actually in effect" gap that task 118 already documented for
`HandleLidSwitch`.

**Tasks**:

- [x] Capture the pre-activation baseline for the record *(completed)*:
      `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` ->
      `'nothing'` (as expected before activation), `sleep-inactive-ac-timeout` -> `3600`,
      `sleep-inactive-battery-type` -> `'suspend'`, `sleep-inactive-battery-timeout` -> `3600`.
- [x] Activate. *(completed — the blocker recorded in the prior dispatch has dissolved: the
      NixOS-integrated path was switched via `sudo nixos-rebuild switch --flake .#hamsa`
      (`/run/current-system` now resolves to the exact store path built and verified in
      Phase 2, `nixos-system-hamsa-26.05.20260710.8f0500b`) and the standalone path via
      `home-manager switch --flake .#benjamin` (generation `home-manager-213-link`, created
      2026-07-25 07:18 PDT). Both activations landed within the same minute, consistent with
      `bash scripts/update.sh` having run both in sequence.)*
- [x] Read the LIVE values — re-run independently in this dispatch, not merely transcribed from
      the orchestrator's report:
  - [x] `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type`
        -> `'suspend'` (confirmed, live read this dispatch)
  - [x] `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout`
        -> `43200` (confirmed, live read this dispatch — **not** the `3600` schema default)
  - [x] `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type`
        -> confirmed `'suspend'` (unchanged by this task, as expected)
  - [x] `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout`
        -> confirmed `3600` (unchanged by this task, as expected)
- [x] Confirm the untouched neighbors did not regress *(completed, re-verified live this
      dispatch)*: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1
      org.freedesktop.login1.Manager IdleAction` -> `"ignore"`, `HandleLidSwitch` -> `"lock"`,
      and `HandleLidSwitchExternalPower` -> `"lock"` (additional neighbor checked, also
      unaffected).
- [x] Confirm the two Home Manager profile paths agree *(completed — deeper than a `gsettings`
      read, this traces both activation paths to their generated dconf keyfiles)*: the
      NixOS-integrated path's `systemd` unit `home-manager-benjamin.service` (active/exited,
      "Activating dconfSettings" logged) and the standalone
      `~/.local/state/nix/profiles/home-manager` generation both resolve their `dconf load`
      step to the byte-identical store path `hm-dconf.ini`
      (`/nix/store/m38ajb6p0zwppsfgblr1hrknvcw377mf-hm-dconf.ini`), which contains
      `sleep-inactive-ac-timeout=43200` / `sleep-inactive-ac-type='suspend'` /
      `sleep-inactive-battery-timeout=3600` / `sleep-inactive-battery-type='suspend'`. The two
      paths are not merely both-correct by coincidence — they reference the same derivation.
- [x] Confirm the dconf keyfile in the active profile carries the new values *(completed)*: see
      the `hm-dconf.ini` content quoted immediately above, read directly from the Nix store
      path referenced by both live activation records.
- [ ] On any mismatch, do not report success. Work the remediation ladder in order and re-read
      after each step: (1) confirm the Home Manager path that owns `dconf` actually activated
      (re-run its `switch` and watch for the dconf activation step); (2) re-read to rule out a
      transient; (3) log out and back in to force a fresh `gnome-settings-daemon`; (4) if it
      still disagrees, stop and report the mismatch as a blocker with all four `gsettings`
      readings attached. *(deviation: skipped — not reached; no mismatch occurred on any of the
      four live reads, so the remediation ladder was never triggered.)*
- [x] Note the known limitation in the summary *(completed)*: `gsettings get` proves the dconf
      database value. gsd-power follows GSettings change notifications live, so a DB match is
      sufficient in practice, but a DB match is not by itself proof that the daemon re-armed its
      timer.

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**: none (activation and live verification only)

**Verification**:

- All four live `gsettings get` reads return the intended values (`'suspend'`, `43200`,
  `'suspend'`, `3600`).
- `IdleAction` is still `"ignore"` and `HandleLidSwitch` is still `"lock"`.
- The four live readings are transcribed verbatim into the implementation summary as evidence.

---

### Phase 4: Update the documentation that asserts the old AC values [COMPLETED]

**Goal**: Keep `docs/` from becoming a stale contradictory source of truth, and record the niri
divergence explicitly.

**Tasks**:

- [ ] Update `docs/no-sleep-agents.md`:
  - [ ] The GNOME settings block (around lines 109-112) currently shows
        `sleep-inactive-ac-type = "nothing"` and the "inert given the type above" note for the
        AC timeout. Change to `"suspend"` / `43200` with a `12 hours` annotation; leave the
        battery lines as-is.
  - [ ] The "How the four mechanisms compose" table (around lines 199-211): the two AC rows
        currently read "Nothing sleeps — AC idle-suspend is disabled outright" and "Still
        nothing — AC idle-suspend type is `"nothing"` unconditionally". Rewrite as: with a
        Claude session open, the inhibitor blocks suspend indefinitely; with no session open
        and 12h of idle, the machine suspends.
  - [ ] The "Activation & verification" section's GNOME block (around lines 245-253): add
        `sleep-inactive-ac-timeout` to the listed `gsettings get` commands and change the
        expected values from `'nothing'`, `'suspend'`, `3600` to `'suspend'`, `43200`,
        `'suspend'`, `3600`.
  - [ ] In the niri section (mechanism 3), state plainly that niri has no idle auto-suspend on
        either power state and therefore does not have the 12h/1h split, that this is a
        deliberate deferral rather than an oversight, and that `swayidle` has no
        AC/battery-conditional timeout of its own.
- [ ] Update `docs/gnome-settings.md` (around lines 25-28): change the AC bullet from
      `sleep-inactive-ac-type = "nothing"` / "never auto-suspends on AC" / "timeout ... is
      inert" to the explicit 12h ceiling; leave the battery bullet unchanged.
- [ ] Grep for any other occurrence of the stale claim so nothing is missed:
      `grep -rn 'sleep-inactive-ac\|never auto-suspend' docs/ modules/ README.md`.
- [ ] Per `.claude/rules/no-task-references-in-deliverables.md`, do not cite task numbers in
      the `docs/` prose.

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:

- `docs/no-sleep-agents.md` - settings block, composition table, verification block, niri note
- `docs/gnome-settings.md` - AC idle-suspend bullet

**Verification**:

- `grep -rn 'sleep-inactive-ac-type' docs/` shows only `"suspend"`, with no remaining
  `"nothing"`.
- `grep -rn '43200' docs/` matches in both updated files.
- The `gsettings` commands quoted in `docs/no-sleep-agents.md` match the ones actually run in
  Phase 3, and their stated expected values match the readings recorded there.
- No task numbers appear in the edited `docs/` prose.

---

### Phase 5: Record the niri boundary and produce the follow-up task recommendation [COMPLETED]

**Goal**: Close the task with the deferral written down as an actionable recommendation, so the
niri gap is deferred rather than dropped.

**Tasks**:

- [x] Write `specs/119_fix_ac_vs_battery_idle_sleep_timeouts/summaries/01_ac-battery-idle-sleep-summary.md`
      containing: the diff summary, the exact verification commands run in Phases 2 and 3 with
      their verbatim outputs, and the scope boundary restated. *(completed — updated in this
      dispatch with the actual post-activation live evidence now that Phase 3's blocker has
      dissolved: all four `gsettings` reads and the two `busctl` reads were re-run
      independently and confirm the fix is live)*
- [x] Include a "Deferred — niri AC/battery parity" section in the summary describing the
      follow-up work concretely enough to act on:
  - Problem: niri has zero idle auto-suspend on any power state; `swayidle`
    (`config/config.kdl:271`) has no AC/battery-conditional timeout.
  - Option A: a power-state-aware supervisor that respawns
    `swayidle -w timeout <43200|3600> 'systemctl suspend'` on `/sys/class/power_supply/ACAD/online`
    transitions, structurally mirroring the udev idiom already used in
    `modules/system/power.nix`.
  - Option B: two mutually-exclusive systemd user units (`swayidle-ac` / `swayidle-battery`)
    gated on AC power.
  - Known hazards either way: respawn races, two idle timers armed at once, and a supervisor
    that dies silently leaving no idle policy at all.
  - Explicit warning not to resurrect the commented-out `services.swayidle` block in
    `modules/home/desktop/swaylock.nix` verbatim — its unconditional `timeout 600 -> systemctl
    suspend` predates the AC/battery split requirement.
- [x] Surface a ready-to-run task-creation invocation in the summary, e.g.
      `/task "Give the niri session AC/battery-conditional idle suspend (12h AC, 1h battery) to
      match the GNOME session"`. Do **not** create the task automatically: task creation is an
      interactive, user-confirmed operation under this repo's multi-task creation standard.
      *(completed — superseded: this follow-up task was subsequently created and tracked
      separately (task 120) between dispatches of this task, so the summary now points to that
      tracked task instead of a still-pending invocation)*
- [x] Confirm the final change set is exactly `modules/home/desktop/gnome.nix`,
      `docs/no-sleep-agents.md`, `docs/gnome-settings.md`, plus this task's `specs/` artifacts —
      and nothing else. *(completed — `git status --short` confirmed confined to those paths
      plus orchestrator-managed `specs/TODO.md` / `specs/state.json`, which this agent does not
      touch)*

**Timing**: 20 minutes

**Depends on**: 3, 4

**Files to modify**:

- `specs/119_fix_ac_vs_battery_idle_sleep_timeouts/summaries/01_ac-battery-idle-sleep-summary.md`
  (new)

**Verification**:

- The summary exists, is non-empty, and contains the verbatim Phase 3 live `gsettings` readings.
- The summary contains the niri deferral section and the ready-to-run `/task` invocation.
- `git status --short` shows no files changed outside the four expected paths above.

---

## Testing & Validation

- [ ] `nix fmt` leaves `modules/home/desktop/gnome.nix` unchanged; `statix check` reports no new
      findings.
- [x] `nix flake check` exits 0. *(verified in Phase 2)*
- [x] `nixos-rebuild build --flake .#hamsa` exits 0. *(verified in Phase 2; the built store path
      is the one now running as `/run/current-system`)*
- [x] `home-manager build --flake .#benjamin` exits 0. *(verified in Phase 2)*
- [x] The evaluated/generated dconf value for `sleep-inactive-ac-timeout` is `43200` (via
      `nix eval` or the keyfile-grep fallback) — build success alone is not sufficient.
      *(verified in Phase 2 via `nix eval`)*
- [x] LIVE, post-activation:
      `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` is
      `'suspend'`. *(re-verified independently this dispatch)*
- [x] LIVE, post-activation:
      `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout` is
      `43200`. *(re-verified independently this dispatch)*
- [x] LIVE, post-activation: `sleep-inactive-battery-type` is still `'suspend'` and
      `sleep-inactive-battery-timeout` is still `3600` (no regression on the battery leg).
      *(re-verified independently this dispatch)*
- [x] LIVE: `busctl get-property ... IdleAction` is still `"ignore"` and `HandleLidSwitch` is
      still `"lock"`. *(re-verified independently this dispatch; `HandleLidSwitchExternalPower`
      also checked and is `"lock"`)*
- [x] `systemd-inhibit --list | grep claude-code` still shows a held `sleep:idle` block
      inhibitor while a Claude Code session is open (the "no Claude activity" mechanism is
      intact and untouched). *(re-verified this dispatch — multiple `claude-code` `sleep:idle`
      block inhibitors held)*
- [x] `grep -rn 'sleep-inactive-ac-type' docs/` returns only `"suspend"`. *(re-verified this
      dispatch)*
- [x] `git status --short` shows changes confined to `modules/home/desktop/gnome.nix`,
      `docs/no-sleep-agents.md`, `docs/gnome-settings.md`, and this task's `specs/` artifacts.
      *(re-verified this dispatch: clean apart from this task's own `specs/` scratch/artifact
      files)*

**Behavioral note**: the 12-hour AC path cannot be wall-clock tested within this task. The live
dconf reads plus the unchanged, already-verified inhibitor mechanism are the accepted evidence;
the summary should say so explicitly rather than implying an end-to-end 12h observation.

## Artifacts & Outputs

- `specs/119_fix_ac_vs_battery_idle_sleep_timeouts/plans/01_ac-battery-idle-sleep.md` (this file)
- `specs/119_fix_ac_vs_battery_idle_sleep_timeouts/summaries/01_ac-battery-idle-sleep-summary.md`
- `modules/home/desktop/gnome.nix` (modified: two dconf values, two comments)
- `docs/no-sleep-agents.md` (modified: settings block, composition table, verification block,
  niri note)
- `docs/gnome-settings.md` (modified: AC idle-suspend bullet)
- A follow-up task recommendation for niri AC/battery parity, recorded in the summary (task not
  auto-created)

## Rollback/Contingency

**Immediate live mitigation** (seconds, no rebuild) if the new AC suspend behaves badly:

```bash
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
```

This restores the previous "never suspend on AC" behavior instantly. Caveat: it is a live-only
dconf write and will be overwritten by the next Home Manager activation, so it is a stopgap, not
a fix.

**Durable rollback**: revert the commit and re-activate.

```bash
git revert <commit-sha>          # never `git reset --hard` on a dirty tree
bash scripts/update.sh           # or: sudo nixos-rebuild switch --flake .#hamsa
                                 #     home-manager switch --flake .#benjamin
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type   # expect 'nothing'
```

The revert restores `docs/` alongside the config, so documentation and behavior stay consistent
under rollback.

**Partial-failure contingency**:

- Phase 2 fails (build or evaluated-value probe): nothing has been activated; fix forward in
  `gnome.nix` and re-run Phase 2. No rollback needed.
- Phase 3 mismatch that survives the remediation ladder: leave the commit in place, mark the
  phase `[BLOCKED]`, and report the four live `gsettings` readings. Do not mark the task
  complete on a file-level-only verification — an unproven live value is exactly the bug class
  this task exists to eliminate.
- Phase 4 partially applied: harmless in isolation (docs-only), but do not close the task with
  `docs/` still asserting `"nothing"`.
