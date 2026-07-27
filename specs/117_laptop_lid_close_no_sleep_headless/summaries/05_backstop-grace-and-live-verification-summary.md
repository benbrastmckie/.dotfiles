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
  **Scope caveat (added 2026-07-25, post-activation):** these 23 assertions validate the *grace
  logic* only. Because `BACKSTOP_NOTIFY_BIN` pointed at a stub throughout, the real
  `battery-backstop-notify` helper never ran end-to-end here, and the suite therefore did not
  catch a live defect inside it — `runuser -u "#$uid"` (a sudo-ism `runuser` rejects via
  `getpwnam`), which made every notification silently fail. Fixed post-activation; see the
  "Post-activation findings" section below. Case (h) proved a *failing* notifier cannot block
  suspend; nothing here proved a *succeeding* notifier delivers. Read "23/23" accordingly.
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

## Post-activation findings (2026-07-25, after the user's `nixos-rebuild switch`)

The user activated the round-3 closure; running generation is now **128**. That unblocked the
agent-runnable half of Phase 8 and surfaced one real defect.

**Verified live** (previously activation-blocked, now confirmed against the running system):

| Check | Evidence |
|---|---|
| New script live | `ExecStart` -> `x4a3qw8g…-battery-suspend-backstop`, containing `threshold=10`, `grace_secs=300`, `grace_floor=5`, `grace_drop=2`, `--test-notify` |
| ~~Wake-mark unit~~ **RETRACTED 2026-07-26** | Exists; `StateDirectory=battery-suspend-backstop`; `WantedBy=post-resume.target`; listed in `post-resume.target.wants/` beside `disable-speaker-amp.service` — **but this proves nothing: `post-resume.target` does not exist (`LoadState=not-found`), so the `.wants/` symlinks are orphaned and the unit has never run.** See "Wake-mark hook found inert" below. |
| State dir | `/var/lib/battery-suspend-backstop/` exists (empty — no suspend/resume yet) |
| AC silence, live | Five consecutive timer firings at 100% on AC, each exited without suspending |
| Rounds 1-2 intact | `busctl` runtime: `HandleLidSwitch="lock"`, `HandleLidSwitchExternalPower="lock"`, `HandleLidSwitchDocked="ignore"`; dconf `3600`/`'suspend'` |
| Inhibitor tether | 5 `claude-code` `block` inhibitors held, all holder PIDs alive (no leaks) |

**Defect found and fixed — USER CHECKLIST item 2 failed.** `sudo <script> --test-notify` produced
no notification. Root cause in `battery-backstop-notify`: it called `runuser -u "#$uid"`. The
`#UID` form is a **sudo** convention; `runuser` resolves `-u` through `getpwnam`, which has no `#`
handling, so it exited 1 with `user #1000 does not exist` on every iteration. Two layers hid it:
`notify-send`'s stderr goes to `/dev/null`, and `safe_notify`'s `|| true` discards the status.

Diagnosis was by elimination — the daemon was live (`gnome-shell` 50.2 owning
`org.freedesktop.Notifications`), a direct D-Bus `Notify` returned id 33, banners and lock-screen
display were both enabled, uid discovery resolved correctly, and a minimal-env `notify-send`
(simulating the stripped `runuser` environment) rendered on screen. That left `runuser` itself,
which reproduces standalone.

Fix (`modules/system/power.nix`): parse the username from `loginctl`'s second field and pass
`runuser -u "$user"`. `nix flake check` and `nixos-rebuild build --flake .#hamsa` both green; the
rebuilt helper (`pgh847ij…`) carries the change. **Not yet activated** — needs another
`sudo nixos-rebuild switch`, after which item 2 must be re-run.

Blast radius is limited to the *warning*: `safe_notify`'s fail-open design meant the suspend
decision was never affected, which is exactly the intended behavior and did work.

## Second post-activation round (2026-07-26) — notification fixed, suspend path found BROKEN

The user activated the `runuser` fix (system profile `px5yzfzc…`; live `ExecStart` ->
`4swipawcdfhyxy1my8mcc7ig94nbpnll-battery-suspend-backstop`, whose notify helper is
`pgh847ijj8s1iy3vpggnzaw6y87v7a0p-battery-backstop-notify`, carrying `runuser -u "$user"`).

**USER CHECKLIST item 2 — now PASSES.** The user confirmed the critical notification appeared.
Supporting agent-side checks: `loginctl list-users --no-legend` -> `1000 benjamin no active`, and
the helper's `read -r uid user _rest` parse yields `user=benjamin`; the old `runuser -u "#1000"`
form reproduces `user #1000 does not exist…` standalone; `org.freedesktop.Notifications` is owned
(`:1.26`) and a minimal-env `notify-send` matching the `runuser` env exits 0.

**USER CHECKLIST item 3a — PASSES.** `sudo systemctl suspend` was refused, naming all five
`claude-code` block inhibitors (PIDs 2050382, 2141407, 2148282, 2160071, 2167843). The inhibitor
tether works.

**USER CHECKLIST item 3b — FAILED. HIGH severity: the backstop cannot suspend at all.**
`sudo systemctl suspend -i` raised a polkit `auth_admin` prompt rather than suspending. Root cause:
`org.freedesktop.login1.suspend-ignore-inhibit` ships with `auth_admin_keep` for **all three**
subject classes (`allow_any`, `allow_inactive`, `allow_active`), and no rule on this system grants
it — `/etc/polkit-1/rules.d/` contains only `10-nixos.rules`, which has no `login1` entry. The
prompt under `sudo` also proves systemd 260's logind does **not** bypass polkit for uid-0 callers.

Confirmed empirically in a faithful production context (root, session-less, no agent — exactly how
the timer invokes it) via
`sudo systemd-run --pipe --quiet --service-type=oneshot systemctl suspend -i --no-ask-password`:

> The current polkit policy does not allow root to ignore inhibitors without authentication in
> order to suspend. To allow this action, a new polkit rule is needed. See
> `…systemd-260.2/share/polkit-1/rules.d/10-systemd-logind-root-ignore-inhibitors.rules.example`.

So line 62 of the live script (`exec "$systemctl_bin" suspend -i`) is denied every time. At <=10%
on battery the backstop logs `battery at N% and discharging: suspending (inhibitors bypassed)` and
then fails — **the safety net against a hard 0% death while running headless has never worked.**
The remedy is the rule systemd ships as `.example` (present in the store, not symlinked into
`/etc/polkit-1/rules.d/`); this is not a privilege escalation, since root can already suspend by
writing `/sys/power/state` — the rule merely routes it through logind's proper sleep sequence.

**Tracked as task 123**, which task 117 now depends on. Items 3b, 4, and 5 stay open behind it.

**Verification-methodology gap (the pattern behind both defects).** The round-3 offline suite
stubbed `systemctl` (`BACKSTOP_SYSTEMCTL_BIN`) *and* the notifier (`BACKSTOP_NOTIFY_BIN`). Its
23/23 therefore covered the grace arithmetic and neither real-world leg — so it could not have
caught the `runuser` `#UID` defect, and did not catch this polkit denial either. Both defects sat
precisely where a stub stood in for the real call. Task 123 carries this forward.

## Third round (2026-07-26) — item 3b now PASSES; wake-mark hook found inert

**USER CHECKLIST item 3b — now PASSES.** After the polkit fix landed (tracked separately and
activated by the user), `sudo systemd-run --pipe --quiet --service-type=oneshot systemctl suspend
-i --no-ask-password` suspended the machine from a session-less root context with five
`claude-code` `block` inhibitors held. Journal evidence: `PM: suspend exit` and `System returned
from sleep operation 'suspend'` at 2026-07-26 17:18:51. The backstop's exact call path now works.

**New HIGH-severity defect found on that resume: the wake-grace window is inert.**
`battery-backstop-wake-mark.service` declares only `WantedBy=post-resume.target`, and
**`post-resume.target` does not exist on this system** — `systemctl show post-resume.target -p
LoadState` returns `LoadState=not-found`, and `systemctl list-unit-files` has no `post-resume`
entry at all. systemd never loads a `.wants/` directory whose target unit is absent, so the two
symlinks in `/run/current-system/etc/systemd/system/post-resume.target.wants/` are orphaned.

Confirmed empirically against the real suspend/resume above: the unit's `ActiveEnterTimestamp` is
still empty, `/var/lib/battery-suspend-backstop/` is still empty, and no `wake-mark` file exists.

Two claims in this round's own records were therefore wrong and are retracted in place (see the
verification table above and Phase 8's second checklist item):

1. **"Listed in `post-resume.target.wants/`" was treated as live proof of wiring.** It is not —
   the directory is inert without its target unit.
2. **The cited precedent was misread.** `disable-speaker-amp.service` installs as
   `WantedBy=multi-user.target post-resume.target` and activated at **boot** via
   `multi-user.target` (`ActiveEnterTimestamp=Sat 2026-07-25 23:09:44`), not on any resume. Its
   `post-resume.target` membership has never done anything either.

Consequence: no wake-mark is ever written, so `wake_cap` and the wake timestamp never exist, the
grace branch can never trigger, and a wake at <=10% to plug in a charger is re-suspended within
~60s — exactly the report 04 Q5 behavior Phase 6 was written to prevent. The Phase 6 offline suite
passed because its harness wrote fake wake-mark files into a fake state directory; nothing
exercised the real unit that is supposed to produce one. This is the same failure shape as the
`runuser` and polkit defects: the verification substituted for the thing being verified.

The mechanism needed is available here — `suspend.target`, `sleep.target`, `hibernate.target` and
`hybrid-sleep.target` all exist as linked units, and `powerManagement.enable = true` is already
set in `modules/system/power.nix`. **Tracked as task 124**; task 117 now depends on 123 and 124.

## USER CHECKLIST (blocking — items 2, 3a, 3b now PASS; items 4 and 5 outstanding)

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
