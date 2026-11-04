# NixOS Dotfiles

This repository contains my personal NixOS configuration using flakes and Home Manager for comprehensive system and user environment management.

## Overview

These dotfiles provide a complete NixOS setup with:

- **System Configuration**: NixOS system-wide settings via `modules/system/*.nix`
- **User Environment**: Home Manager configuration in `modules/home/**/*.nix`
- **Flake Management**: Modern Nix flake setup with pinned inputs
- **Custom Modules**: Extended functionality through custom Home Manager modules
- **Application Integration**: Configured applications with seamless integration

## Repository Structure

### Core Configuration Files

- [`configuration.nix`](configuration.nix): A thin import shim -- imports `./modules/system`
  (the NixOS aggregator) and sets `system.stateVersion`. Real system configuration lives in
  `modules/system/*.nix`.
- [`home.nix`](home.nix): A thin import shim -- imports `./modules/home` (the Home Manager
  aggregator). Real user environment configuration lives in `modules/home/**/*.nix`.
- [`flake.nix`](flake.nix): Nix flake with inputs, overlays, and host definitions

### Module Map

```
.
├── flake.nix                      # Inputs + overlays + nixosConfigurations + homeConfigurations
├── configuration.nix              # Thin import shim -> modules/system/
├── home.nix                       # Thin import shim -> modules/home/
│
├── hosts/                         # Per-host hardware configurations
│   ├── nandi/hardware-configuration.nix   # Primary workstation (Intel)
│   ├── hamsa/hardware-configuration.nix   # Secondary machine (AMD Ryzen AI 300)
│   ├── garuda/hardware-configuration.nix  # Laptop
│   └── usb-installer/hardware-configuration.nix
│
├── packages/                      # Custom derivations (not in nixpkgs)
│   ├── claude-code.nix            # Claude Code AI assistant (NPX wrapper)
│   ├── opencode.nix               # OpenCode AI coding agent (custom build; currently not installed)
│   ├── opencode-discord-bot.nix   # OpenCode Discord bot relay (buildPythonApplication; currently disabled)
│   ├── opencode-discord-bot/      # Bot source (co-located with the derivation above)
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
- **[`overlays/`](overlays/)** - Nix overlays extending nixpkgs ([README](overlays/README.md))
- **[`packages/`](packages/)** - Custom package definitions ([README](packages/README.md))

### Documentation Files

- [`docs/installation.md`](docs/installation.md): Setup and installation guide
- [`docs/usb-installer.md`](docs/usb-installer.md): Create bootable USB installer with your complete configuration
- [`docs/configuration.md`](docs/configuration.md): Core configuration details
- [`docs/applications.md`](docs/applications.md): Application-specific configurations
- [`docs/neovim.md`](docs/neovim.md): Neovim configuration, package choice, and sideloadInitLua gotcha
- [`docs/packages.md`](docs/packages.md): Package management and custom packages
- [`docs/screen-recording.md`](docs/screen-recording.md): Screen capture tools and the boosted-microphone PipeWire filter chain
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

- **System changes**: Edit `modules/system/*.nix`
- **User environment**: Edit `modules/home/**/*.nix`
- **Package updates**: Modify [`flake.nix`](flake.nix) inputs
- **Application configs**: Update files in [`config/`](config/)

For comprehensive configuration details, see [`docs/configuration.md`](docs/configuration.md).

## Featured Applications

### Email (Himalaya)
Modern CLI email client with Gmail OAuth2 authentication and mbsync synchronization. Complete setup guide at [`docs/himalaya.md`](docs/himalaya.md).

### MCP-Hub 
Model Context Protocol integration for AI tools with Neovim. Architecture details in [`docs/applications.md`](docs/applications.md#mcp-hub-integration).

### Discord Bot (OpenCode Relay)
**Currently disabled on all hosts** (host opt-ins and the `opencode` CLI are commented out; see the status note in the guide to re-enable). Nextcord bot bridging Discord to a headless OpenCode agent server. Secrets managed with sops-nix/age encryption, injected via systemd LoadCredential. Never touches disk unencrypted. Complete guide at [`docs/discord-bot.md`](docs/discord-bot.md).

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

### Sapience (AI Knowledge Vault)
Extracts durable facts from Claude Code and Codex session transcripts into a searchable vault,
exposed to Claude Code as an MCP server. Replaces the vendor's macOS-only installer with a
home-manager module: store-resolved CLI wrappers, a systemd user timer in place of the launchd
plist, and a declarative `~/.claude.json` registration.

Extraction runs on-device against a local Ollama server, so transcript text does not leave the
machine, and findings stay staged until reviewed. Run `sapience-bootstrap` once to set up. See
[`docs/sapience.md`](docs/sapience.md) for setup, what each backend transmits, and rollback.

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

### Local pre-push gate

Every push to `master` and every pull request is gated by the `nix-flake-check` GitHub Actions
workflow ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)), which does nothing but run
`nix flake check`. The lints are defined as `checks.<system>.*` in
[`flake.nix`](flake.nix) rather than as workflow steps, so **one command reproduces CI exactly**:

```bash
nix flake check -L
```

What it covers: `statix`, `deadnix`, `nixfmt --check`, `shellcheck` over `scripts/`, `tests/` and
`.githooks/`, evaluation of all five `nixosConfigurations` entries, and evaluation of the
standalone home-manager generation. It does not *build* any system closure — that is what
`./scripts/update.sh` does on the machine itself.

To catch a failure before it reaches CI, install the tracked pre-push hook (once per clone):

```bash
./scripts/install-git-hooks.sh
```

This points `core.hooksPath` at [`.githooks/`](.githooks), so the hook is version-controlled
instead of hand-copied into `.git/hooks/`. On push it runs only the four lint checks — about a
second when cached, versus minutes for the full evaluation set — and refuses the push if any
fail. It does not run on commit, so the frequent-commit cadence is unaffected.

Escape hatches:

```bash
git push --no-verify           # skip every hook, once
SKIP_FLAKE_CHECK=1 git push    # skip just the lint checks, once
git config --unset core.hooksPath   # uninstall
```

When something does fail: `nix fmt` fixes formatting and
`nix develop --command statix fix` fixes most statix findings.

## License

MIT
