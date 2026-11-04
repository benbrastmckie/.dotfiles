# Research Report: Sapience standalone flake and nixpkgs blockers

- **Task**: 137 - Sapience standalone flake and nixpkgs blockers
- **Started**: 2026-11-04T02:44:00Z
- **Completed**: 2026-11-04T02:47:00Z
- **Effort**: ~1 hour (research only)
- **Dependencies**: None
- **Sources/Inputs**:
  - `modules/home/services/sapience.nix` (live module, read in full)
  - `docs/sapience.md` (live design-decision doc, read in full)
  - `home.nix` (live wiring, `programs.sapience` block)
  - `config/claude/settings.json` (hooks/permissions, Sapience entries)
  - `packages/README.md` and `packages/*.nix` (repo's existing package-authoring conventions)
  - `flake.nix` (repo's existing input/output conventions, `follows` usage)
  - Live files on disk: `~/.sapience/*.py` (the 10 vendor client files, grepped for license text)
  - Live HTTP probes: `https://app.spnc.ai/{extract_local.py,mcp.py,/,version,manifest,install.sh,VERSION,version.json,/api/version,terms,tos,legal,license,privacy}`
  - Live HTTP probes: `https://pypi.org/pypi/{sapience-ai,spnc}/json`
  - Web search: nixpkgs `meta.license` / `unfreeRedistributable` contribution requirements
- **Artifacts**: this report
- **Standards**: report-format.md, artifact-formats.md, nix.md

## Executive Summary

- A standalone flake is straightforward to build: the vendor payload is 10 pure-stdlib Python 3
  files with no third-party imports and no build step, so the packaging work is entirely in the
  Nix wrapper/module layer already written in `modules/home/services/sapience.nix` — it needs
  **copying and generalizing**, not re-architecting.
- Three concrete generalizations close the "works on my machine" gap: flip `backend`'s default
  from `"ollama"` to `"relay"` (the vendor default — no local inference server assumed), flip
  `memoryFiles`'s default from `false` to `true` (vendor default — this repo's `false` is a
  repo-specific decision about generated `.claude/` deploy artifacts), and drop the
  `/home/benjamin/...`-shaped `apiKeyFile` example string. `model`'s default (`""`) already
  matches the vendor default and needs no change.
- The ollama-journal progress ticker in `sapience-bootstrap` is already gated on
  `cfg.backend == "ollama"` in the live module, but that gate is insufficient once genericized:
  it assumes the local Ollama daemon is a **home-manager-managed, systemd `--user`** unit
  (`journalctl --user -u ollama`), which is silently empty against a **system-level** NixOS
  `services.ollama`, and doesn't exist at all for the proposed `packages.<system>.*` (non-home-manager)
  outputs, which have no `config.*` to probe. Recommend widening the module gate to
  `cfg.backend == "ollama" && config.services.ollama.enable` (mirroring the existing warning's
  condition) and, for the standalone package variant, a runtime `systemctl --user is-active
  --quiet ollama.service` probe instead of an evaluation-time one.
- nixpkgs inclusion is blocked by three independent, individually-sufficient reasons, each
  confirmed live today: no license grant anywhere, nothing hashable upstream, and an invite-only
  private beta with Mac-only official support. Evidence for all three is gathered below with
  exact HTTP responses and file contents, not just the design doc's prose summary.
- Two concrete, narrow asks to the vendor would remove two of the three blockers: publish
  versioned, checksummed release artifacts under the two PyPI names CoreTx has already reserved
  (`sapience-ai`, `spnc`), and publish a license statement that permits redistributing the build
  output (which would let a future nixpkgs package carry `lib.licenses.unfreeRedistributable`
  instead of plain `unfree`, and be substituted from Hydra's cache rather than built locally by
  every user who opts in with `allowUnfree`). The invite-only/macOS-only blocker is a product
  decision the vendor would need to lift separately; no Nix-side ask addresses it.

## Context & Scope

Task 137 asks for a self-contained, shareable directory (e.g. `packages/sapience-flake/`)
carrying its own `flake.nix`, a generalized copy of `modules/home/services/sapience.nix`, and a
`README.md` — isolated from the live home-manager config so it can be handed to the vendor
(CoreTx Inc. / Sapience Labs) as-is. This research phase gathers the evidence and design
groundwork a later plan/implementation phase needs; it does not itself write the flake.

**Hard constraint, verified respected by this research**: nothing in
`modules/home/services/sapience.nix` or `home.nix` was modified. All reads were read-only; the
only writes this phase made are this report and `.return-meta.json`.

**In scope for the eventual flake** (per the dispatch): `homeManagerModules.sapience`,
`packages.<system>.{sapience,sf1,sapience-bootstrap}`, the three default-value generalizations,
the ticker gating fix, documentation of the Claude Code hooks/statusline gap, and the nixpkgs
blockers README with evidence and the two concrete asks.

**Out of scope**: actually writing the flake files (next phase), contacting the vendor, and
resolving the ticker-gating fix in code (flagged here as a finding for the plan to act on).

## Findings

### Existing Configuration — what already exists to vendor

- `modules/home/services/sapience.nix` (918 lines) defines `options.programs.sapience` and three
  wrapper binaries (`sapienceCli`, `sf1Cli`, `sapienceBootstrap`) built with
  `pkgs.writeShellScriptBin`, plus home-manager `config` glue: `home.packages`,
  `home.activation.{sapiencePayload,sapienceTokenRepair,sapienceApiKey,sapienceMcpServer}`,
  and `systemd.user.services.sapience-sync` / `systemd.user.timers.sapience-sync`. All of this is
  pure Nix/shell — no third-party Nix inputs beyond `pkgs.{coreutils,curl,gawk,gitMinimal,
  gnugrep,procps,python3,systemd,util-linux,jq,gnused}`, all of which are in any nixpkgs channel.
- The vendor payload itself is **never packaged as a Nix derivation** — `home.activation.sapiencePayload`
  seeds `~/.sapience/*.py` via `curl` only when a file is absent, and the module's own header
  comment states this is deliberate ("do not 'fix' the payload into a fetchurl derivation").
  This same mutable-seed strategy is exactly what the standalone flake should also use, both
  for `homeManagerModules.sapience` and for the `packages.<system>.*` wrappers, since the
  underlying reason (no hashable upstream artifact) applies identically outside this repo — see
  "Nothing hashable upstream" below.
- `home.nix` (lines 29-50) shows the live call site: `programs.sapience.enable = true;` with
  `backend = "ollama"`, `model = "gemma4:cloud"`, and comments explaining each choice is a
  *this-machine* decision, not a vendor default. This confirms the three fields the dispatch
  names as needing generalization are exactly the fields this machine deliberately overrides.
- `config/claude/settings.json` carries three Sapience-owned hook entries and seven
  `mcp__sapience__*` permission grants, none of which live in `modules/home/services/sapience.nix`:
  - `permissions.allow`: `mcp__sapience__sapience`, `sapience_search`, `sapience_briefing`,
    `sapience_context`, `sapience_ask`, `sapience_outstanding`, `sapience_papers` (7 grants).
  - `hooks.SessionStart` (3rd matcher-less entry): `[ -f "$HOME/.sapience/mcp.py" ] && python3
    "$HOME/.sapience/mcp.py" --briefing-text 2>/dev/null || true`
  - `hooks.SessionEnd` (2nd entry, `async: true`): `... --receipt 2>/dev/null || true`
  - `hooks.Stop` (`timeout: 3`): `... --effect-line 2>/dev/null || true`
  - A `_SAPIENCE_NOTE` key in the same file states why: `home.activation.claudeSettings` treats
    `hooks` and `permissions` as *enforced* keys that get reset from this repo file on every
    `home-manager switch`, so nothing a vendor installer (or a Nix module) writes directly into
    the live `~/.claude/settings.json` would survive. `statusLine` is explicitly *not* wired to
    Sapience at all; that slot is reserved for `hooks/statusline-push.sh` in this repo's separate
    agent-system source store.
  - **Consequence for the flake**: a consumer who only takes `homeManagerModules.sapience` (or
    the `packages.<system>.*` outputs) gets the CLI, the sync unit, and the MCP server
    registration into `~/.claude.json` — but gets *no* per-turn visibility (no session-start
    briefing, no session-end receipt, no stop-hook effect line) and no statusline segment,
    because those three hooks and the permission grants are Claude-Code-settings concerns that
    this repo deliberately keeps outside the home-manager module (for the enforced-key reason
    above) and that the flake has no equivalent mechanism for. This must be documented in the
    flake's README as a known gap, with the exact three hook commands given above so a consumer
    can paste them into their own `~/.claude/settings.json` if they want the same visibility.

### Generalization 1 — `backend` default

- Live default (line 552 of the module): `default = "ollama";`. The option's own description
  already says `"ollama"` is *this repository's* choice ("Defaults to \"ollama\" here rather than
  the vendor's \"relay\" because this repository's Claude Code transcripts are the input
  corpus"), and the vendor's own default is `"relay"`.
- A stranger who clones the flake and enables the module with no local Ollama server would hit
  the build-time `warnings` entry (line 668-674: "backend is \"ollama\" but services.ollama.enable
  is false, so every sync will extract nothing") on every rebuild until they either set up Ollama
  or change the backend — a bad first experience for a shareable artifact.
- **Recommendation**: vendored copy's default `backend = "relay"`, matching the vendor's own
  zero-setup default (chunks redacted and sent through `app.spnc.ai` to Anthropic at the vendor's
  expense, no local server and no API key required). Document in the README that `relay` is
  the only backend where the vendor sees transcript chunks (pre-review), citing the privacy
  table already written in `docs/sapience.md`.

### Generalization 2 — `memoryFiles` default

- Live default (line 639): `default = false;`, with the description stating plainly this is
  *against the vendor default* because this specific repo's `.claude/` trees are generated
  deploy artifacts duplicated across 20+ repositories (see `docs/sapience.md`'s "Memory-file
  ingestion is off" section) — a repo-specific hazard that does not generalize to an arbitrary
  flake consumer's project.
- **Recommendation**: vendored copy's default `memoryFiles = true`, the vendor default, with a
  description explaining *why* this repo overrides it (so a consumer who copies this pattern
  understands the override is conditional on their own `CLAUDE.md`/`AGENTS.md` being
  hand-authored "curated truth" rather than generated scaffolding).

### Generalization 3 — `model` default and the hardcoded path example

- `model`'s live default (line 598-601) is already `default = "";` — this matches the vendor
  default (empty keeps the client's own per-backend default) and needs **no change** in the
  vendored copy. The dispatch text listing "model default empty" as a generalization target is
  satisfied by the status quo; no edit is needed here, only confirmation.
- The hardcoded machine-specific string is `apiKeyFile`'s `example` field (line 584):
  `example = "/home/benjamin/.config/sapience/openai-key";`. This is this machine's home
  directory baked into documentation text visible to every consumer of the vendored module.
- **Recommendation**: replace with a generic placeholder, e.g.
  `example = "/home/YOUR_USER/.config/sapience/openai-key";` or
  `example = "/run/secrets/sapience_openai_key";` (consistent with `tokenFile`'s existing
  generic `/run/secrets/sapience_token` example one field up, which needs no change).

### Ticker gating — already gated, but on the wrong predicate for a generalized consumer

- The progress ticker (lines 379-481) is launched only inside
  `${lib.optionalString (cfg.backend == "ollama") ''...''}` (line 476) — so on `relay`,
  `anthropic`, or `openai` backends, the `if [ -t 2 ]; then ticker ... fi` block is already
  omitted from the generated script entirely (not merely skipped at runtime). This much of the
  dispatch's ask is **already satisfied** on the live module and simply carries over unchanged
  to the vendored copy once `backend`'s *default* flips to `"relay"` (Generalization 1) — most
  flake consumers will never generate the ticker code at all.
- The gap is the "against a system-level ollama" half of the ask. The ticker's signal source is
  `journalctl --user -u ollama` (line 388) — a **systemd user-scope** unit. That unit exists only
  when the consumer's Ollama is managed by home-manager's own `services.ollama` module (which
  this repo's `modules/home/services/ollama.nix` wraps as `services.ollamaModels`, confirmed by
  grepping that file: it sets `services.ollama = { ... }` at line 71, home-manager's own upstream
  option). A consumer running Ollama as a **NixOS system service** instead (`services.ollama.enable`
  at the system/module level, a different, non-home-manager option of the same dotted name) logs
  to the **system** journal under a system-scope unit; `journalctl --user -u ollama` against that
  setup finds nothing and the ticker silently prints no lines for the whole bootstrap run —
  functionally dead code: it still forks a 30-second-interval polling loop (`kill -0 "$watch_pid"`)
  for the run's entire duration, consuming a background process and a `trap`/`cleanup` path, for
  zero observable benefit.
- **Recommendation for the plan/implementation phase**: in `homeManagerModules.sapience`, widen
  the ticker's launch gate from `cfg.backend == "ollama"` to
  `cfg.backend == "ollama" && config.services.ollama.enable`, mirroring the existing build-time
  `warnings` predicate at line 669 exactly (same reasoning: that option is only `true` when
  home-manager's own `services.ollama` module — a user-scope unit — is what's running). For the
  `packages.<system>.sapience-bootstrap` standalone package output, there is no `config.*` to
  evaluate against at all (it is a plain derivation, not a home-manager module), so the
  equivalent check must happen at **runtime** inside the generated script, e.g. a
  `systemctl --user is-active --quiet ollama.service 2>/dev/null` guard immediately before the
  `ticker ... &` launch, falling back to a one-line "progress ticker unavailable: no user-scope
  ollama.service found" notice rather than silently starting a loop that will never print.

### Claude Code hooks/statusline gap — see "Existing Configuration" above

Fully covered above; restated here only to flag it explicitly as dispatch requirement (4). The
flake's README must state, in the vendor-facing language the dispatch requests, that the flake
delivers the MCP server (so `mcp__sapience__*` tools are *reachable* once a consumer merges the
registration into their own `~/.claude.json`) but not the per-turn hooks or statusline segment,
because those are Claude Code *settings* concerns this repo keeps in a separate, repo-specific,
enforced-key file (`config/claude/settings.json`) rather than in the portable Nix module, and the
flake has no analogous settings file to ship. The three exact hook commands are quoted above so
the README can give them verbatim as a copy-paste starting point.

### nixpkgs blocker 1 — no license grant anywhere

All three sub-claims verified live, not merely asserted from `docs/sapience.md`'s prose:

- **No headers in the client files.** `grep -ilE "license|copyright|proprietary|all rights
  reserved" *.py` against the live `~/.sapience/*.py` directory (all 10 files:
  `extract_local.py`, `mcp.py`, `sapience_adddir.py`, `sapience_capture.py`, `sapience_devin.py`,
  `sapience_filter.py`, `sapience_redact.py`, `sapience_upkeep.py`, `sf1.py`, `upload.py`)
  returned **zero matches** — none of the four license-adjacent terms appears in any file.
- **No LICENSE or ToS on the site.** Live HTTP probes against `https://app.spnc.ai/{terms,tos,
  legal,license,privacy}` all returned `HTTP 404`.
- **Patents claimed.** The site's root HTML (`https://app.spnc.ai/`, fetched live) contains the
  sentence: *"We have filed patents covering the architecture."* — an explicit patent claim
  layered on top of the absent copyright license.
- **PyPI reservations declare `Proprietary`.** Live queries against
  `https://pypi.org/pypi/{sapience-ai,spnc}/json` both return `version: 0.0.1`,
  `license: Proprietary`, `summary: "Reserved by CoreTx Inc. Package under development."` — the
  vendor's own packaging metadata, for both names it has reserved, states the opposite of an
  open license.
- **nixpkgs policy grounding** (web search, "nixpkgs manual contributing guidelines unfree
  unfreeRedistributable license requirement package"): nixpkgs' contribution requirements state
  `meta.license` must be set to match the upstream license, defaulting to `unfree` when no
  upstream license can be determined at all. With zero license grant of any kind, a nixpkgs
  submission's only legally defensible `meta.license` value is `lib.licenses.unfree` — which, per
  the same policy, means Hydra does not build or cache it and every user must opt in with
  `allowUnfree` by hand. This is before even reaching blockers 2 and 3.

### nixpkgs blocker 2 — nothing hashable upstream

- **No caching headers.** Live `curl -D -` against both `https://app.spnc.ai/extract_local.py`
  and `.../mcp.py` returned `cache-control: no-cache, no-store, must-revalidate` (stronger than
  the dispatch text's "no-cache" alone) with **no `etag`** header and **no `last-modified`**
  header in either response.
- **No version/manifest/install endpoint.** Live probes against `/version`, `/manifest`,
  `/install.sh`, `/VERSION`, `/version.json`, and `/api/version` all returned `HTTP 404` —
  there is no server-side way to ask "what version is this?" or "what files make up a release?"
  independent of fetching and hashing each file by hand.
- **The client treats a live sha256 comparison as its version.** `sapience_upkeep.py` (per
  `docs/sapience.md`'s "Design decisions" section, consistent with the file's own docstring
  observed on disk: *"keep this computer's Sapience client current"*) computes a per-file sha256
  and compares it against what the server currently serves to decide whether to self-update; it
  self-updates on two paths (`sapience update`, and a background auto-update `mcp.py` spawns on
  its own) and honours a server-side `CLIENT_AUTO_UPDATE=0` kill switch. A `fetchurl` derivation
  pinned to today's hash would (a) break the instant the vendor pushes any edit to `app.spnc.ai`,
  with no warning and no version bump to signal the change, and (b) actively fight the client's
  own updater, which would try to overwrite the pinned, read-only Nix-store copy on every machine
  that has it installed.

### nixpkgs blocker 3 — invite-only private beta, macOS-only official support

- **Private beta confirmed live.** The site's root HTML states: *"Sapience is in private beta.
  Start with your invite code and name."* and *"No code yet? Ask for an invite"* (a `mailto:`
  link to `oliver@coretx.ai`).
- **macOS-only official install path confirmed live.** The same page: *"Use Claude Code or Codex
  on your machine? The terminal install is the fuller path... Mac + Python 3 · about ten
  minutes."* — the vendor's own stated platform requirement for the terminal install is
  Mac-plus-Python-3, with no Linux/NixOS path mentioned anywhere on the page.
- **Practical consequence for nixpkgs, not a quoted written rule**: web search for an explicit
  written nixpkgs policy against invite-only or beta-gated software turned up no such rule
  stated in so many words. The blocker here is practical rather than textual: nixpkgs packages
  are built and tested by anonymous CI (Hydra) and reviewed by maintainers who, for an
  invite-only service, cannot obtain an account to verify the package actually works, and the
  package would be useless to the overwhelming majority of nixpkgs' Linux userbase even if it
  built, since the vendor's own only-tested platform is macOS. This is the same framing
  `docs/sapience.md`'s existing "Design decisions" section already uses ("fails nixpkgs'
  userbase and testability expectations"); this research adds the live beta-copy and
  Mac-and-Python-3 quotes as direct textual evidence rather than relying on that document's
  paraphrase alone.

### The two concrete asks — and what each one would unblock

1. **Publish versioned, checksummed release artifacts under the two already-reserved PyPI
   names** (`sapience-ai`, `spnc` — both confirmed live as `0.0.1` placeholders reserved by
   CoreTx Inc.). This directly answers blocker 2: a real PyPI release gives `fetchurl`/
   `fetchPypi` a stable, versioned, sha256-checkable artifact that does not change under a
   pinned hash, decoupling packaging from the live, mutable `app.spnc.ai` payload entirely.
2. **State a license permitting redistribution of the build output.** This directly answers (part
   of) blocker 1: it would not need to be a fully open-source license — nixpkgs' own
   `lib.licenses.unfreeRedistributable` exists exactly for unfree software whose *build output*
   may legally be redistributed (as opposed to plain `unfree`, where only the source/build
   inputs may be redistributed and every user must build or fetch it themselves under
   `allowUnfree`). Securing that single statement would let a future nixpkgs package be built
   once by Hydra and substituted from the binary cache for everyone, rather than every user
   re-fetching and re-verifying the payload by hand.
   Neither ask touches blocker 3 (invite-only beta, macOS-only official support) — that remains
   a product/business decision the vendor would need to make independently, and no Nix-side
   change can route around it.

## Decisions

- The vendored module copy will be a near-verbatim copy of `modules/home/services/sapience.nix`
  with exactly three value-level changes (`backend` default `"ollama"` → `"relay"`,
  `memoryFiles` default `false` → `true`, `apiKeyFile` example path de-machine-specific-ized) and
  one behavioral change flagged for the implementation phase (ticker gate widened to also check
  `config.services.ollama.enable`, plus a runtime-probe equivalent for the standalone package
  variant). `model`'s default needs no change.
- The flake's `packages.<system>.*` outputs are feasible as plain `pkgs.writeShellScriptBin`
  derivations extracted from the module's existing `let`-bound `sapienceCli`/`sf1Cli`/
  `sapienceBootstrap` definitions, parameterized by function arguments standing in for `cfg.*`
  (no home-manager dependency required for this output set) — mirroring this repo's own
  `packages/*.nix` convention of one file per package, callPackage'd rather than hand-wired.
- The README will document the Claude Code hooks/statusline gap by name, with the three exact
  hook commands and the seven permission grant names given above, rather than a vague pointer.
- The nixpkgs-blockers README section will cite the live evidence gathered in this report
  (HTTP responses, PyPI JSON, grep results, the patents sentence) rather than only restating
  `docs/sapience.md`'s existing prose, so the vendor-facing document is independently verifiable.

## Risks & Mitigations

- **Drift between the live module and the vendored copy.** Two independent copies of
  substantially the same ~900-line file will diverge over time as the live module gets bugfixes.
  Mitigation: have the vendored copy's header comment note it is a generalized fork of
  `modules/home/services/sapience.nix` as of this task, and recommend a periodic manual diff
  rather than attempting any automated sync (over-engineering for a one-off shareable artifact).
- **The ticker-gating fix is non-trivial for the `packages.<system>.*` variant** because that
  output has no `config.*` evaluation context at all, unlike the home-manager module. Mitigation:
  implementation phase should treat the runtime `systemctl --user is-active --quiet
  ollama.service` probe (rather than any evaluation-time check) as the only viable mechanism for
  that output, and accept it as "best effort" consistent with every other external-call guard
  already in this module (e.g., the warning emitted when a fetch fails during activation).
- **The vendor payload remains unpinned/mutable in the standalone flake too**, for the same
  reason it is unpinned in the live module (blocker 2 above) — this is not a defect to fix but a
  property to document prominently in the README so a flake consumer does not mistake the
  absence of a pinned derivation for an oversight.

## Appendix

- `grep -ilE "license|copyright|proprietary|all rights reserved" *.py` against `~/.sapience/*.py` → no matches, 10/10 files.
- `curl -s -D - -o /dev/null https://app.spnc.ai/extract_local.py` and `.../mcp.py` →
  `cache-control: no-cache, no-store, must-revalidate`, no `etag`, no `last-modified`.
- `curl -s -o /dev/null -w "HTTP %{http_code}\n" https://app.spnc.ai/{version,manifest,install.sh,VERSION,version.json,/api/version,terms,tos,legal,license,privacy}` → all `404`.
- `curl -s https://pypi.org/pypi/{sapience-ai,spnc}/json` → both `{"version":"0.0.1","license":"Proprietary","summary":"Reserved by CoreTx Inc. Package under development."}`.
- `curl -s https://app.spnc.ai/` → contains `We have filed patents covering the architecture.`,
  `Sapience is in private beta. Start with your invite code and name.`, and
  `Mac + Python 3 · about ten minutes.`
- Web search: "nixpkgs manual contributing guidelines unfree unfreeRedistributable license
  requirement package" (standard mode) — grounds the `meta.license`/`unfreeRedistributable`
  framing in the two concrete asks.
- Web search: "nixpkgs reject package invite only beta private access requirement testable by
  maintainers" (standard mode) — no explicit written rule found; blocker 3's framing is
  practical-consequence reasoning, flagged as such above rather than attributed to a citation.
