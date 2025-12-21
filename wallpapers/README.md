# Wallpapers Directory

This directory contains wallpaper images used for GNOME desktop and GDM login screen backgrounds.

## Current Wallpapers

### riverside.jpg
**Status**: ⚠️ **NEEDS TO BE ADDED**

**Description**: Nighttime riverside scene from India with illuminated buildings reflected in water and a campfire in the foreground.

**Usage**:
- GNOME desktop background
- GDM login screen background
- Lock screen background

**How to Add**:
1. Save the riverside image from the chat/download
2. Name it `riverside.jpg`
3. Place it in this directory: `~/.dotfiles/wallpapers/riverside.jpg`

**Configuration**:
- Configured in `configuration.nix` (GDM login)
- Configured in `home.nix` (desktop and lock screen)
- See: `specs/plans/012_gnome_wallpaper_configuration.md`

## Adding New Wallpapers

To add a new wallpaper:

1. **Add the image file** to this directory
   ```bash
   cp /path/to/new-wallpaper.jpg ~/.dotfiles/wallpapers/
   ```

2. **Update configuration.nix** (for GDM login):
   ```nix
   # In the custom-wallpaper package
   cp ${./wallpapers/new-wallpaper.jpg} $out/share/backgrounds/custom/new-wallpaper.jpg
   
   # In environment.etc."gdm/greeter.dconf-defaults"
   picture-uri='file:///run/current-system/sw/share/backgrounds/custom/new-wallpaper.jpg'
   ```

3. **Update home.nix** (for desktop):
   ```nix
   "org/gnome/desktop/background" = {
     picture-uri = "file:///run/current-system/sw/share/backgrounds/custom/new-wallpaper.jpg";
     picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/custom/new-wallpaper.jpg";
   };
   ```

4. **Rebuild system**:
   ```bash
   sudo nixos-rebuild switch --flake ~/.dotfiles
   ```

## Supported Formats

- JPEG (.jpg, .jpeg) - Recommended for photographs
- PNG (.png) - For images with transparency
- SVG (.svg) - For vector graphics
- WebP (.webp) - Modern format with good compression
- AVIF (.avif) - GNOME 43+ only

## Recommended Image Sizes

- **Minimum**: 1920x1080 (Full HD)
- **Recommended**: Match or exceed your display resolution
- **Maximum**: No hard limit, but keep file size reasonable (<10MB)

## Git Considerations

- ✅ Include wallpapers in git for reproducibility
- ⚠️ Keep file sizes reasonable (<5MB preferred)
- 💡 Use Git LFS for very large images (>10MB)

## Notes

- Wallpapers are copied to the Nix store during system build
- They become immutable and garbage-collection safe
- Changes require a system rebuild to take effect
- The same wallpaper can be used for desktop, lock screen, and GDM login
