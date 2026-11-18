# Implementation Summary: Retire Machine-Wide Sapience Activation Surface

- **Task**: 138 - Retire every machine-wide Sapience ACTIVATION surface this repository owns
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T08:59:17Z
- **Completed**: 2026-11-13T09:19:14Z
- **Effort**: ~20 minutes
- **Dependencies**: Companion project `gate_sapience_activation_behind_extension` (sited in
  `/home/benjamin/.config/nvim`, project 612) — confirmed landed and verified at Phase 1
- **Artifacts**: plans/01_retire-machine-wide-sapience.md, records/01-04, this summary
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This repository used to turn Sapience on for every Claude Code session on this machine, via a
top-level `mcpServers.sapience` merge into `~/.claude.json`, seven `mcp__sapience__*` grants, and
five Sapience hook entries in `config/claude/settings.json`. All three are retired. One
machine-wide surface is added in their place: a durable `SessionStart` entry in
`config/claude/settings.json` invoking the companion extension-side task's per-project
MCP-registration hook, which is the gating mechanism (not an activation surface) and survives a
`home-manager switch` because `hooks` is an enforced key. Loading the sapience extension into a
repository is now the only thing that turns Sapience on there.

## What Changed

- `modules/home/services/sapience.nix` — removed the `registerMcpServer` option and the
  `sapienceMcpServer` activation entry that merged `mcpServers.sapience` into `~/.claude.json`;
  reconciled four comment sites that described the retired arrangement.
- `config/claude/settings.json` — removed the seven `mcp__sapience__*` permission grants and the
  five Sapience hook entries (`SessionStart` briefing, `UserPromptSubmit`, `PreToolUse`, the
  `SessionEnd` receipt entry, `Stop`); dropped the three hook keys left empty
  (`UserPromptSubmit`, `PreToolUse`, `Stop`); kept `SessionEnd`'s surviving sleep-inhibitor-cleanup
  entry; added a `SessionStart` entry invoking
  `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'` — byte-for-byte
  the string the companion's installer keys its idempotency check on; rewrote `_SAPIENCE_NOTE` to
  state the per-repository arrangement and why the one registration entry stays here.
- `docs/sapience.md` — rewrote the intro, the "What is installed" table rows, first-time-setup
  step 4, the "Why the hooks live in the repo" section (including the already-wrong hook count,
  three instead of the actual five), the module options table, the inspection recipe, and the
  Rollback section; documented the registration entry itself; also fixed a stale
  `sapienceMcpServer` reference in the "token is validated" section not named in the dispatch's
  own enumeration.
- `home.nix` — corrected the one comment claiming the module installs MCP registration.
- One-time live cleanup (Phase 6, not a repository-source change): removed the orphaned top-level
  `mcpServers.sapience` key from the live `~/.claude.json`, left behind by the now-removed
  activation entry's prior writes — see Plan Deviations.
- Four evidence records under `specs/138_retire_machine_wide_sapience_surface/records/`:
  companion-landing confirmation, the owner instruction for `~/.sapience/config.json`, the
  nvim-sited follow-ups coordination record, and the live post-switch verification record.

## Decisions

- Kept the one registration `SessionStart` entry in `config/claude/settings.json` rather than
  relying solely on the companion's installer, because `hooks` is an enforced key and only this
  repository's own switch-time source can make the entry durable.
- Did not touch `modules/home/core/dotfiles.nix`'s `claudeMcpServers` entry (playwright/nixos) —
  confirmed by direct re-read that `sapienceMcpServer` was a separate entry, correcting a
  misnaming in the dispatch's own text that the research phase had already caught.
- Did not touch `packages/sapience-flake/**` — a standalone, separately-checked flake not
  imported by this machine's home configuration; `registerMcpServer = true` remains a correct
  default there for a consumer not using the per-repo extension mechanism.
- For the `~/.sapience/config.json` reconciliation, named a guarded `jq` hand-edit as the
  sanctioned one-time route (recorded in `records/02`), since neither `sapience projects` nor the
  interactive folder picker can express the full four-repository target in one pass — the moved
  `sapience-app` checkout's transcript directory does not exist yet for the picker to offer.
- Surfaced the owner instruction as a non-blocking `user_decision` on `.return-meta.json` rather
  than performing the edit, since `~/.sapience/config.json` is owner-only state this task must
  never write.

## Plan Deviations

- **Phase 6, gate-set task** altered: ran the scoped discharge (`verify-deploy.sh --only-gate 4`
  plus the 8-suite `run-all.sh --only` invocation) instead of the complete unscoped gate sweep,
  per this dispatch's own Batch Gate Deferral directive (this task is one of several
  implement-phase dispatches in a multi-task `/orchestrate` batch). The full sweep is deferred to
  the batch stage, not waived.
- **Phase 6, `~/.claude.json` inspection task** altered: discovered that removing the
  `sapienceMcpServer` writer does not retroactively erase the already-written top-level
  `mcpServers.sapience` key, because that file has no enforced-key reset semantics (unlike
  `~/.claude/settings.json`). Performed a one-time `jq del(.mcpServers.sapience)` cleanup — not a
  task the plan named — to actually satisfy acceptance criterion 2. Full top-level key-set
  comparison against the Phase 1 baseline confirmed zero other keys disturbed. Recorded as a plan
  verification gap, not an implementer error, via `issue-record.sh`.
- **Phase 6, negative/positive session tests** altered: ran the registration hook script
  directly from each test directory (the exact invocation a `SessionStart` hook performs) rather
  than launching interactive Claude Code sessions, since this agent cannot spawn an independent
  interactive session from within its own dispatch.
- **Phase 6, positive test** found a gap, not introduced by this task: `abood` and
  `sapience-app`'s own `.claude/` deploys have not been refreshed since the companion landed, so
  they still show the pre-companion 4-grant/0-hook set rather than 11/5. Out of this task's
  edit-target list; recorded via `issue-record.sh` rather than silently claimed as passing for
  all four repositories.
- No other deviations; every other phase's tasks were completed as planned.

## Impacts

- Sapience's Claude Code reach is now strictly per-repository: unloading the sapience extension
  from a repository's `.claude-extensions.json` now actually turns the vault off there, which was
  not true before this task (the top-level merge and the repo-source grants/hooks made it
  machine-wide regardless of extension state).
- The registration `SessionStart` hook is the one surface that must survive every future
  `home-manager switch`; Phase 6 confirmed it does, byte-identically, and that re-running the
  companion's installer afterward is a no-op rather than a double-registration.
- `~/.claude.json`'s `.projects[<abs path>].mcpServers.sapience` entries now populate themselves
  on the next session started in each loaded repository rather than all at once; a repository
  with no session since this change lands will show no entry until one runs, which is expected.
- The `~/.sapience/config.json` capture scope is currently still misaligned with the
  four-repository loaded set (three unloaded repos still captured, two loaded ones are not) until
  the owner applies the recorded instruction — this task cannot apply it itself.

## Follow-ups

- **Owner action (not an agent task)**: apply the `~/.sapience/config.json` reconciliation in
  `records/02_sapience-config-owner-instruction.md` — reduces `capture.projects` and the
  top-level `folders` allowlist to the four extension-loaded repositories. Verbatim instruction
  reproduced below.
- **nvim-sited follow-up (a)**: update the stale sapience worked example in
  `agent-system/core/context/patterns/mcp-server-ownership.md` (in `/home/benjamin/.config/nvim`)
  to describe the per-repository arrangement this task leaves in place. See `records/03`.
- **nvim-sited follow-up (b)**: resolve an SF-1 card worktree to its parent checkout for
  registration purposes, so the card repository's own repo-scoped retrieval becomes reachable
  inside the worktree. See `records/03`.
- **Deploy-staleness gap (not this task's to fix)**: `/home/benjamin/Projects/abood` and
  `/home/benjamin/Projects/Sapience/sapience-app` need their own `.claude/` deploy refreshed to
  pick up the companion's `settings-fragment.json` update (currently showing 4 grants / 0 hooks
  instead of 11 / 5).

### Owner instruction, reproduced verbatim

```bash
set -euo pipefail
cfg="$HOME/.sapience/config.json"
tmp="$(mktemp "${cfg}.XXXXXX")"

jq '
  .capture.projects = (
    [ .capture.projects[]
      | if (.path_prefix == "/home/benjamin/Projects/BimodalLogic"
            or .path_prefix == "/home/benjamin/Philosophy/Papers/PossibleWorlds"
            or .path_prefix == "/home/benjamin/Projects/Logos/Verification")
        then .enabled = false
        else . end
    ]
    + [
      {path_prefix: "/home/benjamin/Projects/abood", name: "abood", target: "personal", enabled: true},
      {path_prefix: "/home/benjamin/Projects/Sapience/sapience-app", name: "sapience-app", target: "personal", enabled: true}
    ]
  )
  | .folders = [
      "-home-benjamin--config-nvim",
      "-home-benjamin--dotfiles",
      "-home-benjamin-Projects-abood",
      "-home-benjamin-Projects-Sapience-sapience-app"
    ]
' "$cfg" > "$tmp" && mv "$tmp" "$cfg" && chmod 600 "$cfg"
```

Verification afterward: `jq -r '.folders' ~/.sapience/config.json` should list exactly the four
keys above; `jq -r '.capture.projects[] | select(.enabled==true) | .path_prefix' ~/.sapience/config.json`
should list exactly `.config/nvim`, `.dotfiles`, `Projects/abood`, and
`Projects/Sapience/sapience-app`; `stat -c '%a' ~/.sapience/config.json` should read `600`. Full
route determination and rehearsal evidence are in `records/02_sapience-config-owner-instruction.md`.

## References

- `specs/138_retire_machine_wide_sapience_surface/plans/01_retire-machine-wide-sapience.md`
- `specs/138_retire_machine_wide_sapience_surface/records/01_companion-landing-confirmation.md`
- `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`
- `specs/138_retire_machine_wide_sapience_surface/records/03_nvim-sited-followups.md`
- `specs/138_retire_machine_wide_sapience_surface/records/04_live-verification.md`
- `specs/138_retire_machine_wide_sapience_surface/reports/01_retire-machine-wide-sapience.md`
