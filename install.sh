#!/bin/bash

set -e

echo "===> Setting up dotfiles..."

# Make sure flakes are enabled
if ! grep -q "experimental-features.*flakes" /etc/nix/nix.conf 2>/dev/null; then
    echo "===> Enabling flakes in Nix configuration..."
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
fi

# Get the hostname
HOSTNAME=$(hostname)
echo "===> Detected hostname: $HOSTNAME"

# Build NixOS configuration
echo "===> Building and switching to NixOS configuration..."
sudo nixos-rebuild switch --flake .#$HOSTNAME

# Build home-manager configuration
echo "===> Building and switching to Home Manager configuration..."
home-manager switch --flake .#benjamin

echo "===> Dotfiles setup complete!"