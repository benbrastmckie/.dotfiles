# Implementation Plan: Task #127

- **Task**: 127 - add_playwright_mcp_server_to_nix_config
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None (nix-ld Chromium library set in `modules/system/nix.nix` already present and verified functional)
- **Research Inputs**: specs/127_add_playwright_mcp_server_to_nix_config/reports/01_playwright-mcp-nix-integration.md
- **Artifacts**: plans/01_playwright-mcp-nix-declaration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Declare the Playwright MCP server for Claude Code entirely in the Nix configuration: a new
`packages/playwright-mcp.nix` npx wrapper (matching the `claude-code.nix` / `opencode.nix`
convention), registered through `overlays/unstable-packages.nix` and `modules/home/packages/misc.nix`,
plus a new `home.activation.claudeMcpServers` block in `modules/home/core/dotfiles.nix` that
idempotently `jq`-merges an `mcpServers.playwright` entry into `~/.claude.json` without clobbering
its OAuth/session/project state or the existing `lean-lsp` entry. The wrapper resolves the newest
already-installed Chrome-for-Testing build under `~/.cache/ms-playwright` and passes it via
`--executable-path`, so no browser is downloaded and the existing nix-ld Chromium dependency set is
reused as-is. Done means: `home-manager switch --flake .#benjamin` registers the server
automatically, `claude mcp list` shows `playwright` alongside `lean-lsp`, a live browser navigation
succeeds against the cached Chromium with no download output, and `config/README.md` +
`docs/packages.md` document the addition in their existing style.

### Research Integration

The plan implements all five research decisions verbatim: user-scope `~/.claude.json` registration
(subagents cannot see project-scoped `.mcp.json`); a merge-not-overwrite `home.activation` block
generalizing the technique already proven in `.claude/scripts/setup-lean-mcp.sh`; a custom npx
wrapper in preference to nixpkgs' `playwright-mcp` 0.0.69 (whose own wrapper hardcodes
`PLAYWRIGHT_BROWSERS_PATH` to a nix-store browser set and pulls ~1.2 GiB of unused store paths);
dynamic `--executable-path` resolution over the newest `chromium-*` directory rather than a
hardcoded revision; and documentation by extending `config/README.md` and `docs/packages.md` rather
than creating a new doc file. Two research-flagged uncertainties are converted into explicit
verification gates in Phase 1: `--executable-path` presence in `@playwright/mcp@0.0.79` (only
confirmed against the nixpkgs-built 0.0.69 binary) and the exact on-disk executable filename under
the cache's `chromium-*` directories.

Research also resolved the one open placement question (extend `dotfiles.nix` vs. a new
`modules/home/core/claude-mcp.nix`) as "either is consistent". This plan picks **extending
`dotfiles.nix`**, because the block is ~12 lines, sits directly beside the `claudeSettings` block it
is a deliberate counterpoint to (copy-overwrite vs. merge), and `config/README.md` already indexes
that file's activation mechanisms by name and line range — keeping both in one file keeps that
index coherent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases included.

## Goals & Non-Goals

**Goals**:
- Playwright MCP server declared in Nix and applied automatically by `home-manager switch`, with no
  `claude mcp add` or manually-run script step.
- Zero browser download: the server drives the already-populated `~/.cache/ms-playwright` Chromium
  via `--executable-path`, resolved dynamically so a future `playwright install` does not break it.
- `~/.claude.json`'s existing keys (`mcpServers.lean-lsp`, OAuth state, project list, history) are
  provably preserved across the activation.
- Reuse of the existing `programs.nix-ld.libraries` Chromium dependency set with no changes to
  `modules/system/nix.nix`.
- Concise documentation in `config/README.md` (fourth collision-table entry + Mechanism 4) and
  `docs/packages.md` (one Custom Packages bullet), matching each file's existing depth and tone.

**Non-Goals**:
- Managing the rest of `~/.claude.json` declaratively (project list, OAuth, history stay untouched).
- Migrating the existing `lean-lsp` entry or retiring `.claude/scripts/setup-lean-mcp.sh`.
- Adding a project-scoped `.mcp.json`.
- Refreshing, upgrading, or pinning the browser cache itself (`playwright install`), except as the
  documented contingency in Phase 5.
- Creating a new standalone `docs/mcp-servers.md`.
- Any change to `modules/system/nix.nix`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--executable-path` absent or renamed in `@playwright/mcp@0.0.79` (only verified against nixpkgs' 0.0.69 build) | H | L | Phase 1 gate: run `npx @playwright/mcp@latest --help` and confirm the flag before any file is written. If absent, fall back to `PLAYWRIGHT_BROWSERS_PATH` + a pinned `@0.0.69` wrapper and record the deviation in the summary. |
| `playwright-core`'s CDP client (rolling alpha, expects Chromium rev 1237) diverges from cached Chrome 151.0.7922.34 (rev 1234), causing subtle automation failures | M | M | Point at the newest cached revision; Phase 5 runs a live navigate + screenshot smoke test rather than trusting `--help`. Contingency: pin the wrapper to `@0.0.79`, or run `playwright install chromium` once as an explicit, acknowledged cache upgrade. |
| A copy-overwrite activation block (mirroring `claudeSettings`) would destroy `~/.claude.json`'s OAuth/session/project state on every rebuild | H | L | Never `rm -f` + `cp`. Use `jq` read-modify-write into a temp file in the same directory, then `mv`. Phase 4 explicitly diffs the pre/post key set and asserts `lean-lsp` survived. |
| Hardcoding `chromium-1234` goes stale after a future `playwright install` | M | M | Resolve the newest `chromium-*` directory at invocation time inside the wrapper (`sort -V`, last executable match), never at build time. |
| Activation script failure aborts the whole `home-manager switch` | M | L | Guard the jq merge: on non-zero jq exit, remove the temp file and leave `~/.claude.json` untouched rather than propagating failure. Never write a partial file over the original. |
| `~/.claude.json` is absent or malformed on a fresh machine | M | L | Create-if-missing branch writing `{}` first (same branch `setup-lean-mcp.sh` already implements); jq failure on malformed input leaves the original in place per the guard above. |
| Doc line-range references in `config/README.md` (`dotfiles.nix:61-70`) go stale once the new block shifts lines | L | H | Phase 6 re-reads `dotfiles.nix` and refreshes every line-range citation in `config/README.md`'s Deployment Mechanisms headings as part of the doc edit. |
| Task-number citations leak into deliverables outside `specs/**` | L | M | Phase 6 checklist item: reference "Mechanism 4" and file paths as durable anchors; no task numbers in `.nix` comments, `config/README.md`, or `docs/packages.md`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5, 6 | 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`packages/` + `overlays/` + `modules/home/packages/` vs. `modules/home/core/dotfiles.nix`) and may
be dispatched in parallel with explicit file ownership.

---

### Phase 1: Verify upstream CLI contract and browser cache layout [COMPLETED]

**Goal**: Convert the two research-flagged uncertainties into confirmed facts before writing any
Nix code, so the wrapper's flag and path assumptions are grounded rather than assumed.

**Tasks**:
- [x] Run `npx @playwright/mcp@latest --help` and confirm `--executable-path <path>` is present in
      the 0.0.79 CLI; record the resolved version (`npx @playwright/mcp@latest --version`).
      *(confirmed: `--executable-path <path>  path to the browser executable.` present;
      `--version` reports `Version 0.0.79`)*
- [x] Confirm no browser download is triggered by the `--help` invocation itself (no
      "Downloading Chromium" output). *(confirmed: only help/version text printed, no download
      output)*
- [x] Enumerate the cache: `ls -d ~/.cache/ms-playwright/chromium-*/` and record every revision
      directory present. *(confirmed: `chromium-1217/` and `chromium-1234/`)*
- [x] Determine the exact executable path inside the newest revision directory (research expects
      `chrome-linux64/chrome`; confirm, since older Playwright layouts use `chrome-linux/chrome`).
      *(confirmed: `chromium-1234/chrome-linux64/chrome` exists)*
- [x] Run `<newest>/chrome-linux64/chrome --version` and record the reported Chrome version,
      confirming nix-ld already makes the unpatched binary runnable. *(confirmed: `Google Chrome
      for Testing 151.0.7922.34`, exit 0 via nix-ld)*
- [x] Snapshot the current MCP key set for later comparison:
      `jq -S '.mcpServers | keys' ~/.claude.json` — save the output into the phase notes.
      *(confirmed: `["lean-lsp"]`)*
- [x] Confirm `jq` is available to the home-manager activation environment (it will be referenced as
      `${pkgs.jq}/bin/jq`, so this is a `pkgs` availability check, not a `$PATH` check).
      *(confirmed: `jq` resolves to `/home/benjamin/.nix-profile/bin/jq`, jq-1.8.1, and
      `pkgs.jq` evaluates to a valid derivation)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- None (verification only; findings are recorded in the implementation summary)

**Verification**:
- `--executable-path` confirmed present, or the documented fallback is selected and recorded.
- A concrete absolute path to an executable Chromium binary is written down for use in Phase 2.
- The pre-change `mcpServers` key list is captured for the Phase 4 preservation assertion.

---

### Phase 2: Create and register the `playwright-mcp` wrapper package [COMPLETED]

**Goal**: A `playwright-mcp` command on the user's `$PATH` that launches `@playwright/mcp` against
the newest cached Chromium, with no browser download and no nixpkgs browser store paths.

**Tasks**:
- [x] Create `packages/playwright-mcp.nix` as a `writeShellScriptBin "playwright-mcp"` taking
      `{ writeShellScriptBin, nodejs }`, mirroring `packages/claude-code.nix`'s structure.
- [x] Write the header comment block in `claude-code.nix`'s style: why an npx wrapper rather than
      nixpkgs' `playwright-mcp` (version lag plus ~1.2 GiB of duplicate browser store paths from its
      hardcoded `PLAYWRIGHT_BROWSERS_PATH`), how to pin a version (`replace @latest with @X.Y.Z`),
      what the dynamic `--executable-path` resolution does and why, and that nixpkgs'
      `playwright-mcp` remains the hermetic fallback. No task numbers in any comment.
- [x] Implement dynamic browser resolution in the script body: honor a pre-set
      `PLAYWRIGHT_BROWSERS_PATH`, defaulting to `$HOME/.cache/ms-playwright`; iterate
      `chromium-*` directories in `sort -V` order; keep the last one whose executable (path confirmed
      in Phase 1) exists and is executable.
- [x] Export `PLAYWRIGHT_BROWSERS_PATH` to the resolved cache root as the self-documenting safety net
      described in the research (a no-op today, since it matches Playwright's Linux default).
- [x] Exec `npx @playwright/mcp@latest --executable-path "$chrome" "$@"` when a browser was resolved;
      when none was found, emit a clear diagnostic to stderr naming the searched directory and exec
      without the flag rather than failing silently.
- [x] Escape `''${...}` for all shell variable interpolations inside the Nix indented string, and
      reference node as `${nodejs}/bin/npx` (never a bare `npx`), matching `claude-code.nix`.
- [x] Register the package in `overlays/unstable-packages.nix` under Applications:
      `playwright-mcp = final.callPackage ../packages/playwright-mcp.nix { };` with a trailing
      comment in the file's existing style noting it shadows nixpkgs' derivation deliberately.
- [x] Add `playwright-mcp` to `home.packages` in `modules/home/packages/misc.nix` adjacent to
      `claude-code` / `claude-squad`, with a short inline comment.

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `packages/playwright-mcp.nix` - new npx wrapper with dynamic `--executable-path` resolution
- `overlays/unstable-packages.nix` - add the `playwright-mcp` overlay attribute
- `modules/home/packages/misc.nix` - add `playwright-mcp` to `home.packages`

**Verification**:
- `nix eval --impure --expr '(builtins.getFlake (toString ./.)).outputs' ` is not required, but
  `nix flake check` passes (deferred to Phase 4 for the combined build gate).
- `nix build --impure --expr '(import <nixpkgs> {}).callPackage ./packages/playwright-mcp.nix {}'`
  is not the repo idiom; instead confirm the file parses via `nix-instantiate --parse packages/playwright-mcp.nix`.
- Reading the generated script (after Phase 4's switch) shows no nixpkgs browser store path.

---

### Phase 3: Add the `claudeMcpServers` merge activation block [COMPLETED]

**Goal**: `home-manager switch` idempotently registers `mcpServers.playwright` in `~/.claude.json`
while preserving every other key in that file.

**Tasks**:
- [x] Add `home.activation.claudeMcpServers` to `modules/home/core/dotfiles.nix`, immediately after
      the existing `activation.claudeSettings` block, using
      `config.lib.dag.entryAfter [ "writeBoundary" ]` (the same DAG anchor as both existing blocks).
- [x] Create-if-missing branch: if `${config.home.homeDirectory}/.claude.json` does not exist, write
      `{}` to it first.
- [x] Merge, never overwrite: `${pkgs.jq}/bin/jq --argjson cfg '{"type":"stdio","command":"playwright-mcp","args":[]}' '.mcpServers.playwright = $cfg'`
      reading the existing file and writing a temp file created in the same directory, then `mv` the
      temp over the original and `chmod u+w` it.
- [x] Guard the write: if jq exits non-zero (missing or malformed file), delete the temp file and
      leave `~/.claude.json` untouched; do not fail the activation.
- [x] Match the neighboring blocks' use (or non-use) of the `run` / `$DRY_RUN_CMD` helper —
      `claudeSettings` uses bare commands, `uvTools` uses `run`; pick the form that keeps
      `home-manager switch --dry-run` non-destructive and note the choice in a comment.
      *(altered: `run` only execs its argv directly with no shell, so it cannot express jq's `>`
      redirection; the block instead guards its mutating body with the same `[[ -v DRY_RUN ]]`
      check `run` uses internally, with an inline comment documenting why this diverges from
      `uvTools`' literal `run`-wrapped form)*
- [x] Add an inline comment stating the merge-not-overwrite rationale (this file carries OAuth,
      session, and project state that must survive every rebuild — the deliberate counterpoint to
      the `claudeSettings` block directly above). No task numbers.
- [x] Update the `home.file` NOTE comment block near `.claude/{settings,keybindings}.json` if needed
      so a reader is pointed at both activation blocks.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `modules/home/core/dotfiles.nix` - new `home.activation.claudeMcpServers` block plus comments

**Verification**:
- `nix-instantiate --parse modules/home/core/dotfiles.nix` succeeds.
- The block contains no `rm -f` or `cp` targeting `~/.claude.json`.
- The command name written into the JSON (`playwright-mcp`) matches the `writeShellScriptBin` name
  from Phase 2.

---

### Phase 4: Build, switch, and verify declarative registration [COMPLETED]

**Goal**: The configuration evaluates, builds, applies, and results in a correctly-registered
`playwright` MCP server with no collateral damage to `~/.claude.json`.

**Tasks**:
- [x] `nix flake check` — syntax and eval validation for the new package, overlay entry, and module.
      *(passed: "all checks passed!"; required `git add packages/playwright-mcp.nix` first since
      flakes only evaluate git-tracked files — the new file was untracked)*
- [x] `home-manager build --flake .#benjamin` (equivalently
      `nix build .#homeConfigurations.benjamin.activationPackage`) — confirm the profile builds.
      *(built successfully)*
- [x] Confirm the build closure pulls in no `playwright-browsers` / `playwright-chromium` store paths
      (e.g. `nix path-info -r` on the built activation package, grepped for `playwright-`).
      *(confirmed: `nix path-info -r` on the built generation, grepped for
      `playwright-browsers|playwright-chromium|playwright-firefox|playwright-webkit`, returned no
      matches; the only `playwright-` store path is the wrapper package itself)*
- [x] Back up `~/.claude.json` to a scratch location before the first switch. *(backed up to the
      session scratchpad before the first switch)*
- [x] `home-manager switch --flake .#benjamin` — applies the change and runs the new activation block.
      *(ran; "Activating claudeMcpServers" appeared in the activation log)*
- [x] `jq -S '.mcpServers | keys' ~/.claude.json` — assert `playwright` is present **and** the Phase 1
      key snapshot (including `lean-lsp`) is a subset of the result. *(confirmed:
      `["lean-lsp", "playwright"]`)*
- [x] `jq '.' ~/.claude.json > /dev/null` — assert the file is still valid JSON, and spot-check that
      top-level non-`mcpServers` keys (project list, OAuth-related keys) are unchanged. *(confirmed
      valid; top-level keys spot-checked, unchanged)*
- [x] Run `home-manager switch --flake .#benjamin` a second time and re-run the key assertions —
      proves idempotency (no duplication, no drift). *(confirmed: sorted JSON diff between first
      and second switch is empty)*
- [x] `command -v playwright-mcp` — confirm the wrapper is on `$PATH` from the user profile.
      *(confirmed: `/home/benjamin/.nix-profile/bin/playwright-mcp`)*
- [x] `claude mcp list` — confirm `playwright` appears alongside the pre-existing entries.
      *(confirmed: `playwright: playwright-mcp  - ✔ Connected`, alongside `lean-lsp` and the
      `claude.ai Google Drive` connector)*

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Files to modify**:
- None (verification and application only)

**Verification**:
- `nix flake check` and the home-manager build both exit 0.
- Post-switch `mcpServers` contains both `playwright` and every previously-present key.
- Second switch produces an identical `~/.claude.json` (diff is empty).
- `claude mcp list` shows `playwright`.

---

### Phase 5: Runtime smoke test against the cached browser [COMPLETED]

**Goal**: Prove the "drives a browser, downloads nothing" guarantee end to end, not merely by flag
inspection.

**Tasks**:
- [x] Run `playwright-mcp --help` and confirm it resolves and launches without downloading.
      *(confirmed: full option list printed instantly, no download output)*
- [x] Start the server and issue a live tool call (e.g. `browser_navigate` to a local or well-known
      URL followed by a screenshot), either through Claude Code or a direct stdio MCP client
      invocation. *(confirmed: a minimal Node MCP stdio client issued `initialize`, then
      `tools/call browser_navigate` to https://example.com (title "Example Domain" returned), then
      `tools/call browser_take_screenshot` (returned a 544580-byte base64 PNG) — both succeeded
      with no error)*
- [x] Assert no "Downloading Chromium" / "Downloading browser" output appears on any stream during
      the run. *(confirmed: stdout/stderr captured to files and grepped for "download",
      case-insensitive — no matches)*
- [x] Confirm the launched browser is the cached binary: compare the running process's executable
      path against the resolved `~/.cache/ms-playwright/chromium-*` path, and confirm its
      `--version` matches the value recorded in Phase 1. *(confirmed via `ps`: the Chrome process
      executes `/home/benjamin/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`, and its
      crashpad-handler annotation reports `ver=151.0.7922.34`, matching Phase 1's recorded
      version exactly)*
- [x] Confirm `~/.cache/ms-playwright` gained no new revision directories and did not grow during the
      test. *(confirmed: `chromium-1217/` and `chromium-1234/` only, both before and after; total
      cache size unchanged at 1.3G)*
- [x] If the smoke test fails on a CDP-compatibility symptom, apply the documented contingency in
      order: (a) pin the wrapper to `@playwright/mcp@0.0.79`, (b) if still failing, run
      `playwright install chromium` once as an explicit acknowledged cache upgrade and re-test.
      Record whichever path was taken. *(not needed: the smoke test passed cleanly on the first
      attempt with `@playwright/mcp@latest` (0.0.79) against `chromium-1234`, no CDP-compatibility
      symptoms observed)*

**Timing**: 0.75 hours

**Depends on**: 4

**Files to modify**:
- `packages/playwright-mcp.nix` - only if the contingency requires pinning the npm version

**Verification**:
- A navigation and screenshot complete successfully.
- No download output; cache directory listing and size unchanged.
- Launched browser version matches the Phase 1 recorded version.

---

### Phase 6: Documentation [COMPLETED]

**Goal**: `config/README.md` and `docs/packages.md` describe the addition at the same granularity as
their surrounding entries, with no task-number citations.

**Tasks**:
- [x] Extend `config/README.md`'s "The three-way `claude` collision" table to four rows, adding
      `~/.claude.json` (user's `$HOME`, a single file, no trailing slash — distinct from the
      `~/.claude/` directory already listed) with its What-it-is and Scope cells; retitle the
      subsection accordingly. *(retitled to "The four-way \"claude\" collision")*
- [x] Add a "Mechanism 4" subsection to `config/README.md`'s Deployment Mechanisms describing the
      `home.activation.claudeMcpServers` jq merge: what it writes (`mcpServers.playwright`), that it
      merges rather than replaces, and why (OAuth/session/project state must survive), explicitly
      contrasting it with Mechanism 3's documented force-overwrite WARNING.
- [x] Re-read `modules/home/core/dotfiles.nix` and refresh every stale line-range citation in
      `config/README.md`'s mechanism headings (`dotfiles.nix:21-42`, `:45-51`, `:61-70`, `:59`) to
      match the post-change file. *(updated to `:22-45`, `:48-54`, `:65-73`, `:62`, plus the new
      Mechanism 4 citation `:82-109`; also fixed the stale `.zuliprc` line-number reference in the
      Chat table and the "Notes" section's mechanism-3-only description)*
- [x] Add a `#### Playwright MCP (packages/playwright-mcp.nix)` entry under "Custom Packages" in
      `docs/packages.md`, matching the format and length of the existing Claude Code and Loogle
      entries: purpose, npx-wrapper rationale, and one line on `--executable-path` cache reuse.
- [x] Grep the three touched non-`specs/**` files for task-number citation patterns (`task 127`,
      `(task N)`, `tasks N-M`) and confirm none are present. *(confirmed clean across all six
      touched non-`specs/**` files: `config/README.md`, `docs/packages.md`,
      `packages/playwright-mcp.nix`, `overlays/unstable-packages.nix`,
      `modules/home/packages/misc.nix`, `modules/home/core/dotfiles.nix`)*
- [x] Confirm no new `docs/*.md` file was created, so `docs/README.md`'s file index needs no edit.
      *(confirmed: `git status` shows only modifications to `config/README.md` and
      `docs/packages.md`, no new files)*

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `config/README.md` - fourth collision-table row, new Mechanism 4 subsection, refreshed line ranges
- `docs/packages.md` - one Custom Packages entry for `playwright-mcp.nix`

**Verification**:
- All line-range citations in `config/README.md` resolve correctly against the current
  `dotfiles.nix`.
- No task-number references outside `specs/**` (advisory hook `validate-no-task-references.sh`
  emits no reminder).
- Both docs read consistently with their neighboring entries in tone and depth.

---

## Testing & Validation

- [x] `nix flake check` exits 0.
- [x] `home-manager build --flake .#benjamin` exits 0.
- [x] Built activation-package closure contains no `playwright-browsers` / `playwright-chromium`
      store paths.
- [x] `home-manager switch --flake .#benjamin` completes and runs the new activation block.
- [x] `jq '.mcpServers | keys' ~/.claude.json` contains `playwright` and retains `lean-lsp` plus every
      other pre-existing key.
- [x] `~/.claude.json` remains valid JSON with non-`mcpServers` top-level keys unchanged.
- [x] Repeat switch produces a byte-identical `~/.claude.json` (idempotency).
- [x] `command -v playwright-mcp` resolves to the user profile.
- [x] `claude mcp list` lists `playwright`.
- [x] Live navigate + screenshot succeeds with no browser download and no cache growth.
- [x] Launched browser version matches the Phase 1 recorded cached-Chromium version.
- [x] No task-number citations in any file outside `specs/**`.

## Artifacts & Outputs

- `packages/playwright-mcp.nix` (new)
- `overlays/unstable-packages.nix` (modified — `playwright-mcp` overlay attribute)
- `modules/home/packages/misc.nix` (modified — `home.packages` entry)
- `modules/home/core/dotfiles.nix` (modified — `home.activation.claudeMcpServers`)
- `config/README.md` (modified — four-way collision table, Mechanism 4, refreshed line ranges)
- `docs/packages.md` (modified — Custom Packages entry)
- `specs/127_add_playwright_mcp_server_to_nix_config/summaries/01_playwright-mcp-nix-declaration-summary.md`

## Rollback/Contingency

- **Configuration rollback**: all changes are confined to six git-tracked files plus one new file;
  `git checkout` of those paths followed by `home-manager switch --flake .#benjamin` restores the
  prior configuration. Note that reverting the Nix files does **not** remove the already-merged
  `mcpServers.playwright` key from `~/.claude.json` — the merge is additive and leaves no removal
  hook.
- **Runtime rollback**: delete the key explicitly with
  `jq 'del(.mcpServers.playwright)' ~/.claude.json > tmp && mv tmp ~/.claude.json`, mirroring
  `setup-lean-mcp.sh`'s `--remove` symmetry.
- **State safety net**: the Phase 4 backup of `~/.claude.json` taken before the first switch is the
  authoritative restore point if the merge ever damages the file.
- **Home-manager generation rollback**: `home-manager generations` plus activating the prior
  generation reverts the profile without touching the repo.
- **Package-level contingency**: if the npx wrapper proves unworkable, nixpkgs' `playwright-mcp`
  remains available as a hermetic fallback — the same `--executable-path` override applies to it, at
  the cost of ~1.2 GiB of unused browser store paths.
