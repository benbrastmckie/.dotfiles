# Implementation Plan: Restore Piper TTS via Prebuilt Binary

- **Task**: 70 - Restore Piper TTS with the en_US-lessac-medium neural voice via a prebuilt binary
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None (task 62 reverted here; task 66 modularization respected)
- **Research Inputs**: specs/070_restore_piper_tts_prebuilt_binary/reports/01_restore-piper-prebuilt.md
- **Artifacts**: plans/01_restore-piper-prebuilt.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-formats.md, nix.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Restore the natural Piper TTS voice (`en_US-lessac-medium`) that task 62 removed, but via a
**prebuilt Linux x86_64 binary** fetched with `fetchurl` + `autoPatchelfHook` instead of nixpkgs'
`piper-tts` attribute — the release tarball bundles a precompiled `libonnxruntime.so.1.14.1`, so
onnxruntime is never built from source (the constraint that motivated task 62). The change adds a new
`packages/piper-bin.nix` derivation, restores the git-history-recovered `packages/piper-voices.nix`
verbatim, wires both into `overlays/unstable-packages.nix`, swaps `picotts` -> `piper` at
`modules/system/packages.nix`, restores the `~/.local/share/piper` home symlink, reverts
`.claude/hooks/tts-notify.sh` to the Piper stdout-pipe form, and updates the two documentation files.

Phases are ordered so the flake **always evaluates** at each step: the package derivations and their
overlay registration land first (Phase 1-2), then the consumers (system package, home symlink, hook)
reference already-registered attributes, then docs, then verification.

### Research Integration

The research report (`01_restore-piper-prebuilt.md`) live-verified every load-bearing fact:
- Prebuilt tarball `rhasspy/piper` release `2023.11.14-2` / `piper_linux_x86_64.tar.gz`,
  hash `sha256-pQy0XzVbevH211jBs2BxeHe6CjmMyMvm0qejom4iWZI=` (repo archived 2025-10-06; final release).
- Only one external runtime lib beyond glibc: `libstdc++.so.6` -> `buildInputs = [ stdenv.cc.cc.lib ]`;
  all other `.so` files (`libonnxruntime`, `libespeak-ng`, `libpiper_phonemize`) are bundled siblings
  that `autoPatchelfHook` rpaths automatically when installed flat into `$out/bin/`.
- `espeak-ng-data/` resolves relative to the binary's own path at runtime — no `--espeak_data` flag or
  wrapper needed as long as it stays a sibling of the `piper` binary (live-tested with cwd != binary dir).
- Voice model + config hashes re-verified unchanged, so `packages/piper-voices.nix` restores byte-for-byte.
- Restoring nixpkgs `piper-tts` was confirmed to reintroduce `python3.13-onnxruntime` into the closure
  (via `nix-store -q --references`), so the prebuilt route is required, not optional.
- Draft `packages/piper-bin.nix` (report Appendix) is ready to use with minimal refinement.

### Prior Plan Reference

No prior plan for task 70. Task 62's plan (`specs/062.../plans/01_implementation-plan.md`) is the
change being partially reverted here — this plan faithfully restores the Piper side of that diff in
**this repo only** (the `~/.config/nvim` hook copies are a separate git repo, out of scope per task 70).

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Add `packages/piper-bin.nix` prebuilt-binary derivation (fetchurl + autoPatchelfHook), pinned to the
  verified release hash, with no onnxruntime source compile.
- Restore `packages/piper-voices.nix` verbatim (en_US-lessac-medium model + config).
- Register `piper` and `piper-voice-en-us-lessac-medium` in `overlays/unstable-packages.nix`.
- Swap `picotts` -> `piper` at `modules/system/packages.nix` and drop the now-redundant `espeak-ng`
  (bundled in the tarball) — do NOT add a separate `espeak-ng` system package.
- Restore the `.local/share/piper` home.file symlink in `modules/home/core/shell.nix`.
- Revert `.claude/hooks/tts-notify.sh` to the Piper `speak()` (stdout pipe / temp-file), restore the
  `PIPER_MODEL` env var, the `piper` availability check, and the model-existence check.
- Update `README.md` and `docs/applications.md` to describe Piper/lessac-medium instead of SVOX Pico.
- Verify the flake evaluates, the config builds with NO onnxruntime compilation, `pico2wave`/`picotts`
  are fully removed, and the voice synthesizes end-to-end through the hook.

**Non-Goals**:
- Running `nixos-rebuild switch` or `home-manager switch` (build-only verification; user switches).
- Touching the `~/.config/nvim` repo's `tts-notify.sh` copies (separate git repo, out of scope).
- Updating the optional `.claude/context/project/neovim/guides/*.md` TTS guide files (stretch only;
  task 70 explicitly names only README.md and docs/applications.md).
- Adding a `--espeak_data` wrapper (live-verified unnecessary; note as optional robustness only).
- Changing the `TTS_ENABLED` toggle contract or the WezTerm tab-numbering logic in the hook.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `autoPatchelfHook` fails to resolve bundled sibling `.so` files | H | L | Install flat into `$out/bin/` matching tarball layout (live-tested); Phase 1 isolates `nix build .#piper` + `ldd $out/bin/piper` before wiring into closure |
| `espeak-ng-data` not found at runtime for prebuilt binary | M | L | Keep `espeak-ng-data/` a sibling of `piper` in `$out/bin/` (resolves relative to executable path, verified); optionally `wrapProgram --add-flags "--espeak_data $out/bin/espeak-ng-data"` if a failure appears |
| Restoring nixpkgs `piper-tts` by mistake reintroduces onnxruntime | H | L | Use the custom `piper` attribute only; Phase 6 runs `nix why-depends ... nixpkgs#onnxruntime` to prove no source build |
| GitHub release asset disappears (repo archived) | M | L | Hash-pinned `fetchurl`; if URL 404s later, mirror tarball or fall back to a personal artifact host (longer-term risk, not a blocker now) |
| Bundled `libonnxruntime` is a frozen 2023 build with potential CVEs | L | M | Accepted risk for local, non-networked TTS; documented in `piper-bin.nix` header comment |
| Hook `paplay` (temp-file) vs `aplay` (stdout-pipe) asymmetry looks inconsistent | L | M | Preserve verbatim — this is exactly how the known-working pre-task-62 code behaved; do not "fix" it |
| Build fails midway, leaving TTS non-functional | M | L | Rollback = `git checkout` the touched files to return to the working `picotts` state (see Rollback section) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phase 6 (verification) runs last, after all
config and doc changes land, so the build reflects the complete change set.

---

### Phase 1: Add packages/piper-bin.nix + register in overlay [COMPLETED]

**Goal**: Create the prebuilt-binary derivation and make `pkgs.piper` resolvable, verified in isolation
before any consumer references it.

**Tasks**:
- [x] Create `packages/piper-bin.nix` from the research report Appendix draft (verbatim, with header
      comment documenting the archived-upstream status and the `nix-prefetch-url` + `nix hash to-sri`
      update workflow).
- [x] Register in `overlays/unstable-packages.nix` under a `# TTS/STT` grouping, next to the
      `vosk-model-small-en-us` line: `piper = final.callPackage ../packages/piper-bin.nix { };`
- [x] Build in isolation: `nix build .#piper` (or `nix build .#nixosConfigurations.nandi.pkgs.piper`)
      and inspect `ldd $out/bin/piper` to confirm autoPatchelf resolved all bundled `.so` siblings and
      `libstdc++.so.6` with no "not found" lines. *(altered: built via
      `nixosConfigurations.hamsa.pkgs.piper` since this host is hamsa, not nandi; verified
      `ldd result/bin/piper` shows no "not found" lines and `espeak-ng-data/` is present)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `packages/piper-bin.nix` — **Create**. Exact content (from report Appendix, refined):
  ```nix
  # piper - fast, local neural text-to-speech (rhasspy/piper), prebuilt Linux x86_64 binary.
  # Fetches the official GitHub release tarball instead of building from source, avoiding
  # nixpkgs' piper-tts -> onnxruntime source-compile chain (see task 70 research report).
  # NOTE: upstream rhasspy/piper was archived 2025-10-06; 2023.11.14-2 is the final release.
  # The tarball bundles libonnxruntime.so.1.14.1 as a precompiled blob (accepted CVE risk for
  # local, non-networked TTS). To update (if a fork ships new releases):
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
    # Flat install matching the tarball layout: espeak-ng-data/ resolves relative to the piper
    # binary's own path at runtime (verified with cwd != binary dir, no --espeak_data flag needed).
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
- `overlays/unstable-packages.nix` — add `piper = final.callPackage ../packages/piper-bin.nix { };`
  under the `# TTS/STT Models` comment (alongside `vosk-model-small-en-us`).

**Verification**:
- `nix build .#piper` succeeds (or the nixosConfigurations-scoped path).
- `ldd result/bin/piper` shows no `not found`; `libonnxruntime.so.1.14.1`, `libespeak-ng.so.1`,
  `libpiper_phonemize.so.1` resolve to the same `$out/bin/` and `libstdc++.so.6` to the nix store.
- `espeak-ng-data/` present at `result/bin/espeak-ng-data/`.

---

### Phase 2: Restore packages/piper-voices.nix + register + home symlink [COMPLETED]

**Goal**: Make the voice model derivation available as `pkgs.piper-voice-en-us-lessac-medium` and
symlink it into `~/.local/share/piper` declaratively.

**Tasks**:
- [x] Restore `packages/piper-voices.nix` verbatim from git history (report section B1); hashes are
      re-verified unchanged.
- [x] Register in `overlays/unstable-packages.nix` next to the new `piper` line:
      `piper-voice-en-us-lessac-medium = final.callPackage ../packages/piper-voices.nix { };`
- [x] Add the `.local/share/piper` symlink to the `home.file` "TTS/STT Models" block in
      `modules/home/core/shell.nix`.

**Timing**: 0.25 hours

**Depends on**: 1 (shares the overlay `# TTS/STT Models` grouping; both attributes should be adjacent)

**Files to modify**:
- `packages/piper-voices.nix` — **Restore** exactly (do not alter hashes):
  ```nix
  { lib, stdenv, fetchurl }:
  stdenv.mkDerivation rec {
    pname = "piper-voice-en-us-lessac-medium";
    version = "2023.11.14";
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
- `overlays/unstable-packages.nix` — add
  `piper-voice-en-us-lessac-medium = final.callPackage ../packages/piper-voices.nix { }; # Piper TTS voice model`
- `modules/home/core/shell.nix` — in the `home.file` block (after line 51 `# TTS/STT Models`), add
  above the existing vosk line:
  ```nix
  ".local/share/piper".source = pkgs.piper-voice-en-us-lessac-medium;
  ```

**Verification**:
- `nix build .#piper-voice-en-us-lessac-medium` produces `result/en_US-lessac-medium.onnx` and `.onnx.json`.
- `nix eval .#homeConfigurations.benjamin.config.home.file.".local/share/piper".source` resolves without error.

---

### Phase 3: Swap picotts -> piper in system packages, drop espeak-ng [COMPLETED]

**Goal**: Replace the SVOX Pico system package with the restored Piper package; do not reintroduce a
separate `espeak-ng` (bundled in the tarball).

**Tasks**:
- [x] Replace the `picotts` line at `modules/system/packages.nix` (currently line ~159) with the
      `piper` package.
- [x] Confirm no separate `espeak-ng` entry is added (deviation from pure task-62 restore — decision 3
      in the research report).
- [x] Leave `pulseaudio` and the vosk comment untouched.

**Timing**: 0.1 hours

**Depends on**: 2 (references `pkgs.piper` registered in the overlay)

**Files to modify**:
- `modules/system/packages.nix` — in the `# Text-to-Speech and Speech-to-Text` block, change:
  ```nix
  # from:
  picotts # SVOX Pico text-to-speech engine (pico2wave command)
  # to:
  piper # Fast, local neural text-to-speech with natural voice quality (prebuilt binary, no onnxruntime compile)
  ```
  Do NOT add `espeak-ng`. Keep the `pulseaudio` and `# vosk is installed via home-manager` lines.

**Verification**:
- `grep -rn "picotts\|pico2wave" modules/` returns no matches.
- `nix eval .#nixosConfigurations.nandi.config.environment.systemPackages --apply 'ps: builtins.length ps'`
  evaluates without error (attribute `piper` resolves).

---

### Phase 4: Revert .claude/hooks/tts-notify.sh to Piper [NOT STARTED]

**Goal**: Restore the Piper `speak()` function, `PIPER_MODEL` env var, `piper` availability check, and
model-existence check (faithful revert of commit `eb31703`), scoped to this repo's hook only.

**Tasks**:
- [ ] Update header/requirements comments: `pico2wave` -> Piper; add the `PIPER_MODEL` config line to
      the `# Configuration:` block.
- [ ] Add `PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"` before
      the `TTS_ENABLED` line.
- [ ] Replace the `speak()` body with the Piper form (report section B5) — paplay branch writes a temp
      WAV, aplay branch pipes `--output_file -` to stdout (preserve this asymmetry verbatim).
- [ ] Replace the `pico2wave` availability check with a `piper` availability check.
- [ ] Add a model-existence check (`[[ ! -f "$PIPER_MODEL" ]]` -> log + `exit_success`) after the
      availability check, before the lifecycle/interactive mode blocks.

**Timing**: 0.35 hours

**Depends on**: 2 (the model symlink `~/.local/share/piper/en_US-lessac-medium.onnx` is what
`PIPER_MODEL` points at; can run in parallel with Phase 3 as it touches a different file)

**Files to modify**:
- `.claude/hooks/tts-notify.sh`:
  - Line ~2-3 comment: `Announces WezTerm tab number via Piper TTS ...`
  - Line ~10: `# Requirements: piper (piper-bin), aplay or paplay (alsa-utils), wezterm`
  - `# Configuration:` block: add
    `#   PIPER_MODEL - Path to piper voice model (default: ~/.local/share/piper/en_US-lessac-medium.onnx)`
  - Add config var before `TTS_ENABLED`:
    ```bash
    PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"
    ```
  - Replace `speak()` (current lines ~72-86) with:
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
  - Replace the `pico2wave` availability check (current lines ~93-97) with:
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

**Verification**:
- `bash -n .claude/hooks/tts-notify.sh` passes (syntax).
- `grep -n "pico2wave" .claude/hooks/tts-notify.sh` returns nothing.
- `grep -n "PIPER_MODEL\|command -v piper" .claude/hooks/tts-notify.sh` shows the restored lines.

---

### Phase 5: Update README.md + docs/applications.md [NOT STARTED]

**Goal**: Bring the two documentation files task 70 explicitly names back in line with the Piper config.

**Tasks**:
- [ ] Update the README TTS bullet to describe Piper/lessac-medium (prebuilt binary, no onnxruntime compile).
- [ ] Rewrite the `### TTS: SVOX Pico` section in `docs/applications.md` to `### TTS: Piper` with the
      new package name, model, and a piper usage example.

**Timing**: 0.25 hours

**Depends on**: 3, 4 (docs should describe the final package/hook behavior)

**Files to modify**:
- `README.md` (~line 174) — change the SVOX bullet to, e.g.:
  ```
  - **Piper TTS**: Fast, local neural text-to-speech (en_US-lessac-medium voice) via a prebuilt
    binary — natural voice quality with no onnxruntime source compile
  ```
- `docs/applications.md` (~lines 87-101) — replace the `### TTS: SVOX Pico` section:
  ```markdown
  ### TTS: Piper

  Fast, local, fully offline neural text-to-speech with the `en_US-lessac-medium` voice.
  Installed via a prebuilt Linux x86_64 release binary (`packages/piper-bin.nix`, fetchurl +
  autoPatchelfHook) so the bundled onnxruntime is never compiled from source (task 70).

  **Package**: `piper` (custom `packages/piper-bin.nix`, rhasspy/piper release 2023.11.14-2)
  **Model**: `piper-voice-en-us-lessac-medium` (symlinked to `~/.local/share/piper/`)

  **Setup**: `nixos-rebuild switch` installs `piper`; `home-manager switch` links the voice model.

  **Usage**:
  ```bash
  echo "Hello, world!" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | aplay
  ```
  ```

**Verification**:
- `grep -rn "SVOX Pico\|pico2wave\|picotts" README.md docs/applications.md` returns nothing.
- `grep -n "Piper" README.md docs/applications.md` shows the updated content.

---

### Phase 6: Verification (flake check + build, no onnxruntime, smoke test) [NOT STARTED]

**Goal**: Prove the config evaluates and builds with no onnxruntime source compile, SVOX Pico is fully
removed, and the voice synthesizes end-to-end through the hook.

**Tasks**:
- [ ] `nix flake check` passes.
- [ ] Build the primary host toplevel and confirm no onnxruntime is compiled from source.
- [ ] Build the standalone home configuration.
- [ ] Prove `nixpkgs#onnxruntime` is not in the closure as a build target.
- [ ] Confirm `pico2wave`/`picotts` are fully removed repo-wide.
- [ ] Smoke test the piper binary and the hook (requires a built/switched system; if only building,
      run against the `nix build .#piper` result + built voice model).

**Timing**: 0.3 hours

**Depends on**: 5

**Files to modify**: none (verification only).

**Verification** (exact commands — hosts read from flake.nix: `nandi`, `hamsa`, `garuda` share
`x86_64-linux`; standalone home config attribute is `benjamin`):
```bash
# 1. Flake evaluates
nix flake check

# 2. Build primary NixOS host (nandi) — must NOT compile onnxruntime from source
nixos-rebuild build --flake .#nandi 2>&1 | tee /tmp/task70-build.log
grep -i "onnxruntime" /tmp/task70-build.log   # expect: no "building '/nix/store/...onnxruntime...drv'" lines

# 3. Build standalone home configuration
home-manager build --flake .#benjamin   # or: nix build .#homeConfigurations.benjamin.activationPackage

# 4. Prove onnxruntime is not a build dependency of the toplevel
nix why-depends .#nixosConfigurations.nandi.config.system.build.toplevel nixpkgs#onnxruntime 2>&1
# expect: "does not depend on" / no path found (piper's bundled .so is a fetchurl blob, not the drv)

# 5. Confirm SVOX Pico fully removed
grep -rn "pico2wave\|picotts" modules/ .claude/hooks/tts-notify.sh README.md docs/applications.md
# expect: no matches

# 6. Isolated piper build + linkage sanity
nix build .#piper && ldd result/bin/piper | grep -i "not found"   # expect: no output

# 7. End-to-end smoke test (post-switch, or against built artifacts)
piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - <<< "Piper voice restored" | aplay
#   (or paplay). Expect audible lessac-voice output and piper log "Real-time factor: ..."

# 8. Hook smoke test
bash -n .claude/hooks/tts-notify.sh                 # syntax OK
TTS_ENABLED=1 .claude/hooks/tts-notify.sh --lifecycle planned   # expect "{}" JSON + audio (if piper+model present)
```

If `nix flake check` or the host build fails, do not switch — see Rollback/Contingency.

---

## Testing & Validation

- [ ] `nix flake check` passes.
- [ ] `nixos-rebuild build --flake .#nandi` succeeds with NO onnxruntime source compilation in the log.
- [ ] `home-manager build --flake .#benjamin` succeeds.
- [ ] `nix why-depends ... nixpkgs#onnxruntime` finds no source-build dependency.
- [ ] `grep -rn "pico2wave\|picotts"` across `modules/`, the hook, and the two docs returns nothing.
- [ ] `nix build .#piper` + `ldd result/bin/piper` shows no unresolved libraries.
- [ ] `piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - <<< "test" | aplay`
      produces audible lessac-voice output.
- [ ] `.claude/hooks/tts-notify.sh --lifecycle planned` returns `{}` and (with piper + model present) speaks.

## Artifacts & Outputs

- `packages/piper-bin.nix` (new) — prebuilt Piper binary derivation.
- `packages/piper-voices.nix` (restored) — en_US-lessac-medium voice model.
- Modified: `overlays/unstable-packages.nix`, `modules/system/packages.nix`,
  `modules/home/core/shell.nix`, `.claude/hooks/tts-notify.sh`, `README.md`, `docs/applications.md`.
- A green `nix flake check` + host build log showing no onnxruntime compile.

## Rollback/Contingency

The change is confined to the files listed above; the working `picotts` state is fully recoverable via
git:

```bash
# Revert everything if the build fails or the voice does not work
git checkout -- modules/system/packages.nix modules/home/core/shell.nix \
  overlays/unstable-packages.nix .claude/hooks/tts-notify.sh README.md docs/applications.md
git clean -f packages/piper-bin.nix          # remove the new (untracked) file
git checkout -- packages/piper-voices.nix 2>/dev/null || true   # if it had been re-added
```

Contingency specifics:
- **autoPatchelf can't find bundled `.so`**: keep the flat `$out/bin/` layout; if still failing,
  add `wrapProgram $out/bin/piper --add-flags "--espeak_data $out/bin/espeak-ng-data"` and/or
  `autoPatchelfIgnoreMissingDeps = true` (as in `python-cvc5.nix`) and re-inspect `ldd`.
- **espeak-ng-data path errors at runtime**: the data dir must stay a sibling of the `piper` binary;
  the `--espeak_data` wrapper above forces it explicitly.
- **Build regresses / user wants Piper reverted**: restore the single `picotts` line at
  `modules/system/packages.nix` and re-run `nixos-rebuild build` — the picotts package is unchanged in
  nixpkgs, so the SVOX Pico path returns immediately with no new closure cost.
