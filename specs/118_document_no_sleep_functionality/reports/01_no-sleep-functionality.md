# Research Report: Task #118

**Task**: 118 - document_no_sleep_functionality
**Started**: 2026-07-14T15:38:15-07:00
**Completed**: 2026-07-14T16:05:00-07:00
**Effort**: ~30 min research (synthesis of existing task-117 artifacts + live/source verification)
**Dependencies**: task 117 (laptop_lid_close_no_sleep_headless) — this task documents that
  task's already-implemented functionality; no new config changes are researched or proposed
**Sources/Inputs**: `specs/117_laptop_lid_close_no_sleep_headless/{reports,plans,summaries,handoffs}/*`
  (primary source — read in full), current repo files (`modules/system/power.nix`,
  `modules/home/desktop/gnome.nix`, `config/config.kdl`, `config/claude/settings.json`,
  `modules/home/memory/services.nix`), current `docs/` tree, live read-only system probes
  (`busctl`, `gsettings`, `systemctl list-timers`), git log for task 117
**Artifacts**: specs/118_document_no_sleep_functionality/reports/01_no-sleep-functionality.md (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The "no-sleep for AI agents" functionality is **already fully implemented** (task 117, 9
  commits, `e470796`..`417defc`) but is **not yet consolidated as its own documentation
  topic**. It is currently split across `docs/gnome-settings.md` (most of it, under "Power
  Management" and a "Lid-Close Behavior" subsection) and `docs/niri.md` (one paragraph). There
  is no single page a user/future-agent can read to understand the whole system end to end,
  and no page documents the Claude Code session-hook inhibitor mechanism itself (only its
  *effects* are mentioned in gnome-settings.md).
- The functionality has **four independent, layered mechanisms**, each owning a different
  failure mode: (1) Claude Code session-lifetime `systemd-inhibit` locks (blocks idle-suspend
  and ordinary suspend while a session is open), (2) GNOME/logind idle and lid settings tuned
  so nothing auto-sleeps while agents might be running, (3) a niri-session equivalent
  (swayidle, lid handled natively), and (4) a **root-level battery-backstop timer** that
  deliberately *bypasses* inhibitors at ≤10% battery so the machine doesn't die with the lid
  shut in a bag.
- **Activation status is a key fact for the docs**: `modules/system/power.nix`,
  `modules/home/desktop/gnome.nix`, and `config/config.kdl` changes are all committed, and a
  live check this session shows the Home Manager (dconf) settings and the
  `battery-suspend-backstop.timer` **are live** (`sleep-inactive-ac-type` = `'nothing'`,
  `sleep-inactive-battery-type` = `'suspend'`/3600, timer `active`) — but the **system-level
  logind lid setting is NOT yet live**: `busctl get-property … HandleLidSwitch` still returns
  `"suspend"` (stock default), not the configured `"lock"`. This means `nixos-rebuild switch`
  has been run (the timer/service exist) but `systemd-logind` has not been restarted since
  (or a subsequent flake change reset it) — the lid-close-never-suspends guarantee is
  **currently NOT in effect on the live system** and this must be flagged prominently in any
  doc written from this research, with the fix (`sudo systemctl restart systemd-logind` or
  reboot, then re-verify via `busctl`).
- The recommended doc structure (see "Documentation Targets" below): create one new
  consolidated page, `docs/no-sleep-agents.md` (or similarly named), that explains the full
  layered system and the Claude Code hook mechanism, and turn the current
  `docs/gnome-settings.md` Power Management content into a shorter section that cross-references
  it (matching this repo's documented "Inline vs. docs/" and "Adding new docs/ files"
  conventions in `docs/README.md`).

## Context & Scope

Task 118 asks only for **research to support later documentation writing** — no docs are
created by this report. The goal is to hand a future documentation-writing pass everything
needed: the mechanisms, exact file locations and current values, the activation/testing
story, and how the pieces cohere, without that writer needing to re-derive the (extensive)
task-117 forensics from scratch.

Task 117's three research rounds already did the hard forensic work (mutter/gsd/systemd/UPower
source-level verification). This report does **not** repeat that forensic method — it
synthesizes the findings into a documentation-ready shape and adds current-state verification
(git log, live probes, present file contents) that task 117's artifacts predate.

## Findings

### 1. The four mechanisms, in the order a reader should encounter them

**(1) Claude Code session inhibitors — the everyday, per-session layer**

- File: `config/claude/settings.json` (deployed to `~/.claude/settings.json` via the
  activation-script copy in `modules/home/core/dotfiles.nix`).
- `SessionStart` hook (async): reaps stale inhibitor pid files, then runs
  `systemd-inhibit --what=sleep:idle --who=claude-code --why="Claude Code session" --mode=block tail --pid=$PPID -f /dev/null`
  in the background, recording its PID in `/tmp/claude-inhibitor-${SESSION_ID}.pid`.
  - The inhibitor payload was changed from `sleep infinity` to `tail --pid=$PPID -f /dev/null`
    in task 117 phase 3 (commit `29fdd1f`) specifically so the inhibitor process is tethered to
    the owning `claude` process and dies automatically if the session crashes/is killed,
    instead of surviving (as an orphan reparented to `systemd --user`) until reboot.
  - `$PPID` inside the hook shell was empirically verified (task 117 report 03) to resolve
    directly to the owning `claude` process (no ancestor-walk needed on this deployment).
- `SessionEnd` hook (async): kills the recorded inhibitor PID and removes the pid file (fast
  release path; the tether above is the slow/self-healing path).
- Effect: while a Claude Code session is open (even sitting idle at the prompt — this is
  **session-scoped, not activity-scoped**), a `sleep:idle` **block** inhibitor is held. This
  blocks: (a) GNOME's idle-triggered suspend (both AC and battery, when the watch fires), and
  (b) any ordinary/interactive `systemctl suspend` call system-wide. It does **NOT** block the
  lid-switch action (see mechanism 2) and does **NOT** block the battery backstop (see
  mechanism 4 — by design).
- Known accepted limitation (task 117 decision): an idle-but-open Claude terminal blocks the
  60-minute battery idle-suspend indefinitely; only the 10% backstop protects battery life in
  that case. This is intentional, not a bug, per the task-117 user decision recorded in
  `specs/117_.../summaries/02_battery-level-backstop-summary.md`.
- A related, currently-**disabled** mechanism exists in `modules/home/memory/services.nix`
  (commented-out `claude-sleep-inhibitor` service, disabled since task 50 because
  `pgrep -f 'claude'` self-matched other processes and caused permanent sleep blocking) — worth
  a one-line "why not this" mention if docs cover history, but not part of the live system.
- A manual, user-toggled inhibitor also exists via a Neovim `<leader>rz` keymap, referenced in
  `docs/gnome-settings.md`'s existing Note, and a waybar `idle_inhibitor` module
  (`docs/niri.md:881-888`, niri session only) that shows/toggles idle-inhibit state. Grep of the
  live nvim Lua config for the `<leader>rz` binding and any `systemd-inhibit`/`inhibit` call
  turned up nothing in this repo tree — the doc's claim could not be corroborated against source
  in this pass (nvim config may live outside this repo, or the binding may be stale). Flag this
  as **unverified / possibly stale** for the documentation writer to check directly with the
  user or drop if no longer accurate, rather than propagating it uncritically into a new page.

**(2) GNOME/logind system-and-session settings — the structural "never sleep unless told" layer**

- `modules/system/power.nix` — `services.logind.settings.Login`:
  ```nix
  logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
  };
  ```
  - Lid close **locks** the session but never suspends, regardless of AC/battery or whether
    an external monitor is attached (undocked case). `HandleLidSwitchDocked` is deliberately
    left at its systemd default (`ignore`), since docked (>1 display, or docking station) is
    already handled by GNOME's own `gsd-power` `handle-lid-switch` block inhibitor (an
    unrelated, pre-existing GNOME mechanism, not repo-configured) — so external-monitor
    behavior is untouched.
  - **Why `lock` and not `ignore`** (this is the single most important nuance for docs to get
    right, and the one place task 117's own first-round research was wrong and had to be
    corrected in round 2): mutter (GNOME's compositor, source-verified at the installed
    version 50.2) deliberately keeps the internal eDP panel **active** when it is the *only*
    monitor, even with the lid closed — it refuses to leave the session with zero outputs.
    Under plain `ignore`, the panel would stay lit and rendering *inside the closed lid* until
    the ordinary 5-minute idle blank fires (and could re-light later on an undock-while-closed
    edge case). `lock` avoids this: logind's `lock` action never suspends anything, and after
    locking, GNOME powers the internal panel off ~30 seconds later via gsd-power's
    screensaver blank timeout. The niri session's existing swayidle `lock` handler
    (`config/config.kdl`) covers the same signal there.
  - Sleep inhibitors (mechanism 1) do **not** protect against lid-close suspend — this is
    `LidSwitchIgnoreInhibited=yes`, logind's own default, meaning the lid action ignores
    ordinary `sleep` inhibitors. This is why mechanism 2 (a logind *action* setting, not an
    inhibitor) is the only reliable lid protection, and is worth explicitly stating in docs to
    prevent a future reader from assuming Claude's inhibitors alone are sufficient.
- `modules/home/desktop/gnome.nix` — `dconf.settings`, `"org/gnome/settings-daemon/plugins/power"`:
  ```nix
  sleep-inactive-ac-type = "nothing";        # AC: never auto-suspend on idle
  sleep-inactive-ac-timeout = 3600;          # inert given the type above; left in place
  sleep-inactive-battery-timeout = 3600;     # battery: 60 min idle (was 900s/15min pre-task-117)
  sleep-inactive-battery-type = "suspend";   # explicit, was implicit schema default before
  idle-dim = true;
  ```
  and `"org/gnome/desktop/session"`: `idle-delay = 300` (5-minute screen dim/blank —
  unrelated to sleep, untouched by task 117, still governs the visual blank).
  - AC idle-suspend is fully disabled (`"nothing"`) — a plugged-in machine never auto-suspends
    regardless of inhibitors.
  - Battery idle-suspend is retained (60 minutes, up from the pre-task-117 default of 900s/15
    minutes) as a courtesy/battery-protection measure, but **only fires when no logind block
    inhibitor is held** — i.e., it is inert whenever a Claude Code session is open (mechanism
    1), which is the norm while agents work. This is why mechanism 4 (the bypass backstop)
    exists.
  - This idle-suspend watch is also **one-shot per idle period** (verified from gsd-power
    source): if it is denied once (inhibitor held) it does not retry until a sparse re-arm
    event (AC/battery transition, screensaver state change, battery-low threshold crossing at
    20%, etc.) — worth mentioning if the doc explains "why did it not sleep even after I
    thought the inhibitor was gone."

**(3) niri-session equivalent — same intent, different mechanism**

- `config/config.kdl` (deployed via `modules/home/core/dotfiles.nix`), swayidle spawn line:
  ```
  spawn-at-startup "swayidle" "-w" "timeout" "300" "swaylock -f" "before-sleep" "swaylock -f" "lock" "swaylock -f"
  ```
  Locks after 5 minutes idle and on `before-sleep`/`lock` signals. Task 117 phase 3
  (commit `184db8e`) **removed** a pre-existing `"timeout" "600" "systemctl suspend"` clause
  that used to auto-suspend the niri session after 10 minutes idle — this was the one active
  auto-suspend path in the niri session and is now gone, matching the GNOME-session policy.
- Lid handling in niri needs **no separate configuration**: niri natively turns the internal
  monitor off/on in sync with the lid switch (verified against upstream niri wiki
  "Configuration: Switch Events"), independent of logind's `HandleLidSwitch` value. The
  `lock` value at the logind layer still applies (niri doesn't override logind), and
  swayidle's existing `lock` handler responds to it.
- Practical implication for docs: the niri session has **zero idle-based auto-suspend** at
  all (only manual/explicit suspend), which is a slightly different guarantee than the GNOME
  session's 60-minute-battery-idle-suspend-when-uninhibited. Both sessions share the same lid
  behavior and the same mechanism-4 battery backstop (which is system-level, session-agnostic).

**(4) Battery-level suspend backstop — the inhibitor-bypassing safety net**

- File: `modules/system/power.nix`, `systemd.services.battery-suspend-backstop` +
  `systemd.timers.battery-suspend-backstop`.
- Mechanism: a root-owned oneshot service, triggered every 60 seconds by a timer
  (`OnBootSec = "2min"; OnUnitActiveSec = "60s"`), that globs `/sys/class/power_supply/BAT*`
  (deliberately **not** a broader `power_supply/*` glob — this host has a peripheral
  `hid-*-battery` device that perpetually reports `Discharging 100` and would false-trigger),
  and if `status == "Discharging"` and `capacity <= 10`, runs
  `systemctl suspend -i` (the `-i` flag maps to `SuspendWithFlags(SD_LOGIND_SKIP_INHIBITORS)`,
  source-verified against systemd 260) — a call that **skips every ordinary sleep inhibitor**,
  including Claude Code's, and succeeds because root is polkit-authorized for it.
- Why this exists at all (the key "why" for docs): task 117 round 3 proved, from installed
  UPower 1.91.1 and systemd 260 source plus live journal evidence (7 `BlockedByInhibitorLock`
  denials already in this boot's journal), that the machine's pre-existing "safety net" —
  UPower's built-in `CriticalPowerAction = HybridSleep` at 2% battery
  (`/etc/UPower/UPower.conf`) — is an **illusion** while any Claude Code inhibitor is held:
  UPower's own critical-battery call is an ordinary (non-bypassing) sleep call, gets rejected
  outright by logind under a strong block inhibitor, is **never retried**, and the battery
  would drain straight through to hard power-off. UPower's 2% setting is left unchanged in
  the repo (harmless, and still fires in the no-inhibitor case) but is **not load-bearing** —
  the 10% timer is the actual protection and should be described as such, not as a redundant
  backup.
- Threshold rationale: 10%, not UPower's 2%, because suspend on this hardware (Framework 13
  AMD, s2idle only — no deep S3 state exists on this platform) still drains ~1.5-3%/h even
  while suspended, and hibernate/HybridSleep were evaluated and rejected as unreliable on this
  machine (16 GiB swapfile vs up to ~28 GiB routinely-used RAM under agent workloads — image
  allocation at hibernate-entry time is not dependable). 10% leaves hours of s2idle headroom
  instead of minutes.
- Design notes worth carrying into docs: no `ConditionACPower` (the sysfs `status` string is
  the authoritative AC/battery gate, verified against live string values `"Charging"` /
  `"Not charging"` / `"Discharging"`); no hysteresis band — the loop deliberately re-suspends
  on every tick after each wake while still ≤10% and discharging, which *is* the protection,
  not a bug; escape hatches are plugging in (leaves `"Discharging"` state) or
  `systemctl stop battery-suspend-backstop.timer` for a deliberate low-battery working
  session (auto-re-enabled at next boot/`nixos-rebuild switch`).

### 2. How the four mechanisms compose (the cross-cutting story a consolidated doc must tell)

| Scenario | What fires | What doesn't |
|---|---|---|
| AC power, Claude session open, lid open | Nothing sleeps (AC idle-suspend disabled outright) | — |
| AC power, no Claude session, lid open, idle 60 min | Nothing (AC idle-suspend type is `"nothing"` unconditionally, session or not) | — |
| Battery, Claude session open (inhibitor held), idle 60 min | Idle-suspend watch fires but is **denied** by logind (`BlockedByInhibitorLock`); no retry until a sparse re-arm event | Machine stays awake |
| Battery, no Claude session, idle 60 min | Idle-suspend succeeds; machine suspends normally | — |
| Lid closed, any power source, any monitor state, no external monitor | Session **locks**; panel powers off ~30s later (GNOME) or immediately (niri, native); machine never suspends | Suspend |
| Lid closed, external monitor(s) attached | gsd-power's own `handle-lid-switch` inhibitor (+ logind's docked default) — unchanged, pre-existing GNOME behavior, no repo config involved | logind `lock`/suspend action |
| Battery ≤10% and discharging, regardless of inhibitors, regardless of lid/session state | `battery-suspend-backstop` timer fires `systemctl suspend -i`, bypassing all inhibitors; repeats every ~60s until plugged in | UPower's 2% HybridSleep action (denied/ineffective under inhibitors, not load-bearing) |

### 3. Current activation status (live-verified this session, 2026-07-14T15:39 PDT — important, time-sensitive fact for the doc)

| Setting | Expected (per committed config) | Live value observed | Status |
|---|---|---|---|
| `HandleLidSwitch` (logind, via `busctl get-property org.freedesktop.login1 … HandleLidSwitch`) | `"lock"` | `"suspend"` | **NOT ACTIVE** — logind has not picked up the new `/etc/systemd/logind.conf` (needs `sudo systemctl restart systemd-logind` or a reboot after the `nixos-rebuild switch` that wrote the file) |
| `sleep-inactive-ac-type` (gsettings) | `'nothing'` | `'nothing'` | Active |
| `sleep-inactive-battery-type` / `-timeout` (gsettings) | `'suspend'` / `3600` | `'suspend'` / `3600` | Active |
| `battery-suspend-backstop.timer` | `active`, ticking every 60s | `active`, next elapse ~56s out | Active |

**Implication for the documentation writer**: the doc must not claim "closing the lid never
suspends" as unconditionally true of the live system today — it is true of the *committed
configuration* but the logind piece specifically needs a restart/reboot to take effect, and
that gap is exactly the kind of thing a user could be bitten by (close the lid today,
expecting `lock`, and get `suspend` instead). Recommend the doc include a "how to verify this
is actually active" section with the `busctl` command above, mirroring the verification steps
already written in task 117's summaries (`specs/117_.../summaries/01_*.md`,
`specs/117_.../summaries/02_*.md`, and the "USER ACTIVATION CHECKLIST" in the round-2 summary).

### 4. Existing documentation (what's already written, and its gaps)

- `docs/gnome-settings.md` — "Power Management" section (lines ~20-68) is the most complete
  existing writeup: idle-delay, AC/battery idle-suspend, the battery backstop, and a
  "Lid-Close Behavior" subsection, plus a closing Note about the Neovim inhibitor and how
  inhibitors interact with idle-suspend vs the lid action. This is GNOME-session-scoped by the
  file's own title/scope, so it doesn't (and structurally shouldn't) cover the niri-session
  swayidle story or the Claude Code hook mechanism itself in depth.
- `docs/niri.md` — one bullet in the feature list (line 75: "no idle auto-suspend") and one
  paragraph after the `services.swayidle` snippet (lines ~918-923) cross-referencing the
  logind `lock` setting.
- **Gap**: no doc explains the Claude Code `SessionStart`/`SessionEnd` hook mechanism itself
  (the `config/claude/settings.json` inhibitor, the `tail --pid=$PPID` tether, the pid-file
  reaping, why it's session-scoped not activity-scoped) — this is the piece a reader most
  needs to understand "why doesn't my machine sleep while Claude is idle at the prompt," and
  it currently exists only in task-117's `specs/` artifacts, which per this repo's own
  conventions (`.claude/rules/no-task-references-in-deliverables.md`) must not be cited from
  `docs/`.
  - **Note for the writer**: any new `docs/` page must therefore explain this mechanism in its
    own words (file paths, hook names, the tether rationale) without linking to or citing
    `specs/117_.../` — that's a hard repo constraint (see `.claude/rules/no-task-references-in-deliverables.md`), already implicitly honored by the existing task-117-authored doc edits (they contain no `specs/117` references).
- **Gap**: no single page ties all four mechanisms together as one coherent "AI agents run
  uninterrupted" story with the composed-scenario table in §2 above — a reader has to piece it
  together from two files plus inline nix comments.
- `docs/README.md` documents this repo's own conventions for when to add a new `docs/` file
  vs. extend an existing one ("When a topic outgrows inline comments, create a new `docs/`
  file"), and explicitly lists the steps: add to `docs/README.md`'s index under the right
  category, cross-reference root `README.md` if user-facing, and leave `# See docs/X.md.`
  trailers in the relevant nix files. The nix files (`power.nix`, `gnome.nix`) already carry
  extensive inline banner comments but **no** `# See docs/X.md.` trailer pointing anywhere —
  a new consolidated doc should add one.

## Documentation Targets

Recommendation for the (separate, later) documentation-writing pass:

1. **New page — `docs/no-sleep-agents.md`** (name TBD by the writer; alternatives:
   `docs/power-no-sleep.md`, `docs/ai-agent-power-management.md`). Content: the four-mechanism
   breakdown (§1), the composed-scenario table (§2), the activation/verification checklist
   (§3, updated to whatever the live state is at write time), and a short "why not just X"
   section addressing the rejected alternatives from task 117 (plain `ignore` instead of
   `lock`; UPower's 2%; hibernate) — these are valuable "don't re-break this" context for
   future maintainers, phrased in the writer's own words rather than as citations.
2. **`docs/README.md`** — add the new page to the index, most likely under "Applications &
   Desktop" (adjacent to `gnome-settings.md`/`niri.md`) or a new small category if the writer
   judges it belongs elsewhere (it's arguably System/Hardware given the logind and systemd-timer
   content — writer's judgment call).
3. **`docs/gnome-settings.md`** — trim the Power Management section to a summary plus a
   cross-reference to the new page, keeping only what's specifically GNOME-dconf-scoped
   (idle-delay, the raw dconf keys) in place; move the cross-cutting narrative (why AC/battery
   differ, the backstop rationale, the lid `lock`-vs-`ignore` story) to the new page to avoid
   duplication/drift between two pages.
4. **`docs/niri.md`** — similarly trim/cross-reference rather than duplicate.
5. **`modules/system/power.nix` and `modules/home/desktop/gnome.nix`** — add a
   `# See docs/no-sleep-agents.md.` trailer near the relevant blocks (logind settings,
   battery-suspend-backstop, sleep-inactive-* dconf keys), per this repo's documented
   cross-reference convention.
6. **Root `README.md`** — optional one-line mention/link if the writer judges this
   sufficiently user-facing/notable (task 117's own doc-target guidance for the underlying
   config change explicitly said *not* to touch root README; a documentation task specifically
   about explaining the feature may reasonably reach a different conclusion — writer's call).

## Decisions

- This report treats task 117's three research reports and two implementation summaries as
  authoritative primary sources for *mechanism* and *rationale*, and adds only (a) current
  file-content/live-state verification and (b) documentation-structure analysis — it does not
  re-derive or challenge task 117's source-level forensics (mutter/gsd/systemd/UPower
  internals), which were already rigorously verified there.
- Flagged the Neovim `<leader>rz` inhibitor claim (present in `docs/gnome-settings.md` today)
  as unverified against current repo source — grep found no matching keymap or
  `systemd-inhibit` call in any `.lua` file in this tree. Recommend the documentation writer
  confirm with the user or drop the claim rather than propagate it into a new consolidated
  page without verification.
- Flagged the live activation gap (`HandleLidSwitch` still `"suspend"`, not `"lock"`) as a
  time-sensitive fact: it may already be resolved by the time documentation is written (a
  reboot or `systemctl restart systemd-logind` in between), so the doc-writing pass should
  re-run the `busctl` check rather than trust this report's snapshot.

## Risks & Mitigations

- **Doc could go stale on the activation-status claim** — mitigate by writing the verification
  *command*, not a hardcoded status, into the new doc (as task 117's own summaries do).
- **Duplication between the new page and `gnome-settings.md`/`niri.md`** if the trim step is
  skipped — mitigate by explicitly doing the trim-and-cross-reference step (target 3/4 above)
  rather than only adding the new page.
- **Citing `specs/117_...` from `docs/`** would violate
  `.claude/rules/no-task-references-in-deliverables.md` — mitigate by writing all mechanism
  explanations in the new page's own words (this report already models that pattern; task
  117's own doc edits already comply).

## Appendix

**Key repo citations**
- `modules/system/power.nix` — logind lid settings (`Lid-Close Behavior` banner) and
  `battery-suspend-backstop` service+timer (`Battery Suspend Backstop` banner)
- `modules/home/desktop/gnome.nix` — `dconf.settings."org/gnome/settings-daemon/plugins/power"`
  and `"org/gnome/desktop/session".idle-delay`
- `config/config.kdl:268-271` — niri swayidle spawn line (deployed via
  `modules/home/core/dotfiles.nix`)
- `config/claude/settings.json` — `SessionStart`/`SessionEnd` hooks (deployed to
  `~/.claude/settings.json` via `modules/home/core/dotfiles.nix`)
- `modules/home/memory/services.nix` — disabled `claude-sleep-inhibitor` (historical, task 50)
- `docs/gnome-settings.md` (Power Management + Lid-Close Behavior sections),
  `docs/niri.md:75,918-923` (existing partial documentation)
- `docs/README.md` (documentation conventions: inline-vs-docs, cross-reference trailers,
  "adding new docs/ files" procedure)
- `hosts/README.md` (hamsa = AMD Framework 13 laptop, nandi = Intel laptop, garuda = desktop;
  `power.nix` is an always-on module so the battery backstop and lid settings are inert/no-op
  on non-laptop hosts like garuda)

**Task 117 artifacts read in full** (primary sources, not re-cited from any `docs/` output):
- `specs/117_laptop_lid_close_no_sleep_headless/reports/01_lid-close-no-sleep.md` (round 1:
  logind lid mechanism discovery)
- `specs/117_laptop_lid_close_no_sleep_headless/reports/02_lid-close-screen-off-mechanism.md`
  (round 2: mutter panel-stays-lit correction, `lock` recommendation)
- `specs/117_laptop_lid_close_no_sleep_headless/reports/03_battery-level-backstop.md` (round 3:
  UPower/inhibitor-bypass forensics, backstop design)
- `specs/117_laptop_lid_close_no_sleep_headless/summaries/01_lid-close-no-sleep-summary.md`,
  `02_battery-level-backstop-summary.md` (implementation summaries, activation checklists)
- `specs/117_laptop_lid_close_no_sleep_headless/handoffs/phase-1-handoff-20260714.md`

**Live commands run this session (all read-only)**
- `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` → `s "suspend"`
- `systemctl list-timers battery-suspend-backstop.timer --no-pager` → active, ticking every 60s
- `systemctl is-active battery-suspend-backstop.timer` → `active`
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type` → `'nothing'`
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type` → `'suspend'`
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout` → `3600`
- `git log --oneline --all | grep -i "task 117"` → 14 commits from `e470796` to `417defc`
- Greps across `.lua` files for `<leader>rz` / `systemd-inhibit` / `inhibit` — no matches found
  in this repo tree (flagged as unverified in Findings §1)

**Search queries used**: repo greps for `inhibit`, `idle`, `sleep`, `suspend`,
`HandleLidSwitch`, `sleep-inactive`, `idle-delay`, `caffeine`, `no-sleep`, `nosleep`,
`systemd-inhibit`, `logind`; direct reads of all task-117 artifacts; live busctl/gsettings/
systemctl probes; no web search was needed (task 117's own rounds already did exhaustive
upstream-source verification, cited above and not re-fetched here).
