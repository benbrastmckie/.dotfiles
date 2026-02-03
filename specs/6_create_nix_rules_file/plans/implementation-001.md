# Implementation Plan: Task #6

- **Task**: 6 - Create Nix rules file
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/6_create_nix_rules_file/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create `.claude/rules/nix.md` with Nix-specific development rules auto-applied to `*.nix` files. The rules will cover RFC 166/nixfmt formatting standards, NixOS module structure, flake conventions, naming conventions, and common anti-patterns. Research findings provide comprehensive content; implementation is primarily synthesis and formatting to match existing rules file conventions.

### Research Integration

Research report analyzed:
- 5 existing rules files for structure patterns
- RFC 166/nixfmt formatting standards
- 19 repository `.nix` files for local patterns
- NixOS module and flake best practices
- Common anti-patterns to avoid

## Goals & Non-Goals

**Goals**:
- Create `.claude/rules/nix.md` with YAML frontmatter for auto-application on `**/*.nix`
- Include formatting standards (2-space indent, 100-char soft limit)
- Document module patterns (NixOS, Home Manager)
- Document flake conventions (input follows, output schema)
- Include "Do Not" section with common anti-patterns
- Reference existing Nix context files via @-references

**Non-Goals**:
- Creating additional Nix context files (already exist)
- Modifying existing `.nix` files to comply with rules
- Creating test files or verification scripts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rules too verbose | M | M | Follow neovim-lua.md brevity pattern |
| Missing key patterns | L | L | Research is comprehensive; use as source of truth |
| Path pattern conflicts | L | L | Use simple `**/*.nix` pattern |

## Implementation Phases

### Phase 1: Create nix.md Rules File [COMPLETED]

**Goal**: Create the complete `.claude/rules/nix.md` file with all sections

**Tasks**:
- [ ] Create `.claude/rules/nix.md` with YAML frontmatter (`paths: ["**/*.nix"]`)
- [ ] Add Path Pattern section
- [ ] Add Formatting Standards section (indentation, line length, nixfmt compliance)
- [ ] Add Module Patterns section (NixOS modules, Home Manager modules, function signatures)
- [ ] Add Flake Conventions section (input patterns, output schema, overlays)
- [ ] Add Naming Conventions section (packages, options, variables, overlay variables)
- [ ] Add Common Patterns section (conditional configuration, let bindings)
- [ ] Add Testing and Verification section (build commands)
- [ ] Add Do Not section (anti-patterns from research)
- [ ] Add Related Context section with @-references to Nix context files

**Timing**: 45 minutes

**Files to modify**:
- `.claude/rules/nix.md` - Create new file

**Verification**:
- File exists at `.claude/rules/nix.md`
- YAML frontmatter contains `paths: ["**/*.nix"]`
- All 9 main sections present
- Code examples included for each pattern
- @-references point to existing context files

---

### Phase 2: Verify and Update CLAUDE.md [COMPLETED]

**Goal**: Verify rules file integration and update CLAUDE.md if needed

**Tasks**:
- [ ] Verify nix.md structure matches neovim-lua.md conventions
- [ ] Verify all @-references in Related Context section point to existing files
- [ ] Check if CLAUDE.md Rules References section needs updating (add nix.md entry)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Add nix.md to Rules References section (if not already present)

**Verification**:
- nix.md follows same structure as neovim-lua.md
- All @-referenced files exist
- CLAUDE.md includes nix.md in Rules References

---

## Testing & Validation

- [ ] `.claude/rules/nix.md` exists and is non-empty
- [ ] YAML frontmatter is valid and contains correct path pattern
- [ ] All code examples use proper Nix syntax
- [ ] All @-references resolve to existing context files
- [ ] CLAUDE.md updated with nix.md reference

## Artifacts & Outputs

- `.claude/rules/nix.md` - Primary deliverable
- `.claude/CLAUDE.md` - Updated Rules References section (if needed)
- `specs/6_create_nix_rules_file/summaries/implementation-summary-20260203.md` - Implementation summary

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/rules/nix.md` if created
2. Revert any CLAUDE.md changes via git
3. Task remains at [PLANNED] status for retry
