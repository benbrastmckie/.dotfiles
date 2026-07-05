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
NPX wrapper for Claude Code that fetches the latest version from NPM on each invocation. Also sets the default Opus model via `ANTHROPIC_DEFAULT_OPUS_MODEL`.

**Implementation**: Uses `writeShellScriptBin` to create a wrapper that runs `npx @anthropic-ai/claude-code@latest`

**Updating**: To pin a specific version, replace `@latest` with `@X.Y.Z`. After any change, rebuild with `sudo nixos-rebuild switch` (and `home-manager switch` or `./scripts/update.sh`). The npx cache (`~/.npm/_npx/`) may serve a stale version — delete it to force a fresh download.

### opencode-discord-bot.nix
`buildPythonApplication` derivation for the Nextcord Discord bot relay that bridges Discord to a headless OpenCode agent server (task 89) — the first `buildPythonApplication` in this repo (the other Python packages here, e.g. `python-cvc5.nix`, `pymupdf4llm.nix`, `python-vosk.nix`, are libraries built with `buildPythonPackage` and composed into environments via `python3.withPackages`).

**Implementation**: Builds from the in-tree source at `../opencode-discord-bot` (PEP 621 `pyproject.toml` + `setuptools` backend), producing an `opencode-discord-bot` console script. `callPackage`d directly in `modules/system/optional/discord-bot.nix` — **not** routed through `overlays/python-packages.nix`, since that overlay is scoped to library overrides composed via `python3.withPackages`, an architecturally different consumer than a standalone application with its own entry point.

**Runtime**: The `discord-bot` systemd service runs `${opencodeDiscordBot}/bin/opencode-discord-bot` directly (no working-tree `PYTHONPATH` import). Session state is persisted under a systemd `StateDirectory` (`/var/lib/discord-bot`, `SESSION_STORE_PATH=%S/discord-bot/sessions.json`) rather than a nix-store-relative path, since the nix store is read-only at runtime.

**Future work**: extracting `opencode-discord-bot/` to its own repository (consumed as a flake input) is documented — but not implemented — as a header comment in `opencode-discord-bot.nix`, mirroring the email extension's wrapper-binary/own-source precedent. The current in-tree `src = ../opencode-discord-bot` shape is the deliberate near-term choice.

**See**: `docs/discord-bot.md`, `specs/089_opencode_discord_bot_packaging/`

### marker-pdf.nix
UV wrapper for marker-pdf that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing PDF to markdown conversion capabilities.

**Implementation**: Uses `writeShellScriptBin` with `uv run` to execute marker-pdf in an isolated environment

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Isolated environment prevents dependency conflicts
- Handles complex dependencies (PyTorch, etc.) automatically

**Usage**: Available as `marker_pdf` command after home-manager rebuild.

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

### vosk-models.nix
Declarative Vosk STT language model package for reproducible installations. Downloads the small English US model (~50MB) from alphacephei.com.

**Implementation**: Uses `fetchzip` to download and extract the model archive, then installs to the Nix store with `stripRoot = false` to preserve directory structure. Home-manager symlinks to `~/.local/share/vosk/vosk-model-small-en-us-0.15/`.

**Adding more languages**: Create additional derivations for other language models from https://alphacephei.com/vosk/models.

**Update Process**:
1. Check for new models on https://alphacephei.com/vosk/models
2. Update URL and version
3. Rebuild to get new hash, update hash in the file
4. Rebuild: `home-manager switch --flake .#benjamin`

### piper-bin.nix
Prebuilt Linux x86_64 binary for Piper TTS (rhasspy/piper release `2023.11.14-2`), fetched with
`fetchurl` instead of building nixpkgs' `piper-tts` from source. The release tarball bundles a
precompiled `libonnxruntime.so.1.14.1`, so `onnxruntime` is never compiled (task 70; task 62
originally dropped Piper for this reason, but the source-compile is avoidable via a prebuilt
binary). Upstream repo was archived 2025-10-06; this is the final release.

**Implementation**: `stdenvNoCC.mkDerivation` + `autoPatchelfHook`, flat-installs the tarball's
own `piper`/`espeak-ng`/`piper_phonemize` binaries and bundled `.so` siblings into `$out/bin/`
(matches the tarball layout so `espeak-ng-data/` resolves relative to the binary path at
runtime). Only external runtime dependency beyond glibc is `libstdc++.so.6`
(`buildInputs = [ stdenv.cc.cc.lib ]`).

**Update Process**:
1. `nix-prefetch-url --type sha256 <new-release-url>`
2. `nix hash to-sri --type sha256 <output>`
3. Update `version`/`url`/`hash` in `piper-bin.nix`

### piper-voices.nix
Declarative Piper voice model package for the `en_US-lessac-medium` neural voice. Downloads the
ONNX model and its JSON config from HuggingFace (`rhasspy/piper-voices`).

**Implementation**: Uses two `fetchurl` calls (model + config), copies both into `$out/`.
Home-manager symlinks to `~/.local/share/piper/`.

**Update Process**: Re-run `nix-prefetch-url --type sha256 <url>` against the model/config URLs
if HuggingFace content ever changes; update hashes accordingly.

### neovim.nix
A wrapper around Neovim unstable that fixes missing maintainers metadata to prevent build errors.

## MCPHub Integration

MCPHub is integrated as a standard Neovim plugin using lazy.nvim plugin loading.

### Implementation
MCPHub is loaded via lazy.nvim in the Neovim configuration with the following setup:
- Port: 37373
- Configuration: `~/.config/mcphub/servers.json`
- Integration with Avante for AI functionality

## Text-to-Speech and Speech-to-Text Setup

The system includes TTS and STT tools for Claude Code and Neovim integration.

### TTS: Piper (Custom Package)
Fast, local neural text-to-speech via a prebuilt Linux x86_64 release binary
(`piper-bin.nix`, fetchurl + autoPatchelfHook), restoring the natural
`en_US-lessac-medium` voice without compiling `onnxruntime` from source (task 70;
see `piper-bin.nix`/`piper-voices.nix` sections above).

**Test**:
```bash
echo "Hello, this is a test." | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file test.wav
aplay test.wav
```

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