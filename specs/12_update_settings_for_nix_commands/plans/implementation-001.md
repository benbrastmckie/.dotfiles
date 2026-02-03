# Implementation Plan: Task #12

- **Task**: 12 - update_settings_for_nix_commands
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/12_update_settings_for_nix_commands/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add Nix tooling commands (nix, nixos-rebuild, home-manager, nix-shell, nix-env) to the Claude settings.json permission allow list. The target file is `config/claude-settings.json`, which Home Manager deploys to `~/.claude/settings.json`. This is a straightforward configuration update with no dependencies.

### Research Integration

Research report findings integrated:
- Target file: `config/claude-settings.json` (Home Manager managed)
- Permission pattern: `"Bash(command *)"` format
- Placement: After existing build tool commands for logical grouping
- Safety: `sudo` remains in deny list; only build/check commands enabled

## Goals & Non-Goals

**Goals**:
- Add Nix CLI commands to the permission allow list
- Enable Claude to run nix flake check, nixos-rebuild build, home-manager build
- Maintain consistency with existing permission patterns

**Non-Goals**:
- Enabling sudo-requiring commands (nixos-rebuild switch)
- Adding destructive commands (nix-collect-garbage)
- Modifying the deny list

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Accidental system modification | Medium | Low | sudo remains denied; only build commands work |
| Long-running builds blocking Claude | Low | Medium | Use nix flake check for quick validation |

## Implementation Phases

### Phase 1: Add Nix Commands to Settings [COMPLETED]

**Goal**: Update config/claude-settings.json with Nix tooling permissions

**Tasks**:
- [x] Read current config/claude-settings.json to verify structure
- [x] Add Nix commands after build tool section (after "Bash(biber *)")
- [x] Verify JSON validity after edit

**Timing**: 15 minutes

**Files to modify**:
- `config/claude-settings.json` - Add 5 new permission entries to allow list

**Commands to add**:
```json
"Bash(nix *)",
"Bash(nixos-rebuild *)",
"Bash(home-manager *)",
"Bash(nix-shell *)",
"Bash(nix-env *)"
```

**Verification**:
- JSON file parses without errors
- New entries appear in permissions.allow array
- Existing entries unchanged

---

## Testing & Validation

- [ ] JSON syntax validation (jq . < config/claude-settings.json)
- [ ] Verify 5 new Nix commands present in allow list
- [ ] Confirm no changes to deny list or other sections

## Artifacts & Outputs

- plans/implementation-001.md (this plan)
- summaries/implementation-summary-YYYYMMDD.md (after completion)

## Rollback/Contingency

If changes cause issues:
1. Revert config/claude-settings.json to previous commit
2. Run `home-manager switch` to restore previous settings (requires manual execution outside Claude)
