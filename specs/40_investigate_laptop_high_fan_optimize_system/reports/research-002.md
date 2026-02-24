# Research Report: Lake Build Optimization for NixOS

- **Task**: 40 - Investigate laptop high fan activity and optimize system
- **Focus**: Lean 4 / Lake build Mathlib compilation optimization
- **Started**: 2026-02-24T12:00:00-08:00
- **Completed**: 2026-02-24T13:00:00-08:00
- **Effort**: 1 hour
- **Dependencies**: Task 39 (memory optimization), research-001.md (power management)
- **Sources/Inputs**:
  - Lean community Zulip archives
  - Phoronix Framework 13 AMD Ryzen AI 300 benchmarks
  - ArchWiki CPU frequency scaling, Ryzen documentation
  - NixOS Discourse cgroups discussions
  - systemd resource control documentation
  - RyzenAdj GitHub repository
- **Artifacts**: specs/40_investigate_laptop_high_fan_optimize_system/reports/research-002.md
- **Standards**: report-format.md, nix.md

## Project Context

- **Upstream Dependencies**: research-001.md findings (PPD conflict, GNOME tracker)
- **Downstream Dependents**: Lean/Mathlib development workflow, system thermal stability
- **Alternative Paths**: Per-job CPU limiting, systemd slices, tmpfs build directories
- **Potential Extensions**: RyzenAdj power limits, custom compilation wrappers

## Executive Summary

- **Lake parallelism is inherently limited**: Mathlib's dependency graph allows only ~18x average parallelism, so limiting to 8-12 jobs is often optimal for thermal/memory balance
- **LEAN_NUM_THREADS environment variable** is the primary mechanism for limiting Lean's thread usage
- **Memory is the bottleneck**: Each Lean compilation job can use significant RAM; with 32GB RAM, 8-12 parallel jobs is a safe upper bound
- **Systemd user slices** can enforce CPU and memory limits for compilation processes
- **Power-profiles-daemon "balanced" mode** is recommended over "performance" for sustained builds to reduce thermal throttling
- **RyzenAdj support exists** for Strix Point but requires careful configuration

## Context and Scope

This research extends research-001.md with specific focus on optimizing Lean 4 / Lake builds of Mathlib. The system:
- **Hardware**: AMD Ryzen AI 9 HX 370 (12 cores: 4P + 8E) on hamsa host
- **RAM**: 32GB with zram (50% = 16GB compressed swap)
- **Current kernel**: linuxPackages_latest with amd_pstate=active
- **Build tool**: Lake (integrated into Lean 4)
- **Project**: Mathlib4 (large mathematical library)

## Findings

### Lake/Lean Build Parallelism

#### LEAN_NUM_THREADS Environment Variable

The primary mechanism for controlling Lean compilation parallelism is the `LEAN_NUM_THREADS` environment variable. As documented in the [Lean community Zulip](https://leanprover-community.github.io/archive/stream/270676-lean4/topic/Lake.20parallel.20builds.html):

> "There isn't a way to do this from Lake, because Lean does not provide an API-based thread control mechanism. However, there is a program-wide limiting mechanism available through LEAN_NUM_THREADS."

**Key insight**: Unlike `make -j`, Lake does not have a native `-j` flag for parallel jobs. Thread control must be managed via environment variables.

#### Parallelism Limits in Mathlib

Analysis of Mathlib's build graph shows:
- Only ~18x average parallelism is possible across the entire project
- On a 56-core system, only ~16x speedup was achieved
- The import dependency structure inherently limits parallelism
- In-file parallelism (future improvement) may help

**Recommendation**: For a 12-core Ryzen AI 9 HX 370, limiting to **8 parallel jobs** provides good throughput while avoiding thermal throttling and memory exhaustion.

#### Memory Considerations

Mathlib compilation is memory-intensive:
- Build appears "I/O-limited rather than CPU limited" due to writing oleans and paging
- Memory-mapped oleans cause memory pressure at high parallelism
- Peak CPU usage reaches 1400%+ during optimal parallelism phases

**For 32GB RAM system**:
- 8 jobs at ~2-3GB per job = 16-24GB RAM usage
- Leaves headroom for system services and zram compression
- Prevents swapping to disk which kills performance

### CPU Scheduling Optimization

#### Power-Profiles-Daemon Integration

For AMD Ryzen AI 300 with `amd_pstate=active`, [power-profiles-daemon](https://wiki.archlinux.org/title/CPU_frequency_scaling) manages the Energy Performance Preference (EPP):

| Profile | EPP Value | Use Case |
|---------|-----------|----------|
| performance | 0x00 (max perf) | Short bursts, benchmarks |
| balanced | 0x80 (middle) | Sustained compilation |
| power-saver | 0xFF (max efficiency) | Battery preservation |

**Recommendation for compilation**: Use **balanced** mode for sustained builds. Performance mode causes higher temperatures and earlier thermal throttling, resulting in slower overall builds.

```bash
# Set balanced mode before compilation
powerprofilesctl set balanced

# Verify
powerprofilesctl get
```

#### Nice and Ionice for Build Processes

For background compilation that shouldn't interfere with desktop responsiveness:

```bash
# Low CPU priority (nice 19) and best-effort I/O (class 2, priority 7)
nice -n 19 ionice -c 2 -n 7 lake build
```

This allows the compilation to use all available resources when idle but yields to interactive processes.

### Systemd Resource Limits

#### User Slice Configuration

NixOS can configure per-user resource limits via systemd slices. From the [NixOS manual](https://nlewo.github.io/nixos-manual-sphinx/administration/control-groups.xml.html):

```nix
# In configuration.nix
systemd.slices."user-1000" = {
  description = "User slice for benjamin";
  sliceConfig = {
    MemoryHigh = "28G";        # Soft limit: 28GB (leaves 4GB for system)
    MemoryMax = "30G";         # Hard limit: 30GB
    CPUQuota = "1000%";        # Allow up to 10 cores (100% per core)
    TasksMax = 2000;           # Max concurrent tasks
  };
};
```

#### Compilation-Specific Wrapper Service

For more granular control, create a systemd service for compilation:

```nix
# In home.nix or configuration.nix
systemd.user.services.lake-build = {
  description = "Lake build with resource limits";
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = false;
    MemoryHigh = "24G";
    CPUQuota = "800%";         # Limit to 8 cores
    Nice = 10;                 # Lower priority
    IOSchedulingClass = "best-effort";
    IOSchedulingPriority = 7;
  };
};
```

### Memory Management Integration

#### Current Configuration (from configuration.nix)

The system already has good memory management foundations:

```nix
# zram (50% of RAM = 16GB compressed)
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 50;
  priority = 5;
};

# VM tuning for desktop responsiveness
boot.kernel.sysctl = {
  "vm.swappiness" = 10;              # Prefer RAM
  "vm.watermark_boost_factor" = 0;
  "vm.watermark_scale_factor" = 125;
  "vm.page-cluster" = 0;             # Disable readahead for zram
};

# earlyoom for OOM prevention
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;
  extraArgs = [
    "--prefer" "^(claude|node|npm)$"
  ];
};
```

#### Compilation Memory Strategy

With this configuration:
1. Normal compilation uses physical RAM
2. Memory pressure triggers zram compression (fast, in-memory)
3. Overflow goes to swapfile (slower, but prevents OOM)
4. earlyoom kills runaway processes at 10% free RAM

**Optimization**: Add `lean` to earlyoom's prefer list to prioritize killing Lean processes over system processes during OOM:

```nix
services.earlyoom.extraArgs = [
  "--prefer" "^(lean|lake|claude|node|npm)$"
];
```

### I/O Optimization

#### Tmpfs for Build Artifacts

While [tmpfs can speed up builds](https://wiki.gentoo.org/wiki/Portage_TMPDIR_on_tmpfs), modern kernels with sufficient RAM already cache build directories:

> "Building packages in tmpfs is unlikely to provide any benefit on a modern system, as if there is sufficient RAM to build in tmpfs the kernel caching will do it anyway."

**However**, for Mathlib's large `.lake/build` directory, explicit tmpfs can help avoid disk writes:

```bash
# Create tmpfs mount for .lake directory (use with caution - data lost on reboot)
mkdir -p /tmp/lake-build
mount -t tmpfs -o size=16G,noatime tmpfs /tmp/lake-build
ln -s /tmp/lake-build ~/.elan/toolchains/leanprover--lean4---v4.x.0/.lake
```

**Warning**: This loses build artifacts on reboot. Use only for experimentation.

### Thermal/Power Tradeoffs

#### AMD Ryzen AI 300 Thermal Characteristics

From [Phoronix Framework 13 benchmarks](https://www.phoronix.com/review/framework-13-ryzen-ai-power):
- Framework 13 AMD stays around 65-70C during sustained compilation
- Ryzen AI 9 HX 370 maintains 25-35W sustained under compilation
- Outperforms Intel 8-core by 30-40% in all-core workloads

#### RyzenAdj Power Tuning

[RyzenAdj](https://github.com/FlyGoat/RyzenAdj) supports Strix Point (Ryzen AI 300) for power limit adjustment:

```bash
# Install on NixOS (not in nixpkgs, requires manual build)
# Set sustained power limit to 35W (reduces heat while maintaining throughput)
sudo ryzenadj --stapm-limit=35000 --fast-limit=45000 --slow-limit=35000
```

**Power limit recommendations for compilation**:

| PPT (mW) | Thermal Impact | Build Speed Impact |
|----------|----------------|-------------------|
| 28000 | Cool, quiet | ~85% throughput |
| 35000 | Balanced | ~95% throughput |
| 45000 | Hot, loud | 100% throughput |
| 54000+ | Very hot | Thermal throttling likely |

**NixOS integration** (requires overlay):
```nix
# Example wrapper script
environment.systemPackages = [
  (pkgs.writeShellScriptBin "lake-cool" ''
    # Set conservative power limits before build
    sudo ${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=35000
    LEAN_NUM_THREADS=8 nice -n 10 lake "$@"
  '')
];
```

#### Power Profile Switching for Compilation

Create a wrapper that sets optimal power profile:

```bash
#!/usr/bin/env bash
# ~/.local/bin/lake-build
set -e

# Switch to balanced mode for sustained compilation
powerprofilesctl set balanced

# Set thread limit and nice level
export LEAN_NUM_THREADS=8
nice -n 10 lake "$@"
```

## Recommendations

### Priority 1: Environment Variable Configuration

Add to shell configuration (fish/bash):

```fish
# In ~/.config/fish/config.fish
set -gx LEAN_NUM_THREADS 8  # Optimal for 12-core with thermal headroom
```

Or in NixOS home.nix:
```nix
home.sessionVariables = {
  LEAN_NUM_THREADS = "8";
};
```

### Priority 2: earlyoom Configuration Update

Update earlyoom to prefer killing Lean processes:

```nix
services.earlyoom.extraArgs = [
  "--avoid" "^(gnome-shell|Xwayland|niri)$"
  "--prefer" "^(lean|lake|claude|node|npm)$"
];
```

### Priority 3: Lake Build Wrapper Script

Create a convenient wrapper:

```nix
# In environment.systemPackages
(pkgs.writeShellScriptBin "lake-opt" ''
  #!/usr/bin/env bash
  # Optimized lake build for sustained compilation

  # Use balanced power profile
  ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced

  # Set conservative parallelism
  export LEAN_NUM_THREADS=''${LEAN_NUM_THREADS:-8}

  # Run with lower priority
  exec nice -n 10 ionice -c 2 -n 7 ${pkgs.elan}/bin/lake "$@"
'')
```

### Priority 4: Power-Profiles-Daemon Scripting

For automated profile switching:

```bash
# Before starting large compilation
powerprofilesctl set balanced

# After completion (optional, restore performance)
powerprofilesctl set performance
```

### Priority 5: Monitor During Builds

Use these commands to monitor thermal and memory behavior:

```bash
# Temperature monitoring
watch -n1 sensors

# CPU frequency and power state
watch -n1 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | sort -u"

# Memory usage
watch -n1 free -h

# Cgroup usage
systemd-cgtop
```

## Configuration Summary

### Recommended Settings for Mathlib Compilation

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| LEAN_NUM_THREADS | 8 | Balance parallelism with thermal/memory headroom |
| Power profile | balanced | Sustained throughput without thermal throttling |
| Nice level | 10 | Lower priority for background compilation |
| earlyoom prefer | lean,lake | OOM kill compilation before system services |

### Shell Environment (fish)

```fish
# ~/.config/fish/config.fish additions
set -gx LEAN_NUM_THREADS 8

# Alias for optimized builds
alias lake-build "powerprofilesctl set balanced && nice -n 10 lake build"
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Low LEAN_NUM_THREADS slows builds | Medium | 8 threads still provides good throughput |
| Balanced mode reduces peak performance | Low | Sustained builds actually complete faster |
| earlyoom kills Lean during memory spike | Medium | Set prefer pattern carefully, monitor |
| RyzenAdj unavailable in nixpkgs | Low | Power-profiles-daemon provides sufficient control |
| Tmpfs data loss | High | Only use for experimentation, not production |

## Appendix

### References

- [Lean Community - Lake Parallel Builds](https://leanprover-community.github.io/archive/stream/270676-lean4/topic/Lake.20parallel.20builds.html)
- [Phoronix - Framework 13 Ryzen AI 300 Power Tuning](https://www.phoronix.com/review/framework-13-ryzen-ai-power)
- [ArchWiki - CPU Frequency Scaling](https://wiki.archlinux.org/title/CPU_frequency_scaling)
- [ArchWiki - Ryzen](https://wiki.archlinux.org/title/Ryzen)
- [NixOS Manual - Control Groups](https://nlewo.github.io/nixos-manual-sphinx/administration/control-groups.xml.html)
- [NixOS Discourse - Managing Nix Build Resources](https://discourse.nixos.org/t/managing-nix-build-resources-with-cgroups/7870)
- [RyzenAdj GitHub](https://github.com/FlyGoat/RyzenAdj)
- [Power Profiles Daemon 0.22 AMD Improvements](https://www.phoronix.com/news/Power-Profiles-Daemon-0.22)
- [Gentoo Wiki - Portage TMPDIR on tmpfs](https://wiki.gentoo.org/wiki/Portage_TMPDIR_on_tmpfs)
- [systemd.resource-control](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)

### Verification Commands

```bash
# Check current LEAN_NUM_THREADS
echo $LEAN_NUM_THREADS

# Verify power profile
powerprofilesctl get

# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Monitor during build
htop --sort-key=PERCENT_CPU
watch -n1 sensors
systemd-cgtop
```

### Integration with research-001.md

This research builds on research-001.md findings:
1. **Remove cpuFreqGovernor conflict** (research-001.md Priority 1) - Required for PPD to work properly
2. **Disable GNOME tracker** (research-001.md Priority 2) - Reduces background CPU competition
3. **Add LEAN_NUM_THREADS** (this research Priority 1) - Limits compilation parallelism
4. **Update earlyoom** (this research Priority 2) - Improves OOM behavior for Lean

Both reports should be implemented together for optimal results.
