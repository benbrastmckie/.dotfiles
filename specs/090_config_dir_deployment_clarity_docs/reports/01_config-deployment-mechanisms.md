# Research Report: Task #90

**Task**: 90 - Document config/ deployment mechanisms in the NixOS/Home Manager dotfiles repo
**Started**: 2026-07-04T00:00:00Z
**Completed**: 2026-07-04T00:00:00Z
**Effort**: small (doc-only)
**Dependencies**: 88 (completed — renamed `modules/home/core/shell.nix` -> `modules/home/core/dotfiles.nix`)
**Sources/Inputs**:
- Codebase: `modules/home/core/dotfiles.nix`, `config/README.md`, `config/` directory listing, `.claude/README.md`
- specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md
- specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md
- specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md (§1.2, §1.3, §2 row 7, §3 row 9, §5 row 4)
**Artifacts**: this report (`specs/090_config_dir_deployment_clarity_docs/reports/01_config-deployment-mechanisms.md`)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 88 already renamed `modules/home/core/shell.nix` -> `modules/home/core/dotfiles.nix` (commit `a6bbecb task 88 phase 5: rename core/shell.nix to core/dotfiles.nix`). The rename is confirmed live; `shell.nix` no longer exists in `modules/home/core/`.
- All three deployment mechanisms live in the single file `modules/home/core/dotfiles.nix` and are precisely locatable by line range (given below). No other file in `modules/` implements any of the three mechanisms for `config/*` content (the only other `home.file`/`readFile` hits are unrelated: `modules/home/email/aerc.nix` and `mbsync.nix` use `home.file.*.text` with inline heredocs, not `config/` sources).
- `dotfiles.nix`'s current 2-line header comment (lines 1-2) does **not yet** contain a cross-reference to `config/README.md` — this is the "required cross-reference" location the task description refers to; it needs to be *added*, not merely confirmed as already present.
- `config/README.md`'s current "Notes" section already gestures at the three mechanisms in prose ("Most configs are deployed as symlinks; `claude/`, `rclone.conf`, and `.zuliprc` use activation scripts...") but this sentence is **factually stale**: `.zuliprc` is actually deployed via `home.file.".zuliprc".source` (a plain store-symlink, mechanism 1), not an activation script, and `config/rclone.conf` has **no** activation script or any `.nix` reference at all today (it is untracked/gitignored, confirmed dead — matches design doc's "already resolved, nothing to do" disposition). The doc expansion should fix this inaccuracy while adding the three-mechanism structure, since it falls within the same file the task modifies.
- Both required callouts (config/ vs Nix `config` argument shadowing; `.claude/` vs `config/claude/` naming collision) are directly grounded in current code and are explicitly mandated by the task-81 design documents (`target-layout.md` §1.2, §2 row 7, §5 row 4).
- The force-overwrite behavior for `config/claude/{settings,keybindings}.json` -> `~/.claude/{settings,keybindings}.json` is confirmed in the activation script body (`rm -f` then `cp` then `chmod u+w`, unconditionally, every activation) — this is pre-existing intended behavior to document and flag, not to change.

## Context & Scope

Task 90 is a doc-only markdown task (parent 81, blueprint subtask #9, Tier 2/optional) that expands `config/README.md` to document all three existing `config/` deployment mechanisms, plus two required callouts and one required preserve-and-flag note. Its sole dependency (task 88) completed the `shell.nix` -> `dotfiles.nix` rename that subtask 9's cross-reference targets. This research grounds every claim the eventual doc-writing pass needs directly against current file contents (no speculation), per the doc-only/verify-first rescoping noted in task 69's recent commit history and this repo's "docs verified against source, not fixed once" convention (target-layout.md §3, subtask 10).

**Out of scope for this research** (per design doc §1.2, inherited verbatim by subtask 9): `.claude/`, `.memory/`, `.opencode/`, `specs/` are the agent-orchestration tree and must not be edited by this task's implementation — the task's job is only to *document* the `.claude/` vs `config/claude/` collision, never to touch `.claude/` itself.

## Findings

### Codebase Patterns

#### Mechanism 1: `home.file.*.source` store symlinks

File: `modules/home/core/dotfiles.nix`, lines 19-40 (`home.file = { ... }` block) plus line 57 (a fourth, standalone `home.file.".zuliprc".source` assignment outside the main block):

```
19    home.file = {
20      ".config/fastfetch/config.jsonc".source = ../../../config/fastfetch.jsonc;
21      ".config/opencode/opencode.json".source = ../../../config/opencode.json;
22      ".config/sioyek/prefs_user.config".source = ../../../config/sioyek/prefs_user.config;
23      ".config/sioyek/keys_user.config".source = ../../../config/sioyek/keys_user.config;
25      ".config/niri/config.kdl".source = ../../../config/config.kdl;
30      ".config/fish/config.fish".source = ../../../config/config.fish;
31      ".config/kitty/kitty.conf".source = ../../../config/kitty.conf;
32      ".config/zathura/zathurarc".source = ../../../config/zathurarc;
33      ".config/alacritty/alacritty.toml".source = ../../../config/alacritty.toml;
34      ".config/wezterm/wezterm.lua".source = ../../../config/wezterm.lua;
35      ".config/himalaya/config.toml".source = ../../../config/himalaya-config.toml;
39      ".tmux.conf".source = ../../../config/.tmux.conf;
40      ".latexmkrc".source = ../../../config/latexmkrc;
...
57  home.file.".zuliprc".source = ../../../config/zuliprc;
```

These are Nix store symlinks: `home-manager switch` places a symlink at e.g. `~/.config/kitty/kitty.conf` pointing into the Nix store (immutable at runtime; edits must go through `config/` + rebuild). This is the mechanism `config/README.md`'s existing tables already describe correctly for most rows (e.g. "Deployed To" column), **except** the "Chat" table row, which currently mis-describes `.zuliprc` as "*(activation script)*... created via activation script, not symlinked" — that description is stale/wrong; it is in fact mechanism 1 (a plain `home.file.*.source` symlink), confirmed by line 57 above and by the absence of any `zuliprc`-related activation script anywhere in `modules/`.

#### Mechanism 2: `builtins.readFile` copies mirrored into `~/.config/config-files/`

File: `modules/home/core/dotfiles.nix`, lines 42-49 (a second, distinct `home.file` sub-block, same top-level attrset started at line 19):

```
42    # Config-files directory (actual file copies for version control)
43    ".config/config-files/config.fish".text = builtins.readFile ../../../config/config.fish;
44    ".config/config-files/kitty.conf".text = builtins.readFile ../../../config/kitty.conf;
45    ".config/config-files/zathurarc".text = builtins.readFile ../../../config/zathurarc;
46    ".config/config-files/alacritty.toml".text = builtins.readFile ../../../config/alacritty.toml;
47    ".config/config-files/wezterm.lua".text = builtins.readFile ../../../config/wezterm.lua;
48    ".config/config-files/.tmux.conf".text = builtins.readFile ../../../config/.tmux.conf;
49    ".config/config-files/latexmkrc".text = builtins.readFile ../../../config/latexmkrc;
```

`builtins.readFile` reads the source file's contents at *evaluation* time and re-materializes them as `.text`, which Home Manager also deploys as a store symlink — but at a **second**, parallel destination path (`~/.config/config-files/<name>`) alongside the mechanism-1 symlink at the application's real config path. This is a second, independent copy of the same 7 files (`config.fish`, `kitty.conf`, `zathurarc`, `alacritty.toml`, `wezterm.lua`, `.tmux.conf`, `latexmkrc`) used purely as a version-control-visible mirror under `~/.config/config-files/`, per the existing "Some configs are also copied to `~/.config/config-files/` for version control backup" line already in `config/README.md`'s Notes section (accurate as-is, but under-specified: it doesn't name the mechanism or list which 7 files, and should be pulled into its own documented mechanism rather than left as an unglossed Notes bullet).

Note the asymmetry: only 7 of the ~13 mechanism-1 files get a mechanism-2 mirror (`fastfetch.jsonc`, `opencode.json`, `sioyek/*`, `niri/config.kdl`, `himalaya-config.toml`, `.zuliprc` do **not** get a `config-files/` mirror). This asymmetry is a fact worth stating precisely in the expanded doc rather than glossing as "some configs."

#### Mechanism 3: activation-script `cp` for `config/claude/{settings,keybindings}.json`

File: `modules/home/core/dotfiles.nix`, lines 59-68:

```
59    # Copy claude config files as regular files (not symlinks) so Claude Code can write to them
60    home.activation.claudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
61      mkdir -p ${config.home.homeDirectory}/.claude
62      rm -f ${config.home.homeDirectory}/.claude/settings.json
63      cp ${../../../config/claude/settings.json} ${config.home.homeDirectory}/.claude/settings.json
64      chmod u+w ${config.home.homeDirectory}/.claude/settings.json
65      rm -f ${config.home.homeDirectory}/.claude/keybindings.json
66      cp ${../../../config/claude/keybindings.json} ${config.home.homeDirectory}/.claude/keybindings.json
67      chmod u+w ${config.home.homeDirectory}/.claude/keybindings.json
68    '';
```

This is a Home Manager activation script (`home.activation.claudeSettings`, ordered `entryAfter [ "writeBoundary" ]`), not a `home.file` declaration at all. On every `home-manager switch` it unconditionally: creates `~/.claude/` if absent, force-deletes any existing `~/.claude/settings.json` and `~/.claude/keybindings.json`, copies the `config/claude/` originals over them as plain (non-symlink, writable) regular files, then `chmod u+w`s them so Claude Code itself can write to them at runtime (e.g. the CLI's own settings mutations). `config/claude/` currently contains exactly these two files (`ls config/claude/` confirms only `keybindings.json` and `settings.json`, no other content) — the copy targets in the script match 1:1 with `config/claude/`'s actual contents.

**Confirmed force-overwrite semantics** (the pre-existing, intended behavior task 90 must document and flag, not fix): the `rm -f` + `cp` sequence runs unconditionally on every activation, with no diff/merge/skip-if-newer logic. Any manual edit made directly to `~/.claude/settings.json` or `~/.claude/keybindings.json` (not round-tripped back into `config/claude/settings.json` / `config/claude/keybindings.json` first) is silently destroyed on the next `home-manager switch`. This is corroborated by `target-layout.md` §5 row 4 ("Resolve-in-subtask 9 ... Pre-existing, intended behavior — not something this task fixes ... must document and preserve this exact semantic, flagging it explicitly rather than silently widening what gets force-copied") and by report 02's Coverage Gap #4 (same wording). The doc must state this plainly as a documented, intentional constraint — e.g. "if you edit `~/.claude/settings.json` directly, copy your changes back into `config/claude/settings.json` before your next rebuild, or they will be lost."

### Cross-reference: dotfiles.nix header comment

Current header (`modules/home/core/dotfiles.nix` lines 1-2):

```
1  # Dotfiles deployment: session variables, home.file sources from config/, and related
2  # activation scripts.
```

This comment already *describes* what the file does but contains **no explicit pointer** to `config/README.md`. The task description's "cross-reference from dotfiles.nix's header comment" (target-layout.md §1.3, §3 row 9) is a requirement to *add* a line such as "See `config/README.md` for the full deployment-mechanism reference" to this header — confirmed this is not already present, so the implementation step is a genuine addition, not a verification-only no-op.

### External Resources

Not applicable — this is a purely internal documentation task; no external library/tool documentation is relevant. No web research was performed (Search Priority 1, codebase-first, fully answers the task).

### Two Required Callouts (grounded)

**(a) `config/` directory vs. Nix `config` module-argument shadowing.**

`modules/home/core/dotfiles.nix` line 3 declares the module function signature `{ config, pkgs, ... }:`. Inside the module body, the identifier `config` refers exclusively to the Home Manager module-system config attrset (used at lines 16 `config.home.homeDirectory`, 60/71 `config.lib.dag.entryAfter`, 61/63-67 `config.home.homeDirectory`). It never refers to the repo-root `config/` directory. The repo-root directory is always referenced via **relative filesystem paths** (`../../../config/...`, e.g. lines 20-57, 63, 66), never via the `config` argument. This is a real, easily-conflated naming collision for anyone reading the file cold: a reader skimming `config.home.homeDirectory` next to `../../../config/claude/settings.json` needs to understand these are two unrelated things that happen to share the string "config" — one is the Nix module-system's ubiquitous convention-named function argument, the other is this repo's dotfiles-source directory. Confirmed directly in the file; no other module conflates them today, but the doc should flag it explicitly since `dotfiles.nix` is the one file where both appear side-by-side most densely.

**(b) `.claude/` (agent-orchestration system, OUT of scope) vs. `config/claude/` (deployed dotfiles, IN scope) naming collision.**

Confirmed as two entirely separate directories at the repo root:
- `.claude/` — the agent-orchestration system (this very system: `.claude/README.md` opens with "# Claude Code Agent System"; contains `commands/`, `skills/`, `agents/`, `context/`, `rules/`, etc.). Explicitly out of scope for task 81 and all its subtasks per `target-layout.md` §1.2 ("Explicitly out of scope and untouched: `.claude/`, `.memory/`, `.opencode/`, `specs/`").
- `config/claude/` — a small dotfiles-source subdirectory containing exactly `settings.json` and `keybindings.json` (confirmed via `ls config/claude/`), which are copied by the mechanism-3 activation script into the **runtime** `~/.claude/settings.json` / `~/.claude/keybindings.json` (i.e., the deployed target directory also happens to be named `~/.claude/` — a third occurrence of the string, distinct again from both `.claude/` in this repo and `config/claude/`). In scope for task 81/90.

This is exactly the collision flagged in `target-layout.md` §1.2 ("Naming collision to never conflate") and §2 row 7, and Coverage Gap #3 in report 02 ("flag the `.claude/` (agent system) vs. `config/claude/` (deployed dotfiles) naming collision so it isn't conflated during the reorg conversation or in subtask 9's documentation"). The doc must state plainly: three distinct things share the substring "claude" — this repo's `.claude/` agent system (out of scope, untouched), this repo's `config/claude/` dotfiles source (in scope), and the deployed runtime target `~/.claude/` (the user's actual Claude Code CLI config directory, which happens to have the same name as this repo's own `.claude/` but lives in `$HOME`, not in this repo).

### Recommendations

For the doc-writing pass (not performed here — this is research only):

1. Restructure `config/README.md` around the three named mechanisms (rather than only per-application tables), e.g. a new "## Deployment Mechanisms" section preceding or supplementing the existing per-category tables, enumerating: (1) store symlinks via `home.file.*.source`, (2) `builtins.readFile` mirrors into `~/.config/config-files/` (list exactly which 7 files), (3) the `config/claude/` activation-script `cp`.
2. Fix the stale `.zuliprc` "activation script" claim in the existing "Chat" table row — it is mechanism 1, not an activation script.
3. Add the two required callouts as their own clearly headed subsections (e.g. "## Naming Hazards") rather than folding them into prose, given both are explicitly mandated, precisely-worded requirements from the design doc.
4. Add the force-overwrite warning for `config/claude/*` as part of describing mechanism 3, worded as intentional/documented behavior, not a defect — matching the design doc's exact framing ("document and preserve this exact semantic, flagging it explicitly rather than silently widening what gets force-copied").
5. Add a "See config/README.md" pointer line to `dotfiles.nix`'s header comment (lines 1-2) as part of the same change set, satisfying the cross-reference requirement.
6. Optionally correct/clarify the existing Notes bullet about `~/.config/config-files/` once the dedicated mechanism-2 section exists, to avoid duplicated/contradictory prose.

## Decisions

- Confirmed no additional `config/`-deploying code exists outside `modules/home/core/dotfiles.nix`; the doc-writing pass does not need to search further.
- Confirmed task 88's rename is complete and the file to cross-reference from is `modules/home/core/dotfiles.nix` (not `shell.nix`).
- Confirmed the header-comment cross-reference is an addition, not a no-op verification.
- Confirmed `config/rclone.conf` is untracked/gitignored and unreferenced by any `.nix` file — consistent with the design doc's disposition to treat this as already resolved and out of scope for subtask 9; not part of the three mechanisms to document (it currently has zero deployment mechanism at all, since it's git-ignored and manually seeded on disk).

## Risks & Mitigations

- **Risk**: Doc-writing pass could re-conflate `.claude/` vs `config/claude/` vs `~/.claude/` if not careful about which of the three "claude"-named entities each sentence refers to. **Mitigation**: this report enumerates all three explicitly above; the doc should name each one by its full path every time, never bare "claude directory."
- **Risk**: Widening the force-overwrite behavior's scope while "fixing" the doc (e.g. someone reads the doc gap and is tempted to add safety logic to the activation script). **Mitigation**: task 90 is doc-only; report and design doc both state explicitly this is pre-existing intended behavior not to be changed by this task.
- **Risk**: Stale `.zuliprc` mechanism description in the current doc could be left uncorrected if the doc-writer treats subtask 9 as purely additive. **Mitigation**: flagged explicitly above as a correction to make in the same pass.

## Context Extension Recommendations

- **Topic**: Home Manager activation-script force-overwrite pattern for runtime-writable dotfiles (the `config/claude/` case).
- **Gap**: No existing `.claude/context/` or `.context/` file documents this repo's "activation script cp with force-overwrite, no merge" pattern as a reusable convention for other runtime-writable configs (e.g. if a future config needs the same treatment).
- **Recommendation**: Not urgent enough to spawn separately (task 90 itself, once implemented, will serve as this documentation in `config/README.md`); no new context file needed.

## Appendix

### Search queries / commands used

- `grep -rn "home.file" modules/home/`
- `grep -rln "readFile" modules/ home.nix`
- `grep -rn "config-files" modules/ home.nix`
- `grep -rln "activation" modules/home/ home.nix`
- `git log --oneline -3 -- modules/home/core/dotfiles.nix modules/home/core/shell.nix` (confirms rename commit `a6bbecb`)
- `ls config/claude/`, `ls config/`
- `grep -rn "zuliprc\|rclone" modules/ home.nix`
- `git ls-files config/rclone.conf` (confirmed untracked)
- Direct reads: `config/README.md`, `modules/home/core/dotfiles.nix` (full file), `.claude/README.md` (header only, to confirm identity), design doc sections §1.2, §1.3, §2, §3, §5, and both seed reports' `config/` sections.

### Key file:line references

| Fact | Location |
|---|---|
| Header comment (cross-reference target) | `modules/home/core/dotfiles.nix:1-2` |
| Module signature (`config` argument) | `modules/home/core/dotfiles.nix:3` |
| Mechanism 1 (`home.file.*.source`) | `modules/home/core/dotfiles.nix:19-40`, `:57` |
| Mechanism 2 (`builtins.readFile` mirrors) | `modules/home/core/dotfiles.nix:42-49` |
| Mechanism 3 (activation-script `cp`) | `modules/home/core/dotfiles.nix:59-68` |
| Rename commit (task 88) | `a6bbecb task 88 phase 5: rename core/shell.nix to core/dotfiles.nix` |
| `config/claude/` contents | `keybindings.json`, `settings.json` only |
| `.claude/` identity confirmation | `.claude/README.md:1` ("# Claude Code Agent System") |
| Existing doc file to expand | `config/README.md` |
