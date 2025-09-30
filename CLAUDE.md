# Claude Assistant Guidelines

## Project Standards and Quick Reference

### Documentation Links
- **Installation Guide**: [`docs/installation.md`](docs/installation.md)
- **Configuration Details**: [`docs/configuration.md`](docs/configuration.md)
- **Testing Procedures**: [`docs/testing.md`](docs/testing.md)
- **Development Notes**: [`docs/development.md`](docs/development.md)
- **Application Configs**: [`docs/applications.md`](docs/applications.md)
- **Package Management**: [`docs/packages.md`](docs/packages.md)
- **Unstable Packages**: [`docs/unstable-packages.md`](docs/unstable-packages.md)

### Common Commands
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

### Project Structure
- **System Config**: `configuration.nix` (NixOS system-wide)
- **User Config**: `home.nix` (Home Manager)
- **Flake Definition**: `flake.nix` (inputs and outputs)
- **Config Files**: `config/` (application configs)
- **Custom Modules**: `home-modules/` (Home Manager extensions)
- **Host Configs**: `hosts/` (hardware-specific)
- **Packages**: `packages/` (custom packages, Neovim config)

## Specs Directory Protocol

### Purpose
The `specs/` directory contains implementation plans, research reports, and summaries for significant changes and features.

### Structure
```
specs/
├── plans/       # Implementation plans (NNN_*.md format)
├── reports/     # Research reports (NNN_*.md format)
└── summaries/   # Implementation summaries (NNN_*.md format)
```

### File Naming Convention
All specs files use `NNN_descriptive_name.md` format:
- Three-digit numbers with leading zeros (001, 002, etc.)
- Increment from highest existing number in that category
- Lowercase with underscores for names
- Example: `001_nix_flake_migration.md`, `002_email_setup.md`

### Location Guidelines
- **Feature-specific**: Place in the feature's directory (e.g., `packages/neovim/specs/`)
- **Module-specific**: Place in the module's directory (e.g., `home-modules/specs/`)
- **System-wide**: Place in project root `specs/` directory

### Content Templates

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

## Accessing Program Documentation

When configuring programs, always try these methods first before searching online:

### 1. Built-in Help Commands
Most programs provide immediate documentation access:

```bash
# General help
program --help
program -h
program help

# Specific command help
program subcommand --help
program help subcommand
```

### 2. Man Pages
Traditional Unix documentation:

```bash
# View man page
man program

# Search man pages by keyword
man -k keyword
apropos keyword

# Check all sections (1-8)
man -a program
```

### 3. Info Pages
GNU programs often have detailed info documentation:

```bash
# View info page
info program

# Search info pages
info --apropos=keyword
```

### 4. Program-Specific Documentation Commands

#### WezTerm
```bash
# Show all available commands
wezterm --help

# Show current key bindings in Lua format
wezterm show-keys --lua

# Show font information
wezterm ls-fonts

# Generate shell completions
wezterm shell-completion --shell bash
```

#### Neovim/Vim
```bash
# View help from command line
nvim -c "help config" -c "only"

# Inside editor
:help           # General help
:help option    # Specific option
:helpgrep term  # Search help
```

#### Git
```bash
# Built-in help
git help config
git config --help

# List all available commands
git help -a

# Show guides
git help -g
```

#### Systemd Services
```bash
# View service documentation
systemctl help service-name
man systemd.service
man systemd.unit
```

#### Package Managers
```bash
# Nix
nix --help
nix search --help
man nix.conf
man configuration.nix

# Apt/Dpkg
apt-get help
man apt
man dpkg

# DNF/YUM
dnf help
man dnf
```

### 5. Configuration File Documentation

Many programs document their config options in:

```bash
# Example config files
ls /usr/share/doc/program/examples/
ls /etc/program/

# Comments in default configs
cat /etc/program/program.conf.example

# Dedicated config man pages
man program.conf
man 5 program  # Section 5 is for config files
```

### 6. Built-in Documentation Viewers

Some programs have internal documentation systems:

```bash
# Python modules
python -c "import module; help(module)"
pydoc module

# Ruby gems  
ri ClassName
ri method_name

# Perl modules
perldoc Module::Name
```

### 7. Generate Sample Configurations

Many programs can output their default configuration:

```bash
# Generate default config
program --dump-config
program --print-defaults
program config dump

# WezTerm example
wezterm show-keys --lua > default-keys.lua
```

### 8. Version-Specific Documentation

Always check version for accurate docs:

```bash
program --version
program -V
program version
```

### 9. List Available Options

Some programs can list all their options:

```bash
# Common patterns
program --list-options
program --show-options
program config list
```

### 10. Tab Completion

Use shell completion to discover options:

```bash
# Enable completions (if available)
program completion bash
program shell-completion --shell bash

# Then use Tab to explore
program <TAB><TAB>
program --<TAB><TAB>
```

## Priority Order for Documentation

1. **Built-in help** (`--help`) - Always try first
2. **Man pages** (`man program`) - Comprehensive Unix docs  
3. **Program-specific commands** (like `wezterm show-keys`)
4. **Example configs** in `/usr/share/doc/` or `/etc/`
5. **Info pages** for GNU programs
6. **Version-specific online docs** - Only if above methods fail

## Tips

- Always check the program version first to ensure documentation matches
- Many programs accept both `--help` and `help` subcommand formats
- Config file formats often have their own man pages in section 5
- Use `which program` or `whereis program` to locate binaries and associated files
- Check `~/.config/program/` for user-specific configs with comments
- Some programs auto-generate config with `program init` or similar

## Common Config Locations

```bash
# User configs
~/.config/program/
~/.program/
~/.programrc

# System configs  
/etc/program/
/usr/local/etc/program/
/opt/program/etc/
```

Remember: Exhausting local documentation before going online ensures accuracy for the specific version installed and reduces errors from outdated web resources.

## NPX Wrapper Pattern for Node.js Tools

For rapidly-updating Node.js development tools, consider using NPX wrappers instead of traditional Nix packaging when maintainability is prioritized over version pinning.

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