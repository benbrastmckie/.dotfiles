# Testing Instructions

This document provides instructions for testing the NixOS configuration, with a focus on validating unstable package management and system rebuilds.

## Testing the Configuration

Due to complexities with Nix's evaluation, you might encounter errors when running `nix flake check`. This is expected for packages with complex wrapper scripts like Neovim.

### Testing Methods

1. **Use the update script with no-check option:**
   ```bash
   cd ~/.dotfiles
   ./update.sh --no-check
   ```

2. **Apply configuration directly:**
   ```bash
   # System-wide rebuild (requires sudo)
   sudo nixos-rebuild switch --flake .#nandi --option allow-import-from-derivation false

   # User-specific home-manager configuration
   home-manager switch --flake .#benjamin --option allow-import-from-derivation false
   ```

## Verifying Unstable Packages

After rebuilding, verify that you're using the unstable versions:

### Neovim Verification

```bash
nvim --version
```

The version should match the one from the unstable channel. Since we're using neovim-unwrapped, check version details within Neovim as well.

### Claude Code Verification

Claude Code now uses an NPX wrapper for automatic version management:

```bash
# Check claude version
claude --version
# Should show latest version (2.0+) from NPM registry

# Verify wrapper location
which claude
# Should point to Nix store path containing NPX wrapper
```

### Other Package Verification

For packages like `niri`:

```bash
# Find the store path for a package
realpath $(which niri)
# Should contain a hash that matches the unstable package
```

## Managing Unstable Packages

### Adding New Unstable Packages

**Method 1: Overlay in flake.nix (for most packages)**

```nix
unstablePackagesOverlay = final: prev: {
  # Existing packages...
  
  # Your new package
  your-package = pkgs-unstable.your-package; # Reason for using unstable
};
```

**Method 2: Direct reference (for complex packages)**

```nix
home.packages = with pkgs; [
  # Other packages...
  pkgs-unstable.complex-package  # Direct reference to unstable
];
```

### Updating Unstable Packages

```bash
cd ~/.dotfiles
./update.sh
```

This updates flake inputs, including `nixpkgs-unstable`, and rebuilds the system.

## Troubleshooting

### Common Errors and Solutions

**Error: attribute 'maintainers' missing**

This happens with complex packages that have wrapper scripts. Solutions:

#### Solution 1: Use the Unwrapped Package

```nix
# In home.nix
programs.neovim = {
  enable = true;
  package = pkgs-unstable.neovim-unwrapped;  # Use unwrapped version directly
};
```

This bypasses the wrapper causing the error, but you might lose some wrapper features.

#### Solution 2: Use Special Build Flag

Always build with the `allow-import-from-derivation false` flag:

```bash
sudo nixos-rebuild switch --flake ~/.dotfiles/ --option allow-import-from-derivation false
```

The update.sh script includes this flag:

```bash
# In update.sh
sudo nixos-rebuild switch --flake .#$HOSTNAME --option allow-import-from-derivation false
home-manager switch --flake .#benjamin --option allow-import-from-derivation false
```

This flag bypasses attribute validation while allowing the package to build properly.

### Other Troubleshooting Steps

If you encounter other errors:

1. Check if there are breaking changes in the unstable package
2. Try using a direct reference to `pkgs-unstable` for specific packages
3. Verify package availability in the unstable channel
4. Check for additional configuration requirements

## Build Validation

To validate your configuration without applying it:

```bash
# Dry run system build
nixos-rebuild dry-build --flake .#hostname

# Check flake validity
nix flake check --option allow-import-from-derivation false
```

For more detailed information about the unstable package management approach, see [`docs/unstable-packages.md`](unstable-packages.md).