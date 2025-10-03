# CVC5 Python Bindings Implementation Plan

## Metadata
- **Date**: 2025-10-02
- **Feature**: Add CVC5 Python bindings via custom Nix overlay
- **Scope**: Create declarative, reproducible CVC5 Python package for Home Manager
- **Estimated Phases**: 5
- **Estimated Time**: 30-45 minutes
- **Complexity**: Medium
- **Standards File**: `/home/benjamin/.dotfiles/CLAUDE.md`
- **Research Reports**:
  - `specs/reports/011_cvc5_nixos_installation_strategy.md` (Option 1)

## Overview

Implement Option 1 from the CVC5 installation strategy report: create a custom Python package overlay that builds CVC5 Python bindings (v1.3.1) from PyPI wheels and integrates them into the existing Home Manager Python environment.

### Current State
- ✅ CVC5 binary v1.2.0 installed system-wide (`configuration.nix:246`)
- ✅ Python 3.12 environment with multiple packages (`home.nix:132-163`)
- ✅ Existing overlay pattern (`flake.nix:46-89`)
- ❌ No Python bindings for CVC5 (causes `ModuleNotFoundError`)

### Desired State
- ✅ CVC5 Python bindings v1.3.1 available system-wide
- ✅ Fully declarative Nix package definition
- ✅ Integrated into Home Manager Python environment
- ✅ `LD_LIBRARY_PATH` configured for C++ dependencies
- ✅ ModelChecker project works without `shell.nix`

## Success Criteria
- [ ] `python3 -c "import cvc5; print(cvc5.__version__)"` outputs `1.3.1`
- [ ] Package definition in `packages/python-cvc5.nix`
- [ ] Overlay added to `home.nix`
- [ ] `cvc5` added to Python packages list in `home.nix:132`
- [ ] `LD_LIBRARY_PATH` set in `home.sessionVariables`
- [ ] Home Manager rebuild succeeds
- [ ] ModelChecker test runs without `shell.nix`
- [ ] Changes committed to git

## Technical Design

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ home.nix                                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ nixpkgs.overlays                                        │ │
│ │   └─> python312.packageOverrides                        │ │
│ │         └─> cvc5 = callPackage ./packages/python-cvc5  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ home.packages                                           │ │
│ │   └─> python312.withPackages                            │ │
│ │         └─> [ z3 cvc5 setuptools ... ]                  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ home.sessionVariables                                   │ │
│ │   └─> LD_LIBRARY_PATH = ${stdenv.cc.cc.lib}/lib        │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ packages/python-cvc5.nix                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ buildPythonPackage {                                    │ │
│ │   src = fetchPypi (wheel from PyPI)                     │ │
│ │   autoPatchelfHook (fix shared library paths)           │ │
│ │   postFixup (patch cvc5.libs/*.so RPATH)                │ │
│ │ }                                                        │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Package Definition** (`packages/python-cvc5.nix`)
   - Uses `buildPythonPackage` from nixpkgs
   - Fetches pre-built wheel from PyPI (v1.3.1)
   - Uses `autoPatchelfHook` to fix library dependencies
   - Patches RPATH for bundled `.so` files

2. **Python Overlay** (`home.nix`)
   - Overrides `python312.packageOverrides`
   - Makes `cvc5` available as `python312Packages.cvc5`
   - Allows use in `withPackages` alongside z3, pytest, etc.

3. **Library Path Configuration** (`home.nix`)
   - Sets `LD_LIBRARY_PATH` to include `libstdc++.so.6`
   - Required for CVC5's C++ native extensions

### Design Decisions

1. **Why Home Manager over configuration.nix?**
   - Matches existing pattern (Python in `home.nix:132`)
   - No sudo required for rebuilds
   - User-level isolation

2. **Why wheel format over source build?**
   - CVC5 wheel includes pre-built native libraries
   - Source build would require C++ compiler and CVC5 dev headers
   - Wheels are tested and stable

3. **Why overlay over direct pip install?**
   - Fully declarative and reproducible
   - Hash-verified downloads
   - Follows NixOS philosophy
   - See Report 011 Decision Matrix

## Implementation Phases

### Phase 1: Package Definition and Hash Retrieval [COMPLETED]
**Objective**: Create `packages/python-cvc5.nix` with correct SHA256 hash
**Complexity**: Low
**Files**: `packages/python-cvc5.nix`

Tasks:
- [x] Create `packages/python-cvc5.nix` with package definition
- [x] Run `nix-prefetch-url` to get SHA256 hash for CVC5 wheel
- [x] Replace `sha256-PLACEHOLDER` with actual hash
- [x] Verify file syntax with `nix-instantiate --parse`

**Package Definition**:
```nix
{ lib
, buildPythonPackage
, fetchPypi
, stdenv
, autoPatchelfHook
}:

buildPythonPackage rec {
  pname = "cvc5";
  version = "1.3.1";
  format = "wheel";

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    python = "py3";
    abi = "none";
    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
    sha256 = "sha256-PLACEHOLDER";  # Replace in this phase
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  autoPatchelfIgnoreMissingDeps = true;

  postFixup = ''
    # Patch bundled .so files to find libstdc++
    for lib in $out/lib/python*/site-packages/cvc5.libs/*.so*; do
      if [ -f "$lib" ]; then
        patchelf --set-rpath ${stdenv.cc.cc.lib}/lib:$(patchelf --print-rpath "$lib") "$lib" || true
      fi
    done
  '';

  pythonImportsCheck = [ "cvc5" ];

  meta = with lib; {
    description = "Python bindings for CVC5 SMT solver";
    homepage = "https://cvc5.github.io";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}
```

**Hash Retrieval Command**:
```bash
cd /home/benjamin/.dotfiles
nix-prefetch-url --unpack https://files.pythonhosted.org/packages/py3/c/cvc5/cvc5-1.3.1-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
```

**Testing**:
```bash
# Verify Nix syntax
nix-instantiate --parse packages/python-cvc5.nix

# Expected: Nix expression tree (no errors)
```

**Validation**:
- Package file exists at `packages/python-cvc5.nix`
- SHA256 hash is not "PLACEHOLDER"
- File parses without syntax errors

---

### Phase 2: Add Python Overlay to home.nix [COMPLETED]
**Objective**: Configure overlay to make `cvc5` available in `python312Packages`
**Complexity**: Low
**Files**: `home.nix`

Tasks:
- [x] Add `nixpkgs.overlays` section after imports (around line 7)
- [x] Create Python package override with `cvc5` package
- [x] Verify overlay syntax

**Overlay Configuration** (insert after line 7 in `home.nix`):
```nix
{ config, pkgs, pkgs-unstable, lectic, nix-ai-tools, ... }:

{
  # Import our custom modules
  imports = [
    # ./home-modules/mcp-hub.nix  # Disabled - using lazy.nvim approach
  ];

  # Add overlay for custom Python packages
  nixpkgs.overlays = [
    (self: super: {
      python312 = super.python312.override {
        packageOverrides = pySelf: pySuper: {
          cvc5 = pySelf.callPackage ./packages/python-cvc5.nix { };
        };
      };
    })
  ];

  # ... rest of home.nix ...
}
```

**Testing**:
```bash
# Dry-run to check for syntax errors
home-manager build --flake .#benjamin --dry-run
```

**Validation**:
- Overlay added to `home.nix` after imports
- Dry-run succeeds without errors
- No duplicate overlay definitions

---

### Phase 3: Add cvc5 to Python Packages List [COMPLETED]
**Objective**: Include `cvc5` in `python312.withPackages` in `home.nix:132`
**Complexity**: Low
**Files**: `home.nix`

Tasks:
- [x] Locate `python312.withPackages` block (line 132)
- [x] Add `cvc5` to package list (alphabetically after `build`)
- [x] Verify package list syntax

**Modified Python Packages Block** (`home.nix:132`):
```nix
(python312.withPackages(p: with p; [
  z3
  setuptools
  pyinstrument
  build
  cvc5              # ← ADD THIS LINE
  twine
  pytest
  pytest-cov
  pytest-timeout
  # model-checker  # don't install when in development
  tqdm
  pip
  pylatexenc
  pyyaml
  requests
  markdown
  jupyter
  jupyter-core
  notebook
  ipywidgets
  matplotlib
  networkx
  pynvim
  numpy
  # pylint
  # black
  # isort

  # Jupyter Notebooks
  jupytext
  ipython
]))
```

**Testing**:
```bash
# Dry-run to verify package resolution
home-manager build --flake .#benjamin --dry-run
```

**Validation**:
- `cvc5` added to package list
- Dry-run resolves package without errors
- List remains properly formatted

---

### Phase 4: Configure LD_LIBRARY_PATH [COMPLETED]
**Objective**: Set library path for CVC5 C++ dependencies
**Complexity**: Low
**Files**: `home.nix`

Tasks:
- [x] Locate `home.sessionVariables` block (line 410)
- [x] Add or update `LD_LIBRARY_PATH` variable
- [x] Ensure path includes `${pkgs.stdenv.cc.cc.lib}/lib`

**Session Variables Configuration** (`home.nix:410`):

**Option A**: If `LD_LIBRARY_PATH` doesn't exist, add it:
```nix
home.sessionVariables = {
  EDITOR = "nvim";
  NIXOS_OZONE_WL = "1";
  GMAIL_CLIENT_ID = "810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com";
  SASL_PATH = "/nix/store/ja75va5vkxrmm0y95gdzk04kxa0pmw1s-cyrus-sasl-xoauth2-0.2/lib/sasl2:/nix/store/f4spmcr74xb2zwin34n8973jj7ppn4bv-cyrus-sasl-2.1.28-bin/lib/sasl2";
  XCURSOR_THEME = "Adwaita";
  XCURSOR_SIZE = "24";
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";  # ← ADD THIS
};
```

**Option B**: If `LD_LIBRARY_PATH` exists, update it:
```nix
LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH";
```

**Testing**:
```bash
# Check variable will be set correctly
nix-instantiate --eval -E 'with import <nixpkgs> {}; stdenv.cc.cc.lib'
```

**Validation**:
- `LD_LIBRARY_PATH` configured in `home.sessionVariables`
- Path points to valid Nix store location
- Syntax is correct

---

### Phase 5: Rebuild, Test, and Verify [COMPLETED]
**Objective**: Build and verify CVC5 Python bindings are working
**Complexity**: Medium
**Files**: N/A (testing only)

Tasks:
- [x] Rebuild Home Manager configuration
- [x] Verify CVC5 imports successfully
- [x] Test CVC5 solver functionality
- [x] Test with ModelChecker project (optional)
- [x] Document package in `packages/README.md`

**Rebuild Command**:
```bash
cd /home/benjamin/.dotfiles
home-manager switch --flake .#benjamin
```

**Verification Tests**:

1. **Import Test**:
```bash
python3 -c "import cvc5; print('CVC5 version:', cvc5.__version__)"
# Expected output: CVC5 version: 1.3.1
```

2. **Solver Test**:
```bash
python3 -c "
import cvc5
solver = cvc5.Solver()
solver.setLogic('QF_LIA')
x = solver.mkConst(solver.getIntegerSort(), 'x')
solver.assertFormula(solver.mkTerm(cvc5.Kind.EQUAL, x, solver.mkInteger(42)))
result = solver.checkSat()
print('Solver result:', result)
print('x =', solver.getValue(x))
"
# Expected: Solver result: sat
#           x = 42
```

3. **Python Path Test**:
```bash
python3 -c "import sys, cvc5; print('CVC5 location:', cvc5.__file__)"
# Expected: /nix/store/.../python3.12/site-packages/cvc5/__init__.py
```

4. **Library Loading Test**:
```bash
python3 -c "
import cvc5
import ctypes
# This should not raise ImportError or OSError
print('Native library loaded successfully')
"
```

5. **ModelChecker Test** (if applicable):
```bash
# Navigate to ModelChecker project
cd /home/benjamin/Documents/Philosophy/Projects/ModelChecker

# Run CVC5 test (ensure it uses system Python, not venv)
python3 test_bm_cm_1_cvc5.py

# Expected: Test passes without shell.nix
```

**Documentation Update**:

Add to `packages/README.md`:
```markdown
## python-cvc5.nix

**Purpose**: Python bindings for CVC5 SMT solver v1.3.1

**Why Custom Package?**: Nixpkgs does not provide `python312Packages.cvc5`

**Source**: PyPI wheel (pre-built binaries)

**Dependencies**:
- `autoPatchelfHook`: Fixes shared library paths
- `stdenv.cc.cc.lib`: Provides `libstdc++.so.6`

**Usage**: Available in `python312.withPackages` via overlay in `home.nix`

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/cvc5/)
2. Get hash: `nix-prefetch-url --unpack https://files.pythonhosted.org/packages/py3/c/cvc5/cvc5-VERSION-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`
3. Update `version` and `sha256` in `python-cvc5.nix`
4. Rebuild: `home-manager switch --flake .#benjamin`
5. Test: `python3 -c "import cvc5; print(cvc5.__version__)"`

**Related**: Report 011 (CVC5 installation strategy)
```

**Testing**:
All verification tests pass

**Validation**:
- [ ] Home Manager rebuild succeeds
- [ ] Python import test passes
- [ ] Solver functionality test passes
- [ ] CVC5 version is 1.3.1
- [ ] Native libraries load without errors
- [ ] `packages/README.md` updated

---

## Testing Strategy

### Unit Testing
- **Package Build**: `nix-build -E 'with import <nixpkgs> {}; python312Packages.callPackage ./packages/python-cvc5.nix {}'`
- **Import Check**: Built-in `pythonImportsCheck = [ "cvc5" ]`

### Integration Testing
- **Home Manager Dry-Run**: `home-manager build --flake .#benjamin --dry-run`
- **Full Rebuild**: `home-manager switch --flake .#benjamin`

### Functional Testing
- **Python Import**: `python3 -c "import cvc5"`
- **Solver Test**: Create solver, assert formula, check SAT
- **Library Loading**: Verify native `.so` files load

### Regression Testing
- **ModelChecker**: Run existing CVC5-based tests
- **Z3 Compatibility**: Ensure z3 still works (no overlay conflicts)

## Rollback Plan

If the implementation fails or causes issues:

### Quick Rollback (Revert Changes)
```bash
cd /home/benjamin/.dotfiles
git checkout home.nix packages/python-cvc5.nix
home-manager switch --flake .#benjamin
```

### Fallback to pip (Temporary)
```bash
# If you need CVC5 immediately while debugging
pip install --user cvc5==1.3.1
export LD_LIBRARY_PATH=/nix/store/$(nix-build '<nixpkgs>' -A stdenv.cc.cc.lib --no-out-link | cut -d/ -f4)/lib
```

### Remove Package from Overlay
Edit `home.nix`, comment out overlay:
```nix
# nixpkgs.overlays = [
#   (self: super: {
#     python312 = super.python312.override {
#       packageOverrides = pySelf: pySuper: {
#         cvc5 = pySelf.callPackage ./packages/python-cvc5.nix { };
#       };
#     };
#   })
# ];
```

And remove `cvc5` from Python packages list.

## Common Issues and Solutions

### Issue: SHA256 hash mismatch during build
**Cause**: Incorrect hash in `python-cvc5.nix`
**Solution**: Re-run `nix-prefetch-url` and copy exact output

### Issue: `autoPatchelfHook` warnings about missing libraries
**Cause**: CVC5 wheel has bundled libraries with references to system libs
**Solution**: Already handled by `autoPatchelfIgnoreMissingDeps = true`

### Issue: `ImportError: libstdc++.so.6: cannot open shared object file`
**Cause**: `LD_LIBRARY_PATH` not set or incorrect
**Solution**: Verify `home.sessionVariables.LD_LIBRARY_PATH` points to `${pkgs.stdenv.cc.cc.lib}/lib`

### Issue: Home Manager rebuild fails with "cvc5 not found"
**Cause**: Overlay not applied before package use
**Solution**: Ensure overlay is defined **before** `home.packages` in `home.nix`

### Issue: CVC5 imports but solver returns "unknown"
**Cause**: Solver options not configured (not a Nix issue)
**Solution**: Set `mbqi` and `enum-inst` options (see Report 011 Critical Configuration)

## Documentation Requirements

### Files to Update

1. **`packages/README.md`** (Phase 5)
   - Add section for `python-cvc5.nix`
   - Document update process
   - Link to Report 011

2. **`docs/packages.md`** (if exists)
   - Add CVC5 to Python packages section
   - Note custom packaging reason

3. **ModelChecker README** (optional, if migrating from shell.nix)
   - Remove `shell.nix` instructions
   - Reference system-wide CVC5 installation
   - Link to dotfiles configuration

### Commit Messages

Follow conventional commit format from `CLAUDE.md`:

**Phase 1**:
```
feat(packages): add CVC5 Python bindings package definition

Create custom Nix package for CVC5 v1.3.1 Python bindings using
PyPI wheel. Package uses autoPatchelfHook to fix shared library
paths for bundled native extensions.

Related: specs/reports/011_cvc5_nixos_installation_strategy.md
```

**Phase 2-4**:
```
feat(home): integrate CVC5 Python bindings via overlay

Add Python package overlay in home.nix to make cvc5 available
in python312Packages. Include in withPackages list and configure
LD_LIBRARY_PATH for C++ library dependencies.

Related: specs/plans/009_cvc5_python_bindings_overlay.md
```

**Phase 5**:
```
docs(packages): document CVC5 Python bindings installation

Update packages/README.md with CVC5 installation details,
update process, and troubleshooting notes.

Closes: specs/plans/009_cvc5_python_bindings_overlay.md
```

## Dependencies

### External Dependencies
- **PyPI**: CVC5 wheel download (internet required during build)
- **Nix**: `nix-prefetch-url` tool
- **Home Manager**: `home-manager` command

### Package Dependencies (in `python-cvc5.nix`)
- `buildPythonPackage` (from nixpkgs)
- `fetchPypi` (from nixpkgs)
- `autoPatchelfHook` (from nixpkgs)
- `stdenv.cc.cc.lib` (for `libstdc++.so.6`)

### Configuration Dependencies
- Existing Python 3.12 installation
- Home Manager configuration (`home.nix`)
- Flake configuration (`flake.nix`)

## Notes

### Why This Approach?

From Report 011:
> Option 1 (Custom Overlay) is the best fit for your configuration and requirements.

Rationale:
1. **Consistency**: Matches your existing Python package pattern (`home.nix:132`)
2. **Declarative**: Fully managed by Nix (no manual pip installs)
3. **Reproducible**: Hash-verified builds
4. **Maintainable**: Easy updates (version + hash change)
5. **No sudo**: Home Manager rebuild only

### Alternative Considered: pip --user

Rejected because:
- Not declarative (lost on system rebuild)
- No version pinning or hash verification
- Violates NixOS philosophy
- Can break after Nix garbage collection

If you need CVC5 **immediately**, use `pip install --user cvc5` temporarily and implement this plan later.

### Future Enhancements

1. **Upstream to nixpkgs**: Consider submitting `python-cvc5.nix` as a pull request to nixpkgs
2. **Version automation**: Script to check for new CVC5 versions on PyPI
3. **Multi-platform support**: Add Darwin (macOS) support if needed
4. **Source build option**: Alternative package that builds from source instead of wheel

### Related Work

- **Report 011**: CVC5 installation strategy analysis
- **Report 013** (ModelChecker): Original CVC5 installation research
- **claude-code.nix**: NPX wrapper pattern (different approach)
- **flake.nix overlays**: Existing overlay examples (claude-squad, unstable packages)

### Estimated Time Breakdown

- **Phase 1**: 10-15 minutes (create package, get hash)
- **Phase 2**: 5 minutes (add overlay)
- **Phase 3**: 2 minutes (add to package list)
- **Phase 4**: 3 minutes (configure LD_LIBRARY_PATH)
- **Phase 5**: 10-15 minutes (rebuild, test, document)

**Total**: 30-40 minutes (excluding potential debugging)
