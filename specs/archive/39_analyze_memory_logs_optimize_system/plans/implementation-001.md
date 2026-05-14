# Implementation Plan: Task #39

- **Task**: 39 - Analyze memory logs and optimize system robustness
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/39_analyze_memory_logs_optimize_system/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

This implementation addresses memory optimization issues identified through 12 days of log analysis. The research found three actionable issues: (1) dual OOM killers running concurrently (earlyoom + systemd-oomd), (2) missing zram compressed swap, and (3) suboptimal vm.swappiness for desktop use. Changes will be made to configuration.nix in a staged manner to ensure system stability.

### Research Integration

Key findings from research-001.md:
- Peak memory usage reached 86% on Feb 12 with swap at 72%
- Both earlyoom and systemd-oomd are running (conflict)
- System uses 16GB swap file but no zram
- Default vm.swappiness=60 is high for desktop systems
- Claude processes can spike to 1.4GB each with 5+ concurrent instances

## Goals & Non-Goals

**Goals**:
- Disable systemd-oomd to eliminate conflict with earlyoom
- Enable zram with zstd compression for faster swap operations
- Tune vm.swappiness and related parameters for desktop responsiveness
- Maintain existing earlyoom configuration (working as intended)
- Ensure system rebuilds successfully with all changes

**Non-Goals**:
- Per-application memory limits (requires architectural changes)
- Log rotation improvements (separate task scope)
- Hibernation support (would require 32GB+ swap)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| System fails to boot after changes | High | Low | Stage changes in phases, rebuild after each |
| zram CPU overhead affects performance | Low | Low | zstd is optimized; can disable if issues arise |
| Lower swappiness triggers more OOM kills | Medium | Low | earlyoom still intervenes at 10% free |
| Existing swap file conflicts with zram | Medium | Low | zram has higher priority (5 vs -2) |

## Implementation Phases

### Phase 1: Disable systemd-oomd [COMPLETED]

**Goal**: Resolve OOM killer conflict by disabling systemd-oomd (earlyoom is preferred)

**Tasks**:
- [ ] Add `systemd.oomd.enable = false;` to configuration.nix
- [ ] Add comment block explaining the change and referencing task 39
- [ ] Run `nix flake check` to validate syntax
- [ ] Run `nixos-rebuild build` to verify build succeeds
- [ ] Run `nixos-rebuild switch` to apply changes
- [ ] Verify systemd-oomd is stopped: `systemctl status systemd-oomd`
- [ ] Verify earlyoom is still running: `systemctl status earlyoom`

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add systemd.oomd.enable = false

**Verification**:
- `systemctl status systemd-oomd` shows inactive/disabled
- `systemctl status earlyoom` shows active/running

---

### Phase 2: Enable zram Swap [COMPLETED]

**Goal**: Enable zram compressed swap for faster swap operations and reduced SSD wear

**Tasks**:
- [ ] Add zramSwap configuration block to configuration.nix
- [ ] Configure algorithm as zstd (best compression/speed ratio)
- [ ] Set memoryPercent to 50 (16GB of 32GB RAM)
- [ ] Set priority to 5 (higher than swap file at -2)
- [ ] Run `nix flake check` to validate syntax
- [ ] Run `nixos-rebuild build` to verify build succeeds
- [ ] Run `nixos-rebuild switch` to apply changes
- [ ] Verify zram is active: `zramctl` and `swapon --show`

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add zramSwap block

**Verification**:
- `zramctl` shows zram0 with zstd algorithm
- `swapon --show` shows both zram (priority 5) and swapfile (priority -2)

---

### Phase 3: Tune VM Parameters [COMPLETED]

**Goal**: Optimize virtual memory parameters for desktop responsiveness with zram

**Tasks**:
- [ ] Add boot.kernel.sysctl block with vm.swappiness = 10
- [ ] Add vm.watermark_boost_factor = 0 (disable watermark boosting)
- [ ] Add vm.watermark_scale_factor = 125 (better memory reclaim)
- [ ] Add vm.page-cluster = 0 (disable readahead for zram)
- [ ] Run `nix flake check` to validate syntax
- [ ] Run `nixos-rebuild build` to verify build succeeds
- [ ] Run `nixos-rebuild switch` to apply changes
- [ ] Verify sysctl values are applied

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add boot.kernel.sysctl block

**Verification**:
- `sysctl vm.swappiness` returns 10
- `sysctl vm.watermark_boost_factor` returns 0
- `sysctl vm.watermark_scale_factor` returns 125
- `sysctl vm.page-cluster` returns 0

---

### Phase 4: Verification and Documentation [COMPLETED]

**Goal**: Verify all changes work together and document the configuration

**Tasks**:
- [ ] Run `free -h` to confirm memory and swap status
- [ ] Run `swapon --show` to verify swap hierarchy (zram > swapfile)
- [ ] Check `/proc/pressure/memory` for baseline pressure stats
- [ ] Verify desktop responsiveness with normal workload
- [ ] Create implementation summary with verification results
- [ ] Update task state to completed

**Timing**: 30 minutes

**Files to create**:
- `specs/39_analyze_memory_logs_optimize_system/summaries/implementation-summary-20260222.md`

**Verification**:
- All services running as expected
- System responsive under normal usage
- Swap hierarchy correct (zram primary, file secondary)

## Testing & Validation

- [ ] `nix flake check` passes after all changes
- [ ] `nixos-rebuild build` succeeds
- [ ] `nixos-rebuild switch` applies without errors
- [ ] System boots normally after changes
- [ ] earlyoom service active, systemd-oomd service inactive
- [ ] zram swap enabled and active
- [ ] VM sysctl parameters applied correctly
- [ ] Desktop remains responsive during normal usage

## Artifacts & Outputs

- `configuration.nix` - Modified with memory optimization settings
- `specs/39_analyze_memory_logs_optimize_system/plans/implementation-001.md` - This plan
- `specs/39_analyze_memory_logs_optimize_system/summaries/implementation-summary-20260222.md` - Summary

## Rollback/Contingency

If system becomes unstable after changes:

1. Boot from previous generation: At boot menu, select previous NixOS generation
2. Revert changes: Remove the added configuration blocks from configuration.nix
3. Rebuild: `nixos-rebuild switch`

Each phase can be reverted independently:
- Phase 1: Remove `systemd.oomd.enable = false;`
- Phase 2: Remove `zramSwap` block
- Phase 3: Remove `boot.kernel.sysctl` block

The existing swap file configuration remains untouched and serves as fallback.
