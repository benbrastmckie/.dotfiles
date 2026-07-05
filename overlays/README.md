# Overlays

This directory contains the Nix overlays used to extend and customize `nixpkgs`. Each overlay is
a standalone file, imported in `flake.nix` and applied via the shared `nixpkgsConfig.overlays`
list so both `nixosConfigurations` and `homeConfigurations` see the same customized package set.

## Files

### claude-squad.nix

Provides the `claude-squad` package: a terminal app for managing multiple AI coding agents,
built from source via `buildGoModule` (GitHub: `smtg-ai/claude-squad`). Also creates a `cs` alias
symlinked to the `claude-squad` binary (`postInstall`). Wired into `flake.nix` as
`claudeSquadOverlay = import ./overlays/claude-squad.nix;`.

### unstable-packages.nix

The main overlay for packages sourced from `nixpkgs-unstable` or from custom derivations in
`packages/`. This overlay is curried — it takes `pkgs-unstable` as an explicit first argument
(partially applied in `flake.nix` as
`unstablePackagesOverlay = import ./overlays/unstable-packages.nix pkgs-unstable;`) before the
usual `final: prev:` overlay signature.

Currently provides:
- `niri` — pulled directly from `pkgs-unstable` for active-development window manager fixes.
- `gemini-cli` — pulled directly from `pkgs-unstable`.
- `claude-code`, `opencode`, `loogle`, `aristotle`, `slidev`, `kooha` — custom packages/wrappers
  built via `final.callPackage ../packages/<name>.nix { }` (or, for `kooha`, an `overrideAttrs`
  wrapper around the existing `prev.kooha`). See `packages/README.md` for what each of these
  actually does.
- `piper`, `piper-voice-en-us-lessac-medium`, `vosk-model-small-en-us` — TTS/STT binary and model
  packages, also via `final.callPackage`.

### python-packages.nix

Extends `python3` with custom package overrides via `packageOverrides`. Adds `cvc5`,
`pymupdf4llm`, and `vosk` (none available in nixpkgs, or not in the form needed) as
`pySelf.callPackage`d derivations from `packages/`, and patches `httplib2` and `pymupdf` to skip
their (flaky, in this environment) test suites via `overridePythonAttrs { doCheck = false; }`.
Wired into `flake.nix` as `pythonPackagesOverlay = import ./overlays/python-packages.nix;`.

## Adding a New Overlay

1. Create the overlay file under `overlays/`, following the `final: prev: { ... }` signature (or
   a curried variant if the overlay needs an argument like `pkgs-unstable`).
2. Import it in `flake.nix` alongside the existing overlays and add it to the
   `nixpkgsConfig.overlays` list.
3. If the overlay wraps a custom derivation, put the derivation itself under `packages/` and
   `callPackage` it from the overlay (see `unstable-packages.nix` for the pattern), rather than
   inlining the derivation in the overlay file.

See `.claude/rules/nix.md` for the overlay naming convention (`final`/`prev`, never the
deprecated `self`/`super`).

[← Back to main README](../README.md)
