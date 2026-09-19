# Implementation Plan: Task #128

- **Task**: 128 - Claude MCP registration and permission scope
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/128_claude_mcp_registration_and_permission_scope/reports/01_mcp-registration-permission-scope.md
- **Artifacts**: plans/01_mcp-registration-permission-scope.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Four small, fully-specified corrections to two files in this repo: fix a false justification
comment and register a `nixos` MCP server in `modules/home/core/dotfiles.nix`
(`activation.claudeMcpServers`), and rewrite the machine-scope `permissions.allow` list in
`config/claude/settings.json` (drop `mcp__lean-lsp__*`, add nine enumerated playwright tools and
the two `mcp__nixos__*` tools). The two file edits are independent and can run in parallel; a
final phase rebuilds and runs the full verification set named in the task description. The one
rule behind all four items: grant permissions at the same scope where the server is
registered.

### Research Integration

Research re-checked all four items against the current files and the live machine state, and
none of them has changed:
- The target comment is now at `dotfiles.nix:136-137`, not 82-83. The block runs 136-164.
- `mcp__lean-lsp__*` sits at `config/claude/settings.json:44` and is also present in the live
  `~/.claude/settings.json`.
- There are zero `mcp__playwright__*` grants. `claude mcp list` shows playwright Connected.
- `uvx mcp-nixos` (v3.1.0) exposes exactly `nix` and `nix_versions`. `uv` is a system package,
  so `uvx` is found at `/run/current-system/sw/bin/uvx`.
- `lean-lsp` is registered per project under `.projects[...].mcpServers`, not at the top
  level. So the existing comment's line "The existing mcpServers.lean-lsp entry ... is left
  untouched" is also out of date and should be reworded as part of item 1.

Planner re-confirmation: `activation.claudeSettings` lists `permissions` in its ENFORCED key set.
The repo's `permissions` object therefore replaces the live one completely on every
activation. This is what lets item 2's removal actually reach `~/.claude/settings.json`; a
seed-only merge would have kept the stale wildcard.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (not provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Replace the false "(user scope; subagents cannot see project-scoped .mcp.json)" rationale
  with the true one: a Nix-built wrapper binary on PATH via `home.packages`, a dependency on
  the machine-level `~/.cache/ms-playwright` cache, no per-project arguments, and use in every
  repo. The mechanism stays unchanged.
- Remove `mcp__lean-lsp__*` from machine-scope `permissions.allow`.
- Add exactly the nine safe playwright tools, and the two `mcp__nixos__*` tools, to
  machine-scope `permissions.allow`.
- Register the MCP server under the name `nixos` (never `mcp-nixos`) with
  `{"type":"stdio","command":"uvx","args":["mcp-nixos"]}`. The registration must stay
  idempotent, merge rather than overwrite, and keep its `DRY_RUN` guard.

**Non-Goals**:
- Any `mcp__playwright__*` wildcard, or any grant for `browser_evaluate`,
  `browser_file_upload`, or `browser_run_code_unsafe`.
- Changing the playwright registration mechanism, or adding a Nix wrapper package for
  mcp-nixos.
- Editing the sibling agent-system repo, or per-project `lean-lsp` registrations in
  `~/.claude.json`.
- Adding `nixos` or any other key to the `claudeSettings` ENFORCED set.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A malformed jq filter corrupts `~/.claude.json`, which holds OAuth and session state | H | L | Keep the tmpfile-then-`mv` shape and the `rm -f` on failure. Back up `~/.claude.json` before the switch. After the switch, diff the top-level key sets. |
| Verifying from a session that is already running gives a false negative (session-start snapshot) | M | H | Do all tool-call and permission checks in a NEW `claude` process started after the switch. |
| Removing the lean-lsp grant makes Lean repos without their own grant start prompting | L | H | Expected behavior change. Record it in the summary; do not work around it. |
| Someone substitutes a playwright wildcard or a trap name (`mcp-nixos`) | H | L | Phase 3 checks the exact entries with jq: the name `nixos` is present, `mcp-nixos` is absent, and the three withheld tools are absent. |
| `nixos-rebuild build` / `home-manager switch` fails for reasons unrelated to this task | M | L | `nixos-rebuild build` needs no sudo. On an unrelated failure, record it with evidence and mark the phase [BLOCKED] rather than editing unrelated config. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix comment and register nixos server in dotfiles.nix [COMPLETED]

**Goal**: Fix item 1 (comment) and item 4 (registration) in `activation.claudeMcpServers`.

**Tasks**:
- [x] Re-confirm the block's location (`grep -n claudeMcpServers modules/home/core/dotfiles.nix`)
      and that `~/.claude.json` still has no `nixos` or `mcp-nixos` top-level entry.
- [x] Rewrite the comment header of the block:
  - Say it merges both servers (`playwright`, `nixos`).
  - Remove the false subagent-visibility clause.
  - State the true user-scope rationale for playwright: Nix-built `playwright-mcp` wrapper on
    PATH via `home.packages`, depends on the machine-level `~/.cache/ms-playwright` cache, no
    per-project args, useful in every repo.
  - State the `nixos` rationale: invoked via system-level `uvx`
    (`/run/current-system/sw/bin/uvx`) rather than `uv tool install` (whose `~/.local/bin` is
    not on PATH). It is named `nixos` so that tools resolve as `mcp__nixos__nix` /
    `mcp__nixos__nix_versions`, matching existing grants and docs.
  - Correct the stale "existing mcpServers.lean-lsp entry" wording: lean-lsp is registered per
    project and is left untouched, like every other key.
  - Keep the existing (accurate) OAuth-preservation and `DRY_RUN`/`run` explanation.
  - Use no task-number references in the comment.
- [x] Extend the jq merge with a second `--argjson`. Recommended shape: one jq pass,
      `--argjson pw '{...playwright...}' --argjson nixos '{"type":"stdio","command":"uvx","args":["mcp-nixos"]}'`
      with filter `.mcpServers.playwright = $pw | .mcpServers.nixos = $nixos`. This is one
      tmpfile and one `mv`, and stays idempotent because it uses assignment, not append.
      Decision: a single pass is preferred over chaining two jq calls, because it keeps a single
      failure path.
- [x] Update the `DRY_RUN` echo to name both `mcpServers.playwright` and `mcpServers.nixos`.

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `modules/home/core/dotfiles.nix` - `activation.claudeMcpServers` comment and jq merge

**Verification**:
- `nix-instantiate --parse modules/home/core/dotfiles.nix >/dev/null` succeeds.
- Dry-test the jq filter against a copy:
  `jq --argjson pw ... --argjson nixos ... '<filter>' ~/.claude.json`. Confirm that
  `.mcpServers | keys` contains both `nixos` and `playwright`, that the top-level key set
  otherwise equals the original, and that running it twice gives identical output.
- `grep -n 'mcp-nixos' modules/home/core/dotfiles.nix` shows it only as the `args` value and in
  the comment, never as a server key.
- `grep -n 'subagents cannot see' modules/home/core/dotfiles.nix` returns nothing.

---

### Phase 2: Rewrite machine-scope permission grants in settings.json [COMPLETED]

**Goal**: Fix items 2 and 3, plus item 4's optional grants, in `config/claude/settings.json`.

**Tasks**:
- [x] Remove `"mcp__lean-lsp__*"` from `permissions.allow`.
- [x] Add exactly these nine entries:
  - `mcp__playwright__browser_navigate`
  - `mcp__playwright__browser_snapshot`
  - `mcp__playwright__browser_take_screenshot`
  - `mcp__playwright__browser_console_messages`
  - `mcp__playwright__browser_network_requests`
  - `mcp__playwright__browser_click`
  - `mcp__playwright__browser_type`
  - `mcp__playwright__browser_find`
  - `mcp__playwright__browser_wait_for`
- [x] Add `mcp__nixos__nix` and `mcp__nixos__nix_versions`. These are exact names, not a
      wildcard, following the grant-at-registration-scope principle.
- [x] Leave every other key and entry untouched. Preserve the file's existing 2-space
      formatting.

**Timing**: 15 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The net change to `permissions.allow` is -1 / +11 entries (one lean-lsp
removal, nine playwright additions, two nixos additions), with no other diff lines. Confirm with
`git diff config/claude/settings.json`.

**Files to modify**:
- `config/claude/settings.json` - `permissions.allow`

**Verification**:
- `jq -e . config/claude/settings.json` parses.
- `jq -r '.permissions.allow[] | select(startswith("mcp__"))' config/claude/settings.json`
  prints exactly the 11 expected names.
- No entry matches `mcp__playwright__\*`, `browser_evaluate`, `browser_file_upload`,
  `browser_run_code_unsafe`, or `lean-lsp`.

---

### Phase 3: Rebuild and verify end to end [NOT STARTED]

**Goal**: Deploy and run every verification step the task requires.

**Tasks**:
- [ ] Record the pre-switch baseline:
  - `cp ~/.claude.json` to the scratchpad as a backup.
  - Record `jq 'keys' ~/.claude.json`.
  - Record `jq '[.projects[] | .mcpServers["lean-lsp"] // empty] | length' ~/.claude.json`.
- [ ] `nix flake check` (from the repo root). New files are not involved, so a git-add of
      untracked files is not needed.
- [ ] `home-manager switch --flake .#benjamin`.
- [ ] `claude mcp list`: both `playwright` and `nixos` show Connected.
- [ ] Check what survived the switch:
  - The post-switch top-level key set of `~/.claude.json` is a superset of the baseline
    (OAuth, `projects`, and similar keys intact).
  - The per-project lean-lsp count is unchanged.
  - `.mcpServers.nixos` equals the specified config.
  - No `mcp-nixos` key exists.
- [ ] Check that the deployed `~/.claude/settings.json` `permissions.allow` matches the source
      (the ENFORCED reset applied).
- [ ] In a NEW Claude Code process started after the switch, run a headless `claude -p` from a
      neutral directory (or the user's interactive check), since headless mode denies
      un-granted tools rather than prompting. Confirm:
  - A playwright `browser_navigate` call and an `mcp__nixos__nix` search both run without a
    permission prompt or denial.
  - A `browser_evaluate` call is denied or prompts. Check `permission_denials` in
    `--output-format json`.
- [ ] `nixos-rebuild build --flake .#hamsa` (build only, no sudo, no switch).
- [ ] Record the lean-lsp prompting behavior change in the implementation summary.

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- None (deployment and verification only). Any fix-up edit goes back to Phase 1 or 2's file.

**Verification**:
- All of the above pass, with command output captured in the summary.
- If the interactive-only portion cannot be exercised headlessly, mark it explicitly as a
  user-verification item rather than claiming it passed.

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `home-manager switch --flake .#benjamin` succeeds; `--dry-run` path still non-destructive (echo only)
- [ ] `claude mcp list` shows `playwright` and `nixos` Connected
- [ ] `~/.claude.json` pre-existing keys and per-project lean-lsp entries preserved
- [ ] New session: playwright navigate + `mcp__nixos__nix` unprompted; `browser_evaluate` still gated
- [ ] `nixos-rebuild build --flake .#hamsa` succeeds

## Artifacts & Outputs

- `modules/home/core/dotfiles.nix` (modified)
- `config/claude/settings.json` (modified)
- `specs/128_claude_mcp_registration_and_permission_scope/summaries/01_mcp-registration-permission-scope-summary.md`

## Rollback/Contingency

- Revert the two files with `git revert` of the phase commits, then re-run
  `home-manager switch --flake .#benjamin`. Because `permissions` is ENFORCED, this restores the
  prior allow list. The `nixos` entry in `~/.claude.json` persists after a revert, since the
  merge never deletes anything; remove it with `claude mcp remove nixos -s user` if needed.
- If `~/.claude.json` is damaged, restore the Phase 3 scratchpad backup.
