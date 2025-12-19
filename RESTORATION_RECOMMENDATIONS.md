# Restoration Recommendations Report

**Date**: December 19, 2025  
**Root Cause**: Neovim configuration issue (autolist plugin remapping Tab key in markdown files)  
**NOT Related To**: Linux kernel, XKB configuration, or NixOS system settings  

---

## Executive Summary

The keyboard issues (Tab and Ctrl+Enter not working) were caused by **Neovim configuration**, specifically the autolist plugin remapping keys in markdown files. This means **all the NixOS system-level changes we reverted were unnecessary** and can be safely restored.

The wild goose chase led us to revert many useful improvements that had nothing to do with the actual problem.

---

## What Can Be Safely Restored

### ✅ HIGH PRIORITY - Restore Immediately

#### 1. **Suspend/Resume Fixes for Ryzen AI 300** (from commit c764360)
**Status**: Safe to restore  
**Reason**: These kernel parameters and power management settings have nothing to do with keyboard input

**Changes to restore in `configuration.nix`**:
```nix
# Use latest kernel for best Ryzen AI 300 series support
boot.kernelPackages = pkgs.linuxPackages_latest;

# Kernel parameters for Ryzen AI 300 suspend/resume
boot.kernelParams = [
  "amd_pstate=active"           # Enable AMD P-state driver
  "amdgpu.dcdebugmask=0x10"     # Disable problematic GPU features during suspend
  "rtc_cmos.use_acpi_alarm=1"   # Better ACPI wake support
];

# Disable MediaTek WiFi power management to fix suspend issues
boot.extraModprobeConfig = ''
  options snd_hda_intel power_save=0 power_save_controller=N
  options mt7921e disable_aspm=1
'';

# Power management configuration for Ryzen AI 300
powerManagement = {
  enable = true;
  cpuFreqGovernor = "ondemand";
};
```

**Benefits**:
- Fixes suspend/resume issues on Ryzen AI 300 hardware
- Better power management
- Prevents MediaTek WiFi timeout during suspend
- Prevents AMD GPU VPE reset failures

---

#### 2. **User Groups for ydotool** (from commit c764360)
**Status**: Safe to restore  
**Reason**: Required for dictation feature to work properly

**Changes to restore in `configuration.nix`**:
```nix
users.users.benjamin = {
  isNormalUser = true;
  description = "Benjamin";
  extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];  # Added input and uinput
};

# Enable uinput for ydotool (dictation feature)
hardware.uinput.enable = true;
```

**Benefits**:
- Allows whisper-dictate script to work properly
- Enables ydotool daemon to access /dev/uinput

---

#### 3. **WezTerm Autostart** (from commit a8a2224)
**Status**: Safe to restore  
**Reason**: Convenience feature, no impact on keyboard

**Changes to restore in `home.nix`**:
```nix
# Custom keybindings
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
  binding = "<Super>t";
  command = "wezterm";
  name = "Terminal";
};
```

**Benefits**:
- Super+T opens WezTerm terminal
- Consistent with your workflow

---

### ⚠️ MEDIUM PRIORITY - Consider Restoring

#### 4. **Declarative Fish Shell Configuration** (from commit a8a2224)
**Status**: Probably safe, but test carefully  
**Reason**: Unrelated to keyboard, but changes shell behavior

**Changes to restore in `home.nix`**:
```nix
# Fish shell configuration
programs.fish = {
  enable = true;

  interactiveShellInit = ''
    # Disable greeting message
    set fish_greeting

    # Remove Ctrl+T binding (used for NeoVim terminal)
    bind --erase --all \ct

    # Set prompt theme
    fish_config prompt choose scales

    # Run neofetch on start
    if type -q neofetch
      neofetch
    end
  '';

  shellInit = ''
    set -x EDITOR nvim
  '';
};

# Zoxide (smart cd replacement)
programs.zoxide = {
  enable = true;
  enableFishIntegration = true;
  options = [ "--cmd" "cd" ];  # Replace cd command
};
```

**Benefits**:
- Declarative shell configuration (version controlled)
- Consistent across rebuilds
- Removes manual oh-my-fish setup

**Risks**:
- May conflict with existing oh-my-fish configuration
- Test thoroughly before committing

---

#### 5. **GNOME Window Manager Keybindings** (from commit a8a2224)
**Status**: Safe to restore  
**Reason**: These are GNOME shortcuts, not keyboard input layer

**Changes to restore in `home.nix`**:
```nix
# Window manager keybindings (vim-style)
"org/gnome/desktop/wm/keybindings" = {
  close = [ "<Super>q" ];
  cycle-windows = [ "<Super>space" ];
  cycle-windows-backward = [ "<Shift><Super>space" ];
  maximize = [ "<Shift><Control>k" ];
  move-to-monitor-down = [ "<Shift><Super>j" ];
  move-to-monitor-left = [ "<Shift><Super>h" ];
  move-to-monitor-right = [ "<Shift><Super>l" ];
  move-to-monitor-up = [ "<Shift><Super>k" ];
  move-to-workspace-left = [ "<Shift><Alt>h" ];
  move-to-workspace-right = [ "<Shift><Alt>l" ];
  unmaximize = [ "<Shift><Control>j" ];
};

"org/gnome/mutter/keybindings" = {
  toggle-tiled-left = [ "<Shift><Control>h" ];
  toggle-tiled-right = [ "<Shift><Control>l" ];
};
```

**Benefits**:
- Vim-style window management
- Declarative (version controlled)
- Consistent across rebuilds

---

#### 6. **GNOME Interface Preferences** (from commit a8a2224)
**Status**: Safe to restore  
**Reason**: UI preferences, no impact on keyboard

**Changes to restore in `home.nix`**:
```nix
# Interface preferences
"org/gnome/desktop/interface" = {
  color-scheme = "prefer-dark";
  toolkit-accessibility = false;
};

# Mouse and touchpad
"org/gnome/desktop/peripherals/mouse" = {
  speed = 0.34188034188034178;
};
"org/gnome/desktop/peripherals/touchpad" = {
  speed = 0.48717948717948723;
  two-finger-scrolling-enabled = true;
};

# Window manager preferences
"org/gnome/desktop/wm/preferences" = {
  focus-mode = "sloppy";
};
```

**Benefits**:
- Dark mode preference
- Mouse/touchpad speed settings
- Sloppy focus (focus follows mouse)

---

### ❌ DO NOT RESTORE - These Were The Problem

#### 7. **System-Level XKB Options in configuration.nix**
**Status**: ALREADY ADDED (but harmless)  
**Current state**: We added `xkb.options = "caps:swapescape,ctrl:swap_lalt_lctl"` to configuration.nix

**Action**: Keep this - it's the correct way to set XKB options on NixOS

**Note**: The XKB options in configuration.nix are CORRECT and should stay. The problem was in Neovim, not here.

---

#### 8. **Keyboard XKB Options in dconf (home.nix)**
**Status**: CONFLICTING - Do not restore  
**Reason**: Setting XKB options in BOTH configuration.nix AND dconf causes conflicts

**DO NOT restore this from home.nix**:
```nix
# DO NOT ADD THIS - conflicts with configuration.nix
"org/gnome/desktop/input-sources" = {
  xkb-options = [ "lv3:ralt_switch" "caps:swapescape" "ctrl:swap_lalt_lctl" ];
};
```

**Why**: XKB options should be set in ONE place only:
- ✅ `configuration.nix` (system-level) - CORRECT
- ❌ `home.nix` dconf (user-level) - CONFLICTS

---

## Recommended Restoration Plan

### Phase 1: Immediate (High Priority)
1. ✅ Restore suspend/resume fixes (kernel params, power management)
2. ✅ Restore user groups for ydotool (input, uinput)
3. ✅ Restore WezTerm autostart keybinding

### Phase 2: Test and Verify (Medium Priority)
4. ⚠️ Test declarative Fish shell configuration
5. ⚠️ Restore GNOME window manager keybindings
6. ⚠️ Restore GNOME interface preferences

### Phase 3: Verify No Conflicts
7. ✅ Keep system-level XKB options in configuration.nix
8. ❌ Do NOT restore dconf XKB options in home.nix

---

## Implementation Steps

### Step 1: Create a restoration branch
```bash
cd ~/.dotfiles
git checkout -b restore-useful-changes
```

### Step 2: Cherry-pick the useful changes
```bash
# Get the suspend/resume fixes from c764360
git show c764360:configuration.nix > /tmp/c764360-config.nix
# Manually extract the suspend/resume section

# Get the dconf settings from a8a2224 (excluding keyboard XKB options)
git show a8a2224:home.nix > /tmp/a8a2224-home.nix
# Manually extract the useful dconf settings
```

### Step 3: Apply changes carefully
- Edit `configuration.nix` to add suspend/resume fixes
- Edit `configuration.nix` to add user groups
- Edit `home.nix` to add WezTerm keybinding
- Edit `home.nix` to add GNOME preferences (excluding XKB options)

### Step 4: Test rebuild
```bash
sudo nixos-rebuild switch --flake .#hamsa
```

### Step 5: Verify no keyboard issues
- Test Tab key in Neovim (all file types)
- Test Ctrl+Enter in Neovim
- Test keyboard remapping (Ctrl/Alt swap, Caps→Esc)

### Step 6: Commit and merge
```bash
git add -A
git commit -m "restore: add back useful changes that were unrelated to keyboard issue"
git checkout main
git merge restore-useful-changes
```

---

## What We Learned

### The Real Problem
- **Neovim autolist plugin** was remapping Tab key in markdown files
- This had NOTHING to do with:
  - Linux kernel version
  - XKB configuration
  - System-level keyboard settings
  - Hardware issues

### The Correct XKB Configuration
- XKB options should be set in `configuration.nix` (system-level)
- Do NOT set XKB options in both `configuration.nix` AND `home.nix` dconf
- GNOME will read system-level XKB options correctly

### What Was Unnecessarily Reverted
- Suspend/resume fixes for Ryzen AI 300
- Power management improvements
- User group additions for ydotool
- WezTerm autostart
- GNOME window manager keybindings
- GNOME interface preferences
- Declarative Fish shell configuration

---

## Files to Modify

### configuration.nix
- ✅ Add suspend/resume fixes (kernel params, power management)
- ✅ Add user groups (input, uinput)
- ✅ Keep XKB options (already added)

### home.nix
- ✅ Add WezTerm autostart keybinding
- ✅ Add GNOME window manager keybindings
- ✅ Add GNOME interface preferences
- ⚠️ Consider adding declarative Fish shell config
- ❌ Do NOT add dconf XKB options (conflicts with configuration.nix)

---

## Verification Checklist

After restoration, verify:
- [ ] Suspend/resume works properly
- [ ] ydotool daemon starts without permission errors
- [ ] Super+T opens WezTerm
- [ ] Tab key works in Neovim (all file types)
- [ ] Ctrl+Enter works in Neovim
- [ ] Keyboard remapping works (Ctrl/Alt swap, Caps→Esc)
- [ ] GNOME window manager shortcuts work
- [ ] Dark mode is enabled
- [ ] Mouse/touchpad speed is correct
- [ ] Focus follows mouse (sloppy focus)

---

**Report Generated**: December 19, 2025  
**Current Commit**: 4fdd679 "fix: remove hardcoded hostname (again)"  
**Recommended Action**: Restore useful changes that were unrelated to the keyboard issue
