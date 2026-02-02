# Task List

## Active Tasks

### 3. Fix meta.md directory creation specification conflict
- **Status**: [NOT STARTED]
- **Priority**: high
- **Language**: meta
- **Description**: Remove or fix conflicting specification in `.claude/commands/meta.md` line 29 that says "Create task directories for each task" which contradicts the lazy directory creation rule in `.claude/rules/state-management.md`.

**Root Cause Analysis**:
The `/meta` command specification at line 29 states:
> "Create task directories for each task"

But `state-management.md` (lines 226-257) explicitly states:
> "DO NOT create directories at task creation time. The `/task` command only:
> 1. Updates `specs/state.json`
> 2. Updates `specs/TODO.md`"
>
> "WHO creates directories: Artifact-writing agents (researcher, planner, implementer) create directories with `mkdir -p` when writing their first artifact"

**Fix Required**:
1. Edit `.claude/commands/meta.md` line 29
2. Change "Create task directories for each task" to something like:
   - "Task directories created lazily when artifacts are written (see state-management.md)"
   - Or simply remove the line

---

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
