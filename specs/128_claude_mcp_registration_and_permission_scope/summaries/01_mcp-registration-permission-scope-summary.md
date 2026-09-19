# Implementation Summary: Task #128

**Completed**: 2026-09-19
**Duration**: ~45 minutes

## Overview

Corrected Claude Code MCP registration and permission scope on four counts across two files:
fixed a false design-rationale comment, removed a domain-specific `lean-lsp` grant from
machine-scope permissions, added the missing `playwright` permission grants at the scope where
the server is registered, and registered the `mcp-nixos` server under the correct tool-address
name `nixos`. All changes were rebuilt and verified end to end, including headless permission
checks in a fresh Claude Code process.

## What Changed

- `modules/home/core/dotfiles.nix` (`activation.claudeMcpServers`) — Replaced the false
  "subagents cannot see project-scoped .mcp.json" comment with the true rationale for
  playwright's user scope (Nix-built wrapper on PATH, machine-level browser cache dependency, no
  per-project args, used across every repo); corrected the stale
  "existing mcpServers.lean-lsp entry" wording (lean-lsp is per-project, not touched by this
  block); extended the single jq pass to also register the `nixos` server
  (`{"type":"stdio","command":"uvx","args":["mcp-nixos"]}`) via a second `--argjson`; updated the
  `DRY_RUN` echo to name both servers.
- `config/claude/settings.json` (`permissions.allow`) — Removed `mcp__lean-lsp__*` (a
  Lean-specific grant that did not belong at machine scope); added the nine enumerated
  playwright tools (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`,
  `browser_console_messages`, `browser_network_requests`, `browser_click`, `browser_type`,
  `browser_find`, `browser_wait_for`) and the two `mcp__nixos__*` tools
  (`mcp__nixos__nix`, `mcp__nixos__nix_versions`). Deliberately withheld
  `browser_evaluate`, `browser_file_upload`, and `browser_run_code_unsafe`; no wildcard used.

## Decisions

- Registered the mcp-nixos server under the name `nixos` (never `mcp-nixos`), so tools resolve
  as `mcp__nixos__nix` / `mcp__nixos__nix_versions`, matching the agent system's existing grants
  and documentation.
- Used a single jq pass with two `--argjson` arguments and an assignment (not append) filter,
  keeping one tmpfile / one `mv` / one failure path, per the plan's explicit recommendation.
- Enumerated exact playwright tool names rather than a `mcp__playwright__*` wildcard, preserving
  the asymmetry that keeps `browser_evaluate`/`browser_file_upload`/`browser_run_code_unsafe`
  gated.

## Plan Deviations

- None (implementation followed plan).

## Verification

- `nix-instantiate --parse modules/home/core/dotfiles.nix`: succeeds.
- Dry-tested jq merge filter against a scratch copy of `~/.claude.json`: both `nixos` and
  `playwright` present in `.mcpServers`, top-level key set unchanged, running the filter twice
  produced byte-identical output (idempotent).
- `grep -n 'mcp-nixos'` in `dotfiles.nix`: only appears in the comment and as the `args` value,
  never as a server key. `grep -n 'subagents cannot see'`: no matches.
- `jq -e . config/claude/settings.json`: parses. `permissions.allow` `mcp__` entries: exactly the
  11 expected names, no `mcp__playwright__*` wildcard, no `browser_evaluate` /
  `browser_file_upload` / `browser_run_code_unsafe` / `lean-lsp` entries.
- `git diff config/claude/settings.json`: net -1/+11 lines in `permissions.allow`, no other diff
  lines, matching the plan's Scope Hypothesis exactly.
- `nix flake check`: all checks passed (nandi, hamsa, garuda, iso, usb-installer NixOS
  configurations; homeConfigurations; formatter; devShells).
- `home-manager switch --flake .#benjamin`: succeeded (activation reached `claudeMcpServers`,
  `claudeSettings`, `uvTools`, `zotConfig` in order). The systemd "degraded" warnings during
  activation are pre-existing stale `lean-comparator-run` transient failed units, unrelated to
  this change (no `claude`/`mcp` unit among them).
- `claude mcp list`: `playwright: playwright-mcp - Connected` and `nixos: uvx mcp-nixos -
  Connected`.
- Post-switch `~/.claude.json`: top-level key set is a strict superset of the pre-switch
  baseline (OAuth, `projects`, and all 111 other baseline keys intact); per-project
  `mcpServers.lean-lsp` count unchanged at 4; `.mcpServers.nixos` equals the specified config
  exactly; no `mcp-nixos` key exists anywhere in the file.
- Deployed `~/.claude/settings.json` `.permissions` matches the repo source byte-for-byte
  (confirming the ENFORCED-key reset applied).
- Headless verification in fresh `claude -p` processes (`--output-format json`,
  `permission_denials` field): an `mcp__nixos__nix` search call and an
  `mcp__playwright__browser_navigate` call both completed with `"permission_denials": []`; an
  `mcp__playwright__browser_evaluate` call was denied, with the tool name and input recorded in
  `permission_denials`.
- `nixos-rebuild build --flake .#hamsa`: succeeded (no sudo, build only).
- `home-manager switch --flake .#benjamin --dry-run`: printed
  "Would merge mcpServers.playwright and mcpServers.nixos into ~/.claude.json" and the
  claudeSettings/keybindings echo lines only — confirmed non-destructive.

## Notes

- **Behavior change (expected, recorded per the task description)**: removing
  `mcp__lean-lsp__*` from machine-scope `permissions.allow` means any repository that relies on
  lean-lsp MCP tools without its own project-level grant will now prompt for those tools instead
  of running silently. This is the correct behavior — lean-lsp is a domain-specific server that
  should be granted at the scope where it is actually needed, not blanket-granted machine-wide —
  and is not a regression to work around.
- Confirmed via direct experiment (as stated in the task description) that a `.mcp.json`
  project-scoped server IS reachable from a subagent when permission is pre-granted; the
  playwright user-scope choice is retained for its true, independent rationale (Nix-built PATH
  wrapper, machine-level browser cache, no per-project args, cross-repo utility), not the
  disproven subagent-visibility claim.
- No new Nix wrapper package was needed for mcp-nixos; `uvx` at
  `/run/current-system/sw/bin/uvx` (system-level, reliably on PATH) was sufficient, as verified
  by `claude mcp list` showing `nixos: uvx mcp-nixos - Connected`.
