# Implementation Summary: Task #134

**Completed**: 2026-09-18
**Duration**: ~25 minutes (Phase 1) + user-run rebuild + ~10 minutes (Phases 2-4 verification)

## Overview

Pinned the `aeneas` flake input to the exact revision the Logos Verification toolchain
expects (`227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`), re-locked only that input's
subtree, added `hacl.cachix.org` as a trusted substituter, and corrected the stale
"no public binary cache" comment in `flake.nix`. All four phases are now complete: the
config/lock changes (Phase 1), the daemon-level substituter activation and rebuild via
`sudo nixos-rebuild switch` (Phase 2, run directly by the user), confirmation that
`charon`/`aeneas` on PATH report the pinned revisions (Phase 3), and a full pass of the
Logos Verification repo's `framed_channel/check.sh` aeneas revision coherence gate
(Phase 4).

## What Changed

- `flake.nix` — Pinned `aeneas.url` to
  `github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf` (was tracking the
  default branch); rewrote the input comment to explain the pin rationale and the
  hacl.cachix.org substituter.
- `flake.lock` — Re-locked only the `aeneas` input subtree (`aeneas`,
  `aeneas/charon`, `aeneas/charon/rust-overlay`); confirmed via `git diff` that no
  other input moved.
- `modules/system/nix.nix` — Added `substituters = [ "https://hacl.cachix.org" ]` and
  `trusted-public-keys = [ "hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=" ]`
  to the existing `nix.settings` block, with a short explanatory comment.

No files outside `flake.nix`, `flake.lock`, and `modules/system/nix.nix` were changed;
no file in `~/Projects/Logos/Verification` was modified (confirmed clean before and
after Phase 4's re-run).

## Decisions

- Used `nix flake update aeneas` to re-lock narrowly (current syntax, not
  `nix flake lock --update-input`); confirmed the diff touched only the aeneas
  subtree.
- Verified the pinned aeneas flake's own `charon` output path
  (`/nix/store/8psy457ay66wy4flknrfbh6ddzw9k93z-charon`) matches the research-verified
  store path exactly, confirming the charon revision (`a5591f6b94c8575a6ba2ae71090614a722f2b011`)
  is correct before any rebuild.
- Confirmed `nix.settings.substituters` list-merges (does not clobber) the default
  `cache.nixos.org` entry.
- The user ran `sudo nixos-rebuild switch --flake .#hamsa` directly (outside this
  agent's session, since sudo is unavailable to the implementing agent). A prior
  user-run dry-build as root showed both `charon` and `aeneas` "will be fetched"
  (109.7 MiB total), confirming the hacl.cachix.org substituter path rather than a
  multi-hour source build.

## Plan Deviations

- **Phase 2**: the rebuild itself (`sudo nixos-rebuild switch`) was run directly by
  the user, outside this agent's session, rather than by the implementing agent —
  `sudo -n true` is denied outright by the implementing agent's tool permission layer
  (not merely a missing password), matching the plan's documented risk mitigation. All
  verification steps for Phase 2 (substituter live in `/etc/nix/nix.conf`, both paths
  fetched not built) were independently re-confirmed by this dispatch.
- **Phase 3** and **Phase 4**: no deviations — all tasks executed and verified directly
  by this dispatch once Phase 2's rebuild had completed.

## Verification

- Flake evaluation: Success — `nix eval
  .#nixosConfigurations.hamsa.config.system.build.toplevel.drvPath` evaluates cleanly.
- `nix flake check`: Success — `all checks passed!` (only pre-existing, unrelated
  `boot.zfs.forceImportRoot` warnings on other hosts, out of scope).
- Substituter merge: Success — `nix eval --raw
  .#nixosConfigurations.hamsa.config.nix.settings.substituters` lists both
  `https://hacl.cachix.org` and `https://cache.nixos.org/`.
- Charon store path: Success — `nix eval --raw
  'github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf#packages.x86_64-linux.charon.outPath'`
  equals `/nix/store/8psy457ay66wy4flknrfbh6ddzw9k93z-charon` (the research-verified
  store path).
- Formatter check: Success — `nix fmt -- --check flake.nix modules/system/nix.nix`
  reports no diff.
- `/etc/nix/nix.conf` substituters/keys: Success —
  `substituters = https://hacl.cachix.org https://cache.nixos.org/` and
  `trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=`.
- PATH revision check: Success —
  `readlink -f "$(command -v charon)"` ->
  `/nix/store/8psy457ay66wy4flknrfbh6ddzw9k93z-charon/bin/charon`;
  `readlink -f "$(command -v aeneas)"` ->
  `/nix/store/64zn9jy24zngxqkyy0z5mrh4xcmk7w6l-ocaml5.2.1-aeneas-0.1.0/bin/aeneas`;
  `charon version` -> `0.1.263 (a5591f6b94c8575a6ba2ae71090614a722f2b011)`;
  `aeneas -version` -> `aeneas 227f4e7`.
- Verification `check.sh` coherence stage: Success — `bash framed_channel/check.sh`
  from `~/Projects/Logos/Verification` printed `check.sh: PASS`, with all four
  `== aeneas revision coherence ==` lines `[ok]`:
  - `[ok] toolchains agree (leanprover/lean4:v4.31.0; core, bridge and the fetched Aeneas library)`
  - `[ok] flake.lock and aeneas/lake-manifest.json both pin aeneas 227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`
  - `[ok] aeneas on PATH is 227f4e7 (a prefix of the pinned revision)`
  - `[ok] charon on PATH matches Aeneas's charon-pin (a5591f6)`

  Every other stage in the run (extraction staleness, layer import rule, license
  headers, core/bridge package builds, registry statement hashes, specification
  consistency, selection consistency, differential vectors, axiom audit, proof ladder,
  manifest cross-check, independent recheck, `cargo fmt`/`clippy`/`test`, certificate
  identity, approvals) also reported `[ok]`/passed, run from the rebuilt system PATH
  with no scratch/alternate Nix store. `git status --short` in the Verification repo
  was empty both before and after the run — no file there was modified.

## Notes

- Rollback: `git revert` the Phase 1 commit (`7ca1985`) restores the floating URL, old
  lock, and no cache config, if needed. System rollback:
  `sudo nixos-rebuild switch --rollback` (or select the previous generation at boot)
  returns to the prior aeneas/charon and nix.conf, if ever needed.
