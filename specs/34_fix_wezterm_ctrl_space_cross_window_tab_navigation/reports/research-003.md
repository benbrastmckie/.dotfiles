# Research Report: Task #34 (Compositor Integration Focus)

**Task**: 34 - fix_wezterm_ctrl_space_cross_window_tab_navigation
**Date**: 2026-02-17
**Focus**: Compositor-specific solutions for cross-window tab navigation on GNOME and Niri

## Summary

This follow-up research investigates concrete implementation options for focusing WezTerm windows programmatically on the user's NixOS system, which supports both GNOME/Mutter and Niri compositors. The most robust solution involves compositor-specific external commands invoked from WezTerm's Lua config, with Niri offering native IPC support and GNOME requiring a D-Bus extension. Both solutions are available in nixpkgs.

## User Environment

Based on codebase analysis:
- **Primary compositor**: GNOME/Mutter (with GNOME services enabled)
- **Alternative compositor**: Niri (scrollable-tiling Wayland compositor)
- **WezTerm config**: `enable_wayland = true`, `window_decorations = "NONE"`
- **WezTerm app_id**: `org.wezfurlong.wezterm`
- **Both compositors** have existing configuration in the dotfiles

## Solution 1: Niri IPC (Recommended for Niri Sessions)

Niri provides native IPC support via `niri msg` commands. This is the cleanest solution when running under Niri.

### Available Commands

```bash
# List all windows with their IDs
niri msg windows

# Focus a specific window by ID
niri msg action focus-window --id <window_id>

# Pick a window interactively (useful for debugging)
niri msg pick-window
```

### JSON Output

```bash
# Get windows list in JSON format
niri msg --json windows
```

Output includes window ID, app_id, title, workspace, and other metadata.

### Integration with WezTerm Lua

```lua
local function focus_niri_window(window_id)
  local cmd = string.format("niri msg action focus-window --id %d", window_id)
  os.execute(cmd)
end
```

### Challenge: Getting WezTerm Window IDs

WezTerm's Lua API provides `MuxWindow:window_id()` which is the internal WezTerm ID, not the compositor window ID. To map between them:

1. Use `niri msg windows --json` to get all windows
2. Filter by `app_id == "org.wezfurlong.wezterm"`
3. Match by window title (which includes tab info)

### Niri Window Rule

The user's config already has a window rule for WezTerm handling. For reference:

```kdl
window-rule {
  match app-id=r#"^org\.wezfurlong\.wezterm$"#
  default-column-width {}
}
```

### NixOS Availability

Niri is available in nixpkgs and already configured in the user's `configuration.nix`.

## Solution 2: GNOME Shell Extension (Recommended for GNOME Sessions)

For GNOME/Mutter sessions, the `activate-window-by-title` extension provides D-Bus methods to focus windows.

### Extension Details

- **Name**: Activate Window by Title
- **NixOS Package**: `gnomeExtensions.activate-window-by-title`
- **UUID**: `activate-window-by-title@lucaswerkmeister.de`
- **D-Bus Interface**: `de.lucaswerkmeister.ActivateWindowByTitle`

### D-Bus Methods

| Method | Description |
|--------|-------------|
| `activateByTitle(title)` | Exact title match |
| `activateByPrefix(prefix)` | Title starts with prefix |
| `activateBySuffix(suffix)` | Title ends with suffix |
| `activateBySubstring(str)` | Title contains string |
| `activateById(id)` | Activate by window ID |
| `activateByWmClass(class)` | Activate by WM_CLASS |

### Usage from Command Line

```bash
# Activate window by title substring
gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /de/lucaswerkmeister/ActivateWindowByTitle \
  --method de.lucaswerkmeister.ActivateWindowByTitle.activateBySubstring \
  'WezTerm'

# Activate by WM_CLASS (app_id equivalent)
gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /de/lucaswerkmeister/ActivateWindowByTitle \
  --method de.lucaswerkmeister.ActivateWindowByTitle.activateByWmClass \
  'org.wezfurlong.wezterm'
```

### Integration with WezTerm Lua

```lua
local function focus_gnome_window_by_title(title_substring)
  local cmd = string.format(
    [[gdbus call --session --dest org.gnome.Shell ]] ..
    [[--object-path /de/lucaswerkmeister/ActivateWindowByTitle ]] ..
    [[--method de.lucaswerkmeister.ActivateWindowByTitle.activateBySubstring '%s']],
    title_substring
  )
  os.execute(cmd)
end
```

### NixOS/Home Manager Configuration

```nix
# In home.nix
home.packages = with pkgs; [
  gnomeExtensions.activate-window-by-title
];

dconf.settings = {
  "org/gnome/shell" = {
    enabled-extensions = [
      "activate-window-by-title@lucaswerkmeister.de"
    ];
  };
};
```

### Alternative: Window Calls Extended

For more programmatic control, `window-calls-extended` provides:

```bash
# List all windows
gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/Windows \
  --method org.gnome.Shell.Extensions.Windows.List

# Get window details
gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/Windows \
  --method org.gnome.Shell.Extensions.Windows.Details <window_id>

# Activate window by ID
gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /org/gnome/Shell/Extensions/Windows \
  --method org.gnome.Shell.Extensions.Windows.Activate <window_id>
```

## Solution 3: Hybrid Compositor Detection

Since the user has both GNOME and Niri configured, the WezTerm config can detect which compositor is running:

```lua
local function detect_compositor()
  local xdg_session_desktop = os.getenv("XDG_SESSION_DESKTOP")
  local xdg_current_desktop = os.getenv("XDG_CURRENT_DESKTOP")

  if xdg_session_desktop == "niri" or xdg_current_desktop == "niri" then
    return "niri"
  elseif xdg_current_desktop and xdg_current_desktop:find("GNOME") then
    return "gnome"
  end
  return "unknown"
end

local function focus_wezterm_window_external(target_title)
  local compositor = detect_compositor()

  if compositor == "niri" then
    -- Use niri msg to find and focus window
    local handle = io.popen("niri msg --json windows 2>/dev/null")
    if handle then
      local output = handle:read("*a")
      handle:close()
      -- Parse JSON, find window by title, extract ID, focus
      -- (implementation details below)
    end
  elseif compositor == "gnome" then
    -- Use gdbus with activate-window-by-title extension
    local cmd = string.format(
      [[gdbus call --session --dest org.gnome.Shell ]] ..
      [[--object-path /de/lucaswerkmeister/ActivateWindowByTitle ]] ..
      [[--method de.lucaswerkmeister.ActivateWindowByTitle.activateBySubstring '%s' 2>/dev/null]],
      target_title
    )
    os.execute(cmd)
  end
end
```

## Solution 4: Tab Title Encoding Strategy

To enable external focus commands, encode identifying information in WezTerm tab titles:

### Current Tab Title Format

The user's config already includes a `format-tab-title` handler that shows:
- Global tab position (1, 2, 3...)
- Project directory name
- Optional task number from `TASK_NUMBER` user variable

### Enhanced Title for Matching

Modify the tab title format to include a unique window identifier:

```lua
-- In format-tab-title handler, include window_id
local window_id = tab.window_id or "?"
local title = string.format("W%d:%d %s", window_id, tab_number, project_name)
```

This enables matching like `activateBySubstring("W2:3")` to focus window 2, tab 3.

## WezTerm xdg-activation Status

### GitHub Issue #3619 Status

The xdg-activation protocol support issue remains **OPEN** as of February 2026. Key points:

- **Root Cause**: WezTerm doesn't implement the xdg-activation-v1 Wayland protocol
- **Effect**: `gui_window:focus()` calls are ignored by the compositor
- **Workaround**: None internal to WezTerm; must use external compositor tools
- **Related Issue #5538**: Same limitation affects URL opening focus

### Why External Tools Are Needed

The Wayland security model prevents applications from stealing focus. Compositors only grant focus through:
1. User interaction (click, keyboard)
2. xdg-activation tokens (not implemented in WezTerm)
3. Compositor-specific privileged interfaces (our solution)

## Comparison of Solutions

| Solution | Compositor | Complexity | Reliability | NixOS Package |
|----------|------------|------------|-------------|---------------|
| Niri IPC | Niri only | Low | High | `niri` (system) |
| GNOME D-Bus Extension | GNOME only | Medium | High | `gnomeExtensions.activate-window-by-title` |
| Hybrid Detection | Both | Medium-High | High | Both packages |
| Workspace Architecture | Either | Low | Highest | None needed |

## Recommended Implementation

### Option A: Compositor-Specific (Best UX)

1. Install GNOME extension via Home Manager
2. Modify `activate_global_tab()` to:
   - First try WezTerm's `gui_win:focus()` (in case xdg-activation gets implemented)
   - Fall back to compositor-specific external command
   - Use tab title matching with encoded window info

### Option B: Workspace Architecture (Most Robust)

1. Consolidate all WezTerm tabs into a single window
2. Use native `ActivateTab` actions within that window
3. Avoid cross-window focus entirely

This matches the tmux/screen mental model and is immune to compositor limitations.

### Option C: Visual Feedback (Graceful Degradation)

If focus fails, set an urgency hint or visual indicator:
- Use `CLAUDE_STATUS` user variable to highlight the target tab
- User manually switches windows knowing which tab needs attention

## Implementation Sketch

### Modified activate_global_tab()

```lua
local function activate_global_tab(global_position)
  return wezterm.action_callback(function(window, pane)
    -- ... existing tab collection code ...

    local target = all_tabs[global_position]
    if not target then return end

    -- Activate the tab within WezTerm
    target.tab:activate()

    -- Try WezTerm focus first
    local gui_win = wezterm.gui.gui_window_for_mux_window(target.window:window_id())
    if gui_win then
      gui_win:focus()
    end

    -- Check if we're already in the target window
    if target.window:window_id() == window:mux_window():window_id() then
      return -- No cross-window focus needed
    end

    -- External focus fallback
    local compositor = detect_compositor()
    if compositor == "niri" then
      -- Get target window's title for matching
      local target_pane = target.tab:active_pane()
      local title = target_pane:get_title()
      focus_via_niri(title)
    elseif compositor == "gnome" then
      local target_pane = target.tab:active_pane()
      local title = target_pane:get_title()
      focus_via_gnome(title)
    end
  end)
end
```

## NixOS Configuration Changes

### For GNOME Extension Support

```nix
# home.nix additions
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnomeExtensions.activate-window-by-title
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = with pkgs.gnomeExtensions; [
        activate-window-by-title.extensionUuid
        # ... existing extensions
      ];
    };
  };
}
```

### Niri Already Configured

Niri is already enabled in `configuration.nix` with `programs.niri.enable = true` equivalent setup.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Extension not enabled | GNOME focus fails silently | Add to enabled-extensions declaratively |
| Niri not running | Niri commands fail | Check compositor before calling |
| Title matching ambiguity | Wrong window focused | Include unique window ID in title |
| Race condition | Tab activated before focus | Add small delay after tab activation |
| os.execute() blocking | UI freeze | Use non-blocking subprocess if needed |

## References

### WezTerm Issues
- [#3619 - xdg-activation support](https://github.com/wezterm/wezterm/issues/3619) (OPEN)
- [#3542 - activate-window CLI](https://github.com/wezterm/wezterm/issues/3542) (OPEN)
- [#5538 - xdg-activation for URLs](https://github.com/wezterm/wezterm/issues/5538) (OPEN)

### GNOME Extensions
- [activate-window-by-title](https://github.com/lucaswerkmeister/activate-window-by-title)
- [window-calls](https://github.com/ickyicky/window-calls)
- [window-calls-extended](https://github.com/dev-muhammad-adel/window-calls-extended)

### Niri Documentation
- [Niri IPC Documentation](https://github.com/niri-wm/niri/wiki/IPC)
- [Niri Window Rules](https://github.com/niri-wm/niri/wiki/Configuration:-Window-Rules)
- [Niri Application Issues](https://github.com/niri-wm/niri/wiki/Application-Issues)

### NixOS
- [NixOS GNOME Wiki](https://nixos.wiki/wiki/GNOME)
- [Home Manager GNOME Extensions](https://discourse.nixos.org/t/enabling-gnome-extensions-with-home-manager/59701)

## Next Steps

1. **Decide on architecture**: Compositor-specific vs. single-window approach
2. **If compositor-specific**:
   - Add `gnomeExtensions.activate-window-by-title` to home.nix
   - Enable extension in dconf settings
   - Implement hybrid `activate_global_tab()` with fallback
3. **Test on both compositors**: Verify focus works on GNOME and Niri
4. **Add error handling**: Graceful degradation when external tools fail
