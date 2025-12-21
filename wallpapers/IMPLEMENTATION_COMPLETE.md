# Wallpaper Configuration - Implementation Complete ✅

**Date**: 2025-12-20  
**Status**: Ready for rebuild (pending image)

## What Was Implemented

### 1. Configuration Files Updated

#### configuration.nix
- **Line 129-139**: Added GDM login screen background configuration
  - Sets background for GDM greeter
  - Sets screensaver background for login screen
  
- **Line 398-403**: Added custom wallpaper package
  - Copies riverside.jpg to Nix store
  - Installs to `/run/current-system/sw/share/backgrounds/custom/`

#### home.nix
- **Line 45-53**: Added desktop background configuration
  - Sets `picture-uri` for light mode
  - Sets `picture-uri-dark` for dark mode
  - Uses "zoom" scaling option
  
- **Line 55-59**: Added lock screen background configuration
  - Sets screensaver background
  - Uses same image as desktop

### 2. Documentation Created

- `specs/plans/012_gnome_wallpaper_configuration.md` (10KB)
  - Complete implementation plan
  - Step-by-step instructions
  - Testing checklist

- `specs/reports/018_nixos_gnome_wallpaper_setup.md` (14KB)
  - Technical research findings
  - Troubleshooting guide
  - Configuration examples

- `specs/summaries/012_gnome_wallpaper_configuration.md` (7KB)
  - Quick reference
  - Implementation summary

- `wallpapers/README.md`
  - Directory documentation
  - Usage instructions

- `wallpapers/SETUP_INSTRUCTIONS.md`
  - Quick setup guide
  - Copy-paste ready snippets

- `wallpapers/verify-setup.sh`
  - Automated verification script
  - Pre-rebuild checks

## Current Status

✅ Configuration files updated  
✅ Documentation complete  
✅ Verification script ready  
⚠️  **Waiting for image**: `riverside.jpg`

## Next Steps

### 1. Save the Image

Save the riverside image from the chat to:
```
~/.dotfiles/wallpapers/riverside.jpg
```

### 2. Verify Setup

Run the verification script:
```bash
cd ~/.dotfiles/wallpapers
./verify-setup.sh
```

### 3. Rebuild System

Apply the configuration:
```bash
cd ~/.dotfiles
sudo nixos-rebuild switch --flake .
```

### 4. Test Results

After rebuild:

**Desktop Background**:
```bash
gsettings get org.gnome.desktop.background picture-uri-dark
# Should output: 'file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
```

**Installed File**:
```bash
ls -la /run/current-system/sw/share/backgrounds/custom/riverside.jpg
# Should show the file with proper permissions
```

**Visual Tests**:
- Desktop: Should show riverside image immediately
- Lock screen: Press `Super+Grave` to lock and verify
- GDM login: Log out to see login screen background

## Configuration Details

### File Paths

| Component | Path |
|-----------|------|
| Source image | `~/.dotfiles/wallpapers/riverside.jpg` |
| Nix store | `/nix/store/xxx-custom-wallpaper/share/backgrounds/custom/riverside.jpg` |
| System symlink | `/run/current-system/sw/share/backgrounds/custom/riverside.jpg` |

### dconf Settings

**Desktop** (`home.nix`):
- `org.gnome.desktop.background.picture-uri`
- `org.gnome.desktop.background.picture-uri-dark`
- `org.gnome.desktop.background.picture-options`

**Lock Screen** (`home.nix`):
- `org.gnome.desktop.screensaver.picture-uri`
- `org.gnome.desktop.screensaver.picture-options`

**GDM Login** (`configuration.nix`):
- `/etc/gdm/greeter.dconf-defaults`
- Sets same dconf keys for gdm user

## Troubleshooting

### Desktop background not showing

```bash
# Reapply home-manager
home-manager switch --flake ~/.dotfiles#benjamin

# Restart GNOME Shell
# Press Alt+F2, type 'r', press Enter
```

### GDM login background not showing

```bash
# Check GDM config file
cat /etc/gdm/greeter.dconf-defaults

# Restart GDM service
sudo systemctl restart gdm

# Or reboot
sudo reboot
```

### Image file not found during build

```bash
# Verify image exists
ls -la ~/.dotfiles/wallpapers/riverside.jpg

# Check file permissions
chmod 644 ~/.dotfiles/wallpapers/riverside.jpg
```

## Git Commit

Once verified and working, commit the changes:

```bash
cd ~/.dotfiles
git add wallpapers/ configuration.nix home.nix specs/
git commit -m "feat: add declarative GNOME wallpaper configuration

- Add riverside.jpg wallpaper to wallpapers/ directory
- Configure desktop background via home-manager dconf
- Configure GDM login background via system dconf defaults
- Configure lock screen background
- Wallpaper persists across rebuilds and is fully reproducible

Implements: specs/plans/012_gnome_wallpaper_configuration.md"
```

## References

- Plan: `specs/plans/012_gnome_wallpaper_configuration.md`
- Report: `specs/reports/018_nixos_gnome_wallpaper_setup.md`
- Summary: `specs/summaries/012_gnome_wallpaper_configuration.md`
- Quick Setup: `wallpapers/SETUP_INSTRUCTIONS.md`

## Notes

- Same image used for both light and dark mode (as requested)
- Image stored in Nix store for immutability
- Stable path via system profile symlink
- GDM configuration requires system rebuild
- Desktop/lock screen can be updated with home-manager only
