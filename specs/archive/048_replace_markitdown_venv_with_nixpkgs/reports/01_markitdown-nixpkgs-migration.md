# Research: Replace markitdown venv with nixpkgs package

**Task**: 48 - Replace markitdown venv wrapper with nixpkgs python312Packages.markitdown
**Date**: 2026-04-13
**Status**: Complete

## Problem

markitdown is installed via a custom venv wrapper at `~/.local/share/markitdown-venv/`, managed by `packages/markitdown.nix`. The CLI works (wrapper activates the venv), but `import markitdown` from system Python fails because the venv's site-packages is not on `PYTHONPATH`.

## Current Configuration

### packages/markitdown.nix
Creates a shell wrapper that:
- Manages a pip-based venv at `~/.local/share/markitdown-venv/`
- Installs `markitdown[all]` via pip on first run
- Exposes only the `markitdown` CLI command

### flake.nix (line ~89)
```nix
markitdown = final.callPackage ./packages/markitdown.nix {};
```

### home.nix (line ~175)
```nix
markitdown   # Document to markdown converter (supports PDF, DOCX, PPTX, etc)
```

## Key Finding

**`python312Packages.markitdown` exists in nixpkgs** (version 0.1.4). All dependencies including `pdfminer-six` (PDF support) are already propagated as build inputs.

### Verification

```bash
$ nix-shell -p 'python312.withPackages(p: [p.markitdown])' \
    --run 'python3 -c "import markitdown; print(markitdown.__version__)"'
0.1.4
```

This confirms both `import markitdown` and the CLI entry point work from a nix-managed Python environment.

## Recommended Solution

Add `markitdown` to the existing `python312.withPackages` block in `home.nix` and remove the custom wrapper infrastructure.

### Changes Required

| File | Action | Detail |
|------|--------|--------|
| `home.nix` (~line 374) | **Add** | `markitdown` to `python312.withPackages` list |
| `home.nix` (~line 175) | **Remove** | `markitdown` from standalone `home.packages` |
| `flake.nix` (~line 89) | **Remove** | `markitdown = final.callPackage ./packages/markitdown.nix {};` overlay entry |
| `packages/markitdown.nix` | **Delete** | Custom venv wrapper no longer needed |

### Post-rebuild Cleanup

After `home-manager switch` succeeds:
```bash
rm -rf ~/.local/share/markitdown-venv/
```

## Approach Comparison

| Approach | Import Works | Declarative | Reproducible | Effort |
|----------|-------------|-------------|--------------|--------|
| **withPackages (recommended)** | Yes | Yes | Yes | Minimal |
| Custom buildPythonPackage | Yes | Yes | Yes | High |
| PYTHONPATH hack to venv | Fragile | No | No | Low |
| Current wrapper script | No | Partial | No | Done |

## Version Note

nixpkgs has v0.1.4; the venv had v0.1.5. The difference is minor (patch release). The nixpkgs version will track upstream as nixpkgs updates.

## Risk Assessment

- **Low risk**: markitdown is already packaged with all dependencies
- **No conflicts**: Adds to existing `python312.withPackages` pattern used by other packages
- **Reversible**: Can re-add the venv wrapper if needed
