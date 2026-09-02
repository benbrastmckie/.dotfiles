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

Mechanism 5 pulls the other way, and is listed here because it is routinely mistaken for a bug
in the first four: **keeping the machine awake and keeping the screen lit are separate
concerns**, and this system deliberately wants the first without the second.

## The mechanisms

### 1. Claude Code session inhibitors (the everyday layer)

Every time a Claude Code session starts, a `SessionStart` hook (configured in
`config/claude/settings.json`, deployed to `~/.claude/settings.json` by Home Manager) launches:

```
systemd-inhibit --what=sleep --who=claude-code --why="Claude Code session" --mode=block \
  tail --pid=$PPID -f /dev/null
```

in the background, and records the resulting PID in `/tmp/claude-inhibitor-${SESSION_ID}.pid`.
This holds a logind **block** inhibitor on `sleep` for as long as the session is
open — including while the session sits completely idle at the prompt.

**Why `sleep` and not `sleep:idle`.** An earlier version also took the `idle` lock. That was
dropped because it bought nothing and misdescribed the intent: blocking suspend is entirely the
job of the `sleep` lock, while logind's `idle` lock only suppresses the session's idle *hint*.
Screen blanking on this system is not driven by logind at all — it is driven by mutter's idle
monitor and by **GNOME SessionManager** inhibitors (see mechanism 5), so the `idle` lock never
actually held the screen on. Keeping it made `systemd-inhibit --list` look like the culprit
whenever the screen failed to blank, which sent at least one debugging session down the wrong
path. It is **session-scoped,
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
sleep-inactive-ac-type = "suspend";          # AC: explicit 12h idle-suspend ceiling
sleep-inactive-ac-timeout = 43200;           # 12 hours
sleep-inactive-battery-timeout = 3600;       # battery: 60 minutes
sleep-inactive-battery-type = "suspend";     # explicit, not left to the schema default
idle-dim = true;
```

and, under `org/gnome/desktop/session`: `idle-delay = 300` (5-minute screen dim/blank — this is
purely visual blanking, unrelated to sleep, and is not part of the no-sleep story).

On AC power, idle-based auto-suspend is bounded at an explicit 12-hour ceiling rather than
disabled outright — a plugged-in machine stays awake through any single Claude Code session (the
session's own `sleep` block inhibitor takes precedence for as long as it's held) and only
idle-suspends once 12 hours of continuous input-idle time have elapsed with no inhibitor held. On
battery, idle-suspend is retained at 60 minutes as a courtesy/battery-protection measure, and,
like the AC leg, it only fires when no logind block inhibitor is held — which means it is inert
any time a Claude Code session happens to be open (the normal case while agents are working).
This is exactly why the battery backstop (mechanism 4) exists: the 60-minute idle-suspend is not
a reliable safety net on its own.

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
auto-suspend on any power state** — its only idle behavior is locking. This is a deliberate,
acknowledged divergence from the GNOME session's 12h-AC/1h-battery split above, not an oversight:
`swayidle`'s `timeout` clause has no AC/battery-conditional concept of its own (a single
`timeout N command` applies unconditionally regardless of power source), so giving niri the same
split requires new supervisor infrastructure that is out of scope here and tracked as follow-up
work. The niri session's only auto-suspend protection today is the battery-level backstop
(mechanism 4, below), which is power-source-agnostic by design.

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
inhibitor**, including the Claude Code one from mechanism 1. This is the only mechanism on this
system that is guaranteed to suspend the machine regardless of what inhibitors are held --
**but only because of an explicit polkit grant**. By default, login1 ships
`suspend-ignore-inhibit` as `auth_admin_keep` for all three polkit subject classes, so a
session-less root caller (no interactive session, no polkit agent to prompt) is **denied**, not
authorized, when it calls `systemctl suspend -i` -- without an explicit grant, the backstop is
denied on every firing and can never actually suspend the machine. `modules/system/power.nix`
grants root that one action
explicitly via `security.polkit.extraConfig`, deliberately narrower than the
`10-systemd-logind-root-ignore-inhibitors.rules.example` systemd ships (which would grant
power-off/reboot/halt/suspend/hibernate all at once) -- this configuration grants suspend only.

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

### 5. Keeping the screen blanking (the opposite guarantee)

The intent of this system is a machine that never *suspends* while agents work — not a machine
whose display stays lit. The 5-minute screen blank (`org.gnome.desktop.session idle-delay = 300`)
is wanted, and should keep working no matter how long an agent session runs.

Nothing in mechanisms 1-4 keeps the screen on, and it is worth being precise about why, because
`systemd-inhibit --list` is a misleading place to look. Blanking is **not** driven by logind. It
is driven by mutter's idle monitor together with **GNOME SessionManager** inhibitors, which are a
separate DBus registry:

```bash
busctl --user call org.gnome.SessionManager /org/gnome/SessionManager \
  org.gnome.SessionManager GetInhibitors
```

Each returned object path can then be queried for `GetAppId`, `GetReason`, and `GetFlags`. The
flags are a bitmask — `1` logout, `2` switch-user, `4` suspend, `8` idle, `16` auto-mount — and
**flag `8` is the one that suppresses blanking**. A logind `sleep` inhibitor (mechanism 1) never
sets it.

In practice the flag-8 holders on this machine are Chromium-family browsers. A page calling
`navigator.wakeLock` makes the browser register a `Blink Wake Lock` inhibitor, and mutter
registers a matching `idle-inhibit` entry on the client's behalf via the Wayland
`zwp_idle_inhibitor_v1` protocol — two entries, one underlying cause. The lock outlives whatever
prompted it for as long as the tab stays open, so a single forgotten tab silently disables screen
blanking indefinitely.

**The guarantee is enforced by a watchdog, not by trusting applications.**
`modules/home/services/screen-blank-watchdog.nix` defines a user timer that fires every 30
seconds, reads real-input idle time from mutter's idle monitor, compares it against
`org.gnome.desktop.session idle-delay`, and calls `org.gnome.ScreenSaver.SetActive(true)`
directly once the delay is exceeded.

This works because of an asymmetry in GNOME's behaviour: idle inhibitors block only the
*automatic*, idle-triggered activation of the screensaver. An *explicit* `SetActive(true)` is
honoured even while flag-8 inhibitors are held — verified on this host by activating the
screensaver successfully with two inhibitors outstanding. The watchdog therefore reimplements
the idle trigger in the one form that cannot be vetoed.

Reading the threshold from `idle-delay` at each tick rather than hardcoding it means changing the
blank timeout in GNOME Settings changes the watchdog too, with no rebuild; `idle-delay = 0`
("never") is honoured as a no-op. On niri the GNOME DBus names are absent, every call fails, and
the script exits 0 without acting — swayidle owns locking there (mechanism 3).

Blanking is not suspending: this unit never suspends anything, and mechanisms 1-4 are unaffected.
Agents keep working with the screen dark, which is the whole point.

Belt and braces, both browser entry points additionally disable the wake-lock feature outright, so
the common case never reaches the watchdog:

- `modules/system/packages.nix` overrides `brave` with
  `commandLineArgs = "--disable-blink-features=ScreenWakeLock"`.
- `packages/playwright-mcp.nix` passes the same flag through a generated `--config` file, and
  additionally runs the browser **headless**. Headless is the load-bearing setting there: a
  headed browser owns a Wayland surface and can inhibit through `zwp_idle_inhibitor_v1`
  regardless of any Blink flag, whereas a surface-less browser cannot inhibit by any route.

This distinction matters for agent workloads specifically. GNOME needs an **uninterrupted**,
inhibitor-free idle stretch to reach the blank timeout, so agents launching short-lived headed
browsers on a loop can hold the screen on indefinitely while showing no persistent inhibitor in
any point-in-time check. Sampling over time (a few minutes of `GetInhibitors` at a fixed
interval) is the way to tell that pattern apart from a single stuck lock; a snapshot cannot.

**What was actually measured here** (worth recording, because Playwright was the initial
suspect and was wrong): sampling `GetInhibitors`, mutter's `GetIdletime`, and the count of live
`ms-playwright` browser processes every 2 seconds for ~2.5 minutes produced 76 samples, 24 of
which had Playwright browsers running (8 processes at peak). The inhibitor set was byte-identical
in every sample, and `GetIdletime` climbed monotonically straight through the Playwright activity.
So agent-driven Playwright browsers registered no idle inhibitors and did not reset the idle
timer. The two constant flag-8 holders — Brave's `Blink Wake Lock` and mutter's `idle-inhibit`
relay — were the entire cause; the Brave process had been up for over two days, holding a wake
lock from a page long since forgotten. The lesson generalizes: check `GetAppId` on each inhibitor
before blaming a process, and note that a mutter `idle-inhibit` entry names mutter, not the client
that requested it, so it must be attributed by correlation over time rather than by reading it.

The tradeoff is accepted deliberately: pages that legitimately want to hold the screen on (video,
presentations, recipes) no longer can, and the screen blanks on them after 5 minutes. That is the
desired behavior here — blanking the display costs a running agent nothing, since blanking is not
suspending.

To check the guarantee is live, confirm no flag-8 inhibitor is held while the browser is open:

```bash
busctl --user call org.gnome.SessionManager /org/gnome/SessionManager \
  org.gnome.SessionManager GetInhibitors
```

Expected: no entry whose `GetAppId` is a browser and whose `GetFlags` is `8`. Note that the flag
only takes effect for browser processes started *after* the rebuild — an already-running browser
keeps whatever locks it holds until it is restarted.

## How the mechanisms compose

| Scenario | What happens |
|---|---|
| AC power, Claude Code session open, lid open | Nothing sleeps — the session's `sleep` block inhibitor prevents idle-suspend for as long as it's held, regardless of elapsed idle time. The screen still blanks on the ordinary 5-minute `idle-delay`; blanking and suspend are independent (mechanism 5). |
| AC power, no Claude Code session, lid open, idle 12+ hours | The machine idle-suspends — the explicit 12-hour AC ceiling has elapsed with no inhibitor held. |
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

**Battery backstop polkit authorization** — confirm the polkit grant from `modules/system/power.nix`
is actually live and effective for root (requires `sudo`; this is a read-only authorization query,
it does not suspend anything):

```bash
sudo bash -c 'pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"'
```

Expected: **exit 0** (authorized), no `auth_admin_keep` line. Note the single-quoted `bash -c`
form is required so `$$` expands in the root shell, not your own; writing
`sudo pkcheck ... --process "$$"` instead expands `$$` in your own uid-1000 shell and will report
`auth_admin_keep`/exit 2 -- that is the mis-invocation, not a real failure.

**GNOME idle-suspend settings** — confirm the dconf values Home Manager wrote are the live
values:

```bash
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout
```

Expected: `'suspend'`, `43200`, `'suspend'`, `3600` respectively.

**Claude Code session inhibitor** — while a Claude Code session is open, confirm its inhibitor is
held:

```bash
systemd-inhibit --list | grep claude-code
```

Expected: a `sleep` `block` entry with `who` set to `claude-code`. It should disappear
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
