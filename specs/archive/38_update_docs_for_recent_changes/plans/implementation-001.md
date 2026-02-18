# Implementation Plan: Update Documentation for Recent Changes

- **Task**: 38 - update_docs_for_recent_changes
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/38_update_docs_for_recent_changes/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Update four documentation files to reflect configuration changes made in tasks 33-37 over the past week. The research phase identified 12 specific discrepancies: one stale value in gnome-settings.md, one missing section in terminal.md, one missing section in packages.md, and multiple outdated/missing elements in niri.md (including an obsolete "Future" section that is now current reality).

### Research Integration

Research report research-001.md identified exact line numbers and replacement text for all discrepancies. The implementation phases follow the research recommendations, organized by file for efficiency.

## Goals & Non-Goals

**Goals**:
- Update docs/gnome-settings.md with correct AC sleep timeout (3600s)
- Add global cross-window tab navigation section to docs/terminal.md
- Add Wayland/Niri tools section to docs/packages.md
- Update docs/niri.md with current Waybar configuration and rename "Future" section to "Current"

**Non-Goals**:
- Restructuring documentation beyond the identified discrepancies
- Auto-generating documentation from source files
- Adding new documentation for features not mentioned in research

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Waybar config in niri.md may drift again | M | M | Note in commit that manual sync may be needed |
| Line numbers may have shifted since research | L | L | Verify line numbers before editing |
| Missing additional undocumented changes | M | L | Research was comprehensive; accept scope limitation |

## Implementation Phases

### Phase 1: Update docs/gnome-settings.md [COMPLETED]

**Goal**: Fix stale AC sleep timeout value from 900s to 3600s.

**Tasks**:
- [ ] Edit line 22 to change `900 seconds (15 minutes)` to `3600 seconds (60 minutes)`

**Timing**: 5 minutes

**Files to modify**:
- `docs/gnome-settings.md` - Line 22: Update AC sleep timeout value

**Verification**:
- Read the file and confirm line 22 shows `3600 seconds (60 minutes)`

---

### Phase 2: Update docs/terminal.md [COMPLETED]

**Goal**: Add documentation for global cross-window tab navigation feature (Ctrl+Space + 1-9).

**Tasks**:
- [ ] Insert new section "### Global Cross-Window Tab Navigation" after line 66 (after "Leader + p: Previous tab")
- [ ] Include key bindings table (Leader + 1-9)
- [ ] Explain how global tab numbering works across windows
- [ ] Note the GNOME extension dependency for cross-window focus

**Timing**: 15 minutes

**Files to modify**:
- `docs/terminal.md` - Insert new section after line 66

**New section content**:
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

**Verification**:
- Read docs/terminal.md and confirm new section appears after line 66
- Verify section includes keybinding table and explanation

---

### Phase 3: Update docs/packages.md [COMPLETED]

**Goal**: Add documentation for 7 new Wayland/Niri packages added in task 36.

**Tasks**:
- [ ] Add new section "### Wayland/Niri Tools" after the Email Testing section (around line 229)
- [ ] Document all 7 packages: satty, grim, slurp, xwayland-satellite, fuzzel, wdisplays, power-profiles-daemon

**Timing**: 15 minutes

**Files to modify**:
- `docs/packages.md` - Insert new section before "## Package Testing" section

**New section content**:
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

**Verification**:
- Read docs/packages.md and confirm new section appears before "## Package Testing"
- Verify all 7 packages are documented

---

### Phase 4: Update docs/niri.md [COMPLETED]

**Goal**: Update Waybar configuration documentation and rename "Future" section to reflect current active status.

**Tasks**:
- [ ] Update section title from "Future: GNOME + Niri Hybrid (When Ready)" to "Current: GNOME + Niri Hybrid (Active)" at line 830
- [ ] Update modules-right in example config at line 854 to match actual: `["idle_inhibitor" "tray" "bluetooth" "pulseaudio" "network" "battery"]`
- [ ] Add bluetooth module documentation to the Waybar config example
- [ ] Add idle_inhibitor module documentation to the Waybar config example
- [ ] Add workspace format-icons configuration to the example
- [ ] Add clock tooltip-format configuration to the example
- [ ] Add battery charging/plugged formats to the example
- [ ] Remove or update instructions about uncommenting configuration (lines 832-838)

**Timing**: 45 minutes

**Files to modify**:
- `docs/niri.md` - Lines 830-862: Update section title and Waybar configuration

**Detailed edits**:

1. Line 830: Change `#### Future: GNOME + Niri Hybrid (When Ready)` to `#### Current: GNOME + Niri Hybrid (Active)`

2. Lines 832-838: Replace the "uncomment" instructions with a note that Niri is now active:
```markdown
Niri is now enabled and configured as an alternative session alongside GNOME. The following configuration is active in the current system.
```

3. Lines 847-862: Replace the simplified Waybar example with the current comprehensive config:
```nix
programs.waybar = {
  enable = true;
  settings = {
    mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      modules-left = ["niri/workspaces" "niri/window"];
      modules-center = ["clock"];
      modules-right = ["idle_inhibitor" "tray" "bluetooth" "pulseaudio" "network" "battery"];

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

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d %H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

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

      bluetooth = {
        format = " {status}";
        format-connected = " {device_alias}";
        format-disabled = "";
        tooltip-format = "{controller_alias}\t{controller_address}";
        on-click = "gnome-control-center bluetooth";
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "";
          deactivated = "";
        };
        tooltip-format-activated = "Idle inhibitor: ON";
        tooltip-format-deactivated = "Idle inhibitor: OFF";
      };

      # Click to open GNOME Settings
      network.on-click = "gnome-control-center wifi";
      pulseaudio.on-click = "gnome-control-center sound";
      battery.on-click = "gnome-control-center power";
    };
  };
};
```

**Verification**:
- Read docs/niri.md lines 830-900 and confirm section title is "Current"
- Verify Waybar config includes bluetooth, idle_inhibitor, and other new modules
- Verify modules-right matches actual configuration

---

## Testing & Validation

- [ ] Read each modified file to confirm changes applied correctly
- [ ] Verify no markdown syntax errors introduced
- [ ] Confirm all line numbers in research report were accurate (adjust if needed during implementation)
- [ ] Check that new sections integrate well with surrounding content

## Artifacts & Outputs

- `specs/38_update_docs_for_recent_changes/plans/implementation-001.md` (this file)
- `specs/38_update_docs_for_recent_changes/summaries/implementation-summary-20260217.md` (after completion)

**Modified files**:
- `docs/gnome-settings.md`
- `docs/terminal.md`
- `docs/packages.md`
- `docs/niri.md`

## Rollback/Contingency

All changes are to documentation files only. If changes are incorrect:
1. Use `git diff docs/` to review changes
2. Use `git checkout docs/<file>` to revert specific files
3. Or use `git checkout HEAD~1 -- docs/` to revert all documentation changes

No system configuration files are modified, so there is no risk of breaking the system.
