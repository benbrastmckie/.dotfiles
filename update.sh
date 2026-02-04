#\!/bin/bash

set -e

echo "===> Updating dotfiles..."

# Create git checkpoint if there are uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "===> Creating git checkpoint before update..."
  git add -A
  git commit -m "checkpoint: auto-commit before update

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
  echo "===> Checkpoint created"
else
  echo "===> No uncommitted changes, skipping checkpoint"
fi

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
