# Research Report: Task #70

**Task**: 70 - Restore Piper TTS with the en_US-lessac-medium neural voice via a prebuilt binary
**Started**: 2026-07-01T00:42:49Z
**Completed**: 2026-07-01T00:50:00Z
**Effort**: ~1.5 hours implementation (estimate)
**Dependencies**: None (task 62 fully reverted here; task 66 modularization already landed and is respected)
**Sources/Inputs**: Local repo read (flake.nix, packages/, overlays/, modules/system/packages.nix, modules/home/core/shell.nix, .claude/hooks/tts-notify.sh), git history (commits fd23e98, b17b02e, eb31703, 4e21b4b, 2911937, f7f8aa1, 201cf86), GitHub Releases API (rhasspy/piper), HuggingFace (rhasspy/piper-voices), live `nix-prefetch-url` + `nix hash convert` + extraction/execution tests of the actual release tarball
**Artifacts**: this report
**Standards**: report-format.md, artifact-formats.md, nix.md

---

## Executive Summary

- The repo's picotts-based config lives at `modules/system/packages.nix:159` (system package) with no Home Manager symlink or overlay — the cleanest restore point is a **new `packages/piper-bin.nix`** (prebuilt `fetchurl` derivation, `autoPatchelfHook`, modeled directly on the existing `packages/opencode.nix` + `packages/python-cvc5.nix` patterns already in this repo) registered in `overlays/unstable-packages.nix`, exactly parallel to how `vosk-model-small-en-us` and `claude-code`/`opencode` are wired today.
- The upstream `rhasspy/piper` GitHub repo was **archived October 2025**; the latest (and effectively final) Linux x86_64 release asset is `2023.11.14-2` / `piper_linux_x86_64.tar.gz`. I fetched this asset directly and confirmed its sha256 hash, extracted it, and ran a live end-to-end synthesis test — it works, requires no external espeak-ng or onnxruntime packages, and bundles its own `libonnxruntime.so.1.14.1` as a **precompiled binary blob** (not a build target), which is exactly what makes the prebuilt route avoid the ~500MB onnxruntime compile that motivated task 62.
- The voice model URLs and hashes recorded in the git-history-recovered (deleted) `packages/piper-voices.nix` were **independently re-verified** via fresh `nix-prefetch-url` calls against HuggingFace today — hashes match exactly, so the old file can be restored byte-for-byte with no changes.
- Recommended approach is **not** a pure restore of the pre-task-62 config: (a) `espeak-ng` as a separate system package is no longer needed (the release tarball bundles its own `libespeak-ng.so.1` + `espeak-ng-data/`), and (b) the package name changes from nixpkgs' `piper-tts` (which pulls `python3.13-onnxruntime` as a build/closure dependency — confirmed live below) to a new custom `piper` attribute built by `piper-bin.nix`. Everything else (voice model derivation, home.file symlink, tts-notify.sh speak() logic, PIPER_MODEL env var) restores faithfully from git history.
- A pure "restore nixpkgs `piper-tts`" would **re-introduce** the onnxruntime dependency into the closure (confirmed via `nix-store -q --references` on the `piper-tts` derivation below) — the prebuilt-binary route is required to satisfy the task's no-compile constraint.

---

## Context & Scope

Task 62 (commit `fd23e98`, phase 2 commit `eb31703`, rename fix `4e21b4b`) replaced `piper-tts` (nixpkgs, pulls onnxruntime) with `picotts`/pico2wave to cut NixOS rebuild times. Task 70 restores the natural Piper voice (`en_US-lessac-medium`) but via a **prebuilt binary fetched with `fetchurl`** so onnxruntime never has to be built from source — the tarball ships a precompiled `.so`. This report documents (A) the current repo's package-wiring conventions in detail, (B) the exact pre-task-62 config recovered from git history, (C) live-verified download URLs/hashes for both the piper binary and the voice model, and (D) the recommended integration design.

---

## Findings

### A. Current repo configuration (post task-62, post task-66 modularization)

The repo was modularized under task 66 *after* task 62 landed, so the original task-62 diff touched `configuration.nix`/`home.nix` directly, but those are now thin import lists. Current locations:

| Concern | Old location (task 62 diff) | Current location |
|---|---|---|
| System TTS package | `configuration.nix:635-636` | `modules/system/packages.nix:159` |
| Home Python packages | `home.nix:401` (markitdown) | `modules/home/packages/python.nix:55` |
| Home.file symlinks | `home.nix:1199` | `modules/home/core/shell.nix:52` (vosk symlink lives here now) |
| Overlay for custom packages | `flake.nix:99` (`customPackagesOverlay`, then inline in flake outputs) | `overlays/unstable-packages.nix` (curried overlay, applied via `unstablePackagesOverlay` in flake.nix) |

**`modules/system/packages.nix:159`** (current):
```nix
# Text-to-Speech and Speech-to-Text
picotts # SVOX Pico text-to-speech engine (pico2wave command)
pulseaudio # PulseAudio client tools (parecord for audio recording)
# vosk is installed via home-manager Python environment
```

**`overlays/unstable-packages.nix`** (current, full file) — this is where all custom `packages/*.nix` derivations get wired into `pkgs`:
```nix
pkgs-unstable: final: prev: {
  niri = pkgs-unstable.niri;
  claude-code = final.callPackage ../packages/claude-code.nix { };
  opencode = final.callPackage ../packages/opencode.nix { };
  gemini-cli = pkgs-unstable.gemini-cli;
  loogle = final.callPackage ../packages/loogle.nix { };
  aristotle = final.callPackage ../packages/aristotle.nix { };
  slidev = final.callPackage ../packages/slidev.nix { };
  kooha = import ../packages/kooha.nix prev.kooha final.gst_all_1;

  # TTS/STT Models
  vosk-model-small-en-us = final.callPackage ../packages/vosk-models.nix { }; # Vosk STT language model

  # Add other packages that benefit from using unstable below
}
```
This overlay is applied globally in `flake.nix` (`nixpkgsConfig.overlays = [ claudeSquadOverlay unstablePackagesOverlay pythonPackagesOverlay ]`), so anything registered here becomes `pkgs.<name>` for both the NixOS-integrated and standalone Home Manager evaluations. This is the correct/only place to add both the new `piper` package and the restored `piper-voice-en-us-lessac-medium` model package.

**Prebuilt-binary derivation pattern already used in this repo** — `packages/opencode.nix` (closest existing analog: single-binary GitHub release tarball fetched with `fetchurl`, no `autoPatchelfHook` because opencode's binary happens to be statically-friendly, but it demonstrates the `stdenvNoCC.mkDerivation` + custom `unpackPhase` + `installPhase` idiom used here):
```nix
{ lib, stdenvNoCC, fetchurl, makeWrapper, ripgrep }:
let
  version = "1.14.33";
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
    hash = "sha256-qz3j1ApnVzQZ7HSRYhDPkNz4wYDcnYBS23Gsn1XCiBA=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version src;
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  dontConfigure = true;
  unpackPhase = ''
    tar -xzf $src
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 opencode $out/bin/opencode
    wrapProgram $out/bin/opencode --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
    runHook postInstall
  '';
  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
  };
}
```
`packages/opencode.nix`'s header comment also documents the repo's standard update workflow (`nix store prefetch-file --hash-type sha256 <url>`, no `--unpack`), which the new `piper-bin.nix` should mirror.

**`autoPatchelfHook` pattern already used in this repo** — since piper's tarball contains ELF binaries linked against bundled `.so` files plus `libstdc++.so.6`, `packages/python-cvc5.nix` is the exact template to follow (fetchurl of a prebuilt binary wheel, `autoPatchelfHook`, `buildInputs = [ stdenv.cc.cc.lib ]` for libstdc++):
```nix
{ lib, buildPythonPackage, fetchurl, stdenv, autoPatchelfHook }:
buildPythonPackage rec {
  pname = "cvc5"; version = "1.3.3"; format = "wheel";
  src = fetchurl { url = "..."; sha256 = "..."; };
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  autoPatchelfIgnoreMissingDeps = true;
  ...
}
```
`packages/python-vosk.nix` shows the same `autoPatchelfHook` + `stdenv.cc.cc.lib` idiom for a non-wheel case.

**Home.file / models symlink pattern** — `packages/vosk-models.nix` (fetchzip-based model derivation) + `modules/home/core/shell.nix:52`:
```nix
# packages/vosk-models.nix
stdenv.mkDerivation rec {
  pname = "vosk-model-small-en-us"; version = "0.15";
  src = fetchzip { url = "..."; hash = "..."; stripRoot = false; };
  installPhase = '' mkdir -p $out; cp -r vosk-model-small-en-us-${version}/* $out/ '';
  meta = with lib; { description = "..."; homepage = "..."; license = licenses.asl20; platforms = platforms.all; };
}

# modules/home/core/shell.nix — home.file block
home.file = {
  ...
  # TTS/STT Models - declaratively managed
  ".local/share/vosk/vosk-model-small-en-us-0.15".source = pkgs.vosk-model-small-en-us;
};
```
The restored piper voice symlink should be added as a sibling line in this exact `home.file` block: `".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;` (this matches the pre-task-62 `home.nix:1199` line exactly, just relocated to the module).

**`.claude/hooks/tts-notify.sh`** (current, full content read) — pico2wave temp-file version. Full file is 116 lines; the relevant `speak()` function and surrounding contract are quoted verbatim in section B below (as the "current" side of the diff to be reverted).

**nixpkgs channel/pin** (from `flake.lock`):
- `nixpkgs` (stable, used for `pkgs`): `github:NixOS/nixpkgs/nixos-26.05`, locked rev `cf3ffa5d140899101f1deb3f4d16b1a1aa2de849`
- `nixpkgs-unstable` (used for `pkgs-unstable`, and for `overlays/unstable-packages.nix` custom packages): locked rev `567a49d1913ce81ac6e9582e3553dd90a955875f`
- `system = "x86_64-linux"` (AMD Ryzen desktop, per project-overview) — all hosts (`nandi`, `hamsa`, `garuda`) share this platform.
- Custom packages in `overlays/unstable-packages.nix` are built with `final.callPackage` against the **stable** `pkgs` set with the unstable overlay layered on — `piper-bin.nix` should be added the same way (`final.callPackage ../packages/piper-bin.nix { }`), no special pkgs-unstable dependency needed since it's a pure `fetchurl` + `autoPatchelfHook` derivation, platform-independent of the exact nixpkgs snapshot beyond providing `stdenv.cc.cc.lib` and `autoPatchelfHook`.

---

### B. Recovered task-62-removed configuration (from git history)

#### B1. `packages/piper-voices.nix` (deleted in `fd23e98`) — restore verbatim

```nix
{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "piper-voice-en-us-lessac-medium";
  version = "2023.11.14";

  # Download both the model and config files
  model = fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
    hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
  };

  config = fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
    hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp ${model} $out/en_US-lessac-medium.onnx
    cp ${config} $out/en_US-lessac-medium.onnx.json
  '';

  meta = with lib; {
    description = "Piper TTS voice model - US English (Lessac, Medium quality)";
    homepage = "https://huggingface.co/rhasspy/piper-voices";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
```

**Both hashes independently re-verified today** via live `nix-prefetch-url --type sha256 <url>` + `nix hash to-sri` — they match the recovered file exactly, byte for byte. No changes needed to this file; restore it as-is at `packages/piper-voices.nix`.

#### B2. Old `flake.nix` overlay entry (removed in `fd23e98`, was inline in flake outputs before task 66 moved it)

```nix
piper-voice-en-us-lessac-medium = final.callPackage ./packages/piper-voices.nix {}; # Piper TTS voice model
```
Post-task-66, this should be added to **`overlays/unstable-packages.nix`** (not `flake.nix` directly) as:
```nix
piper-voice-en-us-lessac-medium = final.callPackage ../packages/piper-voices.nix { }; # Piper TTS voice model
```
placed next to the existing `vosk-model-small-en-us` line under the `# TTS/STT Models` comment.

#### B3. Old `home.nix` symlink (removed in `fd23e98`)

```nix
".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;
```
Post-task-66, add to **`modules/home/core/shell.nix`**'s `home.file` block, next to the vosk line:
```nix
# TTS/STT Models - declaratively managed
".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;
".local/share/vosk/vosk-model-small-en-us-0.15".source = pkgs.vosk-model-small-en-us;
```

#### B4. Old `configuration.nix` piper-tts + espeak-ng lines (removed in `fd23e98`)

```nix
# Text-to-Speech and Speech-to-Text
piper-tts            # Fast, local neural text-to-speech with natural voice quality
espeak-ng            # Text-to-speech synthesizer (dependency for piper-tts)
```
Post-task-66, this maps to `modules/system/packages.nix:159`. **Recommendation (deviation from pure restore, see section D)**: do NOT restore `espeak-ng` as a separate system package — the new prebuilt tarball bundles its own `libespeak-ng.so.1` + `espeak-ng-data/`, so a system-level `espeak-ng` package is now redundant weight. Also, the package attribute is `piper` (our custom `piper-bin.nix`), not nixpkgs' `piper-tts`.

#### B5. Old `.claude/hooks/tts-notify.sh` `speak()` function and surrounding contract (reverted to pico2wave in `eb31703`)

Full recovered diff (reading `eb31703` in reverse — this is the **target** state to restore):

Header/requirements comments:
```bash
# Announces WezTerm tab number via Piper TTS for lifecycle transitions
...
# Requirements: piper-tts, aplay or paplay (alsa-utils), wezterm
...
# Configuration:
#   PIPER_MODEL - Path to piper voice model (default: ~/.local/share/piper/en_US-lessac-medium.onnx)
#   TTS_ENABLED - Set to "0" to disable (default: 1)
```

Config variable (restore before `TTS_ENABLED`):
```bash
PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"
TTS_ENABLED="${TTS_ENABLED:-1}"
```

`speak()` function (both branches use the stdout-streaming form for `paplay`, and a `--output_file -` pipe to `aplay` — note the asymmetry is intentional in the pre-task-62 version: paplay writes to a temp file, aplay pipes stdout directly):
```bash
# Helper: speak a message via piper
speak() {
    local message="$1"
    if command -v paplay &>/dev/null; then
        local temp_wav="specs/tmp/claude-tts-$$.wav"
        mkdir -p specs/tmp
        (timeout 10s bash -c "echo '${message}' | piper --model '${PIPER_MODEL}' --output_file '${temp_wav}' 2>/dev/null && paplay '${temp_wav}' 2>/dev/null; rm -f '${temp_wav}'" &) || true
    elif command -v aplay &>/dev/null; then
        (timeout 10s bash -c "echo '${message}' | piper --model '${PIPER_MODEL}' --output_file - 2>/dev/null | aplay -q 2>/dev/null" &) || true
    else
        log "No audio player found (aplay or paplay) - skipping TTS"
        return 1
    fi
    return 0
}
```

Availability + model-existence checks (restore before the lifecycle/interactive mode blocks, replacing the current `pico2wave` check):
```bash
# Check if piper is available
if ! command -v piper &>/dev/null; then
    log "piper command not found - skipping TTS notification"
    exit_success
fi

# Check if model exists
if [[ ! -f "$PIPER_MODEL" ]]; then
    log "Piper model not found at $PIPER_MODEL - skipping TTS notification"
    exit_success
fi
```

**Note on scope**: the task-62 migration touched 5 copies of `tts-notify.sh` across two git repos (`~/.dotfiles` and `~/.config/nvim`, per `specs/062.../reports/01_replace-piper-svox-pico.md` Q5/Q6/Q7). Task 70's description explicitly scopes to `.claude/hooks/tts-notify.sh` in **this** repo only. I confirmed live that `~/.config/nvim/.claude/hooks/tts-notify.sh` and `~/.config/nvim/.opencode/hooks/tts-notify.sh` currently contain **no** piper/PIPER_MODEL references (already fully on pico2wave) — those are a separate git repo and out of scope here; flag for the user if they also want Piper restored there (would need a follow-up task in that repo).

#### B6. Documentation drift to fix in this repo

Live grep confirms two files still describe the picotts-only state and will need updating to match the restored config:
- `README.md:174-179` (Text-to-Speech & Speech-to-Text section, references "SVOX Pico TTS" and no-onnxruntime claim)
- `docs/applications.md:87-101` (`### TTS: SVOX Pico` section, `**Package**: picotts`, usage example `pico2wave -w output.wav ...`)

Task 62's report also references 5 copies each of `tts-stt-integration.md` and `neovim-integration.md` (all under `.claude/context/project/neovim/guides/` and its nvim-extension mirrors) — a quick check shows these guide files exist under `.claude/context/project/neovim/guides/` in this repo too and likely still describe pico2wave; the planner should grep for `pico2wave|picotts` across `.claude/context/` and `README.md`/`docs/` to get the complete doc-update list (task 70's explicit scope only names README.md and docs/applications.md, so treat the guides as optional/stretch).

---

### C. Pinned prebuilt-binary sources (live-verified)

#### C1. Piper binary release

- **Upstream status**: `rhasspy/piper` GitHub repo was **archived 2025-10-06** (read-only). Release tags: `2023.11.14-2` (latest), `v1.2.0`, `v1.1.0`, `v1.0.0`, `v0.0.2`.
- **Asset**: `piper_linux_x86_64.tar.gz` from tag `2023.11.14-2`
- **URL**: `https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz`
- **Size**: 26,460,462 bytes (confirmed via GitHub Releases API)
- **Hash** (live-verified via `nix-prefetch-url --type sha256 <url>` then `nix hash to-sri --type sha256 <base32>`):
  ```
  sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=
  ```
  Command the implementer can re-run to reproduce: `nix-prefetch-url --type sha256 https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz`
- **License**: MIT (confirmed via `LICENSE.md` in the piper repo, Copyright 2022 Michael Hansen)

**Tarball contents** (extracted and listed live):
```
piper/
piper/piper                          <- main executable
piper/espeak-ng                      <- bundled espeak-ng CLI (not needed at runtime by piper itself)
piper/piper_phonemize                <- phonemizer CLI (not needed at runtime)
piper/libespeak-ng.so, .so.1, .so.1.52.0.1
piper/libpiper_phonemize.so, .so.1, .so.1.2.0
piper/libonnxruntime.so, .so.1.14.1  <- PREBUILT BLOB, not a nixpkgs build target
piper/libtashkeel_model.ort          <- Arabic diacritization model (unused for en_US)
piper/pkgconfig/
piper/espeak-ng-data/                <- ~200 dict/voice files bundled, incl. en dict
```

**Runtime linkage** (confirmed via `patchelf --print-needed` on the extracted binaries):
```
piper:                  libespeak-ng.so.1, libpiper_phonemize.so.1, libonnxruntime.so.1.14.1,
                         libpthread.so.0, libm.so.6, libc.so.6, ld-linux-x86-64.so.2
libonnxruntime.so.1.14.1: libdl.so.2, librt.so.1, libpthread.so.0, libstdc++.so.6,
                         libm.so.6, libgcc_s.so.1, libc.so.6
libpiper_phonemize.so.1.2.0: libespeak-ng.so.1, libonnxruntime.so.1.14.1, libstdc++.so.6,
                         libgcc_s.so.1, libc.so.6
libespeak-ng.so.1.52.0.1: libm.so.6, libc.so.6
```
Only **one** external (non-bundled, non-glibc) shared library is needed: **`libstdc++.so.6`**, satisfiable via `buildInputs = [ stdenv.cc.cc.lib ]` — exactly the pattern already used in `packages/python-cvc5.nix` and `packages/python-vosk.nix`. All the `.so.1`-named libraries piper links against (`libespeak-ng.so.1`, `libpiper_phonemize.so.1`, `libonnxruntime.so.1.14.1`) are **bundled siblings in the same tarball directory** — `autoPatchelfHook` will find and rpath them automatically as long as they're installed into the same output directory as the `piper` binary (e.g., all under `$out/bin/`, matching the tarball's own flat layout).

**`--help` output** (confirmed live by extracting and running the binary with `LD_LIBRARY_PATH` pointed at itself):
```
-m FILE  --model       FILE  path to onnx model file
-c FILE  --config      FILE  path to model config file (default: model path + .json)
-f FILE  --output_file FILE  path to output WAV file ('-' for stdout)
-d DIR   --output_dir  DIR   path to output directory (default: cwd)
--output_raw                 output raw audio to stdout as it becomes available
--espeak_data           DIR  path to espeak-ng data directory
--tashkeel_model       FILE  path to libtashkeel onnx model (arabic)
```
This **confirms** `tts-notify.sh`'s expected `--model` and `--output_file -` flags are both present and behave as before.

**espeak-ng-data resolution — live-tested, important finding**: I ran `piper --model en_US-lessac-medium.onnx --output_file test.wav` **without** passing `--espeak_data`, from a working directory *different* from the binary's own directory, and it **still found `espeak-ng-data` automatically** (resolves relative to the executable's own path, not `cwd`) and produced valid audio (61KB/88KB WAV files, synthesis completed with `Real-time factor: 0.05-0.07`). This means: as long as `espeak-ng-data/` is installed as a sibling directory of the `piper` binary in `$out/bin/`, no `--espeak_data` flag or wrapper is required. (For extra robustness the implementer could still add `wrapProgram $out/bin/piper --add-flags "--espeak_data $out/bin/espeak-ng-data"` — optional, not required based on this live test.)

**Full end-to-end synthesis test** (live, using the real voice model — see C2): `echo "Hello from piper" | piper --model en_US-lessac-medium.onnx --output_file test.wav` succeeded, produced a valid playable WAV, log output:
```
[piper] [info] Loaded voice in 0.14 second(s)
[piper] [info] Initialized piper
[piper] [info] Real-time factor: 0.066 (infer=0.078 sec, audio=1.18 sec)
[piper] [info] Terminated piper
```

#### C2. Voice model (en_US-lessac-medium)

- **Model URL**: `https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx`
- **Config URL**: `https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json`
- **Hashes** (live-verified today, `nix-prefetch-url --type sha256 <url>` + `nix hash to-sri`):
  - model: `sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=`
  - config: `sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=`
  - **These match the git-history-recovered hashes in the deleted `packages/piper-voices.nix` exactly** — the HuggingFace files have not changed since task 62. Restore the file verbatim (section B1).

#### C3. Does a pure "restore nixpkgs `piper-tts`" avoid onnxruntime? — No, confirmed live

```
$ nix eval --json nixpkgs#piper-tts.drvAttrs.buildInputs
["/nix/store/...-espeak-ng-1.52.0.1-unstable-2025-09-09"]

$ nix-store -q --references <piper-tts.drvPath>
/nix/store/...-python3.13-onnxruntime-1.24.4.drv
/nix/store/...-python3.13-onnx-1.21.0.drv
```
The current nixpkgs `piper-tts` (v1.4.2, a Python package) still has `python3.13-onnxruntime-1.24.4` and `python3.13-onnx-1.21.0` as derivation-graph references — i.e., restoring nixpkgs' `piper-tts` attribute directly would reintroduce exactly the dependency task 62 was created to eliminate, regardless of whether Hydra happens to have a cached substitute for it at rebuild time. **The prebuilt-binary route (`fetchurl` of the GitHub release tarball) is the only way to get the natural Piper voice without ever evaluating/building/depending-on nixpkgs' onnxruntime derivation** — it downloads a foreign precompiled `.so` blob instead, which is a fundamentally different closure edge (a `fetchurl` fixed-output derivation with no build-time compute, vs. a full `stdenv.mkDerivation` build tree).

---

## Decisions

1. **Package name**: new custom attribute `piper` (built by `packages/piper-bin.nix`), not nixpkgs' `piper-tts`. Rationale: C3 above.
2. **Release pin**: `2023.11.14-2` / `piper_linux_x86_64.tar.gz`, hash `sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=`. This is the last release before the upstream repo was archived — no newer release exists to pin instead.
3. **Do not restore `espeak-ng` as a separate system package** — deviation from the literal pre-task-62 config. The prebuilt tarball bundles its own `libespeak-ng.so.1` + `espeak-ng-data/`; a system-level `espeak-ng` entry would be dead weight duplicating functionality already inside the piper derivation.
4. **`autoPatchelfHook` + `buildInputs = [ stdenv.cc.cc.lib ]`** required (matches `python-cvc5.nix`/`python-vosk.nix` pattern) — the only external runtime dependency beyond glibc is `libstdc++.so.6`.
5. **Install layout**: flat `$out/bin/{piper,libespeak-ng.so.1,libpiper_phonemize.so.1,libonnxruntime.so.1.14.1,libtashkeel_model.ort,espeak-ng-data/}` mirroring the tarball's own flat directory — confirmed live that `espeak-ng-data` resolves correctly this way with zero extra flags/wrapping.
6. **Voice model file**: restore `packages/piper-voices.nix` verbatim (hashes independently re-verified, unchanged).
7. **Overlay registration**: both `piper` and `piper-voice-en-us-lessac-medium` go in `overlays/unstable-packages.nix` (not `flake.nix` directly — task-66 modularization moved this), under the `# TTS/STT Models` comment, next to `vosk-model-small-en-us`.
8. **`modules/system/packages.nix:159`**: replace the `picotts` line with `piper # Fast, local neural text-to-speech with natural voice quality (prebuilt binary, no onnxruntime compile)`.
9. **`modules/home/core/shell.nix`**: restore the `.local/share/piper` symlink line in the existing `home.file` "TTS/STT Models" block.
10. **`tts-notify.sh`**: restore the pre-task-62 `speak()` function, `PIPER_MODEL` env var, availability check, and model-existence check verbatim (section B5) — this is a faithful revert of commit `eb31703`, scoped to `.claude/hooks/tts-notify.sh` only (the `~/.config/nvim` copies are a separate repo, out of scope per task 70's description).
11. **Documentation**: update `README.md:174-179` and `docs/applications.md:87-101` (the two files task 70 explicitly names) to describe Piper/lessac-medium instead of SVOX Pico; treat `.claude/context/project/neovim/guides/*.md` updates as optional/stretch since task 70's description doesn't name them.

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `autoPatchelfHook` fails to find bundled sibling `.so` files if installed to a non-flat layout | Install everything flat into `$out/bin/` (matches tarball layout exactly, matching what was live-tested) |
| GitHub release asset disappears (repo archived, no further releases) | Hash-pinned `fetchurl` protects against silent content changes; if the asset URL 404s in the future, mirror the tarball into a Nix store cache or a personal artifact host — flag as a longer-term risk given the repo's archived status |
| `espeak-ng` binary/data version drift between the bundled tarball and system locale expectations | Not a concern — tarball is fully self-contained down to `espeak-ng-data/`; no reliance on system `espeak-ng` |
| Voice model URLs on HuggingFace change/move (branch `v1.0.0` could be deprecated) | Hashes are pinned via `fetchurl`; if the URL breaks, `rhasspy/piper-voices` also publishes the same file under `main` — implementer can fall back to that ref |
| `libonnxruntime.so.1.14.1` bundled blob has unpatched CVEs (it's a frozen 2023-era build) | Acceptable for a local, non-networked TTS use case; note as an accepted risk, not a blocker |
| tts-notify.sh temp-file (`paplay` branch) vs. stdout-pipe (`aplay` branch) asymmetry looks inconsistent | This asymmetry is exactly how the pre-task-62 code worked (verified in git history) — preserve it faithfully rather than "fixing" it, to minimize deviation from the known-working prior state |
| Doc scope creep (5 copies of guides across 2 repos per task 62's report) | Task 70's explicit description only names `README.md` and `docs/applications.md`; do not touch `~/.config/nvim` (separate repo) without explicit user request |

---

## Appendix

### Files to change (implementer checklist)

| File | Action |
|---|---|
| `packages/piper-bin.nix` | **Create** — new prebuilt-binary derivation (fetchurl + autoPatchelfHook), per section D design, hash `sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=` |
| `packages/piper-voices.nix` | **Restore verbatim** from git history (section B1) — hashes re-verified unchanged |
| `overlays/unstable-packages.nix` | Add `piper = final.callPackage ../packages/piper-bin.nix { };` and `piper-voice-en-us-lessac-medium = final.callPackage ../packages/piper-voices.nix { };` under `# TTS/STT Models` |
| `modules/system/packages.nix:159` | Replace `picotts # ...` line with `piper # Fast, local neural text-to-speech with natural voice quality (prebuilt binary, no onnxruntime compile)`; do not add `espeak-ng` |
| `modules/home/core/shell.nix` | Add `".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;` to the `home.file` TTS/STT Models block |
| `.claude/hooks/tts-notify.sh` | Revert `speak()`, `PIPER_MODEL` var, availability + model-existence checks, header/requirements comments per section B5 |
| `README.md` (lines ~174-179) | Update TTS section to describe Piper/lessac-medium |
| `docs/applications.md` (lines ~87-101) | Update `### TTS: SVOX Pico` section to `### TTS: Piper` with package/model/usage details |

### Verification commands for implementer

```bash
# Confirm flake evaluates and package builds
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run  # or full build
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath

# Confirm onnxruntime is NOT being built from source (only the fetchurl'd blob is a foreign binary)
nix why-depends .#nixosConfigurations.<host>.config.system.build.toplevel nixpkgs#onnxruntime 2>&1
# Expected: no path found (piper's bundled libonnxruntime.so is not the nixpkgs onnxruntime derivation)

# Smoke test after switch
piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file /tmp/test.wav <<< "Hello from piper"
paplay /tmp/test.wav
```

### Re-fetch commands (if hashes ever need re-verification)

```bash
nix-prefetch-url --type sha256 https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz
nix-prefetch-url --type sha256 https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx
nix-prefetch-url --type sha256 https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
# then: nix hash to-sri --type sha256 <base32-output>
```

### Draft `packages/piper-bin.nix` (for the planner/implementer — not yet written to the repo)

```nix
# piper - fast, local neural text-to-speech (rhasspy/piper), prebuilt Linux x86_64 binary.
# Fetches the official GitHub release tarball instead of building from source, avoiding
# nixpkgs' piper-tts -> onnxruntime source-compile chain (see task 70 research report).
# NOTE: upstream rhasspy/piper was archived 2025-10-06; 2023.11.14-2 is the final release.
# To update (if a fork/successor project ships new releases):
#   nix-prefetch-url --type sha256 <new-url>
#   nix hash to-sri --type sha256 <output>

{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, stdenv }:

let
  version = "2023.11.14-2";
  src = fetchurl {
    url = "https://github.com/rhasspy/piper/releases/download/${version}/piper_linux_x86_64.tar.gz";
    hash = "sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "piper";
  inherit version src;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ]; # libstdc++.so.6 for bundled onnxruntime/phonemize libs

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar -xzf $src
  '';

  # Flat install matching the tarball's own layout: espeak-ng-data/ resolves relative to
  # the piper binary's own path at runtime (verified: works with cwd != binary dir, no
  # --espeak_data flag needed as long as siblings stay together).
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r piper/* $out/bin/
    chmod +x $out/bin/piper $out/bin/espeak-ng $out/bin/piper_phonemize
    runHook postInstall
  '';

  meta = {
    description = "Fast, local neural text-to-speech (prebuilt binary, bundles onnxruntime)";
    homepage = "https://github.com/rhasspy/piper";
    license = lib.licenses.mit;
    mainProgram = "piper";
    platforms = [ "x86_64-linux" ];
  };
}
```
This is a draft for the planner to refine, not a final file — the implementer should double check `autoPatchelfHook` output (e.g. run `nix build .#piper` in isolation and inspect `ldd $out/bin/piper`) before wiring it into the system closure.
