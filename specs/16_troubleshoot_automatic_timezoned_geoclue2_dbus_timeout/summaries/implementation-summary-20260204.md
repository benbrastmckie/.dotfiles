# Implementation Summary: Task #16

**Completed**: 2026-02-04
**Duration**: ~3 hours (including troubleshooting and fixes)

## Root Cause

The automatic-timezoned service was failing because:
1. geoclue2 has a hardcoded 60-second idle timeout that causes it to shut down
2. **WiFi geolocation was disabled** (`services.geoclue2.enableWifi = false` by default)
3. Without WiFi geolocation, geoclue couldn't determine location before timing out
4. automatic-timezoned crashed on D-Bus disconnection when geoclue shut down

## Solution

Fixed by enabling WiFi geolocation and adding restart resilience:

### 1. Enable WiFi Geolocation (Critical Fix)
```nix
services.geoclue2 = {
  enable = true;
  enableWifi = lib.mkForce true;  # Enable WiFi-based location detection
  # ... static source configuration
};
```

**Key insight**: WiFi geolocation uses WiFi access point data (BSSIDs, signal strength) to determine physical location via BeaconDB. This is separate from WiFi networking and doesn't affect internet connectivity.

### 2. Configure Static Location Fallback
```nix
services.geoclue2 = {
  enableStatic = true;
  staticLatitude = 37.77;    # San Francisco
  staticLongitude = -122.42;
  staticAltitude = 50;       # Required field (meters)
  staticAccuracy = 100000;   # 100km accuracy
};
```

### 3. Add Restart Resilience for automatic-timezoned
```nix
systemd.services.automatic-timezoned = {
  serviceConfig = {
    Restart = "on-failure";
    RestartSec = "30s";
  };
  startLimitBurst = 10;
  startLimitIntervalSec = 300;
};
```

**Note**: The geoclue-agent already has `Restart = "on-failure"` from the NixOS module, so no override needed.

### 4. Timezone Configuration Discovery

Discovered that the NixOS automatic-timezoned module sets `time.timeZone = null` to allow dynamic timezone management via `timedatectl`. Therefore:
- `lib.mkDefault "America/Los_Angeles"` doesn't work as a fallback (gets overridden by module's null)
- automatic-timezoned sets timezone **imperatively** when it succeeds
- No declarative fallback is needed with the restart mechanism

## Files Modified

- `configuration.nix`:
  - Added `enableWifi = lib.mkForce true` to `services.geoclue2`
  - Added static source configuration (latitude, longitude, altitude, accuracy)
  - Added `automatic-timezoned` systemd restart configuration
  - Kept `time.timeZone = lib.mkDefault "America/Los_Angeles"` (for documentation, though overridden by module)

## Verification

After rebuilding:

```bash
# Check WiFi geolocation enabled
cat /etc/geoclue/geoclue.conf | grep -A2 "\[wifi\]"
# Should show: enable=true

# Check static source enabled
cat /etc/geoclue/geoclue.conf | grep -A2 "\[static-source\]"
# Should show: enable=true

# Monitor service (should succeed now)
journalctl -u automatic-timezoned -u geoclue -f

# Verify timezone is set correctly
timedatectl | grep "Time zone"
# Should show: America/Los_Angeles (or auto-detected timezone)

# Check restart configuration
systemctl cat automatic-timezoned | grep Restart
# Should show: Restart=on-failure
```

## Fixes Required During Implementation

1. **Missing staticAltitude**: Added `staticAltitude = 50` (required field)
2. **Conflicting Restart definition**: Used `lib.mkForce` for geoclue-agent Restart (later removed as module default is sufficient)
3. **Conflicting enableWifi definition**: Used `lib.mkForce true` to override module's default `false`
4. **Home Manager collision**: Backed up `.claude/settings.json` to allow Home Manager to manage it

## Expected Behavior

1. automatic-timezoned queries geoclue for location
2. geoclue uses WiFi geolocation (BeaconDB) to determine location quickly
3. If WiFi geolocation fails, static source provides California coordinates
4. Timezone is set automatically before the 60-second timeout
5. If service fails, it restarts automatically (max 10 times per 5 minutes)

## Key Lessons

- **WiFi geolocation ≠ WiFi networking**: `enableWifi` for geoclue is about location detection, not internet connectivity
- **lib.mkForce needed for module overrides**: When NixOS modules set explicit defaults, use `lib.mkForce` to override
- **Restart policies**: `"on-failure"` is sufficient and preferred over `"always"` for long-running services
- **Module design patterns**: automatic-timezoned module sets `time.timeZone = null` to manage timezone imperatively via timedatectl

## References

- [geoclue manual - Arch Linux](https://man.archlinux.org/man/geoclue.5)
- [services.geoclue2 options - MyNixOS](https://mynixos.com/options/services.geoclue2)
- [automatic-timezoned GitHub](https://github.com/maxbrunet/automatic-timezoned)
- [systemd.service documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
