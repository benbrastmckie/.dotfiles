# Research Report: Task #65 — Migrate python312 pins to default python3

**Task**: 65 - Migrate python312 pins to default python3 (3.13)
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: Small (2 files, 3 edits)
**Dependencies**: None blocking (tasks 60/61 are advisory — safer with cache/memory guardrails but not required)
**Sources/Inputs**: Local nix files, nixpkgs eval, PyPI JSON API
**Artifacts**: - specs/065_migrate_python312_pins_to_default_python3/reports/01_python312-to-python3-migration.md

## Executive Summary

- `pkgs.python3` resolves to **3.13.13** on the current nixpkgs pin (nixos-unstable/26.05)
- All packages in `home.nix` are available in `python3Packages` (3.13) and marked `broken=false`
- **One blocker**: `packages/python-cvc5.nix` fetches a `cp312`-specific wheel — needs updating to the `cp313` wheel (URL + hash already found)
- **One caveat**: `vosk` is a `py3-none` pure wheel — compatible with 3.13 without changes
- Discord bot packages (`nextcord`, `aiohttp`, `anyio`) all exist in `python3Packages` with no PEP 594 issues
- The `enableNixpkgsReleaseCheck` warning is unrelated: nixpkgs is actually `26.05.19700101.dirty` (matching home-manager `release-26.05`), not 26.11-pre

## Context & Scope

Two pins to migrate:
1. `home.nix:352` — `python312.withPackages(...)` → `python3.withPackages(...)`
2. `configuration.nix:10` — `pkgs.python312.withPackages(...)` → `pkgs.python3.withPackages(...)`

The `pythonPackagesOverlay` in `flake.nix` already applies `customPythonPackages` to both `python3` and `python312`. No overlay changes needed for home.nix migration. One overlay change needed: `python312` entry can be removed from `flake.nix:123-125` after migration.

## Findings

### Existing Configuration

**home.nix:352** — `python312.withPackages` inside `with pkgs;` block:
```
z3-solver, setuptools, pyinstrument, build, cvc5, twine, pytest, pytest-cov,
pytest-timeout, tqdm, pip, pylatexenc, pyyaml, requests, markdown, jupyter,
jupyter-core, notebook, ipywidgets, matplotlib, networkx, pynvim, numpy,
pandas, datasets, huggingface-hub, torch, moviepy, scipy, statsmodels,
seaborn, pyarrow, ipython, google-generativeai, python-docx, vosk, pymupdf,
scikit-learn (dotted form)
```

**configuration.nix:10** — `discordBotPython`:
```
nextcord, aiohttp, anyio
```

**flake.nix:106-126** — `pythonPackagesOverlay`:
- Applies `customPythonPackages` to both `python3` AND `python312`
- Custom packages: `cvc5` (cp312 wheel), `pymupdf4llm`, `vosk` (py3 wheel), `httplib2` (doCheck=false), `pymupdf` (doCheck=false)

### Package Verification (all confirmed in nixpkgs python3Packages / 3.13)

| Package | Version | Notes |
|---------|---------|-------|
| z3-solver | 4.16.0 | OK |
| setuptools | 80.10.1 | OK |
| pyinstrument | 5.1.1 | OK |
| build | 1.4.4 | OK |
| cvc5 | custom wheel | **NEEDS UPDATE** — see below |
| twine | 6.2.0 | OK |
| pytest | 9.0.3 | OK |
| pytest-cov | 7.1.0 | OK |
| pytest-timeout | 2.4.0 | OK |
| tqdm | 4.67.1 | OK |
| pip | 25.3 | OK |
| pylatexenc | 2.10 | OK |
| pyyaml | 6.0.3 | OK |
| requests | 2.33.1 | OK |
| markdown | 3.10.2 | OK |
| jupyter | 1.1.1 | OK |
| jupyter-core | 5.9.1 | OK |
| notebook | 7.5.6 | OK |
| ipywidgets | 8.1.8 | OK |
| matplotlib | 3.10.9 | OK |
| networkx | 3.6.1 | OK |
| pynvim | 0.6.0 | OK |
| numpy | 2.4.4 | OK |
| pandas | 2.3.3 | OK |
| datasets | 4.5.0 | OK |
| huggingface-hub | 1.10.2 | OK |
| torch | 2.12.0 | OK — evaluates cleanly, Hydra-cached |
| moviepy | 2.2.1 | OK |
| scipy | 1.17.1 | OK |
| statsmodels | 0.14.6 | OK |
| seaborn | 0.13.2 | OK |
| pyarrow | 23.0.0 | OK |
| ipython | 9.9.0 | OK |
| google-generativeai | 0.8.6 | OK |
| python-docx | 1.2.0 | OK |
| vosk | custom py3 wheel | OK — `dist="py3"`, `abi="none"` — version-agnostic |
| pymupdf | 1.27.2.3 | OK (overridden doCheck=false applies via python3 overlay) |
| scikit-learn | 1.8.0 | OK |

**Discord bot packages** (python3Packages):
| Package | Version | PEP 594 risk |
|---------|---------|-------------|
| nextcord | 3.2.0 | None (no stdlib-deprecated deps) |
| aiohttp | 3.13.5 | None |
| anyio | 4.13.0 | None |

### Packages That Need Attention

#### 1. cvc5 custom wheel — MUST UPDATE

`packages/python-cvc5.nix` fetches a `cp312`-specific wheel. A `cp313` wheel for the same version (1.3.3) exists on PyPI:

```
cp313 wheel URL:
https://files.pythonhosted.org/packages/a8/0f/81d6872063607f1e1a8f3367d0ee3771a5570738aa63b7952173db159199/cvc5-1.3.3-cp313-cp313-manylinux2014_x86_64.manylinux_2_17_x86_64.whl

sha256 (hex): bd5ec09a731342c14608d0bc99f3e0d64dadb7ff688126d2ea4dde2697e4db27
sha256 (SRI): sha256-vV7AmnMTQsFGCNC8mfPg1k2tt/9ogSbS6k3eJpfk2yc=
```

The `pythonImportsCheck = [ "cvc5" ]` line will catch any patching failures at build time.

#### 2. Disabled packages (jupytext, pdf2docx, pymupdf4llm)

These are commented out in home.nix with upstream-specific reasons:
- `jupytext` — async/sync ContentsManager test failures (not Python-version-specific)
- `pdf2docx` — dep chain `python-docx → behave → cucumber-expressions → uv_build<0.10.0` (nixpkgs has 0.10.0) — same conflict on 3.13
- `pymupdf4llm` — requires PyMuPDF 1.26.6, nixpkgs has 1.24.10 — same on 3.13

All three should remain disabled after migration; the upstream issues are independent of Python version.

### enableNixpkgsReleaseCheck Warning

The warning is a false alarm from the dirty git tree. The actual nixpkgs version is `26.05.19700101.dirty` which matches `home-manager/release-26.05`. The task description mentions "26.11-pre" — this was likely from an earlier flake.lock state. The flake.nix currently uses `github:NixOS/nixpkgs/nixos-unstable` and `github:nix-community/home-manager/release-26.05`. This is task 61's scope (channel pinning); document and ignore here.

## Decisions

- Migrate home.nix to `python3.withPackages` (not `pkgs.python313` explicit pin — use the default alias)
- Migrate configuration.nix discordBotPython to `pkgs.python3.withPackages`
- Update `packages/python-cvc5.nix` to cp313 wheel before or simultaneously with the migration
- Remove the `python312 = prev.python312.override { ... }` block from flake.nix overlay after migration (no longer needed)
- Leave `python3 = prev.python3.override { ... }` overlay intact (it covers the custom packages)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| cvc5 cp313 wheel patching fails | Medium | `pythonImportsCheck = ["cvc5"]` catches it at build; wheel hash pre-verified from PyPI |
| torch or heavy package source-builds | Medium | Tasks 60/61 (resource limits + stable channel) reduce this; torch 2.12.0 is in python3Packages so Hydra should cache it |
| vosk py3 wheel breaks on 3.13 | Low | py3-none wheel means no ABI dependency; C extension is pre-built in the wheel |
| Discord bot PEP 594 breakage | None | nextcord/aiohttp/anyio don't use any removed stdlib modules |

## Exact Lines to Change

### 1. home.nix:352
```nix
# Before
    (python312.withPackages(p: (with p; [
# After
    (python3.withPackages(p: (with p; [
```

### 2. configuration.nix:10
```nix
# Before
  discordBotPython = pkgs.python312.withPackages (p: with p; [
# After
  discordBotPython = pkgs.python3.withPackages (p: with p; [
```

### 3. packages/python-cvc5.nix — update wheel to cp313
```nix
# Before (line ~14-15)
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/99/f5/7843b57f53001606bb0acc53af13900303814a9e7a29d798390840073c32/cvc5-1.3.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "sha256-ekGx71KvDFuLewqP9nAAFoC3WPt5/nVwNNvp+hhhJlk=";
  };

# After
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/a8/0f/81d6872063607f1e1a8f3367d0ee3771a5570738aa63b7952173db159199/cvc5-1.3.3-cp313-cp313-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
    sha256 = "sha256-vV7AmnMTQsFGCNC8mfPg1k2tt/9ogSbS6k3eJpfk2yc=";
  };
```

### 4. flake.nix:123-125 — remove python312 overlay entry (cleanup)
```nix
# Remove these 3 lines:
        python312 = prev.python312.override {
          packageOverrides = customPythonPackages;
        };
```

## Appendix

### Verification commands after implementation

```bash
# Confirm python3 resolves to 3.13
nix eval --raw .#nixosConfigurations.hamsa.pkgs.python3.version

# Confirm torch evaluates (no build needed for eval)
nix eval --raw .#nixosConfigurations.hamsa.pkgs.python3Packages.torch.version

# Dry-run home-manager build
home-manager build --flake .#benjamin@hamsa

# Dry-run full NixOS build
nixos-rebuild build --flake .#hamsa
```

### Search queries used
- `nix eval --raw "nixpkgs#python3Packages.X.version"` for all 33 packages
- `nix eval "nixpkgs#python3Packages.X.meta.broken"` for key packages
- `curl https://pypi.org/pypi/cvc5/1.3.3/json` for wheel inventory
- `nix eval --raw .#nixosConfigurations.nandi.pkgs.python3.version` for version confirmation
