# Package Management

## Package Sources

### Stable Packages

Main package set from nixpkgs stable channel:
- System utilities and core applications
- Well-tested packages with stability focus
- Default choice for most applications

### Unstable Packages

Packages from nixpkgs unstable channel defined in `unstable-packages.nix`:
- Latest versions of development tools
- Packages requiring newer features
- Applications needing frequent updates

### Custom Packages

Custom package definitions in `packages/`:

#### Neovim (packages/neovim.nix)

Comprehensive Neovim configuration:
- Language servers and tools
- Plugin dependencies
- Custom build with specific features
- Integration with system clipboard and external tools

#### Package Structure

- Package derivations and build instructions
- Custom wrappers for applications
- Build scripts and testing utilities

## Adding Packages

### System Packages

Add to `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  package-name
];
```

### User Packages

Add to `home.nix`:
```nix
home.packages = with pkgs; [
  package-name
];
```

### Unstable Packages

Add to `unstable-packages.nix` and reference in configurations.

## Package Testing

Use `packages/test-mcphub.sh` as template for testing custom packages:
- Verify installation
- Test functionality
- Validate dependencies