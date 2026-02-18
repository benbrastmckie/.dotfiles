# Implementation Plan: Task #33

- **Task**: 33 - configure_wezterm_global_tab_navigation
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/33_configure_wezterm_global_tab_navigation/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Modify the WezTerm configuration to enable cross-window global tab navigation using Ctrl+Space + number keys. The existing `get_global_tab_position()` function already provides global tab numbering for display; this implementation adds a corresponding `activate_global_tab()` function that uses `MuxTab:activate()` and `GuiWindow:focus()` to navigate to tabs by their global position across all windows.

### Research Integration

Key findings from research-001.md:
- Existing `get_global_tab_position()` helper (lines 204-221) provides the sorting algorithm for global tab numbering
- Current keybindings use `act.ActivateTab(N)` which only works within the current window
- Solution uses `wezterm.action_callback()` with `MuxTab:activate()` (available since WezTerm 20230408)
- `GuiWindow:focus()` brings the target window to foreground after tab activation

## Goals & Non-Goals

**Goals**:
- Ctrl+Space + 1-9 navigates to the tab with that global position across all windows
- Pressing a number key activates the tab and focuses its containing window
- Maintain consistency with existing global tab numbering shown in tab bar

**Non-Goals**:
- Changing the tab bar display format (already shows global numbers)
- Adding support for more than 9 tabs via keybindings
- Modifying the `get_global_tab_position()` function itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `gui_window()` returns nil in daemon/mux context | Low | Low | Guard with nil check; tab activation still works |
| WezTerm version incompatibility | High | Low | Require WezTerm >= 20230408 for `MuxTab:activate()` |
| Tab numbering mismatch between display and navigation | Medium | Low | Both use identical sorting algorithm (sorted by tab_id) |

## Implementation Phases

### Phase 1: Implement Global Tab Navigation [COMPLETED]

**Goal**: Add the `activate_global_tab()` helper function and update keybindings to use it.

**Tasks**:
- [x] Add `activate_global_tab(global_position)` function after `get_global_tab_position()`
- [x] Replace the 9 existing `act.ActivateTab(N)` keybindings with `activate_global_tab(N)` calls
- [x] Update the comment above keybindings to indicate global navigation

**Timing**: 20 minutes

**Files to modify**:
- `config/wezterm.lua`
  - Add new function around line 222 (after `get_global_tab_position`)
  - Replace keybindings at lines 372-417

**Verification**:
- WezTerm config reloads without errors
- Tab bar continues to show global numbers correctly

---

### Phase 2: Manual Testing and Verification [COMPLETED]

**Goal**: Verify cross-window tab navigation works correctly.

**Tasks**:
- [ ] Open WezTerm and create 2-3 tabs in a single window
- [ ] Open a second WezTerm window and create 1-2 tabs
- [ ] Verify Ctrl+Space + 1 activates the first globally-created tab (regardless of window)
- [ ] Verify Ctrl+Space + 3 activates the third globally-created tab (may be in different window)
- [ ] Verify the target window is brought to focus when navigating cross-window

**Timing**: 10 minutes

**Verification**:
- All keybindings 1-9 work as expected
- Window focus switches correctly when navigating to tabs in other windows

## Testing & Validation

- [ ] WezTerm config loads without syntax errors
- [ ] Tab bar display unchanged (still shows global numbers)
- [ ] Single-window tab navigation works (same as before, but using global positions)
- [ ] Cross-window tab navigation works (new functionality)
- [ ] Window focus switches correctly when navigating cross-window

## Artifacts & Outputs

- `config/wezterm.lua` - Modified with new `activate_global_tab()` function and updated keybindings
- `specs/33_configure_wezterm_global_tab_navigation/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

If the implementation causes issues:
1. Restore original keybindings using `act.ActivateTab(N)` pattern
2. Remove the `activate_global_tab()` function
3. The change is isolated to a single file with a simple revert path via `git checkout config/wezterm.lua`
