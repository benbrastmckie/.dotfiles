# Research Report: Laptop High Fan Activity Investigation

- **Task**: 40 - Investigate laptop high fan activity and optimize system
- **Started**: 2026-02-23T12:00:00-08:00
- **Completed**: 2026-02-23T12:45:00-08:00
- **Effort**: 45 minutes
- **Dependencies**: Task 39 (memory optimization, already completed)
- **Sources/Inputs**:
  - Local configuration files (configuration.nix, home.nix, flake.nix)
  - NixOS Wiki: Laptop, Power Management
  - NixOS Discourse community discussions
  - Linux kernel documentation (amd-pstate)
  - Framework Community forums (Ryzen AI 300 thermals)
- **Artifacts**: specs/40_investigate_laptop_high_fan_optimize_system/reports/research-001.md
- **Standards**: report-format.md, nix.md

## Project Context

- **Upstream Dependencies**: configuration.nix power management, kernel parameters
- **Downstream Dependents**: System thermal stability, battery life, user experience
- **Alternative Paths**: TLP vs auto-cpufreq vs power-profiles-daemon
- **Potential Extensions**: Undervolting, custom fan curves, per-process CPU limits

## Executive Summary

- Current configuration already has good power management foundations (amd_pstate=active, ondemand governor, power-profiles-daemon)
- **Potential conflict detected**: power-profiles-daemon is enabled alongside manual cpuFreqGovernor setting, which may cause unpredictable behavior
- GNOME tracker services can cause significant CPU spikes during file indexing
- Task 39's memory optimizations (zram, vm.swappiness=10) are already in place, which helps reduce memory-related CPU overhead
- AMD Ryzen AI 300 series users report thermal issues often stem from driver problems rather than configuration, particularly with graphics rendering
- Several optimization opportunities exist: disable conflicting services, tune thermald, disable GNOME tracker indexing

## Context and Scope

The user reports high fan activity during low usage on their laptop running NixOS. The system:
- **Hardware**: AMD Ryzen AI 300 series (HX 370 on hamsa host)
- **Desktop**: GNOME with optional niri session
- **Kernel**: linuxPackages_latest with amd_pstate=active
- **Current power tools**: power-profiles-daemon enabled, cpuFreqGovernor = "ondemand"

This research identifies causes and recommends optimizations specific to this dotfiles configuration.

## Findings

### Current Power Configuration Analysis

**In configuration.nix:**
```nix
# Kernel parameters (lines 36-41)
boot.kernelParams = [
  "amd_pstate=active"           # AMD P-state driver active mode
  "amdgpu.dcdebugmask=0x10"     # GPU debug mask for suspend
  "rtc_cmos.use_acpi_alarm=1"   # ACPI wake support
  "hung_task_timeout_secs=60"   # Deadlock detection
];

# Power management (lines 275-282)
powerManagement = {
  enable = true;
  cpuFreqGovernor = "ondemand";  # Manual governor setting
};
services.power-profiles-daemon.enable = true;  # PPD also enabled
```

**Issue Identified**: The `cpuFreqGovernor = "ondemand"` setting conflicts with `services.power-profiles-daemon.enable = true`. When power-profiles-daemon (PPD) is active, it manages CPU governors itself. Setting a manual governor may cause:
- PPD repeatedly trying to set its own governor
- CPU frequency oscillations
- Increased background CPU activity

### AMD P-State Modes

The current `amd_pstate=active` mode delegates frequency decisions to hardware, which should be optimal. The three modes are:

| Mode | Description | Best For |
|------|-------------|----------|
| `active` | Hardware-controlled (EPP) | Modern systems with PPD |
| `passive` | Kernel-controlled | Systems with TLP/auto-cpufreq |
| `guided` | Hybrid (hardware within kernel limits) | Balance of control |

**Recommendation**: Keep `active` mode when using power-profiles-daemon, but remove manual governor setting.

### Power Management Tool Conflicts

The NixOS community has documented conflicts between power management tools:

| Tool Combination | Status | Notes |
|------------------|--------|-------|
| PPD + manual governor | Conflict | PPD overrides governors; manual setting causes fighting |
| PPD + TLP | Conflict | Both modify same kernel tunables |
| PPD + auto-cpufreq | Conflict | auto-cpufreq disables PPD on install |
| thermald + PPD | Compatible | thermald handles thermal, PPD handles frequency |
| thermald + auto-cpufreq | Compatible | Different responsibilities |

### GNOME Services Causing CPU Load

GNOME's tracker-miner services can cause significant CPU spikes:

1. **tracker-miner-fs**: File system indexing
2. **tracker-miner-fs-3**: Updated version in GNOME 42+
3. **tracker-extract**: Metadata extraction

These services index files for GNOME's search functionality. Heavy directories (Downloads, large code repositories) trigger intensive indexing.

**Current Configuration**: No explicit tracker disabling found. GNOME is enabled with default services.

### Ryzen AI 300 Specific Issues

Community reports from Framework and other AMD laptop users indicate:

1. **Graphics driver issues**: Software rendering mode (fallback) causes 100% CPU usage. Solution: Ensure proper AMDGPU driver with `amdgpu` videoDriver
2. **Kernel version matters**: Users report improvements with kernel 6.10+ for RDNA 3.5 support
3. **Thermal throttling at 100C**: Normal for these chips under load; firmware manages this
4. **No Linux undervolting yet**: Unlike Intel, AMD Ryzen AI 300 lacks stable Linux undervolting tools

### Services Currently Enabled

Services in configuration.nix that run continuously:

| Service | Purpose | CPU Impact |
|---------|---------|------------|
| geoclue2 | Location services | Low (periodic) |
| automatic-timezoned | Timezone detection | Low (on location change) |
| earlyoom | OOM prevention | Very low (polling) |
| gdm | Display manager | Low |
| gnome-settings-daemon | GNOME settings | Medium (handles power) |
| tracker (implicit) | File indexing | HIGH during indexing |
| pipewire | Audio | Low |
| avahi | Network discovery | Low |

### Home Manager User Services

From home.nix:

| Service | Purpose | CPU Impact |
|---------|---------|------------|
| ydotool | Input automation | Very low (idle daemon) |
| gmail-oauth2-refresh | Token refresh (45min) | Negligible |
| memory-monitor | Memory logging (30s) | Very low |
| claude-memory-tracker | Process tracking (60s) | Very low |
| mako | Notifications (niri only) | Low |
| kanshi | Display config (niri only) | Low |

## Decisions

1. **Remove manual cpuFreqGovernor**: Let power-profiles-daemon manage governors since it's already enabled
2. **Consider disabling GNOME tracker**: Provides marginal benefit for code/document-focused workflows
3. **Keep amd_pstate=active**: Correct mode for PPD integration
4. **Do not switch to TLP**: PPD integrates better with GNOME and is already configured

## Recommendations

### Priority 1: Remove Governor Conflict

Remove the manual governor setting to let PPD manage CPU frequency:

```nix
# In configuration.nix, change:
powerManagement = {
  enable = true;
  # Remove: cpuFreqGovernor = "ondemand";
};
```

This eliminates the conflict where two systems try to control the same kernel tunables.

### Priority 2: Disable GNOME Tracker Services

For code/document workflows where GNOME search is rarely used:

```nix
# In configuration.nix, add:
services.gnome.tracker-miners.enable = false;
services.gnome.tracker.enable = false;
```

**Alternative**: Keep tracker but exclude heavy directories via dconf:
```nix
# In home.nix dconf.settings:
"org/freedesktop/tracker/miner/files" = {
  index-recursive-directories = [];
  index-single-directories = [];
};
```

### Priority 3: Enable thermald for Intel/AMD Thermal Management

While thermald primarily targets Intel, it can help with general thermal management:

```nix
# In configuration.nix:
services.thermald.enable = true;
```

**Note**: thermald works alongside PPD without conflict and provides proactive thermal throttling before hardware limits are reached.

### Priority 4: Verify Graphics Driver

Ensure AMDGPU driver is being used (not software rendering):

```nix
# Already have:
hardware.graphics.enable = true;
hardware.graphics.enable32Bit = true;

# Consider adding explicitly if issues persist:
services.xserver.videoDrivers = [ "amdgpu" ];
```

**Verification command**:
```bash
glxinfo | grep "OpenGL renderer"
# Should show AMD Radeon, not llvmpipe
```

### Priority 5: Diagnostic Commands

Before making changes, collect baseline data:

```bash
# Check current CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check power profile
powerprofilesctl get

# Check if software rendering
glxinfo | grep -i "renderer"

# Monitor CPU frequency in real-time
watch -n1 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | sort -u"

# Check tracker status
systemctl --user status tracker-miner-fs-3

# Check for high CPU processes
htop --sort-key PERCENT_CPU
```

### Priority 6: Consider auto-cpufreq Alternative (Optional)

If PPD integration continues to cause issues, switch to auto-cpufreq:

```nix
# Replace PPD with auto-cpufreq
services.power-profiles-daemon.enable = false;
services.auto-cpufreq = {
  enable = true;
  settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };
};
```

**Note**: This requires changing `amd_pstate=active` to `amd_pstate=passive` since auto-cpufreq needs kernel-controlled governors.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Disabling tracker breaks GNOME search | Low | Can re-enable if needed; most workflows don't use it |
| Removing governor affects performance | Low | PPD manages this automatically |
| thermald conflicts with AMD | Low | Modern thermald has AMD support; can disable if issues |
| Changes cause boot issues | Medium | NixOS rollback makes recovery trivial |

## Appendix

### References

- [NixOS Wiki - Laptop](https://wiki.nixos.org/wiki/Laptop)
- [NixOS Wiki - Power Management](https://wiki.nixos.org/wiki/Power_Management)
- [NixOS Discourse - Power Management Options](https://discourse.nixos.org/t/what-is-the-best-option-for-power-management/63406)
- [Framework Community - Ryzen AI 300 Thermals](https://community.frame.work/t/framework-ai-300-hx-370-overly-warm/68427)
- [AMD P-State Driver Documentation](https://docs.kernel.org/admin-guide/pm/amd-pstate.html)
- [TLP Documentation - PPD Compatibility](https://linrunner.de/tlp/faq/ppd.html)
- [NixOS Discourse - Disable GNOME Applications](https://discourse.nixos.org/t/howto-disable-most-gnome-default-applications-and-what-they-are/13505)

### Implementation Configuration Block

Complete recommended changes for configuration.nix:

```nix
# ==========================================================================
# Thermal and CPU Optimization
# ==========================================================================
# Resolves power management conflicts and reduces background CPU load.
# See: specs/40_investigate_laptop_high_fan_optimize_system
# ==========================================================================

# Power management - let PPD manage governors
powerManagement = {
  enable = true;
  # cpuFreqGovernor removed - PPD manages this
};

# Power profiles daemon (already enabled)
services.power-profiles-daemon.enable = true;

# Disable GNOME tracker indexing (reduces background CPU)
services.gnome.tracker-miners.enable = false;
services.gnome.tracker.enable = false;

# Optional: Enable thermald for proactive thermal management
services.thermald.enable = true;
```

### Verification Commands After Implementation

```bash
# Verify no governor conflict
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Should show one of: powersave, balanced, performance (from PPD)

# Verify tracker is disabled
systemctl --user status tracker-miner-fs-3
# Should show "not-found" or "masked"

# Monitor temperatures
watch -n1 sensors

# Monitor fan speed (if available)
cat /sys/class/hwmon/hwmon*/fan*_input 2>/dev/null

# Check power profile
powerprofilesctl get
# Should show: balanced (or power-saver/performance)
```
