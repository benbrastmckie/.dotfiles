# Implementation Plan: Task #1

- **Task**: 1 - update_claudemd_for_dotfiles
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/1_update_claudemd_for_dotfiles/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update CLAUDE.md and project-overview.md to accurately describe this NixOS dotfiles repository. The current content incorrectly describes a "Neovim Configuration Management System" with a nonexistent `nvim/` directory structure. The repository is actually a comprehensive NixOS flake-based configuration managing multiple hosts, custom packages, and application configurations.

### Research Integration

The research report (research-001.md) confirmed:
- The `nvim/` directory does **NOT** exist in this repository
- This is a NixOS/Home Manager dotfiles system with flake.nix, configuration.nix, home.nix
- Context import paths are all valid and should be preserved
- Two files need updating: CLAUDE.md and project-overview.md

## Goals & Non-Goals

**Goals**:
- Update title and description to reflect "NixOS Dotfiles Configuration System"
- Replace incorrect Project Structure section with actual repository structure
- Preserve all working task management content (commands, status markers, etc.)
- Update project-overview.md with consistent information

**Non-Goals**:
- Add new features or commands
- Restructure the task management system
- Modify any context import paths (they are all valid)
- Create new context files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking task management references | Medium | Low | Only modify descriptive sections, keep all commands and state references unchanged |
| Inconsistency between files | Low | Low | Update both files in sequence, verify consistency |
| Over-editing | Low | Medium | Focus strictly on research findings, make minimal necessary changes |

## Implementation Phases

### Phase 1: Update CLAUDE.md [NOT STARTED]

**Goal**: Correct the title, description, and Project Structure section in CLAUDE.md

**Tasks**:
- [ ] Update title from "Neovim Configuration Management System" to "NixOS Dotfiles Configuration System"
- [ ] Update description from "Neovim configuration maintenance" to "NixOS dotfiles maintenance"
- [ ] Replace Project Structure section with actual repository structure showing:
  - Core Nix files (flake.nix, configuration.nix, home.nix)
  - hosts/ directory for multi-host configurations
  - packages/ directory for custom Nix packages
  - home-modules/ directory for Home Manager modules
  - config/ directory for application configurations
  - specs/ and .claude/ directories (keep existing)
- [ ] Update Rules References to remove mention of nonexistent nvim/**/*.lua pattern
- [ ] Verify all other sections remain unchanged

**Timing**: 30 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Title, description, Project Structure section, Rules References

**Verification**:
- Title reads "NixOS Dotfiles Configuration System"
- Project Structure shows actual directories (flake.nix, hosts/, packages/, config/)
- No references to nonexistent nvim/ directory
- All command references and task management content preserved

---

### Phase 2: Update project-overview.md [NOT STARTED]

**Goal**: Update project-overview.md to be consistent with CLAUDE.md changes

**Tasks**:
- [ ] Update title from "Neovim Configuration Project" to "NixOS Dotfiles Configuration Project"
- [ ] Update Project Overview section to describe NixOS/Home Manager dotfiles
- [ ] Update Technology Stack section to reflect Nix/NixOS/Home Manager
- [ ] Replace Project Structure section with actual repository structure
- [ ] Update Core Configuration section to describe Nix flakes and Home Manager
- [ ] Update Development Workflow section for Nix development
- [ ] Update Common Tasks section for Nix-specific tasks
- [ ] Update Verification Commands section for Nix commands

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/project/repo/project-overview.md` - Complete rewrite to reflect NixOS dotfiles

**Verification**:
- Content is consistent with updated CLAUDE.md
- Technology stack shows Nix, NixOS, Home Manager
- Project structure matches actual repository
- Development workflow reflects Nix-based development

---

## Testing & Validation

- [ ] CLAUDE.md title and description are accurate
- [ ] Project Structure in CLAUDE.md matches actual repository (`ls -la /home/benjamin/.dotfiles/`)
- [ ] project-overview.md is consistent with CLAUDE.md
- [ ] No references to nonexistent nvim/ directory in either file
- [ ] All command references still valid
- [ ] Context import paths unchanged (they were already valid)

## Artifacts & Outputs

- `.claude/CLAUDE.md` - Updated main reference file
- `.claude/context/project/repo/project-overview.md` - Updated project overview
- `specs/1_update_claudemd_for_dotfiles/summaries/implementation-summary-20260203.md` - Implementation summary

## Rollback/Contingency

If changes cause issues:
1. Use `git diff .claude/CLAUDE.md` to review changes
2. Use `git checkout .claude/CLAUDE.md` to restore original
3. Similarly for project-overview.md
4. Both files are tracked in git, so full history is available
