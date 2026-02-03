# Research Report: Task #9

**Task**: 9 - Create skill-nix-research
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:05:00Z
**Effort**: Low (1-2 hours)
**Dependencies**: nix-research-agent.md (already exists)
**Sources/Inputs**: Codebase analysis of existing skill patterns
**Artifacts**: specs/9_create_skill_nix_research/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The skill-nix-research wrapper can be created by following the established pattern from skill-neovim-research and skill-researcher
- Key differences: language trigger is "nix", subagent is "nix-research-agent"
- The nix-research-agent already exists and implements MCP-NixOS integration with graceful degradation
- 11 execution stages are required: input validation, preflight status, marker creation, delegation context, subagent invocation, metadata parsing, status update, artifact linking, git commit, cleanup, return summary

## Context & Scope

This research analyzes the existing skill wrapper patterns to understand how to create skill-nix-research. The skill must:

1. Follow the thin wrapper pattern (preflight, delegate, postflight)
2. Delegate to nix-research-agent via Task tool
3. Handle metadata file exchange pattern
4. Implement skill-internal postflight (status update, artifact linking, git commit)

## Findings

### Existing Skill Patterns

Both skill-neovim-research and skill-researcher follow an identical 11-stage pattern:

| Stage | Purpose |
|-------|---------|
| 1 | Input validation (task number, focus prompt) |
| 2 | Preflight status update (set to "researching") |
| 3 | Create postflight marker (.postflight-pending) |
| 4 | Prepare delegation context JSON |
| 5 | Invoke subagent via Task tool |
| 6 | Parse subagent return (read metadata file) |
| 7 | Update task status (postflight) |
| 8 | Link artifacts to state.json |
| 9 | Git commit changes |
| 10 | Cleanup marker and metadata files |
| 11 | Return brief text summary |

### Skill YAML Frontmatter

```yaml
---
name: skill-nix-research
description: Conduct Nix/NixOS/Home Manager research using MCP-NixOS, web docs, and codebase exploration. Invoke for nix research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---
```

### Key Customizations for Nix

| Field | Value |
|-------|-------|
| Skill name | skill-nix-research |
| Trigger language | "nix" |
| Subagent | nix-research-agent |
| Description | Nix/NixOS/Home Manager research using MCP-NixOS |
| Delegation path | ["orchestrator", "research", "skill-nix-research"] |

### Nix-Research-Agent Features

The nix-research-agent (already exists) provides:

1. **MCP-NixOS Integration**:
   - Package search: `mcp__nixos__nix(action="search", query="pkgName", source="nixpkgs")`
   - Option lookup: `mcp__nixos__nix(action="options", query="services.X", source="nixos-options")`
   - Home Manager options: `mcp__nixos__nix(action="options", query="programs.X", source="home-manager")`
   - Function signatures: `mcp__nixos__nix(action="search", query="functionName", source="noogle")`
   - Version history: `mcp__nixos__nix_versions(package="pkgName")`

2. **Graceful Degradation**:
   - Falls back to WebSearch when MCP unavailable
   - Uses nix CLI (`nix search`, `nix eval`) as alternative
   - Logs MCP unavailability as informational (not error)

3. **Nix-Specific Search Strategy**:
   - Analyzes local *.nix files first
   - Checks flake.nix, configuration.nix, home.nix patterns
   - Searches NixOS Wiki and official documentation
   - Looks up package/module options

### Context References

The skill should reference (lazy load):

- `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema
- `.claude/context/core/patterns/postflight-control.md` - Marker file protocol
- `.claude/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns

### State.json Update Pattern

Uses the "| not" pattern to avoid jq Issue #1132:

```bash
# Step 1: Filter out existing research artifacts
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add new research artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### Return Format

Brief text summary (NOT JSON):

```
Research completed for task {N}:
- Analyzed existing Nix configuration patterns
- Documented available options from NixOS/Home Manager
- Created report at specs/{N}_{SLUG}/reports/research-{NNN}.md
- Status updated to [RESEARCHED]
- Changes committed
```

## Recommendations

### Implementation Approach

1. **Copy skill-neovim-research/SKILL.md as template** - It is the most similar pattern
2. **Modify YAML frontmatter** - Update name, description
3. **Change trigger condition** - Language "nix" instead of "neovim"
4. **Update subagent reference** - Use "nix-research-agent" in Task tool invocation
5. **Update delegation path** - ["orchestrator", "research", "skill-nix-research"]

### Directory Structure

```
.claude/skills/skill-nix-research/
  SKILL.md
```

### Validation Requirements

After creation, verify:
1. YAML frontmatter is valid
2. All 11 stages are present
3. Task tool invocation uses correct subagent
4. Error handling covers MCP failures (graceful degradation pattern)
5. jq commands use "| not" pattern (Issue #1132)

## Decisions

- Use skill-neovim-research as the template (closest pattern match)
- Keep allowed-tools identical: Task, Bash, Edit, Read, Write
- Include jq escaping workarounds reference in context

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| jq parse errors (Issue #1132) | Use "select(.type == X \| not)" pattern instead of "!=" |
| MCP-NixOS unavailable | Already handled by nix-research-agent graceful degradation |
| Metadata file not created by agent | Keep status as "researching", preserve postflight marker |

## Appendix

### Files Analyzed

1. `.claude/skills/skill-neovim-research/SKILL.md` - Primary template
2. `.claude/skills/skill-researcher/SKILL.md` - Secondary template
3. `.claude/agents/nix-research-agent.md` - Target subagent
4. `.claude/context/core/formats/return-metadata-file.md` - Metadata schema

### Existing Skill-to-Agent Mapping (from CLAUDE.md)

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | Neovim/plugin research |
| skill-nix-research | nix-research-agent | Nix/NixOS/Home Manager research |
| skill-researcher | general-research-agent | General web/codebase research |

The skill-nix-research entry already exists in the mapping table, confirming this skill is expected.
