# Implementation Summary: Task #117 (Round 2 — Battery-Level Backstop)

**Completed**: 2026-07-14 (config phases; activation pending user)
**Plan**: plans/02_battery-level-backstop.md
**Duration**: ~1.5 hours (agent side)

## Overview

Implemented the real low-battery protection this machine was missing: a root systemd timer
that suspends at <=10% battery while discharging, **bypassing all sleep inhibitors**
(`systemctl suspend -i`). Report 03 proved the existing "UPower HybridSleep at 2%" backstop is
an illusion under any Claude Code block inhibitor (rejected outright by systemd v260, never
retried, and hibernate could not complete anyway with a 16G swapfile vs 30G RAM). Supporting
work: GNOME battery idle-suspend raised to 60 minutes with an explicit `suspend` type, and the
Claude session inhibitor hooks hardened so dead/crashed sessions release their locks (hooks
remain SESSION-scoped per user decision 1).

Phases 1, 2, 3, 5 are complete, build-verified, and committed. Phase 4 (activation + runtime
verification) is **pending the user** — see the checklist below.

## What Changed

- `modules/system/power.nix` — added `battery-suspend-backstop` systemd service + timer
  (polls `/sys/class/power_supply/BAT*` every 60 s from 2 min after boot; suspends via
  `systemctl suspend -i` at <=10% while `Discharging`); header comment updated. Commit c72c4cf.
- `modules/home/desktop/gnome.nix` — `sleep-inactive-battery-timeout` 900 -> 3600; explicit
  `sleep-inactive-battery-type = "suspend"`; comments state the inhibitor caveat. Commit 2386332.
- `config/claude/settings.json` — SessionStart hook: inhibitor payload `sleep infinity` ->
  `tail --pid=$PPID -f /dev/null` (tethers the lock's lifetime to the owning `claude` process),
  plus a stale-pid-file reap prepended. SessionEnd hook unchanged (fast-path release retained).
  Commit 29fdd1f.
- `docs/gnome-settings.md` — Power Management: battery idle-suspend bullet rewritten (3600 s,
  explicit type, inhibitor caveat + accepted limitation), new "Battery backstop (10%)" bullet
  (inhibitor bypass, intentional re-suspend loop, escape hatch, s2idle drain caveat, hibernate
  upgrade path, UPower 2% not load-bearing); Lid-Close warning and Neovim-inhibitor note
  corrected (no more "15-minute backstop" claims). Commit 09eb586.

## Decisions

- **No `ConditionACPower`** on the backstop service: the sysfs `status = "Discharging"` check
  is the authoritative AC gate (live strings: `Not charging`/`Charging` on AC, `Discharging`
  on battery).
- **No hysteresis band**: re-suspend on every tick while <=10% and discharging is intentional
  and documented in the unit banner; escape hatches are plug-in or
  `systemctl stop battery-suspend-backstop.timer`.
- **`$PPID` tether, direct form** (empirically verified — see below); ancestor-walk fallback
  not needed on this deployment.
- **`services.upower.*` left untouched** per the plan's leave-alone recommendation (the 2%
  action is unreachable behind the 10% timer and reconfiguring it would be churn or worse).
- **Hooks stay SESSION-scoped** (user decision 1) — only the dead-session release path changed.

## Empirical Verifications (agent-performed, safe)

- **Hook shell ancestry** (plan-flagged unverified): probe injected into the deployed
  `~/.claude/settings.json`, scratch session run (`claude -p`), ancestry captured:
  `sh(hook, pid 2553382) <- claude(pid 2553343) <- ...` — the hook shell's `$PPID` IS the
  owning claude process directly. Deployed file restored from backup afterwards.
- **Tether mechanism end-to-end** (isolated, no claude, no suspend): a real
  `systemd-inhibit --mode=block tail --pid=<owner> -f /dev/null` acquired the lock; `kill -9`
  of the owner released the inhibitor within ~1 s.
- **Backstop branch logic** (fake sysfs values in a scratch dir, `systemctl` stubbed): fires at
  9% and 10% Discharging; silent at 11% Discharging, `Not charging` 5%, `Charging` 3%; the
  peripheral `hid-*-battery` path is excluded by the `BAT*` glob.
- **Reap loop** (fake pid files): live-PID file kept, dead-PID and empty files removed, no
  process ever signaled.
- **Store script dry-run** on the real machine (AC, 100%): exits 0 silently.

## Verification (build-level)

- `nix flake check`: green after every config phase and at the end.
- `nixos-rebuild build --flake .#hamsa`: green after phases 1, 2, 3 (final closure
  `nixos-system-hamsa-26.05.20260710.8f0500b`).
- Eval checks: `ExecStart` store script shows `BAT*` glob / threshold 10 / `suspend -i`;
  `timerConfig = { OnBootSec = "2min"; OnUnitActiveSec = "60s"; }`; HM dconf eval shows
  `sleep-inactive-battery-timeout = 3600`, `sleep-inactive-battery-type = "suspend"`,
  `sleep-inactive-ac-type = "nothing"`.
- `jq .` parses `config/claude/settings.json`; extracted hook command passes `bash -n`.
- Docs: `grep "900\|15 minutes\|15-minute" docs/gnome-settings.md` returns nothing.

## Plan Deviations

- None (implementation followed plan; the `$PPID`-direct branch was chosen after the plan's
  mandated empirical probe confirmed it).

## USER ACTIVATION CHECKLIST (Phase 4 — pending)

1. **Activate**: `sudo nixos-rebuild switch --flake .#hamsa`, then **reboot** (clears pre-fix
   stale inhibitor state, guarantees fresh logind/gsd config).
2. **One-time cleanup** (safe anytime; the new hook also self-heals this at every SessionStart):
   `for f in /tmp/claude-inhibitor-*.pid; do kill -0 "$(cat "$f")" 2>/dev/null || rm -f "$f"; done`
3. **Backstop timer live**: `systemctl list-timers battery-suspend-backstop.timer --no-pager`
   (next elapse <=60 s); `journalctl -u battery-suspend-backstop.service -n 10` silent at >10%.
4. **Safe A/B suspend test** (with a Claude session open so inhibitors are held — no battery
   draining): `sudo systemctl suspend` must be REFUSED (`BlockedByInhibitorLock`); then
   `sudo systemctl suspend -i` must suspend despite them (wake with lid/keypress). This proves
   the exact call the backstop makes.
5. **GNOME values live**: `gsettings get org.gnome.settings-daemon.plugins.power
   sleep-inactive-battery-timeout` -> `3600`; `... sleep-inactive-battery-type` -> `'suspend'`;
   `... sleep-inactive-ac-type` -> `'nothing'`.
6. **Lid (round-1)**: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1
   org.freedesktop.login1.Manager HandleLidSwitch` -> `"lock"` (same for
   `HandleLidSwitchExternalPower`); close lid undocked -> locks, panel off ~30 s, stays awake.
7. **Hook tether live**: `diff <(jq .hooks ~/.claude/settings.json) <(jq .hooks
   config/claude/settings.json)` empty; start a scratch Claude session, confirm
   `systemd-inhibit --list` shows a claude-code entry with a `tail` payload, `kill -9` the
   scratch claude process, confirm the inhibitor disappears within a few seconds.
8. **Escape hatch reminder**: for a deliberate low-battery session,
   `systemctl stop battery-suspend-backstop.timer` (re-enabled at next boot/switch).

## Notes

- Do NOT test the backstop by draining the battery; step 4 above validates the whole bypass
  chain safely.
- Accepted limitation (user decision 2): an open-but-idle Claude terminal blocks the 60-minute
  battery idle-suspend until the 10% backstop fires. Documented in docs/gnome-settings.md.
- MCP-NixOS was unavailable this session (informational); all option paths were pre-verified
  live during planning and re-confirmed via `nix eval` here.
