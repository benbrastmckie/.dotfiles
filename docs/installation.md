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

### 2. Generate Hardware Configuration

Generate the hardware configuration for your machine:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/$(hostname)/hardware-configuration.nix
```

Then add your host to `flake.nix` (see Host Configuration section below).

### 3. System Configuration

> **⚠️ IMPORTANT - First Build**: On the first build, you **must** explicitly specify your hostname (e.g., `.#hamsa`) rather than using `$(hostname)`. The hostname is set by NixOS configuration, so until the correct config is applied, `$(hostname)` will return the wrong value. After the first successful build, `$(hostname)` and `./update.sh` will work correctly.

**First build** (specify hostname explicitly):
```bash
sudo nixos-rebuild switch --flake .#your-hostname
```

**Subsequent builds** (hostname auto-detected):
```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```

Or use the update script which auto-detects your hostname:

```bash
./update.sh
```

Check available configurations:

```bash
nix flake show
```

### 4. Home Manager Setup

```bash
home-manager switch --flake .#benjamin
```

### 5. Scripts

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