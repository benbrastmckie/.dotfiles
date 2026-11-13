# Implementation Plan: Sapience coverage measurement series and extraction-scope decision

- **Task**: 136 - Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Status**: [IMPLEMENTING]
- **Effort**: 9.5 hours of attended work, spread across at least 7 calendar days
- **Dependencies**: 138 (owner-action reconciliation of `~/.sapience/config.json`) -- confirmed applied live, see Premise Re-Validation below
- **Research Inputs**:
  - `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/02_baseline-and-extraction-backend-blocked.md` (figures superseded, see below)
  - `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/reports/01_coverage-baseline-blocked.md`
- **Artifacts**: plans/02_coverage-measurement-series-and-decision.md (this file)
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
cap, put extraction on a schedule, or leave the arrangement as it stands. The measurement cannot
be compressed into one sitting: it requires at least five hand-run extraction passes spaced at
least a day apart and spanning at least a week, so each pass has fresh transcripts to find and
the drain rate is observed rather than inferred. The plan is therefore structured as one phase
per pass, each appending a dated block to a single measurement ledger, so that a dispatch on any
given day advances exactly one phase and the series survives across `/orchestrate` invocations.
Done means a written decision on each of the four candidate outcomes, with every figure in it
traceable to a dated ledger block.

### Premise Re-Validation

Required by this dispatch's Premise Re-Validation section. Each result is stated explicitly, and
two of the three are **not** confirmations.

**The task 138 precondition and its recorded obligation: discharged, re-verified live.**
`.decisions.json`'s cycle-4 answer claims the owner instruction was applied. Live read at this
dispatch confirms it: `jq -c '.folders' ~/.sapience/config.json` returns exactly
`["-home-benjamin--config-nvim","-home-benjamin--dotfiles","-home-benjamin-Projects-abood","-home-benjamin-Projects-Sapience-sapience-app"]`,
and `sapience coverage` independently reports `Folders selected (4): nvim, dotfiles, app, abood`.
The obligation that recorded route named is discharged; the measurement window is open and no
re-ask is warranted.

**Description line 52 (the non-overridable subagent/harness-started filter): confirmed
unchanged.** The live journal line from the 2026-11-13 12:06:52 run reads verbatim
`sapience: skipped 6 harness-started transcripts (thread mechanics, not knowledge;
SAPIENCE_INCLUDE_HEADLESS=1 does not override this)`. The description's characterisation of this
filter is accurate as written.

**Description line 71 (whether 50 chunks per pass can keep up with the backlog): the premise has
materially shifted and this plan reframes it.** `MAX_CHUNKS` is still 50 (confirmed live in the
`Per-run extraction cap: 50 chunks (MAX_CHUNKS)` coverage line and at
`modules/home/services/sapience.nix:397`, `budget="${MAX_CHUNKS:-50}"`). But the backlog-drain
framing is no longer the binding constraint. One real 50-chunk pass now takes 29 minutes and
stages roughly 1200 knowledge objects against a 2000-objects/day cap, so the cap on a day's
extraction and the depth of the unreviewed queue bind before the chunk cap does. Phase 7 answers
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

| Figure | reports/02 (ollama, 402-failing) | Live at this dispatch (anthropic) |
|--------|----------------------------------|-----------------------------------|
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
a phase takes its own. No phase below may cite this table as its measurement.

### Research Integration

Three findings from `reports/02` survive the backend migration and are carried into the plan:

- **The two-filter asymmetry is real and large.** 30 transcripts skipped as headless/agent against
  900 skipped as subagent/harness-started -- the non-overridable filter removes roughly 30x more
  than the overridable one. The report correctly declines to call this settled from one reading;
  phases 2-5 collect it per pass and phase 7 decides from the series.
- **The counters partition the backlog with no remainder.** 78 + 0 + 30 + 900 + 145 = 1153,
  matching "Available on disk" exactly. Phase 1 re-runs that arithmetic as a cheap integrity check
  on every reading.
- **Readings must never be carried forward.** The report measured "Available on disk" growing from
  1133 to 1136 in twelve minutes purely from new transcripts. Each phase below captures its own
  fresh readings; the Scope Hypothesis on every phase makes that obligation explicit.

The report's two recommendations that the migration has overtaken are recorded as such rather than
silently dropped: resolving Ollama billing (recommendation 1) is moot at the anthropic backend, and
the CLI model-mismatch gap (recommendation 2) is materially reduced because `extract_local.py:184-188`
now falls back to `config.json`'s own `backend` when `--backend` is absent, so the bare CLI and the
systemd unit both land on anthropic. Phase 1 records the one residue of that gap that is still live.

### Prior Plan Reference

No prior plan. `specs/136_.../plans/` is empty; this is the task's first plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Produce a baseline reading of `sapience coverage` and `sapience pending` against the live
  anthropic backend, with the four skip counters recorded verbatim.
- Run and record at least five extraction passes, spaced at least a day apart and spanning at
  least a week, each with its own before/after reading pair and its own error-line count.
- Establish, from the series rather than from one reading, which of the two filters dominates and
  at what ratio.
- Establish whether a 50-chunk pass drains "would ingest now" faster than new transcripts accrue,
  and what fraction of the 2000-objects/day cap one pass consumes.
- Audit what the vault actually holds, read-only, confirming the captured material is substantive
  work rather than thread mechanics.
- Decide each of the four candidate outcomes explicitly, with the measured figure that supports
  or refutes it, and enact whatever the decision selects.

**Non-Goals**:

- Reducing the per-call cost of extraction, or making local inference viable. Those are owned by
  tasks 139 (`reduce_sapience_classifier_cost`) and 140 (`diagnose_slow_local_ollama_inference`);
  this plan measures cost only well enough to keep the decision honest and defers the work there.
- Approving, sharing, or dropping any staged knowledge object. The review gate is the user's, and
  phase 6 is deliberately read-only (see its first task for why).
- Re-litigating task 138's capture set. The four-repository folder selection is this task's given
  denominator, not its subject.
- Editing anything under `~/.sapience/` (vendor-owned, regenerated by activation) or under
  `.claude/**` (a disposable deploy artifact).
- Changing the extraction backend or model. The migration to anthropic is a settled given here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A later dispatch carries this plan's plan-time figures forward instead of re-measuring | H | H | Every phase carries a Scope Hypothesis naming its asserted figures as plan-time readings the implementer must re-take; the Premise Re-Validation table above is marked non-citable |
| The five-pass series outlives several `/orchestrate` invocations and a future dispatch loses the thread | H | H | One phase per pass, each appending to one ledger file whose per-pass block shape is fixed in phase 1; the ledger, not this plan, is the series' state |
| `sapience review` run unattended shares or drops the whole 1200+ object queue | H | M | Phase 6 forbids it by name and substitutes a read-only read of `~/.sapience/pending_kos.jsonl`; the substitution and its reason are recorded in the phase itself |
| A pass fails at the provider (as the 402 series did) and its zero yield is misread as low-information content rather than total failure | H | M | Every pass phase records each `extract error:` line from the journal, and treats any non-zero error count as making that pass's yield unusable as a drain-rate datum |
| Passes spend real money on the user's Anthropic key, and the plan prescribes four more | M | H | The per-pass cost signal is recorded from phase 2 onward; phase 7 may not recommend a cap increase or a timer on an unmeasured cost, and must say so if no figure is obtainable |
| A pass runs long and an agent kills it mid-flight, destroying the datum | M | M | Pass phases use bounded polling with a 60-minute cap and explicitly record an overrun rather than killing the unit |
| Phase 8's file set overlaps tasks 139 and 140, which both declare `home.nix` and `docs/sapience.md` | M | M | Noted here for the orchestrator: serialize phase 8 against 139/140 with a dependency edge rather than running them concurrently |
| The daily 2000-object cap silently truncates a pass, making its yield look like a drain-rate figure when it is a cap figure | M | M | Every pass block records the day's cumulative `sapience yield` line against the cap, so a truncated pass is visible as such |
| The series span falls short of a week because passes land on consecutive days only | L | M | Phase 5 checks span explicitly and either adds a sixth pass or records the shortfall as a stated limitation of the decision |

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
| 8 | 8 | 7 |

Phases within the same wave can execute in parallel. This plan has no parallelism by design: each
pass must observe the state the previous pass left, and the calendar spacing between passes is
itself a measurement requirement.

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
      the journal, and state that no before/after coverage pair was captured around it, so phase 7
      knows it yields a cost/duration datum but not a drain-rate datum. *(completed)*
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

### Phase 2: Extraction Pass 2 -- First Fully Observed Pass [NOT STARTED]

**Goal**: Run one pass end to end with a before/after reading pair, producing the series' first
genuine drain-rate datum, and establish what cost signal is obtainable at all.

**Tasks**:

- [ ] Confirm at least 24 hours have elapsed since the Pass-1 timestamp in the ledger. If not, stop
      and leave this phase `[NOT STARTED]`; the spacing is a measurement requirement, not a
      formality, and running early destroys the datum rather than delaying it.
- [ ] Capture `sapience coverage` and `sapience pending` BEFORE the pass, verbatim, with timestamp.
- [ ] Run the pass with `systemctl --user start sapience-sync.service`, not the bare CLI -- the unit
      is the path that passes `--backend`/`--model` explicitly, and a detached run logs to the
      journal rather than depending on an agent's foreground wait. Record the start time.
- [ ] Wait with bounded polling per `context/patterns/external-process-wait.md` and
      `context/patterns/bounded-build-waiter.md`: poll `systemctl --user is-active
      sapience-sync.service` at a bounded interval, to a hard cap of 60 minutes. If the unit is
      still active at the cap, record the overrun in the ledger and stop waiting -- do NOT stop or
      kill the unit, and do not start a second pass.
- [ ] Read `journalctl --user -u sapience-sync --since <recorded start>` and extract: wall clock
      from `systemctl --user status`; chunk count; objects staged and awaiting review; the redaction
      and set-aside lines; and EVERY `extract error:` line. Zero errors is the expected case; any
      non-zero count makes this pass's yield unusable as a drain-rate datum and must be stated as
      such in the block, exactly as the 402 run's was.
- [ ] Capture `sapience coverage` and `sapience pending` AFTER the pass, verbatim.
- [ ] Append the Pass-2 block to the ledger, including the computed deltas: `would ingest now`
      before minus after, `Available on disk` growth, each skip counter's change, `pending` growth,
      and objects staged per chunk.
- [ ] Establish the cost signal once, for the rest of the series to reuse: check whether
      `sapience stats`, the journal, or `~/.sapience/` exposes any token or cost counter for a run.
      Record what is available and, if nothing is, record that plainly -- phase 7 depends on knowing
      whether a per-pass cost figure exists at all.
- [ ] Record any issue or win via `issue-record.sh` as it arises, not reconstructed at the end.

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
- The ≥24h spacing is stated with both timestamps, not asserted.
- The cost-signal finding states what exists or that nothing does.

---

### Phase 3: Extraction Pass 3 and First Mid-Series Filter Check [NOT STARTED]

**Goal**: Add a third reading and make the first mid-series check of the two-filter ratio and the
daily-cap headroom, early enough that a surprise can still change how later passes are run.

**Tasks**:

- [ ] Confirm at least 24 hours since the Pass-2 timestamp; if not, stop and leave this phase
      `[NOT STARTED]`.
- [ ] Run the pass and record it exactly as phase 2 prescribes: before pair, `systemctl --user
      start sapience-sync.service`, bounded 60-minute poll with no kill, journal read including
      every `extract error:` line, after pair, computed deltas, Pass-3 block appended to the ledger.
- [ ] Compute and record the two-filter ratio at each of the three readings so far: `skipped
      (headless/agent)` against `skipped (subagent / harness-started)`. State whether the
      non-overridable filter still dominates and whether the ratio is stable or moving.
- [ ] Compute and record the daily-cap headroom: the day's cumulative `sapience yield` objects
      against the 2000-objects/day cap, and how many 50-chunk passes a single day would admit before
      the cap truncates one. If any pass in the series was truncated by the cap, flag its yield as a
      cap figure rather than a drain figure.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

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

### Phase 4: Extraction Pass 4 and Review-Queue Growth Check [NOT STARTED]

**Goal**: Add a fourth reading and measure the constraint the backend migration introduced -- the
unreviewed queue's growth rate, which no earlier artifact measured because the queue was empty.

**Tasks**:

- [ ] Confirm at least 24 hours since the Pass-3 timestamp; if not, stop and leave this phase
      `[NOT STARTED]`.
- [ ] Run the pass and record it exactly as phase 2 prescribes: before pair, unit start, bounded
      60-minute poll with no kill, journal read including every `extract error:` line, after pair,
      computed deltas, Pass-4 block appended to the ledger.
- [ ] Compute and record the review-queue growth across the series: `sapience pending` at every
      reading, the objects added per pass, and the resulting per-pass and per-day growth rate. State
      plainly whether the queue grows faster than any plausible review session could drain it, since
      an object staged and never reviewed is captured but not in the vault.
- [ ] Record the queue's growth against the 2000-objects/day cap: if a day's passes can stage more
      objects than a day's review can absorb, that is a constraint on cadence independent of cost,
      and phase 7 must weigh it.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 30-40 minutes of attended work plus a bounded wait of up to 60 minutes, at least one day
after Pass 3

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` ledger, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every pending figure is verbatim `sapience pending` output and every rate shows its
numerator and denominator.

**Scope Hypothesis**: This phase asserts the queue was 1208 objects deep at plan time and that no
review session will have drained it in the interim. The implementer MUST re-read `sapience pending`
and `wc -l ~/.sapience/pending_kos.jsonl` at this phase and compute growth from the ledger's own
recorded series; if the queue has shrunk, a review session happened outside this task and the
growth figure must be annotated as discontinuous rather than computed across the gap.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` - append the Pass-4 block plus the review-queue growth-rate check

**Verification**:
- The Pass-4 block matches the ledger's fixed block shape with no field omitted.
- The growth rate is stated per pass and per day, each with its inputs.
- Any discontinuity in the pending series is annotated rather than averaged over.

---

### Phase 5: Extraction Pass 5 and Series-Completeness Check [NOT STARTED]

**Goal**: Complete the required five-pass series and establish, before any analysis, whether the
series actually satisfies the method's spacing and span requirements.

**Tasks**:

- [ ] Confirm at least 24 hours since the Pass-4 timestamp; if not, stop and leave this phase
      `[NOT STARTED]`.
- [ ] Run the pass and record it exactly as phase 2 prescribes: before pair, unit start, bounded
      60-minute poll with no kill, journal read including every `extract error:` line, after pair,
      computed deltas, Pass-5 block appended to the ledger.
- [ ] Run the series-completeness check and record its result in the ledger: at least five passes
      recorded; every consecutive gap at least one day; total span from the first to the last pass
      at least seven days; and how many passes carry a usable before/after coverage pair as opposed
      to a journal reconstruction.
- [ ] If the span is under seven days, do NOT proceed to phase 6 on the strength of five passes
      alone. Either add a sixth pass on a later day (recording it as an additional block in the same
      shape) or record the shortfall explicitly as a stated limitation that phase 7's decision must
      carry.
- [ ] If any pass in the series recorded a non-zero `extract error:` count, list those passes here
      and state which of them must be excluded from the drain-rate computation.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 40-50 minutes of attended work plus a bounded wait of up to 60 minutes, at least one day
after Pass 4

**Depends on**: 4

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` ledger, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming the completeness check's four assertions each cite the ledger timestamps they rest on.

**Scope Hypothesis**: This phase assumes five passes will be the full series and that the span will
reach seven days. The implementer MUST compute the actual span from the ledger's own timestamps and,
if it falls short, follow the shortfall branch above rather than declaring the series complete; the
pass count is a floor from the task's method, not a target to stop at.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` - append the Pass-5 block (and any additional pass the span check requires) plus the series-completeness check

**Verification**:
- The ledger holds at least five pass blocks, each in the fixed shape.
- The completeness check states the pass count, every consecutive gap, the total span, and the count
  of usable before/after pairs -- each citing timestamps.
- Any span shortfall or error-bearing pass is named explicitly, with its consequence for the
  analysis stated.

---

### Phase 6: Read-Only Vault-Content Audit [NOT STARTED]

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
      key set of one record. Record both -- four passes will have grown the file since plan time and
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

**Depends on**: 5

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` audit record, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every quoted record is copied verbatim from `pending_kos.jsonl` and every ratio states
its denominator.

**Scope Hypothesis**: The queue is asserted here to hold 1208 records carrying the field set
`subject`, `predicate`, `object_value`, `ko_type`, `confidence`, `reasoning`, `open_thread`, `sid`,
`tool`, `at`, `project`, read at plan time. The implementer MUST re-count the file and re-read one
record's keys before sampling, and MUST state the live count in the audit rather than the plan's.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/02_vault-content-audit.md` - new; the read-only queue profile, the classified sample with verbatim examples, and the mechanics-filter cross-check

**Verification**:
- The audit states, in its own words, that `sapience review` was not run and why.
- The sample size is at least 30 and its spread across projects and `ko_type` values is shown.
- Every classification count carries its denominator; no whole-queue claim is made from the sample.
- Each quoted example is traceable to a record in `pending_kos.jsonl`.

---

### Phase 7: Series Analysis and the Extraction-Scope Decision [NOT STARTED]

**Goal**: Produce this task's actual deliverable -- a written decision on each of the four candidate
outcomes, with every figure traceable to a dated ledger block.

**Tasks**:

- [ ] Re-read the task description from `specs/state.json` before writing, to confirm the candidate
      outcome set is still the four this plan enumerates.
- [ ] Tabulate from the ledger, across every recorded pass: wall clock, chunks, objects staged,
      objects per chunk, `would ingest now` before and after, each of the four skip counters,
      `pending` before and after, and the day's yield against the 2000-objects/day cap. Exclude from
      the drain-rate columns any pass phase 5 flagged for non-zero `extract error:` lines.
- [ ] Answer the two-filter question from the series, not one reading: does `skipped (subagent /
      harness-started)` continue to dominate `skipped (headless/agent)`, and at what ratio at each
      reading?
- [ ] Answer the drain question from measurement: does a 50-chunk pass reduce `would ingest now`
      faster than new transcripts accrue? State the per-day accrual rate computed from the
      `Available on disk` series, alongside the per-pass reduction.
- [ ] Decide each candidate outcome explicitly, naming for each the measured figure that supports or
      refutes it:
      - **(a) Add `programs.sapience.includeAgentSessions`** wiring `SAPIENCE_INCLUDE_HEADLESS`.
        Supported only if the headless/agent count is large AND phase 6's audit shows that material
        would be substantive. State the measured asymmetry against the non-overridable filter, which
        the option cannot touch.
      - **(b) Adjust the per-run chunk cap, or prescribe a periodic wider `sapience backfill` pass.**
        Weigh against the measured drain rate AND against the daily object cap and the per-pass wall
        clock, both of which scale with the cap.
      - **(c) Turn on `programs.sapience.backgroundSync` with `syncInterval`.** Weigh against the
        measured per-pass cost and the measured review-queue growth, not only against the risk of
        forgetting to run a pass.
      - **(d) Leave all three as they are.** If this is the decision, state it as the decision,
        grounded in the same figures -- not as an absence of one.
- [ ] State the cost dimension honestly. Extraction is now billed per call to the user's Anthropic
      key (`backend = "anthropic"`, `model = "claude-haiku-4-5"`). Use whatever cost signal phase 2
      established; if no per-pass figure is obtainable, say so plainly and bound the decision
      accordingly -- do NOT recommend a cap increase or a timer on an unmeasured cost. Defer
      cost-reduction work to tasks 139 (`reduce_sapience_classifier_cost`) and 140
      (`diagnose_slow_local_ollama_inference`) by name rather than duplicating it here.
- [ ] Write the decision record with: the decision on each of the four outcomes; the figures each
      rests on, each citing a dated ledger block; the outcomes rejected and why; and a limitations
      section naming the series span, the audit sample size and denominator, any error-bearing pass
      excluded, and any unmeasured cost.
- [ ] State in the record whether the decision requires any configuration change at all, so phase 8
      knows whether it has work to do.
- [ ] Record any issue or win via `issue-record.sh` as it arises.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: prose

**Tier Justification**: The only path written is the `specs/**` decision record, for which
`suite_selection_select` returns `__FULL_SWEEP__`, so the covering check is the diff read-through
confirming every figure in the record traces to a dated ledger block and no figure originates in
this plan or in `reports/02`.

**Scope Hypothesis**: This phase asserts the candidate outcome set is exactly the four the task
description enumerates and that the ledger will hold at least five pass blocks plus the phase-6
audit. The implementer MUST re-read the description and the ledger first and, if either differs,
decide over what is actually there -- recording the divergence rather than planning around it.

**Files to modify**:
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/03_extraction-scope-decision.md` - new; the decision on each candidate outcome, its grounding figures, the rejected alternatives, and the stated limitations

**Verification**:
- The record names a decision for each of the four candidate outcomes, including the ones rejected.
- Every figure cites a dated ledger block; no figure is carried from this plan or `reports/02`.
- The limitations section names the series span, the audit sample denominator, every excluded pass,
  and the cost figure or its absence.
- The record states explicitly whether phase 8 has any configuration change to make.

---

### Phase 8: Enact the Decision and Reconcile the Documentation [NOT STARTED]

**Goal**: Apply exactly what the decision selected, make `docs/sapience.md` state the contract that
is then live, and close the task against the full gate set.

**Tasks**:

- [ ] Read phase 7's decision record. Enact exactly what it selected and nothing more; this phase
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

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: The file set is asserted to be at most `home.nix`,
`modules/home/services/sapience.nix`, and `docs/sapience.md`, with `backgroundSync` declared at
`modules/home/services/sapience.nix:710`, `syncInterval` at `:725`, and the chunk budget at `:397`
as of plan time. The implementer MUST confirm against the decision record which of the three files
the decision actually requires, and MUST re-grep for `backgroundSync` and `MAX_CHUNKS` in that
module rather than trusting those line numbers. Tasks 139 and 140 both declare `home.nix` and
`docs/sapience.md` in their own `file_scope`, so this phase must not run concurrently with either.

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

- [ ] `bash .claude/scripts/validate-artifact.sh specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/02_coverage-measurement-series-and-decision.md plan` passes.
- [ ] The ledger's five `Available on disk` sub-counters sum to the stated total at every reading.
- [ ] Every pass block carries a before/after reading pair, or is explicitly flagged as a journal
      reconstruction that cannot supply one.
- [ ] Every pass block states its `extract error:` line count, including zero.
- [ ] Consecutive pass timestamps are at least one day apart, and the series spans at least seven
      days, or the shortfall is recorded as a limitation of the decision.
- [ ] The phase-6 audit states a sample size of at least 30 with its denominator, and confirms
      `sapience review` was not run.
- [ ] Every figure in the decision record cites a dated ledger block.
- [ ] `bash .claude/scripts/verify-deploy.sh` green at phase 8.
- [ ] If any Nix file changed at phase 8, flake evaluation and a Home Manager build are green.

## Artifacts & Outputs

- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/plans/02_coverage-measurement-series-and-decision.md` -- this plan.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/01_coverage-pass-ledger.md` -- the measurement ledger: baseline, five or more pass blocks, mid-series checks.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/02_vault-content-audit.md` -- the read-only queue profile and classified sample.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/records/03_extraction-scope-decision.md` -- the decision on each candidate outcome, its grounding figures, and its limitations.
- Conditional, only if the decision selects a change: edits to `home.nix`,
  `modules/home/services/sapience.nix`, and `docs/sapience.md`.
- `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/summaries/02_*-summary.md` -- the completion summary.

## Rollback/Contingency

Phases 1 through 7 write only new files under `specs/**` and change no configuration, so there is
nothing to roll back from them: an unsatisfactory ledger or audit is corrected by appending a
correction block, not by reverting.

Phase 8 is the only phase that changes machine configuration. Its edits are confined to `home.nix`,
`modules/home/services/sapience.nix`, and `docs/sapience.md`, all tracked, so reverting is an
ordinary revert of that phase's commit followed by a Home Manager switch back to the prior
generation. If an intentional rollback of uncommitted work in that phase is needed, take the
snapshot first per `context/contracts/recovery.md`'s rollback rung -- including its out-of-scope
override flag for the deliberate whole-tree case -- and then run the destructive command; never
emit a bare reverting snapshot as a routine precaution.

If a pass fails at the provider the way the earlier Ollama series did, the contingency is not a
retry loop: record the failure and its error lines in the ledger, exclude that pass from the
drain-rate computation, and run the next pass on the next day. If every pass in the series fails,
the task is blocked on the extraction backend rather than on measurement, and that -- not a decision
drawn from zero successful passes -- is what phase 7 must record.
