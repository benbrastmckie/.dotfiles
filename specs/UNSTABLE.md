# Managing Stable and Unstable Packages

This document outlines a plan for improving how we manage stable and unstable packages in our NixOS configuration, with a specific focus on migrating Neovim from the stable to the unstable channel while maintaining simplicity, elegance, and maintainability.

## Current Implementation Analysis

### How Packages Are Currently Managed

1. **Nixpkgs Inputs**:
   - Stable channel: `nixpkgs.url = "nixpkgs/nixos-24.11"`
   - Unstable channel: `nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"`

2. **Package Sets**:
   - Stable: `pkgs = nixpkgs.legacyPackages.${system}`
   - Unstable: `pkgs-unstable = import nixpkgs-unstable { inherit system; config = {...} }`

3. **Selective Unstable Package Usage**:
   - `pkgs-unstable` is passed as `extraSpecialArgs` to both system and home-manager modules
   - Currently used for specific packages: `pkgs-unstable.claude-code` in home.nix
   - System-level overlay for niri: `niri = pkgs-unstable.niri`

4. **Neovim Configuration**:
   - Currently using stable channel: `package = pkgs.neovim-unwrapped`

### Strengths of Current Approach

- Clear separation between stable and unstable channels
- Selective use of unstable packages where needed
- Package selection is explicit and visible

### Limitations of Current Approach

- No systematic approach for deciding which packages should use unstable
- Individual references to `pkgs-unstable` scattered throughout configuration
- Overlays are defined inline within system configuration rather than centralized
- No easy way to see which packages are pulled from unstable

## Proposed Implementation Plan

### 1. Create a Centralized Unstable Package Management System

#### Approach A: Centralized Overlay File

Create a dedicated file that defines all packages that should come from unstable:

```nix
# unstable-packages.nix
{ pkgs, pkgs-unstable }:

{
  # Development tools
  neovim = pkgs-unstable.neovim-unwrapped;
  
  # Applications
  niri = pkgs-unstable.niri;
  claude-code = pkgs-unstable.claude-code;
  
  # Add other packages that benefit from using unstable
}
```

This would be imported and used as an overlay:

```nix
# In flake.nix
nixpkgs.overlays = [
  (import ./unstable-packages.nix { inherit pkgs pkgs-unstable; })
];
```

#### Approach B: Declarative Unstable Package List

Create a list of package names that should come from unstable:

```nix
# unstable-packages.nix
[
  "neovim-unwrapped"
  "niri"
  "claude-code"
]
```

Then generate an overlay dynamically:

```nix
# In flake.nix
let
  unstablePackages = import ./unstable-packages.nix;
  unstableOverlay = final: prev: 
    builtins.listToAttrs (
      map (name: { 
        inherit name; 
        value = pkgs-unstable.${name}; 
      }) unstablePackages
    );
in {
  nixpkgs.overlays = [ unstableOverlay ];
}
```

### 2. Implementation Plan for Neovim Specifically

1. Add `neovim-unwrapped` to the centralized unstable package list
2. Update home-manager configuration to use the overlaid package:

```nix
# home.nix
programs.neovim = {
  enable = true;
  package = pkgs.neovim-unwrapped;  # This will now pull from unstable
};
```

### 3. Complete Implementation Steps

1. **Create Centralized Unstable Package Definition**:
   - Create `/home/benjamin/.dotfiles/unstable-packages.nix` using either Approach A or B
   - Include neovim-unwrapped, niri, claude-code, and any other desired unstable packages

2. **Update Flake Configuration**:
   - Modify `flake.nix` to import and apply the unstable packages overlay
   - Apply this overlay at the top level so it's available to both system and home-manager

3. **Update Home Manager Configuration**:
   - Keep the neovim configuration as is, since it will now use the unstable version through the overlay
   - Remove direct references to `pkgs-unstable.claude-code` in favor of `pkgs.claude-code` (which will use unstable via overlay)

4. **Update System Configuration**:
   - Remove the inline niri overlay as it will be handled by the centralized unstable package overlay

5. **Documentation**:
   - Add comments to unstable-packages.nix explaining the purpose of each unstable package choice
   - Update README.md to explain the unstable package management approach

## Comparison of Approaches

### Approach A: Centralized Overlay File

**Pros:**
- More flexibility to customize how each package is imported
- Can handle complex cases (e.g., packages that need special configuration)
- More explicit about what's happening with each package

**Cons:**
- More verbose
- Requires more knowledge of Nix overlays

### Approach B: Declarative Package List

**Pros:**
- More concise and easier to maintain
- Simpler to understand at a glance which packages use unstable
- Lower barrier to adding new unstable packages

**Cons:**
- Less flexible for packages requiring special handling
- Can't easily customize how packages are pulled from unstable

## Recommendation

**Recommend Approach A** for your setup because:

1. You already have experience with overlays based on your config
2. Your system has specialized packages like lectic that might need custom handling
3. It provides better documentation of why specific packages are using unstable
4. It offers more flexibility as your configuration grows

This approach maintains simplicity through centralization while providing the elegance of a well-documented, purpose-built overlay system and the maintainability of having unstable package definitions in one place.

## Next Steps After Implementation

1. **Testing**:
   - Build your configuration with the new approach
   - Verify that Neovim is using the unstable version
   - Check that other unstable packages still work as expected

2. **Maintenance Plan**:
   - Review unstable packages periodically to determine if they should move back to stable
   - Consider adding a comment with justification next to each unstable package
   - Consider automating a way to see which unstable packages have significant version differences