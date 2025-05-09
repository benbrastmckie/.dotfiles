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

After making changes, rebuild the system:

```bash
sudo nixos-rebuild switch --flake .#nandi
```

## License

MIT