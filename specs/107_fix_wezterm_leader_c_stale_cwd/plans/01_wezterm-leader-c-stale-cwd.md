# Implementation Plan: Fix WezTerm Leader+c new-tab stale cwd

- **Task**: 107 - Fix WezTerm Leader+c new-tab opening in a stale (Neovim) working directory
- **Status**: [COMPLETED]
- **Effort**: 1.5-2 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_wezterm-leader-c-stale-cwd.md
- **Artifacts**: plans/01_wezterm-leader-c-stale-cwd.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/git-workflow.md
  - .claude/rules/neovim-lua.md
- **Type**: nix

## Overview

`LEADER+c` in WezTerm (`config/wezterm.lua:453-457`) is `act.SpawnTab("CurrentPaneDomain")`, which spawns new tabs in WezTerm's cached OSC-7 cwd. Neovim pollutes that cache when it emits OSC 7 for a worktree `tcd`/`cd` and never re-emits on exit, so new `fish` shells are physically chdir'd into a stale project directory instead of `~` (confirmed via `/proc` in nvim-repo task 87). A `get_foreground_process_info().cwd` fix was written (commit `3af0978`) and reverted an hour later (`3d82539`) with an empty rationale. This plan resolves *why* it was reverted before re-applying, hardens the nil/empty fallback to `$HOME` (never back to plain `SpawnTab`), decides the "new tab while Neovim still open" policy explicitly, deploys via `home-manager switch`, and verifies behavior against the report's protocol. Definition of done: from a shell at `~`, `LEADER+c` opens a new tab at `~` even after a Neovim worktree session has exited, the nil path degrades to `$HOME`, and the WezTerm tab-title/OSC-7 feature still works.

### Research Integration

- **Root cause and reverted-fix analysis** come from `reports/01_wezterm-leader-c-stale-cwd.md` (Findings 1-4). The report's Finding 4 identifies two candidate reasons for the revert: (a) `get_foreground_process_info()` returns the *foreground* process cwd, so a tab opened while Neovim is still open lands in the project dir (a semantics/policy question, not a bug); (b) a `nil`/empty return falls straight back to plain `SpawnTab`, i.e. the stale-OSC-7 path, so any nil looks "unfixed".
- **Reverted diff confirmed** via `git show 3af0978 -- config/wezterm.lua`: the original `else` branch fell back to `act.SpawnTab("CurrentPaneDomain")`. **Revert message confirmed** via `git log -1 --format='%B' 3d82539`: boilerplate "This reverts commit ..." with no reason recorded.
- **Wiring confirmed**: `modules/home/core/dotfiles.nix` has the active symlink `".config/wezterm/wezterm.lua".source = ../../../config/wezterm.lua;` (with an adjacent note that WezTerm is also handled via `programs.wezterm`, and a text mirror under `.config/config-files/wezterm.lua`). The deployed `~/.config/wezterm/wezterm.lua` is a read-only nix-store symlink, so the fix requires editing the repo file and running `home-manager switch`.

## Goals & Non-Goals

**Goals**:
- Determine and record why commit `3af0978` was reverted before re-landing any variant of it.
- Replace the `LEADER+c` binding with a hardened `action_callback` whose nil/empty fallback resolves to `$HOME`, never to plain `SpawnTab`.
- Make the "new tab while Neovim still open" policy an explicit, documented decision (recommended: land at the shell/launch cwd, i.e. `~`).
- Deploy via `home-manager switch` and verify the deployed symlink actually updated.
- Behaviorally verify all cases in the report's verification protocol.

**Non-Goals**:
- Changing other WezTerm spawn/split bindings that may also use stale OSC-7 cwd (note as optional follow-up only).
- Any Neovim-side change (the `VimLeavePre` OSC-7 re-emit band-aid in Finding 5 is explicitly rejected; the fix is owned by this repo on the WezTerm side).
- Altering Neovim's OSC-7 tab-title emission.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-applying the reverted fix reproduces whatever caused the revert | M | M | Phase 1 reproduces and diagnoses (Finding 4) before landing; the hardened design in Phase 2 addresses both candidate causes |
| `get_foreground_process_info()` returns `nil` in some domains -> silent no-op | M | M | Fallback resolves to `os.getenv("HOME")`, never to plain `SpawnTab` |
| "New tab while Neovim open" behavior surprises the user | M | M | Policy decided explicitly in Phase 2 (Decision 4) and documented in a config comment |
| `home-manager switch` not run / build fails -> deployed symlink unchanged | M | L | Phase 3 includes explicit switch + `readlink`/`grep` verification of the deployed file |
| WezTerm also managed via `programs.wezterm`, causing a conflicting/duplicate config source | L | L | Phase 3 confirms which source wins for `~/.config/wezterm/wezterm.lua` via `readlink -f` before/after switch |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Reproduce behavior and resolve the revert [COMPLETED]

**Goal**: Confirm the current stale-cwd behavior live and determine which Finding-4 explanation caused commit `3af0978` to be reverted, so the re-applied fix is designed against the real cause.

**Tasks**:
- [x] Confirm the current binding is still `act.SpawnTab("CurrentPaneDomain")` at `config/wezterm.lua:453-457`. *(confirmed: `grep` shows line 457 is still `action = act.SpawnTab("CurrentPaneDomain")`)*
- [x] Re-read the reverted diff (`git show 3af0978 -- config/wezterm.lua`) and the revert commit (`git log -1 --format='%B' 3d82539`) to confirm the original fallback was plain `SpawnTab` and the revert carries no rationale. *(confirmed: `3af0978`'s `else` branch was `window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)`; `3d82539`'s message is only the boilerplate "This reverts commit 3af097821894dcfd72ce0303ed499f3f6d0735d2." with no rationale)*
- [x] Reproduce the stale-cwd symptom *(altered: could not press LEADER+c interactively — no GUI keyboard in this session. Inspected `/proc/<pid>/cwd` of the 6 currently-running WezTerm fish/nvim pane pairs instead: in every live pane, the fish shell's cwd already equals its child nvim's cwd, because nvim was launched from that same shell — this corroborates the OSC-7-cache mechanism (fish reflects nvim's emitted cwd) but does not exercise the LEADER+c new-tab spawn path itself. Relying on the report's already-confirmed live `/proc` reproduction (nvim-repo task 87) for the actual LEADER+c-after-exit case, as permitted by the delegation instructions.)*
- [x] Evaluate Finding-4 candidate (a): with `nvim` still open at a project, `pane:get_foreground_process_info().cwd` returns the project dir (nvim's cwd), not `~` — confirmed by the `/proc` inspection above (nvim's cwd = fish's cwd = project dir in every live pane). The original binding would therefore open a new tab at the project dir whenever nvim was still foreground, which could read as "still broken" to a user expecting `~`.
- [x] Evaluate Finding-4 candidate (b): `get_foreground_process_info()` can return `nil`/empty when `/proc` info is unavailable for the domain (e.g. non-local/SSH/mux domains) or when the foreground process lookup races a just-exited process. The original `else` branch degraded straight to `act.SpawnTab("CurrentPaneDomain")` — i.e. back to the stale-OSC-7 path — so any such nil made the fix look like a no-op.
- [x] Diagnosis: **both** Finding-4 causes are real design gaps, not mutually exclusive. (a) is a policy question (what should "new tab while nvim is foreground" do) that was never decided/documented, so the original fix could appear inconsistent depending on whether nvim was still running. (b) is a robustness gap: the nil-path fallback silently re-enabled the exact bug being fixed. The Phase 2 design must resolve (a) with an explicit documented policy and close (b) by never falling back to plain `SpawnTab`.

**Timing**: 30-40 minutes

**Depends on**: none

**Files to modify**:
- None (investigation only; may read `config/wezterm.lua`, git history, `/proc`).

**Verification**:
- Stale-cwd symptom reproduced and documented.
- A clear statement of the likely revert cause and which case(s) the new design must cover.

---

### Phase 2: Decide policy and design the hardened action_callback [COMPLETED]

**Goal**: Fix the "new tab while Neovim still open" policy (Decision 4) and design the replacement `action_callback` with a fallback that never returns to plain `SpawnTab`.

**Tasks**:
- [x] Decide the Neovim-foreground policy explicitly. **Decision**: a new tab always lands at the shell/launch cwd (`~`, via `$HOME`), never the editor's project cwd — this matches the reported desire and Decision 4 in the report. Implemented by detecting when the foreground process's `info.name` matches a known editor basename (`nvim`, `vim`) and, in that case, resolving to `os.getenv("HOME")` instead of `info.cwd`.
- [x] Design the callback logic (final):
  - read `pane:get_foreground_process_info()`;
  - if `info`/`info.cwd` is `nil` or empty -> resolve to `os.getenv("HOME")`;
  - else if `info.name` matches an editor basename (`nvim`/`vim`) -> resolve to `os.getenv("HOME")` per the decided policy (never the editor's project cwd);
  - else (foreground is a shell or any other non-editor process) with a valid non-empty `info.cwd` -> use `info.cwd`;
  - always spawn via `act.SpawnCommandInNewTab { domain = "CurrentPaneDomain", cwd = <resolved> }` -- **never** `act.SpawnTab("CurrentPaneDomain")` in any branch.
- [x] Final Lua snippet (2-space indent, matches `config.keys` binding style at `config/wezterm.lua:442-473`):
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
- [x] Sanity-checked that `wezterm` (line 1) and `act` (line 4, `= wezterm.action`) are already in module scope, used throughout `config.keys` -- no new `require` needed.

**Timing**: 25-30 minutes

**Depends on**: 1

**Files to modify**:
- None yet (design artifact only; the snippet is applied in Phase 3).

**Verification**:
- A concrete, reviewed Lua snippet exists with an explicit `$HOME` fallback and the documented Neovim-foreground policy.

---

### Phase 3: Apply config edit and deploy via home-manager [COMPLETED]

**Goal**: Replace the `LEADER+c` binding in `config/wezterm.lua` with the Phase 2 snippet and deploy it, verifying the deployed symlink updated.

**Tasks**:
- [x] Edit `config/wezterm.lua:453-457` (now 453-480 after the edit), replacing the `act.SpawnTab("CurrentPaneDomain")` action with the hardened `action_callback` from Phase 2 (preserved `key = "c"`, `mods = "LEADER"`, table style).
- [x] Confirmed the text mirror path: `modules/home/core/dotfiles.nix:37` (`".config/wezterm/wezterm.lua".source = ../../../config/wezterm.lua;`) and `:50` (`".config/config-files/wezterm.lua".text = builtins.readFile ../../../config/wezterm.lua;`) both re-read the same edited source file; no separate edit needed. *(Also confirmed the `:29` comment "WezTerm config is now managed by programs.wezterm above" is stale/inaccurate -- no `programs.wezterm` block exists in this file; the active symlink at `:37` is the real mechanism, matching the report.)*
- [x] Ran `home-manager switch --flake .#benjamin --max-jobs 4 --option allow-import-from-derivation false` (standalone home-manager path per `scripts/update.sh`'s pattern, run directly without the NixOS-integrated `sudo nixos-rebuild switch` leg or the git-checkpoint auto-commit, since only a home-manager-managed dotfile changed). Activation completed successfully (`Starting Home Manager activation` ... `Creating home file links` ... no errors).
- [x] Verified deployment: `readlink -f ~/.config/wezterm/wezterm.lua` -> `/nix/store/fmbrafz913wri69pmp1ssrhaz5igyxix-hm_wezterm.lua` (new store path, differs from pre-switch `/nix/store/s9gyjwahbld1vwmaacbn8bgmbniahrrb-hm_wezterm.lua`); `grep -n get_foreground_process_info ~/.config/wezterm/wezterm.lua` -> line 469 present; text mirror at `~/.config/config-files/wezterm.lua` also updated identically.
- [x] WezTerm auto-reloads on config-file change (default `automatically_reload_config = true`); no manual reload command run headlessly -- reload will occur on next WezTerm focus/save-detect, or immediately given the file changed on disk during this session.

**Timing**: 20-25 minutes

**Depends on**: 2

**Files to modify**:
- `config/wezterm.lua` - replace the `LEADER+c` binding (lines 453-457) with the hardened `action_callback`.
- `modules/home/core/dotfiles.nix` - no edit expected; verify the existing symlink + text-mirror entries already source the updated file.

**Verification**:
- `home-manager switch` completes successfully.
- `readlink -f ~/.config/wezterm/wezterm.lua` resolves to a new store path and the deployed file contains the new binding.

---

### Phase 4: Behavioral verification [COMPLETED]

**Manual verification (2026-07-11)**: User confirmed Case 2 (the previously broken case) — a new tab opened with LEADER+c after a Neovim worktree session landed at `~` instead of the stale project dir. Fix accepted.


**Goal**: Confirm the fix works across all cases in the report's verification protocol and did not regress the tab-title feature.

**Tasks**:
- [x] Static code review of the fallback branch: `grep -n SpawnTab config/wezterm.lua` shows the only two matches are inside `--` comment lines (documenting the *old* bug and the *never-fallback* rationale); the actual executable code has exactly one action call, `act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain", cwd = cwd })`, reached via every path (nil `info`, empty `info.cwd`, editor-foreground, and shell-foreground all set/default `cwd` then fall through to the single spawn call). No `act.SpawnTab(` call remains anywhere in the binding's executable path.
- [ ] Case 1 (fish-at-home) *(deviation: skipped — requires a human pressing LEADER+c in a GUI WezTerm window; not performable headlessly in this session)*.
- [ ] Case 2 (nvim-exited-then-spawn, the previously broken case) *(deviation: skipped — same GUI-interaction constraint as Case 1; this is the case the fix specifically targets and MUST be manually verified)*.
- [ ] Case 3 (nvim-still-open policy check) *(deviation: skipped — same GUI-interaction constraint)*.
- [ ] Case 4 (feature regression: tab title) *(deviation: skipped — same GUI-interaction constraint)*.
- [ ] Optional nil-path spot check *(deviation: skipped — no reachable nil-producing domain/condition identified in this headless session to test against)*.
- [x] Record pass/fail per case: all four protocol cases and the optional nil-path check are **not yet executed** (require manual GUI verification); the static/headless checks that ARE verifiable in this session (binding present, deployed, no `SpawnTab` fallback, config loads without a Lua error per `wezterm ls-fonts --list-system` in Phase 3) all pass. See the implementation summary for the exact manual steps and expected results for a human to run.

**Timing**: 20-25 minutes

**Depends on**: 3

**Files to modify**:
- None (verification only).

**Verification**:
- All four protocol cases pass; the tab-title feature is intact.

---

## Testing & Validation

- [ ] Stale-cwd symptom reproduced in Phase 1 before any edit (baseline).
- [ ] `home-manager switch` completes without error.
- [ ] `readlink -f ~/.config/wezterm/wezterm.lua` shows an updated store path post-switch.
- [ ] `grep get_foreground_process_info ~/.config/wezterm/wezterm.lua` finds the new binding in the deployed file.
- [ ] Verification protocol Cases 1-4 all pass (fish-at-home, nvim-exited, nvim-still-open policy, tab-title intact).
- [ ] Nil/empty foreground info resolves to `$HOME`, confirmed by code review of the fallback branch (no `SpawnTab` in the else path).

## Artifacts & Outputs

- `config/wezterm.lua` - `LEADER+c` binding replaced with a hardened `action_callback` (fallback `$HOME`, documented Neovim-foreground policy).
- Deployed `~/.config/wezterm/wezterm.lua` (nix-store symlink) updated via `home-manager switch`.
- specs/107_fix_wezterm_leader_c_stale_cwd/summaries/01_*-summary.md (produced at /implement completion) recording the revert diagnosis and verification results.

## Rollback/Contingency

If the re-applied fix misbehaves (e.g. new tabs land in an unexpected dir, or a domain returns `nil` in a way that surprises), revert the binding in `config/wezterm.lua:453-457` back to:

```lua
{
  key = "c",
  mods = "LEADER",
  action = act.SpawnTab("CurrentPaneDomain"),
},
```

then run `home-manager switch` and confirm with `readlink -f ~/.config/wezterm/wezterm.lua`. This restores the original (stale-cwd) behavior with no other side effects, since the change is scoped to a single keybinding. Do not silently re-revert without recording the failing case (per the report's lesson that the prior revert carried no rationale); capture which verification case failed so the next attempt targets the real cause.
