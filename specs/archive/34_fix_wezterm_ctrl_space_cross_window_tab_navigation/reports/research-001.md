# Research Report: Task #34

**Task**: 34 - fix_wezterm_ctrl_space_cross_window_tab_navigation
**Date**: 2026-02-11
**Focus**: Investigate why cross-window tab navigation is not working and identify solutions

## Summary

The cross-window tab activation implementation from task 33 uses `MuxTab:activate()` and `GuiWindow:focus()` correctly, but window focusing fails on Wayland due to focus-stealing prevention. WezTerm does not fully support the xdg-activation protocol required for programmatic window focus on modern Wayland compositors. The primary fix involves using `wezterm.gui.gui_window_for_mux_window()` instead of `MuxWindow:gui_window()`, and potentially working around Wayland limitations by using wezterm CLI commands or the ActivateWindow action.

## Findings

### Current Implementation Analysis

The `activate_global_tab()` function at lines 226-261 of `config/wezterm.lua`:

1. Collects all tabs from all windows using `wezterm.mux.all_windows()`
2. Sorts by `tab_id` for consistent global ordering
3. Calls `target.tab:activate()` to activate the target tab
4. Calls `target.window:gui_window()` then `gui_win:focus()` to focus the window

**Potential Issue 1: `MuxWindow:gui_window()` may return nil for different windows**

The current code calls `target.window:gui_window()` where `target.window` is a `MuxWindow` object. According to WezTerm documentation, `MuxWindow:gui_window()` returns the GUI window representation, but this may return `nil` if:
- The MuxWindow is in a detached/daemon context
- The MuxWindow belongs to a different GUI process
- There's no active GUI window association for that MuxWindow

The code has a nil guard, but if `gui_window()` returns nil, the focus call is simply skipped, leaving the user on the wrong window.

**Potential Issue 2: Wayland Focus-Stealing Prevention**

On Wayland compositors (the config has `enable_wayland = true`), programmatic window focus is restricted by the xdg-activation protocol. Key limitations:

- Applications cannot programmatically steal focus; they can only request it
- The compositor can reject focus requests at any time
- WezTerm has an open issue (#3619) for incomplete xdg-activation support
- `GuiWindow:focus()` may silently fail on Wayland compositors like GNOME/Mutter

### WezTerm API Options

**Option A: Use `wezterm.gui.gui_window_for_mux_window()`**

This function (available since 20220807) directly resolves a MuxWindow to its GuiWindow:
```lua
local gui_win = wezterm.gui.gui_window_for_mux_window(target.window:window_id())
```

This is potentially more reliable than `MuxWindow:gui_window()` when working across windows in an action_callback context.

**Option B: Use `perform_action` with `ActivateWindow`**

Instead of calling `gui_win:focus()`, use the built-in ActivateWindow action which may have better Wayland support:
```lua
-- Get window index and use ActivateWindow action
window:perform_action(wezterm.action.ActivateWindow(window_index), pane)
```

However, this requires knowing the window's index, not its MuxWindow object.

**Option C: Use wezterm CLI as a workaround**

The `wezterm cli activate-pane` command can activate panes, and when combined with `WEZTERM_UNIX_SOCKET`, might provide a more reliable activation path. However, CLI commands are designed for external scripts, not Lua callbacks.

### Wayland Protocol Limitations

The xdg-activation protocol (the Wayland standard for window activation):
- Requires an "activation token" that transfers focus permission between surfaces
- Tokens can be invalidated by the compositor at any time
- GNOME/Mutter has strict focus-stealing prevention
- WezTerm issue #3619 tracks incomplete xdg-activation support

This means that even with correct API usage, Wayland compositors may refuse to focus a window that wasn't initiated by direct user action on that window.

### Testing Environment

The user's config shows:
- `config.enable_wayland = true`
- Running on NixOS with Wayland
- Using Mutter/GNOME or similar compositor

## Recommendations

### Primary Fix: Use `wezterm.gui.gui_window_for_mux_window()`

Replace lines 255-259 in `activate_global_tab()`:

```lua
-- Current (potentially problematic):
local gui_win = target.window:gui_window()
if gui_win then
  gui_win:focus()
end

-- Recommended:
local gui_win = wezterm.gui.gui_window_for_mux_window(target.window:window_id())
if gui_win then
  gui_win:focus()
end
```

### Secondary Fix: Add ActivateWindow fallback

If `gui_win:focus()` alone is insufficient on Wayland, consider using the Window object from the callback to perform an ActivateWindow action. This may have better compositor integration.

### Workaround for Wayland: Raise visual urgency

If focus cannot be stolen programmatically, consider setting the window's urgency hint so the compositor shows a visual notification (like a bouncing dock icon or taskbar highlight). This at least alerts the user.

### Alternative Architecture: Single Window with Multiple Tabs

If cross-window navigation proves unreliable on Wayland, consider whether the workflow could use a single WezTerm window with more tabs instead of multiple windows.

## References

- [WezTerm MuxWindow Object](https://wezterm.org/config/lua/mux-window/index.html)
- [WezTerm gui_window_for_mux_window](https://wezterm.org/config/lua/wezterm.gui/gui_window_for_mux_window.html)
- [WezTerm Issue #3619 - xdg-activation support](https://github.com/wezterm/wezterm/issues/3619)
- [WezTerm Issue #3542 - activate-window CLI command](https://github.com/wezterm/wezterm/issues/3542)
- [XDG Activation Protocol](https://wayland.app/protocols/xdg-activation-v1)
- [Kai Uwe's Blog - On Window Activation](https://blog.broulik.de/2025/08/on-window-activation/)

## Next Steps

1. Implement the `wezterm.gui.gui_window_for_mux_window()` fix
2. Test cross-window navigation on both Wayland and X11 (if available)
3. If still failing on Wayland, investigate window urgency hints as a fallback
4. Consider adding debug logging to determine if `gui_window()` is returning nil or if `focus()` is being called but ignored
