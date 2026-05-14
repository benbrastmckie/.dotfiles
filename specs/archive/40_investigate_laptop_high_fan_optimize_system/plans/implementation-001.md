# Implementation Plan: Laptop Thermal Optimization

- **Task**: 40 - Investigate laptop high fan activity and optimize system
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: Task 39 (memory optimization, completed)
- **Research Inputs**: specs/40_investigate_laptop_high_fan_optimize_system/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

This plan addresses laptop thermal issues identified in research: a power management conflict between manual cpuFreqGovernor setting and power-profiles-daemon, plus GNOME tracker services causing background CPU spikes. The implementation removes the conflicting governor setting, disables unnecessary tracker services, and optionally enables thermald for proactive thermal management.

### Research Integration

- Research identified cpuFreqGovernor="ondemand" conflicting with power-profiles-daemon
- GNOME tracker-miner services cause CPU spikes during file indexing
- AMD Ryzen AI 300 with amd_pstate=active mode is correctly configured for PPD
- thermald can complement PPD without conflict

## Goals & Non-Goals

**Goals**:
- Eliminate power management conflict between cpuFreqGovernor and power-profiles-daemon
- Reduce background CPU load by disabling GNOME tracker services
- Improve thermal behavior and reduce fan activity during idle/low usage
- Maintain system functionality and rollback capability

**Non-Goals**:
- Switching from power-profiles-daemon to TLP or auto-cpufreq (would require kernel parameter changes)
- Hardware-level modifications (undervolting, custom fan curves)
- Optimizing graphics driver configuration (already correctly configured)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Disabling tracker breaks GNOME search | Low | Medium | Can re-enable if needed; search rarely used for code workflows |
| Removing governor causes unexpected frequency behavior | Low | Low | PPD manages this automatically; can revert if issues |
| thermald conflicts with AMD platform | Low | Low | Modern thermald has AMD support; can disable if issues |
| Changes cause boot issues | Medium | Very Low | NixOS rollback makes recovery trivial via boot menu |

## Implementation Phases

### Phase 1: Baseline Diagnostics [NOT STARTED]

**Goal**: Collect current system state for comparison after changes

**Tasks**:
- [ ] Run diagnostic commands to capture baseline thermal/CPU state
- [ ] Document current governor, power profile, and tracker status
- [ ] Note current fan behavior and temperatures

**Timing**: 15 minutes

**Files to modify**: None (diagnostic only)

**Verification**:
- Baseline data captured and documented in summary

---

### Phase 2: Remove Power Management Conflict [NOT STARTED]

**Goal**: Eliminate the cpuFreqGovernor setting that conflicts with power-profiles-daemon

**Tasks**:
- [ ] Edit configuration.nix to remove cpuFreqGovernor = "ondemand"
- [ ] Keep powerManagement.enable = true
- [ ] Verify power-profiles-daemon.enable = true remains

**Timing**: 15 minutes

**Files to modify**:
- `configuration.nix` - Remove cpuFreqGovernor line from powerManagement block

**Verification**:
- configuration.nix has powerManagement block without cpuFreqGovernor
- nix flake check passes

---

### Phase 3: Disable GNOME Tracker Services [NOT STARTED]

**Goal**: Disable tracker-miner services that cause background CPU spikes

**Tasks**:
- [ ] Add services.gnome.tracker-miners.enable = false to configuration.nix
- [ ] Add services.gnome.tracker.enable = false to configuration.nix
- [ ] Place settings in appropriate location (near other GNOME configuration)

**Timing**: 15 minutes

**Files to modify**:
- `configuration.nix` - Add tracker disable options

**Verification**:
- nix flake check passes
- Tracker options properly configured

---

### Phase 4: Enable thermald (Optional) [NOT STARTED]

**Goal**: Enable thermald for proactive thermal management alongside PPD

**Tasks**:
- [ ] Add services.thermald.enable = true to configuration.nix
- [ ] Place setting near other power management options

**Timing**: 10 minutes

**Files to modify**:
- `configuration.nix` - Add thermald enable option

**Verification**:
- nix flake check passes

---

### Phase 5: Build and Deploy Configuration [NOT STARTED]

**Goal**: Apply changes to the system and verify improvements

**Tasks**:
- [ ] Run nixos-rebuild switch to apply configuration
- [ ] Verify system boots and operates normally
- [ ] Check that power-profiles-daemon is managing governors
- [ ] Verify tracker services are disabled
- [ ] Verify thermald is running (if enabled)

**Timing**: 30 minutes

**Files to modify**: None (deployment only)

**Verification**:
- nixos-rebuild switch completes successfully
- System operates normally after reboot
- `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` shows PPD-managed governor
- `systemctl --user status tracker-miner-fs-3` shows not-found or masked
- `systemctl status thermald` shows active (if enabled)

---

### Phase 6: Post-Implementation Verification [NOT STARTED]

**Goal**: Compare thermal behavior to baseline and document results

**Tasks**:
- [ ] Run same diagnostic commands as Phase 1
- [ ] Compare temperatures, fan behavior, CPU frequencies
- [ ] Document improvements or remaining issues
- [ ] Create implementation summary

**Timing**: 15 minutes

**Files to modify**:
- `specs/40_investigate_laptop_high_fan_optimize_system/summaries/implementation-summary-20260223.md` - Create summary

**Verification**:
- Summary documents before/after comparison
- Any remaining issues noted for follow-up

## Testing & Validation

- [ ] nix flake check passes after configuration changes
- [ ] nixos-rebuild switch completes without errors
- [ ] System boots normally after changes
- [ ] Power-profiles-daemon controls CPU governors (no conflict)
- [ ] GNOME tracker services are disabled
- [ ] Fan noise reduced during idle/low usage (subjective)
- [ ] Temperatures stable or improved (objective measurement)

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-20260223.md (after completion)
- Modified configuration.nix with optimizations

## Rollback/Contingency

NixOS provides built-in rollback capability:

1. **Boot menu rollback**: Select previous generation from GRUB/systemd-boot menu
2. **Command rollback**: `sudo nixos-rebuild switch --rollback`
3. **Git rollback**: `git checkout HEAD~1 -- configuration.nix && sudo nixos-rebuild switch`

If issues occur:
- Boot to previous generation from boot menu
- Re-enable removed settings if specific feature is needed
- thermald can be disabled independently if it causes issues
