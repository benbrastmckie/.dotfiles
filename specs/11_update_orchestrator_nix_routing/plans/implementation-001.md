# Implementation Plan: Task #11

- **Task**: 11 - update_orchestrator_nix_routing
- **Status**: [NOT STARTED]
- **Effort**: 0.25 hours
- **Dependencies**: Tasks 9 (skill-nix-research) and 10 (skill-nix-implementation) - COMPLETED
- **Research Inputs**: specs/11_update_orchestrator_nix_routing/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add nix language routing to skill-orchestrator by inserting one table row in the Language-Based Routing section. The nix-specific skills (skill-nix-research, skill-nix-implementation) already exist from tasks 9 and 10. CLAUDE.md already documents nix in both routing tables correctly. This is a minimal single-file change.

### Research Integration

- Confirmed skill-orchestrator SKILL.md is the only file requiring modification (lines 42-49)
- Verified skill-nix-research and skill-nix-implementation exist and follow neovim pattern
- Confirmed CLAUDE.md already has nix in both Language-Based Routing and Skill-to-Agent Mapping tables

## Goals & Non-Goals

**Goals**:
- Add nix row to skill-orchestrator routing table
- Position nix immediately after neovim (grouped with dedicated skill languages)
- Enable /research and /implement to route nix tasks correctly

**Non-Goals**:
- Modifying CLAUDE.md (already complete)
- Creating new skills or agents
- Changing routing logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Skill name typo | High | Low | Copy exact names from existing skill files |
| Markdown table formatting | Low | Low | Match existing row format exactly |

## Implementation Phases

### Phase 1: Add nix routing row [NOT STARTED]

**Goal**: Insert nix language row into skill-orchestrator routing table

**Tasks**:
- [ ] Edit `.claude/skills/skill-orchestrator/SKILL.md`
- [ ] Add row: `| nix | skill-nix-research | skill-nix-implementation |`
- [ ] Position row after neovim, before latex

**Timing**: 5 minutes

**Files to modify**:
- `.claude/skills/skill-orchestrator/SKILL.md` - Add nix row to table (after line 44)

**Verification**:
- Table contains 7 rows (neovim, nix, latex, typst, general, meta, markdown)
- nix row is positioned immediately after neovim row
- Skill names match exactly: skill-nix-research, skill-nix-implementation

---

## Testing & Validation

- [ ] Verify table has correct number of rows (7 languages)
- [ ] Verify nix row follows neovim row
- [ ] Verify skill names match existing skill directories

## Artifacts & Outputs

- `.claude/skills/skill-orchestrator/SKILL.md` (modified)
- `specs/11_update_orchestrator_nix_routing/summaries/implementation-summary-20260203.md`

## Rollback/Contingency

Revert single line addition from skill-orchestrator/SKILL.md. Since this is a single-row addition to a markdown table, rollback is trivial via git checkout.
