# Host Configurations

This directory contains host-specific configurations for different machines in the NixOS setup.

## Hosts

### [garuda/](garuda/)
Hardware configuration for the Garuda host system.

### [nandi/](nandi/)
Hardware configuration for the Nandi host system (Intel laptop).

### [hamsa/](hamsa/)
Hardware configuration for the Hamsa host system (AMD laptop).

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
# Using current hostname
sudo nixos-rebuild switch --flake .#$(hostname)

# Or use the update script (auto-detects hostname)
./update.sh
```

Available hosts: `garuda`, `nandi`, `hamsa`, `usb-installer`

[← Back to main README](../README.md)