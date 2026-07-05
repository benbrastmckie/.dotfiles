# Implementation Summary: Task #69

**Completed**: 2026-07-05
**Duration**: ~25 minutes (eval/build wait dominated)

## Overview

Unified the `lectic` `extraSpecialArgs` resolution across both home-manager evaluation paths.
The NixOS-integrated path (`lib/mkHost.nix`, and the inline `iso` config in `flake.nix` via
`hmExtraSpecialArgs`) previously passed the raw, unbuilt `lectic` flake input straight into
`home.packages`, silently installing an inert reference with no `bin/lectic`. This was the same
defect class as the `lectic` regression task 66 phase 9 fixed for the standalone path only. Task
86 had documented this asymmetry as "intentional divergence, not a bug" without actually fixing
it. This task applies the standalone path's existing resolution expression to both raw-lectic
sites, corrects the inaccurate documentation, and verifies via `nix eval`, `nix flake check`, and
representative builds.

## What Changed

- `lib/mkHost.nix` — `home-manager.extraSpecialArgs.lectic` changed from `inherit lectic;` (raw
  flake input) to `lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default
  or lectic;` (resolved built package), matching the expression already used 8 lines below in the
  same file's top-level `specialArgs`.
- `flake.nix` — `hmExtraSpecialArgs.lectic` given the same resolution fix, which flows through to
  the `iso` NixOS config's home-manager path (consumed raw at `hmExtraSpecialArgs` reference).
  Also removed the now-redundant standalone `// { lectic = ...; }` override in
  `homeConfigurations.benjamin` (both paths now share the resolved value via
  `hmExtraSpecialArgs`), replacing the stale "do not unify these" comment with one explaining the
  override is no longer needed.
- `docs/dual-home-manager.md` — rewrote the "extraSpecialArgs divergence (intentional)" bullet to
  describe the now-unified state, name the resolution expression by name (not brittle line
  numbers), and explain this was a real asymmetry (task-66-phase-9 regression class), not an
  intentional design choice.

## Decisions

- Removed rather than kept-with-updated-comment the standalone `lectic` override block in
  `flake.nix` (smaller diff, per the plan's explicit choice), since `hmExtraSpecialArgs` now
  already carries the resolved value for both paths.
- Left `specs/state.json` / `specs/TODO.md` out of this commit's staging (see Plan Deviations)
  because they currently carry unrelated in-flight edits from other concurrent tasks (86, 88, 89,
  93); bundling them would pull unrelated work into this task's commit.

## Plan Deviations

- **Phase 4 staging** altered: excluded `specs/state.json` and `specs/TODO.md` from `git add`
  (plan listed them) because both files currently contain unrelated, uncommitted modifications
  from other concurrently in-flight tasks. State/TODO updates for task 69's own status are
  deferred to the invoking skill's postflight step, which owns state.json writes per the
  nix-implementation-agent's documented division of responsibility. No other deviations —
  implementation otherwise followed the plan exactly (identical resolution expression at both
  raw-lectic sites, doc correction, full verification).

## Verification

- Baseline (Phase 1): `nandi`/`hamsa`/`garuda`/`iso` each showed exactly one `NO-NAME` entry in
  `home.packages` (raw `lectic` input); standalone already showed `lectic-0.0.0`.
- Post-fix (Phase 4): `nandi`/`hamsa`/`garuda`/`iso` and standalone all show `lectic-0.0.0` in
  `home.packages` — zero `NO-NAME` entries remain.
- `nix flake check`: green both before and after the edits.
- `nix build .#nixosConfigurations.nandi.config.system.build.toplevel`: succeeded
  (`/nix/store/n3zqk0yqwg838lxvfw5jqxml2vrm679r-nixos-system-nandi-26.05.20260622.3426825`),
  rebuilding the home-manager generation with the real `lectic` package linked.
- `nix build .#homeConfigurations.benjamin.activationPackage`: succeeded
  (`/nix/store/fx21pk2pqqiqk46ai9ig2wvmjrdlk2hd-home-manager-generation`).

## Notes

- **Closure growth is intentional**: NixOS-integrated profiles (`nandi`, `hamsa`, `garuda`,
  `usb-installer`, `iso`) now link the real `lectic` package (~280 MiB including its
  `node_modules`) where previously nothing usable was linked (the raw flake-input attrset
  contributed only its `outPath`, unused at runtime). This is the correctness fix's expected and
  desired effect, not a regression.
- `usb-installer` uses `mkHost` and therefore picks up the same `lib/mkHost.nix` fix
  automatically; it was not separately eval-checked here as it is a rarely-built target, but the
  fix is structurally identical to `nandi`/`hamsa`/`garuda`.
- Non-goals honored: no changes to `hosts/nandi/default.nix`, `modules/*/default.nix`,
  `useGlobalPkgs`, `useUserPackages`, `pkgs-unstable`, or `nix-ai-tools` wiring. `flake.nix` is
  left in a clean, committed state for task 87's planned `iso`-block extraction.
