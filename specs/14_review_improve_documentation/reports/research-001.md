# Research Report: Task #14

**Task**: 14 - review_improve_documentation
**Started**: 2026-02-03T12:00:00Z
**Completed**: 2026-02-03T12:45:00Z
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (.claude/ and docs/ directories)
**Artifacts**: This report at specs/14_review_improve_documentation/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- Inventoried 190+ markdown files in .claude/ and 17 files in docs/
- Identified 19 files with stale "ProofChecker" references (different project)
- Found 6 files with stale ".opencode" references (deprecated name)
- Discovered significant documentation redundancy (771+ lines in duplicate files)
- Nix context directory (2,496 lines, 11 files) is undocumented in context/README.md
- Nix context is well-structured and content quality is high, but loading guidance is inconsistent across referencing documents

## Context & Scope

This research systematically reviewed documentation in `.claude/` (190+ files) and `docs/` (17 files) to identify:
1. Documentation gaps and inconsistencies
2. Missing or broken cross-links
3. Nix context file quality and loading patterns
4. Redundancies that could be consolidated
5. Areas of excessive verbosity

---

## Findings

### 1. Stale Project References

**ProofChecker References (19 files)**:
Files reference "ProofChecker" which is a different project. These appear to be remnants from when the .claude/ system was shared between projects.

Affected files include:
- `.claude/docs/README.md` - Links to "ProofChecker README"
- `.claude/context/project/typst/patterns/cross-references.md`
- `.claude/context/project/meta/interview-patterns.md`
- `.claude/context/project/meta/meta-guide.md`
- `.claude/context/project/meta/architecture-principles.md`
- `.claude/context/core/standards/documentation.md`
- `.claude/context/core/standards/error-handling.md`
- `.claude/context/core/standards/status-markers.md`
- `.claude/docs/guides/user-guide.md`
- Plus 10 others

**Recommendation**: Update these to reference "NixOS dotfiles" or remove project-specific references entirely.

**.opencode References (6 files)**:
Files reference ".opencode" which was a previous name for the system:
- `.claude/context/project/meta/meta-guide.md`
- `.claude/context/project/meta/architecture-principles.md`
- `.claude/context/core/standards/task-management.md`
- `.claude/context/core/standards/documentation.md`
- `.claude/docs/guides/creating-commands.md`
- `.claude/docs/guides/context-loading-best-practices.md`

**Recommendation**: Replace ".opencode" with ".claude" throughout.

---

### 2. Documentation Redundancy

**system-overview.md Duplication (771 lines total)**:
Two files cover the same topic:
- `.claude/docs/architecture/system-overview.md` (281 lines)
- `.claude/context/core/architecture/system-overview.md` (490 lines)

Both describe the three-layer architecture. The context version is more detailed.

**Recommendation**: Consolidate into one file in `context/core/architecture/` and have docs version link to it.

**documentation.md Duplication (556 lines total)**:
Two files with similar names and overlapping content:
- `.claude/context/core/standards/documentation.md` (315 lines)
- `.claude/context/core/standards/documentation-standards.md` (241 lines)

The first covers documentation content standards; the second covers file naming conventions and README requirements. There is some overlap.

**Recommendation**: Merge into single `documentation-standards.md` file.

---

### 3. Nix Context File Analysis

**Content Quality Assessment**: HIGH

The 11 Nix context files (2,496 lines total) are well-structured:

| File | Lines | Quality | Notes |
|------|-------|---------|-------|
| domain/nix-language.md | 215 | Excellent | Concise syntax reference |
| domain/flakes.md | 239 | Excellent | Good real examples from this repo |
| domain/nixos-modules.md | 253 | Excellent | Clear with real mcp-hub example |
| domain/home-manager.md | 287 | Excellent | Comprehensive with dconf examples |
| patterns/overlay-patterns.md | 237 | Excellent | Real overlay examples from flake.nix |
| patterns/derivation-patterns.md | 282 | Excellent | Good buildGoModule examples |
| patterns/module-patterns.md | 239 | Excellent | Clear enable pattern examples |
| standards/nix-style-guide.md | 291 | Good | Could be slightly more concise |
| tools/nixos-rebuild-guide.md | 208 | Excellent | Clear command reference |
| tools/home-manager-guide.md | 245 | Excellent | Covers both installation modes |
| README.md | 94 | Good | Clear loading strategy |

**Loading Pattern Analysis**:

The Nix context files are referenced in:
1. **CLAUDE.md** (lines 165-172) - Lists 8 of 11 files as "load as needed"
2. **rules/nix.md** (lines 222-229) - Lists 8 files in "Related Context"
3. **agents/nix-research-agent.md** - Task-based loading guidance
4. **agents/nix-implementation-agent.md** - Task-based loading guidance
5. **skills/skill-nix-implementation/SKILL.md** - Lists all 11 files

**Issues Found**:
1. `context/README.md` does NOT list `project/nix/` at all - major documentation gap
2. `nix-style-guide.md` is not listed in CLAUDE.md but IS listed in rules/nix.md
3. `module-patterns.md` is only listed in rules/nix.md and agents, not CLAUDE.md
4. Loading guidance differs between CLAUDE.md and rules/nix.md

**Recommendation**:
1. Add `project/nix/` section to `context/README.md` (currently missing entirely)
2. Align CLAUDE.md and rules/nix.md to list the same files
3. Consider whether all 11 files need to be loaded for every Nix task, or if task-based loading from agents is sufficient

---

### 4. Missing Cross-Links

**context/README.md Gaps**:
The file documents structure but is missing:
- `project/nix/` directory entirely (11 files, 2,496 lines)
- Should include loading strategy similar to other project directories

**context/index.md Observations**:
At 550 lines, this is comprehensive but:
- Has no Nix context section (unlike Neovim, Typst)
- Contains outdated deprecation notes (deprecated files removed but notes remain)

**docs/README.md vs .claude/docs/README.md**:
Two README files exist with different purposes:
- `/docs/README.md` - NixOS dotfiles documentation hub (project docs)
- `/.claude/docs/README.md` - Claude agent system documentation hub

This is correct separation, but `.claude/docs/README.md` has stale ProofChecker links.

---

### 5. Verbosity Analysis

**Files That Could Be More Concise**:

| File | Lines | Issue |
|------|-------|-------|
| `.claude/README.md` | 1,300+ | Very comprehensive, but duplicates CLAUDE.md content |
| `.claude/context/index.md` | 550 | Contains outdated deprecation notes |
| `.claude/context/core/orchestration/architecture.md` | 750 | Could consolidate with system-overview.md |

**Nix Files - Appropriately Sized**:
The Nix context files are generally well-sized (200-290 lines each). The style guide at 291 lines has some examples that could be trimmed but is not excessively verbose.

---

## Recommendations

### High Priority

1. **Add Nix to context/README.md**
   - Add `project/nix/` section with same structure as neovim/latex/typst
   - Include loading strategy guidance

2. **Add Nix to context/index.md**
   - Create "Nix Context (project/nix/)" section
   - Mirror format of existing Neovim Context section

3. **Update stale project references**
   - Replace "ProofChecker" with "NixOS dotfiles" (19 files)
   - Replace ".opencode" with ".claude" (6 files)

### Medium Priority

4. **Consolidate duplicate system-overview.md**
   - Keep `context/core/architecture/system-overview.md` (490 lines, more complete)
   - Update `docs/architecture/system-overview.md` to be a brief summary with link

5. **Consolidate documentation standards files**
   - Merge `documentation.md` and `documentation-standards.md`

6. **Align Nix file references**
   - Add `nix-style-guide.md` and `module-patterns.md` to CLAUDE.md
   - Ensure consistent list between CLAUDE.md and rules/nix.md

### Low Priority

7. **Clean up context/index.md deprecation notes**
   - Remove references to files that were already removed

8. **Review .claude/README.md for duplication with CLAUDE.md**
   - CLAUDE.md is the minimal reference; README.md is comprehensive
   - Ensure they don't contradict each other

---

## Appendix

### Search Queries Used
- `Glob .claude/**/*.md` - 190 files found
- `Glob docs/**/*.md` - 17 files found
- `Grep @\.claude/context/project/nix` - Loading pattern analysis
- `Grep ProofChecker` - Stale reference detection (19 files)
- `Grep \.opencode` - Stale reference detection (6 files)
- `wc -l` on Nix context files - Size analysis

### Nix Context File Sizes (for reference)
```
  94 .claude/context/project/nix/README.md
 215 .claude/context/project/nix/domain/nix-language.md
 239 .claude/context/project/nix/domain/flakes.md
 253 .claude/context/project/nix/domain/nixos-modules.md
 287 .claude/context/project/nix/domain/home-manager.md
 237 .claude/context/project/nix/patterns/overlay-patterns.md
 282 .claude/context/project/nix/patterns/derivation-patterns.md
 239 .claude/context/project/nix/patterns/module-patterns.md
 291 .claude/context/project/nix/standards/nix-style-guide.md
 208 .claude/context/project/nix/tools/nixos-rebuild-guide.md
 245 .claude/context/project/nix/tools/home-manager-guide.md
2496 total
```

### Files With Stale References
**ProofChecker (19 files)**:
- `.claude/context/project/typst/patterns/cross-references.md`
- `.claude/context/project/meta/interview-patterns.md`
- `.claude/context/project/meta/meta-guide.md`
- `.claude/context/project/meta/architecture-principles.md`
- `.claude/context/project/hooks/wezterm-integration.md`
- `.claude/context/core/templates/agent-template.md`
- `.claude/context/core/standards/xml-structure.md`
- `.claude/context/core/standards/status-markers.md`
- `.claude/context/core/standards/git-safety.md`
- `.claude/context/core/standards/error-handling.md`
- `.claude/context/core/standards/documentation.md`
- `.claude/context/core/standards/documentation-standards.md`
- `.claude/context/core/orchestration/state-management.md`
- `.claude/context/core/formats/command-structure.md`
- `.claude/docs/templates/command-template.md`
- `.claude/docs/templates/agent-template.md`
- `.claude/docs/templates/README.md`
- `.claude/docs/guides/user-guide.md`
- `.claude/docs/README.md`

**.opencode (6 files)**:
- `.claude/context/project/meta/meta-guide.md`
- `.claude/context/project/meta/architecture-principles.md`
- `.claude/context/core/standards/task-management.md`
- `.claude/context/core/standards/documentation.md`
- `.claude/docs/guides/creating-commands.md`
- `.claude/docs/guides/context-loading-best-practices.md`
