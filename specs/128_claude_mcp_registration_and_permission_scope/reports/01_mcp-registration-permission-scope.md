# Research Report: Claude MCP Registration and Permission Scope

- **Task**: 128 - Claude MCP registration and permission scope
- **Started**: 2026-09-19T01:14:37Z
- **Completed**: 2026-09-19T01:35:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `modules/home/core/dotfiles.nix` (this repo)
  - `config/claude/settings.json` (this repo)
  - `flake.nix`, `modules/system/packages.nix` (this repo)
  - `~/.claude.json`, `~/.claude/settings.json` (live runtime state on this machine)
  - `/home/benjamin/.config/nvim/agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (sibling agent-system repo — authoritative corroborating design doc)
  - `/home/benjamin/.config/nvim/agent-system/extensions/{web,present,nix,lean}/settings-fragment.json` (sibling agent-system repo)
  - Live `uvx mcp-nixos` MCP handshake (`initialize` response `instructions` field)
  - `claude mcp list` (live command)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- All four items in the dispatch are re-confirmed against current repo/machine state; nothing
  has moved since the dispatch was written. This is a **direct, mechanical implementation task**
  requiring nix/JSON edits plus rebuilds — no design decisions remain open.
- Item 1: `modules/home/core/dotfiles.nix` lines 136-137 still carry the false "(user scope;
  subagents cannot see project-scoped .mcp.json)" justification, contradicted by
  `mcp-server-ownership.md`'s empirically-verified "session-start snapshot trap" section. Comment
  fix only — no mechanism change.
- Item 2: `config/claude/settings.json` line 44 still carries `mcp__lean-lsp__*` in
  `permissions.allow`. Confirmed the agent-system repo's own core `root-files/settings.json` no
  longer carries this wildcard (only `extensions/lean/settings-fragment.json` does), and this
  dotfiles-repo copy was never updated to match.
- Item 3: `config/claude/settings.json` has zero `mcp__playwright__*` entries anywhere. The
  9-tool safe enumeration lives only in the agent-system repo's `web` and `present`
  extensions' `settings-fragment.json` files — both absent from a bare nvim/dotfiles-repo
  session — exactly reproducing `mcp-server-ownership.md`'s documented "Carve-out" and "live
  counter-example" of the scope-mismatch principle.
- Item 4: no `nixos`/`mcp-nixos` entry exists yet in `~/.claude.json` `mcpServers`. Live-ran
  `uvx mcp-nixos`'s MCP `initialize` handshake and confirmed its own advertised `instructions`
  text: "Two tools are exposed: `nix` ... `nix_versions`" — matching the dispatch's VERIFIED
  claim and the two exact grants (`mcp__nixos__nix`, `mcp__nixos__nix_versions`, not a wildcard)
  already present in `agent-system/extensions/nix/settings-fragment.json`. Confirmed `uv` (hence
  `uvx`) is installed via `modules/system/packages.nix` at system scope, so `uvx` resolves at
  `/run/current-system/sw/bin/uvx` without depending on `~/.local/bin`.
- Live `~/.claude.json` currently registers only `playwright` under top-level `mcpServers`
  (confirmed via direct read) and carries ~90 unrelated OAuth/session/telemetry/project-list
  keys that the merge-not-overwrite jq pattern must continue to preserve. `lean-lsp` is
  registered per-project under `.projects["<path>"].mcpServers` (four active projects found),
  not at top level — consistent with the local-scope migration `mcp-server-ownership.md`
  documents; item 4's new jq merge must not disturb this.

## Context & Scope

Task 128 asks for four concrete, previously-verified corrections to this repo's Claude Code MCP
registration (`modules/home/core/dotfiles.nix`) and permission configuration
(`config/claude/settings.json`), plus registration of a new `mcp-nixos`-backed server under the
name `nixos`. The dispatch explicitly states all four items were empirically verified already
and instructs re-confirmation only (not re-derivation) before editing, "since this config may
have moved on." This research phase re-confirmed every claim against current file contents and
live runtime state; none had moved on.

## Findings

### Item 1 — False design-justification comment (`modules/home/core/dotfiles.nix`)

- Confirmed at `modules/home/core/dotfiles.nix:136-137` (not 82-83 as the dispatch estimated —
  the file has grown; the target block is `activation.claudeMcpServers`, currently at lines
  136-164). The comment reads: `"Idempotently merge the playwright MCP server into ~/.claude.json
  (user scope; subagents cannot see project-scoped .mcp.json)."`
- The sibling agent-system repo's `mcp-server-ownership.md` (a design doc this repo's own
  CLAUDE.md Nix-extension section does not reference, but which documents the exact empirical
  disproof the dispatch describes) states under "The session-start snapshot trap": *"An
  already-running session cannot see a server added to `.mcp.json` after that session started —
  and this affects the MAIN session identically to any subagent; it is not a subagent-specific
  limitation,"* and separately, under "Workspace trust": *"Once a workspace is trusted,
  project-scoped servers are fully reachable by dispatched subagents — directly demonstrated,
  twice, including via the general-research-agent class this system actually dispatches, with
  the permission pre-granted so permission was not a confound."*
- The correct rationale for keeping playwright at user scope (per both the dispatch and
  `mcp-server-ownership.md`'s "Choosing a registration surface" section) is: playwright-mcp is a
  Nix-built wrapper binary on `PATH` via `home.packages`, it depends on the machine-level
  `~/.cache/ms-playwright` browser cache, it needs no per-project arguments, and it is useful
  across every repository — i.e. it satisfies the "no per-project computed arguments" branch of
  the registration-surface decision tree, not a subagent-visibility constraint.

### Item 2 — Domain-specific grant at machine scope (`config/claude/settings.json`)

- Confirmed `config/claude/settings.json:44` still carries `"mcp__lean-lsp__*"` inside
  `permissions.allow`, and confirmed this exact string is present in the **live deployed**
  `~/.claude/settings.json` as well (read directly).
- Confirmed the claimed prior fix: `agent-system/extensions/core/root-files/settings.json`'s
  `permissions.allow` array does **not** contain `mcp__lean-lsp__*` (grepped directly, zero
  matches); the grant now lives solely in `agent-system/extensions/lean/settings-fragment.json`
  (`permissions.allow: ["mcp__lean-lsp__*"]`). This corroborates the dispatch's claim that the
  agent-system repo already moved this grant to its domain-specific extension and the
  machine-scope dotfiles copy was simply never updated to match, "because the two live in
  different git repositories with nothing linking them."
- Live consequence check: `~/.claude.json`'s `projects` map currently has four projects
  (`Logos/Theory`, `BimodalLogic`, `cslib`, `cslib-pr648`) each with their own local-scope
  `lean-lsp` entry — these are unaffected by removing the settings.json wildcard; only the
  *permission* grant is removed, not the *registration*. Any repo that relies on lean-lsp tools
  without its own domain-specific grant will begin prompting, as the dispatch already states.

### Item 3 — Missing playwright grants at machine scope (`config/claude/settings.json`)

- Confirmed `config/claude/settings.json` has **zero** `mcp__playwright__*` entries anywhere in
  `permissions.allow`.
- Confirmed `claude mcp list` (live, this session) shows `playwright: playwright-mcp - ✔
  Connected` — registration is fine, only permission is missing, exactly the "Connected, but
  every call prompts" failure row in `mcp-server-ownership.md`'s Composition table.
- Confirmed the exact 9-tool safe enumeration the dispatch specifies is already defined
  identically in two places in the sibling agent-system repo:
  `agent-system/extensions/web/settings-fragment.json` and
  `agent-system/extensions/present/settings-fragment.json` — both containing exactly:
  `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`,
  `browser_network_requests`, `browser_click`, `browser_type`, `browser_find`, `browser_wait_for`.
  `browser_evaluate`, `browser_file_upload`, and `browser_run_code_unsafe` are absent from both,
  matching the dispatch's withhold list exactly.
- `mcp-server-ownership.md`'s "Carve-out" section independently documents why a
  `mcp__playwright__*` wildcard must not be used here: those three withheld tools run arbitrary
  code or move files, and a wildcard would silently re-grant them.
- `mcp-server-ownership.md` itself flags this exact gap as a known, not-yet-fixed issue: *"Fixing
  this asymmetry is a separate follow-up, not performed here — it is recorded, not corrected, by
  this document."* Task 128 item 3 is that follow-up, but it must land in **this** repo's
  `config/claude/settings.json` (the file that actually governs the `~/.claude/settings.json`
  deployed on this machine), not in the agent-system repo, which has no bearing on
  machine-scope permissions unless one of its extensions happens to be loaded in the active
  project.

### Item 4 — Register the NixOS MCP server (`modules/home/core/dotfiles.nix`)

- Confirmed no `nixos` or `mcp-nixos` entry currently exists in live `~/.claude.json`
  `mcpServers` (only `playwright` is present, read directly).
- Confirmed the naming hazard is real and already recorded as a "Migration" note in
  `mcp-server-ownership.md`'s "Known gaps" section: the agent-system repo's own now-deleted dead
  `nix` extension `mcpServers` block previously used the trap name `mcp-nixos`, and that note
  explicitly instructs: *"a home-manager activation block in a separate NixOS configuration
  repository will register the server under the name `nixos`"* — i.e. this dotfiles repo is that
  separate repository, and it must use `nixos`, never `mcp-nixos`.
- Confirmed the two exact grants already exist, unchanged, in
  `agent-system/extensions/nix/settings-fragment.json`: `mcp__nixos__nix` and
  `mcp__nixos__nix_versions` (not wildcarded — this is one of the few servers where the exact
  tool surface is enumerated rather than wildcarded, though for a different reason than
  playwright's safe/unsafe split: it simply mirrors the server's already-small, stable 2-tool
  surface).
- Live-verified the server's tool surface directly: ran `uvx mcp-nixos`'s MCP `initialize`
  handshake in this session. The server's own self-reported `instructions` field states: *"Two
  tools are exposed: `nix` — unified search/info/... `nix_versions` — commit-accurate
  history..."* — confirming the dispatch's VERIFIED claim independently, in addition to trusting
  the prior verification.
- Confirmed the `uvx`-over-`uv-tool-install` PATH claim: `modules/system/packages.nix:66`
  installs `uv` in `environment.systemPackages` (system-level), so `uv`/`uvx` resolve at
  `/run/current-system/sw/bin/`. By contrast, `.claude/scripts/setup-lean-mcp.sh` (and its
  `.opencode/` and agent-system-repo `extensions/lean/scripts/` copies) exists specifically
  because `uv tool install`-placed binaries in `~/.local/bin` need a wrapper to be reliably
  reachable — corroborating why item 4 should use `uvx` directly rather than following the
  `activation.uvTools` (`uv tool install --force lean-lsp-mcp`) pattern already present just
  above the `claudeMcpServers` block at `modules/home/core/dotfiles.nix:130-134`.
- Config to register, verbatim per dispatch: `{"type":"stdio","command":"uvx","args":["mcp-nixos"]}`.

### Live runtime state relevant to the merge implementation

- `~/.claude.json` currently holds ~90 top-level keys beyond `mcpServers`
  (`oauthAccount`, `projects`, `numStartups`, `machineID`, `cachedGrowthBookFeatures`, etc.) —
  concretely confirming why the dispatch insists the jq merge must be additive
  (`.mcpServers.nixos = $cfg`, alongside the existing `.mcpServers.playwright = $cfg` line) and
  never an overwrite of the whole file or the whole `mcpServers` object.
- The existing `activation.claudeMcpServers` block (`modules/home/core/dotfiles.nix:147-164`)
  already has the idempotent merge-via-jq-tmpfile-then-mv shape, the `DRY_RUN` guard matching
  `activation.claudeSettings`'s pattern, and `chmod u+w` after the move. Item 4 is a same-shape
  second `jq --argjson cfg ... '.mcpServers.<name> = $cfg'` line/merge added alongside the
  existing one (either as a second `jq` invocation chained off the first's tmpfile, or a single
  `jq` call that sets both keys in one pass) — the dispatch does not mandate one specific
  sub-shape, only that both properties (idempotent, merge-not-overwrite, `DRY_RUN`-guarded) be
  preserved.

### Verification commands named by the dispatch (all still applicable, none obsolete)

- `home-manager switch --flake .#benjamin` — confirmed as the correct flake output
  (`flake.nix:213`, `homeConfigurations.benjamin`).
- `nixos-rebuild build --flake .#hamsa` — confirmed as the correct host output
  (`flake.nix:153-155`, `hosts.hamsa`).
- `claude mcp list` — live-tested this session; currently shows `playwright` Connected (plus
  four unrelated `claude.ai` HTTP connectors); `nixos` will need to appear after the rebuild.
- `nix flake check` — not yet run in this research phase (left for implementation/verification
  phase per dispatch's own ordering: edit, then rebuild, then verify).

## Decisions

- No open design decisions remain; this task is a direct, four-item mechanical correction plus
  one new registration, all fully specified by the dispatch and independently corroborated by a
  design document in the sibling agent-system repo that predates this task and already records
  three of the four items (the false comment's true rationale, the lean-lsp/core boundary
  violation, and the playwright grant gap) as known, previously-diagnosed issues — with item 4's
  naming trap likewise pre-recorded in that same document's "Known gaps: Migration" note.
- Recommend the implementation phase treat `mcp-server-ownership.md`'s "Grant permissions at the
  same scope where the server is registered" rule as the single governing principle for all four
  items, exactly as the dispatch's own item 3 closing sentence already states.

## Recommendations

1. **Item 1 (comment fix)**: Edit only the comment text at `modules/home/core/dotfiles.nix:136-137`
   (and adjust wording of the still-accurate parts of the surrounding 136-146 comment block as
   needed for flow) to state the true rationale — Nix-built wrapper binary, machine-level
   `~/.cache/ms-playwright` dependency, no per-project args, cross-repo utility — and remove the
   false "(user scope; subagents cannot see project-scoped .mcp.json)" clause. No code change.
2. **Item 2 (settings.json)**: Remove `"mcp__lean-lsp__*"` from `config/claude/settings.json`'s
   `permissions.allow` array (currently line 44).
3. **Item 3 (settings.json)**: Add the 9 enumerated `mcp__playwright__browser_*` tool names
   (listed above, verbatim from the dispatch and cross-checked against
   `agent-system/extensions/web/settings-fragment.json`) to `permissions.allow`. Do not use a
   `mcp__playwright__*` wildcard.
4. **Item 4a (dotfiles.nix)**: Extend `activation.claudeMcpServers` with a second server merge
   registering `nixos` -> `{"type":"stdio","command":"uvx","args":["mcp-nixos"]}`, preserving
   idempotency, merge-not-overwrite, and the `DRY_RUN` guard.
5. **Item 4b (settings.json, dispatch's "Consider also")**: Add `mcp__nixos__nix` and
   `mcp__nixos__nix_versions` (not a wildcard) to `config/claude/settings.json`'s
   `permissions.allow`, mirroring `agent-system/extensions/nix/settings-fragment.json` exactly,
   so the server is usable without prompting in this repo.
6. **Verification order** (per dispatch, all required): `home-manager switch --flake
   .#benjamin` → `claude mcp list` shows both `playwright` and `nixos` Connected → confirm
   `~/.claude.json` still contains its OAuth/session/project keys and the `lean-lsp` per-project
   entries are undisturbed → **start a genuinely new Claude Code session** (per the
   session-start-snapshot trap, a running session cannot observe the new registration) → confirm
   a playwright navigation call and an `mcp__nixos__nix` search call both run without a
   permission prompt, and a `browser_evaluate` call still prompts → `nix flake check` →
   `nixos-rebuild build --flake .#hamsa`.

## Risks & Mitigations

- **Session-start snapshot trap**: testing from the currently-running session (this one, or the
  implementer's own) will produce a false negative for the new `nixos` registration and for the
  new permission grants. Mitigation: the dispatch already mandates a fresh session for
  verification; implementation should not skip this step or trust an in-session test.
- **jq merge correctness**: a malformed second `jq` invocation could corrupt `~/.claude.json`
  (which carries OAuth/session state — ~90 keys observed live). Mitigation: follow the existing
  block's tmpfile-then-`mv` pattern exactly, and verify post-rebuild that `oauthAccount`,
  `projects`, and other pre-existing keys survive (dispatch's own verification step 3).
- **Behavior change from item 2**: removing `mcp__lean-lsp__*` at machine scope will cause any
  repo without its own `mcp__lean-lsp__*` grant to start prompting for lean-lsp tools. This is
  the dispatch's own stated, accepted consequence, not a defect to work around.
- **Wildcard temptation on item 3**: a `mcp__playwright__*` wildcard would silently regrant
  `browser_evaluate`, `browser_file_upload`, and `browser_run_code_unsafe`. The dispatch and
  `mcp-server-ownership.md` both explicitly forbid this; the implementation must enumerate all 9
  tools individually.

## Appendix

- `claude mcp list` output (this session): `claude.ai Claude Docs`, `claude.ai Gmail`,
  `claude.ai Google Drive`, `claude.ai Google Calendar` (all HTTP, unrelated to this task),
  `playwright: playwright-mcp - ✔ Connected`.
- `uvx mcp-nixos` live `initialize` response `serverInfo`: `{"name":"mcp-nixos","version":"3.1.0"}`.
- Live `~/.claude.json` `.projects` keys carrying per-project `lean-lsp` entries: `/home/benjamin/Projects/Logos/Theory`, `/home/benjamin/Projects/BimodalLogic`, `/home/benjamin/Projects/cslib`, `/home/benjamin/Projects/cslib-pr648`.
- Sibling-repo design doc consulted in full:
  `/home/benjamin/.config/nvim/agent-system/extensions/core/context/patterns/mcp-server-ownership.md`.
