# Implementation Plan: Replace piper-tts with svox pico and drop onnxruntime

- **Task**: 62 - Replace piper-tts with svox pico and drop onnxruntime
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/062_replace_piper_with_svox_pico_drop_onnxruntime/reports/01_replace-piper-svox-pico.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Replace piper-tts with the svox pico TTS engine (`pico2wave`) across the NixOS dotfiles configuration and agent hook scripts to eliminate onnxruntime (~500 MB) from the system closure. The change spans two git repositories: `~/.dotfiles` (Nix configuration, 1 dotfiles hook copy) and `~/.config/nvim` (4 hook copies, all documentation). Additionally remove markitdown from home packages (its magika dependency pulls onnxruntime unconditionally) and espeak-ng (piper-only dependency). The task touches Nix configuration files, 5 shell hook scripts, and 9 documentation files.

### Research Integration

The research report (01_replace-piper-svox-pico.md) verified:
- `pkgs.svox` is the correct nixpkgs attribute; `pico2wave` is the mainProgram; only dependency is `popt` (zero onnxruntime)
- pico2wave cannot pipe to stdout -- must write to a named .wav file then play with aplay/paplay
- markitdown imports magika unconditionally, which depends on onnxruntime; must be removed entirely from home packages
- espeak-ng was listed as a piper dependency and has no other consumers
- 4 of 5 tts-notify.sh copies are identical; the 5th (`~/.config/nvim/.claude/hooks/tts-notify.sh`) has a TTS_COOLDOWN feature that must be preserved
- All speak() function branches must switch to temp-file pattern (no stdout piping with pico2wave)
- `PIPER_MODEL` env var and model existence check are eliminated (pico2wave bundles language data in the Nix store)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No actionable ROADMAP.md items for this task.

## Goals & Non-Goals

**Goals**:
- Remove piper-tts, espeak-ng, piper-voices.nix, and markitdown from the system/home closure
- Add pkgs.svox to configuration.nix
- Update all 5 tts-notify.sh copies to use pico2wave with temp-file pattern
- Preserve the TTS_ENABLED toggle contract (tts-config.sh unchanged, which-key.lua toggle continues to work)
- Preserve the TTS_COOLDOWN feature in the ~/.config/nvim/.claude/hooks variant
- Update all documentation to reference pico2wave instead of piper
- Verify the build succeeds and onnxruntime is absent from the new closure

**Non-Goals**:
- Running `nixos-rebuild switch` or `home-manager switch` (build-only verification; user switches)
- Changing the TTS_ENABLED toggle mechanism or tts-config.sh
- Modifying which-key.lua or any Neovim Lua files
- Changing settings.json hook registrations (paths unchanged)
- Evaluating alternative TTS engines (decision already made: svox pico)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| pico2wave voice quality lower than piper | L | H | Expected and acceptable for short tab-notification phrases |
| markitdown removal breaks a workflow | M | L | Document on-demand `nix shell` invocation in comment and docs |
| Temp .wav file leak if timeout kills process | L | L | `rm -f` in bash subshell handles cleanup; PID-named files avoid collisions |
| specs/tmp not present in nvim repo hooks | M | M | `mkdir -p specs/tmp` already in speak() body pattern |
| 5 hook copies diverge during implementation | M | L | Update all atomically in Phase 2; verify with diff after changes |
| Build fails due to missing overlay reference | H | L | Phase 4 catches this before user switches |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 1, 2 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Nix Configuration Changes [NOT STARTED]

**Goal**: Remove piper-tts, espeak-ng, piper-voices.nix, and markitdown from the Nix configuration; add svox; clean up flake overlay and home.nix symlink.

**Tasks**:
- [ ] Edit `configuration.nix` lines 635-636: replace `piper-tts` and `espeak-ng` with `svox` (with comment `# SVOX Pico text-to-speech engine (pico2wave command)`)
- [ ] Edit `home.nix` line 401: remove `markitdown` from Python packages; add comment `# markitdown removed - depends on magika->onnxruntime; use: nix shell nixpkgs#python3Packages.markitdown`
- [ ] Edit `home.nix` line 1199: remove the `.local/share/piper` symlink line entirely
- [ ] Edit `flake.nix` line 99: remove the `piper-voice-en-us-lessac-medium` overlay entry
- [ ] Delete file `packages/piper-voices.nix`

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `configuration.nix` - Replace piper-tts + espeak-ng with svox (lines 635-636)
- `home.nix` - Remove markitdown (line 401) and piper symlink (line 1199)
- `flake.nix` - Remove piper-voice overlay entry (line 99)
- `packages/piper-voices.nix` - Delete entire file

**Verification**:
- `grep -rn "piper" configuration.nix home.nix flake.nix` returns no results
- `grep -n "svox" configuration.nix` shows the new entry
- `packages/piper-voices.nix` no longer exists
- `grep -n "markitdown" home.nix` returns only the comment about on-demand usage

---

### Phase 2: Hook Script Updates [NOT STARTED]

**Goal**: Update all 5 tts-notify.sh copies to use pico2wave instead of piper, preserving the TTS_ENABLED contract and the TTS_COOLDOWN feature in the variant copy.

**Tasks**:
- [ ] Update Group A (4 identical files) -- for each file:
  - Update header comment: "Piper TTS" -> "pico2wave TTS"
  - Update requirements comment: "piper-tts" -> "svox (pico2wave)"
  - Remove `PIPER_MODEL` from configuration comment block
  - Remove `PIPER_MODEL` variable assignment line
  - Update speak() function comment: "via piper" -> "via pico2wave"
  - Replace speak() body: both paplay and aplay branches use temp-file pattern with `pico2wave -w`
  - Replace piper availability check with pico2wave check
  - Remove model existence check block entirely
- [ ] Update Group B (`~/.config/nvim/.claude/hooks/tts-notify.sh`) with same changes as Group A, verifying the TTS_COOLDOWN block is preserved unchanged
- [ ] Verify all 5 files no longer contain `piper` or `PIPER_MODEL` references
- [ ] Verify Group B file still contains `TTS_COOLDOWN` logic

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify** (all tts-notify.sh):
- `~/.dotfiles/.claude/hooks/tts-notify.sh` - Group A
- `~/.config/nvim/.claude/extensions/core/hooks/tts-notify.sh` - Group A
- `~/.config/nvim/.opencode/hooks/tts-notify.sh` - Group A
- `~/.config/nvim/.opencode/extensions/core/hooks/tts-notify.sh` - Group A
- `~/.config/nvim/.claude/hooks/tts-notify.sh` - Group B (cooldown variant)

**Verification**:
- `grep -l "piper" ~/.dotfiles/.claude/hooks/tts-notify.sh ~/.config/nvim/.claude/hooks/tts-notify.sh ~/.config/nvim/.claude/extensions/core/hooks/tts-notify.sh ~/.config/nvim/.opencode/hooks/tts-notify.sh ~/.config/nvim/.opencode/extensions/core/hooks/tts-notify.sh` returns empty
- `grep -c "pico2wave" <each file>` returns positive count in each
- `grep "TTS_COOLDOWN" ~/.config/nvim/.claude/hooks/tts-notify.sh` returns matches
- `grep "TTS_ENABLED" <each file>` returns matches (contract preserved)
- `diff` the 4 Group A files against each other confirms they remain identical

---

### Phase 3: Documentation Updates [NOT STARTED]

**Goal**: Update all copies of tts-stt-integration.md (5 files) and neovim-integration.md (4 files) to replace piper/espeak-ng references with svox/pico2wave.

**Tasks**:
- [ ] Update tts-stt-integration.md (Group A, 3 files -- identical content):
  - Requirements: `piper-tts` -> `svox (pico2wave)`; remove `espeak-ng` line
  - Dependency table: `piper-tts | Neural text-to-speech` -> `svox (pico2wave) | Lightweight text-to-speech`; remove espeak-ng row
  - Remove "Piper Voice Model" download instructions section entirely
  - Configuration table: remove `PIPER_MODEL` row
  - Add note: pico2wave uses bundled language data, no manual model download
  - Troubleshooting: `which piper` -> `which pico2wave`; remove model path check
  - Uninstall: remove `~/.local/share/piper/` step
- [ ] Update tts-stt-integration.md (Groups B and C, 2 files -- variants with same piper content)
  - Apply equivalent changes as Group A, respecting structural differences
- [ ] Update neovim-integration.md (Group A, 3 files -- identical):
  - Remove `export PIPER_MODEL=...` line
  - Replace `which piper` -> `which pico2wave`
  - Replace model path check with `pico2wave -w /tmp/test.wav "test" && echo "works"`
- [ ] Update neovim-integration.md (Group B, 1 file -- variant):
  - Apply equivalent changes, respecting different line numbers

**Timing**: 40 minutes

**Depends on**: 1, 2

**Files to modify**:
- `~/.dotfiles/.claude/context/project/neovim/guides/tts-stt-integration.md` - Group A
- `~/.config/nvim/.claude/context/project/neovim/guides/tts-stt-integration.md` - Group A
- `~/.config/nvim/.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - Group A
- `~/.config/nvim/.opencode/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - Group B
- `~/.config/nvim/.opencode/docs/guides/tts-stt-integration.md` - Group C
- `~/.dotfiles/.claude/context/project/neovim/guides/neovim-integration.md` - Group A
- `~/.config/nvim/.claude/context/project/neovim/guides/neovim-integration.md` - Group A
- `~/.config/nvim/.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - Group A
- `~/.config/nvim/.opencode/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - Group B

**Verification**:
- `grep -rl "piper" <all 9 doc files>` returns empty
- `grep -l "pico2wave" <all 9 doc files>` returns all 9
- No mention of `PIPER_MODEL`, `espeak-ng`, or `~/.local/share/piper` in any doc file

---

### Phase 4: Build Verification [NOT STARTED]

**Goal**: Verify the Nix configuration builds successfully after all changes. Provide a smoke test command for the user to run post-switch.

**Tasks**:
- [ ] Run `nix flake check` in `~/.dotfiles` to verify flake syntax and evaluation
- [ ] Run `nixos-rebuild build --flake /home/benjamin/.dotfiles#default` to verify the system configuration builds (do NOT switch)
- [ ] Run `home-manager build --flake /home/benjamin/.dotfiles#benjamin` to verify the home configuration builds
- [ ] If any build fails, diagnose and fix the issue in Phase 1 files, then re-verify
- [ ] Document smoke test command for user to run after switching: `pico2wave -w /tmp/test-tts.wav "Hello from pico2wave" && paplay /tmp/test-tts.wav; rm -f /tmp/test-tts.wav`

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only; fixes loop back to Phase 1 files if needed)

**Verification**:
- `nix flake check` exits 0
- `nixos-rebuild build` exits 0
- `home-manager build` exits 0

---

### Phase 5: Closure Verification (onnxruntime elimination) [NOT STARTED]

**Goal**: Verify that onnxruntime is no longer present in the new system closure, confirming the primary objective of the task.

**Tasks**:
- [ ] Run `nix why-depends` against the built system configuration to check for onnxruntime: `nix why-depends /home/benjamin/.dotfiles#nixosConfigurations.default.config.system.build.toplevel nixpkgs#onnxruntime 2>&1` -- expected result: no dependency path found
- [ ] Run `nix why-depends` against the built home-manager configuration for onnxruntime
- [ ] If onnxruntime is still found, trace the dependency chain and identify the remaining consumer; fix if possible, document if not
- [ ] Create separate commits: one for ~/.dotfiles changes, one for ~/.config/nvim changes (different git repos)

**Timing**: 20 minutes

**Depends on**: 4

**Files to modify**:
- None (verification only; fixes would be in earlier phases)

**Verification**:
- `nix why-depends` shows no path to onnxruntime for either system or home closure
- Two clean git commits created (one per repo)
- `nix path-info -rS` on the built system shows reduced closure size vs current

---

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `nixos-rebuild build --flake .#default` succeeds
- [ ] `home-manager build --flake .#benjamin` succeeds
- [ ] No `piper`, `PIPER_MODEL`, or `espeak-ng` references remain in modified files
- [ ] All 5 tts-notify.sh files reference `pico2wave`
- [ ] Group B hook retains TTS_COOLDOWN feature
- [ ] TTS_ENABLED contract preserved in all hooks and tts-config.sh untouched
- [ ] `nix why-depends` shows no onnxruntime in system or home closure
- [ ] Post-switch smoke test: `pico2wave -w /tmp/test.wav "Tab 3 researched" && paplay /tmp/test.wav; rm -f /tmp/test.wav`

## Artifacts & Outputs

- `specs/062_replace_piper_with_svox_pico_drop_onnxruntime/plans/01_implementation-plan.md` (this file)
- `specs/062_replace_piper_with_svox_pico_drop_onnxruntime/summaries/01_execution-summary.md` (after implementation)

## Rollback/Contingency

All changes are in version-controlled files across two git repos. To revert:
1. In `~/.dotfiles`: `git checkout HEAD~1 -- configuration.nix home.nix flake.nix packages/piper-voices.nix .claude/hooks/tts-notify.sh .claude/context/project/neovim/guides/tts-stt-integration.md .claude/context/project/neovim/guides/neovim-integration.md`
2. In `~/.config/nvim`: `git checkout HEAD~1 -- .claude/hooks/tts-notify.sh .claude/extensions/core/hooks/tts-notify.sh .opencode/hooks/tts-notify.sh .opencode/extensions/core/hooks/tts-notify.sh` (plus doc files)
3. Run `nixos-rebuild switch --flake ~/.dotfiles#default` and `home-manager switch --flake ~/.dotfiles#benjamin` to restore piper-based configuration

The piper voice model data remains in the Nix store until garbage collected, so reverting is safe even after switching.
