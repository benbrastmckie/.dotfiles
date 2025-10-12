# Research Report: Niri Window Manager with GNOME Desktop Integration

## Metadata
- **Date**: 2025-10-02
- **Scope**: Using niri scrollable-tiling Wayland compositor on NixOS while leveraging GNOME desktop services and features
- **Primary Directory**: `/home/benjamin/.dotfiles`
- **Files Analyzed**: `configuration.nix`, `home.nix`, `config/config.kdl`

## Executive Summary

You already have a working niri + GNOME integration setup! Your current configuration at `configuration.nix:106-132` demonstrates a functional hybrid approach: niri handles window management while GNOME services provide desktop features (settings, keyring, online accounts, etc.).

However, your current implementation has a potential issue: spawning `gnome-session --session=gnome` from niri's config.kdl (line 180) may conflict with niri's own session management and could prevent proper systemd integration. The recommended approach is to use **niri-session** for systemd integration, which automatically handles GNOME services through D-Bus activation, or to selectively enable only the GNOME services you need without the full GNOME session.

## What is Niri?

**Niri** is a scrollable-tiling Wayland compositor inspired by PaperWM (a GNOME Shell extension). Key characteristics:

- **Scrollable Tiling**: Windows arranged in columns on an infinite horizontal strip
- **Monitor Independence**: Each monitor has its own separate window strip
- **No Forced Resizing**: Opening new windows never resizes existing ones
- **Modern**: Graduated from v0.1 in January 2025, currently at v25.05 (May 2025)
- **KDL Configuration**: Uses KDL format with live reload support

## Current Configuration Analysis

### What You Have Working

**System Configuration** (`configuration.nix:106-132`):
```nix
# Niri compositor
programs.niri = {
  enable = true;
  package = pkgs.niri;
};

# Session package registration
services.displayManager.sessionPackages = [ pkgs.niri ];

# GNOME services enabled
services.gnome = {
  gnome-settings-daemon.enable = true;
  gnome-online-accounts.enable = true;
  evolution-data-server.enable = true;
  gnome-keyring.enable = true;
  gnome-remote-desktop.enable = true;
};
```

**Benefits of Your Current Approach**:
- ✅ Niri handles window management (tiling, workspace control)
- ✅ GNOME Settings Daemon provides theme management, dark mode, location services
- ✅ GNOME Keyring manages passwords and secrets
- ✅ GNOME Online Accounts integrates email, calendar, cloud storage
- ✅ Evolution Data Server provides calendar/contacts backend
- ✅ GDM display manager with Wayland support

### Potential Issues

**Problem with `spawn-at-startup "gnome-session --session=gnome"`** (`config/config.kdl:180`):

1. **Conflicts with niri-session**: When you select "niri" from GDM, it should run `niri-session`, which:
   - Starts niri as a systemd service
   - Activates the `graphical-session.target`
   - Auto-starts D-Bus services on-demand
   - Imports environment variables globally

2. **Spawning Full GNOME Session**: Your current config spawns the full GNOME session, which:
   - May try to start GNOME Shell (conflicting window manager)
   - Could duplicate systemd services already running
   - Bypasses niri's proper systemd integration
   - May cause race conditions in service startup order

3. **Missing XDG Portal Configuration**: No explicit portal configuration detected in your files.

## Recommended Configuration Improvements

### Option 1: Pure niri-session Approach (Recommended)

**Advantages**:
- Cleanest systemd integration
- Automatic D-Bus service activation
- Proper graphical session target handling
- Auto-start support for XDG Desktop entries
- On-demand portal activation

**Changes Needed**:

1. **Remove** `spawn-at-startup "gnome-session --session=gnome"` from `config/config.kdl:180`

2. **Add** XDG portal configuration to `configuration.nix`:

```nix
# XDG Desktop Portal Configuration
xdg.portal = {
  enable = true;
  extraPortals = with pkgs; [
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
  ];
  config = {
    common = {
      default = ["gnome" "gtk"];
    };
    niri = {
      default = ["gnome" "gtk"];
      "org.freedesktop.impl.portal.FileChooser" = ["gnome"];
      "org.freedesktop.impl.portal.Screenshot" = ["gnome"];
      "org.freedesktop.impl.portal.Screencast" = ["gnome"];
      "org.freedesktop.impl.portal.Settings" = ["gnome"];
    };
  };
};

# Add nautilus to D-Bus for FileChooser portal
services.dbus.packages = [ pkgs.nautilus ];
```

3. **Ensure** you're selecting "niri" (not "GNOME") from GDM login screen

4. **Keep** all existing GNOME services in `services.gnome.*`

5. **Consider** adding to `configuration.nix` for GNOME Settings access:
```nix
environment.systemPackages = with pkgs; [
  gnome-control-center  # GNOME Settings GUI
  nautilus              # File manager (required by portal)
  # ... existing packages
];
```

### Option 2: Hybrid Approach with Manual Service Management

If you need more control over which services start:

**Configuration** (`configuration.nix`):
```nix
# Keep existing GNOME service enables
services.gnome = {
  gnome-settings-daemon.enable = true;
  gnome-online-accounts.enable = true;
  evolution-data-server.enable = true;
  gnome-keyring.enable = true;
};

# Add portal configuration (as in Option 1)
xdg.portal = { ... };
```

**Update** `config/config.kdl` autostart section:
```kdl
// Essential services for niri (replace existing spawn-at-startup)
spawn-at-startup "/run/current-system/sw/bin/swaybg -i ~/.wallpapers/current -m fill"

// GNOME Components (started manually if needed)
// spawn-at-startup "gnome-control-center --gapplication-service"
// spawn-at-startup "nautilus --gapplication-service"
```

Note: With proper niri-session + systemd integration, these should start automatically on-demand via D-Bus activation.

### Option 3: Minimal niri (No GNOME Services)

For a pure niri experience without GNOME dependencies:

**Configuration Changes**:
1. **Disable** GNOME services in `configuration.nix`
2. **Uncomment** standalone tools in `configuration.nix:196-209`:
   - fuzzel (launcher)
   - mako (notifications)
   - waybar (status bar)
   - swaylock (screen locker)
   - nm-applet (network management)
   - blueman (Bluetooth)
3. **Uncomment** spawn-at-startup entries in `config/config.kdl:186-194`
4. **Use** xdg-desktop-portal-gtk instead of GNOME portal

**Trade-offs**:
- ❌ Lose GNOME Settings, Online Accounts, integrated calendar/contacts
- ✅ Lighter resource usage
- ✅ More explicit control over services
- ✅ Better alignment with niri philosophy

## Integration Details

### What GNOME Services Provide in niri

| Service | Functionality | Visible in niri? |
|---------|--------------|------------------|
| **gnome-settings-daemon** | Theme management, dark mode, keyboard settings, power management, location services | Yes - affects all apps |
| **gnome-keyring** | Password/secret storage, SSH key management, GPG integration | Yes - background service |
| **gnome-online-accounts** | Single sign-on for Google, Microsoft, etc. Email/calendar/cloud integration | Yes - used by Evolution, Files, Calendar |
| **evolution-data-server** | Calendar, contacts, tasks backend | Yes - data accessible to apps |
| **gnome-control-center** | Settings GUI | Yes - can launch manually |
| **nautilus** | File manager, portal FileChooser implementation | Yes - can launch or use portal |
| **gnome-remote-desktop** | Remote desktop server | Background service |

### XDG Desktop Portals Explained

**What are Portals?**
- D-Bus services that mediate access to desktop features
- Allow sandboxed apps (Flatpak, browsers) to access system resources
- GNOME implementation provides: file chooser, screenshot, screencast, settings, etc.

**Why xdg-desktop-portal-gnome?**
- Integrates with GNOME Settings (theme, dark mode)
- Uses nautilus for file picker (familiar GNOME UI)
- Screen sharing works in browsers/video conferencing
- Reads GNOME UI settings for Flatpak apps

**Required for**:
- Firefox/Chrome screen sharing in Wayland
- Flatpak file access dialogs
- GNOME theme consistency in sandboxed apps

### How niri-session Works

When you log in through GDM selecting "niri":

1. **GDM** launches `/usr/bin/niri-session` (provided by NixOS module)
2. **niri-session** script:
   - Imports environment variables to systemd user manager
   - Starts `graphical-session.target`
   - Activates D-Bus services
   - Launches niri compositor
3. **systemd** automatically starts on-demand:
   - xdg-desktop-portal.service (when portal is needed)
   - gnome-keyring-daemon.service (when secrets accessed)
   - pipewire.service (for audio)
4. **XDG autostart** entries run automatically (apps configured in GNOME Startup Applications)

## Testing Your Configuration

### 1. Verify Session Type
```bash
# After logging into niri
echo $XDG_SESSION_TYPE  # Should be "wayland"
echo $XDG_CURRENT_DESKTOP  # Should be "niri"
systemctl --user show-environment | grep XDG_CURRENT_DESKTOP
```

### 2. Check Portal Status
```bash
# List running portals
systemctl --user status xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-gnome.service

# Test file chooser portal (should open nautilus)
busctl --user call org.freedesktop.portal.Desktop \
  /org/freedesktop/portal/desktop \
  org.freedesktop.portal.FileChooser \
  OpenFile s "test" a{sv} 0
```

### 3. Verify GNOME Services
```bash
# Check if GNOME services are running
systemctl --user status gnome-keyring-daemon.service
systemctl --user status gvfs-daemon.service
ps aux | grep gnome-settings-daemon
ps aux | grep evolution
```

### 4. Test Screen Sharing
```bash
# Open Firefox or Brave, go to: https://mozilla.github.io/webrtc-landing/gum_test.html
# Click "Share your screen" - should show portal dialog
```

## Known Issues and Workarounds

### Issue 1: Electron Apps with IME
**Symptom**: Input methods don't work in Electron apps
**Workaround**: Already configured in `configuration.nix:81-82`:
```nix
environment.sessionVariables = {
  NIXOS_OZONE_WL = "1";
  WLR_NO_HARDWARE_CURSORS = "1";
};
```

### Issue 2: Qt Apps Title Bar Behavior
**Symptom**: Qt apps with client-side decorations
**Workaround**: Already implemented for sioyek in `configuration.nix:311-319`:
```nix
(writeShellScriptBin "sioyek" ''
  #!/bin/sh
  export QT_QPA_PLATFORM=xcb
  exec ${pkgs.sioyek}/bin/sioyek "$@"
'')
```

### Issue 3: Waybar Duplication After DPMS
**Symptom**: Status bar duplicates after monitor sleep/wake
**Solution**: Use systemd service management instead of spawn-at-startup (if using waybar)

### Issue 4: GNOME Session Conflicts
**Symptom**: Window management conflicts, duplicate services
**Solution**: Remove `spawn-at-startup "gnome-session --session=gnome"` and rely on niri-session

## Migration Path

### Phase 1: Fix Portal Configuration (High Priority)
**Why**: Enables screen sharing, file chooser, proper GNOME theme integration

**Actions**:
1. Add portal configuration to `configuration.nix` (see Option 1 above)
2. Add nautilus to `services.dbus.packages`
3. Test with `nixos-rebuild test --flake .#nandi`
4. Verify portals work (see Testing section)

### Phase 2: Remove gnome-session Spawn (Medium Priority)
**Why**: Prevents conflicts, enables proper systemd integration

**Actions**:
1. Remove or comment out `spawn-at-startup "gnome-session --session=gnome"` in `config/config.kdl:180`
2. Also remove `spawn-at-startup "dbus-daemon ..."` (line 178) - systemd manages this
3. Rebuild and test: `home-manager switch --flake .#benjamin`
4. Log out and back in
5. Verify GNOME services still work (see Testing section)

### Phase 3: Optimize Service Selection (Optional)
**Why**: Reduce resource usage, clarify which services you actually use

**Actions**:
1. Audit which GNOME services you actively use:
   - Email/calendar → Keep evolution-data-server, gnome-online-accounts
   - Cloud storage in Files → Keep gnome-online-accounts, gvfs
   - Remote desktop → Keep gnome-remote-desktop or disable if unused
2. Consider disabling unused services
3. Test for 1-2 weeks to ensure no regressions

## Recommendations

### Immediate Actions (Do First)
1. ✅ **Add XDG portal configuration** - Critical for screen sharing, file chooser
2. ✅ **Remove `gnome-session` spawn** - Prevents conflicts, improves systemd integration
3. ✅ **Test with new configuration** - Verify screen sharing, GNOME Settings, keyring

### Short Term (Next Week)
1. **Install GNOME Control Center** if you want GUI settings access:
   ```nix
   environment.systemPackages = [ pkgs.gnome-control-center ];
   ```
2. **Create wallpaper directory** if needed:
   ```bash
   mkdir -p ~/.wallpapers
   ln -s /path/to/your/wallpaper.jpg ~/.wallpapers/current
   ```
3. **Test all GNOME integrations** you rely on (email, calendar, cloud storage)

### Long Term (Consider Later)
1. **Evaluate service usage** - Disable GNOME services you don't actively use
2. **Custom session file** - If you need fine-grained control, create a custom session.desktop
3. **Document your setup** - Update `docs/configuration.md` with your niri + GNOME choices

### Not Recommended
1. ❌ **Running full GNOME + niri simultaneously** - Resource waste, conflicts
2. ❌ **Disabling all GNOME services** - You're already configured for them; they provide value
3. ❌ **Switching to pure niri** - Unless you want to lose GNOME conveniences

## Conclusion

Your current configuration demonstrates a good understanding of niri + GNOME integration. The main improvements needed are:

1. **Portal configuration** (missing, critical for modern features)
2. **Remove gnome-session spawn** (causes conflicts)
3. **Trust systemd/D-Bus activation** (already enabled via niri-session)

The recommended approach is **Option 1** (Pure niri-session), which gives you:
- Clean window management via niri
- GNOME desktop services (settings, keyring, online accounts)
- Automatic service activation via systemd
- Full portal support for screen sharing and file chooser
- Best of both worlds: tiling WM + desktop integration

## References

### Files in Your Dotfiles
- `configuration.nix:106-132` - Current niri + GNOME configuration
- `config/config.kdl:178-182` - Autostart configuration (needs update)
- `configuration.nix:196-209` - Commented alternative tools for pure niri

### External Documentation
- [Niri NixOS Wiki](https://wiki.nixos.org/wiki/Niri) - Official NixOS integration guide
- [Niri GitHub Wiki - Getting Started](https://github.com/YaLTeR/niri/wiki/Getting-Started) - Upstream documentation
- [vlaci's Niri Setup](https://vlaci.github.io/nix.org/posts/niri) - Example NixOS configuration
- [Arch Wiki - Niri](https://wiki.archlinux.org/title/Niri) - Comprehensive setup guide
- [GNOME Flashback](https://wiki.archlinux.org/title/GNOME/Flashback) - Alternative for using non-GNOME WMs with GNOME

### Related NixOS Options
- `programs.niri.*` - Niri module options
- `xdg.portal.*` - Portal configuration
- `services.gnome.*` - GNOME services configuration
- `services.displayManager.sessionPackages` - Custom session registration

### Project Standards
- See `CLAUDE.md` for configuration and testing procedures
- See `docs/configuration.md` for general NixOS configuration patterns
- See `docs/applications.md` for application-specific settings
