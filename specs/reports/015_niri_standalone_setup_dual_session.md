# Research Report: Niri Standalone Setup and Dual-Session Configuration

## Metadata
- **Date**: 2025-10-03
- **Scope**: Essential services for standalone niri setup and running niri alongside GNOME
- **Primary Directory**: `/home/benjamin/.dotfiles`
- **Files Analyzed**: `configuration.nix`, `config/config.kdl`, NixOS Wiki, Arch Wiki, web research

## Executive Summary

Running niri as a standalone Wayland compositor without GNOME requires installing approximately 10-15 essential services and utilities to replace GNOME's integrated functionality. These include a status bar (waybar), notification daemon (mako), authentication agent (polkit), network/bluetooth applets, clipboard manager, and various Wayland utilities.

**Good news**: You can run both GNOME and niri side-by-side on the same system and switch between them at login via GDM. This allows for seamless transition testing without commitment.

## Question 1: Essential Services for Standalone Niri

### Core System Services

#### 1. **Authentication & Security**
```nix
# configuration.nix
security.polkit.enable = true;  # Already enabled
services.gnome.gnome-keyring.enable = true;  # Password/secrets storage

# Polkit authentication agent (choose one)
systemd.user.services.polkit-gnome-authentication-agent-1 = {
  description = "polkit-gnome-authentication-agent-1";
  wantedBy = [ "graphical-session.target" ];
  wants = [ "graphical-session.target" ];
  after = [ "graphical-session.target" ];
  serviceConfig = {
    Type = "simple";
    ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    Restart = "on-failure";
    RestartSec = 1;
    TimeoutStopSec = 10;
  };
};
```

**Why needed**: Handles privilege escalation prompts (like sudo GUI dialogs)

#### 2. **Display & Session Management**
```nix
# configuration.nix
programs.xwayland.enable = true;  # Already enabled (X11 app support)
environment.sessionVariables.NIXOS_OZONE_WL = "1";  # Already set

# GDM continues to work for session selection
services.xserver.displayManager.gdm = {
  enable = true;  # Already enabled
  wayland = true;
};
```

#### 3. **XDG Desktop Portals**
```nix
# configuration.nix - already partially configured
xdg.portal = {
  enable = true;
  extraPortals = with pkgs; [
    xdg-desktop-portal-gtk  # File picker, screen sharing
    # Remove xdg-desktop-portal-gnome if dropping GNOME entirely
  ];
  config = {
    niri = {
      default = ["gtk"];  # Use GTK portals instead of GNOME
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      "org.freedesktop.impl.portal.Screenshot" = ["gtk"];
    };
  };
};
```

### Essential User Applications

#### 4. **Status Bar** (Waybar)
```nix
# home.nix
programs.waybar = {
  enable = true;
  settings = {
    mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      modules-left = ["niri/workspaces" "niri/window"];
      modules-center = ["clock"];
      modules-right = ["network" "wireplumber" "bluetooth" "battery" "tray"];

      network = {
        format-wifi = " {essid} ({signalStrength}%)";
        format-ethernet = " {ifname}";
        format-disconnected = "⚠ Disconnected";
        on-click = "nm-connection-editor";
      };

      bluetooth = {
        format = " {status}";
        format-connected = " {device_alias}";
        on-click = "blueman-manager";
      };

      wireplumber = {
        format = "{icon} {volume}%";
        format-muted = " Muted";
        on-click = "pavucontrol";
      };

      battery = {
        format = "{icon} {capacity}%";
        format-icons = ["" "" "" "" ""];
      };
    };
  };
};
```

**Purpose**: Displays system status, workspaces, network, audio, battery, etc.

#### 5. **Notification Daemon** (Mako)
```nix
# home.nix
services.mako = {
  enable = true;
  defaultTimeout = 5000;  # 5 seconds
  backgroundColor = "#2e3440";
  textColor = "#eceff4";
  borderColor = "#5e81ac";
  borderSize = 2;
  icons = true;
  maxIconSize = 64;
};
```

**Purpose**: Desktop notifications (replaces GNOME notifications)

#### 6. **Screen Locking & Idle Management**
```nix
# home.nix
programs.swaylock = {
  enable = true;
  settings = {
    color = "2e3440";
    font-size = 24;
    indicator-idle-visible = false;
    indicator-radius = 100;
    line-color = "5e81ac";
  };
};

services.swayidle = {
  enable = true;
  events = [
    { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
    { event = "lock"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
  ];
  timeouts = [
    { timeout = 300; command = "${pkgs.swaylock}/bin/swaylock -f"; }
    { timeout = 600; command = "${pkgs.systemd}/bin/systemctl suspend"; }
  ];
};

# Also add to configuration.nix
security.pam.services.swaylock = {};
```

**Purpose**: Lock screen and auto-suspend on idle

#### 7. **Network Management**
```nix
# configuration.nix - already enabled
networking.networkmanager.enable = true;

# Add to environment.systemPackages
environment.systemPackages = with pkgs; [
  networkmanagerapplet  # nm-applet for tray icon
  # ... other packages
];

# Auto-start in config.kdl
spawn-at-startup "nm-applet --indicator"
```

**Purpose**: WiFi/ethernet management with system tray icon

#### 8. **Bluetooth Management**
```nix
# configuration.nix - check if already enabled
hardware.bluetooth.enable = true;
services.blueman.enable = true;

# Add to environment.systemPackages
environment.systemPackages = with pkgs; [
  blueman  # Bluetooth manager with GUI
  # ... other packages
];

# Auto-start in config.kdl
spawn-at-startup "blueman-applet"
```

**Purpose**: Bluetooth device pairing and management

**Note**: Blueman has some Wayland compatibility quirks but generally works

#### 9. **Audio Control**
```nix
# configuration.nix - PipeWire already configured
# Just add GUI mixer to packages
environment.systemPackages = with pkgs; [
  pavucontrol  # PulseAudio/PipeWire volume control
  # ... other packages
];
```

**Purpose**: Advanced audio control (click waybar audio icon to open)

#### 10. **Clipboard Manager**
```nix
# home.nix
services.clipman = {
  enable = true;
  systemdTarget = "graphical-session.target";
};

# Or use alternative
# environment.systemPackages = [ pkgs.wl-clipboard-x11 pkgs.cliphist ];
# spawn-at-startup "wl-paste -t text --watch cliphist store"
```

**Purpose**: Clipboard history and management

#### 11. **Application Launcher**
```nix
# home.nix
programs.fuzzel = {
  enable = true;
  settings = {
    main = {
      terminal = "${pkgs.kitty}/bin/kitty";
      font = "monospace:size=12";
      dpi-aware = "yes";
    };
    colors = {
      background = "2e3440dd";
      text = "eceff4ff";
      match = "88c0d0ff";
      selection = "5e81acff";
      selection-text = "eceff4ff";
    };
  };
};
```

**Already configured** in your `config.kdl` with `Mod+p`

#### 12. **Wallpaper**
```nix
# Already configured via spawn-at-startup
# spawn-at-startup "swaybg -i ~/.wallpapers/current -m fill"
```

**Purpose**: Static wallpaper (swaybg already installed)

#### 13. **Output/Monitor Management** (Optional)
```nix
# home.nix
services.kanshi = {
  enable = true;
  profiles = {
    laptop = {
      outputs = [
        {
          criteria = "eDP-1";
          status = "enable";
        }
      ];
    };
    docked = {
      outputs = [
        {
          criteria = "eDP-1";
          status = "disable";
        }
        {
          criteria = "HDMI-A-1";
          status = "enable";
        }
      ];
    };
  };
};
```

**Purpose**: Automatic display configuration (laptop/docked profiles)

### Complete Package List Summary

**System Packages** (configuration.nix):
```nix
environment.systemPackages = with pkgs; [
  # Already installed
  gnome-control-center  # Can still use GNOME Settings if desired
  nautilus              # File manager
  wl-clipboard
  xdg-utils
  swaybg

  # NEW - Essential for standalone niri
  networkmanagerapplet  # nm-applet
  blueman               # Bluetooth manager
  pavucontrol           # Audio mixer
  polkit_gnome          # Authentication agent (or lxqt.lxqt-policykit)

  # NEW - Optional but recommended
  grim                  # Screenshot utility
  slurp                 # Area selection for screenshots
  wl-clipboard-x11      # X11 clipboard compatibility

  # Already have these
  fuzzel                # App launcher
  kitty                 # Terminal
];
```

**Home Manager Services** (home.nix):
```nix
programs.waybar.enable = true;
services.mako.enable = true;
programs.swaylock.enable = true;
services.swayidle.enable = true;
services.clipman.enable = true;
programs.fuzzel.enable = true;
services.kanshi.enable = true;  # Optional
```

**Auto-start in config.kdl**:
```kdl
spawn-at-startup "swaybg -i ~/.wallpapers/current -m fill"
spawn-at-startup "waybar"
spawn-at-startup "mako"
spawn-at-startup "nm-applet --indicator"
spawn-at-startup "blueman-applet"
spawn-at-startup "kitty"
```

### What You Can Remove (If Dropping GNOME Entirely)

**Services to disable** in `configuration.nix`:
```nix
# Remove or comment out:
services.gnome = {
  gnome-settings-daemon.enable = false;  # No longer needed
  gnome-online-accounts.enable = false;  # Unless you use it
  evolution-data-server.enable = false;  # Calendar/contacts
  gnome-remote-desktop.enable = false;
  # Keep gnome-keyring.enable = true; (for password storage)
};

# Change portal to GTK only
xdg.portal.extraPortals = with pkgs; [
  xdg-desktop-portal-gtk  # Keep this
  # Remove: xdg-desktop-portal-gnome
];
```

**Packages to remove**:
```nix
# Can remove from systemPackages if not using GNOME:
# gnome-control-center  # Unless you still want it
# nautilus - replace with: nemo, thunar, or pcmanfm-qt
```

## Question 2: Running Both GNOME and Niri Side-by-Side

### Yes, You Can Run Both!

**GDM (GNOME Display Manager) already supports multiple sessions**. You can keep both GNOME and niri installed and choose which to use at login.

### Configuration for Dual Sessions

#### Step 1: Keep Current GNOME Setup
```nix
# configuration.nix - Keep these enabled
services.xserver = {
  enable = true;
  displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  desktopManager.gnome.enable = true;  # Keep GNOME
};
```

#### Step 2: Re-enable Niri Configuration
```nix
# configuration.nix - Uncomment niri setup
programs.niri = {
  enable = true;
  package = pkgs.niri;
};

services.displayManager.sessionPackages = [ pkgs.niri ];

# Configure both portals
xdg.portal = {
  enable = true;
  extraPortals = with pkgs; [
    xdg-desktop-portal-gnome  # For GNOME session
    xdg-desktop-portal-gtk     # For niri session
  ];
  config = {
    common = {
      default = ["gnome" "gtk"];
    };
    gnome = {
      default = ["gnome"];  # GNOME uses GNOME portals
    };
    niri = {
      default = ["gtk"];  # Niri uses GTK portals
      "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
      "org.freedesktop.impl.portal.Screenshot" = ["gtk"];
    };
  };
};
```

#### Step 3: Uncomment Niri in Flake
```nix
# flake.nix - Uncomment niri input
inputs = {
  # ... other inputs
  niri = {
    url = "github:YaLTeR/niri";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

outputs = { self, nixpkgs, home-manager, niri, ... }@inputs:
  # Add niri back to outputs parameter
```

#### Step 4: Uncomment Home Manager Config
```nix
# home.nix - Uncomment
home.file.".config/niri/config.kdl".source = ./config/config.kdl;
```

#### Step 5: Rebuild System
```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Switching Between Sessions

**At Login (GDM)**:
1. Click your username
2. Click the gear icon (⚙️) at bottom-right
3. Select either:
   - **GNOME** - Full GNOME Shell (current setup)
   - **GNOME (Wayland)** - GNOME on Wayland
   - **niri** - Niri window manager

**Your choice is remembered** - next login uses the same session unless you change it.

### Session-Specific Autostart

You can configure different programs to start based on which session you're using:

**For Niri session**:
- Configured in `~/.config/niri/config.kdl` via `spawn-at-startup`
- Waybar, mako, nm-applet, etc. auto-start

**For GNOME session**:
- GNOME Shell handles everything automatically
- GNOME settings, extensions, startup applications work normally

### Benefits of Dual-Session Approach

**✅ Advantages:**
1. **Safe Testing**: Test niri without breaking your GNOME setup
2. **Easy Fallback**: If something breaks in niri, just log back into GNOME
3. **Transition Period**: Use GNOME for important work, niri for casual testing
4. **Compare Workflows**: Experience both approaches to make informed decision
5. **Shared Resources**: Both sessions share the same home directory and configs

**⚠️ Considerations:**
1. **Storage**: Both desktop environments installed uses more disk space (~500MB extra)
2. **Maintenance**: Two sets of configs to manage (but this is minimal)
3. **Updates**: Both need to be updated (happens automatically with `nixos-rebuild`)

### Migration Strategy

**Phase 1: Setup Dual Sessions** (Week 1)
1. Re-enable niri configuration
2. Install essential niri services (waybar, mako, etc.)
3. Test switching between GNOME and niri
4. Verify all niri functionality works

**Phase 2: Daily Testing** (Weeks 2-4)
1. Use niri for non-critical tasks
2. Log into GNOME when you need reliability
3. Configure niri to your preferences
4. Note any missing features or issues

**Phase 3: Full Migration** (After comfortable with niri)
1. Set niri as default session
2. Use GNOME only when needed
3. Eventually disable GNOME services if desired

**Phase 4: Cleanup** (Optional, once fully committed)
1. Disable `services.gnome.*` services
2. Remove `xdg-desktop-portal-gnome`
3. Remove GNOME-specific packages
4. Keep `gnome-keyring` for password storage

## Comparison: Minimal Standalone Niri vs GNOME

| Feature | GNOME (Current) | Niri Standalone |
|---------|-----------------|-----------------|
| **RAM Usage** | ~800-1200 MB | ~200-400 MB |
| **Boot Time** | ~5-10 seconds | ~2-5 seconds |
| **WiFi Management** | Integrated top bar | nm-applet in waybar |
| **Bluetooth** | Integrated top bar | blueman-applet in waybar |
| **Audio Control** | Quick settings panel | pavucontrol + waybar |
| **Settings GUI** | gnome-control-center | Individual tool settings |
| **File Manager** | Nautilus | Any (thunar, nemo, pcmanfm) |
| **Notifications** | GNOME Shell | mako |
| **Screen Lock** | GNOME Shell | swaylock |
| **Clipboard** | GNOME Shell | clipman/cliphist |
| **Status Bar** | GNOME Shell | waybar |
| **Startup Apps** | GNOME Settings | config.kdl |
| **Customization** | Extensions + Settings | Config files |
| **Integration** | ✅ Seamless | ⚠️ Manual setup |
| **Maintenance** | 🔄 Auto-updates | 🛠️ Config management |

## Recommended Approach

### Option A: Dual-Session (Recommended for Transition)
**Keep both GNOME and niri installed**, switch at login as needed.

**Best for**:
- Testing niri before committing
- Needing GNOME reliability for work
- Gradual transition
- Having fallback option

**Setup effort**: Medium (uncomment existing config + add services)

### Option B: Full Standalone Niri
**Remove GNOME entirely**, use niri + standalone services.

**Best for**:
- Committed to minimal setup
- Comfortable with config files
- Want maximum performance
- Don't need GNOME integration

**Setup effort**: High (configure all services properly)

### Option C: GNOME + PaperWM (Current Choice)
**Keep GNOME**, use PaperWM extension for tiling.

**Best for**:
- Want scrollable tiling + GNOME utilities
- Prefer GUI settings over config files
- Value integration over performance
- Current recommendation (as per docs/niri.md)

## Implementation Plan

If you want to test dual-session approach:

### Minimal Changes for Testing
```bash
# 1. Uncomment niri in all config files
# 2. Add minimal services to home.nix:

programs.waybar.enable = true;
services.mako.enable = true;

# 3. Rebuild
sudo nixos-rebuild switch --flake .#$(hostname)

# 4. Log out, select "niri" from GDM gear menu
# 5. Test basic functionality
# 6. Log back to GNOME if issues
```

### Full Standalone Migration
See `/plan` command to create detailed implementation plan for:
1. Service configuration
2. Waybar setup with modules
3. Autostart programs
4. Keybinding adjustments
5. Testing procedures
6. Gradual GNOME removal

## References

### Documentation Files
- `configuration.nix:106-117` - Commented niri configuration
- `configuration.nix:128` - Commented sessionPackages
- `configuration.nix:149-172` - XDG portal configuration
- `config/config.kdl:189-199` - Commented standalone services list
- `docs/niri.md:555-750` - GNOME + PaperWM alternative documentation

### External Resources
- **NixOS Niri Wiki**: https://wiki.nixos.org/wiki/Niri
- **Arch Niri Wiki**: https://wiki.archlinux.org/title/Niri
- **Niri GitHub**: https://github.com/YaLTeR/niri
- **Waybar Config**: https://github.com/Alexays/Waybar/wiki
- **Mako Config**: https://github.com/emersion/mako
- **NixOS Sway Guide**: https://nixos.wiki/wiki/Sway (similar patterns)

### Related Reports
- `specs/reports/012_niri_with_gnome_integration.md` - Niri + GNOME integration
- `specs/reports/013_niri_gnome_implementation_risks.md` - Risk assessment
- `specs/plans/010_niri_gnome_portal_integration.md` - Implementation plan

## Conclusion

**Short Answer**:
1. **Essential services**: ~10-15 packages/services (waybar, mako, swaylock, swayidle, nm-applet, blueman, polkit agent, clipman, kanshi)
2. **Dual sessions**: Yes! Uncomment niri config, rebuild, choose at GDM login. Both can coexist.

**Recommendation**: Start with dual-session approach for safe testing, then decide between:
- **Full niri** (if you love the performance/minimalism)
- **GNOME + PaperWM** (if you prefer integrated utilities)

The configuration is already 90% ready - just uncomment the niri sections and add Home Manager services for waybar/mako/swayidle.
