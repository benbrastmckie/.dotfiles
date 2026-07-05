# How to Add a Package

This guide explains where a new package belongs in the configuration and why.

## Decision Tree

```
Is it a system-level tool needed for all users or system services?
  YES → environment.systemPackages in modules/system/packages.nix
  NO  ↓

Is it a personal productivity or development tool for the benjamin user?
  YES → home.packages in modules/home/packages/*.nix (grouped by category: dev-tools, email-tools,
        media-dictation, misc, python)
  NO  ↓

Is it a program with an official NixOS/Home Manager module?
  YES → programs.<name>.enable = true; (NixOS or Home Manager — prefer modules over raw packages)
  NO  ↓

Is it a custom package not in nixpkgs?
  YES → packages/<name>.nix (custom derivation) → referenced in environment.systemPackages or home.packages
  NO  ↓

Does it need to be a different version than nixpkgs provides?
  YES → overlays/unstable-packages.nix (pulls from nixpkgs-unstable)
      OR packages/<name>.nix (pin a specific version)
```

## Package Ownership Policy

| Location | Owner | When to Use |
|----------|-------|-------------|
| `environment.systemPackages` | System (NixOS) | System-wide tools: editors available before login, sysadmin tools, display servers |
| `home.packages` | User (Home Manager) | User tools: shell utilities, apps, language runtimes used interactively |
| `programs.<name>` | System or User module | Official modules with options (git, neovim, fish, gnome, etc.) — prefer over raw packages |
| `packages/<name>.nix` | Custom derivation | Packages not in nixpkgs, or needing heavy customization |
| `overlays/unstable-packages.nix` | Overlay | Packages needing a newer version from nixpkgs-unstable |
| `overlays/python-packages.nix` | Overlay | Custom Python packages added to python3 |

## Common Examples

### Add a CLI tool for personal use (e.g., `bat`)

```nix
# In modules/home/packages/misc.nix (or the most fitting category file) → home.packages
home.packages = with pkgs; [
  bat  # A cat clone with syntax highlighting and Git integration
  # ... existing packages
];
```

### Add a system-wide tool (e.g., an editor available at login shell)

```nix
# In modules/system/packages.nix → environment.systemPackages
environment.systemPackages = with pkgs; [
  bat  # Available before home-manager activates
];
```

### Add a package via its NixOS module

```nix
# In the relevant modules/system/*.nix file (e.g. modules/system/services.nix)
services.openssh.enable = true;  # Pulls in openssh automatically
```

### Add a custom package not in nixpkgs

1. Create `packages/my-tool.nix` with the derivation.
2. Add it to `overlays/unstable-packages.nix`:
   ```nix
   my-tool = final.callPackage ./packages/my-tool.nix {};
   ```
3. Use `pkgs.my-tool` in `home.packages` or `environment.systemPackages`.

### Add a package from nixpkgs-unstable

```nix
# In overlays/unstable-packages.nix
unstable-packages = final: prev: {
  my-package = pkgs-unstable.my-package;
};
```

## Avoiding Duplication

A package should appear in **only one** of `environment.systemPackages` or `home.packages`.
If it's in both, one entry is redundant — prefer `home.packages` for user tools since
it participates in the standalone home-manager profile and can be updated without `sudo`.

The following packages were cleaned up in task 66 Phase 1 (removed from `systemPackages`
because they are already in `home.packages`): `stylua`, `cvc5`, `lectic`, `wl-clipboard`.

## Python Packages

Custom Python packages live in `overlays/python-packages.nix`, a standalone overlay file wired
into `flake.nix` as `pythonPackagesOverlay`. They extend `python3` via `packageOverrides`.

To add a new Python package:
1. If a nixpkgs derivation exists: add to `python3.withPackages` or the overlay.
2. If a custom derivation: create `packages/python-mylib.nix`, add to `customPythonPackages` in
   the overlay.
