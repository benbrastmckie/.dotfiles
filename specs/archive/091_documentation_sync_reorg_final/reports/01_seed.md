# Seed Report: Final Documentation Sync (Task 91)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #10, Final tier. **Depends on tasks 82-90** (all preceding
subtasks — this documents the tree they collectively produce).

## Scope

Update root `README.md`'s Module Map to drop stale "(planned: task 66 Phase 2/3/4)" annotations
(task 66 is long completed) and its package list to drop `neovim.nix` (removed by task 82) and add
`piper-bin.nix`/`piper-voices.nix`. Complete the `docs/README.md` index to list
`dual-home-manager.md`, `email-workflow.md`, `how-to-add-package.md`, `how-to-add-service.md`,
`gnome-settings.md`, `video-editing.md` (exist on disk, currently unlisted). Add a new
`modules/README.md` documenting the system/home split, the aggregator convention introduced by
task 86, and the meaning of `optional/`. Record one-line "checked, no action needed" notes for
`flake.lock` health and `stateVersion` values (Critic-verified non-issues). Resolve task 69's
dual-home-manager documentation closure here (Option A retained, documented) if task 86 did not
already do so. Establish the "docs verified against source, not fixed once" convention so task 78
(niri docs rewrite) can cite it — task 78 should ADOPT but NOT be merged with or made dependent
on this reorg's doc convention.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §3 "Subtask Blueprint" row 10, §5 "Open Decisions & Dispositions" (gap #6 flake.lock/
  stateVersion, gap #8 task-69 dual-home-manager, gap #9 task-78 sequencing note), §5.3
  "Roadmap Linkage Note", §6 "Created Subtasks" (final mapping table — read once other subtasks
  have landed to confirm actual final state).
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "Documentation drift" section (root README staleness, docs/README.md index gaps,
  hosts/README.md, missing modules/README.md).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — "Conflicts Resolved #4" (documentation-sync ordering — must be last), Coverage Gaps #6, #8,
  #9.

## Key Excerpt (design doc §5, Gap #9)

> Task 78 (niri docs) should adopt but not merge with this reorg's doc convention ... Task 78
> depends on tasks 74-77 and should adopt the "docs verified against source, not fixed once"
> convention established by subtask 10, but must not be merged with or made dependent on task 81's
> subtask chain.

## Verification Level

Full regression: re-run the complete build harness (`nix flake check` + nandi/hamsa/garuda builds
+ HM activation) as a final check, plus a manual README-vs-`find` drift check across the whole
tree. Stage with `git add <specific paths>` before verification.

## Scope Boundary

Nix-managed tree documentation only (root `README.md`, `docs/`, `modules/README.md`). Do not edit
`specs/ROADMAP.md` (read-only; only note linkage per design doc §5.3).
