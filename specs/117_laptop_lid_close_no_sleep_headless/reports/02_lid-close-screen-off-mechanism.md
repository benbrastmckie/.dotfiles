# Research Report: Task #117 (Round 2) — Does the screen actually turn off?

**Task**: 117 - laptop_lid_close_no_sleep_headless
**Started**: 2026-07-14T21:30:00-07:00
**Completed**: 2026-07-14T22:10:00-07:00
**Effort**: ~45 min (live probes + upstream source verification)
**Dependencies**: Builds on reports/01_lid-close-no-sleep.md; audits its central unverified claim
**Sources/Inputs**: mutter 50.2 source (exact installed version), gnome-settings-daemon source, installed systemd 260 man page, niri wiki, live read-only probes of hamsa (Framework Laptop 13 AMD Ryzen AI 300)
**Artifacts**: specs/117_laptop_lid_close_no_sleep_headless/reports/02_lid-close-screen-off-mechanism.md (this report)
**Standards**: report-format.md, subagent-return.md

---

## Direct Answer (the headline question)

**The committed `HandleLidSwitch=ignore` change is NOT sufficient on its own. A companion screen-off mechanism is required for the GNOME session.** Round 1's claim that "mutter disables eDP on lid close" is **falsified for exactly the case that matters** (lid closed with NO external monitors): mutter 50.2's monitor-config generator deliberately keeps the built-in panel **active and rendering** whenever it is the only monitor, lid closed or not. After activating the committed config, closing the lid undocked would leave the panel powered, lit, and compositing inside the closed lid for up to **5 minutes** (until the existing `idle-delay = 300` blank fires), and it can re-light later (see the undock-while-closed edge case). This is precisely the panel-lit-in-a-bag failure mode this round was asked to rule in or out — it is **ruled in** for plain `ignore`.

**For the niri session, no companion is needed**: niri natively turns the internal monitor off on lid close, independent of logind.

**Recommended companion (concrete)**: change the two committed values in `modules/system/power.nix` from `"ignore"` to `"lock"`:

```nix
services.logind.settings.Login = {
  HandleLidSwitch = "lock";               # was "ignore"
  HandleLidSwitchExternalPower = "lock";  # was "ignore"
  # HandleLidSwitchDocked stays at its "ignore" default — unchanged
};
```

`lock` never suspends anything (it only screen-locks the running sessions), so the no-sleep goal is fully preserved; and locking is what makes GNOME actually power the panel off (~30 s after lock, verified against gsd-power source below). The docked/external-monitor path remains untouched by **two independent layers** (gsd-power's `handle-lid-switch` inhibitor + logind's `Docked` heuristic). Full option analysis in Findings §3.

---

## Verified Fact vs Inference — summary table

| # | Claim | Status | Evidence |
|---|-------|--------|----------|
| 1 | Live system is still PRE-change: no `HandleLidSwitch` in effective logind.conf → default `suspend` | **VERIFIED (live)** | `systemd-analyze cat-config systemd/logind.conf` → only `[Login] KillUserProcesses=false` |
| 2 | mutter tracks lid state via **UPower's `LidIsClosed`** D-Bus property, not via logind's lid action | **VERIFIED (source)** | mutter 50.2 `meta-backend.c:40,656,724` |
| 3 | `HandleLidSwitch=ignore` suppresses only logind's *action*; lid state stays visible to compositors (UPower reads the SW_LID evdev switch itself; logind's `LidClosed` property also keeps updating) | **VERIFIED (live + man page)** | `busctl ... LidClosed` → `b false` (property exists and is served regardless of Handle* config); `man logind.conf` (systemd 260): "If 'ignore', systemd-logind will never handle these keys" — action-only wording |
| 4 | **mutter keeps the internal panel ACTIVE when it is the only monitor and the lid is closed** | **VERIFIED (source, installed version 50.2)** | Three independent code paths, quoted in Findings §1 |
| 5 | mutter disables the internal panel on lid close **only when other monitors are connected** | **VERIFIED (source)** | `MONITOR_MATCH_VISIBLE` rule, Findings §1 |
| 6 | gsd-power locks/blanks on lid close **only if a gnome-session suspend inhibitor is registered**; Claude Code's `systemd-inhibit` (logind-level) does NOT register there | **VERIFIED (source + live)** | `do_lid_closed_action` source; live `gdbus ... IsInhibited 4` → `(false,)` while 7 claude-code logind inhibitors are held |
| 7 | niri turns the internal monitor off/on with the lid automatically | **VERIFIED (upstream docs)** | niri wiki, Switch Events page (quoted below); installed niri 26.04 |
| 8 | "Docked" for `HandleLidSwitchDocked` = docking station OR **more than one display connected**; default `ignore` | **VERIFIED (installed man page + live)** | systemd 260 `man logind.conf` quote below; live `Docked` property = `true` with 2 external DPs connected |
| 9 | With lid closed + screensaver active, GNOME powers displays off after 30 s | **VERIFIED (source)** | `SCREENSAVER_TIMEOUT_BLANK = 30` (gsd-power-constants.h); `backlight_disable()` → `set_power_saving_mode(GSD_POWER_SAVE_MODE_OFF)` |
| 10 | logind acts on the lid ~8 s after the last external monitor is unplugged with the lid still closed (gsd releases its inhibitor on a safety timer) | **VERIFIED (source) + INFERENCE on logind re-trigger** | `LID_CLOSE_SAFETY_TIMEOUT = 8` + comment "When unplugging the external monitor, give a certain amount of time before suspending the laptop" |
| 11 | Framework 13's EC/firmware does not power the panel off on lid close by itself; the OS/compositor decides | **INFERENCE** (consistent with all observed layers; no firmware-level cutoff found in any probe; not directly testable without closing the lid, which would suspend today) | — |

---

## Context & Scope

Second research round. Goal: rigorously verify whether the internal eDP panel powers off on lid close once `HandleLidSwitch=ignore` is activated, for both GNOME (mutter, the active session) and niri; if not, identify and recommend the companion mechanism; confirm the docked path is unaffected; enumerate any remaining suspend paths. Research only, no config edits, no activation.

**Live-probe caveat**: every live probe below reflects the **PRE-activation** system (`HandleLidSwitch` is still the stock `suspend`). **Do not close the lid to test anything right now** — it will suspend the machine and freeze the running agents (7 live `claude-code` inhibitors are `sleep:idle` blocks, which logind's lid action ignores by default because `LidSwitchIgnoreInhibited=yes`).

Live environment (verified this session):
- Framework `Laptop 13 (AMD Ryzen AI 300 Series)` (`/sys/class/dmi/id/product_name`), GNOME Shell 50.2 on Wayland (`XDG_CURRENT_DESKTOP=GNOME`, session Type=wayland), mutter 50.2, niri 26.04 installed as alternate session, systemd 260 (260.2), UPower 1.91.1.
- Lid switch present as evdev device: `Name="Lid Switch"`, `PNP0C0D/button/input0`, handler `event1` (`/proc/bus/input/devices`); `upower -d` → `lid-is-present: yes`, `lid-is-closed: no`; `/proc/acpi/button/lid/*/state` → `open`.
- Currently docked: eDP-1 + **two** external DP outputs connected (`/sys/class/drm/card1-DP-10, DP-11: connected`); `busctl` `Docked` → `b true`; gsd-power holds a live `handle-lid-switch` **block** inhibitor ("External monitor attached or configuration changed recently").
- Live gsettings still pre-activation as well: `sleep-inactive-ac-type 'suspend'` (repo commit 6207dc3 sets it to `nothing`, not yet switched in).

---

## Findings

### §1 GNOME/mutter: the panel does NOT turn off on lid close when it is the only monitor — VERIFIED from installed-version source

Mutter learns the lid state from **UPower**, not from logind's lid action, so the signal path is intact under `ignore` (mutter 50.2, `src/backends/meta-backend.c`, fetched from gitlab.gnome.org at tag `50.2` — exactly the installed version):

```c
 * - Querying UPower (over D-Bus) to know when the lid is closed   (line 40)
...
g_dbus_proxy_get_cached_property (proxy, "LidIsClosed");           (line 724)
```

On every lid change mutter regenerates the monitor config (`meta-monitor-manager.c:343-355`):

```c
void
meta_monitor_manager_lid_is_closed_changed (MetaMonitorManager *manager)
{
  meta_monitor_manager_ensure_configured (manager);
}
```

The config generator excludes a closed laptop panel **only as long as another monitor exists**. Three independent code paths in `meta-monitor-config-manager.c` (50.2) prove the only-monitor fallback:

1. **Config-key generation** (lines ~457-490) — builtin skipped when lid closed, then explicitly added back if nothing else remains:

```c
      if (meta_monitor_is_builtin (monitor))
        {
          laptop_monitor_spec = meta_monitor_get_spec (monitor);
          if (is_lid_closed (monitor_manager))
            continue;
        }
      ...
  if (!monitor_specs && laptop_monitor_spec)
    {
      monitor_specs =
        g_list_prepend (NULL, meta_monitor_spec_clone (laptop_monitor_spec));
    }
```

2. **Primary-monitor selection** (comment above `find_primary_monitor`, line ~631):

```c
 * If the laptop lid is closed, exclude the laptop panel from possible
 * alternatives, except if no other alternatives exist.
```

3. **The actual applied config**: `meta_monitor_config_manager_create_linear()` passes `MONITOR_MATCH_VISIBLE | MONITOR_MATCH_ALLOW_FALLBACK`. `MONITOR_MATCH_VISIBLE` rejects a closed builtin panel — but `MONITOR_MATCH_ALLOW_FALLBACK` re-selects it via `find_monitor_with_highest_preferred_resolution (…, MONITOR_MATCH_ALL)` when no visible monitor exists. Net result: lid closed + no externals ⇒ a one-monitor config with the **closed eDP panel active**.

(The "Refusing to activate a closed laptop panel" error in `meta-monitor-manager.c:2477` applies only to *externally requested* configs via the D-Bus `ApplyMonitorsConfig` API, e.g. Settings → Displays — not to mutter's own generated fallback config.)

**Conclusion (GNOME, undocked)**: after activation of `ignore`, lid close leaves the panel powered and compositing. What eventually turns it off is the ordinary idle path: `idle-delay = 300` → gsd-power `BLANK` mode → `backlight_disable()` → `set_power_saving_mode(GSD_POWER_SAVE_MODE_OFF)` (verified in gsd-power source; live mutter `PowerSaveMode` property confirmed present, currently `i 0` = on). Claude Code's `systemd-inhibit ... idle` blocks are **logind**-level and do not feed GNOME's idle monitor (mutter counts user input), so the 5-minute blank does still fire — verified live: `gdbus … org.gnome.SessionManager.IsInhibited 8` → `(false,)` and `IsInhibited 4` → `(false,)` despite 7 active claude-code logind inhibitors. So: **up to ~5 minutes of lit, rendering panel inside the closed lid** — plus the §4 edge case where it re-lights.

### §2 gsd-power's lid handling — GNOME's *designed* not-suspending-lid-close path exists but is currently unreachable

gnome-settings-daemon (`plugins/power/gsd-power-manager.c`, master) does listen to the lid independently (via UPower, `lid_state_changed_cb`). On close:

```c
static gboolean
suspend_on_lid_close (GsdPowerManager *manager)
{
        return !external_monitor_is_connected () || !manager->session_is_active;
}
...
static void
do_lid_closed_action (GsdPowerManager *manager)
{
        ...
        if (suspend_on_lid_close (manager)) {
                gboolean is_inhibited;
                idle_is_session_inhibited (manager, GSM_INHIBITOR_FLAG_SUSPEND, &is_inhibited);
                if (is_inhibited) {
                        g_debug ("Suspend is inhibited but lid is closed, locking the screen");
                        lock_screensaver (manager);
                }
        }
}
```

So GNOME *does* have a "lid closed but we're not suspending → lock the screen (which blanks it)" branch — but it fires only when a **gnome-session** (GSM) suspend inhibitor is registered. Claude Code's inhibitors are logind-level and invisible to GSM (verified live, table row 6). With plain `HandleLidSwitch=ignore` and no GSM inhibitor, gsd-power does nothing on lid close but play a sound.

Two more gsd-power facts used in §3/§5 (all from source):
- Screensaver-active blank: once the screensaver/lock is active, gsd installs a 30 s idle watch (`SCREENSAVER_TIMEOUT_BLANK = 30`, gsd-power-constants.h) → `backlight_disable()` → displays powered off via mutter `PowerSaveMode`.
- Idle-suspend gating: `idle_configure()` zeroes the sleep timeout when the action is GSM-suspend-inhibited (`is_action_inhibited`), and `action_suspend()` calls logind `Suspend(false)` — a non-interactive call that logind refuses while any `sleep` **block** inhibitor (e.g. Claude Code's) is held. This is the verified mechanism behind "the machine never idle-suspends while agents run".

### §3 The companion mechanism — options evaluated, one recommended

| Option | Mechanism | Screen off (undocked lid close) | Docked path | Side effects | Verdict |
|---|---|---|---|---|---|
| **L. `HandleLidSwitch=lock` + `HandleLidSwitchExternalPower=lock`** (change the two committed `ignore` values) | logind screen-locks all sessions on lid close (never suspends: "If 'lock', all running sessions will be screen-locked" — man logind.conf, systemd 260). GNOME lock → screensaver active → gsd blanks/powers off displays after 30 s (§2). niri session: swayidle's existing `lock → swaylock -f` handles the logind lock signal; panel-off is native anyway | ~30 s (GNOME); immediate panel-off in niri | **Untouched by two layers**: gsd-power's `handle-lid-switch` block inhibitor (present whenever an external monitor is attached — live-verified) makes logind take *no* action ("If a low-level inhibitor lock is taken … the Handle*= settings are irrelevant" — man page); independently, `Docked=true` (>1 display) routes to `HandleLidSwitchDocked` default `ignore` | Adds *lock-on-lid-close* (today lock comes only after 5 min idle). Arguably desirable for a laptop being bagged; zero new units; also covers the §4 undock-while-closed edge (~8 s + 30 s) | **RECOMMENDED** |
| A. Keep `ignore`; add a GNOME-session user unit running `gnome-session-inhibit --inhibit suspend --inhibit-only` | Makes gsd-power's native branch (§2) fire: lid close + no externals + GSM inhibitor → `lock_screensaver` → blank after 30 s | ~30 s | Untouched — gsd's own `external_monitor_is_connected()` check skips the lock when docked | Permanent GSM suspend inhibitor **also disables GNOME idle-suspend on battery** (`idle_configure` zeroes the sleep timeout) — silently removes the 15-min battery safety net; visible as an always-on inhibitor in the power panel; new unit to maintain | Workable, second choice |
| B. Keep `ignore`; custom user service watching UPower `LidIsClosed` over D-Bus → if no external `/sys/class/drm/*` connected → `gdbus … org.gnome.ScreenSaver.SetActive true` (or mutter `PowerSaveMode=3`) | Immediate-ish, fully controllable | seconds | Untouched (script checks for externals) | Custom code duplicating what gsd/logind already offer; must handle GNOME vs niri; most maintenance | Not recommended |
| C. Keep `ignore` alone, accept the idle blank | 5-min lit-panel window; §4 edge can re-light the panel later | ≤ ~5.5 min | Untouched | None | Acceptable only if the bag scenario is dismissed |
| D. `wlopm` / wlr-output-power-management | — | — | — | **Mutter does not implement the wlr-output-power-management protocol**; GNOME-session unusable. niri supports `niri msg output … off` but doesn't need it (native) | Inapplicable |
| E. Root-side udev/acpid SW_LID hook calling into the user session | — | — | fragile | Root→user D-Bus bridging (XDG_RUNTIME_DIR, bus address), duplicate of logind's own switch handling; unidiomatic on NixOS when option L is a 2-word diff | Rejected |

Why L over A: identical end state on GNOME (lock → 30 s → panel off), but L is a 2-value diff to the already-committed block, needs no new unit, works identically in both sessions, does **not** change battery idle-suspend semantics, and also mitigates the §4 edge case. The only behavioral addition is that lid close locks the session — which the 5-minute swaylock/GNOME idle lock already does today, just later.

Note on `HandleLidSwitchExternalPower` under systemd 260 (installed man page): it is "completely ignored by default (for backwards compatibility) — an explicit value must be set before it will be used", i.e. when unset the plain `HandleLidSwitch` action applies on AC too. The committed config already sets it explicitly; keep that, just with `lock`.

### §4 Docked/external-monitor path — genuinely unaffected (and one edge case)

Verified semantics (installed systemd 260 man page, quoted):

> "If the system is inserted in a docking station, or if more than one display is connected, the action specified by HandleLidSwitchDocked= occurs; if the system is on external power the action (if any) specified by HandleLidSwitchExternalPower= occurs; otherwise the HandleLidSwitch= action occurs." — `HandleLidSwitchDocked=` defaults to `ignore`.

Live confirmation on this machine right now: 2 external DPs connected → `Docked=true`, and gsd-power holds the `handle-lid-switch` block inhibitor — either one alone already prevents any logind lid action while docked, under the old config, the committed `ignore` config, and the recommended `lock` config alike. Window distribution across monitors is mutter's monitor-config logic (`MONITOR_MATCH_VISIBLE` excludes the closed panel when externals exist — §1 path, i.e. today's behavior) and is not touched by any logind Handle* value. **The docked case is byte-for-byte unchanged under both `ignore` and `lock`.**

**Edge case (undock while lid closed)**: gsd-power releases its `handle-lid-switch` inhibitor 8 s after the last external monitor is unplugged (`LID_CLOSE_SAFETY_TIMEOUT = 8`; source comment: "When unplugging the external monitor, give a certain amount of time before suspending the laptop"). Today that produces the familiar suspend-after-undock. After activation: mutter's fallback (§1) re-activates the eDP panel *inside the closed lid*. With `ignore`, it stays lit until the 5-min idle blank; with `lock`, logind's lid action fires on uninhibit/undock (inference, row 10) → lock → blank at 30 s. Another concrete reason to prefer `lock`.

### §5 Remaining paths that could still suspend or kill headless agents

Audited exhaustively; after activating the committed changes plus the §3 recommendation:

1. **Battery idle-suspend — the one live decision point.** `sleep-inactive-battery-type = 'suspend'`, `timeout 900` is deliberately retained by commit 6207dc3. On battery, lid shut, headless: gsd fires suspend after 15 idle minutes via logind `Suspend(false)`. While a Claude Code CLI session holds its `sleep` block inhibitor (7 held right now), logind refuses the call and agents survive; any agent **not** launched under the CLI wrapper (cron, nohup, detached jobs) is unprotected and dies at the 15-minute mark. **Trade-off flagged, not decided**: (a) keep it — battery protection, agents-on-battery rely on Claude inhibitors; or (b) also set `sleep-inactive-battery-type = "nothing"` — full "never sleep unless told", relying on the UPower critical-battery backstop. That backstop exists and is verified live: `/etc/UPower/UPower.conf` → `PercentageAction=2`, `CriticalPowerAction=HybridSleep` (machine hybrid-sleeps at 2 % rather than dying mid-write).
2. **GNOME AC idle-suspend** — eliminated by commit 6207dc3 (`sleep-inactive-ac-type = "nothing"`), pending activation.
3. **gsd-power lid handling** — never suspends by itself on lid close (§2: it only locks or inhibits); its `logind Suspend` calls occur solely on the idle path (item 1) and critical battery.
4. **niri session swayidle** — the `timeout 600 systemctl suspend` was removed in commit 184db8e; live `config.kdl:271` now has only `timeout 300 swaylock -f`, `before-sleep`, and `lock` handlers (verified). No idle suspend remains in the niri session.
5. **logind `IdleAction`** — unset in the effective config → default `ignore` (no logind-side idle suspend).
6. **UPower critical battery** — `HybridSleep` at 2 % (see item 1); this is desired data-loss protection, keep.
7. **Thermal/ACPI** — no thermald/auto-suspend-on-thermal path exists on this host; kernel thermal shutdown is an emergency mechanism, out of scope.
8. **`HoldoffTimeoutSec`** (30 s default): for completeness — after boot/resume logind ignores lid events for 30 s; irrelevant once the action is `ignore`/`lock`.

### §6 niri session — verified native behavior

Upstream niri wiki (Configuration: Switch Events), exact quote:

> "These events correspond to closing and opening of the laptop lid. Note that niri will already automatically turn the internal laptop monitor on and off in accordance with the laptop lid."

Installed niri is 26.04; `config.kdl` defines no `switch-events` block, so pure default behavior applies: lid close → internal monitor off (immediately, compositor-level), externals unaffected. Occasional upstream bugs exist (e.g. niri-wm/niri#2927, filed against 25.08 on Intel hardware, and the #2438/#2504 family about monitor state after lid cycles — worth a one-time functional check in the niri session, nothing more). With `HandleLidSwitch=lock`, swaylock additionally engages via swayidle's existing `lock` handler. No niri-specific work is required for this task.

---

## Decisions

- **Round-1 claim correction recorded**: "mutter/niri disable eDP on lid close" is true for niri, and true for mutter *only when another monitor is connected*. The undocked GNOME case — the entire point of the task — behaves the opposite way (panel stays active), per installed-version source.
- **Recommendation**: flip the two committed values to `"lock"` (option L). This is a revision to the already-committed-but-unactivated `power.nix` block, not a new mechanism; docs commit 4913e63 will need a matching wording touch-up ("locks and blanks" instead of "blanks").
- **Left open for the user (do not decide unilaterally)**: battery 15-minute idle-suspend (§5 item 1) — keep (battery protection; CLI-launched agents are already protected by Claude inhibitors) vs also `nothing` (uniform never-sleep; UPower 2 % HybridSleep remains as backstop).

## Risks & Mitigations

- **If plain `ignore` is activated as committed**: undocked lid close leaves the panel lit up to ~5 min, and the undock-while-closed edge (§4) re-lights it inside a bag. Mitigation: adopt option L (or A) before/with activation.
- **`lock` adds immediate session lock on lid close**: behavior addition vs today (lock currently comes via the 5-min idle path). If the user objects, fall back to option A (GNOME-only, new unit, battery-idle-suspend side effect) or C (accept the window).
- **logind restart semantics on activation** (carried over from round 1): verify the new value is live post-switch via `busctl` (step 2 below) rather than assuming the rebuild restarted logind.
- **niri lid bugs**: low-probability upstream regressions (#2927 class); one functional check in the niri session suffices.

## What the user must do to activate and test safely

1. (Optional but recommended first) Apply option L: in `modules/system/power.nix`, change both `"ignore"` values to `"lock"`. Then: `sudo nixos-rebuild switch --flake .#hamsa`.
2. Confirm the config is live (no lid needed):
   `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → must show `"lock"` (or `"ignore"` if activated as-committed). If it still shows `"suspend"`, run `sudo systemctl restart systemd-logind` (or reboot) and re-check.
3. **Safe lid test — dock first**: with external monitors attached (today's docked behavior is the known-safe path in every configuration), close the lid → windows stay on externals, no suspend, exactly as today.
4. **Undocked test — protect the agents anyway**: before the first undocked lid close, either be OK with the 30 s lock-then-blank (option L), or run a canary instead of live agents: `( while true; do date >> /tmp/lid-test.log; sleep 5; done ) &`, unplug all monitors, close the lid for 2-3 minutes, reopen, and check the log for a gap. `journalctl -b -u systemd-logind | grep -i lid` should show "Lid closed." with **no** "Suspending..." entry.
5. Verify panel power-off (option L): after closing the lid undocked, the lock engages immediately and the panel powers off within ~30 s (feel the hinge area stays cool / observe no glow at the lid seam), rather than after 5 minutes.
6. **Do NOT close the lid before step 1-2 are done**: the live system still suspends on lid close, and the `claude-code` sleep inhibitors do not protect against the lid action (`LidSwitchIgnoreInhibited=yes` default).

## Appendix — evidence log

**Live commands (all read-only, PRE-activation)**
- `systemd-analyze cat-config systemd/logind.conf` → `[Login] KillUserProcesses=false` only.
- `busctl get-property org.freedesktop.login1 … LidClosed` → `b false`; `… Docked` → `b true`.
- `systemd-inhibit --list` → gsd-power `handle-lid-switch` **block** ("External monitor attached or configuration changed recently"); gsd-media-keys `handle-power-key:handle-suspend-key:handle-hibernate-key` block; 7× `claude-code … sleep:idle … block`.
- `/proc/bus/input/devices` → `Name="Lid Switch"` (PNP0C0D, event1); `upower -d` → `lid-is-present: yes`; `/proc/acpi/button/lid/*/state` → `open`.
- `/sys/class/drm/*/status` → eDP-1 + DP-10 + DP-11 connected.
- `gdbus call --session --dest org.gnome.SessionManager … IsInhibited 4` → `(false,)`; `IsInhibited 8` → `(false,)` (logind inhibitors invisible to GSM).
- `busctl --user get-property org.gnome.Mutter.DisplayConfig … PowerSaveMode` → `i 0`.
- `gsettings`: `idle-delay uint32 300`; `sleep-inactive-ac-type 'suspend'` (live ≠ repo — pre-activation); `org.gnome.desktop.screensaver lock-enabled true`.
- `cat /etc/UPower/UPower.conf` → `PercentageAction=2`, `CriticalPowerAction=HybridSleep`.
- `systemctl --version` → systemd 260 (260.2); `niri --version` → 26.04; DMI → Framework Laptop 13 (AMD Ryzen AI 300).
- `grep -n idle config/config.kdl` → line 271: swayidle with `timeout 300 swaylock -f`, `before-sleep`, `lock` only (no suspend).

**Upstream sources**
- mutter 50.2 (installed version): https://gitlab.gnome.org/GNOME/mutter/-/blob/50.2/src/backends/meta-monitor-config-manager.c (only-monitor fallback, `MONITOR_MATCH_VISIBLE`/`ALLOW_FALLBACK`), https://gitlab.gnome.org/GNOME/mutter/-/blob/50.2/src/backends/meta-backend.c (UPower `LidIsClosed` tracking), https://gitlab.gnome.org/GNOME/mutter/-/blob/50.2/src/backends/meta-monitor-manager.c (`lid_is_closed_changed` → `ensure_configured`).
- gnome-settings-daemon master: https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/blob/master/plugins/power/gsd-power-manager.c (`do_lid_closed_action`, `suspend_on_lid_close`, `idle_configure`, `action_suspend`, `backlight_disable`), https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/blob/master/plugins/power/gsd-power-constants.h (`SCREENSAVER_TIMEOUT_BLANK 30`, `LID_CLOSE_SAFETY_TIMEOUT 8`).
- systemd 260 `man logind.conf` (installed, quoted verbatim in §4 and table rows 3/8): Handle* semantics, docked definition, `LidSwitchIgnoreInhibited=yes` default, low-level inhibitor precedence, `HoldoffTimeoutSec`.
- niri: https://github.com/niri-wm/niri/wiki/Configuration:-Switch-Events (automatic internal-monitor lid behavior, quoted in §6); https://github.com/niri-wm/niri/issues/2927, https://github.com/niri-wm/niri/issues/145 (feature/bug history).
- Community context: https://bbs.archlinux.org/viewtopic.php?id=289770, https://discussion.fedoraproject.org/t/turn-off-external-monitor-when-lid-is-closed/172318 (GNOME lid/output-reconfiguration reports; secondary to source evidence above).

**Search queries used**: mutter lid close internal display HandleLidSwitch=ignore; niri lid close built-in monitor automatic; Framework GNOME lid closed screen stays on; plus direct source fetches (gitlab.gnome.org raw at tag 50.2, gsd master). MCP-NixOS not needed this round (no package/option lookups; nixpkgs option form was verified in round 1 via `nix eval`).
