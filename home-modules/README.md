# Home Manager Modules

This directory contains custom Home Manager modules that extend the base functionality.

## Modules

- **mcp-hub.nix**: Custom module for MCP-Hub configuration (currently unused)

These modules are available for import in `home.nix` to provide additional configuration options.

## Usage

Custom modules can be imported in `home.nix` using:
```nix
imports = [
  ./home-modules/module-name.nix
];
```

[← Back to main README](../README.md)