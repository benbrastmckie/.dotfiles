# Implementation Summary: Add Playwright MCP server to Nix config

- **Task**: 127 - add_playwright_mcp_server_to_nix_config
- **Status**: [COMPLETED]
- **Started**: 2026-08-11T02:36:39Z
- **Completed**: 2026-08-11T02:50:01Z
- **Effort**: ~45 minutes agent time (6 phases)
- **Dependencies**: None
- **Artifacts**:
  - `specs/127_add_playwright_mcp_server_to_nix_config/plans/01_playwright-mcp-nix-declaration.md`
  - `specs/127_add_playwright_mcp_server_to_nix_config/reports/01_playwright-mcp-nix-integration.md`
  - `packages/playwright-mcp.nix`
  - `overlays/unstable-packages.nix`
  - `modules/home/packages/misc.nix`
  - `modules/home/core/dotfiles.nix`
  - `config/README.md`
  - `docs/packages.md`
- **Standards**: `.claude/context/formats/summary-format.md`, `.claude/rules/nix.md`

## Overview

Declared the Playwright MCP server for Claude Code entirely in Nix: a new npx-wrapper package
that reuses the already-populated `~/.cache/ms-playwright` Chromium build via
`--executable-path`, registered through the existing overlay/`home.packages` conventions, plus a
new merge-only `home.activation` block that idempotently registers `mcpServers.playwright` in
`~/.claude.json` on every `home-manager switch`, without ever touching the pre-existing
`mcpServers.lean-lsp` entry or any other key (OAuth, session, project list).

## What Changed

- `packages/playwright-mcp.nix` (new) — `writeShellScriptBin "playwright-mcp"` wrapper around
  `npx @playwright/mcp@latest`; resolves the newest `chromium-*` directory under
  `$PLAYWRIGHT_BROWSERS_PATH` (default `~/.cache/ms-playwright`) at invocation time and passes it
  via `--executable-path`, so no browser is ever downloaded.
- `overlays/unstable-packages.nix` — registered `playwright-mcp = final.callPackage
  ../packages/playwright-mcp.nix { };` under Applications.
- `modules/home/packages/misc.nix` — added `playwright-mcp` to `home.packages`.
- `modules/home/core/dotfiles.nix` — added `home.activation.claudeMcpServers`, immediately after
  `activation.claudeSettings`, using the same `jq` read-modify-write technique already proven by
  `.claude/scripts/setup-lean-mcp.sh` (create-if-missing, merge via temp file + `mv`, discard the
  temp file and leave the original untouched on jq failure); updated the neighboring `home.file`
  NOTE comment to point at both activation blocks.
- `config/README.md` — retitled "the three-way `claude` collision" to "the four-way `claude`
  collision" and added the `~/.claude.json` row; added a "Mechanism 4" subsection describing the
  merge-not-overwrite activation block and its explicit contrast with Mechanism 3's
  force-overwrite WARNING; refreshed every stale `dotfiles.nix` line-range citation (mechanisms
  1-3 plus the `.zuliprc` line) to match the post-change file.
- `docs/packages.md` — added a "Playwright MCP (packages/playwright-mcp.nix)" entry under Custom
  Packages, matching the depth of the existing Claude Code and Loogle entries.

## Decisions

- Extended `modules/home/core/dotfiles.nix` rather than creating a new
  `modules/home/core/claude-mcp.nix` — the block is short and sits directly beside the
  `claudeSettings` block it is a deliberate counterpoint to (per research's placement
  recommendation).
- The `activation.claudeMcpServers` block guards its own mutating body behind a direct
  `[[ -v DRY_RUN ]]` check rather than wrapping each command in home-manager's `run` helper (as
  `uvTools` does): `run` execs its argv directly with no shell, so it cannot express jq's `>`
  redirection. This keeps `home-manager switch --dry-run` non-destructive without fighting `run`'s
  argument-vector-only interface — documented inline as the reason for diverging from `uvTools`'
  form.
- Kept `@playwright/mcp@latest` (unpinned), matching the `claude-code.nix`/`opencode.nix`
  zero-maintenance convention; the smoke test in Phase 5 passed cleanly against the resolved
  0.0.79 CLI, so the version-pin contingency in the plan's risk table was not needed.

## Impacts

- Every `home-manager switch` now performs a read-modify-write on `~/.claude.json` via the new
  `activation.claudeMcpServers` block. The merge is additive and key-scoped, but `~/.claude.json`
  is app-owned mutable state (OAuth, session, project list), so this is the first activation step
  in this config that writes into a file Claude Code itself rewrites at runtime.
- `playwright-mcp` is now on `PATH` for the `benjamin` home configuration, and Claude Code
  discovers the `playwright` MCP server automatically on next start — no `claude mcp add` step.
- `~/.cache/ms-playwright` becomes an undeclared runtime dependency: the wrapper resolves the
  newest `chromium-*` build there at invocation time. Nix does not manage or populate that cache,
  so it is imperative state the declarative config now relies on (see Follow-ups).
- `config/README.md`'s `claude` collision table grew from three-way to four-way, and its
  `dotfiles.nix` line-range citations were refreshed — future edits to `dotfiles.nix` will stale
  them again.

## Plan Deviations

- **Phase 3** (`run` / `$DRY_RUN_CMD` helper choice): altered from a literal `run`-wrapped form to
  an equivalent `[[ -v DRY_RUN ]]` guard, because `run` cannot express shell redirection. Both
  achieve the same dry-run-safety goal; the divergence is documented inline in `dotfiles.nix` and
  annotated on the plan checklist.
- No other deviations — all six phases completed exactly as planned, including the Phase 5
  contingency ladder (pin to `0.0.79`, then `playwright install chromium`), which was not
  triggered because the smoke test passed on the first attempt.

## Verification

- `nix flake check`: Success (all outputs, including the new package/overlay/module, evaluate
  cleanly).
- `home-manager build --flake .#benjamin`: Success.
- Closure check: `nix path-info -r` on the built generation contains no
  `playwright-browsers`/`playwright-chromium`/`playwright-firefox`/`playwright-webkit` store
  paths — confirming the npx-wrapper choice avoided the ~1.2 GiB nixpkgs `playwright-mcp` would
  have pulled in.
- `home-manager switch --flake .#benjamin` (twice): `mcpServers` gained `playwright` and retained
  `lean-lsp`; a sorted JSON diff between the first and second switch's `~/.claude.json` was empty
  (idempotent, no drift or duplication).
- `command -v playwright-mcp` resolves to `~/.nix-profile/bin/playwright-mcp`.
- `claude mcp list` shows `playwright: playwright-mcp  - ✔ Connected` alongside `lean-lsp` and the
  pre-existing `claude.ai Google Drive` connector.
- Runtime smoke test: a direct MCP stdio client issued `initialize`, `browser_navigate` (to
  https://example.com, title "Example Domain" returned), and `browser_take_screenshot` (returned a
  544580-byte PNG) — all succeeded with no errors. `ps` confirmed the spawned Chrome process
  executes `~/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome` directly, with its
  crashpad-handler annotation reporting `ver=151.0.7922.34`, matching the Phase 1 recorded
  version. No "download" text appeared on stdout/stderr, and the cache directory's revision set
  (`chromium-1217`, `chromium-1234`) and total size (1.3G) were unchanged before and after.
- Task-number citation grep: clean across all six touched non-`specs/**` files.

## Follow-ups

- **Empty/cleared browser cache is unhandled**: if `~/.cache/ms-playwright` is pruned or the
  machine is re-provisioned, the wrapper has no `chromium-*` directory to resolve and the MCP
  server will fail at launch. No bootstrap path (`playwright install chromium`) is wired in.
  Decide whether to add one or document the manual recovery step.
- **`@playwright/mcp@latest` is unpinned**: `npx` will silently resolve a newer CLI over time, so
  a future upstream change to `--executable-path` semantics would surface as a runtime failure
  rather than a build failure. This matches the `claude-code.nix`/`opencode.nix` convention, so
  the trade-off is deliberate — revisit only if drift causes breakage.
- **Browser/CLI version skew is unchecked**: the wrapper picks the newest cached Chromium
  regardless of what the resolved `@playwright/mcp` expects. Verified compatible at
  Chromium 151.0.7922.34 / CLI 0.0.79, with no assertion guarding future skew.
- **`config/README.md` line-range citations remain manually maintained** — no check keeps them in
  sync with `dotfiles.nix`.

## References

- Plan: `specs/127_add_playwright_mcp_server_to_nix_config/plans/01_playwright-mcp-nix-declaration.md`
- Research report: `specs/127_add_playwright_mcp_server_to_nix_config/reports/01_playwright-mcp-nix-integration.md`
- Implementation commit: `004fbd5`
- Precedent for the jq-merge technique: `.claude/scripts/setup-lean-mcp.sh`
- Package conventions followed: `packages/claude-code.nix`, `packages/opencode.nix`

## Notes

`~/.claude.json` was backed up to the session scratchpad before the first switch, per the plan's
safety-net requirement; no restore was needed since every verification step passed. The existing
`mcpServers.lean-lsp` entry and all other pre-existing top-level keys (OAuth/session/project-list
state) were confirmed present and unchanged after both switches.
