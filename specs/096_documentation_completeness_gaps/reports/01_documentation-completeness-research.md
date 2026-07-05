# Research Report: Task #96

**Task**: 96 - documentation_completeness_gaps
**Started**: 2026-07-05T00:00:00Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: Small (one new file + 10 one/two-line header additions)
**Dependencies**: Builds on task 95 (corrected host README wording, completed) and task 97
  (package-set change that supersedes the "9 of 13" count in the source backlog); task 99
  (created `docs/ryzen-ai-300.md`, consulted here for hamsa hardware ground truth)
**Sources/Inputs**:
- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` (Group B,
  findings 8-9 — primary source, per task instructions)
- `hosts/README.md`, `hosts/nandi/README.md`, `hosts/garuda/README.md` (current, post-task-95
  corrected wording — read as-is, not the stale phrasing report 02 described)
- `hosts/hamsa/hardware-configuration.nix` (only file currently in `hosts/hamsa/`; no
  `default.nix`)
- `docs/ryzen-ai-300.md` (task 99's consolidated Ryzen AI 300 doc; supersedes the two
  near-duplicate docs report 02's Group E flagged)
- The 10 currently header-less `packages/*.nix` files (read in full): `aristotle.nix`,
  `claude-code.nix`, `kooha.nix`, `loogle.nix`, `piper-voices.nix`, `pymupdf4llm.nix`,
  `python-cvc5.nix`, `python-vosk.nix`, `slidev.nix`, `vosk-models.nix`
- Reference files that already carry the target header style: `packages/piper-bin.nix`,
  `packages/opencode.nix`, `packages/opencode-discord-bot.nix`, `packages/sioyek-wayland.nix`,
  `packages/zathura-x11.nix`, `packages/polkit-gnome-agent-wrapper.nix`
- `overlays/unstable-packages.nix`, `overlays/python-packages.nix`, `modules/system/packages.nix`,
  `modules/home/packages/{python,misc,dev-tools}.nix`, `modules/home/core/dotfiles.nix` (consumer
  sites, used to confirm each package's role/why-it's-custom)
**Artifacts**: This report —
`specs/096_documentation_completeness_gaps/reports/01_documentation-completeness-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Hamsa README**: `hosts/hamsa/` currently contains only `hardware-configuration.nix` (no
  `default.nix`). The nandi/garuda READMEs, read fresh from disk, already carry task 95's
  corrected wording (points at `modules/system/*.nix` for always-on settings and
  `hosts/<name>/default.nix` for host-specific overrides — no stale `configuration.nix` sentence
  remains in either file). The new hamsa README should mirror that exact structure/wording,
  substituting hamsa-specific hardware facts sourced from `hosts/hamsa/hardware-configuration.nix`
  and `docs/ryzen-ai-300.md`.
- **Hamsa hardware facts** (ground truth, from `hardware-configuration.nix` comments + `boot.*`
  fields, cross-confirmed by `docs/ryzen-ai-300.md`): AMD Ryzen AI 9 HX 370 (Ryzen AI 300 series,
  Zen 4 + Zen 5c hybrid), `kvm-amd` (AMD virtualization), NVMe root + vfat `/boot`, Thunderbolt +
  USB 3.0 (`thunderbolt`, `xhci_pci`, `usb_storage` in `availableKernelModules`), and a firmware
  comment flagging MediaTek WiFi (`mt7925e` WiFi 6E/7 chip) requiring
  `hardware.enableRedistributableFirmware = true` (see `docs/wifi.md` cross-reference already
  inline in the hardware file). `hamsa` has no `default.nix`, so — unlike nandi — the "Notes"
  section should say host-specific overrides *would* go in `hosts/hamsa/default.nix` if ever
  needed (garuda's phrasing pattern, since garuda also lacks one), not claim one exists.
- **Package headers**: task 97 changed the package set since report 02 was written. A fresh count
  confirms exactly 10 files (not report 02's stale "9 of 13") currently lack a top-of-file header
  comment: `aristotle.nix`, `claude-code.nix`, `kooha.nix`, `loogle.nix`, `piper-voices.nix`,
  `pymupdf4llm.nix`, `python-cvc5.nix`, `python-vosk.nix`, `slidev.nix`, `vosk-models.nix`. Note
  `claude-code.nix` is a special case: it already has an inline comment block, but it sits *after*
  the function-argument line (`{ lib, writeShellScriptBin, nodejs }:`), not before it — every
  reference file (`piper-bin.nix`, `opencode.nix`, `sioyek-wayland.nix`, `zathura-x11.nix`,
  `polkit-gnome-agent-wrapper.nix`) puts its header **above** the argument line. So
  `claude-code.nix` needs its header *moved* to the top, not merely added.
- Confirmed 6 files already meet the convention and must NOT be touched: `opencode.nix`,
  `opencode-discord-bot.nix`, `piper-bin.nix`, `polkit-gnome-agent-wrapper.nix`,
  `sioyek-wayland.nix`, `zathura-x11.nix`.
- Established the header style from the 6 reference files: 1-3 `#`-prefixed lines directly above
  the function signature, stating (a) what the derivation builds/wraps and (b) why it's a custom
  derivation rather than a plain nixpkgs package (version pin needed, wrapper behavior, nixpkgs
  gap, GitHub-release fetch, etc.) — matching `piper-bin.nix`'s and `opencode.nix`'s style
  exactly. No blank-line-then-header pattern; comment lines are contiguous and touch the first
  code line.

## Context & Scope

Research-only task, no files modified. Scope: (a) source accurate hamsa hardware/role facts and a
README structure that matches the task-95-corrected nandi/garuda READMEs; (b) read all 10
currently header-less `packages/*.nix` files plus their 6 already-headed siblings (for style
calibration) and their consumer/overlay sites (for accurate "why custom" framing), to hand the
planner an exact per-file header proposal.

## Findings

### Existing Configuration

**`hosts/README.md`** (current) still reads "Present on `garuda/` and `nandi/`" for the
per-host `README.md` bullet in its Structure section — this line will go stale the moment
`hosts/hamsa/README.md` is created. Report 02's finding 8 explicitly calls for updating this
bullet "once created." This is a one-line, low-risk companion edit in the same doc-only family as
the main hamsa-README addition — flagged for the plan to include even though it's not separately
numbered in the task's two-item description, since leaving it stale immediately re-creates a
documentation-completeness gap of exactly the kind this task exists to close.

**`hosts/nandi/README.md`** and **`hosts/garuda/README.md`** (read fresh, current state):
Structure is identical between the two:
```
# {Host} Host Configuration

Hardware configuration for the {Host} system.

## Hardware Details
- **CPU**: ...
- **Boot**: ...
- **Storage**: ...
- **USB**: ...

## Files
- **hardware-configuration.nix** - Auto-generated hardware configuration

## Building
Build the {Host} configuration:
```bash
...
```

## Notes
This hardware configuration is auto-generated by `nixos-generate-config` and should not be
modified manually. Always-on system settings belong in `modules/system/*.nix`; {host-specific
override sentence, tailored to whether default.nix exists}.

[← Back to hosts](../README.md) | [← Back to main README](../../README.md)
```
The only wording difference between the two is the "Notes" section's second sentence, tailored to
whether the host has a `default.nix`:
- nandi (has `default.nix`, opt-in Discord bot): "host-specific overrides for this machine go in
  `hosts/nandi/default.nix` (already used here for the opt-in Discord bot module)."
- garuda (no `default.nix`): "if garuda needs host-specific overrides, add
  `hosts/garuda/default.nix` (garuda does not currently have one)."

Hamsa also has no `default.nix` (confirmed: `ls hosts/hamsa/` returns only
`hardware-configuration.nix`), so hamsa's Notes section should follow **garuda's** phrasing
pattern, not nandi's.

**`hosts/hamsa/hardware-configuration.nix`** (only file in the directory) — hardware facts:
- `boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ]`
  → NVMe SSD, USB 3.0 (`xhci_pci`), Thunderbolt, USB storage support.
- `boot.kernelModules = [ "kvm-amd" ]` → AMD virtualization (KVM), confirming AMD not Intel (unlike
  nandi/garuda's "Intel with KVM support").
- `fileSystems."/"` is `ext4` on NVMe (`/dev/disk/by-uuid/...`); `fileSystems."/boot"` is `vfat`
  (UEFI ESP).
- Inline comment: `# Enable firmware with redistributable licenses (includes MediaTek WiFi
  firmware)` / `# CRITICAL: Required for mt7925e WiFi 6E/7 chip - see docs/wifi.md` — this is a
  hamsa-specific hardware note the nandi/garuda READMEs have no equivalent of (neither mentions
  WiFi chip specifics), worth including as an extra bullet or Notes callout since it's flagged
  CRITICAL in the source file itself.
- `hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware`
  → AMD microcode updates enabled.
- `nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux"`.

**`docs/ryzen-ai-300.md`** (task 99, consolidated doc — supersedes the two near-duplicate docs
report 02's Group E flagged as needing a user decision; that decision appears already resolved by
task 99's consolidation) — corroborates and adds color beyond the hardware-configuration.nix
comments:
- Processor: **AMD Ryzen™ AI 9 HX 370** (Ryzen AI 300 Series), **Zen 4 + Zen 5c hybrid
  architecture**, `x86_64-linux`.
- Confirms Thunderbolt 4/5, USB 3.0/3.1/4.0 (`xhci_pci`), NVMe, integrated Radeon graphics (RDNA
  3/3.5), XDNA 2 NPU (kernel 6.5+ for AI acceleration), AMD P-state power management.
- This doc is a general Ryzen-AI-300-series reference (useful for anyone installing NixOS on this
  CPU class), not hamsa-specific — the hamsa README should stay terse (per nandi/garuda's own
  terseness) and can optionally link to `docs/ryzen-ai-300.md` for the deeper hardware-support
  narrative rather than duplicating its content.

### Package Files — Fresh Header-Presence Scan

Verified via `head -1` / full read of all 16 `packages/*.nix` files (superseding report 02's stale
"9 of 13" count, which predates task 97's package-set change):

| File | Header present? | Notes |
|---|---|---|
| `aristotle.nix` | No | Needs header |
| `claude-code.nix` | Comment exists but **misplaced** (after arg line) | Needs header moved to top |
| `kooha.nix` | No | Needs header |
| `loogle.nix` | No | Needs header |
| `opencode-discord-bot.nix` | Yes | Do not touch |
| `opencode.nix` | Yes | Do not touch |
| `piper-bin.nix` | Yes | Do not touch (style reference) |
| `piper-voices.nix` | No | Needs header |
| `polkit-gnome-agent-wrapper.nix` | Yes | Do not touch |
| `pymupdf4llm.nix` | No | Needs header |
| `python-cvc5.nix` | No | Needs header |
| `python-vosk.nix` | No | Needs header |
| `sioyek-wayland.nix` | Yes | Do not touch |
| `slidev.nix` | No | Needs header |
| `vosk-models.nix` | No | Needs header |
| `zathura-x11.nix` | Yes | Do not touch |

10 files confirmed needing a header, matching the task's given list exactly.

### Per-File Purpose (from file contents + consumer/overlay sites)

- **`aristotle.nix`**: `writeShellScriptBin` wrapper that runs `uvx --from aristotlelib@latest
  aristotle "$@"`. Consumed in `modules/system/packages.nix:76` with inline comment "AI theorem
  prover with Lean". Custom because it's a `uvx`-fetched Python tool, not packaged in nixpkgs.
- **`claude-code.nix`**: `writeShellScriptBin "claude"` wrapper around `npx
  @anthropic-ai/claude-code@latest`. Existing (misplaced) comment already documents the pinning
  mechanism, rebuild step, and npx-cache-clear caveat — this content is worth preserving, just
  relocated above the arg line. Consumed via `overlays/unstable-packages.nix:9` ("Latest AI
  capabilities (custom build)").
- **`kooha.nix`**: Takes `kooha` and `gst_all_1` as positional args (not `callPackage`'d — wired
  via `import ../packages/kooha.nix prev.kooha final.gst_all_1` per
  `overlays/unstable-packages.nix:16`, matching the same self-referential-override pattern as
  `sioyek-wayland.nix`/`zathura-x11.nix`). `overrideAttrs` adds `gst-plugins-bad` (AAC encoders for
  MP4) and `gst-libav` (extra codecs) to nixpkgs' `kooha`. Custom because nixpkgs' default kooha
  lacks these GStreamer plugins needed for MP4 export.
- **`loogle.nix`**: `writeShellScriptBin "loogle"` — self-bootstrapping wrapper that clones and
  builds `nomeata/loogle` (Lean 4 Mathlib search tool) into `~/.cache/loogle` on first run via `nix
  develop`. Consumed in `overlays/unstable-packages.nix:13` / `modules/home/packages/misc.nix:15`
  ("Lean 4 Mathlib search tool (wrapper script)"). Custom because loogle has no nixpkgs package;
  this wraps its own flake-based build.
- **`piper-voices.nix`**: `stdenv.mkDerivation` fetching two Hugging Face assets (ONNX model +
  JSON config) for Piper TTS's "en_US-lessac-medium" voice, installing them into `$out`. Consumed
  as `piper-voice-en-us-lessac-medium` in `overlays/unstable-packages.nix:27` ("Piper TTS voice
  model"). Custom because voice model data isn't packaged by nixpkgs at all (data fetch, not a
  build).
- **`pymupdf4llm.nix`**: `buildPythonPackage` for the `pymupdf4llm` PyPI wheel (LLM-optimized PDF
  extraction, depends on `pymupdf`+`tabulate`). Wired via `overlays/python-packages.nix:7`
  (comment: "Adds cvc5, pymupdf4llm, vosk... custom package"); currently referenced but
  **commented out** in `modules/home/packages/python.nix:50` ("TEMPORARILY DISABLED: requires
  PyMuPDF 1.26.6, nixpkgs has 1.24.10" — worth noting in the header since it explains the
  version-pin motivation, though the disabled-consumption fact itself belongs to `python.nix`, not
  this file).
- **`python-cvc5.nix`**: `buildPythonPackage` for the `cvc5` SMT solver's Python bindings, fetched
  as a manylinux wheel with `autoPatchelfHook`/`patchelf` rpath fixes for bundled `.so` files.
  Wired via `overlays/python-packages.nix:6`; consumed in `modules/home/packages/python.nix:11`.
  Custom because nixpkgs lacks Python cvc5 bindings as a wheel-based package needing binary
  patching.
- **`python-vosk.nix`**: `buildPythonPackage` for the `vosk` PyPI wheel (offline speech
  recognition), manylinux wheel + `autoPatchelfHook` for `libvosk.so`, several propagated deps
  (`cffi`, `requests`, `tqdm`, `srt`, `websockets`). Wired via `overlays/python-packages.nix:8`;
  consumed in `modules/home/packages/python.nix:53` ("Offline speech recognition (custom
  package)"). Same "no nixpkgs package, needs binary patching" rationale as `python-cvc5.nix`.
- **`slidev.nix`**: `writeShellScriptBin "slidev"` wrapper around `npx @slidev/cli@latest`.
  Consumed via `overlays/unstable-packages.nix:15` / `modules/home/packages/dev-tools.nix:8`
  ("Presentation slides from Markdown (sli.dev)"). Custom because it's an npx-fetched Node tool,
  same pattern as `claude-code.nix`/`slidev`'s own npx wrapper style.
- **`vosk-models.nix`**: `stdenv.mkDerivation` using `fetchzip` to download and unpack the
  small English Vosk STT model (~50MB). Consumed as `vosk-model-small-en-us` in
  `overlays/unstable-packages.nix:28` and symlinked into `~/.local/share/vosk/...` by
  `modules/home/core/dotfiles.nix:55`. Custom for the same reason as `piper-voices.nix` — model
  data, not a nixpkgs package.

### Community Patterns

Not applicable — this is a pure documentation/comment-completeness task; no external package
research was needed since every fact was sourced from the local tree (hardware config, existing
READMEs, overlay/consumer sites).

## Recommendations

### (a) `hosts/hamsa/README.md` — proposed content

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

Rationale for each deviation from a literal nandi/garuda copy:
- CPU line names the exact model + hybrid architecture (nandi/garuda only say "Intel with KVM
  support" since they don't have a dedicated Ryzen doc to cross-reference; hamsa does, via task
  99, so it's worth being more specific here — this is additive, not a format break, since the
  bullet list shape is unchanged).
- Added a "WiFi" bullet — the only host-specific hardware quirk hamsa's own
  `hardware-configuration.nix` flags as `CRITICAL`; nandi/garuda have no equivalent bullet so this
  is a hamsa-specific addition, not a template deviation.
- Notes section follows garuda's "does not currently have one" phrasing (hamsa has no
  `default.nix`, same as garuda), not nandi's "already used here" phrasing.
- Added one link to `docs/ryzen-ai-300.md` in the Notes paragraph — optional but low-risk; keeps
  the per-host README terse while pointing at the deeper reference doc instead of duplicating it
  (avoids recreating the near-duplicate-content problem report 02's Group E flagged for the old
  two-Ryzen-doc pair).

**Companion edit** (not part of the task's two numbered items, but flagged as directly caused by
adding this file): update `hosts/README.md`'s Structure section bullet from `Present on
`garuda/` and `nandi/`.` to `Present on `garuda/`, `hamsa/`, and `nandi/`.` — one line, zero risk,
prevents the doc from going stale the instant the new README lands.

### (b) Package header table — proposed header per file

All headers use the established 1-3 line `#`-prefixed style, placed immediately above the
function-argument line (no blank line between header and signature), matching
`piper-bin.nix`/`opencode.nix`/`sioyek-wayland.nix` exactly.

| File | Proposed header comment |
|---|---|
| `aristotle.nix` | `# aristotle - AI theorem prover with Lean support, fetched via uvx on each invocation.`<br>`# Custom because aristotlelib is a PyPI/uvx-distributed tool, not packaged in nixpkgs.` |
| `claude-code.nix` | *(move existing comment block to above the arg line, unchanged in content)*:<br>`# Wrapper that fetches Claude Code via npx on each invocation.`<br>`# To pin a version, replace @latest with @X.Y.Z (e.g. @2.1.177).`<br>`# After changing this file, rebuild with: sudo nixos-rebuild switch --flake .#<host>`<br>`# The npx cache (~/.npm/_npx/) may also need clearing: rm -rf ~/.npm/_npx/`<br>`# Model selection is in config/claude/settings.json (ANTHROPIC_DEFAULT_OPUS_MODEL).` |
| `kooha.nix` | `# Custom kooha override: adds gst-plugins-bad (AAC encoders for MP4) and gst-libav`<br>`# (extra codec support) to nixpkgs' kooha via overrideAttrs. Positional-arg style`<br>`# (kooha, gst_all_1), wired via prev.kooha in overlays/unstable-packages.nix — same`<br>`# self-referential-override pattern as sioyek-wayland.nix/zathura-x11.nix.` |
| `loogle.nix` | `# loogle - Lean 4 Mathlib search tool. Self-bootstrapping wrapper: clones and builds`<br>`# nomeata/loogle into ~/.cache/loogle on first run via its own flake, since loogle`<br>`# has no nixpkgs package.` |
| `piper-voices.nix` | `# Piper TTS voice model data (en_US-lessac-medium) fetched from Hugging Face.`<br>`# Custom because this is voice-model data, not a buildable nixpkgs package.` |
| `pymupdf4llm.nix` | `# pymupdf4llm - LLM-optimized PDF extraction, built from the PyPI wheel.`<br>`# Custom/pinned because it requires PyMuPDF >=1.26.6; nixpkgs currently ships 1.24.10.` |
| `python-cvc5.nix` | `# Python bindings for the CVC5 SMT solver, built from the manylinux wheel with`<br>`# autoPatchelfHook/patchelf rpath fixes for bundled .so files (libstdc++). Custom`<br>`# because nixpkgs has no Python cvc5 wheel package.` |
| `python-vosk.nix` | `# Python bindings for Vosk (offline speech recognition), built from the manylinux`<br>`# wheel with autoPatchelfHook for the bundled libvosk.so. Custom because nixpkgs`<br>`# has no Python vosk wheel package.` |
| `slidev.nix` | `# slidev - presentation slides from Markdown, fetched via npx on each invocation.`<br>`# Custom because @slidev/cli is an npm-distributed tool, not packaged in nixpkgs.` |
| `vosk-models.nix` | `# Vosk speech-recognition model data (small English US, ~50MB), fetched and unpacked`<br>`# from alphacephei.com. Custom because this is model data, not a buildable package.` |

Notes for the planner:
- `claude-code.nix` is the one file requiring an edit (moving a comment block), not a pure
  addition — flag this distinctly from the other 9 pure-addition files in the plan's phase/step
  breakdown, since it touches an existing comment rather than only inserting new lines.
- All 10 changes are comment-only / additive; no `nix flake check` is strictly required, but
  running it once after all 10 edits (cheap, fast) is good practice to catch any accidental syntax
  slip (e.g., a header line placed wrong relative to Nix's `{ ... }:` argument-set syntax) before
  considering the phase done.
- Do not add headers to any of the 6 files already confirmed to have one (`opencode.nix`,
  `opencode-discord-bot.nix`, `piper-bin.nix`, `polkit-gnome-agent-wrapper.nix`,
  `sioyek-wayland.nix`, `zathura-x11.nix`).

## Decisions

- Followed garuda's (not nandi's) Notes-section phrasing for hamsa, since hamsa — like garuda,
  unlike nandi — has no `default.nix`.
- Added a hamsa-specific WiFi bullet and a `docs/ryzen-ai-300.md` cross-link that nandi/garuda's
  READMEs don't have, since these are genuinely hamsa-specific facts (flagged `CRITICAL` in
  hamsa's own hardware-configuration.nix comment) rather than template drift — recommended as
  in-scope additive detail, not a deviation the planner should second-guess.
- Flagged the `hosts/README.md` Structure-bullet update as an in-scope companion edit even though
  it's outside the task's literal two-item list, because leaving it stale immediately regresses
  the exact kind of gap this task is meant to close.
- Used the fresh 10-file count (matching the task's provided list) rather than report 02's stale
  "9 of 13", per the task's explicit instruction that task 97 changed the package set.
- Treated `claude-code.nix` as "relocate existing comment above the arg line" rather than
  "leave as-is + add a second header", to avoid duplicate/redundant commentary in one file.

## Risks & Mitigations

- **Risk**: `claude-code.nix`'s comment-move could be mis-applied as an addition instead of a
  relocation, leaving two comment blocks (one stale-positioned, one new). Mitigation: plan should
  explicitly instruct "move, don't duplicate."
- **Risk**: A header edit could accidentally shift or corrupt the function-argument line syntax
  (e.g., `kooha.nix`'s unusual positional-arg-style signature `kooha: gst_all_1:` rather than an
  attrset). Mitigation: run `nix flake check` after all 10 header edits as a cheap safety net,
  even though these are comment-only changes.
- **Risk**: Copying nandi/garuda's README template too literally could re-introduce the very
  staleness pattern task 95 fixed, if a future edit to those two files' wording isn't mirrored to
  hamsa. Mitigation: none needed for this task (point-in-time copy is fine), but noted for future
  maintainers — if the Group A "corrected wording" pattern changes again, hamsa's README should be
  updated in the same pass as nandi/garuda's.
- No `nixos-rebuild`/`home-manager switch` cycle is needed for either (a) or (b) — both are
  doc/comment-only changes with no build/runtime impact, matching report 02's own risk assessment
  for Group B.

## Appendix

### Search/verification commands used

```bash
cat hosts/README.md
ls hosts/ hosts/hamsa/
cat hosts/nandi/README.md hosts/garuda/README.md
cat hosts/hamsa/hardware-configuration.nix
find . -iname "ryzen*" -not -path "*/.git/*"
cat docs/ryzen-ai-300.md
for f in packages/*.nix; do head -1 "$f"; done   # header-comment presence re-check (16 files)
cat packages/{aristotle,claude-code,kooha,loogle,piper-voices,pymupdf4llm,python-cvc5,python-vosk,slidev,vosk-models}.nix
cat packages/{piper-bin,opencode,opencode-discord-bot,sioyek-wayland,zathura-x11,polkit-gnome-agent-wrapper}.nix
grep -rn "aristotle|loogle|kooha|piper-voices|pymupdf4llm|python-cvc5|cvc5|python-vosk|vosk|slidev|vosk-models" overlays/ modules/
grep -n "claude-code|claude" overlays/*.nix modules/system/packages.nix modules/home/**/*.nix
```

### Files read in full

`specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md`,
`hosts/README.md`, `hosts/nandi/README.md`, `hosts/garuda/README.md`,
`hosts/hamsa/hardware-configuration.nix`, `docs/ryzen-ai-300.md`, all 16 `packages/*.nix` files
(10 header-less + 6 reference), relevant lines of `overlays/unstable-packages.nix`,
`overlays/python-packages.nix`, `modules/system/packages.nix`,
`modules/home/packages/{python,misc,dev-tools}.nix`, `modules/home/core/dotfiles.nix`.

### Cross-references

- `specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md` — Group B
  (findings 8-9), the primary source for this task's scope.
- Task 95 (completed) — source of the corrected nandi/garuda README wording being mirrored here.
- Task 97 (completed) — changed the `packages/*.nix` file set, superseding report 02's stale
  count; this report uses the fresh 10-file scan the task description specified.
- Task 99 (completed) — created `docs/ryzen-ai-300.md`, consulted here for hamsa hardware
  ground truth and linked from the proposed hamsa README.
