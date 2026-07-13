# Seed Report: NEW — nix flake check CI Gate (Task 84)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #3, Tier 0 (parallel, no dependencies)

## Scope

Add a `nix flake check` GitHub Actions workflow (and/or a pre-commit hook). This closes the
drift-discovered-late gap that let tasks 67 (R env/ICU), 68 (zfs-kernel), and 69 (lectic
specialArgs) go undetected until an unrelated task's audit surfaced them.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §3 "Subtask Blueprint" row 3, §4.4 "CI-Gate Rationale" (why this is first-class Tier-0, not
  optional).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — "Migration Philosophy" section (CI gate rationale), Recommended Subtask Decomposition row 3.

## Key Excerpt (design doc §4.4)

> Subtask 3 adds a `nix flake check` GitHub Actions workflow. This is the design's answer to
> "no automated backstop exists across a 9-10 subtask, multi-session reorg" — three of the repo's
> last ~15 tasks (67 R-env/ICU, 68 zfs-kernel, 69 lectic specialArgs) are exactly the class of
> drift such a gate would catch immediately rather than during an unrelated task's audit later.

## Verification Level

Build-only inertness: workflow runs green on a trivial PR/push; local `nix flake check` still
passes. Stage the new workflow file with `git add <specific path>` before verifying locally.

## Scope Boundary

Nix-managed tree + new `.github/workflows/` directory only.
