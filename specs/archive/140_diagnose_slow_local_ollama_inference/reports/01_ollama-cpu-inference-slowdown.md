# Research Report: Diagnose Slow Local Ollama Inference

**Task**: 140 - Diagnose why local llama3.1 inference runs at 0.66 tokens per second on this hardware, and decide whether local Sapience extraction can be made viable
**Started**: 2026-11-13T22:34:04Z
**Completed**: 2026-11-13T22:40:23Z
**Effort**: ~1 session, live diagnosis on the affected machine (no re-pull needed; llama3.1 was still resident)
**Dependencies**: None
**Sources/Inputs**:
- `journalctl --user -u ollama` (live log inspection, 30-day window)
- Live re-measurement via `/api/generate` against the running `ollama.service`
- `/proc/cpuinfo`, `lscpu`, `/sys/devices/system/cpu/cpu*/cpufreq/*`, `/sys/class/thermal/*`, `free -h`, `systemctl --user show`
- Nix store inspection of the `ollama-0.32.3` derivation (`/nix/store/r316a9qc91ryabf01dpg2jzcnz5vsqc8-ollama-0.32.3`)
- `modules/home/services/ollama.nix`, `home.nix`, `~/.sapience/extract_local.py`
- Web search: community llama.cpp CPU benchmarks for Ryzen AI 9 HX 370 / Strix Point
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The 0.66 tok/s figure is real (confirmed verbatim in `journalctl`: `eval time = 88497.33 ms / 58 tokens ... 0.66 tokens per second`) but it is an **outlier**, not this machine's steady state — the call immediately before and the one just run during this research both measured 6-7 tok/s decode.
- Even the machine's normal steady state is itself well below hardware potential: historical `print_timing` lines across dozens of Sapience-sync chunks show a consistent **~9-13 tok/s prompt-eval / ~5.5-7.7 tok/s decode-eval** baseline, versus a community-reported **~80-90 tok/s prompt-eval / ~12-15 tok/s decode** reference for an 8B Q4_K_M model on this exact chip (Ryzen AI 9 HX 370, CPU-only, llama.cpp). That is roughly 2x low on decode and 7-9x low on prompt-eval even in the "good" case.
- Two of the task's four candidate causes are **ruled out** with direct evidence: the nixpkgs `ollama` derivation ships proper per-microarchitecture CPU backends (`libggml-cpu-zen4.so` among them) with AVX2/AVX512/AVX512_VNNI/AVX512_BF16/REPACK all detected `=1` at runtime; and `n_ctx` is capped at 4096 (not the model's 131072 training context), with actual prompt sizes of 250-440 tokens, nowhere near that cap.
- Memory pressure and thermal/power limiting remain live candidates but neither is conclusively proven: `ollama.service`'s own cgroup shows negligible swap (peak 3.1 MB) even though system-wide memory is tight (18-19 GB/30 GB used, 5.6 GB swap in use); ACPI thermal zones read into the high 80s-90s °C even under light load, with no `sensors`/RAPL telemetry available on this machine to confirm actual core-level throttling.
- A separate, unrelated finding: Sapience's own `extract_local.py` deliberately pins the scheduled `--sync` path to `num_thread=1` (a prior incident fix, "Ari Sklar #12, 2026-09-19"); this does not explain the measured 0.66 tok/s event (that event's own log line shows `n_threads_batch=24`) but it does mean any future local-sync throughput number must be read against which code path made the call.
- **Bottom line for the Sapience-viability question**: even fixing whatever caused the 0.66 tok/s anomaly only recovers this machine to its ~6-13 tok/s baseline, which is itself several-fold below this chip's published ceiling. A real fix for Sapience-at-scale viability needs to close the baseline gap (see Recommendations), not just the anomaly.

## Context & Scope

Scope: diagnose why CPU-only `llama3.1` (8B, Q4_K_M, 4.9 GB) inference under `ollama` is extremely slow on this machine (AMD Ryzen AI 9 HX 370, 24 logical / 12 physical cores, Radeon 890M iGPU, no discrete GPU, 30 GB RAM), and determine whether local inference can be made viable for Sapience's extraction workload (currently routed to `api.anthropic.com` on a metered key specifically because local inference was judged impractical). ROCm acceleration for the 890M was separately considered and set aside; this report stays on the CPU path per the dispatch.

The model (`llama3.1:latest`, 4.9 GB) was still resident on disk (`ollama list` confirms), so this research re-measured live against the running `ollama.service` rather than needing a re-pull.

## Findings

### The reported figure is confirmed, and is an outlier

`journalctl --user -u ollama --since "-30 days"` contains the exact event, verbatim:

```
slot print_timing: id  0 | task 0 | prompt eval time =    2579.75 ms /    35 tokens (   73.71 ms per token,    13.57 tokens per second)
slot print_timing: id  0 | task 0 |        eval time =   88497.33 ms /    58 tokens ( 1525.82 ms per token,     0.66 tokens per second)
slot print_timing: id  0 | task 0 |       total time =   91077.09 ms /    93 tokens
```

This is a decode-phase (`eval time`) collapse: the prompt-eval phase of the *same* call ran at a normal-for-this-machine 13.57 tok/s, then decode fell to 0.66 tok/s for the 58 generated tokens. The very next call on record (run live during this research, seconds later) on the same model, same server, same thread settings produced:

```
slot print_timing: id  0 | task 0 | prompt eval time =     488.01 ms /    14 tokens (   34.86 ms per token,    28.69 tokens per second)
slot print_timing: id  0 | task 0 |        eval time =    2431.53 ms /    17 tokens (  143.03 ms per token,     6.99 tokens per second)
```
— a 10x recovery with no configuration change. This rules out a structural/permanent cause (bad build, wrong backend, broken quantization) as the *sole* explanation, since the same binary/model/config produced normal-for-this-machine numbers moments later.

### The "normal" baseline on this machine is itself several-fold below the chip's published ceiling

Across the full 30-day log window, excluding the one outlier above, `print_timing` lines are consistent:

| Phase | This machine (observed range) | Community reference, HX 370, CPU-only, 8B Q4_K_M |
|---|---|---|
| Prompt-eval (prefill) | ~9-13 tok/s (occasionally 8.4, occasionally 12-13) | ~80-90 tok/s (pp512) |
| Decode (eval) | ~5.5-7.7 tok/s | ~12-15 tok/s (tg) |

(Reference figures: Framework 13 HX 370 forum benchmarks reporting `pp512 ≈ 87.7` / `tg16 ≈ 11.96` and `pp512 ≈ 79.4` / `tg128 ≈ 14.2` for comparable 8B Q4_K_M models, CPU-only llama.cpp — see Sources.)

The gap is much larger for prompt-eval (~7-9x low) than for decode (~2x low). Prompt-eval is the most SIMD/matmul-dense, most power-hungry phase (saturates all cores simultaneously on dense batched GEMM), while decode is comparatively light per step. That asymmetry is consistent with a **sustained power/thermal ceiling specific to this chassis** being hit hardest exactly when the chip tries to draw the most power (prefill), rather than with a backend/kernel selection bug (which would depress both phases proportionally, and which the detected-feature evidence below argues against anyway).

### Ruled out: generic/CPU-feature-poor llama.cpp build

The nixpkgs `ollama` 0.32.3 derivation (`/nix/store/r316a9qc91ryabf01dpg2jzcnz5vsqc8-ollama-0.32.3/lib/ollama/`) ships the full set of per-microarchitecture CPU backend variants used for llama.cpp's runtime dispatch, including `libggml-cpu-zen4.so`, `-icelake.so`, `-sapphirerapids.so`, `-skylakex.so`, `-cascadelake.so`, `-alderlake.so`, `-haswell.so`, `-sandybridge.so`, `-x64.so`. This is not a single generic scalar build.

`journalctl` confirms the capability detection that selects among these at runtime:

```
cmn  common_param: system_info: n_threads = 24 (n_threads_batch = 24) / 24 | CPU : SSE3 = 1 | SSSE3 = 1 | AVX = 1 | AVX2 = 1 | F16C = 1 | FMA = 1 | BMI2 = 1 | AVX512 = 1 | AVX512_VBMI = 1 | AVX512_VNNI = 1 | AVX512_BF16 = 1 | LLAMAFILE = 1 | REPACK = 1 |
```

All of AVX2/AVX512/AVX512_VNNI/AVX512_BF16 and the `REPACK` quantization-repack optimization are detected `true`, and `/proc/cpuinfo` independently confirms the CPU itself exposes `avx512f avx512dq avx512ifma avx512cd avx512bw avx512vl avx_vnni avx512_bf16 avx512vbmi avx512_vnni avx512_bitalg avx512_vpopcntdq`. This candidate cause is ruled out.

### Ruled out: inflated context-size default

```
llama_context: n_ctx         = 4096
llama_model_loader: - kv  10:                       llama.context_length u32              = 131072
print_info: n_ctx_train           = 131072
```

The server caps the actual context window at 4096 (ollama's conventional default), not the model's 131072-token training context. Logged prompt sizes across the historical Sapience-sync chunks (`task.n_tokens`) range 244-441 tokens — far below even the 4096 cap, let alone the model's max. Per-token decode cost does not grow meaningfully at these prompt sizes. This candidate cause is ruled out.

### Not conclusively resolved: memory pressure

At measurement time: `free -h` shows 18-19 GB/30 GB RAM in use, 7-9 GB available, and **5.6 GB of swap in use** system-wide (`swappiness=10`). However, `systemctl --user show`/cgroup accounting for `ollama.service` itself shows `Memory: 16.1M (peak: 8.7G, swap: 2.9M, swap peak: 3.1M)` — i.e. the ollama process's *own* pages were almost never swapped (peak 3.1 MB), which argues against "the model itself got paged out mid-inference" as the direct mechanism.

What is not ruled out: system-wide memory pressure from many concurrent foreground processes (observed at measurement time: a Lean 4 build consuming 235%+ CPU and ~4.5 GB RSS, multiple `claude` CLI sessions, a multi-process Brave browser) could still degrade `llama-server`'s *effective* memory bandwidth and cache residency without ever swapping `llama-server`'s own pages — by evicting its working set from shared L3/cache and by contending for the same DRAM channels. This is consistent with both the depressed baseline and the transient 0.66 tok/s collapse, but was not isolated by a controlled (idle-system) re-run in this research pass.

### Not conclusively resolved: thermal/power limiting

No `lm_sensors` (`sensors` command) or AMD RAPL/energy telemetry is available on this machine, so core-level throttle state could not be directly confirmed. The available ACPI thermal zones read:

```
thermal_zone0 (acpitz): 60.8 - 62.8 °C
thermal_zone1 (acpitz): 76.8 - 78.8 °C
thermal_zone2 (acpitz): 45.8 °C
thermal_zone3 (acpitz): 87.8 - 98.8 °C   <- fluctuated to within ~1-2 °C of a typical mobile APU's throttle point, under light/idle-ish load
```

`dmesg` contains no explicit thermal-throttle messages (none were emitted in either direction — this machine's ACPI/firmware may simply not report them to the kernel log). `scaling_governor` is `powersave` via the `amd-pstate-epp` driver with `energy_performance_preference=balance_performance` and `boost=active`; this is a legitimate, non-broken configuration (not a hard-capped low-clock mode), but it does mean the firmware/EPP layer is free to pull clocks down aggressively under sustained multi-core load or elevated temperature, which a thin/light chassis for this chip plausibly reaches well before the cooling-optimized systems the community benchmark figures above came from (e.g. Framework 13, a thicker chassis with a larger fan/heatsink). This candidate cause is plausible and well-aligned with the prompt-eval-vs-decode asymmetry noted above, but not confirmed with direct instrumentation in this pass.

### Unrelated but notable: Sapience's own client already throttles the scheduled sync path to 1 thread

`~/.sapience/extract_local.py`:

```python
def ollama_num_thread():
    """Ollama threads for the extraction model (Ari Sklar #12, 2026-09-19: the every-4-h agent took every
    core for its whole run). SAPIENCE_NUM_THREAD, else config.json "num_thread"; unset = 1 thread under
    the scheduled --sync (a background job stays in the background), Ollama's own default (all cores)
    for an interactive run or a --backfill. 0 = Ollama's default explicitly."""
    v = _cfg_num('num_thread', 'SAPIENCE_NUM_THREAD', None)
    if v is None: return 1 if (SYNC and not BACKFILL) else 0
    return max(0, int(v))
```

Historical `journalctl` lines confirm both values have been seen in practice: `n_threads = 1 (n_threads_batch = 1) / 24` and `n_threads = 24 (n_threads_batch = 24) / 24` both appear in the 30-day window. This is a deliberate, documented design choice (not a bug) to keep a background cron-style sync from starving the foreground — but it means **a scheduled `--sync` run's throughput is not representative of this hardware's real capability**, and any future viability test must either run `--backfill`/interactive, or set `SAPIENCE_NUM_THREAD`/config `num_thread` explicitly, to measure the hardware rather than the deliberate throttle. The specific 0.66 tok/s event analyzed above was **not** this case — its own log line shows `n_threads_batch=24` — so this finding explains a different, adjacent risk, not the headline anomaly.

### Ollama's `services.ollamaModels` module (local config) is not implicated

`modules/home/services/ollama.nix` and the systemd user unit it generates (`~/.config/systemd/user/ollama.service`) set no CPU/memory cgroup limits (`CPUQuotaPerSecUSec=infinity`, `MemoryMax=infinity`, `CPUWeight` unset) and no thread-count environment variables (`OLLAMA_NUM_THREADS`/`OMP_*` are absent from the running process's environment — only `OLLAMA_HOST` and the cgroup-injected `MEMORY_PRESSURE_WATCH` are set). The module and the local NixOS/home-manager configuration are not throttling or misconfiguring the server.

## Decisions

- Treated the 0.66 tok/s figure as confirmed-via-live-log (re-derived, not carried) rather than re-running a fresh 88-second reproduction, since the exact historical `print_timing` line matches the task description's numbers verbatim and a fresh short generation immediately after already demonstrates the 10x swing without needing a second long run.
- Did not attempt to force a clean, all-else-idle re-run (closing Lean builds / browser / other Claude sessions) in this research pass, to avoid disrupting the user's live session; this is flagged as unresolved below rather than assumed.
- Did not install `lm_sensors` or investigate a RAPL/energy-telemetry path to get direct core-throttle confirmation, since that would add a package install mid-research; left as a recommended next step.

## Recommendations

1. **Re-run a controlled benchmark with the system otherwise idle.** Use `ollama run llama3.1 --verbose` (or `llama-bench` directly against the store's `llama-server`) with no other heavy foreground processes (no Lean build, no browser, fewer concurrent CLI sessions) and capture `print_timing` for prompt-eval and decode separately. This isolates whether the depressed baseline (not just the 0.66 anomaly) is a contention effect or persists on an otherwise-quiet machine — the single highest-value next step, since it discriminates between the two unresolved candidates (memory/cache contention vs. thermal/power ceiling) without new tooling.
2. **Install `lm_sensors` (or read AMD's `k10temp`/energy counters if exposed) and re-run the same idle benchmark while sampling per-core frequency (`watch -n1 'grep MHz /proc/cpuinfo'`) and junction temperature.** If per-core frequency craters during prompt-eval specifically (the phase showing the largest gap vs. the community reference), that confirms the thermal/power-limiting hypothesis directly rather than by inference from ACPI zones alone.
3. **If step 1 shows the baseline recovers close to the ~12-15 tok/s / ~80-90 tok/s community reference once the system is quiet**, treat the original 0.66 tok/s event as resource contention from concurrent foreground load (plausible on this machine, which routinely runs multiple Lean builds and several Claude Code CLI sessions at once) and the fix is operational (don't run heavy local-inference extraction concurrently with other CPU-heavy foreground work), not a configuration change.
4. **If step 1 shows the baseline stays depressed even when idle**, pursue the power/thermal-envelope hypothesis as the primary fix target: check the firmware/BIOS power-limit (STAPM/fast-limit/slow-limit) settings if this is a laptop with user-adjustable TDP, since the community reference figures come from a thicker chassis (Framework 13) that likely sustains a higher continuous power budget than a thin-and-light HX 370 design.
5. **Separately, before trusting any future "local sync throughput" measurement**: explicitly set `SAPIENCE_NUM_THREAD` (env) or `num_thread` in `~/.sapience/config.json` when benchmarking via the Sapience client itself, or use `--backfill`/an interactive call, so the deliberate 1-thread scheduled-sync throttle (`ollama_num_thread()` in `extract_local.py`) is not mistaken for a hardware ceiling.
6. **Revisit the Sapience-viability decision only after step 1's controlled baseline is in hand.** Even in the best case uncovered here (the one fresh post-anomaly measurement), decode ran at 6.99 tok/s — Sapience's own `LLM_MAX_TOKENS=8000` reply budget at that rate is still multiple minutes per chunk, and the existing `anthropic`-backend comment in `home.nix` already estimates "near eleven hours" for a 50-chunk pass at ~0.66 tok/s. Recovering to this machine's own ~6-13 tok/s baseline (let alone the ~12-15 tok/s community reference) meaningfully changes that estimate but likely does not make local extraction fast in absolute terms; a go/no-go call belongs to a planning phase once step 1's number is in hand, not to this research report.

## Risks & Mitigations

- **Risk**: a controlled idle re-run (Recommendation 1) still shows a 0.66-tok/s-class collapse even with no contention, which would point back toward a genuine backend/driver defect despite the feature-detection evidence above. **Mitigation**: if that happens, the next diagnostic step is `OLLAMA_DEBUG=1` plus checking which `libggml-cpu-*.so` was actually `dlopen`'d at runtime (not just which CPU features were detected) via `strace -f -e trace=openat` on a fresh `ollama serve` invocation, since detected-capability and selected-backend are logged separately upstream.
- **Risk**: thermal/power investigation (Recommendation 2) requires installing `lm_sensors` system-wide via the NixOS/home-manager config, which is a configuration change outside this research task's scope. **Mitigation**: scope that as its own narrow follow-up task (or a one-off `nix shell nixpkgs#lm_sensors` for diagnosis only, no persistent config change) rather than bundling it into this diagnosis.

## Appendix

### Search queries used
- `Ryzen AI HX 370 Strix Point llama.cpp CPU tokens per second 8B Q4_K_M benchmark`
- `ollama "disabling mmap" "reason=cpu" llama-server load`

### Key references
- Framework Community forum llama.cpp CPU benchmark threads for Ryzen AI HX 370 (8B Q4_K_M: `pp512 ≈ 87.7`, `tg16 ≈ 11.96`; and a second thread: `pp512 ≈ 79.4`, `tg128 ≈ 14.2`) — https://community.frame.work/t/llm-performance/66708 and https://community.frame.work/t/framework-13-ryzen-ai-linux-distro-llm/69069
- AMD's own llama.cpp-on-Ryzen-AI-300-series performance blog — https://www.amd.com/en/blogs/2024/accelerating-llama-cpp-performance-in-consumer-llm.html
