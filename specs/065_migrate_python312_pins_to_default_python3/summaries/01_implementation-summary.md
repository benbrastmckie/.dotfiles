# Implementation Summary: Task #65 — Migrate python312 Pins to Default python3

**Completed**: 2026-06-12
**Duration**: ~30 minutes (4 phases)
**Session**: sess_1781315200_b4c3d2

## Overview

Migrated all explicit `python312` pins to the default `python3` alias (currently 3.13.13) across the NixOS dotfiles repository. Four files were edited in Phase 1; Phases 2-4 were read-only verification steps. All evaluation and flake checks passed cleanly.

## What Changed

- `home.nix:352` — `python312.withPackages` → `python3.withPackages`
- `configuration.nix:8-10` — comment updated from "Python 3.12" to "Python 3"; `pkgs.python312.withPackages` → `pkgs.python3.withPackages`
- `packages/python-cvc5.nix:14-15` — cp312 wheel URL and hash replaced with cp313 wheel (cvc5 1.3.3 for Python 3.13)
- `flake.nix:123-125` — removed dead `python312 = prev.python312.override { ... }` overlay block

## Decisions

- Used `python3` (default alias) rather than explicit `python313` for future-proofing
- All 33 packages in the home.nix environment confirmed available in python3Packages (3.13)
- cvc5 cp313 wheel URL and hash taken from PyPI JSON API (pre-verified in research report)
- python312 overlay entry in flake.nix removed since python3 overlay already applies customPythonPackages

## Plan Deviations

- None (implementation followed plan exactly)

## Verification

### Phase 2: Eval Verification

| Check | Result |
|-------|--------|
| `nix eval .#nixosConfigurations.hamsa.config.system.build.toplevel.drvPath` | OK — `/nix/store/4l8wzfax9ysqq4gyxi7iaisx21fq13s2-nixos-system-hamsa-26.11...drv` |
| `nix eval .#homeConfigurations.benjamin.activationPackage.drvPath` | OK — `/nix/store/0pgcavdic2h557191fx5jhha8aqzsxjq-home-manager-generation.drv` |
| `nix eval --raw .#nixosConfigurations.hamsa.pkgs.python3.version` | `3.13.13` |
| python3.12 in NixOS requisites | 350 bootstrap `.drv` build-time deps (nixpkgs-internal plumbing); **0 runtime paths** |
| python3.12 in home requisites | **0 entries** |

The 350 python3.12 entries in the NixOS closure are all `python3.12-bootstrap-*` and related `.drv` files used by nixpkgs internally to build packages at the tool layer (hatchling, setuptools, pytest, etc.). They exist regardless of which Python version is used for user packages and are NOT from the configuration changes.

### Phase 3: Binary Cache Coverage

All heavy python3 packages resolve as substitutable from cache.nixos.org:

| Package | Version | Store Path | Cache |
|---------|---------|-----------|-------|
| torch | 2.12.0 | `/nix/store/n678a91as05dls78hghfcqygjq7s5h31-python3.13-torch-2.12.0` | **CACHED** |
| scipy | 1.17.1 | `/nix/store/8ks33136i68asgf0r3hiydyxn2gm61z1-python3.13-scipy-1.17.1` | **CACHED** |
| numpy | 2.4.4 | `/nix/store/l59n6vzkswz23y6s4pr6cmv2p4dpd5f0-python3.13-numpy-2.4.4` | **CACHED** |
| matplotlib | 3.10.9 | `/nix/store/qn7jy02spsabp9s97d8n1j5z63k7jpbi-python3.13-matplotlib-3.10.9` | **CACHED** |

**All 4 packages are in the Hydra binary cache — no source builds expected for the home environment.**

### Phase 4: Flake Check

`nix flake check` — **all checks passed**

Pre-existing warnings (unrelated to this migration):
- Home Manager 26.05 / Nixpkgs 26.11 version mismatch (task 61 scope)
- `boot.zfs.forceImportRoot` default value warning (NixOS 26.11 recommendation)

## Next Steps

The user must run the following to apply changes:

```bash
# NixOS system rebuild
nixos-rebuild build --flake .#hamsa    # build-test first
nixos-rebuild switch --flake .#hamsa   # apply when satisfied

# Home Manager rebuild
home-manager build --flake .#benjamin  # build-test first
home-manager switch --flake .#benjamin # apply when satisfied
```

All heavy packages (torch, scipy, numpy, matplotlib) will be substituted from cache.nixos.org — no long source builds expected.

## Notes

- The vosk package uses a `py3-none` wheel (version-agnostic ABI) — no changes needed
- Packages disabled before migration (jupytext, pdf2docx, pymupdf4llm) remain disabled — upstream issues are Python-version-independent
- The `enableNixpkgsReleaseCheck` warning is pre-existing (task 61 scope: channel pinning)
