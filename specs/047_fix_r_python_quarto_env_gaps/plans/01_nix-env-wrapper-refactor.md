# Implementation Plan: Task 47 - Fix R/Python/Quarto Environment Gaps

- **Task**: 47 - fix_r_python_quarto_env_gaps
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/027_fix_task20_env_gaps/reports/01_fix-env-gaps.md
- **Artifacts**: plans/01_nix-env-wrapper-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The current NixOS configuration has a structural problem with R packages: flat `rPackages.*` entries in `environment.systemPackages` do not expose packages to the R binary's library path. This plan refactors R configuration to use `rWrapper.override`, adds missing Python scientific packages to `home.nix`, installs Quarto for report rendering, and verifies all environments work correctly.

### Research Integration

Research report F3 identified the root cause: R sees only its base library at `/nix/store/.../R-4.5.3/lib/R/library` because contributed packages require composition via `rWrapper.override`. F4-F7 provide exact remediation patterns. F8 provides verification commands.

## Goals & Non-Goals

**Goals**:
- Replace flat `rPackages.*` entries with `rWrapper.override` pattern in configuration.nix
- Add P0/P1/P2 R packages: survival, MASS, nlme, lme4, tidyverse, broom, gtsummary, mice, knitr, rmarkdown, languageserver, styler, lintr
- Add scipy, statsmodels, scikit-learn, seaborn, pyarrow to Python environment in home.nix
- Install quarto to systemPackages for report rendering
- Verify all packages load correctly via one-liner tests

**Non-Goals**:
- Creating per-project flake.nix (separate task)
- Adding Bayesian packages (rstan, brms, cmdstanr) -- out of scope
- Configuring Zed settings.json for R LSP (can be follow-up task)
- Setting up renv/uv lockfile workflows (separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `rPackages.tidyverse` long build/download | M | L | Binary cache should cover it on nixos-unstable; fallback to listing individual packages |
| Removing bare `R` breaks tooling | M | L | `rWrapper` provides same `bin/R` and `bin/Rscript`; verify with `which R` |
| `scikit-learn` hyphen-in-with-block error | H | M | Use `p.scikit-learn` dotted form outside `with` block per research |
| Quarto `quarto check` warnings about TeX | L | M | Benign; `texlive.combined.scheme-full` already present; PDF output works |
| Rebuild takes longer than expected | L | M | All packages binary-cached; estimate 3-10 min download on broadband |

## Implementation Phases

### Phase 1: R Wrapper Refactor [NOT STARTED]

**Goal**: Replace flat R package entries with composed `rWrapper.override` that makes all packages visible to R binary.

**Tasks**:
- [ ] Read `~/.dotfiles/configuration.nix` lines 520-530 to locate current R entries
- [ ] Remove: `R`, `rPackages.languageserver`, `rPackages.styler`, `rPackages.lintr`
- [ ] Add `rWrapper.override` block with all P0/P1/P2 packages in same position:
  - P0: survival, MASS, nlme, lme4
  - P1: tidyverse, broom, gtsummary, mice, knitr, rmarkdown
  - P2: languageserver, styler, lintr
- [ ] Add `quarto` to systemPackages near pandoc entry

**Timing**: 30 minutes

**Files to modify**:
- `~/.dotfiles/configuration.nix` - Replace R package entries with wrapper, add quarto

**Verification**:
- File syntax check via `nix-instantiate --parse`

---

### Phase 2: Python Scientific Stack [NOT STARTED]

**Goal**: Add missing scientific Python packages to home.nix using correct identifier syntax.

**Tasks**:
- [ ] Read `~/.dotfiles/home.nix` lines 330-370 to locate `python312.withPackages` block
- [ ] Add packages using `p.` dotted form to avoid hyphen-in-identifier issues:
  - `p.scipy`
  - `p.statsmodels`
  - `p.scikit-learn` (dotted form required due to hyphen)
  - `p.seaborn`
  - `p.pyarrow`
- [ ] Restructure if needed: convert `with p;` entries to `p.` form for consistency, or use concatenation pattern

**Timing**: 20 minutes

**Files to modify**:
- `~/.dotfiles/home.nix` - Add scientific packages to python312.withPackages

**Verification**:
- File syntax check via `nix-instantiate --parse`

---

### Phase 3: System Rebuild [NOT STARTED]

**Goal**: Rebuild NixOS with new configuration and verify activation.

**Tasks**:
- [ ] Run `nix flake check ~/.dotfiles` to validate flake
- [ ] Run `sudo nixos-rebuild switch --flake ~/.dotfiles#$(hostname)`
- [ ] Wait for rebuild to complete (expect 3-10 minutes for downloads)
- [ ] Verify no errors in rebuild output

**Timing**: 15 minutes

**Files to modify**:
- None (system operation)

**Verification**:
- Rebuild exits with code 0
- No "error:" lines in output

---

### Phase 4: Environment Verification [NOT STARTED]

**Goal**: Verify all packages are accessible via runtime tests from research F8.

**Tasks**:
- [ ] R library path check: `R --quiet -e '.libPaths()'` (expect rWrapper path, not bare R)
- [ ] R P0 packages: `Rscript -e 'library(survival); library(MASS); library(nlme); library(lme4); cat("P0 OK\n")'`
- [ ] R P1 packages: `Rscript -e 'library(tidyverse); library(broom); library(gtsummary); library(mice); library(knitr); library(rmarkdown); cat("P1 OK\n")'`
- [ ] R P2 packages: `Rscript -e 'library(languageserver); library(styler); library(lintr); cat("P2 OK\n")'`
- [ ] Python stack: `python3 -c 'import scipy, statsmodels.api, sklearn, seaborn, pyarrow; print("py OK")'`
- [ ] Quarto: `quarto check` and `quarto --version`
- [ ] End-to-end: render minimal qmd with R chunk

**Timing**: 15 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- All commands exit 0
- `.libPaths()` shows rWrapper site-library path
- `quarto check` shows R and Python engines detected

## Testing & Validation

- [ ] R `.libPaths()` returns rWrapper site-library (not bare R library)
- [ ] All 13 R packages load without error
- [ ] All 5 Python packages import without error
- [ ] `quarto check` detects knitr and jupyter engines
- [ ] `quarto render /tmp/t.qmd` succeeds for a minimal R-chunk document

## Artifacts & Outputs

- `plans/01_nix-env-wrapper-refactor.md` (this file)
- `summaries/01_nix-env-wrapper-refactor-summary.md` (post-implementation)
- Modified `~/.dotfiles/configuration.nix`
- Modified `~/.dotfiles/home.nix`

## Rollback/Contingency

If the rebuild fails or packages don't work:
1. Revert configuration.nix and home.nix changes via `git checkout`
2. Run `sudo nixos-rebuild switch --flake ~/.dotfiles#$(hostname)` to restore previous state
3. If specific package fails to build, remove it from the wrapper and rebuild
4. For tidyverse build issues, replace meta-package with individual components: dplyr, readr, ggplot2, tidyr, purrr, stringr, forcats, tibble, lubridate
