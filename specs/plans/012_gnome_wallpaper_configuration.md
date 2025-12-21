# Plan 012: GNOME Desktop and GDM Login Wallpaper Configuration

**Status**: Pending Implementation  
**Created**: 2025-12-20  
**Priority**: Medium

## Problem Statement

Currently, the GNOME desktop background and GDM (login screen) background are not declaratively managed in the NixOS configuration. This means:

1. Desktop wallpaper must be manually set through GNOME Settings after each fresh install
2. GDM login screen shows the default GNOME background
3. Custom wallpapers are not preserved across system rebuilds
4. The configuration is not reproducible

The user wants to set a specific image (a nighttime riverside scene from India) as both the desktop background and login screen background.

## Current State Analysis

### Existing Configuration

**home.nix** (lines 38-115):
- Contains dconf settings for GNOME preferences
- Does NOT currently set desktop background
- Has dark mode preference: `color-scheme = "prefer-dark"`

**configuration.nix**:
- Enables GDM: `services.displayManager.gdm.enable = true`
- Does NOT configure GDM background

### Image Details

- **Source**: User-provided image (riverside scene at night)
- **Location**: Currently only in chat/temporary storage
- **Needed**: Copy to Nix store for declarative management

## Research Findings

### Desktop Background (Home Manager)

From [hoverbear.org](https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/):

```nix
dconf.settings = {
  "org/gnome/desktop/background" = {
    picture-uri = "file:///path/to/image.png";
    picture-uri-dark = "file:///path/to/image.png";
  };
  "org/gnome/desktop/screensaver" = {
    picture-uri = "file:///path/to/image.png";
  };
};
```

**Key points**:
- `picture-uri` - Used in light mode
- `picture-uri-dark` - Used in dark mode (GNOME 42+)
- `screensaver/picture-uri` - Lock screen background
- Must use `file://` URI scheme
- Path must be absolute

### GDM Login Background (System Configuration)

GDM background requires system-level configuration. Two approaches:

**Approach 1: Using GDM dconf settings** (Recommended)
```nix
# In configuration.nix
systemd.tmpfiles.rules = [
  "L+ /run/gdm/.config/monitors.xml - - - - ${pkgs.writeText "gdm-monitors.xml" (builtins.readFile ./monitors.xml)}"
];

# Set GDM background via dconf
programs.dconf.profiles.gdm.databases = [{
  settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/custom/wallpaper.jpg";
      picture-options = "zoom";
    };
  };
}];
```

**Approach 2: Using environment.etc** (Simpler)
```nix
# In configuration.nix
environment.etc."gdm/greeter.dconf-defaults".text = ''
  [org/gnome/desktop/background]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/wallpaper.jpg'
  picture-options='zoom'
'';
```

### Image Storage Strategy

**Option 1: Store in Nix store via pkgs.copyPathToStore**
```nix
let
  wallpaper = pkgs.copyPathToStore ./wallpapers/riverside.jpg;
in
```

**Option 2: Install to system backgrounds directory**
```nix
environment.systemPackages = [
  (pkgs.runCommand "custom-wallpaper" {} ''
    mkdir -p $out/share/backgrounds/custom
    cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/wallpaper.jpg
  '')
];
```

**Recommendation**: Use Option 2 for GDM (system-wide access) and reference the same file in home-manager.

## Proposed Solution

### Directory Structure

```
~/.dotfiles/
├── wallpapers/
│   └── riverside.jpg          # User's custom wallpaper
├── home.nix                   # Desktop background config
├── configuration.nix          # GDM background config
└── flake.nix                  # (no changes needed)
```

### Implementation Steps

#### Step 1: Create Wallpaper Directory and Copy Image

```bash
mkdir -p ~/.dotfiles/wallpapers
# Copy the riverside image to ~/.dotfiles/wallpapers/riverside.jpg
```

#### Step 2: Update configuration.nix

Add wallpaper package and GDM configuration:

```nix
# In configuration.nix, add to environment.systemPackages around line 265

environment.systemPackages = [
  # ... existing packages ...
  
  # Custom wallpaper package
  (pkgs.runCommand "custom-wallpaper" {} ''
    mkdir -p $out/share/backgrounds/custom
    cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/riverside.jpg
  '')
];

# Add GDM background configuration (new section after services.displayManager.gdm)
# Around line 120, after the gdm configuration block

# Set GDM login screen background
environment.etc."gdm/greeter.dconf-defaults".text = ''
  [org/gnome/desktop/background]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
  picture-options='zoom'
  
  [org/gnome/desktop/screensaver]
  picture-uri='file:///run/current-system/sw/share/backgrounds/custom/riverside.jpg'
'';
```

#### Step 3: Update home.nix

Add desktop background configuration to dconf.settings:

```nix
# In home.nix, add to dconf.settings around line 38
# Add new section after "org/gnome/desktop/interface"

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
  
  # ... rest of existing settings ...
};
```

#### Step 4: Apply Configuration

```bash
# Rebuild NixOS system (for GDM background)
sudo nixos-rebuild switch --flake ~/.dotfiles

# Apply home-manager configuration (for desktop background)
home-manager switch --flake ~/.dotfiles#benjamin

# Or if home-manager is integrated in flake, just:
sudo nixos-rebuild switch --flake ~/.dotfiles
```

#### Step 5: Verify Changes

```bash
# Check desktop background setting
gsettings get org.gnome.desktop.background picture-uri
gsettings get org.gnome.desktop.background picture-uri-dark

# Check lock screen setting
gsettings get org.gnome.desktop.screensaver picture-uri

# Check if wallpaper file exists in system
ls -la /run/current-system/sw/share/backgrounds/custom/

# Test GDM background by logging out
# The login screen should show the riverside image
```

## Expected Outcomes

1. ✅ Desktop background shows riverside image in both light and dark mode
2. ✅ Lock screen (screensaver) shows riverside image
3. ✅ GDM login screen shows riverside image
4. ✅ All backgrounds persist across system rebuilds
5. ✅ Configuration is fully declarative and reproducible

## File Locations Summary

| Component | Config File | Setting Location |
|-----------|-------------|------------------|
| Desktop background | `home.nix` | `dconf.settings."org/gnome/desktop/background"` |
| Lock screen | `home.nix` | `dconf.settings."org/gnome/desktop/screensaver"` |
| GDM login | `configuration.nix` | `environment.etc."gdm/greeter.dconf-defaults"` |
| Wallpaper source | `wallpapers/riverside.jpg` | Copied to Nix store |
| Wallpaper install | `configuration.nix` | `environment.systemPackages` |

## Testing Checklist

- [ ] Wallpaper directory created: `~/.dotfiles/wallpapers/`
- [ ] Image copied to: `~/.dotfiles/wallpapers/riverside.jpg`
- [ ] `configuration.nix` updated with wallpaper package
- [ ] `configuration.nix` updated with GDM dconf defaults
- [ ] `home.nix` updated with desktop background settings
- [ ] `home.nix` updated with screensaver settings
- [ ] System rebuild successful: `sudo nixos-rebuild switch`
- [ ] Home-manager switch successful (if separate)
- [ ] Desktop background shows riverside image
- [ ] Lock screen shows riverside image (test with Super+Grave)
- [ ] GDM login screen shows riverside image (log out to verify)
- [ ] Wallpaper file exists at `/run/current-system/sw/share/backgrounds/custom/riverside.jpg`
- [ ] Settings persist after reboot

## Rollback Plan

If issues occur:

```bash
# Revert configuration files
cd ~/.dotfiles
git checkout configuration.nix home.nix

# Remove wallpaper directory if needed
rm -rf wallpapers/

# Rebuild system
sudo nixos-rebuild switch --flake ~/.dotfiles

# Or manually reset GNOME settings
gsettings reset org.gnome.desktop.background picture-uri
gsettings reset org.gnome.desktop.background picture-uri-dark
gsettings reset org.gnome.desktop.screensaver picture-uri
```

## Alternative Approaches Considered

### 1. Using stylix (Rejected)
- **Pros**: Unified theming across system
- **Cons**: Overkill for just setting wallpaper, adds complexity
- **Decision**: Keep it simple with direct dconf settings

### 2. Using home-manager for GDM (Not Possible)
- **Issue**: GDM runs as system service before user login
- **Limitation**: home-manager only affects user session
- **Decision**: Must use system-level configuration.nix for GDM

### 3. Storing image in home directory (Rejected)
- **Issue**: GDM can't access user home directory at login
- **Decision**: Must use system-wide path like `/run/current-system/sw/share/`

## Notes

- The `picture-options = "zoom"` setting ensures the image fills the screen while maintaining aspect ratio
- Using the same path for both `picture-uri` and `picture-uri-dark` means the same image is used regardless of light/dark mode preference
- The GDM greeter runs as the `gdm` user, so the wallpaper must be in a system-accessible location
- Changes to GDM configuration require a full system rebuild, not just home-manager switch
- The wallpaper will be copied into the Nix store, making it immutable and garbage-collection safe

## References

- [Declarative GNOME configuration with NixOS](https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/)
- [NixOS Wiki - GNOME](https://nixos.wiki/wiki/GNOME)
- [Home Manager dconf module](https://nix-community.github.io/home-manager/options.html#opt-dconf.settings)
- [GNOME Desktop Background Schema](https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas/-/blob/master/schemas/org.gnome.desktop.background.gschema.xml.in)
- Current configuration: `~/.dotfiles/home.nix`, `~/.dotfiles/configuration.nix`
