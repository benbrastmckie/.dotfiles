# Implementation Plan: Task #25

- **Task**: 25 - Configure swap space in NixOS configuration
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/25_configure_swap_space_nixos/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Add 16GB swap file to NixOS configuration to provide a memory safety buffer that works alongside the existing earlyoom service. The swap file will be configured in `configuration.nix` since all hosts share the same 32GB RAM specification. SSD TRIM optimization will be enabled via `discardPolicy`.

### Research Integration

Key findings from research-001.md:
- All three hosts (garuda, hamsa, nandi) have `swapDevices = []` in hardware-configuration.nix
- earlyoom is already configured with 10% free memory/swap thresholds
- Swap file approach is simpler than partition (no repartitioning needed)
- 16GB size aligns with development workload recommendations for 32GB RAM systems
- `/var/lib/swapfile` is the NixOS conventional location for swap files

## Goals & Non-Goals

**Goals**:
- Add 16GB swap file as memory safety buffer
- Enable SSD TRIM optimization for swap
- Integrate with existing earlyoom configuration
- Document the three-tier memory management approach

**Non-Goals**:
- Hibernation support (would require swap >= RAM size)
- zram configuration (can be added later if disk swap proves insufficient)
- Per-host swap configuration (all hosts have identical 32GB RAM)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Swap file creation fails on rebuild | Medium | Low | NixOS handles automatically; verify with `nixos-rebuild build` first |
| SSD wear from swap | Low | Low | `discardPolicy = "once"` minimizes writes; earlyoom reduces swap usage |
| Performance degradation when swapping | Low | Low | 16GB buffer means swapping is rare; earlyoom intervenes before heavy swap |
| Build evaluation error | Medium | Very Low | Test with `nix flake check` before rebuild |

## Implementation Phases

### Phase 1: Add Swap Configuration [NOT STARTED]

**Goal**: Add 16GB swap file configuration to configuration.nix

**Tasks**:
- [ ] Add `swapDevices` configuration block after earlyoom section
- [ ] Configure swap file at `/var/lib/swapfile` with 16GB size
- [ ] Enable SSD TRIM with `discardPolicy = "once"`
- [ ] Add documentation comment explaining three-tier memory management

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add swap configuration section

**Code to add** (after earlyoom section, around line 300):

```nix
  # ==========================================================================
  # Swap Configuration - Memory Safety Buffer
  # ==========================================================================
  # Three-tier memory management:
  # 1. Normal operation: Applications use RAM freely
  # 2. Memory pressure: Kernel moves inactive pages to swap
  # 3. Critical: earlyoom terminates memory-hungry processes at 10% free
  #
  # 16GB swap provides buffer before earlyoom intervention, especially useful
  # for memory spikes from development tools (Claude, Node.js, browsers).
  #
  # Note: For hibernation support, swap must be >= RAM size (32GB+).
  # Current configuration is for memory safety only, not hibernation.
  #
  # See: specs/25_configure_swap_space_nixos
  # ==========================================================================
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 16 * 1024;  # 16GB in MiB
    discardPolicy = "once";  # TRIM on activation for SSD optimization
  }];
```

**Verification**:
- [ ] File saves without syntax errors
- [ ] Nix expression is well-formed

---

### Phase 2: Build Verification [NOT STARTED]

**Goal**: Verify configuration builds without errors before activation

**Tasks**:
- [ ] Run `nix flake check` to validate flake
- [ ] Run `nixos-rebuild build --flake .#hamsa` (or current host) to build without activating
- [ ] Review build output for any warnings

**Timing**: 15 minutes

**Commands**:
```bash
cd /home/benjamin/.dotfiles
nix flake check
nixos-rebuild build --flake .#hamsa
```

**Verification**:
- [ ] `nix flake check` passes
- [ ] `nixos-rebuild build` completes successfully
- [ ] No evaluation errors or warnings related to swapDevices

---

### Phase 3: System Activation and Testing [NOT STARTED]

**Goal**: Apply configuration and verify swap is active

**Tasks**:
- [ ] Run `sudo nixos-rebuild switch --flake .#<hostname>` to activate
- [ ] Verify swap file was created at `/var/lib/swapfile`
- [ ] Verify swap is active using `swapon --show`
- [ ] Verify swap size using `free -h`
- [ ] Check earlyoom detects swap: `journalctl -u earlyoom | head -20`

**Timing**: 15 minutes

**Commands**:
```bash
# Apply configuration
sudo nixos-rebuild switch --flake .#hamsa

# Verify swap
ls -la /var/lib/swapfile
swapon --show
free -h

# Check earlyoom
journalctl -u earlyoom | head -20
```

**Verification**:
- [ ] Swap file exists at `/var/lib/swapfile`
- [ ] `swapon --show` shows 16G swap
- [ ] `free -h` shows 16Gi swap
- [ ] earlyoom logs show it's monitoring swap threshold

---

## Testing & Validation

- [ ] Configuration builds without errors
- [ ] Swap file is created automatically (16GB)
- [ ] Swap is active after reboot
- [ ] earlyoom continues to function with swap enabled
- [ ] No performance degradation under normal workload

## Artifacts & Outputs

- `configuration.nix` - Modified with swap configuration
- Swap file at `/var/lib/swapfile` (created by NixOS on rebuild)

## Rollback/Contingency

If swap causes issues:

1. **Immediate rollback**: Boot previous NixOS generation from bootloader
2. **Disable swap**: Set `swapDevices = []` and rebuild
3. **Manual cleanup**: If needed, `sudo swapoff -a && sudo rm /var/lib/swapfile`

The configuration is non-destructive - removing the swapDevices configuration simply prevents swap from being created/enabled on next rebuild.
