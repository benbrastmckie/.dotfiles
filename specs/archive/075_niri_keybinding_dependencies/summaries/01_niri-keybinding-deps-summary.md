# Implementation Summary: Task #75

**Completed**: 2026-07-04
**Duration**: ~15 minutes

## Overview

Fixed three niri keybindings in `config/config.kdl` that spawned binaries not present in the home-manager closure or system path, and added the one missing package (`playerctl`) needed by the already-correct media-transport binds. All edits were re-anchored against the fresh file content (task 74 had just modified the autostart/wallpaper section of the same file); no line-number assumptions were made without re-verifying content first.

## What Changed

- `config/config.kdl` — Mod+C (`spawn "code"` → `spawn "codium"`, comment updated to VSCodium); Mod+Shift+S and Print screenshot binds rewritten from `grimshot save area`/`grimshot save screen` to the `sh -c "grim ... | satty -f -"` form already used by Mod+Shift+A, using the identical escaped-quote pattern. Mod+Shift+A, the volume/mute binds, and task 74's autostart/wallpaper/polkit changes were left untouched.
- `modules/home/packages/media-dictation.nix` — added `playerctl` to `home.packages`, alongside the existing grim/slurp/satty screenshot tools.

## Decisions

- Chose the grim/slurp/satty rewrite over adding `pkgs.sway-contrib.grimshot`, per the plan's recommended path (consistency with the existing Mod+Shift+A bind, zero new dependency since grim/slurp/satty were already home-manager-owned).
- `playerctl` added to `modules/home/packages/media-dictation.nix` (home-manager), not `modules/system/packages.nix`, per the plan's ownership convention for niri-session tooling.

## Plan Deviations

- None (implementation followed plan).

## Verification

- `nix flake check`: Success (all NixOS configurations and home configurations evaluate cleanly; only a pre-existing, unrelated `boot.zfs.forceImportRoot` warning on two hosts).
- `home-manager build --flake .#benjamin`: Success. Inspected the built `home-path/bin`: confirmed `grim`, `slurp`, `satty`, `playerctl`, `playerctld` present. `codium` confirmed present at `/run/current-system/sw/bin/codium` (system-wide via `modules/system/packages.nix`, not home-manager — consistent with the research report).
- `grep -n grimshot config/config.kdl`: no matches.
- `grep -n 'spawn "code"' config/config.kdl`: no matches.
- Mod+Shift+A (screenshot-with-annotation) and the volume/mute binds (wpctl) confirmed unchanged by diff inspection.

## Notes

Live exercising of the keys (area/full screenshot, media play/next/prev, Mod+C launching VSCodium) in an actual niri session is an explicit manual, post-`home-manager switch` step for the user — not performed here per plan scope and orchestrator instructions (headless verification only, no `switch`, no login to niri).
