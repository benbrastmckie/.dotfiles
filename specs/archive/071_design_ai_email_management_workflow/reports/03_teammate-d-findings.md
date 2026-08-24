# Teammate D Findings (Round 3): Horizons — Cross-System Integration & Maintainability

**Task**: 71 — Design AI-assisted email management workflow
**Round**: 3 (builds on round-2 synthesis, `02_team-research.md`)
**Angle**: Cross-system fit, extension-architecture correctness, long-term maintainability
**Date**: 2026-07-02

---

## Key Findings

### 1. The task brief's premise about "source of truth" is backwards from observed practice — this must be corrected before scoping the extension

The prompt frames `~/.dotfiles/.claude/` as "the source of truth / extension library." Live inspection of `extensions.json` in **every** repo checked contradicts this:

- `~/.dotfiles/.claude/extensions.json` records `source_dir` for all 5 of its loaded extensions (`core`, `memory`, `nix`, `nvim`, `python`) as `/home/benjamin/.config/nvim/.claude/extensions/{name}` — i.e., dotfiles received these from nvim-config.
- `~/Mail/.claude/extensions.json` shows the identical pattern: `core`/`memory`/`nix`/`nvim`/`python`, all sourced from `/home/benjamin/.config/nvim/.claude/extensions/`.
- `~/.config/nvim/.claude/extensions.json` itself records `core`'s `source_dir` as **itself** (`/home/benjamin/.config/nvim/.claude/extensions/core`) — i.e., nvim-config is self-sourced; it is the origin, not a downstream copy.
- `~/.config/nvim/.claude/extensions/` contains **18 domain directories** (`cslib`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`, `lean`, `literature`, `present`, `slidev`, `typst`, `web`, `z3`, plus the 5 shared ones) — a genuine comprehensive library. `~/.dotfiles/.claude/extensions/` has only the 5 that this repo happens to have loaded.
- The `<leader>al` picker plugin itself lives in the nvim config tree (`lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`, per `docs/AI_TOOLING.md`), reinforcing that nvim-config is where the loader and its authored library are co-located.

**Conclusion**: `~/.config/nvim/.claude/extensions/` is the actual, currently-operating master library; `.dotfiles`, `~/Mail`, and every other project are *consumers* that pull extensions into themselves via `<leader>al`. This is the opposite of what the task brief assumed, and it changes the answer to "where should the email extension's source of truth live."

### 2. The `~/Mail/.claude` prior art is not "dormant rules" — it is a complete, unpackaged extension already sitting on top of the shared framework

Round 2 characterized `~/Mail/.claude` as "a preference-rules file" plus scripts. Direct inspection shows it is far more complete and far closer to a real extension than previously credited:

- `~/Mail/.claude/agents/email-agent.md` — a full subagent definition.
- `~/Mail/.claude/commands/email.md` — a real slash command (`/email --analyze|--cleanup|--triage|--status [ACCOUNT]`), with `model: claude-opus-4-5-20251101` frontmatter, task-status-mapped modes (`analyze`→researched, `cleanup`/`triage`→planned), and **already account-parameterized** (`logos` default, `gmail` supported) — meaning the Gmail-first pivot from round 2 is not a rebuild, it is a default-flag flip on code that already exists.
- `~/Mail/.claude/skills/skill-email/SKILL.md` — a thin-wrapper skill delegating to `email-agent`, using the same "skill-internal postflight" pattern documented in this repo's `context/patterns/postflight-control.md`.
- `~/Mail/.claude/context/project/email/` — six files: `email-preferences.md` (the JSON-rule-block preference schema B/C/A should reuse rather than re-derive — it already encodes newsletter/notification/promotional/transactional categorization with confidence thresholds), `email-patterns.md`, `himalaya-integration.md`, `task-integration.md`, `ai-triage-prompts.md`, `email-plan-format.md`.
- `~/Mail/.claude/scripts/email/*.py` — five scripts: `email_analyze.py`, `email_triage.py`, `email_list.py`, `email_filter.py`, `email_execute.py`.
- Task history in `~/Mail/specs/state.json`: 28 tasks, several completed (`email_cleanup_logos_20260218`, `email_cleanup_logos_20260219`, `fix_pass_initialization_protonmail_bridge`, `fix_email_rendering_himalaya`) — this is a working system with real mileage, not a prototype.

**This was built entirely by hand, directly against the shared framework, never packaged as `.claude/extensions/email/`** — even though `~/Mail/.claude/extensions.json` already had `core`/`nix`/`nvim`/`python`/`memory` loaded as proper extensions at the time. That is precisely the "second uncoordinated agent" risk the round-2 synthesis flagged in Finding 1, and precisely why it forked and went dormant: it lived in one repo's `.claude/` tree with no packaging boundary, so it could not be reloaded, versioned, or reused elsewhere — every future improvement had to happen by hand-editing `~/Mail/.claude` directly, the same trap `~/Mail/.claude` itself was in relative to the framework it was bolted onto.

### 3. Packaging the prior art as an extension is a *migration*, not a *rebuild* — and it resolves the "separate git repo" failure mode by construction

Because the prior art already has the exact shape an extension needs (agent, command, skill, context/project/email, scripts), promoting it to `.claude/extensions/email/{agents,commands,skills,context/project/email,scripts}/` plus a `manifest.json`/`EXTENSION.md`/`README.md` is largely a move-and-wire operation, not new design. Concretely:

- `agents/email-agent.md` → `extensions/email/agents/email-agent.md`
- `commands/email.md` → `extensions/email/commands/email.md`
- `skills/skill-email/` → `extensions/email/skills/skill-email/`
- `context/project/email/*.md` → `extensions/email/context/project/email/*.md` (registered via `index-entries.json`, same as `nix`'s `project/nix/*` pattern)
- `scripts/email/*.py` → `extensions/email/scripts/*.py`, declared in `manifest.provides.scripts` (this repo's own literature-extension packaging bug — scripts referenced but not declared in `manifest.provides.scripts`, tracked as nvim-config task 793 — is the exact failure mode to avoid here; declare every script)

This directly answers **why an extension earns its keep over "just the connector + nix wrappers" (Q4)**: the wrapper-script-only alternative (A's `email-census`/`email-classify`/etc. as bare `writeShellScriptBin`) forfeits the task-integration layer (`specs/{NNN}_{SLUG}/`, plan-approval, artifact history) that the prior art already built and that the round-2 UX findings (manifest-as-audit-trail, checkbox approval) depend on. A bare Nix-wrapper-only design would have to reinvent that layer or bolt it on ad hoc — which is exactly how `~/Mail/.claude` came to exist in the first place. The extension is not competing with "connector + nix wrappers" (B) below it — it *is* the packaging of the orchestration layer that sits above them. The connector remains Path A (read-only triage/draft); the nix wrappers/Himalaya CLI remain the mechanism Path B's scripts shell out to; the `email` extension is the `/email` command, skill, agent, and task-integration glue that already exists and only needs a packaging boundary.

### 4. `~/Mail` should be retired as a *`.claude/` maintenance burden*, not as a repo — its `specs/` task history and maildir are legitimately project-scoped

Q2 in the brief asks whether `~/Mail/.claude` should be "retired entirely." The evidence supports a narrower, more precise answer:

- **Retire**: the hand-forked copies of `agents/email-agent.md`, `commands/email.md`, `skills/skill-email/`, `scripts/email/*.py`, and the context files *as independently-maintained artifacts*. These become extension-managed (loaded via `<leader>al`, versioned in the nvim-config library, updated by reloading — not by hand-editing a second copy).
- **Keep, as a repo**: `~/Mail` itself, its own git history, and its own `specs/{NNN}_{SLUG}/` task directories. The 28-task history (`email_cleanup_logos_*`, `fix_pass_initialization_protonmail_bridge`, etc.) is legitimate per-mailbox operational history — exactly analogous to how `cslib` or `ProofChecker` are legitimate independent projects that happen to load extensions from the shared library. Round-2's "audit-trail repo location" open question (`.dotfiles/specs/071.../` vs `~/Mail/specs/`) resolves naturally once this distinction is drawn: task 71's *design* artifacts belong in `.dotfiles/specs/071_.../` (this is a meta/design task about the framework); *execution* artifacts from actually running `/email --cleanup` against a live mailbox belong in `~/Mail/specs/` (or wherever the target account's Maildir-adjacent project lives), exactly as they do today.
- **Data preservation for `email-preferences.md`**: this file is user-tuned, per-mailbox content (Logos-specific thresholds/categories), not framework logic. The extension system already has a purpose-built mechanism for exactly this: `data_skeleton_files` / `copy_data_dirs()`, documented in `docs/architecture/extension-system.md:542` as "merge-copy, non-overwriting." Ship a generic default `email-preferences.md` as a `manifest.provides.data` skeleton file; on first load into `~/Mail` (or any project), the existing tuned file is preserved (skeleton copy only fills in if absent), and it should additionally be added to that project's `.syncprotect` so future `<leader>al` reloads of the `email` extension never clobber it. This is a one-line addition to a mechanism that already exists — no new infrastructure needed, directly parallel to how `.syncprotect` already protects hand-tuned files from "Load Core" syncs.

### 5. Selective loading composes cleanly with the existing model — no special-casing needed, but the manifest must declare an explicit tool-availability precondition

Q3 asks whether `email` should be off-by-default, per-machine. The mechanism already fits without modification:

- Extensions are opt-in per project via the `<leader>al` picker (confirmed: `~/.config/nvim`, `~/.dotfiles`, and `~/Mail` each have their own independently-curated `extensions.json` subset — `nvim` itself doesn't load `latex`/`lean`/`z3`/etc. into its own root `.claude/`, even though it hosts the library). "Only load where mail is synced" is just normal extension hygiene: load `email` into `~/Mail` and into any other project whose `.claude/` should get `/email`; don't load it into e.g. this `.dotfiles` repo's own root `.claude/` unless dotfiles itself needs to run email operations (it currently manages the *Nix modules* for mbsync/himalaya/aerc/notmuch, which is a `nix` extension concern, not an `email` extension concern — worth keeping that boundary explicit in the extension's README so it's not loaded somewhere it can't do anything).
- CLAUDE.md is regenerated from loaded extensions' `EXTENSION.md` merge-sources (per this repo's own CLAUDE.md: "Do not edit directly... generated automatically from loaded extensions"). This means an unloaded `email` extension contributes **zero** CLAUDE.md bloat or routing-table noise on machines where mail isn't synced — the selective-loading answer to Q3 is already the system's default behavior for every other extension, not something that needs new design.
- **Gap to close**: the manifest should declare a runtime precondition (e.g., a `hooks.preflight` script, per the existing `hooks` schema used by `nix`'s `scripts/nix-preflight.sh`) that checks `himalaya --version` / `~/.mbsyncrc` / notmuch db presence and fails gracefully with a clear message rather than a cryptic command-not-found, since — unlike `nix` (present on every NixOS machine by construction) — mail-tool presence is genuinely machine-conditional here.

### 6. Composition seam with the Anthropic connector, himalaya, and aerc: the extension's job is orchestration and task-integration, never the mail protocol itself

Q5 asks how the extension should compose with, not replace, the other tools. The prior art already draws this line correctly and it should be preserved explicitly in the new `EXTENSION.md`:

- The extension **never** talks IMAP/SMTP directly. All protocol work is delegated to `himalaya` (already the pattern in `email_analyze.py` et al., confirmed via A's live verification of `himalaya envelope list -o json` / `himalaya message delete` / `himalaya folder expunge` in round 2).
- The extension does not attempt to replace the Anthropic Gmail connector's triage/draft UX — per round 2's Path A/Path B split, the connector remains the zero-setup, works-anywhere daily surface; the extension is what runs *only* on machines with the local stack configured, for anything destructive or Logos-account-scoped (the connector can't reach Protonmail at all).
- `aerc` remains the human review surface (round 2 Teammate C: provisional tags + saved-search views); the extension's role there is to *generate* the manifest/tags aerc reviews against and to *execute* the approved IMAP-level action, not to reimplement a mail client UI.
- **Clean seam statement for the README**: "This extension orchestrates and audits; himalaya executes; aerc/connector are where a human looks." Any future contributor tempted to add a raw IMAP library call inside the extension's scripts should read that line first.

### 7. Concrete roadmap/maintenance risks specific to the horizons view

- **Tool-version drift**: the extension's scripts assume specific himalaya output shapes (round 2 A: `himalaya envelope list -o json` field names "drift across versions/blogs"; notmuch 0.40 lacks `search --output=sender`). Because himalaya/notmuch versions are pinned via this repo's Nix modules (`modules/home/email/*.nix`) but the *extension* is authored in nvim-config and deployed to N different machines/projects, there is no single place today that guarantees the extension's assumed CLI surface matches the locally-pinned version. **Recommendation**: the extension's `EXTENSION.md`/README should pin a minimum himalaya/notmuch version and the preflight hook (Finding 5) should assert it (`himalaya --version` string check), rather than discovering drift mid-run against a live mailbox.
- **`check-extension-docs.sh` doc-lint**: this script (already in this repo) will flag the new extension if `manifest.provides.scripts` omits any script the command/skill/agent reference, if README predates manifest, or if commands aren't mentioned in README. Run it as part of the extension PR before first load — cheap, already wired, catches exactly the class of bug that broke the `literature` extension's portability (nvim-config task 793, still open: scripts referenced-but-unpackaged).
- **Task 46 (Gmail OAuth2 token expiry) is a live external dependency**, currently `researched` (not yet planned/implemented) per `specs/state.json`. Root cause: OAuth consent screen stuck in "Testing" mode → hard 7-day refresh-token expiry. This is orthogonal to the extension's packaging but is a **hard blocker for any unattended Gmail-account run** the extension enables — the extension's preflight/guard hook should detect `invalid_grant` and fail safe (round 2 Teammate D/B already flagged this; reaffirmed here as a maintenance-horizon risk because it will silently re-break any long-lived automation the extension makes possible, not just the one-time backlog purge).
- **Two authoring locations to keep synchronized**: once `email` is authored in nvim-config's library, it must be reloaded (not hand-patched) in every consumer (`~/Mail`, and wherever else it's loaded) whenever it's updated — exactly the discipline this repo's own memory system already encodes (`MEM-agent-system-reload-propagation`: "Agent system changes propagate... by reloading via `<leader>al` — no separate porting tasks needed"). The risk is someone hand-editing `~/Mail/.claude/skills/skill-email/` post-migration out of habit (that habit is literally how the current fork happened); the README should say explicitly "edit in nvim-config, reload via `<leader>al`, never hand-edit a deployed copy."

---

## Recommended Approach

1. **Author the extension at `~/.config/nvim/.claude/extensions/email/`**, matching the observed and self-consistent convention for every other specialized domain (latex, lean, z3, founder, present, etc.) — not at `~/.dotfiles/.claude/extensions/email/` as the task brief assumed. Flag this explicitly to the user as a correction to the brief's premise before `/plan` locks in a target path.
2. **Migrate, don't rebuild**, the `~/Mail/.claude` prior art into that extension's `agents/`, `commands/`, `skills/`, `context/project/email/`, and `scripts/` subdirectories, writing `manifest.json` (declaring every script explicitly), `EXTENSION.md` (routing + the Path A/B/connector/aerc composition seam from Finding 6), and `README.md`. Run `check-extension-docs.sh` before first load.
3. **Ship `email-preferences.md` as a `manifest.provides.data` skeleton file** (non-overwriting `copy_data_dirs()`), and add it to each consuming project's `.syncprotect` after first install, so per-mailbox tuning survives extension updates.
4. **Load `email` selectively via `<leader>al`** into `~/Mail` (retiring its hand-forked copies in favor of the loaded extension) and into any other project that needs `/email`; do not load it into `.dotfiles`'s own root `.claude/` unless dotfiles itself needs to execute email operations (it currently only owns the Nix module declarations, a `nix`-extension concern).
5. **Keep `~/Mail` as a repo**, with its own `specs/` task history for actual mailbox operations, distinct from `.dotfiles/specs/071_.../` which holds this design task's artifacts.
6. **Add a preflight hook** asserting himalaya/notmuch minimum version and OAuth health (`invalid_grant` detection, tying to task 46) before any email-extension command runs against a live account.
7. **State the connector/himalaya/aerc composition seam explicitly** in the extension's `EXTENSION.md`: orchestrate + audit (extension) / execute (himalaya) / human-review (aerc) / zero-setup-triage (connector) — never protocol logic inside the extension itself.

This does not contradict round 2's "split investment: one-time purge tool + minimal ongoing loop" — it is the packaging layer both of those run inside. The heavy one-time purge and the minimal ongoing loop are both `/email` **modes** (`--cleanup` for the former, `--status`/scheduled `--triage` for the latter) within the same extension, exactly as the prior art already models modes as task-status transitions. Packaging as an extension is what makes the "minimal ongoing loop" actually minimal to *maintain* long-term (one versioned source, reload-to-update) rather than minimal only in scope but expensive to keep in sync across repos — which is the failure mode that produced the original fork.

---

## Evidence/Examples

- `extensions.json` `source_dir` fields (all consumers) point to `/home/benjamin/.config/nvim/.claude/extensions/{name}`; nvim-config's own `core.source_dir` points to itself — directly inspected via `jq` across `~/.dotfiles/.claude/extensions.json`, `~/Mail/.claude/extensions.json`, `~/.config/nvim/.claude/extensions.json`.
- `~/.config/nvim/.claude/extensions/` listing: 18 domains vs. `~/.dotfiles/.claude/extensions/`'s 5 — directory listing.
- `~/Mail/.claude/commands/email.md` frontmatter and mode table — read directly; shows `logos`/`gmail` account parameterization already present.
- `~/Mail/.claude/skills/skill-email/SKILL.md` — thin-wrapper-with-internal-postflight pattern, matching this repo's own `context/patterns/postflight-control.md` and `context/patterns/thin-wrapper-skill.md`.
- `~/Mail/.claude/context/project/email/email-preferences.md` — live JSON-rule-block schema (newsletter/notification/promotional/transactional categories with confidence thresholds) already covering much of what round-2 C/A designed from scratch.
- `~/Mail/specs/state.json` — 28-task history, several `completed`, confirming this is a used system, not a stub.
- `docs/architecture/extension-system.md:542` — `data_skeleton_files` / `copy_data_dirs()` documented as "merge-copy, non-overwriting," the exact mechanism for preserving `email-preferences.md`.
- `.claude/scripts/check-extension-docs.sh` — doc-lint already checks for manifest-declared-but-missing scripts/agents/commands/rules; nvim-config's open task 793 documents the exact failure mode (referenced-but-unpackaged scripts) this catches, from the `literature` extension.
- `specs/state.json` task 46 — status `researched` (not yet resolved), confirming the OAuth 7-day-expiry blocker is still live.
- `.memory/10-Memories/MEM-agent-system-reload-propagation.md` (nvim-config) — "Agent system changes... propagate... by reloading via `<leader>al` — no separate porting tasks needed," the reload-not-hand-edit discipline this recommendation depends on.

---

## Confidence Level

**High** for Findings 1, 2, 4, 6 (all directly verified by reading live files/JSON across three repos, not inference).
**Medium-High** for Finding 3 (the migration mechanics are inferred by analogy to the `nix`/`literature` extension packaging patterns already in this repo's docs, not yet executed) and Finding 5 (the selective-loading mechanism is confirmed generic, but the preflight-precondition-hook addition is a recommendation, not yet built).
**Medium** for Finding 7's version-drift risk specifics (himalaya/notmuch pinned-version cross-check is a recommended control, not something currently implemented anywhere).

---

## References

- `~/.dotfiles/.claude/README.md`, `~/.dotfiles/.claude/CLAUDE.md` (extension architecture, generation-from-loaded-extensions model)
- `~/.dotfiles/docs/dual-home-manager.md` (himalaya OAuth2 unmanaged-secret note)
- `specs/071_design_ai_email_management_workflow/reports/02_team-research.md` (round-2 synthesis)
- `~/.dotfiles/.claude/docs/architecture/extension-system.md` (data_skeleton_files/copy_data_dirs semantics)
- `~/.dotfiles/.claude/docs/guides/creating-extensions.md`, `~/.dotfiles/.claude/context/guides/extension-development.md`
- `~/.dotfiles/.claude/scripts/check-extension-docs.sh`
- `~/.dotfiles/.claude/extensions.json`, `~/Mail/.claude/extensions.json`, `~/.config/nvim/.claude/extensions.json` (source_dir evidence)
- `~/Mail/.claude/{agents/email-agent.md, commands/email.md, skills/skill-email/SKILL.md, context/project/email/*, scripts/email/*.py}` (prior art, directly read)
- `~/Mail/specs/state.json` (28-task history)
- `~/.dotfiles/specs/state.json` task 46 (OAuth expiry, status `researched`)
- `~/.config/nvim/.memory/10-Memories/MEM-agent-system-reload-propagation.md`
- `~/.config/nvim/docs/AI_TOOLING.md`, `~/.config/nvim/docs/MAPPINGS.md` (`<leader>al` picker location/behavior)
- `~/.config/nvim/specs/state.json` task 793 (literature-extension script-packaging bug — analogous failure mode to avoid)
