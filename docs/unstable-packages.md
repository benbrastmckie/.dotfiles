# Managing Unstable Packages

This document explains the approach used for managing packages from the unstable channel within the NixOS configuration.

## Approach

The configuration uses a centralized overlay in `flake.nix` to selectively pull packages from the unstable channel while keeping the rest of the system on the stable channel. This approach:

1. Makes it explicit which packages are being pulled from unstable
2. Keeps the configuration clean and maintainable
3. Provides a central place to manage all unstable packages

## How It Works

1. Both stable (`nixpkgs`) and unstable (`nixpkgs-unstable`) inputs are defined in the flake
2. An overlay selectively replaces stable packages with their unstable counterparts
3. This overlay is applied globally to NixOS and Home Manager configurations

## Current Unstable Packages

The following packages are currently pulled from the unstable channel:

| Package          | Reason for using unstable |
|------------------|---------------------------|
| neovim-unwrapped | Get latest editor features and bug fixes |
| niri             | Window manager under active development |
| gemini-cli       | Google Gemini AI CLI tool |
| goose-cli        | Block's open source AI coding agent |

**Note**: `claude-code` was previously managed via unstable packages but has been migrated to a custom NPX wrapper approach for zero-maintenance automatic updates. See `packages/claude-code.nix` and the NPX Wrapper Pattern section in `CLAUDE.md` for details.

## Adding New Unstable Packages

To add a new package to be pulled from unstable:

1. Add it to the `unstablePackagesOverlay` in `flake.nix`
2. Include a comment explaining why the package benefits from using the unstable version
3. Use the package as normal with `pkgs.package-name` throughout your configuration

### Example

```nix
unstablePackagesOverlay = final: prev: {
  # Development tools
  neovim-unwrapped = pkgs-unstable.neovim-unwrapped; # Get latest Neovim features and bug fixes
  
  # Add your package here
  your-package = pkgs-unstable.your-package; # Reason for using unstable
};
```

## Handling Complex Packages

For complex packages like Neovim that have wrapper scripts with potential attribute errors, there are two approaches:

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

For building the system, use the special flag `--option allow-import-from-derivation false` to bypass attribute errors:

```bash
# In update.sh
sudo nixos-rebuild switch --flake .#hostname --option allow-import-from-derivation false
home-manager switch --flake .#username --option allow-import-from-derivation false
```

This flag helps avoid issues with complex wrapper scripts and their attributes while giving access to the latest Neovim features from unstable.

## Troubleshooting

### Common Error: attribute 'maintainers' missing

This usually happens with complex packages that have wrapper scripts. Solutions:

1. **Use the unwrapped package** (bypasses wrapper issues)
2. **Use the allow-import-from-derivation false flag** (bypasses attribute validation)
3. **Direct reference to pkgs-unstable** for specific packages

### Updating Unstable Packages

To update all packages to their latest unstable versions:

```bash
cd ~/.dotfiles
./update.sh
```

This updates flake inputs, including `nixpkgs-unstable`, and rebuilds the system.