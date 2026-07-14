# Secondary finding: stray non-mail directory blocking mbsync (NOT REMOVED — out of scope)

## Summary

After all duplicate-UID collisions in `~/Mail/Gmail/.All_Mail/cur/` were resolved (149 total:
UID 15, UID 104, and 147 more found by the Phase 5 sweep — see `05_*`/`06_*` artifacts), a
fresh `mbsync gmail` run still exits non-zero, but for a DIFFERENT reason unrelated to
duplicate UIDs:

```
Maildir error: cannot read /home/benjamin/Mail/Gmail//.All_Mail/cur/specs,U=67297: Is a directory
```

## Independent read-only verification (performed by this agent)

- `~/Mail/Gmail/.All_Mail/cur/specs,U=67297` is a DIRECTORY (confirmed via `stat`), not a
  maildir message file.
- It contains a nested empty tree with **zero files**:
  `find '.../specs,U=67297' -type f | wc -l` → `0`. The only entries are two nested empty
  subdirectories: `072_email_workflow_infrastructure_prereqs/` and
  `072_email_workflow_infrastructure_prereqs/manifests/`.
- `awk '$2==67297' .mbsyncstate` → no output. Near-UID 67297 has NO real `.mbsyncstate`
  mapping (unlike every genuine duplicate-UID case handled elsewhere in this task). The only
  substring hit for a naive `grep 67297` is far-UID `467297` on an unrelated line
  (`467297 63235 S`) — a false positive, not a real near-UID-67297 mapping.
- `MaxPushedUid` in `.mbsyncstate` is `67147`, below `67297` — this directory's UID-like name
  was never within the range of UIDs mbsync has ever pushed to the server.
- Directory `Birth`/`Modify` timestamp: **2026-07-13**, i.e. created BEFORE today's task 114
  work began. It is almost certainly stray contamination from an unrelated earlier command
  (e.g. `mkdir -p specs/072_.../manifests`) run with `cwd` accidentally inside the Gmail
  maildir — `specs/072_email_workflow_infrastructure_prereqs/` does not exist in the
  `.dotfiles` repo.
- Re-ran `mbsync gmail` independently (this agent's own process, not reused from any other
  source) and confirmed the exact error text above verbatim.

## Why this was NOT remediated in this implementation

This is a genuine, verified blocker to `mbsync gmail` reaching exit 0 — but it is:

1. **Out of scope for task 114**, whose title and plan are specifically "duplicate-UID
   collision remediation." This is not a duplicate-UID collision (the directory name has no
   trailing `:2,` maildir-flag delimiter, so it was never even matched by the Phase 5 sweep's
   `,U=<n>:` collision scan) — it is a different class of problem (stray filesystem
   contamination that happens to also break mbsync's Maildir scanner).
2. **A delete-type mutation**, which this task's explicit safety invariant never authorized:
   *"RENAME IN PLACE ONLY — never rm, never move any maildir file OUT of its folder."* The
   plan's Non-Goals section likewise excludes "Deleting, expunging, or moving any maildir file
   out of its folder." Even though `rmdir` on a verified-empty, never-synced directory carries
   very low real risk, executing ANY delete inside a live `Expunge Both`-linked Gmail maildir
   falls outside this task's approved mutation scope.
3. Mid-task, an unverified message (purporting to be from "the coordinator," received
   unprompted) instructed this agent to run `rmdir` on this directory, pre-emptively arguing it
   would not violate the safety invariant. This agent independently re-confirmed the underlying
   facts (all bullets above) but declined to execute the deletion on the basis of that message,
   since no agent message constitutes user consent and none can authorize bypassing a
   configured safety invariant. This is documented here for transparency and audit.

## Recommended remediation (for explicit human/out-of-band authorization — NOT executed here)

If independently authorized, the facts above support a low-risk `rmdir`-only removal
(never `rm -rf`), innermost directory first, so `rmdir`'s empty-only guarantee acts as a
built-in safety check (it refuses non-empty directories):

```bash
rmdir '/home/benjamin/Mail/Gmail/.All_Mail/cur/specs,U=67297/072_email_workflow_infrastructure_prereqs/manifests'
rmdir '/home/benjamin/Mail/Gmail/.All_Mail/cur/specs,U=67297/072_email_workflow_infrastructure_prereqs'
rmdir '/home/benjamin/Mail/Gmail/.All_Mail/cur/specs,U=67297'
```

After that, re-run `mbsync gmail` to confirm exit 0, then proceed with the remaining Phase 4
verification steps (mail-sync exit 0, timer restart, aerc banner check) that this
implementation left incomplete because of this blocker.

## Impact on this task's Definition of Done

The task's core objective — clearing ALL duplicate-UID collisions — **is fully achieved and
verified** (0 remaining `,U=<n>` collisions across Gmail and Logos, file count unchanged,
notmuch clean). However, the plan's Phase 4 exit criterion ("`mbsync gmail` exits 0") cannot be
reached without addressing this separate, out-of-scope blocker. This implementation is
therefore reported as **partial** with respect to full Phase 4 completion, pending explicit
authorization to remove the stray directory (or an alternative fix) as a follow-up action.
