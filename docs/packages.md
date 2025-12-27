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

#### Python Packages (packages/python-cvc5.nix)

Custom Python packages are integrated via overlays defined in `flake.nix`:

**CVC5 SMT Solver Bindings (v1.3.1)**:
- Custom package for CVC5 Python bindings (not available in nixpkgs)
- Built from PyPI wheel with autoPatchelfHook for native libraries
- Integrated via `pythonPackagesOverlay` in `flake.nix`
- Available in `python312.withPackages` alongside standard packages
- Requires `LD_LIBRARY_PATH` configuration for C++ dependencies

See [`packages/README.md`](../packages/README.md) for detailed documentation on custom packages.

**Related Documentation**:
- Implementation plan: [`specs/plans/009_cvc5_python_bindings_overlay.md`](../specs/plans/009_cvc5_python_bindings_overlay.md)
- Research report: [`specs/reports/011_cvc5_nixos_installation_strategy.md`](../specs/reports/011_cvc5_nixos_installation_strategy.md)

#### Claude Code (packages/claude-code.nix)

NPX wrapper for Claude Code that automatically uses the latest version:
- Zero-maintenance approach (no version pinning)
- Simple shell script wrapper around `npx @anthropic-ai/claude-code@latest`
- Offline support via NPX caching

#### Loogle (packages/loogle.nix)

Wrapper script for the Lean 4 Mathlib search tool:
- Lazy installation: clones and builds on first run
- Caches everything in `~/.cache/loogle/` for fast subsequent runs
- Uses Nix development shell for reproducible builds
- Automatically manages Lean toolchain via elan
- First run downloads ~484 MB and takes 1-2 minutes
- Subsequent runs are instant

Usage: `loogle 'List.map'` or `loogle --help`

See [Development Guide](development.md#lean-4-development) for detailed usage.

#### Package Structure

- Package derivations and build instructions
- Custom wrappers for applications
- Python package overlays for missing nixpkgs packages
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