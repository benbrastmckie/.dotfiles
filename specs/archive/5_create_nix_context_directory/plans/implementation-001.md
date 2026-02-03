# Implementation Plan: Task #5

- **Task**: 5 - create_nix_context_directory
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None (parallel with task 4)
- **Research Inputs**: specs/5_create_nix_context_directory/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create comprehensive Nix context directory at `.claude/context/project/nix/` mirroring the neovim context structure. The directory will contain 11 markdown files covering Nix language fundamentals, flakes, NixOS modules, home-manager, overlay patterns, derivation patterns, style guide, and tool guides. Content will be concise and example-heavy, pulling examples from the repository's existing flake.nix, home.nix, and configuration.nix files.

### Research Integration

The research report (research-001.md) provides comprehensive coverage of:
- Nix language syntax (let, with, inherit, rec, functions)
- Flakes structure and output schema
- NixOS module system (options, config, mkIf, mkMerge, types)
- Home Manager patterns (programs, services, file management)
- Overlay patterns (final/prev, override, overrideAttrs)
- Derivation patterns (mkDerivation, wrapper scripts)
- Style guide (nixfmt, naming conventions, anti-patterns)
- Tool guides (nixos-rebuild, home-manager CLI)

## Goals & Non-Goals

**Goals**:
- Create 11 markdown files matching the target directory structure
- Use concise, example-heavy style consistent with neovim context
- Include examples from repository's actual Nix files (flake.nix, home.nix, configuration.nix)
- Make each file self-contained with cross-references to related files
- Follow neovim context patterns for structure and depth

**Non-Goals**:
- Comprehensive Nix documentation (focus on patterns used in this repo)
- Templates directory (not needed for initial context)
- Experimental or unstable Nix features
- Detailed coverage of nix-darwin (not used in this repo)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Content too verbose | M | M | Follow neovim context style: concise headers, code-heavy |
| Missing patterns | L | L | Focus on patterns in existing repo files; extend later as needed |
| Outdated Nix info | L | L | Document stable patterns, link to official docs |

## Implementation Phases

### Phase 1: Foundation - README and Domain Files [COMPLETED]

**Goal**: Create README.md and all 4 domain knowledge files

**Tasks**:
- [ ] Create `.claude/context/project/nix/` directory structure
- [ ] Create `README.md` with overview, directory structure, loading strategy
- [ ] Create `domain/nix-language.md` covering let, with, inherit, rec, functions, types
- [ ] Create `domain/flakes.md` covering inputs, outputs, lock file, follows
- [ ] Create `domain/nixos-modules.md` covering options, config, mkOption, mkIf, types
- [ ] Create `domain/home-manager.md` covering programs, services, file management

**Timing**: 1 hour

**Files to create**:
- `.claude/context/project/nix/README.md`
- `.claude/context/project/nix/domain/nix-language.md`
- `.claude/context/project/nix/domain/flakes.md`
- `.claude/context/project/nix/domain/nixos-modules.md`
- `.claude/context/project/nix/domain/home-manager.md`

**Verification**:
- All 5 files exist and are non-empty
- README lists complete directory structure
- Each domain file has code examples

---

### Phase 2: Patterns [COMPLETED]

**Goal**: Create all 3 pattern files with implementation examples

**Tasks**:
- [ ] Create `patterns/module-patterns.md` covering enable pattern, submodule pattern, conditional config
- [ ] Create `patterns/overlay-patterns.md` covering final/prev, override, overrideAttrs, add package
- [ ] Create `patterns/derivation-patterns.md` covering mkDerivation, wrapper scripts, build phases

**Timing**: 45 minutes

**Files to create**:
- `.claude/context/project/nix/patterns/module-patterns.md`
- `.claude/context/project/nix/patterns/overlay-patterns.md`
- `.claude/context/project/nix/patterns/derivation-patterns.md`

**Verification**:
- All 3 files exist with code examples
- Examples reference or mirror patterns from repo's Nix files
- Cross-references to domain files included

---

### Phase 3: Standards [COMPLETED]

**Goal**: Create style guide with formatting and naming conventions

**Tasks**:
- [ ] Create `standards/nix-style-guide.md` covering nixfmt, indentation, naming, anti-patterns

**Timing**: 20 minutes

**Files to create**:
- `.claude/context/project/nix/standards/nix-style-guide.md`

**Verification**:
- File covers nixfmt as official formatter
- Naming conventions documented
- Anti-patterns listed (with, rec misuse)

---

### Phase 4: Tools and Verification [COMPLETED]

**Goal**: Create tool guides and verify complete implementation

**Tasks**:
- [ ] Create `tools/nixos-rebuild-guide.md` covering switch, boot, test, build, rollback
- [ ] Create `tools/home-manager-guide.md` covering switch, build, generations, news
- [ ] Verify all 11 files exist and have appropriate content
- [ ] Update CLAUDE.md Context Imports section with new nix context paths

**Timing**: 25 minutes

**Files to create**:
- `.claude/context/project/nix/tools/nixos-rebuild-guide.md`
- `.claude/context/project/nix/tools/home-manager-guide.md`

**Files to modify**:
- `.claude/CLAUDE.md` - Add nix context references to Context Imports section

**Verification**:
- All 11 files exist in correct locations
- Each file follows the concise, example-heavy style
- CLAUDE.md updated with nix context paths
- File count: 1 README + 4 domain + 3 patterns + 1 standards + 2 tools = 11

## Testing & Validation

- [ ] All 11 markdown files exist in `.claude/context/project/nix/`
- [ ] README.md accurately reflects directory contents
- [ ] Each file has at least one code example
- [ ] Cross-references between files are valid
- [ ] Style matches existing neovim context files (concise, example-heavy)
- [ ] CLAUDE.md Context Imports section updated

## Artifacts & Outputs

- `specs/5_create_nix_context_directory/plans/implementation-001.md` (this file)
- `specs/5_create_nix_context_directory/summaries/implementation-summary-{DATE}.md` (after completion)
- `.claude/context/project/nix/` directory with 11 markdown files

## Rollback/Contingency

If implementation fails:
1. Delete the `.claude/context/project/nix/` directory
2. Revert CLAUDE.md changes via git
3. Task remains in [PLANNED] status for retry
