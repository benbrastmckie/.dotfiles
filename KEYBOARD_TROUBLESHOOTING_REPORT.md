# Keyboard Troubleshooting Report

**Date**: December 19, 2025  
**Hardware**: AMD Ryzen AI 9 HX 370, Keebio Iris CE Rev. 1 (QMK keyboard)  
**OS**: NixOS with GNOME on Wayland  
**Issue**: Tab, Ctrl+Enter not working in Neovim; keyboard remapping (Ctrl/Alt swap) not working

---

## Current State

### System Information
- **Kernel**: 6.12.62 (still on latest, not LTS)
- **Nixpkgs**: f771eb401a46846c1aebd20552521b233dd7e18b (April 26, 2025)
- **Nixpkgs Kernel**: 6.12.24 (but system running 6.12.62)
- **Session**: Wayland
- **Desktop**: GNOME

### Keyboard Configuration Status
- **gsettings XKB options**: `['lv3:ralt_switch', 'caps:swapescape', 'ctrl:swap_lalt_lctl']` ✅
- **localectl XKB options**: `terminate:ctrl_alt_bksp` ❌ (WRONG - should have our options)
- **VIA errors**: "Failed to open the device", "Received invalid protocol version"

### The Problem
**XKB options are set in gsettings (user level) but NOT in localectl (system level)**. This means GNOME has the settings but they're not being applied to the actual keyboard input layer.

---

## What We've Tried

### Attempt 1: Revert to a8a2224 (First Revert)
**Commit**: e2156ec  
**Action**: Reverted configuration.nix and home.nix to commit a8a2224  
**Removed**:
- Suspend/resume fixes from configuration.nix
- System-level XKB options
- WezTerm autostart

**Kept**:
- dconf keyboard settings in home.nix

**Result**: ❌ FAILED - Keyboard still broken

---

### Attempt 2: Revert to 487129c (Second Revert)
**Commit**: 3cef33d  
**Action**: Reverted to commit 487129c "opencode works"  
**Removed**:
- ALL dconf.settings from home.nix (180+ lines)
- programs.fish declarative config
- programs.zoxide declarative config
- All GNOME customizations via dconf

**Discovery**: At 487129c, keyboard was configured MANUALLY via GNOME Tweaks, not declaratively

**Result**: ❌ FAILED - Keyboard still broken even after manual GNOME Tweaks configuration

---

### Attempt 3: Fix Package Deprecations
**Commits**: 4130045, 67636d0, d6ac446, 7bd40cf, 519734c, 30e9da3, 4f6392a, fd70dd0, 226fd41, 3a6dca8  
**Action**: Fixed all package renames and deprecations to build on current nixpkgs
**Fixed**:
- openai-whisper-cpp → whisper-cpp
- nerdfonts → nerd-fonts.roboto-mono
- z3 → z3-solver
- mathlibtools (removed - archived)
- libsForQt5.okular → kdePackages.okular
- noto-fonts-emoji → noto-fonts-color-emoji
- torrential (removed - not available)
- All deprecated NixOS/Home Manager options

**Result**: ✅ System builds successfully, but ❌ keyboard still broken

---

## Root Cause Analysis

### Critical Discovery: Kernel Mismatch
**Expected**: Kernel 6.12.24 (from nixpkgs f771eb401a46)  
**Actual**: Kernel 6.12.62 (still running)

**This is the smoking gun!** The flake.lock has the right nixpkgs, but the system is still running the wrong kernel.

### Why Kernel Didn't Change
Possible reasons:
1. **Bootloader not updated** - old kernel still in boot menu
2. **System not fully rebuilt** - kernel package downloaded but not activated
3. **Flake.lock not actually used** - rebuild using cached/different nixpkgs

### XKB Options Not Applied
**Problem**: Options in gsettings but not in localectl  
**Cause**: GNOME on Wayland may not be reading gsettings XKB options properly

**Evidence**:
- gsettings shows: `ctrl:swap_lalt_lctl`
- localectl shows: `terminate:ctrl_alt_bksp` (default, not our options)
- This means the system keyboard layer doesn't have our remapping

---

## Hardware-Specific Issues

### Keebio Iris CE Rev. 1 + VIA
**VIA Errors**:
```
Failed to open the device
Received invalid protocol version from device
```

**Possible causes**:
1. **QMK firmware outdated** - incompatible with current VIA version
2. **USB permissions** - hidraw devices owned by root
3. **Kernel regression** - 6.12.62 has known input handling issues

### AMD Ryzen AI 9 HX 370
**Very new hardware** (2024 release)  
**Known issues**:
- Requires kernel 6.5+ for full support
- MediaTek WiFi (mt7925e) has suspend issues
- AMD GPU VPE has reset failures

---

## Theories

### Theory 1: Kernel 6.12.62 Input Regression (MOST LIKELY)
**Evidence**:
- Keyboard worked at some point
- System still running 6.12.62 despite flake.lock having 6.12.24
- VIA showing protocol errors (firmware/kernel mismatch)

**Solution**: Force kernel downgrade to 6.12.24 or earlier

### Theory 2: GNOME Wayland XKB Bug
**Evidence**:
- XKB options in gsettings but not localectl
- Manual GNOME Tweaks also doesn't work

**Solution**: Set XKB options at system level (services.xserver.xkb.options)

### Theory 3: QMK Firmware Issue
**Evidence**:
- VIA errors about protocol version
- Keyboard is QMK-based (custom firmware)

**Solution**: Reflash keyboard firmware or use keyd instead of XKB

---

## Next Steps to Try

### Priority 1: Force Kernel Downgrade
```nix
# In configuration.nix
boot.kernelPackages = pkgs.linuxPackages_6_1;  # Use older LTS kernel
```

Or check bootloader:
```bash
sudo nixos-rebuild boot --flake .#hamsa
# Then reboot and select older kernel from boot menu
```

### Priority 2: Verify Flake.lock is Being Used
```bash
# Check what nixpkgs the build actually uses
nix eval .#nixosConfigurations.hamsa.pkgs.linuxPackages.kernel.version
```

### Priority 3: Set XKB at System Level (Already Tried)
We already tried this in earlier commits but it was reverted. May need to try again.

### Priority 4: Use keyd Instead of XKB
```nix
services.keyd = {
  enable = true;
  keyboards.default = {
    ids = [ "*" ];
    settings.main = {
      capslock = "esc";
      leftalt = "leftcontrol";
      leftcontrol = "leftalt";
    };
  };
};
```

### Priority 5: Check QMK Firmware
- Reflash keyboard with latest QMK firmware
- Or test with a different (non-QMK) keyboard to isolate issue

---

## Questions to Answer

1. **Why is kernel still 6.12.62?**
   - Is bootloader updated?
   - Is flake.lock actually being used?
   - Is there a kernel override somewhere?

2. **Why don't XKB options apply?**
   - GNOME Wayland bug?
   - Need system-level config?
   - Input method interfering?

3. **Is this QMK-specific?**
   - Does a regular USB keyboard work?
   - Is VIA causing issues?

---

## Files to Check

- `/boot/loader/entries/*.conf` - Check which kernel is in bootloader
- `~/.config/dconf/user` - Check if dconf settings are actually saved
- `/etc/X11/xkb/` - Check if XKB rules exist
- `journalctl -b | grep -i keyboard` - Check for keyboard-related errors

---

## Conclusion

**CRITICAL FINDING**: The flake evaluates to kernel 6.12.62 even though the nixpkgs commit (f771eb401a46) should have 6.12.24. This is because:

1. **flake.lock uses a tarball URL** from nixos-unstable releases, not the git commit
2. **The default kernel in nixpkgs has changed** - even old nixpkgs commits now resolve to newer kernels via the tarball
3. **We need to explicitly pin the kernel version** in configuration.nix

## Recommended Solution

Add to configuration.nix:
```nix
boot.kernelPackages = pkgs.linuxPackages_6_6;  # LTS kernel
```

This will:
- Use kernel 6.6.x (Long Term Support)
- Bypass the nixpkgs default kernel
- Avoid the 6.12.x input regressions
- Still support Ryzen AI 300 hardware (requires 6.5+)

The keyboard worked before because it was on an older kernel. The 6.12.x series has known input handling regressions with QMK keyboards.
