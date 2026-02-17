# Research Report: Task #36

**Task**: 36 - review_niri_nixos_upgrades
**Started**: 2026-02-17T00:00:00Z
**Completed**: 2026-02-17T01:00:00Z
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**: NixOS Wiki, Niri Wiki, niri-flake docs, Arch Wiki, community configurations
**Artifacts**: - specs/36_review_niri_nixos_upgrades/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Current Niri setup is well-configured with GNOME service integration and XDG portal compatibility
- Major upgrade opportunities exist: floating windows (25.01+), xwayland-satellite auto-integration (25.08+), Alt-Tab switcher (25.11+), kanshi/wdisplays support (25.11+)
- Configuration enhancements available: prefer-no-csd, shadows, rounded corners, better window rules
- GNOME compatibility is already excellent; dual-session setup works well
- Recommended: Add xwayland-satellite, kanshi, enhanced window rules, and visual polish

## Context & Scope

This research reviews the current Niri configuration in the dotfiles repository to identify natural upgrades and best practices. The goal is to enhance the Niri experience while maintaining full GNOME Desktop compatibility for a gradual transition.

### Current Setup Summary

**System Configuration (configuration.nix)**:
- `programs.niri.enable = true` with `pkgs.niri` package
- Full XDG portal configuration with GNOME portals (FileChooser, Screenshot, Screencast, Settings)
- GNOME services enabled (gnome-settings-daemon, gnome-keyring, gnome-online-accounts, evolution-data-server)
- GDM display manager with Wayland enabled
- Dual session available: GNOME or Niri at login

**Flake Configuration (flake.nix)**:
- Niri input from `github:YaLTeR/niri` following nixpkgs
- `niri = pkgs-unstable.niri` in overlay for latest features

**Home Manager (home.nix)**:
- Waybar configured with niri/workspaces, niri/window modules
- Mako notification daemon enabled
- Swaylock screen lock configured
- cliphist clipboard history in packages

**Niri Config (config/config.kdl)**:
- Nord color scheme for focus ring and borders
- Vim-style keybindings (h/j/k/l navigation)
- 9 named workspaces
- Auto-start: swaybg, kitty, cliphist, swayidle
- Window rules for Firefox PiP and pavucontrol
- Basic audio/media controls

## Findings

### 1. Niri Version Features Analysis

Based on the [Niri releases](https://github.com/niri-wm/niri/releases), recent versions have added significant features:

| Version | Key Features | Current Status |
|---------|--------------|----------------|
| 25.01 | **Floating windows**, toggle-window-floating, switch-focus-between-floating-and-tiling | Not configured |
| 25.05 | Improved screencasting, windowed fullscreen, enhanced screenshot UI | Available |
| 25.08 | **xwayland-satellite auto-integration**, screen reader support, modal exit confirmation | Not configured |
| 25.11 | **Alt-Tab window switcher**, animated fullscreen transitions, **wlr-output-management (kanshi/wdisplays)**, true maximize | Not configured |

**Recommendation**: Ensure nixpkgs-unstable has 25.11+ for all features.

### 2. Missing Essential Components

#### xwayland-satellite (Priority: High)

Per the [Niri Xwayland wiki](https://github.com/niri-wm/niri/wiki/Xwayland), xwayland-satellite is highly recommended for X11 app compatibility. Since 25.08, Niri auto-integrates it when detected.

**Current**: Not installed
**Fix**:
```nix
# configuration.nix
environment.systemPackages = with pkgs; [
  xwayland-satellite  # X11 compatibility for Niri
];
```

**Note**: Remove any manual DISPLAY setting or xwayland-satellite spawn from config.kdl if present.

#### kanshi (Priority: Medium)

The [wlr-output-management protocol](https://discourse.nixos.org/t/how-to-install-niri/63975) support in 25.11 enables kanshi and wdisplays for dynamic monitor configuration.

**Current**: Not configured
**Fix** (home.nix):
```nix
services.kanshi = {
  enable = true;
  systemdTarget = "niri.service";  # For Niri session
  settings = [
    {
      profile.name = "undocked";
      profile.outputs = [
        { criteria = "eDP-1"; status = "enable"; }
      ];
    }
    # Add docked profiles as needed
  ];
};
```

### 3. Configuration Enhancements

#### Floating Windows (25.01+)

Per the [Floating Windows wiki](https://github.com/niri-wm/niri/wiki/Floating-Windows), add to config.kdl:

```kdl
binds {
    // Floating window controls
    Mod+Shift+v { switch-focus-between-floating-and-tiling }
    Mod+w { toggle-window-floating }  // Changed from v to avoid conflict
}
```

#### prefer-no-csd and Shadows

Per the [Configuration: Layout wiki](https://github.com/niri-wm/niri/wiki/Configuration:-Layout), add visual polish:

```kdl
prefer-no-csd

layout {
    // Existing focus-ring and border settings...

    shadow {
        on
        softness 30
        spread 5
        offset { x 0 y 5 }
        color "rgba(0, 0, 0, 0.5)"
    }
}

// Global corner radius for windows
window-rule {
    geometry-corner-radius 8
    clip-to-geometry true
}
```

#### Enhanced Window Rules

Per the [Window Rules wiki](https://github.com/niri-wm/niri/wiki/Configuration:-Window-Rules), add common application rules:

```kdl
// WezTerm fix for initial window size
window-rule {
    match app-id=r#"^org\.wezfurlong\.wezterm$"#
    default-column-width {}
}

// Steam notifications position
window-rule {
    match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
    default-floating-position x=10 y=10 relative-to="bottom-right"
}

// GNOME apps with proper corner radius (GTK3)
window-rule {
    match app-id="^gnome-"
    geometry-corner-radius 8 8 0 0
}

// Zotero (floating dialogs)
window-rule {
    match app-id="^Zotero$" title="^Quick Format Citation$"
    open-floating true
}
```

### 4. Waybar Configuration Improvements

Current configuration is basic. Consider enhancing per [Waybar Niri guide](https://gist.github.com/nalakawula/c888bf832277d008cee11cacbe92d0db):

```nix
programs.waybar.settings.mainBar = {
  layer = "top";  # Important for visibility in Niri
  position = "top";
  height = 32;
  modules-left = ["niri/workspaces" "niri/window"];
  modules-center = ["clock"];
  modules-right = ["idle_inhibitor" "pulseaudio" "network" "bluetooth" "battery" "tray"];

  "niri/workspaces" = {
    format = "{icon}";
    format-icons = {
      "1:web" = "";
      "2:code" = "";
      "3:term" = "";
      "4:docs" = "";
      "5:media" = "";
      "6:chat" = "";
      default = "";
    };
  };

  idle_inhibitor = {
    format = "{icon}";
    format-icons = {
      activated = "";
      deactivated = "";
    };
  };

  bluetooth = {
    format = " {status}";
    on-click = "gnome-control-center bluetooth";
  };
};
```

### 5. Screenshot Configuration

Niri has a built-in screenshot UI, but for annotation consider adding satty or swappy:

```nix
# home.nix packages
home.packages = with pkgs; [
  satty  # Screenshot annotation tool
  grim   # Screenshot utility
  slurp  # Area selection
];
```

```kdl
// config.kdl - Custom screenshot with annotation
Mod+Shift+a { spawn "sh" "-c" "grim -g \"$(slurp)\" - | satty -f -" }
```

### 6. niri-flake Consideration

The [niri-flake](https://github.com/sodiboo/niri-flake) provides:
- Declarative Nix-native configuration via `programs.niri.settings`
- Build-time config validation
- Automatic Home Manager integration
- Binary cache for faster builds

**Current approach**: Using nixpkgs niri + manual config.kdl (simpler, works well)
**Alternative**: niri-flake for Nix-native config (more complex, better validation)

**Recommendation**: Stay with current approach unless Nix-native config is desired.

### 7. GNOME Compatibility Status

Current setup is excellent for dual-session compatibility:

| Component | Status | Notes |
|-----------|--------|-------|
| XDG Portals | Configured | GNOME portals for File Chooser, Screenshot, Screencast |
| gnome-settings-daemon | Enabled | Theme, dark mode, keyboard settings |
| gnome-keyring | Enabled | Password storage |
| gnome-control-center | Available | WiFi, Bluetooth, Sound accessible |
| Screen sharing | Working | Via GNOME portal |
| File chooser | Working | Uses Nautilus |
| Dark mode | Working | Via dconf/gsettings |

**No changes needed** for GNOME compatibility.

### 8. Additional Services to Consider

#### fuzzel (Application Launcher)

Already referenced in config.kdl but may not be installed system-wide:

```nix
# configuration.nix or home.nix
environment.systemPackages = with pkgs; [ fuzzel ];
```

#### Power Profiles Daemon

For Waybar power-profiles-daemon module:

```nix
services.power-profiles-daemon.enable = true;
```

## Recommendations

### Phase 1: Essential Upgrades (Immediate)

1. **Add xwayland-satellite** to environment.systemPackages
2. **Add floating window keybindings** to config.kdl
3. **Fix WezTerm window rule** for proper initial sizing
4. **Enable prefer-no-csd** for consistent window appearance

### Phase 2: Visual Polish (Short-term)

1. **Enable shadows** in layout configuration
2. **Add geometry-corner-radius** window rule
3. **Enhance Waybar** with icons and additional modules
4. **Add satty/grim/slurp** for screenshot annotation

### Phase 3: Monitor Management (When Needed)

1. **Enable services.kanshi** in Home Manager
2. Configure profiles for docked/undocked modes
3. Consider wdisplays for GUI configuration

### Phase 4: Optional Enhancements

1. Consider niri-flake for Nix-native configuration
2. Add custom window rules for frequently used apps
3. Explore additional Waybar customization

## Decisions

1. **Keep current approach** (nixpkgs niri + config.kdl) over niri-flake for simplicity
2. **Prioritize xwayland-satellite** as it's most impactful for app compatibility
3. **Maintain GNOME services** for dual-session compatibility (already well-configured)
4. **Gradual enhancement** rather than complete rewrite of config.kdl

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Config.kdl syntax errors | Low | High (session won't start) | Use `niri validate` before applying |
| xwayland-satellite conflicts | Low | Medium | Remove any manual DISPLAY settings |
| Waybar visibility issues | Low | Low | Ensure `layer = "top"` is set |
| kanshi conflicts with GNOME | Low | Medium | Set systemdTarget to niri-specific target |

## Appendix

### Search Queries Used
- "Niri NixOS configuration best practices 2025 2026"
- "niri-flake sodiboo NixOS home-manager configuration settings 2025"
- "Niri wayland compositor companion applications waybar mako fuzzel NixOS"
- "Niri GNOME compatibility dual session XDG portal configuration"
- "Niri 0.2 0.3 2025 new features changelog improvements"
- "xwayland-satellite NixOS niri configuration 2025"
- "niri waybar configuration best settings modules 2025"
- "niri floating windows toggle resize 25.01 configuration"
- "niri kanshi wdisplays output management NixOS configuration"
- "niri prefer-no-csd client-side-decorations window borders shadow configuration"
- "niri screenshot picker UI grimshot grim slurp 2025 configuration"
- "niri window rules app-id examples configuration common applications"

### Key References

- [NixOS Wiki - Niri](https://wiki.nixos.org/wiki/Niri)
- [niri-flake GitHub](https://github.com/sodiboo/niri-flake)
- [Niri Wiki - Getting Started](https://github.com/niri-wm/niri/wiki/Getting-Started)
- [Niri Wiki - Configuration Layout](https://github.com/niri-wm/niri/wiki/Configuration:-Layout)
- [Niri Wiki - Window Rules](https://github.com/niri-wm/niri/wiki/Configuration:-Window-Rules)
- [Niri Wiki - Floating Windows](https://github.com/niri-wm/niri/wiki/Floating-Windows)
- [Niri Wiki - Xwayland](https://github.com/niri-wm/niri/wiki/Xwayland)
- [Niri Releases](https://github.com/niri-wm/niri/releases)
- [Arch Wiki - Niri](https://wiki.archlinux.org/title/Niri)
- [Home Manager - services.kanshi](https://mynixos.com/home-manager/options/services.kanshi)
