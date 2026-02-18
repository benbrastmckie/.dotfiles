# Research Report: Configure Swap Space in NixOS

- **Task**: 25 - Configure swap space in NixOS configuration
- **Started**: 2026-02-11T00:00:00Z
- **Completed**: 2026-02-11T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Local configuration files (configuration.nix, hardware-configuration.nix for all hosts)
  - NixOS Wiki - Swap documentation
  - NixOS Discourse community discussions
  - nixpkgs/nixos/modules/config/swap.nix source code
- **Artifacts**: specs/25_configure_swap_space_nixos/reports/research-001.md
- **Standards**: report-format.md, nix.md

## Executive Summary

- System has 32GB RAM with no swap configured (all hosts have `swapDevices = []`)
- earlyoom is already configured for userspace OOM prevention (freeMemThreshold = 10%)
- Recommended approach: Add 8-16GB swap file using `swapDevices` with automatic file creation
- zram is a viable alternative/complement for compressed in-memory swap
- Swap file approach is simpler than partition (no repartitioning needed)
- Hibernation requires swap >= RAM size (not in task scope, but noted for reference)

## Context & Scope

The task requires configuring swap space as a safety net to prevent OOM killer from terminating processes during memory spikes. The system currently has:
- 32GB RAM (~30Gi usable)
- No swap configured
- earlyoom service enabled (kills processes at 10% free RAM threshold)

**Goal**: Add 8-16GB swap as additional memory buffer before earlyoom or kernel OOM killer intervenes.

## Findings

### Current Configuration State

All three hosts (garuda, hamsa, nandi) have identical swap configuration:
```nix
swapDevices = [ ];
```

The system already has memory management via earlyoom in `configuration.nix`:
```nix
services.earlyoom = {
  enable = true;
  freeMemThreshold = 10;
  freeSwapThreshold = 10;
  enableNotifications = true;
  extraArgs = [
    "--avoid" "^(gnome-shell|Xwayland|niri)$"
    "--prefer" "^(claude|node|npm)$"
  ];
};
```

### NixOS Swap Configuration Options

#### swapDevices Configuration

The `swapDevices` option supports the following attributes:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `device` | string | required | Path to swap device or file (e.g., `/var/lib/swapfile`) |
| `label` | string | null | Device label (alternative to device path) |
| `size` | int (MiB) | null | When set, creates swap file of specified size automatically |
| `priority` | int (0-32767) | null | Higher values = higher priority; null lets kernel assign |
| `options` | list of strings | `["defaults"]` | Mount options (e.g., `["nofail"]`) |
| `discardPolicy` | enum | null | SSD TRIM: `"once"`, `"pages"`, or `"both"` |
| `randomEncryption` | bool/submodule | false | Encrypt with random key at boot (prevents hibernation) |

#### Swap File vs Partition

| Approach | Pros | Cons |
|----------|------|------|
| **Swap File** | No repartitioning, easy resize, automatic creation by NixOS | Slightly slower on some filesystems, ZFS incompatible |
| **Swap Partition** | Fastest, hibernation-friendly, ZFS compatible | Requires repartitioning, harder to resize |

**Recommendation**: Swap file is preferred for this use case due to simplicity.

#### zramSwap Alternative

zram provides compressed in-memory swap, which can complement or replace disk swap:

```nix
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 30;  # Use 30% of RAM for zram
  priority = 100;      # Higher priority than disk swap
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable zram swap device |
| `algorithm` | string | "lzo" | Compression algorithm (zstd, lz4, lzo) |
| `memoryPercent` | int | 50 | Percentage of RAM for zram |
| `memoryMax` | int | null | Maximum memory in bytes |
| `priority` | int | 5 | Swap priority |

**Note**: Do not use zram and zswap simultaneously.

### Swap Size Recommendations

For systems with 32GB RAM without hibernation:

| Use Case | Recommended Size | Rationale |
|----------|-----------------|-----------|
| Safety net only | 4-8GB | Catches memory spikes, earlyoom handles most cases |
| Development workload | 8-16GB | Larger buffers for memory-intensive tools |
| Hibernation required | 32GB+ | Must fit entire RAM contents |

The task specifies 8-16GB, which aligns with development workload recommendations.

### Configuration Examples

#### Minimal Swap File (Recommended)

```nix
# In configuration.nix or hardware-configuration.nix
swapDevices = [{
  device = "/var/lib/swapfile";
  size = 16 * 1024;  # 16GB in MiB
}];
```

#### Swap File with SSD Optimization

```nix
swapDevices = [{
  device = "/var/lib/swapfile";
  size = 16 * 1024;
  discardPolicy = "once";  # TRIM on activation
}];
```

#### Combined zram + Swap File

```nix
# zram as primary (fast, compressed in-memory)
zramSwap = {
  enable = true;
  algorithm = "zstd";
  memoryPercent = 25;  # 8GB of 32GB
  priority = 100;
};

# Disk swap as fallback
swapDevices = [{
  device = "/var/lib/swapfile";
  size = 8 * 1024;  # 8GB
  priority = 10;    # Lower priority than zram
}];
```

### Integration with earlyoom

The existing earlyoom configuration references swap usage:
```nix
freeSwapThreshold = 10;  # Consider swap in OOM decisions
```

With swap enabled:
1. Memory pressure first spills to swap
2. earlyoom monitors both RAM and swap usage
3. When both RAM and swap are 90% full, earlyoom intervenes
4. This provides more time before process termination

### Deployment Considerations

**File Location**: `/var/lib/swapfile` is the conventional location for NixOS swap files.

**Activation**: Adding to `swapDevices` with `size` parameter causes NixOS to:
1. Create the swap file automatically on rebuild
2. Format it with `mkswap`
3. Enable it with `swapon`
4. Add entry to `/etc/fstab`

**Per-Host vs Shared Config**: Since all hosts have 32GB RAM, the swap configuration can go in `configuration.nix`. If hosts had different RAM amounts, host-specific hardware-configuration.nix would be more appropriate.

## Decisions

1. **Swap type**: Use swap file (not partition) for simplicity and flexibility
2. **Swap size**: 16GB provides adequate safety margin for development workloads
3. **Location**: `/var/lib/swapfile` following NixOS conventions
4. **SSD optimization**: Enable `discardPolicy = "once"` for SSD TRIM support
5. **zram**: Optional enhancement; can be added later if disk swap proves insufficient
6. **Config location**: Add to `configuration.nix` (shared across all hosts)

## Recommendations

1. **Primary Implementation**: Add 16GB swap file to `configuration.nix`:
   ```nix
   swapDevices = [{
     device = "/var/lib/swapfile";
     size = 16 * 1024;
     discardPolicy = "once";
   }];
   ```

2. **Test Strategy**: After `nixos-rebuild switch`:
   - Verify swap with `free -h` or `swapon --show`
   - Check earlyoom detects swap: `journalctl -u earlyoom`

3. **Optional Enhancement**: Consider zram for faster compressed swap as first tier, keeping disk swap as fallback.

4. **Documentation**: Add comment explaining the three-tier memory management:
   - Tier 1: zram (optional, compressed in-memory)
   - Tier 2: disk swap (safety buffer)
   - Tier 3: earlyoom (process termination as last resort)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Swap file creation fails | Low | Medium | NixOS handles automatically; verify with `nixos-rebuild build` first |
| SSD wear from swap | Low | Low | `discardPolicy = "once"` minimizes writes; earlyoom reduces swap usage |
| Performance degradation when swapping | Medium | Low | 16GB buffer means swapping is rare; zram can mitigate |
| Hibernation incompatibility | N/A | N/A | Task scope excludes hibernation; can resize later if needed |

## Appendix

### References

- [NixOS Wiki - Swap](https://wiki.nixos.org/wiki/Swap)
- [NixOS Discourse - How to add swap after installation](https://discourse.nixos.org/t/how-to-add-a-swap-after-nixos-installation/41742)
- [nixpkgs swap.nix source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/swap.nix)
- [NixOS Discourse - zram vs zswap configuration](https://discourse.nixos.org/t/configuring-zram-and-zswap-parameters-for-optimal-performance/47852)
- [MyNixOS - swapDevices options](https://mynixos.com/nixpkgs/option/swapDevices)
- [MyNixOS - zramSwap options](https://mynixos.com/options/zramSwap)
- [How Much Swap Should You Use in Linux?](https://itsfoss.com/swap-size/)

### Search Queries Used

- "NixOS swapDevices configuration swap file vs partition 2025 2026"
- "NixOS zramSwap configuration enable options 2025"
- "Linux swap size recommendation 16GB 32GB RAM 2025 hibernation"

### System State

```
Current RAM: 32GB (30Gi usable)
Current Swap: 0B
earlyoom: enabled (10% threshold)
Hosts: garuda, hamsa, nandi (all x86_64-linux)
```
