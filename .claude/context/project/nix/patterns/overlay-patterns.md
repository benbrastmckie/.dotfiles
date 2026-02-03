# Overlay Patterns

Customize and extend the Nixpkgs package set.

## Basic Structure

```nix
final: prev: {
  # Your modifications here
}
```

- `final` (or `self`): The final package set after all overlays
- `prev` (or `super`): The package set before this overlay

## Add New Package

```nix
final: prev: {
  mypackage = final.callPackage ./mypackage.nix {};
}
```

Use `final.callPackage` to get dependencies from final set.

## Override Existing Package

Change build options:

```nix
final: prev: {
  vim = prev.vim.override {
    guiSupport = false;
    pythonSupport = true;
  };
}
```

Use `prev.vim` to reference the original package.

## Override Attributes

Modify derivation attributes:

```nix
final: prev: {
  hello = prev.hello.overrideAttrs (old: {
    version = "2.12";
    src = final.fetchFromGitHub {
      owner = "...";
      repo = "hello";
      rev = "v2.12";
      sha256 = "...";
    };
    # Can reference old attributes
    buildInputs = old.buildInputs ++ [ final.newdep ];
  });
}
```

## Real Examples from flake.nix

### Claude-Squad Overlay

Building a Go package:

```nix
claudeSquadOverlay = final: prev: {
  claude-squad = final.buildGoModule rec {
    pname = "claude-squad";
    version = "1.0.8";

    src = final.fetchFromGitHub {
      owner = "smtg-ai";
      repo = "claude-squad";
      rev = "v${version}";
      sha256 = "sha256-mzW9Z+QN4EQ3JLFD3uTDT2/c+ZGLzMqngl3o5TVBZN0=";
    };

    vendorHash = "sha256-BduH6Vu+p5iFe1N5svZRsb9QuFlhf7usBjMsOtRn2nQ=";

    nativeBuildInputs = with final; [ go ];
    buildInputs = with final; [ tmux gh ];

    postInstall = ''
      ln -s $out/bin/claude-squad $out/bin/cs
    '';
  };
};
```

### Unstable Packages Overlay

Mix stable and unstable packages:

```nix
unstablePackagesOverlay = final: prev: {
  # Use package from unstable channel
  niri = pkgs-unstable.niri;

  # Custom wrapper scripts
  claude-code = final.callPackage ./packages/claude-code.nix {};
  loogle = final.callPackage ./packages/loogle.nix {};

  # Override existing package
  kooha = import ./packages/kooha.nix prev.kooha final.gst_all_1;
};
```

### Python Packages Overlay

Add custom Python packages:

```nix
pythonPackagesOverlay = final: prev:
let
  customPythonPackages = pySelf: pySuper: {
    cvc5 = pySelf.callPackage ./packages/python-cvc5.nix {};
    vosk = pySelf.callPackage ./packages/python-vosk.nix {};
  };
in {
  python3 = prev.python3.override {
    packageOverrides = customPythonPackages;
  };
  python312 = prev.python312.override {
    packageOverrides = customPythonPackages;
  };
};
```

## Applying Overlays

### In flake.nix

```nix
let
  nixpkgsConfig = {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      overlay1
      overlay2
      overlay3
    ];
  };
  pkgs = import nixpkgs nixpkgsConfig;
in {
  nixosConfigurations.host = lib.nixosSystem {
    modules = [
      { nixpkgs = nixpkgsConfig; }
      ./configuration.nix
    ];
  };
}
```

### Order Matters

Overlays are applied in order:

```nix
overlays = [
  # First: base packages
  baseOverlay
  # Second: modifications (can reference base)
  modificationOverlay
  # Third: final adjustments
  finalOverlay
];
```

## final vs prev

Use **`final`** when:
- Getting dependencies for a new package
- Referencing packages that might be modified by later overlays

Use **`prev`** when:
- Overriding an existing package
- Accessing the "original" version before modification

```nix
final: prev: {
  # Use prev for the package being overridden
  vim = prev.vim.override { ... };

  # Use final for dependencies (gets latest version)
  mypackage = final.stdenv.mkDerivation {
    buildInputs = [ final.openssl ];  # Gets potentially-overlaid openssl
  };
}
```

## Debugging Overlays

```bash
# Check if package exists
nix eval .#nixosConfigurations.host.pkgs.mypackage.name

# Build package directly
nix build .#nixosConfigurations.host.pkgs.mypackage

# Show package derivation
nix show-derivation .#nixosConfigurations.host.pkgs.mypackage
```

## Common Patterns

### Wrapper Script

```nix
final: prev: {
  mycommand = final.writeShellScriptBin "mycommand" ''
    exec ${final.actualpackage}/bin/actual "$@"
  '';
}
```

### Pin to Specific Version

```nix
final: prev: {
  nodejs = prev.nodejs_18;  # Pin to Node.js 18
}
```

### Add Patches

```nix
final: prev: {
  package = prev.package.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./my-fix.patch
    ];
  });
}
```
