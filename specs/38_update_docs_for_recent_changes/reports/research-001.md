# Research Report: Task #38

**Task**: 38 - update_docs_for_recent_changes
**Started**: 2026-02-17T00:00:00Z
**Completed**: 2026-02-17T00:15:00Z
**Effort**: Low (documentation updates only)
**Dependencies**: None
**Sources/Inputs**:
- `docs/gnome-settings.md`
- `docs/niri.md`
- `docs/terminal.md`
- `docs/packages.md`
- `home.nix` (current configuration)
- `configuration.nix` (current configuration)
- `config/wezterm.lua` (current configuration)
**Artifacts**:
- `specs/38_update_docs_for_recent_changes/reports/research-001.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Found 12 specific documentation discrepancies across 4 files
- `docs/gnome-settings.md` has stale power management timeout (900s should be 3600s for AC)
- `docs/niri.md` has outdated Waybar configuration and an obsolete "Future" section that is now current reality
- `docs/terminal.md` is missing global cross-window tab navigation feature (Ctrl+Space + number)
- `docs/packages.md` is missing 7 new packages added in task 36

## Context & Scope

This research audits current documentation files against implementation changes made in tasks 33-37 over the past week. The focus is on identifying specific text that needs updating with exact line numbers and replacement text.

## Findings

### 1. docs/gnome-settings.md - Power Management Section

**Location**: Lines 20-23

**Current Documentation (STALE)**:
```markdown
### Power Management
- **Idle delay**: 300 seconds (5 minutes) - screen dims/blanks
- **Sleep timeout (AC)**: 900 seconds (15 minutes)
- **Sleep timeout (Battery)**: 900 seconds (15 minutes)
```

**Actual Configuration** (home.nix lines 57-60):
```nix
"org/gnome/settings-daemon/plugins/power" = {
  sleep-inactive-ac-timeout = 3600;     # 60 minutes on AC power
  sleep-inactive-battery-timeout = 900; # 15 minutes on battery
  idle-dim = true;                      # Dim screen before blanking
};
```

**Required Update**:
```markdown
### Power Management
- **Idle delay**: 300 seconds (5 minutes) - screen dims/blanks
- **Sleep timeout (AC)**: 3600 seconds (60 minutes)
- **Sleep timeout (Battery)**: 900 seconds (15 minutes)
```

---

### 2. docs/niri.md - Waybar Configuration Section

The documentation at lines 841-862 shows an outdated Waybar configuration. The actual configuration (home.nix lines 1042-1131) includes several new features.

#### 2a. Missing `bluetooth` module

**Current Documentation**: Does not mention bluetooth module

**Actual Configuration** (home.nix lines 1109-1115):
```nix
bluetooth = {
  format = " {status}";
  format-connected = " {device_alias}";
  format-disabled = "";
  tooltip-format = "{controller_alias}\t{controller_address}";
  on-click = "gnome-control-center bluetooth";
};
```

#### 2b. Missing `idle_inhibitor` module

**Current Documentation**: Does not mention idle_inhibitor module

**Actual Configuration** (home.nix lines 1117-1125):
```nix
idle_inhibitor = {
  format = "{icon}";
  format-icons = {
    activated = "";
    deactivated = "";
  };
  tooltip-format-activated = "Idle inhibitor: ON";
  tooltip-format-deactivated = "Idle inhibitor: OFF";
};
```

#### 2c. Workspace format changed to format-icons

**Documentation shows** (line 852-854):
```nix
modules-left = ["niri/workspaces" "niri/window"];
```

**Actual Configuration** (home.nix lines 1053-1067):
```nix
"niri/workspaces" = {
  format = "{icon}";
  format-icons = {
    "1:web" = "";
    "2:code" = "";
    "3:term" = "";
    "4:docs" = "";
    "5:media" = "";
    "6:chat" = "";
    "7:misc" = "";
    "8:extra" = "";
    "9:bg" = "";
    default = "";
  };
};
```

#### 2d. Clock now has tooltip with calendar

**Documentation shows** (implied simple clock)

**Actual Configuration** (home.nix lines 1073-1077):
```nix
clock = {
  format = "{:%H:%M}";
  format-alt = "{:%Y-%m-%d %H:%M}";
  tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
};
```

#### 2e. Battery now has charging/plugged formats

**Actual Configuration** (home.nix lines 1079-1088):
```nix
battery = {
  format = "{icon} {capacity}%";
  format-charging = " {capacity}%";
  format-plugged = " {capacity}%";
  format-icons = ["" "" "" "" ""];
  states = {
    warning = 30;
    critical = 15;
  };
};
```

#### 2f. modules-right now includes bluetooth and idle_inhibitor

**Documentation shows** (line 854):
```nix
modules-right = ["tray" "battery" "network" "wireplumber"];
```

**Actual Configuration** (home.nix line 1051):
```nix
modules-right = ["idle_inhibitor" "tray" "bluetooth" "pulseaudio" "network" "battery"];
```

---

### 3. docs/niri.md - "Future: GNOME + Niri Hybrid" Section is Now Current

**Location**: Lines 830-897 (section header at line 830)

The section titled "#### Future: GNOME + Niri Hybrid (When Ready)" is now outdated because:

1. Niri IS the active configuration (programs.niri.enable = true in configuration.nix line 170-173)
2. The dual-session setup is complete and working
3. The section says "Uncomment Niri Configuration" but niri config is NOT commented out

**Required Update**:
- Change section title from "Future: GNOME + Niri Hybrid (When Ready)" to "Current: GNOME + Niri Hybrid (Active)"
- Remove instructions about uncommenting configuration
- Update to reflect that niri is the active session alongside GNOME

---

### 4. docs/terminal.md - Missing Global Tab Navigation

**Location**: After line 66 (after "Leader + p: Previous tab")

**Missing Documentation**: The global cross-window tab navigation feature implemented in tasks 33 and 34 is not documented.

**Actual Configuration** (config/wezterm.lua lines 446-495):
```lua
-- Global tab switching with Ctrl+Space + number (1-9)
-- Navigates to the tab with that global position across ALL windows,
-- not just the nth tab in the current window
{
  key = "1",
  mods = "LEADER",
  action = activate_global_tab(1),
},
-- ... (keys 2-9 follow same pattern)
```

**Required Addition** after line 66:
```markdown
### Global Cross-Window Tab Navigation

Navigate directly to any tab across ALL WezTerm windows using Ctrl+Space followed by a number:

| Key | Action |
|-----|--------|
| **Leader + 1-9** | Jump to global tab 1-9 |

**How it works**:
- Tab numbers are assigned globally in creation order across all windows
- If you have 3 tabs in window A and 2 tabs in window B, tabs are numbered 1-5 globally
- `Leader + 3` will jump to the 3rd oldest tab, regardless of which window it is in
- On GNOME, this also focuses the target window using the `activate-window-by-title` extension

This feature requires the `gnomeExtensions.activate-window-by-title` extension for cross-window focus on Wayland.
```

---

### 5. docs/packages.md - Missing New Packages

**Location**: The file does not have a dedicated section for Wayland/Niri packages. These 7 packages are installed but not documented:

| Package | Source | Purpose | Added In |
|---------|--------|---------|----------|
| `satty` | home.nix line 229 | Screenshot annotation tool | Task 36 |
| `grim` | home.nix line 230 | Wayland screenshot utility | Task 36 |
| `slurp` | home.nix line 231 | Region selection for Wayland | Task 36 |
| `xwayland-satellite` | configuration.nix line 355 | X11 compat for Niri | Task 36 |
| `fuzzel` | configuration.nix line 356 | App launcher for Wayland | Task 36 |
| `wdisplays` | configuration.nix line 357 | Monitor config GUI | Task 36 |
| `power-profiles-daemon` | configuration.nix line 282 | Power management (Waybar integration) | Task 36 |

**Required Addition**: Add a new section "### Wayland/Niri Tools" to docs/packages.md:

```markdown
### Wayland/Niri Tools (configuration.nix, home.nix)

Tools for the Niri Wayland compositor session:

- `xwayland-satellite` - X11 compatibility layer for running X11 applications in Niri
- `fuzzel` - Lightweight application launcher for Wayland (Mod+p in niri)
- `wdisplays` - GUI tool for configuring monitors on wlr-output-management compositors
- `satty` - Screenshot annotation tool with drawing and text capabilities
- `grim` - Minimal Wayland screenshot utility (captures full screen or regions)
- `slurp` - Region selection tool for Wayland (used with grim for area screenshots)
- `power-profiles-daemon` - System service for power profile management (integrated with Waybar)
```

---

## Summary Table of All Discrepancies

| File | Line(s) | Current Text | Should Be |
|------|---------|--------------|-----------|
| gnome-settings.md | 22 | `Sleep timeout (AC): 900 seconds (15 minutes)` | `Sleep timeout (AC): 3600 seconds (60 minutes)` |
| niri.md | 830 | `#### Future: GNOME + Niri Hybrid (When Ready)` | `#### Current: GNOME + Niri Hybrid (Active)` |
| niri.md | 854 | `modules-right = ["tray" "battery" "network" "wireplumber"]` | `modules-right = ["idle_inhibitor" "tray" "bluetooth" "pulseaudio" "network" "battery"]` |
| niri.md | N/A | (missing) | Add bluetooth module documentation |
| niri.md | N/A | (missing) | Add idle_inhibitor module documentation |
| niri.md | N/A | (missing) | Add clock tooltip-format documentation |
| niri.md | N/A | (missing) | Add battery charging/plugged formats |
| niri.md | N/A | (missing) | Add workspace format-icons documentation |
| terminal.md | after 66 | (missing) | Add "Global Cross-Window Tab Navigation" section |
| packages.md | N/A | (missing) | Add "Wayland/Niri Tools" section with 7 packages |

---

## Decisions

1. **gnome-settings.md**: Simple one-line fix for AC timeout value
2. **niri.md**: Requires structural changes to Waybar section and "Future" section rename
3. **terminal.md**: Requires adding new section for global tab navigation
4. **packages.md**: Requires adding new section for Wayland/Niri tools

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Waybar config in niri.md may drift again | Consider auto-generating from home.nix or just referencing the nix file |
| "Future" section rename may confuse users | Add note that this was previously documented as future, now active |
| Package list may become stale | Consider documenting packages closer to their definition in nix files |

## Appendix

### Files Read
- `/home/benjamin/.dotfiles/docs/gnome-settings.md` (217 lines)
- `/home/benjamin/.dotfiles/docs/niri.md` (991 lines)
- `/home/benjamin/.dotfiles/docs/terminal.md` (307 lines)
- `/home/benjamin/.dotfiles/docs/packages.md` (233 lines)
- `/home/benjamin/.dotfiles/home.nix` (1229 lines)
- `/home/benjamin/.dotfiles/configuration.nix` (657 lines)
- `/home/benjamin/.dotfiles/config/wezterm.lua` (566 lines)

### Key Configuration Locations
- Power management: home.nix lines 52-61
- Waybar: home.nix lines 1042-1131
- Niri packages: configuration.nix lines 354-357
- WezTerm global tabs: config/wezterm.lua lines 222-297, 446-495
- Screenshot tools: home.nix lines 228-231
