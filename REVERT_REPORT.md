# Revert Report: Keyboard Issues Fix

**Date**: December 19, 2025  
**Issue**: Tab key, Ctrl+Enter, and keyboard remapping not working  
**Root Cause**: Changes introduced in commit c764360 "breaking changes"  
**Solution**: Revert configuration files to commit a8a2224 "updated project context"

---

## Summary

Reverted `configuration.nix` and `home.nix` to their state at commit **a8a2224** (before the "breaking changes" commit) to restore working keyboard functionality.

---

## What Was Reverted

### 1. **configuration.nix** - Removed ALL suspend/resume changes

#### Removed Sections:
- **Suspend/Resume Fix block** (lines 15-38)
  - Removed `boot.kernelPackages` setting (was causing kernel issues)
  - Removed `boot.kernelParams` for AMD Ryzen AI 300
  - Removed WiFi power management fix (`options mt7921e disable_aspm=1`)

- **System-level XKB options** (line 217)
  - Removed: `xkb.options = "lv3:ralt_switch,caps:swapescape,ctrl:swap_lalt_lctl";`
  - This was conflicting with home-manager dconf settings

- **Power management block** (lines 260-264)
  - Removed `powerManagement.enable = true`
  - Removed `powerManagement.cpuFreqGovernor = "ondemand"`

#### What Remains in configuration.nix:
- Audio static/EMI fix (unchanged)
- All other system configuration (unchanged)
- XKB layout set to "us" only (no options)

### 2. **home.nix** - Removed autostart changes

#### Removed Sections:
- **WezTerm autostart** (lines 540-548)
  - Removed `xdg.configFile."autostart/wezterm.desktop"`
  - WezTerm will no longer auto-start on login

#### Minor Changes:
- Fish greeting: Changed from `set -g fish_greeting ""` back to `set fish_greeting`

#### What Remains in home.nix:
- **dconf keyboard settings** (KEPT - this is what was working!)
  - `xkb-options = [ "lv3:ralt_switch" "caps:swapescape" "ctrl:swap_lalt_lctl" ]`
  - These settings in dconf work correctly when NOT overridden by system-level config

---

## Why This Fixes The Issue

### The Problem:
1. **System-level XKB options** in `configuration.nix` were **overriding** the home-manager dconf settings
2. **Kernel changes** introduced input handling regressions with QMK keyboards
3. The combination broke keyboard input completely

### The Solution:
1. **Remove system-level XKB config** - let home-manager dconf handle it
2. **Remove kernel changes** - use default kernel from nixpkgs
3. **Keep dconf settings** - these work correctly on their own

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

### Restored To:
- `a8a2224` - updated project context (WORKING STATE)

---

## Next Steps

1. **Commit this revert**:
   ```bash
   git add -A
   git commit -m "revert: restore working keyboard configuration from a8a2224"
   ```

2. **Rebuild NixOS**:
   ```bash
   sudo nixos-rebuild switch --flake .#hamsa
   ```

3. **Reboot** to load the correct kernel and configuration

4. **Test keyboard**:
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
**Revert Commit**: To be created  
**Working State Restored From**: a8a2224 "updated project context"
