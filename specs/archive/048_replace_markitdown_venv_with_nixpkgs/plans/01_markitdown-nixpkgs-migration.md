# Implementation Plan: Replace markitdown venv with nixpkgs package

- **Task**: 48 - Replace markitdown venv wrapper with nixpkgs python312Packages.markitdown
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_markitdown-nixpkgs-migration.md
- **Artifacts**: plans/01_markitdown-nixpkgs-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: true

## Overview

Migrate markitdown from a custom venv-based wrapper to the native nixpkgs package. The research confirmed `python312Packages.markitdown` exists in nixpkgs with all dependencies including PDF support. This change enables both CLI usage (`markitdown` command) and Python imports (`import markitdown`) from the system Python environment without venv management.

### Research Integration

- Report: `reports/01_markitdown-nixpkgs-migration.md`
- Key finding: `python312Packages.markitdown` v0.1.4 available with `pdfminer-six` dependency
- Verified: Both CLI and import work via `python312.withPackages`

## Goals & Non-Goals

**Goals**:
- Enable `import markitdown` from system Python
- Maintain CLI functionality (`markitdown` command)
- Remove pip/venv management overhead
- Simplify configuration to declarative Nix pattern

**Non-Goals**:
- Feature parity with markitdown v0.1.5 (minor patch difference acceptable)
- Backporting additional optional dependencies beyond PDF support

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing optional dependencies | L | L | nixpkgs package includes pdfminer-six; add more if needed later |
| Version difference (0.1.4 vs 0.1.5) | L | M | Minor patch; nixpkgs will update |
| Rebuild failure | M | L | Rollback by reverting git changes |

## Implementation Phases

### Phase 1: Configuration Changes [COMPLETED]

**Goal**: Migrate markitdown from overlay to python312.withPackages

**Tasks**:
- [ ] Add `markitdown` to `python312.withPackages` block in `home.nix` (around line 330)
- [ ] Remove `markitdown` from standalone `home.packages` list in `home.nix` (line 175)
- [ ] Remove `markitdown = final.callPackage ./packages/markitdown.nix {};` from `flake.nix` overlay (line 89)
- [ ] Delete `packages/markitdown.nix` file
- [ ] Update `packages/README.md` to remove markitdown.nix documentation (two duplicate sections exist)

**Timing**: 15 minutes

**Files to modify**:
- `home.nix` - Add to withPackages, remove from packages list
- `flake.nix` - Remove overlay entry
- `packages/markitdown.nix` - Delete
- `packages/README.md` - Remove markitdown.nix sections

**Verification**:
- `nix-instantiate --parse ~/.dotfiles/home.nix` - Syntax check
- `nix flake check` - Flake evaluation

---

### Phase 2: Build and Verification [COMPLETED]

**Goal**: Verify the migration works correctly

**Tasks**:
- [ ] Run `home-manager build --flake ~/.dotfiles#benjamin` to verify build succeeds
- [ ] Run `home-manager switch --flake ~/.dotfiles#benjamin` (user-executed)
- [ ] Verify CLI: `markitdown --help`
- [ ] Verify import: `python3 -c "import markitdown; print(markitdown.__version__)"`
- [ ] Clean up old venv: `rm -rf ~/.local/share/markitdown-venv/`

**Timing**: 15 minutes

**Files to modify**: None (verification only)

**Verification**:
- Build completes without errors
- CLI command works
- Python import succeeds
- Version output shows 0.1.4 (or later)

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `home-manager build` succeeds
- [ ] `markitdown --help` shows usage
- [ ] `python3 -c "import markitdown"` succeeds
- [ ] PDF conversion test: `markitdown test.pdf` (optional, if test file available)

## Artifacts & Outputs

- plans/01_markitdown-nixpkgs-migration.md (this file)
- summaries/01_markitdown-nixpkgs-migration-summary.md (post-implementation)

## Rollback/Contingency

If migration fails:
1. Restore `packages/markitdown.nix` from git: `git checkout packages/markitdown.nix`
2. Restore `flake.nix` overlay entry
3. Restore `home.nix` changes
4. Rebuild with `home-manager switch`

The original venv at `~/.local/share/markitdown-venv/` is not deleted until Phase 2 verification passes, providing a safety window.
