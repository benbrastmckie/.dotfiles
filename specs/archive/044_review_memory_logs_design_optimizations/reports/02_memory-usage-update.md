# Research Report: Updated Memory Log Review and System Optimization Assessment

- **Task**: 44 - Review memory logs and design system optimizations
- **Started**: 2026-05-14T13:30:00Z
- **Completed**: 2026-05-14T14:10:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `specs/44_review_memory_logs_design_optimizations/reports/research-001.md` (prior research, 2026-03-10)
  - `~/.local/share/memory-monitor/system.log`
  - `~/.local/share/memory-monitor/claude.csv`
  - `free -h`, `/proc/meminfo`, `/proc/pressure/memory`
  - `ps aux --sort=-%mem`
  - `configuration.nix` memory-related sections
  - `systemctl status` for earlyoom, memory-monitor, claude-memory-tracker
- **Artifacts**: `specs/044_review_memory_logs_design_optimizations/reports/02_memory-usage-update.md`
- **Standards**: report-format.md, status-markers.md, artifact-management.md

## Project Context

- **Upstream Dependencies**: Task 39 (memory log analysis and optimization), Task 26 (memory monitoring systemd services), Task 25 (swap space configuration)
- **Downstream Dependents**: None directly; informs user practices for memory management
- **Alternative Paths**: None identified
- **Potential Extensions**: Opencode instance hygiene, automated memory pressure response

## Executive Summary

- **Memory usage has improved dramatically** since March 2026: current usage is ~51% (15 GB used of 30 GB) versus 80% (24 GB used) at the time of the previous research.
- **Claude instance count dropped from 7 to 2**, reflecting improved session hygiene; total Claude RSS is now ~1.0 GB versus ~3.8 GB in March.
- **New memory consumer identified: OpenCode** (3 instances, ~1.7 GB RSS total). This is the most significant change in the memory landscape since the previous research.
- **All memory management infrastructure remains operational**: earlyoom, zram, swap file, VM sysctl tuning, memory-monitor, and claude-memory-tracker services are all active and correctly configured.
- **One critical memory event occurred on 2026-03-29** where usage spiked to 99% and swap reached 86%. The system recovered without intervention, demonstrating infrastructure resilience.
- **No system-level configuration changes are recommended**. Current optimizations from Task 39 are still effective. Focus should remain on user-level process hygiene.

## Context & Scope

This report is an update to the prior research conducted on 2026-03-10 (`specs/44_review_memory_logs_design_optimizations/reports/research-001.md`). The goal is to:

1. Re-assess current memory consumption patterns.
2. Verify that memory management infrastructure (earlyoom, zram, VM tuning, monitoring) is still functioning.
3. Identify new memory consumers or behavioral changes.
4. Review memory monitor logs for trends, anomalies, or shifts since March 2026.
5. Validate whether previous recommendations (Claude session hygiene, browser tab management) remain relevant.

## Findings

### Current Memory State (vs. March 2026)

| Metric | March 2026 (Previous) | May 2026 (Current) | Change |
|--------|----------------------|-------------------|--------|
| Total RAM | 30 GB | 30 GB | — |
| Used | 24 GB (80%) | 15 GB (50%) | **-9 GB (-30%)** |
| Available | 6 GB | 15 GB | **+9 GB** |
| Swap (zram) | 3.1 GB used of 15.3 GB | 3.4 GB used of 15.3 GB | +0.3 GB |
| Swap (file) | 0 B used of 16 GB | 0 B used of 16 GB | — |
| Memory Pressure (PSI) | avg10=0.00 | avg10=0.00 | — |

The system is currently operating at a comfortable 50-51% memory usage, a significant improvement from the 80%+ observed in March. This represents approximately 9 GB of freed RAM.

### Top Memory Consumers

Current top processes by RSS (from `ps aux --sort=-%mem`):

| Process | RSS (MB) | %MEM | Notes |
|---------|----------|------|-------|
| Lean worker | 2,473 | 7.8% | ProofChecker project (larger than March) |
| Lake serve | 787 | 2.4% | Lean build system |
| OpenCode (inst. 1) | 707 | 2.2% | **NEW** — headless agent |
| Claude (inst. 1) | 639 | 1.9% | `.config/nvim` session |
| OpenCode (inst. 2) | 624 | 1.9% | **NEW** — headless agent |
| Brave renderer | 510 | 1.5% | One of many Brave processes |
| Lua language server | 449 | 1.3% | **NEW** — Neovim LSP |
| OpenCode serve | 443 | 1.3% | **NEW** — local server |
| Claude (inst. 2) | 404 | 1.2% | Logos/Vision session |
| Gnome Shell | 429 | 1.3% | Desktop environment |
| **Total Brave (all renderers)** | **~6,707** | **~21%** | Multiple tabs/processes |
| **Total Lean/Lake** | **~4,381** | **~14%** | Mathlib-based project |
| **Total AI assistants** | **~2,945** | **~9%** | 2 Claude + 3 OpenCode |

**Key changes from March 2026:**

- **Claude instances**: Reduced from 7 (~3.8 GB) to 2 (~1.0 GB). The previous recommendation to consolidate Claude sessions has been effective.
- **OpenCode emergence**: Three OpenCode processes now consume ~1.7 GB combined. This is a new category of memory consumer not present in March.
- **Lua language server**: A new significant consumer at 449 MB, likely related to Neovim configuration.
- **Lean worker**: Now the single largest process at 2.5 GB (up from 1.8 GB in March), reflecting continued work on the ProofChecker project.
- **Brave**: Total Brave RSS is ~6.7 GB, up from ~5 GB in March. Browser tab management remains relevant.

### AI Assistant Memory Landscape

The claude-memory-tracker logs (via `~/.local/share/memory-monitor/claude.csv`) show:

| PID | Name | RSS (KB) | VSZ (KB) | %MEM |
|-----|------|----------|----------|------|
| 2488447 | claude | 604,876 | 76,099,948 | 1.8% |
| 2621365 | claude | 398,484 | 74,126,324 | 1.2% |
| 2533930 | opencode | — | — | 1.3% |
| 2643391 | opencode | — | — | 1.9% |
| 2699102 | opencode | — | — | 2.0% |

The claude-memory-tracker script currently tracks only processes matching `claude` in their command line. It does **not** capture OpenCode instances. The tracker service itself uses 3.7 MB.

### Memory Monitor Log Analysis

The `~/.local/share/memory-monitor/system.log` contains 76,398 valid samples spanning from 2026-03-09 to 2026-05-14.

**Overall statistics:**
- **Minimum**: 50%
- **Maximum**: 99%
- **Median**: 59%
- **Average**: 58%

**Distribution:**
- 50-60%: Most common range (~17,000 samples)
- 60-70%: Frequent during active work (~13,000 samples)
- 70-80%: Occasional (~4,000 samples)
- 80%+: Infrequent but notable (~350 samples total)
- 90%+: Rare (~50 samples), clustered around specific dates

**Dates with 80%+ memory usage:**
- 2026-04-10: 96 samples (peak ~80%, mostly steady)
- 2026-03-17: 89 samples
- 2026-03-29: 76 samples (critical event)
- 2026-03-12: 74 samples
- 2026-03-10: 66 samples (previous research date)
- 2026-05-02: 38 samples

**Critical event: 2026-03-29**
- Memory usage spiked to **99%** at 15:29:07.
- Swap usage reached **86%** concurrently.
- The spike lasted approximately 10-15 minutes (15:21–15:31).
- The system recovered without earlyoom intervention (earlyoom logs show no kills on this date).
- This demonstrates that the zram + swap infrastructure successfully absorbed the pressure spike.

**Current trend (May 2026):**
- Memory usage has stabilized at 50-51% throughout the current session.
- Swap usage is steady at 11%.
- No warning or critical notifications have fired since May 2, 2026 (per `.cooldown.warning` and `.cooldown.critical` timestamps).

### Memory Infrastructure Status

All components from Task 39 are operational and unchanged:

| Component | Status | Configuration | Notes |
|-----------|--------|---------------|-------|
| earlyoom | Active (running since May 10) | 10% free threshold, desktop notifications | prefer: lean/lake/claude/node/npm; avoid: gnome-shell/Xwayland/niri |
| systemd-oomd | Disabled | — | Correctly disabled to prevent conflict |
| zram | Active | 15.3 GB, zstd, priority 5 | 2.2 GB data compressed to 509 MB (~4.3:1 ratio) |
| Swap file | Ready | 16 GB, priority -1 | Unused (zram handles all pressure) |
| vm.swappiness | 10 | Prefer RAM over swap | Unchanged |
| vm.watermark_boost_factor | 0 | Disabled | Unchanged |
| vm.watermark_scale_factor | 125 | Better reclaim | Unchanged |
| vm.page-cluster | 0 | No readahead for zram | Unchanged |
| memory-monitor | Active | User service, 30s interval | Logging correctly |
| claude-memory-tracker | Active | User service, 60s interval | Tracking correctly |

**System changes since March 2026:**
- **NixOS upgraded** from an earlier version to `26.05.20260510.da5ad66 (Yarara)`.
- **Kernel upgraded** to `7.0.3` (previously unspecified).
- **OpenCode added** to the system as a new AI assistant package and service (see `configuration.nix` and `modules/opencode.nix`).
- **OpenCode Discord bot** added as a system service (PID 2681819, Python process, ~57 MB RSS).

### NixOS Configuration Review

The memory-related NixOS configuration in `configuration.nix` (lines 361–439) remains identical to the March 2026 configuration:

- `services.earlyoom` is enabled with the same thresholds and prefer/avoid rules.
- `swapDevices` defines a 16 GB swap file at `/var/lib/swapfile`.
- `zramSwap` is enabled with zstd, 50% of RAM, priority 5.
- `boot.kernel.sysctl` sets the same VM tuning parameters.
- `systemd.oomd.enable = false` prevents conflicts.

No memory-related configuration changes have been made since Task 39.

## Decisions

1. **No system-level changes needed**: The current earlyoom + zram + VM tuning + swap configuration is robust and has proven effective even during the March 29 critical spike.
2. **OpenCode is now a primary memory consumer**: The previous recommendation to manage Claude sessions should be broadened to include OpenCode instance hygiene.
3. **claude-memory-tracker scope is now incomplete**: It only tracks `claude` processes and misses OpenCode instances. Consider renaming or extending to track all AI assistant processes.
4. **Previous recommendations remain valid**: Browser tab management and Lean session awareness are still relevant, though current memory headroom reduces urgency.
5. **80% threshold is appropriate**: The system comfortably handles spikes up to 99% without hard failure; lowering the threshold would be unnecessary.

## Recommendations

### Priority 1: OpenCode Instance Hygiene (User Practice)

OpenCode now consumes ~1.7 GB across 3 instances. This is the largest change in the memory landscape since March.

- **Limit OpenCode instances**: Currently 3 instances (2 headless agents + 1 server). Consolidate where possible.
- **Close unused OpenCode sessions**: The two `--port` instances may be redundant depending on workflow.
- **Review OpenCode Discord bot necessity**: The bot uses only ~57 MB but runs continuously; evaluate if it needs to be a persistent system service.

**Estimated impact**: Could reduce memory usage by 0.5–1.5 GB.

### Priority 2: Update Process Tracker to Include OpenCode (Minor Enhancement)

The `claude-memory-tracker` script in `home.nix` only matches `claude` processes. It should also match `opencode` to provide complete AI assistant memory tracking.

**Suggested change** (in `home.nix`, within the claude-memory-tracker script):
Update the `pgrep` pattern from `claude` to `claude|opencode`, or add a separate OpenCode tracker.

**Estimated impact**: Better visibility into total AI assistant memory consumption.

### Priority 3: Browser Tab Management (Still Relevant)

Brave continues to be a major memory consumer at ~6.7 GB total. Previous recommendations still apply:

- Use Brave's memory saver feature.
- Close or suspend heavy tabs.
- Monitor for renderer process accumulation.

**Estimated impact**: Could reduce memory by 1–3 GB.

### Priority 4: Lean Session Awareness (Still Relevant)

Lean language server + Lake serve now total ~4.4 GB, up from ~1.8 GB in March. This reflects active work on the ProofChecker project.

- Close ProofChecker-related editors when not actively editing.
- Lean memory usage scales with project complexity; Mathlib-based projects are inherently heavy.

**Estimated impact**: Could free 2–4 GB when not needed.

### Priority 5: Optional Log Rotation (No Change)

The `system.log.old` file is 1.8 GB. This remains a disk space concern but does not affect memory.

- Consider adjusting `MAX_LOG_SIZE` in the memory-monitor script if disk space becomes tight.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OpenCode instances proliferate like Claude did in March | Medium | Medium | User awareness; consider adding OpenCode to earlyoom prefer list |
| Lean memory grows further with larger projects | Medium | Low | earlyoom prefer list already includes `lean` and `lake` |
| March 29-style spike recurs | Low | Low | zram + swap infrastructure has proven resilience |
| Log file disk usage grows unbounded | Low | Medium | Adjust `MAX_LOG_SIZE` or implement log compression |
| Lua language server memory growth | Low | Low | Monitor; not currently in earlyoom prefer list |

## Context Extension Recommendations

- **Topic**: OpenCode memory tracking
  - **Gap**: The `claude-memory-tracker` service and logs only capture Claude processes. OpenCode is now a significant memory consumer but is invisible to the tracker.
  - **Recommendation**: Update the tracker script to match `opencode` processes, or create a separate `ai-memory-tracker` that monitors both Claude and OpenCode.

- **Topic**: Memory event alerting
  - **Gap**: The March 29 critical spike (99% memory, 86% swap) was not proactively alerted beyond the existing desktop notification system. There is no post-event analysis or summary.
  - **Recommendation**: Consider adding a simple daily/weekly memory summary report (e.g., max usage, average, any >90% events) to help catch trends before they become critical.

## Appendix

### Verification Commands

```bash
# Current memory status
free -h
cat /proc/meminfo | head -20

# Swap and zram status
swapon --show
zramctl

# Memory pressure
cat /proc/pressure/memory

# Top consumers
ps aux --sort=-%mem | head -30

# VM parameters
sysctl vm.swappiness vm.watermark_boost_factor vm.watermark_scale_factor vm.page-cluster

# Service status
systemctl status earlyoom
systemctl --user status memory-monitor
systemctl --user status claude-memory-tracker

# AI assistant processes
pgrep -fa "claude|opencode"

# Memory logs
tail -50 ~/.local/share/memory-monitor/system.log
tail -50 ~/.local/share/memory-monitor/claude.csv
```

### References

- `specs/44_review_memory_logs_design_optimizations/reports/research-001.md` (previous research, 2026-03-10)
- `configuration.nix` (memory management sections, lines 361–439)
- `home.nix` (memory-monitor and claude-memory-tracker scripts, lines 497–820)
- `modules/opencode.nix` (OpenCode configuration)
- NixOS 26.05 (Yarara), kernel 7.0.3

### Prior Related Tasks

- Task 26: Memory monitoring systemd services
- Task 39: Memory log analysis and optimization
- Task 25: Configure swap space
- Task 44: Original memory log review (2026-03-10)
