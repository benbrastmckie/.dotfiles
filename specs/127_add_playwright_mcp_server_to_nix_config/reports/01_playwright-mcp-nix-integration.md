# Research Report: Task #127

**Task**: 127 - add_playwright_mcp_server_to_nix_config
**Started**: 2026-08-10T00:00:00Z
**Completed**: 2026-08-10T00:00:00Z
**Effort**: Medium (package wrapper + new activation mechanism + docs)
**Dependencies**: None (nix-ld Chromium deps already present in `modules/system/nix.nix`)
**Sources/Inputs**: Codebase read (flake.nix, modules/, packages/, config/, docs/), `nix eval`/`nix build` against this flake's pinned nixpkgs, `npm view` against the live registry, direct inspection of built store paths (wrapper scripts, `package.json`, `browsers.json`), prior archived task reports (4, 13, 19)
**Artifacts**: specs/127_add_playwright_mcp_server_to_nix_config/reports/01_playwright-mcp-nix-integration.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **MCP registration mechanism**: this repo has no home-manager-managed `~/.claude.json`. The one precedent for a declarative-but-mutable MCP entry is `.claude/scripts/setup-lean-mcp.sh`, an **imperative, manually-run** jq-merge script — not wired into any Nix module. The repo's real "module/option style" precedent for *runtime-writable* Claude Code files is `modules/home/core/dotfiles.nix`'s `home.activation.claudeSettings` block (copies `config/claude/settings.json` → `~/.claude/settings.json`, not a symlink, specifically so Claude Code can still write to it). Recommendation: add a **new home-manager activation block** in the same file/style that idempotently `jq`-merges a `playwright` entry into `~/.claude.json`'s `mcpServers` — the declarative generalization of what `setup-lean-mcp.sh` already does by hand, targeting user scope per `.claude/README.md`'s "MCP Configuration" note (subagents cannot see project-scoped `.mcp.json`).
- **Package**: nixpkgs' own `playwright-mcp` (pinned via this flake's `nixpkgs` input, nixos-26.05) resolves to **0.0.69**, well behind the npm registry's **0.0.79**, and — critically — its wrapper script **hardcodes `PLAYWRIGHT_BROWSERS_PATH`** to a nix-store-only browser set, so using it as-is would ignore `~/.cache/ms-playwright` entirely and pull ~1.2 GB of duplicate Chromium/Firefox/WebKit store paths. Recommend a thin `packages/playwright-mcp.nix` **npx wrapper** (matching the existing `claude-code.nix`/`opencode.nix` "npx @latest, zero-maintenance" convention) instead of the nixpkgs derivation.
- **Browser reuse mechanism**: the `playwright-mcp` CLI supports `--executable-path <path>`, which **bypasses Playwright's internal revision-based browser resolution entirely** — verified directly against the built nixpkgs 0.0.69 binary's `--help` output. Pointing this flag at the cache's existing `chrome-linux64/chrome` binary decouples the MCP server's `playwright-core` version pin from the installed browser's revision, so nothing gets (re-)downloaded regardless of which package/version is used.
- **Version-pin risk (verified, not assumed)**: nixpkgs' `playwright-driver`/`playwright-mcp` (1.59.1 core) expects Chromium **revision 1217** (Chrome 147.0.7727.15); the npm registry's `@playwright/mcp@0.0.79` depends on a `playwright-core` alpha snapshot that expects revision **1237** (Chrome 152.0.7977.8). **Neither matches exactly** the two cached revisions (1217, 1234/Chrome 151.0.7922.34). `--executable-path` sidesteps this mismatch, but it is a real CDP-compatibility gap worth flagging for implementation-time smoke testing — recommend pointing at the newest cached revision, **chromium-1234**, resolved dynamically rather than hardcoded.
- **Docs**: no existing doc covers Claude Code MCP servers or `~/.claude.json` as a managed artifact. `config/README.md` (the authoritative deployment-mechanism reference) already documents a "three-way claude collision" table (`​.claude/`, `config/claude/`, `~/.claude/`) that is missing a fourth easily-confused entity, `~/.claude.json` (no trailing slash, a single file, distinct from the `~/.claude/` directory). Recommend extending that table plus a new "Mechanism 4" subsection there, plus a one-bullet addition to `docs/packages.md` for the new package, matching existing granularity. No task-number citations belong in either file per `.claude/rules/no-task-references-in-deliverables.md`.

## Context & Scope

This research covers where and how to declare a Playwright MCP server for Claude Code inside `/home/benjamin/.dotfiles`, reusing already-present infrastructure (nix-ld Chromium deps, the populated `~/.cache/ms-playwright` cache) rather than an ad-hoc `claude mcp add` CLI registration or a fresh browser download. It does not cover implementing the change — only identifying the exact files, mechanisms, and package/version to use.

## Findings

### 1. How this repo manages Claude Code configuration today

Three (soon-to-be-four, see Documentation section) distinct "claude" paths exist, per `config/README.md`'s own "Naming Hazards" section:

| Path | What it is | Managed how |
|------|------------|-------------|
| `.claude/` (repo root) | Agent-orchestration system (commands/skills/agents) | Git-tracked directly, out of scope here |
| `config/claude/settings.json`, `config/claude/keybindings.json` | Dotfiles *source* for Claude Code CLI settings | Git-tracked source |
| `~/.claude/settings.json`, `~/.claude/keybindings.json` | Deployed runtime target | `home.activation.claudeSettings` in `modules/home/core/dotfiles.nix:63-71` — **copies** (not symlinks) source → target on every `home-manager switch`, `chmod u+w`s them afterward, so Claude Code can still write runtime changes. Explicitly documented as force-overwrite (`config/README.md` "Mechanism 3"): any manual edit to the deployed file not copied back into `config/claude/` is silently destroyed on next rebuild. |
| `~/.claude.json` (user's home, **not** inside `~/.claude/`) | Claude Code's master user-scope config: `mcpServers`, project list, OAuth state, session history | **Not managed by any Nix module today.** The only existing automation is `.claude/scripts/setup-lean-mcp.sh`, an imperative bash+jq script that is run manually (no `home.activation` or systemd hook invokes it — confirmed via `grep -rn "setup-lean-mcp.sh" modules/ home.nix hosts/` returning nothing). |

`~/.claude.json` currently contains only `mcpServers.lean-lsp` (per delegation-context verification) plus Claude Code's own runtime state (project list, OAuth, etc.) — none of which this task should touch or risk clobbering.

`.claude/README.md`'s "MCP Configuration" section states the binding constraint: **"Custom subagents cannot access project-scoped MCP servers (`.mcp.json`). For subagent access, configure servers in user scope (`~/.claude.json`)."** This repo also has no `.mcp.json` at the root. Given the task wants Claude Code (including subagents) to drive a browser, **user scope (`~/.claude.json`) is the only viable target**, matching where `lean-lsp` already lives.

### 2. `setup-lean-mcp.sh`: the closest existing precedent, and its limitation

`.claude/scripts/setup-lean-mcp.sh` (lines 73-209) is a fully worked idempotent pattern:
- Detects whether `~/.claude.json` exists; creates it with `{"mcpServers": {"lean-lsp": ...}}` if not.
- If it exists, uses `jq --argjson leanConfig "$LEAN_CONFIG" '.mcpServers."lean-lsp" = $leanConfig'` written to a temp file then `mv`'d over the original — an atomic, non-destructive merge that **preserves every other key** in the file (unlike the settings.json "Mechanism 3" full-overwrite pattern, which is safe there only because `config/claude/settings.json` deliberately excludes all runtime state).
- Supports `--remove` for symmetric teardown.

This script is exactly the right *technique* (merge-only jq) but the wrong *integration point*: it is invoked by hand, which is precisely the "registered ad-hoc via the CLI" pattern task 127 asks to avoid. The task's "module/option style used elsewhere" is best read as: **wire the same merge technique into a `home.activation.*` block**, mirroring `claudeSettings`'s automatic-on-every-switch behavior, rather than requiring a human (or an agent) to remember to run a script or type `claude mcp add`.

### 3. Recommended mechanism: new `home.activation` block

Add a new activation entry alongside (or immediately after) `activation.claudeSettings` in `modules/home/core/dotfiles.nix`, e.g. `activation.claudeMcpServers`, using `config.lib.dag.entryAfter [ "writeBoundary" ]` (same DAG anchor already used for both existing activation blocks in that file) that:

1. `mkdir -p`'s `$HOME` (already exists, no-op) and touches `~/.claude.json` with `{}` if absent (same create-if-missing branch `setup-lean-mcp.sh` already implements).
2. Runs a `jq --argjson cfg '<playwright mcp server json>' '.mcpServers.playwright = $cfg'` merge into a temp file, then `mv`s it into place — **never a full overwrite**, since this file (unlike `settings.json`) carries OAuth/session state that must survive every rebuild.
3. Does **not** touch `.mcpServers.lean-lsp` or any other key.

This keeps the "declared once in Nix, applied automatically, mutually idempotent with manual `.claude.json` edits to unrelated keys" property that both existing mechanisms (`claudeSettings` copy, `setup-lean-mcp.sh` merge) individually have, combined into the one place that's actually missing: automatic application. A dedicated new module file (e.g. `modules/home/core/claude-mcp.nix`, imported from `modules/home/default.nix`) is also viable if the planner prefers single-responsibility file splitting over extending `dotfiles.nix` further — either placement should be documented in `config/README.md` (see Documentation section) since that file is the canonical index of "what deploys where."

**Payload for `mcpServers.playwright`** (values depend on the package decision below):
```json
{
  "type": "stdio",
  "command": "playwright-mcp",
  "args": []
}
```
matching `lean-lsp`'s existing shape (`"command": "uvx", "args": ["lean-lsp-mcp"]`) — a bare command name resolved via `$PATH` (which includes `~/.nix-profile/bin` / the per-user profile once the wrapper package is in `home.packages`), no absolute store path needed (store paths are also viable but bare names match the existing precedent and survive package rebuilds without edits).

### 4. Package choice: nixpkgs `playwright-mcp` vs. an npx wrapper

**Verified via `nix eval --impure` against this flake's actual pinned `nixpkgs` input** (nixos-26.05, not just the ambient `nixpkgs` channel/registry — both agreed in this check):

| | nixpkgs `playwright-mcp` | npm `@playwright/mcp@latest` |
|---|---|---|
| Version (this flake's pin) | **0.0.69** | **0.0.79** (npm registry, live) |
| `playwright-core` pin | `1.59.0-alpha-1774912654000` (≈ nixpkgs `playwright-driver` 1.59.1) | `1.63.0-alpha-2026-08-05` |
| Expected Chromium revision | **1217** (Chrome 147.0.7727.15) | **1237** (Chrome 152.0.7977.8) |
| Browser sourcing | Wrapper **hardcodes** `export PLAYWRIGHT_BROWSERS_PATH='/nix/store/kx4k5qivjm8p0y2azx5pnvczvzk6ap1i-playwright-browsers'` — confirmed by `cat`ing the built `bin/playwright-mcp` wrapper | None by default (uses Playwright's normal `~/.cache/ms-playwright` default location) |
| Extra store cost if used as-is | ~1.2 GiB additional store paths (`playwright-chromium`, `playwright-browsers`, `playwright-firefox`, `playwright-webkit`, etc.) pulled from the binary cache — confirmed via `nix build`, which fetched 377.7 MiB / unpacked 1.2 GiB | None (only the small JS package via npx, same cost model as `claude-code.nix`/`opencode.nix`) |
| `postinstall` browser-download hook | N/A (browsers ship as separate FODs) | **Confirmed absent** via `npm view @playwright/mcp@0.0.79 scripts` / `npm view playwright-core@1.59.1 scripts` / `npm view playwright@1.59.1 scripts` — none define a `postinstall`, so `npx` alone never triggers a browser fetch |
| `--executable-path` CLI flag | **Present**, confirmed via `--help` on the built 0.0.69 binary | Same upstream CLI codebase; not independently verified against 0.0.79's exact `--help` output — verify at implementation time |

Neither cached revision (1217, 1234) exactly matches either package's expectation, so **exact revision equality is not achievable with either choice** — the deciding factor becomes duplication cost and the repo's own stated convention. Given:
- The repo already has an established, explicitly-documented pattern for exactly this situation — nixpkgs lagging upstream AI-tooling releases — solved with a thin npx wrapper: `packages/claude-code.nix` ("Zero-maintenance approach (no version pinning)... Simple shell script wrapper around `npx @anthropic-ai/claude-code@latest`") and `packages/opencode.nix` (`overlays/unstable-packages.nix:11`, explicit comment "Latest release (custom build, bypasses nixpkgs lag)" superseding a commented-out `pkgs-unstable.opencode` line).
- The nixpkgs derivation would silently defeat the task's explicit "reuse `~/.cache/ms-playwright`" requirement unless additionally overridden with `--executable-path` anyway (its own wrapper's `PLAYWRIGHT_BROWSERS_PATH` export is otherwise irrelevant once that flag is set, since an explicit executable path skips revision resolution entirely) — so it buys no simplicity, only ~1.2 GiB of avoidable store duplication.

**Recommendation**: add `packages/playwright-mcp.nix`, a `writeShellScriptBin` wrapper around `npx @playwright/mcp@latest ...` (mirroring `claude-code.nix`'s structure/comment style), registered in `overlays/unstable-packages.nix` the same way `claude-code`/`opencode` are (either as a fresh overlay attribute, or explicitly shadowing nixpkgs' own `playwright-mcp` attribute the way `opencode` shadows `pkgs-unstable.opencode` — both are established idioms in that file), then added to `home.packages` in `modules/home/packages/misc.nix` next to `claude-code`/`claude-squad`. Document nixpkgs' `playwright-mcp` as the fallback/hermetic alternative for a future maintainer who prioritizes reproducibility over currency (same `--executable-path` override would apply to it too).

### 5. Reusing the existing browser cache without re-downloading

Verified facts:
- `programs.nix-ld.libraries` in `modules/system/nix.nix:32-63` already lists the full Chromium runtime dependency set, with an explicit inline comment: `# Enable nix-ld for running unpatched dynamic binaries (required for elan/Lean toolchains, Playwright/Chromium, and other foreign binaries)`. This is *because* `~/.cache/ms-playwright`'s Chrome-for-Testing binaries are generic-Linux dynamically-linked executables (not nixpkgs-patched/patchelf'd), so they need nix-ld's loader shim + this exact library set to run on NixOS. No changes needed here — it is already correctly in place and was already verified functional (`chrome --version` → exit 0) per the delegation context.
- The `playwright-mcp` CLI's `--executable-path <path>` option (confirmed present via `--help`) instructs Playwright to launch that binary directly rather than resolving/downloading a browser by revision. This is the standard, documented Playwright mechanism for "run against an already-installed browser" and is independent of the `PLAYWRIGHT_BROWSERS_PATH` env var once supplied.
- Two Chromium revisions currently exist in the cache: `chromium-1217` (older) and `chromium-1234` (Chrome 151.0.7922.34, most recently populated — verified working per delegation context). **Recommend pointing at `chromium-1234`** as the newer/closer match to current `@playwright/mcp` expectations (revision 1237), minimizing CDP protocol drift.
- Recommend the wrapper resolve the path **dynamically** at invocation time (e.g. `ls -d "$HOME/.cache/ms-playwright"/chromium-*/ | sort -V | tail -1`) rather than hardcoding `chromium-1234`, so a future system-level `playwright install chromium` (bumping to a new revision directory) does not silently break the MCP server without a config edit. This mirrors the self-healing philosophy already present in `claude-code.nix`'s `heal()` function (detects and repairs a broken npx install rather than hardcoding assumptions).
- Defensive addition (low cost, no behavioral change given `--executable-path` is authoritative): also export `PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"` in the wrapper — this is already Playwright's Linux default, so it is a no-op today, but makes the intended browser source self-documenting in the wrapper script and provides a safety net if some MCP tool call path ever falls back to revision-based resolution.

### 6. Version-pinning trade-off (explicit answer to research goal 3)

- **If maximal MCP-server currency is prioritized** (latest tool schema, bug fixes): use `@playwright/mcp@latest` via npx. Its `playwright-core` pin (a rolling alpha, currently expecting Chromium 1237) will always be slightly ahead of whatever `chromium-1234` (or any static cache snapshot) provides. `--executable-path` makes this a non-issue for *launching* the browser, but CDP surface added in very recent Chromium/Playwright releases could theoretically be unavailable in an older cached build. Given the task is browser-driving automation (navigation, clicking, screenshots — long-stable CDP surface), this risk is low in practice but not zero.
- **If maximal reproducibility/version-lock is prioritized**: pin `@playwright/mcp@0.0.79` explicitly (not `@latest`) in the wrapper, trading zero-maintenance for a fixed, testable combination — closer to how a version could be pinned in `claude-code.nix`'s comment ("To pin a version, replace `@latest` with `@X.Y.Z`").
- Either way, **the browser build itself (`chromium-1234`) stays fixed and reused** — it is the MCP server package version that floats, not the browser. This satisfies the task's core ask (no browser re-download) regardless of which npx pinning strategy is chosen; recommend leaving that specific choice (`@latest` vs. pinned) to the implementation plan, following the `@latest` convention used by `claude-code.nix`/`opencode.nix` unless the planner has reason to diverge.
- Post-implementation smoke test is cheap and should be part of the plan's verification step regardless of which option is chosen (see Recommendations).

### 7. Documentation placement

No existing doc covers Claude Code MCP servers, `~/.claude.json`, or Playwright. Fitting locations, in order of how directly this task touches them:

1. **`config/README.md`** — the authoritative "what deploys where and how" reference, already structured with numbered "Deployment Mechanisms" and an explicit "Naming Hazards" section listing the three easily-confused "claude" paths. This addition:
   - Introduces a fourth easily-confused path (`~/.claude.json`, single file, no trailing slash — distinct from the `~/.claude/` directory already in the table) that belongs in the "three-way claude collision" table (making it four-way).
   - Warrants a new "Mechanism 4" subsection alongside the existing "Mechanism 3: `home.activation.claudeSettings` copy" one, describing the merge-not-replace activation block, why it merges instead of overwrites (OAuth/session state must survive), and pointing at `mcpServers.playwright` as the concrete example — matching that file's existing depth and tone (it already documents the force-overwrite WARNING for Mechanism 3 in comparable detail).
2. **`docs/packages.md`** — under "Custom Packages", add a bullet for `playwright-mcp.nix` in the same format as the existing "Claude Code (packages/claude-code.nix)" and "Loogle (packages/loogle.nix)" entries (package purpose, npx-wrapper rationale, one line on the `--executable-path`/cache-reuse behavior).
3. **Inline comments** in the new `.nix` files themselves: `packages/playwright-mcp.nix` should carry a header comment block in the same style as `claude-code.nix` (rationale, pin-a-version instructions, what `--executable-path` resolution does and why); the new activation block should carry an inline comment referencing the merge-not-overwrite rationale, matching the tone of the existing `claudeSettings` block's neighboring comments.
4. **Not recommended**: a new dedicated `docs/*.md` file (e.g. `docs/mcp-servers.md`) — the addition is narrow (one server, one package, one activation block) and the task explicitly asks for "concise documentation... matching surrounding conventions"; extending the two existing docs above is proportionate. `docs/README.md`'s file index would only need an entry if a new file were created, so no index edit is expected under this recommendation.
5. **Rule compliance**: none of `config/README.md`, `docs/packages.md`, or any `.nix` file comment may cite "task 127" or any task number, per `.claude/rules/no-task-references-in-deliverables.md` (deliverables outside `specs/**`). If provenance needs a durable anchor, reference the mechanism name ("Mechanism 4") or file path, not the task number.

### 8. Verification commands appropriate to this repo

- `nix flake check` — syntax/eval validation for the new package + module.
- `nix build .#homeConfigurations.benjamin.activationPackage` or `home-manager build --flake .#benjamin` — confirms the home-manager profile (including the new `home.packages` entry and activation block) evaluates and builds. (`home-manager switch --flake .#benjamin` is this repo's documented command for user-only rebuilds, per `flake.nix:189-192`'s comments and `docs/README.md`'s "Quick Reference".)
- `home-manager switch --flake .#benjamin` — applies the change; runs the new activation block.
- `jq '.mcpServers' ~/.claude.json` — confirm `playwright` was added **and** `lean-lsp` (and any other existing keys) were preserved, not clobbered.
- `claude mcp list` — should show `playwright` alongside the pre-existing `lean-lsp` and the three `claude.ai` connectors noted in the delegation context.
- Smoke test for the "no re-download" guarantee: run the wrapper directly (e.g. `playwright-mcp --executable-path <resolved-path> --help` or start it and issue a `browser_navigate` tool call) and confirm no "Downloading Chromium/browser" output appears, and that the launched process's `chrome --version` matches the cached `chromium-1234` binary's `151.0.7922.34`.
- `nixos-rebuild build --flake .#<hostname>` is not required for this change (home-manager-only), but should still pass if the affected files are shared between NixOS-integrated and standalone home-manager paths (per `hmExtraSpecialArgs` in `flake.nix` — both consume the same `modules/home/` tree).

## Decisions

1. Register the server in **user-scope `~/.claude.json`**, not a project `.mcp.json`, because subagents cannot see project-scoped servers (per `.claude/README.md`) and the existing `lean-lsp` precedent already lives there.
2. Use a **new/extended `home.activation` block** (jq merge, not full overwrite) rather than reusing `setup-lean-mcp.sh` as-is or calling `claude mcp add` — this is the direct Nix-module-style generalization of both existing techniques in this repo.
3. Prefer a **custom `packages/playwright-mcp.nix` npx wrapper** over the nixpkgs `playwright-mcp` derivation, both for version currency (0.0.79 vs. 0.0.69) and to avoid ~1.2 GiB of duplicate, unused-by-this-task browser store paths that nixpkgs' derivation pulls in via its own wrapper's hardcoded `PLAYWRIGHT_BROWSERS_PATH`.
4. Use **`--executable-path`** (verified-present CLI flag) resolved dynamically against the newest `chromium-*` directory in `~/.cache/ms-playwright`, rather than `PLAYWRIGHT_BROWSERS_PATH` alone or a hardcoded revision path, to guarantee no browser download regardless of which `playwright-core` version the MCP server package pins.
5. Document the addition by **extending** `config/README.md` (new Mechanism 4 + fourth collision-table entry) and `docs/packages.md` (one bullet), not by creating a new standalone doc file.

## Recommendations

Prioritized for the planning and implementation phases. P1 items gate the rest: both are cheap
checks that invalidate the chosen approach if they fail, so neither should be deferred until
after code is written.

1. **P1 — Confirm the two unverified preconditions before writing any code** (owner:
   implementation). Run `npx @playwright/mcp@latest --help` and confirm `--executable-path` is
   present in the resolved 0.0.79 CLI (only verified against the nixpkgs-built 0.0.69 binary
   here), and record the exact executable filename under `~/.cache/ms-playwright/chromium-*`.
   If `--executable-path` is absent, fall back to the nixpkgs derivation and re-open the
   package-choice decision.
2. **P2 — Add `packages/playwright-mcp.nix`** (owner: implementation), an npx wrapper matching
   the `claude-code.nix`/`opencode.nix` form, resolving the newest `chromium-*` directory
   dynamically rather than hardcoding a revision. Register it in `overlays/unstable-packages.nix`
   and `modules/home/packages/misc.nix`.
3. **P3 — Add the `home.activation` registration block** (owner: implementation), using the
   `jq` read-modify-write technique from `setup-lean-mcp.sh`. This must **merge**, never
   `rm -f` + `cp`: `~/.claude.json` holds OAuth, session, and project-list state, and the
   pre-existing `mcpServers.lean-lsp` entry must survive. Back the file up before the first
   switch.
4. **P3 — Planner must pick the module location and record it** (owner: planning). Extending
   `modules/home/core/dotfiles.nix` and creating `modules/home/core/claude-mcp.nix` are equally
   consistent with repo conventions; the choice is arbitrary but must be made once and reflected
   in `config/README.md`'s Mechanism list.
5. **P4 — Verify with the no-download property as the explicit success criterion** (owner:
   implementation). Beyond `nix flake check` and `home-manager build`, assert that the built
   closure contains no `playwright-browsers`/`playwright-chromium` store paths, run
   `home-manager switch` twice and diff `~/.claude.json` for idempotency, and finish with a live
   navigate + screenshot smoke test confirming the spawned browser process runs from
   `~/.cache/ms-playwright` with no download and no cache growth.
6. **P5 — Extend the existing docs rather than adding a file** (owner: implementation): a fourth
   `claude` collision-table row and a new Mechanism 4 subsection in `config/README.md`, plus one
   Custom Packages entry in `docs/packages.md`. Refresh the stale `dotfiles.nix` line-range
   citations while editing.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `playwright-core`'s CDP client (whatever version the MCP server pins) may diverge from cached Chrome 151.0.7922.34's CDP server surface, causing subtle automation failures | Point at the newest cached revision (`chromium-1234`); add a post-implementation smoke test (navigate + screenshot) to the plan's verification step; if failures appear, the fallback is `playwright install chromium` once to refresh the cache to the exact expected revision — still not a re-download of *this* task's existing browsers, just an explicit acknowledged upgrade |
| Hardcoding `chromium-1234` in the wrapper becomes stale after a future manual `playwright install` changes the cache's newest revision directory | Resolve the executable path dynamically (`sort -V | tail -1` over `chromium-*` dirs) inside the wrapper rather than hardcoding the revision number |
| A full-overwrite activation block (copying the `claudeSettings` Mechanism-3 pattern verbatim) would destroy `~/.claude.json`'s OAuth/session/project-list state on every rebuild | Use a `jq`-based **merge** (same technique as `setup-lean-mcp.sh`), never `rm -f` + `cp` |
| `--executable-path` support in `@playwright/mcp@0.0.79`'s exact CLI was not independently verified (only confirmed against the nixpkgs-built 0.0.69 binary) | Implementation should confirm via `npx @playwright/mcp@latest --help` before relying on it; both versions share the same upstream `microsoft/playwright-mcp` codebase lineage, so divergence is unlikely but not proven here |
| Two Nix module locations are both plausible (extend `dotfiles.nix` vs. new `modules/home/core/claude-mcp.nix`) | Either is consistent with repo conventions; the planning phase should pick one and document it in `config/README.md`'s Mechanism list regardless of which |

## Appendix

### Verified store contents / commands run
- `nix eval --impure --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux.playwright-mcp.version'` → `0.0.69`
- `nix eval --impure --expr '...playwright-driver.version'` → `1.59.1`
- `nix build --impure --expr '...playwright-mcp'` → built successfully from binary cache, pulling in `playwright-chromium`, `playwright-browsers` (1.2 GiB unpacked), confirming the wrapper's own browser bundle
- `cat /nix/store/.../playwright-mcp-0.0.69/bin/playwright-mcp` → confirmed `export PLAYWRIGHT_BROWSERS_PATH=...` hardcoding
- `/nix/store/.../playwright-mcp-0.0.69/bin/playwright-mcp --help` → confirmed `--executable-path <path>` flag exists
- `npm view @playwright/mcp@0.0.79 dependencies --json` → `{"playwright": "1.63.0-alpha-2026-08-05", "playwright-core": "1.63.0-alpha-2026-08-05"}`
- Downloaded `playwright-core-1.63.0-alpha-2026-08-05.tgz` from the npm registry tarball URL and inspected `package/browsers.json` directly → chromium revision `1237` / browser version `152.0.7977.8`
- Inspected nixpkgs' `playwright-core@1.59.1` `browsers.json` (via the built `playwright-test-1.59.1` store path) → chromium revision `1217` / browser version `147.0.7727.15`
- `npm view @playwright/mcp@0.0.79 scripts --json`, `npm view playwright-core@1.59.1 scripts --json`, `npm view playwright@1.59.1 scripts --json` → all empty of `postinstall` hooks

### Files read
- `flake.nix`, `modules/system/nix.nix`, `modules/home/core/dotfiles.nix`, `packages/claude-code.nix`, `overlays/unstable-packages.nix`, `modules/home/packages/misc.nix`, `config/claude/settings.json`, `config/README.md`, `docs/README.md`, `docs/packages.md`, `docs/how-to-add-package.md`, `docs/applications.md`, `docs/claude-session-scopes.md`, `.claude/scripts/setup-lean-mcp.sh`, `.claude/README.md`, prior archived reports for tasks 4 (`manage_claude_settings_with_home_manager`), 13 (`research_nix_mcp_tools`), 19 (`install_setup_mcp_servers_web_development`)

### References
- Upstream `@playwright/mcp` (Microsoft): https://www.npmjs.com/package/@playwright/mcp
- nixpkgs `playwright-mcp` derivation (via this flake's pinned nixos-26.05 input)
- Playwright docs on `--executable-path` / running against a pre-installed browser (standard, well-documented Playwright launch option; not separately fetched in this session — CLI flag presence was verified directly against the built binary instead)
