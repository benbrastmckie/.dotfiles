# Implementation Plan: Task #113

- **Task**: 113 - Archive-on-reply + periodic sync (aerc replies archive locally, aerc updates immediately, Gmail stays in sync occasionally)
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: Task 112 (completed) - `maildir-store`/`multi-file-strategy = act-dir` make `:archive`/`:send -a` live rather than silent no-ops
- **Research Inputs**: specs/113_aerc_archive_on_reply_and_periodic_sync/reports/01_archive-on-reply-and-periodic-sync.md
- **Artifacts**: plans/01_archive-on-reply-periodic-sync.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Deliver two independent Home Manager config changes so that replying to a message in aerc
archives exactly the replied-to message locally (immediate aerc update), and Gmail-in-the-browser
stays occasionally in sync. Part A switches archive-on-reply from the currently-drafted (and
uncommitted) `[hooks] mail-sent` subject-string approach to aerc 0.21.0's native `:send -a flat`
mechanism by rebinding `compose::review`'s `y` key and deleting the draft hook block. Part B adds
a `systemd.user` service+timer pair running `mail-sync both` (the primary "sync even when aerc is
closed" mechanism, modeled on the repo's proven `cache-cleanup.nix`), plus a while-open
convenience by wiring `[gmail]` `check-mail`/`check-mail-cmd`/`check-mail-timeout`. Definition of
done: `home-manager build --flake .#benjamin` succeeds; the reply->archive->sync->Gmail-web
end-to-end check is deferred to the user as a manual checklist (implementer does config +
build-verify only, never drives the TUI or touches live servers).

### Research Integration

The research report (01) is grounded against the exact nixpkgs-built aerc 0.21.0 Go source tree
and drives the two most consequential decisions in this plan:

- **Part A approach change (Finding 3, Decision A)**: aerc 0.21.0 has a native, purpose-built
  archive-on-reply mechanism. `commands/compose/send.go`'s `Send` command declares
  `Archive string` (`opt:"-a"`), and `commands/msg/reply.go`'s `OnClose` closure consumes it by
  archiving the *exact* `models.MessageInfo` captured by reference at `:reply` time. This is
  immune to the list-reflow / cursor-drift risk carried by the drafted `mail-sent` hook (which
  archives whatever is *currently selected* when the hook fires), a risk that gets worse once
  Part B's periodic sync can reflow the list mid-compose. The report confirms `-a flat` is inert
  (never archives) on `:forward`, fresh `:compose`, and `:recall`, so the rebind is
  unconditionally safe. It also confirms `:reply -a` (reply-all) and `:send -a` (archive scheme)
  are independently scoped options with no collision. **Running both mechanisms simultaneously
  risks a double-archive**, so the draft hook must be removed, not kept alongside.
- **Part B primary mechanism (Findings 9-11, Decision B)**: a `systemd.user.services` +
  `systemd.user.timers` pair running `mail-sync both`, modeled directly on the live, verified
  `cache-cleanup.nix`. `mail-sync`'s flock (task 109) serializes concurrent timer- and
  aerc-triggered runs, so both triggers are safe together. The report flags `cache-cleanup.nix`'s
  proven shape (oneshot + `OnCalendar` + `Persistent = true`) and the cautionary
  `gmail-oauth2.nix` precedent (a guaranteed-every-run failure once degraded the systemd --user
  session) - mail-sync differs materially (expected-success, transient failures self-clear) but
  the failure-visibility trade-off is documented explicitly.
- **Part B check-mail gotchas (Findings 7-8)**: `check-mail-timeout` defaults to only 10s, far too
  short for `mail-sync`'s up-to-300s flock wait plus a real network `mbsync` round-trip, so the
  plan uses `mail-sync gmail --no-wait` (fails fast on lock contention) and raises
  `check-mail-timeout` to `30s`. Wiring `check-mail-cmd` also fixes the pre-existing broken `u`
  keybind (`:check-mail`), which currently errors ("checkmail: no command specified") because
  `check-mail-cmd` has never been set.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set). Advances the email-stack work
continued from tasks 109 and 112.

## Goals & Non-Goals

**Goals**:
- Replying in aerc archives exactly the replied-to message via the native `:send -a flat`
  mechanism, with the aerc INBOX view updating immediately (local file move).
- Remove the uncommitted `[hooks] mail-sent` draft so the two archive-on-reply mechanisms never
  run simultaneously.
- Add an always-on periodic sync (`mail-sync both` on a systemd user timer) that keeps Gmail in
  sync occasionally even when aerc is closed.
- Add a safe while-aerc-is-open `check-mail` convenience on `[gmail]`, which also fixes the
  currently-broken `u` keybind.
- `home-manager build --flake .#benjamin` succeeds with all changes applied.

**Non-Goals**:
- Any live-mail end-to-end verification driven by the agent (reply, send real mail, run
  mbsync/mail-sync against live servers, drive aerc's TUI). These are a MANUAL USER checklist.
- Committing the changes. Committing is orchestrator-handled because the working tree holds
  intermingled uncommitted hunks (task 112 edits plus the draft hook being removed). No
  interactive `git add -p` is planned here.
- Changes to `mbsync.nix`, `mail-sync.nix`, or notmuch config (Gmail's archive/expunge semantics
  are already correct per task 112; `mail-sync`'s flock already provides all needed locking).
- Wiring `check-mail` on `[logos]` (kept out of scope, matching the existing gmail-only `$`
  keybind convention; a trivial future extension).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing the draft hook + rebinding `y` are intermingled with task 112's uncommitted hunks in the same file | M | H | Implementer edits only the specified regions; do NOT commit (orchestrator handles staging of intermingled hunks). Build-verify confirms the file still evaluates. |
| A user who types a bare `:send` on the ex command line (bypassing `y`) no longer auto-archives | L | L | Deliberate, documented trade-off (research Finding 5); the normal keybind-driven flow is unaffected and archives the correct message. Documented inline. |
| `check-mail-timeout` 10s default truncates `mail-sync`, surfacing spurious timeout errors | M | M | Use `mail-sync gmail --no-wait` in `check-mail-cmd` and raise `check-mail-timeout` to `30s` (research Finding 7). |
| systemd-timer `mail-sync both` failure (laptop offline, Bridge down) leaves systemd --user "degraded" | L | M | mail-sync is expected-success and self-clears on next run (unlike the revoked-token `gmail-oauth2.nix` precedent); document that the user should occasionally check `systemctl --user status`/`journalctl --user -u mail-sync-timer`. |
| systemd service cannot resolve `mail-sync` or reach secret-tool/D-Bus credentials | M | L | Export `PATH` in the wrapped script (mirroring `cache-cleanup.nix`) and set `Unit.After = [ "graphical-session.target" ]` so the credential store is available (research Finding 9). |
| Concurrent timer + aerc `check-mail` runs race the Maildir | L | L | Rely on `mail-sync`'s existing flock (task 109); `--no-wait` on the aerc side avoids a long UI hang. No new locking needed. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 1 and 3 both edit
`modules/home/email/aerc.nix`; Phase 3 depends on Phase 1 only to serialize edits to that shared
file (no logical dependency).

### Phase 1: Part A - native archive-on-reply (rebind `y`, remove draft hook) [COMPLETED]

**Goal**: Replace the uncommitted `[hooks] mail-sent` archive-on-reply draft with aerc's native
`:send -a flat` mechanism, so a reply archives exactly the replied-to message.

**Tasks**:
- [ ] In `modules/home/email/aerc.nix`, change `extraBinds."compose::review".y` from
      `":send<Enter>"` to `":send -a flat<Enter>"`.
- [ ] Add a concise inline comment on the `y` binding explaining the "why": aerc 0.21.0's native
      `:send -a` is consumed by `reply.go`'s `OnClose`, which archives the exact replied-to
      message captured by reference at `:reply` time (immune to list reflow / cursor drift);
      `-a` is inert on `:forward`, fresh `:compose`, and `:recall`, so the rebind is safe on all
      send paths; `:reply -a` (reply-all, the `R` key) does not collide with `:send -a`.
- [ ] Delete the entire `hooks = { ... };` attribute set (the `mail-sent = "case ... :archive
      flat ..."` entry and its comment block) from `extraConfig`. This REMOVES an uncommitted
      working-tree hunk. Removing it prevents a double-archive (native path archives the correct
      message AND the hook would archive whatever is separately selected).

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `modules/home/email/aerc.nix` - rebind `compose::review.y`; delete the `hooks` attrset block.

**Verification**:
- The `hooks = { ... }` block is entirely gone from the file.
- `compose::review.y` reads `":send -a flat<Enter>"`.
- `R = ":reply -a<Enter>"` (reply-all) is left unchanged.
- Deferred to Phase 4: `home-manager build` confirms the file still evaluates.

---

### Phase 2: Part B primary - systemd user timer running `mail-sync both` [COMPLETED]

**Goal**: Add an always-on periodic sync that runs `mail-sync both` on an interval even when aerc
is closed, satisfying "Gmail stays in sync occasionally."

**Tasks**:
- [ ] Create `modules/home/services/mail-sync-timer.nix`, modeled on
      `modules/home/services/cache-cleanup.nix`:
  - `systemd.user.services.mail-sync-timer` with `Type = "oneshot"`, `Unit.Description`, and
    `Unit.After = [ "graphical-session.target" ]` (so secret-tool / D-Bus credentials the
    underlying `mbsync` `PassCmd` needs are available).
  - `ExecStart` via `pkgs.writeShellScript` that exports
    `PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:$PATH"`
    (mirroring `cache-cleanup.nix`) and runs `mail-sync both`.
  - `systemd.user.timers.mail-sync-timer` with `OnCalendar = "*:0/15"` (every 15 minutes),
    `Persistent = true`, `RandomizedDelaySec` (e.g. 120), `Unit.Requires =
    [ "mail-sync-timer.service" ]`, and `Install.WantedBy = [ "timers.target" ]`.
  - Use the `{ config, pkgs, ... }:` signature (needs both `config` and `pkgs`).
- [ ] Add an inline comment documenting: the flock-safety rationale (task 109 `mail-sync` lock
      serializes this timer against aerc-triggered runs); the interval is intentionally coarse
      ("occasional" is acceptable) and easily adjustable; and the `gmail-oauth2.nix` cautionary
      note that a persistently-failing oneshot can degrade the systemd --user session, with the
      distinction that mail-sync is expected-success and self-clears (so the user should
      occasionally check `systemctl --user status`/`journalctl --user -u mail-sync-timer`).
- [ ] Import the new module in `modules/home/default.nix` under the "Service modules" section
      (add `./services/mail-sync-timer.nix` alongside `./services/cache-cleanup.nix`).

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `modules/home/services/mail-sync-timer.nix` (new) - oneshot service + timer running
  `mail-sync both`.
- `modules/home/default.nix` - add the new module to the imports list.

**Verification**:
- New module exists and follows the `cache-cleanup.nix` shape (service + timer, `Persistent =
  true`, `WantedBy = [ "timers.target" ]`).
- `default.nix` imports it in the Service modules section.
- Deferred to Phase 4: `home-manager build` evaluates the new unit; `systemctl --user
  list-timers` (read-only) may be inspected after a switch (not performed by the implementer).

---

### Phase 3: Part B secondary - `[gmail]` check-mail wiring (while-open convenience, fixes `u`) [COMPLETED]

**Goal**: Add a safe while-aerc-is-open sync on `[gmail]` and fix the currently-broken `u`
(`:check-mail`) keybind.

**Tasks**:
- [ ] In `modules/home/email/aerc.nix`'s `accounts.conf` `[gmail]` block, add:
  - `check-mail = 10m`
  - `check-mail-cmd = mail-sync gmail --no-wait`
  - `check-mail-timeout = 30s`
- [ ] Add an inline comment documenting: `--no-wait` makes a lock-contended call fail fast (the
      systemd timer will pick up the sync shortly regardless) rather than hanging aerc's
      "Checking for new mail..." indicator for up to 300s; `check-mail-timeout` is raised from its
      10s default so a normal uncontended network `mbsync` run is not spuriously killed; wiring
      `check-mail-cmd` also makes the pre-existing `u = ":check-mail<Enter>"` keybind functional
      (it currently errors "checkmail: no command specified"). Note `[logos]` is intentionally
      left unwired (matches the gmail-only `$` keybind convention; out of scope).

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `modules/home/email/aerc.nix` - add three `check-mail*` keys to the `[gmail]` accounts.conf
  block (same file as Phase 1; sequenced after it to serialize edits).

**Verification**:
- `[gmail]` block contains the three `check-mail*` keys with the values above.
- `[logos]` block is unchanged.
- Deferred to Phase 4: `home-manager build` confirms the accounts.conf text still evaluates.

---

### Phase 4: Build verification + read-only systemd inspection [COMPLETED]

**Goal**: Confirm all changes evaluate and build cleanly, without any live-mail action.

**Tasks**:
- [ ] Run `home-manager build --flake .#benjamin` from the repo root; confirm it succeeds.
- [ ] Fix forward any evaluation/build errors (e.g. Nix syntax in the new module, malformed
      accounts.conf text) and re-run the build until green.
- [ ] (Optional, read-only, SAFE) After a switch would be applied by the user, `systemctl --user
      list-timers` and `systemctl --user status mail-sync-timer.timer` may be inspected to
      confirm the timer is scheduled. These are read-only and safe for the implementer to run if
      a generation has been activated, but the implementer MUST NOT run `home-manager switch`,
      start the service, or trigger a sync.

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Files to modify**: none (verification only; may loop back to fix source if the build fails).

**Verification**:
- `home-manager build --flake .#benjamin` exits 0.
- No new evaluation warnings introduced by the changed/added files.

---

### Phase 5: Manual user end-to-end checklist + commit handoff note [PARTIAL] *(deferred to manual user verification — see implementation summary for the checklist; no agent-driven TUI/mail-send/mbsync action was performed, per plan Non-Goals)*

**Goal**: Record the live end-to-end verification as a MANUAL USER checklist and note that
committing is orchestrator-handled.

**Tasks**:
- [ ] Present (in the implementation summary, not as agent actions) the manual end-to-end
      checklist for the USER to run after `home-manager switch`:
  - [ ] In aerc, select a test message in the Gmail INBOX and press `r` (reply), compose, then
        press `y` to send; confirm the message leaves the aerc INBOX view immediately.
  - [ ] Confirm a fresh `:compose` (`c`) and a `:forward` (`f`) do NOT archive anything on send.
  - [ ] Let the systemd timer run (or manually run `mail-sync gmail` / press `u`/`$` in aerc),
        then open Gmail in the browser and confirm the replied-to message is archived (out of
        INBOX, still in All Mail).
  - [ ] Optionally confirm `systemctl --user list-timers` shows `mail-sync-timer.timer`
        scheduled and `journalctl --user -u mail-sync-timer` shows successful runs.
- [ ] Record the COMMIT NOTE in the summary: do NOT plan or perform an interactive `git add -p`
      commit. The working tree holds intermingled uncommitted hunks (task 112 edits + the draft
      hook removal); committing is orchestrator-handled.

**Timing**: 10 minutes

**Depends on**: 4

**Files to modify**: none (documentation in the implementation summary only).

**Verification**:
- The implementation summary contains the manual user checklist and the orchestrator-commit note.
- No agent-driven TUI, mail-send, or mbsync/mail-sync live action was performed.

## Testing & Validation

- [ ] `home-manager build --flake .#benjamin` succeeds (Phase 4).
- [ ] `modules/home/email/aerc.nix` no longer contains any `hooks = { ... }` block.
- [ ] `compose::review.y` is `":send -a flat<Enter>"`; `R` (reply-all) unchanged.
- [ ] `[gmail]` accounts.conf contains `check-mail`, `check-mail-cmd = mail-sync gmail --no-wait`,
      `check-mail-timeout = 30s`; `[logos]` unchanged.
- [ ] `modules/home/services/mail-sync-timer.nix` exists and is imported in `default.nix`.
- [ ] (Read-only, post-switch, optional) `systemctl --user list-timers` shows
      `mail-sync-timer.timer`.
- [ ] MANUAL USER end-to-end reply->archive->sync->Gmail-web check (Phase 5) - not an agent
      action.

## Artifacts & Outputs

- `modules/home/email/aerc.nix` (modified) - native archive-on-reply rebind, hook removal,
  `[gmail]` check-mail wiring.
- `modules/home/services/mail-sync-timer.nix` (new) - `mail-sync both` oneshot service + timer.
- `modules/home/default.nix` (modified) - imports the new service module.
- `specs/113_aerc_archive_on_reply_and_periodic_sync/plans/01_archive-on-reply-periodic-sync.md`
  (this file).
- `specs/113_aerc_archive_on_reply_and_periodic_sync/summaries/01_archive-on-reply-periodic-sync-summary.md`
  (produced by /implement).

## Rollback/Contingency

- All changes are declarative Home Manager config; reverting the edits to `aerc.nix`,
  `default.nix`, and deleting `mail-sync-timer.nix` then rebuilding fully reverts.
- If the systemd timer misbehaves after activation, disabling it is a one-line change (remove the
  `default.nix` import or delete the module) followed by `home-manager switch`.
- Because committing is orchestrator-handled and the tree holds intermingled hunks, rollback of
  an unwanted change is a targeted edit-and-rebuild, not a destructive `git` operation on the
  dirty tree.
