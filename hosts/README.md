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

### [iso/](iso/)
ISO installer image configuration. Wired directly via `lib.nixosSystem` in `flake.nix` rather
than through `mkHost`, since an installer image has no `hardware-configuration.nix`.

## Structure

Each host directory contains:
- `hardware-configuration.nix` - Auto-generated hardware configuration

Some host directories also carry:
- `default.nix` - Optional, host-toggled NixOS module (opt-in only, wired in explicitly via
  `extraModules` in `flake.nix`; see `.claude/rules/nix.md`'s Optional/Host-Toggled Modules
  convention). Present on `nandi/` (opts into the Discord bot relay) and `usb-installer/`
  (installer-specific overrides).
- `README.md` - Per-host notes on hardware details and building. Present on `garuda/`, `hamsa/`,
  and `nandi/`.

## Usage

Host configurations are built via the `mkHost` factory (`lib/mkHost.nix`), which centralizes the
repeated `nixpkgs.lib.nixosSystem` wiring — `configuration.nix`,
`hosts/<hostname>/hardware-configuration.nix`, `sops-nix`, the shared nixpkgs overlay
configuration, and the home-manager module are all included automatically. `flake.nix` calls it
once per host:

```nix
mkHost = import ./lib/mkHost.nix {
  inherit nixpkgs home-manager sops-nix;
  inherit nixpkgsConfig username name pkgs-unstable lectic nix-ai-tools system;
  root = self;
};

nixosConfigurations = {
  # Simple form: only hostname is required.
  hamsa = mkHost { hostname = "hamsa"; };
  garuda = mkHost { hostname = "garuda"; };

  # Richer form: extraModules and extraSpecialArgs extend the generated configuration.
  usb-installer = mkHost {
    hostname = "usb-installer";
    extraModules = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ./hosts/usb-installer/default.nix
    ];
    extraSpecialArgs = { inherit niri; };
  };
};
```

`mkHost` accepts `{ hostname, extraModules ? [ ], extraSpecialArgs ? { } }`. Note: the `iso`
configuration is NOT built via `mkHost` — an installer image has no
`hardware-configuration.nix`, which `mkHost` unconditionally requires, so `iso` is wired directly
with `lib.nixosSystem` in `flake.nix`.

## Building for a Host

```bash
# Using current hostname
sudo nixos-rebuild switch --flake .#$(hostname)

# Or use the update script (auto-detects hostname)
./scripts/update.sh
```

Available hosts: `garuda`, `nandi`, `hamsa`, `usb-installer`, `iso`

[← Back to main README](../README.md)