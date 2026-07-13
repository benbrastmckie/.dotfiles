# Implementation Summary: Task #95

**Completed**: 2026-07-05
**Duration**: ~40 minutes

## Overview

Fixed all remaining documentation that pointed contributors at `configuration.nix`/`home.nix` for
content that now lives in `modules/system/*.nix` and `modules/home/**/*.nix`, and closed out
`docs/dictation.md`'s three independent staleness defects (renamed `whisper-cpp` package, broken
`home.nix:183-264` line reference, dead `wtype` references). All 8 plan phases completed; this was
a markdown-only sweep with no `.nix` changes and no build required.

## What Changed

- `README.md` — repointed 7 stale pointer locations (overview bullets, core-config file
  descriptions, ASCII tree comments, customization section) to `modules/system/*.nix` /
  `modules/home/**/*.nix`; left the two mechanism-accurate `home.nix` mentions (build-evaluation
  notes) untouched.
- `hosts/nandi/README.md` — reworded the stale "System-specific changes... `configuration.nix`"
  sentence to distinguish always-on settings (`modules/system/*.nix`) from host-specific overrides
  (`hosts/nandi/default.nix`, which this host already uses).
- `hosts/garuda/README.md` — same correction, phrased as "if garuda needs host-specific overrides,
  add `hosts/garuda/default.nix`" since garuda has no existing host default.nix.
- `docs/dictation.md` — named the three real backing modules
  (`modules/home/scripts/whisper.nix`, `modules/home/services/ydotool.nix`,
  `modules/home/packages/media-dictation.nix`) in place of the `home.nix` reference; fixed the
  renamed `openai-whisper-cpp` → `whisper-cpp` package name; fixed the broken
  `home.nix:183-264` line reference to `modules/home/scripts/whisper.nix` (lines 6-74); removed
  the dead wtype Documentation Resources link; replaced the dead `wtype` Quick Reference row with
  a verified `ydotool type "text"` invocation.
- `docs/neovim.md` — repointed both `home.nix` references (prose + markdown link target) to
  `modules/home/core/neovim.nix`.
- `docs/gnome-settings.md` — repointed all 9 stale `home.nix` references to
  `modules/home/desktop/gnome.nix` (backlog had named only 5; research found 4 additional).
- `docs/discord-bot.md` — repointed all 7 stale `configuration.nix` references: 6 to
  `modules/system/optional/discord-bot.nix`, 1 (fish shell-init comment) to
  `modules/system/shell.nix` (backlog had named only 2; research found 5 additional).
- `docs/installation.md` and `docs/development.md` — reworded the identical stale "Reference
  host-specific settings in `configuration.nix`" new-host step to distinguish always-on settings
  (`modules/system/*.nix`) from host-specific overrides (`hosts/<name>/default.nix`).

## Decisions

- Left `README.md` lines 105 and 185 (originally 102, 182) — "Both commands evaluate `home.nix`"
  and "Both commands install `home.nix` packages" — unchanged, since these describe genuine build
  mechanics (the entry-point files really are what gets evaluated), not edit-target pointers.
- Left `docs/development.md:47` ("System configuration from `configuration.nix`" under ISO
  Contents) unchanged, per the plan's default: it describes the ISO build's import-chain root, not
  an edit target, and the plan explicitly marked this optional/non-required.
- Left `docs/dictation.md:166` ("Why ydotool?" sentence mentioning `wtype`) unchanged — this is
  accurate explanatory context (why wtype doesn't work with GNOME/Mutter), not one of the plan's
  enumerated "two dead wtype references" (the Resources link and Quick Reference row, both fixed).
- Sanity-checked the discord-bot.md rollback script's "4 host module imports" claim per the plan's
  optional flag: confirmed via `grep -rln "discord-bot" hosts/*/default.nix` that only
  `hosts/nandi/default.nix` currently imports the module, so the count is stale. Left unchanged
  per the plan's explicit "leave it for a separate finding" allowance — outside this task's
  `configuration.nix`-pointer scope.

## Plan Deviations

- **Phase 8 dictation-specific sweep**: `grep -n "openai-whisper\|wtype" docs/dictation.md`
  returns 1 hit (line 166) instead of the plan's stated "zero hits" expectation. This is the
  legitimate "Why ydotool?" explanatory sentence discussed above — not a defect, and consistent
  with the overall task directive to avoid over-correcting legitimate non-stale mentions. No other
  deviations; all other tasks were completed exactly as planned.

## Verification

- Phase 1-7 per-file grep sweeps: all pass (each phase's stale pointers repointed, whitelisted
  legitimate mentions preserved).
- Phase 8 consolidated sweep (`grep -n "configuration\.nix\|home\.nix"` across all 9 files):
  surviving hits are only the whitelisted legitimate mentions (README.md thin-import-shim
  descriptions/tree comments and the two build-mechanics notes, `docs/development.md:47`) plus
  incidental `hardware-configuration.nix` filename substring matches (never a sweep target).
- Dictation-specific sweep: `openai-whisper` zero hits; `wtype` 1 legitimate hit (see Deviations).
- `git status --short` confirms `hosts/README.md`, `modules/README.md`, `docs/configuration.md`
  are untouched, and exactly the 9 intended files were modified (plus concurrent, out-of-scope
  changes from tasks 97/99 to `flake.nix`, `docs/README.md`, `docs/niri.md`,
  `docs/usb-installer.md` — not touched by this task).
- No `.nix` files modified; no build or `nix flake check` required (markdown-only change set per
  the plan).

## Notes

All module-target corrections were grounded by reading the actual source files before writing:
`modules/home/scripts/whisper.nix`, `modules/home/services/ydotool.nix`,
`modules/home/packages/media-dictation.nix`, `modules/home/core/neovim.nix`,
`modules/home/desktop/gnome.nix`, `modules/system/optional/discord-bot.nix`, and
`modules/system/shell.nix` — no target was guessed.
