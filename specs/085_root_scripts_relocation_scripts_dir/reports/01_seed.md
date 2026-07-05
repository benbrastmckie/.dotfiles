# Seed Report: Root Shell Scripts → scripts/ (Task 85)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #4, Tier 0 (parallel, no dependencies)

## Scope

Move `install.sh`, `update.sh`, `build-usb-installer.sh` into a new `scripts/` directory; update
references in root `README.md`, `docs/testing.md`, `docs/usb-installer.md` in the same subtask.
(`test-sasl.sh` is deleted by subtask 82, not moved here.)

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §1.3 "Target Directory Layout" (`scripts/` entry), §2 "Decision Table" row 5, §3 "Subtask
  Blueprint" row 4.
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "Root files" table.
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — Design-Question Decisions table row "scripts/ for root shell scripts".

## Key Excerpt (design doc, Decision Table row 5)

> `scripts/` for root shell scripts | Yes, for `install.sh`/`update.sh`/`build-usb-installer.sh`;
> update direct doc references in the same subtask. `test-sasl.sh` deleted, not moved. |
> Corroborated by hlissner's `bin/` precedent.

## Verification Level

Build-only inertness: `grep` across docs shows only `scripts/`-prefixed paths; `./scripts/update.sh`
and `./scripts/install.sh` run; `nix flake check` green. Use `git mv`/`git add` (never `-A`) before
verification — an unstaged move looks like a stale-success or confusing "file not found" failure
because `flake.nix` uses `root = self`.

## Scope Boundary

Nix-managed tree + new `scripts/` directory + the three doc files listed above only.
