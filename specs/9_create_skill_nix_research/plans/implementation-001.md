# Implementation Plan: Task #9

- **Task**: 9 - Create skill-nix-research
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: nix-research-agent.md (already exists)
- **Research Inputs**: specs/9_create_skill_nix_research/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the skill-nix-research thin wrapper skill that delegates to nix-research-agent following the established 11-stage pattern from skill-neovim-research. The skill handles preflight (status update, marker creation), delegation (Task tool invocation with context), and postflight (metadata parsing, artifact linking, git commit, cleanup). Research findings indicate the implementation is straightforward copy-and-customize from skill-neovim-research.

### Research Integration

Key findings from research-001.md:
- skill-neovim-research provides exact template to follow
- 11 execution stages required (input validation through return summary)
- jq commands must use "| not" pattern to avoid Issue #1132
- nix-research-agent already handles MCP-NixOS with graceful degradation
- Delegation path should be ["orchestrator", "research", "skill-nix-research"]

## Goals & Non-Goals

**Goals**:
- Create skill-nix-research/SKILL.md following skill-neovim-research pattern
- Implement all 11 execution stages
- Use correct jq escaping patterns
- Enable /research command routing for language "nix"

**Non-Goals**:
- Modify nix-research-agent (already complete)
- Add new features beyond the thin wrapper pattern
- Change the existing skill architecture

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq parse errors (Issue #1132) | M | M | Use "select(.type == X \| not)" pattern instead of "!=" |
| YAML frontmatter syntax error | L | L | Validate YAML structure matches template exactly |
| Missing stage in execution flow | M | L | Copy all 11 stages from skill-neovim-research template |

## Implementation Phases

### Phase 1: Create Skill Directory and SKILL.md [COMPLETED]

**Goal**: Create the skill-nix-research skill file with proper YAML frontmatter and all 11 execution stages

**Tasks**:
- [ ] Create directory `.claude/skills/skill-nix-research/`
- [ ] Copy SKILL.md structure from skill-neovim-research
- [ ] Update YAML frontmatter:
  - name: skill-nix-research
  - description: Conduct Nix/NixOS/Home Manager research using MCP-NixOS, web docs, and codebase exploration
  - allowed-tools: Task, Bash, Edit, Read, Write
- [ ] Update header and overview section for Nix context
- [ ] Update trigger conditions for language "nix"
- [ ] Update Stage 4 delegation context:
  - language: "nix"
  - delegation_path: ["orchestrator", "research", "skill-nix-research"]
- [ ] Update Stage 5 Task tool invocation:
  - subagent_type: "nix-research-agent"
  - description: "Execute Nix research for task {N}"
- [ ] Update Stage 11 return summary for Nix context

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-nix-research/SKILL.md` - Create new file

**Verification**:
- YAML frontmatter is valid (name, description, allowed-tools present)
- All 11 stages are present in Execution Flow
- Task tool invokes "nix-research-agent"
- Delegation path includes "skill-nix-research"
- jq commands use "| not" pattern

---

### Phase 2: Verify Integration [COMPLETED]

**Goal**: Validate skill file structure and integration points

**Tasks**:
- [ ] Read the created SKILL.md file
- [ ] Verify YAML frontmatter syntax is correct
- [ ] Verify all 11 stages are present:
  1. Input Validation
  2. Preflight Status Update
  3. Create Postflight Marker
  4. Prepare Delegation Context
  5. Invoke Subagent
  6. Parse Subagent Return
  7. Update Task Status (Postflight)
  8. Link Artifacts
  9. Git Commit
  10. Cleanup
  11. Return Brief Summary
- [ ] Verify context references point to correct files
- [ ] Verify jq commands use safe patterns
- [ ] Confirm skill triggers on language "nix"

**Timing**: 15 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- All 11 stages present and properly documented
- No jq commands use "!=" operator
- Context references are valid paths
- Subagent is "nix-research-agent"

---

### Phase 3: Documentation Confirmation [IN PROGRESS]

**Goal**: Confirm skill is properly documented in CLAUDE.md skill-to-agent mapping

**Tasks**:
- [ ] Verify CLAUDE.md already lists skill-nix-research -> nix-research-agent mapping
- [ ] Confirm language routing table includes "nix" language
- [ ] No changes needed if already documented (research confirms it is)

**Timing**: 10 minutes

**Files to modify**:
- None (verification only - research confirms mapping already exists in CLAUDE.md)

**Verification**:
- Skill-to-Agent Mapping table includes skill-nix-research -> nix-research-agent
- Language-Based Routing table includes "nix" language

---

## Testing & Validation

- [ ] SKILL.md file created at `.claude/skills/skill-nix-research/SKILL.md`
- [ ] YAML frontmatter is syntactically valid
- [ ] All 11 execution stages documented
- [ ] Task tool invokes nix-research-agent (not neovim-research-agent)
- [ ] Delegation path includes "skill-nix-research"
- [ ] jq commands use "| not" pattern (no "!=" operators)
- [ ] Context references use valid paths
- [ ] Skill triggers on language "nix"

## Artifacts & Outputs

- `.claude/skills/skill-nix-research/SKILL.md` - Main skill file
- `specs/9_create_skill_nix_research/summaries/implementation-summary-{DATE}.md` - Implementation summary

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/skills/skill-nix-research/` directory
2. No other files are modified (CLAUDE.md already has the mapping)
3. Re-run /implement 9 to retry
