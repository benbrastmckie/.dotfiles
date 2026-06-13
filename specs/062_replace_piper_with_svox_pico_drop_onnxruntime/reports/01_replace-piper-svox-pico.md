# Research Report: Task #62

**Task**: 62 - Replace piper-tts with svox pico and drop onnxruntime
**Started**: 2026-06-12T17:20:00Z
**Completed**: 2026-06-12T17:45:00Z
**Effort**: ~2 hours implementation
**Dependencies**: None
**Sources/Inputs**: nixpkgs evaluation, local file reads, pico2wave CLI testing
**Artifacts**: - specs/062_replace_piper_with_svox_pico_drop_onnxruntime/reports/01_replace-piper-svox-pico.md
**Standards**: report-format.md

---

## Executive Summary

- nixpkgs attribute for svox pico is `pkgs.svox`; mainProgram is `pico2wave`; confirmed available in current nixpkgs unstable (version `0-unstable-2021-05-06`)
- `svox` has zero onnxruntime dependency: its only buildInput is `popt` (argument parser)
- `pico2wave` requires writing to a named .wav file — it cannot pipe to stdout; both aplay and paplay paths in `speak()` must use a temp-file approach
- `markitdown` imports `magika` unconditionally in `_markitdown.py` (not optional); `magika` depends on `onnxruntime`; the only safe path is **removing markitdown from home packages** and running it on-demand via `nix shell nixpkgs#python3Packages.markitdown`
- `espeak-ng` is listed as a piper dependency comment — after removing piper it is no longer needed and should be dropped
- The which-key.lua TTS toggle is **already disabled** (commented out since 2025-12-09); `TTS_ENABLED` env-var contract is still respected by tts-notify.sh and must be preserved
- 5 copies of tts-notify.sh span two repos; 4 are identical, 1 (`~/.config/nvim/.claude/hooks/tts-notify.sh`) adds a `TTS_COOLDOWN` feature that must be preserved
- Documentation spans 4 copies of `tts-stt-integration.md` and 4 copies of `neovim-integration.md`

---

## Context & Scope

The goal is to replace piper-tts (which pulls onnxruntime into the system closure) with the simpler svox pico (`pico2wave`) TTS engine. onnxruntime is a large ML inference library (~500 MB) with no benefit here. The second onnxruntime consumer is markitdown (via magika) in the Python environment. The task spans Nix configuration files in `~/.dotfiles` and shell hook scripts in both `~/.dotfiles` and `~/.config/nvim`.

---

## Findings

### Q1: Correct nixpkgs attribute for svox pico

**Attribute**: `pkgs.svox`  
**Version**: `0-unstable-2021-05-06`  
**mainProgram**: `pico2wave`  
**License**: Apache 2.0  
**Source**: forked from Android SVOX, maintained at `github.com/naggety/picotts`

Confirmed via `nix search nixpkgs svox` and `nix eval --json nixpkgs#svox.meta`. Also available as `pkgs.picotts` (a separate package that "improves pico2wave") and `pkgs.nanotts`. The canonical package for the stock `pico2wave` binary is `pkgs.svox`.

Related packages for reference:
- `pkgs.picotts` - text-to-speech from SVox (same underlying engine, different wrapper)
- `pkgs.nanotts` - commandline utility that improves pico2wave

Use `pkgs.svox` for a direct 1:1 replacement of the `pico2wave` binary.

### Q2: pico2wave command-line syntax

```bash
# Write to WAV file (required - cannot pipe to stdout)
pico2wave -w /tmp/output.wav "Your text here"
pico2wave --wave=/tmp/output.wav "Your text here"

# With language selection (default: en-US)
pico2wave -l en-US -w /tmp/output.wav "Your text here"

# Supported languages bundled in the Nix store (no external models needed):
# en-US, en-GB, de-DE, it-IT, es-ES, fr-FR

# Full pipeline for aplay:
pico2wave -w /tmp/tts-$$.wav "Tab 3 researched" && aplay -q /tmp/tts-$$.wav; rm -f /tmp/tts-$$.wav

# Full pipeline for paplay:
pico2wave -w /tmp/tts-$$.wav "Tab 3 researched" && paplay /tmp/tts-$$.wav; rm -f /tmp/tts-$$.wav
```

**Critical difference from piper**: pico2wave CANNOT write to stdout (`-w -` returns "Cannot open output wave file"). Both the paplay and aplay branches in `speak()` must use the temp-file pattern. The current dotfiles piper aplay branch uses `--output_file -` (stdout pipe) — this must change to the file-based approach.

Language data is **bundled inside the Nix store derivation** at `share/pico/lang/` — no external model downloads required, no `~/.local/share/piper` symlink needed.

### Q3: svox dependencies (no onnxruntime)

```
svox build inputs: [ popt ]  (argument parser only)
svox runtime deps: none beyond standard C libs
onnxruntime in closure: NONE (confirmed with nix why-depends)
```

Removing piper-tts and adding svox eliminates the entire onnxruntime chain from the TTS side.

### Q4: markitdown and onnxruntime

**Chain**: `markitdown -> magika -> onnxruntime`

Verified via `nix why-depends`:
```
markitdown -> python3.13-onnxruntime-1.24.4 -> onnxruntime-1.24.4
magika     -> python3.13-onnxruntime-1.24.4 -> onnxruntime-1.24.4
```

In `_markitdown.py` line 15: `import magika` (unconditional, top-level import).  
`self._magika = magika.Magika()` is called in `__init__` on every instantiation.

**Conclusion**: magika cannot be made optional without patching the upstream source. The nixpkgs `markitdown` package has no override passthru to exclude magika.

**Recommendation**: **Remove markitdown from home.nix** (line 401). Use on-demand via:
```bash
nix shell nixpkgs#python3Packages.markitdown -- markitdown input.pdf
# or temporarily:
nix-shell -p python3Packages.markitdown --run "markitdown input.pdf"
```

This is the correct NixOS pattern for occasionally-used heavy tools. markitdown with its full dependency tree (includes openai, pandas, speechrecognition, etc.) is a heavy package; on-demand shell is appropriate.

### Q5 & Q6: Current tts-notify.sh interface contract and differences between copies

**5 files total; 2 groups**:

#### Group A: 4 identical files (no cooldown)
- `/home/benjamin/.dotfiles/.claude/hooks/tts-notify.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/core/hooks/tts-notify.sh`
- `/home/benjamin/.config/nvim/.opencode/hooks/tts-notify.sh`
- `/home/benjamin/.config/nvim/.opencode/extensions/core/hooks/tts-notify.sh`

#### Group B: 1 file with added cooldown logic
- `/home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh`

**Extra features in Group B only**:
- `TTS_COOLDOWN="${TTS_COOLDOWN:-10}"` — seconds between announcements (default 10)
- `LAST_NOTIFY_FILE="/tmp/claude-tts-last-notify"` — cooldown state file
- Cooldown check block after TTS_ENABLED check
- `date +%s > "$LAST_NOTIFY_FILE"` written after each speak call

**Interface contract (preserved across all copies)**:

| Element | Value | Must preserve |
|---------|-------|---------------|
| `TTS_ENABLED` env var | `"0"` disables, default `"1"` | YES |
| `PIPER_MODEL` env var | path to voice model | REMOVE (replace with nothing, no env var needed for pico2wave) |
| `--lifecycle STATUS` arg | speaks "Tab N STATUS" | YES |
| no args mode | speaks "Tab N" | YES |
| Exit JSON | `echo '{}'` | YES |
| `exit 0` always | hook must not error | YES |
| `LOG_FILE` | `specs/tmp/claude-tts-notify.log` | YES |

**Key changes needed to speak() function**:

Current piper paplay branch:
```bash
(timeout 10s bash -c "echo '${message}' | piper --model '${PIPER_MODEL}' --output_file '${temp_wav}' 2>/dev/null && paplay '${temp_wav}' 2>/dev/null; rm -f '${temp_wav}'" &) || true
```

New pico2wave paplay branch:
```bash
(timeout 10s bash -c "pico2wave -w '${temp_wav}' '${message}' 2>/dev/null && paplay '${temp_wav}' 2>/dev/null; rm -f '${temp_wav}'" &) || true
```

Current piper aplay branch (uses stdout pipe):
```bash
(timeout 10s bash -c "echo '${message}' | piper --model '${PIPER_MODEL}' --output_file - 2>/dev/null | aplay -q 2>/dev/null" &) || true
```

New pico2wave aplay branch (must also use temp file):
```bash
(timeout 10s bash -c "pico2wave -w '${temp_wav}' '${message}' 2>/dev/null && aplay -q '${temp_wav}' 2>/dev/null; rm -f '${temp_wav}'" &) || true
```

**Availability check**: Replace piper check with pico2wave check:
```bash
# Remove: PIPER_MODEL variable
# Remove: model existence check (pico2wave needs no external model)
# Change: "if ! command -v piper" -> "if ! command -v pico2wave"
```

### Q7: Documentation files needing updates

#### tts-stt-integration.md (5 copies, 3 distinct versions)

| File | MD5 | Group |
|------|-----|-------|
| `~/.dotfiles/.claude/context/project/neovim/guides/tts-stt-integration.md` | `5616...` | A |
| `~/.config/nvim/.claude/context/project/neovim/guides/tts-stt-integration.md` | `5616...` | A |
| `~/.config/nvim/.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` | `5616...` | A |
| `~/.config/nvim/.opencode/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` | `75e9...` | B |
| `~/.config/nvim/.opencode/docs/guides/tts-stt-integration.md` | `33cc...` | C |

Group A is canonical; B and C are slight variants (same piper content, minor structural differences). All 5 need updating.

Lines containing piper references in group A (385 lines total):
- Line 30: `piper-tts` in requirements list
- Line 31: `espeak-ng  # Piper dependency`
- Lines 54-55: table rows for Piper TTS and espeak-ng
- Lines 66-74: Piper voice model download instructions section
- Line 154: `PIPER_MODEL` env var table row
- Line 164: `export PIPER_MODEL=...` example
- Lines 193-195: troubleshooting piper commands
- Line 367: "delete ~/.local/share/piper/"

#### neovim-integration.md (4 copies, 2 distinct versions)

| File | MD5 | Group |
|------|-----|-------|
| `~/.dotfiles/.claude/context/project/neovim/guides/neovim-integration.md` | `930f...` | A |
| `~/.config/nvim/.claude/context/project/neovim/guides/neovim-integration.md` | `930f...` | A |
| `~/.config/nvim/.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md` | `930f...` | A |
| `~/.config/nvim/.opencode/extensions/nvim/context/project/neovim/guides/neovim-integration.md` | `b1eb...` | B |

Group A (335 lines) piper references:
- Line 117: `export PIPER_MODEL="$HOME/.local/share/piper/en_US-lessac-medium.onnx"`
- Line 237: `which piper`
- Line 242: `ls -la ~/.local/share/piper/en_US-lessac-medium.onnx`

### Q8: Is espeak-ng still needed after dropping piper?

**No**. `espeak-ng` is listed at `configuration.nix:636` with the comment "Text-to-speech synthesizer (dependency for piper-tts)". Once piper-tts is removed, espeak-ng has no other consumers in the configuration. The `svox` package bundles its own synthesis engine (Android SVOX) with no dependency on espeak-ng.

Remove both `piper-tts` (line 635) and `espeak-ng` (line 636) from `configuration.nix`.

### Q9: What exactly to remove from packages/ and flake.nix

#### packages/piper-voices.nix

File at `/home/benjamin/.dotfiles/packages/piper-voices.nix` - delete entirely.

This custom derivation fetches the `.onnx` model and `.onnx.json` config from HuggingFace. It has no other use.

#### flake.nix overlay entry

File `/home/benjamin/.dotfiles/flake.nix`, line 99:
```nix
piper-voice-en-us-lessac-medium = final.callPackage ./packages/piper-voices.nix {}; # Piper TTS voice model
```
Remove this line from the `customPackagesOverlay`.

#### home.nix piper symlink

File `/home/benjamin/.dotfiles/home.nix`, line 1199:
```nix
".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;
```
Remove this line. The `svox` package bundles language data in the Nix store; no `~/.local/share/piper` directory is needed.

---

## Recommendations

### Nix Changes (configuration.nix + home.nix + flake.nix)

1. **configuration.nix lines 635-636**: Replace:
   ```nix
   piper-tts            # Fast, local neural text-to-speech with natural voice quality
   espeak-ng            # Text-to-speech synthesizer (dependency for piper-tts)
   ```
   With:
   ```nix
   svox                 # SVOX Pico text-to-speech engine (pico2wave command)
   ```

2. **home.nix line 401**: Remove `markitdown` from Python packages. Add comment:
   ```nix
   # markitdown removed - depends on magika->onnxruntime; use: nix shell nixpkgs#python3Packages.markitdown
   ```

3. **home.nix line 1199**: Remove `.local/share/piper` symlink line entirely.

4. **flake.nix line 99**: Remove `piper-voice-en-us-lessac-medium` overlay entry.

5. **packages/piper-voices.nix**: Delete file.

### tts-notify.sh Changes (all 5 copies)

The 4 identical copies (Group A) need identical changes. The Group B file (`~/.config/nvim/.claude/hooks/tts-notify.sh`) needs the same changes plus preserving its cooldown block.

**Changes per file**:

a. Update header comment line 3: `# Announces WezTerm tab number via Piper TTS` -> `# Announces WezTerm tab number via pico2wave TTS`

b. Update Requirements comment: `# Requirements: piper-tts, aplay or paplay (alsa-utils), wezterm` -> `# Requirements: svox (pico2wave), aplay or paplay (alsa-utils), wezterm`

c. Remove `PIPER_MODEL` from Configuration section (lines 20-21 in group A, equivalent in group B):
   ```bash
   # REMOVE this line:
   #   PIPER_MODEL - Path to piper voice model (default: ~/.local/share/piper/en_US-lessac-medium.onnx)
   ```

d. Remove the `PIPER_MODEL` variable assignment (line 26):
   ```bash
   # REMOVE:
   PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"
   ```

e. Update `speak()` function header comment (line 74): `# Helper: speak a message via piper` -> `# Helper: speak a message via pico2wave`

f. Replace the speak() function body - both branches now use temp-file approach:
   ```bash
   speak() {
       local message="$1"
       local temp_wav="specs/tmp/claude-tts-$$.wav"
       mkdir -p specs/tmp
       if command -v paplay &>/dev/null; then
           (timeout 10s bash -c "pico2wave -w '${temp_wav}' '${message}' 2>/dev/null && paplay '${temp_wav}' 2>/dev/null; rm -f '${temp_wav}'" &) || true
       elif command -v aplay &>/dev/null; then
           (timeout 10s bash -c "pico2wave -w '${temp_wav}' '${message}' 2>/dev/null && aplay -q '${temp_wav}' 2>/dev/null; rm -f '${temp_wav}'" &) || true
       else
           log "No audio player found (aplay or paplay) - skipping TTS"
           return 1
       fi
       return 0
   }
   ```

g. Replace piper availability check (lines 95-99):
   ```bash
   # REPLACE:
   # Check if piper is available
   if ! command -v piper &>/dev/null; then
       log "piper command not found - skipping TTS notification"
       exit_success
   fi

   # WITH:
   # Check if pico2wave is available
   if ! command -v pico2wave &>/dev/null; then
       log "pico2wave command not found - skipping TTS notification"
       exit_success
   fi
   ```

h. Remove the model existence check (lines 102-105 in group A):
   ```bash
   # REMOVE entirely:
   # Check if model exists
   if [[ ! -f "$PIPER_MODEL" ]]; then
       log "Piper model not found at $PIPER_MODEL - skipping TTS notification"
       exit_success
   fi
   ```

### Documentation Updates

Update all copies of both doc files to replace piper/espeak-ng references with svox/pico2wave:

**tts-stt-integration.md updates** (5 files):
- Requirements section: replace `piper-tts` with `svox` and remove `espeak-ng` row
- Dependency table: row `piper-tts -> Neural text-to-speech` becomes `svox (pico2wave) -> Lightweight text-to-speech`; remove espeak-ng row
- Remove "Model Downloads > Piper Voice Model" section entirely (pico2wave uses bundled language data)
- Configuration table: remove `PIPER_MODEL` row
- Add note: pico2wave uses bundled language data; no manual model download required
- Troubleshooting: replace `which piper` with `which pico2wave`, remove model path check
- Uninstall section: remove `~/.local/share/piper/` step

**neovim-integration.md updates** (4 files):
- Line 117: remove `export PIPER_MODEL=...`
- Line 237: replace `which piper` with `which pico2wave`
- Line 242: replace model path check with `pico2wave -w /tmp/test.wav "test" && echo "works"`

---

## Decisions

1. **Package**: Use `pkgs.svox` (not `pkgs.picotts` or `pkgs.nanotts`) - provides the standard `pico2wave` binary
2. **markitdown**: Remove from home packages (not override) - magika dependency is unconditional; override would produce a broken package
3. **espeak-ng**: Remove with piper-tts - no other consumers, comment confirms it's a piper dependency
4. **No env var for model**: pico2wave bundles language data in Nix store; `PIPER_MODEL` env var removed entirely; no `~/.local/share/pico` symlink needed
5. **speak() function**: Both aplay and paplay branches use temp-file pattern (pico2wave cannot write to stdout)
6. **which-key.lua**: No changes needed - TTS toggle is already commented out since 2025-12-09
7. **Cooldown feature**: Preserved in `~/.config/nvim/.claude/hooks/tts-notify.sh` unchanged

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| pico2wave voice quality different from piper | Expected and acceptable - pico is simpler/older but sufficient for short phrases |
| markitdown breakage for current workflows | Document `nix shell` invocation in comment; markitdown was used ad-hoc |
| temp_wav file leak if timeout kills process | `rm -f` in the bash -c already handles cleanup; PID-named file avoids collisions |
| specs/tmp not present in nvim hooks | `mkdir -p specs/tmp` already in speak() body |
| Missing `pico2wave` when svox not yet installed | Graceful exit_success with log (same as piper check) |
| 5 copies getting out of sync | Plan implementation phase should update all 5 atomically |

---

## Appendix

### File Inventory

| File | Action | Line(s) |
|------|--------|---------|
| `configuration.nix` | Remove piper-tts + espeak-ng, add svox | 635-636 |
| `home.nix` | Remove markitdown from Python env | 401 |
| `home.nix` | Remove .local/share/piper symlink | 1199 |
| `flake.nix` | Remove piper-voice overlay entry | 99 |
| `packages/piper-voices.nix` | Delete file | entire |
| `~/.dotfiles/.claude/hooks/tts-notify.sh` | pico2wave migration | multiple |
| `~/.config/nvim/.claude/hooks/tts-notify.sh` | pico2wave migration (preserve cooldown) | multiple |
| `~/.config/nvim/.claude/extensions/core/hooks/tts-notify.sh` | pico2wave migration | multiple |
| `~/.config/nvim/.opencode/hooks/tts-notify.sh` | pico2wave migration | multiple |
| `~/.config/nvim/.opencode/extensions/core/hooks/tts-notify.sh` | pico2wave migration | multiple |
| `~/.dotfiles/.claude/context/project/neovim/guides/tts-stt-integration.md` | doc update | multiple |
| `~/.config/nvim/.claude/context/project/neovim/guides/tts-stt-integration.md` | doc update | multiple |
| `~/.config/nvim/.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` | doc update | multiple |
| `~/.config/nvim/.opencode/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` | doc update | multiple |
| `~/.config/nvim/.opencode/docs/guides/tts-stt-integration.md` | doc update | multiple |
| `~/.dotfiles/.claude/context/project/neovim/guides/neovim-integration.md` | doc update | 117, 237, 242 |
| `~/.config/nvim/.claude/context/project/neovim/guides/neovim-integration.md` | doc update | 117, 237, 242 |
| `~/.config/nvim/.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md` | doc update | 117, 237, 242 |
| `~/.config/nvim/.opencode/extensions/nvim/context/project/neovim/guides/neovim-integration.md` | doc update | different line numbers |

### pico2wave Verified Facts

- Tested: `pico2wave -w /tmp/test.wav "Tab 3 researched"` produces 36012-byte WAV successfully
- Cannot pipe to stdout: `-w -` returns "Cannot open output wave file"
- Bundled language data at `$out/share/pico/lang/` (en-US, en-GB, de-DE, it-IT, es-ES, fr-FR)
- No external model download required
- Single runtime dependency: `popt` (argument parsing library)
