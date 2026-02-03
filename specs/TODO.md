# Task List

## Active Tasks

### 2. Update README.md for dotfiles context
- **Status**: [IMPLEMENTING]
- **Priority**: high
- **Language**: meta
- **Researched**: 2026-02-03
- **Planned**: 2026-02-03
- **Research**: [research-001.md](specs/2_update_readme_for_dotfiles/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/2_update_readme_for_dotfiles/plans/implementation-001.md)
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

### 4. Manage Claude settings.json with home-manager
- **Status**: [COMPLETED]
- **Priority**: medium
- **Language**: general
- **Completed**: 2026-02-03
- **Plan**: [implementation-001.md](specs/4_manage_claude_settings_with_home_manager/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/4_manage_claude_settings_with_home_manager/summaries/implementation-summary-20260203.md)

**Description**: Maintain ~/.claude.json and ~/.claude/settings.json via home-manager similar to other config files like wezterm.lua in the dotfiles repository.

---

### 9. Create skill-nix-research
- **Status**: [COMPLETED]
- **Priority**: high
- **Language**: meta
- **Depends on**: Task 7
- **Researched**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/9_create_skill_nix_research/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/9_create_skill_nix_research/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/9_create_skill_nix_research/summaries/implementation-summary-20260203.md)

**Description**: Create skill-nix-research thin wrapper skill that delegates to nix-research-agent following the established skill pattern (preflight, delegate, postflight).

**Implementation Notes**:
- Mirror `.claude/skills/skill-neovim-research/SKILL.md` structure
- Preflight: Update task status to RESEARCHING
- Delegate: Invoke nix-research-agent via Task tool (created in Task 7)
- Postflight: Parse metadata, link artifacts, update status to RESEARCHED, git commit

---

### 10. Create skill-nix-implementation
- **Status**: [COMPLETED]
- **Priority**: high
- **Language**: meta
- **Depends on**: Task 8
- **Researched**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/10_create_skill_nix_implementation/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/10_create_skill_nix_implementation/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/10_create_skill_nix_implementation/summaries/implementation-summary-20260203.md)

**Description**: Create skill-nix-implementation thin wrapper skill that delegates to nix-implementation-agent following the established skill pattern (preflight, delegate, postflight).

**Implementation Notes**:
- Mirror `.claude/skills/skill-neovim-implementation/SKILL.md` structure
- Preflight: Update task status to IMPLEMENTING
- Delegate: Invoke nix-implementation-agent via Task tool (created in Task 8)
- Postflight: Parse metadata, link artifacts, update status to COMPLETED, git commit

---

### 11. Update orchestrator for nix language routing
- **Status**: [PLANNED]
- **Priority**: medium
- **Language**: meta
- **Depends on**: Tasks 9, 10
- **Researched**: 2026-02-03
- **Planned**: 2026-02-03
- **Research**: [research-001.md](specs/11_update_orchestrator_nix_routing/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/11_update_orchestrator_nix_routing/plans/implementation-001.md)

**Description**: Update skill-orchestrator to add language='nix' routing that delegates to nix-specific agents for research and implementation.

**Changes Required**:
1. Add `nix` to language routing table
2. Route `language: "nix"` research to `skill-nix-research` (created in Task 9)
3. Route `language: "nix"` implementation to `skill-nix-implementation` (created in Task 10)
4. Update CLAUDE.md Language-Based Routing table

---

### 12. Update settings.json for Nix commands
- **Status**: [PLANNED]
- **Priority**: low
- **Language**: meta
- **Researched**: 2026-02-03
- **Planned**: 2026-02-03
- **Research**: [research-001.md](specs/12_update_settings_for_nix_commands/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/12_update_settings_for_nix_commands/plans/implementation-001.md)

**Description**: Update settings.json to add allowed Bash commands for Nix tooling: nix, nixos-rebuild, home-manager, nix-shell, nix-env.

**Commands to add**:
- `nix` - General Nix CLI
- `nix flake *` - Flake operations
- `nix build *` - Build derivations
- `nix develop *` - Development shells
- `nixos-rebuild *` - System rebuild
- `home-manager *` - Home Manager operations
- `nix-shell *` - Legacy shell
- `nix-env *` - Legacy package management
