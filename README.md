# Dotfiles

This repository contains my personal dotfiles for NixOS configuration.

## Overview

These dotfiles manage my NixOS system and home configuration using the following components:

- **NixOS Configuration**: System-wide settings defined in `configuration.nix`
- **Home Manager**: User-specific configurations in `home.nix`
- **Flake-based setup**: Modern Nix configuration using `flake.nix`

## Structure

- `configuration.nix`: System-wide NixOS configuration
- `home.nix`: Home Manager configuration for user environment
- `flake.nix`: Nix flake defining system inputs and outputs
- `config/`: Directory containing configuration files for various programs
- `hosts/`: Host-specific hardware configurations

## Setup

### Prerequisites

- NixOS with flakes enabled

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/benbrastmckie/dotfiles.git ~/.dotfiles
   ```

2. Build and switch to the configuration:
   ```bash
   cd ~/.dotfiles
   sudo nixos-rebuild switch --flake .#nandi
   ```
   
   Replace `nandi` with your hostname if different.

3. Apply home-manager configuration:
   ```bash
   home-manager switch --flake .#benjamin
   ```

## Configuration

Edit the following files to customize the setup:

- `configuration.nix` for system-wide changes
- `home.nix` for user-specific configuration
- `flake.nix` to update inputs or add new modules

### Special Configurations

- **MCP-Hub**: MCP-Hub is integrated with Neovim using the official MCPHub flake. The integration uses environment variables for clean communication between NixOS and Neovim. See `packages/README.md` for more details on the simplified architecture.

The MCP-Hub integration follows these principles:
1. Core MCP-Hub binary is provided by NixOS
2. Extensions are installed at runtime via NPM
3. Configuration is managed by your Neovim setup, not NixOS
4. This separation ensures that rebuilding your system won't interfere with your tool configuration

- **PDF Viewer Title Bar Removal**: Custom wrappers for Zathura and Sioyek handle title bar removal differently due to their underlying UI toolkits:

  - **Zathura (GTK)**: Uses server-side decorations that the Unite GNOME extension can hide. The custom wrapper forces X11 for consistency but isn't strictly required for title bar removal.
  
  - **Sioyek (Qt6)**: Uses client-side decorations that Unite cannot hide on Wayland. The custom wrapper forces X11 (`QT_QPA_PLATFORM=xcb`) to enable server-side decorations that Unite can control. The original sioyek package is excluded to prevent conflicts.

After making changes, rebuild the system:

```bash
sudo nixos-rebuild switch --flake .#nandi
```

## License

MIT