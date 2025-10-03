# Documentation

This directory contains comprehensive documentation for the NixOS configuration setup.

## Documentation Files

### Getting Started
- **[installation.md](installation.md)** - Setup and installation guide
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

### Development
- **[development.md](development.md)** - Development notes and ISO building

## Reading Order

For new users, we recommend reading in this order:
1. [installation.md](installation.md) - Get the system running
2. [configuration.md](configuration.md) - Understand the configuration structure
3. [applications.md](applications.md) - Configure applications
4. [packages.md](packages.md) - Manage packages

## Quick Reference

- **System rebuild**: `sudo nixos-rebuild switch --flake .#hostname`
- **User config**: `home-manager switch --flake .#benjamin`
- **Update flake**: `nix flake update`

[← Back to main README](../README.md)