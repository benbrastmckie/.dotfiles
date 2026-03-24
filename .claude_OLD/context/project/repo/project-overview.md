# NixOS Dotfiles Configuration Project

## Project Overview

This is a NixOS dotfiles repository using Nix flakes for declarative system and user environment configuration. The configuration manages multiple hosts with shared modules, custom packages, and application-specific configurations.

**Purpose**: Maintain reproducible NixOS system configurations across multiple machines with unified Home Manager user environments.

## Technology Stack

**Primary Language:** Nix
**Configuration System:** NixOS + Home Manager
**Package Management:** Nix flakes with pinned dependencies
**Target Systems:** NixOS (multiple hosts)
**Version:** NixOS unstable channel

## Project Structure

```
flake.nix                 # Nix flake - inputs and system definitions
flake.lock                # Pinned dependency versions
configuration.nix         # System-wide NixOS configuration
home.nix                  # Home Manager user environment
unstable-packages.nix     # Unstable package definitions

hosts/                    # Host-specific hardware configurations
├── garuda/              # Garuda host
├── nandi/               # Nandi host - Intel laptop
├── hamsa/               # Hamsa host - AMD laptop
└── usb-installer/       # Generic USB installer

home-modules/             # Custom Home Manager modules
packages/                 # Custom Nix package definitions
config/                   # Application configuration files (symlinked via Home Manager)
wallpapers/               # Desktop wallpapers

docs/                     # Project documentation
specs/                    # Task management
├── TODO.md              # Task list
├── state.json           # Task state
└── {N}_{SLUG}/          # Task artifacts
    ├── reports/
    ├── plans/
    └── summaries/

.claude/                  # Claude Code configuration
├── CLAUDE.md            # Main reference
├── commands/            # Slash commands
├── skills/              # Skill definitions
├── agents/              # Agent definitions
├── rules/               # Auto-applied rules
└── context/             # Domain knowledge
```

## Core Configuration

### Nix Flakes

The repository uses Nix flakes for:
- Declarative input pinning (nixpkgs, home-manager, etc.)
- Per-host system configurations
- Reproducible builds across machines

### Multi-Host Support

Each host in `hosts/` contains:
- `hardware-configuration.nix` - Hardware-specific settings
- Host-specific overrides and customizations

### Home Manager Integration

User environment managed via Home Manager:
- Package installations
- Dotfile management (symlinks from `config/`)
- Application configuration
- Shell environment (zsh, bash)

## Development Workflow

### Standard Workflow

1. **Identify Need**: Package to add, configuration to change, module to create
2. **Research**: Check nixpkgs options, Home Manager options, NixOS wiki
3. **Implement**: Modify Nix files (flake.nix, configuration.nix, home.nix, modules)
4. **Test**: Run `nix flake check`, `nixos-rebuild test`
5. **Apply**: Run `nixos-rebuild switch` or `home-manager switch`
6. **Commit**: Track changes

### AI-Assisted Workflow

1. **Research**: `/research` - Gather Nix options, patterns, examples
2. **Planning**: `/plan` - Create implementation plan
3. **Implementation**: `/implement` - Execute the plan
4. **Review**: `/review` - Analyze configuration

## Common Tasks

### Adding a System Package

1. Add package to `configuration.nix` under `environment.systemPackages`
2. Run `nixos-rebuild switch`

### Adding a User Package

1. Add package to `home.nix` under `home.packages`
2. Run `home-manager switch` or `nixos-rebuild switch`

### Creating a Custom Module

1. Create module in `home-modules/` following NixOS module pattern
2. Import in `home.nix` or `configuration.nix`
3. Configure module options

### Adding Host-Specific Configuration

1. Create or modify files in `hosts/{hostname}/`
2. Update `flake.nix` to reference new host configuration
3. Test with `nixos-rebuild test --flake .#{hostname}`

## Verification Commands

```bash
# Check flake validity
nix flake check

# Test system configuration (without applying)
nixos-rebuild test --flake .#hostname

# Build system configuration
nixos-rebuild build --flake .#hostname

# Apply system configuration
sudo nixos-rebuild switch --flake .#hostname

# Update flake inputs
nix flake update

# Show flake outputs
nix flake show
```

## Related Documentation

- `.claude/context/project/nix/` - Nix domain knowledge
- `.claude/rules/nix.md` - Nix coding standards
- `docs/` - Project-specific documentation
