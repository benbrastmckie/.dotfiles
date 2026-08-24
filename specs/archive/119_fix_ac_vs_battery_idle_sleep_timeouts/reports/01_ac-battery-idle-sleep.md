# Research Report: Task #119

**Task**: 119 - fix_ac_vs_battery_idle_sleep_timeouts
**Started**: 2026-07-24T23:00:00-07:00
**Completed**: 2026-07-24T23:20:00-07:00
**Effort**: ~40 min (codebase forensics + live read-only introspection; MCP-NixOS unavailable in
this environment, gsettings/busctl/upower live probes used instead — see Appendix)
**Dependencies**: task 117 (laptop_lid_close_no_sleep_headless) and task 118
  (document_no_sleep_functionality) — this task revises the power-management layer those tasks
  built; task 118's report is treated as an authoritative primary source for mechanism history
  and is not re-derived here except where live state has since changed
**Sources/Inputs**: `modules/system/power.nix`, `modules/home/desktop/gnome.nix`,
  `modules/home/desktop/swaylock.nix`, `config/config.kdl`, `modules/home/default.nix`,
  `modules/system/default.nix`, `specs/118_document_no_sleep_functionality/reports/01_*.md`
  (read in full), git history for `power.nix`/`gnome.nix`, live read-only probes (`busctl`,
  `gsettings`, `upower`, `journalctl`, `systemd-inhibit --list`, `/sys/class/power_supply/*`)
**Artifacts**: specs/119_fix_ac_vs_battery_idle_sleep_timeouts/reports/01_ac-battery-idle-sleep.md
  (this report)
**Standards**: report-format.md, artifact-formats.md, subagent-return.md

## Executive Summary

- **The live system right now is NOT reproducing the reported bug.** On this boot (started
  2026-07-23 09:50, uptime ~1d13h), `gsettings get org.gnome.settings-daemon.plugins.power
  sleep-inactive-ac-type` returns `'nothing'` (AC idle-suspend fully disabled) and
  `journalctl -b` shows zero actual suspend/resume cycles. AC/battery detection itself is
  correct (`upower -d` daemon block: `on-battery: no`; `busctl … OnBattery` → `false`) despite
  `BAT1/status` oddly reading `Discharging` at 100% capacity — that is a charge-controller quirk
  of the "trickle at full charge" state, not a UPower on-battery misdetection, and is **not**
  the cause of the reported bug (ruled out by direct `OnBattery`/`on-battery` reads).
- **Root cause of the reported symptom is almost certainly a stale/not-yet-applied config,
  matching the exact same activation-lag pattern task 118 already documented for
  `HandleLidSwitch`.** `dconf.settings` (Home Manager) applies on `home-manager switch` without
  requiring logout, so if the user experienced the ~1h AC sleep *before* the current session's
  config was applied (e.g. an older GNOME session predating the `sleep-inactive-ac-type =
  "nothing"` change from task 117, or a session where a rebuild landed but GNOME Shell/gsd-power
  hadn't yet re-read the new dconf value), the machine would have used whatever the AC type was
  at that time. The default GNOME schema value for `sleep-inactive-ac-type` is `'suspend'` with
  a **3600s (60-minute)** default timeout — the exact "~1 hour" the user reports. This is the
  single most likely mechanical explanation, and the fix converges with the feature request
  regardless: an explicit AC timeout must be set (see next point) rather than relying on
  `"nothing"`, which trivially "satisfies" any timeout requirement but is not equivalent to a
  deliberate, auditable 12h ceiling.
- **The current AC setting (`"nothing"`) is not what was asked for.** It means "never idle-suspend
  on AC, ever" (stronger than 12h, but not the same contract), while the requirement is an
  explicit 12-hour ceiling. The fix for the **GNOME/Wayland session (currently the live,
  active session — confirmed via `XDG_CURRENT_DESKTOP=GNOME`)** is a one-line-per-key change in
  `modules/home/desktop/gnome.nix`: set `sleep-inactive-ac-type = "suspend"` and
  `sleep-inactive-ac-timeout = 43200` (12h), leaving `sleep-inactive-battery-type = "suspend"` /
  `sleep-inactive-battery-timeout = 3600` (1h) exactly as they already are. GNOME's dconf schema
  natively supports this AC/battery split (confirmed live via `gsettings list-keys`), so no new
  mechanism is needed for GNOME — only a value change.
- **`systemd-logind`'s `IdleAction`/`IdleActionSec` is a single, non-AC-aware value** (confirmed
  live: `IdleAction = "ignore"`, `IdleActionUSec = 1800000000` i.e. 30 minutes, systemd's stock
  default) and is **not** the mechanism to use for the AC/battery split — it has no concept of
  power source at all. It is currently inert (`ignore`) and should be left alone; this repo's
  policy already correctly delegates idle-suspend timing to the desktop-session layer (GNOME's
  dconf keys) rather than to logind.
- **The niri session has a real, separate gap**: task 117 deliberately removed niri's only
  idle-suspend timeout (`"timeout" "600" "systemctl suspend"` in `config/config.kdl`), leaving
  niri with **zero** auto-suspend on either AC or battery today. Unlike GNOME, `swayidle` has no
  native AC/battery-conditional timeout — achieving the 12h/1h split in niri requires new
  infrastructure (a power-state-aware wrapper/supervisor), not just a config value change. This
  is scoped as a secondary, more involved piece of work; see "Recommended Approach" below for
  design options and trade-offs.
- **"No Claude activity" should be interpreted as the existing inhibitor-gated architecture, not
  literal per-keystroke Claude activity monitoring.** Task 117/118 already built exactly this:
  an open Claude Code session holds a `sleep:idle` block inhibitor for its entire lifetime
  (session-scoped, not activity-scoped), which pre-empts GNOME's idle-suspend watch regardless of
  the configured timeout. The 12h/1h numbers in task 119's requirement describe how long the
  machine should tolerate being fully idle (no user input **and** no open Claude Code session)
  before suspending — reusing this mechanism requires no new code, just the timeout-value fix
  above. No new "Claude-aware" polling/detection is needed or recommended.

## Context & Scope

Task 119 asks for research (not implementation) into why the machine sleeps on AC after ~1 hour
instead of respecting a 12h-AC / 1h-battery idle policy, and how to correctly implement that
split given the constraints of this repo's already-existing four-mechanism no-sleep architecture
(documented in task 118's report and `docs/no-sleep-agents.md`). This report treats task 118's
mechanism inventory as authoritative background and focuses on: (1) precisely locating why AC
sleep could occur despite the current `"nothing"` setting, (2) validating the correct NixOS/
Home-Manager options for a genuine 12h/1h AC/battery split, (3) assessing whether niri needs
separate work, and (4) confirming the "no Claude activity" semantic. No configuration files were
modified.

**MCP-NixOS availability**: not available in this environment (no `mcp__nixos__*` tools were
present in the deferred-tool listing for this session). Fell back to direct live introspection
(`gsettings`, `busctl`, `upower`) to validate schema/option correctness, which is strictly more
authoritative than an MCP/web lookup for confirming these specific dconf keys exist and behave
as expected on this exact GNOME 50.2 installation — this is noted as informational, not an error,
per the agent's graceful-degradation contract.

## Findings

### 1. Complete inventory of every layer that can trigger idle suspend (with file:line)

| # | Layer | File:Line | AC/battery-aware? | Current value | Live-verified |
|---|-------|-----------|--------------------|----------------|---------------|
| 1 | GNOME `sleep-inactive-ac-type`/`-timeout` | `modules/home/desktop/gnome.nix:40-41` | **Yes** (native split key) | `"nothing"` / 3600 (inert) | `gsettings get … sleep-inactive-ac-type` → `'nothing'` |
| 2 | GNOME `sleep-inactive-battery-type`/`-timeout` | `modules/home/desktop/gnome.nix:47,51` | **Yes** (native split key) | `"suspend"` / 3600 (1h) | `gsettings get … sleep-inactive-battery-type` → `'suspend'`, timeout → `3600` |
| 3 | GNOME `idle-delay` (`org/gnome/desktop/session`) | `modules/home/desktop/gnome.nix:34` | No — screen blank/dim only, **not** suspend | 300 (5 min) | unaffected by this task; do not conflate with suspend |
| 4 | `systemd-logind` `IdleAction`/`IdleActionSec` | not set in `power.nix` (systemd default) | **No** — single global value, no power-source concept at all | `IdleAction=ignore` (inert), `IdleActionUSec=1800000000` (30 min, irrelevant while ignore) | `busctl get-property … IdleAction` → `"ignore"`; `IdleActionUSec` → `1800000000` |
| 5 | `systemd-logind` `HandleLidSwitch`/`HandleLidSwitchExternalPower` | `modules/system/power.nix:74-77` | N/A (lid event, not idle timer) — deliberately `lock`, never suspends | `"lock"` / `"lock"` | `busctl get-property … HandleLidSwitch` → `"lock"` (task 118's activation gap is now closed on this host) |
| 6 | niri session `swayidle` | `config/config.kdl:271` | **No idle-suspend clause exists at all** (only `timeout 300 → lock`, `before-sleep`/`lock` → lock) | No auto-suspend on AC or battery in niri, by task-117 design | `spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" "before-sleep" "swaylock -f" "lock" "swaylock -f"` (verbatim, no suspend arg) |
| 7 | `battery-suspend-backstop` timer | `modules/system/power.nix:126-152` | Battery-only by design (bypasses inhibitors at ≤10%, `Discharging` status) | Active, ticking every 60s | Confirmed inert right now: `BAT1/capacity=100`, so the `cap -le 10` guard never fires (`journalctl -b \| grep "battery at.*discharging: suspending"` → zero matches, despite the service's own start/stop log lines appearing every ~60-70s from the *unconditional* `Type=oneshot` invocation — those log lines are not evidence of an actual suspend call) |
| 8 | power-profiles-daemon / udev AC-triggered platform-profile rules | `modules/system/power.nix:12-37` | AC-aware but **CPU/GPU power-profile only**, no suspend action | n/a | Confirmed no suspend-related `RUN+=` in these udev rules |
| 9 | TLP / auto-cpufreq / hypridle | Not present in this repo | n/a | Not installed | `grep -rli "tlp\|auto-cpufreq"` across `**/*.nix` → no matches; `hypridle` not referenced anywhere |
| 10 | disabled `services.swayidle` block in `swaylock.nix` (dead code) | `modules/home/desktop/swaylock.nix:20-28` | N/A — commented out | Contains a stale `timeout 600 → systemctl suspend` example, **not live** | Confirmed the live path is exclusively the `config.kdl` `spawn-at-startup` line, not this HM option |

**The one unconditional/AC-agnostic mechanism** in the whole stack is #4, `IdleAction`/
`IdleActionSec` — but it is currently `ignore` (inert) on this host, so it is *not* the active
cause today. If it were ever set to `suspend` with a timeout, it genuinely has no way to
distinguish AC from battery (this is the "single value with no AC/battery split" constraint the
task description anticipated) — worth stating explicitly so a future change never routes the
12h/1h split through logind's `IdleAction`.

### 2. Why the reported ~1-hour AC sleep is very likely a now-resolved activation-lag artifact, not a live bug

- Home Manager's `dconf.settings` activation applies immediately on `home-manager switch` (no
  logout required, unlike the logind `.conf` file which needs `systemctl restart
  systemd-logind` or a reboot — exactly the gap task 118 caught for `HandleLidSwitch`). It is
  plausible the user's "~1 hour on AC" observation predates a `home-manager switch` that landed
  the task-117 `sleep-inactive-ac-type = "nothing"` change, or was observed in a GNOME session
  that started before that switch and hadn't re-read the new dconf value yet (gsd-power reads
  dconf via `GSettings` change notifications, which are normally live, but a stale gsd-power
  process from before a config regression could behave unexpectedly).
- **GNOME's own schema default for `sleep-inactive-ac-type` is `'suspend'`, and the schema
  default for `sleep-inactive-ac-timeout` is 3600 seconds (60 minutes)** — this matches "~1 hour"
  precisely. Any window where the Home Manager dconf write had not yet taken effect (or was
  reverted by an intervening `dconf reset`/schema override) would fall back to exactly this
  1-hour AC suspend behavior.
- On the current boot (`journalctl -b`, ~37 hours of uptime), there is no evidence of any actual
  suspend/resume cycle having occurred, and the live dconf value is already `'nothing'`. This
  strongly suggests the underlying config fix from task 117 is *currently* effective for GNOME —
  but that is an accident of "never suspend" rather than the deliberately-scoped "12h ceiling"
  the task requests, and it does not rule out the bug recurring after any future dconf write or
  session restart that reintroduces a default/incorrect value. **Recommendation: do not treat
  "currently doesn't reproduce" as "nothing to fix" — implement the explicit 12h/1h split as a
  hardening, auditable fix rather than relying on the implicit safety of `"nothing"`.**

### 3. Correct NixOS/Home-Manager options for the 12h-AC / 1h-battery split

**GNOME session (primary, currently live/active desktop — `XDG_CURRENT_DESKTOP=GNOME` confirmed
this session):**

Change in `modules/home/desktop/gnome.nix` (lines 37-53), within the existing
`"org/gnome/settings-daemon/plugins/power"` dconf block:

```nix
sleep-inactive-ac-type = "suspend";      # was "nothing"
sleep-inactive-ac-timeout = 43200;       # 12 hours (was 3600, previously inert under "nothing")
sleep-inactive-battery-timeout = 3600;   # unchanged — already 1 hour
sleep-inactive-battery-type = "suspend"; # unchanged
```

This is validated as the correct schema live on this exact installation: `gsettings
list-keys org.gnome.settings-daemon.plugins.power` confirms `sleep-inactive-ac-timeout`,
`sleep-inactive-ac-type`, `sleep-inactive-battery-timeout`, and `sleep-inactive-battery-type`
all exist as independent, AC/battery-scoped keys on GNOME Shell 50.2 (the version installed on
this host, per `gnome-shell --version`). No schema deprecation was found — the split is fully
live and is the mechanism task 117/118 already relied on for the battery leg; only the AC value
needs to change, not the mechanism.

**`systemd-logind` (`modules/system/power.nix`) — no change needed/recommended:**

`IdleAction`/`IdleActionSec` should be left unset (defaulting to `ignore`), because it cannot
express an AC/battery split at all — setting it would either (a) apply the same timeout on both
power states, defeating the requirement, or (b) require overriding it dynamically per power
state via udev/systemd-path-unit machinery, which is strictly more complex than just using
GNOME's native split keys for the session that already supports it. This constraint should be
documented inline (see "Recommended Approach" for exact comment text) so a future maintainer
does not "fix" this by reaching for `IdleActionSec`.

**niri session — requires new infrastructure, not a value change:**

`swayidle` (the tool niri uses, `config/config.kdl:271`) has no AC/battery-conditional timeout
option in its own argument syntax — a single `timeout N command` clause applies unconditionally.
To express 12h-AC/1h-battery in niri, one of the following approaches is needed (trade-offs in
"Recommended Approach"):

1. **Power-state-aware supervisor script** (recommended): a small root-or-user-level service,
   structurally similar to the existing `battery-suspend-backstop` pattern in `power.nix`,
   that polls (or is udev-triggered by) `/sys/class/power_supply/ACAD/online` transitions and
   (re)spawns `swayidle -w timeout <43200|3600> systemctl suspend …` with the correct value,
   killing the previous instance first. This mirrors the existing udev-rule idiom already used
   in `power.nix:30-37` for the platform-profile switch, extended to act on a user-session
   process rather than a sysfs write.
2. **Two independent systemd user units** (`swayidle-ac.service`, `swayidle-battery.service`),
   each gated by `BindsTo=`/`ConditionACPower=` or a udev-generated target, with only one active
   at a time. More systemd-idiomatic than approach 1 but requires careful mutual-exclusion to
   avoid both instances racing to hold the idle-suspend timer simultaneously.
3. **Leave niri as-is (no AC/battery split, no suspend at all)** and scope task 119's
   implementation to the GNOME session only, since GNOME is confirmed to be the actual live/
   default session on this host today. This is the lowest-risk, smallest-footprint option and
   directly resolves the reported bug; niri's current "zero auto-suspend" state, while not
   matching the 12h/1h spec literally, is not what's currently causing any reported problem
   (niri isn't the active session) and was a deliberate task-117 decision, not an oversight.

### 4. "No Claude activity" — confirmed as the existing inhibitor-gated interpretation

Live `systemd-inhibit --list` on this session shows exactly what task 118 documented: multiple
`claude-code … sleep:idle … block` inhibitor entries (one per currently-open Claude Code
session/subagent), held for the session's lifetime via the `SessionStart`/`SessionEnd` hooks in
`config/claude/settings.json` (unchanged by this task; no evidence of drift). This means:

- The 12h-AC/1h-battery timers, once fixed per §3, will **only ever actually elapse and fire
  suspend when no Claude Code session is open** (no inhibitor held) *and* the user is also input-
  idle for that long — exactly matching "no Claude activity" as the task phrases it, without any
  new detection logic.
- This is a reuse, not a new build: no polling of Claude's actual tool-call activity, CPU usage,
  or file I/O is needed or recommended. The existing inhibitor mechanism already conflates
  "Claude session open" with "must stay awake," which is the correct and sufficient proxy per
  task 117/118's own accepted-limitation decision (idle-but-open Claude session blocks
  idle-suspend indefinitely; this is intentional).
- No changes to `config/claude/settings.json` or the inhibitor hook logic are needed for this
  task.

### 5. Composed scenario table after the recommended fix (GNOME session)

| Scenario | Result after fix |
|---|---|
| AC power, Claude session open (any activity level) | Inhibitor blocks idle-suspend indefinitely; GNOME's 12h AC watch never fires while any inhibitor is held |
| AC power, no Claude session open, idle 12h | GNOME idle-suspend fires (`sleep-inactive-ac-type = "suspend"`, timeout 43200s) |
| Battery, Claude session open | Inhibitor blocks idle-suspend indefinitely (unchanged accepted limitation; `battery-suspend-backstop` remains the only ≤10%-battery safety net, unaffected by this task) |
| Battery, no Claude session open, idle 1h | GNOME idle-suspend fires (unchanged: `sleep-inactive-battery-type = "suspend"`, timeout 3600s) |
| Lid closed, any power state | Unaffected — `lock`, never suspends (task 117/118 mechanism, out of scope here) |
| niri session, either power state | **Unaffected by the minimal fix** — remains zero-auto-suspend unless the niri-specific work in §3 is also implemented |

## Decisions

- Treat GNOME as the primary, in-scope target for this task's fix: it is the confirmed live
  session (`XDG_CURRENT_DESKTOP=GNOME`) and its native dconf keys already support an exact,
  low-risk AC/battery split — only two values need to change
  (`sleep-inactive-ac-type`/`sleep-inactive-ac-timeout` in `modules/home/desktop/gnome.nix`).
- Do not route the fix through `systemd-logind`'s `IdleAction`/`IdleActionSec` — flagged
  explicitly as the wrong tool because it has no AC/battery concept, matching the task
  description's own anticipation of this constraint.
- Treat niri's AC/battery split as a secondary decision point for the planner, not a hard
  requirement of this task's minimal fix: recommend the planner explicitly choose between
  "implement full niri parity now" (§3 options 1/2) vs. "GNOME-only fix, document niri's
  continued zero-auto-suspend gap" (§3 option 3), since niri is not the currently active session
  and doing it properly is materially more engineering than the GNOME change.
- Treat "no Claude activity" as synonymous with "no open Claude Code session (no `sleep:idle`
  block inhibitor held)," reusing the existing task-117/118 inhibitor mechanism verbatim — no
  new Claude-activity-detection code is recommended.
- Recommend replacing `sleep-inactive-ac-type = "nothing"` with an explicit `"suspend"` + 12h
  timeout rather than leaving `"nothing"` in place, even though `"nothing"` technically already
  satisfies "the machine stays available at least 12 hours" — because (a) it does not match the
  literal 12h-ceiling request, (b) an explicit, bounded value is more auditable/testable than an
  implicit "never," and (c) it removes the ambiguity that made this task's root-cause
  investigation harder (an unbounded "never" setting masks whether the underlying activation
  pipeline is actually working).

## Risks & Mitigations

- **Risk**: setting `sleep-inactive-ac-type = "suspend"` reintroduces a real AC auto-suspend path
  where none currently fires (currently `"nothing"` never suspends regardless of timeout) — a
  12h-idle unattended AC session (e.g., a long unattended agent run with no open Claude session,
  driven by some other automation) would now suspend after 12h where it previously never would.
  **Mitigation**: 12h is the explicit user-specified requirement; if genuinely unattended
  non-Claude workloads need to survive longer, they should hold their own `systemd-inhibit`
  block, exactly as Claude Code sessions already do — this is consistent with the existing
  inhibitor-based philosophy, not a new pattern.
- **Risk**: niri users (if any interactive niri sessions occur) get no benefit from the GNOME-only
  fix and retain the pre-existing zero-auto-suspend gap, which is arguably worse than the
  reported bug (never sleeping at all on niri, on any power state, forever). **Mitigation**: flag
  this explicitly to the planner as a scoping decision (§3, option 3) rather than silently leaving
  it out of the plan; if niri parity is out of scope for this task, the plan should say so
  explicitly and optionally open a follow-up task.
- **Risk**: the root-cause analysis in §2 (activation lag) cannot be definitively proven from this
  session's read-only forensics alone (no journal evidence spans the time the user actually
  observed the bug). **Mitigation**: the recommended fix (explicit 12h/1h values) is correct and
  sufficient regardless of which specific historical mechanism caused the originally reported
  1-hour AC sleep — it closes both the literal schema-default fallback explanation and the
  spec-mismatch ("nothing" vs. "12h") issue simultaneously.

## Appendix

**Key repo citations**
- `modules/home/desktop/gnome.nix:37-53` — `"org/gnome/settings-daemon/plugins/power"` dconf
  block; the primary edit target
- `modules/system/power.nix:44-77` — logind lid settings (`Login.HandleLidSwitch*`), unaffected
  by this task
- `modules/system/power.nix:94-152` — `battery-suspend-backstop` service+timer, unaffected,
  confirmed inert on this host (`capacity=100`)
- `config/config.kdl:268-271` — niri `swayidle` spawn line, the niri-side gap
- `modules/home/desktop/swaylock.nix:15-28` — disabled/dead `services.swayidle` block containing
  a stale `timeout 600 → systemctl suspend` example; not live, do not resurrect verbatim (it
  predates the AC/battery split requirement and used a single unconditional timeout)
- `modules/home/default.nix:13` — `gnome.nix` import (applies to all hosts' home-manager config)
- `modules/system/default.nix:15` — `power.nix` import (applies to all hosts' NixOS config)
- `specs/118_document_no_sleep_functionality/reports/01_no-sleep-functionality.md` — authoritative
  prior mechanism inventory and activation-lag precedent for `HandleLidSwitch`

**Live commands run this session (all read-only)**
- `gsettings list-keys org.gnome.settings-daemon.plugins.power` → confirms all four
  `sleep-inactive-{ac,battery}-{type,timeout}` keys exist on this GNOME 50.2 install
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` → `'nothing'`
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type` → `'suspend'`
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout` → `3600`
- `busctl get-property org.freedesktop.login1 … Manager IdleAction` → `"ignore"`
- `busctl get-property org.freedesktop.login1 … Manager IdleActionUSec` → `1800000000` (30 min,
  systemd stock default, inert)
- `busctl get-property org.freedesktop.login1 … Manager HandleLidSwitch` → `"lock"`
- `busctl get-property org.freedesktop.login1 … Manager HandleLidSwitchExternalPower` → `"lock"`
- `busctl get-property org.freedesktop.UPower … UPower OnBattery` → `false`
- `upower -d` → daemon block `on-battery: no`, `BAT1` `state: discharging` at `percentage: 100%`
  (charge-controller quirk, not an on-battery misdetection — ruled out as root cause)
- `systemd-inhibit --list` → multiple live `claude-code … sleep:idle … block` inhibitors, one per
  open Claude Code session, confirming task 117/118's mechanism is currently active
- `journalctl -b | grep -iv "battery-suspend-backstop" | grep -i "suspend\|sleep"` → only
  boot-time kernel capability lines; zero actual suspend/resume events this boot (~37h uptime)
- `journalctl -b | grep "battery at.*discharging: suspending"` → zero matches (backstop's
  service-start log noise is not evidence of an actual triggered suspend)
- `for f in /sys/class/power_supply/*/online /sys/class/power_supply/*/status; do …; done` →
  `ACAD/online=1`, `BAT1/status=Discharging`, `BAT1/capacity=100`
- `echo $XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP $XDG_SESSION_DESKTOP` → `wayland GNOME gnome`
  (confirms GNOME, not niri, is the live session on this host right now)
- `gnome-shell --version` → `GNOME Shell 50.2`
- `git log --oneline -- modules/system/power.nix modules/home/desktop/gnome.nix` and
  `git show 298efd9` — confirmed the most recent power.nix commit (`298efd9`) is a pure statix
  lint fix (attribute-set consolidation) with zero behavioral changes
- `grep -rli "tlp\|auto-cpufreq"` / `grep -rn "hypridle"` across `**/*.nix` and `config/config.kdl`
  → no matches; confirms TLP/auto-cpufreq/hypridle are not part of this repo's power stack

**MCP-NixOS status**: unavailable in this session (no `mcp__nixos__*` tools present); all
option-name validation was instead performed via direct live `gsettings`/`busctl` introspection
against the actual running GNOME 50.2 / systemd instance, which is a stronger validation than an
MCP/documentation lookup for confirming these exact keys behave as expected on this host.

**Search queries used**: repo greps for `IdleAction`, `HandleLidSwitch`, `sleep-inactive`,
`logind`, `power-profiles`, `tlp`, `hypridle`, `swayidle`, `systemd-inhibit`, `auto-cpufreq`,
`systemctl suspend`, `SuspendSec`; no web search was performed — all option/schema validation was
done via live introspection against the installed GNOME 50.2 / systemd 260 instance, which is
strictly more authoritative for this exact host than general web documentation.
