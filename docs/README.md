# Documentation

This directory contains comprehensive documentation for the NixOS configuration setup.

## Documentation Files

### Getting Started
- **[installation.md](installation.md)** - Setup and installation guide
- **[usb-installer.md](usb-installer.md)** - Create bootable USB installer with your complete configuration
- **[configuration.md](configuration.md)** - Core configuration details
- **[testing.md](testing.md)** - Testing and validation procedures

### Package Management
- **[packages.md](packages.md)** - Package management and custom packages
- **[unstable-packages.md](unstable-packages.md)** - Managing unstable channel packages

### Applications & Desktop
- **[applications.md](applications.md)** - Application-specific configurations
- **[discord-bot.md](discord-bot.md)** - Discord bot infrastructure and secrets management
- **[himalaya.md](himalaya.md)** - Himalaya email client setup and configuration
- **[neovim.md](neovim.md)** - Neovim configuration, package choice, and sideloadInitLua gotcha
- **[niri.md](niri.md)** - Niri window manager keybindings and configuration
- **[terminal.md](terminal.md)** - WezTerm and Kitty terminal configuration
- **[dictation.md](dictation.md)** - Whisper dictation system setup

### Development & Hardware
- **[development.md](development.md)** - Development notes and workflows
- **[wifi.md](wifi.md)** - **CRITICAL:** WiFi configuration requirements and troubleshooting
- **[ryzen-ai-300-compatibility.md](ryzen-ai-300-compatibility.md)** - AMD Ryzen AI 300 series hardware support
- **[ryzen-ai-300-support-summary.md](ryzen-ai-300-support-summary.md)** - Ryzen AI 300 support summary

## Reading Order

For new users, we recommend reading in this order:
1. [installation.md](installation.md) - Get the system running
2. [configuration.md](configuration.md) - Understand the configuration structure
3. [applications.md](applications.md) - Configure applications
4. [packages.md](packages.md) - Manage packages

For creating a portable installer:
1. [usb-installer.md](usb-installer.md) - Complete USB installer guide

## Quick Reference

### System Management
- **System rebuild**: `sudo nixos-rebuild switch --flake .#hostname`
- **User config**: `home-manager switch --flake .#benjamin`
- **Update flake**: `nix flake update`
- **Full update**: `./update.sh`

### USB Installer
- **Build ISO**: `nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage`
- **Write to USB**: `sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M conv=fsync status=progress`

## Documentation Conventions

### Inline comments in nix files

Keep inline comments to 1-4 lines explaining **why** a decision was made or why a
workaround exists -- not what the code does (that is visible from the code itself).

Use consistent severity prefixes:
- `# Note:` -- for implementation notes, rationale, and context
- `# Critical:` -- for must-know warnings and footguns

Avoid ALL_CAPS variants (`NOTE:`, `WARNING:`, `IMPORTANT:`).

### Cross-references to docs/

When an inline comment touches on a decision, gotcha, or workaround with fuller
context in a `docs/` file, append a cross-reference trailer:

```nix
# Note: jsregexp is required by LuaSnip for snippet expansion.
# See docs/neovim.md.
```

The `# See docs/X.md.` pattern is the standard cross-reference format.

### Inline vs. docs/

| Context | Goes inline | Goes in docs/ |
|---------|-------------|---------------|
| Why a specific option is set | Brief rationale (1-4 lines) | Full context, alternatives considered |
| Gotchas and workarounds | Summary and severity | Step-by-step explanation, history |
| Config values | Not needed (visible in code) | Not needed |
| Architecture decisions | Brief pointer | Full explanation with trade-offs |
| How-to guides and workflows | Not inline | Full procedure in docs/ |

### Adding new docs/ files

When a topic outgrows inline comments, create a new `docs/` file:
1. Add the file to `docs/README.md` under the appropriate category
2. Add a cross-reference to root `README.md` if the topic is user-facing
3. Add a `# See docs/X.md.` trailer to the relevant inline comment in the nix file

### Prohibited practices

- **No `NOTES.md`** -- `docs/` is the single authoritative home for documentation.
  Do not use a catch-all file as a staging area.
- **No emojis** in documentation files.
- **No "Quick Reference" documents** -- quick-reference content belongs within the
  authoritative topic file.

[← Back to main README](../README.md)
