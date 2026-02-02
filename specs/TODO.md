# Task List

## Active Tasks

### 1. Update CLAUDE.md for dotfiles repository
- **Status**: [NOT STARTED]
- **Priority**: high
- **Language**: meta
- **Description**: Rewrite CLAUDE.md to accurately reflect this NixOS dotfiles repository instead of describing a Neovim-only configuration system.

**Changes Required**:
1. Update title from "Neovim Configuration Management System" to "NixOS Dotfiles Management System"
2. Fix Project Structure section to show actual directories:
   - `flake.nix`, `configuration.nix`, `home.nix` (core Nix files)
   - `config/` (application configs)
   - `docs/` (documentation)
   - `hosts/` (multi-host hardware configs)
   - `packages/` (custom Nix packages)
   - `home-modules/` (Home Manager modules)
   - `specs/` (task management)
   - `.claude/` (Claude Code configuration)
3. Update Language-Based Routing to add `nix` language type with tools: `Read, Write, Edit, Bash (nixos-rebuild, home-manager)`
4. Update or remove Context Imports that reference non-existent neovim paths
5. Verify Rules References paths exist or update them
6. Keep task management documentation (still valid)

---

### 2. Update README.md for dotfiles context
- **Status**: [NOT STARTED]
- **Priority**: high
- **Language**: meta
- **Description**: Update the Claude system architecture README.md to reflect the NixOS dotfiles repository context rather than Neovim-only focus.

**Changes Required**:
1. Update System Overview to describe NixOS dotfiles management
2. Update "Purpose and Goals" to include NixOS configuration management
3. Revise Language Routing section to include `nix` language
4. Update or remove Neovim-specific sections that don't apply broadly
5. Add sections on NixOS-specific workflows:
   - Flake updates (`nix flake update`)
   - System rebuilds (`nixos-rebuild switch`)
   - Home Manager updates (`home-manager switch`)
   - Host management (multi-system configs)
6. Update Related Documentation paths to match actual repo structure
7. Keep core architecture documentation (delegation, state management, etc.) since it's still valid

---

## Completed Tasks

(none)

## Archived Tasks

(none)
