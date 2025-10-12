# Niri + GNOME Portal Integration Implementation Plan

## Metadata
- **Date**: 2025-10-02
- **Feature**: Pure niri-session with GNOME services via D-Bus activation
- **Scope**: Configure XDG portals, remove conflicting gnome-session spawn, enable proper systemd integration
- **Estimated Phases**: 3
- **Standards File**: `/home/benjamin/.dotfiles/CLAUDE.md`
- **Research Reports**:
  - `specs/reports/012_niri_with_gnome_integration.md` (Option 1: Pure niri-session Approach)

## Overview

Implement Option 1 from the niri + GNOME integration research report to achieve clean systemd integration with automatic D-Bus service activation. This resolves portal configuration gaps and removes conflicts caused by spawning `gnome-session` from niri's config.

**Current State**:
- Niri enabled and working for window management
- GNOME services configured but potentially duplicated by gnome-session spawn
- Missing XDG portal configuration (no screen sharing, file chooser portal)
- Conflicting session management in config.kdl:178-180

**Target State**:
- Clean niri-session systemd integration
- Full portal support (file chooser, screen sharing, screenshot, settings)
- Automatic D-Bus service activation for GNOME components
- No session conflicts or service duplication
- Best of both worlds: tiling WM + GNOME desktop integration

## Success Criteria
- [ ] XDG portals configured and functional
- [ ] Screen sharing works in browsers (Firefox/Brave)
- [ ] File chooser portal uses nautilus
- [ ] GNOME Settings (dark mode, themes) applied correctly
- [ ] No duplicate services running
- [ ] Clean systemd session with proper graphical-session.target
- [ ] Configuration passes `nixos-rebuild dry-build`
- [ ] System rebuilds successfully without errors

## Technical Design

### Architecture Decisions

**Portal Stack**:
```
Browser/App → xdg-desktop-portal → xdg-desktop-portal-gnome → nautilus/GNOME Services
                                 ↘ xdg-desktop-portal-gtk (fallback)
```

**Session Management**:
```
GDM → niri-session → systemd user manager → graphical-session.target
                                          → D-Bus activation of services
                                          → xdg-desktop-portal.service (on-demand)
                                          → GNOME services (on-demand)
```

**Service Activation Flow**:
1. User logs in via GDM, selects "niri" session
2. GDM launches `/usr/bin/niri-session`
3. niri-session imports environment to systemd user manager
4. niri-session starts `graphical-session.target`
5. systemd activates D-Bus services on-demand:
   - Portal needed → `xdg-desktop-portal.service` starts
   - Secrets needed → `gnome-keyring-daemon.service` starts
   - Audio needed → `pipewire.service` starts
6. No manual spawn-at-startup needed for system services

### Key Components Modified

1. **`configuration.nix`**:
   - Add `xdg.portal` configuration block
   - Add nautilus to `services.dbus.packages`
   - Optionally add gnome-control-center to system packages
   - Keep all existing `services.gnome.*` settings

2. **`config/config.kdl`**:
   - Remove lines 178-180 (dbus-daemon and gnome-session spawns)
   - Keep wallpaper spawn (line 182)
   - Keep commented alternative tools section for reference

3. **No changes to**:
   - `home.nix` - No user-level changes needed
   - `flake.nix` - Existing configuration sufficient
   - Other config files

### Testing Strategy

**Per-Phase Testing**:
- Phase 1: Syntax validation via dry-build
- Phase 2: Service activation verification
- Phase 3: Functional portal testing

**Integration Testing**:
- Screen sharing in video conferencing apps
- File chooser in web browsers
- GNOME Settings application
- Theme consistency across apps

## Implementation Phases

### Phase 1: Portal Configuration
**Objective**: Add XDG portal configuration and nautilus D-Bus package
**Complexity**: Low

Tasks:
- [ ] Add XDG portal configuration block to `configuration.nix` after line 138 (after gvfs.enable)
  ```nix
  # XDG Desktop Portal Configuration for niri
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
  ```

- [ ] Add nautilus to D-Bus packages in `configuration.nix` after portal config
  ```nix
  # Nautilus required for GNOME portal FileChooser implementation
  services.dbus.packages = [ pkgs.nautilus ];
  ```

- [ ] Optionally add GNOME Control Center and nautilus to system packages in `configuration.nix:187-320`
  ```nix
  environment.systemPackages =
    (with pkgs; [
      # GNOME Tools for niri integration
      gnome-control-center  # GNOME Settings GUI
      nautilus              # File manager (required by portal)

      # Wayland and Niri essentials
      # ... (existing packages)
    ]);
  ```

- [ ] Test configuration syntax
  ```bash
  nixos-rebuild dry-build --flake .#nandi
  ```

Testing:
```bash
# Verify configuration builds without errors
nixos-rebuild dry-build --flake .#nandi --option allow-import-from-derivation false

# Expected: No errors, dry build succeeds
```

**Validation Criteria**:
- Configuration passes dry-build
- No syntax errors in Nix expressions
- Portal packages included in derivation

---

### Phase 2: Remove Session Conflicts
**Objective**: Remove conflicting gnome-session spawn from niri config
**Complexity**: Low

Tasks:
- [ ] Edit `config/config.kdl` to remove lines 178-180:
  - Remove: `spawn-at-startup "dbus-daemon --session --address=unix:path=$XDG_RUNTIME_DIR/bus"`
  - Remove: `// Start GNOME Session (this will handle most system services)`
  - Remove: `spawn-at-startup "gnome-session --session=gnome"`

- [ ] Keep line 182 (wallpaper) and adjust comment:
  ```kdl
  //// AUTOSTART PROGRAMS ////

  // Wallpaper (systemd handles all other services via D-Bus activation)
  spawn-at-startup "/run/current-system/sw/bin/swaybg -i ~/.wallpapers/current -m fill"
  ```

- [ ] Keep commented alternative tools section (lines 184-194) for reference

- [ ] Test niri config syntax (if niri provides validation)

Testing:
```bash
# Check niri config syntax (if niri has validation command)
# niri validate-config ~/.config/niri/config.kdl || echo "No validation command available"

# Verify file changes
git diff config/config.kdl
```

**Validation Criteria**:
- Lines 178-180 removed
- Wallpaper spawn retained
- Config file syntax valid
- Changes tracked in git

---

### Phase 3: System Rebuild and Verification
**Objective**: Apply configuration changes and verify portal functionality
**Complexity**: Medium

Tasks:
- [ ] Rebuild NixOS system configuration
  ```bash
  sudo nixos-rebuild switch --flake .#nandi --option allow-import-from-derivation false
  ```

- [ ] Rebuild Home Manager configuration (for config.kdl symlink update)
  ```bash
  home-manager switch --flake .#benjamin --option allow-import-from-derivation false
  ```

- [ ] Log out of current session completely

- [ ] Log back in via GDM, selecting **"niri"** session (not GNOME)

- [ ] Verify session type and desktop environment
  ```bash
  echo $XDG_SESSION_TYPE      # Should be "wayland"
  echo $XDG_CURRENT_DESKTOP   # Should be "niri"
  systemctl --user show-environment | grep XDG_CURRENT_DESKTOP
  ```

- [ ] Check portal service status
  ```bash
  systemctl --user status xdg-desktop-portal.service
  systemctl --user status xdg-desktop-portal-gnome.service
  ```

- [ ] Verify GNOME services running
  ```bash
  systemctl --user status gnome-keyring-daemon.service
  ps aux | grep gnome-settings-daemon
  ps aux | grep gvfs
  ```

- [ ] Test file chooser portal (should open nautilus)
  ```bash
  # This may require a GUI app that uses portal
  # Alternative: Test via browser file upload dialog
  ```

- [ ] Test screen sharing
  ```bash
  # Open Firefox or Brave
  # Navigate to: https://mozilla.github.io/webrtc-landing/gum_test.html
  # Click "Share your screen" - should show GNOME portal dialog
  ```

- [ ] Test GNOME Settings application
  ```bash
  gnome-control-center
  # Should open GNOME Settings
  # Change dark mode - verify it applies to apps
  ```

- [ ] Check for duplicate services (should be none)
  ```bash
  ps aux | grep -i gnome | grep -v grep
  # Verify no duplicate gnome-session or shell processes
  ```

- [ ] Create wallpaper directory if needed
  ```bash
  mkdir -p ~/.wallpapers
  # Link or copy a wallpaper as ~/.wallpapers/current
  ```

Testing:
```bash
# Comprehensive system check script
cat > /tmp/verify-niri-gnome.sh << 'EOF'
#!/usr/bin/env bash
set -e

echo "=== Session Verification ==="
echo "Session type: $XDG_SESSION_TYPE (expect: wayland)"
echo "Desktop: $XDG_CURRENT_DESKTOP (expect: niri)"

echo -e "\n=== Portal Services ==="
systemctl --user is-active xdg-desktop-portal.service
systemctl --user is-active xdg-desktop-portal-gnome.service

echo -e "\n=== GNOME Services ==="
systemctl --user is-active gnome-keyring-daemon.service || echo "Keyring will start on-demand"
pgrep -fl gnome-settings-daemon && echo "Settings daemon running" || echo "Settings daemon will start on-demand"

echo -e "\n=== Duplicate Check ==="
DUPS=$(ps aux | grep -i "gnome-session\|gnome-shell" | grep -v grep | wc -l)
if [ "$DUPS" -eq 0 ]; then
  echo "✓ No duplicate GNOME session processes"
else
  echo "✗ Found $DUPS conflicting processes:"
  ps aux | grep -i "gnome-session\|gnome-shell" | grep -v grep
fi

echo -e "\n=== Portal Config ==="
ls -la /etc/xdg/xdg-desktop-portal/ 2>/dev/null || echo "Portal config not found (this may be normal)"

echo -e "\n=== Summary ==="
echo "If all checks pass, test screen sharing in browser"
EOF

chmod +x /tmp/verify-niri-gnome.sh
/tmp/verify-niri-gnome.sh
```

**Validation Criteria**:
- System rebuilds without errors
- Session type is "wayland", desktop is "niri"
- Portal services start on-demand
- No duplicate GNOME session processes
- Screen sharing works in browser
- File chooser uses nautilus
- GNOME Settings accessible and functional

---

## Post-Implementation Testing

### Functional Tests

**Portal File Chooser**:
1. Open Firefox or Brave
2. Navigate to any file upload form
3. Click "Choose File" or "Upload"
4. Verify nautilus file chooser dialog appears
5. Select a file and confirm it uploads

**Screen Sharing**:
1. Open browser (Firefox/Brave)
2. Go to: https://mozilla.github.io/webrtc-landing/gum_test.html
3. Click "Share your screen"
4. Verify GNOME portal screen selection dialog appears
5. Select a screen/window and confirm it streams

**GNOME Settings**:
1. Launch: `gnome-control-center`
2. Navigate to Appearance → Style
3. Toggle Dark/Light mode
4. Verify all apps (GTK/Qt) reflect the change
5. Check other settings (Wi-Fi, Bluetooth, etc.)

**GNOME Online Accounts**:
1. Open GNOME Settings → Online Accounts
2. Verify existing accounts appear
3. Test adding/removing an account
4. Verify calendar/contacts sync (Evolution)

**Keyring**:
1. Open an app requiring password (e.g., browser with saved passwords)
2. Verify GNOME Keyring prompt appears if needed
3. Check: `secret-tool search service test` (should work)

### Performance Tests

**Service Activation**:
```bash
# Boot time check
systemd-analyze blame --user | head -20

# Service startup time
systemd-analyze critical-chain --user xdg-desktop-portal.service
```

**Resource Usage**:
```bash
# Check memory usage of GNOME services
ps aux | grep -i gnome | awk '{print $6/1024 " MB - " $11}'

# Compare before/after removing gnome-session spawn
# Expected: Lower memory usage with on-demand activation
```

### Edge Cases

**Multi-Monitor**:
- Test screen sharing with multiple monitors
- Verify portal shows all screens
- Check niri's per-monitor window strips work correctly

**Flatpak Apps**:
```bash
# Install a Flatpak app (if not already installed)
flatpak install flathub org.gnome.Calculator

# Run and verify it uses GNOME theme
flatpak run org.gnome.Calculator

# Test file chooser in Flatpak app
```

**XWayland Apps**:
- Open an X11 app (e.g., xeyes, xterm)
- Verify it runs via XWayland
- Check theme consistency

## Rollback Plan

If issues occur during implementation:

### Immediate Rollback (Phase 3 Issues)
```bash
# Revert to previous NixOS generation
sudo nixos-rebuild switch --rollback

# Or select previous generation at boot (systemd-boot menu)
# Reboot and select "NixOS - Configuration X (previous)"
```

### Partial Rollback (Portal Issues Only)

If portals don't work but system is otherwise stable:

1. **Disable portal config** in `configuration.nix`:
   ```nix
   xdg.portal.enable = false;
   ```

2. **Keep gnome-session spawn** in `config/config.kdl` (restore lines 178-180)

3. **Rebuild**:
   ```bash
   sudo nixos-rebuild switch --flake .#nandi
   ```

### Git Revert

If configuration is committed but broken:
```bash
# Check commit history
git log --oneline -5

# Revert to working commit
git revert <commit-hash>

# Or reset (if not pushed)
git reset --hard HEAD~1

# Rebuild from reverted config
sudo nixos-rebuild switch --flake .#nandi
```

## Documentation Requirements

### Update Project Documentation

**After successful implementation**, update:

1. **`docs/configuration.md`**:
   - Add section: "Niri + GNOME Portal Integration"
   - Document portal configuration pattern
   - Explain niri-session systemd integration
   - List which GNOME services are used and why

2. **`CLAUDE.md`** (if applicable):
   - Add to "Common Patterns" or "Window Manager Configuration"
   - Reference this plan in "Specs Directory Protocol"

3. **Create summary** in `specs/summaries/010_niri_gnome_portal_integration.md`:
   ```markdown
   # Implementation Summary: Niri + GNOME Portal Integration
   Date: [completion-date]

   ## What Was Done
   - Configured XDG portals for niri with GNOME backend
   - Removed conflicting gnome-session spawn
   - Enabled clean systemd/D-Bus service activation

   ## Files Modified
   - `configuration.nix`: Added xdg.portal config, nautilus to D-Bus
   - `config/config.kdl`: Removed gnome-session spawn

   ## Key Decisions
   - Use niri-session for systemd integration (not manual spawns)
   - GNOME portal for best integration with existing services
   - Keep all GNOME services enabled for desktop features

   ## Results
   - Screen sharing works in browsers
   - File chooser uses nautilus
   - GNOME Settings fully functional
   - No service duplication or conflicts

   ## Future Considerations
   - Monitor resource usage of GNOME services
   - Consider disabling unused services if needed
   - Evaluate alternative portals if issues arise
   ```

### Configuration Comments

Add comments to configuration files for future reference:

**`configuration.nix`**:
```nix
# XDG Desktop Portal Configuration for niri
# Enables screen sharing, file chooser, and GNOME Settings integration
# See: specs/reports/012_niri_with_gnome_integration.md
xdg.portal = {
  # ...
};
```

**`config/config.kdl`**:
```kdl
//// AUTOSTART PROGRAMS ////

// Note: systemd handles service activation via D-Bus (no manual spawns needed)
// GNOME services start on-demand through niri-session integration
// See: specs/plans/010_niri_gnome_portal_integration.md

spawn-at-startup "/run/current-system/sw/bin/swaybg -i ~/.wallpapers/current -m fill"
```

## Dependencies

### System Dependencies
- **NixOS**: 24.11 (already met - see `configuration.nix:366`)
- **niri package**: Available in nixpkgs (already configured)
- **GNOME packages**: gnome-keyring, settings-daemon, etc. (already enabled)
- **Portal packages**: xdg-desktop-portal-gnome, xdg-desktop-portal-gtk (added in Phase 1)
- **nautilus**: Required for FileChooser portal (added in Phase 1)

### Optional Dependencies
- **gnome-control-center**: For Settings GUI (recommended, added in Phase 1)
- **Wallpaper image**: For swaybg (user must provide or update path)

### External Services
- **systemd user session**: Required for D-Bus activation (provided by NixOS)
- **D-Bus session bus**: Required for portal communication (provided by systemd)
- **GDM**: Display manager for session selection (already configured)

### Build-Time Dependencies
- **Nix flakes**: Already enabled (`nix.settings.experimental-features`)
- **Home Manager**: Already configured in flake (for config.kdl)
- **Network access**: For Nix store downloads (standard requirement)

## Notes

### Design Decisions

**Why Remove gnome-session Spawn?**
- Conflicts with niri-session systemd integration
- Causes duplicate service instances
- Prevents proper D-Bus activation flow
- GNOME Shell would compete with niri for window management

**Why Use GNOME Portal?**
- Best integration with existing GNOME services
- Provides nautilus file chooser (familiar UI)
- Reads GNOME Settings (dark mode, themes)
- Required for screen sharing in most apps
- GTK portal as fallback ensures compatibility

**Why Keep GNOME Services?**
- Settings Daemon: Manages themes, power, location services
- Keyring: Stores passwords, SSH keys, OAuth tokens
- Online Accounts: Single sign-on for email, calendar, cloud
- Evolution Data Server: Calendar/contacts backend for apps
- Already configured and providing value

### Alternative Approaches Not Taken

**GNOME Flashback** (from research):
- More complex setup for minimal benefit
- Requires custom session file creation
- Not necessary when niri-session + D-Bus works

**Pure niri without GNOME** (Option 3 from report):
- Would lose Settings, Online Accounts, keyring integration
- Requires setting up alternative tools (waybar, mako, etc.)
- More maintenance burden
- User already invested in GNOME ecosystem

**Manual systemd service units**:
- Unnecessary when D-Bus activation works
- More complex to maintain
- Bypasses standard portal infrastructure

### Known Limitations

**Niri-Specific**:
- No GNOME Shell extensions (niri is not Shell)
- No Activities overview or app grid
- Must use alternative launcher (fuzzel configured in config.kdl:101)

**Portal-Specific**:
- Some apps may not support portals (legacy X11 apps)
- Requires app to use modern Flatpak/portal APIs
- File chooser only works if app uses XDG portal

**GNOME Services**:
- Settings daemon may conflict if multiple instances run (fixed by this plan)
- Remote desktop service may not work without GNOME Shell (untested)
- Some GNOME apps expect Shell for certain features (e.g., screenshot annotations)

### Future Enhancements

**Short Term**:
- Create wallpaper directory and symlink default wallpaper
- Test with all regularly-used apps (browsers, editors, etc.)
- Benchmark resource usage before/after changes

**Medium Term**:
- Evaluate disabling unused GNOME services (e.g., remote desktop if not used)
- Consider adding swaylock config for screen locking
- Set up automatic wallpaper rotation if desired

**Long Term**:
- Explore custom niri session file for fine-grained control
- Consider contributing niri + GNOME portal config example to NixOS wiki
- Monitor niri upstream for improved GNOME integration features

### Testing Environment Notes

**Required for Full Testing**:
- Video conferencing account (Zoom, Google Meet, etc.) for screen sharing test
- Web browser with WebRTC support (Firefox/Brave already installed)
- Flatpak configured (if testing Flatpak app integration)
- Multiple monitors (if testing multi-display features)

**Optional Test Scenarios**:
- VPN connection (test with NetworkManager integration)
- Bluetooth device pairing (test GNOME Bluetooth service)
- Printer setup (test CUPS + GNOME Settings integration)
- External displays (test hot-plug with niri + GNOME)

## Success Metrics

### Technical Metrics
- [ ] Zero duplicate GNOME services running
- [ ] Portal services start within 2 seconds of first use
- [ ] System memory usage reduction (from removing gnome-session spawn)
- [ ] No errors in `journalctl --user -u xdg-desktop-portal.service`

### Functional Metrics
- [ ] 100% success rate for screen sharing in browsers
- [ ] File chooser works in all tested apps (web browsers, Flatpaks)
- [ ] GNOME Settings accessible and all panels functional
- [ ] Dark mode toggles correctly affect all apps within 1 second

### User Experience Metrics
- [ ] Login to session under 10 seconds (GDM → usable desktop)
- [ ] No visible errors or warnings on login
- [ ] All existing workflows continue to work
- [ ] New portal features (screen sharing) work seamlessly

## Commit Strategy

Follow conventional commit format from `CLAUDE.md`:

### Phase 1 Commit
```bash
git add configuration.nix
git commit -m "feat(niri): add XDG portal configuration with GNOME backend

Configure xdg-desktop-portal with GNOME and GTK backends for niri
session. Adds nautilus to D-Bus packages for FileChooser portal
implementation. Optionally includes gnome-control-center for Settings
GUI access.

Enables screen sharing, file chooser, and GNOME settings integration
in niri compositor.

Related: specs/reports/012_niri_with_gnome_integration.md
Implements: specs/plans/010_niri_gnome_portal_integration.md (Phase 1)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Phase 2 Commit
```bash
git add config/config.kdl
git commit -m "fix(niri): remove conflicting gnome-session spawn

Remove spawn-at-startup for gnome-session and dbus-daemon from niri
config. These conflict with niri-session's systemd integration and
cause duplicate services.

Systemd and D-Bus now handle service activation automatically via
graphical-session.target. GNOME services start on-demand when needed.

Related: specs/reports/012_niri_with_gnome_integration.md
Implements: specs/plans/010_niri_gnome_portal_integration.md (Phase 2)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Phase 3 Commit (Summary)
```bash
git add specs/summaries/010_niri_gnome_portal_integration.md
git commit -m "docs: add niri GNOME portal integration summary

Summarize implementation of clean niri-session with GNOME services
via D-Bus activation. Documents portal configuration, service
activation flow, and testing results.

Completed: specs/plans/010_niri_gnome_portal_integration.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Related Files

### Modified Files
- `/home/benjamin/.dotfiles/configuration.nix` - Portal config, D-Bus packages
- `/home/benjamin/.dotfiles/config/config.kdl` - Remove session spawns

### Reference Files (Not Modified)
- `/home/benjamin/.dotfiles/home.nix` - User config (unchanged)
- `/home/benjamin/.dotfiles/flake.nix` - System flake (unchanged)

### Documentation Files
- `/home/benjamin/.dotfiles/specs/reports/012_niri_with_gnome_integration.md` - Research report
- `/home/benjamin/.dotfiles/CLAUDE.md` - Project standards
- `/home/benjamin/.dotfiles/docs/configuration.md` - To be updated post-implementation
