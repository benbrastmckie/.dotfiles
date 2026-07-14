# Implementation Plan: Gmail/.All_Mail duplicate-UID remediation

- **Task**: 114 - Safely remediate the duplicate-UID collision in `~/Mail/Gmail/.All_Mail`
- **Status**: [NOT STARTED]
- **Effort**: 3.25 hours
- **Dependencies**: None (task 113 surfaced the symptom but is not a code dependency)
- **Research Inputs**: specs/114_gmail_allmail_duplicate_uid_remediation/reports/01_duplicate-uid-diagnosis.md
- **Artifacts**: plans/01_duplicate-uid-remediation.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

The `gmail-all` mbsync channel aborts with `Maildir error: duplicate UID 15 in
/home/benjamin/Mail/Gmail//.All_Mail` because two different messages in
`~/Mail/Gmail/.All_Mail/cur/` both carry the maildir tag `,U=15`. `.mbsyncstate` holds exactly
one legitimate mapping for near-UID 15 (`34 15 S`), so one of the two files is a stray that
erroneously acquired the tag. The fix is to **rename the stray in place** to strip its `,U=15`
suffix — never delete or move any file out of the folder — which clears the collision while
`Create Near` guarantees the de-UID'd local-only file is never uploaded (no server duplicate) and
no removed file means no `Expunge Both` propagation (no server deletion). The change is tiny; the
risk is high, so the plan front-loads corroboration and snapshotting before the single rename, and
back-loads full verification (mbsync exit 0, both messages still present in Gmail, aerc banner
clears, timer unit non-failed). Definition of done: `mbsync gmail` exits 0, both subject lines
still exist in Gmail All Mail server-side, and no other unremediated duplicate-UID collision
remains in the swept folders.

### Research Integration

The diagnosis report (`reports/01_duplicate-uid-diagnosis.md`, live-verified 2026-07-14) supplies:
the two colliding filenames, subjects, and Message-IDs; the single `34 15 S` state mapping; the
`Expunge Both` / `Create Near` channel semantics from `modules/home/email/mbsync.nix`; the rejected
alternatives (`rm`/move-out = server-deletion risk, full state reset = does not fix filename-derived
UIDs); and four open questions (confirm the stray, notmuch re-index behaviour, optional
`mail-sync.nix` benign-duplicate guard, sweep for other collisions) that map directly to phases
below. Additional grounding gathered during planning: `modules/home/email/mail-sync.nix` already
detects this exact class via `is_duplicate_uid()` and prints manual-remediation guidance, but still
returns `OVERALL_STATUS=1` — which is precisely what red-banners aerc's check-mail. This makes the
Phase 6 guard decision concrete: the plumbing to recognize the class already exists.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided).

## Goals & Non-Goals

**Goals**:
- Clear the duplicate `,U=15` collision in `~/Mail/Gmail/.All_Mail` so `mbsync gmail` /
  `mail-sync gmail` exit 0.
- Do so with zero server-side change: no message deleted from and no duplicate uploaded to Gmail
  All Mail.
- Confirm (not assume) which of the two files is the stray before renaming.
- Leave the fix fully reversible (rename back) at every step.
- Sweep for and remediate any OTHER duplicate-UID collisions so the fix is complete, not
  whack-a-mole.
- Decide, with rationale, whether a durable benign-duplicate guard belongs in `mail-sync.nix`.

**Non-Goals**:
- Re-doing or revising tasks 110-113 (aerc/mail-sync wiring is out of scope).
- Deleting, expunging, or moving any maildir file out of its folder.
- Full `.mbsyncstate` / `.uidvalidity` reset (rejected: slow re-pair of ~64k messages and does not
  fix filename-derived UID collisions).
- Any server-side (Gmail web) mutation.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Renaming the WRONG file (de-UID the legit message) | H | M | Phase 2 corroboration gate (read-only IMAP FETCH 34 and/or notmuch) must positively identify the stray before Phase 3; abort if inconclusive |
| A file gets `rm`'d or moved out, triggering `Expunge Both` server deletion | H | L | Hard rule threaded through every phase: rename in place only; Phase 1 records exact filenames + hashes so any accidental disappearance is detectable and reversible |
| mbsync runs mid-edit and reconciles a half-changed state | M | L | Take the `mail-sync` flock or ensure no sync/timer is active during Phase 3; pause the mail-sync timer for the mutation window |
| notmuch left with a dangling index entry after rename | L | M | Phase 4 runs `notmuch new --no-hooks` and confirms the renamed file re-keys with no orphan |
| A future server pull re-downloads the de-UID'd message as a second local copy | L | M | Accepted as harmless/self-correcting per research; documented, not blocked |
| Other undiscovered duplicate-UID collisions still fail mbsync after the UID-15 fix | M | M | Phase 5 sweep across All_Mail and other folders before declaring done |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential by design: the
HIGH-RISK, `Expunge Both` blast radius mandates confirm-before-mutate and verify-before-proceed
ordering, so each wave holds exactly one phase.

### Phase 1: Snapshot and baseline the collision (read-only) [COMPLETED]

**Goal**: Capture a reversible, evidence-grade record of the current on-disk and state-file
situation before touching anything, and re-confirm the failure live.

**Tasks**:
- [x] Record both colliding files' full basenames, byte sizes, sha256, and mtimes from
  `~/Mail/Gmail/.All_Mail/cur/` (the two `,U=15:2,` files named in the report). *(completed: see artifacts/01_phase1-baseline.txt)*
- [x] Extract and record each file's `Subject` and `Message-ID` headers to confirm they match the
  report (`eNTERTAINMENT cENTER` / `<...@isda1>` and `CEO Nick Slape` / `<...@t01.communicatoremail.com>`). *(completed: headers match exactly)*
- [x] Copy `~/Mail/Gmail/.All_Mail/.mbsyncstate` to a task-local backup and confirm it still
  contains the single `34 15 S` mapping and no second UID-15 line. *(completed: backed up, single mapping confirmed)*
- [x] Reproduce the failure: run `mbsync gmail` (or `mail-sync gmail`) and capture the
  `duplicate UID 15` non-zero exit as the before-state. *(completed: exit_code=1, captured in artifacts/01_mbsync-gmail-before-state.log)*
- [x] Confirm the mail-sync systemd timer/service is idle (or stop the timer) so no sync runs
  during the later mutation window. *(completed: mail-sync-timer.timer stopped via systemctl)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- None (read-only). Writes only task-local backups under
  `specs/114_gmail_allmail_duplicate_uid_remediation/` (e.g. an `artifacts/` or notes area) — never
  under `~/Mail`.

**Verification**:
- Both filenames, hashes, and Message-IDs recorded and match the report.
- `.mbsyncstate` backup exists and shows exactly one UID-15 mapping.
- `mbsync gmail` reproduced exiting non-zero with the UID-15 message.

---

### Phase 2: Confirm which file is the stray (read-only corroboration gate) [NOT STARTED]

**Goal**: Positively identify which of the two files is the stray, mapping the legitimate near-UID
15 to far (server) UID 34, WITHOUT any mutation. This is the decision gate for the whole task.

**Tasks**:
- [ ] Primary corroboration: read-only IMAP `FETCH 34 (BODY[HEADER.FIELDS (MESSAGE-ID)])` against
  `[Gmail]/All Mail` to learn the Message-ID that far-UID 34 (the legit near-UID 15) corresponds to.
  Use existing credentials carefully; this is a pure read, no STORE/flag change.
- [ ] Match the fetched Message-ID to exactly one of the two files → that file is the LEGIT one; the
  other is the STRAY to be de-UID'd.
- [ ] Secondary/fallback corroboration: check notmuch for each Message-ID and any consistent UID
  usage elsewhere in the maildir; if IMAP is impractical, corroborate via notmuch plus the
  report's mtime-ordinal heuristic (later-mtime `..._624... eNTERTAINMENT cENTER` is the likely
  injected duplicate) — but only accept the heuristic when a second signal agrees.
- [ ] Record the identified stray filename explicitly and STOP for confirmation if the two signals
  disagree or are inconclusive (do not proceed to Phase 3 on a guess).

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- None (read-only IMAP FETCH + notmuch queries only).

**Verification**:
- Exactly one file is identified as the stray with a documented, corroborated basis
  (IMAP FETCH 34 Message-ID match, ideally seconded by notmuch/mtime).
- The identification is written down; ambiguity results in a documented STOP, not a rename.

---

### Phase 3: Rename the stray in place to strip `,U=15` (the single mutation) [NOT STARTED]

**Goal**: Resolve the collision with one reversible in-place rename of the confirmed stray.

**Tasks**:
- [ ] Re-verify no mail-sync/mbsync run is active (flock held or timer stopped from Phase 1).
- [ ] Rename ONLY the confirmed-stray file in place within `.All_Mail/cur/`, stripping the `,U=15`
  portion of the suffix (e.g. `..._624.hamsa,U=15:2,` → `..._624.hamsa:2,`). Use `mv` within the
  same directory only. Do NOT `rm`, do NOT move to `tmp/`, `new/`, or any other folder, do NOT
  touch the legit file.
- [ ] Record the exact old→new name mapping so the rename can be reverted verbatim.
- [ ] Confirm both files still physically exist in `.All_Mail/cur/` (one now without `,U=15`, one
  still with `,U=15`), so no `Expunge Both` deletion can be propagated.

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `~/Mail/Gmail/.All_Mail/cur/<stray-file>` - renamed in place to drop the `,U=15` tag (no file
  removed, none moved out of the folder).

**Verification**:
- Only one `,U=15` file now remains in `.All_Mail/cur/`.
- Both messages' files are still present in the folder (count unchanged, one renamed).
- The reverse-rename mapping is recorded.

---

### Phase 4: Verify sync recovers with zero server-side change [NOT STARTED]

**Goal**: Confirm the collision is cleared, the sync now succeeds, and nothing was lost or
duplicated server-side.

**Tasks**:
- [ ] Run `notmuch new --no-hooks` and confirm the renamed file re-keys cleanly with no dangling
  index entry for the old name.
- [ ] Run `mbsync gmail`; confirm it exits 0 (no `duplicate UID` error).
- [ ] Run `mail-sync gmail`; confirm it exits 0.
- [ ] In the Gmail web UI, confirm BOTH `eNTERTAINMENT cENTER` and `A message from our CEO Nick
  Slape` still exist in All Mail (nothing deleted server-side).
- [ ] `systemctl --user start mail-sync-timer.service` (or the unit name), then confirm
  `is-failed` returns non-failed; re-enable the timer if it was stopped in Phase 1.
- [ ] Observe aerc: confirm the recurring `checkmail: error running command: exit status 1` banner
  no longer appears on the next check-mail cycle.

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- None (verification only; may re-enable the previously stopped timer).

**Verification**:
- `mbsync gmail` and `mail-sync gmail` both exit 0.
- Both subject lines confirmed present in Gmail All Mail (server intact).
- mail-sync timer unit non-failed; aerc banner cleared.
- notmuch shows no orphaned index entry for the renamed file.

---

### Phase 5: Sweep for and remediate other duplicate-UID collisions [NOT STARTED]

**Goal**: Ensure the fix is complete rather than whack-a-mole by finding any other duplicate-UID
collisions in All_Mail and other Gmail (and Logos) maildir folders.

**Tasks**:
- [ ] Scan each maildir folder's `cur/`+`new/` for repeated `,U=<n>` values (group filenames by
  their `,U=` suffix and flag any UID appearing on 2+ files) across `~/Mail/Gmail/*` and
  `~/Mail/Logos/*`.
- [ ] For any additional collision found, apply the SAME confirm-then-rename procedure as Phases
  2-3 (identify the stray via state/IMAP/notmuch corroboration, rename the stray in place only),
  re-verifying with `mbsync` per Phase 4 after each.
- [ ] If no other collisions are found, record that the sweep was clean.

**Timing**: 45 minutes

**Depends on**: 4

**Files to modify**:
- Potentially additional `~/Mail/.../cur/<stray-file>` in-place renames, only if collisions are
  found and their strays are corroborated (same never-delete/never-move-out rule).

**Verification**:
- No `,U=<n>` value appears on 2+ files in any swept folder (or each remaining collision has been
  remediated and re-verified with `mbsync` exit 0).

---

### Phase 6: Decide on a durable benign-duplicate guard in mail-sync.nix [NOT STARTED]

**Goal**: Make an explicit, documented decision (and implement it only if chosen) about whether
`modules/home/email/mail-sync.nix` should treat the known, already-tracked duplicate-UID class as a
warning that exits 0, so aerc's check-mail does not red-banner on a benign condition.

**Tasks**:
- [ ] Review the existing `is_duplicate_uid()` branch in `mail-sync.nix`: it already recognizes the
  class and prints manual-remediation guidance but returns `OVERALL_STATUS=1` (the red-banner
  cause).
- [ ] Weigh the trade-off: exiting 0 on the known class stops nuisance banners but risks masking a
  genuine future duplicate-UID corruption. Default recommendation: do NOT silently exit 0 for the
  whole class after this remediation, since Phases 3-5 remove the current corruption and a future
  duplicate-UID SHOULD surface. Only implement a guard if there is a durable, benign, whitelisted
  case that cannot be remediated.
- [ ] If a guard IS chosen: implement it narrowly in `mail-sync.nix` (e.g. a distinct exit code or a
  warning-only path gated to an explicit known-UID allowlist, not a blanket class suppression),
  then `home-manager build --flake .#<user>` (or the repo's build command) to verify the Nix
  change evaluates.
- [ ] Record the decision and rationale in the implementation summary regardless of outcome.

**Timing**: 30 minutes

**Depends on**: 5

**Files to modify**:
- `modules/home/email/mail-sync.nix` - ONLY if a guard is chosen (otherwise unchanged; decision
  recorded in the summary).

**Verification**:
- A written decision with rationale exists.
- If a guard was added: `home-manager build` (or `nix flake check`) succeeds and the guard is
  narrowly scoped (not a blanket suppression of all duplicate-UID failures).

---

## Testing & Validation

- [ ] `mbsync gmail` exits 0 (was: non-zero with `duplicate UID 15`).
- [ ] `mail-sync gmail` exits 0.
- [ ] Both `eNTERTAINMENT cENTER` and `CEO Nick Slape` messages still present in Gmail All Mail
  (web UI) — no server deletion.
- [ ] No second local upload created server-side (Create Near honored) — no server duplicate.
- [ ] `notmuch new --no-hooks` leaves no dangling index entry for the renamed file.
- [ ] `mail-sync-timer.service` `is-failed` returns non-failed.
- [ ] aerc check-mail banner no longer appears.
- [ ] Duplicate-UID sweep across Gmail/Logos folders is clean (or all found collisions remediated).
- [ ] If mail-sync.nix changed: `home-manager build` / `nix flake check` succeeds.

## Artifacts & Outputs

- plans/01_duplicate-uid-remediation.md (this file)
- summaries/01_duplicate-uid-remediation-summary.md (on implementation)
- Task-local evidence records: pre-change filenames/hashes/Message-IDs, `.mbsyncstate` backup, and
  the old→new rename mapping(s) under `specs/114_gmail_allmail_duplicate_uid_remediation/`
- Optionally: `modules/home/email/mail-sync.nix` (only if Phase 6 guard is chosen)

## Rollback/Contingency

- **Primary rollback**: the only mutation is an in-place rename, fully reversible by renaming the
  file back to its recorded original `,U=15` basename (Phase 3 records the exact mapping). Restoring
  the original name reinstates the pre-change state exactly.
- **State-file rollback**: `.mbsyncstate` was backed up in Phase 1; if mbsync behaves unexpectedly,
  restore the backup (no `.mbsyncstate` edit is planned, so this should be unnecessary).
- **Abort conditions**: if Phase 2 cannot positively identify the stray, STOP before Phase 3 — do
  not rename on a guess. If a Gmail-web check ever shows a message missing after any step,
  immediately revert the most recent rename and re-run `mbsync gmail` to reconcile.
- **Never** attempt recovery via `rm`, moving files out of the maildir, or a full state reset;
  these reintroduce the `Expunge Both` deletion / slow-repair risks the plan exists to avoid.
