# WiFi Configuration Guide

## Current Status: ✅ WORKING

The mt7925e WiFi 6E/7 chip works correctly with NetworkManager's default wpa_supplicant backend.

## Hardware Information

- **WiFi Chip**: MediaTek MT7925E
- **Standards**: WiFi 6E (802.11ax) / WiFi 7 (802.11be)
- **Frequency Bands**: 2.4 GHz, 5 GHz, 6 GHz
- **Kernel Driver**: `mt7925e` module
- **System**: Ryzen AI 300 series laptop

## Working Configuration

### NetworkManager Setup (configuration.nix)

```nix
networking = {
  networkmanager = {
    enable = true;
    # wifi.backend = "iwd";  # DO NOT UNCOMMENT - breaks WiFi
  };
  # Note: wireless.enable is automatically managed by NetworkManager
  # Do NOT set it manually or use lib.mkForce - let NetworkManager control wpa_supplicant
};
```

**Key points:**
- Use NetworkManager with default wpa_supplicant backend
- Do NOT set `networking.wireless.enable` manually
- Do NOT use `wifi.backend = "iwd"` (doesn't work with this hardware)

### Kernel Module Configuration (configuration.nix)

```nix
boot.extraModprobeConfig = ''
  options mt7925e disable_aspm=1 power_save=0
'';
```

**Purpose:** Disables PCIe Active State Power Management and power saving for stability.

### Firmware (hosts/hamsa/hardware-configuration.nix)

```nix
hardware.enableRedistributableFirmware = true;
```

**Required** for mt7925e firmware support.

## Common Mistakes to Avoid

### ❌ DO NOT: Use lib.mkForce on wireless.enable

```nix
networking.wireless.enable = lib.mkForce false;  # BREAKS WiFi!
```

**Why it breaks:** NetworkManager's NixOS module needs to set `wireless.enable = true` to configure wpa_supplicant with D-Bus control. Using `lib.mkForce` prevents this, leaving NetworkManager without a WiFi backend.

### ❌ DO NOT: Manually set wireless.enable

```nix
networking.wireless.enable = false;  # NetworkManager can't override this
```

**Why it breaks:** NetworkManager can't override this setting to enable wpa_supplicant.

### ❌ DO NOT: Enable iwd backend

```nix
networking.networkmanager.wifi.backend = "iwd";  # Doesn't work with mt7925e
```

**Why it breaks:** The iwd backend doesn't work with this specific hardware configuration (reason unknown).

## Troubleshooting

### If WiFi Stops Working

**Symptoms:**
- Build succeeds
- WiFi stops working after reboot
- No WiFi networks visible in `nmcli device wifi list`

**Check these in configuration.nix:**

1. **Remove any manual wireless.enable settings:**
   ```nix
   # Remove this line if present:
   networking.wireless.enable = ...;  # Remove entirely
   ```

2. **Ensure iwd is commented out:**
   ```nix
   networking.networkmanager.wifi.backend = "iwd";  # Comment this out
   ```

3. **Rebuild and reboot:**
   ```bash
   sudo nixos-rebuild switch --flake .#hamsa
   sudo reboot
   ```

### Verification Commands

After a successful build and reboot:

```bash
# Check that wpa_supplicant is running (should show active)
systemctl status wpa_supplicant

# Check that iwd is not running (should show "could not be found")
systemctl status iwd

# List available WiFi networks
nmcli device wifi list

# Check WiFi connection status
nmcli device status
```

## How NetworkManager WiFi Works

NetworkManager automatically manages `networking.wireless.enable` based on the backend:

```nix
# From NixOS networkmanager.nix module:
(mkIf (!delegateWireless && !enableIwd) {
  wireless.enable = true;            # Auto-enabled for wpa_supplicant
  wireless.autoDetectInterfaces = false;
  wireless.dbusControlled = true;    # NetworkManager controls via D-Bus
})
```

**Important:** Let NetworkManager handle this automatically. Manual intervention breaks the configuration.

## Summary

**✅ DO:**
- Use NetworkManager with default settings
- Let NetworkManager manage `wireless.enable` automatically
- Keep `wifi.backend = "iwd"` commented out
- Reboot after configuration changes to test WiFi

**❌ DON'T:**
- Set `networking.wireless.enable` manually
- Use `lib.mkForce` on `wireless.enable`
- Enable `wifi.backend = "iwd"`
- Add unnecessary powersave or scanRandMacAddress settings
