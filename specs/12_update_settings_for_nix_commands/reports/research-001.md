# Research Report: Task #12

**Task**: 12 - update_settings_for_nix_commands
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:05:00Z
**Effort**: 15 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (settings files, home.nix, CLAUDE.md documentation)
**Artifacts**: specs/12_update_settings_for_nix_commands/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The Claude settings file managed by Home Manager is located at `config/claude-settings.json`
- Home Manager deploys this to `~/.claude/settings.json` via symlink
- Current allowed Bash commands include git, lake, latex tools, and basic file operations
- Nix commands (`nix`, `nixos-rebuild`, `home-manager`, `nix-shell`, `nix-env`) need to be added to the permissions allow list
- The permission pattern uses wildcards: `"Bash(command *)"` for command prefixes

## Context and Scope

This research investigates how to add Nix tooling commands to the Claude Code settings.json file for this NixOS dotfiles project. The task is categorized as "meta" since it involves modifying the Claude Code configuration itself.

## Findings

### Current Settings File Locations

| File | Purpose |
|------|---------|
| `/home/benjamin/.dotfiles/.claude/settings.json` | Project-level settings (in git) |
| `/home/benjamin/.dotfiles/.claude/settings.local.json` | Personal overrides (not committed) |
| `/home/benjamin/.dotfiles/config/claude-settings.json` | Home Manager managed settings |
| `/home/benjamin/.dotfiles/.claude/templates/settings.json` | Template for reference |

### Home Manager Integration

The `home.nix` file at line 630 manages the user's Claude settings:

```nix
".claude/settings.json".source = ./config/claude-settings.json;
```

This creates a symlink from `~/.claude/settings.json` to the Nix store copy of `config/claude-settings.json`.

### Current Permission Structure

The `config/claude-settings.json` file has this structure:

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TodoWrite",
      "mcp__lean-lsp__*",
      "Bash(echo:*)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ],
    "defaultMode": "default"
  },
  ...
}
```

### Permission Pattern Syntax

The permission patterns follow this syntax:
- `"Bash(command *)"` - Allows command with any arguments
- `"Bash(git:*)"` - Allows git with colon separator (variant syntax)
- `"mcp__server__*"` - Wildcard for MCP tool access

### Nix Commands to Add

Based on CLAUDE.md documentation and nix.md rules, these commands are needed:

| Command | Usage | Description |
|---------|-------|-------------|
| `nix` | `nix flake check`, `nix build`, `nix develop` | Core Nix command |
| `nixos-rebuild` | `nixos-rebuild build --flake .#hostname` | NixOS configuration building |
| `home-manager` | `home-manager build --flake .#user` | Home Manager configuration |
| `nix-shell` | `nix-shell -p package` | Legacy shell environments |
| `nix-env` | `nix-env -q` | Legacy package queries |

### Relevant Documentation References

From CLAUDE.md:
```
| `nix` | WebSearch, WebFetch, Read, MCP-NixOS | Read, Write, Edit, Bash (nix flake check, nixos-rebuild), MCP-NixOS |
```

From `.claude/rules/nix.md`:
```bash
nix flake check
nixos-rebuild build --flake .#hostname
home-manager build --flake .#user
```

### Safety Considerations

1. **sudo is denied**: `nixos-rebuild switch` requires sudo, but `nixos-rebuild build` does not
2. **Build-only operations**: Safe commands for validation without system modification:
   - `nix flake check`
   - `nix build`
   - `nixos-rebuild build`
   - `home-manager build`
3. **Read-only operations**: Query and inspection:
   - `nix flake show`
   - `nix-env -q`

## Recommendations

### Implementation Approach

Add these permission entries to `config/claude-settings.json`:

```json
"Bash(nix *)",
"Bash(nixos-rebuild *)",
"Bash(home-manager *)",
"Bash(nix-shell *)",
"Bash(nix-env *)"
```

### Placement

Add after the existing build tool commands (after `"Bash(biber *)"`) to group related development tool permissions together.

### Alternative: Project-Level Settings

The project-level `.claude/settings.json` could also be updated. Since both files are in the repository, updating `config/claude-settings.json` is preferred because:
1. It's the authoritative source for Home Manager deployment
2. Changes propagate to the user's home directory automatically
3. The project-level file appears to be a copy/duplicate

## Decisions

- Target file: `config/claude-settings.json` (Home Manager managed)
- Pattern style: Use `"Bash(command *)"` format (consistent with existing patterns)
- No sudo needed: Only build/check commands, not switch commands

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Accidental system modification | `sudo` is in deny list; only build commands allowed |
| Long-running builds | Use `nix flake check` for quick validation |
| Nix garbage collection | Not adding `nix-collect-garbage` (destructive) |

## Appendix

### Files Examined

1. `/home/benjamin/.dotfiles/.claude/settings.json`
2. `/home/benjamin/.dotfiles/.claude/settings.local.json`
3. `/home/benjamin/.dotfiles/config/claude-settings.json`
4. `/home/benjamin/.dotfiles/home.nix`
5. `/home/benjamin/.dotfiles/.claude/rules/nix.md`
6. `/home/benjamin/.dotfiles/.claude/CLAUDE.md`

### Search Queries Used

- `**/*settings*.json` - Find all settings files
- `allowedCommands|allowedBashCommands` - Find permission patterns
- `Bash\(nix|Bash\(nixos|Bash\(home-manager` - Check existing Nix commands
- `nix.*flake|nixos-rebuild|home-manager` - Find Nix documentation references
