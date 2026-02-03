# Implementation Plan: Task #2

- **Task**: 2 - update_readme_for_dotfiles
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/2_update_readme_for_dotfiles/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update .claude/README.md (1053 lines) to reflect NixOS dotfiles management context rather than Neovim-specific focus. The core architecture documentation (delegation safety, state management, orchestration) remains valid and will be preserved. Research identified 7 sections needing updates and 2 new sections to add, while 10 sections remain unchanged.

### Research Integration

Key findings from research-001.md:
- CLAUDE.md already updated for NixOS dotfiles (must align README.md)
- Preserve generic architecture patterns (delegation, state management, error handling)
- Add Nix-specific agents (nix-research-agent, nix-implementation-agent)
- Document NixOS workflows (flake updates, nixos-rebuild, Home Manager)
- Reference existing .claude/context/project/nix/ files rather than duplicating

## Goals & Non-Goals

**Goals**:
- Update System Overview to describe NixOS dotfiles management context
- Add nix language to Language Routing section
- Add Nix-specific subagents to Component Hierarchy
- Add new NixOS-Specific Workflows section
- Update Related Documentation paths to match actual structure
- Align README.md with existing CLAUDE.md structure

**Non-Goals**:
- Duplicating Nix documentation that exists in context files
- Rewriting generic architecture sections (delegation, state management)
- Changing the overall document structure
- Removing historical references (Task 191) that provide context

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing workflow documentation | Medium | Low | Preserve all generic patterns, only update domain-specific content |
| Inconsistency with CLAUDE.md | High | Medium | Cross-reference CLAUDE.md during each phase |
| Missing context references | Low | Low | Verify all referenced paths exist before finalizing |
| Document becoming too long | Low | Low | Reference context files rather than duplicating content |

## Implementation Phases

### Phase 1: Update System Overview and Purpose [COMPLETED]

**Goal**: Change the document's framing from Neovim-specific to NixOS dotfiles with multi-domain support

**Tasks**:
- [ ] Update System Overview section (lines 30-54) to describe NixOS dotfiles management
- [ ] Update Purpose and Goals section (lines 36-42) to include NixOS/Nix language support
- [ ] Keep clean-break rationale but frame generically (applies to any domain)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/README.md` - System Overview section (lines 30-54)

**Verification**:
- Overview mentions NixOS dotfiles management
- Purpose includes Nix language routing
- No Neovim-only framing remains in these sections

---

### Phase 2: Update Language Routing Section [COMPLETED]

**Goal**: Add nix language to routing logic and document Nix-specific integration

**Tasks**:
- [ ] Update routing logic example (lines 499-540) to include nix language
- [ ] Add nix routing pattern (nix-research-agent, nix-implementation-agent)
- [ ] Update future language support section to remove nix (now present)
- [ ] Add NixOS-specific verification commands (nix flake check, nixos-rebuild)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/README.md` - Language Routing section (lines 499-540)

**Verification**:
- Routing logic shows nix → nix-research-agent / nix-implementation-agent
- Nix verification commands documented
- Future language section reflects current state

---

### Phase 3: Update Component Hierarchy [COMPLETED]

**Goal**: Add Nix-specific subagents alongside Neovim-specific subagents

**Tasks**:
- [ ] Add "Nix-Specific Subagents" subsection after "Neovim-Specific Subagents" (lines 257-260)
- [ ] Include nix-research-agent and nix-implementation-agent descriptions
- [ ] Reference MCP-NixOS tool integration

**Timing**: 20 minutes

**Files to modify**:
- `.claude/README.md` - Component Hierarchy section (lines 249-279)

**Verification**:
- Nix-Specific Subagents section exists
- Both nix-research-agent and nix-implementation-agent described
- MCP-NixOS mentioned as tool integration

---

### Phase 4: Update Context Organization Section [COMPLETED]

**Goal**: Reflect that project context includes both Neovim and Nix domains

**Tasks**:
- [ ] Update Clean Context Organization section (lines 148-166)
- [ ] Add reference to project/nix/ directory
- [ ] Add reference to project/repo/ directory
- [ ] Update description to say project context includes multiple domains

**Timing**: 15 minutes

**Files to modify**:
- `.claude/README.md` - Clean Context Organization section (lines 148-166)

**Verification**:
- project/nix/ directory referenced
- project/repo/ directory referenced
- Description mentions multi-domain support

---

### Phase 5: Add NixOS-Specific Workflows Section [COMPLETED]

**Goal**: Document NixOS-specific workflows and multi-host support

**Tasks**:
- [ ] Create new section after Language Routing (before Error Handling)
- [ ] Document flake updates (nix flake update)
- [ ] Document system rebuilds (nixos-rebuild switch --flake .#hostname)
- [ ] Document Home Manager updates (home-manager switch --flake .#benjamin)
- [ ] Document multi-host support (hosts/ directory, current hosts: nandi, hamsa, garuda, usb-installer)
- [ ] Document testing before applying (nixos-rebuild test)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/README.md` - New section after Language Routing

**Verification**:
- NixOS-Specific Workflows section exists
- All key workflows documented
- Multi-host support documented with actual host names

---

### Phase 6: Update Related Documentation and Skill Mapping [IN PROGRESS]

**Goal**: Update references and skill-to-agent mapping to match actual structure

**Tasks**:
- [ ] Update Skill-to-Agent Mapping section (around lines 905-913) to include nix skills
- [ ] Verify Related Documentation paths (lines 1044-1053) exist
- [ ] Remove or note non-existent paths
- [ ] Update Testing and Validation section (lines 602-643) with NixOS tests
- [ ] Update Table of Contents if new section added

**Timing**: 30 minutes

**Files to modify**:
- `.claude/README.md` - Multiple sections

**Verification**:
- Skill-to-Agent mapping includes nix-research and nix-implementation skills
- All Related Documentation paths verified
- Testing section includes NixOS verification commands
- Table of Contents accurate

## Testing & Validation

- [ ] All modified sections maintain valid markdown formatting
- [ ] Table of Contents accurately reflects section headings
- [ ] Cross-references between README.md and CLAUDE.md are consistent
- [ ] All referenced file paths exist in the repository
- [ ] No broken internal links within the document

## Artifacts & Outputs

- specs/2_update_readme_for_dotfiles/plans/implementation-001.md (this file)
- .claude/README.md (modified)
- specs/2_update_readme_for_dotfiles/summaries/implementation-summary-20260203.md (on completion)

## Rollback/Contingency

- Git history preserves original README.md
- If changes introduce errors, revert with: `git checkout HEAD~1 -- .claude/README.md`
- Phase-by-phase commits allow partial rollback if needed
