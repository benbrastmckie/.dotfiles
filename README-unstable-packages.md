# Managing Unstable Packages

This document explains the approach used for managing packages from the unstable channel within our NixOS configuration.

## Approach

We use a centralized overlay in `flake.nix` to selectively pull packages from the unstable channel while keeping the rest of the system on the stable channel. This approach:

1. Makes it explicit which packages are being pulled from unstable
2. Keeps the configuration clean and maintainable
3. Provides a central place to manage all unstable packages

## How It Works

1. We define both stable (`nixpkgs`) and unstable (`nixpkgs-unstable`) inputs in our flake
2. We create an overlay that selectively replaces stable packages with their unstable counterparts
3. We apply this overlay globally to our NixOS and Home Manager configurations

## Current Unstable Packages

The following packages are currently pulled from the unstable channel:

| Package          | Reason for using unstable |
|------------------|---------------------------|
| neovim-unwrapped | Get latest editor features and bug fixes |
| niri             | Window manager under active development |
| claude-code      | Latest AI capabilities and improvements |

## Adding New Unstable Packages

To add a new package to be pulled from unstable:

1. Add it to the `unstablePackagesOverlay` in `flake.nix`
2. Include a comment explaining why the package benefits from using the unstable version
3. Use the package as normal with `pkgs.package-name` throughout your configuration

## Example

```nix
unstablePackagesOverlay = final: prev: {
  # Development tools
  neovim-unwrapped = pkgs-unstable.neovim-unwrapped; # Get latest Neovim features and bug fixes
  
  # Add your package here
  your-package = pkgs-unstable.your-package; # Reason for using unstable
};
```

## Note on Complex Packages

For some complex packages like Neovim that have wrapper scripts with potential attribute errors, we have two approaches:

### Approach 1: Use the Unwrapped Package Directly

The simplest approach is to use the unwrapped version of the package directly from unstable:

```nix
# In home.nix
programs.neovim = {
  enable = true;
  package = pkgs-unstable.neovim-unwrapped;  # Use neovim-unwrapped directly from unstable
};
```

This approach bypasses the wrapper that's causing the maintainers attribute error.

### Approach 2: Build with Special Flags

For building the system, we use the special flag `--option allow-import-from-derivation false` to bypass attribute errors:

```bash
# In update.sh
sudo nixos-rebuild switch --flake .#hostname --option allow-import-from-derivation false
home-manager switch --flake .#username --option allow-import-from-derivation false
```

This flag helps avoid issues with complex wrapper scripts and their attributes.

This approach gives us the latest Neovim features from unstable while properly handling the meta attributes to avoid build errors.