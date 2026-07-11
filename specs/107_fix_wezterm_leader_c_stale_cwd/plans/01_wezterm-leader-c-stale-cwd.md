# Implementation Plan: Fix WezTerm Leader+c new-tab stale cwd

- **Task**: 107 - Fix WezTerm Leader+c new-tab opening in a stale (Neovim) working directory
- **Status**: [NOT STARTED]
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

### Phase 1: Reproduce behavior and resolve the revert [NOT STARTED]

**Goal**: Confirm the current stale-cwd behavior live and determine which Finding-4 explanation caused commit `3af0978` to be reverted, so the re-applied fix is designed against the real cause.

**Tasks**:
- [ ] Confirm the current binding is still `act.SpawnTab("CurrentPaneDomain")` at `config/wezterm.lua:453-457`.
- [ ] Re-read the reverted diff (`git show 3af0978 -- config/wezterm.lua`) and the revert commit (`git log -1 --format='%B' 3d82539`) to confirm the original fallback was plain `SpawnTab` and the revert carries no rationale.
- [ ] Reproduce the stale-cwd symptom: from a shell at `~`, open `nvim`, `tcd`/`cd` into a project (or worktree), exit `nvim`, then `LEADER+c` and confirm the new tab lands in the stale project dir (`pwd`); optionally inspect `/proc/<fish-pid>/cwd` to confirm the physical chdir.
- [ ] Evaluate Finding-4 candidate (a): with `nvim` still open at a project, determine what `pane:get_foreground_process_info().cwd` would return (the project dir) versus the desired `~` -- establishing that the original behaved "correctly" for the exited case but not the still-open case.
- [ ] Evaluate Finding-4 candidate (b): identify conditions under which `get_foreground_process_info()` returns `nil`/empty (domain/`/proc` unavailability) and confirm the original `else` branch degraded straight back to the stale OSC-7 path.
- [ ] Record the diagnosis (which cause is most likely, or that both must be handled) to carry into the Phase 2 design.

**Timing**: 30-40 minutes

**Depends on**: none

**Files to modify**:
- None (investigation only; may read `config/wezterm.lua`, git history, `/proc`).

**Verification**:
- Stale-cwd symptom reproduced and documented.
- A clear statement of the likely revert cause and which case(s) the new design must cover.

---

### Phase 2: Decide policy and design the hardened action_callback [NOT STARTED]

**Goal**: Fix the "new tab while Neovim still open" policy (Decision 4) and design the replacement `action_callback` with a fallback that never returns to plain `SpawnTab`.

**Tasks**:
- [ ] Decide the Neovim-foreground policy explicitly. Recommended (per report Decision 4 and the reported desire): a new tab should land at the shell's/launch cwd (`~`), not the editor's project cwd. Implement by detecting when the foreground process is an editor (via `info.name`/argv) and, in that case, resolving to `$HOME` rather than the editor's project cwd.
- [ ] Design the callback logic:
  - read `pane:get_foreground_process_info()`;
  - if the foreground process is a shell (fish/bash) with a valid `cwd`, use that real `cwd`;
  - if the foreground process is an editor (nvim), resolve to `os.getenv("HOME")` per the decided policy;
  - on `nil`/empty `info`/`info.cwd`, resolve to `os.getenv("HOME")` -- never plain `SpawnTab("CurrentPaneDomain")`;
  - spawn via `act.SpawnCommandInNewTab { domain = "CurrentPaneDomain", cwd = <resolved> }`.
- [ ] Write the final Lua snippet (2-space indent, matching the surrounding `config.keys` binding style at `config/wezterm.lua:442-473`) with a comment documenting the chosen policy and why the fallback is `$HOME`, not `SpawnTab`.
- [ ] Sanity-check that `wezterm` and `act` are already in scope in the file (they are used by the existing bindings) so no new requires are needed.

**Timing**: 25-30 minutes

**Depends on**: 1

**Files to modify**:
- None yet (design artifact only; the snippet is applied in Phase 3).

**Verification**:
- A concrete, reviewed Lua snippet exists with an explicit `$HOME` fallback and the documented Neovim-foreground policy.

---

### Phase 3: Apply config edit and deploy via home-manager [NOT STARTED]

**Goal**: Replace the `LEADER+c` binding in `config/wezterm.lua` with the Phase 2 snippet and deploy it, verifying the deployed symlink updated.

**Tasks**:
- [ ] Edit `config/wezterm.lua:453-457`, replacing the `act.SpawnTab("CurrentPaneDomain")` action with the hardened `action_callback` from Phase 2 (preserve the `key = "c"`, `mods = "LEADER"` fields and the surrounding table style).
- [ ] Confirm the text mirror path is handled: the repo also exposes `.config/config-files/wezterm.lua` via `builtins.readFile` in `modules/home/core/dotfiles.nix`, which re-reads the same source file, so no separate edit is needed -- verify this rather than assume.
- [ ] Run `home-manager switch` (or the host's `nixos-rebuild` path if home-manager is a NixOS module); capture success/failure.
- [ ] Verify deployment: `readlink -f ~/.config/wezterm/wezterm.lua` points at the new nix-store path, and `grep -n "get_foreground_process_info" ~/.config/wezterm/wezterm.lua` shows the new binding is present in the deployed file.
- [ ] Reload WezTerm config (WezTerm auto-reloads on config change; otherwise trigger a reload) so the new binding is active for Phase 4.

**Timing**: 20-25 minutes

**Depends on**: 2

**Files to modify**:
- `config/wezterm.lua` - replace the `LEADER+c` binding (lines 453-457) with the hardened `action_callback`.
- `modules/home/core/dotfiles.nix` - no edit expected; verify the existing symlink + text-mirror entries already source the updated file.

**Verification**:
- `home-manager switch` completes successfully.
- `readlink -f ~/.config/wezterm/wezterm.lua` resolves to a new store path and the deployed file contains the new binding.

---

### Phase 4: Behavioral verification [NOT STARTED]

**Goal**: Confirm the fix works across all cases in the report's verification protocol and did not regress the tab-title feature.

**Tasks**:
- [ ] Case 1 (fish-at-home): from `fish` at `~`, `LEADER+c` -> new tab `pwd` is `~`.
- [ ] Case 2 (nvim-exited-then-spawn, the previously broken case): open `nvim`, `tcd`/`cd` into a project, **exit nvim**, then `LEADER+c` -> new tab `pwd` is `~`.
- [ ] Case 3 (nvim-still-open policy check): with `nvim` still open at a project, `LEADER+c` -> confirm the tab lands at `~` per the Phase 2 policy decision (or the explicitly documented alternative).
- [ ] Case 4 (feature regression): confirm the WezTerm tab title / project-name feature still updates from Neovim's OSC-7 emission (open nvim in a project, verify the tab title reflects the project).
- [ ] Optional nil-path spot check: if a domain/condition producing `nil` is reachable, confirm the new tab still lands at `$HOME` rather than a stale dir.
- [ ] Record pass/fail per case; if any case fails, return to Phase 1/2 diagnosis rather than re-reverting blindly.

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
