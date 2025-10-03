# Niri Window Manager

## Overview

Niri is a scrollable-tiling Wayland compositor inspired by PaperWM. It provides a unique window management experience where windows are arranged in columns on an infinite horizontal strip.

**Key Features:**
- **Scrollable Tiling**: Windows arranged in columns, scroll infinitely left/right
- **No Forced Resizing**: Opening new windows never resizes existing ones
- **Per-Monitor Independence**: Each monitor has its own window strip
- **Smooth Animations**: Modern, fluid window transitions
- **Wayland Native**: Full Wayland support with XWayland fallback

**Configuration Location**: `~/.config/niri/config.kdl` (managed by Home Manager)

## Keybindings Reference

**Mod key = Super (Windows/Command key)**

### Essential Keys - Memorize These First!

| Key | Action | Notes |
|-----|--------|-------|
| **Mod+t** | Open kitty terminal | Opens automatically on login |
| **Mod+p** | Open fuzzel (app launcher) | Type to search apps |
| **Mod+q** | Close current window | No confirmation dialog |
| **Mod+Shift+r** | Reload niri config | Live config reload |
| **Mod+Shift+q** | Quit niri session | Returns to GDM |

### Window Navigation (Vim-style)

| Key | Action | Description |
|-----|--------|-------------|
| **Mod+h** | Focus column left | Move focus to previous column |
| **Mod+j** | Focus window down | Within same column |
| **Mod+k** | Focus window up | Within same column |
| **Mod+l** | Focus column right | Move focus to next column |
| **Mod+Tab** | Focus most recent window | Quick window switching |

### Window Movement (Vim-style)

| Key | Action | Description |
|-----|--------|-------------|
| **Mod+Shift+h** | Move column left | Reorder columns |
| **Mod+Shift+j** | Move window down | Within column stack |
| **Mod+Shift+k** | Move window up | Within column stack |
| **Mod+Shift+l** | Move column right | Reorder columns |

### Window Management

| Key | Action | Description |
|-----|--------|-------------|
| **Mod+r** | Enter resize mode | Use h/j/k/l to resize, Esc to exit |
| **Mod+m** | Toggle maximize | Maximize current window |
| **Mod+v** | Split column | Create vertical split in column |
| **Mod+s** | Stack column | Stack windows in column |

### Workspaces

| Key | Action | Workspace Name |
|-----|--------|----------------|
| **Mod+1** | Switch to workspace 1 | 1:web |
| **Mod+2** | Switch to workspace 2 | 2:code |
| **Mod+3** | Switch to workspace 3 | 3:term |
| **Mod+4** | Switch to workspace 4 | 4:docs |
| **Mod+5** | Switch to workspace 5 | 5:media |
| **Mod+6** | Switch to workspace 6 | 6:chat |
| **Mod+7** | Switch to workspace 7 | 7:misc |
| **Mod+8** | Switch to workspace 8 | 8:extra |
| **Mod+9** | Switch to workspace 9 | 9:bg |

**Moving Windows to Workspaces**: Add Shift to any workspace key
- **Mod+Shift+1-9** moves current window to workspace 1-9

### Quick Launch Applications

| Key | Application | Package |
|-----|-------------|---------|
| **Mod+b** | Brave browser | brave |
| **Mod+f** | Nautilus file manager | nautilus |
| **Mod+c** | VSCodium | vscodium |
| **Mod+z** | Zotero | zotero |
| **Mod+m** | Spotify | spotify |

### System Controls

| Key | Action | Description |
|-----|--------|-------------|
| **Mod+Shift+s** | Screenshot area | Select area to capture |
| **Print** | Screenshot full screen | Entire screen capture |
| **Mod+Shift+x** | Lock screen | Activate swaylock |

### Audio/Media Controls (Hardware Keys)

| Key | Action | Description |
|-----|--------|-------------|
| **XF86AudioRaiseVolume** | Volume up 5% | Max 150% volume |
| **XF86AudioLowerVolume** | Volume down 5% | Uses wpctl |
| **XF86AudioMute** | Toggle mute | System-wide mute |
| **XF86AudioPlay** | Play/Pause media | Uses playerctl |
| **XF86AudioNext** | Next track | Works with Spotify, etc. |
| **XF86AudioPrev** | Previous track | Works with Spotify, etc. |

## Input Configuration

### Keyboard Settings

```kdl
keyboard {
    xkb {
        layout "us"
        options "caps:escape,compose:ralt"
    }
    repeat-delay 300
    repeat-rate 50
}
```

**Features:**
- **Layout**: US keyboard
- **Caps Lock**: Remapped to Escape
- **Compose Key**: Right Alt for special characters
- **Fast Repeat**: 300ms delay, 50 repeats/second

### Touchpad Settings

```kdl
touchpad {
    natural-scroll true
    tap true
    dwt false  // Disable while typing
    accel-profile "adaptive"
    accel-speed 0.2
    scroll-factor 1.2
}
```

**Features:**
- **Natural Scrolling**: Enabled (macOS-style)
- **Tap to Click**: Enabled
- **Disable While Typing**: Disabled (personal preference)
- **Acceleration**: Adaptive profile, 0.2 speed

### Mouse Settings

```kdl
mouse {
    natural-scroll false
    accel-profile "flat"
    accel-speed 0
}
```

**Features:**
- **Natural Scrolling**: Disabled (traditional scroll)
- **Acceleration**: Flat profile, no acceleration (gaming/precision)

## Visual Configuration

### Theme and Appearance

**Focus Ring:**
- Active color: Nord blue (#5E81AC)
- Inactive color: Nord muted (#434C5E)
- Width: 3px
- Gradient: Light blue to standard blue

**Window Borders:**
- Active border: Nord blue
- Inactive border: Nord muted
- Width: 2px
- Matches focus ring style

**Layout:**
- Gaps between windows: 8px
- Top strut (reserved space): 32px (for potential status bar)
- Default column width: 50% of screen

### Animations

All animations enabled with speed level 7 (1-10 scale):
- Window open/close: 200ms
- Window move/resize: 150ms
- Workspace switch: 200ms

Provides smooth, modern feel without excessive delay.

## Auto-Start Programs

On niri session login, the following programs start automatically:

```kdl
spawn-at-startup "/run/current-system/sw/bin/swaybg -i ~/.wallpapers/current -m fill"
spawn-at-startup "kitty"
```

**Programs:**
1. **swaybg**: Displays wallpaper from `~/.wallpapers/current`
2. **kitty**: Terminal emulator for immediate command line access

**GNOME Services** (via systemd D-Bus activation):
- gnome-settings-daemon (theme, dark mode, location services)
- gnome-keyring-daemon (password/secret storage)
- gnome-online-accounts (email, calendar, cloud integration)
- evolution-data-server (calendar/contacts backend)
- xdg-desktop-portal-gnome (screen sharing, file chooser)

These services start on-demand when needed, not at session startup.

## XDG Desktop Portal Integration

Niri is configured to use GNOME portals for desktop integration features:

**Portal Configuration** (`/etc/xdg/xdg-desktop-portal/niri-portals.conf`):
- **File Chooser**: GNOME (nautilus)
- **Screenshot**: GNOME
- **Screencast**: GNOME (screen sharing)
- **Settings**: GNOME (dark mode, themes)

**Fallback**: GTK portal for compatibility

**Benefits:**
- ✅ Screen sharing works in browsers (Firefox, Brave)
- ✅ File upload dialogs use nautilus (familiar GNOME UI)
- ✅ GNOME Settings (dark mode) apply to all apps
- ✅ Flatpak apps integrate properly

**Testing Portal Functionality:**
```bash
# Check portal services
systemctl --user status xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-gnome.service

# Test screen sharing in browser:
# https://mozilla.github.io/webrtc-landing/gum_test.html
```

See: `specs/reports/012_niri_with_gnome_integration.md` for detailed integration guide.

## Window Rules

Custom rules for specific applications:

```kdl
// Firefox Picture-in-Picture
match {
    title "^Picture-in-Picture$"
    float true
    sticky true
}

// System dialogs (PulseAudio Volume Control)
match {
    app-id "^pavucontrol$"
    float true
    center true
}
```

**Add more rules** by editing `~/.config/niri/config.kdl` and running **Mod+Shift+r** to reload.

## Usage Tips

### Getting Started

1. **First Login**:
   - Select "niri" session from GDM gear icon
   - Kitty terminal opens automatically
   - Press **Mod+p** to launch apps via fuzzel

2. **Basic Workflow**:
   - Use **Mod+t** to open terminals
   - Use **Mod+h/l** to navigate between columns
   - Use **Mod+1-9** to organize by workspace

3. **App Launching**:
   - **Mod+p** → Type app name → Enter
   - Or use quick launch keys (Mod+b for browser, etc.)

### Scrollable Tiling Concept

Unlike traditional tiling window managers that subdivide screen space:

- Windows are **full-height columns** by default
- Columns scroll **infinitely left and right**
- **No automatic resizing** when opening new windows
- Each monitor manages its **own independent strip**

**Example Layout:**
```
[Terminal] [Browser] [VSCode] [Zotero] → scroll more →
```

Navigate with **Mod+h/l** or use **Mod+1-9** for workspace jumps.

### Organizing Workspaces

**Recommended Workspace Organization:**
- **1:web** - Browsers and web apps
- **2:code** - Development environments (VSCode, terminals)
- **3:term** - General terminal work
- **4:docs** - Zotero, LibreOffice, document viewers
- **5:media** - Spotify, VLC, media players
- **6:chat** - Signal, messaging apps
- **7:misc** - Temporary workspace for miscellaneous tasks
- **8:extra** - Overflow workspace
- **9:bg** - Background tasks (downloads, long-running processes)

### Resize Mode

**Entering Resize Mode**: Press **Mod+r**

**In Resize Mode:**
- **h** - Shrink width
- **l** - Grow width
- **k** - Shrink height
- **j** - Grow height
- **Esc** - Exit resize mode

### Working with Multiple Monitors

Each monitor has its own:
- Independent window strip (columns scroll separately)
- Own workspace set (workspaces 1-9 per monitor)
- Focus follows mouse between monitors

Windows **cannot overflow** to adjacent monitors - use **Mod+Shift+h/l** to move columns between monitors if supported.

## Integration with GNOME

Niri uses GNOME services for desktop functionality while providing custom window management:

**GNOME Components Used:**
- **Settings Daemon**: Theme, dark mode, keyboard settings, power management
- **Keyring**: Password and secret storage (SSH keys, app passwords)
- **Online Accounts**: Email, calendar, cloud storage integration
- **Evolution Data Server**: Calendar and contacts backend
- **GVfs**: Virtual filesystem (network drives, MTP devices)

**GNOME Settings Access:**
```bash
gnome-control-center
```

**Dark Mode Toggle:**
```bash
# Enable dark mode
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# Enable light mode
gsettings set org.gnome.desktop.interface color-scheme prefer-light
```

Changes apply immediately to all GTK/GNOME apps.

## Troubleshooting

### Blank Screen on Login

**Cause**: Graphics driver or compositor issue

**Solution**:
1. Press **Ctrl+Alt+F2** to access TTY
2. Login with your credentials
3. Run: `sudo nixos-rebuild switch --rollback`
4. Log out and back in

### Keybindings Not Working

**Cause**: Config syntax error or reload needed

**Solution**:
1. Check config syntax: `cat ~/.config/niri/config.kdl`
2. Reload config: Press **Mod+Shift+r**
3. Check journal: `journalctl --user -u niri.service`

### Portals Not Working (Screen Sharing/File Chooser)

**Cause**: Portal services not started or misconfigured

**Diagnosis**:
```bash
systemctl --user status xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-gnome.service
```

**Solution**:
```bash
# Restart portal services
systemctl --user restart xdg-desktop-portal.service
systemctl --user restart xdg-desktop-portal-gnome.service
```

### Wallpaper Not Displaying

**Cause**: Missing wallpaper file or path

**Solution**:
```bash
# Create wallpaper directory
mkdir -p ~/.wallpapers

# Symlink your preferred wallpaper
ln -s /path/to/your/wallpaper.jpg ~/.wallpapers/current

# Reload niri config
# Press Mod+Shift+r
```

### Application Not Opening

**Cause**: Application not installed or wrong package name

**Solution**:
```bash
# Check if application is installed
which application-name

# Use fuzzel to verify available apps
# Press Mod+p and search for app
```

## Configuration Customization

### Editing Config

Config file location: `~/.config/niri/config.kdl`

**After editing:**
1. Save the file
2. Press **Mod+Shift+r** to reload (no logout required)
3. Test your changes

**Common Customizations:**

**Add New Keybinding:**
```kdl
binds {
    Mod+e { spawn "your-app" }
}
```

**Change Window Gaps:**
```kdl
layout {
    gaps 16  // Increase from 8 to 16
}
```

**Disable Animations:**
```kdl
animations {
    enabled false
}
```

**Add Auto-Start Program:**
```kdl
spawn-at-startup "your-application"
```

### Managing Config with Home Manager

Config is managed by Home Manager via `home.nix`:

```nix
home.file = {
    ".config/niri/config.kdl".source = ./config/config.kdl;
};
```

**After editing `config/config.kdl` in repo:**
```bash
home-manager switch --flake .#benjamin
```

This updates the symlink and applies changes.

## Performance and Resource Usage

**Resource Efficiency:**
- Niri compositor: ~50-100 MB RAM (lightweight)
- GNOME services (on-demand): ~200-400 MB total
- Lower than full GNOME Shell (~800+ MB)

**Battery Life:**
- Efficient Wayland compositor
- Hardware-accelerated rendering
- Services start only when needed

**Boot Time:**
- GDM → Niri session: ~2-5 seconds
- Comparable to GNOME, faster than KDE Plasma

## Related Documentation

- **Integration Guide**: `specs/reports/012_niri_with_gnome_integration.md`
- **Implementation Plan**: `specs/plans/010_niri_gnome_portal_integration.md`
- **Risk Assessment**: `specs/reports/013_niri_gnome_implementation_risks.md`
- **GNOME Applications**: `docs/applications.md`
- **Terminal Configuration**: `docs/terminal.md`

## External Resources

- **Niri GitHub**: https://github.com/YaLTeR/niri
- **Niri Wiki**: https://github.com/YaLTeR/niri/wiki
- **NixOS Wiki**: https://wiki.nixos.org/wiki/Niri
- **Matrix Chat**: https://matrix.to/#/#niri:matrix.org
- **Arch Wiki**: https://wiki.archlinux.org/title/Niri (general guidance)

## Quick Reference Card

**Print or keep visible during first use:**

```
╔════════════════════════════════════════════════════╗
║          NIRI ESSENTIAL KEYBINDINGS                ║
║                                                    ║
║  Mod = Super/Windows Key                           ║
║                                                    ║
║  Mod+t         Open terminal                       ║
║  Mod+p         App launcher (fuzzel)               ║
║  Mod+q         Close window                        ║
║  Mod+h/j/k/l   Navigate (vim-style)                ║
║  Mod+1-9       Switch workspace                    ║
║                                                    ║
║  Mod+Shift+r   Reload config                       ║
║  Mod+Shift+q   Quit niri                           ║
║                                                    ║
║  Ctrl+Alt+F2   Emergency TTY                       ║
╚════════════════════════════════════════════════════╝
```

Save this reference or access anytime:
```bash
cat ~/.dotfiles/docs/niri.md | less
```
