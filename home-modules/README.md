# Home Manager Modules

This directory contains custom Home Manager modules that extend the base functionality.

## Modules

- **mcp-hub.nix**: Custom module for integrating MCP-Hub with Neovim
  - Provides the `programs.neovim.mcp-hub` option
  - Manages environment variables for Neovim integration
  - Sets up configuration directory structure
  - Configurable port (default: 37373)

These modules are imported in `home.nix` to provide additional configuration options.