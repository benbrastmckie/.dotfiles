# Research Report: Task #33

**Task**: 33 - configure_wezterm_global_tab_navigation
**Started**: 2026-02-11T12:00:00Z
**Completed**: 2026-02-11T12:15:00Z
**Effort**: Small (configuration change)
**Dependencies**: None
**Sources/Inputs**: Codebase (config/wezterm.lua), WezTerm official documentation
**Artifacts**: specs/33_configure_wezterm_global_tab_navigation/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The existing `config/wezterm.lua` already has global tab numbering via `get_global_tab_position()` function
- Current keybindings use `act.ActivateTab(N)` which only navigates within the current window
- Solution: Use `wezterm.action_callback` with `MuxTab:activate()` method to enable cross-window navigation
- The `GuiWindow:focus()` method can bring the target window to foreground after tab activation

## Context & Scope

The user wants Ctrl+Space followed by a number (1-9) to navigate to the tab with that specific global number across all WezTerm windows, rather than just the Nth tab within the current window.

**Current Behavior**: Ctrl+Space + 1 activates tab index 0 in the current window only.
**Desired Behavior**: Ctrl+Space + 1 activates the tab with global position 1 (which may be in any window).

## Findings

### Codebase Patterns

The existing `config/wezterm.lua` (lines 204-221) already has the `get_global_tab_position()` helper function:

```lua
local function get_global_tab_position(current_tab_id)
  local ok, result = pcall(function()
    local all_tab_ids = {}
    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
      for _, mux_tab in ipairs(mux_window:tabs()) do
        table.insert(all_tab_ids, mux_tab:tab_id())
      end
    end
    table.sort(all_tab_ids)
    for i, tid in ipairs(all_tab_ids) do
      if tid == current_tab_id then
        return i
      end
    end
    return nil
  end)
  return ok and result or nil
end
```

This function:
1. Collects all tab IDs from all windows
2. Sorts them by creation order (tab IDs are globally unique and assigned in creation order)
3. Returns the 1-indexed global position of a given tab ID

The current keybindings (lines 373-417) use:
```lua
{ key = "1", mods = "LEADER", action = act.ActivateTab(0) },
{ key = "2", mods = "LEADER", action = act.ActivateTab(1) },
-- ... etc
```

`act.ActivateTab(N)` only activates the tab at index N **within the current window**.

### WezTerm API Research

#### Key APIs for Solution

1. **`wezterm.mux.all_windows()`** - Returns list of all MuxWindow objects
2. **`MuxWindow:tabs()`** - Returns list of MuxTab objects for a window
3. **`MuxTab:tab_id()`** - Returns the globally unique tab ID
4. **`MuxTab:activate()`** - Activates (focuses) the tab (since version 20230408-112425-69ae8472)
5. **`MuxWindow:gui_window()`** - Returns the GuiWindow object for the MuxWindow
6. **`GuiWindow:focus()`** - Brings the window to foreground
7. **`wezterm.action_callback(fn)`** - Creates a custom keybinding action

#### MuxTab:activate() Documentation

From [WezTerm docs](https://wezterm.org/config/lua/MuxTab/activate.html):
- Available since version 20230408-112425-69ae8472
- Takes no parameters
- Activates (focuses) the tab

#### wezterm.action_callback() Documentation

From [WezTerm docs](https://wezterm.org/config/lua/wezterm/action_callback.html):
- Available since version 20211204-082213-a66c61ee9
- Takes a callback function with parameters `(win, pane)`
- Returns an action that triggers the callback

### Recommended Implementation

Create a helper function that finds and activates a tab by its global position:

```lua
-- Helper function to activate a tab by its global position (1-indexed)
local function activate_global_tab(global_position)
  return wezterm.action_callback(function(win, pane)
    -- Collect all tabs with their IDs and parent windows
    local all_tabs = {}
    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
      for _, mux_tab in ipairs(mux_window:tabs()) do
        table.insert(all_tabs, {
          tab = mux_tab,
          tab_id = mux_tab:tab_id(),
          window = mux_window,
        })
      end
    end

    -- Sort by tab_id to get global creation order
    table.sort(all_tabs, function(a, b)
      return a.tab_id < b.tab_id
    end)

    -- Find and activate the tab at the requested global position
    if global_position >= 1 and global_position <= #all_tabs then
      local target = all_tabs[global_position]
      target.tab:activate()

      -- Also focus the window containing this tab
      local gui = target.window:gui_window()
      if gui then
        gui:focus()
      end
    end
  end)
end
```

Then replace the existing keybindings:

```lua
-- Direct tab switching with Ctrl+Space + number (1-9) - GLOBAL across windows
{ key = "1", mods = "LEADER", action = activate_global_tab(1) },
{ key = "2", mods = "LEADER", action = activate_global_tab(2) },
{ key = "3", mods = "LEADER", action = activate_global_tab(3) },
{ key = "4", mods = "LEADER", action = activate_global_tab(4) },
{ key = "5", mods = "LEADER", action = activate_global_tab(5) },
{ key = "6", mods = "LEADER", action = activate_global_tab(6) },
{ key = "7", mods = "LEADER", action = activate_global_tab(7) },
{ key = "8", mods = "LEADER", action = activate_global_tab(8) },
{ key = "9", mods = "LEADER", action = activate_global_tab(9) },
```

### Alternative Approaches Considered

1. **Using `wezterm cli activate-tab --tab-id`**: This CLI command supports `--tab-id` but would require spawning a subprocess for each keybinding, which is slower and more complex than using the Lua API directly.

2. **Using a key table**: Could create a numbered key table for tab selection, but this adds complexity without benefit for this use case.

## Decisions

- Use `wezterm.action_callback` for custom keybinding logic
- Reuse the existing tab ID sorting logic from `get_global_tab_position()`
- Use `MuxTab:activate()` followed by `GuiWindow:focus()` for cross-window activation
- Keep the 1-9 keybinding range (global position 1 = key "1")

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `gui_window()` returns nil in daemon context | Low | Minor | Guard with nil check; tab activation still works |
| Tab numbering mismatch with display | Low | Medium | Both display and keybindings use same sorting algorithm |
| WezTerm version incompatibility | Low | High | Require WezTerm >= 20230408 for `MuxTab:activate()` |

## Appendix

### Search Queries Used

- "WezTerm activate tab by tab_id different window cross-window navigation Lua API"
- "WezTerm wezterm.mux.get_tab activate tab by id global tab navigation"
- "WezTerm MuxTab activate method wezterm.action.callback cross-window tab switch"
- "wezterm.action_callback custom keybinding lua function example"
- "WezTerm MuxWindow focus gui_window activate bring to front"

### References

- [WezTerm MuxTab:activate()](https://wezterm.org/config/lua/MuxTab/activate.html)
- [WezTerm wezterm.action_callback()](https://wezterm.org/config/lua/wezterm/action_callback.html)
- [WezTerm wezterm.mux.get_tab()](https://wezterm.org/config/lua/wezterm.mux/get_tab.html)
- [WezTerm CLI activate-tab](https://wezterm.org/cli/cli/activate-tab.html)
- [WezTerm GuiWindow methods](https://wezterm.org/config/lua/window/index.html)
- [GitHub Issue #3217: Activate MuxTab and Pane directly](https://github.com/wezterm/wezterm/issues/3217)
