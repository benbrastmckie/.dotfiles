# Research Report: Task #60

**Task**: 60 - Add Nix build resource limits to prevent OOM during rebuilds
**Started**: 2026-06-24T00:00:00Z
**Completed**: 2026-06-24T00:00:00Z
**Effort**: ~2 hours research
**Dependencies**: None
**Sources/Inputs**: Nix reference manual, NixOS Discourse, nixpkgs GitHub, mynixos.com, local configuration.nix, update.sh
**Artifacts**: `specs/060_add_nix_build_resource_limits_prevent_oom/reports/01_build-resource-limits.md`
**Standards**: report-format.md

---

## Executive Summary

- The HX 370 machine has 32 GB RAM (32122796 kB per /proc/meminfo) and 24 logical cores (12 Zen 5 cores with SMT). Current `nix.settings` has no `max-jobs` or `cores` constraints; the default `max-jobs = "auto"` and `cores = 0` (all cores) means the nix daemon will freely spawn 24 parallel jobs each attempting to use all 24 cores — in the worst case 576 concurrent compiler processes.
- For heavy C++ packages (onnxruntime, LLVM, libtorch), a single compile unit can consume 1–4 GB RSS. The safe formula is `max-jobs × cores ≤ RAM_GB / mem_per_compile_unit_GB`. With 30 GB usable RAM and ~2 GB/unit for worst-case C++: at most ~15 simultaneous compiler processes.
- **Recommended values**: `max-jobs = 4`, `cores = 6` (product = 24 total cores used; ≤ 12 simultaneous heavy C++ compile units). A lower-risk conservative option is `max-jobs = 2`, `cores = 12` (better single-job throughput, at most 12 simultaneous heavy processes).
- `nixos-rebuild` accepts `--max-jobs N` / `-j N` as a direct CLI flag and `--cores N` via `--option cores N` override. Both work alongside `--flake`. Adding a `--max-jobs 2` guard to `update.sh` is a safe override for interactive rebuilds.
- No modifications to `configuration.nix`, `home.nix`, or `flake.nix` were made during this research (read-only investigation).

---

## Context & Scope

### Hardware

- **CPU**: AMD Ryzen AI 9 HX 370, 12 cores / 24 threads (SMT), Zen 5 architecture
- **RAM**: 32 GB (32122796 kB MemTotal per /proc/meminfo; ~30.6 GiB usable; task description says 30 GB — the figure is correct in practice after BIOS/kernel reservation)
- **Swap**: 16 GB swapfile (priority −2) + zram at 50% RAM (up to ~15 GB, priority 5) = ~31 GB total virtual memory buffer

### Problem

onnxruntime and similar heavy C++ packages (LLVM, Abseil, Protobuf) build via CMake/Ninja. When nix spawns N parallel derivation builds, each Ninja instance itself spawns `NIX_BUILD_CORES` sub-processes. With defaults:

- `max-jobs = "auto"` → 24 parallel derivations
- `cores = 0` → NIX_BUILD_CORES = 24 per derivation
- Worst case: 24 × 24 = **576 concurrent compiler processes**

At 1–2 GB RSS per heavy C++ TU, this trivially exhausts 32 GB RAM + triggers swap thrashing, then OOM-kill cascade. earlyoom (already configured at 10% free threshold) will eventually kill processes but not before a multi-minute system freeze.

### Constraints for This Research

- No build commands, no writes to /nix/store, no GC operations
- Read-only inspection of configuration.nix and update.sh
- A Lean build is actively running on /nix/store; any nix daemon interference is prohibited

---

## Findings

### 1. Current Configuration State

`configuration.nix` line 735–745:

```nix
nix = {
  settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
};
```

No `max-jobs` or `cores` setting is present. Both default to their "auto/0" values (all cores, unlimited jobs). `update.sh` runs:

```bash
sudo nixos-rebuild switch --flake .#$HOSTNAME --option allow-import-from-derivation false
home-manager switch --flake .#benjamin --option allow-import-from-derivation false
```

No `-j`/`--max-jobs` or `--cores` override is present in the script.

### 2. Official Nix Documentation — Option Semantics

**`nix.settings.max-jobs`** ([NixOS options search](https://search.nixos.org/options?channel=24.05&show=nix.settings.max-jobs), [MyNixOS](https://mynixos.com/nixpkgs/option/nix.settings.max-jobs))
- Type: `signed integer or "auto"`
- Default: `"auto"` (equals number of logical CPUs — 24 on this machine)
- Meaning: maximum number of derivations built in parallel by the nix daemon
- Setting to `0`: disables local builds (remote/substitution only)

**`nix.settings.cores`** ([MyNixOS](https://mynixos.com/nixpkgs/option/nix.settings.cores))
- Type: `signed integer`
- Default: `0` (use all available cores)
- Meaning: sets `NIX_BUILD_CORES` env var inside each build sandbox; build systems (Ninja, make) use this as their `-j` value
- Setting to `0`: each build uses all 24 cores (the most dangerous default)
- Caveat: "some builds may become non-deterministic with this option; use with care"
- Note: packages must have `enableParallelBuilding = true` (most C++ packages in nixpkgs do)

**Total cores formula** ([Nix Reference Manual — Tuning Cores and Jobs](https://nix.dev/manual/nix/stable/advanced-topics/cores-vs-jobs)):

```
max_cores_in_use = max-jobs × NIX_BUILD_CORES
```

where `NIX_BUILD_CORES = cores` unless `cores = 0`, in which case `NIX_BUILD_CORES = nproc`.

With defaults on this machine: `24 × 24 = 576` (catastrophic for 32 GB RAM).

### 3. Memory Model for Heavy C++ Packages

From the NixOS Discourse thread ([I/O & CPU scheduling, jobs & cores](https://discourse.nixos.org/t/i-o-cpu-scheduling-jobs-cores-and-performance-baby/66120)) and onnxruntime build failure reports ([nixpkgs issue #301949](https://github.com/NixOS/nixpkgs/issues/301949)):

| Package | Approx. peak RSS per compile unit | Source |
|---------|----------------------------------|--------|
| onnxruntime (CPU-only) | 1.5–2.5 GB | nixpkgs#301949 (freezes 24 GB machine) |
| LLVM clang | 1–2 GB | Community reports |
| libtorch / PyTorch C++ | 2–4 GB | Community reports |
| General C++ (Abseil, Protobuf) | 0.5–1 GB | Typical |

The Discourse user with 32 HT + 60 GB RAM + 100 GB swap reports: "Even 60GB RAM + 100GB swap couldn't fit everything at 16 jobs × 32 cores." The key insight: **as soon as swap is involved, CPU utilization plummets and build time increases dramatically** — often worse than a single-job serial build.

**Safe budget calculation for this machine:**

```
Usable RAM budget for builds = 30 GB - 4 GB (OS/desktop/Lean daemon overhead) = ~26 GB
Max concurrent compiler processes = 26 GB / 2 GB per unit = ~13
```

With `max-jobs × cores = 12–15`, the system should stay in RAM without touching swap.

### 4. Interaction with earlyoom and zram

The existing earlyoom configuration kills processes at 10% free RAM (≈3 GB). With zram at 50% / priority 5, the effective memory hierarchy is:

1. RAM (30 GB usable) — first tier
2. zram compressed swap (up to ~15 GB, priority 5) — fast in-RAM tier  
3. swapfile (16 GB, priority −2) — SSD-backed tier

During a heavy C++ build, zram will compress idle pages to free RAM. However, C++ compiler processes have poor compressibility (large active working sets). If builds exhaust RAM + zram, the swapfile kicks in over NVMe — acceptable latency for cold pages but catastrophic for active compiler heap.

**Conclusion**: setting `max-jobs × cores ≤ 12` keeps the system comfortably within the RAM budget, with zram providing additional headroom for page cache reclaim.

### 5. Community Recommendations

From the Discourse thread ([Concrete suggestions for balancing cores and max-jobs](https://discourse.nixos.org/t/are-there-concrete-suggestions-for-balancing-cores-and-max-jobs/11824)):

- Recommended starting point: `max-jobs = 2`, `cores = nproc` (set cores to CPU count, keep jobs low)
- The reasoning: most `make`-based builds use `-l${NIX_BUILD_CORES}` (load-average limiting), so over-commit is self-correcting for those. But CMake/Ninja builds (like onnxruntime) may not respect load average and will genuinely spawn `NIX_BUILD_CORES` processes.
- For systems where heavy C++ packages OOM: reduce BOTH settings so the product stays within memory budget.

The Nix manual explicitly presents the `(4, 6)` example as "efficient use without overselling at 24 processes" on a 24-core system.

### 6. CLI Override Syntax

**nixos-rebuild** ([Man page](https://www.mankier.com/8/nixos-rebuild), [Nix common options](https://nix.dev/manual/nix/2.24/command-ref/opt-common)):

```bash
# Short form
sudo nixos-rebuild switch --flake .#hostname -j 4

# Long form  
sudo nixos-rebuild switch --flake .#hostname --max-jobs 4

# Cores override (via --option pass-through)
sudo nixos-rebuild switch --flake .#hostname --max-jobs 4 --option cores 6

# Minimal safe override (only constrain job count, keep cores default 0 → all)
sudo nixos-rebuild switch --flake .#hostname --max-jobs 2
```

`--max-jobs`/`-j` is a first-class nixos-rebuild flag. `--cores` is accessible via `--option cores N` (the `--option name value` syntax passes arbitrary nix.conf overrides to the nix daemon for that invocation).

**home-manager** accepts the same Nix common options:

```bash
home-manager switch --flake .#benjamin --max-jobs 4 --option cores 6
```

---

## Decisions

### Recommended Values for `nix.settings`

**Option A — Balanced (recommended for most rebuilds):**

```nix
nix.settings = {
  max-jobs = 4;   # 4 parallel derivations
  cores = 6;      # 6 compiler threads per derivation; 4×6 = 24 total cores
};
```

Rationale: 24 total cores = full CPU utilization. Maximum simultaneous heavy C++ compile units = 4 × 6 = 24 processes. At 1 GB/process (conservative): 24 GB — safe. At 2 GB/process (onnxruntime peak): 48 GB — would OOM. So this configuration is safe for typical packages but may still OOM on onnxruntime specifically.

**Option B — Conservative (recommended for onnxruntime-class packages):**

```nix
nix.settings = {
  max-jobs = 2;   # 2 parallel derivations  
  cores = 6;      # 6 compiler threads per derivation; 2×6 = 12 total
};
```

Rationale: 12 simultaneous compile units at 2 GB = 24 GB — within budget with 2 GB headroom. Build time impact: roughly halved parallelism vs. Option A, but avoids OOM entirely for onnxruntime-class packages. Single-derivation builds (most packages) use 6 cores, completing in reasonable time.

**Option C — For onnxruntime specifically (most conservative):**

Override at CLI rather than configuring globally:

```bash
sudo nixos-rebuild switch --flake .#hostname --max-jobs 1 --option cores 8
```

8 Ninja threads for one derivation at a time = 8 × 2 GB = 16 GB peak, safe even with OS overhead.

**Decision**: Implement Option B (`max-jobs = 2`, `cores = 6`) in `nix.settings` as the permanent baseline. Option C is the `update.sh` override when specifically rebuilding with onnxruntime in the dependency graph.

### Recommended `nix.settings.cores` Value vs. Default

Setting `cores = 0` (default "all cores") combined with `max-jobs = 2` gives: 2 × 24 = 48 simultaneous processes — still too high for onnxruntime. Therefore `cores` must be set explicitly.

Setting `cores = 6` with `max-jobs = 2` gives product 12 — safe. With `max-jobs = 4` gives product 24 — marginal.

### update.sh Override

Add `--max-jobs` to the `nixos-rebuild` and `home-manager` invocations in `update.sh` as a safety net for interactive rebuilds. A value of `2` or `4` here complements the nix.settings baseline:

```bash
# In update.sh — nixos-rebuild line, add -j 4 (or --max-jobs 4):
sudo nixos-rebuild switch --flake .#$HOSTNAME \
  --option allow-import-from-derivation false \
  --max-jobs 4

# home-manager line:
home-manager switch --flake .#benjamin \
  --option allow-import-from-derivation false \
  --max-jobs 4
```

Or for a more conservative override specifically when onnxruntime is in scope, introduce an environment variable check:

```bash
MAX_JOBS="${NIX_MAX_JOBS:-4}"
sudo nixos-rebuild switch --flake .#$HOSTNAME \
  --option allow-import-from-derivation false \
  --max-jobs "$MAX_JOBS"
```

Users can then run `NIX_MAX_JOBS=1 ./update.sh` when doing a full rebuild that includes onnxruntime.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `cores = 6` under-utilizes CPU for lightweight packages | Medium | Lightweight packages build in seconds regardless; build throughput dominates for C++ anyway |
| `max-jobs = 2` slows total rebuild time | Medium | Acceptable — correctness > speed; interactive rebuilds are occasional |
| onnxruntime still OOMs at `max-jobs=2, cores=6` | Low | Override with `--max-jobs 1 --option cores 8` at CLI; earlyoom provides backstop |
| Some packages don't respect NIX_BUILD_CORES | Low | Those packages use 1 thread regardless of setting; no harm |
| Non-determinism from parallel builds | Very Low | Nixpkgs packages are tested with parallelism; caveat applies primarily to custom derivations |
| Lean build interrupted by nix daemon resource grab | None for this change | Settings only take effect after `nixos-rebuild switch`; Lean build is unaffected today |

---

## Appendix

### Search Queries Used

1. "NixOS nix.settings max-jobs cores tuning heavy C++ builds memory 2024 2025"
2. "nixpkgs nix settings max-jobs cores options documentation NixOS"
3. "onnxruntime nixpkgs build memory requirements C++ compile parallel jobs OOM"
4. "nixos-rebuild --max-jobs -j command line syntax update.sh script nix build override"
5. "nix.settings.cores nixos option documentation default description 2024"

### References

- [Tuning Cores and Jobs — Nix Reference Manual (stable)](https://nix.dev/manual/nix/stable/advanced-topics/cores-vs-jobs)
- [nix.settings.max-jobs — MyNixOS](https://mynixos.com/nixpkgs/option/nix.settings.max-jobs)
- [nix.settings.cores — MyNixOS](https://mynixos.com/nixpkgs/option/nix.settings.cores)
- [NixOS Options Search: nix.settings.max-jobs](https://search.nixos.org/options?channel=24.05&show=nix.settings.max-jobs)
- [Concrete suggestions for balancing cores and max-jobs — NixOS Discourse](https://discourse.nixos.org/t/are-there-concrete-suggestions-for-balancing-cores-and-max-jobs/11824)
- [I/O & CPU scheduling, jobs & cores… — NixOS Discourse](https://discourse.nixos.org/t/i-o-cpu-scheduling-jobs-cores-and-performance-baby/66120)
- [Limit CPU usage when building — NixOS Discourse](https://discourse.nixos.org/t/limit-cpu-usage-when-building/61099)
- [onnxruntime build failure — nixpkgs issue #301949](https://github.com/NixOS/nixpkgs/issues/301949)
- [Nix Common Options (--max-jobs, --cores, --option)](https://nix.dev/manual/nix/2.24/command-ref/opt-common)
- [nixos-rebuild man page](https://www.mankier.com/8/nixos-rebuild)

### Existing Configuration Reference

`configuration.nix` lines 734–745: current `nix` block — no `max-jobs` or `cores` set.
`update.sh` lines 36–41: `nixos-rebuild` and `home-manager` invocations — no `-j`/`--max-jobs` present.
`/proc/meminfo`: MemTotal = 32122796 kB (~30.6 GiB), SwapTotal = 32838136 kB.
