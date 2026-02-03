# Implementation Plan: Manage Claude Settings with Home Manager

- **Task**: 4 - manage_claude_settings_with_home_manager
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: None (codebase exploration sufficient)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

This task implements declarative management of `~/.claude/settings.json` through Home Manager, following the same pattern used for other configuration files like wezterm.lua and himalaya config. The settings.json file contains Claude Code permissions, MCP server configurations, and status line settings. By managing this file through Home Manager, configuration becomes reproducible across machines and version-controlled.

## Goals & Non-Goals

**Goals**:
- Create a source file `config/claude-settings.json` in the dotfiles repository
- Configure `home.file` in home.nix to symlink `~/.claude/settings.json` to this file
- Preserve the current settings.json structure and permissions
- Enable version control of Claude Code configuration

**Non-Goals**:
- Managing `~/.claude.json` (user-wide settings with runtime state like project history, usage stats)
- Creating a custom Home Manager module (simple home.file is sufficient)
- Modifying the existing permissions structure

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Symlinked file causes Claude Code issues | Medium | Low | Test Claude Code after deployment; keep backup of original |
| Runtime writes to settings.json fail | High | Medium | Verify Claude Code handles read-only symlinks; may need to use `.text` with regeneration |
| MCP server paths become invalid | Low | Low | Use absolute paths that work across sessions |

## Implementation Phases

### Phase 1: Create Source Configuration File [COMPLETED]

**Goal**: Create the declarative source file containing Claude Code settings

**Tasks**:
- [ ] Create `config/claude-settings.json` with current settings structure
- [ ] Extract only the declarative portions (permissions, model, statusLine, mcpServers)
- [ ] Exclude runtime state (numStartups, tipsHistory, projects, skillUsage, etc.)
- [ ] Format JSON with 2-space indentation for readability

**Timing**: 30 minutes

**Files to create**:
- `config/claude-settings.json` - Claude Code permissions and settings

**Verification**:
- File is valid JSON
- Contains required fields: permissions, model, statusLine

---

### Phase 2: Configure Home Manager Integration [IN PROGRESS]

**Goal**: Add home.file entry to manage the settings.json symlink

**Tasks**:
- [ ] Add `home.file.".claude/settings.json"` entry to home.nix
- [ ] Use `.source = ./config/claude-settings.json` pattern (matching wezterm.lua approach)
- [ ] Ensure the entry is placed logically with other config file entries
- [ ] Add optional backup entry to `config-files/` directory for reference

**Timing**: 20 minutes

**Files to modify**:
- `home.nix` - Add home.file entry for .claude/settings.json

**Verification**:
- No Nix syntax errors (`nix flake check`)
- Entry follows existing patterns in home.nix

---

### Phase 3: Test and Validate [NOT STARTED]

**Goal**: Verify the configuration works with Claude Code

**Tasks**:
- [ ] Run `home-manager switch` to apply configuration
- [ ] Verify `~/.claude/settings.json` is a symlink to the Nix store
- [ ] Start Claude Code and verify it loads correctly
- [ ] Verify permissions work as expected
- [ ] Test MCP server configuration if present

**Timing**: 30 minutes

**Verification**:
- `ls -la ~/.claude/settings.json` shows symlink
- `claude` command starts without errors
- Permissions from settings.json are active

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `home-manager build --flake .#benjamin` succeeds
- [ ] `home-manager switch --flake .#benjamin` applies changes
- [ ] Claude Code starts and reads configuration correctly
- [ ] Permissions work (allowed tools work, denied tools blocked)

## Artifacts & Outputs

- `config/claude-settings.json` - Declarative Claude Code settings
- `home.nix` modification - home.file entry for settings.json
- `specs/4_manage_claude_settings_with_home_manager/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

If the symlinked approach causes issues:
1. Remove the home.file entry from home.nix
2. Run `home-manager switch` to remove the symlink
3. Copy the original settings.json back to `~/.claude/`
4. Consider alternative: use `home.activation` script to copy file instead of symlink

If Claude Code requires writeable settings.json:
1. Switch from `.source` to `.text` with `builtins.readFile`
2. Or create a Home Manager module that uses `xdg.configFile` with proper permissions
3. Or use `home.activation` to copy the file (not symlink) on each switch
