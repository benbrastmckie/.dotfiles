# Implementation Summary: Task #76 - niri_laptop_hardware_keys

**Completed**: 2026-07-04
**Duration**: ~15 minutes

## Overview

Added laptop backlight brightness control to the niri Wayland session by installing
`brightnessctl` and binding the `XF86MonBrightnessUp`/`XF86MonBrightnessDown` function keys in
`config/config.kdl`. No udev rule, `video` group, or NixOS hardware module was added, per
research finding that `brightnessctl` falls back to the `systemd-logind` `SetBrightness` D-Bus
method for non-root users.

## What Changed

- `modules/system/packages.nix` — Added `brightnessctl` to the "Niri essential packages" group,
  immediately after `wdisplays`, with an inline comment documenting the logind-fallback rationale.
- `config/config.kdl` — Added two new binds in the `binds { }` block immediately after the
  existing `XF86AudioPrev` bind and before the `// Window management` comment:
  - `XF86MonBrightnessUp { spawn "brightnessctl" "set" "5%+"; }`
  - `XF86MonBrightnessDown { spawn "brightnessctl" "-n" "5%" "set" "5%-"; }`
  - A preceding comment: `// Brightness controls (niri owns these keys; gsd-media-keys does not grab them here)`
  - The existing `wpctl` audio volume/mute binds were left unchanged.

## Decisions

- Followed the plan exactly: package-only installation (no `services.udev.packages`, no
  `video`/`input` group additions to `modules/system/users.nix`, no reference to the removed
  `hardware.brightnessctl.enable` module).
- Re-read `config/config.kdl` fresh before editing (per orchestrator instruction) since tasks 74
  and 75 had recently modified this file; anchored the insertion on bind content
  (`XF86AudioPrev`) rather than stale line numbers. Confirmed via `git status`/`git diff --stat`
  that only `config/config.kdl` and `modules/system/packages.nix` were touched by this task; other
  modified files (`modules/home/email/agent-tools.nix`, `specs/tmp/claude-tts-notify.log`)
  pre-existed from prior session activity and were left untouched.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Flake check: Success (`nix flake check` — all checks passed, only pre-existing "dirty tree" and
  `boot.zfs.forceImportRoot` warnings, unrelated to this change).
- NixOS build: Success (`nixos-rebuild build --flake .#hamsa` completed, produced `./result`).
- Confirmed `brightnessctl` present in the built system closure:
  `ls -1 ./result/sw/bin/ | grep brightnessctl` → `brightnessctl` found.
- Did not run `nixos-rebuild switch` and did not attempt the live keypress test, per plan
  (both are explicitly out of scope / manual user steps).

## Notes

- The manual post-`switch` verification step (press brightness keys, confirm panel dims/brightens
  on `eDP-1`, spot-check volume/mute keys still work) remains for the user to perform after a live
  `nixos-rebuild switch` and niri session login.
- If the live keypress test later shows the keys no-op, the documented fallback (add
  `services.udev.packages = [ pkgs.brightnessctl ]` + `video`/`input` group + re-login) is a
  follow-up change, not part of this task.
