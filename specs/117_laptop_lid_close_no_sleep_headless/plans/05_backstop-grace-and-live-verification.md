# Implementation Plan: Task #117 (Round 3) — Backstop Wake-Grace and Live Verification

- **Task**: 117 - laptop_lid_close_no_sleep_headless
- **Status**: [IN PROGRESS]
  - Started: 2026-07-14 (rounds 1-2; phases 1, 2, 3, 5 complete, committed, and now confirmed LIVE)
  - Revised: 2026-07-25 (round 3: report 04 integrated)
- **Effort**: 6.25 hours cumulative (4 hours already spent and complete in rounds 1-2; 2.25 hours remaining in phases 6, 7, 8)
- **Dependencies**: Rounds 1-2 implementation (plans/01 and plans/02) — all config phases committed AND live on the running system (generation 126+, re-verified 2026-07-25). No activation debt remains for that work.
- **Research Inputs**:
  - specs/117_laptop_lid_close_no_sleep_headless/reports/04_partial-state-resolution.md (primary for this round)
  - specs/117_laptop_lid_close_no_sleep_headless/reports/03_battery-level-backstop.md (integrated in v2)
  - specs/117_laptop_lid_close_no_sleep_headless/reports/02_lid-close-screen-off-mechanism.md (absorbed into the round-1 *implementation* but never recorded; recorded here — see Research Integration)
  - specs/117_laptop_lid_close_no_sleep_headless/reports/01_lid-close-no-sleep.md (integrated in v1)
- **Artifacts**: plans/05_backstop-grace-and-live-verification.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: nix

## Overview

Task 117's mechanism (logind lid `lock`, GNOME battery idle-suspend 3600 s with an explicit
`suspend` type, session-tethered Claude inhibitors, and the root `battery-suspend-backstop` timer
that suspends at <=10% while discharging via `systemctl suspend -i`) is **built, committed, and
live on the running system**. Report 04 established this by read-only live introspection, and it
was independently re-verified after the user's most recent rebuild: `HandleLidSwitch` reads
`"lock"`, `battery-suspend-backstop.timer` is `active` and ticking, and the GNOME battery dconf
values are live (`'suspend'` / `3600`). The previous plan (v2) and `.orchestrator-handoff.json`
assert that all of Phase 4 is gated on the user; that assertion is **stale** and overstates the
remaining work by roughly 5x.

This revision does three things and nothing more. **(1)** It fixes the one genuine defect report 04
surfaced (Q5, HIGH severity): the backstop has no wake-grace period and no user-visible
notification, so a user who opens the lid at <=10% specifically to plug in a charger can be
re-suspended within ~60 s, repeatedly, with zero feedback — the journal `echo` is invisible behind
a lock screen. **(2)** It replaces Phase 4's six-item blocked checklist with an honest record of
what is already live plus a reduced checklist of the three items that genuinely remain (the
suspend-cycle A/B test, a physical undocked lid-close observation, and the docked multi-monitor
regression check that was reasoned through architecturally but never run). **(3)** It lands a small
in-scope docs delta covering the new grace semantics and the report 04 Q3 caveat.

Definition of done: the wake-grace + notification change is build-verified, activated, and
live-verified; the three remaining human checks are performed and recorded; docs describe the grace
window and its limits; and the multi-monitor requirement's evidence status is stated explicitly
rather than left ambiguous.

### Research Integration

Newly integrated in this revision:

| Report | Status | What it contributes here |
|---|---|---|
| `reports/04_partial-state-resolution.md` | **NEW — integrated in v3** | Q1 live-state audit (5 of 6 Phase-4 items already true), Q2 multi-monitor evidence-status finding, Q3 gsd one-shot / AC-leg gap, Q5 wake-grace defect (drives Phase 6), Q6 activation-debt correction, Q7 revise-in-place recommendation |
| `reports/02_lid-close-screen-off-mechanism.md` | **Recorded in v3 (retroactive)** | Was NOT listed in `plan_metadata.reports_integrated` (only 01 and 03 were), but its findings **were** absorbed — mid-round-1 implementation, not via a plan. Verified: `summaries/01_lid-close-no-sleep-summary.md:74-85` documents that report 02 falsified the round-1 `ignore` choice and drove the change to `HandleLidSwitch=lock` in commit d82e669, and report 02's docked-path re-verification (`reports/02:173`) is the sole basis for the multi-monitor claim. Nothing from report 02 is un-absorbed; only the bookkeeping was missing. Recorded now against v3 with this explanation, since it was never integrated into a *plan* version. |

Key report 04 facts this plan is built on (all live-verified read-only, no `sudo`, no state
transition):

- `busctl get-property org.freedesktop.login1 ... HandleLidSwitch` -> `"lock"`;
  `HandleLidSwitchExternalPower` -> `"lock"`. Generated `logind.conf` matches the committed Nix.
- `systemctl is-active battery-suspend-backstop.timer` -> `active`; next elapse ~49 s out.
  `systemctl show` -> `WakeSystem=no`, `Persistent=no`, `OnBootSec=2min`, `OnUnitActiveSec=60s`.
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type` ->
  `'suspend'`; `sleep-inactive-battery-timeout` -> `3600`.
- Hook tether live and *behaviorally* confirmed, not just textually: `diff <(jq .hooks
  ~/.claude/settings.json) <(jq .hooks config/claude/settings.json)` is empty, and `ps -o cmd=` on
  all six live `claude-code` inhibitor PIDs shows `... --mode=block tail --pid=<owner> -f
  /dev/null` with a live `tail` child. No orphaned inhibitors; all pid files point at live PIDs.
- `OnUnitActiveSec` is measured on a clock that does not advance across suspend, so the timer is
  overdue the instant the machine resumes and fires within the `AccuracySec=1min` coalescing
  window — this is the mechanical root of the Q5 defect.

### Multi-monitor requirement — evidence status (stated explicitly, per report 04 Q2)

The task description requires preserving multi-monitor window distribution when monitors are
attached. This requirement is **satisfied by architectural reasoning, cross-checked against
installed gsd/mutter source across two research rounds, and documented — but it has never been
empirically re-tested live with an external monitor attached after `HandleLidSwitch=lock` went
live.** Specifically:

- The docked lid path is gated by two layers that do not read `HandleLidSwitch` /
  `HandleLidSwitchExternalPower` at all — `gsd-power`'s own `handle-lid-switch` block inhibitor,
  and logind's separate `HandleLidSwitchDocked` (deliberately left at its default). Report 02
  concluded "the docked case is byte-for-byte unchanged under both `ignore` and `lock`"
  (`reports/02:173`), and report 01 recorded the deliberate decision not to set
  `HandleLidSwitchDocked`. niri's side is independently covered: niri natively syncs the internal
  monitor to the lid switch and manages per-output workspaces without consulting logind's lid
  value.
- The live evidence report 02 cited (`Docked=true`, two external DPs connected, gsd-power
  inhibitor present) was gathered **before** the `lock` value was committed — it is a pre-change
  baseline supporting an argument by independence, not a post-activation regression test.
- Report 04 could not close the gap: the machine was undocked at check time (`eDP-1` connected,
  all `DP-*` disconnected, live `Docked` -> `b false`).

Conclusion recorded here: the requirement is **not silently dropped and not believed broken**, but
its verification status is *reasoned, not tested*. The docked regression check stays in the
remaining human checklist (Phase 8) and the plan does not claim the requirement verified until that
check runs.

### Scope boundary — `docs/no-sleep-agents.md` is OUT of this task's file_scope

Report 04's Q2/Q3 recommendations name `docs/no-sleep-agents.md` as the place for the docked-test
audit-trail sentence and the "12h AC ceiling is best-effort" caveat. That file is **not** in task
117's `file_scope` (`config/claude/settings.json`, `config/config.kdl`, `docs/configuration.md`,
`docs/gnome-settings.md`, `docs/niri.md`, `modules/home/desktop/gnome.nix`,
`modules/system/power.nix`). It is task 118's deliverable and sits in the `file_scope` of task 119
(currently `[IMPLEMENTING]`) and task 120.

**Stated explicitly rather than silently widening scope**: this plan does NOT edit
`docs/no-sleep-agents.md`. The in-scope equivalents land in `modules/system/power.nix` (the durable
banner record of the grace mechanism) and `docs/gnome-settings.md` (the AC-ceiling caveat clause
and the docked-status note). **Recommended follow-up**: fold the fuller
`docs/no-sleep-agents.md` narrative — the grace-window paragraph, the docked-test audit line, and
the gsd one-shot AC caveat — into task 119's docs phase (it already owns that file and is mid-flight
on exactly the AC leg), or spawn a small doc task if 119 closes first. Do not let this plan's
Phase 7 grow to cover it.

### Coordination note

`docs/gnome-settings.md` is in the `file_scope` of both task 117 and task 119, and task 119 has
already edited its Power Management section (the live file shows `sleep-inactive-ac-type =
"suspend"` / `43200`). Phase 7's edit must be **additive and minimal** — one caveat clause on the
existing AC bullet, one grace clause near the backstop reference — and must not restate or
re-litigate task 119's AC timeout value, which is settled and now live.

### Explicitly out of scope for this revision

- Re-planning or re-verifying phases 1, 2, 3, 5 (complete, committed, live).
- Re-litigating the AC timeout value (task 119's settled decision; live).
- Any change to `.orchestrator-handoff.json` — it belongs to task 117's orchestration loop and is
  not touched by this plan, even though report 04 correctly identifies it as stale. The same goes
  for `summaries/01` and `summaries/02`: identified stale, corrected by *this plan's* record, not
  rewritten.
- The Q4 activity-timeout inhibitor redesign (report 04 explicitly does not recommend it).
- `services.upower.*` (unchanged leave-alone decision from v2).

## Goals & Non-Goals

**Goals**:

- Bounded **wake-grace window** on `battery-suspend-backstop` so a user who wakes the machine at
  <=10% has a usable window to authenticate, read the battery state, and plug in or shut down
  cleanly — without defeating the backstop on a truly unattended machine.
- **User-visible notification** on the user's session bus (visible on the GNOME lock screen)
  before/at each suspend decision, replacing a journal `echo` nobody can see.
- Honest, corrected record of Phase 4: five of six items live-verified; three genuinely-remaining
  checks (A/B suspend, physical undocked lid close, docked multi-monitor regression) consolidated
  into one clearly-labeled user checklist.
- Explicit statement of the multi-monitor requirement's evidence status (reasoned, not tested)
  until the docked check runs.
- One added sentence carrying report 03's gsd one-shot idle-suspend finding over to the AC leg, in
  an in-scope doc.
- All new verification reads LIVE state (`gsettings get`, `systemctl is-active`, `busctl
  get-property`, `systemctl list-timers`, `systemctl cat`) — never "the file was edited".

**Non-Goals**:

- No change to the 10% threshold, the `BAT*` glob, the `Discharging` gate, the 60 s poll, or
  `systemctl suspend -i` — the mechanism is correct and live.
- No hysteresis *band* (suspend at 10, re-allow at 15). The fix is a time/charge-bounded grace
  after a *wake*, which is a different thing and does not lengthen awake time on the unattended
  descent.
- No change to the SessionStart/SessionEnd hook scoping (user decision 1, unchanged).
- No hibernate / HybridSleep / suspend-then-hibernate work.
- No edit to `docs/no-sleep-agents.md` (out of `file_scope` — see Scope boundary).
- No agent-executed `sudo`, `systemctl suspend`, `nixos-rebuild switch`, or physical hardware
  manipulation. All such steps are in the Phase 8 user checklist.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Grace window defeats the backstop's purpose — unattended machine burns its reserve in repeated grace grants | H | L | Three independent bounds, all in Phase 6: (a) grace only after a *resume*, never on the unattended descent; (b) `grace_floor=5` — zero grace at or below 5%, original unconditional loop resumes; (c) `grace_drop=2` — grace is voided the moment capacity falls 2 points below its value at wake, so each grant costs at most ~2% regardless of the clock. Worst case is a handful of grants between 10% and 5%, i.e. the descent is slowed, never halted |
| Grace window too short to be useful (the defect persists) | M | M | 300 s is sized against the actual obstacle report 04 names: lock-screen authentication then reading the battery indicator. The notification states the remaining seconds so the window is legible rather than invisible |
| Resume-hook wake-mark never runs (suspend path bypasses `post-resume.target`) | M | L | Fail-safe direction: no wake-mark means no grace, i.e. exactly today's live behavior — protection is never weakened by the hook failing. Phase 8 live-checks that `post-resume.target` actually pulled the unit after a real resume |
| Notification failure blocks or delays the suspend | H | L | The notify call is wrapped in a bounded `timeout` and `\|\| true`; it can never gate the `exec systemctl suspend -i`. Phase 6 verification includes exercising the fire path with the notify helper forced to fail |
| Root unit cannot reach the user's session bus (uid/bus-path assumptions) | M | M | Discover uid via `loginctl list-users` rather than hardcoding; `runuser` + `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS` per uid; journal `echo` retained as the always-works fallback. A `--test-notify` mode makes the root->user path a one-line user check instead of a guess |
| Notification spam (one per 60 s tick through a 5-minute grace) | L | M | Notify on the first grace-skip tick and on the fire tick only; suppress repeats via a marker in the `StateDirectory`, cleared by the resume hook. Does not depend on server-side hint support for replace-in-place |
| Concurrent edit conflict with task 119 in `docs/gnome-settings.md` | L | M | Phase 7 edits are additive clauses on existing bullets; re-read the file immediately before editing and re-check `gsettings` live values rather than assuming v2's doc text still exists (task 118 already restructured this file) |
| New Nix option shapes wrong (round-1 was burned by renamed options) | M | L | The `wantedBy = [ "post-resume.target" ]` idiom is **live-proven in this repo**: `modules/system/audio.nix:46-58` uses it and `/run/current-system/etc/systemd/system/post-resume.target.wants/disable-speaker-amp.service` exists in the running closure. `powerManagement.resumeCommands` also verified present on the pin, but the explicit-unit form is preferred as the proven one |
| Regression to the live lid/inhibitor behavior from touching `power.nix` again | M | L | Phase 6 only *adds* to the backstop service and adds one small unit; Phase 8 re-reads `HandleLidSwitch` live as an explicit regression guard |
| Docked regression turns out real (multi-monitor requirement actually broken) | H | L | Phase 8's docked check is the gate; if it fails, that is a new finding requiring its own round — do not paper over it in docs. Contingency named in Rollback/Contingency |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 6 | 1 |
| 3 | 4, 5, 7 | 1, 2, 3 (phases 4, 5); 6 (phase 7) |
| 4 | 8 | 6, 7 |

Phases within the same wave can execute in parallel. Waves 1-3's completed members (1, 2, 3, 5)
already ran in rounds 1-2 and are carried forward unchanged; the only unexecuted work is phase 6
(wave 2), phase 7 (wave 3), phase 8 (wave 4), plus phase 4's three carried-over human checks which
phase 8 owns.

### Phase 1: Battery-level suspend backstop — root timer, `systemctl suspend -i` at <=10% Discharging [COMPLETED]

- Completed: 2026-07-14 (commit c72c4cf)
- Live-confirmed: 2026-07-25 (`systemctl is-active battery-suspend-backstop.timer` -> `active`;
  `systemctl show` -> `OnBootSec=2min`, `OnUnitActiveSec=60s`, `WakeSystem=no`, `Persistent=no`;
  unit source at `modules/system/power.nix` matches the running unit)

**Goal**: A root systemd service + timer in `modules/system/power.nix` polling the internal battery
every 60 s and suspending — bypassing all sleep inhibitors — at <=10% while genuinely
`Discharging`.

**Tasks** (all complete — carried forward verbatim in substance, do not re-execute):
- [x] `systemd.services.battery-suspend-backstop` + `systemd.timers.battery-suspend-backstop` added
  in the file's banner-comment style; `BAT*` glob only (a peripheral `hid-*-battery` reports
  perpetual `Discharging 100` and must not match); threshold 10; `exec systemctl suspend -i`.
- [x] `Discharging`-only sysfs gate; no `ConditionACPower` (duplicate gate, different multi-supply
  semantics).
- [x] Re-suspend-loop semantics documented in the banner as intentional.
- [x] `power.nix` header comment updated.
- [x] `nix flake check` green; `nixos-rebuild build --flake .#hamsa` green; eval confirms glob,
  threshold, verb, and both timer keys; branch logic exercised against fake sysfs values (fires at
  9 and 10 Discharging, silent at 11 / `Not charging` / `Charging`).

**Timing**: 1 hour (spent)

**Depends on**: none

**Files modified**: `modules/system/power.nix`

**Round-3 note**: the re-suspend loop documented here as "intentional" is battery-correct but
usability-defective (report 04 Q5). Phase 6 corrects it *additively* — the loop itself is retained
below the grace floor.

---

### Phase 2: GNOME battery idle timeout — 3600 s + explicit suspend type [COMPLETED]

- Completed: 2026-07-14 (commit 2386332)
- Live-confirmed: 2026-07-25 (`gsettings get org.gnome.settings-daemon.plugins.power
  sleep-inactive-battery-timeout` -> `3600`; `sleep-inactive-battery-type` -> `'suspend'`)

**Goal**: Battery idle-suspend at 1 hour with the action type pinned explicitly instead of riding
the schema default.

**Tasks** (complete):
- [x] `modules/home/desktop/gnome.nix`: `sleep-inactive-battery-timeout` 900 -> 3600, comment noting
  it fires only when no block inhibitor is held.
- [x] Added `sleep-inactive-battery-type = "suspend"` explicitly.
- [x] Build + HM dconf eval verified; committed.

**Timing**: 0.5 hours (spent)

**Depends on**: 1

**Files modified**: `modules/home/desktop/gnome.nix`

---

### Phase 3: Orphan inhibitor cleanup — tether inhibitor lifetime to the owning session process [COMPLETED]

- Completed: 2026-07-14 (commit 29fdd1f)
- Live-confirmed: 2026-07-25 (deployed vs repo `.hooks` diff empty; all six live `claude-code`
  inhibitor processes show `--mode=block tail --pid=<owner> -f /dev/null` with a live `tail` child;
  no orphaned inhibitors, all pid files point at live PIDs)

**Goal**: A Claude session that dies without firing SessionEnd releases its sleep inhibitor
automatically. Hooks stay SESSION-scoped (user decision 1); only the release path was hardened.

**Tasks** (complete):
- [x] Ancestry assumption verified empirically: the hook shell's `$PPID` IS the owning `claude`
  process; no ancestor walk needed.
- [x] SessionStart inhibitor payload `sleep infinity` -> `tail --pid=$PPID -f /dev/null`.
- [x] Stale-pid-file reap prepended (removes only files whose PID fails `kill -0`; never signals).
- [x] SessionEnd hook unchanged (fast-path release).
- [x] `jq` parse + `bash -n` on the extracted command + build green; committed.

**Timing**: 1 hour (spent)

**Depends on**: 1

**Files modified**: `config/claude/settings.json`

---

### Phase 4: Activation and live verification of rounds 1-2 [PARTIAL]

- Started: 2026-07-14
- Live-verified: 2026-07-25 (five of six checklist items TRUE by read-only introspection; no
  `sudo`, no state transition)

> **Round-3 status correction.** Plan v2 and `.orchestrator-handoff.json` describe this phase as
> fully blocked on the user with "no runtime item checked because none was executed." That is
> **stale as of 2026-07-25**: the machine was activated (generation 126 current, built
> 2026-07-14 14:40:23) and the config has been live ever since; nobody re-ran the cheap read-only
> checks to notice. **No further `nixos-rebuild switch` is needed for rounds 1-2.** This phase stays
> `[PARTIAL]` — not `[COMPLETED]` — solely because three checks genuinely require a real suspend
> cycle or physical hardware. Those three are **carried to Phase 8** and are not duplicated here.

**Goal**: Establish, from live state, which of rounds 1-2's layers are actually in effect.

**Tasks**:
- [x] Activation handed to the user (`summaries/02`) and subsequently performed — generation 126
  current, no newer generation, config live.
- [x] **Backstop timer live**: `systemctl is-active battery-suspend-backstop.timer` -> `active`;
  `list-timers` shows next elapse ~49 s out; `journalctl -u battery-suspend-backstop.service`
  silent at >10% (script exits 0 without output). VERIFIED 2026-07-25.
- [x] **Threshold logic inert-by-inspection**: the running unit's `ExecStart` matches the committed
  `BAT*` / threshold-10 / `suspend -i` logic; `/sys/class/power_supply/BAT1/{status,capacity}` ->
  `Not charging`, `100`, so the branch is provably inert without executing it. VERIFIED 2026-07-25.
- [x] **GNOME battery values live**: `sleep-inactive-battery-timeout` -> `3600`;
  `sleep-inactive-battery-type` -> `'suspend'`. VERIFIED 2026-07-25. (The AC leg's live value is
  task 119's business and is deliberately not asserted here.)
- [x] **Lid values live**: `busctl get-property org.freedesktop.login1 /org/freedesktop/login1
  org.freedesktop.login1.Manager HandleLidSwitch` -> `"lock"`; `HandleLidSwitchExternalPower` ->
  `"lock"`; generated `logind.conf` agrees. VERIFIED 2026-07-25.
- [x] **Hook tether live and behaviorally confirmed**: deployed-vs-repo `.hooks` diff empty; all six
  live inhibitor command lines show the `tail --pid` payload with a live `tail` child; no orphans.
  VERIFIED 2026-07-25 (stronger than the checklist asked — runtime behavior, not just source text).
- [ ] **Carried to Phase 8** (genuinely gated, not re-listed here): safe A/B suspend test; physical
  undocked lid-close observation; docked multi-monitor regression check.

**Timing**: 0.5 hours (spent; the read-only re-verification was ~10 minutes)

**Depends on**: 1, 2, 3

**Files to modify**: none (verification only)

---

### Phase 5: Documentation — rounds 1-2 [COMPLETED]

- Completed: 2026-07-14 (commit 09eb586)

**Goal**: Docs match rounds 1-2: the 10% backstop is the only inhibitor-proof protection; battery
idle-suspend is 1 hour and only fires with no session open; stale "15-minute backstop" framings
corrected.

**Tasks** (complete):
- [x] `power.nix` banner comments cross-checked against the built store script.
- [x] `docs/gnome-settings.md` Power Management and Lid-Close sections rewritten (3600 s, explicit
  type, inhibitor caveat, new backstop bullet, accepted open-session limitation, UPower 2% stated
  non-load-bearing).
- [x] `grep -n "900\|15 minutes\|15-minute" docs/gnome-settings.md` returns nothing.
- [x] Committed.

**Timing**: 0.75 hours (spent)

**Depends on**: 1, 2, 3

**Files modified**: `docs/gnome-settings.md`, `modules/system/power.nix`

**Round-3 note**: task 118 subsequently restructured `docs/gnome-settings.md`, consolidating the
narrative into `docs/no-sleep-agents.md` and leaving a raw-values Power Management block plus a
cross-reference. Phase 7 must re-read the file as it stands rather than assuming this phase's text
is still present.

---

### Phase 6: Wake-grace window and user-visible notification for the battery backstop [COMPLETED]

- Completed: 2026-07-25 (commit pending in this same implementation pass)

**Goal**: Fix report 04's Q5 HIGH-severity defect. After any resume, the backstop grants a bounded
grace window before it may re-suspend, and every suspend decision produces a notification the user
can actually see. The unattended-descent protection is unchanged, and the grace is bounded on three
independent axes so it cannot become a way for the machine to drain past its reserve.

**Design (implement exactly this shape; parameter names are load-bearing for the docs in Phase 7)**

Parameters, all in the script preamble as named shell variables with a comment each:

| Name | Value | Purpose / bound it enforces |
|---|---|---|
| `threshold` | `10` | Unchanged suspend trigger |
| `grace_secs` | `300` | Wake-grace window length (5 min) |
| `grace_floor` | `5` | **No grace at or below this capacity** — below it, the original unconditional loop applies |
| `grace_drop` | `2` | Grace is voided once capacity has fallen this many points below its value at wake |

Mechanism:

1. **Wake mark, written by a resume hook.** Add a tiny second unit,
   `systemd.services.battery-backstop-wake-mark`, with `wantedBy = [ "post-resume.target" ]` — the
   idiom already proven live in this repo (`modules/system/audio.nix:46-58`; the running closure
   contains `post-resume.target.wants/disable-speaker-amp.service`). On resume it writes
   `<epoch> <capacity>` to `${STATE_DIRECTORY}/wake-mark` and removes any `notified` marker. Both
   units declare `StateDirectory = "battery-suspend-backstop"` so they share
   `/var/lib/battery-suspend-backstop/`.
   - **Why a resume hook and not clock arithmetic**: `OnUnitActiveSec` runs on a clock that does not
     advance across suspend, but `date +%s` (realtime) *does*. A grace measured from the suspend
     would be entirely consumed by the suspend's own duration (wake after 3 h -> delta 3 h >
     `grace_secs` -> no grace), which would silently reproduce the defect. The window must be
     measured from the **wake**, so the wake timestamp must come from a resume hook.
2. **Backstop tick logic** (replacing only the inner branch; the `BAT*` loop, `Discharging` gate,
   and threshold comparison are untouched):
   - Not `Discharging`, or `cap > threshold` -> next battery, as today.
   - Otherwise, a suspend is due. Grant grace only if **all** hold: `cap > grace_floor`; the
     `wake-mark` file exists and parses; `0 <= (now - wake_epoch) < grace_secs`; and
     `(wake_cap - cap) < grace_drop`. On grant: notify (once per wake, gated by the `notified`
     marker) with the capacity and the remaining seconds, log to the journal, and **skip this tick**.
   - Otherwise: notify "battery at N%, suspending now — plug in to stop this", log, then
     `exec systemctl suspend -i` exactly as today.
3. **Notification path** (must never be able to block or delay the suspend):
   - Enumerate uids via `loginctl list-users --no-legend`, skipping uid < 1000; for each, invoke
     `runuser` (from `pkgs.util-linux`) with `XDG_RUNTIME_DIR=/run/user/<uid>` and
     `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus` running
     `${pkgs.libnotify}/bin/notify-send -u critical` with a short title/body.
   - Wrap the whole notify helper in `timeout 5 ... || true`. Retain the existing journal `echo`
     unconditionally as the always-works fallback.
   - `-u critical` is chosen so GNOME shows it on the lock screen — the exact surface report 04
     identifies as the one the user is looking at.
4. **`--test-notify` mode**: if invoked with `--test-notify`, the script sends the notification and
   exits 0 without reading batteries or suspending. This turns the root->user-bus path into a
   one-line user check (`sudo <script> --test-notify`) instead of an assumption.
5. **Banner comment** in `power.nix`: extend the existing block rather than replacing it. State the
   defect being fixed (with the report 04 reference), all four parameters, the three bounds, the
   fail-safe direction (no wake-mark -> no grace -> today's behavior), and the trade-off below.

**Trade-off, to be stated in the banner and in Phase 7's docs**: a grace window is a deliberate
weakening of an unattended machine's protection, and the cost is bounded rather than eliminated. In
the worst case (a bagged laptop that keeps waking spuriously), each grant costs at most 5 minutes of
awake time **or** 2% of charge, whichever comes first, and no grant is possible at or below 5%. So
the descent from 10% toward the floor can be slowed by a few windows but never halted, and the
mechanism's actual purpose — never reaching 0% and hard-powering-off — is preserved. A longer window
(15-30 min) was rejected precisely because on a bagged laptop it could burn the entire remaining
reserve in one or two spurious wakes. Grace is granted **only after a resume**, never on the
unattended awake descent, on the reasoning that a machine awake all the way down has had the whole
descent for its desktop low-battery warnings to appear (this last point is a rationale, not a
verified claim — see Flagged Unverified Items).

**Tasks**:
- [x] Verify option shapes against the pin before writing: `StateDirectory` on
  `systemd.services.<n>.serviceConfig`, and that `post-resume.target` is a valid `wantedBy` target
  in this configuration (`nix eval` the built unit, plus read
  `/run/current-system/etc/systemd/system/post-resume.target.wants/`). Prefer the explicit-unit
  idiom from `audio.nix` over `powerManagement.resumeCommands` (both exist; the former is
  live-proven here). VERIFIED: `disable-speaker-amp.service` symlink confirmed present under
  `/run/current-system/etc/systemd/system/post-resume.target.wants/` before writing; `StateDirectory`
  confirmed used elsewhere in-repo (`modules/system/optional/discord-bot.nix:114`).
- [x] Add `systemd.services.battery-backstop-wake-mark` to `modules/system/power.nix` (resume hook,
  writes `wake-mark`, clears `notified`).
- [x] Add the notify helper (`pkgs.writeShellScript`, or inline in the backstop script) with uid
  discovery, `runuser`, `timeout`, and `|| true`. *(deviation: altered — implemented as a separate
  `pkgs.writeShellScript "battery-backstop-notify"` derivation invoked by path from the backstop
  script's `safe_notify()` wrapper, rather than an inline shell function, so `timeout` can bound an
  external command directly instead of needing `bash -c "$(declare -f ...)"` re-exec gymnastics.
  Functionally identical: uid discovery via `loginctl list-users`, `runuser` with
  `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS`, `notify-send -u critical`, wrapped in
  `timeout 5 ... || true` in the caller.)*
- [x] Extend the `battery-suspend-backstop` script with the four parameters, the grace branch, the
  `notified` marker, and `--test-notify`; add `StateDirectory` to its `serviceConfig`.
  *(deviation: altered — added test-only override env vars `BACKSTOP_BATTERY_GLOB`,
  `BACKSTOP_SYSTEMCTL_BIN`, `BACKSTOP_NOTIFY_BIN` (all default to the real production paths via
  bash `${var:-default}`, so an unmodified systemd invocation is byte-identical in behavior) — this
  is what makes the offline logic exercise below possible without `sudo` or a stubbed
  `/sys/class/power_supply/`.)*
- [x] Extend the banner comment per the design above (report 04 reference, parameters, bounds,
  fail-safe direction, trade-off).
- [x] Offline logic exercise (agent-runnable, no `sudo`, no suspend): ran the built store script
  (`/nix/store/x4a3qw8gam9xn41ha6i9ymjg7mra6fjw-battery-suspend-backstop`) against a fake sysfs tree,
  a fake `STATE_DIRECTORY`, and a stubbed `systemctl`/`notify-send`, via
  `/tmp/.../scratchpad/run-backstop-tests.sh`. All cases passed (23/23 assertions, 0 failed):
  (a) `Not charging`/`Charging` -> silent (empty output, systemctl not invoked); (b) 11% Discharging
  -> silent; (c) 9% Discharging, no wake-mark -> fires, `systemctl suspend -i` invoked; (d) 9%
  Discharging, wake-mark 60 s old, `wake_cap=9` -> skips, systemctl NOT invoked, notify invoked
  once; (e) same but wake-mark 400 s old -> fires; (f) same but `wake_cap=11` (2-point drop) ->
  fires; (g) 4% Discharging, fresh wake-mark -> fires (below `grace_floor`); (h) notify helper
  forced to exit 1 -> notify still invoked, suspend STILL fires (notify failure never blocks);
  notified-marker suppression verified across two consecutive ticks in the same grace window
  (1 notify call total, not 2); `--test-notify` verified to invoke the notify helper and exit
  without touching battery state.
- [x] `jq`-free build gates: `nix flake check` green; `nixos-rebuild build --flake .#hamsa` green.
- [x] Commit (`task 117 phase 6: battery backstop wake-grace and notification`).

**Verification**:
- `nix flake check` -- PASS (`all checks passed!`, 2026-07-25).
- `nixos-rebuild build --flake .#hamsa` -- PASS. Built
  `/nix/store/j84p3im5jdmb4wrz74hppc20jmwbwcrd-nixos-system-hamsa-26.05.20260710.8f0500b`; 9
  derivations built including `battery-backstop-wake-mark`, `battery-backstop-notify`,
  `battery-suspend-backstop`, and both new/changed unit files.
- `nix eval --raw .#nixosConfigurations.hamsa.config.systemd.services.battery-suspend-backstop.serviceConfig.ExecStart`
  -> `/nix/store/x4a3qw8gam9xn41ha6i9ymjg7mra6fjw-battery-suspend-backstop`; read: contains all four
  parameters (`threshold=10`, `grace_secs=300`, `grace_floor=5`, `grace_drop=2`), the grace branch,
  and the unchanged `BAT*` / `Discharging` / threshold-10 / `suspend -i` core.
- `nix eval --json .#nixosConfigurations.hamsa.config.systemd.services.battery-backstop-wake-mark.wantedBy`
  -> `["post-resume.target"]`. `...serviceConfig.StateDirectory` -> `"battery-suspend-backstop"` on
  BOTH `battery-suspend-backstop` and `battery-backstop-wake-mark` (confirmed both, matching the
  plan's shared-directory design).
- The eight offline cases above all pass (23/23 assertions). Live verification is Phase 8 (this
  phase changes nothing on the running system until activation).

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `modules/system/power.nix` — extend the backstop service/script and banner; add the wake-mark unit
  and notify helper

---

### Phase 7: Documentation delta — grace semantics, AC-ceiling caveat, docked status [COMPLETED]

- Completed: 2026-07-25

**Goal**: In-scope docs describe the grace window and its bounds, carry report 03's gsd one-shot
finding over to the AC leg, and state the multi-monitor evidence status honestly. Minimal and
additive — task 118 restructured `docs/gnome-settings.md` and task 119 is mid-flight in it.

**Tasks**:
- [x] Re-read `docs/gnome-settings.md` as it currently stands before editing (do NOT assume plan
  v2's text survives; the Lid-Close narrative moved to `docs/no-sleep-agents.md` in task 118).
  CONFIRMED: file shows the raw-values Power Management block + `no-sleep-agents.md`
  cross-reference (task 118 restructure), plus task 119's already-live `sleep-inactive-ac-type =
  "suspend"` / `43200` bullet, exactly as this plan's Coordination note anticipated.
- [x] `modules/system/power.nix` — cross-check the Phase 6 banner against the final built script
  (parameters, three bounds, fail-safe direction, trade-off, `--test-notify`). This is the durable
  in-scope record of the grace mechanism. VERIFIED: banner (lines ~236-280) and the built script
  agree on all four parameters, the three bounds, the fail-safe direction, the trade-off, and
  `--test-notify`; no changes needed (Phase 6 already wrote it correctly).
- [x] `docs/gnome-settings.md`, Power Management block: add a short clause to the existing backstop
  cross-reference noting the wake-grace window — after a resume, the backstop waits up to 5 minutes
  before it may re-suspend, unless capacity is at or below 5% or has dropped 2 points since the
  wake, and a critical notification (visible on the lock screen) announces each decision.
- [x] `docs/gnome-settings.md`, "Idle suspend (AC)" bullet: add **one** caveat clause carrying report
  03's finding to the AC leg — gsd's idle-suspend watch is one-shot per idle period with no retry,
  so the AC ceiling is a **best-effort bound, not a deterministic guarantee**: if the boundary is
  crossed while any block inhibitor is briefly held, the attempt is denied and is not retried until
  a re-arm event. Do NOT restate or re-litigate the timeout value itself (task 119's settled, live
  decision). Note in the commit message that this clause coordinates with task 119.
- [x] `docs/gnome-settings.md`: one sentence recording the multi-monitor status — the docked
  lid-close path is unaffected by `HandleLidSwitch`/`HandleLidSwitchExternalPower` by design
  (`HandleLidSwitchDocked` deliberately unset; gsd-power holds its own lid inhibitor), verified
  architecturally against gsd/mutter source and, once Phase 8's docked check runs, live. Phrase it
  so it is accurate *before* Phase 8 completes, and tighten it after.
- [x] Do NOT edit `docs/no-sleep-agents.md` (out of `file_scope`). Record the recommended follow-up
  (fold the fuller narrative into task 119's docs phase, or a small new doc task) in the
  implementation summary so it is not lost.
- [x] Commit (`task 117 phase 7: document backstop wake-grace and AC ceiling caveat`).

**Verification**:
- `grep -n "grace\|wake-grace\|best-effort" docs/gnome-settings.md modules/system/power.nix` shows
  the new text in both places. VERIFIED 2026-07-25: `docs/gnome-settings.md:28,37` and
  `modules/system/power.nix` (multiple lines, banner + script).
- Every touched doc line reconciled against LIVE state, not against the source: `gsettings get` the
  four power keys and confirm the doc's stated values match what is actually live at edit time
  (recording, not asserting, the AC leg's value, which task 119 owns). VERIFIED 2026-07-25 live:
  `sleep-inactive-battery-timeout` -> `3600`; `sleep-inactive-battery-type` -> `'suspend'`;
  `sleep-inactive-ac-timeout` -> `43200`; `sleep-inactive-ac-type` -> `'suspend'`;
  `HandleLidSwitch` -> `"lock"`; `Docked` -> `b false` (undocked at edit time — consistent with the
  doc's "not yet re-tested docked" statement, not a docked regression run).
- `git diff --stat` touches only `docs/gnome-settings.md` in this phase's own diff (`power.nix` was
  already committed correct in Phase 6; the cross-check required no further edit) — no
  out-of-scope file was widened into.

**Timing**: 0.5 hours

**Depends on**: 6

**Files to modify**:
- `docs/gnome-settings.md` — additive clauses only
- `modules/system/power.nix` — banner cross-check

---

### Phase 8: Activate the grace change and close the reduced live checklist [NOT STARTED]

**Goal**: Activate ONLY the new Phase 6/7 change (rounds 1-2 are already live and need no
re-activation), verify the grace mechanism live, and close the three genuinely-remaining checks
carried over from Phase 4.

**Agent-runnable live checks** (no `sudo`, read-only; run after the user's switch):
- [ ] `systemctl is-active battery-suspend-backstop.timer` -> `active`;
  `systemctl list-timers battery-suspend-backstop.timer --no-pager` shows it ticking.
- [ ] `systemctl cat battery-suspend-backstop.service` shows the **new** store script (grace
  parameters present); `systemctl show battery-suspend-backstop.service -p StateDirectory` ->
  `battery-suspend-backstop`; `test -d /var/lib/battery-suspend-backstop`.
- [ ] `systemctl cat battery-backstop-wake-mark.service` exists and
  `ls /run/current-system/etc/systemd/system/post-resume.target.wants/` lists it — the live proof
  the resume hook is actually wired, not merely declared.
- [ ] `journalctl -u battery-suspend-backstop.service -n 20` silent at >10% (no behavior change on
  AC).
- [ ] **Regression guards, live**: `busctl get-property org.freedesktop.login1
  /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` -> `"lock"` (and
  `HandleLidSwitchExternalPower`); `gsettings get org.gnome.settings-daemon.plugins.power
  sleep-inactive-battery-timeout` -> `3600` and `sleep-inactive-battery-type` -> `'suspend'`. Record
  the AC leg's live values without asserting them (task 119 owns that value).
- [ ] After the user's A/B test below, confirm the wake path worked:
  `systemctl status battery-backstop-wake-mark.service` shows an activation timestamp at the resume,
  and `sudo`-free `stat /var/lib/battery-suspend-backstop/wake-mark` shows a matching mtime (read the
  file if permissions allow; otherwise the unit's activation timestamp is sufficient evidence).
- [ ] Record all outcomes in the round-3 implementation summary, including the recommended
  `docs/no-sleep-agents.md` follow-up from Phase 7.

**USER CHECKLIST** (requires `sudo`, a real suspend cycle, or physical hardware — agents must not
perform any of these):
1. **Activate the new change only**: `sudo nixos-rebuild switch --flake .#hamsa`. No reboot is
   required — rounds 1-2 are already live, and this change adds units rather than altering logind.
2. **Notification path**: `sudo $(systemctl cat battery-suspend-backstop.service | sed -n
   's/^ExecStart=//p') --test-notify` — a critical notification should appear in your GNOME session.
   Repeat with the screen locked to confirm it is visible on the lock screen (the surface that
   matters).
3. **Safe A/B suspend test** (carried over from Phase 4; with a Claude session deliberately open so
   block inhibitors are held — no battery draining involved): `sudo systemctl suspend` must be
   **REFUSED** with `BlockedByInhibitorLock`; then `sudo systemctl suspend -i` must suspend despite
   the inhibitors. Wake with the lid or a keypress. This proves the exact call the backstop makes,
   and the resume also exercises the new wake-mark hook.
4. **Physical lid-close, undocked** (carried over from Phase 4): close the lid with no external
   monitor attached -> the session locks, the panel powers off roughly 30 s later, and the machine
   **stays awake** (verify afterwards via `who -b` / `journalctl -b 0 -g "suspend"` showing no
   suspend, or simply that an in-flight agent kept running).
5. **Docked multi-monitor regression** (carried over from Phase 4 / report 04 Q2 — the check that
   has never been run): with at least one external monitor attached, confirm `busctl get-property
   org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager Docked` -> `b true`,
   then close the lid and confirm the pre-existing docked behavior is unchanged — windows distribute
   to the external display(s), no lock, no suspend. **This is the gate on the task's multi-monitor
   requirement**; if it fails, stop and report rather than documenting around it.
6. **Escape hatch reminder** (unchanged): for a deliberate low-battery session,
   `systemctl stop battery-suspend-backstop.timer` (re-enabled at next boot/switch).
7. Do **NOT** test the backstop by draining the battery. Step 3 validates the bypass chain safely,
   and Phase 6's offline cases cover the grace logic.

**Verification**:
- All agent-runnable checks above pass against LIVE state (not source).
- User checklist items 2-5 reported back; any failure keeps this phase `[PARTIAL]` with the failing
  layer named explicitly, and item 5's failure specifically blocks any claim that the multi-monitor
  requirement is verified.

**Timing**: 0.5 hours agent-side (the user performs the switch and items 2-5, together well under
15 minutes)

**Depends on**: 6, 7

**Files to modify**: none expected (verification only; fixes loop back into the owning phase's file)

## Testing & Validation

Already green and live (rounds 1-2 — do not re-run):

- [x] `nix flake check` green; `nixos-rebuild build --flake .#hamsa` green.
- [x] Backstop `ExecStart` / `timerConfig` eval checks; HM dconf eval.
- [x] `jq .` parses `config/claude/settings.json`; hook command passes `bash -n`.
- [x] LIVE: timer `active` and ticking; `HandleLidSwitch` and `HandleLidSwitchExternalPower` read
  `"lock"`; battery dconf reads `3600` / `'suspend'`; hook tether behaviorally confirmed on all six
  live inhibitor processes; no orphaned inhibitors.
- [x] Docs contain no stale 900 s / 15-minute claims.

New in round 3:

- [x] Eight offline grace-logic cases pass (Phase 6), including the notify-fails-still-suspends case.
  VERIFIED 2026-07-25: 23/23 assertions pass via scratchpad test harness against the built store
  script.
- [x] `nix flake check` + `nixos-rebuild build --flake .#hamsa` green after Phase 6. VERIFIED
  2026-07-25.
- [x] Eval: `battery-backstop-wake-mark.wantedBy` contains `post-resume.target`; `StateDirectory` set
  on both units; new script present in `ExecStart`. VERIFIED 2026-07-25.
- [ ] LIVE after activation: new script in `systemctl cat`; `/var/lib/battery-suspend-backstop/`
  exists; wake-mark unit listed under `post-resume.target.wants/`; backstop journal silent on AC.
- [ ] LIVE regression guards after activation: `HandleLidSwitch` still `"lock"`; battery dconf still
  `3600` / `'suspend'`.
- [ ] USER: `--test-notify` visible, including on the lock screen.
- [ ] USER: A/B suspend test — plain `suspend` refused, `suspend -i` succeeds; wake-mark unit shows
  an activation timestamp at the resume.
- [ ] USER: physical undocked lid close — locks, panel off, stays awake.
- [ ] USER: docked multi-monitor regression — `Docked` -> `b true`, lid close leaves docked behavior
  unchanged. **Gates the multi-monitor requirement.**
- [ ] Docs: `grep -n "grace\|best-effort" docs/gnome-settings.md modules/system/power.nix` shows the
  new text; `git diff --stat` touches no file outside `file_scope`.

## Artifacts & Outputs

- `specs/117_laptop_lid_close_no_sleep_headless/plans/05_backstop-grace-and-live-verification.md`
  (this file; supersedes `plans/02_battery-level-backstop.md`, which is retained for history)
- Modified in round 3: `modules/system/power.nix` (Phase 6, Phase 7), `docs/gnome-settings.md`
  (Phase 7)
- Unchanged from rounds 1-2 (live): `modules/home/desktop/gnome.nix`, `config/claude/settings.json`
- `specs/117_laptop_lid_close_no_sleep_headless/summaries/05_backstop-grace-and-live-verification-summary.md`
  on implementation completion. It must carry: the reduced user checklist verbatim, the recommended
  `docs/no-sleep-agents.md` follow-up, and the multi-monitor check outcome.
- Not written or modified by this plan: `.orchestrator-handoff.json`, `summaries/01`, `summaries/02`
  (identified stale by report 04; corrected by this plan's record, not rewritten here).
- Directory guardrail: `plans/` already exists; create nothing else eagerly. `summaries/` is created
  only when its file is written.

## Rollback/Contingency

- Phase 6 and Phase 7 are separate scoped commits; `git revert <sha>` per phase. Reverting Phase 6
  restores the current live behavior exactly (unconditional re-suspend loop), which is
  battery-correct — the revert is never a safety regression.
- Grace mechanism misbehaving live and no rebuild available: `sudo systemctl stop
  battery-suspend-backstop.timer && sudo systemctl disable battery-suspend-backstop.timer` (masks
  until next switch) — but note this removes the protection entirely, so prefer
  `sudo rm /var/lib/battery-suspend-backstop/wake-mark`, which disables only the grace (no wake-mark
  -> no grace -> pre-Phase-6 behavior) while leaving the backstop armed. This fail-safe direction is
  a deliberate property of the design.
- Notifications noisy or unwanted: they are advisory only; reverting Phase 6 removes them, or the
  notify helper can be neutered independently without touching the suspend logic (it is already
  wrapped in `timeout ... || true`).
- Wake-mark unit failing at resume: no action needed for safety (grace simply never engages);
  investigate via `systemctl status battery-backstop-wake-mark.service` and
  `journalctl -u battery-backstop-wake-mark.service -b 0`.
- **Docked multi-monitor check fails (Phase 8 item 5)**: do not patch docs to match. Stop, record
  the observed behavior, and treat it as a new finding needing its own research round — the two-layer
  independence argument (gsd-power's own lid inhibitor + `HandleLidSwitchDocked` left at default)
  would be falsified and the correct fix is not knowable from this plan.
- Rounds 1-2 rollback story is unchanged from plans/01 and plans/02 and is not affected by this
  revision.

## Flagged Unverified Items

- **Desktop low-battery warnings on the awake descent**: the rationale for granting grace only after
  a resume (rather than also before the first fire) assumes GNOME/gsd already warns the user on the
  way down to 10% while awake. The exact gsd notification thresholds on this system were NOT
  verified. If Phase 8 or later experience shows no such warning, revisit whether the *first* fire
  should also be preceded by a short notice-then-suspend delay — a small, additive follow-up, not a
  redesign.
- **`grace_secs = 300` sizing**: chosen against the obstacle report 04 names (lock-screen
  authentication plus reading the battery indicator), not measured. Adjust after the first real
  encounter; the three bounds make any value in the low-minutes range safe.
- **s2idle drain rate 1.5-3%/h**: still an INFERENCE from Framework 7040-class community reports
  (report 03), never measured on this board. It informs the threshold and floor *rationale*, not the
  mechanism.
- **`suspend -i` end-to-end on this machine**: source- and polkit-verified, never executed here.
  Phase 8 user item 3 is the live proof and is the oldest outstanding item in this task.
- **Multi-monitor / docked lid path**: reasoned and cross-checked against gsd/mutter source, live
  *baselined* pre-change, never re-tested post-activation. Phase 8 user item 5 closes it. Until then
  this plan does not claim the requirement verified.
- **Root -> user-session notification path**: designed against `loginctl` uid discovery plus
  `runuser` and the standard `/run/user/<uid>/bus` path; not exercised from a root unit context.
  `--test-notify` exists specifically so this is a one-line check rather than an assumption, and the
  journal `echo` fallback means failure is cosmetic.
- **`powerManagement.resumeCommands` vs explicit `post-resume.target` unit**: `resumeCommands` was
  confirmed to exist on the pin, but the explicit-unit idiom is preferred because it is live-proven
  in this repo (`modules/system/audio.nix`, and the target's `.wants` directory is present in the
  running closure). Phase 6 re-verifies the chosen shape before writing.
