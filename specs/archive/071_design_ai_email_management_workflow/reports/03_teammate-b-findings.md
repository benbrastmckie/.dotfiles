# Research Report: Task #71 (Round 3, Teammate B — Extension Authoring)

**Task**: 71 - Design AI-assisted email management workflow
**Focus**: How to build an `email/` Claude Code extension in `~/.dotfiles/.claude/extensions/`
**Started**: 2026-07-02
**Completed**: 2026-07-02
**Dependencies**: Round-1/2 reports (01_ai-email-workflow.md, 02_team-research.md, 02_teammate-{a,b,c,d}-findings.md), plans/02_email-workflow-implementation.md
**Sources/Inputs**: `.claude/extensions/{core,nix,python,nvim,memory}/manifest.json`, `.claude/context/guides/extension-development.md`, `.claude/docs/guides/creating-extensions.md`, `.claude/docs/reference/standards/extension-slim-standard.md`, `.claude/scripts/check-extension-docs.sh`, `.claude/commands/task.md` (keyword resolution algorithm), `~/.config/nvim/.claude/extensions/{cslib,literature}/manifest.json` (keyword_overrides examples), `specs/071_.../plans/02_email-workflow-implementation.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The existing task-71 plan (v2) already designed the wrapper scripts, the PreToolUse
  `mail-guard.sh` hook, and a single `.claude/skills/skill-email-cleanup/SKILL.md` — but it
  wires all of that directly into core `.claude/`, not through the extension system. Wrapping it
  as `.claude/extensions/email/` costs relatively little (one manifest, EXTENSION.md, README,
  index-entries.json, one rules file, one context dir) and buys portability (loadable/unloadable
  via the picker, mergeable into other repos that use this dotfiles-derived `.claude/` system) —
  consistent with how `nix`, `python`, `nvim` package equally repo-specific tooling.
- **Recommendation on task_type** (item 2): give `email` its own `task_type` with a **custom
  implementation agent** (mandatory — it is the safety-critical piece that must call wrappers,
  never raw `himalaya`/`notmuch`) but **reuse `skill-researcher`/`skill-planner`** for
  research/plan (email research is mostly reading wrapper output and prior census data, not
  deep external research). This mirrors the nix/python/nvim pattern's routing shape while
  keeping the footprint smaller — full custom agent pairs are the more expensive of two viable
  options; a resource-only/lighter extension (no task_type, just a direct-execution `/email`
  command like `skill-memory`/`skill-literature`) is the other, and is recommended as a
  **complementary, not alternative**, addition for ad hoc "clean up my inbox now" sessions that
  don't want the full task lifecycle (see item 2 below for the trade-off table).
- Concrete `manifest.json`, `keyword_overrides`, file layout, and registration checklist are
  below. `check-extension-docs.sh` enforces the doc-lint invariants (README/EXTENSION.md/manifest
  present, `provides.*` entries exist on disk, routing block present when skills declared,
  routing targets resolvable/deployed, deployed skills reference agents that exist) — the
  proposed layout is designed to pass all of these checks as-is.

## Context & Scope

Researched how `.claude/extensions/{core,nix,python,nvim,memory}/manifest.json` are structured,
what the extension-authoring docs (`context/guides/extension-development.md`,
`docs/guides/creating-extensions.md`, `docs/reference/standards/extension-slim-standard.md`)
require, how `keyword_overrides` and task_type routing get consumed by `/task` (per
`.claude/commands/task.md` steps 4a-4e), and what `check-extension-docs.sh` will flag on a new
extension. Cross-referenced against the task-71 plan's Phase 2 (wrapper scripts), Phase 3
(mail-guard hook), and Phase 4 (skill-email-cleanup) to determine what the extension should
*reference* rather than re-implement.

## Findings

### 1. Full proposed file layout for `.claude/extensions/email/`

```
.claude/extensions/email/
├── manifest.json                          # required
├── EXTENSION.md                           # required, <=60 lines (extension-slim-standard.md)
├── README.md                              # required
├── index-entries.json                     # recommended
├── agents/
│   └── email-implementation-agent.md      # custom — enforces wrapper-only + confirmation-token
├── skills/
│   ├── skill-email-implementation/
│   │   └── SKILL.md                       # /implement routing target for task_type=email
│   └── skill-email-cleanup/
│       └── SKILL.md                       # direct-execution skill for ad hoc /email sessions
│                                           #   (moved here from core per plan Phase 4, now
│                                           #    extension-owned so it loads/unloads with `email`)
├── commands/
│   └── email.md                           # optional: `/email` command, direct-execution
│                                           #   (mirrors /literature, /learn — see item 2)
├── rules/
│   └── email-wrappers.md                  # "call wrappers, not raw himalaya/notmuch" rule,
│                                           #   path-scoped to specs/**/email* or always-applied
├── context/project/email/
│   ├── README.md                          # loading strategy overview
│   ├── domain/
│   │   ├── wrapper-contracts.md           # census/classify/archive/delete I/O shapes, manifest
│   │   │                                  #   schema, confirmation-token format
│   │   └── himalaya-notmuch-reference.md  # pointer to docs/himalaya.md + notmuch config, NOT a
│   │                                      #   duplicate (link out to existing docs/ file)
│   ├── patterns/
│   │   └── propose-review-confirm-execute.md  # the four-stage loop (dry-run -> manifest ->
│   │                                          #   confirm-manifest <sha256> -> execute)
│   └── standards/
│       └── recall-on-keep-bias.md         # deterministic-first classifier rule, VIP allowlist
└── scripts/                               # only if lifecycle hooks are added (optional)
    └── email-preflight.sh                 # e.g. warn if `himalaya`/`notmuch` binaries missing
```

Notes:
- No `agents/email-research-agent.md` — research routes to the shared `skill-researcher`
  (see item 2 for why).
- `skill-email-cleanup` (direct-execution, no `Agent` delegation needed since it's a thin
  "teach the current agent to call wrappers" skill per plan Phase 4) is placed **inside** the
  extension rather than core, so unloading `email` removes it — the plan's original placement at
  `.claude/skills/skill-email-cleanup/` should be treated as a draft location, superseded by this
  extension-owned path once the extension is authored.
- The PreToolUse `mail-guard.sh` hook and its `.claude/settings.json` registration (plan Phase 3)
  are **not** extension `provides.hooks` file-copy targets in the traditional sense — they are
  security-critical and always-on regardless of whether `email` is "loaded" as a task-type
  extension. Two options: (a) declare `mail-guard.sh` under `provides.hooks` so it deploys to
  `.claude/hooks/mail-guard.sh` and register the PreToolUse matcher via `merge_targets.settings`
  (the same mechanism `nix`'s manifest uses for `mcp_servers`/permissions, see Evidence #3), or
  (b) keep it in core's `merge-sources/settings-hooks.json` alongside the existing WezTerm hooks
  (core's documented rationale, see Evidence #4) if the mail-guard is judged core-safety
  infrastructure rather than domain-specific. **Recommendation: (a)** — it is domain-specific
  (only fires on himalaya/msmtp/notmuch commands) and should travel with the extension so it is
  removed on unload rather than orphaned in core.

### 2. task_type recommendation: custom implementation agent, shared research/plan, PLUS a direct-execution command

**Two viable shapes, not mutually exclusive:**

| Option | What it is | When it fires |
|---|---|---|
| A. Full task_type `email` (like nix/python/nvim) | `routing.research/plan/implement` entries; `/task "clean up my inbox"` auto-detects `task_type=email` via `keyword_overrides`; goes through the normal research→plan→implement lifecycle with artifacts in `specs/{N}_.../` | One-off, trackable, multi-phase work — e.g. "run the census, propose a classification pass, archive the confirmed low-risk senders" as a discrete task with a plan and a summary |
| B. Direct-execution `/email` command (like `/literature`, `/learn`) | `skill-email-cleanup` invoked directly, no task lifecycle, no `specs/{N}_.../` artifacts | Ad hoc, session-scoped — "check my inbox and draft replies to these three threads right now" |

**Recommendation: build both, with the routing/agent asymmetry below:**

- `routing.research` → `skill-researcher` (shared, core). Rationale: email "research" in the
  task-lifecycle sense is reading existing wrapper output/manifests and prior census data, not
  external web research — the general research agent with email context files injected (via
  `index-entries.json` `load_when.task_types: ["email"]`) is sufficient. A dedicated
  `email-research-agent` would duplicate `general-research-agent`'s Stage 0-8 flow for no
  domain-specific gain.
- `routing.plan` → `skill-planner` (shared, like every other extension in this repo —
  see nix/python/nvim manifests, Evidence #1). No extension overrides `plan`.
- `routing.implement` → `skill-email-implementation` → **custom**
  `email-implementation-agent`. This is the one place a dedicated agent earns its cost: the
  agent's entire job is "call the Phase 2 nix wrappers via Bash, never construct raw
  `himalaya`/`notmuch` commands, always run dry-run first, only pass `--execute
  --confirm-manifest <sha256>` after the manifest has been shown to the user." A generic
  `general-implementation-agent` has no such constraint baked in and, per the plan's own risk
  list (`docs/architecture` "lethal trifecta" framing in round-2 findings), is exactly the place
  a bug would be catastrophic (bulk-deleting the wrong messages). This matches why `nix` has a
  dedicated `nix-implementation-agent` (verification against `nix flake check`/`nixos-rebuild
  build`) rather than reusing the general one.

**Trade-off**: a fully custom research+implementation pair (mirroring nix/python exactly) is
more consistent with existing extensions but roughly doubles agent-maintenance surface for a
domain where the research half adds little value over the shared agent + injected context.
Reusing `skill-researcher`/`skill-planner` and only forking `skill-email-implementation` keeps
the extension's execution-critical logic centralized in one custom agent while minimizing
duplicate boilerplate — the same asymmetric pattern this repo could apply to any tool-wrapper
domain where planning is generic but execution is safety-critical.

### 3. Exact `keyword_overrides` entries

Per `.claude/commands/task.md` §4b (Evidence #5), `keyword_overrides` is scanned per-manifest
before the hardcoded table, with whole-word case-insensitive matching. Draft entry for
`.claude/extensions/email/manifest.json`:

```json
"keyword_overrides": {
  "email": {
    "keywords": [
      "inbox", "email", "e-mail", "gmail", "himalaya", "notmuch",
      "unsubscribe", "junk mail", "spam", "mail backlog", "mbsync",
      "aerc", "draft reply", "mail triage"
    ],
    "aliases": ["mail", "mailbox"]
  }
}
```

Rationale for specific entries:
- `"inbox"`, `"junk"` (as `"junk mail"` to avoid colliding with generic "junk" usage
  elsewhere), `"draft"` (scoped as `"draft reply"` since bare "draft" is a common English word
  that would false-positive on unrelated tasks — e.g. "draft a plan"), `"unsubscribe"`,
  `"himalaya"` were explicitly named in the round-3 prompt.
- `"gmail"`, `"notmuch"`, `"mbsync"`, `"aerc"` added because they are the concrete tool names
  this workflow touches (per plan's ownership table, Evidence #2) and are unambiguous domain
  markers, unlike bare "mail" (too broad — could match "mailing list" for a changelog, hence
  `"mail"` is an **alias** rather than a **keyword**: aliases only apply post-resolution
  remapping from 4c/4d per task.md §4e, so `"mail"` alone won't trigger email routing from an
  unrelated hardcoded-table hit, but the whole-word keyword `"inbox"`/`"gmail"` will).
- Precedence note: meta keywords ("meta", "agent", "command", "skill") still win unconditionally
  per §4a; `"email"` keyword_overrides only fires if none of those meta terms are present, and
  fires before the hardcoded table and `default_task_type`.

### 4. Extension = interface, wrappers = mechanism

The extension's skills/commands must **call**, not re-implement, the task-71 nix wrappers
(`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
`email-unsubscribe-extract` — plan Phase 2, Evidence #6) and the PreToolUse `mail-guard.sh`
hook (plan Phase 3). Concretely:

- `email-implementation-agent.md`'s "Tool Usage" section should list `Bash` with an explicit
  constraint block (mirroring the plan's Phase 4 hard rules): "Only invoke `email-census`,
  `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
  `email-unsubscribe-extract` by name. Never call `himalaya` or `notmuch` directly. Every
  archive/delete call must first run without `--execute`, present the resulting manifest to the
  user, then re-run with `--execute --confirm-manifest <sha256-of-manifest>`." This is enforced
  twice — once socially (agent instructions) and once technically (the `mail-guard.sh`
  PreToolUse hook denies any `Bash` command matching the raw-tool regex without a valid token,
  per plan Phase 3) — the extension should document both layers in `context/project/email/
  patterns/propose-review-confirm-execute.md` so neither is discovered only by reading the hook
  source.
- `skill-email-cleanup/SKILL.md` (the direct-execution, ad hoc skill) is a thin instructional
  wrapper exactly like the plan's Phase 4 describes it — "thin wrapper" here has the same
  meaning as `skill-nix-research` being a "thin wrapper that delegates to nix-research-agent"
  (Evidence #7): the skill file itself should contain no email-domain logic, only the GATE
  IN/DELEGATE/GATE OUT scaffolding plus a pointer to the wrapper contract context file.
- The manifest's `provides.scripts` should stay **empty** or list only extension-lifecycle
  scripts (e.g. an optional preflight that warns if `himalaya`/`notmuch` binaries are missing) —
  the actual `email-census`/etc. binaries are Nix-built (`writeShellScriptBin`) and live in
  `modules/home/packages/email-tools.nix` / `modules/home/email/agent-tools.nix`, **outside**
  `.claude/` entirely. The extension must not duplicate them under `.claude/extensions/email/
  scripts/` — it references them as already-on-`$PATH` commands, same as how `nix-implementation-
  agent`'s "Verification Commands" section (Evidence #8) references `nixos-rebuild`/`home-manager`
  as external tools rather than bundling them.

### 5. Registration checklist for load + CLAUDE.md regeneration

From `context/guides/extension-development.md` (Two-Layer Architecture, Evidence #9) and
`extensions.json` (Evidence #10), what must exist/happen for `email` to load and for CLAUDE.md
to pick it up:

1. **`manifest.json`** with `merge_targets.claudemd = {"source": "EXTENSION.md", "target":
   ".claude/CLAUDE.md", "section_id": "extension_email"}` and `merge_targets.index = {"source":
   "index-entries.json", "target": ".claude/context/index.json"}` — these are what the loader
   reads to know *where* to merge content; omitting either means EXTENSION.md content or context
   entries are silently not merged even if the files exist.
2. **Load via the extension picker** (not manual copy) — the loader (`loader.lua`, referenced
   from the nvim-side dotfiles source, not this repo) is what performs the actual file copy from
   `.claude/extensions/email/*` into the runtime dirs (`.claude/agents/`, `.claude/skills/`,
   `.claude/rules/`, `.claude/context/project/email/`) and appends an `email` entry to
   `.claude/extensions.json` (mirroring the `nix`/`memory`/`core` entries already there —
   Evidence #10) with `installed_files`, `installed_dirs`, `source_dir`, `status: "active"`.
3. **CLAUDE.md regeneration**: on load, `generate_claudemd()` concatenates every loaded
   extension's `merge_targets.claudemd.source` file, core first then others sorted — so
   `EXTENSION.md` must be authored and kept under the 60-line slim standard (Evidence #11) or it
   bloats every future session's context.
4. **Doc-lint compliance** (`check-extension-docs.sh`, Evidence #12) — before considering the
   extension "done", run `bash .claude/scripts/check-extension-docs.sh` and confirm: manifest/
   EXTENSION.md/README.md all present and non-empty; every `provides.agents/skills/commands/
   rules/scripts` entry exists on disk at the expected path; a `routing` block exists (since
   `provides.skills` will be non-empty); every routing target (`skill-email-implementation`,
   `skill-planner`, `skill-researcher`) resolves to either a deployed `.claude/skills/*` dir or
   another extension's `provides.skills`; every deployed skill's `subagent_type:` in its SKILL.md
   body resolves to a `.claude/agents/*.md` file; README.md mentions every command listed in
   `provides.commands` (so if `commands/email.md` is added, README.md must contain `/email`
   literally).
5. **`keyword_overrides` and hardcoded-table interaction**: no core file needs editing —
   `task.md` §4b already scans `.claude/extensions/*/manifest.json` generically (Evidence #5),
   so adding the `email` extension's `keyword_overrides` block is sufficient; nothing needs to be
   added to the "4d hardcoded keyword table" fallback list in `task.md` or `CLAUDE.md` itself.
6. **`opencode_json` merge target** (optional, seen in nix/python/nvim manifests) — if this repo
   also drives OpenCode, add `"opencode_json": {"source": "opencode-agents.json", "target":
   "opencode.json"}` to `merge_targets` for parity; not required for Claude Code alone.

## Decisions

- Recommend a full `task_type: "email"` with **asymmetric routing**: shared `skill-researcher`/
  `skill-planner`, custom `skill-email-implementation` → `email-implementation-agent`.
- Recommend the mail-guard PreToolUse hook and its `.claude/settings.json` registration travel
  with the extension (`provides.hooks` + `merge_targets.settings`), not stay in core, since it is
  domain-specific enforcement that should unload cleanly with the extension.
- Recommend `skill-email-cleanup` (direct-execution, ad hoc) live inside the `email` extension
  rather than at the core-level path the round-2 plan originally sketched, so both the tracked
  (task-lifecycle) and ad hoc (direct-execution) entry points are extension-owned and travel
  together.

## Risks & Mitigations

- **Risk**: `"mail"` as a bare keyword would false-positive on unrelated tasks (e.g. "update
  mailing list config"). **Mitigation**: keep `"mail"`/`"mailbox"` as `aliases` (post-resolution
  remapping only), not `keywords` (direct whole-word match) — per task.md §4e semantics.
- **Risk**: duplicating `himalaya`/`notmuch` reference docs already in `docs/himalaya.md` bloats
  context and risks drift. **Mitigation**: `context/project/email/domain/himalaya-notmuch-
  reference.md` should be a short pointer file linking to the existing `docs/himalaya.md`, not a
  copy.
- **Risk**: if the custom `email-implementation-agent` is under-specified, an agent could still
  fall back to raw `himalaya`/`notmuch` calls the mail-guard hook doesn't catch (regex gaps).
  **Mitigation**: the SKILL.md wrapper-only constraint (social layer) and the hook (technical
  layer) are both required — document explicitly that neither is sufficient alone, matching the
  round-2 findings' "lethal trifecta" framing.

## Context Extension Recommendations

- **Topic**: No existing `.claude/context/` entry documents the "asymmetric routing" pattern
  (custom implementation agent, shared research/plan agents) used here.
- **Gap**: `context/guides/extension-development.md` and `docs/guides/creating-extensions.md`
  both assume symmetric research+implementation agent pairs (per their templates); there is no
  guidance for when to fork only one side of routing.
- **Recommendation**: after this extension is built, consider adding a short "Partial Custom
  Routing" subsection to `docs/guides/creating-extensions.md` documenting the
  wrapper-safety-critical-implementation-only pattern as a recognized alternative to the
  full-pair template.

## Appendix — Evidence/Examples (file:line refs)

1. Shared `skill-planner` for `plan` routing across all extensions:
   `.claude/extensions/nix/manifest.json` (`"plan": {"nix": "skill-planner"}`),
   `.claude/extensions/python/manifest.json` (`"plan": {"python": "skill-planner"}`),
   `.claude/extensions/nvim/manifest.json` (`"plan": {"neovim": "skill-planner"}`) — no
   extension in this repo forks the planner.
2. Wrapper/hook ownership table: `specs/071_design_ai_email_management_workflow/plans/
   02_email-workflow-implementation.md:57-62` (five wrapper names, notmuch config, aerc keybinds,
   mbsync helper, PreToolUse hook, and `skill-email-cleanup` all listed with owners).
3. `mcp_servers`/permissions merge via `merge_targets`/settings pattern:
   `.claude/extensions.json` `extensions.nix.merged_sections.settings` block (new
   `mcpServers.mcp-nixos` object + appended `permissions.allow` entries
   `mcp__nixos__nix`, `mcp__nixos__nix_versions`).
4. Core's rationale for keeping lifecycle hooks in `settings.json` not `settings.local.json`:
   `.claude/extensions/core/manifest.json` `merge_targets.settings._comment` field (WezTerm
   hooks are "required core functionality" vs. lean/nix/epi's `settings.local.json` "personal
   MCP/permission preference" precedent) — directly informs the core-vs-extension placement
   question for `mail-guard.sh`.
5. `/task` keyword-resolution precedence (meta > extension keyword_overrides > project default >
   hardcoded table > general), including the exact jq scan pattern:
   `.claude/commands/task.md:111-187` (steps 4a-4e).
6. Wrapper script names and phase: `specs/071_.../plans/02_email-workflow-implementation.md:251-272`
   (Phase 2: `email-census`, `email-classify`, `email-archive-confirmed`,
   `email-delete-confirmed`).
7. "Thin wrapper" skill framing: `.claude/docs/guides/creating-extensions.md:420`
   ("Thin wrapper that delegates to `your-domain-research-agent`").
8. External tool reference pattern (not bundling binaries):
   `.claude/CLAUDE.md` Nix Extension "Build Verification" section (`nix flake check`,
   `nixos-rebuild build --flake .#hostname`, `home-manager build --flake .#user`).
9. Two-Layer Architecture (extension source vs. loaded runtime, loader copies files + merges
   index + calls `generate_claudemd()`): `.claude/context/guides/extension-development.md:9-20`.
10. Existing `extensions.json` entries showing `installed_files`/`installed_dirs`/`source_dir`/
    `status: "active"`/`merged_sections` shape for `nix`, `memory`, `core`:
    `.claude/extensions.json` (top-level `extensions` object).
11. EXTENSION.md 60-line slim standard with required 4-section structure (Header, Routing Table,
    Command List, Context Pointers): `.claude/docs/reference/standards/extension-slim-standard.md:7-24`.
12. Doc-lint checks (manifest entries exist on disk, routing block presence, routing target
    resolvability/deployment, deployed-skill-references-existing-agent, README mentions every
    command): `.claude/scripts/check-extension-docs.sh` (full file; see `check_manifest_entries`,
    `check_routing_block`, `check_routing_consistency`, `check_deployed_skill_agents`,
    `check_readme_vs_manifest` functions).
13. `keyword_overrides` real-world shape (keywords + aliases object per task_type, and the
    simpler string-only meta-keyword form): `~/.config/nvim/.claude/extensions/cslib/
    manifest.json` (`"cslib": {"keywords": [...], "aliases": ["lean4"]}`) and
    `~/.config/nvim/.claude/extensions/literature/manifest.json`
    (`"literature": "meta"` flat-string form).

## References

- `.claude/extensions/{core,nix,python,nvim,memory}/manifest.json`
- `.claude/extensions.json`
- `.claude/context/guides/extension-development.md`
- `.claude/docs/guides/creating-extensions.md`
- `.claude/docs/architecture/extension-system.md`
- `.claude/docs/reference/standards/extension-slim-standard.md`
- `.claude/scripts/check-extension-docs.sh`
- `.claude/commands/task.md`
- `specs/071_design_ai_email_management_workflow/plans/02_email-workflow-implementation.md`
- `~/.config/nvim/.claude/extensions/{cslib,literature}/manifest.json`

## Confidence Level

**High** for manifest schema, registration mechanics, doc-lint requirements, and
keyword_overrides syntax — all directly quoted from files in this repo. **Medium** for the
task_type routing recommendation (asymmetric custom-implementation-only) — this is a
judgment call/trade-off, not a documented convention; no existing extension in this repo uses
this exact asymmetric shape, though the underlying mechanism (per-operation routing keys) fully
supports it. **Medium** for the mail-guard-hook-lives-in-extension-vs-core placement — plausible
per the core manifest's own stated rationale for the settings-vs-settings.local split, but not
something the docs decide definitively either way.
