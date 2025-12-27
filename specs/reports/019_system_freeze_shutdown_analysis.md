# System Freeze and Shutdown Issues - Root Cause Analysis and Remediation Plan

**Date**: December 24, 2025  
**System**: Framework Laptop 13 (AMD Ryzen AI 300 Series)  
**OS**: NixOS 26.05 (Yarara) with Linux 6.18.1  
**Host**: hamsa

## Executive Summary

The system experiences periodic freezes where most programs become unresponsive (WiFi disconnection fails, browser won't open, applications hang) without a complete system freeze. When attempting shutdown, systemd services timeout in sequence, requiring up to 5+ minutes for forced termination. Root cause analysis identifies **NetworkManager mutex deadlocks** caused by MediaTek WiFi driver (mt7925e) kernel worker threads blocking critical network operations.

## Symptoms

### During System Freeze
- WiFi cannot be disconnected via NetworkManager
- Browser fails to open or respond
- Most GUI applications become unresponsive
- System is not completely frozen (some operations still work)
- No keyboard/mouse freezing

### During Shutdown Sequence
Systemd services timeout in this order:
1. **Avahi mDNS/DNS-SD Stack** (90s timeout)
2. **User Manager for UID 1000** (120s timeout) 
3. **Location Lookup Service (geoclue)** (90s timeout)
4. **Generate shutdown ramfs** (service hangs)
5. **Logrotate Service** (90s timeout)

Total shutdown time: 5-7+ minutes (vs normal 5-10 seconds)

## Root Cause Analysis

### Primary Issue: NetworkManager Mutex Deadlock

**Evidence from kernel logs** (configuration.nix:12:23:19):

```
INFO: task avahi-daemon:1203 blocked for more than 122 seconds.
INFO: task avahi-daemon:1203 is blocked on a mutex likely owned by task NetworkManager:1349.

INFO: task NetworkManager:1349 blocked for more than 122 seconds.
INFO: task NetworkManager:1349 is blocked on a mutex likely owned by task kworker/u98:2:40429.

INFO: task wpa_supplicant:1572 blocked for more than 122 seconds.
INFO: task wpa_supplicant:1572 is blocked on a mutex likely owned by task NetworkManager:1349.

INFO: task .xdg-desktop-po:2846 blocked for more than 122 seconds.
INFO: task .xdg-desktop-po:2846 is blocked on a mutex likely owned by task NetworkManager:1349.

INFO: task .goa-daemon-wra:2870 blocked for more than 122 seconds.
INFO: task .evolution-cale:2951 blocked for more than 122 seconds.
INFO: task .evolution-addr:3035 blocked for more than 122 seconds.
INFO: task .gnome-calendar:3249 blocked for more than 122 seconds.
INFO: task kworker/u97:3:32641 blocked for more than 122 seconds.
```

**Deadlock Chain**:
```
kworker/u98:2 (kernel worker) 
  ↓ holds mutex
NetworkManager (PID 1349)
  ↓ holds mutex  
avahi-daemon, wpa_supplicant, GNOME services, user applications
  ↓ all blocked waiting
```

### Contributing Factors

#### 1. MediaTek WiFi Driver Issues

**Driver**: mt7925e (MediaTek MT7925 WiFi 7 card)

**Problems identified**:
- Kernel worker threads (`kworker/u98:*`) deadlock during WiFi operations
- P2P device errors: `error setting IPv4 forwarding to '0': Resource temporarily unavailable`
- Occurs repeatedly during WiFi state changes (suspend/resume, network switching)
- Configuration.nix:39-42 applies workarounds for suspend but not for general operation

**Current mitigation in place** (configuration.nix:39-42):
```nix
boot.extraModprobeConfig = ''
  options snd_hda_intel power_save=0 power_save_controller=N
  options mt7921e disable_aspm=1  # Wrong driver module name!
'';
```

**Critical error**: The configuration disables ASPM for `mt7921e`, but the actual driver is `mt7925e`. This mitigation is **not being applied**.

#### 2. Service Timeout Configurations

Current timeouts (all default NixOS values):

| Service | TimeoutStopUSec | Actual Behavior |
|---------|----------------|-----------------|
| NetworkManager | 2min | Forced kill after timeout |
| avahi-daemon | 1min 30s | Waits for NetworkManager mutex |
| geoclue | 1min 30s | Waits for NetworkManager mutex |
| user@1000 | 2min | Waits for GNOME services |
| logrotate | 1min 30s | Standard oneshot timeout |

**Issue**: Services wait sequentially, not in parallel, causing cumulative delays.

#### 3. NetworkManager Configuration Issues

**wpa_supplicant vs iwd conflict**:
- Configuration.nix:48-55 uses NetworkManager with default wpa_supplicant backend
- Comment suggests iwd backend for "better WiFi performance" but not enabled
- wpa_supplicant is explicitly involved in deadlock chain

**IPv4 Forwarding Errors**:
```
device (p2p-dev-wlp192s0): error setting IPv4 forwarding to '0': Resource temporarily unavailable
```
- Occurs on every WiFi state change
- P2P device shouldn't need forwarding configuration
- Indicates kernel/driver resource exhaustion

#### 4. Service Dependency Cascade

**Dependency chain causing sequential timeouts**:

```
NetworkManager (deadlocked)
  ↓ blocks
avahi-daemon (timeout #1: 90s)
  ↓ blocks
geoclue (timeout #2: 90s) 
  ↓ blocks
GNOME Online Accounts, Evolution, Calendar
  ↓ blocks  
user@1000 session (timeout #3: 120s)
  ↓ delays
shutdown ramfs generation (timeout #4: variable)
logrotate (timeout #5: 90s)
```

Total: 390+ seconds (6.5 minutes minimum)

#### 5. Geoclue Restart Loop

**Evidence** (configuration.nix:69-81):
- Geoclue restarts every 60 seconds: "Service not used for 60 seconds. Shutting down.."
- Immediately restarted by automatic-timezoned/localtimed
- Each restart attempts to communicate with NetworkManager
- During deadlock, these restarts queue up and timeout individually

**Configuration issue** (configuration.nix:86-92):
```nix
# services.automatic-timezoned.enable = true;  # Commented out
services.localtimed.enable = true;  # Uses geoclue for timezone
```

Both services trigger geoclue, creating unnecessary location lookups.

## Remediation Plan

### Phase 1: Critical Fixes (Immediate - Prevent Deadlocks)

#### Fix 1.1: Correct WiFi Driver Configuration

**File**: `configuration.nix:39-42`

**Change**:
```nix
boot.extraModprobeConfig = ''
  options snd_hda_intel power_save=0 power_save_controller=N
  # Fix: Use correct driver name mt7925e instead of mt7921e
  options mt7925e disable_aspm=1
  # Add: Disable problematic power management features
  options mt7925e power_save=0
'';
```

**Rationale**: 
- ASPM (Active State Power Management) causes PCIe bus issues with MediaTek drivers
- Power management transitions trigger kernel worker deadlocks
- This was already attempted but with wrong driver name

#### Fix 1.2: Switch NetworkManager to iwd Backend

**File**: `configuration.nix:48-55`

**Change**:
```nix
networking = {
  networkmanager = {
    enable = true;
    wifi.backend = "iwd";  # Enable - better mt7925e compatibility
  };
  wireless.enable = false;
};
```

**Rationale**:
- iwd has better MediaTek WiFi 7 driver support
- Eliminates wpa_supplicant from deadlock chain
- Already suggested in configuration comments
- Reduces kernel worker contention

#### Fix 1.3: Fix Geoclue Restart Loop

**File**: `configuration.nix:86-92`

**Option A** (Recommended - Static timezone):
```nix
# Disable automatic timezone detection to prevent geoclue restart loop
# services.automatic-timezoned.enable = false;
services.localtimed.enable = false;

# Set static timezone
time.timeZone = "America/New_York";  # Adjust to your timezone

# Keep time synchronization
services.timesyncd.enable = true;
```

**Option B** (Keep automatic timezone with rate limiting):
```nix
# Keep automatic timezone but prevent excessive geoclue restarts
services.localtimed.enable = true;

# Override geoclue systemd settings
systemd.services.geoclue = {
  serviceConfig = {
    # Prevent restart loop
    Restart = "on-failure";
    RestartSec = "60s";
    # Longer idle timeout
    Environment = "GEOCLUE_INACTIVITY_TIMEOUT=600";
  };
};
```

**Rationale**:
- Static timezone eliminates unnecessary geoclue lookups
- Reduces NetworkManager communication attempts during deadlock
- Most users don't need automatic timezone detection

### Phase 2: Improve Shutdown Reliability (Reduce Timeout Impact)

#### Fix 2.1: Reduce Service Stop Timeouts

**File**: `configuration.nix` (add new section)

**Add**:
```nix
# Reduce shutdown timeout cascade
systemd.services = {
  NetworkManager = {
    serviceConfig = {
      # Reduce from 2min to 30s - force kill faster on deadlock
      TimeoutStopSec = "30s";
    };
  };
  
  avahi-daemon = {
    serviceConfig = {
      # Reduce from 90s to 20s
      TimeoutStopSec = "20s";
    };
  };
  
  geoclue = {
    serviceConfig = {
      # Reduce from 90s to 15s
      TimeoutStopSec = "15s";
    };
  };
};
```

**Rationale**:
- Doesn't fix root cause but limits damage
- Reduces total shutdown time from 6.5min to ~1.5min worst case
- Services that are deadlocked can't gracefully stop anyway

#### Fix 2.2: Add NetworkManager Watchdog

**File**: `configuration.nix` (add to systemd.services.NetworkManager section)

**Add**:
```nix
systemd.services.NetworkManager = {
  serviceConfig = {
    TimeoutStopSec = "30s";
    # Add watchdog to detect hangs
    WatchdogSec = "3min";
    Restart = "on-watchdog";
  };
};
```

**Rationale**:
- Automatically restarts NetworkManager if it hangs for 3 minutes
- May prevent system freeze from becoming permanent
- Gives users a chance to recover without reboot

### Phase 3: Advanced Mitigations (If Issues Persist)

#### Fix 3.1: Disable WiFi P2P Device

**File**: `configuration.nix`

**Add**:
```nix
boot.extraModprobeConfig = ''
  # ... existing config ...
  
  # Disable P2P device if not needed (reduces IPv4 forwarding errors)
  options mt7925e disable_p2p=1
'';
```

**Rationale**:
- P2P device (wlp192s0-p2p-dev) causes repeated IPv4 forwarding errors
- Most users don't use WiFi Direct/P2P features
- Reduces kernel worker contention

#### Fix 3.2: Kernel Command Line Parameters

**File**: `configuration.nix:31-36`

**Add**:
```nix
boot.kernelParams = [
  "amd_pstate=active"
  "amdgpu.dcdebugmask=0x10"
  "rtc_cmos.use_acpi_alarm=1"
  # Add: Reduce hung task timeout to get earlier warnings
  "hung_task_timeout_secs=60"
  # Add: WiFi driver debugging (if needed for further analysis)
  # "mt7925e.debug=0x00000001"
];
```

**Rationale**:
- Earlier detection of hung tasks (60s instead of 122s)
- Helps identify deadlocks before they cascade
- Optional debug output for driver issues

#### Fix 3.3: Alternative WiFi Firmware

**File**: `configuration.nix`

**Add**:
```nix
# Use latest WiFi firmware (may fix mt7925e issues)
hardware.enableRedistributableFirmware = true;
hardware.firmware = with pkgs; [
  linux-firmware
];
```

**Rationale**:
- MediaTek WiFi 7 is very new hardware
- Firmware updates may fix kernel worker deadlocks
- Already likely enabled but worth confirming

### Phase 4: Monitoring and Diagnostics

#### Add Systemd Hang Detection

**File**: Create `/etc/nixos/scripts/detect-hangs.sh`

**Content**:
```bash
#!/usr/bin/env bash
# Monitor for NetworkManager hangs and log details

while true; do
  # Check if NetworkManager is in blocked state
  if journalctl --since "2 minutes ago" -u NetworkManager | grep -q "blocked"; then
    echo "[$(date)] NetworkManager deadlock detected!" >> /var/log/nm-hangs.log
    
    # Log stack traces
    ps aux | grep NetworkManager >> /var/log/nm-hangs.log
    
    # Log WiFi state
    nmcli device status >> /var/log/nm-hangs.log
    
    # Notify user
    notify-send "System Issue" "NetworkManager deadlock detected. Check logs."
  fi
  
  sleep 120
done
```

**NixOS Configuration**:
```nix
systemd.services.nm-hang-monitor = {
  description = "Monitor NetworkManager for deadlocks";
  wantedBy = [ "multi-user.target" ];
  script = "${pkgs.bash}/bin/bash /etc/nixos/scripts/detect-hangs.sh";
  serviceConfig = {
    Restart = "always";
    RestartSec = "10s";
  };
};
```

**Rationale**:
- Provides early warning of issues
- Collects diagnostic data for upstream bug reports
- User notification before system becomes unusable

## Implementation Priority

### Must Do (Prevents Deadlocks)
1. **Fix 1.1**: Correct WiFi driver configuration (mt7921e → mt7925e)
2. **Fix 1.2**: Switch to iwd WiFi backend
3. **Fix 1.3**: Fix geoclue restart loop

### Should Do (Limits Impact)
4. **Fix 2.1**: Reduce service timeouts
5. **Fix 2.2**: Add NetworkManager watchdog

### Optional (If Problems Persist)
6. **Fix 3.1**: Disable P2P device
7. **Fix 3.2**: Kernel command line tuning
8. **Fix 3.3**: Verify latest firmware
9. **Phase 4**: Add monitoring

## Testing Plan

### After Implementing Phase 1 Fixes

1. **Reboot and verify services start**:
   ```bash
   sudo systemctl status NetworkManager
   sudo systemctl status avahi-daemon
   sudo systemctl status geoclue
   ```

2. **Test WiFi stability**:
   ```bash
   # Monitor for P2P errors
   journalctl -fu NetworkManager
   
   # Test WiFi reconnection
   nmcli device disconnect wlp192s0
   nmcli device connect wlp192s0
   ```

3. **Test suspend/resume cycle**:
   ```bash
   systemctl suspend
   # Wait 30s, wake system
   journalctl -b | grep -E "(blocked|mutex|hung_task)"
   ```

4. **Test shutdown**:
   ```bash
   # Time the shutdown
   time sudo systemctl poweroff
   ```
   Should complete in < 30 seconds.

### Success Criteria

- ✅ No "blocked on mutex" messages in kernel logs
- ✅ No NetworkManager deadlocks during normal operation
- ✅ Shutdown completes in < 30 seconds
- ✅ WiFi remains stable through suspend/resume cycles
- ✅ No P2P IPv4 forwarding errors (if P2P disabled)

## Upstream Bug Reports

This issue should be reported to:

1. **Linux Kernel** (MediaTek driver):
   - Component: `drivers/net/wireless/mediatek/mt76/mt7925`
   - Issue: Kernel worker threads deadlock during WiFi state changes
   - Evidence: Mutex ownership chain in kernel logs

2. **NetworkManager**:
   - Issue: Deadlock when WiFi driver kernel workers hold locks
   - Request: Better timeout handling for driver-level deadlocks

3. **NixOS** (low priority):
   - Note: `mt7921e` vs `mt7925e` naming confusion in documentation

## References

- **Hardware**: Framework Laptop 13 (AMD Ryzen AI 300 Series)
- **WiFi Card**: MediaTek MT7925 (WiFi 7)
- **Current Config**: `/home/benjamin/.dotfiles/configuration.nix`
- **Kernel Version**: Linux 6.18.1
- **Known Issues**: 
  - Ryzen AI 300 suspend/resume (already mitigated in configuration.nix:15-43)
  - MediaTek mt7925e ASPM issues (not yet properly mitigated)

## Related Documentation

- `docs/ryzen-ai-300-compatibility.md` - Suspend/resume fixes
- `configuration.nix:15-43` - Existing Ryzen AI 300 workarounds
- `configuration.nix:46-55` - NetworkManager configuration
- `configuration.nix:68-96` - Location services and timezone

---

**Next Steps**: Implement Phase 1 fixes in configuration.nix and test for 24-48 hours.
