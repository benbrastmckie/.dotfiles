# Task List

## Active Tasks

### 13. Research Nix MCP tools
- **Status**: [COMPLETED]
- **Priority**: medium
- **Language**: general
- **Researched**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/13_research_nix_mcp_tools/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/13_research_nix_mcp_tools/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/13_research_nix_mcp_tools/summaries/implementation-summary-20260203.md)

**Description**: Identify MCP servers or other tools that could enhance Nix search or otherwise assist the nix-research-agent implemented in task 7.

---

### 1. Update CLAUDE.md for dotfiles repository
- **Status**: [COMPLETED]
- **Priority**: high
- **Language**: meta
- **Researched**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/1_update_claudemd_for_dotfiles/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/1_update_claudemd_for_dotfiles/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/1_update_claudemd_for_dotfiles/summaries/implementation-summary-20260203.md)
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
- **Status**: [PLANNING]
- **Priority**: high
- **Language**: meta
- **Researched**: 2026-02-03
- **Research**: [research-001.md](specs/2_update_readme_for_dotfiles/reports/research-001.md)
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
- **Status**: [NOT STARTED]
- **Priority**: medium
- **Language**: general

**Description**: Maintain ~/.claude.json and ~/.claude/settings.json via home-manager similar to other config files like wezterm.lua in the dotfiles repository.

---

### 5. Create Nix context directory structure
- **Status**: [COMPLETED]
- **Completed**: 2026-02-03
- **Priority**: high
- **Language**: meta
- **Research**: [research-001.md](specs/5_create_nix_context_directory/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/5_create_nix_context_directory/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/5_create_nix_context_directory/summaries/implementation-summary-20260203.md)

**Description**: Create context/project/nix/ directory structure with domain knowledge (Nix language, flakes, modules), patterns (module patterns, overlays), standards (style guide), and tools (home-manager, nixos-rebuild guides).

**Structure**:
```
.claude/context/project/nix/
├── README.md                    # Nix context overview
├── domain/                      # Domain knowledge
│   ├── nix-language.md         # Nix expression syntax
│   ├── flakes.md               # Flake structure and inputs
│   ├── nixos-modules.md        # NixOS module system
│   └── home-manager.md         # Home Manager modules
├── patterns/                    # Implementation patterns
│   ├── module-patterns.md      # Module definition patterns
│   ├── overlay-patterns.md     # Overlay patterns
│   └── derivation-patterns.md  # Package derivation patterns
├── standards/                   # Coding standards
│   └── nix-style-guide.md      # Formatting, naming conventions
└── tools/                       # Tool-specific guides
    ├── nixos-rebuild-guide.md  # System rebuild workflows
    └── home-manager-guide.md   # Home Manager workflows
```

---

### 6. Create Nix rules file
- **Status**: [COMPLETED]
- **Completed**: 2026-02-03
- **Priority**: high
- **Language**: meta
- **Research**: [research-001.md](specs/6_create_nix_rules_file/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/6_create_nix_rules_file/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/6_create_nix_rules_file/summaries/implementation-summary-20260203.md)

**Description**: Create .claude/rules/nix.md with Nix-specific development rules auto-applied to *.nix files, covering formatting, module structure, and flake patterns.

**Applies to**: `*.nix`, `flake.nix`, `configuration.nix`, `home.nix`

**Should cover**:
- Indentation (2 spaces)
- Module structure patterns
- Flake input/output conventions
- Naming conventions (kebab-case for packages, camelCase for options)
- Common anti-patterns to avoid

---

### 7. Create nix-research-agent
- **Status**: [COMPLETED]
- **Priority**: high
- **Language**: meta
- **Depends on**: Tasks 5, 6
- **Researched**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/7_create_nix_research_agent/reports/research-001.md)
- **Plan**: [implementation-001.md](specs/7_create_nix_research_agent/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260203.md](specs/7_create_nix_research_agent/summaries/implementation-summary-20260203.md)

**Description**: Create nix-research-agent mirroring neovim-research-agent pattern with Nix domain knowledge: Nix language, flakes, NixOS modules, home-manager, overlays, derivations.

**Implementation Notes**:
- Mirror `.claude/agents/neovim-research-agent.md` structure
- Tools: WebSearch, WebFetch, Read, Write, Edit, Bash, Glob, Grep
- Domain: Nix language syntax, flake.nix patterns, NixOS module system, home-manager modules
- Output: Writes metadata file + research report artifact
- Include early metadata creation (Stage 0 resilience pattern)
- Load context from `.claude/context/project/nix/` (created in Task 5)
- Apply rules from `.claude/rules/nix.md` (created in Task 6)

---

### 8. Create nix-implementation-agent
- **Status**: [COMPLETED]
- **Priority**: high
- **Language**: meta
- **Depends on**: Tasks 5, 6
- **Researched**: 2026-02-03
- **Completed**: 2026-02-03
- **Research**: [research-001.md](specs/8_create_nix_implementation_agent/reports/research-001.md), [research-002.md](specs/8_create_nix_implementation_agent/reports/research-002.md)
- **Plan**: [implementation-002.md](specs/8_create_nix_implementation_agent/plans/implementation-002.md) (revised)
- **Summary**: [implementation-summary-20260203.md](specs/8_create_nix_implementation_agent/summaries/implementation-summary-20260203.md)

**Description**: Create nix-implementation-agent mirroring neovim-implementation-agent pattern with Nix-specific verification (nix flake check, nixos-rebuild build, home-manager build), phase-based execution, and MCP-NixOS integration.

**Implementation Notes**:
- Mirror `.claude/agents/neovim-implementation-agent.md` structure
- Verification commands: `nix flake check`, `nix build`, `nixos-rebuild build --flake .`, `home-manager build --flake .`
- Phase-based execution with Nix-specific validation
- **MCP-NixOS integration for package/option validation with graceful degradation**
- Handle flake lock updates appropriately
- Load context from `.claude/context/project/nix/` (created in Task 5)
- Apply rules from `.claude/rules/nix.md` (created in Task 6)

---

### 9. Create skill-nix-research
- **Status**: [NOT STARTED]
- **Priority**: high
- **Language**: meta
- **Depends on**: Task 7

**Description**: Create skill-nix-research thin wrapper skill that delegates to nix-research-agent following the established skill pattern (preflight, delegate, postflight).

**Implementation Notes**:
- Mirror `.claude/skills/skill-neovim-research/SKILL.md` structure
- Preflight: Update task status to RESEARCHING
- Delegate: Invoke nix-research-agent via Task tool (created in Task 7)
- Postflight: Parse metadata, link artifacts, update status to RESEARCHED, git commit

---

### 10. Create skill-nix-implementation
- **Status**: [NOT STARTED]
- **Priority**: high
- **Language**: meta
- **Depends on**: Task 8

**Description**: Create skill-nix-implementation thin wrapper skill that delegates to nix-implementation-agent following the established skill pattern (preflight, delegate, postflight).

**Implementation Notes**:
- Mirror `.claude/skills/skill-neovim-implementation/SKILL.md` structure
- Preflight: Update task status to IMPLEMENTING
- Delegate: Invoke nix-implementation-agent via Task tool (created in Task 8)
- Postflight: Parse metadata, link artifacts, update status to COMPLETED, git commit

---

### 11. Update orchestrator for nix language routing
- **Status**: [NOT STARTED]
- **Priority**: medium
- **Language**: meta
- **Depends on**: Tasks 9, 10

**Description**: Update skill-orchestrator to add language='nix' routing that delegates to nix-specific agents for research and implementation.

**Changes Required**:
1. Add `nix` to language routing table
2. Route `language: "nix"` research to `skill-nix-research` (created in Task 9)
3. Route `language: "nix"` implementation to `skill-nix-implementation` (created in Task 10)
4. Update CLAUDE.md Language-Based Routing table

---

### 12. Update settings.json for Nix commands
- **Status**: [NOT STARTED]
- **Priority**: low
- **Language**: meta

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

(none)

## Archived Tasks

(none)
