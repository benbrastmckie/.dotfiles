# Implementation Plan: Task #96

- **Task**: 96 - documentation_completeness_gaps
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 95 (completed — supplies the corrected nandi/garuda README wording being mirrored). Related-but-not-blocking: 97 (completed — changed the package set, giving the fresh 10-file count), 99 (completed — created `docs/ryzen-ai-300.md`), 98 (deferred — a later repo-wide `nix fmt` pass that will reformat these same `packages/*.nix` files).
- **Research Inputs**: specs/096_documentation_completeness_gaps/reports/01_documentation-completeness-research.md
- **Artifacts**: plans/01_hamsa-readme-pkg-headers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Close two documentation-completeness gaps identified in task 94's cleanup backlog (Group B) and
grounded by task 96's research report. First, create `hosts/hamsa/README.md` — hamsa is the only
host lacking a README — modeling it on the CURRENT (post-task-95) garuda README wording, since
hamsa, like garuda, has no `default.nix`. Second, add a 1-3 line `#`-prefixed header comment to
exactly the 10 currently header-less `packages/*.nix` files (9 pure additions plus `claude-code.nix`,
whose existing comment must be RELOCATED above the function-argument line, not duplicated). A
one-line companion edit to `hosts/README.md`'s Structure bullet keeps that doc from going stale.
All changes are documentation/comment-only with no build or runtime impact; a single
`nix flake check` at the end confirms the `.nix` comment additions did not break parsing.

### Research Integration

The research report (`reports/01_documentation-completeness-research.md`) supplies all ground-truth
content used verbatim in this plan:
- Hamsa hardware facts sourced from `hosts/hamsa/hardware-configuration.nix` and cross-confirmed by
  `docs/ryzen-ai-300.md`: AMD Ryzen AI 9 HX 370 (Ryzen AI 300 series, Zen 4 + Zen 5c hybrid),
  `kvm-amd`, NVMe root + vfat `/boot`, Thunderbolt + USB 3.0, and a `CRITICAL`-flagged MediaTek
  `mt7925e` WiFi 6E/7 firmware requirement.
- A ready-to-write hamsa README body (report Recommendations §a), mirroring garuda's exact
  structure with hamsa-specific CPU/WiFi detail and a `docs/ryzen-ai-300.md` link.
- A fresh scan confirming exactly 10 header-less package files (superseding report 02's stale
  "9 of 13" count) plus a per-file proposed header comment (report Recommendations §b table).
- The `claude-code.nix` relocate-not-duplicate special case (report Executive Summary + Decisions).

### Prior Plan Reference

No prior plan. This is the first plan for task 96.

### Roadmap Alignment

No `roadmap_flag` set for this dispatch; ROADMAP.md consultation not requested. No roadmap phases
added.

## Goals & Non-Goals

**Goals**:
- Create `hosts/hamsa/README.md` matching the post-task-95 garuda README structure/wording, with
  hamsa-specific hardware facts and a link to `docs/ryzen-ai-300.md`.
- Add a header comment to exactly the 10 named header-less `packages/*.nix` files.
- Relocate `claude-code.nix`'s existing comment block to above the function-argument line (move, not
  add a second block).
- Update the `hosts/README.md` Structure bullet to list `hamsa/` alongside `garuda/` and `nandi/`.
- Confirm the `.nix` comment additions parse cleanly via `nix flake check`.

**Non-Goals**:
- Touching any of the 6 already-compliant package files (`opencode.nix`,
  `opencode-discord-bot.nix`, `piper-bin.nix`, `polkit-gnome-agent-wrapper.nix`,
  `sioyek-wayland.nix`, `zathura-x11.nix`).
- Reformatting or `nix fmt`-normalizing the edited files — task 98 (deferred) applies a repo-wide
  `nix fmt` pass that will normalize these same files afterward. Keep header edits minimal and
  clean; do not hand-tune whitespace to match a formatter.
- Any `nixos-rebuild` / `home-manager switch` cycle — these are doc/comment-only changes with no
  build or runtime impact.
- Editing `hosts/nandi/README.md` or `hosts/garuda/README.md` (point-in-time mirror only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `claude-code.nix` comment mis-applied as an addition, leaving two comment blocks | M | M | Phase 4 explicitly instructs "move, don't duplicate"; verify the post-arg-line copy is deleted after inserting the top copy. |
| A header line corrupts a function-argument signature (esp. `kooha.nix`'s positional-arg style `kooha: gst_all_1:`) | M | L | Header lines are contiguous `#` comments placed directly ABOVE the first code line; Phase 5 `nix flake check` catches any syntax slip. |
| Accidentally adding a header to an already-compliant file | L | L | Phase 3 operates on the explicit 9-file allowlist; Non-Goals names the 6 forbidden files. |
| Over-tuning formatting that task 98's `nix fmt` will just rewrite | L | M | Non-Goals + this plan's guidance: keep edits minimal, do not whitespace-tune. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 3, 4 |

Phases within the same wave can execute in parallel. Phases 1-4 touch disjoint files (hamsa README,
hosts README, the 9 package files, `claude-code.nix`) and are mutually independent; Phase 5 verifies
the `.nix` edits from Phases 3-4.

### Phase 1: Create hosts/hamsa/README.md [COMPLETED]

**Goal**: Add the missing per-host README for hamsa, mirroring the current garuda README structure
with hamsa-specific hardware facts.

**Tasks**:
- [ ] Create `hosts/hamsa/README.md` with the exact content below (from research report
      Recommendations §a):

```markdown
# Hamsa Host Configuration

Hardware configuration for the Hamsa system.

## Hardware Details

- **CPU**: AMD Ryzen AI 9 HX 370 (Ryzen AI 300 series, Zen 4 + Zen 5c hybrid) with KVM support (`kvm-amd`)
- **Boot**: UEFI with Thunderbolt support
- **Storage**: NVMe SSD
- **USB**: USB 3.0 and USB storage support
- **WiFi**: MediaTek `mt7925e` (WiFi 6E/7) — requires `hardware.enableRedistributableFirmware = true` (see `docs/wifi.md`)

## Files

- **hardware-configuration.nix** - Auto-generated hardware configuration

## Building

Build the Hamsa configuration:
```bash
# When on this machine
sudo nixos-rebuild switch --flake .#$(hostname)

# Or use the update script
./scripts/update.sh
```

## Notes

This hardware configuration is auto-generated by `nixos-generate-config` and should not be
modified manually. Always-on system settings belong in `modules/system/*.nix`; if hamsa needs
host-specific overrides, add `hosts/hamsa/default.nix` (hamsa does not currently have one). See
`docs/ryzen-ai-300.md` for broader Ryzen AI 300 series hardware-support notes.

[← Back to hosts](../README.md) | [← Back to main README](../../README.md)
```

- [ ] Confirm the Notes section uses garuda's "does not currently have one" phrasing (NOT nandi's
      "already used here"), since hamsa has no `default.nix`.

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `hosts/hamsa/README.md` - new file (create)

**Verification**:
- File exists and is non-empty.
- Structure matches garuda's README (Hardware Details / Files / Building / Notes / back-links).
- Contains the hamsa-specific WiFi bullet and the `docs/ryzen-ai-300.md` link.

---

### Phase 2: Companion edit — hosts/README.md Structure bullet [COMPLETED]

**Goal**: Keep `hosts/README.md`'s Structure section accurate now that hamsa has a README.

**Tasks**:
- [ ] In `hosts/README.md`, locate the Structure-section `README.md` bullet currently reading
      `Present on `garuda/` and `nandi/`.` (around line 33-34).
- [ ] Change it to `Present on `garuda/`, `hamsa/`, and `nandi/`.`
- [ ] Leave the adjacent `default.nix` bullet (which correctly lists `nandi/` and `usb-installer/`)
      unchanged.

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `hosts/README.md` - one-line edit to the Structure section's per-host README bullet

**Verification**:
- The README bullet now names `garuda/`, `hamsa/`, and `nandi/`.
- No other line in `hosts/README.md` changed.

---

### Phase 3: Add headers to the 9 header-less package files [COMPLETED]

**Goal**: Add a 1-3 line `#`-prefixed header comment directly ABOVE the function-argument line of
each of the 9 pure-addition package files, matching the established style
(`piper-bin.nix`/`opencode.nix`: contiguous comment lines touching the first code line, no blank
line between header and signature).

**Tasks** (each header text is verbatim from research report Recommendations §b):
- [ ] `packages/aristotle.nix`:
      ```
      # aristotle - AI theorem prover with Lean support, fetched via uvx on each invocation.
      # Custom because aristotlelib is a PyPI/uvx-distributed tool, not packaged in nixpkgs.
      ```
- [ ] `packages/kooha.nix`:
      ```
      # Custom kooha override: adds gst-plugins-bad (AAC encoders for MP4) and gst-libav
      # (extra codec support) to nixpkgs' kooha via overrideAttrs. Positional-arg style
      # (kooha, gst_all_1), wired via prev.kooha in overlays/unstable-packages.nix — same
      # self-referential-override pattern as sioyek-wayland.nix/zathura-x11.nix.
      ```
- [ ] `packages/loogle.nix`:
      ```
      # loogle - Lean 4 Mathlib search tool. Self-bootstrapping wrapper: clones and builds
      # nomeata/loogle into ~/.cache/loogle on first run via its own flake, since loogle
      # has no nixpkgs package.
      ```
- [ ] `packages/piper-voices.nix`:
      ```
      # Piper TTS voice model data (en_US-lessac-medium) fetched from Hugging Face.
      # Custom because this is voice-model data, not a buildable nixpkgs package.
      ```
- [ ] `packages/pymupdf4llm.nix`:
      ```
      # pymupdf4llm - LLM-optimized PDF extraction, built from the PyPI wheel.
      # Custom/pinned because it requires PyMuPDF >=1.26.6; nixpkgs currently ships 1.24.10.
      ```
- [ ] `packages/python-cvc5.nix`:
      ```
      # Python bindings for the CVC5 SMT solver, built from the manylinux wheel with
      # autoPatchelfHook/patchelf rpath fixes for bundled .so files (libstdc++). Custom
      # because nixpkgs has no Python cvc5 wheel package.
      ```
- [ ] `packages/python-vosk.nix`:
      ```
      # Python bindings for Vosk (offline speech recognition), built from the manylinux
      # wheel with autoPatchelfHook for the bundled libvosk.so. Custom because nixpkgs
      # has no Python vosk wheel package.
      ```
- [ ] `packages/slidev.nix`:
      ```
      # slidev - presentation slides from Markdown, fetched via npx on each invocation.
      # Custom because @slidev/cli is an npm-distributed tool, not packaged in nixpkgs.
      ```
- [ ] `packages/vosk-models.nix`:
      ```
      # Vosk speech-recognition model data (small English US, ~50MB), fetched and unpacked
      # from alphacephei.com. Custom because this is model data, not a buildable package.
      ```
- [ ] For each file, place the comment block immediately above the existing function-argument line
      (the `{ ... }:` attrset, or `kooha.nix`'s positional `kooha: gst_all_1:` form) with no
      intervening blank line.
- [ ] Do NOT touch `claude-code.nix` in this phase (handled in Phase 4).

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `packages/aristotle.nix`, `packages/kooha.nix`, `packages/loogle.nix`, `packages/piper-voices.nix`,
  `packages/pymupdf4llm.nix`, `packages/python-cvc5.nix`, `packages/python-vosk.nix`,
  `packages/slidev.nix`, `packages/vosk-models.nix` - prepend header comment above the arg line.

**Verification**:
- All 9 files begin with the header comment above their function signature.
- None of the 6 already-compliant files were modified (`git status` shows only the 9 + Phase 4's file
  under `packages/`).
- `head -1` of each of the 9 files is a `#` comment line.

---

### Phase 4: Relocate claude-code.nix comment above the arg line [COMPLETED]

**Goal**: Move `packages/claude-code.nix`'s existing descriptive comment block (currently positioned
AFTER the function-argument line `{ lib, writeShellScriptBin, nodejs }:`) to sit ABOVE that line, so
it matches the convention every reference file follows. This is a RELOCATION, not a second header —
do not leave a duplicate block behind.

**Tasks**:
- [ ] Read `packages/claude-code.nix` and identify the existing comment block and its current
      position relative to the `{ ... }:` argument line.
- [ ] Move that comment block (content unchanged) to directly above the argument line. Its content
      documents the npx-fetch/pinning mechanism, rebuild step, npx-cache-clear caveat, and model
      selection — preserve it verbatim; only its position changes. Expected content (from report
      Recommendations §b), adjust to match the file's actual existing text:
      ```
      # Wrapper that fetches Claude Code via npx on each invocation.
      # To pin a version, replace @latest with @X.Y.Z (e.g. @2.1.177).
      # After changing this file, rebuild with: sudo nixos-rebuild switch --flake .#<host>
      # The npx cache (~/.npm/_npx/) may also need clearing: rm -rf ~/.npm/_npx/
      # Model selection is in config/claude/settings.json (ANTHROPIC_DEFAULT_OPUS_MODEL).
      ```
- [ ] Delete the original (now post-arg-line) copy so exactly one comment block remains, positioned
      above the argument line.

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `packages/claude-code.nix` - relocate existing comment block above the function-argument line

**Verification**:
- Exactly one comment block exists in the file, positioned above the `{ ... }:` line.
- No duplicate/stale comment remains after the argument line.
- `git diff packages/claude-code.nix` shows a move (comment removed from below, added above), not a
  net addition of a second block.

---

### Phase 5: Verify parsing with nix flake check [COMPLETED]

**Goal**: Confirm the comment additions/relocation across the 10 `.nix` files did not break Nix
parsing or flake evaluation.

**Tasks**:
- [ ] From the repo root, run `nix flake check`.
- [ ] Confirm it completes without new parse/evaluation errors attributable to the edited package
      files. (Comment-only changes should not affect evaluation; any error touching one of the 10
      files indicates a mis-placed header relative to the `{ ... }:` syntax — fix and re-run.)
- [ ] Note: do NOT attempt `nix fmt` or formatting normalization here — task 98 (deferred) owns the
      repo-wide `nix fmt` pass that will reformat these files.

**Timing**: 10 minutes (dominated by flake evaluation time)

**Depends on**: 3, 4

**Files to modify**:
- None (verification only)

**Verification**:
- `nix flake check` exits 0 (or fails only for pre-existing, unrelated reasons — capture output and
  confirm no error references the 10 edited files).

---

## Testing & Validation

- [ ] `hosts/hamsa/README.md` exists, is non-empty, and mirrors garuda's README structure with the
      hamsa-specific CPU/WiFi detail and `docs/ryzen-ai-300.md` link.
- [ ] `hosts/README.md` Structure bullet lists `garuda/`, `hamsa/`, and `nandi/`.
- [ ] All 9 pure-addition package files start with their header comment above the argument line.
- [ ] `packages/claude-code.nix` has exactly one comment block, positioned above the argument line.
- [ ] None of the 6 already-compliant package files were modified.
- [ ] `nix flake check` passes (no new errors from the edited `.nix` files).
- [ ] Edits are minimal/clean (no manual formatting normalization; task 98 will `nix fmt`).

## Artifacts & Outputs

- `hosts/hamsa/README.md` (new)
- `hosts/README.md` (edited — Structure bullet)
- `packages/aristotle.nix`, `packages/kooha.nix`, `packages/loogle.nix`, `packages/piper-voices.nix`,
  `packages/pymupdf4llm.nix`, `packages/python-cvc5.nix`, `packages/python-vosk.nix`,
  `packages/slidev.nix`, `packages/vosk-models.nix` (edited — header added)
- `packages/claude-code.nix` (edited — comment relocated)
- `specs/096_documentation_completeness_gaps/summaries/01_hamsa-readme-pkg-headers-summary.md`
  (implementation summary, produced at /implement time)

## Rollback/Contingency

All changes are additive documentation/comment edits confined to `hosts/hamsa/README.md`,
`hosts/README.md`, and 10 `packages/*.nix` files, with no build/runtime impact. To revert, delete
`hosts/hamsa/README.md` and `git checkout -- hosts/README.md packages/*.nix` for the affected files
(clean tree only; snapshot first if uncommitted work exists elsewhere). If `nix flake check` fails
in Phase 5, the offending file is one of the 10 edited `.nix` files — inspect the header placement
relative to its `{ ... }:` argument line, correct it, and re-run; no other phase needs reverting.
