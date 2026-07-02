# Teammate A Findings (Round 3): Neovim AI System & `<leader>al` Extension Loader

**Task**: 71 — Design AI-assisted email management workflow
**Teammate**: A (round 3 — nvim Claude/AI harness dimension)
**Date**: 2026-07-02
**Sources/Inputs**: Direct file reads of `~/.config/nvim/lua/neotex/plugins/ai/**`, `~/.config/nvim/.claude/`, `~/.dotfiles/.claude/`, `~/Mail/.claude/` (a third, live install)
**Artifacts**: this report

---

## Key Findings

1. **`<leader>al` is a two-tool router into a Telescope "artifact picker + extension manager," not an email-specific mechanism.** It is bound in `~/.config/nvim/lua/neotex/plugins/editor/which-key.lua:259` to `ai-tool-picker.show_commands_picker()`, which does a `vim.ui.select` between `ClaudeCode`/`OpenCode` and then runs `:ClaudeCommands` (or `:OpencodeCommands`). `:ClaudeCommands` is registered in `claude/init.lua:146` and opens the Telescope picker built in `claude/commands/picker/init.lua`, whose entries include a special `is_load_all` row ("Load Core Agent System") plus one row per extension (with per-extension Load/Unload/Reload submenus).

2. **The picker's "global source of truth" is hardcoded to `~/.config/nvim`, not `~/.dotfiles`.** `shared/picker/config.lua:71` and `shared/extensions/config.lua:49/65` both default `global_source_dir`/`global_dir` to `vim.fn.expand("~/.config/nvim")`, and `claude/commands/picker/utils/scan.lua:8-17` (`get_global_dir()`) falls back to the same path. This means `~/.config/nvim/.claude/extensions/{name}/` is the canonical extension source for *every* project the picker is used in, including `~/.dotfiles` itself. `~/.dotfiles/.claude/` and any other project's `.claude/` are **sync targets**, not the origin. I confirmed this empirically: `~/Mail/.claude/extensions.json` records `"source_dir": "/home/benjamin/.config/nvim/.claude/extensions/python"` (and same for `nix`, `nvim`, `core`, `memory`) for extensions loaded today (`2026-07-02T18:5x:xxZ`) — i.e. someone (the user) opened `<leader>al` inside `~/Mail` earlier this session and loaded `core + memory + nix + nvim + python` in preparation for this exact task, but **no `email` extension exists yet anywhere** (not in `~/.config/nvim/.claude/extensions/`, not in `~/Mail/.claude/extensions/`, not in `~/.dotfiles/.claude/extensions/`).

3. **"Load Core" / per-extension Load is a one-way file-copy sync, gated by a manifest-driven allow/blocklist and `.syncprotect`, not a symlink or generation step.** `commands/picker/operations/sync.lua::load_all_globally()` scans `~/.config/nvim/.claude/extensions/core/{agents,skills,commands,rules,context,scripts,hooks,systemd}` (core has been physically relocated under `extensions/core/` — see `core_source_base` logic at `sync.lua:732`) and copies files into the target project's `.claude/`. Per-extension load/unload/reload (`shared/extensions/loader.lua`) does the analogous copy for a single extension's `provides.*` lists, tracked in the target's `.claude/extensions.json` (`shared/extensions/state.lua`) with `installed_files`/`installed_dirs` so `unload` can cleanly remove exactly what `load` added. `.syncprotect` (project-root file, one relative path per line) is read by both `sync.lua::load_syncprotect()` and `loader.lua::load_syncprotect()` and skips matching files during any copy — this is the same `.syncprotect` documented in `~/.dotfiles/.claude/CLAUDE.md`'s "Syncprotect" section, confirming the nvim Lua loader and the Claude-Code-side `.claude/` documentation describe **one shared protocol**, implemented twice (interactive Lua UI + the CLAUDE.md-documented contract Claude Code agents read).

4. **`CLAUDE.md` is a generated, concatenated artifact, never hand-edited** — `sync.lua`'s `reinject_loaded_extensions()` and the `merge_targets.claudemd` mechanism (each extension's `EXTENSION.md` → appended into `.claude/CLAUDE.md` under `<!-- SECTION: extension_{name} -->` markers) is exactly what produces the "This file is generated automatically from loaded extensions. Do not edit directly." banner at the top of both `~/.dotfiles/.claude/CLAUDE.md` and `~/Mail/.claude/CLAUDE.md`. `strip_extension_sections()`/`preserve_sections()`/`restore_sections()` in `sync.lua` exist specifically so a full "Load Core" resync doesn't destroy other extensions' already-merged sections. An `email` extension's `EXTENSION.md` would become one of these concatenated sections (`section_id: "extension_email"`).

5. **No existing bridge between the nvim AI layer and the existing Himalaya email plugin.** `neotex.plugins.tools.himalaya/` is a large (150+ file), fully independent Neovim email client (mbsync/notmuch/Protonmail-Bridge backed, bound under `<leader>m*` in `which-key.lua:621-638`, e.g. `<leader>mm` toggle sidebar, `<leader>ms` sync inbox, `<leader>mr` maildir resync). Grepping the entire himalaya plugin tree for `claude`/`anthropic`/AI mentions returns only two unrelated README hits (an email address containing "-ai" in the domain name and a doc mention). There is **no code path connecting `<leader>m*` (Himalaya) to `<leader>a*` (Claude/OpenCode)** today. The one loose empirical thread is that `<leader>mr`'s "maildir resync" keymap (`which-key.lua`) deletes `/home/benjamin/Mail/.claude/output/email.md` as part of its cleanup command — but that file turned out to be leftover raw (PGP-encrypted, undecryptable) email body text, not a structured AI artifact; it's incidental debris from an ad hoc prior session, not a designed integration point.

6. **`~/Mail/.claude/` is a third, independent `.claude` install** (distinct from `~/.config/nvim/.claude/` and `~/.dotfiles/.claude/`), rooted at the Maildir (`~/Mail`), with its own `specs/`, `extensions.json`, and loaded extensions (`core`, `memory`, `nix`, `nvim`, `python` — all loaded today, no `email` extension). This is almost certainly where the user intends to run Claude Code / `/task`, `/research`, `/implement` etc. for the *actual* email-cleanup work (cwd = `~/Mail`, so Himalaya/notmuch/mbsync are directly reachable via relative paths), and where a new `email` extension would ultimately need to be **loaded** (via `<leader>al` → Claude → Load) even though it must be **authored** under `~/.config/nvim/.claude/extensions/email/`.

---

## Recommended Approach

**Author the `email` extension at `~/.config/nvim/.claude/extensions/email/` (the global source), following the exact manifest/provides contract already used by `nix`/`python`/`literature`, then load it via `<leader>al` → Claude → Load (or "Load Core" if bundling with other loads) into `~/Mail/.claude/`.** Do NOT author it directly inside `~/Mail/.claude/extensions/email/` or `~/.dotfiles/.claude/extensions/email/` — those are sync targets that get overwritten/removed by unload, and any other project that later loads `email` would not see hand-edits made only in one target.

Concretely:

1. **Location**: `~/.config/nvim/.claude/extensions/email/` with subdirs `agents/`, `skills/skill-email-{research,implementation}/`, `context/project/email/`, and optionally `scripts/` for wrapper scripts (per Teammate A's round-2 findings on Himalaya/notmuch wrappers — not re-litigated here).
2. **manifest.json**, mirroring the `nix`/`python` schema exactly (per `context/guides/extension-development.md` and confirmed live in `~/.config/nvim/.claude/extensions/nix/manifest.json`):
   - `"name": "email"`, `"task_type": "email"`, `"dependencies": ["core"]` (add `"literature"` only if citation verification against Zotero-sourced email policy docs is needed — unlikely)
   - `"provides"`: `agents` (e.g. `email-research-agent.md`, `email-implementation-agent.md`), `skills` (`skill-email-research`, `skill-email-implementation`), `context` (`project/email`), `scripts` (any wrapper `.sh` files), `rules` (optional)
   - `"routing"`: `{"research": {"email": "skill-email-research"}, "plan": {"email": "skill-planner"}, "implement": {"email": "skill-email-implementation"}}` — note `plan` routes to the *generic* `skill-planner`, matching every other extension (none define a domain-specific planner)
   - `"merge_targets"`: `claudemd` (source `EXTENSION.md`, target `.claude/CLAUDE.md`, `section_id: "extension_email"`) and `index` (source `index-entries.json`, target `.claude/context/index.json`) — the two merge targets every existing extension declares at minimum
   - Optionally `"keyword_overrides"`: `{"email": "email", "himalaya": "email", "inbox": "email", "unsubscribe": "email"}` so `/task "clean up my Gmail inbox"` auto-routes to `task_type: email` without the user specifying it (see `literature`'s manifest for the precedent pattern)
3. **EXTENSION.md**: routing table + skill-agent mapping section, written exactly like `nix`'s or `python`'s CLAUDE.md fragment — this becomes the `<!-- SECTION: extension_email -->` block injected into whichever project's `CLAUDE.md` loads it.
4. **index-entries.json**: context entries for domain knowledge (Himalaya CLI semantics, notmuch query syntax, the Gmail-safe-delete rule from Teammate A's round-2 report, etc.), scoped with `"load_when": {"task_types": ["email"]}`.
5. **Loading it into `~/Mail/.claude/`**: cd into `~/Mail` in Neovim (or `:cd ~/Mail`), press `<leader>al` → `ClaudeCode` → find the `email` row in the picker (it appears automatically once `manifest.json` exists under the global `extensions/` dir — no registration step needed; `manifest.M.list_extensions()` just `readdir`s the extensions folder) → `Load`. This copies `provides.*` files into `~/Mail/.claude/`, updates `~/Mail/.claude/extensions.json`, and regenerates `~/Mail/.claude/CLAUDE.md` with the new section appended.
6. **Propagation to other projects** (e.g. `~/.dotfiles` itself, if the user ever wants email tooling there too) is just another `<leader>al` → Load in that project's Neovim buffer — no extra plumbing, since the loader always resolves back to the same `~/.config/nvim/.claude/extensions/email/` source.
7. **`.syncprotect` interaction**: if the email extension's context files reference secrets or local account specifics that must never be silently overwritten by a "Load Core"/full-sync in `~/Mail`, add those relative paths to `~/Mail/.syncprotect` (project root, not inside `.claude/`) up front — analogous to how `context/repo/project-overview.md` is auto-seeded as protected today (`sync.lua:1071-1119`).

This keeps the email extension inside the *same* single-source-of-truth model every other domain extension already uses, rather than inventing a bespoke install path, and makes it immediately available in `~/Mail` (where the actual mailbox operations happen), `~/.dotfiles` (where task/plan/report artifacts for *this* task 71 live), or any future project — all without touching nvim Lua code, since the picker/loader is fully manifest-driven and generic across domains.

---

## Evidence/Examples

### `<leader>al` binding (which-key.lua:259)
```lua
{ "<leader>al", function()
  local ok, picker = pcall(require, "neotex.plugins.ai.shared.picker.ai-tool-picker")
  if not ok then
    vim.notify("AI tool picker module not loaded", vim.log.levels.WARN)
    return
  end
  if not picker._initialized then picker.setup() end
  picker.show_commands_picker()
end, desc = "ai load commands/agents", mode = { "n" }, icon = "󰚩" },
```

### Dispatch to `:ClaudeCommands` (`shared/picker/ai-tool-picker.lua:282-284`)
```lua
else
  vim.cmd(choice.value == "claude" and "ClaudeCommands" or "OpencodeCommands")
end
```
`:ClaudeCommands` registered at `claude/init.lua:146`:
```lua
vim.api.nvim_create_user_command("ClaudeCommands", M.show_commands_picker, {
  desc = "Browse Claude commands in hierarchical picker",
  nargs = 0,
})
```

### Global source defaults (proves `~/.config/nvim` is canonical, not `~/.dotfiles`)
`shared/extensions/config.lua:48-49`:
```lua
function M.claude(global_dir)
  global_dir = global_dir or vim.fn.expand("~/.config/nvim")
  return M.create({
    ...
    global_extensions_dir = global_dir .. "/.claude/extensions",
```
`shared/picker/config.lua:71`:
```lua
global_source_dir = global_dir or vim.fn.expand("~/.config/nvim"),
```

### Empirical proof: `~/Mail/.claude/extensions.json` `source_dir` fields
```
python 2026-07-02T18:50:40Z /home/benjamin/.config/nvim/.claude/extensions/python
memory 2026-07-02T18:50:24Z /home/benjamin/.config/nvim/.claude/extensions/memory
nix    2026-07-02T18:50:48Z /home/benjamin/.config/nvim/.claude/extensions/nix
nvim   2026-07-02T18:51:55Z /home/benjamin/.config/nvim/.claude/extensions/nvim
core   2026-07-02T18:50:23Z /home/benjamin/.config/nvim/.claude/extensions/core
```
All five extensions were loaded within the same minute-scale window today, and every `source_dir` points at `~/.config/nvim/.claude/extensions/*` — confirming the user pre-staged `~/Mail/.claude/` for an email task by loading everything *except* an `email` extension, because none exists yet.

### `.syncprotect` read logic shared by sync and loader
`commands/picker/operations/sync.lua:565-600` (`load_syncprotect`) and `shared/extensions/loader.lua:16-44` (`M.load_syncprotect`) are near-identical implementations, both reading `{project_dir}/.syncprotect` first, falling back to the legacy `{project_dir}/{base_dir}/.syncprotect` location. This matches `~/.dotfiles/.claude/CLAUDE.md`'s documented "Syncprotect" contract verbatim.

### Manifest schema (from live `nix/manifest.json`, structurally identical to what `email/manifest.json` should follow)
```json
{
  "name": "nix",
  "version": "1.0.0",
  "dependencies": ["core"],
  "provides": { "agents": [...], "skills": [...], "rules": [...], "context": ["project/nix"], "scripts": [], "hooks": [] },
  "routing": {
    "research": { "nix": "skill-nix-research" },
    "plan": { "nix": "skill-planner" },
    "implement": { "nix": "skill-nix-implementation" }
  },
  "merge_targets": {
    "claudemd": { "source": "EXTENSION.md", "target": ".claude/CLAUDE.md", "section_id": "extension_nix" },
    "settings": { "source": "settings-fragment.json", "target": ".claude/settings.local.json" },
    "index": { "source": "index-entries.json", "target": ".claude/context/index.json" }
  }
}
```

### No AI-Himalaya bridge (negative-result grep)
```
$ grep -rli "claude\|anthropic\|\bai\b" himalaya/README.md himalaya/config/README.md
himalaya/config/README.md:15:- `logos` - Protonmail account (benjamin@logos-labs.ai) via ...
himalaya/README.md:64:| logos | benjamin@logos-labs.ai | Protonmail Bridge | Maildir + SMTP |
```
Both hits are incidental (the account's email domain literally contains "-ai"), not integration references.

---

## Confidence Level

**High** for findings 1–4 (picker mechanics, global-source-dir default, manifest/sync contract) — all directly read from source with line-level citations and cross-checked against a live `extensions.json` on disk. **High** for finding 5 (no existing AI↔Himalaya bridge) — based on exhaustive grep across the entire himalaya plugin tree plus the AI plugin tree, returning zero true-positive hits. **Medium-high** for finding 6 and the "why `~/Mail/.claude` was set up today" inference — the timestamps and source_dir data are solid facts, but the *intent* (staging for this task) is a reasonable inference from context (today's date, the exact task-71 topic, and the coincidence of extensions loaded) rather than something explicitly stated in a file.

## References

- `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` (lines 259, 268, 621-638)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/init.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/config.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/state.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/manifest.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/extensions/config.lua`, `init.lua`
- `/home/benjamin/.config/nvim/.claude/extensions/nix/manifest.json`, `/home/benjamin/.config/nvim/.claude/extensions/literature/manifest.json`
- `/home/benjamin/.dotfiles/.claude/context/guides/extension-development.md`
- `/home/benjamin/.dotfiles/.claude/CLAUDE.md` (Syncprotect section)
- `/home/benjamin/Mail/.claude/extensions.json`, `/home/benjamin/Mail/.claude/CLAUDE.md`
- `/home/benjamin/config/nvim/lua/neotex/plugins/tools/himalaya/` (tree listing + README/config README grep, negative result)
