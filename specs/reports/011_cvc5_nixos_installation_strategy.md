# CVC5 NixOS Installation Strategy Research Report

## Metadata
- **Date**: 2025-10-02
- **Scope**: Analyze best approach for system-wide CVC5 Python bindings installation
- **Primary Directory**: `/home/benjamin/.dotfiles`
- **Files Analyzed**: `configuration.nix:246`, `home.nix:132-163`, `flake.nix`, ModelChecker report `013_nixos_cvc5_system_installation.md`

## Executive Summary

Your NixOS configuration already has the **CVC5 binary** (v1.2.0) installed system-wide via `configuration.nix:246`, but **lacks Python bindings** (verified by `ModuleNotFoundError: No module named 'cvc5'`). Nixpkgs does not provide pre-packaged CVC5 Python bindings, requiring a custom solution.

**Recommended Approach**: Add `cvc5` to your existing `python312.withPackages` in `home.nix:132` using a custom overlay that builds the Python bindings from PyPI.

This approach is:
- **Declarative**: Fully managed by Nix
- **Reproducible**: Version-pinned with hash verification
- **Consistent**: Follows your existing Python package pattern (z3, setuptools, etc.)
- **User-scoped**: Installed in Home Manager (no sudo required)

## Current State Analysis

### What You Already Have

1. **System-wide CVC5 binary** (`configuration.nix:246`)
   ```nix
   environment.systemPackages = with pkgs; [
     cvc5  # Modern SMT solver (v1.2.0)
   ];
   ```
   - ✅ Binary works: `/run/current-system/sw/bin/cvc5`
   - ❌ No Python bindings available

2. **Home Manager Python environment** (`home.nix:132-163`)
   ```nix
   (python312.withPackages(p: with p; [
     z3 setuptools pyinstrument build twine pytest
     pytest-cov pytest-timeout tqdm pip pylatexenc
     pyyaml requests markdown jupyter notebook
     ipywidgets matplotlib networkx pynvim numpy
     jupytext ipython
   ]))
   ```
   - Pattern already established for declarative Python packages
   - Uses `python312.withPackages` for reproducibility
   - Includes other SMT solver (z3) successfully

3. **Configuration Structure**
   - `flake.nix`: Manages inputs and overlays
   - `configuration.nix`: System-wide packages
   - `home.nix`: User-level packages via Home Manager
   - Existing overlays: `claude-squad`, `unstablePackagesOverlay`

### What's Missing

- **CVC5 Python bindings** (PyPI package `cvc5==1.3.1`)
- Nixpkgs does **not** provide `python312Packages.cvc5`
- Requires custom packaging or pip installation

## Options Considered

### Option 1: Custom Overlay in Home Manager (RECOMMENDED)

**Approach**: Create a custom Python package overlay for CVC5 bindings.

**Implementation**:

#### Step 1: Create `packages/python-cvc5.nix`

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
  format = "wheel";  # CVC5 provides pre-built wheels

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    python = "py3";
    abi = "none";
    platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
    sha256 = "sha256-PLACEHOLDER";  # Run nix-prefetch-url to get hash
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  # Fix RPATH for bundled shared libraries
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

#### Step 2: Get SHA256 Hash

```bash
cd /home/benjamin/.dotfiles
nix-prefetch-url --unpack https://files.pythonhosted.org/packages/py3/c/cvc5/cvc5-1.3.1-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
# Replace "sha256-PLACEHOLDER" with output
```

#### Step 3: Add Overlay to `home.nix`

```nix
{ config, pkgs, pkgs-unstable, lectic, nix-ai-tools, ... }:

{
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

  # Use the overlayed Python environment
  home.packages = with pkgs; [
    # ... existing packages ...
    (python312.withPackages(p: with p; [
      z3
      cvc5  # ← Add this line
      setuptools
      # ... rest of packages ...
    ]))
  ];
}
```

#### Step 4: Rebuild Home Manager

```bash
cd /home/benjamin/.dotfiles
home-manager switch --flake .#benjamin
```

**Verification**:
```bash
python3 -c "import cvc5; print('CVC5 version:', cvc5.__version__)"
# Expected: CVC5 version: 1.3.1
```

**Pros**:
- ✅ Fully declarative and reproducible
- ✅ Follows your existing Python package pattern
- ✅ Version-pinned with hash verification
- ✅ No manual pip installations
- ✅ Integrated with Home Manager
- ✅ Easy to update (just change version + hash)

**Cons**:
- ❌ Initial setup complexity (one-time)
- ❌ Requires understanding Nix packaging
- ❌ Must update hash when upgrading CVC5

**Maintenance Burden**: Low (after initial setup)

---

### Option 2: pip Install with Home Manager Activation Script

**Approach**: Use Report 013's Option 3 (Home Manager activation).

**Implementation**:

```nix
# home.nix
{
  home.packages = with pkgs; [
    (python312.withPackages (ps: with ps; [
      pip
      # ... existing packages ...
    ]))
  ];

  home.sessionVariables = {
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH";
  };

  home.activation.installCVC5 = config.lib.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.python312}/bin/pip install --user cvc5==1.3.1
  '';
}
```

**Pros**:
- ✅ Simple implementation
- ✅ No custom packaging required
- ✅ Quick to set up

**Cons**:
- ❌ **Not truly declarative** (pip state outside Nix)
- ❌ Activation scripts run every rebuild (slow)
- ❌ Can cause rebuild failures if PyPI is down
- ❌ No hash verification (less reproducible)
- ❌ `--user` pip packages may conflict with Nix
- ❌ Not idiomatic Nix (mixing imperative/declarative)

**Maintenance Burden**: Medium (fragile, non-idiomatic)

---

### Option 3: System-wide Installation (configuration.nix)

**Approach**: Install CVC5 Python bindings system-wide alongside the binary.

**Same as Option 1**, but in `configuration.nix`:

```nix
# configuration.nix
{
  environment.systemPackages = with pkgs; [
    cvc5  # Binary
    (python312.withPackages (ps: [ ps.cvc5 ]))  # Bindings
  ];

  environment.variables = {
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH";
  };
}
```

**Pros**:
- ✅ Same location as CVC5 binary (configuration.nix:246)
- ✅ Available to all users
- ✅ Fully declarative

**Cons**:
- ❌ Requires sudo to rebuild
- ❌ System-wide changes for single-user need
- ❌ Slower rebuild cycle
- ❌ Doesn't match your pattern (you use home.nix for Python)

**Maintenance Burden**: Low (but slower workflow)

---

### Option 4: pip --user (Manual, Non-Declarative)

**Approach**: One-time pip installation outside Nix.

```bash
pip install --user cvc5==1.3.1
```

Add to `home.nix`:
```nix
home.sessionVariables = {
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH";
};
```

**Pros**:
- ✅ Extremely simple
- ✅ No Nix expertise required

**Cons**:
- ❌ **Not declarative** (lost on system rebuild)
- ❌ Not reproducible
- ❌ Not tracked in version control
- ❌ Violates NixOS philosophy
- ❌ Can break after Nix GC

**Maintenance Burden**: High (manual tracking, fragile)

---

## Recommendation: Option 1 (Custom Overlay)

### Rationale

1. **Consistency with Existing Patterns**
   - You already use `python312.withPackages` in `home.nix:132`
   - You already have custom overlays (`claude-squad`, `unstablePackagesOverlay`)
   - Matches your declarative approach

2. **Best Practices Alignment**
   - Your `CLAUDE.md` emphasizes: "Fully declarative and reproducible"
   - Your project already uses overlays for custom packages
   - NPX wrapper pattern shows you value maintainability over complexity

3. **Practical Benefits**
   - **One-time setup**: Package definition doesn't change often
   - **Easy updates**: Just bump version + hash
   - **Version control**: Everything tracked in git
   - **Reproducible**: Hash-verified builds
   - **No sudo**: Home Manager rebuild only

### Alternative Recommendation (If Time-Constrained)

If you need CVC5 **immediately** and will circle back later:

**Temporary**: Use Option 4 (pip --user) to unblock ModelChecker work
**Long-term**: Implement Option 1 when you have time

This follows your NPX wrapper philosophy: pragmatism over purity when appropriate.

## Implementation Plan

### Phase 1: Create Package Definition (15 minutes)

1. Create `packages/python-cvc5.nix` (see Option 1 code above)
2. Get SHA256 hash:
   ```bash
   nix-prefetch-url --unpack https://files.pythonhosted.org/packages/py3/c/cvc5/cvc5-1.3.1-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
   ```
3. Update `sha256` in package file

### Phase 2: Add Overlay (5 minutes)

1. Add overlay to `home.nix` (after line 7):
   ```nix
   nixpkgs.overlays = [
     (self: super: {
       python312 = super.python312.override {
         packageOverrides = pySelf: pySuper: {
           cvc5 = pySelf.callPackage ./packages/python-cvc5.nix { };
         };
       };
     })
   ];
   ```

2. Add `cvc5` to `home.nix:132` Python packages list

3. Add `LD_LIBRARY_PATH` to `home.sessionVariables` (line 410):
   ```nix
   home.sessionVariables = {
     # ... existing vars ...
     LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
   };
   ```

### Phase 3: Build and Test (5 minutes)

```bash
cd /home/benjamin/.dotfiles
home-manager switch --flake .#benjamin
python3 -c "import cvc5; print('CVC5:', cvc5.__version__)"
```

### Phase 4: Update ModelChecker (2 minutes)

Test with ModelChecker project:
```bash
cd /home/benjamin/Documents/Philosophy/Projects/ModelChecker
python3 test_bm_cm_1_cvc5.py  # Should work without shell.nix
```

### Phase 5: Document and Clean Up (5 minutes)

1. Add entry to `docs/packages.md`:
   ```markdown
   ## Custom Python Packages

   ### CVC5 Python Bindings
   Location: `packages/python-cvc5.nix`
   Version: 1.3.1
   Reason: Not available in nixpkgs; built from PyPI wheel
   ```

2. Remove `shell.nix` from ModelChecker if present

**Total Time**: ~30 minutes

## Critical Configuration Notes

### CVC5 Solver Options (From Report 013)

When using CVC5 Python bindings, ensure these options are set:

```python
solver = cvc5.Solver()
solver.setLogic("ALL")
solver.setOption("produce-models", "true")
solver.setOption("mbqi", "true")        # CRITICAL for witness predicates
solver.setOption("enum-inst", "true")   # CRITICAL for witness predicates
```

Without `mbqi` and `enum-inst`, CVC5 returns "unknown" for witness predicate problems.

### Library Path Requirements

The `LD_LIBRARY_PATH` must include `libstdc++.so.6` for CVC5's C++ bindings:

```nix
home.sessionVariables = {
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
};
```

This is **critical** for the Python module to load.

## Migration from shell.nix

Once system-wide installation is complete:

1. ✅ Remove `shell.nix` from ModelChecker project
2. ✅ Remove `venv/` directory
3. ✅ Update ModelChecker README to reference system installation
4. ✅ Verify tests run without `nix-shell`

## Future Considerations

### When to Update CVC5

CVC5 releases follow semantic versioning. Update when:
- Major version (e.g., 2.0.0): Review breaking changes
- Minor version (e.g., 1.4.0): New features, likely safe
- Patch version (e.g., 1.3.2): Bug fixes, always safe

Update process:
```bash
# 1. Check new version on PyPI
# 2. Download new wheel and get hash
nix-prefetch-url --unpack https://files.pythonhosted.org/packages/py3/c/cvc5/cvc5-NEW_VERSION-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

# 3. Update packages/python-cvc5.nix
#    - version = "NEW_VERSION";
#    - sha256 = "NEW_HASH";

# 4. Rebuild
home-manager switch --flake .#benjamin

# 5. Test
python3 -c "import cvc5; print(cvc5.__version__)"
```

### Alternative: Switch to NPX-Style Wrapper

If CVC5 updates become too frequent (unlikely for SMT solvers), consider an NPX-style approach:

```nix
# packages/cvc5-python.nix
{ writeShellScriptBin, python312 }:

writeShellScriptBin "cvc5-python" ''
  exec ${python312}/bin/python -m pip install --user cvc5 --upgrade
  exec ${python312}/bin/python "$@"
''
```

**Not recommended** because:
- SMT solvers change slowly (CVC5 1.3.1 released months ago)
- Breaking changes in solvers are rare but impactful
- Version pinning is important for reproducible proofs

## References

### Local Files
- Report: `/home/benjamin/Documents/Philosophy/Projects/ModelChecker/specs/reports/013_nixos_cvc5_system_installation.md`
- Config: `/home/benjamin/.dotfiles/configuration.nix:246`
- Home: `/home/benjamin/.dotfiles/home.nix:132-163`
- Flake: `/home/benjamin/.dotfiles/flake.nix`

### External Resources
- [CVC5 Python API Docs](https://cvc5.github.io/docs/cvc5-1.3.1/api/python/python.html)
- [CVC5 PyPI Package](https://pypi.org/project/cvc5/)
- [Nixpkgs Python Documentation](https://nixos.org/manual/nixpkgs/stable/#python)
- [Nixpkgs Python Overlay Guide](https://nixos.wiki/wiki/Python#Overriding_Python_packages)

### Related NixOS Patterns in Your Config
- Custom package overlay: `flake.nix:46-77` (claude-squad)
- Unstable packages overlay: `flake.nix:79-89`
- Python withPackages: `home.nix:132-163`
- NPX wrapper pattern: `packages/claude-code.nix`

## Appendix: Troubleshooting

### Issue: `ModuleNotFoundError: No module named 'cvc5'`

**Causes**:
1. CVC5 not in Python path
2. Wrong Python interpreter
3. Failed build

**Debug**:
```bash
# Check Python site-packages
python3 -c "import sys; print('\n'.join(sys.path))"

# Check if cvc5 is in Nix profile
ls $(nix-build '<nixpkgs>' -A python312Packages.cvc5)/lib/python*/site-packages/
```

### Issue: `ImportError: libstdc++.so.6: cannot open shared object file`

**Cause**: `LD_LIBRARY_PATH` not set

**Fix**: Ensure `home.sessionVariables.LD_LIBRARY_PATH` includes `${pkgs.stdenv.cc.cc.lib}/lib`

### Issue: Build fails with hash mismatch

**Cause**: Incorrect SHA256 hash

**Fix**: Re-run `nix-prefetch-url` and copy the output exactly

### Issue: `autoPatchelfHook` warnings

**Cause**: CVC5 wheel has pre-built binaries

**Solution**: Add `autoPatchelfIgnoreMissingDeps = true;` (already in recommended config)

## Decision Matrix

| Criterion              | Option 1 (Overlay) | Option 2 (Activation) | Option 3 (System) | Option 4 (pip) |
|------------------------|--------------------|-----------------------|-------------------|----------------|
| Declarative            | ✅ Yes             | ⚠️ Partial           | ✅ Yes            | ❌ No          |
| Reproducible           | ✅ Yes             | ⚠️ Partial           | ✅ Yes            | ❌ No          |
| Follows your patterns  | ✅ Yes             | ⚠️ Partial           | ❌ No             | ❌ No          |
| Easy to update         | ✅ Yes             | ✅ Yes               | ✅ Yes            | ✅ Yes         |
| No sudo required       | ✅ Yes             | ✅ Yes               | ❌ No             | ✅ Yes         |
| Version controlled     | ✅ Yes             | ✅ Yes               | ✅ Yes            | ❌ No          |
| Setup complexity       | ⚠️ Medium         | ✅ Low               | ⚠️ Medium         | ✅ Low         |
| Maintenance burden     | ✅ Low             | ⚠️ Medium            | ✅ Low            | ❌ High        |
| NixOS philosophy       | ✅ Excellent       | ⚠️ Acceptable        | ✅ Excellent      | ❌ Poor        |

**Verdict**: Option 1 (Custom Overlay) is the best fit for your configuration and requirements.
