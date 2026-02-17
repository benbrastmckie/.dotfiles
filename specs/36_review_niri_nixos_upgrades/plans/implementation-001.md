# Implementation Plan: Task #36

- **Task**: 36 - review_niri_nixos_upgrades
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/36_review_niri_nixos_upgrades/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Implement Niri compositor upgrades for NixOS to enable floating windows, X11 app compatibility via xwayland-satellite, visual polish (shadows, rounded corners, prefer-no-csd), and enhanced Waybar configuration. All changes maintain full GNOME Desktop compatibility for dual-session operation during the transition period.

### Research Integration

Research report (research-001.md) identified:
- Current setup is well-configured with GNOME service integration already in place
- Key missing components: xwayland-satellite, kanshi, floating window keybindings
- Visual enhancements available: shadows, rounded corners, prefer-no-csd
- Waybar can be enhanced with additional modules and icons
- GNOME compatibility requires no changes (already excellent)

## Goals & Non-Goals

**Goals**:
- Add xwayland-satellite for X11 application compatibility
- Enable floating window support with keybindings
- Add visual polish (shadows, rounded corners, prefer-no-csd)
- Enhance Waybar configuration with better modules
- Add screenshot annotation tools (satty, grim, slurp)
- Configure kanshi for dynamic monitor management
- Maintain full GNOME Desktop compatibility

**Non-Goals**:
- Migrate to niri-flake declarative configuration (keeping current nixpkgs + config.kdl approach)
- Remove any GNOME services or packages
- Complete the GNOME to Niri transition

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| config.kdl syntax errors | High (session won't start) | Low | Use `niri validate` before applying |
| xwayland-satellite conflicts | Medium | Low | Remove any manual DISPLAY settings in config.kdl |
| Waybar visibility issues | Low | Low | Ensure `layer = "top"` is set |
| kanshi conflicts with GNOME | Medium | Low | Set systemdTarget to niri-specific target |

## Implementation Phases

### Phase 1: Essential Upgrades [NOT STARTED]

**Goal**: Add xwayland-satellite for X11 compatibility and enable floating window keybindings

**Tasks**:
- [ ] Add xwayland-satellite to environment.systemPackages in configuration.nix
- [ ] Verify fuzzel is installed (referenced in config.kdl but may not be system-wide)
- [ ] Add floating window keybindings to config/config.kdl (toggle-window-floating, switch-focus-between-floating-and-tiling)
- [ ] Add WezTerm window rule for proper initial sizing
- [ ] Enable prefer-no-csd for consistent window appearance
- [ ] Run `niri validate` on config.kdl to verify syntax

**Timing**: 45 minutes

**Files to modify**:
- `configuration.nix` - Add xwayland-satellite and fuzzel packages
- `config/config.kdl` - Add floating window keybindings, prefer-no-csd, WezTerm rule

**Verification**:
- `nix flake check` passes
- `niri validate` passes on config.kdl
- xwayland-satellite appears in system packages

---

### Phase 2: Visual Polish [NOT STARTED]

**Goal**: Add shadows, rounded corners, and visual enhancements to Niri configuration

**Tasks**:
- [ ] Add shadow configuration to layout section in config.kdl
- [ ] Add geometry-corner-radius window rule for rounded corners
- [ ] Add GNOME apps corner radius adjustment (GTK3 apps need different values)
- [ ] Add Steam notification positioning rule
- [ ] Add Zotero floating dialog rule
- [ ] Validate config.kdl syntax

**Timing**: 30 minutes

**Files to modify**:
- `config/config.kdl` - Add shadow config, corner radius rules, app-specific rules

**Verification**:
- `niri validate` passes on config.kdl
- Visual inspection after rebuild (shadows, corners visible)

---

### Phase 3: Waybar and Screenshot Enhancements [NOT STARTED]

**Goal**: Enhance Waybar with additional modules and add screenshot annotation tools

**Tasks**:
- [ ] Add satty, grim, slurp to home.packages in home.nix
- [ ] Add custom screenshot keybinding with annotation pipeline to config.kdl
- [ ] Enhance Waybar niri/workspaces with format icons
- [ ] Add idle_inhibitor module to Waybar
- [ ] Add bluetooth module to Waybar (links to gnome-control-center)
- [ ] Ensure layer = "top" is set in Waybar config

**Timing**: 45 minutes

**Files to modify**:
- `home.nix` - Add screenshot packages, enhance Waybar configuration
- `config/config.kdl` - Add screenshot with annotation keybinding

**Verification**:
- `nix flake check` passes
- Waybar shows new modules after rebuild
- Screenshot annotation workflow works (Mod+Shift+a)

---

### Phase 4: Monitor Management [NOT STARTED]

**Goal**: Configure kanshi for dynamic monitor profiles and enable power-profiles-daemon

**Tasks**:
- [ ] Enable services.kanshi in home.nix with niri.service systemdTarget
- [ ] Create basic kanshi profile for undocked mode (eDP-1 only)
- [ ] Add placeholder for docked profile (to be configured when external monitor available)
- [ ] Enable services.power-profiles-daemon in configuration.nix (if not already enabled)
- [ ] Optionally add wdisplays to packages for GUI monitor configuration

**Timing**: 30 minutes

**Files to modify**:
- `home.nix` - Add services.kanshi configuration
- `configuration.nix` - Enable power-profiles-daemon, add wdisplays

**Verification**:
- `nix flake check` passes
- `systemctl --user status kanshi` shows active after Niri session start
- Monitor detection works when docking/undocking

---

### Phase 5: Final Validation [NOT STARTED]

**Goal**: Comprehensive testing and documentation of all changes

**Tasks**:
- [ ] Run `nix flake check` to verify all Nix syntax
- [ ] Run `niri validate` on final config.kdl
- [ ] Build system with `nixos-rebuild build --flake .#<hostname>`
- [ ] Document any configuration notes for future reference
- [ ] Create implementation summary

**Timing**: 30 minutes

**Files to modify**:
- None (validation only)
- `specs/36_review_niri_nixos_upgrades/summaries/implementation-summary-20260217.md` - Create summary

**Verification**:
- Full `nix flake check` passes
- `niri validate` passes
- System builds successfully
- All new features documented

## Testing & Validation

- [ ] `nix flake check` passes with no errors
- [ ] `niri validate` confirms config.kdl syntax is correct
- [ ] `nixos-rebuild build --flake .#<hostname>` completes successfully
- [ ] After applying changes:
  - [ ] Niri session starts correctly via GDM
  - [ ] GNOME session still starts correctly via GDM (compatibility check)
  - [ ] Floating windows work (Mod+w toggles, Mod+Shift+v switches focus)
  - [ ] X11 apps run via xwayland-satellite
  - [ ] Shadows and rounded corners visible
  - [ ] Waybar displays all configured modules
  - [ ] Screenshot with annotation works
  - [ ] kanshi manages monitor profiles

## Artifacts & Outputs

- `plans/implementation-001.md` (this file)
- `summaries/implementation-summary-20260217.md` (created in Phase 5)

## Rollback/Contingency

If configuration causes session startup failures:
1. Switch to GNOME session at GDM login screen
2. Revert config.kdl changes: `git checkout config/config.kdl`
3. Revert NixOS changes: `sudo nixos-rebuild switch --flake .#<hostname> --rollback`

For partial issues:
- Individual features can be disabled by commenting out relevant sections
- kanshi can be disabled: `services.kanshi.enable = false`
- prefer-no-csd can be removed if causing issues with specific apps
