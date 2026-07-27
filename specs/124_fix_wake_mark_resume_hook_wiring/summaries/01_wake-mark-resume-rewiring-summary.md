# Implementation Summary: Task #124

**Status**: Partial -- Phases 1-2 complete (autonomous), Phases 3-5 pending user action
**Completed (this dispatch)**: 2026-07-27
**Duration**: ~20 minutes

## Overview

`battery-backstop-wake-mark.service` in `modules/system/power.nix` was rewired from the
non-existent `post-resume.target` to the live `sleep.target` mechanism, with the wake-mark
script moved from `ExecStart` to `ExecStop` so it runs after resume. The two in-file comments
that previously cited the disproven `post-resume.target` / `.wants/`-symlink precedent were
rewritten to state plainly that `post-resume.target` does not exist on this host and that a
populated `.wants/` directory is not evidence of wiring. The change evaluates and builds cleanly,
and the generated unit text matches the intended shape exactly. **This is not yet proof the fix
works** -- per the plan's binding Prohibited Evidence section, only a real suspend/resume cycle
counts, and that step requires the user.

## What Changed

- `modules/system/power.nix`:
  - `battery-backstop-wake-mark` systemd service: `wantedBy = [ "post-resume.target" ]` ->
    `wantedBy = [ "sleep.target" ]`, added `before = [ "sleep.target" ]`, added
    `unitConfig.StopWhenUnneeded = true`, added `serviceConfig.RemainAfterExit = true`, and
    `serviceConfig.ExecStart = batteryBackstopWakeMark` -> `serviceConfig.ExecStop =
    batteryBackstopWakeMark` (`ExecStart` omitted entirely, not stubbed).
  - Unit banner comment (~lines 329-346): rewritten to explain `post-resume.target` is
    `LoadState=not-found` on this host, that a populated `.wants/` directory is not evidence of
    wiring, and to ground the `sleep.target` choice in `man systemd.special` and nixpkgs's own
    already-live `sleep-actions.service`.
  - Script comment inside `batteryBackstopWakeMark` (~line 35): rewritten to say the script runs
    as the `sleep.target` hook's `ExecStop` after every resume, rather than the disproven
    "post-resume.target hook" phrasing.
  - No other files modified. `batteryBackstopScript`, the timer, the threshold/grace parameters,
    and `modules/system/audio.nix` were left untouched, per the plan's non-goals.

## Decisions

- Followed the plan's primary recommendation verbatim (the `sleep.target`-hooked dedicated unit),
  rather than the `powerManagement.resumeCommands` contingency, to preserve the
  `battery-backstop-wake-mark` unit name used by `systemctl status`/journal filtering and the
  cross-reference comment in the sibling `battery-suspend-backstop` unit's banner.

## Plan Deviations

- None (implementation followed the plan exactly for Phases 1-2).

## Verification

- **Phase 1** (`git diff modules/system/power.nix`): confirmed the diff is exactly the unit
  rewiring plus the two comment rewrites, nothing else. `grep -n "post-resume"
  modules/system/power.nix` returns only lines that explicitly describe `post-resume.target` as
  not-found/disproven. No new files created.
- **Phase 2** (eval/build shape gate -- explicitly NOT wiring proof):
  - `nix flake check`: exit 0, `all checks passed!` (all `nixosConfigurations`, `homeConfigurations`,
    `formatter`, `devShells` outputs evaluated successfully).
  - `nixos-rebuild build --flake .#hamsa`: exit 0, `Done. The new configuration is
    /nix/store/sg9gshigzqkcd5g3xg1dwvhq2cs8lx2b-nixos-system-hamsa-26.05.20260710.8f0500b`.
  - Generated unit text (`./result/etc/systemd/system/battery-backstop-wake-mark.service`)
    matches the expected shape exactly: `Before=sleep.target`, `StopWhenUnneeded=true`,
    `Type=oneshot`, `RemainAfterExit=true`,
    `ExecStop=/nix/store/pi2wc9n4xldvkgrrba69dmjisnxh969g-battery-backstop-wake-mark`,
    `WantedBy=sleep.target` under `[Install]`. No `ExecStart=` line. No `post-resume` string
    anywhere in the generated unit.
  - Full command output and the required Prohibited-Evidence disclaimer are recorded verbatim in
    the plan file's Phase 2 "Phase Notes" subsection.
- **Phases 3-4: NOT performed by this agent, and NOT claimed as verified.** These are marked
  `[NOT STARTED]` in the plan and require the user:
  - Phase 3: `sudo nixos-rebuild switch --flake .#hamsa` (activates the new generation), plus
    three read-only `systemctl show`/`systemctl cat` checks confirming the unit and `sleep.target`
    are `LoadState=loaded` in the running system.
  - Phase 4 (hard gate, the only acceptable proof): a real `systemctl suspend` followed by a
    physical wake, with baseline and post-resume `wake-mark` epoch timestamps, journal output for
    `battery-backstop-wake-mark.service` bracketing the sleep, `ExecMainStatus=0`, and
    `journalctl -b -u systemd-suspend.service` confirming the machine actually slept. Exact
    commands and expected output are in the plan's Phase 4 section.
- No claim in this summary rests on `.wants/` inspection, a self-writing test harness, a manual
  `systemctl start`, citation of `sleep-actions.service`/the man page, or the green build above --
  consistent with the plan's Prohibited Evidence section.

## Handoff to User

To complete this task:

1. Run Phase 3's commands (verbatim in the plan) and paste the four outputs back to the
   agent/session.
2. Run Phase 4's commands (verbatim in the plan): record the pre-suspend baseline, run
   `systemctl suspend`, wait for a real sleep and physical wake, then run the post-resume checks
   and paste all outputs back.
3. Once Phase 4 shows a fresh `wake-mark` epoch strictly greater than the baseline (with
   `ExecMainStatus=0` and non-empty bracketing journal output), a follow-up implementation pass
   completes Phase 5: records the verbatim evidence in this summary, flags the
   `disable-speaker-amp` follow-up (see below), and commits with `task 124: complete
   implementation`.
4. If Phase 4 shows no fresh wake-mark, the plan's Rollback/Contingency section documents the
   `powerManagement.resumeCommands` fallback (reusing nixpkgs's `sleep-actions.service`).

## Notes

- **Follow-up (out of scope for this task)**: `disable-speaker-amp.service` in
  `modules/system/audio.nix` carries the identical dead `post-resume.target` reference on its
  resume path; it currently fires at boot via `multi-user.target` only, not on resume. A separate
  task should fix this using the same `sleep.target` idiom applied here.
- No commit has been made for `modules/system/power.nix` yet -- per the plan, Phase 5 (which
  depends on the still-unverified Phase 4) is the designated commit-and-close-out point. This
  dispatch's changes remain uncommitted in the working tree pending user verification, or are
  committed separately by the orchestrator as an intermediate checkpoint; either way, the task
  must not be marked `[COMPLETED]` until Phase 4's real suspend/resume evidence is obtained.
