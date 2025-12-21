#!/usr/bin/env bash
# Verification script for wallpaper configuration

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Wallpaper Configuration Verification Script           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if image exists
echo "🔍 Checking for wallpaper image..."
if [ -f "$HOME/.dotfiles/wallpapers/riverside.jpg" ]; then
    echo "   ✅ riverside.jpg found"
    ls -lh "$HOME/.dotfiles/wallpapers/riverside.jpg"
else
    echo "   ❌ riverside.jpg NOT FOUND"
    echo ""
    echo "   Please save the riverside image to:"
    echo "   $HOME/.dotfiles/wallpapers/riverside.jpg"
    echo ""
    exit 1
fi

echo ""
echo "🔍 Checking configuration files..."

# Check configuration.nix
if grep -q "custom-wallpaper" "$HOME/.dotfiles/configuration.nix"; then
    echo "   ✅ configuration.nix has wallpaper package"
else
    echo "   ❌ configuration.nix missing wallpaper package"
fi

if grep -q 'gdm/greeter.dconf-defaults' "$HOME/.dotfiles/configuration.nix"; then
    echo "   ✅ configuration.nix has GDM background config"
else
    echo "   ❌ configuration.nix missing GDM background config"
fi

# Check home.nix
if grep -q 'org/gnome/desktop/background' "$HOME/.dotfiles/home.nix"; then
    echo "   ✅ home.nix has desktop background config"
else
    echo "   ❌ home.nix missing desktop background config"
fi

if grep -q 'org/gnome/desktop/screensaver' "$HOME/.dotfiles/home.nix"; then
    echo "   ✅ home.nix has lock screen config"
else
    echo "   ❌ home.nix missing lock screen config"
fi

echo ""
echo "📋 Ready to rebuild!"
echo ""
echo "Run the following command to apply changes:"
echo ""
echo "   cd ~/.dotfiles"
echo "   sudo nixos-rebuild switch --flake ."
echo ""
echo "After rebuild, verify with:"
echo ""
echo "   # Check installed wallpaper"
echo "   ls -la /run/current-system/sw/share/backgrounds/custom/riverside.jpg"
echo ""
echo "   # Check desktop background setting"
echo "   gsettings get org.gnome.desktop.background picture-uri-dark"
echo ""
echo "   # Visual tests:"
echo "   - Desktop: Should show riverside image"
echo "   - Lock screen: Press Super+Grave"
echo "   - GDM login: Log out"
echo ""
