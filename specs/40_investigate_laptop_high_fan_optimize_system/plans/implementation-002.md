# Implementation Plan: Laptop Thermal & Build Optimization

- **Task**: 40 - Investigate laptop high fan activity and optimize system
- **Version**: 002
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 39 (memory optimization, completed)
- **Research Inputs**:
  - specs/40_investigate_laptop_high_fan_optimize_system/reports/research-001.md (power management)
  - specs/40_investigate_laptop_high_fan_optimize_system/reports/research-002.md (lake build optimization)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

This revised plan combines two optimization tracks identified in research:

1. **System-wide thermal optimization** (research-001.md): Remove power management conflicts and reduce background CPU load
2. **Compilation workload optimization** (research-002.md): Configure Lean/Lake builds for optimal thermal and memory balance

The implementation removes the conflicting governor setting, disables GNOME tracker services, configures LEAN_NUM_THREADS for controlled parallelism, and updates earlyoom to prefer killing compilation processes during OOM events.

### Research Integration

From research-001.md:
- cpuFreqGovernor="ondemand" conflicts with power-profiles-daemon
- GNOME tracker-miner services cause CPU spikes during file indexing
- AMD Ryzen AI 300 with amd_pstate=active is correctly configured for PPD

From research-002.md:
- LEAN_NUM_THREADS=8 provides optimal parallelism for 12-core Ryzen AI 9 HX 370
- Mathlib's dependency graph inherently limits parallelism to ~18x regardless of core count
- Power-profiles-daemon "balanced" mode outperforms "performance" for sustained builds
- earlyoom should prefer killing lean/lake processes during OOM

## Goals & Non-Goals

**Goals**:
- Eliminate power management conflict between cpuFreqGovernor and power-profiles-daemon
- Reduce background CPU load by disabling GNOME tracker services
- Configure optimal LEAN_NUM_THREADS for compilation workloads
- Update earlyoom to prefer killing compilation processes during memory pressure
- Improve thermal behavior during both idle and sustained compilation
- Maintain system functionality and rollback capability

**Non-Goals**:
- Switching from power-profiles-daemon to TLP or auto-cpufreq
- Hardware-level modifications (undervolting via RyzenAdj - not in nixpkgs)
- Tmpfs for .lake directories (data loss risk)
- Systemd user slices for compilation (complexity outweighs benefit)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Disabling tracker breaks GNOME search | Low | Medium | Can re-enable if needed; search rarely used for code workflows |
| Removing governor causes unexpected behavior | Low | Low | PPD manages this automatically; can revert if issues |
| LEAN_NUM_THREADS=8 slows builds | Low | Low | 8 threads still provides ~95% throughput on 12 cores |
| earlyoom kills Lean during memory spike | Medium | Low | Prefer pattern allows controlled OOM behavior |
| Changes cause boot issues | Medium | Very Low | NixOS rollback via boot menu |

## Implementation Phases

### Phase 1: Baseline Diagnostics [NOT STARTED]

**Goal**: Collect current system state for comparison after changes

**Tasks**:
- [ ] Run diagnostic commands to capture baseline thermal/CPU state
- [ ] Document current governor, power profile, and tracker status
- [ ] Note current fan behavior and temperatures
- [ ] Test a small lake build and note thermal behavior

**Timing**: 15 minutes

**Files to modify**: None (diagnostic only)

**Commands**:
```bash
# Baseline diagnostics
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
powerprofilesctl get
systemctl --user status tracker-miner-fs-3
sensors
echo "LEAN_NUM_THREADS=$LEAN_NUM_THREADS"
```

**Verification**:
- Baseline data captured and documented in summary

---

### Phase 2: Remove Power Management Conflict [NOT STARTED]

**Goal**: Eliminate the cpuFreqGovernor setting that conflicts with power-profiles-daemon

**Tasks**:
- [ ] Edit configuration.nix to remove cpuFreqGovernor = "ondemand"
- [ ] Keep powerManagement.enable = true
- [ ] Verify power-profiles-daemon.enable = true remains

**Timing**: 10 minutes

**Files to modify**:
- `configuration.nix` - Remove cpuFreqGovernor line from powerManagement block

**Change**:
```nix
# Before:
powerManagement = {
  enable = true;
  cpuFreqGovernor = "ondemand";
};

# After:
powerManagement = {
  enable = true;
  # cpuFreqGovernor removed - PPD manages this
};
```

**Verification**:
- configuration.nix has powerManagement block without cpuFreqGovernor
- nix flake check passes

---

### Phase 3: Disable GNOME Tracker Services [NOT STARTED]

**Goal**: Disable tracker-miner services that cause background CPU spikes

**Tasks**:
- [ ] Add services.gnome.tracker-miners.enable = false to configuration.nix
- [ ] Add services.gnome.tracker.enable = false to configuration.nix
- [ ] Place settings near other GNOME configuration

**Timing**: 10 minutes

**Files to modify**:
- `configuration.nix` - Add tracker disable options

**Change**:
```nix
# Add to GNOME services section:
services.gnome.tracker-miners.enable = false;
services.gnome.tracker.enable = false;
```

**Verification**:
- nix flake check passes
- Tracker options properly configured

---

### Phase 4: Configure LEAN_NUM_THREADS [NOT STARTED]

**Goal**: Set optimal Lean compilation parallelism via environment variable

**Tasks**:
- [ ] Add LEAN_NUM_THREADS=8 to fish shell configuration
- [ ] Verify variable is exported in shell sessions

**Timing**: 10 minutes

**Files to modify**:
- `config/config.fish` - Add LEAN_NUM_THREADS export

**Change**:
```fish
# Add to config.fish:
# Lean compilation parallelism (optimal for 12-core Ryzen AI 9 HX 370)
set -gx LEAN_NUM_THREADS 8
```

**Verification**:
- `echo $LEAN_NUM_THREADS` returns 8 in new shell

---

### Phase 5: Update earlyoom Configuration [NOT STARTED]

**Goal**: Configure earlyoom to prefer killing compilation processes during OOM

**Tasks**:
- [ ] Update earlyoom extraArgs to include lean and lake in prefer pattern
- [ ] Keep existing prefer patterns for claude, node, npm
- [ ] Verify avoid pattern protects desktop processes

**Timing**: 10 minutes

**Files to modify**:
- `configuration.nix` - Update earlyoom.extraArgs

**Change**:
```nix
# Before:
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;
  extraArgs = [
    "--prefer" "^(claude|node|npm)$"
  ];
};

# After:
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;
  extraArgs = [
    "--avoid" "^(gnome-shell|Xwayland|niri)$"
    "--prefer" "^(lean|lake|claude|node|npm)$"
  ];
};
```

**Verification**:
- nix flake check passes
- earlyoom configuration includes lean/lake in prefer pattern

---

### Phase 6: Build and Deploy Configuration [NOT STARTED]

**Goal**: Apply changes to the system and verify improvements

**Tasks**:
- [ ] Run nixos-rebuild switch to apply configuration
- [ ] Verify system boots and operates normally
- [ ] Check that power-profiles-daemon is managing governors
- [ ] Verify tracker services are disabled
- [ ] Verify earlyoom is running with new configuration

**Timing**: 30 minutes

**Files to modify**: None (deployment only)

**Commands**:
```bash
# Build and switch
sudo nixos-rebuild switch --flake .

# Verify power management
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
powerprofilesctl get

# Verify tracker disabled
systemctl --user status tracker-miner-fs-3

# Verify earlyoom
systemctl status earlyoom
journalctl -u earlyoom | tail -5
```

**Verification**:
- nixos-rebuild switch completes successfully
- System operates normally after reboot
- Governor shows PPD-managed value (powersave/balanced/performance)
- tracker-miner-fs-3 shows not-found or masked
- earlyoom status shows running with new args

---

### Phase 7: Post-Implementation Verification [NOT STARTED]

**Goal**: Compare thermal behavior to baseline and test compilation workload

**Tasks**:
- [ ] Run same diagnostic commands as Phase 1
- [ ] Compare temperatures, fan behavior, CPU frequencies at idle
- [ ] Run a test lake build and observe thermal behavior
- [ ] Verify LEAN_NUM_THREADS limits parallelism
- [ ] Document improvements or remaining issues
- [ ] Create implementation summary

**Timing**: 30 minutes

**Files to modify**:
- `specs/40_investigate_laptop_high_fan_optimize_system/summaries/implementation-summary-20260224.md` - Create summary

**Commands**:
```bash
# Post-implementation diagnostics
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
powerprofilesctl get
sensors
echo "LEAN_NUM_THREADS=$LEAN_NUM_THREADS"

# Test compilation (small build)
cd ~/Projects/Logos/Theory
lake build Logos.Basic --verbose 2>&1 | head -20

# Monitor during build
htop --sort-key=PERCENT_CPU
watch -n1 sensors
```

**Verification**:
- Summary documents before/after comparison
- Idle temperatures improved
- Compilation runs with limited parallelism
- Fan noise reduced during idle
- Any remaining issues noted for follow-up

## Testing & Validation

- [ ] nix flake check passes after configuration changes
- [ ] nixos-rebuild switch completes without errors
- [ ] System boots normally after changes
- [ ] Power-profiles-daemon controls CPU governors (no conflict)
- [ ] GNOME tracker services are disabled
- [ ] LEAN_NUM_THREADS=8 is set in new shell sessions
- [ ] earlyoom running with lean/lake in prefer pattern
- [ ] Fan noise reduced during idle/low usage (subjective)
- [ ] Temperatures stable or improved (objective measurement)
- [ ] Compilation runs with controlled parallelism

## Artifacts & Outputs

- plans/implementation-002.md (this file)
- summaries/implementation-summary-20260224.md (after completion)
- Modified configuration.nix with optimizations
- Modified config/config.fish with LEAN_NUM_THREADS

## Rollback/Contingency

NixOS provides built-in rollback capability:

1. **Boot menu rollback**: Select previous generation from GRUB/systemd-boot menu
2. **Command rollback**: `sudo nixos-rebuild switch --rollback`
3. **Git rollback**: `git checkout HEAD~1 -- configuration.nix && sudo nixos-rebuild switch`

For LEAN_NUM_THREADS:
- Remove or comment out the line in config.fish
- Open new shell to get default behavior

If issues occur:
- Boot to previous generation from boot menu
- Re-enable removed settings if specific feature is needed
- Adjust LEAN_NUM_THREADS up or down based on observations
