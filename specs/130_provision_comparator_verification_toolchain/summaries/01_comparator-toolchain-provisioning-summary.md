# Implementation Summary: Provision the Comparator Lean proof-verification toolchain

- **Task**: 130 - Provision the Comparator Lean proof-verification toolchain (landrun, lean4export, comparator)
- **Status**: [PARTIAL]
- **Completed**: 2026-09-07
- **Duration**: ~4.5 hours
- **Artifacts**: plans/01_comparator-toolchain-provisioning.md

## Overview

All 8 plan phases were executed. `landrun` (pinned `v0.1.17`), a deterministic Lean
`v4.34.0-rc2` toolchain acquisition, a real pinned `comparator` derivation, and a
toolchain-keyed `comparator-lean4export-resolve` resolver were built and behaviorally verified —
including Comparator accepting a matching Challenge/Solution fixture and rejecting a mismatching
one, both under the README's `systemd-run` sandbox-escape wrapper. One item (automatic
`COMPARATOR_LANDRUN` session-variable sourcing into a plain login shell) remains open because it
requires `sudo nixos-rebuild switch`, which this agent session cannot run — this is an
environment/permission boundary, not a packaging defect, and is the reason for the `[PARTIAL]`
status rather than a claim of full completion.

## What Changed

- `packages/landrun.nix` — new; pinned `v0.1.17` `buildGoModule` derivation (rejects nixpkgs'
  `0.1.15` on recursive-ELF-`ldd` evidence)
- `packages/lean-toolchain-bin.nix` — new; deterministic Lean `v4.34.0-rc2` acquisition (FOD
  fetch of the official release tarball + offline `autoPatchelfHook` unpack)
- `packages/comparator.nix` — new; real pinned `comparator` derivation (offline `path`-style
  `lean4export` vendoring, no FOD fallback needed)
- `packages/lean4export.nix` — new; defines `comparator-lean4export-resolve`, a toolchain-keyed
  resolver script (not a fixed binary)
- `overlays/unstable-packages.nix` — `callPackage` wiring for all four packages
- `flake.nix` — resolved the previously-unused `lean4` input with an explanatory comment
  (comment-and-keep, not pin-and-use)
- `modules/home/packages/dev-tools.nix` — added the three packages to `home.packages`;
  set `home.sessionVariables.COMPARATOR_LANDRUN`; documented the deliberate
  `COMPARATOR_LEAN4EXPORT`/`COMPARATOR_NANODA` omissions in place
- `packages/README.md` — new "Comparator Lean Proof-Verification Toolchain" section with four
  package entries and six decision records (five task-mandated plus the
  elan-wrapper-script-vs-landrun finding discovered during verification)

## Decisions

- **landrun**: pinned tag `v0.1.17` (commit `62823c05e58ec22c1f91b4c8468318c1f97f2d32`), not
  nixpkgs' `0.1.15` — recursive vs. shallow `--ldd` ELF resolution sits directly in the flag
  combination Comparator hardcodes. This host's Landlock ABI probes at 9, matching `v0.1.17`'s
  ceiling exactly.
- **lean4export**: one system-wide binary is structurally wrong (binary format is tied to the
  Lean version that produced the `.olean` files it reads); resolution is hoisted into a
  standalone resolver (`comparator-lean4export-resolve`) since Comparator's own sandboxed call
  has no writable paths or network. Cache keyed by the target's exact `lean-toolchain` string,
  with a sidecar recording what was actually built, for caller-side mismatch detection.
- **comparator**: a real, pinned Nix derivation, not a `loogle.nix`-style silent-rebuild wrapper
  — trust semantics of a checker whose provenance must be auditable, and a Mathlib-free
  dependency footprint that makes this tractable unlike loogle's case. Offline vendoring of
  `lean4export` via a `path`-style Lake require worked cleanly (verified under `unshare -rn`); no
  network-permitted FOD fallback was needed for the whole build.
- **nanoda**: deferred explicitly (not silently omitted) — not required for these acceptance
  criteria; leaving `COMPARATOR_NANODA` unset makes `enable_nanoda: true` fail loudly rather than
  silently skip.
- **systemd-run wrapper**: retained for portability even though this host (kernel `7.1.3`) is
  past the landrun sandbox-escape fix Comparator's README describes as landing in Linux 7.1 —
  both fixture runs were performed under it and confirmed compatible.
- **Load-bearing discovery**: elan-installed Lean toolchains ship `bin/lake` as a bash-shebang
  wrapper script (LEAN_CC injection), which landrun's ELF-only `--ldd` dependency detection
  cannot see through — the kernel's nested exec of the wrapper's bash interpreter is denied by
  Landlock (`permission denied`, no verdict). Using `lean-toolchain-bin` (raw ELF via
  `autoPatchelfHook`) instead of elan's own toolchain on `PATH` resolved this. Documented in
  `packages/README.md` as an operational requirement for any `comparator` caller on this host
  when the checked project targets `v4.34.0-rc2`.

## Verification

- `nix flake check`: Success (all NixOS configurations, `homeConfigurations`, `formatter`,
  `devShells` evaluate cleanly)
- `nixos-rebuild build --flake .#hamsa`: Success (31 derivations, full system closure including
  the home-manager-integrated session variables)
- `home-manager build --flake .#benjamin`: Success
- `home-manager switch --flake .#benjamin`: Success — put `landrun`, `comparator`,
  `comparator-lean4export-resolve` on `PATH` immediately
- `landrun --version` (real login shell): `landrun version 0.1.17`
- `landrun --help`: lists `--ldd` and `--add-exec`
- `comparator --help` (real execution): no true `--help` flag exists upstream; produces its real,
  deterministic "no such file or directory" error (exit 1) since it treats any argument as a
  config-file path — documented honestly rather than claimed as conventional usage text
- `comparator-lean4export-resolve --help`: full contract documentation printed
- `"$(comparator-lean4export-resolve <project>)" --help`: real lean4export metadata JSON,
  reporting `"version":"4.34.0-rc2"` (lean4export similarly has no true `--help` flag)
- Resolver mismatch detection: hand-tampered a sidecar file, confirmed the resolver refuses
  (exit 1) rather than returning a possibly-mismatched cached binary; restored afterward
- Resolver failure path: a deliberately-nonexistent Lean release exits 1 with the real
  `lake`/elan error on stderr and empty stdout
- **Accept fixture** (`tests/projects/simple_match`, under the `systemd-run` wrapper): full
  build + export + kernel-replay pipeline completed; final line `"Your solution is okay!"`;
  exit 0 — matches `test.json`'s `exit_code: 0`
- **Reject fixture** (`tests/projects/simple_mismatch`, under the `systemd-run` wrapper): full
  build + export pipeline completed; final line `"uncaught exception: Challenge and solution
  constant kind don't match: 'comm'"`; exit 1 — matches `test.json`'s `exit_code: 1`, and the
  rejection is content-based (names the actual mismatch), clearly distinguishable from a tooling
  or sandbox-setup failure
- `echo "$COMPARATOR_LANDRUN"` from a plain login shell: **does not** print a value in this
  agent session (see Notes/blocker below) — the underlying value is confirmed correct via
  `nix eval` and via the standalone `home-manager switch`'s own `hm-session-vars.sh`

## Notes

**Blocker (environment/permission, not a packaging defect) — Phase 6, partial**: this host's
shell startup chain (`/etc/profile` → the NixOS-generated `set-environment`) is the *only*
mechanism that auto-sources `home.sessionVariables` into a plain login shell; neither
`/etc/bashrc`, `~/.profile`, nor `~/.bashrc` source the standalone home-manager path's
`~/.nix-profile/etc/profile.d/hm-session-vars.sh`. Activating the NixOS-integrated generation
requires `sudo nixos-rebuild switch --flake .#hamsa`, and this agent session's permission system
categorically denies `sudo` (`sudo -n true` → "Permission ... has been denied" from the harness
itself). **Required follow-up for the user**: run `sudo nixos-rebuild switch --flake .#hamsa` (or
this repo's `./scripts/update.sh` if it wraps both home-manager paths) to make
`COMPARATOR_LANDRUN` auto-available in new login shells. Everything else — the four packages, the
overlay wiring, the fixture-level accept/reject verdicts, and the `comparator-lean4export-resolve`
mismatch/failure handling — is complete and independently verified without needing that step.

**Fixture verification environment note**: Comparator's own hardcoded landrun sandbox args
(`--best-effort --ro / --rw /dev --ldd --add-exec`) interact badly with `elan`'s
toolchain-wrapper-script convention (see Decisions above); Phase 7's fixture runs used
`packages/lean-toolchain-bin.nix`'s output on `PATH` (ahead of `elan`) to avoid this. This is
recorded in `packages/README.md` as a required operational note for downstream callers, since it
is not specific to this verification session — any caller checking a `v4.34.0-rc2` project on
this host would hit the same issue with a bare `elan` toolchain on `PATH`.

## References

- `specs/130_provision_comparator_verification_toolchain/plans/01_comparator-toolchain-provisioning.md`
- `specs/130_provision_comparator_verification_toolchain/reports/01_comparator-toolchain-provisioning.md`
- `specs/130_provision_comparator_verification_toolchain/handoffs/phase-{1..8}-handoff-*.md`
- `packages/README.md` (Comparator Lean Proof-Verification Toolchain section)
