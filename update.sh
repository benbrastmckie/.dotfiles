#\!/bin/bash

set -e

echo "===> Updating dotfiles..."

# Update flake inputs
echo "===> Updating flake inputs..."
nix flake update

# Get the hostname
HOSTNAME=$(hostname)
echo "===> Detected hostname: $HOSTNAME"

# Option to skip checks (useful for testing problematic packages)
SKIP_CHECK=""
if [ "$1" == "--no-check" ]; then
  echo "===> Skipping build checks for problematic packages..."
  SKIP_CHECK="--option allow-import-from-derivation false"
fi

# Rebuild NixOS configuration
echo "===> Rebuilding NixOS configuration..."
sudo nixos-rebuild switch --flake .#$HOSTNAME --option allow-import-from-derivation false

# Rebuild home-manager configuration
echo "===> Rebuilding Home Manager configuration..."
home-manager switch --flake .#benjamin --option allow-import-from-derivation false

echo "===> Dotfiles update complete\!"
