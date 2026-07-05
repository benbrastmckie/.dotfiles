# Managing Unstable Packages

This document explains the approach used for managing packages from the unstable channel within the NixOS configuration.

> **Note**: The root-level `unstable-packages.nix` file has been deleted (task 66, Phase 1).
> Unstable package management now lives entirely in `flake.nix` (overlay inline, pending
> Phase 2 extraction to `overlays/unstable-packages.nix`).

## Approach

The configuration uses a centralized overlay (`unstablePackagesOverlay`) defined in `flake.nix`
and implemented in `overlays/unstable-packages.nix` (`flake.nix:59` imports it, curried with
`pkgs-unstable`) to selectively pull packages from the unstable channel while keeping the rest of
the system on the stable channel. This approach:

1. Makes it explicit which packages are being pulled from unstable
2. Keeps the configuration clean and maintainable
3. Provides a central place to manage all unstable packages

## How It Works

1. Both stable (`nixpkgs`) and unstable (`nixpkgs-unstable`) inputs are defined in the flake
2. An overlay selectively replaces stable packages with their unstable counterparts
3. This overlay is applied globally to NixOS and Home Manager configurations

## Current Unstable Packages

The following packages are currently pulled from the unstable channel (in `flake.nix` →
`unstablePackagesOverlay`):

| Package              | Reason for using unstable |
|----------------------|---------------------------|
| neovim-unwrapped     | Get latest editor features and bug fixes |
| niri                 | Window manager under active development |
| gemini-cli           | Google Gemini AI CLI tool |
| claude-code          | Custom build (packages/claude-code.nix) |
| opencode             | Custom build (packages/opencode.nix) |
| loogle               | Custom Lean 4 Mathlib search wrapper |
| aristotle            | Custom AI theorem prover wrapper |
| slidev               | Custom presentation tool wrapper |
| kooha                | Screen recorder with full GStreamer support |
| vosk-model-small-en-us | Vosk STT language model |

**Note**: `claude-code` and `opencode` are custom packages (not pulled from nixpkgs-unstable
directly) — they live in `packages/` as callPackage derivations overlaid via `unstablePackagesOverlay`.

## Adding New Unstable Packages

To add a new package to be pulled from unstable:

1. Add it to the `unstablePackagesOverlay` in `flake.nix` (after Phase 2: `overlays/unstable-packages.nix`)
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
# In scripts/update.sh
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
./scripts/update.sh
```

This updates flake inputs, including `nixpkgs-unstable`, and rebuilds the system.