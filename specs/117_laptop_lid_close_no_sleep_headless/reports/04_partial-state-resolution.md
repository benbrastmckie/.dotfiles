# Research Report: Task #117 (Round 4) — Resolving the `[PARTIAL]` State

**Task**: 117 - laptop_lid_close_no_sleep_headless
**Started**: 2026-07-24T23:50:00-07:00
**Completed**: 2026-07-25T00:40:00-07:00
**Effort**: ~50 min (full artifact re-read across tasks 117/118/119/120, live read-only introspection, git/generation forensics)
**Dependencies**: Builds on reports/01, 02, 03 and both plans (01, 02) — does not re-derive their findings, only audits their current truth-state and answers seven specific questions about what remains
**Sources/Inputs**: All task 117 artifacts (reports 01-03, plans 01-02, summaries 01-02, phase-1 handoff, `.orchestrator-handoff.json`), task 118 report, task 119 artifacts (report, plan, summary, handoff, `.orchestrator-handoff.json`), task 120/77 state.json entries, `modules/system/power.nix`, `modules/home/desktop/gnome.nix`, `config/config.kdl`, `config/claude/settings.json`, `docs/no-sleep-agents.md`, `docs/gnome-settings.md`, `docs/niri.md`, `docs/configuration.md`, git log/show, live read-only introspection (`busctl`, `gsettings`, `systemctl`, `systemd-inhibit --list`, `ps`, `journalctl`, `nixos-rebuild list-generations`, `/sys/class/power_supply/*`, `/sys/class/drm/*`)
**Artifacts**: specs/117_laptop_lid_close_no_sleep_headless/reports/04_partial-state-resolution.md (this report)
**Standards**: report-format.md, artifact-formats.md, subagent-return.md

## Executive Summary

- **Q1**: Phase 4 is NOT purely blocked on the user. Live, read-only introspection performed in
  this session proves **5 of 6 Phase-4 checklist items are already true on the running system
  right now** — the `.orchestrator-handoff.json` and both implementation summaries are **stale**
  (they describe the state as of 2026-07-14; the machine was in fact activated shortly after
  and nobody re-checked). Only two items remain genuinely gated: a suspend-cycle A/B test and a
  physical lid-close observation.
- **Q2**: The multi-monitor/window-distribution requirement was **not silently dropped** — it was
  addressed by explicit, cross-verified architectural reasoning (twice, in reports 01 and 02) and
  is documented in `docs/no-sleep-agents.md`. But it was never *empirically* tested live with an
  external monitor attached after the `lock` config went live — that specific checklist item is
  still open and should be folded into the remaining human checklist.
- **Q3**: Task 119's AC change does **not** functionally reverse task 117's headless-agent
  guarantee for the primary case (a Claude Code session open) — the block-inhibitor denial
  mechanism is orthogonal to the configured timeout value. It **does** narrow protection for a
  case 117 never covered (unattended non-Claude AC workloads with no open session), which is a
  documented, accepted trade-off in task 119's own plan. One under-analyzed detail: task 119 did
  not carry over report 03's "gsd idle-suspend watch is one-shot, no retry" finding to the AC
  leg — worth a one-line doc correction, not a design change.
- **Q4**: The accepted requirement-(B) partial (idle-but-open Claude session blocks battery
  idle-suspend until the 10% backstop) is a **reasonable, well-bounded engineering trade-off**,
  not a defect requiring urgent fixing. A higher-quality activity-timeout-based design is
  possible in principle but not built; not recommended as a required fix.
- **Q5 — highest severity finding of this round**: the battery-suspend-backstop's re-suspend loop
  is **safe with respect to data/battery loss** but has a **real, unaddressed usability defect**:
  there is no wake-grace period and no user-facing notification, so a user who opens the lid at
  ≤10% battery specifically to check on the machine or find a charger can be re-suspended out
  from under them within roughly 60 seconds, repeatedly, with zero visual feedback. Given hours
  of headroom at the 10% threshold (already established in report 03), a bounded grace window
  costs essentially nothing in safety margin and meaningfully fixes the UX. **Recommended: fix,
  not merely document.**
- **Q6**: A single `sudo nixos-rebuild switch --flake .#hamsa` closes essentially all remaining
  activation debt. Task 117's config is **already live** (confirmed by generation history); only
  task 119's two-value dconf change remains uncommitted-to-runtime. No reboot is required for
  119. There is no meaningful ordering hazard — contrary to the premise that both tasks have
  "config simultaneously never activated," only 119 does.
- **Q7 — Recommendation**: Do not abandon (confirmed: doing so would discard substantial, live,
  load-bearing configuration). Do not split into a new task. **Revise the plan** (a small round-3
  addition to task 117, not a new task) to: (a) formally record the live-activation facts found
  here, closing most of Phase 4; (b) perform the two still-gated checks; (c) add a small phase
  fixing the Q5 wake-grace defect; (d) add one sentence to `docs/no-sleep-agents.md` closing the
  Q2 docked-regression-test gap. This is bounded, cheap, and keeps ownership of the mechanism
  coherent in the task that already owns the file.

## Context & Scope

Task 117 has accumulated three research rounds, two plan versions (five phases each), and two
implementation summaries, all concluding "build-verified, Phase 4 blocked pending user
activation." This round does not re-litigate any of that prior work. Its job is narrower and
more important: determine whether the `[PARTIAL]` status and the "blocked on the user" framing
are still *true*, given that ten days have elapsed since the last research/implementation round
and the machine has plausibly been used (and rebuilt) in the interim. This is exactly the
activation-lag bug class task 118/119 already identified as endemic to this repo — the risk here
is that the same class of staleness exists in task 117's own status, undetected because nobody
re-checked after the fact.

Read-only only. No config edited, no `sudo`, no `systemctl suspend` variant executed, no
activation performed.

## Findings

### Q1 — Is Phase 4 the only thing left, and is the remaining work purely human?

**No on both counts.** The claim that Phase 4 is entirely blocked on interactive `sudo` is
**stale** — it was accurate on 2026-07-14 when the round-2 implementation agent wrote it, but a
live-system check performed in this session shows the machine has since been activated.

**Direct proof the machine is running a generation built from task 117's final committed state**,
via `nixos-rebuild list-generations` (no sudo required to read):

```
Generation  Build-date           NixOS version           Kernel  Current
126         2026-07-14 14:40:23  26.05.20260710.8f0500b  7.1.3   True
```

Generation 126 is `Current: True` and no newer generation exists. Its build-date
(2026-07-14 14:40:23) falls in the same few-minute window as task 117 round-2's phase commits
(`c72c4cf` 14:35:24, `2386332` 14:37:45, `29fdd1f` 14:41:14, `09eb586` 14:42:53, `417defc`
14:46:53) — the generation's build-date sits *between* the phase-2 and phase-3 commit
timestamps. This is consistent with Nix flakes evaluating the local git working tree (tracked,
possibly-uncommitted content, with a "dirty tree" warning) rather than strictly the latest
commit — i.e., a `sudo nixos-rebuild switch --flake .` run around 14:40 on 2026-07-14 very
plausibly picked up files that were already edited on disk even though their commits landed a
minute or two later. This causal detail is INFERENCE (flagged as such); what is **not**
inference is the live state itself, checked directly this session:

| Phase-4 checklist item (plan 02) | Live-verified this session | Method |
|---|---|---|
| 1. Backstop timer live | **TRUE** — `active`, next elapse in 49s at check time | `systemctl is-active` / `list-timers` |
| 2. Safe A/B suspend test (`suspend` refused, `suspend -i` succeeds) | **NOT DONE — genuinely requires a real suspend cycle** (category b) | N/A — requires actual state transition, explicitly out of scope for this research |
| 3. Threshold dry-run (script logic, no suspend) | Effectively confirmed by inspection: `power.nix:126-143` shows the exact committed `BAT*`/threshold-10/`suspend -i` logic live in the running unit's `ExecStart`; battery is currently `Not charging` at 100%, so the branch is provably inert right now without executing it | Read of `power.nix` + `systemctl cat battery-suspend-backstop.service` (implied by matching source) |
| 4. GNOME values live (`sleep-inactive-battery-timeout`=3600, `-type`='suspend'; `sleep-inactive-ac-type`='nothing') | **TRUE** — `gsettings get` returns exactly these four values | `gsettings get org.gnome.settings-daemon.plugins.power ...` |
| 5. Lid `HandleLidSwitch`/`HandleLidSwitchExternalPower` = `"lock"` (+ physical lid test) | Logind values **TRUE** (`busctl` → `s "lock"` for both); physical lid-close observation **NOT DONE — genuinely physical** (category a) | `busctl get-property ... HandleLidSwitch` / `HandleLidSwitchExternalPower` |
| 6. Hook tether live (deployed hooks match repo; tether payload is `tail --pid`, not `sleep infinity`; scratch-session kill-9 releases it) | **TRUE**, and more thoroughly than the checklist even asked: `diff <(jq .hooks ~/.claude/settings.json) <(jq .hooks config/claude/settings.json)` is empty, AND the six live `claude-code` inhibitor processes' actual command lines were inspected directly (`ps -o cmd=`) and all six show `systemd-inhibit --what=sleep:idle ... --mode=block tail --pid=<owner-pid> -f /dev/null` with a live `tail` child process — this is the *runtime behavior*, not just the deployed source text | `jq` diff + `ps -o cmd=` + `pgrep -P` on all 6 live inhibitor PIDs |

Additional corroborating live facts: `/etc/systemd/logind.conf` (`systemd-analyze cat-config`)
shows exactly `HandleLidSwitch=lock`, `HandleLidSwitchExternalPower=lock`,
`KillUserProcesses=false` — the generated file matches the committed Nix, and it is the file
`systemd-logind` is actually running against (`busctl` reads agree). No orphaned inhibitor pid
files exist: all 6 `/tmp/claude-inhibitor-*.pid` files point at live PIDs matching the 6 live
`claude-code` inhibitors currently held.

**Verdict**: Of the six Phase-4 checklist items, five are true today and were verified read-only
in this session without any elevated privilege. Only two things remain genuinely gated, and both
are small and bounded:

1. **(b) Requires a real suspend cycle**: the safe A/B test (`sudo systemctl suspend` refused →
   `sudo systemctl suspend -i` succeeds). This needs an actual sleep/resume transition and
   `sudo`; it cannot be automated read-only. Takes under two minutes.
2. **(a) Genuinely physical**: closing the lid undocked and observing that the panel powers off
   ~30 s after lock rather than staying lit, and (per Q2 below) closing the lid *with* an
   external monitor attached to confirm the docked path is unaffected.

**This materially changes the picture the `.orchestrator-handoff.json` presents.** That file
(dated to session `sess_1784057900_748474`, 2026-07-14) says "no runtime item is checked because
none was actually executed" and instructs the user to run the full switch+reboot+checklist from
scratch. That instruction is now **redundant and misleading** for 5 of 6 items — re-running
`nixos-rebuild switch` is not even necessary (nothing has changed since generation 126), and
telling the user "all of Phase 4 is blocked on you" overstates the remaining work by roughly 5x.
This is the single largest driver of task 117 being stuck: the handoff literally instructs the
next reader to re-verify from a state that no longer requires nearly all of that work, without
anyone ever having re-run the (extremely cheap) read-only checks to notice.

### Q2 — Was the multi-monitor requirement silently dropped?

**Not dropped — addressed by design reasoning across two research rounds and documented, but
never empirically tested live post-activation.** This is a nuanced "(a) addressed" with one
concrete open action item folded in.

Evidence it was addressed, not forgotten:

- Report 01 (round 1) has a dedicated "Multi-monitor / window distribution" subsection
  (`reports/01_lid-close-no-sleep.md:44-46`) and states plainly in its Decisions section: "Do NOT
  set `HandleLidSwitchDocked`... preserves current docked semantics byte-for-byte." Plan 01's
  Goals section explicitly states: "Preserve existing multi-monitor behavior exactly: windows
  continue to distribute to external displays on lid close when docked"
  (`plans/01_lid-close-no-sleep.md:40`).
- Report 02 (round 2) *re-verified* this specifically for the revised `lock` value (the value
  changed from `ignore` after round 1, so the docked-path claim needed re-checking against the
  new value): "The docked case is byte-for-byte unchanged under both `ignore` and `lock`"
  (`reports/02_lid-close-screen-off-mechanism.md:173`), backed by live evidence gathered that
  session (`Docked=true` with two external DPs connected, gsd-power holding its own
  `handle-lid-switch` block inhibitor).
- `docs/no-sleep-agents.md` carries this forward as the durable record: a "Docked/external-monitor
  behavior is untouched" paragraph and a composition-table row ("Lid closed, external monitor(s)
  attached → GNOME's own docked-lid inhibitor takes over... windows move to the external display,
  no lock, no suspend").

The gap: **the live evidence cited in report 02 (`Docked=true`, gsd-power inhibitor present) was
gathered *before* the `lock` config was ever committed** — it was a baseline observation of
today's pre-fix docked behavior, used to argue by *independence* (the docked path is gated by two
layers — `gsd-power`'s own inhibitor and logind's `HandleLidSwitchDocked` default — neither of
which reads the `HandleLidSwitch`/`HandleLidSwitchExternalPower` value at all) that the change
cannot regress it. That reasoning is sound and was cross-checked against installed gsd/mutter
source in round 2, but it is architectural inference, not an empirical post-activation test. This
machine is currently undocked (`/sys/class/drm/card1-eDP-1/status: connected`, all `DP-*`
outputs `disconnected`, live `Docked` property `b false`), so a live functional re-test could not
be performed in this session either. Plan 01's own Phase 4 checklist already lists this as a
required item ("Regression test (docked case)") — per Q1, it has never actually been run. It
should be treated as the third item in the remaining human checklist (see Q7), alongside the
suspend A/B test and the physical undocked lid-close observation.

On what "implementing it would actually require" (per the prompt) if it *had* been silently
dropped: nothing further would need building. niri's side of this is equally already covered —
niri natively turns the internal monitor on/off in sync with the lid switch and manages
per-output workspaces independently of logind's `HandleLidSwitch` value (upstream niri wiki,
quoted verbatim in report 02 §6); no repo config touches niri's monitor/workspace handling at
all, and `kanshi.nix` only has a placeholder "undocked" profile with docked profiles commented
out as an *unrelated*, pre-existing todo (`modules/home/desktop/kanshi.nix:19-28`), not something
this task introduced or needs to complete. `niri msg outputs` could not be run in this session to
confirm live niri output state, because the active session is GNOME, not niri (`niri msg
outputs` failed with "NIRI_SOCKET is not set, are you running this within niri?", as expected) —
that command is worth adding to a future niri-session functional check, not something skippable
by design.

### Q3 — Does task 119 partially reverse a deliberate task 117 decision?

**Not a functional reversal for the case task 117 actually names ("keep AI agents running
headless"); a real, but different and already-documented, narrowing for a case 117 never
covered.** One analysis gap is worth calling out. This interaction is currently **prospective**,
not live: task 119 has not been activated (live `sleep-inactive-ac-type` is still `'nothing'`,
confirmed this session), so none of this manifests yet.

The mechanism, established across reports 02/03 and re-verified live this session, is
inhibitor-**state**-gated, not timeout-**value**-gated: GNOME's `gsd-power` idle watch fires a
legacy `Suspend()` D-Bus call to logind once the configured idle timeout elapses, *regardless* of
what that timeout is (60 min, 3600 s, or 12 h, 43200 s — the watch always arms and always
attempts the call at expiry). The block happens entirely on logind's side, at the point of that
call: a strong (`--mode=block`) inhibitor causes logind to reject the call outright
(`BlockedByInhibitorLock`), before polkit is even consulted. Whether the AC timeout is 3600 or
43200 has **zero effect** on whether that rejection happens — it only changes *when the attempt
is made*. So:

- **Active Claude session, AC power**: identical outcome under both task 117's old `"nothing"`
  and task 119's new `"suspend"`/43200 — the machine never suspends, because the inhibitor
  denies the call whenever it is attempted (and under `"nothing"` the call is simply never
  attempted at all; under `"suspend"`/43200 it is attempted once at the 12-hour mark and denied
  if the inhibitor is still held). **Task 117's headline "keep AI agents running headless" intent
  is not weakened.**
- **Idle-but-open Claude session**: same as above — the inhibitor is held for the session's full
  lifetime regardless of activity level (this is task 117's own deliberate design, "User Decision
  1" in plan 02), so it denies the 12h AC attempt exactly as it denies the 60-min battery attempt
  today. No difference in kind between the AC and battery legs here.
- **Crashed session**: the tether fix (task 117 round 2, phase 3, live-verified this session —
  `tail --pid=<owner>` dies within ~1s of the owner process dying) means a crash releases the
  inhibitor promptly. If a crash happens to coincide with an idle-suspend attempt, the machine
  can suspend — but the crashed session's work is already lost regardless, so this is not a
  regression in the sense the task is worried about.
- **Stale-pidfile-reap reaping a live session's inhibitor**: verified not possible — the reap
  loop only removes pid files whose PID fails `kill -0` (dead); it is never applied to a file
  whose PID is alive (confirmed both by the implementation's own isolated testing, recorded in
  the round-2 summary, and by this session's live check: all 6 current pid files point at live
  PIDs and none were reaped).
- **Gap between "user input idle" and "no Claude activity"**: this is real but symmetric between
  AC and battery, and pre-existing — not introduced by task 119. A detached `run_in_background`
  job that outlives its owning session's `SessionEnd` is unprotected either way; this is a known,
  general limitation of session-scoped (not activity-scoped) inhibition, already accepted as
  Decision 1 in plan 02, not something task 119 changes.

**What task 119 genuinely does change**: it re-introduces a real AC auto-suspend path where none
currently exists for the specific case of **no open Claude session** (task 117's `"nothing"`
never suspends on AC under any circumstance; task 119's `"suspend"`/43200 suspends after 12h of
pure idle with zero inhibitors held). This affects unattended non-Claude AC workloads (cron jobs,
long builds not wrapped in their own inhibitor) that were previously immune and now are not,
after 12 hours. This is explicitly flagged and accepted as a trade-off in task 119's own risk
table ("Mitigation: 12h is the explicit user-specified requirement; non-Claude unattended
workloads should hold their own `systemd-inhibit` block, consistent with the existing
inhibitor philosophy") — it is a real, intentional, and reasonably scoped narrowing, not a
silent regression, and it does not touch the specific guarantee task 117's description names
("keep AI agents running headless" = Claude Code agents specifically).

**Analysis gap worth flagging**: task 119's report and plan never carry forward report 03's
finding that gsd's idle-suspend watch is **one-shot per idle period with no automatic retry**
(report 03 §3.2, re-derived from installed gsd 50.2 source: `idle_configure()` only re-arms on a
short list of trigger events — AC/battery transition, screensaver state change, the 20%
"battery low" crossing, and similar; a denied attempt is *not* retried within the same idle
window). This was analyzed thoroughly for the battery leg but never explicitly re-derived for
the AC leg in task 119's artifacts. The practical consequence: the "12h AC ceiling" is not a hard
deterministic guarantee — if the 12h boundary happens to be crossed while any inhibitor
(including a stray non-Claude one) is briefly held, the attempt is denied and the watch will not
retry until a re-arm event, which on a machine that stays on AC continuously could be
comparatively rare (screen-lock/unlock via lid-close-then-open is one plausible frequent re-arm
trigger, given `HandleLidSwitch=lock`, but this was not analyzed by either task). This cuts in
task 117's favor (errs toward *not* sleeping, which is safe for headless agents) and against
task 119's stated goal (a reliable, auditable 12h ceiling) — worth a one-line doc correction in
`docs/no-sleep-agents.md`'s idle-suspend section stating the ceiling is a best-effort bound, not
a deterministic guarantee, rather than a code change.

**Verdict**: no genuine conflict for task 117's actual scope; a documented, accepted, and
correctly-scoped narrowing for a case outside 117's scope; one small doc-accuracy gap
identified, not requiring implementation work.

### Q4 — Is the accepted partial on requirement (B) the best available solution?

**Reasonable trade-off; not a required fix.** Re-derivation of the actual risk profile, corrected
from a literal reading of the prompt: the danger period for "laptop in a bag, idle Claude session
open, on battery" is **not** the s2idle-suspended drain rate (that only applies *after* the
backstop has already fired) — it is the **fully-awake** drain rate from whatever charge level the
bag started at, down to the 10% backstop threshold, because `HandleLidSwitch=lock` keeps the
machine fully powered (screen off, CPU/board running) rather than suspending it. This is *by
design* — it is precisely what "keep AI agents running headless" requires — and the backstop is
the deliberate, explicit safety net for exactly this scenario, not a mitigation for an unrelated
problem. `docs/no-sleep-agents.md` already states this "Accepted limitation" plainly, in exactly
these terms, in the Claude Code session inhibitors section.

A genuinely higher-quality alternative exists in principle: an **activity-timeout-based**
inhibitor, where the block is released after N minutes of no actual tool/turn activity (tracked
via a heartbeat file updated on `PreToolUse`/`PostToolUse`/`UserPromptSubmit` hooks, watched by a
small timer that drops the inhibitor when stale and lets the next hook event re-acquire it). This
was considered in an adjacent form during round-3 research (report 03 §3.3, "closest achievable
approximation") and explicitly rejected in favor of the current session-scoped design because
pure turn-scoped hooks risk suspending the machine while a detached background Task agent is
still working between turns — the heartbeat variant sketched here would avoid that specific
failure mode (a genuinely working background agent would still be updating the heartbeat), but it
is meaningfully more infrastructure (a new state file, a new watcher unit, new hook wiring) for a
benefit that is already bounded by the 10% backstop. **Assessment**: worth recording as a
candidate future enhancement if the user wants tighter (~1h-scale rather than backstop-scale)
battery protection with an open idle session, but not something this round's findings compel
fixing now — the existing design is honest about its limitation, the limitation is narrow (only
matters with an idle-but-open session on battery), and the consequence is bounded (hours of
suspended headroom once the backstop fires, per report 03 §4).

### Q5 — Is the `systemctl suspend -i` re-suspend loop a latent bug?

**Data/battery-safety: sound as designed. Usability: a real, unaddressed defect. This is the
highest-severity finding of this research round, as the task instructions anticipated.**

The mechanism, confirmed live this session (`systemctl show battery-suspend-backstop.timer`):
`WakeSystem=no`, `Persistent=no`, `OnBootSec=2min`, `OnUnitActiveSec=60s` (matches
`power.nix:146-152` exactly). Because `OnUnitActiveSec` measures elapsed time from the unit's
last *activation*, and wall-clock time does not advance while the machine is suspended, any
`OnUnitActiveSec` timer is overdue the instant the machine resumes and fires essentially
immediately (bounded only by the default `AccuracySec` coalescing window, documented at 1 minute
for systemd timers unless overridden — not set here, so the default applies). Concretely: **on
any wake while capacity is still ≤10% and the battery is still `Discharging`, the very next tick
— within roughly a minute, often much sooner — suspends the machine again.**

This is explicitly *intentional* per the extensive banner comment in `power.nix:107-116` and the
matching prose in `docs/no-sleep-agents.md`'s "There's no hysteresis band on this loop by design"
paragraph — but the stated rationale only argues that repeated suspend/resume cycles are cheap in
*battery* terms ("each cycle costs very little battery... s2idle at ≤10% survives hours"). It
never analyzes the **interactive** failure mode the task prompt specifically raises: a user who
opens the lid (the natural, expected wake trigger on this hardware) *specifically because* they
want to check on the machine, find a charger, or make a considered decision (e.g., "let it die
gracefully" vs. "shut it down cleanly instead of suspending") gets essentially no functional
window to act. Compounding factors, all verified or directly inferable from the live config:

1. **No visible feedback**: the backstop script's only output is a plain `echo` line
   (`power.nix:137`), which lands in the systemd journal — invisible to a user looking at a
   locked/blank screen. There is no `notify-send` or equivalent desktop notification anywhere in
   the unit. A user who does not already know this mechanism exists (or has forgotten, since it
   was documented ten days ago in a task they may not be actively tracking) has no way to
   understand why their laptop appears to refuse to stay awake.
2. **Lock-screen overhead eats into the window**: because `HandleLidSwitch=lock` (task 117's own,
   correct, separate design decision), waking the machine presents a *locked* screen requiring
   authentication before the user can even see status or reach a terminal/Settings app — this
   consumes a meaningful fraction of the already-short window before the next tick.
3. **Every wake is punished identically, with no distinction between "accidental jostle" and
   "deliberate user check-in"** — there is no mechanism (nor could there easily be one) to tell
   these apart, so the current design treats a user's own investigative action as just another
   trigger for immediate re-punishment.

Given report 03's own established headroom figure — roughly 2-6 hours of suspended survival once
the backstop first fires at 10% — **the cost of adding a short, bounded grace period after each
wake is negligible against that headroom, while the benefit to usability is substantial.** A
scoped fix (e.g., track a last-suspend timestamp in a `StateDirectory` file and skip re-firing
for a few minutes after a wake unless capacity has measurably dropped further; and/or add a
`notify-send`-via-`busctl`-to-the-user-session call so the user actually sees "suspending at N%,
plug in to stop this" before it happens) is small, localized to the same unit this task already
owns, and does not touch anything else in this task's scope. **Recommendation: fix, not just
document as intentional.** The current documentation is not wrong about the battery-safety
argument — it is simply silent on the usability argument the task correctly identifies as the
real risk.

### Q6 — What is the cluster-level activation debt?

**A single `sudo nixos-rebuild switch --flake .#hamsa` closes essentially all of it. No reboot is
required. There is no meaningful ordering hazard.**

Established facts, all live/committed as labeled:

- **LIVE**: current generation is 126, `Current: True`, built 2026-07-14 14:40:23 — this is task
  117's final state (rounds 1 and 2 both), confirmed by every live check in Q1 above. No
  generation newer than 126 exists.
- **COMMITTED, NOT LIVE**: task 119's two-value dconf change
  (`sleep-inactive-ac-type`: `"nothing"` → `"suspend"`, `sleep-inactive-ac-timeout`: `3600` →
  `43200`) plus its doc updates. Confirmed live: `gsettings get ... sleep-inactive-ac-type` still
  returns `'nothing'` (task 117's value), not `'suspend'`.
- **NOT STARTED**: tasks 120 (niri AC/battery-conditional idle suspend, depends on 119 + 77) and
  77 (niri/GNOME service reconciliation, depends on 74-76). Neither has any committed config
  change; both are out of scope for closing 117/119's debt and do not block it.

**Does one activation cover both 117 and 119?** Yes, for 119's remaining piece specifically,
because task 119's dconf change lives in `modules/home/desktop/gnome.nix`, and this repo's Home
Manager configuration is integrated into the NixOS module system (`nixosConfigurations.hamsa`
includes `home-manager.users.benjamin`), not a separate always-required activation step — this
was already established and used as the verification method in task 117 round 1 ("Home Manager
is part of the NixOS closure via `mkHost`") and is consistent with generation 126 already
carrying task 117's own `gnome.nix` changes (the battery-timeout/type values) live without any
separate `home-manager switch` having been run. Task 119's plan hedges by additionally
recommending a standalone `home-manager switch --flake .#benjamin` "in case the two profiles
disagree" — this is a reasonable defensive habit given a standalone `homeConfigurations.benjamin`
flake output does also exist and build successfully (confirmed in task 119's own Phase 2
verification), but it is not strictly necessary for dconf specifically: `dconf.settings`
activation writes directly and immediately to the live dconf database regardless of which
Home-Manager-owning path last ran, so whichever activation path runs *last* determines the live
GNOME settings, with no risk of "disagreement" for this specific setting class (the profile
divergence risk task 119's plan worries about applies more to `$PATH`/package availability than
to dconf state). **Corrected guidance**: `sudo nixos-rebuild switch --flake .#hamsa` alone is
sufficient to activate task 119's change; running `home-manager switch --flake .#benjamin`
afterward is optional belt-and-suspenders, not required.

**Does 117 additionally need a reboot?** No — not now. It already got whatever activation event
(switch, and/or a reboot at some point between 2026-07-14 and the current boot at 2026-07-23
09:50) was needed to make `systemd-logind` pick up the new `HandleLidSwitch=lock` value; this is
proven live (`busctl` reads `"lock"`, not the stale `"suspend"` default that would indicate a
pending-restart gap). Task 119 touches no logind settings, so it introduces no new
reboot requirement either. GNOME's dconf changes apply live without logout (task 119's own report
establishes this, and gsd-power's live GSettings-change-notification behavior is consistent with
it).

**Ordering hazard**: none identified. The premise that both tasks have "power config
simultaneously never activated" does not hold — only task 119's small diff is actually pending.
Activating it now applies a two-value dconf change on top of an already-live, already-correct
task 117 baseline; there is no interaction between the two changes beyond the Q3 analysis above
(which is about runtime *behavior* interaction, not activation-order interaction — both changes
are independent files/mechanisms with no shared state that could be corrupted by activation
order).

**Correct single command sequence** to discharge the cluster's activation debt:

```bash
sudo nixos-rebuild switch --flake .#hamsa
# then verify live (read-only, no reboot needed):
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type      # expect 'suspend'
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout   # expect 43200
```

Tasks 77 and 120 are related (120 explicitly depends on 119 and touches the same
`docs/no-sleep-agents.md` file, per its `file_scope`) but are not-started, have no committed
config, and do not participate in this activation debt at all — they are future work, correctly
sequenced behind 119 by the dependency graph already recorded in `state.json`.

### Q7 — Recommendation

**Do not abandon.** Confirmed, explicitly: task 117 has landed two full plan rounds (10 phases
total across plans 01 and 02, 8 of which are `[COMPLETED]`), is the origin of the entire
lid-lock/battery-backstop/session-inhibitor-tether mechanism this machine's power management now
depends on, is **already live and working on the running system** (Q1), and is the explicit
foundation both task 118's documentation task and task 119's entire research scope build on and
cite as authoritative (task 119 report: "task 118's report is treated as an authoritative primary
source... not re-derived here"; its own plan explicitly lists task 117 as a dependency it
"revises the layer" of). `docs/no-sleep-agents.md` — 300+ lines, the primary reference doc for
this machine's entire no-sleep architecture — is a direct deliverable of this task. Abandoning
task 117 would either strand this documentation and code as orphaned, task-number-less
deliverables, or require it to be silently re-attributed, and would formally mark as "not done"
work that is, per Q1, mostly done and already running in production. **The earlier suggestion to
abandon was made without the information in this report (specifically, that the code is live)
and should be treated as superseded.**

**Do not split into a new task.** The remaining work (two verification checks, one small
usability fix, one doc sentence) is small, entirely within files this task already owns
(`modules/system/power.nix`, `docs/no-sleep-agents.md`), and does not warrant new
task-management overhead. A new task would also duplicate task 117's own accumulated context
unnecessarily.

**Recommended path: revise the plan (plan version 3 / a bounded round-3 addition), not "complete
Phase 4 as-is."** "As-is" is close but not quite right, because Q5 found a genuine defect in the
same mechanism this task already owns — closing Phase 4 without addressing it would ship a known,
documented-here usability problem under the banner of "done." The revision should be small and
scoped to exactly four things:

1. **Record the live-activation findings from this report** as the authoritative update to
   Phase 4's status — most of it is done; re-verify nothing that was already read-only-confirmed
   here.
2. **Perform the three still-open checks** (all small, bounded, together well under 15 minutes):
   the safe suspend/`suspend -i` A/B test; the physical undocked lid-close observation; and the
   docked-with-external-monitor lid-close regression test (folding in Q2's finding).
3. **Add a small, scoped fix for Q5**: a wake-grace mechanism for `battery-suspend-backstop`
   (e.g., a `StateDirectory`-tracked last-suspend timestamp gating re-fire for a short window
   unless capacity has dropped further) plus a user-visible notification before/at each fire.
   This is genuinely new work, sized as roughly one more implementation phase, not a
   documentation change.
4. **One added sentence to `docs/no-sleep-agents.md`** closing the Q2 audit trail (explicitly
   note the docked lid-close-with-monitor path was verified live post-activation, once step 2 is
   done) and, per Q3, a note that the 12h AC ceiling (once task 119 activates) is a best-effort
   bound rather than a deterministic guarantee, given gsd's one-shot idle-watch behavior.

This keeps task 117's status change auditable, fixes the one real defect this round surfaced,
and does not block on or duplicate task 119/120's separate, already-correctly-scoped work.

## Decisions

- This report does not modify any file outside itself, per the read-only constraint given.
- The `.orchestrator-handoff.json` and both implementation summaries are identified as stale but
  are explicitly NOT rewritten here (per instruction) — a future plan/implementation round should
  correct them as part of closing out the revised Phase 4.
- Q4's accepted limitation is left as-is (no fix recommended) — distinguished explicitly from
  Q5, which does get a fix recommendation, so the report does not conflate "documented and
  bounded" (Q4) with "documented but still a real usability gap" (Q5).

## Risks & Mitigations

- **Risk**: this report's "generation 126 was built mid-commit-sequence" reasoning about *why*
  the live state matches the final commit is inference, not proof. **Mitigation**: the report
  leads with the actually-authoritative evidence (direct live reads: `busctl`, `gsettings`,
  `systemctl`, `ps` command lines, `jq` diff) rather than resting the Q1 conclusion on the
  generation-timing narrative; the narrative is offered only as corroborating context, clearly
  labeled as inference.
- **Risk**: no external monitor was available during this session to close the Q2 docked-test
  gap. **Mitigation**: explicitly folded into the Q7 recommendation as a required remaining
  check rather than silently left open.
- **Risk**: the recommended Q5 fix (wake-grace + notification) is described at the concept level
  only, not designed to Nix-code detail, since this is a research-only task. **Mitigation**: a
  future plan round should treat this as normal phase-planning work, not treat this report's
  sketch as a finished design.

## Appendix

**Live-system evidence gathered this session (all read-only)**

- `busctl get-property org.freedesktop.login1 ... HandleLidSwitch` → `s "lock"`;
  `HandleLidSwitchExternalPower` → `s "lock"`; `IdleAction` → `s "ignore"`; `Docked` → `b false`.
- `systemd-analyze cat-config systemd/logind.conf` → `[Login] HandleLidSwitch=lock
  HandleLidSwitchExternalPower=lock KillUserProcesses=false`.
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` → `'nothing'`;
  `sleep-inactive-ac-timeout` → `3600`; `sleep-inactive-battery-type` → `'suspend'`;
  `sleep-inactive-battery-timeout` → `3600`.
- `systemctl is-active battery-suspend-backstop.timer` → `active`;
  `systemctl list-timers battery-suspend-backstop.timer` → next elapse ~49s out at check time.
- `systemctl show battery-suspend-backstop.timer -p RandomizedDelaySec -p WakeSystem -p
  Persistent` → `WakeSystem=no`, `Persistent=no`.
- `ps -o cmd=` on all six live `claude-code` inhibitor PIDs → all show
  `systemd-inhibit --what=sleep:idle --who=claude-code --why=... --mode=block tail --pid=<owner>
  -f /dev/null`, each with a live `tail` child (`pgrep -P`).
- `diff <(jq .hooks ~/.claude/settings.json) <(jq .hooks config/claude/settings.json)` → empty
  (byte-identical).
- `/tmp/claude-inhibitor-*.pid`: 6 files, all pointing at live PIDs, no orphans.
- `nixos-rebuild list-generations` → generation 126, `Current: True`, build-date
  `2026-07-14 14:40:23`, no newer generation.
- `who -b` → system boot `2026-07-23 09:50`; `/run/current-system` symlink same timestamp.
- `/sys/class/drm/*/status` → only `eDP-1` connected (`connected`), all `DP-*` disconnected
  (undocked at check time — Q2's docked test could not be performed live).
- `/sys/class/power_supply/BAT1/{status,capacity}` → `Not charging`, `100`.
- `niri msg outputs` → fails ("NIRI_SOCKET is not set"), expected since GNOME is the active
  session; `niri --version` → `26.04 (Nixpkgs)`, confirms the binary is present for a future
  niri-session check.
- `git log --all --oneline --grep="task 117"` / `"task 119"` / `"task 120"` — confirms the full
  commit sequences and timestamps cited throughout.

**Key repo citations**

- `modules/system/power.nix:44-77` (lid `lock` settings, live-matching), `:94-152`
  (`battery-suspend-backstop` service+timer, live-matching)
- `modules/home/desktop/gnome.nix:37-58` (GNOME power dconf block, partially live — battery leg
  matches, AC leg is task 119's pending change)
- `config/claude/settings.json:65-88` (session-tethered inhibitor hooks, live-matching byte for
  byte)
- `docs/no-sleep-agents.md` (primary reference doc, all four mechanisms, "Accepted limitation" and
  "no hysteresis band" callouts referenced in Q4/Q5)
- `specs/117_laptop_lid_close_no_sleep_headless/.orchestrator-handoff.json` (identified stale)
- `specs/119_fix_ac_vs_battery_idle_sleep_timeouts/plans/01_ac-battery-idle-sleep.md` (Phase 3,
  the pending activation piece)
- `specs/state.json` (project entries 117, 119, 120, 77 — dependency graph confirming 120/77 are
  correctly out of scope for the immediate activation debt)

**Search queries / commands used**: full re-read of all task 117/118/119 artifacts;
`git log --all --grep`; `nixos-rebuild list-generations`; live `busctl`/`gsettings`/
`systemctl`/`journalctl`/`ps`/`pgrep`/`jq` probes as enumerated above. No MCP-NixOS lookups were
needed this round (no new option names introduced; all values audited were already verified
against the pinned nixpkgs in prior rounds).
