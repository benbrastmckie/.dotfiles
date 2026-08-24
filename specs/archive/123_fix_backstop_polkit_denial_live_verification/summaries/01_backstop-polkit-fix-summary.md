# Implementation Summary: Fix backstop polkit denial and replace stubbed verification with live checks

- **Task**: 123 - fix_backstop_polkit_denial_live_verification
- **Status**: [COMPLETED]
- **Started**: 2026-07-26T23:10:15Z
- **Completed**: 2026-07-26T23:25:00Z (Phases 1-3 only; Phase 4 blocked on user)
- **Effort**: ~1.5 hours agent time (Phases 1-3)
- **Dependencies**: Task 117 (rounds 1-3, read-only cross-reference; no file under
  `specs/117_laptop_lid_close_no_sleep_headless/` was modified)
- **Artifacts**:
  - `specs/123_fix_backstop_polkit_denial_live_verification/plans/01_backstop-polkit-fix.md`
  - `modules/system/power.nix`
  - `tests/battery-suspend-backstop-offline.sh`
  - `docs/no-sleep-agents.md`
  - `docs/testing.md`
- **Standards**: `.claude/context/formats/summary-format.md`, `.claude/rules/nix.md`

## Overview

The `battery-suspend-backstop` oneshot in `modules/system/power.nix` calls `systemctl suspend -i`
as session-less root with no polkit agent; the shipped login1 policy denies this by default
(`auth_admin_keep`), so the <=10% battery safety net has never once been able to suspend. This
round adds a narrowly-scoped `security.polkit.extraConfig` grant, corrects two documentation/code
comments that falsely asserted root was already authorized, and commits a previously-ephemeral
offline test suite with an honest stub-coverage caveat plus one new non-stubbed `pkcheck`
assertion. Phases 1-3 (all agent-runnable) are complete, committed, and build-verified. Phase 4
(live end-to-end verification) is blocked: it requires `sudo`, a NixOS generation activation, and
a real suspend/resume cycle, none of which this agent is permitted to run.

**This implementation does not and cannot prove the backstop can now suspend the machine.**
Build-green, closure-grep-green, and offline-suite-green are evidence the rule is written,
present, narrow, and syntactically valid — they are not evidence it is *authorized* end to end.
Two consecutive prior defects in this same file shipped as "verified" because the verification
stubbed out the real call; this round deliberately does not repeat that mistake by claiming more
than Phases 1-3 can support.

## What Changed

- `modules/system/power.nix` — added `security.polkit.extraConfig` granting root
  `org.freedesktop.login1.suspend-ignore-inhibit` only (not the other four `*-ignore-inhibit`
  actions systemd's shipped example would grant); corrected the banner comment that previously
  claimed "root is polkit-authorized to use" `systemctl suspend -i` by default.
- `tests/battery-suspend-backstop-offline.sh` (new, 108 lines, executable) — committed the
  offline decision-logic suite (8 reconstructed cases + notified-marker suppression +
  `--test-notify`), with a mandatory caveat header and known-gap footer naming
  `BACKSTOP_SYSTEMCTL_BIN`/`BACKSTOP_NOTIFY_BIN` explicitly, plus one non-stubbed `pkcheck`
  authorization non-regression assertion.
- `docs/no-sleep-agents.md` — removed the false "Root is authorized to do this via polkit"
  claim; replaced with an accurate statement of the default-deny policy and the explicit grant
  this repo adds; added a root `pkcheck` verification step (flagged `sudo`-required) to the
  activation-verification section.
- `docs/testing.md` — added a "Battery Backstop Offline Test Suite" section pointing to the new
  script and stating both what it covers and what it cannot cover.

## Decisions

- Used `security.polkit.extraConfig` (not `environment.etc` symlinking systemd's shipped
  `.rules.example`) — matches three other in-tree nixpkgs modules doing the same shape of grant
  and avoids granting the other four `*-ignore-inhibit` actions.
- Doc corrections omit task-number/`specs/` path citations, per
  `.claude/rules/no-task-references-in-deliverables.md` (docs/ is outside `specs/**`) — annotated
  as deviations in the plan file.
- Fixed a self-caught test-design bug while building the offline suite: the "notify helper fails"
  case must exercise the suspend-fires branch (no wake-mark present), not the grace-skip branch,
  since only the fires branch invokes `systemctl` after the notify call.

## Plan Deviations

- **Phase 2, task "Keep it proportionate"** altered: the script is 108 lines, ~8% over the
  ~70-100 soft envelope. No test framework or new dependency was introduced; the extra length
  covers all 8 offline cases from the task-117 baseline plus notified-marker-suppression and the
  pkcheck assertion without collapsing readability.
- **Phase 3, doc-correction tasks** altered: replacement text in `docs/no-sleep-agents.md` does
  not cite task 123 or task 117 by number/path (see Decisions above).
- **Phase 4**: all USER CHECKLIST items (U1-U4) and the agent-runnable post-activation follow-up
  are deferred — not attempted, per this agent's hard constraint against running `sudo` or
  triggering a suspend.

## Verification

**Agent-runnable, all passed**:
- `nixos-rebuild build --flake .#hamsa` — **exit 0** (authoritative build gate).
- `nix flake check` — **exit 0**, "all checks passed!" for all four `nixosConfigurations`,
  `formatter`, and `devShells`. Not a known-expected-failure case this round; reported as an
  honest pass rather than presumed green.
- Built-closure grep: the new rule is present in
  `./result/etc/polkit-1/rules.d/10-nixos.rules` alongside the pre-existing `addAdminRule` and
  `automatic-timezoned`/cups/NetworkManager/`fwupd-refresh` blocks; zero matches for
  `power-off-ignore-inhibit`, `reboot-ignore-inhibit`, `halt-ignore-inhibit`, and
  `hibernate-ignore-inhibit`; `subject.user == "root"` confirmed with exact `==`.
- `node --check` on the extracted rule block — **exit 0** (closes the upstream
  no-compile-time-validation gap in nixpkgs `polkit.nix`).
- `bash tests/battery-suspend-backstop-offline.sh` — **exit 0, 16/16 assertions passed**.
  Idempotent across two consecutive runs (byte-identical output); `/var/lib/battery-suspend-backstop`
  mtime confirmed unchanged before and after.
- Unprivileged `pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"`
  — `polkit.result=auth_admin_keep`, exit 2, as expected (pre-activation baseline; this is a
  non-regression check, not proof of root's grant).
- `docs/` grep checks: no remaining "Root is authorized... via polkit" or bare `polkit-authorized`
  claims; `docs/testing.md` pointer confirmed present.
- `git status --short` confined to `modules/system/power.nix`, `tests/battery-suspend-backstop-offline.sh`,
  `docs/no-sleep-agents.md`, `docs/testing.md`, and this task's own directory. Nothing under
  `specs/117_*` was modified.

**NOT verified — proven nothing about live suspend behavior** (this is Phase 4, user-required):
build-green, closure-grep-green, and offline-suite-green are explicitly stated by the plan (and
restated here) as insufficient evidence that the backstop can suspend the machine. Only a real
root `pkcheck` returning exit 0 (U2) and a real session-less `systemctl suspend -i` that actually
suspends (U3/U4) would settle that, and both require `sudo`, which this agent must not run.

## Live verification results (2026-07-26, user-executed) — ALL PASS

The acceptance bar is met: both user-run live rows passed and are recorded with journal evidence.

| Item | Result | Evidence |
|---|---|---|
| U1 activate | PASS | Live rules file `a6p6zrwh…` — the same store path verified in the built closure before activation. System profile `x3siinp9…`. Rule present, root + `suspend-ignore-inhibit` only; **0** matches for the other four `*-ignore-inhibit` actions. |
| U2 root pkcheck gate | PASS | Silent exit 0. Negative control: the same probe as uid 1000 still returns `auth_admin_keep`/exit 2 — grant is root-only, no over-grant. |
| U3 session-less root suspend | PASS | `systemd-run --service-type=oneshot systemctl suspend -i --no-ask-password` suspended with five `claude-code` `block` inhibitors held. `PM: suspend exit` at 17:18:51. **This is the defect this task existed to fix.** |
| U4 non-stubbed, both legs | PASS | Real script, 9% fake capacity, both stub vars unset. Notify leg: `runuser[2822114]` PAM session opened for benjamin by uid 0 at 17:32:30 and closed cleanly — no `#UID` error. Suspend leg: `Reached target Suspend` at 17:32:34. |

On U4's notification: the banner was not visually caught (it fires ~4s before the suspend). The
`runuser` PAM session pair is the evidence of delivery, matching the signature of the
`--test-notify` run at 15:39:17 that *was* seen on screen. `safe_notify` is fail-open, so absence
of an error is not by itself proof — the positive PAM pair is.

Non-regression: the real timer ticked at 17:33:16 against the real battery on AC and exited
without suspending, so the fake-battery run left no runaway behavior.

**Out-of-scope defect found during this verification** (belongs to task 117's wake-grace feature,
tracked as task 124, not fixed here): `battery-backstop-wake-mark.service` declares only
`WantedBy=post-resume.target`, and `post-resume.target` does not exist on this system
(`LoadState=not-found`). Neither of the two real suspend/resume cycles above produced a wake-mark
file. The wake-grace window is therefore inert, and U4 could not exercise the grace-branch
notification — only the suspend-branch one.

## USER CHECKLIST — ALL ITEMS EXECUTED AND PASSING (2026-07-26)

> **U1. Activate the change.**
> ```
> sudo nixos-rebuild switch --flake .#hamsa
> ```
> No reboot required — this adds a polkit rule to a file the system already ships and does not
> alter logind. Confirm the new rule is live in the running system (not just the built closure):
> ```
> grep -n suspend-ignore-inhibit /etc/polkit-1/rules.d/10-nixos.rules
> ```
>
> **U2. Cheap authorization gate — query only, nothing suspends.** This is the first positive
> proof that root is granted the action.
> ```
> sudo bash -c 'pkcheck --action-id org.freedesktop.login1.suspend-ignore-inhibit --process "$$"'
> ```
> Expected after the fix: **exit 0** (authorized), with no `auth_admin_keep` line.
>
> Note the quoting: the single-quoted `bash -c` form is required so `$$` expands to the **root**
> shell's PID. Writing `sudo pkcheck ... --process "$$"` expands `$$` in your own uid-1000 shell
> instead and will report `polkit.result=auth_admin_keep`, exit 2 — that is the mis-invocation,
> not a real failure. If you get exit 2, re-run with the exact command above before concluding
> anything.
>
> **If U2 does not return exit 0, STOP HERE.** Do not run U3 or U4. Report the output; the rule
> is not live or not matching.
>
> **U3. Real end-to-end suspend probe — this suspends the machine.** This is the exact
> session-less-root, no-agent shape that reproduced the original denial:
> ```
> sudo systemd-run --pipe --quiet --service-type=oneshot systemctl suspend -i --no-ask-password
> ```
> Expected: the machine **actually suspends**, instead of printing "The current polkit policy
> does not allow root to ignore inhibitors without authentication in order to suspend." Wake with
> the lid or a keypress. Run this with a Claude Code session open so block inhibitors are
> genuinely held — otherwise the probe does not exercise the inhibitor-skipping path that matters.
>
> **U4. Non-stubbed backstop run — real suspend AND real notification, only the battery faked.**
> This is the item that satisfies "verify the suspend and notification legs without the stubs".
> Create a scratch fake battery tree and a scratch state dir, then invoke the **real built**
> backstop script with only `BACKSTOP_BATTERY_GLOB` and `STATE_DIRECTORY` overridden — leave
> `BACKSTOP_SYSTEMCTL_BIN` and `BACKSTOP_NOTIFY_BIN` **unset** so the real `systemctl` and the
> real notify helper are used:
> ```
> mkdir -p /tmp/fakebat/BAT0 /tmp/fakestate
> echo Discharging > /tmp/fakebat/BAT0/status
> echo 9          > /tmp/fakebat/BAT0/capacity
> sudo env BACKSTOP_BATTERY_GLOB='/tmp/fakebat/BAT*' STATE_DIRECTORY=/tmp/fakestate \
>   "$(systemctl cat battery-suspend-backstop.service | sed -n 's/^ExecStart=//p')"
> ```
> Expected: a critical low-battery notification appears in the GNOME session **and** the machine
> suspends. Nobody should drain the real battery to 9% to test this; the battery state is the one
> input that cannot safely be faked any other way. Both overridden vars are inputs only — neither
> stands between the script and the two legs under test.
>
> **U5. Report back** the outcome of U1-U4 (pass/fail plus any output) so the agent-runnable
> follow-up below can be completed.
>
> **Agent-runnable post-activation follow-up** (only after the user reports U1-U4):
> - Re-run the unprivileged non-regression probe — must still be `auth_admin_keep`, exit 2.
> - Re-run `bash tests/battery-suspend-backstop-offline.sh` against the newly activated system.
> - `journalctl -u battery-suspend-backstop.service -n 40 --no-pager` — confirm the denial
>   message no longer appears on firings after activation.
> - Confirm the resume from U3/U4 exercised the wake hook (`battery-backstop-wake-mark.service`
>   activation timestamp; `/var/lib/battery-suspend-backstop/` no longer empty).
> - Confirm the live `/etc/polkit-1/rules.d/10-nixos.rules` still grants no
>   `power-off`/`reboot`/`halt`/`hibernate` `-ignore-inhibit` action.

## Impacts

- The battery-suspend backstop's authorization leg is fixed at the configuration level, but the
  fix is **not live** on the running system until the user runs U1 (`sudo nixos-rebuild switch`).
  Until then, the running system's `/etc/polkit-1/rules.d/10-nixos.rules` still denies the
  session-less root call — the safety net remains non-functional on this host until activation.
- The security delta is narrow and net-positive per the plan's research: root already had an
  unconditional, hook-skipping `/sys/power/state` path; this grant only removes a polkit prompt
  for one specific, already-root-reachable action.

## Follow-ups

- User must run Phase 4's USER CHECKLIST (U1-U4) and report results — this task cannot be marked
  `[COMPLETED]` without a recorded, real, non-stubbed `systemctl suspend -i` that actually
  suspends the machine (U3 or U4).
- If U2 fails, do not re-open Phases 1-3; re-check the *live* `/etc/polkit-1/rules.d/10-nixos.rules`
  (not the built closure) and check `journalctl -u polkit -b 0` for a silent JS load failure, per
  the plan's Rollback/Contingency section.

## References

- `specs/123_fix_backstop_polkit_denial_live_verification/plans/01_backstop-polkit-fix.md`
  (Phases 1-3 `[COMPLETED]`, Phase 4 `[PARTIAL]`, all verification results recorded in place)
- `specs/123_fix_backstop_polkit_denial_live_verification/reports/01_backstop-polkit-denial.md`
- `specs/123_fix_backstop_polkit_denial_live_verification/handoffs/` (per-phase handoff notes)
- `specs/117_laptop_lid_close_no_sleep_headless/plans/05_backstop-grace-and-live-verification.md`
  (read-only cross-reference for the offline-suite case reconstruction and USER CHECKLIST format;
  not modified)
