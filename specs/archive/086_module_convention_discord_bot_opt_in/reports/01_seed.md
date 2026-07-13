# Seed Report: Module Convention + Aggregators + Per-Host Discord-Bot Opt-In (Task 86)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #5, **Tier 1 — strategic core, sequence BEFORE task 77's
dispatch.** Self-contained (no dependencies). **Explicitly behavior-changing.**

## Scope

This is the single highest-leverage subtask in the reorganization. Work:

1. Amend `.claude/rules/nix.md` to scope the options-pattern requirement to optional/host-toggled
   modules only (not a blanket 43-file rewrite).
2. Introduce `modules/system/default.nix` and `modules/home/default.nix` aggregators, replacing
   `configuration.nix`'s and `home.nix`'s flat hand-maintained import lists.
3. Convert `modules/system/optional/discord-bot.nix` to `options.services.discordBot.enable` +
   `mkIf`; remove it from the shared/default aggregator.
4. Wire it explicitly per-host (e.g. `hosts/nandi/default.nix` sets
   `services.discordBot.enable = true`) via `extraModules` in `flake.nix` — **explicit wiring,
   NOT a generic `pathExists`/`readDir` auto-discovery layer.**
5. Delete garuda's empty-body `hosts/garuda/default.nix` now; re-add only with real content plus
   explicit `flake.nix` wiring when garuda actually needs an opt-in module.
6. Update `docs/discord-bot.md:25`.
7. Fold task 69's dual-home-manager Option-A documentation-only resolution in here (or defer to
   subtask 91/documentation-sync if more natural there).

**THIS SUBTASK IS EXPLICITLY BEHAVIOR-CHANGING**: a host that silently got the Discord bot before
will legitimately stop getting it. Not covered by the standard build-only inertness harness.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §1.3 (target tree, `modules/system/default.nix`, `modules/home/default.nix`,
  `optional/discord-bot.nix`), §2 (Decision Table rows 1, 2, 10), §3 "Subtask Blueprint" row 5,
  §4.3 "Runtime Verification Requirement" (MANDATORY — read this in full before implementing).
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "modules/" section (options-pattern gap, discord-bot.nix unconditional import), "hosts/"
  section (garuda's empty placeholder).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — "Conflicts Resolved #2" (per-host wiring mechanism — explicit wins over `pathExists`),
  Design-Question Decisions table rows on options pattern / per-host wiring / task-69 resolution.

## Key Excerpt (design doc §4.3, Runtime Verification Requirement)

> Subtasks 5 ... are intentionally behavior-changing ... Build-level `nix store diff-closures`
> **cannot observe** these changes ... For these ... subtasks, the build harness must be
> supplemented with `nixos-rebuild switch --flake .#<host>`, `systemctl status`, `journalctl -u
> ... -n 50`, `systemctl cat ...` confirming ExecStart/PYTHONPATH points at a `/nix/store/...`
> path.

## Verification Level

**RUNTIME + BUILD**: full harness (`nix flake check` + build nandi/hamsa/garuda + HM activation)
PLUS `nixos-rebuild switch` + `systemctl status`/`journalctl` confirming hamsa's closure no
longer includes the Discord bot's Python closure and nandi's does. Stage with
`git add <specific paths>` (never `-A`) before verification.

## Scope Boundary

Nix-managed tree only; do not touch `.claude/`, `.memory/`, `.opencode/`, `specs/` (except the
one `.claude/rules/nix.md` amendment explicitly called for above, which is a rules-doc change,
not a Nix-managed-tree file).
