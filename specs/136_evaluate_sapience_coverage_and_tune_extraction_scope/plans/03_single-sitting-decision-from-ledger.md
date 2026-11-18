# Implementation Plan: Sapience extraction-scope decision from the recorded ledger, in one sitting

- **Task**: 136 - Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Status**: [IMPLEMENTING]
- **Effort**: 9.5 hours total, of which roughly 5.5-6.5 hours remain; the remaining work runs in one sitting with no calendar spacing
- **Dependencies**: 138 (owner-action reconciliation of `~/.sapience/config.json`) -- confirmed applied live, see Premise Re-Validation below
- **Research Inputs**:
  - `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/02_baseline-and-extraction-backend-blocked.md` (figures superseded, see below)
  - `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/01_coverage-baseline-blocked.md`
- **Artifacts**: plans/03_single-sitting-decision-from-ledger.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
- **Type**: general
- **Lean Intent**: false

## Overview

This task measures how much of this machine's session history Sapience actually captures and
decides, from collected numbers, whether to widen the extraction scope, raise the per-run chunk
cap, put extraction on a schedule, or leave the arrangement as it stands. The measurement series
is now closed at the three real extraction passes already recorded in
`records/01_coverage-pass-ledger.md`: the remaining phases reach the decision from that recorded
evidence plus read-only `sapience coverage` / `sapience pending` sampling, which costs nothing and
needs no extraction run. No further paid extraction pass is run, and no phase waits on the
calendar. Done means a written decision on each of the four candidate outcomes, with every figure
in it traceable to a dated ledger block, and with the reduced evidence base recorded as a stated
limitation of that decision.

### Premise Re-Validation

Required by this dispatch's Premise Re-Validation section. Each result is stated explicitly, and
two of the three are **not** confirmations.

**The task 138 precondition and its recorded obligation: discharged, re-verified live.**
`.decisions.json`'s cycle-4 answer claims the owner instruction was applied. Live read at the
originating dispatch confirms it: `jq -c '.folders' ~/.sapience/config.json` returns exactly
`["-home-benjamin--config-nvim","-home-benjamin--dotfiles","-home-benjamin-Projects-abood","-home-benjamin-Projects-Sapience-sapience-app"]`,
and `sapience coverage` independently reports `Folders selected (4): nvim, dotfiles, app, abood`.
The obligation that recorded route named is discharged; the measurement window is open and no
re-ask is warranted.

**Description line 52 (the non-overridable subagent/harness-started filter): confirmed
unchanged.** The live journal line from the 2026-11-13 12:06:52 run reads verbatim
`sapience: skipped 6 harness-started transcripts (thread mechanics, not knowledge;
SAPIENCE_INCLUDE_HEADLESS=1 does not override this)`. The description's characterisation of this
filter is accurate as written, and Pass 3's own journal line (`skipped 18 harness-started
transcripts`, same parenthetical) repeats it verbatim at the anthropic backend.

**Description line 71 (whether 50 chunks per pass can keep up with the backlog): the premise has
materially shifted and this plan reframes it.** `MAX_CHUNKS` is still 50 (confirmed live in the
`Per-run extraction cap: 50 chunks (MAX_CHUNKS)` coverage line and at
`modules/home/services/sapience.nix:397`, `budget="${MAX_CHUNKS:-50}"`). But the backlog-drain
framing is no longer the binding constraint. A real 50-chunk pass takes 29-48 minutes and stages
between 550 and 2051 knowledge objects, and the unreviewed queue it feeds has tripled in two
passes, so the depth of that queue binds before the chunk cap does. The decision phase answers
the description's question, but it answers it against those constraints rather than against drain
rate alone.

**The research report's blocker is resolved, and all of its figures are superseded.**
`reports/02_baseline-and-extraction-backend-blocked.md` reports every one of 50 chunk calls
failing with `HTTP Error 402: Payment Required` against `gemma4:cloud` and sets a blocking
`user_decision` on Ollama billing. That blocker was resolved by a route none of the four offered
options named: commit `2b713bf` ("sapience: move extraction to the anthropic backend") switched
`programs.sapience` to `backend = "anthropic"`, `model = "claude-haiku-4-5"`, with
`apiKeyFile = "/run/secrets/anthropic_api_key"`. The deployed unit
(`/nix/store/qc34qy2m0g978zlqisblv4lghzajyf4p-sapience-sync`) passes
`--backend "anthropic" --model "claude-haiku-4-5"`, and `sapience coverage` reports
`Backend: anthropic`. The `user_decision`'s own stated obligation -- make at least one documented
way to run a pass actually complete chunk extractions -- is therefore discharged, and this plan
raises no new decision on it.

Superseded figures, stated side by side so no later dispatch carries the old ones forward:

| Figure | reports/02 (ollama, 402-failing) | Plan-time reading (anthropic) |
|--------|----------------------------------|-------------------------------|
| Backend | ollama / `gemma4:cloud` | anthropic / `claude-haiku-4-5` |
| Available on disk | 1133 | 1153 |
| would ingest now | 74 | 78 |
| skipped (headless/agent) | 30 | 30 |
| skipped (subagent / harness-started) | 885 | 900 |
| skipped (folder not chosen) | 144 | 145 |
| `sapience pending` | 0 | 1208 |
| Objects staged by a 50-chunk pass | 0 (all calls failed) | 1208 |
| Wall clock for a 50-chunk pass | 16.677s (fast-fail) | 29min 4.283s (real) |

Every figure in that right-hand column is a plan-time reading and is itself superseded the moment
a phase takes its own. **No phase below may cite this table as its measurement.**

### Research Integration

No new research reports have been produced since the prior plan round: this dispatch's
`new_research_paths` was empty, so this revision integrates no report that the prior plan had not
already integrated. Reports integrated into this plan remain
`reports/01_coverage-baseline-blocked.md` and `reports/02_baseline-and-extraction-backend-blocked.md`.

Three findings from `reports/02` survive the backend migration and are carried into the plan:

- **The two-filter asymmetry is real and large.** 30 transcripts skipped as headless/agent against
  900 skipped as subagent/harness-started -- the non-overridable filter removes roughly 30x more
  than the overridable one. The report correctly declines to call this settled from one reading;
  the recorded series has since confirmed it across five readings, and the decision phase decides
  from those five.
- **The counters partition the backlog with no remainder.** 78 + 0 + 30 + 900 + 145 = 1153,
  matching "Available on disk" exactly. Every reading re-runs that arithmetic as a cheap integrity
  check.
- **Readings must never be carried forward.** The report measured "Available on disk" growing from
  1133 to 1136 in twelve minutes purely from new transcripts. Each phase below captures its own
  fresh readings; the Scope Hypothesis on every phase makes that obligation explicit.

### Prior Plan Reference

The prior plan round is
`specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/02_coverage-measurement-series-and-decision.md`,
which structured the task as a five-pass series with a `>=24 hours since the previous pass` gate
on each pass phase and a seven-day span requirement. Phases 1, 2 and 3 of that plan ran and are
carried into this plan unchanged, with their recorded completion annotations intact. The user has
decided to close the extraction series at the three real passes those phases recorded and reach
the decision from that evidence in one sitting; see `## Decisions` below for what that changes and
what it costs.

### Roadmap Alignment

`specs/ROADMAP.md` was provided as this dispatch's `roadmap_path`. The roadmap carries no batch
entry that this task's remaining phases alter, and this revision adds, removes, or reorders no
roadmap phase: the change is a scope reduction inside this task's own measurement method.

## Goals & Non-Goals

**Goals**:

- Produce a baseline reading of `sapience coverage` and `sapience pending` against the live
  anthropic backend, with the four skip counters recorded verbatim.
- Close the extraction series at the three real passes already recorded, and answer the remaining
  measurement questions from those recorded readings plus fresh read-only `sapience coverage` /
  `sapience pending` sampling, which needs no extraction pass.
- Establish, from the series rather than from one reading, which of the two filters dominates and
  at what ratio.
- Establish what the recorded passes do and do not show about the drain rate, the per-pass yield
  variability, and the growth of the unreviewed review queue, naming explicitly each question
  three passes cannot answer.
- Audit what the vault actually holds, read-only, confirming the captured material is substantive
  work rather than thread mechanics.
- Decide each of the four candidate outcomes explicitly, with the measured figure that supports
  or refutes it, record the reduced evidence base as a stated limitation of that decision, and
  enact whatever the decision selects.

**Non-Goals**:

- Reducing the per-call cost of extraction, or making local inference viable. Those are owned by
  tasks 139 (`reduce_sapience_classifier_cost`) and 140 (`diagnose_slow_local_ollama_inference`);
  this plan measures cost only well enough to keep the decision honest and defers the work there.
- Approving, sharing, or dropping any staged knowledge object. The review gate is the user's, and
  the vault-content audit phase is deliberately read-only (see its first task for why).
- Re-litigating task 138's capture set. The four-repository folder selection is this task's given
  denominator, not its subject.
- Editing anything under `~/.sapience/` (vendor-owned, regenerated by activation) or under
  `.claude/**` (a disposable deploy artifact).
- Changing the extraction backend or model. The migration to anthropic is a settled given here.
- Running any further extraction pass. The evidence base is closed at the three real passes in
  the ledger; a further pass is out of scope for every remaining phase, and a pass run
  back-to-back with Pass 3 would destroy the datum it purports to add rather than delay it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A later dispatch carries this plan's plan-time figures forward instead of re-measuring | H | H | Every phase carries a Scope Hypothesis naming its asserted figures as plan-time or ledger-carried readings the implementer must re-take or re-read; the Premise Re-Validation table above is marked non-citable |
| The decision is drawn from three passes over five calendar days and is read later as if it rested on the original five-pass, seven-day series | H | H | The analysis phase runs the completeness check over what actually exists and names each criterion it falls short of; the decision phase must carry those shortfalls in its own limitations section, and may not assert a figure in place of a question the series cannot answer |
| An agent reads "finish in one sitting" as license to add a quick extra pass to strengthen the series | H | M | A further pass is a stated Non-Goal; the analysis phase's first task is to run no pass and to record why a near-spaced pass would be worse than none |
| `sapience review` run unattended shares or drops the whole queue, now 3757 objects deep | H | M | The audit phase forbids it by name and substitutes a read-only read of `~/.sapience/pending_kos.jsonl`; the substitution and its reason are recorded in the phase itself |
| Pass 2's 34 `extract error:` lines are averaged into the drain-rate figures rather than excluded | H | M | Pass 2 is already flagged in the ledger as unusable as a clean drain-rate datum; that flag is preserved, and the decision phase must exclude it from the drain-rate columns by name |
| The analysis phase silently asserts a figure for a question only a longer series could answer | H | M | Each such question must be named as a stated limitation with no figure in its place; the phase's own verification checks for exactly that |
| The unreviewed queue grows faster than review can drain it, making capture without review the real constraint | M | H | The queue's growth is computed across the whole recorded series and weighed in the decision independently of cost and of the chunk cap |
| No per-pass cost figure is obtainable from the client's own output | M | H | Confirmed three times in the ledger; the decision may not recommend a cap increase or a timer on an unmeasured cost, and must say so plainly |
| The final phase's file set overlaps tasks 139 and 140, which both declare `home.nix` and `docs/sapience.md` | M | M | Noted here for the orchestrator: serialize the final phase against 139/140 with a dependency edge rather than running them concurrently |

## Decisions

- **The extraction series is closed at three real passes, and no further pass is run.** The user
  decided to stop paying for a day-spaced pass series and to reach the decision from the evidence
  already collected. The cost is accepted and recorded, not argued away: three real passes rather
  than five, five calendar days (2026-11-13 to 2026-11-18) rather than seven, and one of the three
  unusable as a clean drain-rate datum. The decision phase carries all three as stated limitations.
- **No `>=24 hours since the previous pass` gate survives in any remaining phase, and no softer
  gate replaces it.** The gate was a measurement requirement of the five-pass method; with the
  series closed, it gates nothing.
- **A pass run back-to-back with Pass 3 is rejected outright, not merely unrequired.** The prior
  plan's own ruling applies -- "running early destroys the datum rather than delaying it" -- so a
  near-spaced pass would make the series worse rather than longer. This is why the reduction is a
  clean stop rather than a compressed series.
- **Read-only `sapience coverage` / `sapience pending` sampling substitutes for anything that
  still needs an accrual-over-time signal.** Those readings cost nothing and need no extraction
  run, and the recorded series already shows `Available on disk` growing 1611 -> 1786 across the
  passes, with +6 and +5 observed *during* a pass.

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
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. This plan has no parallelism by design: each
phase reads what the previous phase recorded. The calendar spacing that the superseded pass
phases required is gone -- phases 4 through 7 run in one sitting.

---

### Phase 1: Re-baseline on the Anthropic Backend and Open the Measurement Ledger [COMPLETED]

**Goal**: Establish the post-migration baseline against the correct population, create the ledger
every later phase appends to, and retro-record the one pass that has already succeeded.

**Tasks**:

- [x] Create `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md`
      with a fixed per-pass block shape, so every later phase records the same fields: pass number;
      ISO 8601 UTC timestamp; invocation path used; wall clock from `systemctl --user status`; chunk
      count; objects staged; `sapience pending` before and after; the `Available on disk` total and
      all five sub-counters verbatim before and after; the `Per-run extraction cap` line; the
      `Folders selected` line; the day's `sapience yield` line against the 2000-objects/day cap;
      every `extract error:` line from the journal (with an explicit `0 errors` when there are none);
      and the redaction / set-aside counts. *(completed)*
- [x] Confirm the live backend wiring before taking any reading, recording all three verbatim:
      `jq -c '{backend, model, api_key_env}' ~/.sapience/config.json`; the `ExecStart` script's
      `--backend`/`--model` flags via `systemctl --user cat sapience-sync.service` and a read of the
      script it names; and the `Backend:` line of `sapience coverage`. *(completed)*
- [x] Record, without changing either file, the one live residue of the report's model-mismatch
      finding: `~/.sapience/config.json` carries `"model": null` while `home.nix` sets
      `model = "claude-haiku-4-5"`. State which invocation path each value governs -- the systemd
      unit passes `--model` explicitly so it is unaffected, while the bare CLI falls through to
      `extract_local.py:188`'s own per-backend default (`claude-haiku-4-5-20251001` for anthropic).
      Note whether the two models differ in any way that would make a bare-CLI pass
      non-comparable with a unit pass. *(completed)*
- [x] Capture a fresh `sapience coverage` and `sapience pending` as the Pass-0 baseline block,
      verbatim, with timestamp. *(completed)*
- [x] Verify the five `Available on disk` sub-counters sum to the `Available on disk` total and
      record the arithmetic in the block. A mismatch is itself a finding -- record it rather than
      reconciling it silently. *(completed: 78+0+30+904+145 = 1157, matches exactly)*
- [x] Retro-record Pass 1 from `journalctl --user -u sapience-sync --since 2026-11-13`: the run
      starting `11:37:47` and finishing `12:06:52`. Mark the block explicitly as reconstructed from
      the journal, and state that no before/after coverage pair was captured around it, so the
      decision phase knows it yields a cost/duration datum but not a drain-rate datum. *(completed)*
- [x] Record in the ledger that `reports/02_baseline-and-extraction-backend-blocked.md`'s figures
      are superseded by the anthropic migration and must not be carried forward. *(completed)*

**Timing**: 45-60 minutes

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Every path this phase writes lies under `specs/**`, for which
`suite_selection_select` returns `__FULL_SWEEP__` (no suite covers it), so the covering check is
plan-format.md sub-case (a)'s diff read-through, confirming each recorded figure is a verbatim copy
of live command output.

**Scope Hypothesis**: This phase asserts the plan-time readings tabulated in Premise Re-Validation
above (78 would ingest now, 1153 on disk, 30 headless/agent, 900 subagent/harness-started, 145
folder-not-chosen, pending 1208, read 2026-11-13) and the `"model": null` discrepancy. The
implementer MUST re-run `sapience coverage`, `sapience pending`, and the `jq` read itself and
record its own fresh figures; the plan's numbers are a plan-time snapshot those readings supersede,
never the baseline.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` - new; the series ledger with its fixed per-pass block shape, the Pass-0 baseline block, and the journal-reconstructed Pass-1 block

**Verification**:
- The ledger exists and documents its own per-pass block shape before any block uses it.
- The Pass-0 block carries all five skip counters verbatim plus the summation check.
- The Pass-1 block is flagged as journal-reconstructed and states which datum it cannot supply.
- The backend wiring block records three independent confirmations, not one.
- Diff read-through confirms no figure in the ledger was copied from this plan or from `reports/02`.

---

### Phase 2: Extraction Pass 2 -- First Fully Observed Pass [COMPLETED]

**Goal**: Run one pass end to end with a before/after reading pair, producing the series' first
genuine drain-rate datum, and establish what cost signal is obtainable at all.

**Tasks**:

- [x] Confirm at least 24 hours have elapsed since the Pass-1 timestamp in the ledger. If not, stop
      and leave this phase `[NOT STARTED]`; the spacing is a measurement requirement, not a
      formality, and running early destroys the datum rather than delaying it. *(completed: Pass 1
      finished 2026-11-13T12:06:52Z; this pass started 2026-11-17T21:00:38Z, ~104.9h gap)*
- [x] Capture `sapience coverage` and `sapience pending` BEFORE the pass, verbatim, with timestamp.
      *(completed: Available on disk 1611, would ingest now 118, pending 1208)*
- [x] Run the pass with `systemctl --user start sapience-sync.service`, not the bare CLI -- the unit
      is the path that passes `--backend`/`--model` explicitly, and a detached run logs to the
      journal rather than depending on an agent's foreground wait. Record the start time.
      *(completed: started 2026-11-17T21:00:38Z)*
- [x] Wait with bounded polling per `context/patterns/external-process-wait.md` and
      `context/patterns/bounded-build-waiter.md`: poll `systemctl --user is-active
      sapience-sync.service` at a bounded interval, to a hard cap of 60 minutes. If the unit is
      still active at the cap, record the overrun in the ledger and stop waiting -- do NOT stop or
      kill the unit, and do not start a second pass. *(completed: unit settled to inactive at
      22min 29.8s, well under the 60-minute cap; polling corrected mid-run after the first attempt
      wrongly matched only ActiveState=="active", missing the "activating" state a Type=oneshot
      unit holds while running -- deviation noted below)*
- [x] Read `journalctl --user -u sapience-sync --since <recorded start>` and extract: wall clock
      from `systemctl --user status`; chunk count; objects staged and awaiting review; the redaction
      and set-aside lines; and EVERY `extract error:` line. Zero errors is the expected case; any
      non-zero count makes this pass's yield unusable as a drain-rate datum and must be stated as
      such in the block, exactly as the 402 run's was. *(completed: 34 extract-error lines, flagged
      as a partial-failure pass unusable for the clean drain-rate datum)*
- [x] Capture `sapience coverage` and `sapience pending` AFTER the pass, verbatim. *(completed:
      Available on disk 1617, would ingest now 118, pending 1747)*
- [x] Append the Pass-2 block to the ledger, including the computed deltas: `would ingest now`
      before minus after, `Available on disk` growth, each skip counter's change, `pending` growth,
      and objects staged per chunk. *(completed)*
- [x] Establish the cost signal once, for the rest of the series to reuse: check whether
      `sapience stats`, the journal, or `~/.sapience/` exposes any token or cost counter for a run.
      Record what is available and, if nothing is, record that plainly -- the decision phase depends
      on knowing whether a per-pass cost figure exists at all. *(completed: re-confirmed no per-pass
      cost signal exists, matching Phase 1's finding)*
- [x] Record any issue or win via `issue-record.sh` as it arises, not reconstructed at the end.
      *(completed: external-dependency-failure/costly recorded for the 34 extract errors)*

**Timing**: 20-30 minutes of attended work plus a bounded wait of up to 60 minutes, on a calendar
day at least one day after Pass 1

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` ledger, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every recorded figure is verbatim command or journal output.

**Scope Hypothesis**: The 60-minute wait cap is extrapolated from the single observed successful
pass (29min 4.283s on 2026-11-13); no second successful pass has been timed. The implementer MUST
treat an overrun past the cap as a datum to record, not as a failure to force, and MUST NOT shorten
the cap on the assumption that 29 minutes is typical.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` - append the Pass-2 block with its before/after pair, deltas, and the cost-signal availability finding

**Verification**:
- The Pass-2 block carries a before reading and an after reading, each timestamped, not one reading.
- The `extract error:` line count is stated explicitly, including when it is zero.
- The >=24h spacing is stated with both timestamps, not asserted.
- The cost-signal finding states what exists or that nothing does.

---

### Phase 3: Extraction Pass 3 and First Mid-Series Filter Check [COMPLETED]

**Goal**: Add a third reading and make the first mid-series check of the two-filter ratio and the
daily-cap headroom, early enough that a surprise can still change how later passes are run.

**Tasks**:

- [x] Confirm at least 24 hours since the Pass-2 timestamp; if not, stop and leave this phase
      `[NOT STARTED]`. *(completed: Pass 2 finished 2026-11-17T21:23:08Z; this pass started
      2026-11-18T21:23:48Z, a gap of ~24h00m40s)*
- [x] Run the pass and record it exactly as phase 2 prescribes: before pair, `systemctl --user
      start sapience-sync.service`, bounded 60-minute poll with no kill, journal read including
      every `extract error:` line, after pair, computed deltas, Pass-3 block appended to the ledger.
      *(completed: clean pass, 0 extract errors, 2010 objects staged, 47min 58.5s wall clock)*
- [x] Compute and record the two-filter ratio at each of the three readings so far: `skipped
      (headless/agent)` against `skipped (subagent / harness-started)`. State whether the
      non-overridable filter still dominates and whether the ratio is stable or moving.
      *(completed: computed across all 5 coverage readings present in the ledger -- Pass 0, Pass 2
      before/after, Pass 3 before/after -- ratio stable in a 30.13x-31.45x band; non-overridable
      filter dominates at every reading)*
- [x] Compute and record the daily-cap headroom: the day's cumulative `sapience yield` objects
      against the 2000-objects/day cap, and how many 50-chunk passes a single day would admit before
      the cap truncates one. If any pass in the series was truncated by the cap, flag its yield as a
      cap figure rather than a drain figure. *(completed: no truncation observed in any of the 3
      real passes; Pass 3 alone exceeded the 2000-object cap (2051) with no sign of being stopped
      mid-run, so a single admissible-pass-count cannot be stated -- recorded as a range bounded by
      the observed 550-2051 per-pass yield variability instead)*
- [x] Record any issue or win via `issue-record.sh` as it arises. *(completed: issue recorded for
      the daily-cap overshoot; win recorded for the stable filter ratio and the clean zero-error
      pass)*

**Timing**: 30-40 minutes of attended work plus a bounded wait of up to 60 minutes, at least one day
after Pass 2

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` ledger, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every recorded figure is verbatim command output and every computed ratio shows its two
inputs.

**Scope Hypothesis**: The mid-series check asserts three readings will exist by this phase (Pass-0
baseline, Pass-2, Pass-3), treating the journal-reconstructed Pass-1 block as contributing no
coverage pair. The implementer MUST count the coverage pairs actually present in the ledger and
compute the ratio over those, stating the denominator, rather than over an assumed three.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` - append the Pass-3 block plus the mid-series filter-ratio and daily-cap-headroom checks

**Verification**:
- The Pass-3 block matches the ledger's fixed block shape with no field omitted.
- The filter-ratio check shows both inputs at each reading and names its denominator.
- The daily-cap headroom is stated as a number of admissible passes per day, not as prose.

---

### Phase 4: Close the Series and Answer the Remaining Measurement Questions From the Ledger [NOT STARTED]

**Goal**: Answer the review-queue-growth, series-span, and filter-stability questions from the
readings already recorded plus fresh read-only sampling, run no further extraction pass, and name
explicitly every question three passes cannot answer.

**Tasks**:

- [ ] Run NO extraction pass in this phase, and record that decision and its reason in the ledger:
      the evidence base is closed at the three real passes already recorded, and a pass run
      back-to-back with Pass 3 would be exactly the near-spaced datum the method calls destroyed
      rather than delayed, so adding one would make the series worse rather than longer.
- [ ] Take fresh read-only readings now and append them to the ledger as an accrual sample,
      explicitly labelled as such rather than as a pass block: `sapience coverage` verbatim,
      `sapience pending`, and `wc -l ~/.sapience/pending_kos.jsonl`, each with an ISO 8601 UTC
      timestamp. These readings cost nothing and need no extraction run.
- [ ] Verify the fresh reading's five `Available on disk` sub-counters sum to its stated total and
      record the arithmetic, as every earlier reading did. A mismatch is a finding to record, not
      to reconcile silently.
- [ ] Compute and record the review-queue growth across the whole recorded series from the
      `sapience pending` readings already in the ledger plus the fresh reading above: the value at
      every reading, the objects added per pass, and the resulting per-pass and per-day growth
      rate, each with its inputs. State plainly whether the queue grows faster than any plausible
      review session could drain it, since an object staged and never reviewed is captured but not
      in the vault.
- [ ] Record the queue's growth against the 2000-objects/day cap: if a day's passes can stage more
      objects than a day's review can absorb, that is a constraint on cadence independent of cost,
      and the decision phase must weigh it. State the cap's observed character alongside it -- the
      ledger records a pass finishing at 2051 objects with no journal line indicating an early stop
      or a dropped chunk.
- [ ] Compute and record the per-day transcript accrual rate from the `Available on disk` series
      already in the ledger plus the fresh reading, naming each interval's two endpoints and its
      elapsed time. State how many intervals the rate rests on, and do not present a single
      averaged rate as if it rested on more.
- [ ] Re-run the two-filter ratio over every coverage reading in the ledger including the fresh
      reading above, naming the denominator, and state whether the band the first mid-series check
      recorded still holds with the new reading added or has moved.
- [ ] Run the series-completeness check over what actually exists, and record each criterion the
      series falls short of as a shortfall rather than as a satisfied criterion: the number of real
      passes recorded; every consecutive gap between passes; the total span from the first to the
      last pass; and how many passes carry a usable before/after coverage pair as opposed to a
      journal reconstruction.
- [ ] List every pass that recorded a non-zero `extract error:` count, preserve its existing flag
      in the ledger, and state which passes must be excluded from the drain-rate computation.
- [ ] Name, as an explicit list of stated limitations for the decision to carry, every question in
      scope for this phase that the recorded readings cannot answer -- asserting no figure in place
      of any of them. At minimum, address whether per-pass yield variability narrows over a longer
      series, whether a steady-state drain rate can be established at all from two fully observed
      passes, and how much confidence the per-day accrual rate carries on the number of intervals
      actually available.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 45-60 minutes, in one sitting; no calendar wait, and no extraction pass

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` ledger, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is plan-format.md
sub-case (a)'s diff read-through, confirming every figure is verbatim command output from the
fresh reading or a value already recorded in the ledger, and that every computed rate shows its
numerator and denominator.

**Scope Hypothesis**: This phase carries figures from
`records/01_coverage-pass-ledger.md`: three real passes (Pass 1 1208 objects, Pass 2 539 staged
with 34 `extract error:` lines, Pass 3 2010 objects); five coverage readings carrying both skip
counters; a `sapience pending` series of 1208 -> 1747 -> 3757; `Available on disk` 1611 -> 1786;
and a series span of 2026-11-13 to 2026-11-18. The implementer MUST re-read the ledger and take
the fresh live readings prescribed above before computing anything, and MUST compute from what is
actually there -- if a review session has drained the queue outside this task, or a pass has run
outside this plan, the growth series must be annotated as discontinuous rather than computed
across the gap.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` - append the accrual-sample reading, the review-queue growth computation, the accrual-rate computation, the re-run filter-ratio check, the series-completeness check with its named shortfalls, and the list of unanswerable questions

**Verification**:
- The ledger records that no extraction pass was run in this phase, and why a near-spaced pass was
  rejected rather than merely skipped.
- The fresh reading is present, timestamped, labelled as an accrual sample rather than a pass
  block, and carries its sub-counter summation check.
- The review-queue growth rate is stated per pass and per day, each with its inputs, and any
  discontinuity in the pending series is annotated rather than averaged over.
- The accrual-rate computation names each interval's endpoints and states how many intervals it
  rests on.
- The filter-ratio check names its denominator and states whether the recorded band still holds.
- The completeness check states the real-pass count, every consecutive gap, the total span, and
  the count of usable before/after pairs, each citing ledger timestamps, and names every criterion
  the series falls short of.
- Every question the recorded readings cannot answer is named as a limitation, with no figure
  asserted in its place.

---

### Phase 5: Read-Only Vault-Content Audit [NOT STARTED]

**Goal**: Discharge the method's third step -- confirm the captured material is substantive work
rather than thread mechanics -- without running the interactive, share-capable review session.

**Tasks**:

- [ ] Do NOT run `sapience review`. Record the reason in the audit: `~/.sapience/extract_local.py`'s
      `--review` path is interactive and share-capable (`review_queue()` prompts at line 1175;
      `review()` at line 1920 prompts `Press Enter to share ALL, numbers like 2,5 to DROP those`),
      so an unattended run against a queue of this size could push the entire queue to the hosted
      vault or drop it. The read-only substitute is `~/.sapience/pending_kos.jsonl`, which holds the
      same staged objects.
- [ ] Re-establish the queue's shape before sampling: `wc -l ~/.sapience/pending_kos.jsonl`, and the
      key set of one record. Record both -- three passes have grown the file since plan time and
      may have changed its fields.
- [ ] Profile the queue read-only: total record count; distribution by `ko_type`; by `project`; by
      `confidence` band; and the count with `open_thread: true`.
- [ ] Hand-read a sample of at least 30 records spread deliberately across projects and `ko_type`
      values, and classify each as (a) substantive work, (b) thread mechanics -- run, dispatch, or
      orchestration bookkeeping, or (c) duplicate of another record already in the sample. Record
      the three counts and quote three to five verbatim examples of each class.
- [ ] Cross-check the client's own mechanics filter against the hand-read: collect the `Set aside N
      transient rows (pid N, dispatch N): run/thread state, not knowledge` lines from every pass in
      the series, and state what the hand-read found that the filter did not catch.
- [ ] State the substantive-versus-mechanics result as a sample ratio with its denominator
      explicitly (for example "22 of 30 sampled"), never as a whole-queue figure, and never as a
      percentage without its denominator.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 1.5-2 hours

**Depends on**: 4

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` audit record, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every quoted record is copied verbatim from `pending_kos.jsonl` and every ratio states
its denominator.

**Scope Hypothesis**: The queue is asserted here to hold 3757 records -- the figure recorded in
`records/01_coverage-pass-ledger.md`'s Pass-3 after-reading, not an independent measurement --
carrying the field set `subject`, `predicate`, `object_value`, `ko_type`, `confidence`,
`reasoning`, `open_thread`, `sid`, `tool`, `at`, `project`, read at the prior plan round's
authoring time. The implementer MUST re-count the file and re-read one record's keys before
sampling, and MUST state the live count in the audit rather than the ledger's or the plan's.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/02_vault-content-audit.md` - new; the read-only queue profile, the classified sample with verbatim examples, and the mechanics-filter cross-check

**Verification**:
- The audit states, in its own words, that `sapience review` was not run and why.
- The sample size is at least 30 and its spread across projects and `ko_type` values is shown.
- Every classification count carries its denominator; no whole-queue claim is made from the sample.
- Each quoted example is traceable to a record in `pending_kos.jsonl`.

---

### Phase 6: Series Analysis and the Extraction-Scope Decision [NOT STARTED]

**Goal**: Produce this task's actual deliverable -- a written decision on each of the four candidate
outcomes, with every figure traceable to a dated ledger block and the reduced evidence base stated
as a limitation of the decision.

**Tasks**:

- [ ] Re-read the task description from `specs/state.json` before writing, to confirm the candidate
      outcome set is still the four this plan enumerates.
- [ ] Tabulate from the ledger, across every recorded pass: wall clock, chunks, objects staged,
      objects per chunk, `would ingest now` before and after, each of the four skip counters,
      `pending` before and after, and the day's yield against the 2000-objects/day cap. Exclude
      from the drain-rate columns any pass phase 4 flagged for non-zero `extract error:` lines.
- [ ] Carry the following findings the recorded series has already established, rather than
      re-deriving them, citing the ledger block each rests on:
      - `would ingest now` held exactly flat across both fully observed passes (118 -> 118, then
        134 -> 134), so one 50-chunk pass does not visibly drain the queue of ingestible
        transcripts.
      - Per-pass yield varies 3.7x (539 / 1208 / 2010 objects) at an identical 50-chunk count,
        driven by the content of the chunks selected that day rather than by accrual time.
      - The non-overridable subagent/harness-started filter dominates the overridable
        headless/agent filter by a stable 30.13x-31.45x across all five coverage readings, and
        `SAPIENCE_INCLUDE_HEADLESS=1` does not override it.
      - `MAX_CHUNKS=50` is not a throughput bottleneck: a pass runs 29-48 minutes.
      - The 2000-objects/day cap is descriptive only and does not truncate a run -- Pass 3
        finished at 2051 objects with no journal line indicating an early stop or a dropped chunk.
      - The unreviewed queue tripled from 1208 to 3757 in two passes; this is the constraint that
        actually binds, not the chunk cap and not the drain rate.
- [ ] Answer the two-filter question from the series, not one reading: does `skipped (subagent /
      harness-started)` continue to dominate `skipped (headless/agent)`, and at what ratio at each
      reading?
- [ ] Answer the drain question from measurement: does a 50-chunk pass reduce `would ingest now`
      faster than new transcripts accrue? State the per-day accrual rate phase 4 computed from the
      `Available on disk` series, alongside the per-pass reduction, and state how many intervals
      that accrual rate rests on.
- [ ] Decide each candidate outcome explicitly, naming for each the measured figure that supports or
      refutes it:
      - **(a) Add `programs.sapience.includeAgentSessions`** wiring `SAPIENCE_INCLUDE_HEADLESS`.
        Supported only if the headless/agent count is large AND the vault-content audit shows that
        material would be substantive. State the measured asymmetry against the non-overridable
        filter, which the option cannot touch.
      - **(b) Adjust the per-run chunk cap, or prescribe a periodic wider `sapience backfill` pass.**
        Weigh against the measured drain rate AND against the daily object cap and the per-pass wall
        clock, both of which scale with the cap.
      - **(c) Turn on `programs.sapience.backgroundSync` with `syncInterval`.** Weigh against the
        measured per-pass cost and the measured review-queue growth, not only against the risk of
        forgetting to run a pass.
      - **(d) Leave all three as they are.** If this is the decision, state it as the decision,
        grounded in the same figures -- not as an absence of one.
- [ ] State the cost dimension honestly. Extraction is now billed per call to the user's Anthropic
      key (`backend = "anthropic"`, `model = "claude-haiku-4-5"`). Use whatever cost signal the
      ledger established; if no per-pass figure is obtainable, say so plainly and bound the decision
      accordingly -- do NOT recommend a cap increase or a timer on an unmeasured cost. Defer
      cost-reduction work to tasks 139 (`reduce_sapience_classifier_cost`) and 140
      (`diagnose_slow_local_ollama_inference`) by name rather than duplicating it here.
- [ ] Record the reduced evidence base as a stated limitation of the decision, in its own right and
      not folded into a general caveat: three real extraction passes rather than the five the
      method called for; a span of five calendar days (2026-11-13 to 2026-11-18) rather than a full
      week; and one of those three passes (Pass 2, 34 `extract error:` lines) unusable as a clean
      drain-rate datum, leaving two fully observed clean intervals at most. State what each
      shortfall costs the decision, and carry every question phase 4 named as unanswerable.
- [ ] Write the decision record with: the decision on each of the four outcomes; the figures each
      rests on, each citing a dated ledger block; the outcomes rejected and why; and a limitations
      section naming the reduced evidence base above, the series span, the audit sample size and
      denominator, the excluded error-bearing pass, and the absent per-pass cost figure.
- [ ] State in the record whether the decision requires any configuration change at all, so the
      final phase knows whether it has work to do.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` decision record, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every figure in the record traces to a dated ledger block and no figure originates in
this plan or in `reports/02`.

**Scope Hypothesis**: This phase asserts the candidate outcome set is exactly the four the task
description enumerates, and carries from `records/01_coverage-pass-ledger.md` the six findings
enumerated in its task list above (the flat `would ingest now` pairs 118/118 and 134/134; the
539/1208/2010 yield spread; the 30.13x-31.45x filter band; the 29-48 minute pass durations; the
2051-object run past the 2000-object cap; and the 1208 -> 3757 queue growth). The implementer MUST
re-read the description and the ledger first and, if either differs, decide over what is actually
there -- recording the divergence rather than planning around it.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/03_extraction-scope-decision.md` - new; the decision on each candidate outcome, its grounding figures, the rejected alternatives, and the stated limitations including the reduced evidence base

**Verification**:
- The record names a decision for each of the four candidate outcomes, including the ones rejected.
- Every figure cites a dated ledger block; no figure is carried from this plan or `reports/02`.
- The limitations section names the reduced evidence base explicitly -- three passes, five calendar
  days, one pass excluded -- alongside the audit sample denominator and the cost figure's absence.
- Every question phase 4 recorded as unanswerable appears in the limitations rather than being
  answered with an asserted figure.
- The record states explicitly whether the final phase has any configuration change to make.

---

### Phase 7: Enact the Decision and Reconcile the Documentation [NOT STARTED]

**Goal**: Apply exactly what the decision selected, make `docs/sapience.md` state the contract that
is then live, and close the task against the full gate set.

**Tasks**:

- [ ] Read phase 6's decision record. Enact exactly what it selected and nothing more; this phase
      has no independent judgment about the right configuration.
- [ ] If the decision adjusts the per-run chunk cap: change it where the module actually reads it --
      `modules/home/services/sapience.nix`'s `budget="${MAX_CHUNKS:-50}"` and the sync unit's
      environment -- and never by editing `~/.sapience/*.py`, which is vendor-owned and regenerated
      by activation.
- [ ] If the decision adds `programs.sapience.includeAgentSessions`: declare the option in
      `modules/home/services/sapience.nix` alongside the existing `backgroundSync`/`syncInterval`
      options, wire `SAPIENCE_INCLUDE_HEADLESS` into the sync unit's environment, and set it in
      `home.nix`. State in the option's own comment that it does not override the
      subagent/harness-started filter, quoting the client's own message to that effect.
- [ ] If the decision turns on scheduled extraction: set `programs.sapience.backgroundSync` and
      `syncInterval` in `home.nix`, and state the measured per-pass cost and duration in the comment
      beside them so the trade is legible where the setting lives.
- [ ] If the decision is to leave all three as they are: make no configuration change, and close
      this phase as `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` block naming the
      decision record as the reason. This is a valid, expected outcome of a measurement task, not a
      failure to deliver.
- [ ] Update `docs/sapience.md` so its "Nothing extracts on a schedule" section states the contract
      that is actually live after this phase. Write it as the current design only -- no "previously",
      "no longer", or draft-history framing, per `.claude/rules/no-record-versioning-in-deliverables.md`.
- [ ] If any Nix file changed, evaluate before committing: `nix flake check` (or the repository's own
      evaluation entry point) and a Home Manager build. An evaluation failure blocks the phase.
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 1-2 hours; closer to 30 minutes if the decision is to leave the arrangement as it stands

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: The file set is asserted to be at most `home.nix`,
`modules/home/services/sapience.nix`, and `docs/sapience.md`, with `backgroundSync` declared at
`modules/home/services/sapience.nix:710`, `syncInterval` at `:725`, and the chunk budget at `:397`
as of the prior plan round's authoring time. The implementer MUST confirm against the decision
record which of the three files the decision actually requires, and MUST re-grep for
`backgroundSync` and `MAX_CHUNKS` in that module rather than trusting those line numbers. Tasks
139 and 140 both declare `home.nix` and `docs/sapience.md` in their own `file_scope`, so this
phase must not run concurrently with either.

**Files to modify**:
- `home.nix` - conditional: the `programs.sapience` settings the decision selects, with the measured trade stated in the comment beside them
- `modules/home/services/sapience.nix` - conditional: the new option or the chunk-budget wiring the decision selects
- `docs/sapience.md` - the extraction-cadence contract that is live after this phase

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` green.
- If any Nix file changed, the flake evaluation and Home Manager build are green.
- The enacted configuration and the decision record agree, field by field.
- `docs/sapience.md`'s cadence statement matches the live `home.nix` values.
- If no configuration change was selected, the phase carries a `#### Reasoned Exclusions` block
  naming the decision record.

## Testing & Validation

- [ ] `bash .claude/scripts/validate-artifact.sh specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/03_single-sitting-decision-from-ledger.md plan` passes.
- [ ] The ledger's five `Available on disk` sub-counters sum to the stated total at every reading,
      including the accrual sample phase 4 appends.
- [ ] No extraction pass was run after Pass 3; the ledger records that and why.
- [ ] Every pass block carries a before/after reading pair, or is explicitly flagged as a journal
      reconstruction that cannot supply one.
- [ ] Every pass block states its `extract error:` line count, including zero.
- [ ] The series-completeness check names each criterion the series falls short of -- real-pass
      count, consecutive gaps, total span, usable before/after pairs -- rather than asserting any
      of them as satisfied.
- [ ] The vault-content audit states a sample size of at least 30 with its denominator, and confirms
      `sapience review` was not run.
- [ ] Every figure in the decision record cites a dated ledger block.
- [ ] The decision record's limitations section names the reduced evidence base -- three passes,
      five calendar days, one pass excluded as error-bearing.
- [ ] `bash .claude/scripts/verify-deploy.sh` green at the final phase.
- [ ] If any Nix file changed at the final phase, flake evaluation and a Home Manager build are
      green.

## Artifacts & Outputs

- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/03_single-sitting-decision-from-ledger.md` -- this plan.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` -- the measurement ledger: baseline, three real pass blocks, the accrual sample, and the series checks.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/02_vault-content-audit.md` -- the read-only queue profile and classified sample.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/03_extraction-scope-decision.md` -- the decision on each candidate outcome, its grounding figures, and its limitations.
- Conditional, only if the decision selects a change: edits to `home.nix`,
  `modules/home/services/sapience.nix`, and `docs/sapience.md`.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/summaries/03_*-summary.md` -- the completion summary.

## Rollback/Contingency

Phases 1 through 6 write only new files under `specs/**` and change no configuration, so there is
nothing to roll back from them: an unsatisfactory ledger entry or audit is corrected by appending a
correction block, not by reverting.

Phase 7 is the only phase that changes machine configuration. Its edits are confined to `home.nix`,
`modules/home/services/sapience.nix`, and `docs/sapience.md`, all tracked, so reverting is an
ordinary revert of that phase's commit followed by a Home Manager switch back to the prior
generation. If an intentional rollback of uncommitted work in that phase is needed, take the
snapshot first per `context/contracts/recovery.md`'s rollback rung -- including its out-of-scope
override flag for the deliberate whole-tree case -- and then run the destructive command; never
emit a bare reverting snapshot as a routine precaution.

If the ledger turns out to hold less than this plan assumes -- a reading missing, a figure
unrecoverable, a review session having drained the queue outside this task -- the contingency is
not to run a replacement extraction pass. Record what is missing, annotate the series as
discontinuous at that point, and carry the gap into the decision's limitations. If the ledger turns
out to support no decision at all on some candidate outcome, that outcome is recorded as undecided
with the specific missing measurement named -- not decided on an asserted figure, and not deferred
to a further pass this plan has ruled out.
