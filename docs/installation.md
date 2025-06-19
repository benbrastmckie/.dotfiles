# Installation Guide

## Prerequisites

- NixOS system with flakes enabled
- Git for cloning the repository
- Sudo access for system configuration

## Setup Process

### 1. Clone Repository

```bash
git clone https://github.com/benbrastmckie/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 2. System Configuration

```bash
sudo nixos-rebuild switch --flake .#nandi
```

Replace `nandi` with your hostname. Check available configurations:

```bash
nix flake show
```

### 3. Home Manager Setup

```bash
home-manager switch --flake .#benjamin
```

### 4. Scripts

- **install.sh**: Automated installation script
- **update.sh**: Updates flake inputs and rebuilds system

## Host Configuration

Host-specific configurations are stored in the `hosts/` directory. To add a new host:

1. Create hardware configuration: `nixos-generate-config`
2. Copy `hardware-configuration.nix` to `hosts/[hostname]/`
3. Update `flake.nix` to include the new host
4. Reference host-specific settings in `configuration.nix`

## Troubleshooting

- Ensure flakes are enabled: `nix.settings.experimental-features = [ "nix-command" "flakes" ];`
- Check syntax: `nix flake check`
- Dry run: `nixos-rebuild dry-build --flake .#hostname`