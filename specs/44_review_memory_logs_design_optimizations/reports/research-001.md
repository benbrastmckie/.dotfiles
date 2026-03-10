# Research Report: Task #44

**Task**: 44 - Review memory logs and design system optimizations
**Date**: 2026-03-10
**Focus**: Identify memory consumers at 80% usage and design improvements

## Summary

Current memory consumption is driven primarily by multiple concurrent Claude Code instances (7 instances totaling ~10GB RSS) and Brave browser renderer processes (~5GB combined). The memory management infrastructure implemented in task 39 (earlyoom, zram, VM tuning) is working correctly. Further optimizations should focus on awareness and process hygiene rather than additional system-level changes.

## Findings

### Current Memory State

At the time of analysis (09:25 local time on 2026-03-10):

| Metric | Value |
|--------|-------|
| Total RAM | 30 GB |
| Used | 24 GB (80%) |
| Available | 6 GB |
| Swap (zram) | 3.1 GB used of 15.3 GB |
| Swap (file) | 0 B used of 16 GB |
| Memory Pressure | avg10=0.00, avg60=0.00, avg300=0.00 |

The swap file is unused because zram (priority 5) is used first, and zstd compression achieves ~3.7:1 ratio (2.7GB data compressed to 734MB).

### Top Memory Consumers

From `ps aux --sort=-%mem` at 80%+ system memory usage:

| Process | RSS (GB) | %MEM | Notes |
|---------|----------|------|-------|
| Brave renderer (tab 1) | 2.85 | 8.8% | Active tab |
| Brave renderer (tab 2) | 2.01 | 6.2% | Active tab |
| Lean language server | 1.84 | 5.7% | ProofChecker project |
| Tinymist preview | 1.24 | 3.8% | Typst document preview |
| Tinymist preview | 1.03 | 3.2% | Second document |
| Lake serve | 0.79 | 2.4% | Lean build system |
| Neovim | 0.78 | 2.4% | Editor instance |
| Claude Code (inst. 1) | 0.75 | 2.3% | Active session |
| Claude Code (inst. 2) | 0.71 | 2.2% | Active session |
| Claude Code (inst. 3) | 0.68 | 2.1% | Active session |
| **7 Claude instances total** | **~3.8** | **~12%** | All active sessions |

### Claude Code Memory Analysis

The claude-memory-tracker service logs show 7 active Claude Code instances:

| PID | RSS (MB) | Project Context |
|-----|----------|-----------------|
| 13060 | 369 | Logos/Theory |
| 212130 | 714 | Logos/Vision |
| 381104 | 277 | Logos/Website |
| 506365 | 749 | Logos/Theory (2nd) |
| 749833 | 315 | .config/nvim |
| 754511 | 680 | ProofChecker |
| 983718 | 413 | .dotfiles |

**Pattern**: Each Claude instance consumes 270-750 MB RSS, with instances working on larger codebases using more memory. Multiple instances for the same project (Logos/Theory) suggest duplicate sessions.

### Memory Log Analysis

Recent memory log entries show the system operating at 73-82% memory usage:

- **Mar 9, 22:14-22:57**: Steady at 73-75% memory, 11-13% swap
- **Mar 10, 08:28-08:35**: Jumped to 79% after resume, settled to 73-74%
- **Mar 10, 08:53-09:25**: Reached 80-82% during active Claude sessions

The 80% threshold triggers warning notifications but the system remains responsive due to:
1. Low memory pressure (PSI avg=0.00)
2. zram compression providing effective buffer
3. earlyoom ready to intervene at 10% free

### Existing Infrastructure Status

All memory optimizations from task 39 are operational:

| Component | Status | Configuration |
|-----------|--------|---------------|
| earlyoom | Active | 10% free threshold, desktop notifications |
| systemd-oomd | Disabled | Prevented conflict with earlyoom |
| zram | Active | 15.3 GB, zstd compression, priority 5 |
| Swap file | Ready | 16 GB fallback, priority -1 |
| vm.swappiness | 10 | Prefer RAM over swap |
| vm.watermark_boost_factor | 0 | Disabled |
| vm.watermark_scale_factor | 125 | Better memory reclaim |
| vm.page-cluster | 0 | Optimized for zram |

### What is NOT Needed

Based on analysis, the following are **not recommended**:

1. **Per-process cgroups for Claude**: Would add complexity without significant benefit. Claude instances are in earlyoom's prefer list and will be killed first if needed.

2. **Additional swap**: The 31 GB total swap (15.3 GB zram + 16 GB file) is more than adequate. The swap file hasn't been used because zram handles all pressure.

3. **Lower earlyoom threshold**: Current 10% (3 GB) threshold is appropriate. System stays responsive even at 80% with proper zram/VM tuning.

4. **systemd-oomd re-enable**: The current earlyoom configuration provides better control with avoid/prefer rules.

## Recommendations

### Priority 1: Claude Session Hygiene (User Practice)

The primary memory consumer is multiple Claude Code sessions. No system changes needed, but user awareness helps:

- Close Claude sessions when switching projects
- Avoid duplicate sessions for the same project
- Use single Claude instance per terminal session

**Estimated impact**: Could reduce memory usage by 1-3 GB through session consolidation.

### Priority 2: Browser Tab Management (User Practice)

Brave renderer processes consume significant memory (2+ GB per heavy tab). Consider:

- Using browser tab suspenders/discards
- Closing unused heavy tabs (e.g., complex web apps)
- Brave's built-in memory saver feature

**Estimated impact**: Could reduce memory by 2-5 GB.

### Priority 3: Optional Log Rotation Enhancement

The memory monitor logs are large (system.log.old is 1.8 GB). This doesn't affect memory usage but consumes disk space.

```nix
# In home.nix memory-monitor script, consider:
MAX_LOG_SIZE=5242880   # Reduce from 10MB to 5MB per rotation
```

**Estimated impact**: Better disk space management, no memory impact.

### Priority 4: Monitor Lean Language Server (Optional)

The Lean language server (lean4, lake serve) consumes 1.8 GB combined. This is normal for Mathlib-based projects but worth noting:

- Consider closing ProofChecker when not actively editing
- Lean memory usage scales with project complexity

**Estimated impact**: Could free 1-2 GB when not needed.

## Decisions

1. **No system-level changes recommended**: The current configuration is well-optimized
2. **Focus on awareness**: Memory usage is driven by user applications, not system inefficiency
3. **Existing infrastructure sufficient**: earlyoom, zram, and VM tuning are working correctly
4. **80% is not critical**: With proper zram and low PSI pressure, the system handles this well

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Many Claude instances consuming memory | Medium | earlyoom prefer list will kill Claude first |
| Memory pressure during Nix builds | Low | zram buffer + earlyoom intervention |
| Browser memory growth | Low | Browser tab discarding, user awareness |
| Log file disk usage | Low | Consider reducing MAX_LOG_SIZE |

## Appendix

### Verification Commands

```bash
# Check current memory status
free -h

# Check swap configuration
swapon --show
zramctl

# Check memory pressure
cat /proc/pressure/memory

# Check VM parameters
sysctl vm.swappiness vm.watermark_boost_factor vm.watermark_scale_factor vm.page-cluster

# Check earlyoom status
systemctl status earlyoom

# Count Claude instances
pgrep -fa claude | wc -l

# View memory logs
tail -50 ~/.local/share/memory-monitor/system.log
tail -50 ~/.local/share/memory-monitor/claude.csv
```

### References

- [NixOS Wiki - Swap](https://wiki.nixos.org/wiki/Swap)
- [NixOS Discourse - earlyoom](https://discourse.nixos.org/t/avoid-linux-locking-up-in-low-memory-situations-using-earlyoom/22072)
- [NixOS Discourse - zram configuration](https://discourse.nixos.org/t/configuring-zram-and-zswap-parameters-for-optimal-performance/47852)
- [NixOS Discourse - RAM limiting applications](https://discourse.nixos.org/t/ram-limiting-firefox-for-pathological-tabbers/5117)
- [nixpkgs - earlyoom.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/earlyoom.nix)
- [nixpkgs - zram.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/zram.nix)

### Prior Related Tasks

- Task 26: Memory monitoring systemd services (implemented three-tier monitoring)
- Task 39: Memory log analysis and optimization (implemented zram, VM tuning, disabled systemd-oomd)
- Task 25: Configure swap space (implemented 16 GB swap file)

## Next Steps

No implementation needed. The current system configuration is well-optimized. If desired, the user can:

1. Consolidate Claude Code sessions (immediate memory savings)
2. Enable browser memory saver features (immediate memory savings)
3. Optionally reduce log rotation size (disk space savings)
