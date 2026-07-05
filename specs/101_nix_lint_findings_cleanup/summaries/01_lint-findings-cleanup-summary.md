# Implementation Summary: Task #101

**Completed**: 2026-07-05
**Duration**: ~1 session

## Overview

Drove the repository to a lint-clean state for both `statix` and `deadnix`, the two warn-only
linters added in task 98. Followed the 8-phase plan exactly in order: skip-comment the 8
intentional-convention deadnix bindings, remove the 11 safe deadnix bindings via `--edit`,
apply the 15 auto-fixable statix findings via `statix fix`, hand-collapse all 42 non-excluded
`repeated_keys` (W20) findings across three difficulty tiers (culminating in
`modules/system/desktop.nix`'s judgment-heavy `services`/`programs` merge), add path-based
exclusions for the 4 auto-generated `hardware-configuration.nix` files, and finish with a full
`nix fmt` + verification pass. `nix flake check` stayed green throughout, and both linters now
report zero findings tree-wide (the 4 hardware-configuration.nix files are excluded by design,
not hand-edited).

## What Changed

- `modules/system/boot.nix`, `modules/system/nix.nix`, `modules/system/desktop.nix` — added
  `# deadnix: skip` above the mandated `{ pkgs, lib, ... }:` header.
- `overlays/claude-squad.nix`, `overlays/python-packages.nix` — added `# deadnix: skip` above
  `final: prev:` and the two `overridePythonAttrs (old: {...})` callbacks.
- `modules/home/services/gmail-oauth2.nix` — added `# deadnix: skip` above the dormant module's
  `{ config, ... }:` header.
- `flake.nix` — removed dead `lean4`/`utils`/`inputs` destructured outputs args (flake inputs
  themselves untouched); collapsed the `home-manager` repeated-keys block; applied
  `lib = nixpkgs.lib;` -> `inherit (nixpkgs) lib;`.
- `home.nix` — reduced to `{ ... }:`; collapsed `home.*` into one `home = {...};` block.
- `packages/aristotle.nix`, `packages/claude-code.nix`, `packages/polkit-gnome-agent-wrapper.nix`,
  `packages/slidev.nix` — removed unused `lib` arg.
- 11 module headers (`modules/system/{shell,networking,services}.nix`,
  `modules/home/core/{git,xdg}.nix`, `modules/home/desktop/{waybar,mako,kanshi,swaylock}.nix`,
  `modules/home/email/{aerc,protonmail}.nix`) — `{ ... }:` -> `_:`.
- `overlays/unstable-packages.nix` — two assignment-to-`inherit` conversions (`niri`, `gemini-cli`).
- `modules/system/packages.nix` — dropped useless outer parens around `with pkgs; [ ... ]`.
- `lib/mkHost.nix`, `hosts/iso/default.nix`, `hosts/usb-installer/default.nix`,
  `modules/system/audio.nix`, `modules/system/services.nix`, `modules/home/email/aerc.nix` —
  Tier-1 W20 collapses (home-manager block, isoImage blocks, services blocks, home.file block).
- `modules/system/boot.nix`, `modules/home/core/dotfiles.nix`, `modules/home/core/xdg.nix`,
  `modules/system/power.nix` — Tier-2 whole-file-wrap W20 collapses (`boot`, `home`, `xdg`,
  partial `services`).
- `modules/system/desktop.nix` — Tier-3 collapse: merged 7 `services.*` and 4 `programs.*`
  non-contiguous occurrences into one `services = {...};` and one `programs = {...};`, leaving
  `environment.etc`, `hardware.graphics`, `security.polkit`, `xdg.portal` untouched.
- `statix.toml` (new, repo root) — `ignore` glob for `.direnv` and
  `hosts/*/hardware-configuration.nix`, with a rationale comment.
- `.github/workflows/ci.yml` — deadnix step now passes
  `--exclude 'hosts/*/hardware-configuration.nix'`.

## Decisions

- Preferred `statix fix` / `deadnix --edit` for the mechanically auto-fixable findings, hand-edited
  only what had no auto-fix (W20).
- Sequenced deadnix skip-comments (Phase 1) strictly before `--edit` (Phase 2) to protect the
  keep-set, per the plan's ordering constraint.
- Left `services.earlyoom` in `power.nix` and `displayManager`/`dconf` sub-keys in other files
  unmerged where doing so already dropped the repeated-key count below statix's 3-occurrence
  firing threshold — avoids unnecessary relocation of code while still reaching zero findings.
- Excluded the 4 auto-generated `hardware-configuration.nix` files by path (statix.toml `ignore`
  glob + deadnix CLI `--exclude`) rather than hand-editing them, since both carry a
  "Do not modify this file!" header and regeneration would silently revert any hand-fix.

## Plan Deviations

- **Phase 2** altered: `deadnix --edit --exclude 'hosts/*/hardware-configuration.nix' -- .`
  transiently stripped the `pkgs` arg from all 4 hardware-configuration.nix files despite the
  exclude flag — the `--exclude <glob> -- .` flag ordering does not reliably apply the exclusion
  in the installed deadnix version. Detected via post-edit diff review; manually restored all 4
  files to pre-edit content (`git show HEAD:<path> > <path>`) before committing. The correct,
  verified invocation order is `deadnix --exclude '<glob>' .` (flags before the positional path,
  no `--` separator) — used for all subsequent exclude-flag invocations (Phase 7's `ci.yml`
  update, final verification).
- **Phase 4** (`home.nix`): no deviation from the named 3 sub-keys, but the note that the
  post-Phase-2 `{ ... }:` header does not itself trigger a new W10 empty-pattern finding was
  verified explicitly (statix's rule apparently does not fire on this multi-line `{ ...\n}:` form
  the way it fires on the single-line 11 module headers in Phase 3 — confirmed empirically, no
  action needed).
- **Phase 5** (`modules/home/core/dotfiles.nix`) altered: the real W20 finding covered 5
  `home.*` occurrences, not the 3 named in the plan/research table (the "2 occurrences omitted"
  note covered `home.activation.claudeSettings` and `home.activation.uvTools`). Folded both
  `activation.*` entries into the same merged `home = {...}` block to fully clear the finding.
- **Phase 5** (`modules/system/power.nix`) altered: the real W20 finding covered 4 `services.*`
  occurrences, not 3 (the omitted one being `services.earlyoom`). Merged only the 3
  plan-specified entries and left `services.earlyoom` unmerged in its original position — this
  drops the file to 2 `services` occurrences, below statix's 3-occurrence firing threshold, so
  the finding still clears without relocating the earlyoom block out of its documented
  memory-management narrative position.
- **Phase 6** (`modules/system/desktop.nix`) altered: one comment
  ("Ensure proper Wayland and GNOME integration") originally headed both a `services.*` line and
  a `programs.*` line; since the two lines land in different merged blocks, the comment was
  duplicated above each destination rather than kept once. `displayManager` and `dconf` sub-keys
  were left as separate statements inside their respective merged sets (only 2 occurrences each,
  below the firing threshold).
- **Phase 7** altered: `ci.yml`'s deadnix step uses
  `deadnix --exclude 'hosts/*/hardware-configuration.nix' . || true` (no `--` separator) instead
  of the plan's literal `-- .` form, per the Phase 2 finding above.

## Verification

- `nix flake check`: green after every phase's edits (confirmed baseline-green before work
  started, and green at final completion).
- `statix check`: zero findings tree-wide (exit code 0, empty output; `statix.toml` excludes the
  4 hardware-configuration.nix files by path).
- `deadnix --exclude 'hosts/*/hardware-configuration.nix' .`: zero findings (exit code 0, empty
  output).
- `nix fmt $(git ls-files '*.nix')`: no diff at final verification — tree was already fully
  normalized from per-phase spot-fmt passes (Phases 3 and 6).
- Semantic-preservation spot-checks: ~20 targeted `nix eval` calls across Phases 4-6 confirm
  unchanged evaluated values for collapsed attrsets (home.stateVersion, aerc account-conf text,
  desktop services/programs options, power-management services, isoImage attrs).

## Notes

None of the 4 `hosts/*/hardware-configuration.nix` files were hand-edited in the final state
(one file was transiently touched by a `deadnix --edit` flag-ordering issue during Phase 2 and
restored before that commit — see Plan Deviations). The two exclusion mechanisms (`statix.toml`
ignore glob, `ci.yml` `--exclude` CLI flag) both match by path, not line number, so they survive
`nixos-generate-config` regeneration without further maintenance.
