# Research Report: Task #11

**Task**: 11 - update_orchestrator_nix_routing
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:05:00Z
**Effort**: Small (< 1 hour implementation)
**Dependencies**: Tasks 9 (skill-nix-research) and 10 (skill-nix-implementation) - COMPLETED
**Sources/Inputs**: Codebase exploration (skill-orchestrator, nix skills, neovim skills, CLAUDE.md)
**Artifacts**: specs/11_update_orchestrator_nix_routing/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The skill-orchestrator currently routes 6 languages but is missing `nix` routing
- Nix-specific skills (skill-nix-research, skill-nix-implementation) already exist and are properly documented in CLAUDE.md's Skill-to-Agent Mapping table
- Only the skill-orchestrator's Language-Based Routing table needs updating (lines 40-49 in SKILL.md)
- This is a minimal change: add one row to the routing table

## Context & Scope

**Objective**: Update skill-orchestrator to route `language='nix'` tasks to nix-specific skills for research and implementation operations.

**Current State**:
- Tasks 9 and 10 created skill-nix-research and skill-nix-implementation
- CLAUDE.md already documents the skill-to-agent mapping correctly
- CLAUDE.md already documents nix in the Language-Based Routing table (tools section)
- skill-orchestrator's routing table is missing the nix entry

## Findings

### 1. Skill-Orchestrator Structure

**File**: `.claude/skills/skill-orchestrator/SKILL.md`

The orchestrator contains a **Language-Based Routing** table (lines 40-49) that maps task languages to research and implementation skills:

```markdown
| Language | Research Skill | Implementation Skill |
|----------|---------------|---------------------|
| neovim | skill-neovim-research | skill-neovim-implementation |
| latex | skill-researcher | skill-latex-implementation |
| typst | skill-researcher | skill-typst-implementation |
| general | skill-researcher | skill-implementer |
| meta | skill-researcher | skill-implementer |
| markdown | skill-researcher | skill-implementer |
```

**Observation**: The `nix` language is NOT present in this table. This is the primary gap.

### 2. Existing Nix Skills (Tasks 9, 10)

**skill-nix-research** (`.claude/skills/skill-nix-research/SKILL.md`):
- Trigger condition: `Task language is "nix"`
- Delegates to: `nix-research-agent`
- Pattern: Thin wrapper with skill-internal postflight (same as neovim skills)

**skill-nix-implementation** (`.claude/skills/skill-nix-implementation/SKILL.md`):
- Trigger condition: `Task language is "nix"`
- Delegates to: `nix-implementation-agent`
- Pattern: Thin wrapper with skill-internal postflight (same as neovim skills)

Both skills follow the established pattern used by neovim-research and neovim-implementation skills.

### 3. CLAUDE.md Current State

**Language-Based Routing Table** (lines 52-62):
```markdown
| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `neovim` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (nvim --headless) |
| `nix` | WebSearch, WebFetch, Read, MCP-NixOS | Read, Write, Edit, Bash (nix flake check, nixos-rebuild), MCP-NixOS |
| ...
```

This table documents **tools available to agents**, not skill routing. Nix is already documented here correctly.

**Skill-to-Agent Mapping Table** (lines 126-143):
```markdown
| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | Neovim/plugin research |
| skill-neovim-implementation | neovim-implementation-agent | Neovim configuration implementation |
| skill-nix-research | nix-research-agent | Nix/NixOS/Home Manager research |
| skill-nix-implementation | nix-implementation-agent | Nix configuration implementation |
| ...
```

This table is already complete - nix skills are documented.

### 4. Pattern Analysis: Neovim as Reference

The neovim language routing pattern is identical to what nix needs:

| Aspect | Neovim | Nix (to add) |
|--------|--------|--------------|
| Research Skill | skill-neovim-research | skill-nix-research |
| Implementation Skill | skill-neovim-implementation | skill-nix-implementation |
| Research Agent | neovim-research-agent | nix-research-agent |
| Implementation Agent | nix-implementation-agent | nix-implementation-agent |

### 5. Required Change

**Single Change Required**: Add nix row to skill-orchestrator routing table.

**Location**: `.claude/skills/skill-orchestrator/SKILL.md`, lines 40-49

**Current Table**:
```markdown
| Language | Research Skill | Implementation Skill |
|----------|---------------|---------------------|
| neovim | skill-neovim-research | skill-neovim-implementation |
| latex | skill-researcher | skill-latex-implementation |
| typst | skill-researcher | skill-typst-implementation |
| general | skill-researcher | skill-implementer |
| meta | skill-researcher | skill-implementer |
| markdown | skill-researcher | skill-implementer |
```

**After Adding Nix**:
```markdown
| Language | Research Skill | Implementation Skill |
|----------|---------------|---------------------|
| neovim | skill-neovim-research | skill-neovim-implementation |
| nix | skill-nix-research | skill-nix-implementation |
| latex | skill-researcher | skill-latex-implementation |
| typst | skill-researcher | skill-typst-implementation |
| general | skill-researcher | skill-implementer |
| meta | skill-researcher | skill-implementer |
| markdown | skill-researcher | skill-implementer |
```

**Rationale for Position**: Place nix immediately after neovim since both are language-specific skills with dedicated research and implementation agents (unlike latex/typst which use generic skill-researcher).

## Decisions

1. **Single file change**: Only skill-orchestrator/SKILL.md needs modification
2. **CLAUDE.md unchanged**: Both routing tables in CLAUDE.md are already correct
3. **Row placement**: Add nix row after neovim (grouped with dedicated skill languages)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Orchestrator doesn't read updated table | Low | Medium | Manual testing with nix task |
| Skill name typo | Low | High | Copy exact names from existing skill files |
| Missing documentation update | Low | Low | CLAUDE.md already complete |

## Implementation Recommendation

This is a **trivial implementation**:
1. Single edit to add one markdown table row
2. No code changes required
3. No validation/verification commands needed (markdown only)
4. Estimated time: < 5 minutes

The planner may choose to skip the planning phase and proceed directly to implementation given the simplicity.

## Appendix

### Files Examined

1. `.claude/skills/skill-orchestrator/SKILL.md` - Primary target for change
2. `.claude/skills/skill-nix-research/SKILL.md` - Verified skill exists and name
3. `.claude/skills/skill-nix-implementation/SKILL.md` - Verified skill exists and name
4. `.claude/skills/skill-neovim-research/SKILL.md` - Reference pattern
5. `.claude/skills/skill-neovim-implementation/SKILL.md` - Reference pattern
6. `.claude/skills/skill-researcher/SKILL.md` - Contrast with generic skill
7. `.claude/CLAUDE.md` - Verified existing documentation
