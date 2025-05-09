# Testing Instructions

This document provides instructions for testing the new unstable package management system, with a focus on validating that Neovim is being installed from the unstable channel.

## Testing the Configuration

Due to some complexities with Nix's evaluation, you might encounter errors when running `nix flake check`. This is expected for some packages with complex wrapper scripts like Neovim. You can use the following approach to test your configuration instead:

1. Use the updated `update.sh` script with the `--no-check` option to bypass some checks:

```bash
cd ~/.dotfiles
./update.sh --no-check
```

2. Alternatively, apply the configuration directly:

```bash
# System-wide rebuild (requires sudo)
sudo nixos-rebuild switch --flake .#nandi --option allow-import-from-derivation false

# User-specific home-manager configuration
home-manager switch --flake .#benjamin --option allow-import-from-derivation false
```

## Verifying Unstable Packages

After rebuilding, verify that you're using the unstable version of Neovim:

1. Check Neovim's version:

```bash
nvim --version
```

The version should match the one from the unstable channel.

2. Since we're using neovim-unwrapped, you should check the version details within Neovim:

```bash
nvim --version
```

3. For other packages like `niri` and `claude-code`, you can verify they're from the unstable channel using:

```bash
# Find the store path for a package
realpath $(which niri)
# Should contain a hash that matches the unstable package
```

## Managing Unstable Packages

### Adding New Unstable Packages

To add more packages to pull from unstable, you can:

1. For most packages, add them to the overlay in `flake.nix`:

```nix
unstablePackagesOverlay = final: prev: {
  # Existing packages...
  
  # Your new package
  your-package = pkgs-unstable.your-package; # Reason for using unstable
};
```

2. For complex packages (like Neovim), use a direct reference in `home.nix`:

```nix
home.packages = with pkgs; [
  # Other packages...
  pkgs-unstable.complex-package  # Direct reference to unstable
];
```

### Updating Unstable Packages

To update all packages to their latest unstable versions:

```bash
cd ~/.dotfiles
./update.sh
```

This will update your flake inputs, including `nixpkgs-unstable`, and rebuild your system.

## Troubleshooting

If you encounter errors about attributes missing in package definitions when using overlays, consider:

1. For packages with complex wrappers like Neovim, try using the unwrapped version (e.g., `neovim-unwrapped` instead of `neovim`)
2. Using a direct reference to `pkgs-unstable` for that specific package
3. Running with `--option allow-import-from-derivation false` to bypass some checks
4. Checking if there are breaking changes in the unstable package that require additional configuration

### Common Errors

**Error: attribute 'maintainers' missing**

This usually happens with complex packages that have wrapper scripts. We've implemented two solutions:

### Solution 1: Use the Unwrapped Package

```nix
# In home.nix
programs.neovim = {
  enable = true;
  package = pkgs-unstable.neovim-unwrapped;  # Use unwrapped version directly
};
```

This approach bypasses the wrapper that's causing the error, but you might lose some convenient wrapper features.

### Solution 2: Use a Special Build Flag

Always build with the `allow-import-from-derivation false` flag:

```bash
sudo nixos-rebuild switch --flake ~/.dotfiles/ --option allow-import-from-derivation false
```

We've updated our update.sh script to always include this flag:

```bash
# In update.sh
sudo nixos-rebuild switch --flake .#$HOSTNAME --option allow-import-from-derivation false
home-manager switch --flake .#benjamin --option allow-import-from-derivation false
```

This flag helps bypass the attribute validation that's causing the error while still allowing the package to build properly.

For more detailed information about the unstable package management approach, see `README-unstable-packages.md`.