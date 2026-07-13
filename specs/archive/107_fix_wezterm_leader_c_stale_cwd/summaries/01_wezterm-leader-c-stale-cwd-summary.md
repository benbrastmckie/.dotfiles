# Implementation Summary: Task #107

**Completed**: 2026-07-11
**Duration**: ~45 minutes

## Overview

Re-applied and hardened the `get_foreground_process_info().cwd` fix for WezTerm's `LEADER+c` new-tab binding, which had been reverted with no rationale a year earlier (commit `3af0978` -> `3d82539`). The new binding never falls back to plain `SpawnTab`, and explicitly resolves to `$HOME` whenever the foreground process is an editor (`nvim`/`vim`) or foreground-process info is unavailable. Deployed via `home-manager switch --flake .#benjamin` and verified the deployed symlink updated with the new binding present. Interactive GUI verification (the four protocol cases) could not be performed in this headless session and requires manual user testing.

## What Changed

- `config/wezterm.lua` — Replaced the `LEADER+c` binding (`key = "c"`, `mods = "LEADER"`, previously `action = act.SpawnTab("CurrentPaneDomain")`) with a `wezterm.action_callback` that resolves the new tab's `cwd` and spawns via `act.SpawnCommandInNewTab { domain = "CurrentPaneDomain", cwd = <resolved> }`.

## Revert Diagnosis (Phase 1)

- Confirmed via `git show 3af0978 -- config/wezterm.lua` that the original fix's `else` branch (on `nil`/empty `info.cwd`) fell back to plain `act.SpawnTab("CurrentPaneDomain")` — i.e. straight back to the stale-OSC-7 bug being fixed.
- Confirmed via `git log -1 --format='%B' 3d82539` that the revert commit message is only the boilerplate "This reverts commit 3af097821894dcfd72ce0303ed499f3f6d0735d2." — no rationale recorded.
- `/proc/<pid>/cwd` inspection of 6 live WezTerm panes (fish + child nvim pairs) showed each fish shell's cwd already equals its own child nvim's cwd (nvim was launched from that same shell), confirming the OSC-7-cache mechanism generally but not directly exercising the LEADER+c spawn path (no GUI keyboard available to press LEADER+c interactively in this session).
- **Diagnosis: both Finding-4 causes are real, non-exclusive design gaps.** (a) `get_foreground_process_info()` returns the *foreground* process's cwd — with `nvim` still open at a project, that's the project dir, not `~`, and the original binding had no explicit policy for this case. (b) A `nil`/empty return degraded straight back to plain `SpawnTab`, silently re-enabling the exact bug being fixed on any such nil. The hardened design addresses both.

## Final Binding

```lua
{
  key = "c",
  mods = "LEADER",
  -- Spawn new tab at the real shell cwd, never WezTerm's cached OSC-7 dir.
  -- OSC-7 goes stale when Neovim emits its own (project) cwd and never
  -- re-emits on exit, so plain SpawnTab("CurrentPaneDomain") can land a
  -- new tab in a defunct Neovim session's project dir (task 107).
  -- Policy: a new tab always opens at $HOME, never an editor's project
  -- cwd -- so if Neovim (or vim) is still the foreground process, resolve
  -- to $HOME rather than trusting its cwd. Nil/empty foreground-process
  -- info (e.g. non-local domains) also resolves to $HOME. The fallback
  -- NEVER reverts to plain SpawnTab (that was the reverted commit's bug:
  -- 3af0978 -> 3d82539).
  action = wezterm.action_callback(function(window, pane)
    local home = os.getenv("HOME")
    local info = pane:get_foreground_process_info()
    local cwd = home
    if info and info.cwd and info.cwd ~= "" then
      local editor_names = { nvim = true, vim = true }
      if not editor_names[info.name] then
        cwd = info.cwd
      end
    end
    window:perform_action(
      act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain", cwd = cwd }),
      pane
    )
  end),
},
```

**Policy decided (Decision 4 in the report)**: a new tab always lands at `$HOME`, never an editor's project cwd — including when Neovim is still the foreground process. This was an explicit, documented choice, not left implicit as in the original 2026-02-24 attempt.

## Decisions

- Editor detection uses `info.name` matched against `{ nvim = true, vim = true }` (exact basename match) rather than a substring/pattern match, to avoid false positives on unrelated processes whose name happens to contain "vim".
- The fallback variable `cwd` defaults to `home` and is only overridden when `info`/`info.cwd` is valid AND the foreground process is not a known editor — so every code path (nil info, empty cwd, editor foreground, ordinary shell foreground) funnels through the single `act.SpawnCommandInNewTab` call. There is no branch that reaches `act.SpawnTab`.
- Confirmed `wezterm` (line 1) and `act` (line 4, `= wezterm.action`) are already in module scope; no new `require` was needed.
- Deployed via the standalone `home-manager switch --flake .#benjamin` path only (not the NixOS-integrated `sudo nixos-rebuild switch --flake .#hamsa` leg, and not `scripts/update.sh`, which additionally requires an opt-in git checkpoint auto-commit). This repo's `home.file` wiring for `config/wezterm.lua` is a home-manager-managed dotfile symlink, so the standalone home-manager rebuild alone is sufficient to update `~/.config/wezterm/wezterm.lua`; the NixOS-integrated leg manages the same file identically per `flake.nix`'s comments but was not run in this session (no `sudo` invoked).
- Confirmed the `modules/home/core/dotfiles.nix:29` comment ("WezTerm config is now managed by programs.wezterm above") is stale/inaccurate — no `programs.wezterm` block exists in that file. The active mechanism is the `home.file` symlink at line 37 plus the `config-files` text mirror at line 50, both of which re-read the same edited `config/wezterm.lua` source; no separate edit to `dotfiles.nix` was needed.

## Plan Deviations

- **Phase 1, live LEADER+c reproduction**: altered — could not press LEADER+c interactively (no GUI keyboard in this session). Corroborated the OSC-7-cache mechanism via `/proc/<pid>/cwd` inspection of currently-running panes instead, and relied on the research report's already-confirmed live reproduction (nvim-repo task 87) for the specific LEADER+c-after-exit case.
- **Phase 4, Cases 1-4 and the optional nil-path spot check**: all skipped — each requires a human pressing `LEADER+c` in a GUI WezTerm window, which is not performable headlessly. See "Manual Verification Required" below for exact steps.

## Verification

- **Static/headless checks (all passed)**:
  - `config/wezterm.lua` binding present at the `LEADER+c` location with the hardened `action_callback`.
  - `wezterm --config-file config/wezterm.lua ls-fonts --list-system` loaded the edited config without a Lua error (exit 0, no error output) — confirms Lua syntax validity.
  - `home-manager switch --flake .#benjamin --max-jobs 4 --option allow-import-from-derivation false`: **Success**. Home Manager activation completed (`Starting Home Manager activation` ... `Creating home file links in /home/benjamin` ... no errors).
  - `readlink -f ~/.config/wezterm/wezterm.lua`: `/nix/store/fmbrafz913wri69pmp1ssrhaz5igyxix-hm_wezterm.lua` — a new store path, differing from the pre-switch path `/nix/store/s9gyjwahbld1vwmaacbn8bgmbniahrrb-hm_wezterm.lua`.
  - `grep -n get_foreground_process_info ~/.config/wezterm/wezterm.lua`: found at line 469 in the deployed file. Also confirmed present in the `~/.config/config-files/wezterm.lua` text mirror.
  - Code review of the fallback branch: `grep -n SpawnTab config/wezterm.lua` shows the only two matches are inside `--` comment lines; the executable code has exactly one action call (`act.SpawnCommandInNewTab`) reached by every branch. No `act.SpawnTab(` call remains in the binding.
- **Manual/interactive checks: NOT YET PERFORMED** (see below).

## Manual Verification Required

The following four cases from the report's verification protocol, plus the optional nil-path spot check, require a human pressing `LEADER+c` in an actual GUI WezTerm window and were **not** performed in this session:

1. **Case 1 (fish-at-home)**: From a `fish` shell at `~`, press `LEADER+c`. Expected: new tab's `pwd` is `~`.
2. **Case 2 (nvim-exited-then-spawn — the previously broken case)**: Open `nvim`, run a worktree `tcd`/`cd` into a project, **exit nvim**, then press `LEADER+c`. Expected: new tab's `pwd` is `~` (this is the case the fix specifically targets).
3. **Case 3 (nvim-still-open policy check)**: With `nvim` still open at a project, press `LEADER+c`. Expected (per the decided policy): new tab lands at `~`, not the project dir.
4. **Case 4 (tab-title regression check)**: Open `nvim` in a project and confirm the WezTerm tab title / project-name feature still updates correctly from Neovim's OSC-7 emission (unaffected by this change, but should be re-confirmed).
5. **Optional nil-path spot check**: If a domain/condition producing a `nil`/empty `get_foreground_process_info()` result is reachable (e.g. certain non-local/mux domains), confirm the new tab still lands at `$HOME` rather than any stale directory.

If any case fails, per the plan's rollback guidance: do not silently re-revert. Record which case failed (this repo's prior revert had no rationale, which is exactly what made re-diagnosing it necessary this time), then return to a fresh Phase 1/2 diagnosis. The rollback snippet (restoring `act.SpawnTab("CurrentPaneDomain")`) is documented in the plan's Rollback/Contingency section if a full revert is needed.

## Notes

- No conflicts with `programs.wezterm` were found; that reference in `dotfiles.nix:29` is a stale comment and does not correspond to an active config block in this repo.
- WezTerm auto-reloads its config on file change by default (`automatically_reload_config`), so the new binding should already be live in any currently-open WezTerm instance once the deployed symlink updated — no separate reload command was run headlessly.
