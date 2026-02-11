# Research Report: Task #25 - Learning from Memory Monitoring Implementation

- **Task**: 25 - Configure swap space in NixOS configuration
- **Started**: 2026-02-11T20:45:00Z
- **Completed**: 2026-02-11T21:00:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 26 (completed)
- **Sources/Inputs**:
  - Task 26 implementation plan (specs/archive/26_memory_monitoring_systemd_services_nixos/plans/implementation-001.md)
  - System logs (journalctl -u earlyoom, journalctl -u systemd-oomd)
  - Memory monitor logs (~/.local/share/memory-monitor/system.log, claude.csv)
  - Current NixOS configuration (configuration.nix, home.nix)
- **Artifacts**: specs/25_configure_swap_space_nixos/reports/research-002.md
- **Standards**: report-format.md, nix.md

## Executive Summary

- **Task 26 memory monitoring is fully operational**: earlyoom, memory-monitor, and claude-memory-tracker are all running and logging data
- **Critical finding**: systemd-oomd explicitly warns "No swap; memory pressure usage will be degraded" - swap is needed for proper memory pressure tracking
- **Memory usage stable**: Current memory usage ranges 40-58%, with no high-memory events (>80%) recorded in logs
- **Claude process tracking effective**: Peak Claude process usage 793MB, average 557MB per process - well within normal limits
- **No OOM kills observed**: Neither earlyoom nor kernel OOM killer has terminated processes in the past week
- **Recommendation**: The existing implementation plan for task 25 remains valid; swap will enhance systemd-oomd effectiveness and provide better memory pressure visibility

## Context & Scope

This additional research examines what can be learned from the Task 26 memory monitoring implementation to inform or potentially revise the swap configuration approach for Task 25. The focus areas are:

1. Effectiveness of current memory monitoring logging
2. Whether swap would improve monitoring visibility
3. Interaction between swap and existing memory management (earlyoom, systemd-oomd)
4. Whether the implementation plan needs revision

## Findings

### Current Memory Monitoring Status

**All three tiers of memory monitoring from Task 26 are operational:**

| Tier | Service | Status | Purpose |
|------|---------|--------|---------|
| 1 | earlyoom | Active (21+ hours) | System-level OOM prevention at 10% free RAM |
| 2 | memory-monitor | Active (21+ hours) | User-level logging (every 30s) + desktop alerts at 80%/90% |
| 3 | claude-memory-tracker | Active (21+ hours) | Claude process-specific tracking (every 60s) |

**Log data volume:**
- system.log: 685 entries (~21 hours of 30-second samples)
- claude.csv: 4,756 entries (multiple Claude processes tracked per sample)

### Memory Usage Patterns

**System memory distribution from logs:**

| Memory Usage | Occurrences | Percentage of Samples |
|--------------|-------------|----------------------|
| 40-50% | 308 | 45% |
| 50-60% | 377 | 55% |
| >60% | 0 | 0% |
| >80% (warning) | 0 | 0% |

**Claude process memory:**
- Peak RSS: 793 MB (single process)
- Average RSS: 557 MB (per process)
- Multiple Claude processes typically running concurrently (4-5 visible in logs)
- Total Claude footprint: ~2-3 GB across all processes

**Current memory state:**
- Total RAM: 30 GiB
- Used: 17 GiB (57%)
- Available: 12 GiB
- Swap: 0 (none configured)

### systemd-oomd Warning

**Critical observation from system logs:**

```
Feb 05 12:49:26 hamsa systemd-oomd[850]: No swap; memory pressure usage will be degraded
Feb 05 18:55:58 hamsa systemd-oomd[870]: No swap; memory pressure usage will be degraded
```

**Implications:**
- systemd-oomd uses memory pressure (PSI - Pressure Stall Information) for intelligent OOM prevention
- Without swap, the kernel cannot move inactive pages to disk, reducing PSI granularity
- This means systemd-oomd has less time to react between "some pressure" and "critical pressure"
- Swap provides a "buffer zone" that allows PSI metrics to give earlier warning

### earlyoom Behavior

**earlyoom configuration in configuration.nix:**
```nix
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;         # Kill at 10% free RAM
  freeSwapThreshold = 10;        # Also monitor swap
  enableNotifications = true;
  extraArgs = [
    "--avoid" "^(gnome-shell|Xwayland|niri)$"
    "--prefer" "^(claude|node|npm)$"
  ];
};
```

**Current earlyoom output shows:**
```
mem total: 31373 MiB, user mem total: 26759 MiB, swap total: 0 MiB
```

**Key insight**: earlyoom is already configured to monitor swap threshold (10%), but reports 0 MiB swap. Adding swap will make this threshold meaningful and provide an additional protection layer before earlyoom needs to intervene.

### No OOM Events Observed

**Review of system logs (past 7 days):**
- No earlyoom kills (no SIGTERM/SIGKILL events)
- No kernel OOM killer invocations (only disable/enable cycles during suspend/resume)
- No memory-monitor warnings or critical notifications triggered

**Interpretation:**
- The system has not experienced memory exhaustion in the observation period
- Current ~40-58% memory usage provides adequate headroom
- However, this doesn't mean swap is unnecessary - memory spikes can occur during heavy workloads

### Logging Adequacy Assessment

**Current logging is adequate for:**
- Basic memory usage trends (30-second samples)
- Claude process memory tracking (60-second samples, with PID, RSS, VSZ)
- Threshold-based alerting (80% warning, 90% critical)

**Potential improvements identified (not blocking for task 25):**
1. **No memory spike capture**: Current logs only show point-in-time samples; brief spikes between samples are invisible
2. **No swap usage tracking**: swap=0% logged every sample (will become meaningful after swap is added)
3. **No pressure metrics**: PSI (Pressure Stall Information) not logged - would show memory contention even when usage appears normal
4. **Log rotation**: claude.csv at 265KB after 21 hours - rotation at 10MB configured but not yet triggered

### Swap Interaction Analysis

**How swap will integrate with existing monitoring:**

| Component | Without Swap | With Swap |
|-----------|--------------|-----------|
| earlyoom | Only monitors RAM | Monitors RAM + swap, intervenes when both at 90% |
| systemd-oomd | Degraded PSI monitoring | Full PSI monitoring with swap-backed pressure metrics |
| memory-monitor | swap=0% logged | Will log actual swap usage percentage |
| Kernel | Must kill processes immediately when RAM exhausted | Can page out inactive memory, providing grace period |

### Implementation Plan Review

**The existing implementation plan (implementation-001.md) remains valid:**
- 16GB swap file at `/var/lib/swapfile`
- SSD TRIM optimization with `discardPolicy = "once"`
- Three-phase implementation (add config, verify build, activate and test)

**No revisions needed based on this research. The plan correctly:**
- Places swap in `configuration.nix` (shared across all hosts with 32GB RAM)
- Documents the three-tier memory management approach
- Includes verification steps for earlyoom swap detection

**One minor enhancement to consider (optional):**
After swap is implemented, verify that systemd-oomd no longer logs the "memory pressure usage will be degraded" warning.

## Decisions

1. **Keep existing implementation plan**: No revision needed - the plan is well-designed and aligns with monitoring findings
2. **Swap enhances monitoring**: Adding swap will make existing monitoring more effective (PSI metrics, swap threshold in earlyoom)
3. **Current logging is sufficient**: No need to modify memory-monitor scripts before implementing swap
4. **Verification enhancement**: Add a check for systemd-oomd healthy status after swap activation

## Recommendations

1. **Proceed with implementation-001.md as planned**
   - The 16GB swap file approach is appropriate for the system configuration
   - No changes needed to the existing plan

2. **Add post-implementation verification step**
   - After `nixos-rebuild switch`, check: `journalctl -u systemd-oomd | grep -i swap`
   - Confirm no more "No swap; memory pressure usage will be degraded" warnings

3. **Monitor swap effectiveness after implementation**
   - The existing memory-monitor logs will automatically capture swap usage
   - Watch for swap usage patterns during heavy Claude sessions

4. **Future enhancement (not blocking)**
   - Consider adding PSI metrics logging to memory-monitor script
   - Path: `/proc/pressure/memory` contains pressure statistics

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Swap causes unexpected behavior | Low | Medium | Rollback by setting `swapDevices = []` and rebuilding |
| Swap thrashing under heavy load | Low | Low | earlyoom will intervene before severe thrashing; zram can be added later if needed |
| Log file growth with swap activity | Low | Low | Existing 10MB rotation already configured in claude-memory-tracker |

## Appendix

### Commands Used for Analysis

```bash
# Check service status
systemctl --user status memory-monitor
systemctl --user status claude-memory-tracker
systemctl status earlyoom
systemctl status systemd-oomd

# Analyze memory logs
tail -50 ~/.local/share/memory-monitor/system.log
tail -20 ~/.local/share/memory-monitor/claude.csv

# Check for high memory events
grep -E "mem=(8[0-9]|9[0-9]|100)%" ~/.local/share/memory-monitor/system.log

# Check for OOM events
journalctl -u earlyoom --since "7 days ago" | grep -i "kill\|sigterm\|sigkill"
journalctl -u systemd-oomd --since "7 days ago"
journalctl --since "7 days ago" | grep -i "oom\|out of memory"

# Memory statistics
free -h
swapon --show
cat /proc/sys/vm/swappiness  # Default: 60
```

### Key Log Excerpts

**systemd-oomd swap warning:**
```
Feb 05 12:49:26 hamsa systemd-oomd[850]: No swap; memory pressure usage will be degraded
Feb 05 18:55:58 hamsa systemd-oomd[870]: No swap; memory pressure usage will be degraded
```

**earlyoom initialization (showing 0 swap):**
```
Feb 10 15:45:40 hamsa earlyoom[1856798]: mem total: 31373 MiB, user mem total: 26759 MiB, swap total: 0 MiB
Feb 10 15:45:40 hamsa earlyoom[1856798]: sending SIGTERM when mem avail <= 10.00% and swap free <= 10.00%
```

### References

- Task 26 implementation plan: `specs/archive/26_memory_monitoring_systemd_services_nixos/plans/implementation-001.md`
- Task 25 implementation plan: `specs/25_configure_swap_space_nixos/plans/implementation-001.md`
- Research-001: `specs/25_configure_swap_space_nixos/reports/research-001.md`
- systemd-oomd documentation: https://www.freedesktop.org/software/systemd/man/systemd-oomd.html
- Linux PSI documentation: https://docs.kernel.org/accounting/psi.html
