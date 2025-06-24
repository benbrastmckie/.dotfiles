# NixOS Dotfiles

This repository contains my personal NixOS configuration using flakes and Home Manager for comprehensive system and user environment management.

## Overview

These dotfiles provide a complete NixOS setup with:

- **System Configuration**: NixOS system-wide settings via `configuration.nix`
- **User Environment**: Home Manager configuration in `home.nix`
- **Flake Management**: Modern Nix flake setup with pinned inputs
- **Custom Modules**: Extended functionality through custom Home Manager modules
- **Application Integration**: Configured applications with seamless integration

## Repository Structure

### Core Configuration Files

- [`configuration.nix`](configuration.nix): System-wide NixOS configuration
- [`home.nix`](home.nix): Home Manager user environment configuration  
- [`flake.nix`](flake.nix): Nix flake with inputs and system definitions
- [`unstable-packages.nix`](unstable-packages.nix): Packages from nixpkgs unstable

### Directory Organization

- **[`config/`](config/)** - Application configuration files ([README](config/README.md))
- **[`docs/`](docs/)** - Detailed documentation for all components ([README](docs/README.md))
- **[`home-modules/`](home-modules/)** - Custom Home Manager modules ([README](home-modules/README.md))
- **[`hosts/`](hosts/)** - Host-specific hardware configurations ([README](hosts/README.md))
- **[`packages/`](packages/)** - Custom package definitions and Neovim configuration ([README](packages/README.md))

### Documentation Files

- [`docs/configuration.md`](docs/configuration.md): Core configuration details
- [`docs/installation.md`](docs/installation.md): Setup and installation guide
- [`docs/applications.md`](docs/applications.md): Application-specific configurations
- [`docs/himalaya.md`](docs/himalaya.md): Himalaya email client setup and configuration
- [`docs/packages.md`](docs/packages.md): Package management and custom packages
- [`docs/unstable-packages.md`](docs/unstable-packages.md): Managing unstable channel packages
- [`docs/testing.md`](docs/testing.md): Testing and validation procedures
- [`docs/development.md`](docs/development.md): Development notes and ISO building

## Quick Start

For detailed installation instructions, see [`docs/installation.md`](docs/installation.md).

### Basic Setup

1. Clone repository: `git clone <repo-url> ~/.dotfiles`
2. Build system: `sudo nixos-rebuild switch --flake .#hostname`
3. Apply user config: `home-manager switch --flake .#benjamin`

### Customization

- **System changes**: Edit [`configuration.nix`](configuration.nix)
- **User environment**: Edit [`home.nix`](home.nix)  
- **Package updates**: Modify [`flake.nix`](flake.nix) inputs
- **Application configs**: Update files in [`config/`](config/)

For comprehensive configuration details, see [`docs/configuration.md`](docs/configuration.md).

## Featured Applications

### Email (Himalaya)
Modern CLI email client with Gmail OAuth2 authentication and mbsync synchronization. Complete setup guide at [`docs/himalaya.md`](docs/himalaya.md).

### MCP-Hub 
Model Context Protocol integration for AI tools with Neovim. Architecture details in [`docs/applications.md`](docs/applications.md#mcp-hub-integration).

### PDF Viewers
Custom Zathura and Sioyek configurations with title bar removal. Implementation details in [`docs/applications.md`](docs/applications.md#pdf-viewers).

### Development Environment
Comprehensive Neovim setup with language servers and tools. Package details in [`packages/`](packages/).

For complete application configurations and setup instructions, see [`docs/applications.md`](docs/applications.md).

## Maintenance

### Updating System
```bash
sudo nixos-rebuild switch --flake .#hostname
```

### Updating Packages
```bash
nix flake update
./update.sh
```

## License

MIT