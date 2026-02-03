# Implementation Plan: Task #8

- **Task**: 8 - create_nix_implementation_agent
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 5 (Nix context files), Task 6 (Nix rules), Task 7 (nix-research-agent)
- **Research Inputs**: specs/8_create_nix_implementation_agent/reports/research-001.md, research-002.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `nix-implementation-agent.md` by adapting the established `neovim-implementation-agent.md` pattern for Nix development workflows. The agent will execute implementation plans for Nix tasks using Nix-specific verification commands (`nix flake check`, `nixos-rebuild build`, `home-manager build`) and load context from `.claude/context/project/nix/`. The design prioritizes fast evaluation checks over full builds where appropriate, and gracefully benefits from MCP-NixOS if available.

### Research Integration

From research-001.md:
- Mirror the 8-stage execution flow from neovim-implementation-agent
- Use `nix flake check` as primary (fast) verification, full builds for final verification
- Include Nix-specific error handling patterns (syntax, type mismatch, infinite recursion)
- Reference all Nix context files created in Task 5

From research-002.md:
- Design to benefit from MCP-NixOS when available (package/option validation)
- Address LLM hallucination risk with verification-first approach
- Agent should work standalone without MCP dependency

## Goals & Non-Goals

**Goals**:
- Create nix-implementation-agent.md following the established agent pattern
- Support phase-based plan execution with resume capability
- Integrate Nix-specific verification commands
- Load context from .claude/context/project/nix/ directory
- Apply .claude/rules/nix.md coding standards
- Write metadata files per return-metadata-file.md format

**Non-Goals**:
- Creating new Nix context files (done in Task 5)
- Creating new Nix rules (done in Task 6)
- Implementing MCP-NixOS integration (future enhancement)
- Supporting non-flake Nix configurations

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Build timeout during verification | Medium | Medium | Prefer `nix flake check` (fast) over full builds; document timing expectations |
| Host-specific configuration failures | Medium | Low | Agent identifies affected host in error messages |
| Missing context files | Low | Low | Check context file existence before referencing; graceful degradation |
| Inconsistent with other agents | Medium | Low | Use neovim-implementation-agent as direct template |

## Implementation Phases

### Phase 1: Create Agent File Structure [NOT STARTED]

**Goal**: Create the base agent file with metadata and overview sections matching established patterns.

**Tasks**:
- [ ] Create `.claude/agents/nix-implementation-agent.md`
- [ ] Add YAML frontmatter (name, description)
- [ ] Write Overview section describing purpose and invocation
- [ ] Write Agent Metadata section (Name, Purpose, Invoked By, Return Format)
- [ ] Write Allowed Tools section (File Operations + Nix verification commands)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Create new file

**Verification**:
- File exists with valid YAML frontmatter
- Sections follow neovim-implementation-agent.md structure

---

### Phase 2: Write Context References and Execution Flow [NOT STARTED]

**Goal**: Define lazy context loading and the 8-stage execution flow adapted for Nix.

**Tasks**:
- [ ] Write Context References section with @-references to Nix context files
- [ ] Adapt Stage 0 (Early Metadata) for nix-implementation-agent
- [ ] Adapt Stage 1 (Parse Delegation Context) with language: nix
- [ ] Adapt Stage 2 (Load and Parse Plan) - identical structure
- [ ] Adapt Stage 3 (Find Resume Point) - identical structure
- [ ] Write Stage 4 (Execute Implementation Loop) with Nix file patterns
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

---

### Phase 3: Write Nix-Specific Patterns and Commands [NOT STARTED]

**Goal**: Document Nix implementation patterns and verification commands.

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

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add patterns and commands

**Verification**:
- All common Nix patterns documented with examples
- Verification commands match research-001.md recommendations

---

### Phase 4: Write Error Handling and Requirements [NOT STARTED]

**Goal**: Document Nix-specific error handling and critical requirements.

**Tasks**:
- [ ] Write Error Handling section with Nix-specific errors:
  - [ ] Syntax errors
  - [ ] Undefined variable errors
  - [ ] Type mismatch errors
  - [ ] Missing attribute errors
  - [ ] Infinite recursion errors
  - [ ] Build failures
- [ ] Write Phase Checkpoint Protocol (matching neovim agent)
- [ ] Write Critical Requirements section (MUST DO / MUST NOT lists)
- [ ] Add note about optional MCP-NixOS benefit

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-implementation-agent.md` - Add error handling and requirements

**Verification**:
- Error patterns match research-001.md table
- MUST DO/MUST NOT lists are comprehensive

---

### Phase 5: Update System References and Verify [NOT STARTED]

**Goal**: Update CLAUDE.md skill-to-agent mapping and verify agent integration.

**Tasks**:
- [ ] Add nix-implementation-agent to CLAUDE.md Skill-to-Agent Mapping table
- [ ] Verify agent file follows established conventions (compare with neovim-implementation-agent)
- [ ] Check all @-references point to existing files
- [ ] Ensure verification commands are accurate for this repository

**Timing**: 15 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Update Skill-to-Agent Mapping table
- `.claude/agents/nix-implementation-agent.md` - Final review and adjustments

**Verification**:
- CLAUDE.md table includes skill-nix-implementation -> nix-implementation-agent
- Agent file passes internal consistency check
- All referenced context files exist

## Testing & Validation

- [ ] Agent file created at `.claude/agents/nix-implementation-agent.md`
- [ ] YAML frontmatter parses correctly
- [ ] All 8 execution stages documented
- [ ] Context references point to existing `.claude/context/project/nix/` files
- [ ] Verification commands are valid (`nix flake check` etc.)
- [ ] Error handling patterns cover common Nix errors
- [ ] CLAUDE.md Skill-to-Agent Mapping updated
- [ ] Agent structure mirrors neovim-implementation-agent.md

## Artifacts & Outputs

- `.claude/agents/nix-implementation-agent.md` - Main agent definition
- `.claude/CLAUDE.md` - Updated with new agent mapping
- `specs/8_create_nix_implementation_agent/plans/implementation-001.md` - This plan
- `specs/8_create_nix_implementation_agent/summaries/implementation-summary-{DATE}.md` - Summary (created on completion)

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/agents/nix-implementation-agent.md` if malformed
2. Revert CLAUDE.md changes using git
3. Preserve this plan for retry
4. Check dependencies (Tasks 5, 6, 7) are truly complete
