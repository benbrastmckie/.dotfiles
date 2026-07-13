# Seed Report: opencode-discord-bot Packaging (Task 89)

**Parent task**: 81 (reorganize_nixos_dotfiles_repository_design)
**Blueprint reference**: Subtask #8, Tier 2. **Depends on task 86** (module convention +
per-host discord-bot opt-in — the service must already be wired as an explicit per-host option
before its packaging changes underneath it). **Explicitly behavior-changing.**

## Scope

Add a `pyproject.toml` to `opencode-discord-bot/` and convert its packaging to
`buildPythonApplication` under `packages/` (near-term, low-risk destination — NOT extraction to
its own repo, which is a later strategic follow-on once the bot's interface stabilizes, mirroring
the email-extension precedent already in this repo; document that follow-on but do not implement
it here). Point the systemd unit's `ExecStart`/`PYTHONPATH`
(`modules/system/optional/discord-bot.nix:105`) at the built nix-store path instead of
`~/.dotfiles/opencode-discord-bot`. Fix the `discord-bot.nix:20` comment path typo (cites
`opencode-discord-bot/src/bot.py`; real path is `opencode_discord_bot/src/bot.py`). Resolve the
untracked-`.opencode/`-vs-tracked-`opencode.json` inconsistency (root `opencode.json` currently
points at a now-gitignored `.opencode/agent/...` path).

**THIS SUBTASK IS EXPLICITLY BEHAVIOR-CHANGING**: the closure gains the packaged bot and its
runtime execution path changes from a working-tree `PYTHONPATH` import to a nix-store path — NOT
covered by the standard build-only inertness harness.

## Primary Sources (read these first)

- **Design doc**: `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md`
  — §1.3 (`opencode-discord-bot/pyproject.toml`), §2 (Decision Table row 8), §3 "Subtask
  Blueprint" row 8, §4.3 "Runtime Verification Requirement".
- **Seed inventory**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md`
  — "opencode-discord-bot/" section (worst-of-both-worlds packaging gap, comment typo, untracked
  runtime files).
- **Team research**: `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md`
  — "Conflicts Resolved #1" (in-tree `buildPythonApplication` adopted now; extraction to own repo
  deferred).

## Key Excerpt (design doc, Conflicts Resolved #1 / Decision Table row 8)

> Near-term: package in-tree via `buildPythonApplication` under `packages/` (concrete, low-risk,
> immediately fixes the reproducibility hazard). Treat "extract to its own repo as a flake input"
> as a later strategic follow-on once the bot's interface stabilizes, mirroring the
> email-extension precedent.

## Verification Level

**RUNTIME + BUILD**: build harness + explicit runtime check (`systemctl cat`/dry-run showing
`ExecStart`/working directory resolves to a `/nix/store/...` path, not a `$HOME` path); document
the expected closure delta as intentional, not a regression. Stage with
`git add <specific paths>` (never `-A`) before verification.

## Scope Boundary

Nix-managed tree only (`packages/`, `modules/system/optional/discord-bot.nix`,
`opencode-discord-bot/`, root `opencode.json`).
