# Implementation Summary: Task #136

- **Task**: 136 - Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T20:19:34Z
- **Completed**: 2026-11-18T23:06:34Z
- **Effort**: ~9.5 hours total across all dispatches (three prior extraction-pass sittings plus this closing sitting)
- **Dependencies**: 138 (owner-action reconciliation of `~/.sapience/config.json`) -- confirmed applied live before the first reading
- **Artifacts**: plans/03_single-sitting-decision-from-ledger.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Measured how much of this machine's session history Sapience actually captures under manual,
hand-run extraction, and decided -- from the collected numbers, not from a configuration change
chosen up front -- whether to widen the extraction scope, raise the per-run chunk cap, put
extraction on a schedule, or leave the arrangement as it stands. The measurement series closed
at three real extraction passes (recorded over prior dispatches) plus a read-only accrual sample
and vault-content audit added in this dispatch; the decision selects leaving all three candidate
levers unchanged, grounded in the measured figures rather than in an absence of a decision.

## What Changed

- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` -- appended the Phase 4 "no fourth pass" decision, a read-only accrual sample (Available on disk 1793, would ingest now 136, pending 3757), and the series-wide computations: review-queue growth (+2549 over the series, entirely pass-driven), daily-cap headroom, per-day accrual rate (113.6-164.3 objects/day across two full intervals), the re-run two-filter ratio (band holds at 30.13x-31.45x across six readings), the series-completeness check (3 of 5 passes, ~5.44 of >=7 days, 2 of 3 usable before/after pairs, 1 of those clean), and the list of stated limitations.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/02_vault-content-audit.md` -- new; read-only profile of the full 3757-record `pending_kos.jsonl` queue (100% `ko_type: insight`; project split .dotfiles 1687/nvim 1260/sapience-app 810/abood 0) and a 36-record hand-read sample classified 30 substantive / 5 thread-mechanics / 1 duplicate, cross-checked against the client's own mechanics filter (14 rows set aside across the series vs. 5/36 the hand-read additionally flagged).
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/03_extraction-scope-decision.md` -- new; decides all four candidate outcomes (include-headless, chunk-cap/backfill, and backgroundSync timer each rejected on measured grounds; leave-as-is selected), every figure citing a dated ledger or audit block, with a ten-item limitations section naming the reduced evidence base.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/03_single-sitting-decision-from-ledger.md` -- phases 4 through 7 checked off with completion annotations; Phase 7 closed `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` block naming the decision record as the reason no configuration was enacted; Testing & Validation checklist fully checked.

No files outside `specs/**` were modified: the decision selected leaving `home.nix`,
`modules/home/services/sapience.nix`, and `docs/sapience.md`'s underlying contract unchanged, so
there was nothing to enact in those files.

## Decisions

- **Leave all three candidate levers as they are** (outcome (d)). The measured series found no
  evidence supporting (a) adding `includeAgentSessions` (the headless/agent skip count is small,
  ~45, against the non-overridable filter's ~1397 at the same reading, and the vault audit never
  sampled headless/agent-skipped content directly), (b) adjusting the chunk cap or prescribing a
  wider backfill (the measured drain rate shows `would ingest now` held flat across both
  fully-observed passes, so a larger cap would not address a backlog a 50-chunk pass does not
  visibly shrink, and would only accelerate the unreviewed-queue growth that is the real binding
  constraint), or (c) turning on `backgroundSync` (no per-pass cost figure is obtainable at all,
  and the unreviewed queue already tripled across three manual passes with zero review sessions
  run -- automating extraction without addressing review capacity would make that binding
  constraint worse).
- **No further extraction pass was run in this dispatch.** The series was deliberately closed at
  three real passes; a fourth pass run back-to-back with the third would have been exactly the
  near-spaced datum the method calls destroyed rather than delayed.
- **`sapience review` was never run.** Its interactive, share/drop-capable behavior against a
  3757-record queue was judged too risky for an unattended audit; a read-only profile and
  hand-read sample of `~/.sapience/pending_kos.jsonl` substituted for it.

## Plan Deviations

- **Phase 5's duplicate-example task** asked for 3-5 verbatim examples of the duplicate class;
  only one duplicate pair existed in the 36-record sample, so only two verbatim quotes (both
  halves of that one pair) are given, with the shortfall stated explicitly rather than padded.
- **Phase 7's three outcome-specific enactment tasks** (chunk-cap change, `includeAgentSessions`
  addition, `backgroundSync` activation) were each skipped as not selected by the decision --
  annotated as deviations in the plan checklist and the phase's progress file, and the phase
  closed `[COMPLETED WITH EXCLUSIONS]` accordingly, per the plan's own instruction for this case.
- **Phase 7's full-gate-set task** was discharged against this dispatch's Batch Gate Deferral
  directive (scoped `verify-touched.sh --task-dir` check) rather than an independent
  `verify-deploy.sh` run, per that directive's own instruction; the scoped check surfaced 12
  pre-existing, unrelated "mode=source-store" test failures (missing
  `agent-system/extensions/core/scripts/*.sh`, which does not exist in this deploy-consumer
  repository at all) -- confirmed unrelated to this task's `file_scope` and recorded via
  `issue-record.sh` rather than fixed.

## Verification

- Build: N/A (no Nix file changed).
- Tests: `bash .claude/scripts/validate-artifact.sh ... plan` -- [PASS], 0 warnings. Scoped
  `verify-touched.sh --task-dir` run per the Batch Gate Deferral directive; surfaced 12
  pre-existing, unrelated infrastructure failures (not caused by this task), recorded as an
  issue.
- Files verified: Yes -- all ledger summation checks re-verified; every decision-record figure
  traced back to its cited ledger/audit block.

## Impacts

- Tasks `reduce_sapience_classifier_cost` and `diagnose_slow_local_ollama_inference` can proceed
  without waiting on this task further -- this task's roadmap annotation ("parked for now")
  no longer applies, and the measured backlog/cost findings (no per-pass cost signal obtainable;
  per-pass yield 539-2051 objects; 22-48 minute wall clock) are available to inform their own work.
- No change to the live Sapience configuration or behavior -- the current hand-run,
  no-timer, 50-chunk, headless-excluded arrangement continues exactly as before this task.

## Follow-ups

- The unreviewed `pending_kos.jsonl` queue (3757 records at this task's last reading) was
  deliberately left unreviewed and untouched -- reviewing or clearing it is the user's own
  action via `sapience review`, out of this task's scope throughout.
- Two small, unresolved measurement anomalies are recorded but not investigated further: the
  `skipped (headless/agent)` counter dropping by 1 with no pass or review run in between, and the
  one confirmed duplicate knowledge-object pair (lines 3472/3474 of `pending_kos.jsonl`).
- If a future task wants a firmer per-day accrual rate or a true steady-state drain-rate figure,
  this task's own stated limitations (two disagreeing full-day intervals; only one clean,
  fully-observed pass) name exactly what a longer series would need to add.

## References

- Plan: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/03_single-sitting-decision-from-ledger.md`
- Ledger: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md`
- Vault-content audit: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/02_vault-content-audit.md`
- Decision record: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/03_extraction-scope-decision.md`
- Prior research reports: `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/01_coverage-baseline-blocked.md`, `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/02_baseline-and-extraction-backend-blocked.md`
