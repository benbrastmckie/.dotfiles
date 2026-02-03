# Implementation Plan: Task #8 (Revised)

- **Task**: 8 - create_nix_implementation_agent
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: Task 5 (Nix context files), Task 6 (Nix rules), Task 7 (nix-research-agent)
- **Research Inputs**: specs/8_create_nix_implementation_agent/reports/research-001.md, research-002.md
- **Artifacts**: plans/implementation-002.md (this file)
- **Previous Version**: plans/implementation-001.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Revision Summary

**Changes from v001**:
- Added MCP-NixOS integration as a primary goal (moved from Non-Goals)
- Added new Phase 4: MCP-NixOS Integration
- Expanded Phase 3 with MCP-aware validation patterns
- Updated time estimates (+1 hour for MCP integration)
- Added MCP-specific error handling in Phase 5

## Overview

Create `nix-implementation-agent.md` by adapting the established `neovim-implementation-agent.md` pattern for Nix development workflows. The agent will execute implementation plans for Nix tasks using Nix-specific verification commands (`nix flake check`, `nixos-rebuild build`, `home-manager build`) and load context from `.claude/context/project/nix/`.

**Key Enhancement**: This version integrates MCP-NixOS support for package/option validation, addressing the documented LLM hallucination challenge with Nix package names and option paths.

### Research Integration

From research-001.md:
- Mirror the 8-stage execution flow from neovim-implementation-agent
- Use `nix flake check` as primary (fast) verification, full builds for final verification
- Include Nix-specific error handling patterns (syntax, type mismatch, infinite recursion)
- Reference all Nix context files created in Task 5

From research-002.md:
- **MCP-NixOS** provides 130K+ packages, 23K+ NixOS options, 5K+ Home Manager options
- Tools exposed: `nix(action, query, source, type, channel, limit)`, `nix_versions(package, version, limit)`
- Use for package validation before writing configurations
- Use for option path verification before using option hierarchies
- Agent should work standalone (graceful degradation) but benefit significantly when MCP available

## Goals & Non-Goals

**Goals**:
- Create nix-implementation-agent.md following the established agent pattern
- Support phase-based plan execution with resume capability
- Integrate Nix-specific verification commands
- **Integrate MCP-NixOS for package/option validation when available**
- **Implement graceful degradation when MCP is unavailable**
- Load context from .claude/context/project/nix/ directory
- Apply .claude/rules/nix.md coding standards
- Write metadata files per return-metadata-file.md format

**Non-Goals**:
- Creating new Nix context files (done in Task 5)
- Creating new Nix rules (done in Task 6)
- Supporting non-flake Nix configurations
- Implementing MCP server installation/configuration (user responsibility)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Build timeout during verification | Medium | Medium | Prefer `nix flake check` (fast) over full builds; document timing expectations |
| Host-specific configuration failures | Medium | Low | Agent identifies affected host in error messages |
| Missing context files | Low | Low | Check context file existence before referencing; graceful degradation |
| Inconsistent with other agents | Medium | Low | Use neovim-implementation-agent as direct template |
| MCP-NixOS unavailable | Medium | Medium | Agent works without MCP; validation falls back to nix commands |
| MCP rate limiting | Low | Low | Cache validation results; batch lookups where possible |
| Stale MCP data | Low | Low | MCP-NixOS updates from nixpkgs master; note potential staleness in errors |

## Implementation Phases

### Phase 1: Create Agent File Structure [COMPLETED]

**Goal**: Create the base agent file with metadata and overview sections matching established patterns.

**Tasks**:
- [ ] Create `.claude/agents/nix-implementation-agent.md`
- [ ] Add YAML frontmatter (name, description)
- [ ] Write Overview section describing purpose and invocation
- [ ] Write Agent Metadata section (Name, Purpose, Invoked By, Return Format)
- [ ] Write Allowed Tools section (File Operations + Nix verification commands + MCP tools)
- [ ] Add MCP-NixOS tools to allowed tools list:
  - [ ] `mcp__nixos__nix` - Package/option search and validation
  - [ ] `mcp__nixos__nix_versions` - Package version lookup

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Create new file

**Verification**:
- File exists with valid YAML frontmatter
- Sections follow neovim-implementation-agent.md structure
- MCP tools listed in Allowed Tools section

---

### Phase 2: Write Context References and Execution Flow [COMPLETED]

**Goal**: Define lazy context loading and the 8-stage execution flow adapted for Nix.

**Tasks**:
- [ ] Write Context References section with @-references to Nix context files
- [ ] Adapt Stage 0 (Early Metadata) for nix-implementation-agent
- [ ] Adapt Stage 1 (Parse Delegation Context) with language: nix
- [ ] Adapt Stage 2 (Load and Parse Plan) - identical structure
- [ ] Adapt Stage 3 (Find Resume Point) - identical structure
- [ ] Write Stage 4 (Execute Implementation Loop) with Nix file patterns
  - [ ] Add MCP availability check at loop start
  - [ ] Include MCP validation calls before package/option writes
- [ ] Write Stage 5 (Final Verification) with Nix build commands
- [ ] Adapt Stage 6 (Create Summary) - same structure, Nix terminology
- [ ] Adapt Stage 6a (Generate Completion Data) - identical structure
- [ ] Adapt Stages 7-8 (Metadata + Return) - identical structure

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add execution flow

**Verification**:
- All 8 stages documented
- Nix-specific adaptations in Stages 4 and 5
- Context references point to existing files
- MCP integration points documented in Stage 4

---

### Phase 3: Write Nix-Specific Patterns and Commands [COMPLETED]

**Goal**: Document Nix implementation patterns and verification commands with MCP-aware validation.

**Tasks**:
- [ ] Write Nix-Specific Implementation Patterns section
  - [ ] NixOS module structure pattern
  - [ ] Home Manager module structure pattern
  - [ ] Overlay pattern
  - [ ] Flake input/output patterns
- [ ] Write Verification Commands section
  - [ ] `nix flake check` (primary, fast)
  - [ ] `nix flake show` (quick validation)
  - [ ] `nixos-rebuild build --flake .#hostname` (NixOS changes)
  - [ ] `home-manager build --flake .#user` (HM changes)
  - [ ] `nix build .#package` (package changes)
- [ ] Document timing expectations for each command
- [ ] Write MCP-Aware Validation Patterns section
  - [ ] Package name validation before use
  - [ ] Option path validation before configuration
  - [ ] Function signature lookup for lib functions
  - [ ] Version availability check for pinned packages

**Timing**: 40 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add patterns and commands

**Verification**:
- All common Nix patterns documented with examples
- Verification commands match research-001.md recommendations
- MCP validation patterns documented with fallback behavior

---

### Phase 4: MCP-NixOS Integration [COMPLETED]

**Goal**: Document comprehensive MCP-NixOS integration patterns with graceful degradation.

**Tasks**:
- [ ] Write MCP-NixOS Integration section
  - [ ] Document MCP availability detection pattern
  - [ ] Document tool invocation patterns for `mcp__nixos__nix`
  - [ ] Document tool invocation patterns for `mcp__nixos__nix_versions`
- [ ] Write MCP Query Patterns subsection
  - [ ] Package search: `nix(action="search", query="packageName", source="nixpkgs")`
  - [ ] Package info: `nix(action="info", query="packageName", source="nixpkgs")`
  - [ ] NixOS options: `nix(action="options", query="services.x", source="nixos-options")`
  - [ ] Home Manager options: `nix(action="options", query="programs.x", source="home-manager")`
  - [ ] Function signatures: `nix(action="search", query="functionName", source="noogle")`
- [ ] Write Validation Workflow subsection
  - [ ] Pre-write validation: Check package/option exists before writing
  - [ ] Post-error validation: Verify hallucinated names on build failure
  - [ ] Suggestion generation: Use MCP to suggest alternatives on validation failure
- [ ] Write Graceful Degradation subsection
  - [ ] MCP unavailable: Skip validation, proceed with nix commands
  - [ ] MCP timeout: Log warning, continue without validation
  - [ ] MCP error: Fallback to `nix search` command

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add MCP integration section

**Verification**:
- MCP tool invocation patterns are syntactically correct
- Graceful degradation covers all failure modes
- Validation workflow integrates with execution stages

---

### Phase 5: Write Error Handling and Requirements [COMPLETED]

**Goal**: Document Nix-specific error handling and critical requirements including MCP-related errors.

**Tasks**:
- [ ] Write Error Handling section with Nix-specific errors:
  - [ ] Syntax errors
  - [ ] Undefined variable errors
  - [ ] Type mismatch errors
  - [ ] Missing attribute errors
  - [ ] Infinite recursion errors
  - [ ] Build failures
- [ ] Write MCP-Related Error Handling subsection:
  - [ ] Package not found (hallucinated name)
  - [ ] Option path invalid
  - [ ] Version not available
  - [ ] MCP server unavailable
- [ ] Write Phase Checkpoint Protocol (matching neovim agent)
- [ ] Write Critical Requirements section (MUST DO / MUST NOT lists)
  - [ ] Add MCP-specific requirements:
    - [ ] MUST validate new package names via MCP when available
    - [ ] MUST NOT skip validation silently when MCP is available
    - [ ] MUST log MCP unavailability as informational (not error)

**Timing**: 35 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add error handling and requirements

**Verification**:
- Error patterns match research-001.md table
- MCP-related errors documented with recovery strategies
- MUST DO/MUST NOT lists are comprehensive

---

### Phase 6: Update System References and Verify [COMPLETED]

**Goal**: Update CLAUDE.md skill-to-agent mapping and verify agent integration.

**Tasks**:
- [ ] Add nix-implementation-agent to CLAUDE.md Skill-to-Agent Mapping table
- [ ] Verify agent file follows established conventions (compare with neovim-implementation-agent)
- [ ] Check all @-references point to existing files
- [ ] Ensure verification commands are accurate for this repository
- [ ] Verify MCP tool names match actual MCP-NixOS tool names

**Timing**: 15 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Update Skill-to-Agent Mapping table
- `.claude/agents/nix-implementation-agent.md` - Final review and adjustments

**Verification**:
- CLAUDE.md table includes skill-nix-implementation -> nix-implementation-agent
- Agent file passes internal consistency check
- All referenced context files exist
- MCP tool names verified against MCP-NixOS documentation

## Testing & Validation

- [ ] Agent file created at `.claude/agents/nix-implementation-agent.md`
- [ ] YAML frontmatter parses correctly
- [ ] All 8 execution stages documented
- [ ] Context references point to existing `.claude/context/project/nix/` files
- [ ] Verification commands are valid (`nix flake check` etc.)
- [ ] Error handling patterns cover common Nix errors
- [ ] MCP-NixOS integration documented with:
  - [ ] Tool invocation patterns
  - [ ] Query patterns for packages, options, functions
  - [ ] Graceful degradation behavior
- [ ] CLAUDE.md Skill-to-Agent Mapping updated
- [ ] Agent structure mirrors neovim-implementation-agent.md

## Artifacts & Outputs

- `.claude/agents/nix-implementation-agent.md` - Main agent definition
- `.claude/CLAUDE.md` - Updated with new agent mapping
- `specs/8_create_nix_implementation_agent/plans/implementation-002.md` - This plan
- `specs/8_create_nix_implementation_agent/summaries/implementation-summary-{DATE}.md` - Summary (created on completion)

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/agents/nix-implementation-agent.md` if malformed
2. Revert CLAUDE.md changes using git
3. Preserve this plan for retry
4. Check dependencies (Tasks 5, 6, 7) are truly complete

If MCP integration is problematic:
1. Fall back to implementation-001.md (without MCP integration)
2. Defer MCP integration to a follow-up task
3. Ensure agent works in standalone mode first
