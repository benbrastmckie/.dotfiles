# Implementation Summary: Task #74

**Completed**: 2026-07-04
**Duration**: ~15 minutes (including build verification)

## Overview

Fixed three niri-session-only startup gaps identified in research: waybar was never spawned,
the wallpaper path was never expanded (niri spawns without a shell), and no polkit
authentication agent ran in the niri session. GNOME remains the backend and is unaffected — no
home-manager systemd units were added, and no shared-target (`graphical-session.target`)
service enablement was used.

## What Changed

- `config/config.kdl` — Added `spawn-at-startup "waybar"` and
  `spawn-at-startup "/run/current-system/sw/bin/polkit-gnome-authentication-agent-1"` to the
  `//// AUTOSTART PROGRAMS ////` section; changed the `swaybg -i` argument from
  `"~/.wallpapers/current"` to the absolute `"/etc/wallpapers/riverside.jpg"`; replaced the
  stale "systemd handles service activation... no manual spawns needed" comment block (which
  referenced a nonexistent `specs/plans/010_...` doc) with an accurate note describing the
  explicit `spawn-at-startup` lines below.
- `modules/system/packages.nix` — Removed the commented `# polkit_gnome ...` line; added a
  `writeShellScriptBin "polkit-gnome-authentication-agent-1"` wrapper (mirroring the existing
  `zathura`/`sioyek` wrapper pattern) that execs
  `${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1`, since `libexec` is not
  linked into `/run/current-system/sw`.

## Decisions

- Used bare `spawn-at-startup "waybar"` rather than `programs.waybar.systemd.enable`, since
  niri's own `niri.service` unit binds to `graphical-session.target`, which is shared with the
  GNOME session — enabling the systemd unit would spawn a second bar inside GNOME.
- Used a `writeShellScriptBin` wrapper for the polkit agent rather than the home-manager
  `services.polkit-gnome` module, for the same shared-target reason (that module hardcodes
  `graphical-session.target`).
- Combined the config.kdl edits for Phases 1–3 into a single pass since this session had
  exclusive access to the file (tasks 75/76 run strictly after); this reduced edit/verify
  round-trips without changing the plan's per-phase checklist tracking.

## Plan Deviations

- None (implementation followed plan).

## Verification

- `nix flake check`: Success (`all checks passed!`, evaluated all four nixosConfigurations plus
  homeConfigurations; two pre-existing unrelated `boot.zfs.forceImportRoot` evaluation warnings
  on `usb-installer`/`iso` outputs, not touched by this task).
- `nixos-rebuild build --flake .#hamsa`: Success. Built
  `/nix/store/g2d2zywiq04byy8ycnyqn7fpm9n2hawx-nixos-system-hamsa-26.05.20260622.3426825`,
  including the new `polkit-gnome-authentication-agent-1` derivation. Confirmed
  `result/sw/bin/polkit-gnome-authentication-agent-1` resolves to a store path symlink in the
  built system profile.
- `home-manager build --flake .#benjamin`: Success (built `home-manager-generation`, no errors;
  includes the edited `config/config.kdl` as the home-manager-managed source).
- All Phase 1–3 `grep` checks passed: exactly one `spawn-at-startup "waybar"` match, the
  wallpaper path grep matches `/etc/wallpapers/riverside.jpg` and no longer matches
  `~/.wallpapers/current`, `test -f /etc/wallpapers/riverside.jpg` confirmed the file exists,
  and the polkit wrapper/spawn line greps each returned exactly one match with balanced parens
  in `packages.nix`.

## Notes

- No `nixos-rebuild switch` or `home-manager switch` was run, per plan scope — this is an
  explicit manual user step (sequence: `switch` on the system profile first, then
  home-manager `switch`, matching `./update.sh`'s ordering), followed by a niri relogin via GDM
  to visually confirm the bar, wallpaper, and a polkit dialog (e.g. via GNOME Disks).
- The build's temporary `result` symlink (gitignored) was removed after the sanity check to
  keep the working tree clean.
