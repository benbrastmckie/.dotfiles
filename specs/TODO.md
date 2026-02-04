# Task List

## Active Tasks

### 16. Troubleshoot automatic-timezoned service failure
- **Status**: [PLANNED]
- **Language**: nix
- **Researched**: 2026-02-04
- **Planned**: 2026-02-04
- **Research**: [research-001.md](specs/16_troubleshoot_automatic_timezoned_geoclue2_dbus_timeout/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/16_troubleshoot_automatic_timezoned_geoclue2_dbus_timeout/plans/implementation-001.md)

**Description**: Investigate and fix automatic-timezoned service failing with D-Bus communication timeout. Service crashes after 60 seconds when geoclue2 shuts down due to idle timeout, preventing WiFi-based timezone detection from working despite proper configuration and WiFi connectivity.

---

### 15. Configure timezone based on location
- **Status**: [RESEARCHED]
- **Language**: nix
- **Researched**: 2026-02-04
- **Research**: [research-001.md](specs/15_configure_timezone_location_based/reports/research-001.md)

**Description**: Configure NixOS timezone to be set based on location with California as default. Research best practices for automatic timezone detection and configuration.

---

### 14. Review and improve documentation
- **Status**: [COMPLETED]
- **Language**: meta
- **Researched**: 2026-02-03
- **Planned**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/14_review_improve_documentation/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/14_review_improve_documentation/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/14_review_improve_documentation/summaries/implementation-summary-20260203.md)

**Description**: Systematically review and improve documentation throughout .claude/ and docs/ with appropriate cross links.

---

### 11. Update orchestrator for nix language routing
- **Status**: [COMPLETED]
- **Priority**: medium
- **Language**: meta
- **Depends on**: Tasks 9, 10
- **Researched**: 2026-02-03
- **Planned**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/11_update_orchestrator_nix_routing/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/11_update_orchestrator_nix_routing/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/11_update_orchestrator_nix_routing/summaries/implementation-summary-20260203.md)

**Description**: Update skill-orchestrator to add language='nix' routing that delegates to nix-specific agents for research and implementation.

**Changes Required**:
1. Add `nix` to language routing table
2. Route `language: "nix"` research to `skill-nix-research` (created in Task 9)
3. Route `language: "nix"` implementation to `skill-nix-implementation` (created in Task 10)
4. Update CLAUDE.md Language-Based Routing table

---

### 12. Update settings.json for Nix commands
- **Status**: [COMPLETED]
- **Priority**: low
- **Language**: meta
- **Researched**: 2026-02-03
- **Planned**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/12_update_settings_for_nix_commands/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/12_update_settings_for_nix_commands/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/12_update_settings_for_nix_commands/summaries/implementation-summary-20260203.md)

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

---

## Completed Tasks

(archived - see specs/archive/)

## Archived Tasks

- #1: Update CLAUDE.md for dotfiles repository (completed 2026-02-03)
- #2: Update README.md for dotfiles context (completed 2026-02-03)
- #4: Manage Claude settings.json with home-manager (completed 2026-02-03)
- #5: Create Nix context directory structure (completed 2026-02-03)
- #6: Create Nix rules file (completed 2026-02-03)
- #7: Create nix-research-agent (completed 2026-02-03)
- #8: Create nix-implementation-agent (completed 2026-02-03)
- #9: Create skill-nix-research (completed 2026-02-03)
- #10: Create skill-nix-implementation (completed 2026-02-03)
- #13: Research Nix MCP tools (completed 2026-02-03)
