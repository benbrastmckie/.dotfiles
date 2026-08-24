# Research Report: Task #71 (Round 3) — Email Extension & Cross-System Integration

**Task**: 71 — Design AI-assisted email management workflow
**Date**: 2026-07-02
**Mode**: Team Research (4 teammates: A-nvim-loader, B-extension-authoring, C-reconcile/critic, D-horizons)
**Session**: sess_1783021775_ef7877
**Focus**: Study the Neovim `.claude/` agent system + `<leader>al` AI extension loader, to design an
`email/` Claude Code extension that adds clean-up/drafting on top of the tools already researched.
**Builds on**: round-2 synthesis `02_team-research.md` + plan `plans/02_email-workflow-implementation.md`
**Teammate findings**: `03_teammate-{a,b,c,d}-findings.md`

---

## Summary (the one thing that matters)

**The `email/` extension is a packaging/distribution layer, not a new system — and it should be
authored in `~/.config/nvim/.claude/extensions/email/`, which live inspection confirms is the
canonical master extension library, NOT `~/.dotfiles/.claude/extensions/`.** Every extension in
`.dotfiles` and `~/Mail` was *sourced from* `~/.config/nvim/.claude/extensions/*` and installed via
the `<leader>al` loader (a manifest-driven, `.syncprotect`-respecting **file-copy sync**, not a
symlink/build). So the deliverable collapses to **ONE thing**: author `email/` in the nvim-config
extension library, whose `provides:` list is exactly the plan's already-designed Phase 0/3/4 outputs
(preferences doc + `skill-email-cleanup` + `mail-guard.sh` hook), then load it into consuming repos
the same way `nix`/`python`/`latex` are today. The nix wrapper scripts stay nix-owned and unchanged.

Three consequences require a **plan revision** (`/revise 71`) before Phase 0 runs:
1. **Retarget** Phase 0/3/4 authoring paths from `.dotfiles/.claude/...` to the extension layout.
2. **Add** an extension-authoring phase (manifest.json, EXTENSION.md ≤60 lines, `task_type: email`
   routing, `keyword_overrides`, `check-extension-docs.sh` compliance).
3. **Harden a real guardrail gap** the current hook misses (below).

---

## Key Findings by Dimension

### A — the nvim loader & where extensions live (live-verified)

- **`<leader>al`** → `ai-tool-picker.show_commands_picker()` (`shared/picker/ai-tool-picker.lua:250-286`)
  → `:ClaudeCommands` Telescope picker (`claude/commands/picker/init.lua`). Its **Load / Load Core**
  actions (`commands/picker/operations/sync.lua`, `shared/extensions/loader.lua`) do a manifest-driven,
  `.syncprotect`-respecting **file-copy** of `extensions/<name>/*` into a target repo's `.claude/` and
  append an entry to that repo's `.claude/extensions.json`.
- **`~/.config/nvim/.claude/extensions/` is the hardcoded canonical source** (`shared/extensions/config.lua:49`,
  `shared/picker/config.lua:71`) — 18 extension domains. Every `.dotfiles`/`~/Mail` extension's
  `source_dir` points back there. `~/.dotfiles/.claude/` is a *sync target*, not the origin.
- **`~/Mail/.claude/` is already pre-staged**: its `extensions.json` shows `core/memory/nix/nvim/python`
  loaded today, sourced from the nvim library — the user evidently prepared it for this task. **No
  `email` extension exists anywhere yet.**
- **No code bridge** exists between the nvim AI layer and the separate, large Himalaya Neovim plugin.

### B — authoring the `email/` extension (manifest, routing, doc-lint)

- **Recommended shape: full `task_type: "email"` with ASYMMETRIC routing** — reuse shared
  `skill-researcher` + `skill-planner`, but a **custom `skill-email-implementation → email-implementation-agent`**
  because execution is safety-critical (must call wrappers, never raw `himalaya`/`notmuch`). Optionally
  also a direct-execution `/email` command (like `/literature`/`/learn`) for ad-hoc "clean up my inbox now".
- **`keyword_overrides` draft** so `/task "clean up my inbox"` auto-routes to `email`: keywords
  `inbox, email, gmail, himalaya, notmuch, unsubscribe, "junk mail", "draft reply", mbsync, aerc, "mail triage"`;
  aliases `mail, mailbox` (aliases only — bare "mail"/"draft" would false-positive).
- **Interface vs mechanism**: the extension's skills/agent *call* the Phase-2 nix wrappers by name;
  `provides.scripts` stays empty (binaries are `writeShellScriptBin` in `modules/home/`, outside `.claude/`).
- **Hook travels with the extension**: declare `mail-guard.sh` under `provides.hooks` + register the
  PreToolUse matcher via `merge_targets.settings`, so it unloads cleanly (vs orphaning in core).
- **Registration/doc-lint**: `manifest.json` `merge_targets.claudemd`/`index`; EXTENSION.md ≤60 lines;
  `check-extension-docs.sh` must pass (provides exist on disk, routing block present, routing targets
  resolvable, deployed skills reference existing agents, README lists every command).

### C — reconciling the (now FOUR) email surfaces + a guardrail gap

- **FOUR surfaces**, not three: (1) dormant `~/Mail/.claude` harness; (2) the task-71 plan v2;
  (3) the proposed `email/` extension; (4) a **pre-existing Himalaya Neovim plugin**
  (`~/.config/nvim/lua/neotex/plugins/tools/himalaya/` + `mail.lua` keybinds `<leader>me/mS/mf`) with
  its own list/viewer UI — unmentioned anywhere in the plan.
- **"Task 45" does not exist** in `.dotfiles/specs` (grep/jq confirm; nearest are 43 and 46). My earlier
  references to "task 045" were mistaken — the real referent is surface (4) above, an nvim-repo feature.
- **The plan's skill/hook/preferences and the extension are the same deliverable** — repackage the
  plan's Phase 0/3/4 files as the extension's `provides:`; author once in the canonical source.
- **GUARDRAIL GAP (important):** the plan's `mail-guard.sh` regex + `permissions.deny` catch
  `folder expunge`/`send`/`msmtp`/`rm *Mail*`/`secret-tool` — but **NOT `himalaya message delete` or
  `himalaya message move`**, which are the *actual bulk mutations* (move-to-Trash / archive) run before
  expunge. A convenience command calling Himalaya directly would sail through. **Fix: the hook should
  allowlist the five wrapper binaries and DENY raw `himalaya message (delete|move|send)` +
  `folder expunge` outright** — simpler and stronger than token-gating raw commands. This worsens once
  an extension can ship its own commands.
- **`/revise 71` recommended before Phase 0** (structural path/routing changes, not additive). Fallback:
  proceed 0–3 as written, repackage later (accepts file-move churn).

### D — horizons: source of truth, migration, selective loading

- **Author in the nvim-config library so it survives rebuilds and doesn't fork** — the `~/Mail/.claude`
  prior art was a *separate git repo* and got orphaned; don't repeat that. `email/` in the canonical
  library is versioned, loadable, and regenerates CLAUDE.md.
- **`~/Mail` the repo stays** (maildir + `specs/` history are legitimately project-scoped runtime data);
  only its hand-forked `.claude/` copies retire. The extension system's existing
  `data_skeleton_files`/`copy_data_dirs()` + `.syncprotect` preserve `email-preferences.md` across reloads.
- **Selective loading**: email tooling is only useful where mail is synced → the extension should be
  OFF by default and enabled per-machine/project via `<leader>al` (CLAUDE.md regenerates from loaded set).
- **Composition, not replacement**: it composes with the read-only Anthropic connector (drafting) and
  himalaya/aerc (mechanism) — the extension is the orchestration/task-integration layer the prior art
  already proved necessary, which is *why* it earns its keep over bare nix wrappers.

---

## Synthesis

### Conflicts Resolved

1. **Where to author the extension (B vs A/D).** Teammate B assumed `~/.dotfiles/.claude/extensions/email/`;
   A and D proved (live) the canonical source is **`~/.config/nvim/.claude/extensions/email/`** — `.dotfiles`
   is a sync *target*. **Resolution: author canonically in the nvim-config library; install into `.dotfiles`
   (and `~/Mail`, and any project) via `<leader>al`.** B's manifest/routing/doc-lint content is all correct —
   just at the corrected path.

2. **`~/Mail/.claude`: migrate vs harvest-and-retire (D vs C).** D framed it as a working system to
   *migrate* (move + manifest); C argued the round-2 plan already SETTLED on a different, better-guardrailed
   mechanism (nix wrappers + hook + aerc manifest), so reusing the Python harness recreates the round-2
   Postmortem-rule "second uncoordinated agent" risk. **Resolution (lean C, discriminated harvest):**
   RETIRE the harness code (`commands/email.md`, `skill-email`, `email-agent.md`, all **5** Python scripts —
   the plan's Phase 0 says 4, correct to 5: `email_filter.py` was missed); **HARVEST the data** —
   `email-preferences.md` rule taxonomy + JSON schema, and the `MAX_BATCH_SIZE=50` lesson (encode as a
   wrapper/hook limit); **DISCARD** the checkbox-approval UX (churned across `~/Mail` tasks 014/022/023,
   superseded by aerc tagged-views); **DISCARD** the retired command's `model: opus-4-5` pin (follow current
   tiered policy — worker/impl = Sonnet). `~/Mail` the repo persists as a runtime data dir.

3. **task 45 / the 4th surface.** No `.dotfiles` task 45 exists; the real 4th surface is the nvim Himalaya
   plugin + `mail.lua` (`<leader>me/mS/mf`). **Resolution: add a keybind-collision check** (any new email
   keybinds must not shadow `<leader>m*`) and an **open UX question** for the planner — should the
   `Proposed-Delete/Archive/Unsure` review views live in aerc (as planned) or surface inside the existing
   Himalaya Neovim plugin's `ui/` layer? Not answered this round.

### Recommendations (converged)

**A. Revise the plan (`/revise 71`) before Phase 0 runs** — scoped, mechanical:
- Retarget Phase 0 (preferences output), Phase 3 (hook), Phase 4 (skill) and the Artifacts list to the
  **`~/.config/nvim/.claude/extensions/email/`** layout (authored there, installed via loader).
- Add one phase (or expand Phase 4): manifest.json (`task_type: email`, asymmetric routing,
  `keyword_overrides`, `provides` incl. `hooks` + `merge_targets.settings`), EXTENSION.md, README,
  index-entries.json, and `check-extension-docs.sh` compliance.
- **Fold in the hook hardening**: allowlist the 5 wrapper binaries; deny raw
  `himalaya message (delete|move|send)` + `folder expunge` outright.
- Correct Phase 0's "4 Python scripts" → 5; add the harvest/discard table below; add the `<leader>m*`
  keybind-collision check.
- Do NOT reopen: nix phases (2/5/8/10), Phase 6 single-message dry-run, Phase 9 purge, Postmortem
  Constraints, Preserved Assets, or any SETTLED decision.

**B. Deliverable structure (one thing):**
```
~/.config/nvim/.claude/extensions/email/         ← canonical source (author here first)
  manifest.json        (task_type email; research→skill-researcher, plan→skill-planner,
                        implement→skill-email-implementation; keyword_overrides; provides
                        hooks/skills/agents/context; merge_targets claudemd/index/settings)
  EXTENSION.md (≤60 ln), README.md, index-entries.json
  agents/email-implementation-agent.md   (wrapper-only, confirmation-token contract)
  skills/skill-email-implementation/SKILL.md   (task-lifecycle /implement target)
  skills/skill-email-cleanup/SKILL.md          (ad-hoc /email direct-execution; = plan Phase 4)
  hooks/mail-guard.sh                            (= plan Phase 3, hardened per F4)
  context/project/email/…                        (wrapper contracts, preferences harvested from ~/Mail)
→ installed via <leader>al into .dotfiles/.claude/, ~/Mail/.claude/, projects (OFF by default)
modules/home/{packages/email-tools.nix, email/*.nix}   ← UNCHANGED, nix-owned, referenced not bundled
```

**C. Harvest table (`~/Mail/.claude` → new extension):** HARVEST `email-preferences.md` taxonomy + JSON
schema; HARVEST `MAX_BATCH_SIZE=50` as a wrapper/hook limit; DISCARD the 5 Python scripts, the
command/skill/agent harness, the checkbox UX, and the opus model pin; PARTITION the Logos/Bridge lessons
into the Phase-12 deferral doc as a pointer.

**D. Selective loading & composition:** `email/` OFF by default, enabled per-machine via `<leader>al`;
composes with (not replaces) the read-only connector (draft), himalaya/aerc (mechanism); source of truth
is the nvim-config library so it survives rebuilds.

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | nvim `<leader>al` loader + canonical source mapping | completed | High (line-cited + live JSON) |
| B | `email/` extension authoring (manifest/routing/doc-lint) | completed | High mechanics, Medium routing-shape judgment |
| C | Reconcile 4 surfaces + guardrail gap + revise call | completed | Medium-High (task-45 inference flagged) |
| D | Cross-system source-of-truth, migration, selective loading | completed | High on 1/2/4/6, Medium on drift |

## New / Updated Open Questions (for `/revise 71` and user)

- **[USER] Confirm the extension lives in `~/.config/nvim/.claude/extensions/email/`** (canonical library),
  loaded into repos via `<leader>al`, OFF by default — vs authored directly in `.dotfiles`.
- Should the backlog-review UI surface in **aerc** (planned) or the existing **Himalaya Neovim plugin**?
- Keybind-collision check vs `<leader>me/mS/mf` before adding any email keybinds.
- Confirm the harvest/discard verdicts on `~/Mail/.claude` (esp. retire the Python harness).
- "task 45" was a mis-reference — confirm nothing numbered was intended.

---

## References

- nvim loader: `~/.config/nvim/lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`,
  `.../claude/commands/picker/{init.lua,operations/sync.lua}`, `.../shared/extensions/{loader,config,state}.lua`
- 4th surface: `~/.config/nvim/lua/neotex/plugins/tools/himalaya/README.md`, `~/.config/nvim/lua/neotex/plugins/tools/mail.lua`
- Extension system: `.claude/extensions.json`, `.claude/extensions/{core,nix,python,nvim,memory}/manifest.json`,
  `.claude/context/guides/extension-development.md`, `.claude/docs/guides/creating-extensions.md`,
  `.claude/docs/reference/standards/extension-slim-standard.md`, `.claude/scripts/check-extension-docs.sh`,
  `.claude/commands/task.md` (§4a-4e keyword resolution)
- Prior art: `~/Mail/.claude/{commands/email.md,skills/skill-email,agents/email-agent.md,scripts/email/*.py,context/project/email/email-preferences.md}`, `~/Mail/specs/archive/{014,022,023}_*`
- Task 71 plan: `specs/071_design_ai_email_management_workflow/plans/02_email-workflow-implementation.md`
- Round-2 synthesis: `specs/071_design_ai_email_management_workflow/reports/02_team-research.md`

---

*Round-3 team research synthesis. Actionable next step: `/revise 71` to fold the email-extension packaging
+ hook hardening into the existing 13-phase plan (nix/purge/postmortem phases unchanged).*
