# Implementation Plan: Task #34

- **Task**: 34 - fix_wezterm_ctrl_space_cross_window_tab_navigation
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/research-001.md, reports/research-002.md, reports/research-003.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

This plan addresses the cross-window tab navigation failure in WezTerm on Wayland. The root cause is that Wayland's focus-stealing prevention blocks WezTerm's `gui_win:focus()` call. The solution uses the `activate-window-by-title` GNOME Shell extension, which provides D-Bus methods to focus windows programmatically from within the compositor.

### Research Integration

Integrated findings from three research reports:
- **research-001.md**: Identified root cause (Wayland focus-stealing, WezTerm issue #3619)
- **research-002.md**: Evaluated 4 solution approaches (workspace, compositor, user variable, xdg-activation)
- **research-003.md**: Documented GNOME D-Bus extension solution with implementation details

## Goals & Non-Goals

**Goals**:
- Enable cross-window tab navigation (Ctrl+Space + number) on GNOME/Mutter sessions
- Install and enable `activate-window-by-title` GNOME extension via Home Manager
- Modify WezTerm Lua to use gdbus fallback when `gui_win:focus()` fails
- Detect GNOME session and apply compositor-specific focus logic

**Non-Goals**:
- Niri IPC support (deferred to future enhancement per user direction)
- X11 support (user is on Wayland)
- Modifying WezTerm source code or waiting for xdg-activation support

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension not found in nixpkgs | H | L | Verify package exists; fallback to manual install |
| Extension disabled after install | M | M | Enable via dconf.settings declaratively |
| gdbus command fails silently | M | L | Add error logging, verify extension is running |
| Title matching ambiguity | L | L | Use WezTerm's app_id for unique matching |

## Implementation Phases

### Phase 1: Add GNOME Extension to Home Manager [NOT STARTED]

**Goal**: Install and enable the `activate-window-by-title` GNOME Shell extension declaratively via Home Manager.

**Tasks**:
- [ ] Add `gnomeExtensions.activate-window-by-title` to `home.packages` in `home.nix`
- [ ] Add extension UUID to `enabled-extensions` in `dconf.settings`
- [ ] Verify the extension is available in nixpkgs

**Timing**: 20 minutes

**Files to modify**:
- `home.nix` - Add package and dconf settings

**Code changes**:

Add to `home.packages`:
```nix
gnomeExtensions.activate-window-by-title
```

Add to `dconf.settings`:
```nix
"org/gnome/shell" = {
  enabled-extensions = [
    "activate-window-by-title@lucaswerkmeister.de"
  ];
};
```

**Verification**:
- Run `nix flake check` to validate syntax
- After `nixos-rebuild switch`, verify extension appears in GNOME Extensions app
- Test manually: `gdbus call --session --dest org.gnome.Shell --object-path /de/lucaswerkmeister/ActivateWindowByTitle --method de.lucaswerkmeister.ActivateWindowByTitle.activateBySubstring 'WezTerm'`

---

### Phase 2: Implement Compositor Detection in WezTerm [NOT STARTED]

**Goal**: Add a helper function to detect the current compositor (GNOME vs other) so focus logic can be applied conditionally.

**Tasks**:
- [ ] Add `detect_compositor()` function that checks `XDG_CURRENT_DESKTOP` environment variable
- [ ] Return "gnome" for GNOME sessions, "unknown" otherwise
- [ ] Place function near the top of `wezterm.lua` with other helper functions

**Timing**: 15 minutes

**Files to modify**:
- `config/wezterm.lua` - Add compositor detection function

**Code changes**:

Add helper function after line 5 (after `local act = wezterm.action`):
```lua
-- Helper function to detect the current compositor
local function detect_compositor()
  local xdg_current_desktop = os.getenv("XDG_CURRENT_DESKTOP")
  if xdg_current_desktop and xdg_current_desktop:find("GNOME") then
    return "gnome"
  end
  return "unknown"
end
```

**Verification**:
- Add temporary debug print to verify detection works
- Test in GNOME session to confirm "gnome" is returned

---

### Phase 3: Add GNOME Window Focus Function [NOT STARTED]

**Goal**: Create a function that uses gdbus to focus a WezTerm window via the `activate-window-by-title` extension.

**Tasks**:
- [ ] Add `focus_wezterm_window_gnome()` function that calls gdbus
- [ ] Use `activateByWmClass` method with `org.wezfurlong.wezterm` for reliable matching
- [ ] Handle the async nature of `os.execute()` appropriately

**Timing**: 20 minutes

**Files to modify**:
- `config/wezterm.lua` - Add GNOME focus function

**Code changes**:

Add after `detect_compositor()`:
```lua
-- Focus WezTerm window via GNOME Shell extension D-Bus interface
-- Uses activate-window-by-title extension to bypass Wayland focus-stealing prevention
local function focus_wezterm_window_gnome()
  local cmd = [[gdbus call --session ]] ..
    [[--dest org.gnome.Shell ]] ..
    [[--object-path /de/lucaswerkmeister/ActivateWindowByTitle ]] ..
    [[--method de.lucaswerkmeister.ActivateWindowByTitle.activateByWmClass ]] ..
    [['org.wezfurlong.wezterm' 2>/dev/null]]
  os.execute(cmd)
end
```

**Verification**:
- Test function manually from WezTerm debug console if available
- Verify gdbus command works from shell

---

### Phase 4: Modify activate_global_tab to Use GNOME Fallback [NOT STARTED]

**Goal**: Update the `activate_global_tab()` function to use the GNOME focus fallback when the standard `gui_win:focus()` fails or when running on GNOME.

**Tasks**:
- [ ] Replace direct `target.window:gui_window()` with `wezterm.gui.gui_window_for_mux_window()`
- [ ] Add compositor detection and GNOME fallback after the standard focus attempt
- [ ] Only call GNOME focus when navigating to a different window

**Timing**: 25 minutes

**Files to modify**:
- `config/wezterm.lua` - Modify `activate_global_tab()` function (lines 226-261)

**Code changes**:

Replace lines 252-259 in `activate_global_tab()`:
```lua
    -- Activate the target tab
    target.tab:activate()

    -- Check if we're navigating to a different window
    local current_window_id = window:mux_window():window_id()
    local target_window_id = target.window:window_id()

    if current_window_id == target_window_id then
      -- Same window, no focus change needed
      return
    end

    -- Try WezTerm's native focus first (works on X11, may work if xdg-activation implemented)
    local gui_win = wezterm.gui.gui_window_for_mux_window(target_window_id)
    if gui_win then
      gui_win:focus()
    end

    -- Fallback to compositor-specific focus for cross-window navigation
    local compositor = detect_compositor()
    if compositor == "gnome" then
      -- Use GNOME Shell extension to focus the window
      focus_wezterm_window_gnome()
    end
```

**Verification**:
- Open two WezTerm windows with tabs in each
- Use Ctrl+Space + number to navigate to a tab in the other window
- Verify window focus changes correctly

---

### Phase 5: Testing and Verification [NOT STARTED]

**Goal**: Comprehensive testing of cross-window tab navigation on GNOME session.

**Tasks**:
- [ ] Rebuild NixOS configuration: `sudo nixos-rebuild switch --flake .`
- [ ] Log out and log back in to ensure GNOME extension is loaded
- [ ] Open 2-3 WezTerm windows with multiple tabs
- [ ] Test Ctrl+Space + 1-9 to navigate between tabs across windows
- [ ] Verify tab activation works correctly
- [ ] Verify window focus switches to the window containing the target tab
- [ ] Test edge cases: single window, no tabs at position N

**Timing**: 30 minutes

**Verification**:
- All numbered tab shortcuts (1-9) navigate correctly
- Window focus changes when navigating to tabs in different windows
- No errors in WezTerm logs (check `~/.local/share/wezterm/wezterm-gui.log`)
- Extension is visible and enabled in GNOME Extensions app

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `nixos-rebuild switch --flake .` completes successfully
- [ ] GNOME extension appears in Extensions app as enabled
- [ ] Manual gdbus command focuses WezTerm window
- [ ] Ctrl+Space + N navigates to correct tab in same window
- [ ] Ctrl+Space + N navigates to correct tab in different window (focuses window)
- [ ] No WezTerm error logs during navigation

## Artifacts & Outputs

- `home.nix` - Modified with GNOME extension package and dconf settings
- `config/wezterm.lua` - Modified with compositor detection and GNOME focus fallback
- `specs/34_fix_wezterm_ctrl_space_cross_window_tab_navigation/plans/implementation-001.md` - This plan
- `specs/34_fix_wezterm_ctrl_space_cross_window_tab_navigation/summaries/implementation-summary-YYYYMMDD.md` - To be created on completion

## Rollback/Contingency

If the implementation causes issues:

1. **WezTerm config rollback**: Restore `config/wezterm.lua` from git:
   ```bash
   git checkout HEAD -- config/wezterm.lua
   ```

2. **Home Manager rollback**: Remove the GNOME extension from `home.nix` and rebuild:
   ```bash
   git checkout HEAD -- home.nix
   sudo nixos-rebuild switch --flake .
   ```

3. **Partial rollback**: If only the WezTerm changes cause issues, the GNOME extension can remain installed and disabled.
