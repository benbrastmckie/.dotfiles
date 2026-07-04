# Implementation Plan: Task #76 - niri_laptop_hardware_keys

- **Task**: 76 - niri_laptop_hardware_keys
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/076_niri_laptop_hardware_keys/reports/01_niri-hardware-keys.md
- **Artifacts**: plans/01_niri-hardware-keys.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/state-management.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/nix.md
- **Type**: nix

## Overview

Add laptop backlight brightness control to the niri Wayland session, which (unlike the
GNOME session) has no `gsd-media-keys` to grab the `XF86MonBrightness*` function keys. The
change is two coherent edits to shared, host-agnostic config: (1) install `pkgs.brightnessctl`
in the existing "Niri essential packages" group of `modules/system/packages.nix`, and (2) add
`XF86MonBrightnessUp` / `XF86MonBrightnessDown` binds in `config/config.kdl` after the existing
audio binds. Research (report 01) source-verified that current `brightnessctl` falls back to
the `systemd-logind` `Session.SetBrightness` D-Bus method for non-root users, so **no udev rule,
`video` group, or NixOS module is required**. Definition of done: `nix flake check` and
`nixos-rebuild build --flake .#hamsa` succeed with the changes; the live keypress test (panel
visibly dims/brightens) is a manual post-`switch` user step, not part of this plan's execution.

### Research Integration

Report 01 (`reports/01_niri-hardware-keys.md`) resolved the one open correctness question by
reading `brightnessctl.c` directly: as a non-root user without direct sysfs write access,
brightnessctl transparently calls logind's `SetBrightness` over the system D-Bus, which
performs the privileged write. This means the package-only approach works out of the box on this
machine (GDM-managed logind session active in both GNOME and niri). The report also confirmed:
the exact bind syntax and placement (after `config.kdl:186`), that `-n 5%` is valid min-value
syntax for an explicit floor on the down-bind, that the existing `wpctl` audio binds need no
change (PipeWire is system-wide and compositor-independent), and that `hardware.brightnessctl.enable`
no longer exists in nixpkgs and must not be referenced.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set). This task is one of the niri
dual-session hardening series (74-78); task 77 depends on 74-76 landing.

## Goals & Non-Goals

**Goals**:
- Install `brightnessctl` so it resolves on `PATH` in the niri session.
- Bind `XF86MonBrightnessUp` / `XF86MonBrightnessDown` to `brightnessctl set 5%+` / `5%-` in
  `config/config.kdl`, with an explicit `-n 5%` floor on the down-bind.
- Verify the configuration builds headlessly (`nix flake check` + `nixos-rebuild build`).

**Non-Goals**:
- Do NOT add `services.udev.packages = [ pkgs.brightnessctl ]` or add `video`/`input` to
  `modules/system/users.nix` extraGroups — unnecessary given the logind fallback (report 01).
- Do NOT reference `hardware.brightnessctl.enable` — the module was removed from nixpkgs.
- Do NOT modify the existing `wpctl` volume/mute binds (`config.kdl:181-183`) — confirmed correct.
- Do NOT run `nixos-rebuild switch` or perform the live keypress verification — that is a manual
  user step after this plan is implemented.
- Shift-modified fine-step brightness variants are out of scope (report notes XF86 keys do not
  reliably combine with Shift; optional only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| logind `SetBrightness` unreachable in niri session -> keys silently no-op | M | L | Manual keypress test post-switch (user step); documented fallback: add `services.udev.packages` + `video` group and re-login. |
| Multiple backlight devices make brightnessctl target the wrong one | L | L | Intel-only hardware on all hosts; if ambiguous, run `brightnessctl -l` post-switch and add `-d <device>` to binds. |
| KDL syntax error in the new binds breaks niri config parse | M | L | Match the existing multi-arg `spawn` array style verbatim; `nixos-rebuild build` does not validate KDL, so keep edits minimal and mirror the adjacent audio binds exactly. |
| Editing wrong host attr in build command | L | L | Current host is `hamsa` (confirmed via `hostname`); config files are shared across hosts, so building `hamsa` exercises the change. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch different files
(`packages.nix` vs `config.kdl`) with no ordering dependency; Phase 3 verifies both together.

### Phase 1: Install brightnessctl [COMPLETED]

- **Goal:** Add `brightnessctl` to the "Niri essential packages" group so the binary is on
  `PATH` in the niri session.
- **Tasks:**
  - [x] In `modules/system/packages.nix`, add `brightnessctl` immediately after the `wdisplays`
    line (currently line 21) inside the "Niri essential packages (for dual-session with GNOME)"
    group, with an inline comment.
  - [x] Use the exact line:
    `brightnessctl # Laptop backlight control (XF86MonBrightness keys in niri; uses logind SetBrightness, no udev/video-group needed)`
  - [x] Do NOT add `services.udev.packages` or touch `modules/system/users.nix`.
- **Timing:** ~10 min
- **Depends on:** none
- **Files to modify:**
  - `modules/system/packages.nix` — one added line in the niri package group.
- **Verification:**
  - `brightnessctl` appears in the group between `wdisplays` and the commented block; 2-space
    indentation preserved (per `.claude/rules/nix.md`).

### Phase 2: Add brightness keybinds to config.kdl [COMPLETED]

- **Goal:** Bind the brightness function keys in niri's `binds { }` block.
- **Tasks:**
  - [x] In `config/config.kdl`, insert immediately after the audio binds (after line 186,
    the `XF86AudioPrev` line, before the `// Window management` comment) the following:
    ```kdl
    // Brightness controls (niri owns these keys; gsd-media-keys does not grab them here)
    XF86MonBrightnessUp { spawn "brightnessctl" "set" "5%+"; }
    XF86MonBrightnessDown { spawn "brightnessctl" "-n" "5%" "set" "5%-"; }
    ```
  - [x] Match the existing multi-arg `spawn` array style (each arg its own quoted string); no
    `sh -c` wrapper is needed since brightnessctl takes plain positional args.
  - [x] Leave the `wpctl` audio binds (lines 181-183) unchanged.
- **Timing:** ~10 min
- **Depends on:** none
- **Files to modify:**
  - `config/config.kdl` — two bind lines plus a comment, inserted after the audio binds.
- **Verification:**
  - The two `XF86MonBrightness*` binds are present, sit within the `binds { }` block, and use
    the same quoting style as the adjacent `wpctl`/`playerctl` binds.

### Phase 3: Headless build verification [COMPLETED]

- **Goal:** Confirm the changes evaluate and build without errors, headlessly.
- **Tasks:**
  - [x] Run `nix flake check` from the repo root and confirm it passes.
  - [x] Run `nixos-rebuild build --flake .#hamsa` (current host; config is shared across
    `nandi`/`hamsa`/`garuda`, so the current host exercises the change) and confirm it builds.
  - [x] Confirm `brightnessctl` is present in the built system closure, e.g.
    `ls -1 ./result/sw/bin/ | grep brightnessctl` (or `nix eval` the systemPackages), to prove
    Phase 1 took effect.
  - [x] Do NOT run `nixos-rebuild switch`. Do NOT attempt the live keypress test. (confirmed:
    neither was run)
- **Timing:** ~20 min (dominated by build/eval time; cache-dependent)
- **Depends on:** 1, 2
- **Files to modify:** none (verification only).
- **Verification:**
  - `nix flake check` exits 0.
  - `nixos-rebuild build --flake .#hamsa` completes and produces `./result`.
  - `brightnessctl` binary is found in the built closure.

## Testing & Validation

- [x] `nix flake check` passes (Phase 3).
- [x] `nixos-rebuild build --flake .#hamsa` succeeds and yields `./result` (Phase 3).
- [x] `brightnessctl` binary present in the built system closure (Phase 3).
- [x] `config/config.kdl` contains the two `XF86MonBrightness*` binds in the correct place with
  correct quoting (Phase 2).
- [x] `modules/system/packages.nix` contains `brightnessctl` in the niri group; no
  `services.udev.packages` / `users.nix` changes were introduced (Phase 1).
- [ ] **MANUAL (user, post-implementation, NOT part of this plan):** after `nixos-rebuild switch`
  and logging into the niri session, press the brightness up/down keys and confirm the laptop
  panel (eDP-1) visibly dims and brightens; also spot-check that volume/mute keys still work.
  If keys no-op, apply the documented fallback (`services.udev.packages = [ pkgs.brightnessctl ]`
  + `video`/`input` group + re-login).

## Artifacts & Outputs

- `specs/076_niri_laptop_hardware_keys/plans/01_niri-hardware-keys.md` (this plan)
- Modified `modules/system/packages.nix` (Phase 1)
- Modified `config/config.kdl` (Phase 2)
- `specs/076_niri_laptop_hardware_keys/summaries/01_niri-hardware-keys-summary.md` (at implement time)

## Rollback/Contingency

- Both edits are additive and isolated. To revert: remove the `brightnessctl` line from
  `modules/system/packages.nix` and delete the two `XF86MonBrightness*` bind lines (plus the
  comment) from `config/config.kdl`, then `git checkout` those two files or `git revert` the
  implementation commit and rebuild.
- If the build fails, fix forward (correct the edited line); do not discard other uncommitted
  work. If the live keypress test later fails, the fallback (udev rule + `video` group + re-login)
  is documented in report 01 and the Testing section above — that would be a follow-up change,
  not a rollback of this one.
