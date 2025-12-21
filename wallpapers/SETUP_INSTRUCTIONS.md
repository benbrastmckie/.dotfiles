# Quick Setup Instructions

## Step 1: Save the Image

**IMPORTANT**: Save the riverside image to this location:
```
~/.dotfiles/wallpapers/riverside.jpg
```

## Step 2: Update configuration.nix

### Add wallpaper package (around line 265)

In `environment.systemPackages`, add:

```nix
(pkgs.runCommand "custom-wallpaper" {} ''
  mkdir -p $out/share/backgrounds/custom
  cp ${./wallpapers/riverside.jpg} $out/share/backgrounds/custom/riverside.jpg
'')
```

### Add GDM configuration (around line 120)

After the GDM service configuration, add:

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

## Step 3: Update home.nix

In `dconf.settings` (around line 38), add:

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

## Step 4: Apply Changes

```bash
cd ~/.dotfiles
sudo nixos-rebuild switch --flake .
```

## Step 5: Verify

```bash
# Check desktop background
gsettings get org.gnome.desktop.background picture-uri-dark

# Check file exists
ls -la /run/current-system/sw/share/backgrounds/custom/riverside.jpg

# Visual check
# - Desktop: Should show riverside image
# - Lock screen: Press Super+Grave
# - GDM login: Log out
```

## Troubleshooting

If desktop background doesn't show:
```bash
home-manager switch --flake ~/.dotfiles#benjamin
# Then: Alt+F2, type 'r', Enter (restart GNOME Shell)
```

If GDM login doesn't show:
```bash
sudo systemctl restart gdm
# Or: sudo reboot
```

## Complete Documentation

See: `specs/summaries/012_gnome_wallpaper_configuration.md`
