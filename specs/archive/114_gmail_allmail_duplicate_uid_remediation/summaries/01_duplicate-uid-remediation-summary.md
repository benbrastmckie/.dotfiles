# Task 114 — Gmail All_Mail Duplicate-UID Remediation — Implementation Summary

**Task**: 114 (gmail_allmail_duplicate_uid_remediation)
**Status**: COMPLETED
**Risk class**: HIGH (gmail-all channel is `Expunge Both` — mishandling could permanently
delete real Gmail All Mail messages)
**Outcome**: `mbsync gmail` and `mail-sync gmail` now exit 0 with zero server-side change.

## Objective

Remediate the pre-existing duplicate-UID collision in `~/Mail/Gmail/.All_Mail` that made
`mbsync gmail` (and thus `mail-sync gmail`) exit non-zero — surfaced by task 113 as a recurring
aerc `checkmail: error running command: exit status 1` banner and a failing mail-sync timer.

## What was done

### Duplicate-UID collisions (the core task) — 149/149 resolved

- **Confirm-before-mutate**: for each collision, the stray file was positively identified via
  read-only IMAP `FETCH`/`SEARCH` Message-ID corroboration against `.mbsyncstate` (and notmuch as
  a secondary signal) before any change. No file was renamed on a guess.
- **Rename-in-place only**: the confirmed stray in each collision had its `,U=<n>` UID suffix
  stripped by a same-directory `mv` (e.g. `…hamsa,U=15:2,` → `…hamsa:2,`). No file was ever
  `rm`'d or moved out of its maildir folder. Every rename is recorded with a verbatim reversal
  mapping (artifacts 03, 05, 06) and sha256-verified identical before/after.
- **Scope of collisions**: the original `,U=15` case plus `,U=104` plus 147 more found by the
  Phase 5 sweep — all 149 in `Gmail/.All_Mail/cur`, zero in any other Gmail folder and zero in
  Logos. After remediation, **0 duplicate-UID collisions remain** in any swept folder.

### Secondary blocker — stray empty directory (user-authorized follow-up)

- After all collisions were cleared, `mbsync gmail` still exited non-zero on a **separate,
  pre-existing** blocker: a stray non-mail directory `~/Mail/Gmail/.All_Mail/cur/specs,U=67297`
  (created Jul 13, before this task) causing `Maildir error: cannot read …: Is a directory`.
- It was verified (read-only) to be three nested **empty** directories (0 files), never pushed to
  the server (near-UID 67297 has no `.mbsyncstate` mapping and exceeds `MaxPushedUid` 67147, so no
  server counterpart), shadowing no real repo content, referenced nowhere. It was the sole
  remaining non-file entry in `All_Mail/cur`.
- The implementation agent correctly declined to remove it autonomously (deletion is outside the
  task's "rename-in-place-only" mutation scope). It was removed only after **explicit user
  authorization**, via `rmdir` of the empty directories innermost-first (rmdir's empty-only
  guarantee as the safety net). Recorded in artifacts/12_stray-dir-removal.txt (reversible by
  recreating the empty dirs).

### Phase 6 — mail-sync.nix benign-duplicate guard decision

- **Decision: NO guard added.** With all 149 collisions resolved there is no remaining benign
  class to whitelist; a guard now would be a blanket suppression that could hide genuine future
  duplicate-UID corruption. `mail-sync.nix` is unchanged. Full rationale in
  artifacts/10_phase6-guard-decision.md.

## Verification (definition of done)

| Criterion | Result |
|-----------|--------|
| `mbsync gmail` exits 0 | ✅ exit_code=0, `Far: +0 *0 #0 -0` (artifacts 13, 14) |
| `mail-sync gmail` exits 0 | ✅ exit_code=0 (artifact 15) |
| Both colliding messages retained server-side | ✅ "CEO Nick Slape" (now U=67148) + "eNTERTAINMENT cENTER" (U=15) present, distinct Message-IDs; IMAP-confirmed |
| No server-side deletion | ✅ `Far: -0` on every post-fix sync |
| No server duplicate (Create Near honored) | ✅ `Far: +0` on every post-fix sync |
| notmuch: no dangling entries | ✅ (artifacts 04, 07) |
| mail-sync-timer not is-failed | ✅ restarted, not-failed |
| aerc banner cleared | ✅ mail-sync exits 0 → no exit-status-1 source |
| Duplicate-UID sweep clean | ✅ 0 remaining across Gmail + Logos |

## Safety outcome

The HIGH-risk `Expunge Both` deletion hazard was fully avoided: **every** post-fix `mbsync gmail`
run reports `Far: -0` (zero Gmail server-side expunges) and `Far: +0` (nothing uploaded). All
mutations were reversible (in-place renames + empty-dir rmdir), and both originally-colliding
messages are retained.

## Residual notes / follow-ups (out of scope for task 114)

1. **Minor recurring `Near: +2`**: each `mbsync gmail` run downloads 2 messages near-side that do
   not appear to fully settle. It is benign (exit 0, `Far: +0`, no data loss — the direction is
   server→local) but could warrant a small follow-up if it persists.
2. **Second stray-path contamination at `~/Mail/specs/`** (root of Mail, not inside a maildir):
   `state.json`, `TODO.md`, `ROADMAP.md`, `email-manifests/…`, etc. notmuch ignores these as
   non-mail and mbsync never scans there, so it is **not** a sync blocker — but it is the same
   class of accidental relative-path contamination and should be cleaned up separately.

## Key artifacts

- Rename/reversal mappings: 03, 05_bulk-rename-mapping.tsv, 05_rename-mapping-uid104.txt,
  06_final6-rename-mapping.tsv, 12_stray-dir-removal.txt
- Corroboration evidence: 02_*, 05_*, 06_*
- Sync verification: 13_mbsync-gmail-post-rmdir.log, 14_mbsync-gmail-stable.log,
  15_mail-sync-gmail-dod.log
- Stray-directory investigation: 08_stray-directory-finding-NOT-REMOVED.md
- Phase 6 decision: 10_phase6-guard-decision.md
