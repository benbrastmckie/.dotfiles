# Revert Report: Keyboard Issues Fix

**Date**: December 19, 2025  
**Issue**: Tab key, Ctrl+Enter, and keyboard remapping not working  
**Root Cause**: Changes introduced in commit c764360 "breaking changes" AND commit a8a2224 "updated project context"  
**Solution**: Revert configuration files to commit 487129c "opencode works"

---

## Summary - UPDATED (Second Revert)

**First revert (e2156ec)** to a8a2224 did NOT fix the issue.

**Second revert** to commit **487129c "opencode works"** - the last known working state.

### Key Discovery:
The dconf keyboard settings were ADDED in commit a8a2224, which means they were NOT part of the working configuration! At commit 487129c, keyboard remapping was done **manually via GNOME Tweaks**, not via home-manager dconf settings.

---

## What Was Reverted (Second Revert to 487129c)

### 1. **configuration.nix** - Same as first revert
- All suspend/resume changes removed
- No system-level XKB options
- No power management settings

### 2. **home.nix** - MAJOR CHANGES from a8a2224

#### Removed Sections (that were added in a8a2224):
- **ALL dconf.settings** block (180+ lines!)
  - Removed keyboard XKB options from dconf
  - Removed GNOME keybindings
  - Removed mouse/touchpad settings
  - Removed window manager preferences
  - Removed all GNOME customizations

- **programs.fish** configuration
  - Removed fish shell declarative config
  - Fish config now managed manually via config files

- **programs.zoxide** configuration
  - Removed zoxide declarative config

#### What This Means:
At commit 487129c, keyboard remapping was done **manually via GNOME Tweaks UI**, NOT via home-manager dconf. The dconf settings added in a8a2224 may have been causing conflicts.

---

## Why This Should Fix The Issue

### The Problem (Updated Understanding):
1. **dconf keyboard settings** added in a8a2224 may be conflicting with GNOME's internal keyboard handling
2. **System-level XKB options** in `configuration.nix` were also added and conflicting
3. **Kernel changes** may have introduced regressions
4. The combination of declarative dconf + system XKB + kernel changes broke everything

### The Solution (Second Attempt):
1. **Remove ALL dconf keyboard settings** - go back to manual GNOME Tweaks
2. **Remove system-level XKB config** - no declarative keyboard config at all
3. **Remove kernel changes** - use default kernel
4. **Use GNOME Tweaks manually** to set keyboard remapping (as it was at 487129c)

---

## What You Lose By Reverting

### Suspend/Resume Fixes:
- ❌ AMD Ryzen AI 300 kernel parameters
- ❌ MediaTek WiFi power management fix
- ❌ AMD GPU VPE workarounds

**Impact**: Suspend/resume may not work properly. If this becomes an issue, we'll need to find alternative fixes that don't break keyboard input.

### WezTerm Autostart:
- ❌ WezTerm no longer starts automatically on login

**Impact**: You'll need to manually start WezTerm or use Super+T keybinding.

---

## Commits Affected

### Reverted Changes From:
- `c764360` - breaking changes (Dec 19, 2025)
- `360a73e` - fix: add system-level XKB options and switch to LTS kernel
- `390257a` - fix: remove boot.kernelPackages to restore working kernel
- `f6f5676` - fix: rollback flake.lock to working kernel 6.12.24
- `95429b2` - update
- `1ca22de` - reverted to old lock file

### First Revert (e2156ec) - FAILED:
- Reverted to `a8a2224` - updated project context
- **Result**: Keyboard still broken

### Second Revert (this commit) - Restored To:
- `487129c` - opencode works (ACTUAL WORKING STATE)
- This removes ALL dconf keyboard settings
- Keyboard remapping must be done manually via GNOME Tweaks

---

## Next Steps (Second Revert)

1. **Commit this revert**:
   ```bash
   git add -A
   git commit -m "revert: restore to 487129c - remove ALL dconf keyboard settings"
   ```

2. **Rebuild NixOS**:
   ```bash
   sudo nixos-rebuild switch --flake .#hamsa
   ```

3. **Reboot** to load the correct kernel and configuration

4. **Manually configure keyboard via GNOME Tweaks**:
   - Open GNOME Tweaks
   - Go to Keyboard & Mouse → Additional Layout Options
   - Set: Caps Lock → Esc
   - Set: Ctrl position → Swap Left Alt with Left Ctrl

5. **Test keyboard**:
   - Tab key in Neovim
   - Ctrl+Enter in Neovim
   - Left-Ctrl/Left-Alt swap

---

## If Suspend/Resume Becomes An Issue Later

We can try these alternatives that won't break keyboard:
1. Use `systemd` sleep hooks instead of kernel parameters
2. Create udev rules for WiFi power management
3. Use `tlp` or `auto-cpufreq` for power management
4. Investigate BIOS/firmware updates for Ryzen AI 300

---

## Files Modified

- `configuration.nix` - Reverted to a8a2224
- `home.nix` - Reverted to a8a2224
- `flake.lock` - Currently at 1ca22de (may need adjustment)

---

## Verification Checklist

After rebuild and reboot, verify:
- [ ] `uname -r` shows kernel version (should be from nixpkgs default)
- [ ] `gsettings get org.gnome.desktop.input-sources xkb-options` shows correct options
- [ ] `localectl status` shows NO xkb-options (system level)
- [ ] Tab works in Neovim
- [ ] Ctrl+Enter works in Neovim
- [ ] Left-Ctrl acts as Left-Alt
- [ ] Left-Alt acts as Left-Ctrl
- [ ] Caps Lock acts as Escape

---

**Report Generated**: December 19, 2025  
**First Revert Commit**: e2156ec (to a8a2224) - FAILED  
**Second Revert Commit**: To be created (to 487129c) - IN PROGRESS  
**Working State Restored From**: 487129c "opencode works"

---

## Important Note

After this revert, keyboard remapping will NOT be managed declaratively. You must:
1. Use GNOME Tweaks UI to set keyboard options manually
2. These settings will be stored in dconf by GNOME itself (not home-manager)
3. Do NOT try to manage keyboard settings via home-manager dconf - it causes conflicts
