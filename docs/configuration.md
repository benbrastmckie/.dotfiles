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
├── overlays/              # Extracted overlays (claude-squad, unstable, python) — see overlays/README.md
├── lib/                   # mkHost helper function (lib/mkHost.nix)
└── modules/               # system/ (NixOS) + home/ (Home Manager) — see modules/README.md
```

## configuration.nix

A thin import shim: it imports `./modules/system` (the NixOS aggregator, see
[`modules/README.md`](../modules/README.md)) and sets `system.stateVersion`. All actual system
configuration — packages, services, boot, hardware, users — lives in `modules/system/*.nix`, not
in this file. Optional/host-toggled modules (e.g. `modules/system/optional/discord-bot.nix`) are
wired in per-host instead, via `hosts/<name>/default.nix` + `extraModules` in `flake.nix`.

Key module categories under `modules/system/` include:
- Boot loader and kernel configuration (`boot.nix`)
- Hardware enablement — graphics, sound, power/lid behavior (`desktop.nix`, `audio.nix`, `power.nix`)
- Network services and firewall (`networking.nix`)
- Desktop environment setup (`desktop.nix`, `display.nix`)
- Security and user management (`users.nix`)

## flake.nix

The Nix flake that orchestrates the entire configuration:

- Defines inputs (nixpkgs, home-manager, lean4, lectic, niri, sops-nix, utils)
- Specifies system outputs (`nixosConfigurations`, `homeConfigurations`)
- Manages flake inputs and versions (flake.lock)
- Configures both NixOS and Home Manager for all hosts

### Package Overlays (extracted files under overlays/, applied via flake.nix)

The flake configuration uses overlays to extend and customize nixpkgs. Each overlay is a
standalone file under `overlays/` (see [`overlays/README.md`](../overlays/README.md)):

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

A thin import shim: it imports `./modules/home` (the Home Manager aggregator, see
[`modules/README.md`](../modules/README.md)) and sets `home.username`, `home.homeDirectory`, and
`home.stateVersion`. All actual user-environment configuration — application configs, dotfiles,
shell configuration, user packages, and user services — lives in `modules/home/**/*.nix`, not in
this file. The aggregator groups imports by category (Core, Desktop, Email, Packages, Scripts,
Services, Memory).

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