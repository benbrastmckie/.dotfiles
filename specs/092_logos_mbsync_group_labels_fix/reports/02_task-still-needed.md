# Research Report: Task #92 — Is the Proposed Fix Still Needed?

**Task**: 92 - logos_mbsync_group_labels_fix
**Type**: report
**Started**: 2026-07-11T21:48:00Z
**Completed**: 2026-07-11T21:52:00Z
**Session**: sess_1783806533_7050e6
**Dependencies**: None
**Sources/Inputs**: `modules/home/email/mbsync.nix` (current state), `git show a8f65ad`, `git log -- modules/home/email/mbsync.nix`, `specs/092_logos_mbsync_group_labels_fix/reports/01_mbsync-logos-diagnosis.md`
**Artifacts**: this report
**Standards**: report-format.md

## Answer: PARTIAL

Commit `a8f65ad` (2026-07-05, same day the task-92 diagnosis was written, landed for a
different task — nvim task 826) already fixed the actual crash: `logos-labels` was removed from
`Group logos`, so `mbsync logos` (the wrapper's post-mutation reconcile target) can no longer
abort on the dotted Gmail-import label name `benbrastmckie@gmail.com`. That resolves the concrete,
user-facing symptom task 92 was opened to fix. However, the commit's approach diverges from the
literal 3-part proposal in task 92: `logos-folders` was **kept** in `Group logos` (proposal said
to slim to 5 core channels only), no `Group logos-full` was ever added (proposal part 2), and no
negative dotted-name pattern was added to either `logos-labels` or `logos-folders` (proposal part
3). The last gap is not merely cosmetic: the a8f65ad commit message explicitly claims
`logos-labels` is "kept for optional manual inspection (`mbsync logos-labels`)" but, unpatched,
that manual invocation would still crash on the same dotted label name — so the specific residual
work (negative-pattern hardening, at minimum) is still live and worth doing, even though the
original blocking bug is gone.

## Context & Scope

Task 92 diagnosed a whole-group `mbsync logos` failure and proposed a 3-part fix (slim `Group
logos`; add `Group logos-full`; harden channels with negative dotted-name patterns). This report
checks the current state of `modules/home/email/mbsync.nix` and the intervening commit history to
determine whether that proposed fix (in whole or in part) has already landed, superseding task 92.

## Findings

### 1. Current `Group logos` membership

`modules/home/email/mbsync.nix` lines 207-213:

```
    Group logos
    Channel logos-inbox
    Channel logos-sent
    Channel logos-drafts
    Channel logos-trash
    Channel logos-archive
    Channel logos-folders
```

`logos-labels` is **not** a member (removed by a8f65ad). `logos-folders` **is still** a member —
the proposal's "slim to 5 core channels" was not followed literally; instead the fix scoped out
only the specific channel (`logos-labels`) that carries the duplication/dotted-name risk, per an
explicit design-rationale comment at lines 199-206 (Proton Folders are exclusive per-message, so
no duplication risk exists there, unlike additive Gmail-imported labels).

### 2. `Group logos-full`

Does not exist. `grep -n "logos-full" modules/home/email/mbsync.nix` returns zero hits anywhere in
the file (only a comment reference to "task 826" on line 173 partially matches "Group logos"
above it). Proposal part 2 (add an explicit on-demand full-sync group covering
labels+folders) was **not implemented**.

### 3. Negative dotted-name patterns

Not added. Current patterns, unchanged since before a8f65ad:

- `logos-labels` (line 184): `Patterns "Labels/*"` — no `"!Labels/*.*"` exclusion.
- `logos-folders` (line 193): `Patterns "Folders/*"` — no `"!Folders/*.*"` exclusion.

Proposal part 3 was **not implemented**. Practical consequence: `mbsync logos-labels` run
manually today would still hit `SubFolders style Maildir++ does not support dots in mailbox
names` on the `benbrastmckie@gmail.com` label — the exact crash task 92 diagnosed, just now
confined to a channel that is no longer in the auto-invoked group.

### 4. Per-fix-part classification

| # | Proposed fix part | Status | Evidence |
|---|---|---|---|
| 1 | Slim `Group logos` to 5 core channels (inbox/sent/drafts/trash/archive only) | **PARTIAL** (functionally equivalent, differently scoped) | Lines 207-213: group has 6 channels, not 5 — `logos-folders` retained. `logos-labels` (the actual crash source) removed. Root-cause blocking bug (whole-group crash on dotted label) is fixed; the specific "5 channels only" shape of the proposal was not followed, with an explicit rationale (lines 199-206) for why `logos-folders` is safe to keep (exclusive Folders vs. additive Labels). |
| 2 | Add `Group logos-full` (core + labels + folders) for on-demand full sync | **NOT DONE** | No `Group logos-full` anywhere in the file (`grep -n "logos-full"` empty). `logos-labels` channel definition still exists standalone (lines 181-188) for "manual inspection" per the a8f65ad commit message, but there is no group wrapping it with the other channels for a single-command full sync. |
| 3 | Harden `logos-labels`/`logos-folders` with `"!Labels/*.*"` / `"!Folders/*.*"` negative patterns | **NOT DONE** | Line 184: `Patterns "Labels/*"` (unchanged). Line 193: `Patterns "Folders/*"` (unchanged). No negative-pattern exclusion present in either channel. |

### 5. What commit a8f65ad actually did vs. the full proposed fix

`git show a8f65ad -- modules/home/email/mbsync.nix` shows exactly one substantive change to the
Logos section: removal of the line `Channel logos-labels` from `Group logos` (previously present
between `Channel logos-archive` and `Channel logos-folders`), plus ~15 lines of new explanatory
comments justifying the removal and explaining why `logos-folders` was kept. The commit was
authored for a **different task** (`nvim task 826`, `specs/826_logos_maildir_duplication_mbsync_repair`
in the `~/Mail` repo, per the commit body), not task 92 — it landed as a side effect of that
separate maildir-deduplication effort, which independently diagnosed the same root cause (additive
label duplication + dotted Maildir++ name crash) task 92 also found. The commit's fix is narrower
and differently shaped than task 92's 3-part proposal:

- Matches part 1's *intent* (stop the group-wide crash) but not its *literal shape* (kept
  `logos-folders`, proposal wanted it excluded too).
- Does not implement part 2 at all (no `logos-full` group).
- Does not implement part 3 at all (no negative patterns — so the "optional manual inspection"
  path for `logos-labels` that the commit message describes is not actually safe to run yet).

`git log --oneline -- modules/home/email/mbsync.nix` confirms a8f65ad is the only commit to this
file since task 92 was created (2026-07-05); no follow-up commit has added `logos-full` or
negative patterns.

### 6. Secondary issues (duplicate UID, missing Date header)

Not addressed in this repo's `mbsync.nix` — and not expected to be, since both are **data-level**
issues (specific message files with a duplicate `U=` token or a missing `Date:` header), not
`mbsync.nix` configuration issues; no line in the current file references UID surgery or
message-repair tooling. The a8f65ad commit message states the maildir de-duplication/cleanup
itself was handled in the `~/Mail` repo's task 826, which is out of this repository's scope and
was not verified as part of this research (per the task instructions, this research is scoped to
`modules/home/email/mbsync.nix` and its git history only). Task 92 already treated these as
"secondary — note, don't necessarily fix here," so their disposition does not change the
recommendation below.

## Decisions

- Treat the whole-group-crash blocking bug as resolved by a8f65ad; it is not necessary to
  re-implement proposal part 1 in its literal 5-channel form, since the current 6-channel
  `Group logos` (with `logos-folders` retained for a documented, non-duplicating reason) already
  achieves the operational goal (successful `mbsync logos` reconcile).
- Treat proposal parts 2 and 3 as still-open, narrowly-scoped residual work, not full re-litigation
  of the original diagnosis.

## Risks & Mitigations

- **Risk**: Someone runs `mbsync logos-labels` manually for "inspection" (as the a8f65ad commit
  message invites) and hits the same dotted-label crash task 92 originally diagnosed, because no
  negative pattern was added. **Mitigation**: implement proposal part 3 (`"!Labels/*.*"` /
  `"!Folders/*.*"`) so the manual-inspection promise in the a8f65ad commit message is actually
  honored.
  - **Recommendation for a future implementation, if task 92 is kept open**: also add the
    negative pattern to `logos-folders` even though it is in the auto-synced group and has not
    crashed — Proton could introduce a dotted Folder name in the future (e.g. via a Gmail-style
    import), and the guard is cheap defensive hardening consistent with the file's existing
    Gmail-trash/spam-exclusion precedent.
- **Risk**: No `Group logos-full` exists, so there is no single documented command for an
  intentional full sync including labels/folders; an operator must run `mbsync logos-labels`
  and `mbsync logos-folders` separately (and the former would still crash per above).
  **Mitigation**: implement proposal part 2 alongside part 3.

## Recommendation

Mark task 92 **PARTIAL**, not COMPLETED and not ABANDONED:

- The task's primary trigger — `mbsync logos` (the wrapper's post-mutation reconcile) exiting
  non-zero because the whole group choked on a dotted Gmail-import label name — is **already
  fixed** by `a8f65ad`, landed incidentally via a different task. No further work is required to
  unblock the wrapper's routine reconcile path.
- Two of the three specific sub-fixes task 92 proposed (`Group logos-full`; negative
  dotted-name patterns on `logos-labels`/`logos-folders`) were **never implemented**, and the
  negative-pattern gap means the "kept for manual inspection" claim in the a8f65ad commit message
  is not actually true today — `mbsync logos-labels` would still crash if invoked.
- If the remaining value is judged worth a small follow-up (adding `Group logos-full` +
  `"!Labels/*.*"` / `"!Folders/*.*"` patterns, roughly a 10-15 line diff mirroring the sketch
  already in `reports/01_mbsync-logos-diagnosis.md`), keep task 92 open, narrow its scope to just
  those two remaining items, and route it directly to `/plan` (research is effectively already
  done, in `reports/01` plus this report). If that residual convenience/hardening is judged not
  worth a dedicated task, task 92 could instead be marked ABANDONED with a completion note citing
  a8f65ad as having addressed the operationally significant part of the original bug — but that is
  a scope/priority call for the user, not a technical determination this report can make alone.
