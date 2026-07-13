# Seed Report: config/ Deployment Clarity (Task 90)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #9, Tier 2 (optional/low priority). **Depends on task 88**
(module granularity pass, which renames `home/core/shell.nix` to `dotfiles.nix` — this doc's
cross-reference target must already exist under its new name).

## Scope

Expand `config/README.md` to document all three existing deployment mechanisms: (1)
`home.file.*.source` store symlinks, (2) `builtins.readFile` copies mirrored into
`~/.config/config-files/`, (3) the activation-script `cp` for
`config/claude/{settings,keybindings}.json` into `~/.claude/`. Explicitly note: (a) the `config/`
vs Nix `config` module-argument shadowing, and (b) the separate `.claude/` (agent-orchestration
system, out of scope for task 81) vs `config/claude/` (deployed dotfiles, in scope) naming
collision — flag it so it is never conflated. Cross-reference from `dotfiles.nix`'s (renamed by
task 88) header comment. **Preserve and explicitly flag (do not fix or silently widen)** the
pre-existing intended behavior that `config/claude/` activation force-overwrites
`~/.claude/settings.json`/`keybindings.json` on every switch. This subtask is explicitly
optional/do-only-if-a-slow-week-presents-itself.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §1.2 (naming collision), §1.3 (`config/README.md`), §2 (Decision Table row 7), §3 "Subtask
  Blueprint" row 9, §5 (Coverage Gap #4 disposition on force-overwrite preservation).
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "config/" section (three deployment mechanisms, naming collision).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — Coverage Gaps #3 and #4.

## Key Excerpt (design doc §5, Gap #4)

> `config/claude/` activation force-overwrites, doesn't just risk drift ... Pre-existing, intended
> behavior — not something this task fixes. Subtask 9 (config/ deployment clarity) must document
> and preserve this exact semantic, flagging it explicitly rather than silently widening what gets
> force-copied.

## Verification Level

Doc-only: stale-reference grep confirms `config/README.md` accurately reflects the current three
mechanisms and both callouts (shadowing + naming collision) are present. Stage with
`git add <specific paths>` before any verification.

## Scope Boundary

`config/README.md` and `dotfiles.nix`'s header comment only. Do not touch `.claude/` itself.
