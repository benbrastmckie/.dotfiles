# Implementation Plan: Task #10

- **Task**: 10 - create_skill_nix_implementation
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task 8 (nix-implementation-agent) - COMPLETED
- **Research Inputs**: specs/10_create_skill_nix_implementation/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create skill-nix-implementation as a thin wrapper skill that delegates to nix-implementation-agent, following the established 11-stage execution pattern used by skill-typst-implementation. The skill will handle preflight status updates, invoke the agent via Task tool, perform postflight operations (status update, artifact linking, git commit), and return a brief text summary.

### Research Integration

Research findings confirm:
- Use skill-typst-implementation as the primary template (most recent, includes v2 patterns)
- Language validation must be "nix"
- Delegation path: ["orchestrator", "implement", "skill-nix-implementation"]
- CLAUDE.md skill-to-agent mapping already exists (no update needed)
- Verification commands handled by agent: nix flake check, nixos-rebuild build

## Goals & Non-Goals

**Goals**:
- Create SKILL.md file with correct frontmatter and 11-stage execution flow
- Update all Nix-specific references (language, agent, delegation path)
- Ensure consistent formatting with other implementation skills
- Maintain all context references for postflight patterns and jq escaping

**Non-Goals**:
- Updating CLAUDE.md (mapping already exists)
- Modifying nix-implementation-agent (already created in task 8)
- Adding new features beyond the established pattern

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Typo in agent name | M | L | Copy exact name from existing agent file |
| Missing jq escaping patterns | M | L | Include jq-escaping-workarounds.md reference |
| Inconsistent stage numbering | L | L | Compare directly with skill-typst-implementation |

## Implementation Phases

### Phase 1: Create skill-nix-implementation/SKILL.md [COMPLETED]

**Goal**: Create the complete skill file by adapting skill-typst-implementation

**Tasks**:
- [ ] Create directory `.claude/skills/skill-nix-implementation/`
- [ ] Create SKILL.md with frontmatter:
  - name: skill-nix-implementation
  - description: Implement Nix configuration changes from plans. Invoke for nix implementation tasks.
  - allowed-tools: Task, Bash, Edit, Read, Write
- [ ] Update skill title and description for Nix
- [ ] Update trigger conditions: language "nix"
- [ ] Update context references (keep generic postflight/metadata refs)
- [ ] Update Stage 0 (Preflight): Change skill name in marker
- [ ] Update Stage 1 (Input Validation): Change language check to "nix"
- [ ] Update Stage 2 (Context Preparation): Change delegation path and language
- [ ] Update Stage 3 (Invoke Subagent): Change to nix-implementation-agent
- [ ] Update Stage 3a (Validate Return): Keep as-is (generic)
- [ ] Update Stage 4 (Parse Return): Keep as-is (generic)
- [ ] Update Stage 5 (Postflight Status): Keep as-is (generic)
- [ ] Update Stage 6 (Git Commit): Keep as-is (generic)
- [ ] Update Stage 7 (Cleanup): Keep as-is (generic)
- [ ] Update Stage 8 (Return Summary): Update example messages for Nix
- [ ] Update Error Handling section for Nix context
- [ ] Update Return Format examples for Nix

**Timing**: 45 minutes

**Files to create**:
- `.claude/skills/skill-nix-implementation/SKILL.md` - Main skill definition

**Verification**:
- File exists at correct path
- Frontmatter has correct name, description, allowed-tools
- All references to "typst" replaced with "nix"
- Agent reference is "nix-implementation-agent"
- Language validation is "nix"

---

### Phase 2: Verification [COMPLETED]

**Goal**: Verify skill file is complete and consistent

**Tasks**:
- [ ] Read created SKILL.md and verify structure matches template
- [ ] Verify no "typst" references remain (should be all "nix")
- [ ] Verify agent name matches exactly: "nix-implementation-agent"
- [ ] Verify delegation path: ["orchestrator", "implement", "skill-nix-implementation"]
- [ ] Confirm CLAUDE.md already has mapping (no changes needed)
- [ ] Create implementation summary

**Timing**: 15 minutes

**Files to verify**:
- `.claude/skills/skill-nix-implementation/SKILL.md`
- `.claude/CLAUDE.md` (read-only verification)

**Verification**:
- No leftover typst references
- Agent name matches existing agent file
- Skill follows established pattern

---

## Testing & Validation

- [ ] SKILL.md file exists at `.claude/skills/skill-nix-implementation/SKILL.md`
- [ ] Frontmatter contains name: skill-nix-implementation
- [ ] Language validation is "nix" (not "typst")
- [ ] Subagent type is "nix-implementation-agent"
- [ ] No references to "typst" remain in the file
- [ ] All 8 execution stages are present
- [ ] Context references include jq-escaping-workarounds.md

## Artifacts & Outputs

- `.claude/skills/skill-nix-implementation/SKILL.md` - Main skill definition
- `specs/10_create_skill_nix_implementation/summaries/implementation-summary-{DATE}.md` - Completion summary

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/skills/skill-nix-implementation/` directory
2. No state.json or TODO.md changes needed (skill file is standalone)
3. No CLAUDE.md changes needed (mapping pre-exists)
