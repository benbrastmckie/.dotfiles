# Seed Report: Git Hygiene — specs/tmp/ (Task 83)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #2, Tier 0 (parallel, no dependencies)

## Scope

Untrack `specs/tmp/*` contents and extend `.gitignore` — the `specs/tmp/` directory itself must
continue to exist on disk (`skill-base.sh`'s atomic state-write pattern depends on it). Fix
`update.sh`'s mangled shebang and stray `complete\!` text.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §3 "Subtask Blueprint" row 2, §4.1 "Git-Add-Before-Verify Protocol".
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — section "Git hygiene".
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — Critic correction: `specs/tmp/` directory must persist on disk (references
  `.claude/scripts/skill-base.sh:356,362`); `specs/tmp/lit.md` is an unrelated mbsync
  troubleshooting note, not `--lit` tooling — no decoupling work needed.

## Key Excerpt (design doc, Subtask Blueprint row 2)

> Untrack `specs/tmp/*` contents and extend `.gitignore` — the `specs/tmp/` directory itself must
> continue to exist on disk (skill-base.sh's atomic state-write depends on it). `specs/tmp/lit.md`
> is an unrelated note, no decoupling needed. Fix `update.sh`'s mangled shebang and stray
> `complete\!`.

## Verification Level

Build-only inertness: `git status --porcelain` clean on `specs/tmp/` contents; directory still
present; `./update.sh` still executes; `nix flake check` green. Stage with
`git add <specific paths>` before verification — never `git add -A`.

## Scope Boundary

Nix-managed tree + `specs/tmp/`/`.gitignore`/`update.sh` only. Do not touch other content under
`specs/` or `.claude/`.
