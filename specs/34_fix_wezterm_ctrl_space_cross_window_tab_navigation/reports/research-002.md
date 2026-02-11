# Research Report: Task #34 (Follow-up)

**Task**: 34 - fix_wezterm_ctrl_space_cross_window_tab_navigation
**Date**: 2026-02-11
**Focus**: Online research for robust cross-window tab navigation solutions

## Summary

This follow-up research confirms that **programmatic window focus on Wayland is fundamentally limited by design**. However, three viable solutions emerged from community research: (1) Using WezTerm workspaces to consolidate tabs into a single GUI window, (2) Using compositor-specific tools like `hyprctl` or `swaymsg` to handle window focus externally, and (3) Waiting for WezTerm's xdg-activation protocol support (Issue #3619). The workspace approach is the most robust and elegant solution for the current architecture.

## Key Findings from Online Research

### 1. WezTerm's activate-window CLI Command Status

**GitHub Issue [#3542](https://github.com/wezterm/wezterm/issues/3542)**: Request for `wezterm cli activate-window --window-id` command.

**Status**: OPEN (as of May 2024)

**Maintainer Response** (Wez Furlong):
> "The CLI operates at the Mux level which doesn't have any GUI concepts."

This confirms that the CLI cannot handle window focus because the multiplexer layer is decoupled from the GUI layer. The architecture prevents a simple CLI solution.

**Community Workarounds Mentioned**:
- Use `InputSelector` with `PromptInputLine` for in-wezterm workspace selection
- Use `SetUserVar` escape sequences to communicate between shell scripts and wezterm config
- Encode workspace/directory data and listen for `user-var-changed` events

### 2. xdg-activation Protocol Support

**GitHub Issue [#3619](https://github.com/wezterm/wezterm/issues/3619)**: Wayland xdg-activation protocol support.

**Status**: OPEN (as of September 2023)

**Problem**: On Wayland compositors (GNOME/Mutter, KDE/KWin, Hyprland), applications cannot programmatically steal focus. The xdg-activation protocol requires:

1. Setting `StartupNotify=true` in desktop file
2. Handling `$XDG_ACTIVATION_TOKEN` environment variable
3. Passing tokens to `XdgActivationV1::activate` method

**Impact**: Even with correct API usage (`gui_win:focus()`), Wayland compositors may silently reject focus requests that don't have proper activation tokens.

**Related Issue [#5241](https://github.com/wezterm/wezterm/issues/5241)**: `wezterm start --new-tab` doesn't focus window. Closed as duplicate of #3619.

### 3. The MuxTab:activate() and Pane:activate() API

**GitHub Issue [#3217](https://github.com/wezterm/wezterm/issues/3217)**: Activate MuxTab and Pane objects directly.

**Status**: IMPLEMENTED (commit `dd16e58`, April 2023)

The current implementation correctly uses `tab:activate()` which is the proper API. The problem is not with tab activation but with window focus.

### 4. Window Object focus() Method

**Documentation**: [Window Object](https://wezterm.org/config/lua/window/index.html)

The `focus()` method exists on the Window object, but:
- May fail silently on Wayland compositors
- Requires the Window to be resolved from MuxWindow context
- `gui_window_for_mux_window()` is the recommended approach (per documentation)

**GitHub Issue [#4820](https://github.com/wezterm/wezterm/issues/4820)**: `wezterm ssh` window focus issues.

Shows that even explicit `window:gui_window():focus()` calls exhibit the same behavior - working on first run but failing on subsequent runs. This suggests a deeper Wayland protocol issue rather than an API usage problem.

### 5. Workspaces as an Alternative Architecture

**Documentation**: [Workspaces/Sessions](https://wezterm.org/recipes/workspaces.html)

**Key Insight**: Workspaces in WezTerm are not containers; windows are tagged with workspace labels. When switching workspaces, the GUI swaps which windows are visible.

**Discussion [#2243](https://github.com/wezterm/wezterm/discussions/2243)**: What are workspaces?

From the discussion:
> "The actual model is 'window is tagged with a workspace label string' rather than workspaces containing windows."

**Implication**: If all tabs were in a single workspace displayed by a single GUI window, the cross-window focus problem disappears entirely.

### 6. Compositor-Specific Solutions

For users running specific Wayland compositors, external window management is possible:

**Sway/i3-like compositors**:
```bash
swaymsg '[app_id="org.wezfurlong.wezterm"] focus'
```

**Hyprland**:
```bash
hyprctl dispatch focuswindow address:0x...
```

**GNOME** (via [gnome-active-window](https://github.com/vslobodyan/gnome-active-window)):
Replacement for wmctrl/xdotool functions on Wayland.

**Key Limitation**: These tools can focus a window but require knowing which window to focus. Integrating this with WezTerm's Lua config requires spawning external commands.

### 7. Community Config Examples

**Blog: [Session Management in WezTerm](https://fredrikaverpil.github.io/blog/2024/10/20/session-management-in-wezterm-without-tmux/)**

Uses `smart_workspace_switcher.wezterm` plugin with keybindings:
- `Ctrl+Shift+S`: Activate workspace manager
- `Ctrl+Shift+[/]`: Cycle between workspaces
- `Ctrl+Shift+T`: Display open workspaces via launcher

This approach uses workspaces rather than multiple windows, avoiding the focus problem.

**Blog: [WezTerm Projects Selector](https://blog.annimon.com/wezterm-projects/)**

Uses `InputSelector` to dynamically build tab lists and switch between them within WezTerm's UI, avoiding external window focus entirely.

## Recommended Solutions

### Solution A: Workspace-Based Architecture (Recommended)

**Approach**: Consolidate all tabs into a single workspace displayed by a single GUI window.

**Advantages**:
- Completely avoids cross-window focus issues
- Works on all platforms (Wayland, X11, macOS)
- Matches tmux/screen mental model
- Uses WezTerm's built-in workspace switching

**Implementation**:
1. Ensure all tabs spawn in the same workspace (default behavior)
2. Use `ActivateTab` with relative/absolute indices within the window
3. The existing `activate_global_tab()` function works correctly for single-window scenarios

**Trade-off**: Loses the ability to have multiple WezTerm windows visible simultaneously.

### Solution B: Compositor Integration (Compositor-Specific)

**Approach**: Call compositor-specific commands from Lua to focus windows.

**Example for Hyprland**:
```lua
local function focus_window_external(window_address)
  -- Get window address and call hyprctl
  os.execute('hyprctl dispatch focuswindow address:' .. window_address)
end
```

**Challenges**:
- Need to track window addresses/IDs
- Different code paths for different compositors
- WezTerm doesn't expose Wayland surface IDs to Lua
- Fragile if window properties change

**Implementation Sketch**:
```lua
local function activate_global_tab(global_position)
  return wezterm.action_callback(function(window, pane)
    -- ... existing tab collection and sorting code ...

    target.tab:activate()

    -- Try WezTerm focus first
    local gui_win = wezterm.gui.gui_window_for_mux_window(target.window:window_id())
    if gui_win then
      gui_win:focus()
    end

    -- Fallback to compositor-specific focus
    -- This requires knowing the compositor and having appropriate tools
    local compositor = os.getenv("XDG_CURRENT_DESKTOP")
    if compositor == "Hyprland" then
      -- Would need window address - not easily available
      -- os.execute('hyprctl dispatch focuswindow ...')
    end
  end)
end
```

### Solution C: User Variable Signaling (Partial)

**Approach**: Use WezTerm's user variable system to signal that a tab needs attention.

**Current Implementation**: The config already has CLAUDE_STATUS user variable for tab notification coloring.

**Enhancement**: Set an urgency hint when cross-window navigation is attempted:
```lua
-- Instead of failing silently, set visual indicator
if not gui_win then
  -- Mark the target tab as needing attention
  -- User can then manually switch windows
  target_pane:inject_output("\027]1337;SetUserVar=URGENT=1\007")
end
```

**Limitation**: Still requires manual window switching but provides visual feedback.

### Solution D: Wait for xdg-activation Support

**Status**: GitHub Issue #3619 is open but complex to implement.

**Timeline**: Unknown - depends on WezTerm maintainer bandwidth.

**Workaround While Waiting**: Use Solution A (workspaces) as primary, with graceful degradation.

## Implementation Recommendations

### Immediate Fix (Current Architecture)

1. Replace `target.window:gui_window()` with `wezterm.gui.gui_window_for_mux_window(target.window:window_id())` as noted in research-001.md

2. Add debug logging to understand failure modes:
```lua
local gui_win = wezterm.gui.gui_window_for_mux_window(target.window:window_id())
if gui_win then
  wezterm.log_info("Focusing window: " .. tostring(gui_win:window_id()))
  gui_win:focus()
else
  wezterm.log_warn("Could not resolve GUI window for mux window: " .. tostring(target.window:window_id()))
end
```

### Medium-Term (Architecture Change)

Migrate to workspace-based model:
1. Spawn all new tabs in the same window
2. Use `SwitchToWorkspace` for logical grouping if needed
3. Remove multi-window assumption from `activate_global_tab()`

### Long-Term (Contribute Upstream)

Consider contributing to WezTerm's xdg-activation implementation or the `activate-window` CLI command.

## References

### WezTerm GitHub Issues
- [#3542 - Add activate-window CLI command](https://github.com/wezterm/wezterm/issues/3542) (OPEN)
- [#3619 - Wayland xdg-activation support](https://github.com/wezterm/wezterm/issues/3619) (OPEN)
- [#5241 - Focus window with --new-tab](https://github.com/wezterm/wezterm/issues/5241) (CLOSED - duplicate of #3619)
- [#3217 - Activate MuxTab and Pane directly](https://github.com/wezterm/wezterm/issues/3217) (IMPLEMENTED)
- [#4820 - SSH window focus issues](https://github.com/wezterm/wezterm/issues/4820) (OPEN)
- [#5918 - GuiWindow switch MuxWindow](https://github.com/wezterm/wezterm/issues/5918) (OPEN)

### WezTerm Documentation
- [Window Object](https://wezterm.org/config/lua/window/index.html)
- [gui_window_for_mux_window](https://wezterm.org/config/lua/wezterm.gui/gui_window_for_mux_window.html)
- [Workspaces/Sessions](https://wezterm.org/recipes/workspaces.html)
- [InputSelector](https://wezterm.org/config/lua/keyassignment/InputSelector.html)
- [SwitchToWorkspace](https://wezterm.org/config/lua/keyassignment/SwitchToWorkspace.html)
- [wezterm.mux module](https://wezterm.org/config/lua/wezterm.mux/index.html)
- [wezterm cli activate-tab](https://wezterm.org/cli/cli/activate-tab.html)

### Community Resources
- [Session Management in WezTerm (without tmux)](https://fredrikaverpil.github.io/blog/2024/10/20/session-management-in-wezterm-without-tmux/)
- [WezTerm Projects Selector](https://blog.annimon.com/wezterm-projects/)
- [How I use WezTerm](https://mwop.net/blog/2024-07-04-how-i-use-wezterm.html)
- [On Window Activation (Wayland blog)](https://blog.broulik.de/2025/08/on-window-activation/)

### Wayland Protocol
- [XDG Activation Protocol](https://wayland.app/protocols/xdg-activation-v1)

### External Tools
- [gnome-active-window](https://github.com/vslobodyan/gnome-active-window) - wmctrl replacement for GNOME/Wayland
- [swayr](https://sr.ht/~tsdh/swayr/) - Window switcher for Sway

## Conclusion

The cross-window focus problem is a fundamental limitation of Wayland's security model, not a WezTerm bug. The most robust and elegant solution is to adopt a workspace-based architecture where all tabs exist within a single GUI window. This matches the tmux/screen paradigm and avoids focus-stealing issues entirely.

If multiple visible windows are required, compositor-specific integration (hyprctl, swaymsg) can provide focus switching, but this adds complexity and reduces portability.

## Next Steps

1. Decide whether to adopt workspace-based architecture or pursue compositor integration
2. If staying with multi-window, implement the `gui_window_for_mux_window()` fix from research-001.md
3. Add debug logging to understand current failure modes
4. Consider contributing to WezTerm's xdg-activation implementation
