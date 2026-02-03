# Research Report: Task #10

**Task**: 10 - create_skill_nix_implementation
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:15:00Z
**Effort**: Low (template-based)
**Dependencies**: Task 8 (nix-implementation-agent) - COMPLETED
**Sources/Inputs**: Codebase analysis of existing skills and agents
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-nix-implementation should follow the established thin wrapper pattern used by skill-neovim-implementation, skill-latex-implementation, and skill-typst-implementation
- The skill delegates to nix-implementation-agent (created in task 8) via the Task tool
- Key differentiation: language validation for "nix" and Nix-specific context references (MCP-NixOS tools, nix flake check verification)
- Implementation is straightforward template adaptation with clear patterns from existing skills

## Context & Scope

### What Was Researched

1. Existing skill implementations to identify the standard pattern
2. The nix-implementation-agent that this skill will delegate to
3. Nix-specific context files and tools
4. Skill-to-agent mapping in CLAUDE.md

### Constraints

- Must follow the thin wrapper pattern (skill handles preflight/postflight, agent handles work)
- Must use Task tool (not Skill tool) to invoke the agent
- Must be consistent with existing implementation skills (latex, typst, neovim)
- Must validate language as "nix" before proceeding

## Findings

### 1. Established Skill Pattern

All implementation skills follow this 11-stage execution flow:

| Stage | Description |
|-------|-------------|
| 0. Preflight Status Update | Update state.json to "implementing", TODO.md to [IMPLEMENTING], create .postflight-pending marker |
| 1. Input Validation | Validate task_number exists, language matches, status allows implementation |
| 2. Context Preparation | Prepare delegation context JSON with session_id, task_context, plan_path |
| 3. Invoke Subagent | Use **Task** tool to spawn the implementation agent |
| 3a. Validate Return Format | Check if subagent accidentally returned JSON (v1 pattern warning) |
| 4. Parse Subagent Return | Read .return-meta.json file for status, artifacts, completion_data |
| 5. Postflight Status Update | Update state.json to "completed" (if implemented), TODO.md to [COMPLETED] |
| 6. Git Commit | Commit changes with session ID |
| 7. Cleanup | Remove .postflight-pending, .postflight-loop-guard, .return-meta.json |
| 8. Return Brief Summary | Return text summary (NOT JSON) |

### 2. nix-implementation-agent Capabilities

The target agent (from task 8) provides:

**Verification Commands**:
- `nix flake check` - Fast syntax and evaluation check (~10-30 seconds)
- `nix flake show` - Display flake outputs (~5-15 seconds)
- `nixos-rebuild build --flake .#hostname` - Build NixOS configuration (~1-10 minutes)
- `home-manager build --flake .#user` - Build Home Manager configuration (~30s-5 minutes)

**MCP Integration** (optional, graceful degradation):
- `mcp__nixos__nix` - Package/option search and validation
- `mcp__nixos__nix_versions` - Package version history lookup

**Context Files Loaded by Agent**:
- `.claude/context/project/nix/README.md`
- `.claude/context/project/nix/domain/nix-language.md`
- `.claude/context/project/nix/standards/nix-style-guide.md`
- `.claude/rules/nix.md`
- Task-specific context (modules, flakes, overlays, Home Manager)

### 3. Skill Configuration

**Frontmatter** (from template analysis):
```yaml
---
name: skill-nix-implementation
description: Implement Nix configuration changes from plans. Invoke for nix implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---
```

**Trigger Conditions**:
- Task language is "nix"
- /implement command targets a Nix task
- Implementation plan exists for the task

**Context References** (lazy-loaded):
- `.claude/context/core/formats/return-metadata-file.md`
- `.claude/context/core/patterns/postflight-control.md`
- `.claude/context/core/patterns/jq-escaping-workarounds.md`

### 4. Nix-Specific Considerations

**Language Validation**:
```bash
if [ "$language" != "nix" ]; then
  return error "Task $task_number is not a Nix task"
fi
```

**Delegation Path**:
```json
["orchestrator", "implement", "skill-nix-implementation"]
```

**Subagent Type**:
```
subagent_type: "nix-implementation-agent"
```

**Verification Awareness**:
The skill should be aware that Nix verification can be slow (builds may take 1-10 minutes). The subagent handles this, but the skill timeout should accommodate it.

### 5. Files to Create

| File | Purpose |
|------|---------|
| `.claude/skills/skill-nix-implementation/SKILL.md` | Main skill definition |

### 6. CLAUDE.md Entry Already Exists

The skill-to-agent mapping in CLAUDE.md already includes:
```
| skill-nix-implementation | nix-implementation-agent | Nix configuration implementation |
```

No CLAUDE.md update is needed.

### 7. Pattern Differences from Template

Compared to skill-neovim-implementation:

| Aspect | Neovim | Nix |
|--------|--------|-----|
| Language | `"neovim"` | `"nix"` |
| Agent | `neovim-implementation-agent` | `nix-implementation-agent` |
| Verification | `nvim --headless` | `nix flake check`, `nixos-rebuild build` |
| Context | Neovim API, plugin patterns | Nix language, flakes, modules |
| MCP Tools | None | mcp__nixos__nix (optional) |

## Decisions

1. **Template Choice**: Use skill-latex-implementation or skill-typst-implementation as the primary template (more recent, includes v2 patterns)
2. **Timeout**: Use default 3600s (1 hour) to accommodate long Nix builds
3. **MCP Handling**: The skill itself does not use MCP tools - that's the agent's responsibility

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Long verification times | Default 1-hour timeout; agent uses fast `nix flake check` first |
| MCP unavailability | Agent implements graceful degradation |
| Build failures | Agent marks as partial; skill keeps status as "implementing" for retry |

## Implementation Checklist

1. [ ] Create `.claude/skills/skill-nix-implementation/` directory
2. [ ] Create `SKILL.md` with frontmatter (name, description, allowed-tools)
3. [ ] Copy structure from skill-typst-implementation
4. [ ] Update language validation: "nix"
5. [ ] Update agent reference: "nix-implementation-agent"
6. [ ] Update skill name in markers and messages
7. [ ] Update delegation path references
8. [ ] Test invocation with a Nix task

## Appendix

### Search Queries Used

1. `Glob .claude/skills/**/*.md` - Found 14 skill files
2. `Glob .claude/agents/**/*.md` - Found 11 agent files
3. `Read skill-neovim-implementation/SKILL.md` - Primary implementation skill template
4. `Read nix-implementation-agent.md` - Target agent for delegation
5. `Read skill-typst-implementation/SKILL.md` - Recent implementation skill for reference
6. `Read skill-latex-implementation/SKILL.md` - Additional implementation skill reference

### Reference Files

- `/home/benjamin/.dotfiles/.claude/skills/skill-neovim-implementation/SKILL.md` - 244 lines
- `/home/benjamin/.dotfiles/.claude/skills/skill-typst-implementation/SKILL.md` - 377 lines
- `/home/benjamin/.dotfiles/.claude/skills/skill-latex-implementation/SKILL.md` - 377 lines
- `/home/benjamin/.dotfiles/.claude/agents/nix-implementation-agent.md` - 857 lines
- `/home/benjamin/.dotfiles/.claude/context/core/formats/return-metadata-file.md` - 503 lines
