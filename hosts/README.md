# Host Configurations

This directory contains host-specific configurations for different machines in the NixOS setup.

## Hosts

### [garuda/](garuda/)
Hardware configuration for the Garuda host system.

### [nandi/](nandi/)  
Hardware configuration for the Nandi host system.

### [usb-installer/](usb-installer/)
Generic hardware configuration for the USB installer. This configuration is used to create a bootable USB drive that contains the complete dotfiles setup for reproducing the NixOS environment on any machine.

## Structure

Each host directory contains:
- `hardware-configuration.nix` - Auto-generated hardware configuration

## Usage

Host configurations are referenced in `flake.nix` to build system-specific configurations:

```nix
nixosConfigurations = {
  garuda = nixpkgs.lib.nixosSystem {
    modules = [
      ./configuration.nix
      ./hosts/garuda/hardware-configuration.nix
    ];
  };
};
```

## Building for a Host

```bash
sudo nixos-rebuild switch --flake .#hostname
```

Where `hostname` is one of: `garuda`, `nandi`, `usb-installer`

[← Back to main README](../README.md)