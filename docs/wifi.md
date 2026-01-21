# WiFi Configuration (CRITICAL)

## Overview

This system uses a **MediaTek MT7925E WiFi 6E/7 chip**, which requires specific configuration to work properly. This documentation exists because the WiFi configuration is fragile and has broken multiple times due to configuration changes.

**⚠️ WARNING**: Do not modify the WiFi configuration without reading this document first.

## Critical Configuration Requirements

The WiFi configuration in `configuration.nix` MUST include these settings:

```nix
networking = {
  networkmanager = {
    enable = true;
    wifi = {
      backend = "iwd";           # REQUIRED - do not change to wpa_supplicant!
      powersave = false;         # REQUIRED - prevents instability
      scanRandMacAddress = false; # REQUIRED - prevents connection issues
    };
  };
  wireless.enable = lib.mkForce false;  # Disable standalone wpa_supplicant
};
```

### Why These Settings Are Required

1. **`backend = "iwd"`** (MOST CRITICAL)
   - The mt7925e is a WiFi 6E/7 chip that supports 6 GHz networks
   - `wpa_supplicant` has known issues with WiFi 6E/7 and 6 GHz networks
   - `iwd` (iNet wireless daemon) handles WiFi 6E scanning and regulatory domain properly
   - **Removing this setting will break WiFi completely**

2. **`powersave = false`**
   - Disables WiFi power saving mode
   - The mt7925e chip has stability issues with power saving enabled
   - Prevents random disconnections and performance issues

3. **`scanRandMacAddress = false`**
   - Disables MAC address randomization during WiFi scans
   - Some networks have issues with randomized MAC addresses
   - Improves connection reliability

4. **`wireless.enable = lib.mkForce false`**
   - Prevents standalone `wpa_supplicant` from starting
   - NetworkManager manages WiFi when this is disabled
   - The `lib.mkForce` is necessary to override any default settings

## What Breaks WiFi

### Immediate Breakage (WiFi stops working completely)

1. **Removing `backend = "iwd"`**
   - NetworkManager defaults to `wpa_supplicant`
   - `wpa_supplicant` cannot properly handle WiFi 6E/7
   - Result: No WiFi networks visible, cannot connect

2. **Setting `backend = "wpa_supplicant"`**
   - Same as removing the backend setting
   - Explicitly uses the incompatible backend

3. **Enabling `networking.wireless.enable = true`**
   - Runs standalone `wpa_supplicant` alongside NetworkManager
   - Creates conflicts between network managers
   - Result: Unpredictable WiFi behavior

### Degraded Performance

1. **Enabling `powersave = true`**
   - WiFi becomes unstable
   - Random disconnections
   - Slow or intermittent connectivity

2. **Enabling `scanRandMacAddress = true`**
   - Some networks may refuse connections
   - Intermittent connection issues

## Hardware Information

- **Chip Model**: MediaTek MT7925E
- **Standards**: WiFi 6E (802.11ax) / WiFi 7 (802.11be)
- **Frequency Bands**: 2.4 GHz, 5 GHz, 6 GHz
- **Kernel Driver**: `mt7925e` module
- **Firmware Package**: Included in `hardware.enableRedistributableFirmware = true`

### Kernel Module Configuration

The kernel module is configured in `configuration.nix` with specific options:

```nix
boot.extraModprobeConfig = ''
  options mt7925e disable_aspm=1 power_save=0
'';
```

- `disable_aspm=1`: Disables PCIe Active State Power Management for stability
- `power_save=0`: Disables module-level power saving

## Troubleshooting

### WiFi Not Working After Rebuild

1. **Check the backend setting**:
   ```bash
   grep -A 10 "networking =" configuration.nix | grep backend
   ```
   Should show: `backend = "iwd";`

2. **Verify iwd is running**:
   ```bash
   systemctl status iwd
   ```
   Should be active and running.

3. **Check NetworkManager WiFi backend**:
   ```bash
   nmcli general status
   ```
   Should show: `wifi.backend: iwd`

4. **Verify wireless.enable is false**:
   ```bash
   grep "wireless.enable" configuration.nix
   ```
   Should show: `wireless.enable = lib.mkForce false;`

### Rollback to Working Generation

If WiFi breaks after a rebuild:

1. **List recent generations**:
   ```bash
   nixos-rebuild list-generations | head -20
   ```

2. **Boot into a working generation**:
   - Reboot and select the generation from the bootloader
   - Or: `sudo nixos-rebuild switch --rollback`

3. **Check what changed**:
   ```bash
   git diff HEAD~1 configuration.nix | grep -A 20 "networking"
   ```

### Finding a Working Configuration

If you need to identify which generation has working WiFi:

1. **Test generations systematically**:
   ```bash
   sudo nixos-rebuild switch --switch-generation <number>
   sudo systemctl restart NetworkManager
   nmcli device wifi list
   ```

2. **Compare configurations**:
   ```bash
   # Show configuration changes in git history
   git log --oneline -- configuration.nix hosts/*/hardware-configuration.nix
   ```

## History of WiFi Issues

### 2026-01-20: WiFi Broken - Missing iwd Backend

**Symptom**: WiFi stopped working after rebuild. No networks visible.

**Cause**: The `backend = "iwd"` setting was removed from `configuration.nix`, causing NetworkManager to fall back to `wpa_supplicant`.

**Fix**: Restored the complete WiFi configuration from commit `f894603` which includes:
- `backend = "iwd"`
- `powersave = false`
- `scanRandMacAddress = false`

**Lesson**: The backend setting is CRITICAL and must never be removed.

### Earlier Issue (commit f894603): WiFi Fixed

The commit message "fixed wifi" (f894603ba52c28c51e7818887251af3a43b2d592) documents the original fix that established the current working configuration. This commit added comprehensive documentation about why these settings are required.

## Testing WiFi Configuration

After any configuration changes that might affect networking:

1. **Before rebuilding**, verify the WiFi settings:
   ```bash
   grep -A 10 "networking =" configuration.nix | grep -E "(backend|powersave|scanRandMacAddress)"
   ```

2. **After rebuilding**, test WiFi:
   ```bash
   nmcli device wifi list
   nmcli device wifi connect "SSID" password "password"
   ```

3. **Verify backend is iwd**:
   ```bash
   nmcli -f WIFI-PROPERTIES general
   ```

## References

- Configuration file: `configuration.nix` (lines 53-68)
- Hardware configuration: `hosts/hamsa/hardware-configuration.nix`
- Working commit: `f894603ba52c28c51e7818887251af3a43b2d592`
- Kernel module: `mt7925e`
- NetworkManager documentation: https://networkmanager.dev/
- iwd documentation: https://iwd.wiki.kernel.org/

## Quick Reference Commands

```bash
# Check WiFi status
nmcli device wifi list
iwctl station wlan0 show

# Restart networking (if needed)
sudo systemctl restart NetworkManager
sudo systemctl restart iwd

# View WiFi backend
nmcli -f WIFI-PROPERTIES general

# Check iwd status
systemctl status iwd

# View kernel module parameters
systool -v -m mt7925e
```

## Summary

**DO NOT**:
- Remove `backend = "iwd"`
- Change backend to `wpa_supplicant`
- Enable `networking.wireless.enable`
- Enable WiFi power saving
- Remove any of the critical WiFi settings

**DO**:
- Keep all three WiFi settings (`backend`, `powersave`, `scanRandMacAddress`)
- Test WiFi after any networking-related configuration changes
- Refer to this documentation before modifying WiFi configuration
- Keep the warning comments in `configuration.nix`

**When in doubt**: Check commit `f894603` for the known-working configuration.
