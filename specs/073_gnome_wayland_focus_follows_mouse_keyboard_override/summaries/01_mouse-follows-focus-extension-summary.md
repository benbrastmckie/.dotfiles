# Implementation Summary: Task #73

**Completed**: 2026-07-04
**Duration**: ~1 hour (build/switch dominated by nix store fetch/build time)

## Overview

Installed and enabled the `mouse-follows-focus` GNOME Shell extension to fix the GNOME/Wayland bug where a stationary mouse pointer re-asserts sloppy focus and overrides keyboard-driven focus switches. `focus-mode = "sloppy"` and `focus-change-on-pointer-rest = false` were left unchanged; `focus-mode = "click"` was not applied, per the user's LOCKED decision. The configuration was built and switched live; the remaining behavioral verification (Phase 5) requires a GNOME Wayland re-login and is manual, so it is reported as pending user action rather than fabricated.

## What Changed

- `modules/home/packages/dev-tools.nix` — added `gnomeExtensions.mouse-follows-focus-2` alongside the existing `gnomeExtensions.activate-window-by-title`, with an inline comment referencing task 73.
- `modules/home/desktop/gnome.nix` — appended `"mouse-follows-focus@crisidev.org"` to `dconf.settings."org/gnome/shell".enabled-extensions`, after the existing `"unite@hardpixel.eu"` entry. No other lines in this file were touched.

## Decisions

- **Package attribute name correction**: the plan's assumed attribute `gnomeExtensions.mouse-follows-focus` does not exist in the pinned nixpkgs. `nix eval` failed with "attribute 'mouse-follows-focus' missing" and suggested `mouse-follows-focus-2`, which was confirmed to be the correct package: `pname = "gnome-shell-extension-mouse-follows-focus"`, version 12, homepage `https://extensions.gnome.org/extension/7656/mouse-follows-focus/`.
- **UUID resolved from the built package** (never guessed): built the package to `/nix/store/q435hvdx4kf22hj079r04bbsd6lvshfb-gnome-shell-extension-mouse-follows-focus-12`, inspected `share/gnome-shell/extensions/*/metadata.json`, and read `"uuid": "mouse-follows-focus@crisidev.org"`. This confirms the packaged extension is `crisidev/mouse-follows-focus` (one of the two candidate projects named in the research report), not `LeonMatthes/mousefollowsfocus`.
- **Ran `home-manager switch`, not just `build`**: switching only touches dconf settings and the package profile (additive, no logout required), so it was applied live rather than deferring the whole apply step to the user. The behavioral effect of the newly-enabled extension still requires a Wayland re-login (GNOME Shell cannot hot-reload extensions), which is out of scope for headless execution.

## Plan Deviations

- **Task 1.1** (Phase 1, package line) altered: used `gnomeExtensions.mouse-follows-focus-2` instead of the plan's assumed `gnomeExtensions.mouse-follows-focus`, because the latter attribute does not exist in the pinned nixpkgs.
- **Task 2 (shell-version compatibility check)**: the extension's declared `shell-version` is `["45","46","47","48","49"]`; the installed GNOME Shell is `50.1`. This mismatch is a known risk documented in the plan's risk table and is not treated as a blocker per the user's decision to proceed, but it is flagged here explicitly — Phase 5 verification should specifically check whether GNOME Shell 50 refuses to enable the extension, since nixpkgs packaging existing does not guarantee runtime shell-version compatibility.
- **Phase 5 (behavioral verification)** deferred to the user in full: these are manual, physically-interactive tests (mouse movement, keyboard focus switching, visual confirmation of cursor warp) that cannot be performed by an automated agent. No results were fabricated; the plan's Phase 5 checklist items remain unchecked with `*(pending user verification after re-login)*` annotations.

## Verification

- `nix flake check`: **Success** — `all checks passed!` (all nixosConfigurations and homeConfigurations outputs evaluated cleanly; only pre-existing unrelated `boot.zfs.forceImportRoot` warnings on two hosts, no errors).
- `home-manager build --flake .#benjamin`: **Success** — built 4 derivations (`hm-dconf.ini`, `home-manager-path`, `activation-script`, `home-manager-generation`); result symlink resolved to `/nix/store/1mnyykg3889d6lsyb65igrqa5rr3pak2-home-manager-generation`. Inspected the generated `hm-dconf.ini` directly and confirmed:
  - `[org/gnome/shell] enabled-extensions=@as ['activate-window-by-title@lucaswerkmeister.de','unite@hardpixel.eu','mouse-follows-focus@crisidev.org']`
  - `[org/gnome/desktop/wm/preferences] focus-mode='sloppy'` (unchanged)
  - `[org/gnome/mutter] focus-change-on-pointer-rest=false` (unchanged)
- `home-manager switch --flake .#benjamin`: **Success** — activation completed (`installPackages`, `dconfSettings`, `linkGeneration`, etc., no errors).
- Live confirmation: `gsettings get org.gnome.shell enabled-extensions` returned `['activate-window-by-title@lucaswerkmeister.de', 'unite@hardpixel.eu', 'mouse-follows-focus@crisidev.org']`; `gsettings get org.gnome.desktop.wm.preferences focus-mode` returned `'sloppy'`; `gsettings get org.gnome.mutter focus-change-on-pointer-rest` returned `false`.
- `gnome-extensions list --enabled` (checked against the still-running, pre-switch GNOME Shell process): does **not** yet list the new extension. This is expected — Wayland GNOME Shell cannot hot-reload extension state; the entry will appear only after the user logs out and back in.

## Outstanding Manual Step (required before this task can be considered fully closed)

1. **Log out and log back in** to the GNOME Wayland session (or reboot) — required for the newly-enabled extension to actually load.
2. After re-login, run `gnome-extensions list --enabled | grep -i mouse` and `gnome-extensions info mouse-follows-focus@crisidev.org` to confirm it reports `ENABLED`. **Watch specifically for a shell-version rejection**, since the extension declares support through GNOME Shell 49 and the installed version is 50.1 — this was NOT verifiable headlessly.
3. Perform the plan's Phase 5 manual test checklist:
   - (a) Hover-to-focus still works with pure mouse navigation.
   - (b) A keyboard-driven focus switch (`<Super>space`) to a window not under the pointer sticks, with the cursor visibly warping to the new window.
   - (c) The original snap-back bug (pointer resting over an uninvolved third window) no longer reproduces.
   - Repeat (b)/(c) across monitors if multi-monitor.
4. If the extension fails to enable (shell-version mismatch) or the behavior is unacceptable (e.g., the cursor-warp side effect is too disruptive), report back — the documented, unapplied fallback (`focus-mode = "click"`) requires explicit user confirmation before being applied, per the plan's rollback/contingency section.

## Notes

- All git-tracked config changes are isolated to the two files listed above; no other repo files were modified by this implementation.
- The `home-manager switch` was run against the user's actual live GNOME Wayland session (confirmed via `loginctl`/`ps` — `gnome-shell --mode=user`, `XDG_SESSION_TYPE=wayland`). This is a real production desktop, not a sandbox, which is why the disruptive act of logging out was left to the user rather than performed automatically.
