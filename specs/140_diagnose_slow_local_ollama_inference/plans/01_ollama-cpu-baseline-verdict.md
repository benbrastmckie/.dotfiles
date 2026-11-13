# Implementation Plan: Task #140

- **Task**: 140 - Diagnose why local llama3.1 inference runs at 0.66 tokens per second on this hardware, and decide whether local Sapience extraction can be made viable
- **Status**: [NOT STARTED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/140_diagnose_slow_local_ollama_inference/reports/01_ollama-cpu-inference-slowdown.md
- **Artifacts**: plans/01_ollama-cpu-baseline-verdict.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/context/standards/artifact-management.md
  - .claude/context/standards/tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The research phase closed two of the four candidate causes and reframed the headline number: the
0.66 tok/s event is real but is an outlier sitting on top of an already-depressed baseline, and
that baseline — not the outlier — is what decides whether local Sapience extraction is viable.
This plan therefore does not chase the anomaly. It produces a reproducible, load-annotated
baseline with frequency and temperature sampled across each run, uses that data to discriminate
the two surviving candidates (memory/cache contention vs. a sustained power/thermal ceiling),
converts the measured decode rate into Sapience's own per-chunk and per-50-chunk wall clock, and
then corrects the three durable files that currently state the outlier as this machine's rate.
Done means: a measured baseline on record, a named cause (or an explicitly inconclusive verdict
with the evidence that failed to discriminate), a viability number rather than a rate, and
`docs/sapience.md` / `home.nix` / `modules/home/services/ollama.nix` telling the current truth.

### Premise Re-Validation

The dispatch flagged the description's carried figures for explicit re-validation against the
research report and live state. Checked, with the result stated for each — including where it
only confirms the description:

| Carried claim | Status |
|---|---|
| `0.66 tokens/sec` | **Confirmed verbatim** in `journalctl` by the research report (`eval time = 88497.33 ms / 58 tokens ... 0.66 tokens per second`), but **recharacterized**: it is a single decode-phase collapse, not this machine's steady state. |
| `58 tokens in 88 seconds` | **Confirmed verbatim** (`88497.33 ms / 58 tokens`). |
| `roughly 1830 percent CPU across 27 threads` | **Uncorroborated.** The event's own log line reads `n_threads = 24 (n_threads_batch = 24) / 24`, so "27 threads" is not supported by the log, and the CPU-percent figure was never re-derived. Treated as unverified; this plan does not rest on it. |
| `roughly 20x slower than an 8B Q4_K_M model should run` | **Corrected.** Against the community HX 370 CPU reference the real gap at baseline is ~2x low on decode and ~7-9x low on prompt-eval. The 20x framing describes only the outlier event. |
| `24-core AMD Ryzen AI 9 HX 370` | **Confirmed** live (`nproc` = 24 logical; 12 physical). |
| `30 GB RAM` | **Confirmed** live (`free -h`: 30Gi total). |
| `19 of 30 GB in use at measurement time` | **True then, materially different now**: live `free -h` reads 14Gi used / 13Gi free / 16Gi available, with 8.4Gi swap in use. Memory pressure is lower today than at the original measurement, which is why Phase 1 can plausibly sample a quiet window. |
| `4.9 GB model` | **Confirmed** live (`ollama list`: `llama3.1:latest`, 4.9 GB, modified 10 days ago). |
| `Reclaiming the 4.9 GB model with ollama rm would require re-pulling it before this work can proceed` | **Moot.** The model is still resident, so no re-pull is needed and nothing blocks the work. `ollama rm` is a Non-Goal here. |
| `a CPU-feature-poor or generically-built llama.cpp` | **Ruled out** by research (per-microarchitecture backends shipped, `AVX512_VNNI`/`AVX512_BF16`/`REPACK` all detected `=1`). Retained only as Phase 2's fallback branch. |
| `a context-size default inflating per-token work` | **Ruled out** by research (`n_ctx = 4096`, observed prompts 244-441 tokens). |
| ROCm route set aside; CPU path only | **Unchanged and respected.** No phase here touches the iGPU. |

### Research Integration

Findings carried into the phase structure: the measurement target is the **baseline**, not the
anomaly (Executive Summary); two candidates survive and are discriminable by frequency behavior
during prefill specifically, because the prefill gap is far larger than the decode gap
(Findings, "normal baseline" section); `lm_sensors` is absent and no RAPL telemetry exists, so
throttle state cannot be read directly today (Findings, thermal section); and any throughput
number taken through the Sapience client must declare its thread setting, because
`ollama_num_thread()` pins the scheduled `--sync` path to 1 thread by design (Findings,
`extract_local.py` section). Research Recommendations 1-6 map to Phases 1, 1, 2, 2, 3 and 3/5
respectively.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so ROADMAP.md was not loaded as
roadmap context and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A reproducible, load-annotated baseline for prompt-eval and decode throughput on this machine,
  taken with fixed benchmark parameters so successive runs are comparable.
- Per-core frequency and temperature sampled across each run, so a power/thermal ceiling can be
  confirmed or excluded by observation rather than inferred from ACPI zones alone.
- A named cause for the depressed baseline, or an explicitly inconclusive verdict stating which
  evidence failed to discriminate.
- A viability verdict expressed as Sapience's own per-chunk and per-50-chunk wall clock, checked
  against the client's 180s `urlopen` timeout, not as a bare tokens/sec rate.
- `docs/sapience.md`, `home.nix`, and `modules/home/services/ollama.nix` stating the measured
  baseline and the verdict instead of the outlier figure.

**Non-Goals**:
- Flipping `programs.sapience.backend` from `"anthropic"` to `"ollama"`. That changes where raw
  transcript text goes and what the workload costs; Phase 5 surfaces it as a `user_decision`
  rather than taking it.
- ROCm / Radeon 890M acceleration — explicitly set aside by the dispatch.
- Adding `lm_sensors` to the persistent Nix configuration. Diagnosis uses a one-off
  `nix shell nixpkgs#lm_sensors` with no persistent config change, per the research report's own
  scoping note.
- Firmware/BIOS power-limit (STAPM / fast-limit / slow-limit) changes.
- `ollama rm llama3.1:latest` — the model is the instrument for every measurement here.
- Changing Sapience's model (`claude-haiku-4-5`) or its 8000-token reply budget.
- Terminating the user's foreground processes to manufacture an idle window.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A genuinely idle machine cannot be created autonomously (the user's Lean builds, browser and other CLI sessions are theirs to stop) | M | H | Sample opportunistically across windows with materially different `/proc/loadavg`; record the full load inventory per run; never kill a user process. Report the best-case number as "quietest window sampled", not "idle". |
| `lm_sensors` exposes nothing usable on this chip (no `sensors` today, no RAPL found in research) | M | M | Fall back to ACPI thermal zones plus 1s `/proc/cpuinfo` MHz sampling, and record the instrumentation gap explicitly rather than asserting a throttle claim the data cannot carry. |
| Neither surviving candidate is discriminated — baseline stays depressed at low load with no frequency drop | M | M | Phase 2 carries the research-named fallback (`OLLAMA_DEBUG=1` plus `strace -f -e trace=openat` to confirm which `libggml-cpu-*.so` is actually `dlopen`'d), and is explicitly permitted to record an inconclusive verdict. |
| The benchmark itself saturates 24 cores and degrades the user's foreground work | M | H | Bound every run (`-epochs 3`, `-max-tokens 128`); never start a run when the load inventory already shows a heavy job; one run at a time. |
| A `bench` invocation outlives a naive wait and strands the dispatch | M | M | Follow `context/patterns/bounded-build-waiter.md`: hard timeout, writer liveness via `kill -0` on the captured PID, one waiter per log, never `pgrep -f`. |
| A comment edit inside a `''` string block in `ollama.nix` breaks Nix evaluation | H | L | `nix-instantiate --parse` on each edited `.nix` file in Phase 4, and `nix flake check` in Phase 5. |
| Tasks 136 and 139 share `docs/sapience.md` and `home.nix` with this task | M | L | Both are standing down; re-check their status immediately before the Phase 4 edits and defer rather than edit concurrently if either has resumed. |
| The 0.66-class collapse recurs mid-benchmark and distorts a run's figures | L | M | Treat a collapse as a datum, not a spoiled run: capture its full `print_timing` block and the concurrent load at that instant, and report it separately from the baseline median. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Instrumented controlled baseline benchmark [NOT STARTED]

**Goal**: Produce a reproducible, load-annotated baseline for prompt-eval and decode throughput,
with per-core frequency and temperature sampled throughout each run, using fixed benchmark
parameters so runs taken in different windows are comparable.

**Tasks**:
- [ ] Record the pre-run environment for each run: `free -h`, `/proc/loadavg`, the top CPU
      consumers (`ps -eo pcpu,rss,comm --sort=-pcpu | head -12`), swap in use, the governor
      (`cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort -u`), and
      `energy_performance_preference`.
- [ ] Enter a one-off `nix shell nixpkgs#lm_sensors` and capture `sensors` output. If it exposes
      no usable junction temperature or power counter on this chip, record that result verbatim
      and proceed on the ACPI-zone fallback — do not add the package to the persistent config.
- [ ] Start a 1s sampler in the background writing timestamped per-core MHz
      (`grep '^cpu MHz' /proc/cpuinfo`), every readable `/sys/class/thermal/thermal_zone*/temp`,
      and `sensors` output (if usable) to a log in the scratchpad directory. Capture its PID and
      wait on it per `context/patterns/bounded-build-waiter.md` (`kill -0` on the captured PID,
      hard timeout, one waiter per log) — never `pgrep -f`.
- [ ] Run the benchmark against the already-running `ollama.service` using the derivation's own
      tool: `OLLAMA_HOST=127.0.0.1:11434 /nix/store/r316a9qc91ryabf01dpg2jzcnz5vsqc8-ollama-0.32.3/bin/bench -model llama3.1 -epochs 3 -prompt-tokens 512 -max-tokens 128 -format csv -output <scratchpad>/bench-run1.csv`.
      Confirm the store path still resolves before use; if the derivation has been
      garbage-collected or updated, re-resolve it from `command -v ollama` and record the new
      path rather than editing a dead one.
- [ ] Harvest the matching `slot print_timing` lines from `journalctl --user -u ollama` for the
      run's window, keeping prompt-eval and decode as separate figures — the two gaps differ by
      several-fold and must never be collapsed into one number.
- [ ] Repeat the identical invocation in at least two further windows chosen for materially
      different `/proc/loadavg`, recording the full load inventory for each. A quiet window is
      sampled opportunistically; it is not created by stopping the user's work.
- [ ] Stop the sampler. Correlate per-core MHz and temperature during the prefill segment versus
      the decode segment of each run against that run's measured throughput.
- [ ] Write every figure, every load inventory, and the instrumentation gaps into the task's own
      record file.

**Timing**: 1.5 hours (dominated by wall-clock waiting across repeated runs)

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase assumes three bounded `bench` runs in materially different load
windows suffice to separate a load-correlated baseline from a load-independent one, and that
`-epochs 3 -prompt-tokens 512 -max-tokens 128` is long enough to reach steady state without
monopolising the machine. Confirm at implementation time: if the three runs' load inventories are
not materially different, or if within-run epoch variance exceeds the between-run spread, add
runs until the two are separable and record the final count actually taken rather than the three
assumed here.

**Tier Justification**: The phase writes only a new record file under `specs/**` and scratchpad
logs; `suite_selection_select` returns `__FULL_SWEEP__` for that path, so per plan-format's
`__FULL_SWEEP__` sub-case (a) the covering check is the `prose` row's diff read-through of the
record — no suite covers it and none is claimed.

**Files to modify**:
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` - new; every run's figures, load inventory, frequency/temperature trace summary, and instrumentation gaps

**Verification**:
- The record file contains, per run, a load inventory and separate prompt-eval and decode
  figures traceable to a quoted `print_timing` line.
- The frequency/temperature trace distinguishes the prefill segment from the decode segment.
- Any instrumentation that returned nothing usable is recorded as such, not silently omitted.

---

### Phase 2: Discriminate contention from a power/thermal ceiling [NOT STARTED]

**Goal**: Decide from Phase 1's data which surviving candidate explains the depressed baseline,
or state explicitly that the data does not discriminate and which evidence fell short.

**Tasks**:
- [ ] Test the contention hypothesis: does throughput track inversely with each run's concurrent
      load, and does the quietest sampled window approach the community HX 370 reference
      (~80-90 tok/s prefill, ~12-15 tok/s decode)? Record the correlation, not an impression.
- [ ] Test the power/thermal hypothesis: does per-core MHz crater during the prefill segment
      specifically — the phase with the largest gap to reference — while load is low, with
      temperature near the high end of the ACPI zone range the research observed? Prefill-only
      collapse is the discriminating signature; a proportional drop across both phases is not.
- [ ] If the baseline stays depressed at low load with no frequency drop, run the research's
      fallback: `OLLAMA_DEBUG=1` plus `strace -f -e trace=openat` against a fresh `ollama serve`
      to confirm which `libggml-cpu-*.so` is actually `dlopen`'d. Detected CPU capability and
      selected backend are logged separately upstream, so the ruled-out build hypothesis is only
      ruled out for capability detection, not for backend selection.
- [ ] If a 0.66-tok/s-class collapse recurs, capture its full `print_timing` block and the
      concurrent load at that instant, and report it apart from the baseline median.
- [ ] Record the verdict with the specific evidence that discriminated it. If nothing
      discriminated, say so and name what further instrumentation would — do not promote the
      more plausible candidate to a conclusion.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The phase only appends analysis to the same `specs/**` record file, for
which `suite_selection_select` returns `__FULL_SWEEP__`, so per sub-case (a) the covering check
is the `prose` row's diff read-through — no suite covers a `specs/**` record and none is claimed.

**Files to modify**:
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` - append the discrimination analysis and the cause verdict (or the explicit inconclusive finding)

**Verification**:
- The verdict names the specific measurement that discriminated it, quoted from Phase 1's data.
- Every candidate not selected is marked either excluded-with-evidence or still-open, with no
  candidate left unaddressed.
- An inconclusive outcome is recorded as inconclusive, with the missing instrumentation named.

---

### Phase 3: Convert the measured rate into a Sapience viability number [NOT STARTED]

**Goal**: Express viability as Sapience's own per-chunk and per-50-chunk wall clock, checked
against the client's hardcoded request timeout, so the go/no-go rests on a duration rather than
a tokens/sec rate.

**Tasks**:
- [ ] Re-derive, do not carry, the client's live constants from `~/.sapience/extract_local.py`:
      the `LLM_MAX_TOKENS` reply cap (research cites 8000) and the `urlopen` timeout (research
      cites 180s). Record the values found and flag any divergence from the research report.
- [ ] Confirm `ollama_num_thread()` still returns 1 for the scheduled `--sync` path and 0
      (Ollama's own default) for interactive/`--backfill`, then take one representative
      extraction measurement with `SAPIENCE_NUM_THREAD` set explicitly or via `--backfill`, so
      the deliberate 1-thread throttle is not mistaken for a hardware ceiling. State which code
      path produced the number.
- [ ] Measure a representative emitted-JSON reply length from an actual extraction rather than
      assuming the 8000-token cap is reached — the cap is a budget, not an expected length.
- [ ] Compute, from Phase 1's median decode rate: seconds per chunk, the 50-chunk pass estimate,
      and whether a single call's projected duration exceeds the client's `urlopen` timeout. A
      per-call time above that timeout means HTTP 500s and zero findings, which is a different
      failure from mere slowness and must be reported as such.
- [ ] State the verdict in one of three forms — viable / not viable / viable only under named
      conditions — with the specific number each claim rests on.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The phase appends a computation to the same `specs/**` record file, for
which `suite_selection_select` returns `__FULL_SWEEP__`; per sub-case (a) the covering check is
the `prose` row's diff read-through, and `~/.sapience/extract_local.py` is read only, never
edited.

**Files to modify**:
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` - append the live client constants, the thread-path attribution, the per-chunk and per-50-chunk computation, and the viability verdict

**Verification**:
- The record names the live `LLM_MAX_TOKENS` and `urlopen` values as read from the client today,
  not as quoted from the research report.
- Every throughput number used carries the thread setting and code path that produced it.
- The verdict is one of the three named forms and cites the number it rests on.

---

### Phase 4: Record the verdict in the durable carriers [NOT STARTED]

**Goal**: Replace the outlier framing in the three durable files with the measured baseline, the
identified cause, and the viability verdict, so the next reader sees the current measurement.

**Tasks**:
- [ ] Re-check that tasks 136 and 139 are still standing down before editing; both share
      `docs/sapience.md` and `home.nix` with this task. If either has resumed, defer this phase
      rather than editing concurrently.
- [ ] `docs/sapience.md`, "Why this backend" section: replace the single-outlier figure in the
      `0.66 tokens/sec` / `58 tokens took 88 seconds` / "near eleven hours" passage with the
      measured baseline range, the named cause, and the per-chunk viability number. Keep the
      existing privacy-trade statement and the closing "Revisit if local inference on this
      hardware becomes practical" sentence; update only what the measurement changed.
- [ ] `docs/sapience.md`, the call-cost comparison later in the troubleshooting material: apply
      the same figure correction, and retain the 180s-timeout consequence only if Phase 3
      confirmed it still applies at the measured rate.
- [ ] `home.nix`, the `programs.sapience.backend` comment block: apply the same figure
      correction to the lines carrying `0.66 tokens/sec` and "near eleven hours". Leave
      `backend = "anthropic"` itself unchanged (Non-Goals).
- [ ] `modules/home/services/ollama.nix` header comment: correct the stale claim that Sapience
      "currently names gemma4:cloud, so no inference happens here today" — `home.nix` sets
      `backend = "anthropic"`, so Sapience reaches no model through this daemon at all. This
      target was confirmed present at authoring time; if the header has since changed, record
      what was found and skip the edit rather than correcting a target that no longer exists.
- [ ] Write the current measurement only. No record-versioning language: no "previously",
      "no longer", "formerly", or draft-history framing anywhere in these three files
      (`rules/no-record-versioning-in-deliverables.md`), and no task-number citations
      (`rules/no-task-references-in-deliverables.md`).
- [ ] Run `nix-instantiate --parse` on each edited `.nix` file.

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the carried figure appears in exactly two places in
`docs/sapience.md` and one comment block in `home.nix`, and that every edit here is
comment-or-prose-only with no semantic Nix change. Confirm at implementation time by grepping
`0\.66\|eleven hours\|tokens/sec` across the three files before editing; if a further occurrence
exists, or if any intended edit turns out to require a semantic change, widen the file list and
re-declare the tier as `full` rather than editing under a `local` justification that no longer
holds.

**Tier Justification**: Every edit is comment-or-prose-only in deploy-consumer-tree paths that
`suite_selection_select` maps to `__FULL_SWEEP__`, so per sub-case (c) the covering check is
`bash .claude/scripts/verify-deploy.sh --only-gate 4 /home/benjamin/.dotfiles` (the
task-reference lint — gate 3 would SKIP outside the source store) together with
`nix-instantiate --parse` on each edited `.nix` file, which is the one check a comment edit
inside a `''` string block can actually break.

**Files to modify**:
- `docs/sapience.md` - replace the outlier figure with the measured baseline, named cause, and viability number in both passages that carry it
- `home.nix` - same figure correction in the `programs.sapience.backend` comment block; `backend` value itself untouched
- `modules/home/services/ollama.nix` - correct the stale header claim about which model Sapience names
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` - append which durable carriers were updated and the exact wording landed in each

**Verification**:
- `nix-instantiate --parse` exits clean on `home.nix` and `modules/home/services/ollama.nix`.
- `bash .claude/scripts/verify-deploy.sh --only-gate 4 /home/benjamin/.dotfiles` passes.
- `grep -n '0\.66\|eleven hours' docs/sapience.md home.nix` returns only intentional survivals,
  each justified in the record file.
- No record-versioning or task-number language appears in the diff for the three non-`specs/**`
  files.

---

### Phase 5: Final gate and decision surfacing [NOT STARTED]

**Goal**: Run the complete gate set over the task's changes and, if the verdict is viable,
surface the backend choice to the user rather than taking it.

**Tasks**:
- [ ] `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` — the complete gate set,
      unnarrowed, with no `--skip-slow` and no `--only-gate` filter.
- [ ] `bash .claude/scripts/validate-artifact.sh specs/140_diagnose_slow_local_ollama_inference/plans/01_ollama-cpu-baseline-verdict.md plan`
      and the same for the task's summary artifact once written.
- [ ] `nix flake check` on this repository — the semantic evaluation check that Phase 4's
      comment-only `local` tier deliberately did not pay for. If the flake check is prohibitively
      slow, substitute an equivalent full evaluation of the home-manager configuration and record
      which was run.
- [ ] If Phase 3's verdict is "viable" or "viable only under named conditions", set
      `user_decision` on both `.return-meta.json` and `.orchestrator-handoff.json`: the question
      is whether to keep `programs.sapience.backend = "anthropic"` or flip it to `"ollama"` at
      the measured per-pass time, `options[]` states both with their measured cost and privacy
      consequence, `recommended` is the implementer's own best judgment, `blocking` is `false`,
      and `obligation` names the privacy-confinement obligation the recommended route
      discharges. This is contract shape 2 — an external cost and a data-location change the
      user must accept — never an agent's call.
- [ ] If the verdict is "not viable", record that no decision is owed and the existing
      `anthropic` backend stands on the measured number.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` - append the gate-run outcomes and whether a decision was surfaced

**Verification**:
- `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` observed green in this
  dispatch — the complete gate set this tier requires, never trusted on sight.
- `bash .claude/scripts/validate-artifact.sh` passes for the plan and the summary.
- `nix flake check` (or the recorded equivalent full evaluation) exits clean.
- Either a `user_decision` object is present on both metadata files with all required fields, or
  the record states why none is owed.

---

## Testing & Validation

- [ ] Each measured figure in the record file traces to a quoted `print_timing` line or a named
      command's output, never to a recollection.
- [ ] Prompt-eval and decode figures are reported separately throughout.
- [ ] Every throughput number carries the thread setting and code path that produced it.
- [ ] `nix-instantiate --parse` clean on both edited `.nix` files.
- [ ] `nix flake check` (or the recorded equivalent) clean.
- [ ] `bash .claude/scripts/verify-deploy.sh /home/benjamin/.dotfiles` green.
- [ ] `bash .claude/scripts/validate-artifact.sh` green for the plan and the summary.
- [ ] No record-versioning or task-number language in the `docs/`, `home.nix`, or `modules/`
      diffs.

## Artifacts & Outputs

- `specs/140_diagnose_slow_local_ollama_inference/plans/01_ollama-cpu-baseline-verdict.md` (this
  plan)
- `specs/140_diagnose_slow_local_ollama_inference/records/01_controlled-benchmark.md` (the
  measurement record, cause verdict, and viability computation)
- Edits to `docs/sapience.md`, `home.nix`, and `modules/home/services/ollama.nix`
- A task summary under `specs/140_diagnose_slow_local_ollama_inference/summaries/`
- A `user_decision` on the implement dispatch's metadata files, if and only if the verdict is
  viable

## Rollback/Contingency

The only non-`specs/**` changes are the comment-and-prose edits in Phase 4, confined to three
files already named in this task's `file_scope`. If they must be reverted, take a snapshot first
and then revert per `context/contracts/recovery.md`'s rollback rung, which carries the exact
invocation shape including its out-of-scope override flag — not a bare precautionary snapshot at
the start of a phase. The benchmark phases change nothing outside `specs/**` and the scratchpad,
so they need no rollback: an abandoned run leaves only logs. If Phase 2 reaches an inconclusive
verdict, Phase 4 still proceeds — the measured baseline is itself worth recording, and the record
states the cause as unresolved rather than leaving the outlier figure standing as this machine's
rate.
