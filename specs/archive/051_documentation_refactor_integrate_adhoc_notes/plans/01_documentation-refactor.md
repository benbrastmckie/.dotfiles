# Implementation Plan: Documentation Refactor - Integrate Ad-hoc Notes

- **Task**: 51 - documentation_refactor_integrate_adhoc_notes
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/051_documentation_refactor_integrate_adhoc_notes/reports/01_documentation-analysis.md
- **Artifacts**: plans/01_documentation-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown

## Overview

Refactor the repository's documentation to eliminate redundancy and improve discoverability. The work addresses five problems identified by research: no dedicated Neovim documentation file exists, NOTES.md is a 141-line catch-all that duplicates content already in docs/, cross-references from nix files to docs/ are nearly absent, inline comment conventions are inconsistent, and no documentation convention exists for the repo. The plan follows the five prioritized research recommendations: create docs/neovim.md, dissolve NOTES.md, update cross-references across the codebase, establish an inline comment convention, and document that convention.

### Research Integration

Research report `01_documentation-analysis.md` provides a comprehensive analysis of 18 docs/ files, inline comment patterns in nix files, NOTES.md sections and their duplication status, and existing cross-reference patterns. All five recommendations from the research are integrated into this plan as implementation phases. The research also identifies compliance issues with documentation-standards.md (quick-reference sections in docs/niri.md and docs/terminal.md, emoji usage in multiple files) which are noted as out of scope for this task.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

ROADMAP.md exists but contains no relevant items (empty placeholder). No roadmap items to advance.

## Goals & Non-Goals

**Goals**:
- Create `docs/neovim.md` as the authoritative home for Neovim configuration documentation
- Dissolve `NOTES.md` by verifying all content is covered in `docs/` and deleting it
- Add cross-references from nix files to docs/ (home.nix neovim block, README indexes)
- Define and document a lightweight inline comment convention for nix files
- Clean up `docs/development.md` to remove Neovim content already migrated to `docs/neovim.md`

**Non-Goals**:
- Fixing documentation-standards.md compliance issues (emoji usage, quick-reference sections in docs/niri.md or docs/terminal.md)
- Documenting activation script patterns (deferred to future task)
- Power management documentation (deferred to task 52)
- Adding or modifying any `.opencode/` context documentation
- Touching `specs/` task artifacts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting NOTES.md breaks a reference not found by grep | Medium | Low | Grep for `NOTES.md` across entire repo before deletion; only `docs/development.md:98` currently known |
| New docs/neovim.md diverges from actual config over time | Low | Medium | Focus docs/neovim.md on rationale and gotchas, not config values; cross-reference home.nix as source of truth |
| Cross-reference convention adds maintenance burden | Low | Low | Convention is opt-in; only add cross-references for decisions/gotchas that genuinely benefit from docs/ context |
| Merge conflicts if home.nix is being edited concurrently | Medium | Low | Phase 3 modifies only 1-2 comment lines in home.nix; narrow edit scope minimizes risk |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 5 | 1, 4 |
| 3 | 3 | 1, 2, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Create docs/neovim.md [COMPLETED]

**Goal**: Create a new `docs/neovim.md` as the authoritative documentation file for the Neovim configuration, consolidating content currently scattered across NOTES.md, home.nix inline comments, and docs/development.md.

**Tasks**:
- [ ] Read the Neovim section from NOTES.md (lines 94-121) for source content
- [ ] Read the programs.neovim block from home.nix (lines 24-45) for context on package, extraPackages, and sideloadInitLua
- [ ] Read docs/development.md for any Neovim-related content to migrate
- [ ] Write docs/neovim.md covering: why programs.neovim.enable is kept (provider wrapping, extraPackages), the sideloadInitLua gotcha and fix with full context, relationship between home-manager neovim module and standalone ~/.config/nvim/ config, package choice (neovim-unwrapped from unstable), extraPackages rationale, and reference to the separate nvim config repo
- [ ] Verify the file meets documentation standards: present tense, no emojis, ATX headings, code blocks with language specifier, max 100 chars/line

**Timing**: 1.5 hours

**Depends on**: none

**Files to create**:
- `docs/neovim.md` - New file with Neovim configuration documentation

**Verification**:
- `docs/neovim.md` exists and is non-empty
- File covers: program enable rationale, sideloadInitLua gotcha, package choice, extraPackages, standalone config relationship
- File follows documentation-standards.md formatting rules
- No content is copy-pasted verbatim from NOTES.md without adaptation

---

### Phase 2: Dissolve NOTES.md [COMPLETED]

**Goal**: Verify all content in NOTES.md is covered by existing docs/ files and the new docs/neovim.md, then delete NOTES.md or replace it with a redirect.

**Tasks**:
- [ ] For each of the 6 sections in NOTES.md, verify the destination file already covers the content (using research report's duplication table as guide)
- [ ] Verify no new references to NOTES.md were added since the research report was written
- [ ] If the secrets-management quick-reference snippet (lines 135-138) provides unique value not in docs/discord-bot.md, move it there as a brief subsection
- [ ] Delete NOTES.md
- [ ] Remove the reference to NOTES.md at docs/development.md line 98

**Timing**: 0.5 hours

**Depends on**: 1

**Files to delete**:
- `NOTES.md` - Redundant catch-all documentation file

**Files to modify**:
- `docs/development.md` - Remove reference to NOTES.md

**Verification**:
- `NOTES.md` no longer exists in the repository
- `grep -r "NOTES.md"` returns no results (or only results in specs/ and .opencode/)
- All content from NOTES.md sections is verifiably present in destination docs/ files

---

### Phase 3: Update Cross-References [COMPLETED]

**Goal**: Wire the new docs/neovim.md into the repository's navigation structure and add cross-references from nix files to docs/.

**Tasks**:
- [ ] Add `docs/neovim.md` entry to `docs/README.md` index under an appropriate category
- [ ] Add `docs/neovim.md` reference to root `README.md` in the "Documentation" or relevant section
- [ ] Update the sideloadInitLua inline comment in home.nix to include a `# See docs/neovim.md.` cross-reference trailer (applying the convention from Phase 4)
- [ ] Review `docs/development.md` for Neovim-related content that should link to `docs/neovim.md` instead of duplicating it; replace with a brief link
- [ ] Verify all cross-references resolve to existing files

**Timing**: 1 hour

**Depends on**: 1, 2, 4

**Files to modify**:
- `docs/README.md` - Add neovim.md to index
- `README.md` - Add neovim.md reference
- `home.nix` - Add cross-reference to sideloadInitLua comment block
- `docs/development.md` - Replace Neovim content with link to docs/neovim.md

**Verification**:
- `docs/README.md` includes an entry for `docs/neovim.md`
- `README.md` references `docs/neovim.md`
- `home.nix` neovim block has a `# See docs/neovim.md.` comment
- All referenced file paths resolve (no broken links)
- No stale Neovim content remains in docs/development.md that duplicates docs/neovim.md

---

### Phase 4: Establish Inline Comment Convention [COMPLETED]

**Goal**: Define a lightweight, consistent convention for inline comments in nix files, including cross-reference patterns and severity levels.

**Tasks**:
- [ ] Review existing comment patterns documented in the research report for baseline
- [ ] Define the convention: use `# Note:` for implementation notes, `# Critical:` for must-know warnings, no ALL_CAPS variants; keep inline comments to 1-4 lines explaining why (not what); standard cross-reference trailer as `# See docs/X.md.` for full context
- [ ] Write the convention specification into a brief section (to be placed by Phase 5)

**Timing**: 0.5 hours

**Depends on**: none

**Files to create**:
- None (convention text is prepared for Phase 5 to integrate)

**Verification**:
- Convention definition is complete and ready for integration
- Convention is concise (fits within a single short section)
- Convention addresses: comment style, cross-reference pattern, content guidelines (why not what)

---

### Phase 5: Document the Convention in docs/README.md [COMPLETED]

**Goal**: Add a "Documentation Conventions" section to docs/README.md that formalizes the inline comment convention and establishes docs/ as the authoritative home for configuration documentation.

**Tasks**:
- [ ] Read docs/README.md to identify the best insertion point for a "Documentation Conventions" section
- [ ] Add the section covering: the inline-comment-to-docs/ cross-reference pattern (from Phase 4), how to decide what goes inline vs. docs/, how to add new docs/ files, and the prohibition on NOTES.md as a staging area
- [ ] Ensure the new section follows documentation-standards.md (present tense, no emojis, max 100 chars/line, ATX headings)

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `docs/README.md` - Add Documentation Conventions section

**Verification**:
- `docs/README.md` contains a "Documentation Conventions" section
- Section defines: inline comment style, cross-reference pattern, inline vs. docs/ criteria, no-NOTES.md rule
- Section follows documentation-standards.md formatting

## Testing & Validation

- [ ] `grep -r "NOTES.md" --include="*.md" --include="*.nix" . | grep -v specs/ | grep -v ".opencode/"` returns no results
- [ ] `ls docs/neovim.md` confirms file exists
- [ ] `grep "docs/neovim.md" docs/README.md README.md home.nix` returns at least 3 matches
- [ ] All markdown cross-reference links resolve to existing files (manually review)
- [ ] docs/README.md contains a "Documentation Conventions" section
- [ ] No broken internal links introduced by the refactor

## Artifacts & Outputs

- `docs/neovim.md` - New Neovim configuration documentation
- `plans/01_documentation-refactor.md` - This plan file
- Modified: `docs/README.md` (cross-reference entry + conventions section)
- Modified: `README.md` (neovim.md reference)
- Modified: `home.nix` (cross-reference comment on sideloadInitLua)
- Modified: `docs/development.md` (removed NOTES.md reference, replaced Neovim content with link)
- Deleted: `NOTES.md`

## Rollback/Contingency

If the refactor introduces broken links or removes needed content:
1. Restore `NOTES.md` from git: `git checkout NOTES.md`
2. Revert `docs/development.md` changes: `git checkout docs/development.md`
3. Optionally keep `docs/neovim.md` (it is net-new and non-destructive) or remove it: `rm docs/neovim.md`
4. Revert `docs/README.md`, `README.md`, and `home.nix` changes individually via `git checkout`
5. Each phase produces independent changes that can be reverted without affecting others
