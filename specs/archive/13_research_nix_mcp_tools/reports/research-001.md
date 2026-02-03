# Research Report: Task #13

**Task**: 13 - research_nix_mcp_tools
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:30:00Z
**Effort**: Low-Medium
**Dependencies**: Task 7 (nix-research-agent - already implemented)
**Sources/Inputs**: WebSearch, WebFetch, Codebase analysis, Nix CLI exploration
**Artifacts**: specs/13_research_nix_mcp_tools/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **MCP-NixOS** is a mature, production-ready MCP server that provides comprehensive NixOS ecosystem search (130K+ packages, 23K+ options, Home Manager, nix-darwin, Nixvim, FlakeHub)
- Multiple Nix CLI tools have structured JSON output that could supplement MCP-NixOS or be wrapped as additional tools
- Community search services (noogle.dev, search.nixos.org) have queryable APIs but are mostly already exposed through MCP-NixOS
- **Recommended**: Integrate MCP-NixOS as primary enhancement; consider wrapping nix-locate for file-to-package lookup

## Context & Scope

This research investigates MCP servers and tools that could enhance the nix-research-agent (implemented in task 7). The agent currently uses:
- Web tools: WebSearch, WebFetch
- File tools: Read, Write, Edit, Glob, Grep
- Build tools: Bash (nix flake check, nix eval, etc.)

The goal is to identify additional MCP tools that could provide more accurate, structured access to Nix ecosystem information.

## Findings

### 1. Existing Nix-Focused MCP Servers

#### MCP-NixOS (Highly Recommended)

**Repository**: [utensils/mcp-nixos](https://github.com/utensils/mcp-nixos)
**Website**: [mcp-nixos.io](https://mcp-nixos.io/)
**Status**: Production-ready, actively maintained

**Key Features**:
- Unified `nix()` query tool with actions: search, info, stats, options, channels, flake-inputs, cache
- `nix_versions()` for package version history with nixpkgs commit hashes
- Coverage: 130K+ packages, 23K+ NixOS options, 5K+ Home Manager options, nix-darwin, Nixvim, FlakeHub
- Sources: nixos, home-manager, darwin, flakes, flakehub, nixvim, noogle, wiki, nix-dev, nixhub

**Installation Options**:
```bash
# uvx (recommended - no install)
uvx mcp-nixos

# pip
pip install mcp-nixos

# Nix
nix run github:utensils/mcp-nixos
```

**Why Valuable**:
- Eliminates hallucinated package names and options
- No Nix/NixOS required on the host system
- Optimized for minimal context window usage (~1,030 tokens)
- Already integrates noogle.dev, search.nixos.org, FlakeHub APIs

**Integration Complexity**: Low - standard MCP server, well-documented

#### mcp-servers-nix (Framework for MCP Deployment)

**Repository**: [natsukium/mcp-servers-nix](https://github.com/natsukium/mcp-servers-nix)

A Nix-based framework for configuring and deploying MCP servers. Useful if deploying multiple MCP servers via flake-parts, but not a Nix-specific search tool itself.

**Integration Complexity**: Medium - useful for infrastructure, not for search capabilities

#### mcps.nix (Home Manager MCP Integration)

**Repository**: [roman/mcps.nix](https://github.com/roman/mcps.nix)

Flake with MCP server presets for home-manager and devenv modules. Integrates with home-manager's native Claude Code support.

**Integration Complexity**: Low - if using home-manager for Claude Code config

### 2. Nix CLI Tools with Structured Output

These tools could supplement MCP-NixOS or be wrapped as custom MCP tools:

#### nix search (JSON output available)

```bash
nix search nixpkgs#packageName --json
```

**Capabilities**:
- Search packages by name/description regex
- Supports flake references
- JSON output for structured parsing

**Use Case**: Quick package existence checks without API calls

#### nix eval (JSON output)

```bash
nix eval --json nixpkgs#hello.meta
nix eval --raw nixpkgs#lib.version
```

**Capabilities**:
- Evaluate any Nix expression
- Access package metadata, options, lib functions
- JSON or raw output

**Use Case**: Deep introspection of package attributes, option values

#### nix-locate / nix-index (Installed on system)

```bash
nix-locate -w bin/nvim
nix-locate --minimal bin/some-binary
```

**Capabilities**:
- Find which package provides a specific file
- Supports regex patterns
- Minimal output mode for scripting
- Pre-generated databases available via nix-index-database

**Use Case**: "What package provides this binary/library?"

**Integration Complexity**: Low - CLI wrapper needed

#### nix flake show (JSON output)

```bash
nix flake show --json
```

**Capabilities**:
- List all outputs of a flake
- Structured JSON showing packages, modules, overlays

**Use Case**: Explore flake structure without evaluation

### 3. Community Search Services

#### noogle.dev

**Repository**: [nix-community/noogle](https://github.com/nix-community/noogle)

**Capabilities**:
- Search nix functions by type signature, name, description
- Covers builtins, lib, and pkgs functions
- Wasm-based performant search
- Updated daily from nixpkgs main branch

**Status**: Already integrated in MCP-NixOS as a source

#### search.nixos.org

**Repository**: [NixOS/nixos-search](https://github.com/NixOS/nixos-search)

**Endpoints**:
- `/packages` - Package search
- `/options` - NixOS options search
- `/flakes?type=packages` - Flake packages
- `/flakes?type=options` - Flake options

**CLI Access**: [peterldowns/nix-search-cli](https://github.com/peterldowns/nix-search-cli)

```bash
nix-search --query "neovim" --json
nix-search --program "nvim" --details
```

**Status**: Already integrated in MCP-NixOS; CLI could be useful backup

#### FlakeHub

**Website**: [flakehub.com](https://flakehub.com/)
**CLI**: [DeterminateSystems/fh](https://github.com/DeterminateSystems/fh)

**Capabilities**:
- Search and discover published flakes
- Add flake inputs to projects
- Version tracking with semantic versioning

**Status**: Already integrated in MCP-NixOS

### 4. Nix Linting and Analysis Tools

These don't enhance search but could be valuable for configuration validation:

#### statix

**Repository**: [oppiliappan/statix](https://github.com/oppiliappan/statix)

**Capabilities**:
- Lint Nix code for antipatterns
- Auto-fix common issues
- JSON output format

**Use Case**: Validate generated Nix configurations

#### deadnix

**Repository**: [astro/deadnix](https://github.com/astro/deadnix)

**Capabilities**:
- Find unused code in .nix files
- Auto-remove dead code
- JSON output format

**Use Case**: Clean up generated configurations

#### nixpkgs-hammering

**Repository**: [jtojnar/nixpkgs-hammering](https://github.com/jtojnar/nixpkgs-hammering)

**Capabilities**:
- Lint package expressions
- Enforce nixpkgs conventions

**Use Case**: Validate package derivations

### 5. Nix Language Servers

Could provide LSP-style introspection:

#### nil

**Repository**: [oxalica/nil](https://github.com/oxalica/nil)

- Incremental analysis
- Error-tolerant parsing
- Code completion

#### nixd

**Repository**: (linked with official Nix library)

- Package and lib completion from nixpkgs
- NixOS and Home Manager option completion
- Lazy evaluation for resource optimization

**Integration Complexity**: High - these are LSP servers, not MCP tools

## Recommendations

### Tier 1: Immediate Integration (High Value, Low Effort)

| Tool | Value | Effort | Recommendation |
|------|-------|--------|----------------|
| **MCP-NixOS** | Very High | Low | **Integrate immediately** - covers 90% of search needs |

**Implementation**: Add to Claude Code MCP configuration:
```json
{
  "mcpServers": {
    "mcp-nixos": {
      "command": "uvx",
      "args": ["mcp-nixos"]
    }
  }
}
```

### Tier 2: Supplementary Tools (Medium Value, Low Effort)

| Tool | Value | Effort | Recommendation |
|------|-------|--------|----------------|
| nix-locate wrapper | Medium | Low | Wrap as Bash helper for "what package provides X?" |
| nix-search-cli | Low | Low | Backup if MCP-NixOS unavailable |

**Implementation**: Add shell functions to nix-research-agent:
```bash
# Find package providing a file
nix-locate -w --minimal "$1"
```

### Tier 3: Validation Tools (Situational Value)

| Tool | Value | Effort | Recommendation |
|------|-------|--------|----------------|
| statix | Medium | Low | Use in implementation agents for validation |
| deadnix | Low | Low | Use in cleanup/maintenance tasks |

### Not Recommended

| Tool | Reason |
|------|--------|
| nil/nixd LSP | Too complex to integrate; designed for editors, not agents |
| mcp-servers-nix | Infrastructure framework, not a search capability |
| Direct API calls to search.nixos.org | Already covered by MCP-NixOS |

## Decisions

1. **Primary MCP integration**: MCP-NixOS provides comprehensive coverage and should be the primary enhancement
2. **Supplementary CLI**: nix-locate should be available as a Bash fallback for file-to-package lookups
3. **No custom MCP server needed**: MCP-NixOS already aggregates most useful APIs
4. **Validation optional**: statix/deadnix for implementation agents, not research agents

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| MCP-NixOS rate limits | Use cached results; fall back to nix CLI tools |
| MCP-NixOS unavailable | Keep WebSearch as fallback for nix documentation |
| API data staleness | MCP-NixOS syncs with nixpkgs daily; acceptable for most use cases |
| Context window bloat | MCP-NixOS optimized for ~1,030 tokens; monitor usage |

## Appendix

### Search Queries Used
- "MCP Model Context Protocol server Nix NixOS package search 2026"
- "nix MCP server nixpkgs options flake exploration tool 2025 2026"
- "noogle.dev API nix documentation search tool"
- "nix-index nix-locate CLI tool package file search"
- "search.nixos.org API nixos packages options search"
- "flakehub.com API flake search discovery tool"
- "manix nix documentation search CLI tool"
- "statix nix linter static analysis tool"
- "deadnix unused code detection nix linter tool"
- "nil nix language server LSP features"
- "nixd nix language server daemon features"

### References
- [MCP-NixOS GitHub](https://github.com/utensils/mcp-nixos)
- [MCP-NixOS Website](https://mcp-nixos.io/)
- [noogle.dev](https://noogle.dev/)
- [nix-community/nix-index](https://github.com/nix-community/nix-index)
- [NixOS Search](https://search.nixos.org/)
- [FlakeHub](https://flakehub.com/)
- [nix-search-cli](https://github.com/peterldowns/nix-search-cli)
- [manix](https://github.com/nix-community/manix)
- [statix](https://github.com/oppiliappan/statix)
- [deadnix](https://github.com/astro/deadnix)
