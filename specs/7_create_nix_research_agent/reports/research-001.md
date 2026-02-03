# Research Report: Task #7 - Create Nix Research Agent

- **Task**: 7 - create_nix_research_agent
- **Started**: 2026-02-03T12:00:00Z
- **Completed**: 2026-02-03T12:15:00Z
- **Effort**: 15 minutes
- **Dependencies**: Task 5 (Nix context files), Task 6 (Nix rules)
- **Sources/Inputs**: neovim-research-agent.md, skill-neovim-research/SKILL.md, nix.md rules, Nix context files, return-metadata-file.md
- **Artifacts**: This report
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The neovim-research-agent provides a clear template with 7 execution stages, context loading patterns, and metadata file handling
- The nix-research-agent should mirror this structure but load Nix-specific context from `.claude/context/project/nix/`
- Key adaptations needed: Nix-specific research strategy decision tree, verification commands (nix flake check, nixos-rebuild), and domain categories
- Integration will require a new skill-nix-research that mirrors skill-neovim-research
- The existing Nix context files (task 5) and rules (task 6) provide comprehensive domain knowledge for the agent

## Context & Scope

This research examines how to create `nix-research-agent.md` by adapting the existing `neovim-research-agent.md` pattern. The goal is a domain-specific research agent that understands Nix language, flakes, NixOS modules, Home Manager, overlays, and derivations.

## Findings

### Neovim Research Agent Structure Analysis

The neovim-research-agent follows a 7-stage execution flow:

| Stage | Purpose | Nix Adaptation |
|-------|---------|----------------|
| Stage 0 | Initialize early metadata | Same pattern |
| Stage 1 | Parse delegation context | Same pattern |
| Stage 2 | Analyze task, determine strategy | Nix-specific categories |
| Stage 3 | Execute primary searches | Nix-specific search patterns |
| Stage 4 | Synthesize findings | Same pattern |
| Stage 5 | Create research report | Same report format |
| Stage 6 | Write metadata file | Same pattern |
| Stage 7 | Return brief text summary | Same pattern |

### Context Loading Pattern

**Neovim agent loads**:
- `@.claude/context/core/formats/return-metadata-file.md` - Always
- `@.claude/context/core/formats/report-format.md` - When creating report
- `@.claude/context/project/neovim/README.md` - For Neovim research
- `@.claude/context/project/neovim/domain/neovim-api.md` - vim.* patterns
- `@.claude/context/project/neovim/domain/plugin-ecosystem.md` - Plugin overview

**Nix agent should load**:
- `@.claude/context/core/formats/return-metadata-file.md` - Always
- `@.claude/context/core/formats/report-format.md` - When creating report
- `@.claude/context/project/nix/README.md` - For Nix research overview
- `@.claude/context/project/nix/domain/nix-language.md` - Nix syntax fundamentals
- Conditional loading based on task type (see below)

### Nix Context Files Available (Task 5)

The following context files are available for the nix-research-agent:

**Domain (core concepts)**:
- `domain/nix-language.md` - Nix expression syntax
- `domain/flakes.md` - Flake structure and inputs
- `domain/nixos-modules.md` - NixOS module system
- `domain/home-manager.md` - Home Manager modules

**Patterns (implementation)**:
- `patterns/module-patterns.md` - Module definition patterns
- `patterns/overlay-patterns.md` - Overlay patterns
- `patterns/derivation-patterns.md` - Package derivation patterns

**Standards**:
- `standards/nix-style-guide.md` - Formatting, naming conventions

**Tools**:
- `tools/nixos-rebuild-guide.md` - System rebuild workflows
- `tools/home-manager-guide.md` - Home Manager workflows

### Research Strategy Decision Tree

**Neovim agent categories**:
1. Plugin setup -> Plugin docs + examples
2. Keybindings -> Existing config + patterns
3. LSP config -> LSP docs + lspconfig
4. UI/Theme -> Plugin comparisons
5. Performance -> Profiling + optimization

**Nix agent categories** (proposed):
1. "How do I add/configure a package?" -> overlay-patterns.md, derivation-patterns.md
2. "How do I configure a system service?" -> nixos-modules.md, module-patterns.md
3. "How do I set up user configuration?" -> home-manager.md, module-patterns.md
4. "How do I modify my flake?" -> flakes.md
5. "What's the Nix syntax for X?" -> nix-language.md, nix-style-guide.md
6. "How do I build/test my configuration?" -> nixos-rebuild-guide.md, home-manager-guide.md

### Search Priority for Nix

1. Local configuration (existing patterns in *.nix files)
2. Project context files (documented patterns in .claude/context/project/nix/)
3. Nixpkgs documentation (options, packages)
4. NixOS Wiki and official documentation
5. Community resources (NixOS Discourse, GitHub examples)

### Verification Commands

**Neovim agent uses**:
- `nvim --headless -c "lua require('module')" -c "q"` - Test module loads
- `nvim --headless -c "checkhealth" -c "q"` - Run checkhealth

**Nix agent should use**:
- `nix flake check` - Check flake syntax and evaluate
- `nix flake show` - Show flake outputs
- `nixos-rebuild build --flake .#hostname` - Build NixOS configuration
- `home-manager build --flake .#user` - Build Home Manager configuration
- `nix eval .#nixosConfigurations.hostname.config.services` - Evaluate without building

### Rules Integration

The Nix rules file (`.claude/rules/nix.md`) created in task 6 provides:
- Path pattern: `**/*.nix`
- Formatting standards (2 spaces, 100 char soft limit)
- Module structure patterns (NixOS and Home Manager)
- Flake conventions (inputs, outputs, overlays)
- Naming conventions
- Common patterns (mkIf, let bindings, inherit, overrides)
- "Do Not" list (avoid `with pkgs;`, `rec { }`, lookup paths, etc.)

### Repository-Specific Patterns

Analysis of the existing flake.nix shows patterns to recognize:
- Multiple nixosConfigurations (nandi, hamsa, iso, usb-installer)
- homeConfigurations for standalone home-manager
- Custom overlays (claudeSquadOverlay, unstablePackagesOverlay, pythonPackagesOverlay)
- Custom packages in `./packages/` directory
- Home modules in `./home-modules/` directory
- Hosts configurations in `./hosts/` directory

## Decisions

1. **Mirror the neovim-research-agent structure exactly** - The 7-stage flow and metadata patterns work well
2. **Adapt context references for Nix domain** - Load from `.claude/context/project/nix/` instead of neovim
3. **Create Nix-specific research categories** - Based on common Nix development tasks
4. **Include Nix verification commands** - nix flake check, nixos-rebuild, home-manager build
5. **Reference nix.md rules** - For coding standards and "Do Not" patterns

## Recommendations

### nix-research-agent.md Structure

```markdown
---
name: nix-research-agent
description: Research NixOS and Home Manager configuration tasks
---

# Nix Research Agent

## Overview
Research agent for Nix configuration tasks...

## Agent Metadata
- Name: nix-research-agent
- Purpose: Conduct research for Nix configuration and package tasks
- Invoked By: skill-nix-research (via Task tool)
- Return Format: Brief text summary + metadata file

## Allowed Tools
(Same as neovim-research-agent)

## Context References
**Always Load**:
- @.claude/context/core/formats/return-metadata-file.md

**Load When Creating Report**:
- @.claude/context/core/formats/report-format.md

**Load for Nix Research**:
- @.claude/context/project/nix/README.md - Overview
- @.claude/context/project/nix/domain/nix-language.md - Syntax fundamentals

## Research Strategy Decision Tree
(Nix-specific decision tree)

## Execution Flow
(Stages 0-7, same structure as neovim-research-agent)

## Nix-Specific Research Tips
### Package Research
### Module Research
### Flake Research

## Error Handling
(Same patterns)

## Critical Requirements
(Same patterns with Nix-specific adaptations)
```

### Integration with skill-nix-research (Task 9)

The skill should:
1. Validate task language is "nix"
2. Update status to "researching"
3. Create postflight marker
4. Invoke nix-research-agent via Task tool
5. Parse metadata file on return
6. Update status to "researched"
7. Git commit changes
8. Cleanup marker and metadata files

### Differences from Neovim Pattern

| Aspect | Neovim | Nix |
|--------|--------|-----|
| Context path | project/neovim/ | project/nix/ |
| Build commands | nvim --headless | nix flake check, nixos-rebuild |
| Research categories | Plugins, LSP, keybindings | Packages, modules, flakes, home-manager |
| External docs | Plugin READMEs | NixOS Wiki, options search |
| Local patterns | nvim/lua/ | *.nix files, flake.nix |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Nix build commands can be slow | Include timeout handling, note in tips |
| NixOS Wiki may be outdated | Cross-reference with options search, nixpkgs source |
| Flake lockfile changes | Warn about `nix flake update` implications |
| Complex module dependencies | Encourage tracing imports, checking specialArgs |

## Appendix

### Files Examined
- `.claude/agents/neovim-research-agent.md`
- `.claude/skills/skill-neovim-research/SKILL.md`
- `.claude/context/core/formats/return-metadata-file.md`
- `.claude/context/core/formats/report-format.md`
- `.claude/rules/nix.md`
- `.claude/context/project/nix/README.md`
- `.claude/context/project/neovim/README.md`
- `flake.nix` (repository example)

### Nix Context Files (Task 5)
```
.claude/context/project/nix/
├── README.md
├── domain/
│   ├── nix-language.md
│   ├── flakes.md
│   ├── nixos-modules.md
│   └── home-manager.md
├── patterns/
│   ├── module-patterns.md
│   ├── overlay-patterns.md
│   └── derivation-patterns.md
├── standards/
│   └── nix-style-guide.md
└── tools/
    ├── nixos-rebuild-guide.md
    └── home-manager-guide.md
```

### Related Tasks
- Task 5: Create Nix context files (completed)
- Task 6: Create Nix rules file (completed)
- Task 8: Create nix-research-agent.md (next - implementation)
- Task 9: Create skill-nix-research (future)
- Task 10: Create nix-implementation-agent.md (future)
- Task 11: Create skill-nix-implementation (future)
