# Documentation

This directory contains comprehensive documentation for the NixOS configuration setup.

## Documentation Files

### Getting Started
- **[installation.md](installation.md)** - Setup and installation guide
- **[usb-installer.md](usb-installer.md)** - Create bootable USB installer with your complete configuration
- **[configuration.md](configuration.md)** - Core configuration details
- **[testing.md](testing.md)** - Testing and validation procedures

### Package Management
- **[packages.md](packages.md)** - Package management and custom packages
- **[unstable-packages.md](unstable-packages.md)** - Managing unstable channel packages

### Applications & Desktop
- **[applications.md](applications.md)** - Application-specific configurations
- **[himalaya.md](himalaya.md)** - Himalaya email client setup and configuration
- **[niri.md](niri.md)** - Niri window manager keybindings and configuration
- **[terminal.md](terminal.md)** - WezTerm and Kitty terminal configuration
- **[dictation.md](dictation.md)** - Whisper dictation system setup

### Development & Hardware
- **[development.md](development.md)** - Development notes and workflows
- **[wifi.md](wifi.md)** - **CRITICAL:** WiFi configuration requirements and troubleshooting
- **[ryzen-ai-300-compatibility.md](ryzen-ai-300-compatibility.md)** - AMD Ryzen AI 300 series hardware support
- **[ryzen-ai-300-support-summary.md](ryzen-ai-300-support-summary.md)** - Ryzen AI 300 support summary

## Reading Order

For new users, we recommend reading in this order:
1. [installation.md](installation.md) - Get the system running
2. [configuration.md](configuration.md) - Understand the configuration structure
3. [applications.md](applications.md) - Configure applications
4. [packages.md](packages.md) - Manage packages

For creating a portable installer:
1. [usb-installer.md](usb-installer.md) - Complete USB installer guide

## Quick Reference

### System Management
- **System rebuild**: `sudo nixos-rebuild switch --flake .#hostname`
- **User config**: `home-manager switch --flake .#benjamin`
- **Update flake**: `nix flake update`
- **Full update**: `./update.sh`

### USB Installer
- **Build ISO**: `nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage`
- **Write to USB**: `sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M conv=fsync status=progress`

[← Back to main README](../README.md)