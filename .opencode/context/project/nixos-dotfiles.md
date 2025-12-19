# NixOS Dotfiles Project Context

## Overview

This is a NixOS system configuration repository using flakes for declarative system and user environment management.

## Technology Stack

**OS:** NixOS 24.11
**Package Manager:** Nix with flakes
**User Environment:** Home Manager
**Desktop:** GNOME + Niri (dual-session)
**Shell:** Fish
**Terminal:** Kitty, WezTerm, Ghostty
**Editor:** Neovim (custom config)

## Project Structure

```
.
├── configuration.nix       # NixOS system-wide config
├── home.nix               # Home Manager user config
├── flake.nix              # Flake inputs/outputs
├── flake.lock             # Locked dependency versions
├── hosts/                 # Host-specific hardware configs
│   ├── garuda/
│   ├── hamsa/
│   ├── nandi/
│   └── usb-installer/
├── packages/              # Custom package definitions
│   ├── neovim.nix
│   ├── claude-code.nix
│   └── ...
├── home-modules/          # Custom Home Manager modules
├── config/                # Application config files
├── docs/                  # Project documentation
└── specs/                 # Implementation plans/reports
    ├── plans/
    ├── reports/
    └── summaries/
```

## Common Commands

### System Management
```bash
# Update entire system (flakes + rebuild)
./update.sh

# Skip checks for problematic packages
./update.sh --no-check

# Rebuild NixOS system only
sudo nixos-rebuild switch --flake .#$(hostname) --option allow-import-from-derivation false

# Rebuild Home Manager only
home-manager switch --flake .#benjamin --option allow-import-from-derivation false

# Test configuration without applying
nixos-rebuild dry-build --flake .#$(hostname)

# Update flake inputs only
nix flake update

# Check flake validity
nix flake check --option allow-import-from-derivation false
```

### Documentation Access

**NixOS automatically manages man pages** - they're installed/removed with packages and always version-matched.

```bash
# Man pages (auto-synced with installed packages)
man program              # View program documentation
man -k keyword           # Search by keyword
man 5 program            # Config file docs (section 5)
man nix.conf             # Nix configuration
man configuration.nix    # NixOS config options

# Built-in help
program --help           # Quick command reference
nix --help              # Nix commands
git help config         # Git-specific help

# Info pages (GNU programs)
info program            # Detailed GNU docs
info --apropos=keyword  # Search info pages

# Program-specific commands
wezterm show-keys --lua # WezTerm key bindings
nvim -c "help config"   # Neovim help
systemctl help service  # Systemd service docs
```

**Priority Order:**
1. Man pages (`man program`) - Always version-matched in NixOS
2. Built-in help (`--help`)
3. Program-specific commands
4. Info pages
5. Online docs (only if local docs insufficient)

## Specs Directory Protocol

### Purpose
Implementation plans, research reports, and summaries for significant changes.

### Structure
```
specs/
├── plans/       # Implementation plans (NNN_*.md)
├── reports/     # Research reports (NNN_*.md)
└── summaries/   # Implementation summaries (NNN_*.md)
```

### File Naming Convention
- Format: `NNN_descriptive_name.md`
- Three-digit numbers with leading zeros (001, 002, etc.)
- Increment from highest existing number in category
- Lowercase with underscores
- Examples: `001_nix_flake_migration.md`, `002_email_setup.md`

### Location Guidelines
- **Feature-specific**: Place in feature's directory (e.g., `packages/neovim/specs/`)
- **Module-specific**: Place in module's directory (e.g., `home-modules/specs/`)
- **System-wide**: Place in project root `specs/` directory

### Templates

#### Plan Template (plans/NNN_*.md)
```markdown
# Plan: [Feature Name]
Date: YYYY-MM-DD

## Objective
[Clear goal statement]

## Current State
[Existing functionality/issues]

## Proposed Solution
[High-level approach]

## Implementation Steps
1. [Specific, actionable steps]
2. [...]

## Testing Strategy
[How to verify success]

## Rollback Plan
[How to revert if needed]
```

#### Report Template (reports/NNN_*.md)
```markdown
# Research Report: [Topic]
Date: YYYY-MM-DD

## Question/Problem
[What we're investigating]

## Findings
[Key discoveries]

## Options Considered
1. **Option A**: [Description, pros/cons]
2. **Option B**: [Description, pros/cons]

## Recommendation
[Chosen approach and rationale]

## References
[Links, documentation]
```

#### Summary Template (summaries/NNN_*.md)
```markdown
# Implementation Summary: [Feature]
Date: YYYY-MM-DD

## What Was Done
[Brief overview of changes]

## Files Modified
- `path/to/file.nix`: [What changed]
- `path/to/config.conf`: [What changed]

## Key Decisions
[Important choices made and why]

## Results
[Outcome, performance, issues resolved]

## Future Considerations
[Next steps, improvements, technical debt]
```

## Nix Development Standards

### Code Style
- **Indentation**: 2 spaces for Nix files
- **Line Length**: Prefer under 80 characters
- **Comments**: Use `#` for inline, avoid unless necessary
- **Formatting**: Use `nixfmt` when available

### File Organization
- System configs in `configuration.nix`
- User configs in `home.nix`
- Custom packages in `packages/`
- Host-specific in `hosts/hostname/`

### Testing Requirements
- Always test with `nixos-rebuild dry-build` first
- Use `--option allow-import-from-derivation false` for problematic packages
- Verify package versions after rebuild
- Check systemd service status for enabled services

### Git Commit Standards
- Use conventional commits: `type: description`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Reference issues when applicable
- Keep commits atomic and focused

## NPX Wrapper Pattern for Node.js Tools

For rapidly-updating Node.js development tools, use NPX wrappers instead of traditional Nix packaging when maintainability is prioritized over version pinning.

### When to Use NPX Wrappers

**Good candidates:**
- Frequently updated development tools
- Tools with complex npm dependency trees
- Tools where latest version is always preferred
- Tools without package-lock.json in npm packages

**Example tools:** claude-code, create-react-app, @angular/cli

### Implementation Pattern

```nix
# packages/tool-name.nix
{ lib, writeShellScriptBin, nodejs }:

writeShellScriptBin "tool-name" ''
  exec ${nodejs}/bin/npx package-name@latest "$@"
''
```

### Benefits
- **Zero maintenance**: No version updates or hash calculations needed
- **Always latest**: Automatically uses newest version from NPM registry
- **Simple implementation**: Minimal code complexity
- **Offline tolerance**: NPX caches versions for offline use
- **Easy rollback**: Can revert to traditional packaging if needed

### Trade-offs
- Less precise version control
- Requires internet for initial downloads
- Slight startup delay for version checking (cached after first run)
- Dependency on NPM registry availability

### Usage Guidelines
- Use for tools where breaking changes are rare
- Ensure tool provides stable CLI interface
- Document the approach in packages/README.md
- Maintain fallback option in unstable-packages.nix (commented out)
- Consider for tools with update frequency > monthly

## Documentation Links

- **Installation Guide**: `docs/installation.md`
- **Configuration Details**: `docs/configuration.md`
- **Testing Procedures**: `docs/testing.md`
- **Package Management**: `docs/packages.md`
- **Unstable Packages**: `docs/unstable-packages.md`
- **Application Configs**: `docs/applications.md`
- **Himalaya Email**: `docs/himalaya.md`
- **Niri Window Manager**: `docs/niri.md`
- **Terminal Emulators**: `docs/terminal.md`
- **GNOME Settings**: `docs/gnome-settings.md`
- **Development Notes**: `docs/development.md`

## Key Features

### Dual Desktop Sessions
- **GNOME**: Full-featured desktop with extensions
- **Niri**: Tiling Wayland compositor (experimental)
- Both available at GDM login

### Email Setup
- **Client**: Himalaya (TUI email client)
- **Sync**: mbsync with OAuth2 support
- **Auth**: XOAUTH2 via libsecret keyring

### Custom Packages
- Neovim with custom config
- Claude Code (NPX wrapper)
- Various AI tools (gemini-cli, goose-cli)
- Whisper dictation system

### Development Tools
- Python with extensive scientific stack
- Node.js, Go, Rust toolchains
- LaTeX (full TeXLive)
- CVC5 SMT solver
