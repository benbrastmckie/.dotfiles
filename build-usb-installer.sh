#!/usr/bin/env bash
set -euo pipefail

# USB Installer Build Script
# This script builds the NixOS USB installer with complete dotfiles

echo "🔨 Building NixOS USB Installer..."
echo "⏱️  Estimated time: 30-60 minutes"
echo ""

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
echo "🏗️  Building USB installer ISO (this will take a while)..."
echo "💡 Tip: Monitor progress with: ps aux | grep 'nix build'"
echo ""
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# Get the ISO path (compressed .zst file)
ISO_PATH=$(readlink -f result/iso/nixos-*.iso.zst)
ISO_NAME=$(basename "$ISO_PATH")

echo ""
echo "✅ USB installer built successfully!"
echo "📁 ISO location: $ISO_PATH"
echo "💿 ISO name: $ISO_NAME"

# Calculate file size
ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
echo "📊 Compressed size: $ISO_SIZE"

echo ""
echo "🚀 Next steps:"
echo "1. Decompress the ISO:"
echo "   zstd -d $ISO_PATH -o /tmp/nixos-installer.iso"
echo ""
echo "2. Insert a USB drive (8GB minimum, 16GB recommended)"
echo ""
echo "3. Find your USB device:"
echo "   lsblk"
echo ""
echo "4. Write to USB (replace /dev/sdX with your device):"
echo "   sudo umount /dev/sdX*"
echo "   sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress"
echo "   sync"
echo ""
echo "5. Clean up and eject:"
echo "   rm /tmp/nixos-installer.iso"
echo "   sudo eject /dev/sdX"
echo ""
echo "📖 For detailed instructions, see: docs/usb-installer.md"