# Custom Packages

This directory contains custom package definitions and configurations for the NixOS setup.

## Files

### aristotle.nix
UVX wrapper for Aristotle AI theorem prover that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing access to Aristotle's automated theorem proving capabilities with Lean.

**Implementation**: Uses `writeShellScriptBin` to create a simple wrapper that executes `uvx --from aristotlelib@latest aristotle`

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Uses existing uv installation
- Integrated with Lean theorem prover
- Provides system-wide `aristotle` command

**Usage**:
```bash
aristotle --help
aristotle prove-from-file your_lean_file.lean
aristotle --api-key YOUR_API_KEY prove-from-file theorem.lean
```

**API Key**: Can be set via `ARISTOTLE_API_KEY` environment variable or `--api-key` flag

**Documentation**: Visit https://aristotle.harmonic.fun for more information

### claude-code.nix
NPX wrapper for Claude Code that automatically uses the latest version from NPM registry. This zero-maintenance approach eliminates the need for manual version updates and hash calculations while providing access to all Claude Code 2.0+ features.

**Implementation**: Uses `writeShellScriptBin` to create a simple wrapper that executes `npx @anthropic-ai/claude-code@latest`

**Benefits**:
- Automatic updates to latest version
- Zero maintenance required
- 86% reduction in code complexity compared to traditional Nix packaging
- Offline support via NPX caching

### markitdown.nix
UV wrapper for markitdown that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing document to markdown conversion capabilities.

**Implementation**: Uses `writeShellScriptBin` with `uv run` to execute markitdown in an isolated environment

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Isolated environment prevents dependency conflicts
- Handles PDF, DOCX, PPTX, and other document formats

**Usage**: Available as `markitdown` command after home-manager rebuild.

### marker-pdf.nix
UV wrapper for marker-pdf that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing PDF to markdown conversion capabilities.

**Implementation**: Uses `writeShellScriptBin` with `uv run` to execute marker-pdf in an isolated environment

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Isolated environment prevents dependency conflicts
- Handles complex dependencies (PyTorch, etc.) automatically

**Usage**: Available as `marker_pdf` command after home-manager rebuild.

### markitdown.nix
UV wrapper for markitdown that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing document to markdown conversion capabilities.

**Implementation**: Uses `writeShellScriptBin` with `uv run` to execute markitdown in an isolated environment

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Isolated environment prevents dependency conflicts
- Handles PDF, DOCX, PPTX, and other document formats

**Usage**: Available as `markitdown` command after home-manager rebuild.

### loogle.nix
Wrapper script for the Lean 4 Mathlib search tool that provides lazy installation and caching.

**Implementation**: Uses `writeShellScriptBin` to create a wrapper that:
1. Clones loogle repository to `~/.cache/loogle/` on first run
2. Builds loogle using `nix develop` with the Lean toolchain
3. Runs loogle CLI with all arguments passed through

**First Run Setup**:
- Downloads Lean 4 toolchain (~484 MB)
- Clones loogle repository (~331 KB)
- Downloads and caches Mathlib (~7729 files)
- Builds loogle (~1-2 minutes)

**Subsequent Runs**: Instant execution using cached build

**Benefits**:
- Zero maintenance - always uses latest Lean/Mathlib
- Lazy installation - only downloads when first used
- Isolated environment via Nix development shell
- Reproducible builds

**Usage**: 
```bash
loogle 'List.map'              # Search by name
loogle '(List ?a -> ?a)'       # Search by type signature
loogle --interactive           # Interactive mode
loogle --help                  # Show all options
```

**Cache Location**: `~/.cache/loogle/` and `~/.elan/`

**Reset/Update**: `rm -rf ~/.cache/loogle && loogle` to rebuild

See [Development Guide](../docs/development.md#lean-4-development) for detailed usage examples.

### python-cvc5.nix
Custom Python package for CVC5 v1.3.1 SMT solver bindings. Nixpkgs does not provide `python312Packages.cvc5`, so this package builds from the PyPI wheel.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pre-built manylinux wheel, then uses `autoPatchelfHook` to fix shared library paths for the bundled native C++ extensions.

**Dependencies**:
- `autoPatchelfHook`: Automatically fixes shared library paths
- `stdenv.cc.cc.lib`: Provides `libstdc++.so.6` for C++ bindings

**Usage**: Available in `python312.withPackages` via the `pythonPackagesOverlay` defined in `flake.nix`:

```nix
home.packages = with pkgs; [
  (python312.withPackages(p: with p; [
    cvc5
    # ... other packages
  ]))
];
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/cvc5/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/.../cvc5-VERSION-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl`
3. Update `version` and `sha256` in `python-cvc5.nix`
4. Commit changes and rebuild: `home-manager switch --flake .#benjamin`
5. Test: `python3 -c "import cvc5; print(cvc5.__version__)"`

**Related**:
- Report: `specs/reports/011_cvc5_nixos_installation_strategy.md`
- Plan: `specs/plans/009_cvc5_python_bindings_overlay.md`

## UVX/UV Wrapper Pattern

Several packages in this directory follow the same zero-maintenance pattern using UV for package management:

- **aristotle.nix**: `uvx --from aristotlelib@latest aristotle`
- **markitdown.nix**: `uv run markitdown`
- **marker-pdf.nix**: `uv run marker-pdf`

**Benefits of UVX Pattern**:
- Automatic updates to latest version from PyPI
- Zero maintenance required
- Uses existing uv installation
- Isolated environment prevents dependency conflicts
- Simple, lightweight wrapper implementation
- Consistent with modern Python packaging best practices

**Implementation Template**:
```nix
{ writeShellScriptBin, uv }:

writeShellScriptBin "package-name" ''
  exec ${uv}/bin/uvx --from package@latest command "$@"
''
```

### pymupdf4llm.nix
Custom Python package for PyMuPDF4LLM v0.2.2, a specialized extension of PyMuPDF for LLM-optimized PDF extraction. Converts PDFs to structured Markdown with preserved hierarchy.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pure Python wheel (`py3-none-any`).

**Dependencies**:
- `pymupdf`: Python bindings for MuPDF (from nixpkgs)
- `tabulate`: Pretty-print tabular data (from nixpkgs)

**Usage**: Available in `python312.withPackages` via the `pythonPackagesOverlay` defined in `flake.nix`:

```nix
home.packages = with pkgs; [
  (python312.withPackages(p: with p; [
    pymupdf4llm
    # ... other packages
  ]))
];
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/pymupdf4llm/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/py3/p/pymupdf4llm/pymupdf4llm-VERSION-py3-none-any.whl`
3. Convert hash: `nix hash to-sri --type sha256 HASH`
4. Update `version` and `hash` in `pymupdf4llm.nix`
5. Rebuild: `home-manager switch --flake .#benjamin`
6. Test: `python3 -c "import pymupdf4llm; print(pymupdf4llm.__version__)"`

### python-vosk.nix
Custom Python package for Vosk v0.3.45 - offline open source speech recognition API for STT (speech-to-text). Vosk is not available in nixpkgs.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pre-built manylinux wheel for x86_64 Linux. Uses `autoPatchelfHook` to fix shared library paths for the bundled native C++ library (`libvosk.so`).

**Dependencies**:
- `autoPatchelfHook`: Automatically fixes shared library paths for native libraries
- `stdenv.cc.cc.lib`: Provides `libstdc++.so.6` for C++ extensions
- `cffi`: C Foreign Function Interface
- `requests`: HTTP library
- `tqdm`: Progress bars
- `srt`: SubRip subtitle parser
- `websockets`: WebSocket support

**Usage**: Available in `python3.withPackages` via the `pythonPackagesOverlay` defined in `flake.nix`:

```nix
home.packages = with pkgs; [
  (python3.withPackages(p: with p; [
    vosk
    # ... other packages
  ]))
];
```

**Model Management**: Language models are declaratively managed via Nix (see `vosk-models.nix`). Models are automatically symlinked to `~/.local/share/vosk/vosk-model-small-en-us-0.15` after `home-manager switch`.

**Test**:
```python
import vosk
import os
model = vosk.Model(os.path.expanduser("~/.local/share/vosk/vosk-model-small-en-us-0.15"))
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/vosk/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/...`
3. Convert hash: `nix hash to-sri --type sha256 HASH`
4. Update `version` and `hash` in `python-vosk.nix`
5. Rebuild: `nixos-rebuild switch --flake .#HOSTNAME`
6. Test: `python3 -c "import vosk; print(vosk.__version__)"`

**Models**: https://alphacephei.com/vosk/models

**Related**:
- Research: `/home/benjamin/Projects/ProofChecker/specs/761_tts_stt_integration_for_claude_code_and_neovim/reports/research-001.md`

### piper-voices.nix
Declarative Piper TTS voice model package for reproducible installations. Downloads the en_US-lessac-medium voice model (medium quality, ~45MB) and JSON config from HuggingFace.

**Implementation**: Uses `fetchurl` to download both the ONNX model and JSON config, then installs them to the Nix store. Home-manager symlinks to `~/.local/share/piper/`.

**Adding more voices**: Create additional derivations or modify this file to download other voices from https://huggingface.co/rhasspy/piper-voices.

**Update Process**:
1. Check for new voice models on HuggingFace
2. Update URL and rebuild to get new hash
3. Update hash in the file
4. Rebuild: `home-manager switch --flake .#benjamin`

### vosk-models.nix
Declarative Vosk STT language model package for reproducible installations. Downloads the small English US model (~50MB) from alphacephei.com.

**Implementation**: Uses `fetchzip` to download and extract the model archive, then installs to the Nix store with `stripRoot = false` to preserve directory structure. Home-manager symlinks to `~/.local/share/vosk/vosk-model-small-en-us-0.15/`.

**Adding more languages**: Create additional derivations for other language models from https://alphacephei.com/vosk/models.

**Update Process**:
1. Check for new models on https://alphacephei.com/vosk/models
2. Update URL and version
3. Rebuild to get new hash, update hash in the file
4. Rebuild: `home-manager switch --flake .#benjamin`

### neovim.nix
A wrapper around Neovim unstable that fixes missing maintainers metadata to prevent build errors.

### test-mcphub.sh
A diagnostic script for verifying MCPHub installation and configuration in Neovim.

## MCPHub Integration

MCPHub is integrated as a standard Neovim plugin using lazy.nvim plugin loading.

### Implementation
MCPHub is loaded via lazy.nvim in the Neovim configuration with the following setup:
- Port: 37373
- Configuration: `~/.config/mcphub/servers.json`
- Integration with Avante for AI functionality

### Testing
Use `test-mcphub.sh` to verify MCPHub installation:

```bash
bash ~/.dotfiles/packages/test-mcphub.sh
```

The script checks:
- MCPHub binary accessibility
- Configuration directory and files
- Server functionality (optional)

## Text-to-Speech and Speech-to-Text Setup

The system includes TTS and STT tools for Claude Code and Neovim integration.

### TTS: Piper (System Package)
Fast, local neural text-to-speech with natural voice quality. Available in nixpkgs as `piper-tts`.

**Model Management**: Voice models are declaratively managed via Nix (see `piper-voices.nix`). The US English (Lessac, medium quality) voice is automatically symlinked to `~/.local/share/piper/` after `home-manager switch`.

**Test**:
```bash
echo "Hello, this is a test." | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file test.wav
aplay test.wav
```

**Available voices**: https://huggingface.co/rhasspy/piper-voices/tree/main

### STT: Vosk (Custom Package)
See `python-vosk.nix` section above for installation and setup.

### Audio Recording
The system includes PulseAudio client tools (`parecord`) for audio recording:

```bash
# Record 10 seconds at 16kHz (optimal for STT)
timeout 10s parecord --channels=1 --rate=16000 --file-format=wav recording.wav
```

### Integration Examples
- **Claude Code TTS notifications**: See research report for Stop hook implementation
- **Neovim STT**: See research report for Lua integration with `vim.fn.jobstart()`
- **Research**: `/home/benjamin/Projects/ProofChecker/specs/761_tts_stt_integration_for_claude_code_and_neovim/reports/research-001.md`

[← Back to main README](../README.md)