# Implementation Summary: Task #117 (Round 3) — Backstop Wake-Grace and Live Verification

**Completed**: 2026-07-25 (phases 6-7 complete; phase 8 partial, blocked on user activation)
**Duration**: ~1.5 hours

## Overview

This round fixes report 04's HIGH-severity Q5 defect: the battery-suspend-backstop had no
wake-grace period and no user-visible notification, so a user waking the machine at <=10%
specifically to plug in a charger could be re-suspended within ~60s, repeatedly, invisibly. Phase 6
adds a bounded, three-axis wake-grace window plus a lock-screen-visible critical notification to
`modules/system/power.nix`; Phase 7 lands the corresponding additive docs delta in
`docs/gnome-settings.md`; Phase 8 ran every agent-performable live check but the change itself
remains **un-activated** on the running system pending a `sudo` step only the user can run.

## What Changed

- `modules/system/power.nix` — extended the `battery-suspend-backstop` service and added a new
  `battery-backstop-wake-mark` service (`wantedBy = [ "post-resume.target" ]`, the idiom already
  proven live via `disable-speaker-amp` in `audio.nix`). Both units share
  `StateDirectory = "battery-suspend-backstop"`. The backstop script gained four named parameters
  (`threshold=10`, `grace_secs=300`, `grace_floor=5`, `grace_drop=2`), the grace-decision branch, a
  `notified` marker to avoid notification spam, a `--test-notify` mode, and a
  `pkgs.writeShellScript "battery-backstop-notify"` helper (uid discovery via `loginctl`, `runuser`
  + `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS`, `notify-send -u critical`), all wrapped in
  `timeout 5 ... || true` so a notification failure can never block or delay the suspend. The
  banner comment was extended in place (not replaced) with the defect reference, parameters, three
  bounds, fail-safe direction, and trade-off.
- `docs/gnome-settings.md` — three additive clauses: (1) the backstop cross-reference now
  mentions the wake-grace window and lock-screen notification; (2) the existing AC idle-suspend
  bullet gained one caveat sentence carrying report 03's gsd one-shot finding to the AC leg
  (best-effort bound, not a guarantee) without restating or re-litigating task 119's settled
  43200s value; (3) one sentence records the multi-monitor/docked evidence status as reasoned and
  architecturally verified but not yet re-tested live post-`HandleLidSwitch=lock`.
- Unchanged this round (already live from rounds 1-2): `modules/home/desktop/gnome.nix`,
  `config/claude/settings.json`.

## Decisions

- Notify helper implemented as a **separate `writeShellScript` derivation** invoked by path from
  the backstop script's `safe_notify()` wrapper, rather than an inline shell function — lets
  `timeout` bound it directly without `bash -c "$(declare -f ...)"` re-exec.
- Added **test-only override env vars** (`BACKSTOP_BATTERY_GLOB`, `BACKSTOP_SYSTEMCTL_BIN`,
  `BACKSTOP_NOTIFY_BIN`, plus reliance on the standard systemd-provided `STATE_DIRECTORY`), all
  defaulting to the real production paths via bash `${var:-default}` expansion. This is what makes
  the Phase 6 offline logic exercise possible without `sudo` or a stubbed
  `/sys/class/power_supply/` tree, with zero effect on the unmodified systemd-invoked production
  path.
- Grace-drop condition uses **strict inequality** (`drop < grace_drop`), so a drop of exactly 2
  points voids the grace, matching the plan's "voided once capacity has fallen this many points
  below its value at wake" language precisely (verified by offline case (f)).

## Plan Deviations

- **Phase 6, notify helper task**: altered — separate script derivation instead of an inline
  function (see Decisions above). Functionally identical; annotated inline in the plan.
- **Phase 6, script-extension task**: altered — added the three `BACKSTOP_*` test-only override
  env vars, which the plan's design section did not name explicitly but which are necessary to
  satisfy the plan's own requirement that the offline exercise use "a fake sysfs tree, a fake state
  directory, and a stubbed systemctl."
- **Phase 8, wake-path-confirmation task** ("After the user's A/B test... confirm the wake path
  worked"): skipped — this task is explicitly gated on USER CHECKLIST items 1 (activate) and 3
  (real suspend/resume cycle), neither of which is agent-performable. Not silently dropped;
  annotated in the plan and recorded here and in the orchestrator handoff as the phase's blocker.
- No other deviations. Phases 1, 2, 3, 5 were not re-touched (per the plan's explicit scope
  boundary) and remain exactly as rounds 1-2 left them.

## Verification

- `nix flake check` — **PASS** (`all checks passed!`, run after Phase 6's edits).
- `nixos-rebuild build --flake .#hamsa` — **PASS**. Built
  `/nix/store/j84p3im5jdmb4wrz74hppc20jmwbwcrd-nixos-system-hamsa-26.05.20260710.8f0500b`; 9
  derivations built (`battery-backstop-wake-mark`, `battery-backstop-notify`,
  `battery-suspend-backstop`, both unit files, `system-units`, `etc`, `activate`, the top-level
  system derivation).
- Eval checks — **PASS**:
  - `ExecStart` for `battery-suspend-backstop` resolves to the new store script; reading it
    confirms all four parameters and the unchanged `BAT*`/`Discharging`/threshold-10/`suspend -i`
    core.
  - `battery-backstop-wake-mark.wantedBy` -> `["post-resume.target"]`.
  - `StateDirectory` -> `"battery-suspend-backstop"` on **both** units.
- Offline logic exercise — **PASS, 23/23 assertions, 0 failed** (built script run against a fake
  sysfs tree, fake `STATE_DIRECTORY`, and stubbed `systemctl`/`notify-send` via env-var overrides,
  no `sudo`, no real suspend). Covered: (a) `Not charging`/`Charging` silent; (b) 11% Discharging
  silent; (c) 9% Discharging, no wake-mark, fires; (d) 9% Discharging, wake-mark 60s old,
  `wake_cap=9`, skips + notifies once; (e) same but wake-mark 400s old, fires; (f) same but
  `wake_cap=11` (2-point drop), fires; (g) 4% Discharging, fresh wake-mark, fires (below
  `grace_floor`); (h) notify helper forced to exit 1, still fires; plus notified-marker
  suppression across two ticks in one grace window (1 notify call, not 2) and `--test-notify` mode.
- Docs grep — **PASS**: `grep -n "grace\|wake-grace\|best-effort" docs/gnome-settings.md
  modules/system/power.nix` shows the new text in both files.
- Live values reconciled at doc-edit time (2026-07-25): `sleep-inactive-battery-timeout` -> `3600`;
  `sleep-inactive-battery-type` -> `'suspend'`; `sleep-inactive-ac-timeout` -> `43200`;
  `sleep-inactive-ac-type` -> `'suspend'`; `HandleLidSwitch` -> `"lock"`; `Docked` -> `b false`
  (undocked at check time).
- **Phase 8 agent-runnable live checks against the CURRENTLY RUNNING system** (generation
  `nixos-system-hamsa-26.05.20260710.8f0500b`; `nixos-rebuild list-generations` shows nothing newer
  than 118, built 2026-06-30 — i.e. **round 3 has not been activated yet**):
  - PASS (rounds-1-2 behavior, unaffected): timer `active` and ticking; journal silent at >10%
    (`BAT1` `Discharging` `100%` at check time); `HandleLidSwitch`/`HandleLidSwitchExternalPower`
    still `"lock"`; battery dconf still `3600`/`'suspend'` — **no regression**.
  - NOT YET TRUE (expected, activation-pending, not a defect): `systemctl cat
    battery-suspend-backstop.service` still shows the pre-round-3 `ExecStart`
    (`/nix/store/aicmg94rlqd4jvk2pbl7sds7xhhwyki3-...`) with no `StateDirectory`;
    `battery-backstop-wake-mark.service` does not exist on the live system; the built,
    build-verified round-3 closure (`.../j84p3im5jdmb4wrz74hppc20jmwbwcrd-...`) exists in the Nix
    store but is not yet the running system.

## USER CHECKLIST (blocking — carried verbatim from the plan, none performed this round)

Requires `sudo`, a real suspend cycle, or physical hardware; agents must not perform any of these.

1. **Activate the new change only**: `sudo nixos-rebuild switch --flake .#hamsa`. No reboot
   required — rounds 1-2 are already live; this change only adds units.
2. **Notification path**: `sudo $(systemctl cat battery-suspend-backstop.service | sed -n
   's/^ExecStart=//p') --test-notify` — a critical notification should appear in your GNOME
   session; repeat with the screen locked to confirm lock-screen visibility.
3. **Safe A/B suspend test** (with a Claude session open so block inhibitors are held — no battery
   draining): `sudo systemctl suspend` must be **REFUSED** with `BlockedByInhibitorLock`; then
   `sudo systemctl suspend -i` must suspend despite the inhibitors. Wake via lid or keypress — this
   also exercises the new wake-mark hook.
4. **Physical lid-close, undocked**: close the lid with no external monitor attached -> session
   locks, panel powers off ~30s later, machine **stays awake** (verify via `who -b` /
   `journalctl -b 0 -g "suspend"` showing no suspend, or an in-flight agent still running).
5. **Docked multi-monitor regression** (never run before — the gate on the task's multi-monitor
   requirement): with an external monitor attached, confirm `Docked` -> `b true`, then close the
   lid and confirm docked behavior is unchanged (windows stay on external display(s), no lock, no
   suspend). If this fails, stop and report — do not paper over it in docs.
6. **Escape hatch reminder**: `systemctl stop battery-suspend-backstop.timer` for a deliberate
   low-battery session (re-enabled at next boot/switch).
7. Do **NOT** test the backstop by draining the battery — step 3 validates the bypass chain safely
   and Phase 6's offline cases cover the grace logic.

## Multi-Monitor Requirement — Status

**Not yet verified live.** Reasoned and cross-checked architecturally against installed gsd/mutter
source across two prior research rounds (`HandleLidSwitchDocked` deliberately left at default
`ignore`; `gsd-power` holds its own independent lid inhibitor while docked). The live baseline
report 02 cited predates the `HandleLidSwitch=lock` change. USER CHECKLIST item 5 above is the
still-outstanding gate; this task does not claim the requirement verified until that check runs and
passes.

## Recommended Follow-up (out of this task's `file_scope`)

`docs/no-sleep-agents.md` is not in task 117's `file_scope` and was deliberately not edited. Fold
into task 119's docs phase (already mid-flight in the adjacent AC-timeout narrative) or a small new
doc task: (1) the fuller wake-grace-window paragraph, (2) the docked-test audit-trail sentence once
USER CHECKLIST item 5 runs, and (3) the gsd one-shot / AC-ceiling caveat's fuller narrative form.

## Notes

- Rounds 1 and 2 (phases 1, 2, 3, 5) were re-verified live at the start of this round and required
  no changes; they are unaffected by this round's edits.
- `.orchestrator-handoff.json`, `summaries/01`, `summaries/02` were correctly left untouched by this
  plan's file edits (per its explicit scope boundary); the orchestrator handoff for this round is
  written fresh per this dispatch's own requirements, not by editing the plan.
