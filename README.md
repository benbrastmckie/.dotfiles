# NixOS Dotfiles

This repository contains my personal NixOS configuration using flakes and Home Manager for comprehensive system and user environment management.

## Overview

These dotfiles provide a complete NixOS setup with:

- **System Configuration**: NixOS system-wide settings via `configuration.nix`
- **User Environment**: Home Manager configuration in `home.nix`
- **Flake Management**: Modern Nix flake setup with pinned inputs
- **Custom Modules**: Extended functionality through custom Home Manager modules
- **Application Integration**: Configured applications with seamless integration

## Repository Structure

### Core Configuration Files

- [`configuration.nix`](configuration.nix): System-wide NixOS configuration
- [`home.nix`](home.nix): Home Manager user environment configuration
- [`flake.nix`](flake.nix): Nix flake with inputs, overlays, and host definitions

### Module Map

```
.
├── flake.nix                      # Inputs + overlays + nixosConfigurations + homeConfigurations
├── configuration.nix              # System NixOS config (boot, hardware, services, packages)
├── home.nix                       # User Home Manager config (apps, dotfiles, user services)
│
├── hosts/                         # Per-host hardware configurations
│   ├── nandi/hardware-configuration.nix   # Primary workstation (AMD Ryzen AI 300)
│   ├── hamsa/hardware-configuration.nix   # Secondary machine
│   ├── garuda/hardware-configuration.nix  # Laptop
│   └── usb-installer/hardware-configuration.nix
│
├── packages/                      # Custom derivations (not in nixpkgs)
│   ├── claude-code.nix            # Claude Code AI assistant (NPX wrapper)
│   ├── opencode.nix               # OpenCode AI coding agent (custom build)
│   ├── opencode-discord-bot.nix   # OpenCode Discord bot relay (buildPythonApplication)
│   ├── loogle.nix                 # Lean 4 Mathlib search tool
│   ├── aristotle.nix              # AI theorem prover wrapper
│   ├── slidev.nix                 # Presentation slides from Markdown
│   ├── kooha.nix                  # Screen recorder (GStreamer override)
│   ├── vosk-models.nix            # Vosk STT language models
│   ├── piper-bin.nix              # Piper TTS engine (prebuilt binary)
│   ├── piper-voices.nix           # Piper TTS voice models
│   ├── python-cvc5.nix            # CVC5 Python bindings
│   ├── pymupdf4llm.nix            # PyMuPDF4LLM Python package
│   └── python-vosk.nix            # Vosk Python package
│
├── overlays/
│   ├── claude-squad.nix           # claude-squad Go package build
│   ├── unstable-packages.nix      # Packages from nixpkgs-unstable
│   └── python-packages.nix        # Custom python3 packageOverrides
│
├── lib/
│   └── mkHost.nix                 # Helper to deduplicate host definitions
│
├── modules/
│   ├── system/                    # Always-on NixOS modules + optional/ (host-toggled)
│   └── home/                      # Home Manager modules (core/, desktop/, email/, ...)
│                                   # See modules/README.md for the full breakdown.
│
├── config/                        # Application configuration files
├── docs/                          # Documentation
├── secrets/                       # sops-encrypted secrets (secrets.yaml + .sops.yaml)
└── wallpapers/                    # Desktop wallpapers
```

### Directory Organization

- **[`config/`](config/)** - Application configuration files ([README](config/README.md))
- **[`docs/`](docs/)** - Detailed documentation for all components ([README](docs/README.md))
- **[`hosts/`](hosts/)** - Host-specific hardware configurations ([README](hosts/README.md))
- **[`modules/`](modules/)** - System (NixOS) and Home Manager modules, system/home split ([README](modules/README.md))
- **[`packages/`](packages/)** - Custom package definitions ([README](packages/README.md))

### Documentation Files

- [`docs/installation.md`](docs/installation.md): Setup and installation guide
- [`docs/usb-installer.md`](docs/usb-installer.md): Create bootable USB installer with your complete configuration
- [`docs/configuration.md`](docs/configuration.md): Core configuration details
- [`docs/applications.md`](docs/applications.md): Application-specific configurations
- [`docs/neovim.md`](docs/neovim.md): Neovim configuration, package choice, and sideloadInitLua gotcha
- [`docs/packages.md`](docs/packages.md): Package management and custom packages
- [`docs/testing.md`](docs/testing.md): Testing and validation procedures

See [`docs/README.md`](docs/README.md) for complete documentation index.

## Quick Start

For detailed installation instructions, see [`docs/installation.md`](docs/installation.md).

### Basic Setup

1. Clone repository: `git clone <repo-url> ~/.dotfiles`
2. Build system: `sudo nixos-rebuild switch --flake .#hostname`
3. Apply user config: `home-manager switch --flake .#benjamin`

> **Note**: Both commands evaluate `home.nix` — the NixOS rebuild manages
> `/etc/profiles/per-user/`, while `home-manager switch` manages `~/.nix-profile/`
> (which takes PATH priority). Run both to keep them in sync, or use `./scripts/update.sh`
> which handles everything.

### USB Installer

Create a bootable USB installer with your complete configuration:

```bash
# Build ISO (~30-60 minutes)
cd ~/.dotfiles
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# Decompress and write to USB
zstd -d result/iso/nixos-*.iso.zst -o /tmp/nixos-installer.iso
sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

See [`docs/usb-installer.md`](docs/usb-installer.md) for complete guide.

### Customization

- **System changes**: Edit [`configuration.nix`](configuration.nix)
- **User environment**: Edit [`home.nix`](home.nix)  
- **Package updates**: Modify [`flake.nix`](flake.nix) inputs
- **Application configs**: Update files in [`config/`](config/)

For comprehensive configuration details, see [`docs/configuration.md`](docs/configuration.md).

## Featured Applications

### Email (Himalaya)
Modern CLI email client with Gmail OAuth2 authentication and mbsync synchronization. Complete setup guide at [`docs/himalaya.md`](docs/himalaya.md).

### MCP-Hub 
Model Context Protocol integration for AI tools with Neovim. Architecture details in [`docs/applications.md`](docs/applications.md#mcp-hub-integration).

### Discord Bot (OpenCode Relay)
Nextcord bot bridging Discord to a headless OpenCode agent server. Secrets managed with sops-nix/age encryption, injected via systemd LoadCredential. Never touches disk unencrypted. Complete guide at [`docs/discord-bot.md`](docs/discord-bot.md).

### PDF Viewers
Custom Zathura and Sioyek configurations with title bar removal. Implementation details in [`docs/applications.md`](docs/applications.md#pdf-viewers).

### Development Environment
Comprehensive Neovim setup with language servers and tools. Package details in [`packages/`](packages/).

### Loogle - Lean 4 Search
CLI search tool for Lean 4's Mathlib library. Search theorems by name or type signature:
```bash
loogle 'List.map'              # Search by name
loogle '(List ?a -> ?a)'       # Search by type
loogle --interactive           # Interactive mode
```
First run downloads ~484 MB and builds cache. Subsequent runs are instant. See [`docs/development.md`](docs/development.md#lean-4-development) for usage guide.

### Text-to-Speech & Speech-to-Text
Offline TTS and STT tools for AI assistant integration with declaratively managed models:
- **Piper TTS**: Fast, local neural text-to-speech (en_US-lessac-medium voice) via a prebuilt
  binary — natural voice quality with no onnxruntime source compile
- **Vosk STT**: Lightweight offline speech recognition (models auto-installed via Nix)
- **Use cases**: Claude Code notifications, Neovim voice input, WezTerm integration

Models are reproducibly installed to `~/.local/share/` after `home-manager switch`. See [`docs/applications.md`](docs/applications.md#text-to-speech--speech-to-text) for usage.

For complete application configurations and setup instructions, see [`docs/applications.md`](docs/applications.md).

## Maintenance

### Full Update (recommended)
```bash
./scripts/update.sh  # updates flake inputs, rebuilds NixOS + home-manager (pass --checkpoint to auto-commit a dirty tree first; default refuses on a dirty tree)
```

### Manual Rebuilds
```bash
sudo nixos-rebuild switch --flake .#hostname   # system + NixOS-integrated home-manager
home-manager switch --flake .#benjamin         # standalone home-manager only (no sudo)
```

Both commands install `home.nix` packages to separate profile paths. `scripts/update.sh` runs
both in sequence to keep them in sync. For quick home-only changes, `home-manager switch`
alone is sufficient since `~/.nix-profile/` takes PATH priority.

### Optional: local flake-check hook

Every push and pull request is gated by a `nix-flake-check` GitHub Actions workflow
(`.github/workflows/ci.yml`) that runs `nix flake check` — this is the authoritative gate for
the repo, and CI failures are the source of truth.

If you'd like earlier local feedback before pushing, you can opt in to a local `pre-push` hook
that runs the same check. This is **not installed by default** and is entirely optional — it
does not conflict with the repo's frequent-commit cadence, since it only runs on `push`, not on
every commit. To opt in:

```bash
cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Running 'nix flake check' before push..."
nix flake check
EOF
chmod +x .git/hooks/pre-push
```

To remove it later, delete `.git/hooks/pre-push`.

## License

MIT
