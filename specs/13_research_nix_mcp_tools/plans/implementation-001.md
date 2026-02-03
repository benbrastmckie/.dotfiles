# Implementation Plan: Task #13

- **Task**: 13 - research_nix_mcp_tools
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: Task 7 (nix-research-agent - implemented)
- **Research Inputs**: specs/13_research_nix_mcp_tools/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Upgrade the nix-research-agent (created in task 7) with MCP-NixOS integration for enhanced package search, option lookup, and documentation access. The implementation follows the pattern established in task 8's nix-implementation-agent upgrade (implementation-002.md), adding MCP tool references with graceful degradation so the agent works standalone but benefits significantly when MCP-NixOS is available.

### Research Integration

From research-001.md:
- **MCP-NixOS** is the recommended primary enhancement (production-ready, 130K+ packages, 23K+ NixOS options, 5K+ Home Manager options)
- Tools: `mcp__nixos__nix(action, query, source, type, channel, limit)` and `mcp__nixos__nix_versions(package, version, limit)`
- Actions: search, info, stats, options, channels, flake-inputs, cache
- Sources: nixos, home-manager, darwin, flakes, flakehub, nixvim, noogle, wiki, nix-dev, nixhub
- Agent should work standalone with graceful degradation when MCP unavailable
- Consider nix-locate CLI wrapper as supplementary tool

## Goals & Non-Goals

**Goals**:
- Add MCP-NixOS tools to Allowed Tools section
- Update Research Strategy to prefer MCP queries over web search for package/option lookups
- Add MCP-NixOS Integration section with query patterns
- Implement graceful degradation pattern (agent works without MCP)
- Add MCP-related error handling

**Non-Goals**:
- Installing or configuring MCP-NixOS server (user responsibility)
- Creating custom MCP wrappers or tools
- Modifying other agents (nix-implementation-agent already has MCP integration)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| MCP tool names incorrect | Medium | Low | Verify against MCP-NixOS documentation and implementation-002.md pattern |
| Overcomplicating graceful degradation | Low | Medium | Follow implementation-002.md pattern exactly |
| Breaking existing agent functionality | Medium | Low | Preserve existing sections, add MCP as enhancement |
| Inconsistent with nix-implementation-agent | Medium | Low | Use implementation-002.md as direct template for MCP sections |

## Implementation Phases

### Phase 1: Update Allowed Tools Section [NOT STARTED]

**Goal**: Add MCP-NixOS tools to the agent's allowed tools list.

**Tasks**:
- [ ] Read current nix-research-agent.md structure
- [ ] Add new MCP Tools subsection under Allowed Tools
- [ ] Document `mcp__nixos__nix` tool with action types
- [ ] Document `mcp__nixos__nix_versions` tool
- [ ] Add note about MCP availability being optional

**Timing**: 25 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Add MCP Tools subsection

**Verification**:
- MCP tools listed in Allowed Tools section
- Tool descriptions match MCP-NixOS documentation
- Note clarifies MCP is optional enhancement

---

### Phase 2: Update Research Strategy Decision Tree [NOT STARTED]

**Goal**: Integrate MCP queries into the research strategy, prioritizing MCP for package/option lookups.

**Tasks**:
- [ ] Update Research Strategy Decision Tree to include MCP query options
- [ ] Add "MCP Available" decision branch at top of tree
- [ ] Update Search Priority list to prioritize MCP when available
- [ ] Ensure web search remains as fallback when MCP unavailable

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Update Research Strategy section

**Verification**:
- Decision tree includes MCP availability check
- MCP queries prioritized for package/option lookups
- Web search documented as fallback

---

### Phase 3: Add MCP-NixOS Integration Section [NOT STARTED]

**Goal**: Document comprehensive MCP-NixOS integration patterns with graceful degradation.

**Tasks**:
- [ ] Add new "MCP-NixOS Integration" section after Research Strategy
- [ ] Document MCP availability detection pattern
- [ ] Write MCP Query Patterns subsection:
  - [ ] Package search: `nix(action="search", query="packageName", source="nixpkgs")`
  - [ ] Package info: `nix(action="info", query="packageName", source="nixpkgs")`
  - [ ] NixOS options: `nix(action="options", query="services.x", source="nixos-options")`
  - [ ] Home Manager options: `nix(action="options", query="programs.x", source="home-manager")`
  - [ ] Function signatures: `nix(action="search", query="functionName", source="noogle")`
  - [ ] Version lookup: `nix_versions(package="packageName")`
- [ ] Write Graceful Degradation subsection:
  - [ ] MCP unavailable: Fall back to WebSearch and nix CLI
  - [ ] MCP timeout: Log warning, continue with web search
  - [ ] MCP error: Fall back to `nix search` command
- [ ] Write When to Use MCP subsection:
  - [ ] Package existence verification
  - [ ] Option path discovery
  - [ ] Function signature lookup
  - [ ] Version availability check

**Timing**: 40 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Add MCP-NixOS Integration section

**Verification**:
- MCP query patterns match implementation-002.md format
- Graceful degradation covers all failure modes
- Clear guidance on when to use MCP vs web search

---

### Phase 4: Update Error Handling and Critical Requirements [NOT STARTED]

**Goal**: Add MCP-related error handling and update critical requirements.

**Tasks**:
- [ ] Add MCP-Related Error Handling subsection to Error Handling section
  - [ ] MCP unavailable (not an error, just skip MCP queries)
  - [ ] MCP timeout (log and fall back)
  - [ ] Package not found in MCP (may exist in unstable, note in findings)
- [ ] Update Critical Requirements:
  - [ ] MUST DO: Use MCP for package/option validation when available
  - [ ] MUST DO: Log MCP unavailability as informational (not error)
  - [ ] MUST NOT: Fail research if MCP unavailable
  - [ ] MUST NOT: Skip web search entirely even when MCP available
- [ ] Add Nix-Specific Research Tips for MCP usage
- [ ] Verify consistency with nix-implementation-agent MCP patterns

**Timing**: 25 minutes

**Files to modify**:
- `.claude/agents/nix-research-agent.md` - Update Error Handling and Critical Requirements

**Verification**:
- Error handling patterns match implementation-002.md
- Critical requirements comprehensive for MCP usage
- Agent remains functional without MCP

## Testing & Validation

- [ ] Agent file maintains valid markdown structure
- [ ] MCP tool names match MCP-NixOS documentation (`mcp__nixos__nix`, `mcp__nixos__nix_versions`)
- [ ] Graceful degradation explicitly documented
- [ ] Decision tree includes MCP availability branch
- [ ] Error handling covers MCP-specific scenarios
- [ ] Critical requirements include MCP-specific entries
- [ ] Pattern consistency with nix-implementation-agent (implementation-002.md)
- [ ] Existing agent functionality preserved (Stage 0-7 flow unchanged)

## Artifacts & Outputs

- `.claude/agents/nix-research-agent.md` - Updated agent with MCP integration
- `specs/13_research_nix_mcp_tools/plans/implementation-001.md` - This plan
- `specs/13_research_nix_mcp_tools/summaries/implementation-summary-{DATE}.md` - Summary (created on completion)

## Rollback/Contingency

If implementation fails:
1. Revert `.claude/agents/nix-research-agent.md` using git
2. Preserve this plan for retry
3. Check task 7 completion for baseline agent state

If MCP integration is problematic:
1. MCP sections can be removed without affecting core agent functionality
2. Agent works standalone by design (graceful degradation)
3. Consider deferring MCP integration to follow-up task
