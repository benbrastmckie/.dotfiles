#!/usr/bin/env bash
set -euo pipefail

# USB Installer Build Script
# This script builds the NixOS USB installer with complete dotfiles

echo "🔨 Building NixOS USB Installer..."

# Check if we're in the dotfiles directory
if [[ ! -f "flake.nix" ]]; then
    echo "❌ Error: Please run this script from the dotfiles root directory"
    exit 1
fi

# Check if USB installer host exists
if [[ ! -d "hosts/usb-installer" ]]; then
    echo "❌ Error: USB installer host configuration not found"
    exit 1
fi

# Update flake inputs
echo "📦 Updating flake inputs..."
nix flake update

# Build the USB installer
echo "🏗️  Building USB installer ISO..."
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# Get the ISO path
ISO_PATH=$(readlink -f result/iso/nixos-*.iso)
ISO_NAME=$(basename "$ISO_PATH")

echo "✅ USB installer built successfully!"
echo "📁 ISO location: $ISO_PATH"
echo "💿 ISO name: $ISO_NAME"

# Calculate file size
ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
echo "📊 ISO size: $ISO_SIZE"

echo ""
echo "🚀 Next steps:"
echo "1. Insert a USB drive (8GB minimum, 16GB recommended)"
echo "2. Find your USB device with: lsblk"
echo "3. Write to USB with: sudo dd if=\"$ISO_PATH\" of=/dev/sdX bs=4M conv=fsync status=progress"
echo "4. Boot from the USB drive on target machine"
echo ""
echo "📖 For detailed instructions, see: docs/usb-booter.md"