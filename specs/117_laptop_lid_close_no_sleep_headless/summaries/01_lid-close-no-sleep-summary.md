# Implementation Summary: Task #117

**Completed**: 2026-07-14 (config + docs; runtime activation pending user)
**Duration**: ~2 sessions (first agent terminated mid-Phase 1 by session limit; resumed and completed)

## Overview

Configured lid-close to blank the internal screen but never suspend, so headless workloads
(AI agents, builds) keep running with the lid shut and no external monitors. The core fix is a
logind-level `HandleLidSwitch*=ignore` block; two secondary auto-suspend paths (GNOME AC
idle-suspend, niri swayidle 10-minute suspend) were also closed, and docs were updated
proportionately. Multi-monitor behavior is preserved (`HandleLidSwitchDocked` untouched at its
default `ignore`), as is the 5-minute idle screen blank (`idle-delay = 300` untouched).

## What Changed

- `modules/system/power.nix` — Added `logind.settings.Login.HandleLidSwitch = "ignore"` and
  `HandleLidSwitchExternalPower = "ignore"` with an explanatory banner comment (Phase 1).
- `modules/home/desktop/gnome.nix` — Added `sleep-inactive-ac-type = "nothing"` to the
  gsd-power dconf block; AC idle-suspend disabled, 15-minute battery idle-suspend retained as
  protection (Phase 2).
- `config/config.kdl` — Removed `"timeout" "600" "systemctl suspend"` from the niri swayidle
  spawn line (5-minute swaylock, before-sleep, and lock handlers preserved); updated the
  adjacent comment (Phase 3).
- `docs/gnome-settings.md` — Power Management section: new "Lid-Close Behavior" subsection,
  AC idle-suspend line updated, battery bag/heat/drain warning, inhibitor Note extended (Phase 5).
- `docs/niri.md` — Swayidle bullet now says "no idle auto-suspend"; clarifying paragraph after
  the swayidle snippet noting lid close never suspends in either session (Phase 5).
- `docs/configuration.md` — One-phrase touch: power.nix category now reads
  "graphics, sound, power/lid behavior" (Phase 5).

## Decisions

- Used the canonical `services.logind.settings.Login` option form (nixos-26.05), not the
  deprecated `lidSwitch*` aliases.
- Left `sleep-inactive-ac-timeout = 3600` in place (inert with type `nothing`), annotated as such.
- niri session loses all idle auto-suspend including on battery (swayidle cannot discriminate
  AC/battery); accepted per plan, hazard documented.

## Plan Deviations

- **Phase 5, modules/README.md touch** skipped: the current `modules/README.md` contains no
  per-file characterization of `power.nix` (only bare filename lists), so there was no phrase to
  extend; adding a lone description would break the list style and the plan forbade a new
  section. The equivalent one-phrase touch was made in `docs/configuration.md` instead.
- **Phase 4 (activation + runtime verification) BLOCKED, pending user**: the implementing agent
  cannot obtain interactive sudo. No runtime check was executed or marked done. Required user
  steps:
  1. `sudo nixos-rebuild switch --flake .#hamsa`
  2. `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → expect `s "ignore"` (if `"suspend"`, `systemctl restart systemd-logind` or reboot)
  3. `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` → expect `'nothing'` (may need logout/login)
  4. Functional lid test (no monitor, ~2 min closed) via `journalctl -b -u systemd-logind | grep -i lid` — "Lid closed." with no suspend entry
  5. Regression: docked lid-close keeps windows on external display; 5-minute idle blank still works

## Verification

- Flake check: Success (`nix flake check` exits 0, "all checks passed!")
- NixOS build: Success (`nixos-rebuild build --flake .#hamsa`) after each of Phases 1, 2, 3
- logind.conf eval: `[Login]` contains `HandleLidSwitch=ignore`,
  `HandleLidSwitchExternalPower=ignore`, and retains `KillUserProcesses=false`
- niri config: `niri validate -c config/config.kdl` → "config is valid";
  `grep -c 'systemctl suspend' config/config.kdl` → 0
- Runtime (busctl/gsettings/journalctl/lid tests): NOT run — pending user activation (see above)

## Notes

- All three config changes activate together with the single pending
  `sudo nixos-rebuild switch --flake .#hamsa`.
- Rollback: each phase is a separate scoped commit (`git revert`), plus
  `nixos-rebuild switch --rollback` for immediate relief.

## Round-2 Addendum (2026-07-14)

Round-2 research (`reports/02_lid-close-screen-off-mechanism.md`) **falsified the round-1
assumption** that mutter blanks the internal panel on lid close: mutter 50.2 deliberately keeps
the internal eDP panel active when it is the only monitor and the lid closes, so under `ignore`
the panel stayed lit inside the closed lid until the 5-minute idle blank. The two logind values
in `modules/system/power.nix` were therefore changed from `"ignore"` to `"lock"` in commit
d82e669: `lock` never suspends, GNOME powers the panel off ~30s after locking (gsd-power
screensaver blank timeout), and swayidle's existing lock handler covers the niri session.
Docked behavior remains unaffected (gsd-power's `handle-lid-switch` block inhibitor, plus
`HandleLidSwitchDocked` default `ignore`). The docs (`docs/gnome-settings.md`, `docs/niri.md`)
were reconciled with the lock-based behavior in this phase. Activation (Phase 4) is still
pending the user; when verifying, the busctl check in step 2 above should now expect
`s "lock"`, not `s "ignore"`.
