# Custom Packages

This directory contains custom package definitions and configurations for the NixOS setup.

## Files

### claude-code.nix
NPX wrapper for Claude Code that automatically uses the latest version from NPM registry. This zero-maintenance approach eliminates the need for manual version updates and hash calculations while providing access to all Claude Code 2.0+ features.

**Implementation**: Uses `writeShellScriptBin` to create a simple wrapper that executes `npx @anthropic-ai/claude-code@latest`

**Benefits**:
- Automatic updates to latest version
- Zero maintenance required
- 86% reduction in code complexity compared to traditional Nix packaging
- Offline support via NPX caching

### marker-pdf.nix
UV wrapper for marker-pdf that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing PDF to markdown conversion capabilities.

**Implementation**: Uses `writeShellScriptBin` with `uv run` to execute marker-pdf in an isolated environment

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Isolated environment prevents dependency conflicts
- Handles complex dependencies (PyTorch, etc.) automatically

**Usage**: Available as `marker_pdf` command after home-manager rebuild.

### markitdown.nix
UV wrapper for markitdown that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing document to markdown conversion capabilities.

**Implementation**: Uses `writeShellScriptBin` with `uv run` to execute markitdown in an isolated environment

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Isolated environment prevents dependency conflicts
- Handles PDF, DOCX, PPTX, and other document formats

**Usage**: Available as `markitdown` command after home-manager rebuild.

### python-cvc5.nix
Custom Python package for CVC5 v1.3.1 SMT solver bindings. Nixpkgs does not provide `python312Packages.cvc5`, so this package builds from the PyPI wheel.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pre-built manylinux wheel, then uses `autoPatchelfHook` to fix shared library paths for the bundled native C++ extensions.

**Dependencies**:
- `autoPatchelfHook`: Automatically fixes shared library paths
- `stdenv.cc.cc.lib`: Provides `libstdc++.so.6` for C++ bindings

**Usage**: Available in `python312.withPackages` via the `pythonPackagesOverlay` defined in `flake.nix`:

```nix
home.packages = with pkgs; [
  (python312.withPackages(p: with p; [
    cvc5
    # ... other packages
  ]))
];
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/cvc5/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/.../cvc5-VERSION-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl`
3. Update `version` and `sha256` in `python-cvc5.nix`
4. Commit changes and rebuild: `home-manager switch --flake .#benjamin`
5. Test: `python3 -c "import cvc5; print(cvc5.__version__)"`

**Related**:
- Report: `specs/reports/011_cvc5_nixos_installation_strategy.md`
- Plan: `specs/plans/009_cvc5_python_bindings_overlay.md`

### neovim.nix
A wrapper around Neovim unstable that fixes missing maintainers metadata to prevent build errors.

### test-mcphub.sh
A diagnostic script for verifying MCPHub installation and configuration in Neovim.

## MCPHub Integration

MCPHub is integrated as a standard Neovim plugin using lazy.nvim plugin loading.

### Implementation
MCPHub is loaded via lazy.nvim in the Neovim configuration with the following setup:
- Port: 37373
- Configuration: `~/.config/mcphub/servers.json`
- Integration with Avante for AI functionality

### Testing
Use `test-mcphub.sh` to verify MCPHub installation:

```bash
bash ~/.dotfiles/packages/test-mcphub.sh
```

The script checks:
- MCPHub binary accessibility
- Configuration directory and files
- Server functionality (optional)

[← Back to main README](../README.md)