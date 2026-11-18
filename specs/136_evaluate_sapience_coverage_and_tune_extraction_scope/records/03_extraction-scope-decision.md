# Extraction-Scope Decision

Decides each of the four candidate outcomes the task description names, from the measurement
series recorded in `records/01_coverage-pass-ledger.md` and the vault-content audit in
`records/02_vault-content-audit.md`. Every figure below cites the dated ledger block or audit
section it comes from; no figure here originates in this plan or in
`reports/02_baseline-and-extraction-backend-blocked.md`.

## Candidate Outcome Set, Re-Confirmed

Re-read live from `specs/state.json` at this phase's start: task 136's own description still
names exactly the four candidate outcomes this plan enumerates --
`programs.sapience.includeAgentSessions`, the per-run chunk cap / periodic wider backfill,
`programs.sapience.backgroundSync`, or leaving all three as they stand. No divergence found; the
decision below is drawn over that same set.

## Tabulation Across Every Recorded Pass

| Field | Pass 1 (2026-11-13) | Pass 2 (2026-11-17) | Pass 3 (2026-11-18) |
|---|---|---|---|
| Wall clock | 29min 4.283s | 22min 29.800s | 47min 58.532s |
| Chunks | 50 | 50 | 50 |
| Objects staged | 1208 | 539 | 2010 |
| Objects/chunk | 24.16 | 10.78 | 40.2 |
| `would ingest now` before -> after | not captured (journal-reconstructed) | 118 -> 118 | 134 -> 134 |
| `skipped (headless/agent)` before -> after | not captured | 40 -> 40 | 45 -> 46 |
| `skipped (subagent/harness-started)` before -> after | not captured | 1253 -> 1258 | 1388 -> 1391 |
| `skipped (folder not chosen)` before -> after | not captured | 200 -> 201 | 214 -> 215 |
| `sapience pending` before -> after | not captured -> 1208 | 1208 -> 1747 | 1747 -> 3757 |
| Day's `sapience yield` vs. 2000 cap | 1211 objects (cumulative, shared day with a failed ollama run) | 0 -> 550 | 0 -> 2051 (exceeds cap) |
| `extract error:` count | 0 (usable for cost/duration only -- no coverage pair exists) | **34 (excluded from clean drain-rate)** | 0 (clean) |

**Pass 2 is excluded from every drain-rate column below** per its own ledger flag (34
`extract error:` lines, a partial-failure pass) and Phase 4's drain-rate exclusion list. **Pass 1
is excluded from every before/after delta** because it supplies no coverage pair at all (journal
reconstruction only). This leaves **Pass 3 as the only clean, fully-observed drain-rate datum** in
the entire series -- carried forward explicitly as a limitation below, not smoothed over.

## Findings Carried From the Recorded Series (Not Re-Derived)

Each cites the ledger block it rests on:

- **`would ingest now` held exactly flat across both fully observed passes** (Pass 2: 118 -> 118;
  Pass 3: 134 -> 134) -- `records/01_coverage-pass-ledger.md`, Pass 2 and Pass 3 "Computed deltas"
  tables. One 50-chunk pass does not visibly drain the queue of ingestible transcripts.
- **Per-pass yield varies 3.7x at an identical 50-chunk count** (539 / 1208 / 2010 objects) --
  `records/01_coverage-pass-ledger.md`, Pass 3's "Daily-cap headroom check" -- driven by the
  content of the chunks selected that day, not by accrual time.
- **The non-overridable subagent/harness-started filter dominates the overridable headless/agent
  filter by a stable 30.13x-31.45x band across all six coverage readings now in the ledger**
  (five from Phase 3's mid-series check plus the Phase 4 accrual sample's 31.04x) --
  `records/01_coverage-pass-ledger.md`, Pass 3's "Mid-series filter-ratio check" and Phase 4's
  "Two-filter ratio, re-run with the fresh reading added". `SAPIENCE_INCLUDE_HEADLESS=1` does not
  override this dominant filter at all.
- **`MAX_CHUNKS=50` is not a throughput bottleneck**: a pass runs 22-48 minutes wall clock across
  the three real passes, well under any hour-scale budget -- `records/01_coverage-pass-ledger.md`,
  each pass's "Wall clock" field.
- **The 2000-objects/day cap is descriptive only and does not truncate a run** -- Pass 3 finished
  at 2051 objects (51 past the cap) with no journal line indicating an early stop or a dropped
  chunk -- `records/01_coverage-pass-ledger.md`, Pass 3's "Daily-cap finding" and Phase 4's
  "Queue growth against the 2000-objects/day cap".
- **The unreviewed queue tripled from 1208 to 3757 in two passes and has not moved since** (the
  Phase 4 accrual sample, taken with no pass or review run, reads the identical 3757) --
  `records/01_coverage-pass-ledger.md`, Phase 4's "Review-queue growth across the whole recorded
  series". This is the constraint that actually binds, not the chunk cap and not the drain rate.

## Two-Filter Question, Answered From the Series

**Does `skipped (subagent/harness-started)` continue to dominate `skipped (headless/agent)`, and
at what ratio at each reading?** Yes, at every one of the six readings now in the ledger, in a
narrow 30.13x-31.45x band that has not moved as both counters grew (headless/agent 30 -> 45,
+50%; harness-started 904 -> 1397, +55% -- both growing at essentially the same rate). Source:
`records/01_coverage-pass-ledger.md`, Pass 3's mid-series check and Phase 4's re-run check.

## Drain Question, Answered From Measurement

**Does a 50-chunk pass reduce `would ingest now` faster than new transcripts accrue?** On the
evidence recorded, **no** -- the only two fully observed passes (Pass 2 and Pass 3) both show
`would ingest now` completely unmoved by the pass itself (118 -> 118; 134 -> 134), while
`Available on disk` grew during both runs (+6, +5). The per-day accrual rate computed in Phase 4
rests on only two full-day-scale inter-pass intervals -- 113.6 objects/day (Pass 0 to Pass 2
before) and 164.3 objects/day (Pass 2 after to Pass 3 before), a ~45% spread between them -- plus
one sub-hour, noisy interval (263.2/day). **This question cannot be answered with a single
confirmed number**: two clean before/after passes show the backlog not shrinking, but two data
points establish a direction, not a rate precise enough to size a cap change against. Source:
`records/01_coverage-pass-ledger.md`, Phase 4's "Per-day transcript accrual rate" section.

## Decision on Each Candidate Outcome

### (a) Add `programs.sapience.includeAgentSessions` wiring `SAPIENCE_INCLUDE_HEADLESS` -- REJECTED

**Supported only if the headless/agent count is large AND the vault-content audit shows that
material would be substantive.** Neither condition holds on the measured evidence:

- The headless/agent skip count is small in absolute terms (45 at the most recent reading) and is
  dwarfed by the non-overridable filter it cannot touch (1397 at the same reading, a ~31x
  difference per the stable band above). Even if every headless/agent-skipped transcript were
  included, the resulting coverage gain would be small relative to the backlog the
  non-overridable filter already removes -- and that non-overridable filter's own removal cannot
  be changed by this option at all.
- The vault-content audit (`records/02_vault-content-audit.md`) read the content the client
  already captured and staged -- it did **not** sample the headless/agent-skipped transcripts
  themselves, since those were never extracted. **There is no direct evidence from this task
  about whether headless/agent material would be substantive if included** -- this is named
  explicitly as a limitation below, not glossed over.

Given the small measured scale of the gain and the complete absence of direct evidence that the
excluded material is worth keeping, this outcome is rejected on the measured figures as they
stand, not on principle.

### (b) Adjust the per-run chunk cap, or prescribe a periodic wider `sapience backfill` pass -- REJECTED

**Weighed against the measured drain rate AND against the daily object cap and the per-pass wall
clock, both of which scale with the cap.** The measured drain rate shows `would ingest now`
holding flat at an identical 50-chunk count across both fully observed passes -- raising the
per-pass chunk count would not address a backlog that a 50-chunk pass does not visibly shrink in
the first place; the binding constraint identified above is the unreviewed-review-queue depth
(1208 -> 3757, untouched by anything but a pass), not extraction throughput. Widening the cap
would only grow that unreviewed queue faster, without first establishing that review can keep
pace with even the current cap (it has not been tested at all -- no review session was run in
this task, by design). `MAX_CHUNKS=50` is independently confirmed not to be a wall-clock
bottleneck (22-48 minutes per pass, well under an hour). This outcome is rejected: there is no
measured throughput problem for a larger cap to solve, and there is a measured review-queue
problem a larger cap would make strictly worse.

### (c) Turn on `programs.sapience.backgroundSync` with `syncInterval` -- REJECTED

**Weighed against the measured per-pass cost and the measured review-queue growth, not only
against the risk of forgetting to run a pass.** Two independent reasons:

- **No per-pass dollar or token cost figure is obtainable from the client's own output** --
  confirmed three times across the series (Pass 1, Pass 2, Pass 3 in
  `records/01_coverage-pass-ledger.md`) and not contradicted anywhere in this phase. Scheduling
  an unattended, recurring job against an unmeasured per-run cost, billed to the user's own
  Anthropic key, is not something this task's evidence can responsibly recommend. Per the plan's
  own instruction, this decision does not recommend a scheduling change on an unmeasured cost.
- **The unreviewed queue already grew from 1208 to 3757 (entirely pass-driven, confirmed flat
  between passes) across only three manually-triggered passes over ~5.4 days, with zero review
  sessions run in that span.** Scheduling extraction on an automatic timer would only accelerate
  that same growth with no corresponding improvement to review capacity, which this task has no
  evidence about at all (see limitations below). Automating the half of the pipeline that already
  outpaces review, while leaving review itself unaddressed, would make the actual bottleneck
  worse, not better.

This outcome is rejected on both cost and queue-growth grounds, independent of each other.

### (d) Leave all three as they are -- SELECTED

With (a), (b), and (c) each rejected on the measured figures above, **this is the decision,
stated as the decision and grounded in those same figures, not as an absence of one.** The
current arrangement -- hand-run passes via `systemctl --user start sapience-sync.service`, no
background timer, `MAX_CHUNKS=50`, headless/agent sessions excluded -- is retained unchanged. The
binding constraint this series surfaced is review-queue depth, not any of the three levers this
task was asked to weigh; none of the three measured problems this task was built to detect
(coverage gap worth including, throughput shortfall, forgetting to run passes) was actually found.

## Cost Dimension, Stated Honestly

Extraction is billed per call to the user's own Anthropic key (`backend = "anthropic"`, `model =
"claude-haiku-4-5"`, confirmed in `records/01_coverage-pass-ledger.md`'s Pass 0 backend-wiring
block). **No per-pass dollar or token cost figure is obtainable from the client's own output** --
`sapience stats`, `sapience coverage`, and the systemd journal were each checked at Phase 1, Phase
2, and Phase 3 and none exposes one; only wall clock and CPU time are available
(`records/01_coverage-pass-ledger.md`, each pass's "Cost signal" subsection). This decision does
NOT recommend a cap increase or a timer on that unmeasured cost, per the plan's own instruction.
Cost-reduction work (reducing the classifier's cost specifically, or diagnosing slow local
inference as an alternative to the metered anthropic backend) is explicitly deferred to the
roadmap's own task entries for `reduce_sapience_classifier_cost` and
`diagnose_slow_local_ollama_inference` by name, rather than duplicated here.

## Limitations of This Decision

Stated in its own right, not folded into a general caveat:

- **Three real extraction passes, not the five the original method called for.** Pass 1, Pass 2,
  Pass 3 -- `records/01_coverage-pass-ledger.md` in full.
- **A span of about 5.44 calendar days (2026-11-13T11:37:47Z to 2026-11-18T22:11:46Z), not the
  full week the method called for.** `records/01_coverage-pass-ledger.md`, Phase 4's
  series-completeness check.
- **Of the three passes, only two (Pass 2, Pass 3) carry a usable before/after coverage pair, and
  of those two, only one (Pass 3) is clean (zero `extract error:` lines).** Pass 2's 34 errors
  exclude it from the clean drain-rate tabulation -- `records/01_coverage-pass-ledger.md`, Pass
  2's error section and Phase 4's drain-rate exclusion list. **This leaves exactly one clean,
  fully-observed drain-rate datum in the entire decision above.**
- **The vault-content audit sampled 36 of 3757 pending records (0.96%)**, finding 30/36 (83.3%)
  substantive, 5/36 thread mechanics, 1/36 a duplicate pair --
  `records/02_vault-content-audit.md`. This characterizes the sample only, not the whole queue,
  and the audit read only already-captured content, never the headless/agent-skipped material
  decision (a) would have included.
- **No per-pass cost figure exists anywhere in this task's evidence**, bounding decisions (b) and
  (c) above to a cost-blind basis -- stated plainly rather than estimated.
- **Whether per-pass yield variability (3.7x observed: 550/1208/2010) narrows over a longer
  series is unanswerable from three passes.** `records/01_coverage-pass-ledger.md`, Phase 4's
  stated limitations.
- **Whether a steady-state drain rate exists at all is unanswerable from one clean, fully-observed
  pass.** A single clean datum cannot establish a steady state; Pass 3 alone shows `would ingest
  now` flat, but whether that is typical or a coincidence of that pass's own chunk selection is
  unknown. `records/01_coverage-pass-ledger.md`, Phase 4's stated limitations.
- **The per-day accrual rate (113.6/day and 164.3/day across the two available full intervals, a
  ~45% spread) carries low confidence** -- two disagreeing data points, not a measured constant.
  `records/01_coverage-pass-ledger.md`, Phase 4's accrual-rate section.
- **Whether review capacity can keep pace with pass-driven queue growth is entirely unmeasured.**
  No review session was run anywhere in this task (by design -- see
  `records/02_vault-content-audit.md`'s own first finding). The queue-growth side is fully
  measured (+2549 objects across the series); the drain side has no datum at all. This bears
  directly on outcome (c)'s rejection above and is the single largest open question this decision
  carries forward.
- **One small, unresolved measurement anomaly**: `skipped (headless/agent)` dropped 46 -> 45
  between Pass 3's after-reading and the Phase 4 accrual sample with no pass or review run in
  between; no mechanism for this is visible in the coverage output.
  (`records/01_coverage-pass-ledger.md`, Phase 4's accrual-sample delta table.)

## Configuration Change Required: NONE

**The decision selects outcome (d): leave all three as they are.** No change to `home.nix`,
`modules/home/services/sapience.nix`, or `docs/sapience.md`'s underlying configuration is
required by this decision. Phase 7 therefore has no configuration-enactment work to do; per the
plan's own instruction, Phase 7 closes as `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned
Exclusions` block naming this record as the reason, and only reconciles `docs/sapience.md`'s
prose so it continues to state the contract that is actually live (which this decision leaves
unchanged).
