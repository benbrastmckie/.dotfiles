# Research Report: Measure Sapience capture coverage under manual extraction

- **Task**: 136 - Measure Sapience capture coverage under manual extraction and decide whether to widen the scope, the cap, or the cadence
- **Started**: 2026-11-13T09:20:00Z
- **Completed**: 2026-11-13T09:22:54Z
- **Effort**: 20 minutes (verification only; the measurement series itself cannot start yet)
- **Dependencies**: Task 138 (owner-action reconciliation of `~/.sapience/config.json`, not yet applied)
- **Sources/Inputs**:
  - Live read of `~/.sapience/config.json` (outside this repository, owner-only state)
  - `sapience coverage` and `sapience pending` command output (live run)
  - `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`
  - `specs/TODO.md` entries for tasks 136 and 138
  - `docs/sapience.md`
- **Artifacts**:
  - This report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 138 is marked `[COMPLETED]`, but its owner-action reconciliation of `~/.sapience/config.json`
  — the step this task's dispatch names as the gate that must land before any baseline reading is
  usable — has NOT been applied on disk. Task 138 deliberately left this step to the human owner
  (its own record says "Run this as the owner (never as an agent)"), and no owner run has happened
  since.
- Because the measurement window has not opened, no part of this task's METHOD (baseline reading,
  five spaced passes, final `sapience review`) can start. This dispatch stops at the precondition
  check and reports the blocker rather than collecting a baseline against the wrong population.
- A live, informational (non-baseline) `sapience coverage` run confirms the pre-138 config is still
  active: "Folders selected (5): nvim, dotfiles, PossibleWorlds, BimodalLogic, Verification" — the
  old 5-repo set, not the 4-repo set (`nvim`, `dotfiles`, `abood`, `sapience-app`) task 138 specified.
- That same informational run shows the two skip filters this task exists to tell apart already
  diverge sharply even under the stale population: 30 session files skipped as headless/agent vs.
  874 skipped as subagent/harness-started, out of 1120 available on disk. This ratio is carried here
  as context only, not as the baseline — the denominator is about to change once reconciliation
  lands, and this figure is marked accordingly below.
- Recommended path: the user runs task 138's recorded owner instruction (an idempotent `jq` edit
  already drafted, reviewed, and rehearsed against a copy — never run against the live file by any
  agent), then this task's research phase is re-dispatched to take the real baseline reading and
  begin the five-pass series.

## Context & Scope

This dispatch (task 136, phase research, dispatch_seq 4) is the first substantive research pass for
this task — the task directory held no prior report, plan, or `.return-meta.json` before this
dispatch ran; `.dispatch/4.md`'s own loop-guard records `"prior_status":"not_started"`.

The dispatch's own METHOD section is explicit that step 1 ("measure the current backlog first")
may only be done "after 138 has landed," and that "readings taken before that point are not usable
as a baseline." The scope of this dispatch therefore narrowed, on inspection, from "take the
baseline and plan the five-pass series" to "confirm whether the precondition holds, and if it does
not, say so precisely enough that the next dispatch (or the user) knows exactly what remains."

Everything below documents that precondition check: what task 138 was supposed to leave in place,
what is actually on disk, and the exact gap between them.

## Findings

### Task 138's own design explicitly deferred this to the owner

`specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`
states the reconciliation target precisely: set `enabled: false` on the `BimodalLogic`,
`PossibleWorlds`, and `Verification` entries of `capture.projects`; add two new `enabled: true`
entries for `abood` and `sapience-app`; and replace the top-level `folders` array with exactly
`["-home-benjamin--config-nvim", "-home-benjamin--dotfiles", "-home-benjamin-Projects-abood",
"-home-benjamin-Projects-Sapience-sapience-app"]`. The record is explicit that this is a one-time
`jq` hand-edit meant to be **run by the owner, never by an agent** — "This surface is outside every
repository's tree, mode 600, and its payload self-updates daily — it is owner-only state and is
never edited by an agent." The record also documents a rehearsal against a scratchpad copy, with
before/after digests confirming the live file was never touched by task 138's own agent.

Task 138 is recorded `[COMPLETED]` in `specs/TODO.md` (confirmed by `git log --oneline` showing
`task 138: complete implementation` as the most recent task-138 commit) precisely because writing
and rehearsing that owner instruction was task 138's own deliverable — not running it. Running it
was always out of scope for any agent, by task 138's own design.

### Live inspection: the owner instruction has not been run

Reading `~/.sapience/config.json` directly at this dispatch's start (2026-11-13) shows:

- `capture.projects` still has `BimodalLogic`, `PossibleWorlds`, and `Verification` all
  `enabled: true` (not `false`).
- Neither `abood` nor `sapience-app` appears anywhere in `capture.projects`.
- Top-level `folders` is still the original 5-entry array: `-home-benjamin--config-nvim`,
  `-home-benjamin--dotfiles`, `-home-benjamin-Philosophy-Papers-PossibleWorlds`,
  `-home-benjamin-Projects-BimodalLogic`, `-home-benjamin-Projects-Logos-Verification` — not the
  4-entry target set.
- File mode is `600`, matching the pre-reconciliation state the owner-instruction record describes
  as its starting point, byte-for-byte the same shape that record's own "pre-instruction re-read"
  section recorded on 2026-11-13 at task 138's implementation time.

This is the exact unreconciled state task 138's record predicted would exist until the owner runs
the drafted command — it has not drifted in some other direction, it simply has not moved.

### `sapience coverage` independently confirms the stale population

Running `sapience coverage` live (informational only, explicitly not treated as this task's
baseline per the dispatch's own instruction) reports:

```
Folders selected (5): nvim, dotfiles, PossibleWorlds, BimodalLogic, Verification
Ingested: 24 session files across 4 repos
    BimodalLogic, PossibleWorlds, dotfiles, nvim
Available on disk: 1120 session files
  would ingest now:          146
  skipped (outside 30d window): 0
  skipped (headless/agent):    30   (add --include-agents to keep them)
  skipped (subagent / harness-started transcripts): 874   (thread mechanics; never read)
  skipped (folder not chosen): 70
Per-run extraction cap: 50 chunks (MAX_CHUNKS)
```

`sapience pending` reports `0`.

This is self-consistent with the live config.json read above: the folder set reported is exactly
the old 5-repo set, and `abood`/`sapience-app` do not appear among the ingested repos (they could
not, since their `folders` keys are not in the allowlist and `sapience-app`'s own transcript
directory does not yet exist — task 138's record notes the directory is only created the first
time a session runs from the moved `/home/benjamin/Projects/Sapience/sapience-app` checkout).

**These numbers are explicitly NOT this task's baseline.** They characterize a population (the old
5-repo set) the reconciliation is about to discard, exactly the hazard the dispatch's own
Description section warns against ("A coverage or pending figure collected before it is applied
characterises a corpus that is about to be discarded, and any MAX_CHUNKS or coverage conclusion
drawn from such a figure rests on the wrong denominator"). They are recorded here only as evidence
that the precondition check itself ran, and as context for the one qualitative observation below.

### The two-filter divergence the task exists to measure is already visible, even in the stale population

Even under the wrong (pre-reconciliation) denominator, the dispatch's hypothesis that "on an
orchestration-heavy workflow the second filter removes more than the first" already shows up
sharply: 30 skipped as headless/agent vs. 874 skipped as subagent/harness-started, out of 1120
available on disk. The subagent/harness-started filter is removing roughly 29x more material than
the headless/agent filter in this stale reading. [CARRIED-UNVERIFIED: this report's own
"sapience coverage independently confirms the stale population" finding above — the ratio is
reported here only as a qualitative preview, not as the task's measured baseline, and must be
re-derived against the reconciled population once it exists]

Whether this ratio holds, widens, or narrows once the population is the four loaded repos (which
include `sapience-app`, a repository with no prior transcript history, and `abood`, whose
orchestration intensity is currently unknown to this report) is exactly the open question the
five-pass series must answer. No conclusion is drawn from this preview figure.

## Decisions

- **This dispatch will not collect a baseline reading against the pre-138 population.** The
  dispatch's own instructions are unambiguous that such a reading is not usable, and collecting one
  anyway would produce a number this task would have to discard and re-measure, not save work.
- **This dispatch will not run the owner instruction itself.** Task 138's record is explicit that
  the recorded `jq` command is to be run by the owner, never by an agent, and this task's dispatch
  carries no instruction overriding that boundary. Running it here would also pre-empt the owner's
  own confirmation step (`stat`/`jq` checks the owner-instruction record names) that is designed to
  happen at the moment of the owner's own run.
- **The precondition failure is recorded as a blocking issue** (`issues.jsonl`, class "planned
  feature absent", severity `blocking`) rather than silently deferred, per this task's Issue Log
  contract.

## Recommendations

1. **User action required first**: run the exact command recorded in
   `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`
   ("The instruction" section), then its own listed verification commands, to bring
   `~/.sapience/config.json` to the four-repository target state. This is a short, already-rehearsed,
   idempotent edit — not new design work.
2. **Re-dispatch task 136's research phase** immediately after that reconciliation is confirmed
   applied (the next dispatch should re-read `~/.sapience/config.json` and re-run `sapience
   coverage` itself to reconfirm, rather than trusting this report's now-stale snapshot, since
   config.json "self-updates daily" per task 138's own record).
3. **Once the baseline is taken**, follow the dispatch's METHOD exactly: five extraction passes
   hand-run at least a day apart across at least a week, capturing `sapience coverage` and
   `sapience pending` after each pass, then a `sapience review` spot-check — this cannot be
   compressed into fewer, closer-together passes without losing the drain-rate signal the task
   needs.
4. **Carry forward, do not re-derive from scratch**, the one useful piece of context this dispatch
   found: the subagent/harness-started filter dominated the headless/agent filter by roughly 29x
   under the old population. The next dispatch should check whether this pattern persists, widens,
   or narrows under the reconciled four-repo set, since `sapience-app` and `abood` were not part of
   the population this preview measured at all.

## Risks & Mitigations

- **Risk**: the owner instruction is run, but `~/.sapience/config.json` has drifted further since
  task 138's "pre-instruction re-read" (e.g. a `sapience-bootstrap` or interactive extraction run's
  folder picker re-persisted its own selection, a caveat the owner-instruction record itself calls
  out). **Mitigation**: the next research dispatch must re-read the live file and re-run `sapience
  coverage` before treating any number as the baseline, rather than assuming this report's snapshot
  or the owner-instruction record's snapshot still match.
- **Risk**: the five required passes, spaced a day apart over a week, outlive a single `/orchestrate`
  invocation's natural cadence, and a later dispatch forgets why this task is still open after
  several days with "nothing happening." **Mitigation**: each pass's own dispatch should re-record
  the running tally (coverage/pending deltas since the prior pass) in this task's artifacts, so an
  interruption at any point still leaves a reconstructable partial series rather than requiring a
  restart.
- **Risk**: `sapience-app`'s transcript directory does not exist yet (task 138's record notes it is
  only created the first time a session runs from the moved checkout), so even a correctly
  reconciled config could show `sapience-app` contributing 0 sessions for some early passes purely
  because no qualifying session has happened there yet, not because of either skip filter.
  **Mitigation**: do not read a 0-session count for `sapience-app` in an early pass as a filter
  finding; confirm whether a Claude Code session has actually run from that checkout before drawing
  any conclusion about it.

## Context Extension Recommendations

- **Topic**: Owner-only external state that gates a task's measurement window.
- **Gap**: No existing context file documents the general pattern of a task whose precondition is
  an owner-only, agent-forbidden external action (as opposed to a within-repository artifact or a
  CI run). `context/patterns/external-process-wait.md` and `bounded-build-waiter.md` both cover
  waiting on a process this session can observe completing; neither covers a precondition this
  session can only poll for and never advance itself.
- **Recommendation**: if this pattern recurs (an owner-only config edit gating a later task), a
  short pattern note describing "check the precondition, record a blocking issue, surface a
  `user_decision` naming the exact recorded instruction to run, and stop" would save a future
  research dispatch from re-deriving this same shape from scratch.

## Appendix

- Commands run: `sapience coverage`, `sapience pending`, `jq '.' ~/.sapience/config.json`,
  `stat -c '%a' ~/.sapience/config.json`, `git log --oneline` (task 138 commit history), `jq`/`grep`
  reads of `specs/state.json` and `specs/TODO.md`.
- Files read: `~/.sapience/config.json` (owner-only, outside this repository);
  `specs/138_retire_machine_wide_sapience_surface/records/02_sapience-config-owner-instruction.md`;
  `specs/TODO.md` (tasks 136 and 138 entries); `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/.dispatch/4.md`;
  `specs/136_evaluate_sapience_coverage_and_tune_extraction_scope/.orchestrator-loop-guard`.
- Issue log entry: `issues.jsonl` in this task's directory, class `planned feature absent`,
  severity `blocking`, recorded via `issue-record.sh` at dispatch time.
