# Implementation Summary: Task #108

- **Task**: 108 - census freshness rename/deletion-aware signal
- **Status**: [COMPLETED]
- **Started**: 2026-07-13T20:10:54Z
- **Completed**: 2026-07-13T21:05:00Z
- **Artifacts**: plans/01_freshness-set-diff-signal.md, reports/01_freshness-signal-research.md

## Overview

Implemented Approach 1 (RECOMMENDED) from the task's research report: an INBOX-scoped,
UID-joined literal-filename set-diff added to `email-census`'s freshness line, closing a
live-verified false-green gap where a same-count divergence (a maildir flag-rename, or an
add/remove pair that nets to zero) hid behind `divergence=0 [ok]` under the pre-existing
count-tolerance check alone.

## What Changed

- `modules/home/email/agent-tools/census.nix` — added the set-diff computation (an INBOX-scoped
  `find` over `cur`/`new` joined against the existing path-prefix-filtered `notmuch
  --output=files` listing, keyed on the maildir `,U=<n>:` UID token via a single `awk` pass) and
  wired it into the verdict and output line. The freshness line now emits `renamed=<R>
  removed=<X> added=<A>` before the trailing `[ok|STALE]` bracket; the verdict flips `[STALE]`
  if either the pre-existing count-tolerance check OR the new exact-set check
  (`renamed+removed+added > SETDIFF_TOL`, `SETDIFF_TOL=0`) fires. A count-equality guard degrades
  safely to `renamed=? removed=? added=? [STALE]` if `find`'s file count ever disagrees with the
  already-computed himalaya on-disk count.
- `.claude/context/project/email/domain/wrapper-contracts.md` §13 — documented the new fields,
  the "[ok] requires BOTH checks" verdict rule, the join mechanism, the count-equality guard, the
  `"?"` fallback convention, and the required-query-form constraint (never `count`/`tag:`-based).
- `.claude/context/project/email/domain/staleness-detection.md` — added a new section describing
  the exact-set signal as the authoritative rename/deletion-aware contract, with the live-verified
  false-green example, INBOX-only scope (All_Mail explicitly deferred), and the required
  `skill-email-cleanup` Stage 1 parser follow-up.

## Decisions

- Basename reduction for the indexed-side filename list is done inline inside the `awk` join
  (`sub(/.*\//, "", base)`) rather than a separate `sed` pipe stage the plan sketched — functionally
  identical, one fewer subprocess.
- `SETDIFF_TOL=0`: live back-to-back `email-census` runs against the real Gmail INBOX with no
  intervening mail activity produced identical, stable `renamed=1 removed=2 added=2` both times
  (real persistent drift, not jitter), so no tolerance slack was warranted.
- Live verification invoked the newly built `email-census` derivation directly at its Nix store
  path (`nix build` of the derivation's `drvPath`, evaluated from
  `homeConfigurations.benjamin.config.home.packages`) rather than running a full
  `home-manager switch`, since activating a new system generation is a separate, invasive
  operation outside this config-file task's scope. The built binary is byte-identical to what a
  switch would place on `$PATH`.

## Plan Deviations

- **Task 1.1** (Phase 1, basename-reduction step) altered: inline `awk` substitution instead of a
  separate `sed` pipe stage — functionally identical.
- **Task 3.1-3.2** (Phase 3, build/`$PATH` steps) altered: built and invoked the derivation at its
  store path rather than performing a full `home-manager switch`, to avoid an out-of-scope live
  system-generation change.
- **Task 3.5** (Phase 3, synthetic flag-rename) altered: no synthetic drift was manufactured —
  existing live drift on the real mailbox already reproduced the exact flag-rename case
  (`renamed=1`), confirmed read-only.
- All other tasks across all four phases were completed exactly as planned; no tasks were
  skipped.

## Verification

- `nix flake check`: Success (run after Phase 1, Phase 2, and again after Phase 4 — all pass).
- `nix build` of the `email-census` derivation: Success (built cleanly after both Phase 1 and
  Phase 2 edits).
- `bash -n` syntax check of the built wrapper script: Success (both builds).
- Live `email-census --account gmail` run against the real Gmail INBOX: Success. Output:
  `INBOX freshness  on-disk=86  indexed-files=86  divergence=0  tol=9  reindex=never  renamed=1
  removed=2  added=2  [STALE]` — a direct, live reproduction of the exact false-green gap this
  task closes (the old count-only logic would have read `[ok]` here).
- Back-to-back live runs: stable, identical output both times — confirms `SETDIFF_TOL=0` is
  correct with no jitter-driven false STALE risk.
- Count-mismatch fallback path: not exercisable live (on-disk counts agree today); confirmed
  correct by code inspection — the guard sets all three fields to `"?"` on mismatch, and the
  verdict logic's numeric-regex check then routes to its `else` branch, forcing `[STALE]`.
- Read-only invariant preserved throughout: only `find`, `notmuch search`, and `himalaya envelope
  list` were invoked; no `email-reindex`, `mbsync`, or any mutation call was made at any point.

## Notes

- The census change surfaces the richer signal on stdout but does not itself teach
  `skill-email-cleanup`'s Stage 1 parser to branch on the new fields individually — this is
  explicitly documented as a required follow-up in both updated doc files, per the task's
  Non-Goals.
- The live drift observed during verification (`renamed=1 removed=2 added=2`, `reindex=never`) is
  real, pre-existing mailbox state — not a defect introduced by this change. No reindex was run
  as part of this task, per the explicit Non-Goals.
- The two updated doc files under `.claude/context/project/email/domain/` are modified on disk
  (verified) but the entire `.claude/` directory is repo-gitignored (`.gitignore` line 36), so
  they are invisible to `git status`/`git diff` and are not part of any git commit for this task
  — only `modules/home/email/agent-tools/census.nix` is a tracked, committable change.
