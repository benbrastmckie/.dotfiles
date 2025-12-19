# Restoration Summary

**Date**: December 19, 2025  
**Commit**: Restoring useful changes after keyboard issue resolution

---

## What Was Restored

### ✅ High Priority Items (All Restored)

#### 1. Suspend/Resume Fixes for Ryzen AI 300
**File**: `configuration.nix`

**Changes**:
- Added `boot.kernelPackages = pkgs.linuxPackages_latest` for best hardware support
- Added kernel parameters:
  - `amd_pstate=active` - AMD P-state driver for better power management
  - `amdgpu.dcdebugmask=0x10` - Disable problematic GPU features during suspend
  - `rtc_cmos.use_acpi_alarm=1` - Better ACPI wake support
- Added `boot.extraModprobeConfig`:
  - Disable audio power saving (prevents pops)
  - Disable MediaTek WiFi ASPM (fixes suspend timeout)
- Added `powerManagement` section with `ondemand` CPU governor

**Benefits**:
- System suspend/resume should work properly
- Better power management on Ryzen AI 300
- Prevents WiFi timeout during suspend
- Prevents AMD GPU VPE reset failures

---

#### 2. User Groups for ydotool
**File**: `configuration.nix`

**Changes**:
- Added `input` and `uinput` to user groups
- Added `hardware.uinput.enable = true`

**Benefits**:
- ydotool daemon can access /dev/uinput
- Whisper dictation feature will work properly
- No more "Permission denied" errors for ydotool

---

#### 3. System-Level XKB Options
**File**: `configuration.nix`

**Changes**:
- Uncommented and set `xkb.options = "caps:swapescape,ctrl:swap_lalt_lctl"`

**Benefits**:
- Caps Lock ↔ Escape swap
- Left Ctrl ↔ Left Alt swap
- Applied at system level (correct approach)

---

#### 4. GNOME Settings via dconf
**File**: `home.nix`

**Changes Added**:
- **Interface preferences**: Dark mode, disable toolkit accessibility
- **Mouse/touchpad**: Custom speed settings, two-finger scrolling
- **Window manager**: Sloppy focus (focus follows mouse)
- **Window manager keybindings**: Vim-style shortcuts
  - `<Super>q` - Close window
  - `<Super>space` - Cycle windows
  - `<Shift><Control>h/j/k/l` - Tile/maximize/unmaximize
  - `<Shift><Super>h/j/k/l` - Move to monitor
  - `<Shift><Alt>h/l` - Move to workspace
- **Mutter keybindings**: Tile left/right with Shift+Ctrl+h/l
- **Media keys**: Custom shortcuts
  - `<Super>t` - WezTerm terminal
  - `<Super>f` - Files (Nautilus)
  - `<Super>b` - Browser
  - `<Super>backslash` - Settings
  - `<Super>grave` - Lock screen

**Benefits**:
- Declarative GNOME configuration (version controlled)
- Vim-style window management
- WezTerm autostart with Super+T
- Consistent across rebuilds

---

## What Was NOT Restored

### ❌ Keyboard XKB Options in dconf
**Reason**: Would conflict with system-level XKB options in configuration.nix

**Correct approach**: XKB options set in ONE place only (configuration.nix)

---

### ⚠️ Declarative Fish Shell Configuration
**Status**: Not restored yet  
**Reason**: May conflict with existing oh-my-fish setup

**Recommendation**: Test separately in a future commit

---

## Files Modified

1. **configuration.nix** (+41 lines)
   - Suspend/resume fixes
   - Power management
   - User groups
   - XKB options

2. **home.nix** (+61 lines)
   - GNOME dconf settings
   - Window manager keybindings
   - Custom shortcuts

3. **RESTORATION_RECOMMENDATIONS.md** (new file)
   - Detailed analysis of what to restore

4. **RESTORATION_SUMMARY.md** (this file)
   - Summary of what was actually restored

---

## Testing Checklist

After rebuild and reboot, verify:

### Keyboard (Most Important)
- [ ] Tab key works in Neovim (all file types)
- [ ] Ctrl+Enter works in Neovim
- [ ] Left-Ctrl acts as Left-Alt
- [ ] Left-Alt acts as Left-Ctrl
- [ ] Caps Lock acts as Escape

### Suspend/Resume
- [ ] System suspends without errors
- [ ] System resumes properly
- [ ] WiFi reconnects after resume
- [ ] No GPU errors in journal

### ydotool/Dictation
- [ ] ydotool daemon starts without permission errors
- [ ] `systemctl --user status ydotool` shows active
- [ ] whisper-dictate script works

### GNOME Shortcuts
- [ ] Super+T opens WezTerm
- [ ] Super+Q closes window
- [ ] Super+Space cycles windows
- [ ] Shift+Ctrl+H/L tiles windows
- [ ] Shift+Super+H/J/K/L moves to monitor
- [ ] Shift+Alt+H/L moves to workspace

### GNOME Settings
- [ ] Dark mode is enabled
- [ ] Mouse speed is correct
- [ ] Touchpad speed is correct
- [ ] Focus follows mouse (sloppy focus)

---

## Next Steps

1. **Commit these changes**:
   ```bash
   git add -A
   git commit -m "restore: add back useful changes unrelated to keyboard issue"
   ```

2. **Rebuild NixOS**:
   ```bash
   sudo nixos-rebuild switch --flake .#hamsa
   ```

3. **Reboot** to apply kernel changes and power management

4. **Test everything** using the checklist above

5. **If all tests pass**, consider restoring Fish shell configuration in a separate commit

---

## Lessons Learned

1. **Root cause was Neovim config**, not NixOS system settings
2. **XKB options should be set at system level** (configuration.nix), not user level (dconf)
3. **Suspend/resume fixes are independent** of keyboard issues
4. **Always test one change at a time** to isolate issues
5. **Document everything** for future reference

---

**Report Generated**: December 19, 2025  
**Status**: Ready to commit and rebuild
