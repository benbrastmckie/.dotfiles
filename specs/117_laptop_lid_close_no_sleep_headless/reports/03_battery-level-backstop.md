# Research Report: Task #117 (Round 3) — Battery-level backstop & inhibitor semantics

**Task**: 117 - laptop_lid_close_no_sleep_headless
**Started**: 2026-07-14T13:49:55-07:00
**Completed**: 2026-07-14T14:20:00-07:00
**Effort**: ~2 h (live forensics + installed-version source verification)
**Dependencies**: Builds on reports/01 (logind lid config) and reports/02 (lock recommendation); re-litigates neither
**Sources/Inputs**: UPower 1.91.1 source (installed version), systemd v260 source (installed version), gsd 50.2 source, mutter 50.2 source, polkit source, live read-only probes of hamsa, `nix eval` against the pinned flake (nixpkgs `cf3ffa5d`, nixos-26.05), Framework Community forum, `~/.claude/settings.json` hook forensics
**Artifacts**: specs/117_laptop_lid_close_no_sleep_headless/reports/03_battery-level-backstop.md (this report)
**Standards**: report-format.md, subagent-return.md

---

## 1. HEADLINE VERDICT (Q1): the existing 2% UPower backstop is an ILLUSION while agents are active

**While Claude Code's `sleep:idle` block inhibitors are held, UPower's critical-battery action (HybridSleep at 2%) is DENIED by systemd-logind, is never retried, and has no fallback. The battery drains past 2% to zero → hard power loss.** This is exactly the only-outcome-worse-than-status-quo scenario the round was asked to rule in or out. It is **ruled in**, verified end-to-end from the installed versions' sources, and **corroborated by live journal evidence of the identical denial already happening on this machine** (for gsd's idle-suspend, which takes the same logind path):

```
Jul 11..13 hamsa gsd-power[2764]: Error calling suspend action:
  GDBus.Error:org.freedesktop.login1.BlockedByInhibitorLock:
  Operation denied due to active block inhibitor        (7 occurrences this boot)
```

The full verified chain (every step cited in §Verified-Facts below):

1. upowerd (runs as **root**, live-verified) reacts to the warning-level transition to ACTION (2%) **exactly once**: `up_daemon_set_warning_level()` returns early if the level is unchanged, and the 20-second one-shot `take_action_timeout_cb` fires `up_backend_take_action()` a single time. No retry as the battery keeps draining. (UPower 1.91.1 `src/up-daemon.c`)
2. `up_backend_get_critical_action()` asks logind `CanHybridSleep`. Because upowerd is uid 0 and logind's `bus_test_polkit()` short-circuits for callers with the same UID as logind (`sd_bus_query_sender_privilege(call, -1)` → "Sender has same UID as us, then let's grant access"), the answer to **root** is `"yes"` even while block inhibitors are held. (My uid-1000 probe returned `"inhibited"`; the root answer differs — this is caller-dependent.) So UPower selects HybridSleep, not the PowerOff fallback. (systemd v260 `logind-dbus.c` `method_can_shutdown_or_sleep` + `bus-polkit.c` + `bus-convenience.c`; UPower `src/linux/up-backend.c`)
3. UPower then calls the **legacy** `HybridSleep(false)` method — fire-and-forget, `NULL` result callback, no error handling. (`up-backend.c`: `g_dbus_proxy_call(..., "HybridSleep", g_variant_new("(b)", FALSE), ..., NULL, NULL, NULL)`)
4. logind v260 maps the legacy boolean to `flags = interactive ? SD_LOGIND_INTERACTIVE : 0` — the legacy method **cannot** carry `SD_LOGIND_SKIP_INHIBITORS`. (`logind-dbus.c` `method_do_shutdown_or_sleep`)
5. `verify_shutdown_creds()` then rejects **outright**, before any polkit consultation, because Claude's inhibitors are strong (`--mode=block`, not `block-weak`):
   ```c
   /* With a strong inhibitor, if the skip flag is not set, reject outright. */
   if (!FLAGS_SET(flags, SD_LOGIND_SKIP_INHIBITORS) &&
       (offending->mode != INHIBIT_BLOCK_WEAK || ...))
           return sd_bus_error_set(error, BUS_ERROR_BLOCKED_BY_INHIBITOR_LOCK,
                                   "Operation denied due to active block inhibitor");
   ```
   **Root gets no exemption on this path in systemd 260.** The uid-0 bypass I hypothesized going in does not exist here — being root helps at the polkit layer, but the strong-blocker rejection happens before polkit.
6. UPower discards the error (step 3), the ACTION level never re-transitions, nothing else fires. gsd 50.2's ACTION handler (`engine_charge_action`) is **notification-and-sound only** — the action itself belongs to upowerd. Nothing remains between 2% and 0%.

**Secondary illusion (Q5 preview)**: even with zero inhibitors, HybridSleep's hibernate leg is unreliable on this machine (16 GiB disk swapfile vs 30 GiB RAM routinely ~28 GiB used — §5). The 2% backstop is therefore doubly not-load-bearing today.

---

## 2. Per-requirement verdicts

| Req | As stated | Verdict | Basis |
|-----|-----------|---------|-------|
| (A) Lid close on battery never sleeps | "closing the lid doesn't sleep the computer even on battery" | **YES — solved, no regression** (activation still pending) | `modules/system/power.nix` has `HandleLidSwitch = "lock"` / `HandleLidSwitchExternalPower = "lock"` committed; live logind still reads `"suspend"` (pre-activation, re-verified this session). `lock` never suspends; nothing added by this round touches it. |
| (B) Sleep after ~1 h with no agent activity (battery) | "it will sleep if left for an hour without activity from agents" | **NO as stated — achievable only approximately** | Two independent blockers, both verified: (i) the inhibitors are held by **SessionStart→SessionEnd hooks in the user's own settings.json** — held while a session is merely OPEN at the prompt, not while "agents are active"; an idle-but-open Claude terminal blocks suspend forever. (ii) Even with activity-scoped inhibitors, gsd's `sleep-inactive-battery-timeout` fires **once** per idle period at the 60-min-after-last-input mark; if a turn is in flight at that instant, logind denies it and gsd never retries (only sparse events re-arm it). GNOME's idle clock measures USER INPUT, not agent activity, in all cases. See §3. |
| (C) Agents active on battery, lid closed → sleep only at low battery | "only sleep when it drops to some small amount of battery... 2%... or closer to 10%" | **YES — but not with any existing mechanism**; requires one new root timer unit | UPower's action is blocked (§1) and no `services.upower.*` setting can fix that (the denial is at the D-Bus call itself). A root systemd timer calling `systemctl suspend -i` at the threshold works: `-i` maps to `SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS)` (verified in v260 `systemctl-logind.c`), which skips the strong-blocker rejection, and the remaining polkit `suspend-ignore-inhibit` check passes because polkitd implicitly authorizes uid 0 ("special case: uid 0, root, is _always_ authorized for anything" — polkit source). Timer polling retries every tick, so it cannot be raced. Recommended threshold: **10%**, not 2% (§4). |

---

## 3. Requirement (B) in full: what "an hour without agent activity" can and cannot mean

### 3.1 The inhibitors are the user's own hooks — session-lifetime, not activity-scoped (VERIFIED)

`~/.claude/settings.json` (deployed from **this repo**: `config/claude/settings.json`, via the activation-script copy in `modules/home/core/dotfiles.nix:39-41`; repo and deployed hook blocks verified byte-identical):

```json
"SessionStart": [{ "hooks": [{ "type": "command", "async": true,
  "command": "SESSION_ID=$(jq -r '.session_id // \"default\"'); systemd-inhibit --what=sleep:idle --who=claude-code --why=\"Claude Code session\" --mode=block sleep infinity & echo $! > /tmp/claude-inhibitor-${SESSION_ID}.pid" }]}],
"SessionEnd":   [{ "hooks": [{ "type": "command", "async": true,
  "command": "SESSION_ID=$(...); PID_FILE=/tmp/claude-inhibitor-${SESSION_ID}.pid; [ -f \"$PID_FILE\" ] && kill \"$(cat \"$PID_FILE\")\" ...; rm -f \"$PID_FILE\"" }]}]
```

Consequences, all live-verified this session:

- The inhibitor is held from **SessionStart to SessionEnd** — i.e., while a Claude session is open, *including while it sits idle at a prompt*. "No activity from agents" therefore does NOT release the block; only ending the session does. 8 live inhibitors ↔ 8 live `claude` processes; each inhibitor's environment carries the matching `CLAUDE_CODE_SESSION_ID`.
- Mid-session-looking acquisitions (a 6-hour-old `claude` process whose only inhibitor was 20 min old) are explained by session cycling (`/clear`, compaction, forked child sessions — every live inhibitor env has `CLAUDE_CODE_CHILD_SESSION=1`, `CLAUDE_CODE_FORK_SUBAGENT=1`), **not** by idle-release. My initial inference of activity-scoping from process ages was wrong; the hook config is ground truth.
- **Orphan hazard (new finding)**: the `systemd-inhibit ... sleep infinity` processes are reparented to `systemd --user` (live: all 8 have PPID 2380 = `systemd --user`), so they do NOT die with the Claude process. If SessionEnd never fires (SIGKILL, crash, OOM — note earlyoom `--prefer ... claude` on this host), the block inhibitor survives **until reboot**, permanently preventing all sleep. 23 pid files exist in /tmp; several point at dead PIDs (SessionEnd missed or pid file leaked). No orphaned *inhibitor* exists right now, but the design permits it.

### 3.2 Even with better hooks, gsd's battery idle-suspend is one-shot (VERIFIED from gsd 50.2 source + live journal)

- gsd installs the sleep watch on mutter's idle monitor for `sleep-inactive-battery-timeout` seconds of **user-input** idleness (`idle_configure()`, gsd 50.2). Claude's logind inhibitors are invisible to this clock (only GSM inhibitors zero the timeout, via `is_action_inhibited()`).
- When the watch fires, `action_suspend()` calls logind `Suspend(false)` — legacy method, no SKIP flag → denied under any strong block inhibitor, error merely logged (`dbus_call_log_error`). **Seven such denials are in this boot's journal** (§1) — this is the user's lived "never sleeps" experience, mechanized.
- After a denial there is **no retry** within the same idle period. `idle_configure()` re-arms watches only on sparse events: battery `low` threshold crossing (PercentageLow=20), AC↔battery change, screensaver ActiveChanged, GSM inhibitor change, settings change, power-profile change. (When re-armed while already past the timeout, the watch does fire immediately — mutter 50.2 idle-monitor doc: "takes into account the idle time from before the watch was added".)

### 3.3 Verdict and closest approximation

**(B) as stated is unachievable**: "activity from agents" is not a signal any current layer sees. The two available proxies are (a) *a Claude session is open* (current hooks — too broad: an idle open terminal blocks sleep forever) and (b) *a turn/tool-run is in flight* (turn-scoped hooks — close to the user's intent).

Closest achievable approximation (recommended, two small changes + the §6 backstop as safety net):

1. **Make the inhibitor turn-scoped**: in `config/claude/settings.json`, move acquisition from `SessionStart` to `UserPromptSubmit` and release on `Stop` (keep a `SessionEnd` release as belt-and-suspenders). Then "no open turn for an hour" ≈ "no agent activity for an hour", which is what the user means. Cost: a background task launched with `run_in_background` keeps running after its turn's `Stop` fires, unprotected (rare here; the 10% backstop and, on AC, `sleep-inactive-ac-type = "nothing"` limit the damage — on battery, an idle-input hour with only a background job running would suspend it. Flag to the user).
   - While editing: fix the orphan hazard by replacing `sleep infinity` with a waiter tied to the Claude process (e.g. `tail --pid=$PPID -f /dev/null`), so an unkilled inhibitor dies with the process. (Verify at implementation time that `$PPID` inside the hook shell is the `claude` process on this system.)
2. **`sleep-inactive-battery-timeout = 900 → 3600`** and set **`sleep-inactive-battery-type = "suspend"` explicitly** in `modules/home/desktop/gnome.nix` (§7).

Residual gap, stated plainly: if a turn is in flight at the single 60-minute firing instant, the suspend is denied and the machine stays awake until the ~20% battery-low crossing re-arms the watch (one more attempt), then until the 10% backstop. Guaranteed behavior is therefore: *sleeps at 60 idle minutes when agents are quiet at that moment; otherwise sleeps at ≈20% (if quiet then) or 10% (unconditionally)*. A fully-faithful "(B) with retries" would need a custom poller watching for inhibitor absence — possible (the §6 service could be extended: on battery + lid closed + no `claude-code` inhibitor for 60 consecutive polls → plain `systemctl suspend` *without* `-i`), but it duplicates GNOME logic and adds a second idle-policy owner; offered as an option, not recommended for the first iteration.

---

## 4. Threshold: 10%, not 2% (Q4)

Verified inputs:

- Battery: 61.0 Wh full (live: `energy-full: 61.0996 Wh`, BAT1, design 60.6 Wh, cycle-count healthy at ~100.6% capacity).
- Sleep state: **s2idle only** — `/sys/power/mem_sleep` → `[s2idle]`. There is no deep-S3 option on this platform; suspend keeps draining.
- Framework 13 AMD s2idle drain, community-reported: commonly **~2.5-5%/h** (20-40% overnight), ~1%/h in well-tuned setups, with full-overnight-discharge reports on 7040-series ([community.frame.work/t/42395](https://community.frame.work/t/battery-drain-on-suspend-sleep-with-linux/42395), [/t/77826](https://community.frame.work/t/amd-framework-13-unreasonable-battery-loss-when-suspended/77826), [/t/60690](https://community.frame.work/t/excessive-battery-drain-on-framework-13-with-ryzen-5-7040/60690)). `power.nix` already notes the BIOS ≥3.05 standby-drain fix; treat ~1.5-3%/h as the planning range for this Ryzen AI 300 machine (INFERENCE from the 7040-class reports; no measured figure for this exact board).
- At **2%** (≈1.2 Wh): under an hour of s2idle headroom — a lid-closed laptop in a bag is near-certain to hit hard power-off before it is next opened; there is also no margin for the suspend transition itself under agent load (15-30 W draw ⇒ 1.2 Wh ≈ 2-5 min).
- At **10%** (≈6 Wh): roughly 2-6 h of s2idle survival — enough to get to a charger the same day. Cost to the user: agents stop ~8 percentage points earlier, ≈10-25 min of runtime under heavy agent load. Li-ion longevity also mildly favors not cycling to 2%.

**Recommendation: 10%.** The existing 2% default is inadequate independent of the Q1 blocking problem: it assumes the action succeeds instantly and that HybridSleep's zero-drain hibernate leg is real — on this machine it is not (§5). Keep UPower's 2%/HybridSleep as an untouched final layer (it becomes moot behind a working 10% backstop and still fires in the no-inhibitor case), but do not rely on it.

---

## 5. Hibernate viability (Q5): NOT dependable — recommend suspend

Verified:

- Swap: real disk swapfile `/var/lib/swapfile` 16 GiB (priority -1) + `zram0` 15.3 GiB (priority 5, **full** at probe time). systemd excludes zram as a hibernation target; only the 16 GiB file counts.
- RAM: 30 Gi total, **28 Gi in use** + 16 Gi swap used at probe time (heavy, and typical for this host's agent workload — earlyoom exists for a reason).
- `power.nix` line 124 itself documents: "For hibernation support, swap must be >= RAM size (32GB+)" — the swapfile is half that.
- Resume plumbing: `boot.resumeDevice = ""`, no `resume=` on the kernel cmdline, **but** `boot.initrd.systemd.enable = true` and the pinned nixpkgs (`cf3ffa5d`, nixos-26.05) ships `systemd-hibernate-resume` + `systemd-hibernate-resume-generator` in the systemd initrd (`nixos/modules/system/boot/systemd/initrd.nix:102,609,625`); systemd 260 records the hibernation location in the `HibernateLocation` EFI variable at entry (v260 error strings in `method_do_shutdown_or_sleep` confirm EFI-without-`resume=` is a supported configuration). So resume is *mechanically* possible (VERIFIED at the plumbing level, never functionally tested on this machine).
- logind currently deems hibernate/hybrid-sleep resource-feasible — my `CanHibernate`/`CanHybridSleep` probes returned `"inhibited"`, and per v260 source that string is only reachable AFTER `sleep_supported_full()` passed (otherwise "na"/"no").

The problem is entry under real memory pressure (INFERENCE, clearly flagged): the hibernation image must fit in the ~15 GiB free swapfile while the kernel simultaneously needs somewhere to shove ~28 GiB of anonymous memory (zram contents are RAM and get imaged too). logind's feasibility heuristic is coarse; actual image allocation can fail at entry time under this host's routine load, in which case HybridSleep fails entirely and the machine stays awake (and, per §1, nobody retries). **Verdict: do not build the backstop on hibernate or HybridSleep. Use suspend.** If the user later wants a true zero-drain endpoint: grow the swapfile to ≥ RAM (per power.nix's own note), functionally test `systemctl hibernate` twice, and only then consider `suspend-then-hibernate`.

---

## 6. Recommended design (Q3): a root timer backstop that inhibitors cannot block

Mechanism comparison (researched per the prompt):

| Mechanism | Fires under strong block inhibitors? | Retries? | Verdict |
|---|---|---|---|
| UPower `PercentageAction`/`CriticalPowerAction` (incl. all `services.upower.*` values) | **No** for every sleep verb (legacy call, outright reject §1). `PowerOff` would fire (shutdown isn't sleep-inhibited) but is not what the user wants | No (one-shot on level transition) | Leave at defaults; not load-bearing |
| udev rule on `power_supply` uevents | Would call the same bypass command, so yes | Only when events arrive — capacity-change uevent cadence is driver-dependent and known-coarse; ACAD (AC adapter) events exist on this host (power.nix already uses them) but BAT1 percentage-step events are unverified here | Rejected: nondeterministic trigger |
| **Root systemd timer polling sysfs → `systemctl suspend -i`** | **Yes** — verified end-to-end: `-i` ⇒ `SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS)` (v260 `systemctl-logind.c:95`) ⇒ skips the strong-blocker rejection ⇒ polkit `org.freedesktop.login1.suspend-ignore-inhibit` with `POLKIT_ALWAYS_QUERY` ⇒ polkitd implicitly authorizes uid 0 (polkit source, `check_authorization_sync`) | Every tick | **RECOMMENDED** |

Concrete spec (goes in `modules/system/power.nix`, matching its charter; values as named constants for the plan phase):

```nix
  # ==========================================================================
  # Battery Suspend Backstop - fires REGARDLESS of sleep inhibitors
  # ==========================================================================
  # Claude Code sessions hold logind block inhibitors (sleep:idle). On systemd
  # 260 a strong block inhibitor makes logind reject ALL ordinary sleep
  # requests outright - including UPower's own 2% CriticalPowerAction (verified
  # from source; see specs/117.../reports/03_battery-level-backstop.md). Without
  # this unit, a lid-closed laptop with active agents drains to 0% and dies.
  # `systemctl suspend -i` = SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS),
  # which root is polkit-authorized to use; the timer retries every minute so
  # it cannot be raced by a freshly acquired inhibitor.
  systemd.services.battery-suspend-backstop = {
    description = "Suspend at <=10% battery, bypassing sleep inhibitors";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "battery-suspend-backstop" ''
        for bat in /sys/class/power_supply/BAT*; do
          [ -e "$bat/capacity" ] || continue
          status=$(cat "$bat/status")
          cap=$(cat "$bat/capacity")
          if [ "$status" = "Discharging" ] && [ "$cap" -le 10 ]; then
            echo "battery at ''${cap}%% and discharging: suspending (inhibitors bypassed)"
            exec ${pkgs.systemd}/bin/systemctl suspend -i
          fi
        done
      '';
    };
  };
  systemd.timers.battery-suspend-backstop = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "60s";
    };
  };
```

Design notes (each traceable to a probe):

- **Glob `BAT*` only, never `power_supply/*`**: this host exposes a peripheral battery `hid-...-battery-144` that reports `Discharging 100` perpetually, and `ucsi-source-psy-*` USB entries; a naive glob would false-trigger. The internal battery is `BAT1`; `BAT*` is Framework-portable and inert on desktops (`garuda`).
- `status = "Discharging"` gates out AC ("Not charging"/"Charging" at dock, live-verified strings).
- Re-suspend-until-plugged-in is intentional: on wake at ≤10% still discharging, the next tick suspends again (~≤60 s of grace). Escape hatch: plug in, or `systemctl stop battery-suspend-backstop.timer` for a deliberate low-battery session.
- Suspend (s2idle) is used, not hibernate/HybridSleep, per §5.
- No change to `services.upower.*` (defaults verified on the pinned flake: `percentageLow=20, percentageCritical=5, percentageAction=2, criticalPowerAction="HybridSleep", usePercentageForPolicy=true` — exactly the live `/etc/UPower/UPower.conf`). The option names exist under those exact names on nixos-26.05 (nix eval verified), should the plan phase want them anyway.

Plus the (B) approximation from §3.3: turn-scoped hooks in `config/claude/settings.json`, and `gnome.nix` battery timeout 900→3600 with explicit `sleep-inactive-battery-type = "suspend"`.

## 7. Q6 — `sleep-inactive-battery-timeout = 900 → 3600`: sound, with the explicit type

- Verified from gsd 50.2 `idle_configure()`: the battery sleep watch is installed whenever the session is active and the action is not GSM-inhibited — screensaver/lock state does not remove it, and Claude's logind-level inhibitors do not zero it (they surface only as the logind denial at fire time). So the setting is exactly as "inert while inhibitors are held / live when they aren't" as established — with the §3.2 one-shot caveat.
- Set **`sleep-inactive-battery-type = "suspend"` explicitly**. It currently rides on the schema default (`'suspend'`, live-verified round 1); after this task deliberately set the AC type to `"nothing"`, leaving the battery type implicit invites drift and ambiguity. Explicit is also self-documenting next to the 3600.

## 8. Q7 — interaction with `HandleLidSwitch=lock`

Verified from source (gsd 50.2 + mutter 50.2), stated with the §3.2 caveat:

- Locking does **not** deactivate the seat session; `manager->session_is_active` stays true, so `idle_configure()` keeps the sleep watch with the lid closed and the screen locked.
- The lock itself *helps*: screensaver `ActiveChanged` triggers an `idle_configure()` re-arm, and mutter's idle clock counts from last input regardless of lock or panel power. With the lid shut there is no input, so the 3600-second watch fires on schedule.
- The §6 backstop reads sysfs and runs as root — completely independent of session, lock, lid, and compositor state. It fires with the lid shut.
- One INFERENCE flagged: "no input while lid closed" assumes no external keyboard/mouse events while bagged (dock scenario is out of scope — on dock the machine is on AC and `Discharging` gates the backstop off).

## 9. Trade-offs and what could go wrong

1. **`systemctl suspend -i` is a deliberate inhibitor bypass** — it will freeze mid-flight agent turns at ≤10%. That is requirement (C) by design, but note API-call-in-progress state is lost until wake.
2. **s2idle keeps draining after the backstop fires** (~1.5-3%/h): a bagged laptop suspended at 10% still dies in ~2-6 h unplugged. Only a working hibernate ends that (§5 upgrade path). Document; don't promise zero-drain.
3. **Turn-scoped hooks weaken protection for `run_in_background` jobs** (§3.3) and for non-Claude long jobs (builds) — on battery those can now be suspended at the 60-min input-idle mark. The Neovim `<leader>rz` manual inhibitor (docs/gnome-settings.md) remains the tool for those.
4. **Hook edits live in `config/claude/settings.json`** and deploy via the activation-script copy — Claude Code also writes runtime changes to the deployed file (dotfiles.nix note), so verify the copy semantics before/after editing (drift between repo and `~/.claude/settings.json` is possible by design).
5. **The one-shot gsd timer race remains** (§3.3 residual gap) — accepted; the 20% retry and 10% backstop bound it. If the user finds the machine routinely awake at 20-11%, revisit the optional poller-based idle-suspend extension.
6. **Peripheral-battery false trigger** if the glob is ever widened past `BAT*` (§6). Keep the glob.
7. **Orphaned inhibitors** under the current hooks can outlive all Claude processes until reboot (§3.1) — worth fixing even if nothing else in this report is adopted; until then, any "won't sleep" debugging should start with `systemd-inhibit --list`.
8. **Version coupling**: the strong-blocker outright-reject and `-i` flag semantics are systemd v257+ behavior verified at v260, and the UPower analysis is 1.91.1-exact. A future systemd/UPower bump could change either direction (e.g. UPower gaining `WithFlags` calls); the backstop keeps working in all plausible variants since `-i` degrades gracefully (systemctl retries without the flag bit on InvalidArgs, v260 `systemctl-logind.c:108-111`).

## 10. What the user must do to activate/test

1. **Activate the already-committed lid config first** (unchanged from report 02): `sudo nixos-rebuild switch --flake .#hamsa`, then verify `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → `"lock"` (restart `systemd-logind` if it still says `"suspend"`; it did as of this session).
2. After the plan/implementation phase adds the §6 timer: verify with `systemctl list-timers battery-suspend-backstop*` and a dry read of the journal (`journalctl -u battery-suspend-backstop -f`) — at >10% each tick exits silently.
3. **Safe backstop test without draining to 10%**: temporarily lower nothing; instead run the bypass once by hand while agents are active: `sudo systemctl suspend -i` — the machine must suspend despite `systemd-inhibit --list` showing claude-code blocks (this validates the §1/§6 chain live; plain `sudo systemctl suspend` should conversely be REFUSED — a nice A/B proof).
4. Test (B) approximation after the hook change: open a Claude session, let the turn finish, confirm `systemd-inhibit --list` shows no claude-code entry while idle at the prompt; on battery, the 60-min input-idle suspend should then fire (journal: no `BlockedByInhibitorLock` error).
5. Watch for the journal line `battery at N% and discharging: suspending` the first time a real low-battery session happens; confirm wake-and-re-suspend behavior is acceptable.

---

## VERIFIED FACT vs INFERENCE ledger

**VERIFIED (live probe)**: upowerd runs as root (PID 2052); UPower 1.91.1; `/etc/UPower/UPower.conf` = 20/5/2/HybridSleep; `Can{Suspend,Hibernate,HybridSleep,SuspendThenHibernate}` all `"inhibited"` for uid 1000; `[s2idle]` only; swapfile 16G + zram 15.3G, RAM 30Gi/28Gi used; no `resume=` on cmdline; 8 claude-code `sleep:idle` block inhibitors, all parented to `systemd --user`, env-tagged with session IDs; hooks in `~/.claude/settings.json` = SessionStart/SessionEnd, byte-identical to repo `config/claude/settings.json`; 23 pid files incl. stale; **7× `BlockedByInhibitorLock` gsd-power denials in this boot's journal**; live `HandleLidSwitch` still `"suspend"` (pre-activation); battery 61.0 Wh; peripheral `hid-*-battery` reports perpetual `Discharging 100`.

**VERIFIED (installed-version source)**: UPower 1.91.1 `check_action_result` accepts only `"yes"`; action chain Suspend→HybridSleep→Hibernate→PowerOff with `AllowRiskyCriticalPowerAction` guard; legacy `(b) FALSE` fire-and-forget call; one-shot ACTION handling with 20 s delay (up-daemon.c). systemd v260: legacy-method flag mapping; strong-block outright reject in `verify_shutdown_creds`; caller-dependent `Can*` results incl. the `"inhibited"` string construction; `bus_test_polkit` same-UID short-circuit (`sd_bus_query_sender_privilege`); `systemctl -i` ⇒ `SD_LOGIND_SKIP_INHIBITORS` (systemctl-logind.c:94-95); `manager_is_inhibited` weak/strong handling. gsd 50.2: `idle_configure` watch logic incl. screensaver/session-active gating; `action_suspend` legacy call + log-only error; ACTION-level = notification only; `idle_configure` re-arm event list; no `SetIdleHint` anywhere (also kills the logind `IdleAction` alternative, which was additionally rejected for being AC/battery-blind). polkit: uid-0 implicit authorization (`polkitbackendinteractiveauthority.c`). nixpkgs `cf3ffa5d`: `services.upower.*` option names/defaults (nix eval), `boot.initrd.systemd.enable=true` (nix eval), initrd ships hibernate-resume generator (initrd.nix:102,609,625).

**INFERENCE (flagged where used)**: hibernate image allocation likely fails under this host's routine ~28 GiB memory pressure (§5 — logind's coarse feasibility check passed, entry-time behavior untested); s2idle drain planning range 1.5-3%/h for this Ryzen AI 300 board (extrapolated from 7040-class community reports); `$PPID` inside hook shells resolving to the claude process (verify at implementation); "no input while lid closed"; BAT1 percentage-step udev uevent cadence (unmeasured — reason the timer was chosen over udev).

**Upstream source URLs**:
- https://gitlab.freedesktop.org/upower/upower/-/blob/v1.91.1/src/linux/up-backend.c (`check_action_result`, `up_backend_get_critical_action`, `up_backend_take_action`)
- https://gitlab.freedesktop.org/upower/upower/-/blob/v1.91.1/src/up-daemon.c (`up_daemon_set_warning_level`, `take_action_timeout_cb`, `UP_DAEMON_ACTION_DELAY`)
- https://github.com/systemd/systemd/blob/v260/src/login/logind-dbus.c (`verify_shutdown_creds`, `method_do_shutdown_or_sleep`, `method_can_shutdown_or_sleep`)
- https://github.com/systemd/systemd/blob/v260/src/shared/bus-polkit.c (`bus_test_polkit`, `POLKIT_ALWAYS_QUERY`)
- https://github.com/systemd/systemd/blob/v260/src/libsystemd/sd-bus/bus-convenience.c (`sd_bus_query_sender_privilege`)
- https://github.com/systemd/systemd/blob/v260/src/systemctl/systemctl-logind.c (`logind_reboot`, SKIP_INHIBITORS mapping)
- https://github.com/systemd/systemd/blob/v260/src/login/logind-inhibit.c (`manager_is_inhibited`)
- https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/blob/50.2/plugins/power/gsd-power-manager.c (`idle_configure`, `action_suspend`, `engine_charge_action`, `engine_device_warning_changed_cb`)
- https://gitlab.gnome.org/GNOME/mutter/-/blob/50.2/src/backends/meta-idle-monitor.c (`meta_idle_monitor_add_idle_watch` pre-existing-idle semantics)
- https://gitlab.freedesktop.org/polkit/polkit/-/blob/master/src/polkitbackend/polkitbackendinteractiveauthority.c (uid-0 implicit authorization)
- Framework community drain reports: https://community.frame.work/t/battery-drain-on-suspend-sleep-with-linux/42395 , https://community.frame.work/t/amd-framework-13-unreasonable-battery-loss-when-suspended/77826 , https://community.frame.work/t/excessive-battery-drain-on-framework-13-with-ryzen-5-7040/60690
