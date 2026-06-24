# Implementation Summary: Task 66 — Review and Refactor NixOS Configuration (Partial)

**Status**: PARTIAL (gated on tasks 62 and 65)
**Completed**: 2026-06-24
**Branch**: `task-66-refactor-nixos`
**Phases Completed**: 0, 1, 7, 8 of 10 total (phases 2-6, 9 blocked)

## Overview

Task 66 is a large semantically-inert restructure of the NixOS configuration (flake.nix 477L,
configuration.nix 945L, home.nix 1627L). This partial implementation completes the independently
safe phases: quick-win critical fixes (Phase 1), dual HM documentation (Phase 7), and
documentation additions including a module map (Phase 8).

Structural phases 2-6 (overlay extraction, mkHost, configuration.nix split, home.nix split,
username hygiene) are gated on tasks 62 (TTS swap, edits configuration.nix:635) and 65
(python pins, edits home.nix:352 + flake.nix python overlay). Both are still [implementing].

## What Changed

### Phase 1: Quick-Win Safe Fixes

- `home.nix` — Fixed hardcoded SASL_PATH store hash → dynamic `${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2`
- `home.nix` — Removed dead `nix-ai-tools` from function signature (was in `{ ... }:` but never used in body)
- `configuration.nix` — Removed duplicate packages `stylua`, `cvc5`, `lectic`, `wl-clipboard` from `environment.systemPackages` (kept in `home.packages`)
- `configuration.nix` — Removed `neovim` from `environment.systemPackages` (managed by `programs.neovim.enable`)
- `flake.nix` — Added `inputs.nixpkgs.follows = "nixpkgs"` to `lean4` and `lectic` inputs
- `flake.nix` — Fixed pre-existing `hashedInitialPassword` → `initialHashedPassword` in usb-installer inline module (was causing `nix flake check` to fail before this task)
- `unstable-packages.nix` (root) — Deleted (dead file; no importers; superseded by `flake.nix` overlay)

### Phase 7: Dual Home-Manager Documentation

- `docs/dual-home-manager.md` — New: documents the NixOS-integrated vs standalone HM architecture, trade-offs, consolidation options (A/B/C), and the unmanaged `gmail-oauth2.env` secret note. Surfaces the consolidation decision as an explicit QUESTION for the user.

### Phase 8: Documentation + README Module Map

- `docs/how-to-add-package.md` — New: package ownership policy, decision tree, examples for each ownership tier
- `docs/how-to-add-service.md` — New: system vs user service guide with sops secret wiring, existing services table
- `README.md` — Added comprehensive ASCII module map (current + planned structure)
- `docs/configuration.md` — Updated to reflect new structure, planned overlays/lib/modules
- `docs/unstable-packages.md` — Updated: noted deletion of root file, updated package list

## Decisions

- **`utils` (flake-utils) does not get `follows = "nixpkgs"`**: flake-utils only has a `systems` input, not `nixpkgs`. Verified via `nix flake info`. Only `lean4` and `lectic` needed the follows addition.
- **`nix-ai-tools` kept in flake.nix inputs**: The arg is removed from `home.nix` signature since it's unused in the body, but the flake input and `inherit nix-ai-tools` in `extraSpecialArgs` are preserved — removing the input would require a flake.lock change and could break if something references it indirectly.
- **Pre-existing `hashedInitialPassword` bug fixed**: This caused `nix flake check` to fail on the baseline tree, so it was fixed in Phase 1 as a critical defect even though it wasn't in the original Phase 1 task list.
- **Structural phases gated**: Phases 2-6 are marked [BLOCKED] in the plan file. They must be re-dispatched after tasks 62 and 65 complete to avoid merge conflicts.

## Plan Deviations

- **Phase 0, task 1**: Tasks 62 and 65 are still [implementing]; proceeding with Phase 1 per the plan's explicit allowance ("Phase 1 may proceed independently").
- **Phase 0, baseline check**: `nix flake check` did NOT pass on the pre-refactor tree due to `hashedInitialPassword` bug — documented as pre-existing defect, fixed in Phase 1.
- **Phase 1, `utils` follows**: `flake-utils` has no `nixpkgs` input; only `lean4` and `lectic` got follows additions.
- **Phases 7 and 8 advanced**: Completed out of order (before 2-6) since they require no structural moves that would conflict with tasks 62/65.
- **Phases 2-6, 9**: Marked [BLOCKED] in plan; will be resumed once tasks 62 and 65 complete and their changes are stable in the config files.

## Verification

- `nix flake check`: Passes (all 4 nixosConfigurations + homeConfigurations.benjamin)
- `nix eval .#nixosConfigurations.nandi.config.system.build.toplevel`: Evaluates successfully
- `nix eval .#homeConfigurations.benjamin.activationPackage`: Evaluates successfully
- No structural changes to `.nix` files (Phases 2-6 blocked)

## Open Questions for User

1. **Dual Home-Manager**: Keep both NixOS-integrated and standalone HM paths, or consolidate?
   See `docs/dual-home-manager.md` for trade-offs and consolidation options.
2. **`nix-ai-tools` input**: This flake input is passed as `extraSpecialArgs` to all hosts but
   the `nix-ai-tools` arg is not actually used anywhere in `home.nix`. Safe to remove the flake
   input entirely? (Would need to remove from flake inputs, outputs destructuring, and all
   `extraSpecialArgs` blocks.)

## Next Steps

1. Wait for tasks 62 and 65 to complete (check `specs/state.json`)
2. Re-dispatch `/implement 66` to resume from Phase 2 on the `task-66-refactor-nixos` branch
3. Re-verify teammate-A line references in `configuration.nix` and `home.nix` after 62/65 edits
4. Proceed with Phases 2 → 3 → 4a → 4b → 5a → 5b → 6 → 9 sequentially
