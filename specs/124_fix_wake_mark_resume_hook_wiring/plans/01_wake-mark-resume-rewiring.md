# Implementation Plan: Wake-Mark Resume Hook Rewiring

- **Task**: 124 - Fix wake-mark resume hook wiring
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours (of which ~0.75 hour is user-executed and cannot be performed by an agent)
- **Dependencies**: None
- **Research Inputs**: specs/124_fix_wake_mark_resume_hook_wiring/reports/01_wake-mark-resume-hook.md
- **Artifacts**: plans/01_wake-mark-resume-rewiring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

`battery-backstop-wake-mark.service` (defined in `modules/system/power.nix`) declares only
`WantedBy=post-resume.target`, and `post-resume.target` does not exist on this host
(`LoadState=not-found`), so the unit has never been pulled in by a resume. The backstop's
wake-grace window is therefore permanently inert. This plan rewires the unit to the
`sleep.target` mechanism that demonstrably exists and is already loaded here (nixpkgs's own
`sleep-actions.service` uses exactly this shape), moving the script from `ExecStart` to
`ExecStop` so it runs post-resume, and rewrites the two in-file comments that currently cite the
disproven `post-resume.target` / `.wants/`-symlink precedent. Definition of done is a **real**
suspend/resume cycle on host `hamsa` that produces a fresh `/var/lib/battery-suspend-backstop/wake-mark`
timestamp — nothing weaker counts.

### Research Integration

The research report's primary recommendation is adopted verbatim: `wantedBy = [ "sleep.target" ]`,
`before = [ "sleep.target" ]`, `unitConfig.StopWhenUnneeded = true`, `RemainAfterExit = true`,
`Type = "oneshot"`, and `ExecStop = batteryBackstopWakeMark` with `ExecStart` omitted entirely
(valid per `man systemd.service`: a unit with no `ExecStart=` is legal given `RemainAfterExit=yes`
plus at least one `ExecStop=`). The report's `powerManagement.resumeCommands` alternative is
recorded here as the documented contingency (Rollback/Contingency section) rather than the primary
path, per the report's own trade-off analysis: the dedicated unit preserves the
`battery-backstop-wake-mark` name used by `systemctl status`/journal filtering and by the
cross-reference comment in the sibling `battery-suspend-backstop` unit's banner. The report's
"forgot to update the false-proof comment" risk is discharged by making the comment rewrite a
mandatory task inside Phase 1, not a follow-up.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided for this task.

## Goals & Non-Goals

**Goals**:
- Rewire `battery-backstop-wake-mark` from the non-existent `post-resume.target` to the live
  `sleep.target` mechanism, with the wake-mark script running post-resume via `ExecStop`.
- Rewrite both in-file comments that cite the disproven precedent (the unit banner at
  `modules/system/power.nix:329-333`, and the script's own comment at `power.nix:35` which says
  "Written by the post-resume.target hook on every wake").
- Prove the fix with an actual suspend/resume cycle on `hamsa` producing a fresh wake-mark file.
- Leave a durable record of the real verification output so the false-proof pattern cannot recur.

**Non-Goals**:
- Changing the wake-grace logic itself (`batteryBackstopScript`, `batteryBackstopWakeMark` script
  bodies, `grace_secs`/`grace_floor`/`grace_drop` parameters). The scripts are correct; only the
  wiring is broken.
- Fixing `disable-speaker-amp.service` in `modules/system/audio.nix`, which has the identical dead
  `post-resume.target` reference on its resume path. Same root cause, separately scoped; flag as a
  follow-up in the summary, do not bundle.
- Introducing `powerManagement.resumeCommands` (kept as contingency only).
- Any git push or PR creation.

## Prohibited Evidence (binding on the implementer)

The following MUST NOT be presented, in any phase, as evidence that the wiring works. Each is a
specific false proof already identified for this task:

1. **`.wants/` directory or symlink inspection.** `ls /etc/systemd/system/sleep.target.wants/`,
   `ls .../post-resume.target.wants/`, or the presence of a symlink in a build result. systemd's
   unit generator writes `[Install]`-declared `.wants/` symlinks from the unit file's static
   `WantedBy=` list regardless of whether the target resolves — which is precisely how the current
   broken wiring produced a populated `post-resume.target.wants/` while never firing.
2. **A test harness that writes the wake-mark itself.** Any script, `--test` flag, or manual
   `echo ... > wake-mark` that produces the file. This proves the script works (already known) and
   proves nothing about the systemd trigger.
3. **`systemctl start battery-backstop-wake-mark.service`** (or `systemctl stop`) invoked by hand.
   Same defect as (2): exercises the script, not the `sleep.target` lifecycle.
4. **Citing `sleep-actions.service` or the man page as proof this unit fires.** These are valid
   grounds for *choosing* the mechanism (Phase 1 rationale) and are already recorded in the
   research report; they are not verification of this unit.
5. **`nixos-rebuild build` succeeding, or the generated unit text looking correct.** Phase 2 is a
   syntax/eval/shape gate and is explicitly labeled as such below. Passing Phase 2 is necessary
   and nowhere near sufficient.

The only acceptable proof is Phase 4: a fresh `wake-mark` epoch timestamp strictly greater than a
pre-suspend baseline, produced by a real suspend and physical wake, corroborated by journal
entries for the unit bracketing the sleep.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer declares victory at Phase 2 (build green) and never obtains real verification | H | H | Phase 2 tasks are explicitly labeled "NOT wiring proof"; Prohibited Evidence item 5; Phase 4 is a hard gate whose completion requires pasted user-supplied terminal output containing two epoch values |
| `before = [ "sleep.target" ]` on an `ExecStart`-less unit does not activate in time | M | L | Byte-for-byte the shape nixpkgs's `sleep-actions.service` already generates and which is loaded on this host; if it nonetheless fails, Phase 5 contingency switches to `powerManagement.resumeCommands`, reusing that already-vetted unit |
| Comment rewrite forgotten, leaving the disproven `.wants/`-as-proof claim in the tree | M | M | Made a mandatory checklist item in Phase 1 covering BOTH comment sites (lines ~35 and ~329-333); Phase 2 includes a grep gate for residual `post-resume` mentions in `power.nix` |
| `sudo nixos-rebuild switch` cannot be run by an autonomous agent (password/privilege) | M | H | Phase 3 is marked user-executed with exact commands and expected output |
| A real `systemctl suspend` would sever the agent's own session | H | H | Phase 4 is marked user-executed; the agent MUST stop and hand off rather than attempt it |
| Suspend never actually entered (e.g. inhibitor held), producing a false negative | M | L | Phase 4 records `journalctl -b -u systemd-suspend.service` alongside the wake-mark check so "did the machine actually sleep" is separable from "did the hook fire" |
| Regression: wake-mark now written on the resume path only, so first-boot has no wake-mark | L | M | Intended and already handled — the backstop script's fail-safe direction treats a missing/stale wake-mark as "no grace", i.e. the pre-existing unconditional behavior |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase
gates the next, and Phases 3 and 4 additionally gate on a human.

---

### Phase 1: Rewire the unit to sleep.target and remove the false-proof comments [COMPLETED]

**Goal**: `battery-backstop-wake-mark` is declared against `sleep.target` with the wake-mark
script on `ExecStop`, and no comment in `power.nix` still cites `post-resume.target` or
`.wants/`-symlink presence as evidence.

**Tasks**:
- [x] Replace the `battery-backstop-wake-mark` attribute set (currently `modules/system/power.nix`
      ~lines 329-342) with:
      ```nix
      battery-backstop-wake-mark = {
        description = "Record wake timestamp/capacity for the battery-suspend-backstop wake-grace window";
        wantedBy = [ "sleep.target" ];
        before = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "battery-suspend-backstop";
          ExecStop = batteryBackstopWakeMark;
        };
      };
      ```
      Note the four deltas: `post-resume.target` -> `sleep.target` in `wantedBy`; new
      `before`; new `unitConfig.StopWhenUnneeded` and `RemainAfterExit`; `ExecStart` ->
      `ExecStop`. `ExecStart` is omitted entirely, not stubbed with a no-op.
- [x] Rewrite the unit banner comment (currently ~lines 329-333). It must no longer claim
      `disable-speaker-amp` / `post-resume.target` / a `.wants/` symlink as the proven idiom.
      Replace with the real grounding: `sleep.target` is the documented systemd integration point
      for post-resume hooks (`man systemd.special`, "hook program code after the actual system
      sleep operation ... place the command in ExecStop=, enable StopWhenUnneeded= and
      RemainAfterExit="), and nixpkgs's own `sleep-actions.service` (generated by
      `powerManagement.enable`, already set in this module) uses this exact shape on this host.
      State plainly that `post-resume.target` does not exist here and that a populated `.wants/`
      directory is not evidence of wiring.
- [x] Fix the stale script comment at ~line 35 inside `batteryBackstopWakeMark`
      ("Written by the post-resume.target hook on every wake") to say it is run as the
      `sleep.target` hook's `ExecStop`, i.e. after every resume.
- [x] Do not touch `batteryBackstopScript`, the timer, the threshold/grace parameters, or
      `modules/system/audio.nix`.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `modules/system/power.nix` - unit rewiring (~lines 329-342), unit banner comment rewrite
  (~lines 329-333), script comment fix (~line 35)

**Verification**:
- `git diff modules/system/power.nix` shows exactly the unit change plus the two comment rewrites,
  and nothing else.
- `grep -n "post-resume" modules/system/power.nix` returns only lines that explicitly describe
  `post-resume.target` as non-existent/disproven (or returns nothing).
- No new files created.

---

### Phase 2: Evaluation and generated-unit shape gate (NOT wiring proof) [COMPLETED]

**Goal**: The change evaluates and builds, and the generated unit text has the intended shape.
This phase catches typos and Nix errors. It says nothing whatsoever about whether the hook fires.

**Tasks**:
- [x] `cd /home/benjamin/.dotfiles && nix flake check` (or at minimum
      `nixos-rebuild build --flake .#hamsa`) completes without evaluation errors.
- [x] Inspect the generated unit **text** in the build output:
      `cat ./result/etc/systemd/system/battery-backstop-wake-mark.service`
      Expect: `Before=sleep.target`, `StopWhenUnneeded=true`, `Type=oneshot`,
      `RemainAfterExit=true`, `ExecStop=/nix/store/...battery-backstop-wake-mark`,
      `WantedBy=sleep.target` under `[Install]`, and **no** `ExecStart=` line and **no**
      `post-resume.target` anywhere in the file.
- [x] Record the exact command output in the phase notes.
- [x] Explicitly write in the phase notes: "Phase 2 is an eval/shape gate only. Per the plan's
      Prohibited Evidence section, a green build and correct unit text are NOT evidence the resume
      hook fires. Wiring is unproven until Phase 4."

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**: none (read-only verification; `./result` symlink may be created)

**Verification**:
- Build/eval exits 0.
- Generated unit text matches the expected directives above, with `ExecStart` absent.
- The Prohibited-Evidence disclaimer is present in the phase notes.
- The implementer does NOT run `ls` on any `.wants/` directory as part of this phase (Prohibited
  Evidence item 1).

**Phase Notes**:

`nix flake check` output (tail): all four `nixosConfigurations` (nandi, hamsa, garuda, iso plus
usb-installer) evaluated successfully; final line `all checks passed!`. Exit 0.

`nixos-rebuild build --flake .#hamsa` output (tail):
```
building the system configuration...
building '/nix/store/f6mnkx7ckgl7phjibzbpy984sfn2y63h-battery-backstop-wake-mark.drv'...
building '/nix/store/fwsvar8ls7k5y2wy7ib1pnvx9phpj03a-unit-battery-backstop-wake-mark.service.drv'...
...
Done. The new configuration is /nix/store/sg9gshigzqkcd5g3xg1dwvhq2cs8lx2b-nixos-system-hamsa-26.05.20260710.8f0500b
```
Exit 0.

`cat ./result/etc/systemd/system/battery-backstop-wake-mark.service`:
```
[Unit]
Before=sleep.target
Description=Record wake timestamp/capacity for the battery-suspend-backstop wake-grace window
StopWhenUnneeded=true

[Service]
Environment="LOCALE_ARCHIVE=..."
Environment="PATH=..."
Environment="TZDIR=..."
ExecStop=/nix/store/pi2wc9n4xldvkgrrba69dmjisnxh969g-battery-backstop-wake-mark
RemainAfterExit=true
StateDirectory=battery-suspend-backstop
Type=oneshot

[Install]
WantedBy=sleep.target
```
`grep -c ExecStart` and `grep -c post-resume` against this file both returned no match (grep exit
1, count 0) -- confirming no `ExecStart=` line and no `post-resume` string anywhere in the
generated unit. All expected directives present: `Before=sleep.target`, `StopWhenUnneeded=true`,
`Type=oneshot`, `RemainAfterExit=true`, `ExecStop=/nix/store/...battery-backstop-wake-mark`,
`WantedBy=sleep.target`.

No `.wants/` directory was inspected as part of this phase (Prohibited Evidence item 1 avoided).

**Phase 2 is an eval/shape gate only. Per the plan's Prohibited Evidence section, a green build
and correct unit text are NOT evidence the resume hook fires. Wiring is unproven until Phase 4.**

---

### Phase 3: Activation on hamsa — USER-EXECUTED [COMPLETED]

**Observed on hamsa (generation activated 2026-08-05, user-run `nixos-rebuild switch`)**:
- `systemctl show battery-backstop-wake-mark.service` → `LoadState=loaded`,
  `UnitFileState=enabled`, `ActiveState=inactive`, `WantedBy=sleep.target`.
- `systemctl cat battery-backstop-wake-mark.service` → `Before=sleep.target`,
  `StopWhenUnneeded=true`, `RemainAfterExit=true`, `Type=oneshot`,
  `ExecStop=/nix/store/pi2wc9n4xldvkgrrba69dmjisnxh969g-battery-backstop-wake-mark`,
  `[Install] WantedBy=sleep.target`, and **zero** `ExecStart=` lines (grep count 0).
- `systemctl show sleep.target --property=LoadState` → `LoadState=loaded`.
- Contrast confirmed: `systemctl show post-resume.target --property=LoadState` →
  `LoadState=not-found` (the dead target the unit was previously wired to).

**Goal**: The new generation is the running system, so the `sleep.target` wiring is live.

**Owner**: **USER (required).** `nixos-rebuild switch` needs root on the live host. An autonomous
agent MUST NOT attempt this and MUST NOT mark this phase complete from its own output.

**Tasks** (for the user to run, verbatim):
- [ ] ```bash
      cd /home/benjamin/.dotfiles
      sudo nixos-rebuild switch --flake .#hamsa
      ```
- [ ] ```bash
      systemctl show battery-backstop-wake-mark.service \
        --property=LoadState,UnitFileState,ActiveState
      ```
      Expected: `LoadState=loaded`, `UnitFileState=enabled` (or `linked`/`static` as generated),
      `ActiveState=inactive`.
- [ ] ```bash
      systemctl cat battery-backstop-wake-mark.service
      ```
      Expected: matches the Phase 2 shape (`Before=sleep.target`, `StopWhenUnneeded=true`,
      `RemainAfterExit=true`, `ExecStop=...`, no `ExecStart=`, `WantedBy=sleep.target`).
- [ ] ```bash
      systemctl show sleep.target --property=LoadState
      ```
      Expected: `LoadState=loaded` (contrast: `post-resume.target` reports
      `LoadState=not-found`).
- [ ] Paste all four outputs back to the agent/session.

**Timing**: 0.25 hours (user)

**Depends on**: 2

**Files to modify**: none

**Verification**:
- User-pasted output shows `LoadState=loaded` for both the unit and `sleep.target`.
- `systemctl cat` output shows `ExecStop=` and no `ExecStart=`.
- Still NOT wiring proof: this confirms the unit exists in the running closure, which is the same
  thing that was true (via a dead target) before the fix.

---

### Phase 4: Live suspend/resume verification — USER-EXECUTED, HARD GATE [NOT STARTED]

**Goal**: A real suspend and physical wake causes `battery-backstop-wake-mark` to run its
`ExecStop`, writing a fresh `wake-mark`. This is the only phase that proves the task is fixed.

**Owner**: **USER (required).** A real `systemctl suspend` puts the machine to sleep, which would
sever any agent session mid-command. The agent MUST hand off here, wait for user-supplied output,
and MUST NOT substitute any alternative check. Note that `HandleLidSwitch = "lock"` on this host
means closing the lid will NOT suspend — use `systemctl suspend` directly.

**Tasks** (for the user to run, verbatim):
- [ ] **Baseline, before suspending:**
      ```bash
      date +%s
      cat /var/lib/battery-suspend-backstop/wake-mark 2>&1
      stat -c '%y' /var/lib/battery-suspend-backstop/wake-mark 2>&1
      ls -l /var/lib/battery-suspend-backstop/notified 2>&1
      ```
      Record the `date +%s` value as `BASELINE_EPOCH`. The wake-mark file may legitimately be
      absent or stale — either is a fine baseline; absence is expected if the hook has genuinely
      never fired.
- [ ] **Real suspend:**
      ```bash
      systemctl suspend
      ```
      Wait for the machine to actually enter sleep (screen off, power LED indicates sleep), then
      wake it physically (press a key / power button). Wait at least 15 seconds after the desktop
      returns before running the post-checks.
- [ ] **Post-resume checks:**
      ```bash
      date +%s
      cat /var/lib/battery-suspend-backstop/wake-mark
      journalctl -u battery-backstop-wake-mark.service --since "-10 minutes" --no-pager
      systemctl show battery-backstop-wake-mark.service \
        --property=ActiveEnterTimestamp,InactiveEnterTimestamp,ExecMainStatus
      ls -l /var/lib/battery-suspend-backstop/notified 2>&1
      journalctl -b -u systemd-suspend.service --no-pager | tail -20
      ```
- [ ] Paste every one of the above outputs back to the agent/session.

**Expected output — all of these must hold:**
1. `cat .../wake-mark` prints two whitespace-separated fields: an epoch timestamp **strictly
   greater than `BASELINE_EPOCH`**, and a plausible battery capacity integer (0-100).
2. `journalctl -u battery-backstop-wake-mark.service` shows the unit starting and stopping around
   the suspend/resume boundary (e.g. `Starting Record wake timestamp/capacity ...` before sleep,
   then `Stopping`/`Stopped` after resume). Non-empty output for the window is required.
3. `ExecMainStatus=0` (the `ExecStop` script exited cleanly).
4. `ActiveEnterTimestamp` precedes the sleep and `InactiveEnterTimestamp` follows the resume —
   i.e. the unit's lifetime brackets the sleep.
5. `/var/lib/battery-suspend-backstop/notified` is absent after resume (the script `rm -f`s it) —
   an independent second signal the `ExecStop` really ran rather than a stale file being read.
6. `journalctl -b -u systemd-suspend.service` confirms the system actually entered and exited
   sleep, separating "machine never slept" from "hook did not fire".

**If the fresh timestamp does not appear**: mark this phase `[BLOCKED]`, do NOT mark the task
complete, and proceed to the Rollback/Contingency section's `powerManagement.resumeCommands`
alternative (which reuses nixpkgs's already-live `sleep-actions.service` rather than a
second `sleep.target`-pulled unit). Capture the journal output in the summary either way.

**Timing**: 0.5 hours (user, including a real sleep/wake cycle)

**Depends on**: 3

**Files to modify**: `/var/lib/battery-suspend-backstop/wake-mark` (written by the system under
test, not by the implementer — see Prohibited Evidence item 2)

**Verification**:
- All six expected-output conditions above hold, evidenced by user-pasted terminal output.
- The implementer's completion claim quotes the two concrete epoch values (`BASELINE_EPOCH` and
  the post-resume wake-mark epoch) and the arithmetic showing the second exceeds the first.
- A completion claim citing anything from the Prohibited Evidence list instead is invalid and this
  phase stays `[NOT STARTED]` or `[BLOCKED]`.

---

### Phase 5: Record verification evidence and close out [NOT STARTED]

**Goal**: The real verification output is durably recorded, and the related-but-out-of-scope
finding is flagged rather than silently dropped.

**Tasks**:
- [ ] Write `specs/124_fix_wake_mark_resume_hook_wiring/summaries/01_wake-mark-resume-rewiring-summary.md`
      containing the verbatim Phase 4 baseline and post-resume outputs (both epoch values, the
      journal excerpt, `ExecMainStatus`).
- [ ] State explicitly in the summary which mechanism was used (`sleep.target` dedicated unit, or
      the `powerManagement.resumeCommands` contingency if Phase 4 forced the fallback).
- [ ] Flag the follow-up: `disable-speaker-amp.service` in `modules/system/audio.nix` carries the
      same dead `post-resume.target` reference on its resume path; it fires at boot via
      `multi-user.target` only. Recommend a separate task; do not fix here.
- [ ] Commit with `task 124: complete implementation` (staging limited to `modules/system/power.nix`,
      the task directory, and `specs/state.json`/`specs/TODO.md`). Do not `git add -A`. Do not push
      and do not create a PR.

**Timing**: 0.25 hours

**Depends on**: 4

**Files to modify**:
- `specs/124_fix_wake_mark_resume_hook_wiring/summaries/01_wake-mark-resume-rewiring-summary.md` - new

**Verification**:
- Summary file exists, is non-empty, and contains two distinct epoch integers from the real cycle.
- The `disable-speaker-amp` follow-up is named in the summary.
- `git log -1` shows the scoped commit; `git status --short` shows no stray staged files.

---

## Testing & Validation

- [ ] `nix flake check` (or `nixos-rebuild build --flake .#hamsa`) exits 0 after the edit.
- [ ] Generated unit text contains `WantedBy=sleep.target`, `Before=sleep.target`,
      `StopWhenUnneeded=true`, `RemainAfterExit=true`, `ExecStop=`, and no `ExecStart=`.
- [ ] `grep -n "post-resume" modules/system/power.nix` yields no claim that
      `post-resume.target` is a working hook point.
- [ ] `sudo nixos-rebuild switch --flake .#hamsa` succeeds (user).
- [ ] **Gate**: a real `systemctl suspend` + physical wake produces a `wake-mark` epoch strictly
      greater than the pre-suspend baseline, with `ExecMainStatus=0` and a non-empty journal for
      the unit across the sleep boundary (user).
- [ ] `/var/lib/battery-suspend-backstop/notified` absent after resume.
- [ ] No verification claim rests on `.wants/` inspection, a self-writing harness, a manual
      `systemctl start`, `sleep-actions.service`, or a green build.

## Artifacts & Outputs

- `modules/system/power.nix` (modified: unit rewired, two comments corrected)
- `specs/124_fix_wake_mark_resume_hook_wiring/plans/01_wake-mark-resume-rewiring.md` (this file)
- `specs/124_fix_wake_mark_resume_hook_wiring/summaries/01_wake-mark-resume-rewiring-summary.md`
  (Phase 5, containing the real suspend/resume evidence)
- Follow-up recommendation for `modules/system/audio.nix` `disable-speaker-amp` resume path
  (recorded in the summary, not implemented)

## Rollback/Contingency

**Rollback**: the change is confined to one attribute set plus two comments in
`modules/system/power.nix`. `git checkout modules/system/power.nix` (only if the tree is otherwise
clean — see the destructive-git rule) or revert the commit, then
`sudo nixos-rebuild switch --flake .#hamsa`. Reverting restores the previous behavior exactly:
an inert wake-grace window, which the backstop script already fail-safes to "no grace", i.e. the
original unconditional suspend-at-10% protection. There is no data or state to migrate.

**Contingency if Phase 4 shows no fresh wake-mark**: switch to the research report's documented
alternative — delete the `battery-backstop-wake-mark` unit and instead set

```nix
powerManagement.resumeCommands = "${batteryBackstopWakeMark}";
```

in `modules/system/power.nix`, reusing nixpkgs's `sleep-actions.service`
(`wantedBy = [ "sleep.target" ]`, `before = [ "sleep.target" ]`,
`unitConfig.StopWhenUnneeded = true`, script in `preStop`), which is already generated and loaded
on this host because `powerManagement.enable = true`. No other module in this repo sets
`resumeCommands`, so there is no concatenation conflict. Cost: the dedicated unit name disappears
from `systemctl status`/journal filtering, and the cross-reference comment in
`battery-suspend-backstop`'s banner must be reworded. **Phase 4's live suspend/resume verification
applies unchanged to the contingency** — the verification target becomes
`journalctl -u sleep-actions.service`, but the wake-mark freshness check and every Prohibited
Evidence item remain in force.

**If the contingency also fails**: mark the task `[BLOCKED]` with the journal evidence, and do not
report the wake-grace window as functional under any circumstances.
