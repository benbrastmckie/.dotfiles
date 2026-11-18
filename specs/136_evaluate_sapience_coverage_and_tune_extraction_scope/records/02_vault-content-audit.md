# Vault-Content Audit (Read-Only)

Discharges the measurement method's third step -- confirm the captured material is substantive
work rather than thread mechanics -- without running `sapience review`.

## Why `sapience review` Was Not Run

`~/.sapience/extract_local.py`'s `--review` path is interactive and share-capable:
`review_queue()` (line 1175) prompts at each record, and `review()` (line 1920) prompts "Press
Enter to share ALL, numbers like 2,5 to DROP those" over the whole queue. Running it unattended
against a queue of this size (3757 records at this audit's own count, below) risks pushing the
entire queue to the hosted vault or dropping it outright with a single mis-keyed input. The
read-only substitute used instead is a direct read of `~/.sapience/pending_kos.jsonl`, which holds
the same staged objects the interactive command would present.

## Queue Shape (Re-Established Live, Not Carried From the Ledger)

**`wc -l ~/.sapience/pending_kos.jsonl`**: `3757` -- matches the Phase 4 accrual sample's
`sapience pending` reading (3757) exactly, confirming the two counters agree at this audit's own
read time as well.

**Key set of one record** (first line), read live: `_hash`, `_staged_at`, `at`, `confidence`,
`ko_type`, `object_value`, `open_thread`, `predicate`, `project`, `reasoning`, `sid`, `subject`,
`tool`. This is two fields WIDER than the field set the plan's Scope Hypothesis for this phase
named (`subject`, `predicate`, `object_value`, `ko_type`, `confidence`, `reasoning`,
`open_thread`, `sid`, `tool`, `at`, `project`) -- `_hash` and `_staged_at` are present on every
record sampled and were not in the plan-time read. Recorded as a finding, not reconciled: the
plan-time read likely omitted the two underscore-prefixed internal bookkeeping fields rather than
the file having changed shape.

## Read-Only Profile (Full Queue, All 3757 Records)

**By `ko_type`**: every single record carries `ko_type: "insight"` -- **3757 of 3757 (100%)**.
No other `ko_type` value appears anywhere in the queue. This is itself a finding: the vendor
client homogenizes every captured fact to one storage category regardless of whether it reads as
a decision, a measured fact, a correction, or a constraint (the categories this very task's own
dispatch instructions use) -- that distinction, if it exists at all, is not preserved in
`ko_type`.

**By `project`**:

| Project | Count | Share |
|---|---|---|
| `.dotfiles` | 1687 | 44.9% |
| `nvim` | 1260 | 33.5% |
| `sapience-app` | 810 | 21.6% |
| `abood` | 0 | 0.0% |

**`abood` has zero staged records despite being one of the four folders task 138 selected and
`sapience coverage`'s `Folders selected (4): nvim, dotfiles, app, abood` line listing it every
reading in this series.** This is recorded as a finding, not explained -- this audit does not
attempt to determine whether `abood`'s session transcripts simply have not yet been selected by
any of the three passes' chunk sampling, or whether some other factor keeps it at zero every
time. (`app` in the folders line is `sapience-app`, matching the 810-record project above.)

**By confidence band**:

| Band | Count | Share |
|---|---|---|
| 0.9-1.0 | 3535 | 94.1% |
| 0.8-0.9 | 192 | 5.1% |
| 0.7-0.8 | 20 | 0.5% |
| 0.6-0.7 | 2 | 0.1% |
| 0.5-0.6 | 8 | 0.2% |
| <0.5 | 0 | 0.0% |

The overwhelming majority of staged records (94.1%) carry confidence >= 0.9; essentially nothing
is staged below 0.5.

**By `open_thread`**:

| Value | Count | Share |
|---|---|---|
| `false` | 2846 | 75.7% |
| `null`/absent | 581 | 15.5% |
| `true` | 330 | 8.8% |

## Hand-Read Sample

**Sample size: 36 records** (exceeds the plan's minimum of 30), drawn with a fixed random seed
(136, this task's own number, chosen for reproducibility) stratified by project in rough
proportion to the full queue's project shares: 14 from `.dotfiles`, 12 from `nvim`, 10 from
`sapience-app`. Line numbers sampled (1-indexed, sorted): 125, 274, 286, 297, 560, 624, 633, 720,
774, 846, 1124, 1523, 1601, 1699, 1759, 1768, 1895, 1901, 1962, 2060, 2194, 2358, 2433, 2475, 2648,
2789, 2958, 3251, 3415, 3428, 3472, 3474, 3475, 3492, 3684, 3698 -- spanning the file from line
125 to line 3698, i.e. across all three extraction passes' contributions, not clustered at one
end.

**Spread across `ko_type` is not possible**: every record in the full queue (and therefore every
record in the sample) carries `ko_type: "insight"`; the sample's spread is instead across
`project` (as stratified above) and across the file's position (early/mid/late, corresponding
roughly to which pass staged each record).

### Classification

Each of the 36 sampled records was read in full and classified as (a) substantive work, (b)
thread mechanics, or (c) duplicate of another record in the sample:

| Class | Count | Denominator |
|---|---|---|
| (a) Substantive work | 30 | 36 |
| (b) Thread mechanics | 5 | 36 |
| (c) Duplicate of another sampled record | 1 | 36 |

**Substantive-versus-mechanics result: 30 of 36 sampled records (83.3%) read as substantive
work.** This is a sample ratio with its denominator stated explicitly, over this 36-record sample
only -- it is NOT a whole-queue figure and must not be read as "83.3% of the 3757-record queue is
substantive."

### Verbatim Examples -- (a) Substantive Work

- Line 624 (`nvim`, conf 0.97): *"Task 606 filter implementation
  decision / decided as: No client-side filter, wrapper, or hook was built because POST
  /v1/cli/context's server-side leak cannot be fixed from the client and a narrowing would be
  theater; instead Phase 1 records all three sites by name in injection-site-scoping.md with both
  foreclosures and both owner actions verbatim."* -- a decision with its rationale, exactly the
  shape this task's own dispatch instructions describe as worth capturing.
- Line 1699 (`nvim`, conf 0.9): *"fixture dependency drift lint algorithm / decision is: Single
  unified extraction procedure handles both Shape 1 (named array) and Shape 2 (open-coded) by
  extracting literal require_file/cp arguments plus any array consumed by either, regardless of
  array name; mandatory-vs-optional classification is the hard part with four distinct guard
  shapes found..."* -- a durable technique/algorithm decision.
- Line 2789 (`.dotfiles`, conf 0.95): *"Home-manager switch no-op verification method / rule is:
  Two consecutive home-manager switch --flake .#benjamin runs must both be no-ops for all three
  gaps; only expected diff is removed-generation store-path hash; this confirms declarative state
  convergence."* -- a reusable verification technique.
- Line 3428 (`sapience-app`, conf 0.9): *"Concurrency SQLite disk-I/O contention impact /
  constraint is: Concurrent multi-agent load causes SQLite disk-I/O contention that severely
  degrades authoritative coverage runs (2137-2249 regressions vs ~25 baseline), making tier 2/3
  trustworthiness unreliable until addressed."* -- a measured fact about an external system,
  exactly the shape named in this task's own Sapience Notes instructions.

### Verbatim Examples -- (b) Thread Mechanics

- Line 633 (`nvim`, conf 0.97): *"Task 612 batch gate test result / result is: Batch-Gate-
  Deferral-scoped tier passed 16/16."* -- a bare run-outcome record (dispatch bookkeeping), not a
  durable finding about the system's design or behavior.
- Line 720 (`.dotfiles`, conf 0.95): *"Task 138 artifact directory status / finding is:
  /home/benjamin/.dotfiles/specs/138_retire_machine_wide_sapience_surface/ holds no plan or
  reports; no artifact was produced beyond the state entry itself."* -- a point-in-time status
  check of one task's directory, not a reusable fact.
- Line 3251 (`sapience-app`, conf 0.95, `open_thread: true`): *"deliverable 6: playwright id skip
  conversion / open thread is: Make 192 playwright-dependent ids skip rather than error,
  following tests/engine_gate.py's existing marker-and-probe convention; this removes noise, not
  scope creep; 418 pre-existing fail/error ids require ledger diff to interpret every run."* -- an
  open task item / TODO, explicitly flagged `open_thread: true`, not a settled finding.
- Line 3492 (`sapience-app`, conf 0.9): *"Task 607 current state / finding is: Task 607 appears
  in the archive only as a reference; its live record is `planned` and not yet implemented."* --
  task-status bookkeeping.
- Line 3415 (`sapience-app`, conf 0.95): *"Task 26 baseline coverage results / result is:
  Committed results in tests/baseline/coverage/: run.json, route-branches.json,
  handler-methods.json, gaps.md, README.md."* -- an artifact-location record tied to one task's
  own output, not a durable, cross-session fact.

### Verbatim Example -- (c) Duplicate

**Only one duplicate pair surfaced in this 36-record sample -- too few to quote the plan's
suggested 3-5 examples of this class.** Stated explicitly rather than padded: both halves of the
one pair found are quoted in full below.

- Line 3472 (`sapience-app`, conf 0.9): *"Task 28 test execution requirement / rule is: Task 28
  has ten gates, all static (ruff F821/F811/F401, AST size/duplicate/dead-code/rebound-name
  walks, import-cycle detection, Dockerfile COPY coverage) with no suite execution."*
- Line 3474 (`sapience-app`, conf 0.95): *"Task 28 static gates inventory / value is: Ten static
  gates with no suite execution: ruff F821, F811, F401; AST size, duplicate, dead-code,
  rebound-name walks; import-cycle detection; Dockerfile COPY coverage."*

Same fact (the same ten gates, the same "no suite execution" qualifier), staged twice under two
different `subject`/`predicate` headers two lines apart in the file -- the client's own
extraction evidently did not recognize these as the same knowledge object.

## Cross-Check Against the Client's Own Mechanics Filter

The client's own `source_skip`/mechanics filter reports what it sets aside via the `Set aside N
transient rows (...): run/thread state, not knowledge` journal line. Collected from every pass in
the series (per `records/01_coverage-pass-ledger.md`):

| Pass | Set-aside line |
|---|---|
| Pass 1 | `Set aside 6 transient rows (pid 5, dispatch 1): run/thread state, not knowledge.` |
| Pass 2 | `Set aside 2 transient rows (dispatch 2): run/thread state, not knowledge.` |
| Pass 3 | `Set aside 6 transient rows (pid 3, dispatch 2, running 1): run/thread state, not knowledge.` |

**Total set aside by the client's own filter across the series: 14 rows** (6 + 2 + 6), out of
3757 total staged -- 0.37% of the queue.

**What the hand-read found that the filter did not catch**: the hand-read sample (36 records, a
different and much smaller set than the filter's own 14 set-aside rows, with no overlap verified
or expected) independently classified **5 of 36 (13.9%)** as thread mechanics -- run-outcome
records, point-in-time status checks, and an open task item -- despite every one of those 5
having already passed the client's own automated mechanics filter and been staged as "knowledge."
**The client's own filter catches a narrower category than a human reading the content would**:
it appears tuned to recognize `pid`/`dispatch`/session-identifier-bearing rows specifically (the
kind illustrated by its own set-aside lines), not the broader class of task-bookkeeping and
run-result statements a hand-read flags. This is the audit's central finding: the automated
filter and a human reader do not agree on where "thread mechanics" ends, and the automated filter
is the more permissive of the two.

## Limitations of This Audit

- The 36-record sample is drawn from a 3757-record queue (0.96% of the queue) -- the 30/36 and
  5/36 ratios above characterize the sample, not the full queue, and this audit makes no claim
  about the true whole-queue substantive/mechanics split.
- Every record in the queue carries `ko_type: "insight"`, so no spread across `ko_type` values
  was possible; the sample instead spreads across `project` and file position.
- `abood` has zero staged records, so the sample (and the full queue) contains no `abood` example
  to classify at all.
- The duplicate-detection class found exactly one pair in this sample; this says only that
  duplication exists and is not caught by the client's own extraction, not what the queue's true
  duplication rate is -- a larger or differently-seeded sample could find more or fewer.

## Issues/Wins Recorded

Recorded via `issue-record.sh` during this phase: a `minor`-severity finding for the `ko_type`
homogenization (every record "insight", no categorical distinction preserved) and a `minor`
finding for the confirmed duplicate pair (lines 3472/3474); a `win` for the sample's clear
majority-substantive result (30/36) confirming the series' passes are staging real knowledge
rather than mostly mechanics.
