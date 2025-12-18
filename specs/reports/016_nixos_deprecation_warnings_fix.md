# Research Report: NixOS Flake Deprecation Warnings Fix
Date: 2025-12-18

## Question/Problem
During `nixos-install --flake ./#hamsa`, several deprecation warnings were emitted indicating that option names have been renamed in recent NixOS/Home Manager versions. Additionally, a security warning about `/boot` mount permissions was shown.

## Findings

### Deprecation Warnings Summary

The warnings fall into three categories:

#### 1. Home Manager Git Options (home.nix:15-19)
```
programs.git.userEmail → programs.git.settings.user.email
programs.git.userName  → programs.git.settings.user.name
```

#### 2. Home Manager Mako Options (home.nix:602-611)
```
services.mako.defaultTimeout  → services.mako.settings.default-timeout
services.mako.maxIconSize     → services.mako.settings.max-icon-size
services.mako.icons           → services.mako.settings.icons
services.mako.borderColor     → services.mako.settings.border-color
services.mako.borderSize      → services.mako.settings.border-size
services.mako.textColor       → services.mako.settings.text-color
services.mako.backgroundColor → services.mako.settings.background-color
```

#### 3. NixOS System Options (configuration.nix)
```
services.xserver.desktopManager.gnome.enable           → services.desktopManager.gnome.enable
services.xserver.desktopManager.gnome.extraGSettingsOverrides → services.desktopManager.gnome.extraGSettingsOverrides
services.xserver.displayManager.gdm.enable             → services.displayManager.gdm.enable
services.xserver.displayManager.gdm.wayland            → services.displayManager.gdm.wayland
hardware.pulseaudio                                    → services.pulseaudio
```

#### 4. Security Warning
```
Mount point '/boot' which backs the random seed file is world accessible
Random seed file '/boot/loader/.#bootctlrandom-seedfa76792ecc31b323' is world accessible
```

## Fixes Required

### Fix 1: Update home.nix Git Configuration (Lines 15-19)

**Current:**
```nix
programs.git = {
  enable = true;
  userName = "benbrastmckie";
  userEmail = "benbrastmckie@gmail.com";
};
```

**Updated:**
```nix
programs.git = {
  enable = true;
  settings.user = {
    name = "benbrastmckie";
    email = "benbrastmckie@gmail.com";
  };
};
```

### Fix 2: Update home.nix Mako Configuration (Lines 602-611)

**Current:**
```nix
services.mako = {
  enable = true;
  defaultTimeout = 5000;
  backgroundColor = "#2e3440";
  textColor = "#eceff4";
  borderColor = "#5e81ac";
  borderSize = 2;
  icons = true;
  maxIconSize = 64;
};
```

**Updated:**
```nix
services.mako = {
  enable = true;
  settings = {
    default-timeout = 5000;
    background-color = "#2e3440";
    text-color = "#eceff4";
    border-color = "#5e81ac";
    border-size = 2;
    icons = true;
    max-icon-size = 64;
  };
};
```

### Fix 3: Update configuration.nix Display Manager and Desktop Options

**Current (Lines 107-125):**
```nix
services.xserver = {
  enable = true;

  displayManager = {
    gdm = {
      enable = true;
      wayland = true;
    };
  };

  desktopManager.gnome = {
    enable = true;
    extraGSettingsOverrides = ''
      [org.gnome.desktop.interface]
      enable-hot-corners=false
    '';
  };
};
```

**Updated:**
```nix
services.xserver.enable = true;

services.displayManager.gdm = {
  enable = true;
  wayland = true;
};

services.desktopManager.gnome = {
  enable = true;
  extraGSettingsOverrides = ''
    [org.gnome.desktop.interface]
    enable-hot-corners=false
  '';
};
```

### Fix 4: Update configuration.nix PulseAudio Option (Line 217)

**Current:**
```nix
hardware.pulseaudio.enable = false;
```

**Updated:**
```nix
services.pulseaudio.enable = false;
```

### Fix 5: Update Blueman Conditional (Line 215)

After moving GNOME options, update the conditional reference:

**Current:**
```nix
services.blueman.enable = lib.mkIf (!config.services.xserver.desktopManager.gnome.enable) true;
```

**Updated:**
```nix
services.blueman.enable = lib.mkIf (!config.services.desktopManager.gnome.enable) true;
```

### Fix 6: /boot Mount Permissions (Security Warning)

This warning indicates that `/boot` is mounted with world-readable permissions, which could expose the random seed file used by systemd-boot.

**Location:** `hosts/hamsa/hardware-configuration.nix` (Lines 21-25)

**Current:**
```nix
fileSystems."/boot" =
  { device = "/dev/disk/by-uuid/E7D9-1A60";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
```

**Updated:**
```nix
fileSystems."/boot" =
  { device = "/dev/disk/by-uuid/E7D9-1A60";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
```

The change from `0022` to `0077` restricts access:
- `fmask=0077`: files are 0600 (owner read/write only)
- `dmask=0077`: directories are 0700 (owner access only)

Note: You'll also want to apply this fix to other hosts (`nandi`, `usb-installer`) for consistency.

## Files to Modify

| File | Lines | Changes |
|------|-------|---------|
| `home.nix` | 15-19 | Update git options to use `settings.user.*` |
| `home.nix` | 602-611 | Update mako options to use `settings.*` |
| `configuration.nix` | 107-125 | Move gdm/gnome options out of `services.xserver` |
| `configuration.nix` | 215 | Update blueman conditional |
| `configuration.nix` | 217 | Change `hardware.pulseaudio` to `services.pulseaudio` |
| `hosts/hamsa/hardware-configuration.nix` | 21-25 | Change `/boot` mount options from `0022` to `0077` |
| `hosts/nandi/hardware-configuration.nix` | varies | Apply same `/boot` mount fix |
| `hosts/usb-installer/hardware-configuration.nix` | varies | Apply same `/boot` mount fix |

## Recommendation

Apply all fixes to eliminate deprecation warnings. The warnings indicate these options will be removed in future NixOS releases. Fixing them now ensures forward compatibility.

Priority order:
1. **High**: Git and Mako options (simple changes, no functional impact)
2. **High**: Display manager and desktop manager options (deprecated paths)
3. **Medium**: PulseAudio option rename (simple change)
4. **Medium**: /boot security (depends on your security requirements)

## Testing Strategy

After making changes:
```bash
# Test configuration builds without errors
nixos-rebuild dry-build --flake .#hamsa

# If successful, apply changes
sudo nixos-rebuild switch --flake .#hamsa

# For Home Manager changes
home-manager switch --flake .#benjamin
```

## References

- [NixOS 24.11 Release Notes](https://nixos.org/manual/nixos/stable/release-notes.html)
- [Home Manager Options](https://nix-community.github.io/home-manager/options.xhtml)
- [systemd-boot Random Seed Security](https://systemd.io/RANDOM_SEEDS/)
