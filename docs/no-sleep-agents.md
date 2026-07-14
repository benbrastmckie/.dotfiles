# Keeping the System Awake for AI Agents

This machine is expected to run long, unattended AI-agent workloads (builds, background
research, multi-hour Claude Code sessions) with the lid closed and nobody watching the screen.
Ordinary desktop power management — screen blanking, idle suspend, lid-close suspend — would
kill those workloads mid-run if left at defaults. This page explains the four independent
mechanisms that work together to prevent that, how they compose, how to verify each one is
actually active on a running system, and why a couple of tempting simpler alternatives were
rejected.

The mechanisms are layered rather than being one setting, because they protect against
different things: an idle Claude Code session, an idle GNOME/niri desktop, a closed lid, and a
laptop battery draining to zero in a bag. None of them alone covers all four cases.

## The four mechanisms

### 1. Claude Code session inhibitors (the everyday layer)

Every time a Claude Code session starts, a `SessionStart` hook (configured in
`config/claude/settings.json`, deployed to `~/.claude/settings.json` by Home Manager) launches:

```
systemd-inhibit --what=sleep:idle --who=claude-code --why="Claude Code session" --mode=block \
  tail --pid=$PPID -f /dev/null
```

in the background, and records the resulting PID in `/tmp/claude-inhibitor-${SESSION_ID}.pid`.
This holds a logind **block** inhibitor on both `sleep` and `idle` for as long as the session is
open — including while the session sits completely idle at the prompt. It is **session-scoped,
not activity-scoped**: opening a terminal and doing nothing still blocks the machine from
idle-suspending, because the intent is to protect a background agent that might resume work at
any moment, not just active typing.

The inhibitor's payload is deliberately `tail --pid=$PPID -f /dev/null` rather than something
like `sleep infinity`: `tail` exits on its own the moment the parent Claude process (`$PPID`)
dies, so the inhibitor is released automatically if the session crashes or is killed, rather
than surviving as an orphaned process (reparented to the user's systemd instance) until the
next reboot.

A matching `SessionEnd` hook provides the normal, fast release path: it reads the recorded PID
file, kills that process, and removes the file. The `tail`-tethering above is the self-healing
backstop for the case where `SessionEnd` doesn't get a chance to run cleanly. The `SessionStart`
hook also reaps any stale PID files left over from previous sessions before starting its own
inhibitor, so leftover files don't accumulate.

What this inhibitor blocks: GNOME's idle-triggered suspend (mechanism 2, below) on both AC and
battery, and any ordinary interactive `systemctl suspend` call system-wide. What it does **not**
block: the lid-switch action (mechanism 2 handles that separately — see the callout below) and
the battery-level backstop (mechanism 4, by design).

Accepted limitation: an idle-but-open Claude Code terminal blocks the battery idle-suspend
timeout indefinitely. Only the battery backstop (mechanism 4) protects battery life in that
case. This is intentional — closing or exiting idle Claude Code terminals is the way to let the
battery idle-suspend timeout do its job; it is not treated as a bug.

There is also a disabled, unused mechanism worth knowing about so nobody re-introduces it
by accident: `modules/home/memory/services.nix` contains a commented-out
`claude-sleep-inhibitor` systemd unit. It was tried and turned off because its `pgrep -f
'claude'` process match was too broad and self-matched unrelated processes, causing the machine
to stay awake permanently. The `SessionStart`/`SessionEnd` hook pair above replaced it with a
PID-tracked, per-session approach that doesn't have that problem.

### 2. GNOME/logind system settings (the structural "never sleep unless told" layer)

This is the layer that guarantees the machine doesn't auto-suspend even when no Claude Code
session happens to be open, and the layer that specifically owns lid-close behavior.

**Lid close** is configured in `modules/system/power.nix`:

```nix
services.logind.settings.Login = {
  HandleLidSwitch = "lock";
  HandleLidSwitchExternalPower = "lock";
};
```

Closing the lid **locks the session and never suspends**, on AC or battery, whether or not an
external monitor is attached (as long as the laptop panel is the only display — see the docked
note below).

**Why `lock` and not the more obvious `ignore`**: GNOME's compositor (mutter) deliberately keeps
the internal laptop panel powered on when it is the *only* display, even after the lid closes —
it refuses to leave the session with zero outputs. Under `ignore`, the panel would stay lit
*inside the closed lid* until the ordinary idle-blank timeout fired, wasting power and heat with
nothing visible. `lock` avoids this because logind's `lock` action never triggers a suspend by
itself, and once the session is locked, GNOME's screensaver blank timeout (about 30 seconds
later) turns the panel off — giving a blank-but-awake laptop instead of a lit-but-closed one.
The niri session's swayidle `lock` handler (mechanism 3) responds to the same signal, so the
behavior is consistent across sessions.

**Docked/external-monitor behavior is untouched**: while an external monitor is attached, GNOME's
own power daemon (`gsd-power`) holds its own `handle-lid-switch` block inhibitor that makes the
logind lid action moot — this is pre-existing GNOME behavior, not something this repo configures,
and it means closing the lid while docked still just moves windows to the external display as
before, with no lock and no suspend. `HandleLidSwitchDocked` is deliberately left at its systemd
default (`ignore`) rather than being set explicitly, since the `gsd-power` inhibitor already
covers that case.

**Important nuance**: sleep inhibitors (mechanism 1) do **not** protect against lid-close
suspend. Logind's own default (`LidSwitchIgnoreInhibited=yes`) means the lid action ignores
ordinary sleep inhibitors entirely — this is why the lid setting above is a logind *action*
setting rather than something an inhibitor could substitute for. An open Claude Code session
alone would not have prevented lid-close suspend without this setting.

**Idle-suspend timeouts** are configured in `modules/home/desktop/gnome.nix` via Home Manager's
`dconf.settings`, under `org/gnome/settings-daemon/plugins/power`:

```nix
sleep-inactive-ac-type = "nothing";          # AC: never auto-suspend on idle
sleep-inactive-ac-timeout = 3600;            # inert given the type above; left in place
sleep-inactive-battery-timeout = 3600;       # battery: 60 minutes
sleep-inactive-battery-type = "suspend";     # explicit, not left to the schema default
idle-dim = true;
```

and, under `org/gnome/desktop/session`: `idle-delay = 300` (5-minute screen dim/blank — this is
purely visual blanking, unrelated to sleep, and is not part of the no-sleep story).

On AC power, idle-based auto-suspend is disabled outright — a plugged-in machine never
auto-suspends on idle, inhibitor or not. On battery, idle-suspend is retained at 60 minutes as a
courtesy/battery-protection measure, but it only fires when no logind block inhibitor is held —
which means it is inert any time a Claude Code session happens to be open (the normal case while
agents are working). This is exactly why the battery backstop (mechanism 4) exists: the 60-minute
idle-suspend is not a reliable safety net on its own.

One more detail worth knowing if a suspend "should have happened but didn't": GNOME's idle-suspend
watch is one-shot per idle period — if it's denied once because an inhibitor is held, it does not
retry on its own. It only re-arms on a handful of trigger events (an AC/battery power-source
change, a screensaver state change, crossing the 20% "battery low" threshold, and similar). If an
inhibitor is released mid-idle-period, the countdown may not simply resume from where it left off.

### 3. The niri session equivalent (same intent, different tool)

The niri session doesn't use GNOME's power daemon, so idle handling there is configured
separately via `swayidle`, in `config/config.kdl` (deployed by Home Manager):

```
spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" "before-sleep" "swaylock -f" "lock" "swaylock -f"
```

This locks the screen after 5 minutes idle and on `before-sleep`/`lock` signals — but it never
triggers an auto-suspend on its own. An earlier version of this configuration had a
`"timeout" "600" "systemctl suspend"` clause that auto-suspended the niri session after 10
minutes idle; that clause has been removed, so the niri session now has **zero idle-based
auto-suspend**, matching the intent of the GNOME-session AC policy above (though the niri
session has no equivalent of the GNOME battery 60-minute timeout — its only idle behavior is
locking).

Lid handling needs no separate niri configuration at all: niri natively turns the internal
monitor off and back on in sync with the physical lid switch, independent of logind's
`HandleLidSwitch` setting. The logind `lock` setting from mechanism 2 still applies underneath
(niri doesn't override it), and swayidle's existing `lock` handler responds to that same signal,
so lid-close behavior is consistent between the GNOME and niri sessions.

### 4. The battery-level suspend backstop (the inhibitor-bypassing safety net)

Everything above has one shared gap: if a Claude Code session (or any other inhibitor holder) is
open, ordinary idle-suspend simply cannot fire, on any power source. That's fine on AC power, but
on battery it means a laptop with an open agent session and a closed lid could, in principle, run
the battery all the way to zero and hard power off — with no warning and no graceful suspend.

To close that gap, `modules/system/power.nix` defines a root-owned oneshot service
(`battery-suspend-backstop`) driven by a timer that fires every 60 seconds
(`OnBootSec = "2min"; OnUnitActiveSec = "60s"`). Each tick, it globs
`/sys/class/power_supply/BAT*` (deliberately not a broader `power_supply/*` glob — this host has
an unrelated peripheral battery device that always reports itself as discharging, which would
false-trigger a broader glob) and, if a battery's `status` is `Discharging` and its `capacity` is
`<= 10`, runs:

```
systemctl suspend -i
```

The `-i` flag is the key: it tells logind to suspend while **skipping every ordinary sleep
inhibitor**, including the Claude Code one from mechanism 1. Root is authorized to do this via
polkit. This is the only mechanism on this system that is guaranteed to suspend the machine
regardless of what inhibitors are held.

**Why 10%, and why this exists instead of relying on the battery's own built-in low-battery
protection**: this hardware only supports suspend-to-idle (`s2idle`), not a deeper suspend state,
and even a suspended machine on this hardware still drains roughly 1.5-3% of battery per hour.
Hibernate/HybridSleep were considered and rejected (see "Why not" below), so the backstop needs
enough headroom below the point of no return to survive hours, not minutes, of suspended
drain — 10% comfortably provides that, versus the 2% the platform's own critical-battery handling
uses (which, as covered below, doesn't actually work under an inhibitor anyway).

There's no hysteresis band on this loop by design: every tick, if the battery is still `<= 10%`
and discharging — including immediately after a wake — it suspends again. That repeated
resuspend-on-every-wake behavior is the protection working as intended, not a bug; each cycle
costs very little battery, and the alternative (waiting for some higher threshold before
re-arming) would just mean more awake time below the safety margin.

**Escape hatches**, if a deliberate low-battery working session is wanted:
- Plug in the charger — the battery status leaves `Discharging` and the backstop stops firing.
- Stop the timer for the current boot: `systemctl stop battery-suspend-backstop.timer` (it
  re-enables automatically at the next boot or the next `nixos-rebuild switch`, so this is not a
  persistent opt-out).

## How the four mechanisms compose

| Scenario | What happens |
|---|---|
| AC power, Claude Code session open, lid open | Nothing sleeps — AC idle-suspend is disabled outright, session or no session. |
| AC power, no Claude Code session, lid open, idle 60+ minutes | Still nothing — AC idle-suspend type is `"nothing"` unconditionally. |
| Battery, Claude Code session open (inhibitor held), idle 60+ minutes | The idle-suspend watch fires but is denied by logind (blocked by the inhibitor) and does not retry until a re-arm event. Machine stays awake. |
| Battery, no Claude Code session, idle 60+ minutes | Idle-suspend succeeds normally — the machine suspends. |
| Lid closed, any power source, no external monitor | Session locks; the panel powers off shortly after (about 30 seconds on GNOME, immediately on niri). The machine never suspends from this alone. |
| Lid closed, external monitor(s) attached | GNOME's own docked-lid inhibitor takes over (pre-existing, not repo-configured); windows move to the external display, no lock, no suspend. |
| Battery at 10% or below and discharging, regardless of inhibitors, lid state, or session state | The battery backstop suspends the machine every ~60 seconds via `systemctl suspend -i`, bypassing every inhibitor, until the charger is connected. |

## Activation & verification

Configuration being committed to this repository is not the same as it being live on a running
system — some of these settings (particularly the logind lid action) require a service restart
or reboot to take effect after a rebuild. Run the checks below on a live system rather than
trusting the committed config alone; the commands are read-only and safe to run at any time.

**Lid action (logind)** — check whether the lid setting has actually been picked up:

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitch
```

Expected: `s "lock"`. If this instead returns `s "suspend"` (the systemd stock default), the
`/etc/systemd/logind.conf` change has been written by a rebuild but `systemd-logind` has not
picked it up yet — the lid-close-never-suspends guarantee is **not actually in effect** even
though the configuration is committed. Fix with either:

```bash
sudo systemctl restart systemd-logind
```

or a reboot, then re-run the `busctl` check above to confirm it now reports `"lock"`.

**Battery backstop timer** — confirm it's running:

```bash
systemctl is-active battery-suspend-backstop.timer
systemctl list-timers battery-suspend-backstop.timer --no-pager
```

Expected: `active`, with the next elapse within about 60 seconds.

**GNOME idle-suspend settings** — confirm the dconf values Home Manager wrote are the live
values:

```bash
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout
```

Expected: `'nothing'`, `'suspend'`, `3600` respectively.

**Claude Code session inhibitor** — while a Claude Code session is open, confirm its inhibitor is
held:

```bash
systemd-inhibit --list | grep claude-code
```

Expected: a `sleep:idle` `block` entry with `who` set to `claude-code`. It should disappear
within moments of the session ending (or the owning process dying, via the `tail --pid`
tether).

## Why not just X

A few simpler-sounding alternatives were considered and rejected — noting them here so a future
change doesn't accidentally re-introduce a problem that was already worked through.

**Plain `ignore` instead of `lock` for the lid action.** This looks like the more literal "do
nothing on lid close" option, but it isn't: because mutter refuses to power off the only display
even when the lid is shut, `ignore` leaves the internal panel lit and rendering *inside a closed
laptop lid* until the ordinary idle-blank timer eventually catches up — a real heat and power
concern, not just a cosmetic one. `lock` sidesteps this because the lock action itself triggers
GNOME's own (much faster) screensaver-blank timeout.

**Relying on UPower's built-in critical-battery action instead of a dedicated backstop timer.**
UPower ships its own low-battery protection (`CriticalPowerAction`, configured to trigger a
HybridSleep at 2% battery). This setting is left in place in this repository because it's
harmless, but it is not load-bearing: UPower's critical-battery call is an ordinary (non-bypassing)
sleep request, which means it is rejected outright by logind whenever a block inhibitor — such as
the Claude Code one — is held, and UPower does not retry it. In other words, under exactly the
conditions this whole page is trying to survive (a long-running agent session holding an
inhibitor), UPower's own safety net silently does nothing. The dedicated backstop timer's
inhibitor-bypassing `systemctl suspend -i` call is what actually provides protection.

**Hibernate or suspend-then-hibernate instead of suspend-to-idle.** This hardware only supports
suspend-to-idle (`s2idle`) — there is no deeper hardware suspend state available. Hibernate was
evaluated and rejected as unreliable on this machine: hibernate needs a swap allocation at least
as large as the RAM being used at hibernate-entry time, and this system's swap configuration is
smaller than the RAM routinely in use under agent workloads, so a hibernate attempt could not be
trusted to succeed. Suspend-to-idle at a 10% threshold, with hours of headroom before power-off,
was judged more reliable than a hibernate path that might fail outright.

## Applies to laptops only

The lid-close and battery-backstop mechanisms are both inert (no-ops) on non-laptop hosts, since
there is no lid to close and no battery to discharge — the underlying module is shared across all
hosts for simplicity, but only has an effect where the relevant hardware exists.
