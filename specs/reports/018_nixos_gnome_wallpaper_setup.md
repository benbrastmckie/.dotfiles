# Report 018: NixOS GNOME Wallpaper Setup Research

**Date**: 2025-12-20  
**Status**: Complete  
**Related Plan**: [012_gnome_wallpaper_configuration.md](../plans/012_gnome_wallpaper_configuration.md)

## Executive Summary

This report documents research into declaratively managing GNOME desktop and GDM login screen wallpapers in NixOS. The solution requires:

1. **Desktop background**: Configured via home-manager using dconf settings
2. **GDM login background**: Configured via system-level configuration.nix
3. **Image storage**: Wallpaper must be in Nix store and system-accessible path

## Research Questions

1. How to set GNOME desktop background declaratively?
2. How to set GDM login screen background?
3. Where to store the wallpaper image for both user and system access?
4. How to handle light/dark mode variants?

## Findings

### 1. GNOME Desktop Background Configuration

**Method**: Home Manager dconf settings

**Relevant dconf keys**:
```
org.gnome.desktop.background.picture-uri          # Light mode background
org.gnome.desktop.background.picture-uri-dark     # Dark mode background (GNOME 42+)
org.gnome.desktop.background.picture-options      # Scaling: "zoom", "centered", "scaled", "stretched", "spanned"
org.gnome.desktop.screensaver.picture-uri         # Lock screen background
```

**Implementation**:
```nix
# In home.nix
dconf.settings = {
  "org/gnome/desktop/background" = {
    picture-uri = "file:///path/to/wallpaper.jpg";
    picture-uri-dark = "file:///path/to/wallpaper.jpg";
    picture-options = "zoom";
  };
  "org/gnome/desktop/screensaver" = {
    picture-uri = "file:///path/to/wallpaper.jpg";
  };
};
```

**Key insights**:
- Must use `file://` URI scheme with absolute path
- `picture-uri-dark` was added in GNOME 42 for dark mode support
- Setting both to same path uses same wallpaper regardless of theme
- Lock screen uses separate `screensaver` schema

**Source**: [Declarative GNOME configuration with NixOS](https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/)

### 2. GDM Login Screen Background

**Challenge**: GDM runs as system service before user login, so home-manager cannot configure it.

**Solution**: System-level dconf configuration via `environment.etc`

**Method 1: GDM greeter dconf defaults** (Recommended)
```nix
# In configuration.nix
environment.etc."gdm/greeter.dconf-defaults".text = ''
  [org/gnome/desktop/background]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/wallpaper.jpg'
  picture-options='zoom'
'';
```

**Method 2: dconf profiles** (More complex)
```nix
programs.dconf.profiles.gdm.databases = [{
  settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file:///path/to/wallpaper.jpg";
      picture-options = "zoom";
    };
  };
}];
```

**Key insights**:
- GDM greeter runs as `gdm` user, not as regular user
- Wallpaper must be in system-accessible location
- Method 1 is simpler and more commonly used
- Requires full system rebuild to take effect

**Sources**: 
- NixOS Discourse discussions on GDM customization
- NixOS options search for `gdm` and `dconf`

### 3. Image Storage Strategy

**Requirements**:
- Accessible to both user session and GDM system service
- Immutable (in Nix store)
- Survives garbage collection
- Declaratively managed

**Rejected approaches**:

❌ **User home directory** (`~/Pictures/wallpaper.jpg`)
- Problem: GDM cannot access user home directory
- GDM runs before user login

❌ **Direct Nix store path** (`/nix/store/xxx-wallpaper.jpg`)
- Problem: Hash changes with any modification
- Hard to reference consistently

**Recommended approach**:

✅ **System backgrounds directory via package**
```nix
environment.systemPackages = [
  (pkgs.runCommand "custom-wallpaper" {} ''
    mkdir -p $out/share/backgrounds/custom
    cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/riverside.jpg
  '')
];
```

**Benefits**:
- Stable path: `/run/current-system/sw/share/backgrounds/custom/riverside.jpg`
- Accessible to both user and GDM
- Automatically in Nix store
- Won't be garbage collected while system generation exists
- Follows FHS conventions

**Alternative considered**:

✅ **pkgs.copyPathToStore** (Simpler but less flexible)
```nix
let
  wallpaper = pkgs.copyPathToStore ./wallpapers/riverside.jpg;
in
```
- Simpler syntax
- Direct Nix store path
- Less control over installation location

### 4. Light/Dark Mode Handling

**GNOME 42+ behavior**:
- `picture-uri`: Used when `color-scheme = "default"` (light mode)
- `picture-uri-dark`: Used when `color-scheme = "prefer-dark"` (dark mode)

**User requirement**: Same image for both modes

**Solution**: Set both keys to same path
```nix
picture-uri = "file:///path/to/wallpaper.jpg";
picture-uri-dark = "file:///path/to/wallpaper.jpg";
```

**Alternative**: Only set `picture-uri-dark` if always using dark mode
- Current config has `color-scheme = "prefer-dark"`
- Could omit `picture-uri` entirely
- But setting both ensures consistency if theme changes

## Technical Details

### File Path Resolution

**Nix store path**:
```
/nix/store/abc123-custom-wallpaper/share/backgrounds/custom/riverside.jpg
```

**System profile symlink**:
```
/run/current-system/sw/share/backgrounds/custom/riverside.jpg
→ /nix/store/abc123-custom-wallpaper/share/backgrounds/custom/riverside.jpg
```

**Why use profile symlink**:
- Stable path across rebuilds
- Automatically updates when system generation changes
- Standard NixOS pattern for system-wide resources

### dconf vs gsettings

**dconf**: Low-level configuration database
- Binary format
- Direct key-value storage
- Used by home-manager module

**gsettings**: High-level API over dconf
- Schema validation
- Type checking
- Used for manual configuration

**Relationship**:
```
gsettings (CLI/API) → dconf (storage)
home-manager dconf.settings → dconf database
```

### GDM Configuration Precedence

GDM reads configuration in this order:
1. `/etc/gdm/greeter.dconf-defaults` (system defaults)
2. `/etc/dconf/db/gdm.d/` (dconf database)
3. User overrides (if any)

Our approach uses #1 (greeter.dconf-defaults) for simplicity.

## Implementation Considerations

### Image Format Support

GNOME supports:
- JPEG (.jpg, .jpeg)
- PNG (.png)
- SVG (.svg)
- WebP (.webp)
- AVIF (.avif) - GNOME 43+

**Recommendation**: Use JPEG for photographs
- Good compression
- Wide compatibility
- Smaller file size than PNG

### Image Sizing

**Optimal resolution**: Match or exceed display resolution
- User's laptop: Likely 1920x1080 or higher
- Oversized images: GNOME will scale down (no quality loss)
- Undersized images: Will be upscaled (quality loss with "zoom")

**picture-options values**:
- `"zoom"`: Fill screen, crop if needed (recommended for photos)
- `"centered"`: No scaling, center on screen
- `"scaled"`: Scale to fit, maintain aspect ratio
- `"stretched"`: Fill screen, ignore aspect ratio
- `"spanned"`: Span across multiple monitors

### Git Considerations

**Should wallpaper be in git?**

✅ **Yes, if**:
- Image is reasonably sized (<5MB)
- Part of system configuration
- Want full reproducibility

❌ **No, if**:
- Very large file (>10MB)
- Frequently changes
- Privacy concerns

**Recommendation**: Include in git
- Ensures reproducibility
- Single source of truth
- Easy to track changes

**Alternative**: Use Git LFS for large images
```bash
git lfs track "wallpapers/*.jpg"
```

## Testing Strategy

### Verification Commands

```bash
# Check desktop background
gsettings get org.gnome.desktop.background picture-uri
gsettings get org.gnome.desktop.background picture-uri-dark

# Check lock screen
gsettings get org.gnome.desktop.screensaver picture-uri

# Verify file exists
ls -la /run/current-system/sw/share/backgrounds/custom/

# Check file in Nix store
nix-store -q --references /run/current-system | grep wallpaper
```

### Visual Testing

1. **Desktop background**: Log in, check desktop
2. **Lock screen**: Press Super+Grave (lock screen shortcut)
3. **GDM login**: Log out, check login screen
4. **Persistence**: Reboot, verify all three still show wallpaper

## Comparison with Other Approaches

### stylix

**What it is**: NixOS module for unified system theming

**Pros**:
- Automatic color scheme generation from wallpaper
- Consistent theming across applications
- Single source of truth

**Cons**:
- Overkill for just setting wallpaper
- Adds complexity
- May override other theme preferences

**Decision**: Not needed for this use case

### GNOME Tweaks

**What it is**: GUI tool for GNOME customization

**Pros**:
- User-friendly
- Visual preview
- No configuration files

**Cons**:
- Not declarative
- Doesn't survive rebuilds
- Manual process

**Decision**: Not suitable for NixOS declarative approach

### Manual dconf commands

**Example**:
```bash
dconf write /org/gnome/desktop/background/picture-uri "'file:///path/to/wallpaper.jpg'"
```

**Pros**:
- Quick testing
- No rebuild needed

**Cons**:
- Not declarative
- Lost on home-manager switch
- Not reproducible

**Decision**: Useful for testing, but use home-manager for final config

## Potential Issues and Solutions

### Issue 1: Wallpaper not showing after rebuild

**Symptoms**: Desktop shows default background

**Causes**:
- File path incorrect
- File not in Nix store
- dconf settings not applied

**Solutions**:
```bash
# Check if file exists
ls -la /run/current-system/sw/share/backgrounds/custom/riverside.jpg

# Manually verify dconf setting
dconf read /org/gnome/desktop/background/picture-uri

# Force home-manager to reapply
home-manager switch --flake ~/.dotfiles#benjamin

# Restart GNOME Shell (Alt+F2, type 'r', Enter)
```

### Issue 2: GDM still shows default background

**Symptoms**: Login screen unchanged

**Causes**:
- GDM configuration not applied
- File not accessible to gdm user
- Cached GDM settings

**Solutions**:
```bash
# Verify GDM config file exists
cat /etc/gdm/greeter.dconf-defaults

# Restart GDM service
sudo systemctl restart gdm

# Or reboot (GDM restarts on boot)
sudo reboot
```

### Issue 3: Image appears stretched or cropped

**Symptoms**: Wallpaper doesn't look right

**Cause**: Wrong `picture-options` setting

**Solution**: Try different options
```nix
picture-options = "zoom";      # Fill screen, crop if needed
picture-options = "scaled";    # Fit screen, maintain aspect ratio
picture-options = "centered";  # No scaling
```

## Recommendations

1. **Use the system backgrounds approach** for maximum compatibility
2. **Set both picture-uri and picture-uri-dark** for consistency
3. **Use "zoom" for picture-options** for photographs
4. **Include wallpaper in git** for reproducibility
5. **Test all three contexts**: desktop, lock screen, GDM login
6. **Keep original image** in `wallpapers/` directory for easy updates

## Next Steps

See [Plan 012](../plans/012_gnome_wallpaper_configuration.md) for implementation details.

## References

### Primary Sources

1. **Hoverbear.org - Declarative GNOME configuration**
   - URL: https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/
   - Key info: dconf settings structure, home-manager integration
   - Date accessed: 2025-12-20

2. **NixOS Wiki - GNOME**
   - URL: https://nixos.wiki/wiki/GNOME
   - Key info: GNOME module configuration, extensions
   - Date accessed: 2025-12-20

3. **Home Manager Options - dconf**
   - URL: https://nix-community.github.io/home-manager/options.html#opt-dconf.settings
   - Key info: dconf module syntax and options
   - Date accessed: 2025-12-20

### GNOME Documentation

4. **GNOME Desktop Background Schema**
   - URL: https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas/-/blob/master/schemas/org.gnome.desktop.background.gschema.xml.in
   - Key info: Available dconf keys and their types

5. **GNOME Screensaver Schema**
   - URL: https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas/-/blob/master/schemas/org.gnome.desktop.screensaver.gschema.xml.in
   - Key info: Lock screen configuration options

### Community Resources

6. **NixOS Discourse - GDM Background Discussions**
   - Various threads on GDM customization
   - Community solutions and workarounds

7. **GitHub - NixOS/nixpkgs Issues**
   - Issue #103746: GNOME Session Crashes with Auto-Login
   - Related GDM configuration discussions

## Appendix: Complete Configuration Example

### Directory Structure
```
~/.dotfiles/
├── wallpapers/
│   └── riverside.jpg
├── home.nix
├── configuration.nix
└── flake.nix
```

### configuration.nix (relevant sections)
```nix
{ config, lib, pkgs, ... }:
{
  # ... existing config ...
  
  # Custom wallpaper package
  environment.systemPackages = [
    # ... existing packages ...
    
    (pkgs.runCommand "custom-wallpaper" {} ''
      mkdir -p $out/share/backgrounds/custom
      cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/riverside.jpg
    '')
  ];
  
  # GDM login screen background
  environment.etc."gdm/greeter.dconf-defaults".text = ''
    [org/gnome/desktop/background]
    picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
    picture-options='zoom'
    
    [org/gnome/desktop/screensaver]
    picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
  '';
}
```

### home.nix (relevant sections)
```nix
{ config, pkgs, ... }:
{
  # ... existing config ...
  
  dconf.settings = {
    # ... existing settings ...
    
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
  };
}
```

## Conclusion

Setting GNOME desktop and GDM login wallpapers declaratively in NixOS requires:

1. Storing the image in the Nix store via a custom package
2. Configuring desktop/lock screen backgrounds via home-manager dconf settings
3. Configuring GDM login background via system-level dconf defaults

This approach ensures full reproducibility and persistence across system rebuilds while maintaining the declarative nature of NixOS configuration.
