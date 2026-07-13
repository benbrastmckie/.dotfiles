# Implementation Summary: Task #106

**Completed**: 2026-07-11
**Duration**: ~35 minutes

## Overview

Implemented the root-cause fix for hamsa's recurring mt7925e WiFi kernel panics identified in
the task-106 research report: bumped the `nixpkgs` flake input to pull kernel 7.1.3 (which
contains the merged upstream fix, mainline commit `20b126920a25`, for the `sta_poll_list`
corruption race in `mt76_wcid_add_poll`), and added `kernel.panic_on_oops = 1` to close the
diagnostics gap so any future panic actually gets captured. The abort gate passed (kernel
resolved to 7.1.3, not 7.1.2), so the conditional `boot.kernelPatches` fallback (Phase 6) was
not needed. The configuration was built and verified but NOT switched/activated — that step
requires the user (sudo).

## What Changed

- `flake.lock` — `nixpkgs` input (root node `nixpkgs_2`) bumped from
  `a50de1b7d8a586adc18d2395c19de7d6058e6030` (2026-07-04, kernel 7.1.2) to
  `8f0500b9660505dc3cb647775fe9a978a74b5283` (2026-07-10, kernel 7.1.3), via
  `nix flake update nixpkgs`. `nixpkgs-unstable` (task-104 r-V8 pin,
  `567a49d1913ce81ac6e9582e3553dd90a955875f`) was NOT touched — confirmed by a node-scan of
  `git diff flake.lock`, which shows only `nixpkgs_2` changed.
- `modules/system/boot.nix` — added `kernel.sysctl."kernel.panic_on_oops" = 1;` inside the
  `boot = { ... }` block, with an explanatory comment referencing task 104/106 and the
  empty-pstore diagnostics finding. The existing `"panic=10"` entry in `kernelParams` and the
  `extraModprobeConfig` (`mt7925e disable_aspm=1 power_save=0`) were left unchanged.

## Decisions

- Followed the plan's abort-gate design exactly: ran `nix flake update nixpkgs`, then gated on
  `nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version` printing
  `"7.1.3"` before proceeding to build. It printed `"7.1.3"` on the first try, so Phase 6 (the
  `boot.kernelPatches` cherry-pick fallback, which would force a full local kernel rebuild) was
  not triggered and remains purely documented in the plan as a fallback.
- Did not run `sudo nixos-rebuild switch --flake .#hamsa` or reboot the machine. This is an
  explicit plan Non-Goal ("Running `sudo nixos-rebuild switch` autonomously") and a named risk
  mitigation ("Activation run without user consent... Plan flags switch as user-confirmed,
  implementer builds + stages only"). This holds even under `/orchestrate` autonomous mode,
  since it is a hard safety boundary set by the plan itself, not a normal confirmation gate.

## Plan Deviations

- **Phase 1, nixpkgs-pin task** altered: the plan's literal jq command
  (`jq '.nodes.nixpkgs.locked | ...'`) actually addresses an unrelated transitive dedup node in
  `flake.lock`, not the root flake's `nixpkgs` input (the root input resolves through node
  `nixpkgs_2`, per `.nodes.root.inputs.nixpkgs`). Re-ran with the corrected node name; the
  corrected value (`a50de1b7d8a586adc18d2395c19de7d6058e6030`, 2026-07-04) matches the research
  report's cited pin, confirming Phase 1's snapshot is now accurate.
- **Phase 1, pstore check** altered: `ls -la /sys/fs/pstore/` returned `Permission denied` for
  the unprivileged implementer session rather than an empty listing. This is a non-blocking,
  read-only diagnostics check (not a build input); the report already established via a
  root-verified check that `/sys/fs/pstore` was empty, so this doesn't affect the fix.
- **Phase 2 and Phase 3 commits were bundled** into a single git commit
  (`task 106 phase 2: update nixpkgs input & confirm kernel >= 7.1.3`) covering both
  `flake.lock` and `modules/system/boot.nix`, rather than two separate per-phase commits. Both
  phases are in the same dependency wave (both blocked only by Phase 1, both feeding Phase 4)
  and their combined verification (Phase 4's build) is what actually proves them out, so this is
  a minor process deviation with no functional impact.
- **Phase 5 (activation) is PARTIAL, not COMPLETED**: the "flag for the user" task is done (this
  summary + the plan's Phase 5 annotations constitute the flag); the three post-switch/reboot
  verification tasks are deferred to the user, since they require the user-run switch to have
  already happened. See "User Action Required" below.
- **Phase 6 (conditional fallback) was SKIPPED**, as designed — the Phase 2 abort gate passed on
  the first attempt (kernel resolved to 7.1.3), so the `boot.kernelPatches` route was never
  needed.
- **Phase 7 (monitoring & close-out)** is documentation-only and was completed even though its
  plan-declared dependency (Phase 5) is not yet fully complete — the monitoring/escalation
  guidance below is written for the user to apply once they do switch and reboot.

## Verification

- `nix flake check`: **Success** — all 5 `nixosConfigurations` (`nandi`, `hamsa`, `garuda`,
  `iso`, `usb-installer`), `formatter`, and `devShells` evaluated cleanly. Two pre-existing,
  unrelated `boot.zfs.forceImportRoot` evaluation warnings on `iso`/`usb-installer` (not
  introduced by this change).
- `nix eval .#nixosConfigurations.hamsa.config.boot.kernelPackages.kernel.version`: **`"7.1.3"`**
  (both pre-build and post-build).
- `nixos-rebuild build --flake .#hamsa`: **Success** — result
  `/nix/store/07kkg07pmk27zmhiqjd9r3fa68d8v7ap-nixos-system-hamsa-26.05.20260710.8f0500b`.
- Binary-cache confirmation: `nix log` on the kernel derivation
  (`/nix/store/xqcadhgv9qij93jwnm5jzcqrvcqk9f47-linux-7.1.3.drv`) reports "build log ... is not
  available", confirming the kernel itself was substituted from the Hydra binary cache, not
  compiled locally (only `linux-7.1.3-modules`/`initrd-linux-7.1.3` module-packaging/initrd-assembly
  derivations were built, which is expected and cheap).
- `git diff flake.lock`: **Only the `nixpkgs_2` node changed** — `nixpkgs-unstable` pin intact.
- `modules/system/boot.nix`: retains `"panic=10"` in `kernelParams`; adds
  `kernel.sysctl."kernel.panic_on_oops" = 1;`. `nix fmt modules/system/boot.nix` produced no
  further diff.
- NixOS build/activation: **NOT performed** (by design — user-confirmed step, see below).

## User Action Required

The build is verified but not activated. To complete the fix on hamsa:

```bash
sudo nixos-rebuild switch --flake .#hamsa
# then reboot into the new kernel
```

After rebooting, verify:

```bash
uname -r                              # expect >= 7.1.3
cat /proc/sys/kernel/panic            # expect 10
cat /proc/sys/kernel/panic_on_oops    # expect 1
```

## Monitoring & Escalation

**Success criteria** (per the research report): 2+ weeks running on kernel >= 7.1.3 with:
- (a) no journal-truncation freezes (hard panics show as an abrupt journal cutoff),
- (b) no new entries under `/var/lib/systemd/pstore/`,
- (c) no `WARN … mt76_sta_add` lines in the kernel log (the fix's `WARN_ON_ONCE(published)` path
  would indicate an index-collision variant of the race that the fix doesn't fully close).

**Check commands**:
```bash
journalctl --list-boots                    # look for unexpected/short boot spans (crash+reboot)
ls /var/lib/systemd/pstore/                 # any new dirs = a captured crash occurred
journalctl -k | grep -i mt76_sta_add        # residual-race WARN, if the fix is incomplete
```

**Housekeeping (not done in this task)**: retain the one Jun-29 pstore dump for upstream hygiene
(replying to the fix's lore thread or the zbowling/mt7925 tracker per report Rec. 5); prune the
rest of `/var/lib/systemd/pstore/` and `~/pstore-copy/` only after that.

**Terminal fallback**: if the identical trace recurs on kernel >= 7.1.3 WITH pstore capture now
working (confirming it's a genuinely different or incompletely-fixed bug, not a capture-gap
artifact), escalate to a hardware swap — Intel AX210 (non-vPro, `iwlwifi`) or Qualcomm QCNCM865
(`ath12k`) — per Framework community thread 72699 / 78181 (report §5). Not needed now; the
released upstream fix is expected to resolve this.

## Notes

- No option conflicts encountered. `deadnix: skip` pragma at the top of `boot.nix` preserved
  unchanged.
- `boot.kernelPatches` fallback snippet (hash `sha256-gn0aq/7ruSlBobDribGiSKwh3wJqHhV0aKHb7yYOXxY=`)
  remains documented in the plan (Phase 6) as a ready, verified-viable fallback if a future
  channel regression blocks the nixpkgs-bump route on some other host/date, but was not applied
  here.
