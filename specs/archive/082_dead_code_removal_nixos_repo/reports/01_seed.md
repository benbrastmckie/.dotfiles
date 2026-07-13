# Seed Report: Dead Code Removal (Task 82)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #1, Tier 0 (parallel, no dependencies)

## Scope

Remove dead/orphaned files from the NixOS/Home Manager dotfiles repo: `home-modules/` (+ its
stale comment references), `modules/opencode.nix`, `packages/neovim.nix`, `test-sasl.sh`,
`test-update.md`, root `TODO.md`, 5 wallpapers scaffolding files. Widen `packages/test-mcphub.sh`
removal to patch its 3 doc references in the same subtask. Drop the (already resolved)
`config/rclone.conf` verify step.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §3 "Subtask Blueprint" row 1 (full scope + verification level), §4 "Migration Safety &
  Verification" (git-add-before-verify protocol — MANDATORY before any nix verification command).
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — sections "home-modules/ — DEAD (delete)", "modules/ — LIVE, well-factored, but convention
  gaps" (opencode.nix), "packages/ — mostly LIVE; two orphans" (neovim.nix, test-mcphub.sh),
  "Root files" table (test-sasl.sh, test-update.md, TODO.md), "wallpapers/" section (5 cruft
  files).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — Recommended Subtask Decomposition table, row 1 (Critic correction on `test-mcphub.sh` being
  doc-referenced, not orphaned; dropped `config/rclone.conf` step).

## Key Excerpt (design doc, Subtask Blueprint row 1)

> Remove `home-modules/`, `modules/opencode.nix`, `packages/neovim.nix`, `test-sasl.sh`,
> `test-update.md`, root `TODO.md`, wallpapers cruft (5 files); widen `packages/test-mcphub.sh`
> removal to patch its 3 doc references (`docs/packages.md:244`, `docs/applications.md:26`,
> `packages/README.md:260-277`); drop the already-resolved `config/rclone.conf` verify step.

## Verification Level

Build-only inertness: `git status` shows only deletions + doc edits; harness green
(`nix flake check` + `nixos-rebuild build --flake .#nandi/.#hamsa/.#garuda` +
`nix build .#homeConfigurations.benjamin.activationPackage`). Stage all deletions with
`git add <specific paths>` before running the harness — never `git add -A`.

## Scope Boundary

Nix-managed tree only. Do not touch `.claude/`, `.memory/`, `.opencode/`, `specs/`.
