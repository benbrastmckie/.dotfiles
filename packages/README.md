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