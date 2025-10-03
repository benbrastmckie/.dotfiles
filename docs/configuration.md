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

## Key Integration Points

- Flake inputs provide package sources
- Home Manager integrates with NixOS for user configuration
- Custom modules extend functionality
- Environment variables bridge NixOS and user applications