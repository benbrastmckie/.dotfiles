# Implementation Plan: Task #74

- **Task**: 74 - niri_session_startup_services
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/074_niri_session_startup_services/reports/01_niri-startup-services.md
- **Artifacts**: plans/01_niri-startup-services.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Three niri-session-only startup fixes, each a small, self-contained edit grounded in the
completed research report. Waybar and the wallpaper are fixed entirely inside
`config/config.kdl`; the polkit authentication agent needs a `writeShellScriptBin` wrapper in
`modules/system/packages.nix` (because `libexec` is not linked into `/run/current-system/sw`)
plus a matching `spawn-at-startup` line in `config.kdl`. GNOME stays the backend and is
unaffected: no home-manager systemd units are added, so nothing leaks into the GNOME session.
A final phase runs the headless build verification the implementer *can* perform; the actual
`switch` + niri relogin + visual confirmation is called out explicitly as a manual user step.

### Research Integration

The plan follows the report's three "Decisions" verbatim:
- **Waybar**: bare `spawn-at-startup "waybar"` (report Finding 1). Rejects
  `programs.waybar.systemd.enable` because its default target `graphical-session.target` is
  shared with GNOME (confirmed via niri's own `niri.service` `BindsTo=graphical-session.target`),
  which would spawn a stray second bar in GNOME.
- **Polkit**: `writeShellScriptBin "polkit-gnome-authentication-agent-1"` wrapper around
  `${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1`, mirroring the existing
  `zathura`/`sioyek` wrappers already in `packages.nix` (lines 204-219). A bare
  `pkgs.polkit_gnome` install gives no invocable path because only `bin/sbin/lib/etc/share` are
  linked into `/run/current-system/sw` (report Finding 2). The home-manager
  `services.polkit-gnome` module is also rejected (hardcoded `graphical-session.target`).
- **Wallpaper**: change the `swaybg -i` argument at `config.kdl:250` from `~/.wallpapers/current`
  to the absolute `/etc/wallpapers/riverside.jpg` (already installed via
  `modules/system/desktop.nix:33`), because niri never invokes a shell and so never expands `~`
  (report Finding 3).

The report's low-risk suggestion to correct the now-inaccurate autostart-section comment
(`config.kdl:245-247`, which claims "no manual spawns needed") is folded into Phase 1.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap flag was passed to this `/plan` invocation, so no ROADMAP.md review/update phases are
included. The task advances the niri dual-session desktop usability workstream (topic: desktop).

## Goals & Non-Goals

**Goals**:
- Waybar autostarts in the niri session via `config/config.kdl` (fills the reserved 32px strut).
- A polkit authentication agent runs in the niri session so GUI privilege escalation works.
- The niri wallpaper draws from an absolute path that actually exists.
- All changes are niri-session-only and verified to build headlessly.

**Non-Goals**:
- No changes to the GNOME session, GDM, or `modules/system/desktop.nix`.
- No use of `programs.waybar.systemd.enable` or the home-manager `services.polkit-gnome` module
  (both introduce the shared-target double-start risk documented in research).
- No `spawn-sh-at-startup` wrapper for the wallpaper (would not fix the missing-file root cause).
- The implementer does NOT run `nixos-rebuild switch`, relogin to niri, or visually confirm the
  bar/wallpaper/auth dialog — that is a manual user step (see Testing & Validation).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Polkit `spawn-at-startup` line lands before the wrapper package is built into the system profile | M | M | Phase 3 adds the `packages.nix` wrapper and the `config.kdl` spawn line together; both land in the same commit. Manual `switch` step sequences `nixos-rebuild switch` (system profile) before `home-manager switch` (config.kdl symlink) per research Risk note. |
| Editing the wrong line / disturbing adjacent `spawn-at-startup` entries in `config.kdl` | M | L | Each edit targets a unique, quoted string; verify with `grep -n` after each phase and confirm surrounding lines (kitty/cliphist/swayidle spawns) are untouched. |
| Bare `waybar` name not on niri's PATH | L | L | Research confirms `home-manager.useUserPackages = true` (`lib/mkHost.nix:42-43`) puts the per-user profile on the session PATH; existing bare `spawn-at-startup "kitty"` already works this way. |
| `nixos-rebuild build` compiles heavy packages / slow | L | M | `polkit_gnome` is prebuilt in the binary cache (research built it live); build is verification-only and headless. Use the current host attr `hamsa`. |
| Waybar `tray` module needs a working SNI host (unrelated to startup) | L | L | Out of scope for the build; flagged as a smoke-check item for the manual relogin step only. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases 1-3 are logically independent edits but are serialized because Phases 1 and 2 (and the
`config.kdl` half of Phase 3) all modify the single file `config/config.kdl`; sequential
execution avoids overlapping edits to that file. Phase 4 (build verification) depends on all
source edits being in place.

---

### Phase 1: Waybar autostart + stale-comment fix [COMPLETED]

**Goal**: Waybar is spawned by the niri session, and the misleading autostart-section comment is
corrected to reflect that manual spawns now exist.

**Tasks**:
- [x] In `config/config.kdl`, in the `//// AUTOSTART PROGRAMS ////` section, add a new line:
      `spawn-at-startup "waybar"` (bare name, no path — matches the existing `spawn-at-startup "kitty"` convention and upstream niri's default config).
- [x] Correct the stale comment block at `config.kdl:245-247` ("systemd handles service activation via D-Bus (no manual spawns needed)...") so it no longer contradicts the manual spawns present in this section. Replace with a short accurate note (e.g. that niri-session services are started via explicit `spawn-at-startup` lines below). Remove the inaccurate `specs/plans/010_...` reference.
- [x] Do NOT set `programs.waybar.systemd.enable` anywhere.

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `config/config.kdl` - add `spawn-at-startup "waybar"` in the autostart section; fix comment at lines 245-247.

**Verification**:
- `grep -n 'spawn-at-startup "waybar"' config/config.kdl` returns exactly one match.
- The comment at ~lines 245-247 no longer claims "no manual spawns needed".
- Surrounding spawn lines (kitty, cliphist, swayidle) are unchanged.

---

### Phase 2: Wallpaper absolute path [COMPLETED]

**Goal**: `swaybg` loads an existing wallpaper file instead of the never-created, never-expanded
`~/.wallpapers/current`.

**Tasks**:
- [x] Change the `-i` argument on `config/config.kdl:250` from `"~/.wallpapers/current"` to `"/etc/wallpapers/riverside.jpg"`, leaving the rest of the line (`swaybg`, `-m`, `fill`) intact.

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `config/config.kdl` - line 250 wallpaper path.

**Verification**:
- `grep -n '/etc/wallpapers/riverside.jpg' config/config.kdl` returns a match on the swaybg line.
- `grep -n '~/.wallpapers/current' config/config.kdl` returns no matches.
- The swaybg line still begins with `spawn-at-startup "/run/current-system/sw/bin/swaybg" "-i"` and ends with `"-m" "fill"`.
- `test -f /etc/wallpapers/riverside.jpg` confirms the target exists (installed via `modules/system/desktop.nix:33`).

---

### Phase 3: Polkit agent wrapper + autostart [COMPLETED]

**Goal**: A stable `bin/polkit-gnome-authentication-agent-1` exists in the system profile and is
spawned by the niri session, giving GUI privilege escalation an authentication dialog.

**Tasks**:
- [x] In `modules/system/packages.nix`, replace the commented line at line 32
      (`# polkit_gnome         # PolicyKit authentication agent for GNOME`) with a
      `writeShellScriptBin` wrapper added to the `environment.systemPackages` list, matching the
      existing `zathura`/`sioyek` wrapper pattern (lines 204-219):
      ```nix
      # Polkit authentication agent for the niri session (GNOME session uses gnome-shell's own).
      # libexec is not linked into /run/current-system/sw, so wrap the binary to expose a bin/ path.
      (writeShellScriptBin "polkit-gnome-authentication-agent-1" ''
        #!/bin/sh
        exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 "$@"
      '')
      ```
      Place it alongside the other `writeShellScriptBin` wrappers (near lines 204-219) rather than
      inside the commented "For use with Niri without Gnome utilities" block, and delete/clean up
      the now-obsolete commented `polkit_gnome` line at line 32.
- [x] In `config/config.kdl`, in the autostart section, add:
      `spawn-at-startup "/run/current-system/sw/bin/polkit-gnome-authentication-agent-1"`
      (absolute path, mirroring how the existing swaybg line references `/run/current-system/sw/bin`).
- [x] Do NOT enable the home-manager `services.polkit-gnome` module.

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `modules/system/packages.nix` - add `writeShellScriptBin "polkit-gnome-authentication-agent-1"` wrapper; remove commented `polkit_gnome` at line 32.
- `config/config.kdl` - add polkit `spawn-at-startup` line in autostart section.

**Verification**:
- `grep -n 'writeShellScriptBin "polkit-gnome-authentication-agent-1"' modules/system/packages.nix` returns one match.
- `grep -n 'polkit-gnome-authentication-agent-1' config/config.kdl` returns one `spawn-at-startup` match with the `/run/current-system/sw/bin/` absolute path.
- Nix syntax of the edited region is well-formed (parens balanced, wrapper inside the `systemPackages` list); confirmed structurally by Phase 4's `nix flake check`.

---

### Phase 4: Headless build verification [NOT STARTED]

**Goal**: Confirm all edits evaluate and build without a graphical login. This is the last step
the implementer performs.

**Tasks**:
- [ ] Run `nix flake check` from the repo root and confirm it passes (evaluates the flake,
      including the edited `packages.nix`).
- [ ] Run `nixos-rebuild build --flake .#hamsa` (current host attr, confirmed via `hostname`) and
      confirm it completes — this builds the system closure including the new
      `polkit-gnome-authentication-agent-1` wrapper. Do NOT use `switch`.
- [ ] Run `home-manager build --flake .#benjamin` and confirm it completes — this builds the
      home closure including the edited `config/config.kdl` symlink source. Do NOT use `switch`.
- [ ] (Optional sanity) After the `nixos-rebuild build` result symlink exists, confirm the wrapper
      path is present in the built system profile
      (e.g. `ls result/sw/bin/polkit-gnome-authentication-agent-1` on the build output, if the
      `result` symlink is available).
- [ ] Report all three build results in the implementation summary.

**Timing**: 15-30 minutes (build time; polkit_gnome is cache-available)

**Depends on**: 3

**Files to modify**:
- None (verification only).

**Verification**:
- `nix flake check` exits 0.
- `nixos-rebuild build --flake .#hamsa` exits 0.
- `home-manager build --flake .#benjamin` exits 0.

---

## Testing & Validation

**Implementer-performed (headless, in Phase 4)**:
- [ ] `nix flake check` passes.
- [ ] `nixos-rebuild build --flake .#hamsa` succeeds (host attr `hamsa`; other valid attrs are
      `nandi` and `garuda` — use whichever matches the machine `hostname` at implement time).
- [ ] `home-manager build --flake .#benjamin` succeeds.
- [ ] `grep` checks from Phases 1-3 all pass.

**MANUAL USER STEP — NOT performed by the implementer**:
- [ ] `sudo nixos-rebuild switch --flake .#<host>` **then** `home-manager switch --flake .#benjamin`
      (system profile must land before the home-manager `config.kdl` symlink so the polkit
      `spawn-at-startup` path resolves). The repo's `./update.sh` runs both in this order.
- [ ] Log out and into the **niri** session via GDM.
- [ ] Visually confirm: (a) the waybar bar appears at the top filling the 32px strut (with
      tray/clock/battery); (b) the wallpaper draws; (c) a privileged GUI action (e.g. mounting a
      disk in GNOME Disks) shows a polkit authentication dialog.
- [ ] Optional smoke-check: waybar tray icons populate (depends on a working SNI host, unrelated
      to the startup fix).

## Artifacts & Outputs

- Edited `config/config.kdl` (waybar spawn, wallpaper path, polkit spawn, corrected comment).
- Edited `modules/system/packages.nix` (polkit-gnome `writeShellScriptBin` wrapper).
- Implementation summary reporting the three build results.

## Rollback/Contingency

- All changes are confined to two tracked files; `git diff config/config.kdl modules/system/packages.nix`
  shows the full change set and `git checkout -- <file>` (only if the tree is otherwise clean, or
  after a snapshot) reverts.
- If `nixos-rebuild build` fails on the polkit wrapper, re-check that the wrapper sits inside the
  `environment.systemPackages` list with balanced parens and that `pkgs.polkit_gnome` resolves
  (`nix eval nixpkgs#polkit_gnome.outPath`); fix forward rather than discarding edits.
- The three fixes are independent — if one build regresses, the offending phase's file edit can
  be reverted in isolation without losing the others.
- No `switch` is performed by the implementer, so there is no runtime state to roll back; the
  live system is unchanged until the manual user step.
