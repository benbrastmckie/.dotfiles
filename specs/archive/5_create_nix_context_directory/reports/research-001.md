# Research Report: Task #5

**Task**: 5 - create_nix_context_directory
**Started**: 2026-02-03T12:00:03Z
**Completed**: 2026-02-03T12:15:00Z
**Effort**: ~2 hours implementation
**Dependencies**: None (parallel with task 4)
**Sources/Inputs**: Codebase analysis, NixOS Wiki, nix.dev documentation, Nixpkgs manual
**Artifacts**: specs/5_create_nix_context_directory/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Nix context directory should mirror the existing neovim context structure with domain/, patterns/, standards/, and tools/ subdirectories
- Existing flake.nix, home.nix, and configuration.nix files provide rich local examples of Nix patterns used in this repository
- Key concepts to document include: Nix language fundamentals, flakes, NixOS module system, home-manager, overlays, derivations
- Official nixfmt is now the enforced formatter for Nixpkgs contributions (RFC 166)
- Focus on patterns actually used in this repository: overlays for custom packages, home-manager modules, flake-based configuration

## Context & Scope

This research supports creating a comprehensive Nix context directory at `.claude/context/project/nix/` that Claude agents can load when working on Nix-related tasks. The goal is to mirror the structure and depth of the existing neovim context.

### Target Directory Structure

```
.claude/context/project/nix/
├── README.md                    # Nix context overview
├── domain/                      # Domain knowledge
│   ├── nix-language.md         # Nix expression syntax
│   ├── flakes.md               # Flake structure and inputs
│   ├── nixos-modules.md        # NixOS module system
│   └── home-manager.md         # Home Manager modules
├── patterns/                    # Implementation patterns
│   ├── module-patterns.md      # Module definition patterns
│   ├── overlay-patterns.md     # Overlay patterns
│   └── derivation-patterns.md  # Package derivation patterns
├── standards/                   # Coding standards
│   └── nix-style-guide.md      # Formatting, naming conventions
└── tools/                       # Tool-specific guides
    ├── nixos-rebuild-guide.md  # System rebuild workflows
    └── home-manager-guide.md   # Home Manager workflows
```

## Findings

### 1. Codebase Patterns

#### Existing Nix Files in Repository

The repository contains well-structured Nix files demonstrating best practices:

**flake.nix** (452 lines):
- Comprehensive flake with multiple inputs (nixpkgs, home-manager, lean4, niri, etc.)
- Multiple overlays: claudeSquadOverlay, unstablePackagesOverlay, pythonPackagesOverlay
- Multiple nixosConfigurations for different hosts (nandi, hamsa, iso, usb-installer)
- homeConfigurations for standalone home-manager usage
- Input following pattern for consistency: `home-manager.inputs.nixpkgs.follows = "nixpkgs"`

**home.nix** (773 lines):
- Home Manager module with extensive programs.* configuration
- Systemd user services for ydotool and gmail-oauth2-refresh
- dconf.settings for GNOME configuration
- home.file declarations for dotfile management
- Custom shell scripts using writeShellScriptBin

**configuration.nix** (552 lines):
- NixOS system configuration with services, packages, kernel parameters
- Boot configuration, networking, display manager setup
- Hardware configuration references
- Programs and environment.systemPackages

**packages/*.nix**:
- Simple wrapper scripts (claude-code.nix, loogle.nix)
- Python package overrides (python-cvc5.nix, python-vosk.nix)
- Package overrides (kooha.nix, piper-voices.nix)

**home-modules/mcp-hub.nix**:
- Custom home-manager module with options, config, mkIf, mkOption

### 2. Nix Language Fundamentals

Key syntax elements to document in domain/nix-language.md:

#### Let Expressions
```nix
let
  x = 1;
  y = 2;
in x + y
```
- Bindings have local scope
- Names can reference each other in any order
- Expression after `in` uses the bindings

#### Inherit
```nix
# Shorthand for name = name
let x = 1; in { inherit x; }  # => { x = 1; }

# From another set
let attrs = { x = 1; y = 2; }; in { inherit (attrs) x; }  # => { x = 1; }
```

#### Recursive Sets (rec)
```nix
rec {
  x = 1;
  y = x + 1;  # Can reference x
}
```
- Allows self-referential attribute sets
- Risk of infinite recursion

#### With Expression
```nix
with pkgs; [ vim git ]  # Equivalent to [ pkgs.vim pkgs.git ]
```
- `with` is discouraged; prefer explicit `inherit` or full paths
- Does NOT shadow existing let bindings

#### Functions
```nix
# Lambda syntax
x: x + 1

# Pattern matching
{ config, lib, pkgs, ... }: { ... }

# Default arguments
{ x ? 1 }: x
```

### 3. Flakes

Key concepts for domain/flakes.md:

#### Structure
```nix
{
  description = "Flake description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Input following
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem { ... };
    homeConfigurations.username = home-manager.lib.homeManagerConfiguration { ... };
    packages.x86_64-linux.default = ...;
    devShells.x86_64-linux.default = ...;
  };
}
```

#### Output Schema
- `packages.<system>.<name>` - Nix packages
- `nixosConfigurations.<hostname>` - NixOS system configs
- `homeConfigurations.<username>` - Home Manager configs
- `devShells.<system>.<name>` - Development shells
- `overlays.<name>` - Nixpkgs overlays
- `lib.<name>` - Helper functions

#### Lock File (flake.lock)
- Auto-generated, pins inputs to specific revisions
- Update with `nix flake update`
- Update single input: `nix flake lock --update-input nixpkgs`

### 4. NixOS Module System

Key concepts for domain/nixos-modules.md:

#### Module Structure
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myservice = { ... };
  };
}
```

#### Key Functions
- `mkOption` - Declare options with type, default, description
- `mkEnableOption` - Shorthand for boolean enable options
- `mkIf` - Conditional config (avoids infinite recursion)
- `mkMerge` - Merge multiple config sets
- `mkDefault` - Set lower priority default
- `mkForce` - Override all other definitions

#### Common Types (lib.types)
- `bool`, `str`, `int`, `port`
- `attrsOf t` - Attribute set of type t
- `listOf t` - List of type t
- `enum ["a" "b"]` - One of enumerated values
- `submodule` - Nested module
- `nullOr t` - t or null
- `oneOf [t1 t2]` - One of multiple types

### 5. Home Manager

Key concepts for domain/home-manager.md:

#### Module Structure
```nix
{ config, pkgs, ... }:
{
  home.username = "user";
  home.homeDirectory = "/home/user";
  home.stateVersion = "24.11";

  programs.git = {
    enable = true;
    userName = "User Name";
  };

  home.packages = with pkgs; [ vim git ];

  home.file.".config/app/config".text = "...";

  systemd.user.services.myservice = { ... };
}
```

#### Key Options
- `programs.*` - Application configuration (git, neovim, fish, etc.)
- `services.*` - User systemd services
- `home.packages` - Packages to install
- `home.file.*` - File management (symlinks to Nix store)
- `xdg.configFile.*` - XDG config file management
- `home.sessionVariables` - Environment variables
- `dconf.settings` - GNOME dconf settings

#### Standalone vs NixOS Module
- Standalone: `home-manager switch --flake .#username`
- NixOS module: Integrated into nixosConfigurations
- Use `home-manager.useGlobalPkgs = true` for shared pkgs

### 6. Overlay Patterns

Key concepts for patterns/overlay-patterns.md:

#### Basic Structure
```nix
final: prev: {
  # Override existing package
  vim = prev.vim.override { guiSupport = false; };

  # Add new package
  mypackage = final.callPackage ./mypackage.nix {};

  # Override attributes
  hello = prev.hello.overrideAttrs (old: {
    version = "2.12";
    src = ...;
  });
}
```

#### final vs prev
- `final` (self) - Final result of all overlays; use for dependencies
- `prev` (super) - Previous stage; use when overriding same package

#### Pattern from Repository
```nix
unstablePackagesOverlay = final: prev: {
  claude-code = final.callPackage ./packages/claude-code.nix {};
  niri = pkgs-unstable.niri;
};
```

### 7. Derivation Patterns

Key concepts for patterns/derivation-patterns.md:

#### Basic mkDerivation
```nix
stdenv.mkDerivation {
  pname = "mypackage";
  version = "1.0.0";
  src = fetchFromGitHub { ... };

  nativeBuildInputs = [ cmake ];  # Build-time tools
  buildInputs = [ openssl ];       # Runtime libraries

  buildPhase = "make";
  installPhase = "make install PREFIX=$out";
}
```

#### Build Phases
1. unpackPhase - Extract source
2. patchPhase - Apply patches
3. configurePhase - Run configure
4. buildPhase - Compile
5. checkPhase - Run tests
6. installPhase - Install to $out
7. fixupPhase - Post-processing

#### Wrapper Scripts (from repository)
```nix
{ writeShellScriptBin, nodejs }:
writeShellScriptBin "claude" ''
  exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''
```

### 8. Style Guide

Key concepts for standards/nix-style-guide.md:

#### Official Formatter
- **nixfmt** is the official Nix formatter (RFC 166)
- Enforced in Nixpkgs contributions
- Available as `pkgs.nixfmt-rfc-style` or `pkgs.nixfmt`

#### Formatting Conventions
- 2 spaces indentation
- Attribute sets on multiple lines when > 1 attribute
- Trailing commas in multi-line lists/sets
- Function arguments: `{ arg1, arg2, ... }:` on one line if short

#### Naming Conventions
- Package names: lowercase, hyphens (e.g., `my-package`)
- Attributes: camelCase in lib, snake_case in some contexts
- Variables: snake_case
- Options: dot.separated.path

#### Common Anti-patterns
- Avoid `with` when possible; use `inherit` instead
- Don't use `rec` when not needed
- Avoid deeply nested attribute paths in large sets
- Don't mix tabs and spaces

### 9. Tool Guides

#### nixos-rebuild (for tools/nixos-rebuild-guide.md)
```bash
# Build and switch immediately
sudo nixos-rebuild switch

# Build and switch on next boot
sudo nixos-rebuild boot

# Build and activate temporarily (no boot entry)
sudo nixos-rebuild test

# Build without activating
nixos-rebuild build

# Build with flakes
sudo nixos-rebuild switch --flake .#hostname

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Build VM for testing
nixos-rebuild build-vm
```

#### home-manager (for tools/home-manager-guide.md)
```bash
# Build and switch
home-manager switch --flake .#username

# Build without switching
home-manager build --flake .#username

# List generations
home-manager generations

# Rollback
home-manager generations  # Find path
/path/to/previous-gen/activate

# News and changelog
home-manager news
```

## Decisions

1. **Directory Structure**: Mirror neovim context exactly (domain/, patterns/, standards/, tools/)
2. **Focus Areas**: Prioritize patterns actually used in this repository's Nix files
3. **Formatter**: Document nixfmt as the official/recommended formatter
4. **Examples**: Pull examples from the repository's existing flake.nix, home.nix, configuration.nix
5. **Scope**: Include both NixOS and standalone home-manager patterns since both are used

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Nix ecosystem changes rapidly | Document version-specific features, link to official docs |
| Context files become outdated | Focus on stable patterns, avoid experimental features |
| Too much content | Follow neovim context's style: concise, example-heavy |
| Missing patterns | Start with documented patterns, extend as needed |

## Appendix

### Search Queries Used
1. "Nix language syntax tutorial let with inherit rec expressions 2026"
2. "Nix flakes structure inputs outputs schema best practices 2026"
3. "NixOS module system options config mkOption mkIf mkMerge lib.types 2026"
4. "home-manager module structure programs services file management 2026"
5. "Nix overlay patterns final prev package override 2026"
6. "stdenv.mkDerivation Nix package build phases buildInputs nativeBuildInputs 2026"
7. "Nix style guide formatting nixfmt nixpkgs-fmt naming conventions 2026"
8. "nixos-rebuild switch build test boot workflows 2026"
9. "home-manager switch build generations standalone flakes 2026"
10. "Nix builtin functions map filter builtins.attrNames builtins.listToAttrs 2026"

### References
- [Nix language basics - nix.dev](https://nix.dev/tutorials/nix-language.html)
- [Nix Reference Manual - Syntax](https://nixos.org/manual/nix/stable/language/constructs)
- [Flakes - NixOS Wiki](https://wiki.nixos.org/wiki/Flakes)
- [NixOS modules - NixOS Wiki](https://wiki.nixos.org/wiki/NixOS_modules)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Overlays - NixOS Wiki](https://wiki.nixos.org/wiki/Overlays)
- [The Standard Environment - Nixpkgs](https://ryantm.github.io/nixpkgs/stdenv/stdenv/)
- [nixfmt - GitHub](https://github.com/NixOS/nixfmt)
- [nixos-rebuild - NixOS Wiki](https://wiki.nixos.org/wiki/Nixos-rebuild)
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/)

### Recommended Content Structure for Each File

#### domain/nix-language.md
1. Basic syntax (let, with, inherit, rec)
2. Data types (attrsets, lists, strings, paths)
3. Functions and lambdas
4. Built-in functions (map, filter, attrNames, etc.)
5. Import patterns
6. Lazy evaluation

#### domain/flakes.md
1. Flake structure overview
2. Inputs (sources, follows, overrides)
3. Outputs schema
4. Lock file management
5. Common input types
6. Debugging flakes

#### domain/nixos-modules.md
1. Module anatomy
2. Options declaration (mkOption, types)
3. Config definition (mkIf, mkMerge)
4. Module arguments
5. Imports and specialArgs
6. Priority and ordering

#### domain/home-manager.md
1. Home Manager overview
2. programs.* patterns
3. File management (home.file, xdg)
4. User services
5. Session variables
6. Standalone vs NixOS module

#### patterns/module-patterns.md
1. Enable pattern
2. Package override pattern
3. Submodule pattern
4. Conditional configuration
5. Module composition

#### patterns/overlay-patterns.md
1. Override pattern
2. Add package pattern
3. Override attrs pattern
4. Overlay composition
5. Python packages overlay

#### patterns/derivation-patterns.md
1. Basic mkDerivation
2. Wrapper scripts
3. Build phases
4. fetchFromGitHub
5. Python packages
6. Go modules

#### standards/nix-style-guide.md
1. Formatting (nixfmt)
2. Indentation and spacing
3. Naming conventions
4. Common anti-patterns
5. Documentation standards

#### tools/nixos-rebuild-guide.md
1. Common commands
2. Flake-based rebuilds
3. Rollback
4. VM testing
5. Remote deployment

#### tools/home-manager-guide.md
1. Installation modes
2. Build and switch
3. Generations management
4. Debugging
5. News and updates
