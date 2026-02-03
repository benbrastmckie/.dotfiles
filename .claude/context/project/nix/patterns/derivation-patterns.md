# Derivation Patterns

Building packages with Nix.

## Basic mkDerivation

```nix
{ lib, stdenv, fetchFromGitHub, cmake, openssl }:

stdenv.mkDerivation {
  pname = "mypackage";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v1.0.0";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ cmake ];  # Build-time tools
  buildInputs = [ openssl ];       # Libraries to link against

  meta = with lib; {
    description = "My package description";
    homepage = "https://example.com";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

## Build Phases

Standard phases in order:

1. **unpackPhase** - Extract source
2. **patchPhase** - Apply patches
3. **configurePhase** - Run ./configure or cmake
4. **buildPhase** - Compile (make)
5. **checkPhase** - Run tests
6. **installPhase** - Install to $out
7. **fixupPhase** - Post-processing

Override any phase:

```nix
stdenv.mkDerivation {
  # ...

  configurePhase = ''
    ./custom-configure --prefix=$out
  '';

  buildPhase = ''
    make -j$NIX_BUILD_CORES
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp myprogram $out/bin/
  '';
}
```

## Wrapper Scripts

Simple wrappers from this repository:

### packages/claude-code.nix

```nix
{ lib, writeShellScriptBin, nodejs }:

writeShellScriptBin "claude" ''
  exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''
```

### packages/loogle.nix

```nix
{ writeShellScriptBin }:

writeShellScriptBin "loogle" ''
  LOOGLE_DIR="$HOME/.cache/loogle"

  # First-time setup
  if [ ! -d "$LOOGLE_DIR" ]; then
    echo "==> First-time setup: Cloning loogle repository..."
    git clone https://github.com/nomeata/loogle.git "$LOOGLE_DIR"
    cd "$LOOGLE_DIR"
    echo "==> Building loogle (this may take a few minutes)..."
    nix develop . --command sh -c "lake exe cache get && lake build loogle"
  fi

  cd "$LOOGLE_DIR"
  nix develop . --command lake exe loogle "$@"
''
```

## Go Packages

Using `buildGoModule`:

```nix
{ lib, buildGoModule, fetchFromGitHub, tmux, gh }:

buildGoModule rec {
  pname = "claude-squad";
  version = "1.0.8";

  src = fetchFromGitHub {
    owner = "smtg-ai";
    repo = "claude-squad";
    rev = "v${version}";
    sha256 = "sha256-mzW9Z+QN4EQ3JLFD3uTDT2/c+ZGLzMqngl3o5TVBZN0=";
  };

  vendorHash = "sha256-BduH6Vu+p5iFe1N5svZRsb9QuFlhf7usBjMsOtRn2nQ=";

  nativeBuildInputs = [ go ];
  buildInputs = [ tmux gh ];

  postInstall = ''
    ln -s $out/bin/claude-squad $out/bin/cs
  '';

  meta = with lib; {
    description = "Terminal app that manages multiple AI terminal agents";
    homepage = "https://github.com/smtg-ai/claude-squad";
    license = licenses.agpl3Only;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
```

## Python Packages

### Using buildPythonPackage

```nix
{ lib, buildPythonPackage, fetchPypi, numpy }:

buildPythonPackage rec {
  pname = "mypackage";
  version = "1.0.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-...";
  };

  propagatedBuildInputs = [ numpy ];

  pythonImportsCheck = [ "mypackage" ];

  meta = with lib; {
    description = "My Python package";
    license = licenses.mit;
  };
}
```

### Custom Python Package

From packages/python-cvc5.nix pattern:

```nix
{ lib, buildPythonPackage, fetchurl, ... }:

buildPythonPackage rec {
  pname = "cvc5";
  version = "1.2.0";
  format = "wheel";

  src = fetchurl {
    url = "https://.../${pname}-${version}-py3-none-manylinux_2_17_x86_64.whl";
    sha256 = "sha256-...";
  };

  pythonImportsCheck = [ "cvc5" ];
}
```

## Fetchers

### fetchFromGitHub

```nix
src = fetchFromGitHub {
  owner = "owner";
  repo = "repo";
  rev = "v${version}";  # or commit hash
  sha256 = "sha256-...";
};
```

### fetchurl

```nix
src = fetchurl {
  url = "https://example.com/package-${version}.tar.gz";
  sha256 = "sha256-...";
};
```

### fetchgit

```nix
src = fetchgit {
  url = "https://git.example.com/repo.git";
  rev = "abc123...";
  sha256 = "sha256-...";
};
```

## Getting Hash Values

```bash
# For fetchFromGitHub
nix-prefetch-github owner repo --rev v1.0.0

# For fetchurl
nix-prefetch-url https://example.com/file.tar.gz

# Let Nix tell you (use fake hash first)
# Set sha256 = "" or sha256 = lib.fakeSha256
# Build will fail and show correct hash
```

## nativeBuildInputs vs buildInputs

| Attribute | Purpose | Examples |
|-----------|---------|----------|
| `nativeBuildInputs` | Build-time tools (run on build machine) | cmake, pkg-config, makeWrapper |
| `buildInputs` | Libraries to link against | openssl, zlib, curl |
| `propagatedBuildInputs` | Dependencies exposed to downstream | (for libraries) |

## Post-Processing

### makeWrapper

Add environment variables or paths:

```nix
{ makeWrapper, lib }:

stdenv.mkDerivation {
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/myprogram \
      --prefix PATH : ${lib.makeBinPath [ dep1 dep2 ]} \
      --set MY_VAR "value"
  '';
}
```

### Symlinks

```nix
postInstall = ''
  ln -s $out/bin/longname $out/bin/short
'';
```

## Debugging Builds

```bash
# Enter build environment
nix-shell -p mypackage

# Build with verbose output
nix build .#mypackage -L

# Keep failed build directory
nix build .#mypackage --keep-failed

# Show derivation
nix show-derivation .#mypackage
```
