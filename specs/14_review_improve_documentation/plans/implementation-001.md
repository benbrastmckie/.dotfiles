# Implementation Plan: Task #14

- **Task**: 14 - review_improve_documentation
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/14_review_improve_documentation/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Systematic documentation improvement across .claude/ and docs/ directories, addressing findings from research report. Work focuses on three areas: (1) adding missing Nix context documentation, (2) fixing stale project references (ProofChecker, .opencode), and (3) consolidating duplicate documentation files. Research identified 19 files with ProofChecker references, 6 files with .opencode references, and significant documentation gaps for the Nix context directory.

### Research Integration

Key findings integrated from research-001.md:
- 11 Nix context files (2,496 lines) are undocumented in context/README.md and index.md
- 19 files contain "ProofChecker" references from different project
- 6 files contain ".opencode" references (deprecated name)
- 771+ lines of duplicate content in system-overview.md files
- 556 lines of overlapping documentation standards files

## Goals & Non-Goals

**Goals**:
- Add comprehensive Nix context documentation to context/README.md and context/index.md
- Replace all stale "ProofChecker" references with "NixOS dotfiles"
- Replace all ".opencode" references with ".claude"
- Consolidate duplicate system-overview.md files
- Consolidate overlapping documentation standards files
- Ensure consistent Nix file references between CLAUDE.md and rules/nix.md

**Non-Goals**:
- Rewriting content for style (only fixing accuracy)
- Adding new documentation topics not identified in research
- Restructuring the overall documentation hierarchy

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking cross-references | Medium | Low | Grep for file paths before removing/renaming files |
| Inconsistent replacements | Low | Medium | Use replace_all flag for consistent string replacement |
| Missing context in updates | Medium | Low | Read full file before editing to understand context |

## Implementation Phases

### Phase 1: Add Nix Context to Documentation [NOT STARTED]

**Goal**: Document the Nix context directory (11 files, 2,496 lines) in context/README.md and context/index.md

**Tasks**:
- [ ] Read current context/README.md to understand existing structure
- [ ] Add project/nix/ section to context/README.md with same format as other project directories
- [ ] Read current context/index.md to understand existing structure
- [ ] Add "Nix Context (project/nix/)" section to context/index.md mirroring Neovim Context format
- [ ] Add missing Nix files to CLAUDE.md (nix-style-guide.md, module-patterns.md)
- [ ] Verify rules/nix.md and CLAUDE.md now list consistent Nix files

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/README.md` - Add project/nix/ section
- `.claude/context/index.md` - Add Nix Context section
- `.claude/CLAUDE.md` - Add 2 missing Nix context files

**Verification**:
- Grep for "project/nix" in context/README.md returns section
- Grep for "Nix Context" in context/index.md returns section
- Nix file count in CLAUDE.md matches rules/nix.md

---

### Phase 2: Fix Stale ProofChecker References [NOT STARTED]

**Goal**: Replace "ProofChecker" references with "NixOS dotfiles" in all 19 affected files

**Tasks**:
- [ ] Process each file listed in research appendix:
  - .claude/docs/README.md
  - .claude/context/project/typst/patterns/cross-references.md
  - .claude/context/project/meta/interview-patterns.md
  - .claude/context/project/meta/meta-guide.md
  - .claude/context/project/meta/architecture-principles.md
  - .claude/context/project/hooks/wezterm-integration.md
  - .claude/context/core/templates/agent-template.md
  - .claude/context/core/standards/xml-structure.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/standards/git-safety.md
  - .claude/context/core/standards/error-handling.md
  - .claude/context/core/standards/documentation.md
  - .claude/context/core/standards/documentation-standards.md
  - .claude/context/core/orchestration/state-management.md
  - .claude/context/core/formats/command-structure.md
  - .claude/docs/templates/command-template.md
  - .claude/docs/templates/agent-template.md
  - .claude/docs/templates/README.md
  - .claude/docs/guides/user-guide.md
- [ ] Read each file and replace "ProofChecker" with appropriate text ("NixOS dotfiles" or remove if generic example)

**Timing**: 1 hour

**Files to modify**:
- 19 files listed above

**Verification**:
- Grep for "ProofChecker" returns 0 matches in .claude/ directory

---

### Phase 3: Fix Stale .opencode References [NOT STARTED]

**Goal**: Replace ".opencode" references with ".claude" in all 6 affected files

**Tasks**:
- [ ] Process each file listed in research appendix:
  - .claude/context/project/meta/meta-guide.md
  - .claude/context/project/meta/architecture-principles.md
  - .claude/context/core/standards/task-management.md
  - .claude/context/core/standards/documentation.md
  - .claude/docs/guides/creating-commands.md
  - .claude/docs/guides/context-loading-best-practices.md
- [ ] Read each file and replace ".opencode" with ".claude"

**Timing**: 30 minutes

**Files to modify**:
- 6 files listed above

**Verification**:
- Grep for "\.opencode" returns 0 matches in .claude/ directory

---

### Phase 4: Consolidate Duplicate Documentation [NOT STARTED]

**Goal**: Reduce redundancy in documentation by consolidating duplicate files

**Tasks**:
- [ ] Read .claude/docs/architecture/system-overview.md (281 lines)
- [ ] Read .claude/context/core/architecture/system-overview.md (490 lines)
- [ ] Replace docs version with brief summary linking to context version
- [ ] Read .claude/context/core/standards/documentation.md (315 lines)
- [ ] Read .claude/context/core/standards/documentation-standards.md (241 lines)
- [ ] Merge into single documentation-standards.md file
- [ ] Remove or redirect documentation.md to documentation-standards.md
- [ ] Update any cross-references to removed/redirected files

**Timing**: 1 hour

**Files to modify**:
- `.claude/docs/architecture/system-overview.md` - Replace with summary + link
- `.claude/context/core/standards/documentation.md` - Merge into documentation-standards.md
- `.claude/context/core/standards/documentation-standards.md` - Receive merged content

**Verification**:
- docs/architecture/system-overview.md is under 50 lines with link to full version
- Only one documentation standards file exists (or one redirects to the other)
- Grep for references to removed files returns 0 or shows proper redirects

---

### Phase 5: Clean Up Outdated Notes [NOT STARTED]

**Goal**: Remove outdated deprecation notes and verify documentation consistency

**Tasks**:
- [ ] Read context/index.md and identify outdated deprecation notes
- [ ] Remove references to files that were already removed
- [ ] Review .claude/README.md for contradictions with CLAUDE.md
- [ ] Fix any contradictions found
- [ ] Final verification grep for remaining issues

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/index.md` - Remove outdated deprecation notes
- `.claude/README.md` - Fix any contradictions with CLAUDE.md (if found)

**Verification**:
- context/index.md contains no references to non-existent files
- No contradictions between README.md and CLAUDE.md

## Testing & Validation

- [ ] Grep for "ProofChecker" returns 0 matches in .claude/
- [ ] Grep for "\.opencode" returns 0 matches in .claude/
- [ ] context/README.md contains project/nix/ section
- [ ] context/index.md contains Nix Context section
- [ ] CLAUDE.md lists all 11 Nix context files consistently with rules/nix.md
- [ ] No duplicate system-overview.md content (docs version is summary only)
- [ ] Single consolidated documentation standards file

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-20260203.md (upon completion)

## Rollback/Contingency

If changes introduce issues:
1. Git revert individual phase commits
2. Each phase commits separately allowing granular rollback
3. Original file content preserved in git history
