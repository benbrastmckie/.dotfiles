# Research Report: Task #6

**Task**: Create Nix rules file for Claude agents
**Date**: 2026-02-03
**Focus**: Nix rules file for Claude agents - research existing rules patterns, Nix style conventions, and module structure requirements for auto-applied rules on *.nix files

## Summary

Researched existing rules file patterns in `.claude/rules/`, official Nix formatting standards (RFC 166/nixfmt), NixOS module patterns, flake conventions, and common anti-patterns. This report provides comprehensive guidelines for creating `.claude/rules/nix.md` with auto-applied rules for `*.nix` files.

## Findings

### 1. Existing Rules File Patterns

Analyzed five existing rules files to establish the standard structure:

| File | Structure | Key Sections |
|------|-----------|--------------|
| `neovim-lua.md` | Path Pattern + Domain-specific | Coding Standards, API Patterns, Plugin Specs, Error Handling, Do Not, Related Context |
| `state-management.md` | YAML frontmatter + Schemas | File Synchronization, Status Transitions, Schemas, Error Handling |
| `git-workflow.md` | Action-oriented | Commit Conventions, Tables, Safety rules |
| `artifact-formats.md` | Template-heavy | Path templates, Document structures |
| `error-handling.md` | Category-based | Error Categories, Recovery Strategies |

**Common Structure Identified**:
1. YAML frontmatter with `paths:` for auto-application
2. H1 title with domain name
3. H2 Path Pattern section
4. Domain-specific H2 sections
5. H2 "Do Not" section for anti-patterns
6. H2 "Related Context" section with @-references

### 2. Nix Formatting Standards (RFC 166 / nixfmt)

[Official nixfmt standard](https://github.com/NixOS/nixfmt/blob/master/standard.md):

**Indentation and Line Length**:
- 2 spaces per indentation level
- Soft line limit: 100 characters (excluding leading indentation)
- No tabs
- Indentation increases must be gradual (max one level per line)

**Expression Rules**:
- Single-line expressions that fit must remain on one line
- Multi-line lists/attributes require each item on its own line
- Empty sets/lists format compactly: `{}` or `[]`
- First items cannot be placed alongside opening brackets

**String Handling**:
- Quote style preserved (regular vs indented strings)
- Indented strings without newlines convert to regular strings
- Simple interpolations render single-line regardless of length

**Comments**:
- `/* */` block comments convert to `#` line comments (except language annotations)
- Multiline block comments: delimiters on separate lines, content indented

### 3. Repository-Specific Nix Patterns

Analyzed 19 `.nix` files in the repository:

**File Categories**:
- `flake.nix` - Top-level flake with inputs, overlays, outputs
- `configuration.nix` - NixOS system configuration
- `home.nix` - Home Manager configuration
- `packages/*.nix` - Custom package definitions
- `home-modules/*.nix` - Custom Home Manager modules
- `hosts/*/hardware-configuration.nix` - Per-host hardware config

**Observed Patterns**:
1. **Function signatures**: Use `{ config, lib, pkgs, ... }:` pattern
2. **Let bindings**: Extensively used for `cfg`, `pkgs-unstable`, etc.
3. **Overlays**: Three overlay patterns (claudeSquadOverlay, unstablePackagesOverlay, pythonPackagesOverlay)
4. **Module enables**: `mkEnableOption`, `mkOption`, `mkIf cfg.enable`
5. **Package lists**: Explicit `with pkgs;` blocks (though this is an anti-pattern)

### 4. NixOS Module Best Practices

From [nix.dev best practices](https://nix.dev/guides/best-practices.html) and [NixOS Wiki](https://wiki.nixos.org/wiki/NixOS_modules):

**Standard Module Anatomy**:
```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.myService;
in {
  options.services.myService = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    # configuration here
  };
}
```

**Priority Functions**:
- `lib.mkDefault` - Set overridable defaults
- `lib.mkForce` - Override values forcefully
- `lib.mkBefore` / `lib.mkAfter` - Control merge order for lists

### 5. Common Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Top-level `with pkgs;` | Static analysis fails, unclear origins | Use explicit `pkgs.foo` references |
| `rec { ... }` | Risk of infinite recursion | Use `let ... in` bindings |
| Lookup paths `<nixpkgs>` | Depends on external `$NIX_PATH` | Pin explicitly in flake inputs |
| Bare URLs | RFC 45 deprecation | Quote all URLs: `"https://..."` |
| `//` for nested updates | Shallow merge loses nested data | Use `lib.recursiveUpdate` |
| Hardcoded store paths | Non-reproducible | Use package references |
| Missing type annotations | Validation failures | Always specify `type` in `mkOption` |

### 6. Flake Patterns

From [Flakes documentation](https://wiki.nixos.org/wiki/Flakes):

**Input Patterns**:
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Follow pattern for consistency
  home-manager.url = "github:nix-community/home-manager";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";

  # Non-flake input
  neovim-config = {
    url = "github:user/config";
    flake = false;
  };
};
```

**Output Schema**:
```nix
outputs = { self, nixpkgs, ... }@inputs: {
  nixosConfigurations."hostname" = nixpkgs.lib.nixosSystem { ... };
  homeConfigurations."user" = home-manager.lib.homeManagerConfiguration { ... };
  packages."x86_64-linux".default = derivation;
  devShells."x86_64-linux".default = derivation;
  overlays.default = final: prev: { ... };
};
```

### 7. Naming Conventions

| Entity | Convention | Examples |
|--------|------------|----------|
| Package names | lowercase with hyphens | `my-package`, `claude-code` |
| Options paths | dot-separated | `services.myService.enable` |
| Variables | snake_case | `cfg`, `pkgs_unstable`, `my_overlay` |
| Attribute names | camelCase (nixpkgs convention) | `buildInputs`, `extraGroups` |
| Module arguments | lowercase | `config`, `lib`, `pkgs` |
| Overlay variables | conventional: `final`, `prev` | (formerly `self`, `super`) |

### 8. Path Pattern for Auto-Application

Recommended path pattern for `.claude/rules/nix.md`:
```yaml
---
paths: ["**/*.nix", "flake.nix", "flake.lock"]
---
```

This covers:
- All `.nix` files recursively
- Explicit `flake.nix` mention for visibility
- `flake.lock` for lock file awareness (read-only)

## Recommendations

### Recommended nix.md Structure

```markdown
---
paths: ["**/*.nix"]
---

# Nix Development Rules

## Path Pattern
Applies to: `**/*.nix`

## Formatting Standards
### Indentation and Layout
### Line Length
### Expression Formatting

## Module Patterns
### NixOS Modules
### Home Manager Modules
### Standard Function Signatures

## Flake Conventions
### Input Patterns
### Output Schema
### Overlay Patterns

## Naming Conventions
### Packages and Derivations
### Options and Variables

## Common Patterns
### Conditional Configuration
### Package Overrides

## Testing and Verification
### Build Commands
### Evaluation Checks

## Do Not
[List of anti-patterns]

## Related Context
[@-references to context files]
```

### Key Rules to Include

1. **Formatting**: 2-space indentation, 100-char soft limit, nixfmt compliance
2. **Module structure**: Standard `{ config, lib, pkgs, ... }:` signature
3. **Options**: Always use types, descriptions, defaults
4. **Anti-patterns**: Avoid `with pkgs;`, `rec {}`, lookup paths
5. **Overlays**: Use `final`/`prev` naming
6. **Flakes**: Document input following, output schema
7. **Testing**: `nix flake check`, `nixos-rebuild build`, `home-manager build`

## References

- [nixfmt standard.md](https://github.com/NixOS/nixfmt/blob/master/standard.md) - Official formatting rules
- [RFC 166](https://github.com/NixOS/rfcs/pull/166) - Nix formatting RFC
- [nix.dev best practices](https://nix.dev/guides/best-practices.html) - Official best practices
- [NixOS Wiki - Modules](https://wiki.nixos.org/wiki/NixOS_modules) - Module documentation
- [NixOS Wiki - Flakes](https://wiki.nixos.org/wiki/Flakes) - Flakes documentation
- [NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/) - Comprehensive guide

## Next Steps

Run `/plan 6` to create an implementation plan for the nix.md rules file based on this research.
