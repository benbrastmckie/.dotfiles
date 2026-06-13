# Implementation Plan: Task #65 — Migrate python312 Pins to Default python3

- **Task**: 65 - Migrate python312 pins to default python3 (3.13)
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None blocking (tasks 60/61 are advisory)
- **Research Inputs**: specs/065_migrate_python312_pins_to_default_python3/reports/01_python312-to-python3-migration.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Migrate all explicit `python312` pins to the default `python3` alias (currently 3.13.13) across the NixOS dotfiles repository. This ensures Hydra binary cache coverage for the full python3Packages set, eliminating source builds of heavy packages like torch. The migration touches four files with four edits: `home.nix` (withPackages pin), `configuration.nix` (Discord bot pin), `packages/python-cvc5.nix` (cp312 wheel to cp313), and `flake.nix` (remove dead python312 overlay entry).

### Research Integration

Research report `01_python312-to-python3-migration.md` verified:
- All 33 packages in the home.nix environment exist in `python3Packages` (3.13) with `broken=false`
- torch 2.12.0 evaluates cleanly and is Hydra-cached for python3
- Custom `vosk` package uses a `py3-none` wheel (version-agnostic, no change needed)
- Discord bot packages (`nextcord`, `aiohttp`, `anyio`) have no PEP 594 risk on 3.13
- `cvc5` custom wheel needs the cp313 URL and hash (already captured in report)
- The `python3` overlay in `flake.nix` already applies `customPythonPackages`; only the `python312` entry needs removal

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace `python312.withPackages` with `python3.withPackages` in `home.nix:352`
- Replace `pkgs.python312.withPackages` with `pkgs.python3.withPackages` in `configuration.nix:10`
- Update `packages/python-cvc5.nix` from cp312 to cp313 wheel (URL + hash)
- Remove the dead `python312` overlay entry from `flake.nix:123-125`
- Verify both NixOS and home-manager closures evaluate cleanly with python3 (3.13)
- Confirm no python3.12 paths remain in the evaluated derivation requisites
- Check binary cache substitutability for heavy packages (torch, scipy, numpy)

**Non-Goals**:
- Running `nixos-rebuild switch/build` or `home-manager switch/build` (user-only operations)
- Pinning to an explicit `python313` (use the default `python3` alias for future-proofing)
- Re-enabling disabled packages (jupytext, pdf2docx, pymupdf4llm) -- their issues are upstream and version-independent
- Changing the nixpkgs channel pin (task 61 scope)
- Modifying Nix build resource limits (task 60 scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| cvc5 cp313 wheel patching fails | H | L | `pythonImportsCheck = ["cvc5"]` catches at build time; hash pre-verified from PyPI |
| torch or heavy package source-builds instead of cache hit | M | L | torch 2.12.0 is in python3Packages; Hydra caches it; Phase 3 cache check catches misses |
| vosk py3-none wheel breaks on 3.13 | L | L | py3-none ABI means no version dependency; C extension is pre-built in wheel |
| Flake eval fails after overlay removal | M | L | Phase 2 eval check catches immediately; overlay only duplicated what python3 already has |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2 |

Phases within the same wave can execute in parallel (waves 3 and 4 are independent).

---

### Phase 1: Pin Migrations [NOT STARTED]

**Goal**: Apply all four code edits to migrate from python312 to python3.

**Tasks**:
- [ ] Edit `home.nix:352` -- change `python312.withPackages` to `python3.withPackages`
- [ ] Edit `configuration.nix:10` -- change `pkgs.python312.withPackages` to `pkgs.python3.withPackages`
- [ ] Edit `packages/python-cvc5.nix:14-15` -- replace cp312 wheel URL with cp313 URL and update sha256 hash
- [ ] Edit `flake.nix:123-125` -- remove the three-line `python312 = prev.python312.override { ... }` block
- [ ] Update the comment on `configuration.nix:8` from "Python 3.12" to "Python 3" (if present)
- [ ] Git commit: `task 65 phase 1: pin migrations` with session ID in body

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `home.nix:352` -- `python312` to `python3`
- `configuration.nix:10` -- `pkgs.python312` to `pkgs.python3`
- `packages/python-cvc5.nix:14-15` -- cp313 wheel URL and SRI hash
- `flake.nix:123-125` -- remove python312 overlay block

**Verification**:
- `grep -rn 'python312' *.nix packages/*.nix` returns no hits (all pins migrated)
- `grep -n 'python3\.withPackages\|python3Packages' home.nix configuration.nix` shows new pins

---

### Phase 2: Eval Verification [NOT STARTED]

**Goal**: Confirm both NixOS and home-manager closures evaluate cleanly on python3 (3.13), with no residual python3.12 paths.

**Tasks**:
- [ ] Run `nix eval .#nixosConfigurations.hamsa.config.system.build.toplevel.drvPath` -- must succeed (system closure evaluates)
- [ ] Run `nix eval .#homeConfigurations.benjamin.activationPackage.drvPath` -- must succeed (home closure evaluates), or use alternate attribute path if homeConfigurations is structured differently
- [ ] Run `nix eval --raw .#nixosConfigurations.hamsa.pkgs.python3.version` -- confirm output starts with `3.13`
- [ ] Grep the derivation requisites for python3.12 paths: `nix-store -qR $(nix eval --raw .#nixosConfigurations.hamsa.config.system.build.toplevel.drvPath) 2>/dev/null | grep python3.12` should return empty (no 3.12 remains). If nix-store -qR fails on a .drv path, use `nix derivation show` or skip this sub-check as non-blocking.
- [ ] Git commit: `task 65 phase 2: eval verification` with session ID in body

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**: None (read-only verification)

**Verification**:
- Both `nix eval` commands exit 0
- Python version output confirms 3.13.x
- No python3.12 paths found in requisites (or check is noted as skipped with reason)

---

### Phase 3: Cache Coverage Check [NOT STARTED]

**Goal**: Verify that heavy python3 packages (torch, scipy, numpy, matplotlib) resolve as substitutable from cache.nixos.org rather than requiring local builds.

**Tasks**:
- [ ] For each of torch, scipy, numpy, matplotlib: evaluate the store path via `nix eval --raw` on `python3Packages.{pkg}`, then check `nix path-info --store https://cache.nixos.org {path}` for substitutability
- [ ] Record results: which packages have cache hits vs misses
- [ ] If any critical package (torch) misses cache, document as a known issue (non-blocking -- task 61 stable channel pin will improve this)
- [ ] This phase is informational only -- cache misses do not block the migration

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**: None (read-only verification)

**Verification**:
- Cache check commands complete (exit 0 for hits, non-zero for misses logged)
- Results documented in commit message or summary

---

### Phase 4: Build Verification [NOT STARTED]

**Goal**: Run `nix flake check` to validate the flake evaluates cleanly. Delegate actual system/home builds to the user.

**Tasks**:
- [ ] Run `nix flake check` from the repository root -- must exit 0
- [ ] Document that the user must run `nixos-rebuild build --flake .#hamsa` and `home-manager build --flake .#benjamin` themselves to verify the full build
- [ ] Git commit: `task 65 phase 4: build verification` with session ID in body
- [ ] NEVER run `nixos-rebuild switch`, `nixos-rebuild build`, `home-manager switch`, or `home-manager build`

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**: None (read-only verification)

**Verification**:
- `nix flake check` exits 0
- User instructions for manual build clearly stated in commit or summary

## Testing & Validation

- [ ] `grep -rn 'python312' *.nix packages/*.nix` returns no matches
- [ ] `nix eval .#nixosConfigurations.hamsa.config.system.build.toplevel.drvPath` succeeds
- [ ] `nix eval .#homeConfigurations.benjamin.activationPackage.drvPath` succeeds (or equivalent path)
- [ ] `nix eval --raw .#nixosConfigurations.hamsa.pkgs.python3.version` outputs `3.13.x`
- [ ] `nix flake check` exits 0
- [ ] User runs `nixos-rebuild build` and `home-manager build` successfully (manual step)

## Artifacts & Outputs

- `specs/065_migrate_python312_pins_to_default_python3/plans/01_implementation-plan.md` (this file)
- `specs/065_migrate_python312_pins_to_default_python3/summaries/01_execution-summary.md` (post-implementation)

## Rollback/Contingency

All changes are tracked in git. To revert the migration:
1. `git revert` the phase 1 commit to restore all four files to their python312 state
2. No data loss risk -- the migration is purely declarative configuration changes
3. If only the cvc5 wheel fails, revert just `packages/python-cvc5.nix` and re-add the `python312` overlay entry in `flake.nix` while keeping the other two pin changes
