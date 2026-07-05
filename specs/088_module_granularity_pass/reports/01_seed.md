# Seed Report: Module Granularity Pass (Task 88)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #7, Tier 2. **Depends on task 86** (module convention +
aggregators — new/renamed files should register in the new aggregators rather than needing a
second hand-edit).

## Scope

Split `modules/home/email/agent-tools.nix` (761 lines, 5 wrapper binaries) into
`modules/home/email/agent-tools/{default.nix, per-wrapper}.nix` — exact split boundaries are NOT
prescribed by this seed; finalize them during this subtask's own planning by reading the full
file first. Merge tiny fragment files into `modules/home/packages/misc.nix`:
`packages/fonts.nix` (8 lines), `packages/lean-math.nix` (8 lines), `packages/ai-tools.nix`
(10 lines). Co-locate the memory system's split files
(`scripts/memory-monitor.nix` + `services/memory-services.nix`). Rename
`modules/home/core/shell.nix` to `modules/home/core/dotfiles.nix` (it deploys `config/`, not
shell configuration — misnomer fix); treat further splitting deployment logic out to each owning
module as a future direction, not mandatory here.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §1.3 (`modules/home/` tree with `agent-tools/` split and `dotfiles.nix` rename), §2 (Decision
  Table row 11), §3 "Subtask Blueprint" row 7.
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "modules/" section (size outliers: `agent-tools.nix` 761 lines; tiny fragments list).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — Design-Question Decisions table row on raw-dotfile deployment structure (`shell.nix` →
  `dotfiles.nix` rename now; full split deferred as a future direction).

## Key Excerpt (design doc, Subtask Blueprint row 7)

> Split `agent-tools.nix` (761 lines) into `email/agent-tools/{default.nix, per-wrapper}.nix`
> (exact boundaries finalized during planning by reading the full file); merge tiny fragments
> (`fonts.nix`/`lean-math.nix`/`ai-tools.nix` → `packages/misc.nix`); co-locate memory
> scripts+services; rename `home/core/shell.nix` → `dotfiles.nix`. New files register in the
> subtask-5(86) aggregators.

## Verification Level

Build-only inertness: `nix build .#homeConfigurations.benjamin.activationPackage`;
`nix store diff-closures` against the pre-change baseline must be EMPTY (pure structural
refactor). Use `git mv` for renames and `git add <specific paths>` before verification —
never `git add -A`.

## Scope Boundary

Nix-managed tree only (`modules/home/`, `packages/`).
