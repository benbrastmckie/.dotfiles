# Research Report: Memory Log Analysis and System Optimization

- **Task**: 39 - Analyze memory logs and optimize system robustness
- **Started**: 2026-02-22T14:00:00-08:00
- **Completed**: 2026-02-22T14:45:00-08:00
- **Effort**: 45 minutes
- **Dependencies**: None (existing memory monitoring infrastructure)
- **Sources/Inputs**:
  - `~/.local/share/memory-monitor/system.log` (123MB, 7.2M entries)
  - `~/.local/share/memory-monitor/claude.csv` (42MB, 1.2M entries)
  - `/home/benjamin/.dotfiles/configuration.nix` (earlyoom, swap config)
  - `/home/benjamin/.dotfiles/home.nix` (memory-monitor, claude-memory-tracker)
  - NixOS Wiki, NixOS Discourse, nixpkgs source
- **Artifacts**: specs/39_analyze_memory_logs_optimize_system/reports/research-001.md
- **Standards**: report-format.md

## Project Context

- **Upstream Dependencies**: earlyoom, systemd-oomd, swap configuration in configuration.nix
- **Downstream Dependents**: System stability, desktop responsiveness
- **Alternative Paths**: zram swap compression, cgroup memory limits
- **Potential Extensions**: Per-application memory limits, automated log analysis

## Executive Summary

- System has 32GB RAM with 16GB swap file, averaging 54% memory usage over 12 days of logging
- Peak memory usage reached 86% on Feb 12, triggering swap to 72% utilization
- Two OOM killers are running concurrently (earlyoom + systemd-oomd), which is suboptimal
- Claude processes average 138MB RSS but can spike to 1.4GB per instance
- Default vm.swappiness=60 is higher than recommended for desktop systems
- zram is not enabled; enabling it would provide faster swap with compression

## Context and Scope

The system has a three-tier memory monitoring setup implemented in task 26:
1. **Tier 1**: earlyoom - system-level OOM prevention (10% free memory threshold)
2. **Tier 2**: memory-monitor - user-level logging and desktop alerts (80%/90% thresholds)
3. **Tier 3**: claude-memory-tracker - process-specific tracking for Claude

This research analyzes 12 days of logs (Feb 10-22, 2026) to understand memory patterns and identify optimization opportunities.

## Findings

### System Specifications
- **Total RAM**: 32GB (32,126,700 KB)
- **Swap**: 16GB file at `/var/lib/swapfile` (priority -2)
- **Current vm.swappiness**: 60 (kernel default)
- **Current vm.dirty_ratio**: 20
- **Current vm.dirty_background_ratio**: 10

### Memory Usage Statistics
| Metric | Value |
|--------|-------|
| Minimum | 0% (after process kills) |
| Maximum | 86% (Feb 12, 11:05) |
| Average | 53.8% |
| Samples | ~7.2 million (30-second intervals) |

### Daily Peak Analysis
| Date | Max Mem | Max Swap | Notes |
|------|---------|----------|-------|
| 2026-02-11 | 66% | 0% | Normal usage |
| 2026-02-12 | 86% | 72% | **Critical event** |
| 2026-02-13 | 80% | 64% | High pressure |
| 2026-02-16 | 58% | 32% | Light usage |
| 2026-02-17 | 66% | 25% | Normal usage |
| 2026-02-18 | 68% | 59% | Moderate pressure |
| 2026-02-19 | 60% | 60% | Swap persisted |
| 2026-02-20 | 69% | 32% | Elevated |
| 2026-02-21 | 64% | 30% | Normal |

### Critical Event Analysis (Feb 12, 11:05)
```
2026-02-12T11:04:34 mem=60%, swap=25%  <- Before
2026-02-12T11:05:04 mem=86%, swap=60%  <- Spike (+26% mem, +35% swap)
2026-02-12T11:05:34 mem=25%, swap=72%  <- After OOM kill
```

The rapid jump from 60% to 86% memory suggests a sudden allocation spike. The immediate drop to 25% indicates earlyoom intervened and killed a process. Multiple Claude processes were active at this time (5 instances detected).

### Claude Process Memory Analysis
- **Total samples**: 1.2 million process entries
- **Average RSS (overall)**: 138MB
- **Average RSS (>500MB instances)**: 609MB
- **Maximum RSS observed**: 1,395MB (1.4GB) on Feb 13

Claude processes frequently run in parallel (up to 5+ instances observed), which can collectively consume 3-7GB of RAM during heavy usage.

### OOM Killer Configuration Issues
**Current state**: Both earlyoom AND systemd-oomd are running.

```bash
$ systemctl status systemd-oomd
● systemd-oomd.service - Userspace Out-Of-Memory (OOM) Killer
     Active: active (running) since Feb 05
```

This is problematic because:
1. Running two userspace OOM killers concurrently is counterproductive
2. They may conflict in their decisions about which process to kill
3. systemd-oomd uses PSI (Pressure Stall Information) which is more efficient than earlyoom's polling

NixOS 24.05+ enables systemd-oomd by default alongside MGLRU (kernel OOM). The recommendation from the community is to disable systemd-oomd when using earlyoom, or vice versa.

### Missing Optimizations

1. **No zram enabled**: The system uses a swap file but not zram. zram provides:
   - Faster swap operations (in-memory, compressed)
   - Reduced SSD wear
   - Effective RAM expansion through compression (typically 2-3x ratio with zstd)

2. **High vm.swappiness**: Default 60 causes premature swapping on systems with ample RAM. Desktop systems typically benefit from lower values (10-30).

3. **No per-application memory limits**: Heavy processes (Claude, browsers) run without cgroup constraints.

## Decisions

1. **Recommend disabling systemd-oomd** since earlyoom is already configured and preferred (it has explicit avoid/prefer rules for this system)

2. **Recommend enabling zram** as primary swap with the existing 16GB swap file as fallback

3. **Recommend lowering vm.swappiness** to 10-30 for desktop responsiveness

## Recommendations

### Priority 1: Resolve OOM Killer Conflict
```nix
# In configuration.nix
systemd.oomd.enable = false;  # Disable systemd-oomd, keep earlyoom
```

### Priority 2: Enable zram Swap
```nix
# In configuration.nix
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 50;  # Use up to 50% of RAM (16GB) for compressed swap
  priority = 5;        # Higher than swap file (-2)
};
```

This creates ~16GB of compressed swap space with zstd compression, which effectively provides 32-48GB of virtual swap capacity while being much faster than disk.

### Priority 3: Tune vm.swappiness
```nix
# In configuration.nix
boot.kernel.sysctl = {
  "vm.swappiness" = 10;  # Prefer keeping pages in RAM
  "vm.watermark_boost_factor" = 0;  # Disable watermark boosting (recommended with zram)
  "vm.watermark_scale_factor" = 125;  # Better memory reclaim with zram
  "vm.page-cluster" = 0;  # Disable readahead for zram (not beneficial for RAM-backed swap)
};
```

### Priority 4: Consider Claude Memory Limits (Optional)
For systemd user services, you could limit Claude's memory consumption:
```nix
# In home.nix - example of memory limits for a user service
systemd.user.services.claude-code = {
  # ... existing config ...
  Service = {
    MemoryHigh = "8G";  # Soft limit - starts throttling
    MemoryMax = "12G";  # Hard limit - kills if exceeded
  };
};
```

Note: This would require wrapping Claude Code in a systemd service, which may not be practical for interactive use.

### Priority 5: Improve Log Management
The memory monitor logs are growing large (123MB system.log). Consider:
- Reducing check interval from 30s to 60s for less critical monitoring
- Implementing date-based log rotation instead of size-based
- Adding log compression for older entries

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| zram CPU overhead | Low | zstd is optimized; modern CPUs handle compression easily |
| Lower swappiness causing OOM | Medium | earlyoom will still intervene at 10% free |
| Disabling systemd-oomd | Low | earlyoom provides equivalent protection |
| Memory limits killing Claude | Medium | Set limits high enough for normal operation |

## Appendix

### References
- [NixOS Wiki - Swap](https://wiki.nixos.org/wiki/Swap)
- [NixOS Discourse - zram configuration](https://discourse.nixos.org/t/configuring-zram-and-zswap-parameters-for-optimal-performance/47852)
- [nixpkgs zram.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/zram.nix)
- [earlyoom GitHub](https://github.com/rfjakob/earlyoom)
- [NixOS Issues - systemd-oomd vs MGLRU](https://github.com/NixOS/nixpkgs/issues/338175)
- [Linux Kernel - VM Tuning](https://docs.kernel.org/admin-guide/sysctl/vm.html)

### Verification Commands
```bash
# Check current swap
swapon --show
free -h

# Check vm settings
sysctl vm.swappiness vm.dirty_ratio vm.dirty_background_ratio

# Check OOM killers
systemctl status earlyoom
systemctl status systemd-oomd

# Check zram after enabling
zramctl

# Monitor memory pressure
cat /proc/pressure/memory
```

### Implementation Configuration Block
Complete recommended configuration addition for configuration.nix:
```nix
# ==========================================================================
# Memory Optimization - zram and sysctl tuning
# ==========================================================================
# Complements existing earlyoom and swap configuration.
# See: specs/39_analyze_memory_logs_optimize_system
# ==========================================================================

# Disable systemd-oomd since we use earlyoom
systemd.oomd.enable = false;

# Enable zram compressed swap (higher priority than swap file)
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 50;
  priority = 5;
};

# Tune virtual memory for desktop responsiveness with zram
boot.kernel.sysctl = {
  "vm.swappiness" = 10;
  "vm.watermark_boost_factor" = 0;
  "vm.watermark_scale_factor" = 125;
  "vm.page-cluster" = 0;
};
```
