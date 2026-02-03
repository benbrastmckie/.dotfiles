# Implementation Plan: Task #7

- **Task**: 7 - create_nix_research_agent
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 5 (Nix context files - completed), Task 6 (Nix rules - completed)
- **Research Inputs**: specs/7_create_nix_research_agent/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create `nix-research-agent.md` mirroring the structure and patterns of `neovim-research-agent.md`, adapted for Nix domain knowledge. The agent will conduct research for Nix configuration tasks using web search, codebase analysis, and the Nix context files created in Task 5. It follows the Stage 0-7 execution flow with early metadata creation for resilience.

### Research Integration

The research report (research-001.md) provides:
- Complete structural analysis of neovim-research-agent.md (7-stage execution flow)
- Nix-specific research categories (packages, modules, flakes, home-manager, syntax, builds)
- Context loading patterns mapping task types to Nix context files
- Verification commands (nix flake check, nixos-rebuild, home-manager build)
- Differences table between Neovim and Nix patterns

## Goals & Non-Goals

**Goals**:
- Create `.claude/agents/nix-research-agent.md` following agent template structure
- Mirror all 7 stages from neovim-research-agent.md with Nix adaptations
- Include Nix-specific research strategy decision tree
- Reference Nix context files and rules for domain knowledge
- Include verification commands appropriate for Nix configurations
- Support early metadata creation (Stage 0 resilience pattern)

**Non-Goals**:
- Creating skill-nix-research (that is Task 9)
- Creating nix-implementation-agent (that is Task 10)
- Modifying existing Nix context files
- Adding new context files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing domain patterns | Medium | Low | Research report provides comprehensive mapping |
| Inconsistency with neovim agent | Medium | Low | Direct structural mirroring with minimal deviation |
| Context file paths incorrect | Low | Low | Verify paths from Glob results before writing |

## Implementation Phases

### Phase 1: Create Agent File Structure [COMPLETED]

**Goal**: Create the nix-research-agent.md file with frontmatter and overview sections

**Tasks**:
- [ ] Create `.claude/agents/nix-research-agent.md` with YAML frontmatter
- [ ] Write Overview section describing agent purpose
- [ ] Write Agent Metadata section (name, purpose, invoked by, return format)
- [ ] Write Allowed Tools section (File Operations, Build Tools, Web Tools)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Create new file

**Verification**:
- File exists with valid frontmatter
- Overview clearly describes Nix research purpose
- Tool list matches neovim-research-agent pattern

---

### Phase 2: Add Context References and Research Strategy [COMPLETED]

**Goal**: Define context loading patterns and research decision tree for Nix

**Tasks**:
- [ ] Write Context References section with always-load, when-creating-report, and Nix-specific paths
- [ ] Create Research Strategy Decision Tree with 6 Nix categories
- [ ] Define Search Priority order (local -> context -> nixpkgs -> wiki -> community)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Add sections

**Verification**:
- Context paths match actual files in `.claude/context/project/nix/`
- Decision tree covers all major Nix task types
- Search priority reflects Nix ecosystem sources

---

### Phase 3: Implement 7-Stage Execution Flow [COMPLETED]

**Goal**: Document complete execution flow matching neovim-research-agent pattern

**Tasks**:
- [ ] Stage 0: Initialize Early Metadata (identical pattern)
- [ ] Stage 1: Parse Delegation Context (identical pattern with nix-research-agent name)
- [ ] Stage 2: Analyze Task and Determine Search Strategy (Nix categories)
- [ ] Stage 3: Execute Primary Searches (Nix-specific sources and verification)
- [ ] Stage 4: Synthesize Findings (same pattern)
- [ ] Stage 5: Create Research Report (same format)
- [ ] Stage 6: Write Metadata File (identical pattern)
- [ ] Stage 7: Return Brief Text Summary (identical pattern)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Add Execution Flow section

**Verification**:
- All 7 stages documented
- Stage 0 creates early metadata before substantive work
- Stages 3 and 4 contain Nix-specific adaptations
- Metadata file schema matches return-metadata-file.md

---

### Phase 4: Add Nix-Specific Tips and Error Handling [COMPLETED]

**Goal**: Complete agent with domain-specific guidance and error handling

**Tasks**:
- [ ] Write Nix-Specific Research Tips section (Package, Module, Flake subsections)
- [ ] Write Error Handling section (missing package, documentation gaps)
- [ ] Write Critical Requirements section (MUST DO / MUST NOT)
- [ ] Final review for consistency with neovim-research-agent

**Timing**: 15 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Complete remaining sections

**Verification**:
- Tips cover common Nix research scenarios
- Error handling matches established patterns
- Critical requirements include Stage 0 early metadata
- MUST NOT includes "completed" status value and workflow-ending phrases

---

## Testing & Validation

- [ ] Verify file exists at `.claude/agents/nix-research-agent.md`
- [ ] Verify YAML frontmatter is valid (name, description fields)
- [ ] Verify all context paths reference existing files
- [ ] Verify 7 stages are documented with Nix adaptations
- [ ] Verify Stage 0 early metadata pattern is present
- [ ] Compare structure against neovim-research-agent.md for consistency

## Artifacts & Outputs

- `.claude/agents/nix-research-agent.md` - The primary deliverable
- `specs/7_create_nix_research_agent/summaries/implementation-summary-{DATE}.md` - Completion summary

## Rollback/Contingency

If the agent file has issues:
1. Delete `.claude/agents/nix-research-agent.md`
2. Re-run implementation from Phase 1
3. Use neovim-research-agent.md as direct template with find/replace

The task is low-risk as it creates a single new file with no dependencies on existing functionality.
