# Seed Report: hosts/ Structural Cleanup (Task 87)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #6, Tier 2. **Depends on task 86** (module convention +
aggregators — the mkHost pattern and per-host wiring convention must be settled first).

## Scope

Rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example (`hosts/README.md:28-37`) to
document the current `mkHost` factory pattern — folds into task 86's doc edit if not already
done there. As an EXPLICITLY OPTIONAL stretch step only, extract the ~60-line ISO inline config
block (`flake.nix:118-175`) to `hosts/iso/default.nix` for symmetry — scope strictly to wiring, do
NOT touch task 68's broken zfs-kernel state, and exclude iso/usb-installer from the build-diff
harness (not reliably buildable regardless of this task's changes).

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §1.3 (`hosts/` tree, `hosts/iso/{default.nix}` note), §3 "Subtask Blueprint" row 6, §4.2
  "Baseline Verification Harness" (iso/usb-installer exclusion).
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "hosts/" section (garuda empty placeholder, obsolete README pattern), "lib/" section (ISO
  bypass of mkHost.nix).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — Recommended Subtask Decomposition row 6.

## Key Excerpt (design doc, Subtask Blueprint row 6)

> Rewrite `hosts/README.md`'s obsolete inline-`nixosSystem` example to the current `mkHost`
> pattern; extract the ISO inline config block to `hosts/iso/default.nix` only as an explicitly
> optional stretch step — scope strictly to wiring, do not touch task 68's broken zfs-kernel
> state, and exclude iso/usb-installer from the build-diff harness.

## Verification Level

Build-only inertness: `nix flake check`; iso/usb-installer build state unchanged (no new
regression attributable to this subtask). Stage with `git add <specific paths>` before
verification.

## Scope Boundary

Nix-managed tree only (`hosts/`, `flake.nix`). Do not touch task 68's zfs-kernel issue.
