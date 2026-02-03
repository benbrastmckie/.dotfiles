# Research Report: Task #8

**Task**: 8 - create_nix_implementation_agent
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:30:00Z
**Effort**: 2 hours (estimated for implementation)
**Dependencies**: Task 5 (Nix context files), Task 6 (Nix rules), Task 7 (nix-research-agent)
**Sources/Inputs**: Codebase analysis, existing agent patterns
**Artifacts**: - specs/8_create_nix_implementation_agent/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The nix-implementation-agent should mirror neovim-implementation-agent structure with 8-stage execution flow
- Nix-specific verification commands: `nix flake check`, `nixos-rebuild build --flake .#<hostname>`, `home-manager build --flake .#<user>`
- Context loading should reference all Nix domain and pattern files created in Task 5/6
- Build times for Nix can be significant; agent should prefer evaluation checks over full builds where appropriate

## Context & Scope

This research analyzes how to create `nix-implementation-agent.md` by studying:
1. The existing `neovim-implementation-agent.md` structure (primary template)
2. The `nix-research-agent.md` created in Task 7 (context loading patterns)
3. Nix context files in `.claude/context/project/nix/` (domain knowledge)
4. Nix rules in `.claude/rules/nix.md` (coding standards)
5. Other domain-specific implementation agents (latex, typst) for additional patterns

## Findings

### Neovim Implementation Agent Structure Analysis

The neovim-implementation-agent.md follows an 8-stage execution flow:

| Stage | Purpose | Nix Adaptation Required |
|-------|---------|------------------------|
| Stage 0 | Initialize Early Metadata | Identical pattern (agent-type: nix-implementation-agent) |
| Stage 1 | Parse Delegation Context | Identical pattern (language: nix) |
| Stage 2 | Load and Parse Implementation Plan | Identical pattern |
| Stage 3 | Find Resume Point | Identical pattern |
| Stage 4 | Execute Implementation Loop | **Nix-specific file operations and verification** |
| Stage 5 | Run Final Verification | **Nix-specific build commands** |
| Stage 6 | Create Implementation Summary | Same structure, Nix terminology |
| Stage 6a | Generate Completion Data | Identical pattern |
| Stage 7 | Write Metadata File | Identical pattern |
| Stage 8 | Return Brief Text Summary | Identical pattern |

**Key Sections from neovim-implementation-agent**:
- Allowed Tools (File Operations + Verification Tools)
- Context References (lazy loading with @-references)
- Execution Flow (8 stages with detailed instructions)
- Domain-Specific Implementation Patterns (plugin specs, keymaps, autocmds)
- Verification Commands (nvim --headless patterns)
- Error Handling (syntax errors, module not found, conflicts)
- Phase Checkpoint Protocol
- Critical Requirements (MUST DO / MUST NOT)

### Nix Research Agent Context Loading Patterns

From nix-research-agent.md (Task 7), the context loading pattern for Nix:

**Always Load**:
- `@.claude/context/core/formats/return-metadata-file.md` - Metadata file schema

**Load for Nix Implementation**:
- `@.claude/context/project/nix/README.md` - Nix context overview
- `@.claude/context/project/nix/domain/nix-language.md` - Nix syntax fundamentals
- `@.claude/context/project/nix/standards/nix-style-guide.md` - Formatting conventions

**Load Based on Task Type**:
| Task Type | Context Files |
|-----------|--------------|
| Package tasks | derivation-patterns.md, overlay-patterns.md |
| NixOS module tasks | nixos-modules.md, module-patterns.md |
| Home Manager tasks | home-manager.md, module-patterns.md |
| Flake tasks | flakes.md |
| Build/deploy tasks | nixos-rebuild-guide.md, home-manager-guide.md |

### Nix Verification Commands

Based on analysis of `.claude/rules/nix.md` and `.claude/context/project/nix/tools/`:

#### Syntax and Evaluation Verification (Fast)

```bash
# Check flake syntax and evaluate all outputs
nix flake check

# Show flake outputs (quick validation)
nix flake show

# Evaluate specific configuration option
nix eval .#nixosConfigurations.hostname.config.services.nginx.enable
```

#### Build Verification (Slower but Comprehensive)

```bash
# Build NixOS configuration without activating (dry-run)
nixos-rebuild build --flake .#hostname

# Build Home Manager configuration without activating
home-manager build --flake .#username

# Build specific package
nix build .#myPackage
```

#### Recommended Verification Strategy

1. **Always run first**: `nix flake check` - Fast, catches syntax errors and basic evaluation issues
2. **For NixOS changes**: `nixos-rebuild build --flake .#<hostname>` - Validates full system builds
3. **For Home Manager changes**: `home-manager build --flake .#<username>` - Validates user configuration
4. **For package changes**: `nix build .#<package>` - Validates specific package builds

**Build Time Considerations**:
- `nix flake check`: ~10-30 seconds (evaluation only)
- `nixos-rebuild build`: 1-10 minutes (depends on changes)
- `home-manager build`: 30 seconds - 5 minutes (depends on changes)

### Nix-Specific Implementation Patterns

From `.claude/rules/nix.md`:

#### NixOS Module Structure
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myService;
in {
  options.services.myService = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    # configuration here
  };
}
```

#### Home Manager Module Structure
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.myProgram;
in {
  options.programs.myProgram = {
    enable = lib.mkEnableOption "my program";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.myProgram ];
  };
}
```

#### Overlay Patterns
```nix
overlays.default = final: prev: {
  myPackage = prev.myPackage.overrideAttrs (oldAttrs: {
    # overrides
  });
};
```

### Existing Repository Nix Files

From Glob analysis of `**/*.nix`:
- `flake.nix` - Main flake with 4 NixOS configurations (nandi, hamsa, iso, usb-installer)
- `configuration.nix` - Shared NixOS configuration
- `home.nix` - Home Manager configuration
- `hosts/*/hardware-configuration.nix` - Per-host hardware config
- `packages/*.nix` - Custom package definitions (claude-code, loogle, etc.)
- `home-modules/*.nix` - Custom Home Manager modules (mcp-hub)

The repository uses:
- `nixpkgs-unstable` channel
- Home Manager as NixOS module (not standalone)
- Multiple overlays (claude-squad, unstable packages, python packages)
- Flakes with `follows` patterns for input consistency

### Error Handling Patterns

Common Nix errors to handle:

| Error Type | Example Message | Recovery |
|------------|----------------|----------|
| Syntax Error | `error: syntax error, unexpected '}'` | Parse error location, fix syntax |
| Undefined Variable | `error: undefined variable 'cfg'` | Check imports, add missing let binding |
| Type Mismatch | `error: value is a string while a set was expected` | Fix option type or value |
| Missing Attribute | `error: attribute 'enable' missing` | Add required option or check path |
| Infinite Recursion | `error: infinite recursion encountered` | Remove circular dependencies |
| Build Failure | `error: builder failed with exit code 1` | Check build logs, fix derivation |

### Comparison: Neovim vs Nix Implementation Agents

| Aspect | Neovim Agent | Nix Agent |
|--------|-------------|-----------|
| File Types | `*.lua` | `*.nix`, `flake.nix`, `configuration.nix`, `home.nix` |
| Primary Verification | `nvim --headless -c "lua require('module')" -c "q"` | `nix flake check` |
| Secondary Verification | `checkhealth` | `nixos-rebuild build --flake .` |
| Build Tool | N/A (interpreted) | `nix build`, `nixos-rebuild`, `home-manager` |
| Style Guide | lua-style-guide.md | nix-style-guide.md |
| Domain Context | `context/project/neovim/` | `context/project/nix/` |
| Rules File | `rules/neovim-lua.md` | `rules/nix.md` |
| Invoked By | skill-neovim-implementation | skill-nix-implementation |
| Agent Type | neovim-implementation-agent | nix-implementation-agent |

### Recommendations

1. **Agent Structure**: Mirror neovim-implementation-agent exactly for all 8 stages, with Nix-specific adaptations in:
   - Stage 4 (Execute Implementation Loop) - Nix file patterns
   - Stage 5 (Final Verification) - Nix build commands

2. **Verification Strategy**:
   - Always run `nix flake check` after any `.nix` file change (fast)
   - Run `nixos-rebuild build` for NixOS module changes
   - Run `home-manager build` for Home Manager changes
   - Include `--show-trace` flag for debugging failures

3. **Context Loading**: Reference all Nix context files with task-type-based loading

4. **Build Time Handling**:
   - Document that builds can take several minutes
   - Recommend evaluation-only checks for quick iteration
   - Full builds for final verification only

5. **Error Handling**: Include Nix-specific error patterns (syntax, type, recursion)

6. **Critical Requirements**: Include same Stage 0 early metadata pattern, MUST DO/MUST NOT lists

## Decisions

- Agent will follow 8-stage execution flow identical to neovim-implementation-agent
- Primary verification will use `nix flake check` (fast, comprehensive)
- Secondary verification will use `nixos-rebuild build` or `home-manager build` based on change type
- Will include Nix-specific implementation patterns section with module, overlay examples
- Will reference all Nix context files created in Task 5

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Build timeout | Medium | Medium | Prefer `nix flake check` for quick feedback, full builds only when necessary |
| Flake lock changes | Low | Medium | Document that lock updates should be intentional, not automatic |
| Host-specific failures | Medium | Low | Agent should identify which host configuration is affected |
| Network-dependent builds | Low | Low | Most builds should work offline after initial cache |

## Appendix

### Search Queries Used
- Glob: `.claude/agents/**/*.md` - Found all existing agents
- Glob: `.claude/context/project/nix/**/*.md` - Found all Nix context files
- Glob: `**/*.nix` - Found all Nix files in repository
- Read: neovim-implementation-agent.md, nix-research-agent.md, nix.md rules

### References
- `.claude/agents/neovim-implementation-agent.md` - Primary template
- `.claude/agents/nix-research-agent.md` - Context loading patterns
- `.claude/rules/nix.md` - Nix coding standards
- `.claude/context/project/nix/tools/nixos-rebuild-guide.md` - Build commands
- `.claude/context/project/nix/tools/home-manager-guide.md` - HM commands
- Nix Flakes documentation - Build verification patterns
