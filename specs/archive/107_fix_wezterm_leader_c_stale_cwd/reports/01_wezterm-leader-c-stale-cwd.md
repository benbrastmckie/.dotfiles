# Research Report: Task #107

**Task**: 107 - Fix WezTerm Leader+c new-tab opening in a stale (Neovim) working directory
**Started**: 2026-07-11T00:00:00Z
**Completed**: 2026-07-11T00:00:00Z
**Effort**: ~1-2 hours (config change + home-manager switch + behavioral test)
**Dependencies**: None
**Sources/Inputs**: config/wezterm.lua, modules/home/core/dotfiles.nix, dotfiles git history (commits 3af0978, 3d82539), live /proc cwd inspection, nvim-repo task 87 report (specs/087_investigate_wezterm_terminal_directory_change/reports/02_wezterm-cwd-change.md in ~/.config/nvim)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause (confirmed):** WezTerm's `LEADER+c` binding is `act.SpawnTab("CurrentPaneDomain")` (`config/wezterm.lua:456-457`), which spawns the new tab's shell in WezTerm's *cached OSC-7 working directory* for the current pane. Neovim emits OSC 7 whenever it changes its own editor cwd (e.g. a worktree `tcd`/`cd`), and nothing re-emits the shell's real cwd when Neovim exits, so the cache goes **stale**. New `fish` shells are then physically started in the stale project directory instead of `~`.
- **Not a Neovim bug.** Live headless diagnostics in the nvim repo (task 87) proved Neovim never auto-changes its own cwd (`noautochdir`, `noexrc`; `getcwd()` stays at `~`). The defect lives entirely on the WezTerm/home-manager side managed by this repo.
- **Live-reproduced.** Inspecting the `/proc/<pid>/cwd` of running WezTerm panes showed each `fish` shell had physically inherited the *previous* pane's Neovim cwd rather than `$HOME`.
- **The fix was already written — and reverted.** Commit `3af0978` ("task 94 phase 1: replace Leader+c keybinding", Feb 24, from an earlier task-numbering epoch — unrelated to the current task 94) replaced the binding with an `action_callback` that reads `pane:get_foreground_process_info().cwd` and falls back to plain `SpawnTab`. It was reverted an hour later by `3d82539` **with an empty rationale** ("This reverts commit …"). Understanding *why* it was reverted is the central open question this task must resolve before re-applying.
- **Recommended fix:** re-apply the `get_foreground_process_info().cwd` approach, but with the fallback hardened so it cannot silently degrade back to the stale-OSC-7 behavior, and with an explicit reproduction/verification protocol that distinguishes the "Neovim still running" case from the "Neovim exited" case (see Findings 4 for why the original may have appeared not to work).

## Context & Scope

The user opens Neovim in WezTerm from `~`; after working (and after Neovim exits), newly opened WezTerm tabs start in a project root rather than `~`. Goal: new tabs should open in the shell's *real* working directory, without breaking legitimate cwd inheritance or the tab-title feature. This report is the WezTerm/home-manager-side counterpart to nvim-repo task 87, which established the mechanism; the actionable fix belongs here because the WezTerm config is owned by this repo.

### Where the config lives (home-manager wiring)

- Source of truth: `config/wezterm.lua` (this repo).
- Deployed via home-manager at `modules/home/core/dotfiles.nix:37` — `".config/wezterm/wezterm.lua".source = ../../../config/wezterm.lua;` (a read-only nix-store symlink; also mirrored as text at `dotfiles.nix:50`). A note at `dotfiles.nix:29` records that WezTerm is additionally handled via `programs.wezterm`.
- Any fix therefore requires editing `config/wezterm.lua` in this repo and running `home-manager switch` (the deployed `~/.config/wezterm/wezterm.lua` cannot be edited in place).

## Findings

### 1. The offending binding

`config/wezterm.lua:453-457`:
```lua
{
  key = "c",
  mods = "LEADER",
  action = act.SpawnTab("CurrentPaneDomain"),
},
```
`SpawnTab("CurrentPaneDomain")` derives the new tab's cwd from WezTerm's per-pane tracked working directory, which is populated from OSC 7 escape sequences.

### 2. Why the cache goes stale

OSC 7 is the mechanism a program uses to tell the terminal "my cwd is now X." In this setup the emitters are:
- **fish** — re-emits OSC 7 only on an actual `PWD` change (a real `cd`), so it does not self-heal after a child process lied about the cwd.
- **Neovim** — emits OSC 7 on `DirChanged` (to drive the WezTerm tab title / project name). When a worktree action runs `tcd`/`cd`, Neovim reports the *project* directory. On Neovim exit there is no re-emit, so WezTerm keeps the project dir cached even though the underlying `fish` shell never left `~`.

`SpawnTab` then launches the new shell in that cached-but-wrong directory. The new `fish` process is physically `chdir`'d there by WezTerm at spawn, which is why `/proc/<pid>/cwd` shows the stale path.

### 3. Live reproduction (from task 87)

Inspecting all running WezTerm panes' `/proc/<pid>/cwd` showed every `fish` shell sitting in the previous pane's Neovim project directory rather than `$HOME`, and every `nvim` had been launched with no file arguments — matching the reported symptom exactly.

### 4. The prior fix and the revert — the key open question

Commit `3af0978` replaced the binding with:
```lua
action = wezterm.action_callback(function(window, pane)
  local info = pane:get_foreground_process_info()
  if info and info.cwd and info.cwd ~= "" then
    window:perform_action(
      act.SpawnCommandInNewTab { domain = "CurrentPaneDomain", cwd = info.cwd },
      pane)
  else
    window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)  -- falls back to stale OSC-7 path
  end
end),
```
This reads the *foreground process's* real cwd from `/proc` and spawns the new tab there, bypassing the OSC-7 cache. It was reverted by `3d82539` with no recorded reason. Two plausible explanations, both important to test:

1. **Foreground-process semantics vs. intent.** `get_foreground_process_info()` returns the cwd of the *current foreground process*. If the pane still has **Neovim running** at a project dir, `info.cwd` is that project dir — so a new tab opened *while Neovim is open* still lands in the project, not `~`. The fix only corrects the "Neovim already exited, fish is foreground at `~`" case. If the original was tested with Neovim still open, it would have looked like it "didn't work," prompting the revert. This is a semantics question about desired behavior, not a bug.
2. **`nil` return → silent degradation.** `get_foreground_process_info()` can return `nil` (e.g. certain domains, or when `/proc` info is unavailable). The original's `else` branch falls back to plain `SpawnTab("CurrentPaneDomain")` — i.e. straight back to the stale-OSC-7 behavior — so on any `nil` it would appear unfixed. A hardened fallback should prefer `$HOME` (or the pane's known-good launch dir) rather than the OSC-7 path.

### 5. Alternative (cross-repo, less clean)

The nvim-side alternative — a `VimLeavePre` autocmd in `~/.config/nvim/lua/neotex/config/autocmds.lua` that re-emits OSC 7 with the launch directory on exit — also fixes the "Neovim exited" case, but: (a) it must cache the launch dir at `VimEnter` (Neovim's own `getcwd()` at exit is the wrong/project dir), (b) it fires on every exit, (c) it does not help new tabs opened *during* a session, and (d) it puts terminal-integration logic inside the editor. It is a symptom-level band-aid and lives in a different repo; the WezTerm-side fix is the root-cause fix and is owned here.

## Decisions

1. **Fix on the WezTerm side, in this repo** — re-apply the `get_foreground_process_info().cwd` approach in `config/wezterm.lua`.
2. **Before re-applying, resolve the revert.** Reproduce the original behavior and determine which of the two Finding-4 explanations caused the revert; do not blindly re-land the reverted commit.
3. **Harden the fallback** so a `nil`/empty `info.cwd` resolves to `$HOME` (or the pane's launch dir), never to the stale-OSC-7 `SpawnTab` path.
4. **Define desired behavior explicitly** for the "new tab while Neovim is still open" case (project dir vs `~`) so the implementation matches intent and the fix is not perceived as broken again.

## Recommendations

### Recommended change (to be formalized in /plan)

- Replace `config/wezterm.lua:453-457` with an `action_callback` that:
  - reads `pane:get_foreground_process_info()`;
  - if the foreground process is a shell (fish/bash), uses its real `cwd`;
  - decides the "Neovim-is-foreground" policy deliberately (recommended: still spawn at the shell's/launch cwd, i.e. `~`, since that is the reported desire) — e.g. detect `info.name`/argv and, when the foreground is an editor, fall back to `$HOME` rather than the editor's project cwd;
  - on `nil`/empty, falls back to `os.getenv("HOME")`, never to plain `SpawnTab`.
- Apply with `home-manager switch` (or `nixos-rebuild` per host), then behaviorally verify all three cases below.

### Verification protocol (required — the original revert shows behavior must be checked, not assumed)

1. From `fish` at `~`, `LEADER+c` → new tab must be at `~`. (`pwd` in new tab.)
2. Open `nvim`, run a worktree `tcd` to a project, **exit nvim**, then `LEADER+c` → new tab must be at `~` (the previously-broken case).
3. With `nvim` still open at a project, `LEADER+c` → confirm the chosen policy (per Decision 4).
4. Confirm the WezTerm tab title / project-name feature still works (OSC 7 emission from Neovim is untouched by this change).

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Re-applying the reverted fix reproduces whatever caused the revert | Medium | Reproduce and diagnose (Finding 4) before landing; harden the fallback |
| `get_foreground_process_info()` returns `nil` in some domains → silent no-op | Medium | Fallback resolves to `$HOME`, not stale `SpawnTab` |
| "New tab while Neovim open" behavior surprises the user | Medium | Decide policy explicitly (Decision 4); document it in the plan |
| Other WezTerm spawn/split paths still use stale OSC-7 cwd | Low | Scope is `LEADER+c`; note other bindings as optional follow-up |
| home-manager switch not run → deployed symlink unchanged | Low | Plan includes explicit switch + `readlink` verification |

## Appendix

### Key locations
- Binding: `config/wezterm.lua:453-457` (`key="c"`, `mods="LEADER"`, `act.SpawnTab("CurrentPaneDomain")`)
- home-manager wiring: `modules/home/core/dotfiles.nix:37` (and `:50`, `:29`)
- Prior fix: commit `3af0978` ("task 94 phase 1: replace Leader+c keybinding" — earlier numbering epoch)
- Revert: commit `3d82539` (empty rationale)

### Commands used
```bash
grep -n "SpawnTab\|get_foreground_process_info\|LEADER" config/wezterm.lua
grep -rn "wezterm" modules/ | grep -iE "\.lua|dotfiles|home.file|xdg"
git show 3af0978 -- config/wezterm.lua
git log -1 --format='%B' 3d82539
# (task 87, nvim repo) /proc cwd inspection of running panes; nvim --headless getcwd() probes
```

### Cross-reference
- nvim-repo task 87 report: `~/.config/nvim/specs/087_investigate_wezterm_terminal_directory_change/reports/02_wezterm-cwd-change.md` (establishes that Neovim is not the cause and documents the OSC-7 mechanism).
