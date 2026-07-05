# Implementation Summary: Task #87

**Completed**: 2026-07-05
**Duration**: ~40 minutes

## Overview

Task 87 performed hosts/ structural cleanup: the required rewrite of `hosts/README.md`'s
obsolete inline-`nixosSystem` example to document the current `mkHost` factory pattern (Phase 2),
plus the optional extraction of the inline ISO module from `flake.nix` into
`hosts/iso/default.nix` for symmetry with `hosts/usb-installer/default.nix` (Phase 3). Both
required and optional phases were completed; the task closes with the full 3-phase plan done.

## What Changed

- `hosts/README.md` — rewrote the `## Usage` code block to document the `mkHost` factory
  (simple one-liner form + richer `usb-installer` form with `extraModules`/`extraSpecialArgs`);
  refreshed the `## Structure` section to note optional per-host `default.nix`/`README.md`
  files; added `iso` to the "Hosts" list and "Available hosts" line (Phase 3).
- `hosts/iso/default.nix` — NEW. Extracted ISO-specific module body (isoImage settings,
  networking, systemPackages) from `flake.nix`'s inline anonymous module.
- `flake.nix` — replaced the inline ISO module function in the `iso` config's `modules` list
  with `./hosts/iso/default.nix`; added `inherit system;` to the `iso` block's `specialArgs` so
  the extracted module can consume `system` as a module argument.

## Decisions

- **Baseline drvPath capture required a workaround**: plain
  `nix eval --raw .#nixosConfigurations.iso.config.system.build.toplevel.drvPath` fails with
  "Refusing to evaluate package 'zfs-kernel-...' ... broken" because forcing `.drvPath` strictly
  evaluates the derivation (unlike `nix flake check`, which does not). This is task 68's
  pre-existing broken zfs-kernel state, explicitly out of scope. Worked around read-only via
  `NIXPKGS_ALLOW_BROKEN=1 nix eval --impure --raw ...` — an ephemeral env var for the eval
  invocation only; no tracked file was touched to work around it.
- **The plan's suggested `pkgs.system` fix is wrong — used `specialArgs` instead**: the plan
  called for replacing the closure-captured `system` with `pkgs.system` inside the extracted
  module. Testing showed this causes `error: infinite recursion encountered` (`lib/types.nix:892`)
  because the `pkgs` module argument is itself constructed from `config.nixpkgs.hostPlatform` —
  assigning `nixpkgs.hostPlatform = pkgs.system;` is a circular fixpoint. Fixed instead by adding
  `inherit system;` to the `iso` block's `specialArgs` in `flake.nix`, and changing the extracted
  module's signature to `{ pkgs, lib, system, ... }:` with `nixpkgs.hostPlatform = system;`. This
  still resolves the original "undefined variable `system`" problem (the module no longer relies
  on lexical closure over flake.nix's outer `let system = ...`) without introducing recursion.
- Equivalence was proven via identical `drvPath` before/after
  (`/nix/store/3vnp20n5d5w97da6kxgkz00d56li2cpn-nixos-system-nixos-iso-26.05.20260622.3426825.drv`),
  confirming the extraction is byte-for-byte equivalent to the original inline config.

## Plan Deviations

- **Task 1 (Phase 1)** altered: `nix eval --raw ...drvPath` fails on plain invocation due to
  task 68's pre-existing broken zfs-kernel package; worked around with
  `NIXPKGS_ALLOW_BROKEN=1 nix eval --impure --raw ...` (read-only, no tracked file changed).
- **Task 1 (Phase 3)** altered: the plan's `pkgs.system` fix causes infinite recursion; used
  `system` via `specialArgs` instead (see Decisions above).
- **Task 2 (Phase 3)** altered: added `inherit system;` to the `iso` block's `specialArgs` in
  `flake.nix` (a one-line additive change) to support the `specialArgs`-based fix, in addition
  to the planned module-list simplification.

## Verification

- Flake check: Success — `nix flake check --no-build` prints "all checks passed!" with exactly
  the two pre-existing `boot.zfs.forceImportRoot` warnings on `iso`/`usb-installer`, identical
  to the Phase 1 baseline, after both Phase 2 and Phase 3 changes.
- `nix flake show`: Success — all five `nixosConfigurations` (`garuda`, `hamsa`, `iso`, `nandi`,
  `usb-installer`) plus `homeConfigurations` evaluate and are listed.
- `iso` `drvPath` equivalence: IDENTICAL before and after Phase 3
  (`/nix/store/3vnp20n5d5w97da6kxgkz00d56li2cpn-nixos-system-nixos-iso-26.05.20260622.3426825.drv`).
- No ISO/usb-installer builds were run (excluded from the build-diff harness per task 68
  lineage); `lib/mkHost.nix` internals and task 68's zfs-kernel state were not touched.
- Git staging was scoped per phase (`git add hosts/README.md`, then
  `git add hosts/iso/default.nix flake.nix hosts/README.md`, then the plan file) — never
  `git add -A`. `git diff --staged --stat` was reviewed before each commit.

## Notes

Both the required Phase 2 doc rewrite and the optional Phase 3 ISO extraction were completed.
The `pkgs.system` vs. `specialArgs`-provided `system` discovery is worth remembering for any
future closure-breaking extraction involving `nixpkgs.hostPlatform`: `pkgs` is downstream of
`config.nixpkgs.hostPlatform`, so referencing `pkgs.system` to set that same option is circular.
