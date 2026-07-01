# Implementation Summary: Task #70

**Completed**: 2026-06-30
**Duration**: ~45 minutes

## Overview

Restored the natural Piper TTS voice (`en_US-lessac-medium`) that task 62 removed, via a
**prebuilt Linux x86_64 binary** (rhasspy/piper release `2023.11.14-2`, fetched with `fetchurl` +
`autoPatchelfHook`) instead of nixpkgs' `piper-tts` attribute or SVOX Pico (`picotts`). The
release tarball bundles a precompiled `libonnxruntime.so.1.14.1`, so onnxruntime is never
compiled from source — verified end-to-end with `nix why-depends`.

## What Changed

- `packages/piper-bin.nix` (new) — prebuilt-binary derivation: `stdenvNoCC.mkDerivation` +
  `autoPatchelfHook`, flat-installs `piper`/`espeak-ng`/`piper_phonemize` binaries and bundled
  `.so` siblings into `$out/bin/`, `buildInputs = [ stdenv.cc.cc.lib ]` for `libstdc++.so.6`.
- `packages/piper-voices.nix` (restored verbatim from git history) — `en_US-lessac-medium` ONNX
  model + config, hashes re-verified unchanged.
- `overlays/unstable-packages.nix` — registered `piper` and `piper-voice-en-us-lessac-medium`
  under the `# TTS/STT Models` grouping, next to `vosk-model-small-en-us`.
- `modules/system/packages.nix` — replaced the `picotts` line with `piper`; did **not** add a
  separate `espeak-ng` system package (the tarball bundles its own `libespeak-ng.so.1` +
  `espeak-ng-data/`).
- `modules/home/core/shell.nix` — added `".local/share/piper".source =
  pkgs.piper-voice-en-us-lessac-medium;` to the `home.file` "TTS/STT Models" block.
- `.claude/hooks/tts-notify.sh` — reverted `speak()` to the Piper stdout-pipe/temp-file form,
  restored `PIPER_MODEL` env var, the `piper` availability check, and the model-existence check
  (faithful revert of commit `eb31703`).
- `README.md` — TTS bullet now describes Piper/lessac-medium (prebuilt binary, no onnxruntime
  compile).
- `docs/applications.md` — `### TTS: SVOX Pico` section rewritten to `### TTS: Piper` with
  package/model/usage details.
- `packages/README.md` (beyond plan's explicit scope, but directly documents the packages/
  directory this task modified) — added `piper-bin.nix`/`piper-voices.nix` per-file sections
  matching the existing documentation convention, and rewrote the stale
  "TTS: SVOX Pico (System Package)" subsection to describe Piper.

## Decisions

- Custom `piper` attribute (built by `piper-bin.nix`), not nixpkgs' `piper-tts` — restoring
  nixpkgs' attribute directly would reintroduce `python3.13-onnxruntime` as a build/closure
  dependency (confirmed in the research report via `nix-store -q --references`).
- No separate `espeak-ng` system package — deviation from the literal pre-task-62 config,
  since the tarball is self-contained (bundles `libespeak-ng.so.1` + `espeak-ng-data/`).
- Flat install layout (`$out/bin/{piper,*.so,espeak-ng-data/}`) matching the tarball's own
  layout — `espeak-ng-data/` resolves relative to the binary's own path at runtime with no
  `--espeak_data` flag or wrapper needed (matches the research report's live verification).

## Plan Deviations

- **Phase 6 host**: built `nixos-rebuild build --flake .#hamsa` instead of `.#nandi` (the plan's
  named primary host) — this implementation ran on host `hamsa` per the invoking instructions.
  `nandi`/`hamsa`/`garuda` share `x86_64-linux` and the piper derivation is host-independent, so
  this substitution does not change the verification's validity.
- **`.#piper` flake attribute**: the top-level flake does not expose a bare `packages.x86_64-linux.piper`
  output; verified instead via `nix build .#nixosConfigurations.hamsa.pkgs.piper` (functionally
  equivalent, and the plan itself names this as an acceptable alternative).
- **Audible playback test skipped**: `piper --output_file - | aplay/paplay` audible output was not
  verified — this sandbox has no audio hardware/playback access. Synthesis-to-file was verified
  instead (produced a valid, correctly-sized WAV via the actual built binary + voice model). The
  user should run the audible test after `nixos-rebuild switch` (see below).
- **`packages/README.md` updated** (not named in the plan's explicit scope of "README.md and
  docs/applications.md") — this file directly documents the `packages/` directory this task
  modified and had a stale "TTS: SVOX Pico" subsection; updating it keeps documentation
  consistent with the restored config. `.claude/context/project/neovim/guides/*.md` and
  `.opencode/hooks/tts-notify.sh` were left untouched per the plan's explicit non-goals (separate
  scope / separate hook system).

## Verification

- **Flake check**: `nix flake check` — all checks passed.
- **Host build (`hamsa`)**: `nixos-rebuild build --flake .#hamsa` completed successfully
  (`/nix/store/hlpk5jvzb3mgnyv2fsnzykhxsljj4qr2-nixos-system-hamsa-26.05.20260622.3426825`).
  `grep -i onnxruntime /tmp/task70-build.log` returned **zero matches** — no onnxruntime build
  derivation appeared anywhere in the full build log.
- **Home Manager build**: `home-manager build --flake .#benjamin` completed successfully
  (activation-script, home-manager-files, home-manager-generation derivations all built).
- **`nix why-depends` proof** (the key no-onnxruntime-compile proof):
  ```
  $ nix why-depends .#nixosConfigurations.hamsa.config.system.build.toplevel nixpkgs#onnxruntime
  'git+file:///home/benjamin/.dotfiles#nixosConfigurations.hamsa.config.system.build.toplevel'
  does not depend on 'flake:nixpkgs#onnxruntime'
  ```
- **`picotts`/`pico2wave` removal** (scoped grep, matches the plan's exact command):
  ```
  $ grep -rn "pico2wave\|picotts" modules/ .claude/hooks/tts-notify.sh README.md docs/applications.md
  (no output — exit code 1)
  ```
  Note: a broader repo-wide grep also found two intentionally out-of-scope files still referencing
  pico2wave — `.opencode/hooks/tts-notify.sh` (separate hook system, not part of task 70's named
  scope) and `.claude/context/project/neovim/guides/{neovim-integration,tts-stt-integration}.md`
  (plan explicitly lists these as optional/stretch, not required). `packages/README.md` was found
  stale and updated (see Plan Deviations above) even though not in the plan's named scope.
- **Isolated piper build + linkage** (Phase 1):
  ```
  $ nix build .#nixosConfigurations.hamsa.pkgs.piper -o /tmp/piper-result
  $ ldd /tmp/piper-result/bin/piper | grep -i "not found"
  (no output)
  ```
  All bundled `.so` siblings (`libespeak-ng.so.1`, `libpiper_phonemize.so.1`,
  `libonnxruntime.so.1.14.1`) resolved to `$out/bin/`; `libstdc++.so.6`/`libgcc_s.so.1` resolved
  to the Nix store gcc-lib output. `espeak-ng-data/` present as a sibling of the binary.
- **Voice model build** (Phase 2): `nix build .#nixosConfigurations.hamsa.pkgs.piper-voice-en-us-lessac-medium`
  produced `en_US-lessac-medium.onnx` (63,201,294 bytes) and `.onnx.json` (4,885 bytes).
- **Synthesis smoke test** (functional, no audio hardware available in this sandbox):
  ```
  $ echo "Piper voice restored" | piper --model .../en_US-lessac-medium.onnx --output_file /tmp/task70-test.wav
  [piper] [info] Loaded voice in 0.154 second(s)
  [piper] [info] Real-time factor: 0.0494 (infer=0.070 sec, audio=1.416 sec)
  [piper] [info] Terminated piper
  $ ls -la /tmp/task70-test.wav
  -rw-r--r-- 1 benjamin users 71328 ... /tmp/task70-test.wav
  ```
- **Hook smoke test**: `bash -n .claude/hooks/tts-notify.sh` — syntax OK. With `PATH`/`PIPER_MODEL`
  pointed at the built artifacts: `TTS_ENABLED=1 bash .claude/hooks/tts-notify.sh --lifecycle planned`
  returned `{}` and invoked the piper pipeline (temp WAV created under `specs/tmp/`).

## Notes

**What the user should run to apply and audibly test the change**:
```bash
sudo nixos-rebuild switch --flake .#hamsa
home-manager switch --flake .#benjamin   # links ~/.local/share/piper/ voice model
# Audible smoke test (this sandbox could not test actual audio playback):
echo "Piper voice restored" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | aplay
# or via the hook directly:
TTS_ENABLED=1 .claude/hooks/tts-notify.sh --lifecycle planned
```

All 6 plan phases completed and verified. No blockers. The bundled `libonnxruntime.so.1.14.1` is
a frozen 2023-era build (accepted CVE risk for local, non-networked TTS, documented in
`piper-bin.nix`'s header comment) since upstream `rhasspy/piper` was archived 2025-10-06 with no
newer release to pin instead.
