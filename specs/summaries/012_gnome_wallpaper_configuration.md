# Summary 012: GNOME Desktop and GDM Login Wallpaper Configuration

**Date**: 2025-12-20  
**Status**: Ready for Implementation  
**Related Plan**: [012_gnome_wallpaper_configuration.md](../plans/012_gnome_wallpaper_configuration.md)  
**Related Report**: [018_nixos_gnome_wallpaper_setup.md](../reports/018_nixos_gnome_wallpaper_setup.md)

## Overview

This plan sets up declarative wallpaper management for both GNOME desktop and GDM login screen using the riverside nighttime scene image provided by the user.

## What Was Created

1. **Plan Document**: `specs/plans/012_gnome_wallpaper_configuration.md`
   - Complete implementation guide
   - Step-by-step instructions
   - Testing checklist
   - Rollback procedures

2. **Research Report**: `specs/reports/018_nixos_gnome_wallpaper_setup.md`
   - Technical research findings
   - Comparison of approaches
   - Troubleshooting guide
   - Complete configuration examples

3. **Wallpapers Directory**: `wallpapers/` (created, awaiting image)

## Quick Start

### Prerequisites

**IMPORTANT**: Save the riverside image first!

The image from the chat needs to be saved to:
```bash
~/.dotfiles/wallpapers/riverside.jpg
```

You can do this by:
1. Right-click the image in the chat
2. Save as `riverside.jpg`
3. Move it to `~/.dotfiles/wallpapers/riverside.jpg`

Or download it from wherever you have it stored.

### Implementation Steps

Once the image is saved, follow these steps:

#### 1. Update configuration.nix

Add after line 265 (in `environment.systemPackages`):

```nix
# Custom wallpaper package
(pkgs.runCommand "custom-wallpaper" {} ''
  mkdir -p $out/share/backgrounds/custom
  cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/riverside.jpg
'')
```

Add after line 120 (after GDM configuration):

```nix
# Set GDM login screen background
environment.etc."gdm/greeter.dconf-defaults".text = ''
  [org/gnome/desktop/background]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
  picture-options='zoom'
  
  [org/gnome/desktop/screensaver]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
'';
```

#### 2. Update home.nix

Add to `dconf.settings` (around line 38, after the interface section):

```nix
# Desktop background
"org/gnome/desktop/background" = {
  picture-uri = "file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg";
  picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg";
  picture-options = "zoom";
};

# Lock screen background
"org/gnome/desktop/screensaver" = {
  picture-uri = "file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg";
  picture-options = "zoom";
};
```

#### 3. Apply Changes

```bash
cd ~/.dotfiles

# Rebuild system (for GDM background)
sudo nixos-rebuild switch --flake .

# This will also apply home-manager changes if integrated in flake
# Otherwise, run separately:
# home-manager switch --flake .#benjamin
```

#### 4. Verify

```bash
# Check desktop background
gsettings get org.gnome.desktop.background picture-uri-dark

# Check file exists
ls -la /run/current-system/sw/share/backgrounds/custom/riverside.jpg

# Visual check: Log out to see GDM login screen
```

## What This Achieves

✅ **Desktop background**: Shows riverside image  
✅ **Lock screen**: Shows riverside image (Super+Grave to test)  
✅ **GDM login**: Shows riverside image (log out to test)  
✅ **Persistent**: Survives system rebuilds and reboots  
✅ **Declarative**: Fully managed in configuration files  
✅ **Reproducible**: Works on fresh system installs

## File Locations

| What | Where |
|------|-------|
| Source image | `~/.dotfiles/wallpapers/riverside.jpg` |
| Desktop config | `~/.dotfiles/home.nix` (dconf.settings) |
| GDM config | `~/.dotfiles/configuration.nix` (environment.etc) |
| Wallpaper package | `~/.dotfiles/configuration.nix` (systemPackages) |
| Installed image | `/run/current-system/sw/share/backgrounds/custom/riverside.jpg` |

## Configuration Summary

### configuration.nix Changes

**Location 1**: Add to `environment.systemPackages` (around line 265)
```nix
(pkgs.runCommand "custom-wallpaper" {} ''
  mkdir -p $out/share/backgrounds/custom
  cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/riverside.jpg
'')
```

**Location 2**: Add after GDM configuration (around line 120)
```nix
environment.etc."gdm/greeter.dconf-defaults".text = ''
  [org/gnome/desktop/background]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
  picture-options='zoom'
  
  [org/gnome/desktop/screensaver]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
'';
```

### home.nix Changes

**Location**: Add to `dconf.settings` (around line 38)
```nix
"org/gnome/desktop/background" = {
  picture-uri = "file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg";
  picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg";
  picture-options = "zoom";
};

"org/gnome/desktop/screensaver" = {
  picture-uri = "file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg";
  picture-options = "zoom";
};
```

## Troubleshooting

### Desktop background not showing
```bash
# Check if file exists
ls -la /run/current-system/sw/share/backgrounds/custom/riverside.jpg

# Check dconf setting
dconf read /org/gnome/desktop/background/picture-uri-dark

# Reapply home-manager
home-manager switch --flake ~/.dotfiles#benjamin

# Restart GNOME Shell: Alt+F2, type 'r', Enter
```

### GDM login still shows default
```bash
# Check GDM config
cat /etc/gdm/greeter.dconf-defaults

# Restart GDM
sudo systemctl restart gdm

# Or reboot
sudo reboot
```

### Image looks wrong (stretched/cropped)
Try different `picture-options`:
- `"zoom"` - Fill screen, crop if needed (default)
- `"scaled"` - Fit screen, maintain aspect ratio
- `"centered"` - No scaling

## Next Steps

1. **Save the image** to `~/.dotfiles/wallpapers/riverside.jpg`
2. **Update configuration files** as shown above
3. **Rebuild system** with `sudo nixos-rebuild switch --flake .`
4. **Test all three contexts**: desktop, lock screen, GDM login
5. **Commit changes** to git

## Git Commit Message Suggestion

```
feat: add declarative GNOME wallpaper configuration

- Add riverside.jpg wallpaper to wallpapers/ directory
- Configure desktop background via home-manager dconf
- Configure GDM login background via system dconf defaults
- Configure lock screen background
- Wallpaper persists across rebuilds and is fully reproducible

Closes: #012
```

## References

- **Plan**: [specs/plans/012_gnome_wallpaper_configuration.md](../plans/012_gnome_wallpaper_configuration.md)
- **Research**: [specs/reports/018_nixos_gnome_wallpaper_setup.md](../reports/018_nixos_gnome_wallpaper_setup.md)
- **Home Manager dconf**: https://nix-community.github.io/home-manager/options.html#opt-dconf.settings
- **GNOME Background Schema**: https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas

## Notes

- Using same image for both light and dark mode (as requested)
- Image stored in Nix store for immutability
- Stable path via system profile symlink
- GDM configuration requires system rebuild (not just home-manager)
- Lock screen uses separate schema but same image
