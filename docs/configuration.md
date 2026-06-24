# NixOS Configuration Details

## File Structure

The configuration spans three primary files and several support directories:

```
.
├── flake.nix              # Inputs, overlays, host definitions, homeConfigurations
├── configuration.nix      # System-level NixOS options (packages, services, boot, users)
├── home.nix               # Home Manager options (user packages, dotfiles, user services)
├── hosts/                 # Per-host hardware-configuration.nix files
│   ├── nandi/             # Primary workstation
│   ├── hamsa/             # Secondary machine
│   ├── garuda/            # Laptop
│   └── usb-installer/     # USB installer image
├── packages/              # Custom derivations (claude-code, opencode, loogle, etc.)
├── overlays/              # (planned) Extracted overlays (claude-squad, unstable, python)
├── lib/                   # (planned) mkHost helper function
└── modules/               # Stub scaffold (opencode.nix; home-modules/ stubs)
```

> **Task 66 status**: Phases 2-6 (structural split into `modules/system/`, `modules/home/`,
> `lib/mkHost.nix`, `overlays/`) are gated on tasks 62 and 65 completing first.
> Phase 1 quick wins are complete (SASL_PATH fix, duplicate package removal, follows additions).

## configuration.nix

The main system configuration file that defines:

- System packages and services
- Boot configuration
- Hardware settings
- Network configuration
- User accounts and permissions
- System-wide environment variables

Key sections include:
- Boot loader and kernel configuration
- Hardware enablement (graphics, sound, etc.)
- Network services and firewall
- Desktop environment setup
- Security and user management

## flake.nix

The Nix flake that orchestrates the entire configuration:

- Defines inputs (nixpkgs, home-manager, lean4, lectic, niri, sops-nix, utils)
- Specifies system outputs (`nixosConfigurations`, `homeConfigurations`)
- Manages flake inputs and versions (flake.lock)
- Configures both NixOS and Home Manager for all hosts

### Package Overlays (inlined in flake.nix, pending Phase 2 extraction)

The flake configuration uses overlays to extend and customize nixpkgs:

**Claude Squad Overlay** (`claudeSquadOverlay`):
- Builds Claude Squad from source (GitHub)
- Provides terminal app for managing multiple AI agents
- Creates `cs` alias for `claude-squad` command

**Unstable Packages Overlay** (`unstablePackagesOverlay`):
- Provides access to nixpkgs-unstable packages and custom derivations
- Used for rapidly-updating development tools
- See [`unstable-packages.md`](unstable-packages.md) for the full list

**Python Packages Overlay** (`pythonPackagesOverlay`):
- Extends `python3` with custom packages via `packageOverrides`
- Currently provides: `cvc5`, `pymupdf4llm`, `vosk`, patched `httplib2`/`pymupdf`
- Enables declarative Python package management via overlays

All overlays are applied via `nixpkgsConfig` in the flake, making customized packages available throughout the system.

## home.nix

User-specific configuration managed by Home Manager:

- Application configurations
- Dotfiles management
- Shell configuration
- Package installation for user environment
- Service management for user sessions

## Terminal Emulator Configurations

### WezTerm

The configuration at `config/wezterm.lua` provides a modern, GPU-accelerated terminal experience:

**Key Features:**
- RobotoMono Nerd Font with 12pt size
- GPU acceleration via WebGpu with high performance preference
- Fullscreen on startup with no window decorations
- Semi-transparent background (0.9 opacity)
- Custom color scheme matching Kitty terminal
- Mouse support with right-click paste
- Sleek tab bar at bottom with custom styling

**Keybindings:**
- Leader key: `Ctrl+Space` (matching Kitty)
- Tab management: `Leader+c` (new), `Leader+k` (close), `Leader+n/p` (navigate)
- Font size: `Ctrl+Shift+=/-` for zoom
- Copy/Paste: `Ctrl+Shift+C/V` (leaves `Ctrl+C` for terminal interrupts)

**Integration:**
- Uses Fish shell as default
- Copy-on-select enabled
- Wayland support enabled for Linux systems

## Memory Management

The system uses a three-tier memory management strategy optimized for desktop workloads with heavy development tools (Claude, browsers, Node.js).

### OOM Killer

**earlyoom** is the sole OOM killer (systemd-oomd is disabled to avoid conflict):
- Triggers at 10% free RAM or 10% free swap
- Sends SIGTERM first, then SIGKILL after 1 second
- Prefers killing `claude`, `node`, and `npm` processes
- Provides desktop notifications when processes are killed

```nix
systemd.oomd.enable = false;  # Disabled — earlyoom handles OOM protection
```

### Swap Hierarchy

Two swap devices operate in priority order:

| Priority | Type | Size | Purpose |
|----------|------|------|---------|
| 5 (high) | zram | ~16GB | Compressed in-RAM swap, fast |
| -2 (low) | swapfile | 16GB | Disk-based fallback |

zram is configured with zstd compression at 50% of system RAM:

```nix
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 50;
  priority = 5;
};
```

### VM Kernel Parameters

Tuned for desktop responsiveness with zram:

| Parameter | Value | Default | Effect |
|-----------|-------|---------|--------|
| `vm.swappiness` | 10 | 60 | Keeps more data in RAM |
| `vm.watermark_boost_factor` | 0 | 15000 | Disables watermark boosting |
| `vm.watermark_scale_factor` | 125 | 10 | Earlier memory reclaim |
| `vm.page-cluster` | 0 | 3 | Disables readahead (zram doesn't benefit) |

**Verify settings**: `sysctl vm.swappiness vm.watermark_boost_factor vm.watermark_scale_factor vm.page-cluster`

**Check swap status**: `swapon --show` and `zramctl`

> Note: Hibernation is not supported — it requires swap ≥ RAM (32GB+).

## Key Integration Points

- Flake inputs provide package sources
- Home Manager integrates with NixOS for user configuration
- Custom modules extend functionality
- Environment variables bridge NixOS and user applications
- Discord bot infrastructure (sops-nix secrets, systemd services, Python environment) — see [`discord-bot.md`](discord-bot.md)