# Implementation Summary: Task #119

**Completed**: 2026-07-25 (Phases 1, 2, 4 fully verified; Phase 3 blocked pending user
activation — see below)
**Duration**: ~45 minutes

## Overview

Replaced GNOME's unbounded `sleep-inactive-ac-type = "nothing"` with an explicit, auditable
12-hour AC idle-suspend ceiling (`"suspend"` + `43200`) in `modules/home/desktop/gnome.nix`,
leaving the existing 1-hour battery leg untouched. The committed change, its evaluation, and both
build paths are fully verified. **Live activation was not performed** because it requires an
interactive `sudo` password prompt, which this implementation agent is constrained not to run —
this is flagged as a blocker below with the exact command the user needs to run.

## What Changed

- `modules/home/desktop/gnome.nix` — `sleep-inactive-ac-type` changed from `"nothing"` to
  `"suspend"`; `sleep-inactive-ac-timeout` changed from `3600` to `43200` (12 hours); leading
  comment rewritten to state the actual contract (12h ceiling, elapses only with no logind block
  inhibitor held and full idle); added inline comment recording that this split must stay in
  GNOME's AC/battery-scoped dconf keys and must not move to `systemd-logind`'s
  `IdleAction`/`IdleActionSec`. Battery keys (`sleep-inactive-battery-type` /
  `-timeout`), `idle-dim`, and `org/gnome/desktop/session.idle-delay` are byte-for-byte
  unchanged.
- `docs/no-sleep-agents.md` — settings code block, AC/battery narrative paragraph, the "How the
  four mechanisms compose" table's two AC rows, the niri-section note (explicit deliberate
  deferral, not an oversight), and the "Activation & verification" `gsettings` command list and
  expected values all updated to the 12h/1h split.
- `docs/gnome-settings.md` — AC idle-suspend bullet updated to the explicit 12h ceiling.

## Decisions

- No change to `systemd-logind`'s `IdleAction`/`IdleActionSec` or to
  `modules/system/power.nix` — the AC/battery split is expressed purely through GNOME's
  AC/battery-scoped dconf keys, consistent with the plan's explicit constraint.
- niri AC/battery parity is out of scope for this task (see "Deferred" section below);
  `config/config.kdl` and `modules/home/desktop/swaylock.nix` are untouched.
- `config/claude/settings.json` is untouched — "no Claude activity" continues to rely on the
  existing session-scoped `sleep:idle` block inhibitor from tasks 117/118.

## Plan Deviations

- **Phase 3** (activation and LIVE dconf verification) — **skipped, blocked on required
  interactive sudo**: full activation requires `sudo nixos-rebuild switch --flake .#hamsa`
  (interactive password prompt) alongside `home-manager switch --flake .#benjamin`. The
  implementation agent operated under an explicit constraint not to run sudo with a password
  prompt and not to bypass/supply credentials. Activating only the standalone
  `home-manager switch` path (which does not need sudo) was considered and explicitly rejected:
  the plan's own risk table states that activating only one of the two Home Manager paths
  leaves `~/.nix-profile` and `/etc/profiles/per-user` disagreeing, and doing so unilaterally to
  make this phase appear to pass would reintroduce exactly the activation-lag class of bug this
  task exists to close. No live post-activation `gsettings get` reads were taken; only
  pre-activation baseline reads were captured (see "Live Verification" below). This is reported
  as **incomplete**, not complete.
- All other phases (1, 2, 4) followed the plan without deviation.

## Verification

- **Flake check**: `nix flake check` — **pass** (all NixOS configurations, `formatter`, and
  `devShells` evaluate cleanly; only pre-existing `boot.zfs.forceImportRoot` warnings on
  unrelated hosts, no new issues).
- **NixOS build**: `nixos-rebuild build --flake .#hamsa` — **pass**
  (`/nix/store/i29bh6x6vi1yi7c9gz3v6qj5x2k1xh43-nixos-system-hamsa-26.05.20260710.8f0500b`).
- **Home Manager build**: `home-manager build --flake .#benjamin` — **pass**.
- **Evaluated-value probe** (`nix eval`):
  - `.#homeConfigurations.benjamin.config.dconf.settings."org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-timeout`
    → `43200`
  - `.#homeConfigurations.benjamin.config.dconf.settings."org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-type`
    → `"suspend"`
  - Both resolved directly; the keyfile-grep fallback was not needed.
- **Formatting/lint**: `nix fmt -- modules/home/desktop/gnome.nix` left the file unchanged after
  the edit; `nix run nixpkgs#statix -- check modules/home/desktop/gnome.nix` reported no
  findings (exit 0).
- **Docs**: `grep -rn 'sleep-inactive-ac-type' docs/` shows only `"suspend"` occurrences (in
  `docs/gnome-settings.md` and `docs/no-sleep-agents.md`); `grep -rn '43200' docs/` matches in
  both files. No task numbers appear in the edited `docs/` prose.

### Live Verification (Phase 3) — NOT COMPLETE

Live activation did not run. The following are **pre-activation baseline reads only** —
transcribed verbatim, and explicitly NOT evidence that the fix is live:

```
$ gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
'nothing'
$ gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
3600
$ gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
'suspend'
$ gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout
3600
$ busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager IdleAction
s "ignore"
$ busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch
s "lock"
```

These confirm the machine is still running the pre-change values (as expected, since no
activation ran) and that the untouched logind neighbors (`IdleAction`, `HandleLidSwitch`) are
unaffected by this change.

**Required user action to complete Phase 3** — run one of the following, then re-read the four
`gsettings` values:

```bash
# Preferred: runs both Home Manager paths in sequence
bash scripts/update.sh

# Or manually, both are required (activating only one leaves the profiles disagreeing):
sudo nixos-rebuild switch --flake .#hamsa
home-manager switch --flake .#benjamin

# Then confirm the live values:
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type      # expect 'suspend'
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout   # expect 43200
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type    # expect 'suspend' (unchanged)
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout # expect 3600 (unchanged)
```

If `sleep-inactive-ac-timeout` reads back `3600` after activation, the schema default is still in
force and the fix is not live — work the remediation ladder in Phase 3 of the plan (re-run the
Home Manager `switch` that owns dconf, re-read, then log out/in to force a fresh
`gnome-settings-daemon`) before concluding the fix is broken.

**Known limitation** (recorded regardless of when activation happens): `gsettings get` proves
the dconf database value. `gsd-power` follows GSettings change notifications live, so a DB match
is sufficient evidence in practice, but a DB match alone is not proof the daemon re-armed its
idle timer internally.

**Behavioral note**: the 12-hour AC path cannot be wall-clock tested within this task regardless
of activation state. The live dconf reads plus the unchanged, already-verified inhibitor
mechanism from tasks 117/118 are the accepted evidence once activation completes.

## Deferred — niri AC/battery parity

**Problem**: niri has zero idle auto-suspend on any power state. `swayidle`
(`config/config.kdl:271`, `spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" ...`)
has no AC/battery-conditional timeout of its own — a single `timeout N command` clause applies
unconditionally regardless of power source. This is a real, acknowledged gap versus the 12h/1h
spec, deliberately deferred (not dropped) because it errs toward "stays awake" rather than
"sleeps too early," and niri is not the session exhibiting the reported bug.

**Option A**: a power-state-aware supervisor that respawns
`swayidle -w timeout <43200|3600> 'systemctl suspend'` on `/sys/class/power_supply/ACAD/online`
transitions, structurally mirroring the udev idiom already used in `modules/system/power.nix`.

**Option B**: two mutually-exclusive systemd user units (`swayidle-ac` / `swayidle-battery`)
gated on AC power.

**Known hazards either way**: respawn races, two idle timers armed at once, and a supervisor
that dies silently, leaving no idle policy at all.

**Explicit warning**: do not resurrect the commented-out `services.swayidle` block in
`modules/home/desktop/swaylock.nix` verbatim — its unconditional `timeout 600 -> systemctl
suspend` example predates the AC/battery split requirement.

**Ready-to-run follow-up task invocation** (not auto-created — task creation is an interactive,
user-confirmed operation):

```
/task "Give the niri session AC/battery-conditional idle suspend (12h AC, 1h battery) to match the GNOME session"
```

## Notes

- Final change set: `modules/home/desktop/gnome.nix`, `docs/no-sleep-agents.md`,
  `docs/gnome-settings.md`, plus this task's `specs/119_fix_ac_vs_battery_idle_sleep_timeouts/`
  artifacts. No other files were modified.
- Each verified-green phase (1, 2, 4, and the blocked state of 3) was committed separately:
  `task 119 phase 1: ...`, `task 119 phase 2: ...`, `task 119 phase 4: ...`,
  `task 119 phase 3: blocked — live activation requires interactive sudo`.
- The task should not be marked fully complete until a human runs the activation command above
  and the live `gsettings` reads confirm `'suspend'` / `43200` on the AC leg.
