# NixOS Configuration Details

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

- Defines inputs (nixpkgs, home-manager, etc.)
- Specifies system outputs
- Manages flake inputs and versions
- Configures both NixOS and Home Manager

### Package Overlays

The flake configuration uses overlays to extend and customize nixpkgs:

**Claude Squad Overlay** (`claudeSquadOverlay`):
- Builds Claude Squad from source (GitHub)
- Provides terminal app for managing multiple AI agents
- Creates `cs` alias for `claude-squad` command

**Unstable Packages Overlay** (`unstablePackagesOverlay`):
- Provides access to nixpkgs-unstable packages
- Used for rapidly-updating development tools
- Currently includes: niri (window manager), claude-code (custom NPX wrapper)

**Python Packages Overlay** (`pythonPackagesOverlay`):
- Extends Python 3.12 with custom packages
- Currently provides CVC5 SMT solver bindings (v1.3.1)
- Packages not available in standard nixpkgs
- Enables declarative Python package management via overlays

All overlays are applied via the `nixpkgsConfig` in the flake, making customized packages available throughout the system.

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

## Secrets Management (sops-nix)

Secrets are managed with sops-nix using age encryption. The sops-nix flake input is imported as a NixOS module on all hosts (hamsa, nandi, iso, usb-installer).

### Key Files

| File | Purpose |
|------|---------|
| `.sops.yaml` | Age public key + creation rules for `secrets/*.yaml` |
| `secrets/secrets.yaml` | Encrypted secrets (committed encrypted) |
| `~/.config/sops/age/keys.txt` | Age private key (**never committed**) |

### NixOS Configuration

sops-nix decrypts secrets at activation time to `/run/secrets/` (tmpfs):

```nix
sops = {
  defaultSopsFile = ./secrets/secrets.yaml;
  age.sshKeyPaths = [ "/home/benjamin/.config/sops/age/keys.txt" ];

  secrets = {
    "discord_bot_token" = {
      owner = config.users.users.benjamin.name;
    };
    "opencode_server_password" = {
      owner = config.users.users.benjamin.name;
    };
  };
};
```

### Operations

```bash
sops secrets/secrets.yaml              # Edit secrets interactively
sops --decrypt secrets/secrets.yaml    # View plaintext (read-only)
sops --rotate secrets/secrets.yaml     # Re-encrypt after key change
```

Full documentation: [`docs/discord-bot.md`](discord-bot.md)

## Systemd Services

### opencode-serve

Persistent headless OpenCode agent server. Binds to `127.0.0.1`, receives server password via `LoadCredential` from sops-nix. Runs as user `benjamin`.

```nix
ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1"
```

### discord-bot

Nextcord Discord bot relay for OpenCode agent management. Depends on `opencode-serve.service` (Requires + After). Uses the dedicated `discordBotPython` environment, not global system Python. Injectes both Discord token and server password via `LoadCredential`.

```nix
ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot"
PYTHONPATH = "/home/benjamin/.dotfiles/opencode-discord-bot"
```

Both services use `Type=simple`, `Restart=always`, `RestartSec=10s`, and `WantedBy=multi-user.target`.

Full documentation: [`docs/discord-bot.md`](discord-bot.md)

## Key Integration Points

- Flake inputs provide package sources
- Home Manager integrates with NixOS for user configuration
- Custom modules extend functionality
- Environment variables bridge NixOS and user applications