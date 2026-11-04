# Implementation Plan: Sapience standalone flake and nixpkgs blockers

- **Task**: 137 - Sapience standalone flake and nixpkgs blockers
- **Status**: [NOT STARTED]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: specs/137_sapience_standalone_flake_and_nixpkgs_blockers/reports/01_standalone-flake-nixpkgs-blockers.md
- **Artifacts**: plans/01_standalone-flake-nixpkgs-blockers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, nix.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Build a self-contained, vendor-shareable directory at `packages/sapience-flake/` carrying its own
`flake.nix`, a generalized fork of `modules/home/services/sapience.nix`, a shared wrapper builder
that lets the same script bodies back both `homeManagerModules.sapience` and
`packages.<system>.{sapience,sf1,sapience-bootstrap}`, and a `README.md` that documents the
Claude Code hooks/statusline gap and states — with the live evidence the research phase gathered —
why a nixpkgs submission is impossible today plus the two narrow vendor asks that would unblock
two of the three blockers. The work is entirely additive: the live
`modules/home/services/sapience.nix` and `home.nix` must come out of this task byte-identical, and
that is checked as an explicit gate in the final phase rather than assumed.

Definition of done: the directory evaluates and builds as a standalone flake when copied out of
this repository entirely, the parent repo's own Nix gates still pass, and the two protected files
show an empty diff.

### Research Integration

The research report (`reports/01_standalone-flake-nixpkgs-blockers.md`) is integrated as follows:

- **The vendored copy is a copy, not a re-architecture.** The report establishes the payload is 10
  pure-stdlib Python files with no build step, so all packaging value already exists in the
  module's Nix/shell layer. Phase 1 therefore vendors the module verbatim before any edit, so the
  generalization diff is auditable in isolation.
- **Exactly three value-level generalizations**, per the report's Decisions section: `backend`
  default `"ollama"` -> `"relay"`, `memoryFiles` default `false` -> `true`, and the `apiKeyFile`
  `example` string de-machine-specific-ized. `model`'s default is already `""` and matches the
  vendor default — the report confirms this needs **no change**, so Phase 2 only verifies it.
- **The ticker gate is already `cfg.backend == "ollama"`**, so the dispatch's "not dead code on
  relay/anthropic/openai" half is already satisfied and carries over for free. The real gap the
  report identifies is the *system-level ollama* case: the ticker's signal source is
  `journalctl --user -u ollama`, a user-scope unit that does not exist under a NixOS
  `services.ollama`. Phase 3 widens the module gate to also require
  `config.services.ollama.enable` and adds a runtime `systemctl --user is-active` probe for the
  package output, which has no `config.*` to evaluate against at all.
- **The hooks/statusline gap is documented with exact text, not a vague pointer**: the three hook
  commands (`--briefing-text`, `--receipt`, `--effect-line`) and the seven `mcp__sapience__*`
  permission grants the report quotes from `config/claude/settings.json` go into the README
  verbatim as copy-paste material.
- **The nixpkgs blockers section cites the report's live evidence** (HTTP status codes, response
  headers, PyPI JSON, the grep result, the patents/beta/macOS sentences) rather than restating
  `docs/sapience.md`'s prose, so the vendor-facing document is independently verifiable.
- **The payload stays unpinned in the standalone flake too**, which the report frames as a property
  to document prominently, not a defect to fix.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but was not passed as `roadmap_path` for this dispatch, and a search of
it for `sapience` and `flake` returns no matches. No roadmap items are advanced or affected by
this task.

## Goals & Non-Goals

**Goals**:
- A self-contained `packages/sapience-flake/` directory that is shareable with the vendor as-is:
  copy the directory anywhere and it evaluates and builds on its own.
- `homeManagerModules.sapience` (plus `homeManagerModules.default`) exposing a generalized fork of
  the live module with working vendor defaults for a stranger.
- `packages.<system>.{sapience,sf1,sapience-bootstrap}` (plus `packages.<system>.default`) for
  consumers who do not use home-manager, built from the same script bodies as the module.
- The three generalizations and the ticker-gating fix from the research report, landed in the
  vendored copy only.
- A `README.md` documenting usage, the privacy consequence of the `relay` default, the mutable
  payload property, the Claude Code hooks/statusline gap with exact commands, the three nixpkgs
  blockers with live evidence, and the two concrete vendor asks.
- Zero behavioural change on this machine.

**Non-Goals**:
- Any edit to `modules/home/services/sapience.nix` or `home.nix` (hard constraint).
- Pinning the vendor payload into a `fetchurl`/`fetchPypi` derivation — impossible today
  (blocker 2) and explicitly warned against by the live module's own header.
- Any automated sync mechanism between the live module and the vendored copy.
- Contacting the vendor, or submitting anything to nixpkgs.
- Shipping Claude Code `settings.json` hooks from the flake (the gap is documented, not closed).
- Registering the new directory into the parent flake's outputs or overlays — it is a nested,
  independent flake, deliberately not wired into `nixosConfigurations`/`homeConfigurations`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Vendored copy drifts from the live module as the live one gets bugfixes | M | H | Header comment in the vendored copy names it a generalized fork of `modules/home/services/sapience.nix` as of this task, with the source path and a recommendation to diff manually; no automated sync (over-engineering for a one-off shareable artifact) |
| `stateDir` is evaluation-time (`config.home.homeDirectory`) in the module but must be runtime (`$HOME`) in the package output | H | H | Phase 4 parameterizes `stateDir` as a string argument to the shared builder; the package output passes a shell-expanded `"$HOME/.sapience"`. Every interpolation of it inside the scripts must be double-quoted, which Phase 4 audits explicitly rather than assuming |
| Nix flake commands inside a git repo ignore untracked files, so the nested flake appears empty/missing | H | H | Phase 7 verifies from a copy placed **outside** this repository (fresh `git init`), which both sidesteps the untracked-file issue and is the truer test of "shareable as-is"; in-repo evaluation uses `git add -N` if attempted at all |
| A nested `flake.nix` under `packages/` breaks parent-repo evaluation or tooling | M | L | Confirmed live during planning: no `readDir`/glob consumes `packages/`; every package is explicitly `callPackage`d in `overlays/unstable-packages.nix`, and `packages/opencode-discord-bot/` is existing precedent for a subdirectory. Phase 7 still runs the parent `nix flake check` as the gate |
| Extracting the shared wrapper builder silently changes generated script text for the module path | H | M | Phase 4 verifies by rendering the module's wrapper derivations before and after the extraction and diffing the generated script bodies, not by reading the Nix source alone |
| `nix fmt` (nixfmt RFC 166) reformats the new files, producing churn or a failing format check | L | M | Each Nix-authoring phase runs `nixfmt --check` on its own files before closing |
| README overstates a blocker beyond what the research actually verified | M | M | Blocker 3 is written as practical-consequence reasoning and labelled as such (the report found no written nixpkgs rule); every other claim carries the exact probe or quote the report recorded |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 2, 3
and 4 all edit the same vendored module file, Phase 5 depends on the builder signature Phase 4
fixes, Phase 6's usage snippets must match the outputs Phase 5 actually names, and Phase 7 is the
closing gate.

---

### Phase 1: Scaffold the directory and vendor a verbatim module copy [NOT STARTED]

**Goal**: Establish `packages/sapience-flake/` with an unmodified copy of the live module, so every
later generalization shows up as a reviewable diff against a known baseline.

**Tasks**:
- [ ] `mkdir -p packages/sapience-flake/modules packages/sapience-flake/lib`
- [ ] Copy `modules/home/services/sapience.nix` to
      `packages/sapience-flake/modules/sapience.nix` byte-for-byte (`cp`, no edits)
- [ ] Confirm the copy is identical: `diff modules/home/services/sapience.nix
      packages/sapience-flake/modules/sapience.nix` prints nothing
- [ ] Record the baseline line count and the live module's git blob hash
      (`git hash-object modules/home/services/sapience.nix`) in the vendored copy's commit message,
      so a future manual diff has a precise anchor
- [ ] Confirm the live module and `home.nix` are untouched: `git status --short modules/home/services/sapience.nix home.nix`
      is empty

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the live module is 917 lines (measured during planning; the research report
says 918, a one-line discrepancy that is itself evidence counts must be re-measured). Confirm at
implementation time with `wc -l modules/home/services/sapience.nix` and use the measured value,
not either quoted number.

**Files to modify**:
- `packages/sapience-flake/modules/sapience.nix` - new file, verbatim copy of the live module

**Verification**:
- `diff modules/home/services/sapience.nix packages/sapience-flake/modules/sapience.nix` exits 0
  with no output
- `git status --short modules/home/services/sapience.nix home.nix` is empty

---

### Phase 2: Generalize the vendored module's defaults and header [NOT STARTED]

**Goal**: Replace this-repo-specific choices in the vendored copy with the vendor's own defaults so
a stranger who enables the module gets a working, zero-setup configuration, and retarget the header
comment at a flake consumer rather than at this repository.

**Tasks**:
- [ ] `backend`: change `default = "ollama";` to `default = "relay";` and rewrite the option
      description — it currently explains *this repository's* choice; the vendored copy's
      description states `relay` is the vendor's zero-setup default (no local inference server, no
      API key) and notes `relay` is the one backend where the vendor sees redacted transcript
      chunks before any review gate
- [ ] `memoryFiles`: change `default = false;` to `default = true;` (the vendor default) and
      rewrite the description to explain the override is conditional on the consumer's
      `CLAUDE.md`/`AGENTS.md` being hand-authored rather than generated scaffolding
- [ ] `apiKeyFile`: replace `example = "/home/benjamin/.config/sapience/openai-key";` with
      `example = "/run/secrets/sapience_openai_key";`, matching `tokenFile`'s existing generic
      example one field up
- [ ] Verify `model`'s default is already `default = "";` and leave it unchanged; note the
      confirmation in the commit message so the dispatch item is visibly closed rather than skipped
- [ ] Rewrite the file header comment: name it a generalized fork of
      `modules/home/services/sapience.nix` as of this task, keep the "do not fix the payload into a
      fetchurl derivation" warning and the token-never-in-the-store note, and replace the
      repo-internal cross-references (`docs/sapience.md`, `config/claude/settings.json`,
      `hooks/statusline-push.sh`, the `services/cache-cleanup.nix` shape precedent) with pointers to
      this flake's own `README.md`
- [ ] Grep the whole vendored file for any remaining `/home/benjamin`, `benjamin`, `.dotfiles`, or
      `docs/sapience.md` occurrence and resolve each one
- [ ] `nixfmt --check packages/sapience-flake/modules/sapience.nix`

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: exactly three value-level changes are needed (`backend` default,
`memoryFiles` default, `apiKeyFile` example), with `model` needing none. Confirm by grepping the
vendored copy for `default = ` and `example = ` across all of `options.programs.sapience` and
re-reading each hit, rather than trusting this enumeration; and confirm the machine-specific-string
sweep finds no fourth occurrence beyond `apiKeyFile`'s example.

**Files to modify**:
- `packages/sapience-flake/modules/sapience.nix` - three option defaults/examples changed, their
  descriptions rewritten, file header retargeted at a flake consumer

**Verification**:
- `grep -n 'default = "relay"' packages/sapience-flake/modules/sapience.nix` matches inside the
  `backend` option
- `grep -n 'default = true' packages/sapience-flake/modules/sapience.nix` matches inside the
  `memoryFiles` option
- `grep -rniE 'benjamin|\.dotfiles|docs/sapience\.md' packages/sapience-flake/modules/sapience.nix`
  returns nothing
- `diff modules/home/services/sapience.nix packages/sapience-flake/modules/sapience.nix` shows only
  the intended hunks (header, three options) and nothing else
- `nixfmt --check` passes on the file

---

### Phase 3: Fix the ollama progress-ticker gating [NOT STARTED]

**Goal**: Stop the bootstrap ticker from forking a 30-second polling loop that can never print a
line — both in the module (where a system-level `services.ollama` leaves
`journalctl --user -u ollama` permanently empty) and in the script body the standalone package
output will reuse (where there is no `config.*` to evaluate at all).

**Tasks**:
- [ ] In the vendored module, widen the ticker launch gate from
      `lib.optionalString (cfg.backend == "ollama")` to also require
      `config.services.ollama.enable`, mirroring the existing build-time `warnings` predicate
      exactly (same reasoning: that option is only true when home-manager's own `services.ollama`
      module — a user-scope unit — is what runs)
- [ ] Add a runtime guard immediately before the `ticker "$run_started" "$$" &` launch:
      `systemctl --user is-active --quiet ollama.service 2>/dev/null`, so the generated script is
      correct even when it is produced without any evaluation-time knowledge of the consumer's
      Ollama setup
- [ ] On the runtime guard's negative branch, print one line to stderr
      (`progress ticker unavailable: no user-scope ollama.service found`) instead of silently
      starting a loop that will never emit
- [ ] Confirm the guard cannot leave a stale `ticker_pid`: `ticker_pid` must stay empty on the
      negative branch so the existing `cleanup`/`trap` path remains a no-op
- [ ] Re-read the surrounding comment block (it explains why the ticker watches the shell rather
      than the extraction) and extend it to state why the gate is now two-part
- [ ] `nixfmt --check packages/sapience-flake/modules/sapience.nix`

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: the ticker has exactly one launch site (inside the single
`lib.optionalString (cfg.backend == "ollama")` block in `sapienceBootstrap`) and one signal source
(`journalctl --user -u ollama`). Confirm with
`grep -n 'ticker\|journalctl' packages/sapience-flake/modules/sapience.nix` and handle every hit
the grep reports, not only the one this plan names.

**Files to modify**:
- `packages/sapience-flake/modules/sapience.nix` - ticker launch gate widened; runtime
  `systemctl --user is-active` probe and its negative-branch notice added; adjacent comment extended

**Verification**:
- `grep -n 'services.ollama.enable' packages/sapience-flake/modules/sapience.nix` shows the gate in
  addition to the pre-existing `warnings` use
- `grep -n 'is-active --quiet ollama.service' packages/sapience-flake/modules/sapience.nix` matches
  once, inside the bootstrap script
- Shell-level sanity: extract the generated `sapience-bootstrap` script text (via a scratch
  `nix eval`/`nix build` of the module's wrapper, or `bash -n` on the rendered body) and confirm it
  parses
- `nixfmt --check` passes on the file

---

### Phase 4: Extract the shared wrapper builder and rewire the module [NOT STARTED]

**Goal**: Move the three `writeShellScriptBin` wrapper definitions into
`packages/sapience-flake/lib/wrappers.nix`, parameterized by plain arguments standing in for every
`cfg.*` and `config.*` value they read, so the same script bodies back both the home-manager module
and the non-home-manager package outputs with no duplicated shell.

**Tasks**:
- [ ] Create `packages/sapience-flake/lib/wrappers.nix` as a function taking
      `{ pkgs, lib, stateDir, host, backend, model, memoryFiles, tokenFile, backgroundSync,
      syncInterval }` and returning `{ sapience, sf1, sapience-bootstrap }`
- [ ] Move `requiredPayload`, `optionalPayload`, `runtimePath`, `python`, `configFile` and the three
      wrapper bodies into that file unchanged apart from the `cfg.X` -> `X` and
      `config.home.homeDirectory` -> `stateDir` substitutions
- [ ] Audit every interpolation of `stateDir` inside the moved script bodies and ensure each is
      double-quoted, because the package output will pass a shell-expanded `"$HOME/.sapience"`
      rather than an evaluation-time absolute path
- [ ] Rewire `packages/sapience-flake/modules/sapience.nix` to `import ../lib/wrappers.nix` with
      `stateDir = "${config.home.homeDirectory}/.sapience";` and the `cfg.*` values, and use the
      returned attributes in `home.packages`
- [ ] Decide and record how the ticker's eval-time `config.services.ollama.enable` half reaches the
      builder: pass it as an explicit boolean argument (default `false`, which is what the package
      output wants) rather than reaching into `config` from inside `lib/wrappers.nix`, keeping the
      builder free of any home-manager dependency
- [ ] Verify no `config.`, `cfg.`, or `options.` reference survives inside `lib/wrappers.nix`
- [ ] Render the module's three wrapper derivations before and after the extraction and diff the
      generated script bodies; the module path's output must be unchanged except for the
      intentional Phase 3 ticker hunks
- [ ] `nixfmt --check` on both files

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: the wrapper bodies read exactly these values — `cfg.host`, `cfg.memoryFiles`,
`cfg.backend`, `cfg.model`, `cfg.tokenFile`, `cfg.backgroundSync`, `cfg.syncInterval`, and
`config.home.homeDirectory` (via `stateDir`) — so the builder needs that argument set plus the
ollama-enable boolean. Confirm at implementation time with
`grep -nE 'cfg\.|config\.' packages/sapience-flake/lib/wrappers.nix` after the move returning no
hits, which mechanically proves the argument list is complete rather than relying on this list.

**Files to modify**:
- `packages/sapience-flake/lib/wrappers.nix` - new file: parameterized builder returning the three
  wrapper derivations
- `packages/sapience-flake/modules/sapience.nix` - wrapper definitions removed from its `let`
  block, replaced by an `import` of the builder with `cfg.*` values

**Verification**:
- `grep -nE '\bcfg\.|\bconfig\.' packages/sapience-flake/lib/wrappers.nix` returns nothing
- A scratch `nix eval`/`nix build` of the module's `home.packages` still produces three
  derivations named `sapience`, `sf1`, `sapience-bootstrap`
- Generated script bodies before/after the extraction differ only in the Phase 3 ticker hunks
- `nixfmt --check` passes on both files

---

### Phase 5: Author the standalone flake.nix [NOT STARTED]

**Goal**: Give the directory its own `flake.nix` exposing `homeManagerModules.sapience` and
`packages.<system>.{sapience,sf1,sapience-bootstrap}`, with a minimal input set so the artifact is
genuinely standalone and cheap for a stranger to evaluate.

**Tasks**:
- [ ] Write `packages/sapience-flake/flake.nix` with a single input (`nixpkgs`, pinned to a stable
      release channel) and no `flake-utils` dependency — iterate systems with
      `nixpkgs.lib.genAttrs` over an explicit list (`x86_64-linux`, `aarch64-linux`,
      `x86_64-darwin`, `aarch64-darwin`), keeping the input set to one entry
- [ ] Export `homeManagerModules.sapience = ./modules/sapience.nix;` and
      `homeManagerModules.default = self.homeManagerModules.sapience;`
- [ ] Export `packages.<system>.{sapience,sf1,sapience-bootstrap}` by importing
      `./lib/wrappers.nix` with vendor defaults (`host` = the vendor host the module already
      defaults to, `backend = "relay"`, `model = ""`, `memoryFiles = true`, `tokenFile = null`,
      `backgroundSync = false`, `syncInterval` = the module's default) and
      `stateDir = "$HOME/.sapience"` so path resolution happens at runtime
- [ ] Set `packages.<system>.default = packages.<system>.sapience;`
- [ ] Export `lib.mkSapienceWrappers = import ./lib/wrappers.nix;` so a consumer can build the
      wrappers with their own values without the home-manager module
- [ ] Add a `description` and a top-of-file comment stating the directory is shareable as-is, that
      the payload is deliberately unpinned mutable state, and that
      `packages.<system>.*` consumers get no systemd timer and no MCP registration (both are
      home-manager-module-only concerns)
- [ ] Confirm the flake declares no dependency on this repository: grep for `..`-escaping paths and
      for any reference outside `packages/sapience-flake/`
- [ ] `nixfmt --check packages/sapience-flake/flake.nix`
- [ ] Generate `packages/sapience-flake/flake.lock` with `nix flake lock` (best effort — if the
      network is unavailable, record that the lock is absent and that a consumer's first evaluation
      will create it, rather than hand-writing one)

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: the standalone package outputs need no `config.*` context at all, so the only
cross-boundary dependency is the builder's argument list fixed in Phase 4. Confirm by evaluating
`packages.<system>.*` with no home-manager input present; any evaluation error naming `config` or
`home-manager` falsifies the hypothesis and means Phase 4's extraction was incomplete.

**Files to modify**:
- `packages/sapience-flake/flake.nix` - new file: the standalone flake and its outputs
- `packages/sapience-flake/flake.lock` - new file, generated by `nix flake lock` (best effort)

**Verification**:
- `nix flake show` on the directory lists `homeManagerModules.{sapience,default}`, `lib`, and
  `packages.<system>.{sapience,sf1,sapience-bootstrap,default}`
- `nix build` of each of the three package attributes succeeds and each produces a `bin/` entry of
  the expected name
- `grep -n '\.\./\|/home/' packages/sapience-flake/flake.nix` shows no path escaping the directory
- `nixfmt --check` passes

---

### Phase 6: Author the vendor-facing README.md [NOT STARTED]

**Goal**: Write the document that makes the directory shareable: what it is and how to use both
output sets, which defaults were generalized and why, the mutable-payload property, the Claude Code
hooks/statusline gap with exact copy-paste commands, the three nixpkgs blockers with the live
evidence behind each, and the two concrete vendor asks.

**Tasks**:
- [ ] `## What this is` — a generalized fork of a working NixOS/home-manager packaging of the
      Sapience client, shareable as-is; name the source module path and the fork date, and state
      plainly that it replaces the vendor's macOS-only installer on Linux/NixOS
- [ ] `## Using it` — two subsections: `homeManagerModules.sapience` (flake input + module import +
      a minimal `programs.sapience` block, noting what it adds: CLI wrappers, the opt-in sync
      timer, the MCP registration into `~/.claude.json`) and `packages.<system>.*` (plain
      `nix profile`/`nix shell` usage, with the explicit caveat that this path provides no systemd
      timer and no MCP registration)
- [ ] `## Defaults` — a table of the three generalized values (`backend` `relay`, `memoryFiles`
      `true`, `apiKeyFile` example) with the vendor default in one column and the overriding
      rationale a consumer might reuse in another; state that `model`'s empty default already
      matches the vendor's
- [ ] `## Privacy` — `relay` is the only backend where the vendor sees redacted transcript chunks
      before any review gate, and `anthropic`/`openai` have their provider URL hardcoded in the
      vendor client, so only `ollama` has a configurable endpoint
- [ ] `## The payload is deliberately mutable` — activation seeds `~/.sapience/*.py` by `curl` only
      when a file is absent, and the client self-updates in the background; this is a consequence of
      blocker 2 below, not an oversight, and must not be "fixed" into a `fetchurl` derivation
- [ ] `## Known gap: Claude Code hooks and statusline` — state that the flake delivers the MCP
      server (so `mcp__sapience__*` tools become reachable once the registration is merged into the
      consumer's `~/.claude.json`) but no per-turn visibility, because the hooks and permission
      grants are Claude Code *settings* concerns that live outside the Nix module. Quote the three
      hook commands verbatim (`SessionStart` `--briefing-text`, `SessionEnd` `--receipt` with
      `async: true`, `Stop` `--effect-line` with `timeout: 3`), list the seven
      `mcp__sapience__*` permission names, and note `statusLine` is not wired to Sapience at all
- [ ] `## Why this is not in nixpkgs` — three subsections, each independently sufficient:
      (1) **No license grant anywhere**: zero license/copyright/proprietary/all-rights-reserved
      matches across all ten client `.py` files; `HTTP 404` on
      `/{terms,tos,legal,license,privacy}`; the site's own "We have filed patents covering the
      architecture."; both reserved PyPI names (`sapience-ai`, `spnc`) publishing
      `version 0.0.1`, `license: Proprietary`, `summary: "Reserved by CoreTx Inc. Package under
      development."` — so the only defensible `meta.license` is `lib.licenses.unfree`, which Hydra
      neither builds nor caches.
      (2) **Nothing hashable upstream**: `cache-control: no-cache, no-store, must-revalidate` with
      no `etag` and no `last-modified`; `HTTP 404` on
      `/{version,manifest,install.sh,VERSION,version.json,/api/version}`; `sapience_upkeep.py`
      treats a per-file sha256 the server compares as the version, self-updates daily, and honours a
      server-side `CLIENT_AUTO_UPDATE=0` kill switch — so a pinned `fetchurl` hash breaks for every
      user on the vendor's next edit and fights the client's own updater over a read-only store path.
      (3) **Invite-only private beta, macOS-only official support**: the site's own "Sapience is in
      private beta. Start with your invite code and name." and "Mac + Python 3 - about ten minutes."
      Label this one explicitly as practical-consequence reasoning (anonymous Hydra CI and
      maintainers cannot obtain an account to test; the package would be useless to most of
      nixpkgs' Linux userbase) rather than a quoted written nixpkgs rule, because no such written
      rule was found.
- [ ] `## What would unblock it` — the two narrow asks: publish versioned, checksummed release
      artifacts under the two already-reserved PyPI names (answers blocker 2 outright), and state a
      license permitting redistribution of the *build output* (would allow
      `lib.licenses.unfreeRedistributable` instead of plain `unfree`, so Hydra could build once and
      substitute for everyone). State that neither ask touches blocker 3, which is a product
      decision no Nix-side change can route around.
- [ ] Re-verify every quoted command string and permission name against `config/claude/settings.json`
      by grep before closing the phase; do not transcribe them from this plan or the report
- [ ] Confirm no task-number reference appears anywhere in the README (it is a deliverable outside
      `specs/**`)

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: prose

**Scope Hypothesis**: there are exactly three Sapience hook entries and seven `mcp__sapience__*`
permission grants in `config/claude/settings.json`. Confirm with
`grep -c 'mcp__sapience__' config/claude/settings.json` and
`grep -n 'sapience/mcp.py' config/claude/settings.json` at implementation time and write the
measured set, not this count.

**Files to modify**:
- `packages/sapience-flake/README.md` - new file: the vendor-facing document

**Verification**:
- Every section above is present with a `##` heading
- Each of the three hook command strings in the README matches `config/claude/settings.json`
  verbatim (verified by grepping each quoted string back against that file)
- The seven permission names in the README match the seven in `config/claude/settings.json`
- Every nixpkgs-blocker claim has its probe result, header value, or quoted sentence attached;
  blocker 3 is explicitly labelled practical-consequence reasoning
- `bash .claude/scripts/check-task-references.sh` (or an equivalent grep for `task [0-9]`) reports
  nothing for the new README
- Markdown renders with no broken internal links

---

### Phase 7: Repo-side doc wiring, isolation proof, and final gates [NOT STARTED]

**Goal**: Point this repository's own docs at the new directory, prove the artifact works when
copied out of the repo entirely, and prove the live configuration is byte-identical and still
evaluates.

**Tasks**:
- [ ] Add a `### sapience-flake/` entry to `packages/README.md` in that file's existing per-file
      style: what the directory is, that it is a nested independent flake deliberately not wired
      into the parent flake's outputs or overlays, and what its outputs are
- [ ] Add a short pointer from `docs/sapience.md` (documentation-only; near its existing
      "Design decisions" or "Known gaps" section) to `packages/sapience-flake/` as the shareable
      generalized fork, so a future reader finds the fork rather than re-deriving it
- [ ] Isolation proof: copy `packages/sapience-flake/` to a fresh empty directory **outside** this
      repository, `git init && git add -A` there, then run `nix flake check`, `nix flake show`, and
      `nix build .#sapience .#sf1 .#sapience-bootstrap`. This is the real "shareable as-is" test and
      it also sidesteps Nix's in-repo untracked-file behaviour
- [ ] Home-manager consumption smoke test: from that same out-of-repo copy, evaluate a minimal
      standalone `homeManagerConfiguration` that imports `homeManagerModules.sapience` with
      `programs.sapience.enable = true;` and nothing else, confirming the generalized defaults give
      a stranger a configuration that evaluates with no warnings about a missing Ollama server
- [ ] Protected-file gate: `git diff --stat modules/home/services/sapience.nix home.nix` is empty
      and `git status --short` shows neither file modified
- [ ] Repository Nix gate set (this is the complete gate set for a `.nix`-only change in this repo;
      `.claude/scripts/verify-deploy.sh` is the deploy-artifact validator for `.claude/**` and is
      not applicable because no file under `.claude/**` is touched):
  - [ ] `nixfmt --check` over every new `.nix` file
  - [ ] `statix check packages/sapience-flake/` and `deadnix packages/sapience-flake/`
  - [ ] `nix flake check` on the parent repository (proves the nested flake broke no parent
        evaluation)
  - [ ] `home-manager build --flake .` (or `nixos-rebuild build --flake .#<host>`) succeeds,
        proving the live configuration still evaluates unchanged
- [ ] Record any gate that cannot run in this environment (e.g. a darwin system in the flake's
      system list, or an offline `nix flake lock`) as an explicit, named limitation in the
      implementation summary rather than silently skipping it

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- `packages/README.md` - new `### sapience-flake/` entry
- `docs/sapience.md` - short pointer to the shareable fork (documentation only, no behavioural text
  changed)

**Verification**:
- The out-of-repo copy passes `nix flake check` and builds all three packages
- The minimal `homeManagerConfiguration` smoke test evaluates with the generalized defaults
- `git diff --stat modules/home/services/sapience.nix home.nix` is empty
- `nix flake check` on the parent repo passes; `home-manager build --flake .` succeeds
- `nixfmt --check`, `statix check`, and `deadnix` are clean on `packages/sapience-flake/`

---

## Testing & Validation

- [ ] `packages/sapience-flake/` copied outside this repository passes `nix flake check` and
      `nix flake show` on its own, with `nixpkgs` as its only input
- [ ] `nix build` succeeds for `packages.<system>.sapience`, `.sf1`, and `.sapience-bootstrap`, each
      producing the expected `bin/` entry
- [ ] A minimal standalone `homeManagerConfiguration` importing `homeManagerModules.sapience` with
      only `enable = true` evaluates cleanly and emits no Ollama-related warning (confirming the
      `relay` default)
- [ ] `grep -nE '\bcfg\.|\bconfig\.' packages/sapience-flake/lib/wrappers.nix` returns nothing
- [ ] The generated `sapience-bootstrap` script contains the two-part ticker gate and the runtime
      `systemctl --user is-active --quiet ollama.service` probe, and `bash -n` parses it
- [ ] `grep -rniE 'benjamin|\.dotfiles' packages/sapience-flake/` returns nothing
- [ ] Every README nixpkgs-blocker claim is traceable to a probe result or quoted sentence; blocker
      3 is labelled practical-consequence reasoning
- [ ] `git diff --stat modules/home/services/sapience.nix home.nix` is empty
- [ ] Parent repo: `nix flake check` passes and `home-manager build --flake .` succeeds
- [ ] `nixfmt --check`, `statix check`, `deadnix` clean on all new `.nix` files
- [ ] No task-number reference anywhere under `packages/sapience-flake/` or in the
      `packages/README.md` / `docs/sapience.md` additions

## Artifacts & Outputs

- `packages/sapience-flake/flake.nix` - standalone flake: `homeManagerModules.{sapience,default}`,
  `packages.<system>.{sapience,sf1,sapience-bootstrap,default}`, `lib.mkSapienceWrappers`
- `packages/sapience-flake/flake.lock` - generated lock (best effort; absent if offline)
- `packages/sapience-flake/modules/sapience.nix` - generalized fork of the live module
- `packages/sapience-flake/lib/wrappers.nix` - parameterized wrapper builder shared by both output
  sets
- `packages/sapience-flake/README.md` - vendor-facing document: usage, defaults, privacy, mutable
  payload, Claude Code hooks/statusline gap, three nixpkgs blockers with live evidence, two asks
- `packages/README.md` - new `### sapience-flake/` entry
- `docs/sapience.md` - pointer to the shareable fork
- `specs/137_sapience_standalone_flake_and_nixpkgs_blockers/summaries/01_standalone-flake-nixpkgs-blockers-summary.md`

## Rollback/Contingency

The work is purely additive, so rollback is cheap and the live configuration is never at risk:

- **Per-phase**: every phase commits on its own green verification, so `git revert` of a single
  phase commit undoes exactly that phase.
- **Whole task**: `packages/sapience-flake/` is a new directory — removing it plus reverting the two
  small documentation hunks in `packages/README.md` and `docs/sapience.md` restores the repository
  exactly.
- **If a rollback must discard uncommitted work**: that is a genuine rollback, so take the snapshot
  first per `context/contracts/recovery.md`'s rollback rung (which gives the exact
  `git-snapshot.sh` invocation shape, including its out-of-scope override flag for a whole-tree
  case) and only then run the destructive command.
- **If Phase 4's extraction proves to change the module path's generated scripts in any way beyond
  the Phase 3 ticker hunks**: abandon the shared-builder approach rather than accept unexplained
  drift, and fall back to duplicating the three wrapper bodies inside `flake.nix` with vendor
  defaults, documenting the duplication (and the manual-diff obligation) in the vendored module's
  header comment. The flake's external contract is unchanged by that fallback.
- **If the vendor payload host becomes unreachable during verification**: the payload seed is
  activation-time and guarded, so evaluation and `nix build` of all three packages still succeed;
  record the unreachability as a named limitation instead of treating it as a failure.
