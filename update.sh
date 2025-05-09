#\!/bin/bash

set -e

echo "===> Updating dotfiles..."

# Update flake inputs
echo "===> Updating flake inputs..."
nix flake update

# Get the hostname
HOSTNAME=$(hostname)
echo "===> Detected hostname: $HOSTNAME"

# Rebuild NixOS configuration
echo "===> Rebuilding NixOS configuration..."
sudo nixos-rebuild switch --flake .#$HOSTNAME

# Rebuild home-manager configuration
echo "===> Rebuilding Home Manager configuration..."
home-manager switch --flake .#benjamin

echo "===> Dotfiles update complete\!"
