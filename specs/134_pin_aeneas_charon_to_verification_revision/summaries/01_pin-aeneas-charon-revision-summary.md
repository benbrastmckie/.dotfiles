# Implementation Summary: Task #134

**Completed**: 2026-09-18 (Phase 1 only; Phases 2-4 blocked)
**Duration**: ~25 minutes

## Overview

Pinned the `aeneas` flake input to the exact revision the Logos Verification toolchain
expects (`227f4e7ac70d687a6b1a4871b3304f5a1c6994bf`), re-locked only that input's
subtree, added `hacl.cachix.org` as a trusted substituter, and corrected the stale
"no public binary cache" comment in `flake.nix`. Phase 1 (all configuration and lock
changes) is complete and verified via evaluation and `nix flake check`. Phases 2-4
(activating the substituter system-wide, confirming binaries on PATH, and running
Verification's `check.sh` coherence gate) require `sudo nixos-rebuild switch`, which is
unavailable to this implementing agent, and are therefore `[BLOCKED]` pending the user
running the commands below.

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

## Plan Deviations

- **Phase 2** all tasks deferred to the user: `sudo -n true` was denied outright by the
  implementing agent's tool permission layer (not merely a missing password), matching
  the plan's documented risk mitigation ("If sudo is unavailable non-interactively,
  stop after committing the config and lock changes, mark the rebuild/verification
  phases [BLOCKED] with the exact commands for the user to run").
- **Phase 3** and **Phase 4**: all tasks blocked transitively on Phase 2 (binaries on
  PATH and the Verification coherence gate cannot be checked until the substituter is
  live and the pinned packages are actually installed via a rebuild).

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
- NixOS build (`nixos-rebuild switch`): **Not run** — requires sudo, unavailable to
  this agent. See "Commands for the user" below.
- PATH revision check (`aeneas -version` / `charon version`): **Not run** — depends on
  the rebuild above.
- Verification `check.sh` coherence stage: **Not run** — depends on the rebuild above.

## Commands for the User

Run from `~/.dotfiles`. Preview first (root is trusted, so `--option` values apply):

```bash
nixos-rebuild dry-build --flake .#hamsa \
  --option extra-substituters https://hacl.cachix.org \
  --option extra-trusted-public-keys hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=
```

Confirm charon/aeneas show "will be fetched", not "will be built" (a source build takes
hours). If the preview still shows "will be built", check the cache is still serving the
narinfo before proceeding:

```bash
curl -sI https://hacl.cachix.org/8psy457ay66wy4flknrfbh6ddzw9k93z.narinfo
```

Then switch (this activates the substituter and completes the pinned build in one
step, since `modules/system/nix.nix` now configures `hacl.cachix.org` permanently):

```bash
sudo nixos-rebuild switch --flake .#hamsa \
  --option extra-substituters https://hacl.cachix.org \
  --option extra-trusted-public-keys hacl.cachix.org-1:FzsZ2xsByOwKwIWNPII7yMOelJNDZ12mDAj3d1eGX0c=
```

Then verify (Phase 3):

```bash
hash -r
readlink -f "$(command -v charon)"
readlink -f "$(command -v aeneas)"
charon version   # parenthesized suffix should be a5591f6b94c8575a6ba2ae71090614a722f2b011
aeneas -version  # should be a prefix of 227f4e7ac70d687a6b1a4871b3304f5a1c6994bf
```

Then run Phase 4's Verification coherence gate:

```bash
cd ~/Projects/Logos/Verification
bash framed_channel/check.sh
```

Confirm the `== aeneas revision coherence ==` section prints only `[ok]` lines.

## Notes

- After the user completes the rebuild and confirms Phases 2-4, re-run
  `/implement 134` (or `/orchestrate 134 --implement`) to resume from Phase 2, verify,
  and close out the task — the plan and progress files already reflect Phase 1 as
  `[COMPLETED]` and phases 2-4 as `[BLOCKED]` with the exact commands recorded here and
  in `specs/134_pin_aeneas_charon_to_verification_revision/handoffs/phase-1-handoff-20260918T224900Z.md`.
- Rollback: `git revert` the Phase 1 commit (`7ca1985`) restores the floating URL, old
  lock, and no cache config, if needed.
