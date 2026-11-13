# Summary: Task #140

- **Task**: 140 - Diagnose why local llama3.1 inference runs at 0.66 tokens per second on this hardware, and decide whether local Sapience extraction can be made viable
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T14:52:00-08:00
- **Completed**: 2026-11-13T15:30:00-08:00
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_ollama-cpu-baseline-verdict.md, records/01_controlled-benchmark.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Four controlled `bench` runs across materially different ambient-load windows, with per-core
frequency and junction-temperature sampled throughout, replaced the single 0.66-tok/s outlier
with a measured baseline, a discriminated cause, and a Sapience viability verdict expressed as
wall-clock against the client's 180s call timeout rather than a bare rate. The three durable
carriers (`docs/sapience.md`, `home.nix`, `modules/home/services/ollama.nix`) now state the
current measurement.

## What Changed

- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` (new) —
  four load-annotated benchmark runs, the frequency/temperature trace, the discrimination
  analysis, and the per-chunk/per-50-chunk viability computation.
- `docs/sapience.md` — two passages ("Why this backend", "Performance and failure modes")
  replaced the `0.66 tokens/sec` / "near eleven hours" outlier framing with the measured range
  and the dense-chunk timeout failure mode.
- `home.nix` — the `programs.sapience.backend` comment block carries the same correction;
  `backend = "anthropic"` itself is unchanged.
- `modules/home/services/ollama.nix` — the header comment's stale claim about which model
  Sapience names was corrected to state that the `anthropic` backend means Sapience reaches no
  model through this daemon today.
- `specs/140_diagnose_slow_local_ollama_inference/plans/01_ollama-cpu-baseline-verdict.md` —
  all five phases marked `[COMPLETED]`, all checklist items checked.

## Decisions

- Ran one more benchmark window (four total) than the plan's three-run scope hypothesis assumed,
  because the first three (all at elevated ambient load, `loadavg` 9.33-17.25) did not separate
  the two candidate causes from each other; a fourth, genuinely quiet window (`loadavg` 2.03)
  did, and that count is reported as actually taken rather than silently matching the plan's
  assumption.
- Attributed the depressed baseline to two causes rather than forcing a single verdict:
  contention via a shared package power budget (confirmed by matching per-core frequency jumps
  between loaded and quiet windows) as the dominant runtime-variable cause, plus a residual,
  not-fully-isolable gap attributable in part to this `ollama` build's `zen4`-tuned kernel
  (confirmed by `/proc/<pid>/maps` inspection of a live runner) on a chip with no `zen5`-native
  tune shipped yet.
- Computed Sapience viability from the client's live, re-derived constants
  (`LLM_MAX_TOKENS = 8000`, `urlopen` `timeout=180`, `ollama_num_thread()` returning 1 for
  scheduled sync / 0 for backfill-or-interactive) rather than carrying the research report's
  citations, and measured both thread paths directly rather than assuming one from the other.

## Plan Deviations

- None (implementation followed plan; the one addition — a fourth benchmark run beyond the
  three-run scope hypothesis — was pre-authorized by the plan's own Scope Hypothesis confirmation
  clause, not an unplanned deviation).

## Impacts

- `docs/sapience.md`, `home.nix`, and `modules/home/services/ollama.nix` now state the current
  measured baseline and verdict; a future reader is no longer pointed at a single anomalous
  event as this machine's rate.
- The viability verdict is "viable only under named conditions" (run via `--backfill`/interactive
  rather than the scheduled 1-thread sync path; accept that a sufficiently dense chunk will still
  exceed the 180s timeout and fail outright at every thread setting measured). A `user_decision`
  is surfaced on this dispatch's metadata accordingly — whether to flip
  `programs.sapience.backend` from `"anthropic"` to `"ollama"` at this measured cost — rather than
  this task taking that call itself, per the plan's own Non-Goals.

## Follow-ups

- The `user_decision` surfaced by this task (keep `anthropic`, or flip to `ollama` and accept the
  occasional dense-chunk timeout failure) is unresolved pending the user's own judgment.
- No zen5-native `ggml` CPU kernel exists in this `ollama` build; revisit if nixpkgs ships one,
  since that is the one lever this task could not pull itself.
- Task 139 (classifier cost) depends on this task's close; it can now proceed.

## References

- `specs/140_diagnose_slow_local_ollama_inference/reports/01_ollama-cpu-inference-slowdown.md`
- `specs/140_diagnose_slow_local_ollama_inference/plans/01_ollama-cpu-baseline-verdict.md`
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md`
