# NixOS Location Services: Best Practices and Configuration

**Date**: December 24, 2025  
**System**: NixOS 26.05 (Yarara)  
**Related**: specs/reports/019_system_freeze_shutdown_analysis.md

## Executive Summary

This report analyzes best practices for configuring geoclue location services on NixOS, specifically addressing the requirement to check location **once at boot after WiFi connects** rather than continuously polling. The goal is to provide location data for applications like GNOME Weather and Calendar while avoiding the overhead of continuous geoclocation requests that can exacerbate NetworkManager issues.

## Current Problem

**Observed behavior** (configuration.nix:68-96):
1. `services.localtimed.enable = true` triggers automatic timezone detection
2. Geoclue restarts every 60 seconds when not actively used
3. Each restart attempts to communicate with NetworkManager
4. During NetworkManager deadlocks, these restart attempts pile up
5. Creates unnecessary network traffic and system load

## Understanding Geoclue Architecture

### What is Geoclue?

Geoclue is a D-Bus service that provides location information using multiple sources:

**Available Sources** (in priority order):
1. **Static source** - Fixed location from `/etc/geolocation` file
2. **Modem GPS** - GPS hardware in cellular modems
3. **Network NMEA** - GPS devices on local network (via avahi)
4. **WiFi positioning** - Location via WiFi access point database
5. **3G/CDMA** - Cell tower triangulation
6. **IP geolocation** - Approximate location from IP address

### How Geoclue Works

**Normal operation**:
1. Application requests location via D-Bus
2. Geoclue activates (if not already running)
3. Queries enabled sources in priority order
4. Returns location to application
5. After 60 seconds of inactivity, Geoclue exits ("Service not used for 60 seconds. Shutting down..")
6. D-Bus auto-activation restarts it when next needed

**Key insight**: Geoclue is **on-demand** by design. It should NOT run continuously.

### The Timezone Problem

**localtimed/automatic-timezoned behavior**:
- Both services use geoclue to detect location for automatic timezone setting
- They poll geoclue periodically to detect timezone changes (when traveling)
- This prevents geoclue from shutting down after 60 seconds
- Creates a restart loop: geoclue exits → localtimed wakes it → geoclue exits → repeat

**From our logs** (configuration.nix:12:15:12):
```
Dec 24 12:15:12 hamsa geoclue[52314]: Service not used for 60 seconds. Shutting down..
Dec 24 12:15:12 hamsa systemd[1]: geoclue.service: Deactivated successfully.
Dec 24 12:15:12 hamsa systemd[1]: Starting Location Lookup Service...
Dec 24 12:15:12 hamsa systemd[1]: Started Location Lookup Service.
```

This cycle repeats indefinitely.

## Best Practices for NixOS Location Services

### Principle 1: Disable Automatic Timezone Detection

**Recommendation**: Use static timezone unless you frequently travel across time zones.

**Rationale**:
- Most users stay in one timezone 99%+ of the time
- Automatic detection adds complexity and failure points
- Manual timezone changes (when traveling) are trivial: `sudo timedatectl set-timezone America/New_York`
- Eliminates geoclue restart loop

**NixOS Configuration**:
```nix
# Use static timezone (recommended for most users)
time.timeZone = "America/Los_Angeles";

# Disable automatic timezone services
# services.automatic-timezoned.enable = false;  # Default is false
# services.localtimed.enable = false;            # Disable if enabled

# Keep time synchronization
services.timesyncd.enable = true;
```

### Principle 2: Use WiFi-Based Location for Applications

**Recommendation**: Enable geoclue with WiFi source, but configure applications to request location only when needed.

**Rationale**:
- Applications like GNOME Weather, Maps, Calendar need location
- WiFi positioning is accurate (typically 20-100 meters) and doesn't require GPS hardware
- D-Bus activation means geoclue only runs when applications request location
- No continuous polling, no unnecessary restarts

**NixOS Configuration**:
```nix
services.geoclue2 = {
  enable = true;
  
  # Enable WiFi-based location (most reliable for laptops)
  enableWifi = true;
  
  # Disable sources you don't need
  enable3G = false;          # Unless you have cellular modem
  enableCDMA = false;        # Unless you have CDMA modem
  enableModemGPS = false;    # Unless you have GPS modem
  enableNmea = false;        # Unless you have GPS on local network
  
  # Configure WiFi geolocation service
  geoProviderUrl = "https://api.beacondb.net/v1/geolocate";  # Default
  submitData = false;        # Don't submit WiFi AP data to provider
  
  # Application permissions
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
    # Add other apps that need location
  };
};

# Keep location provider for GNOME integration
location.provider = "geoclue2";
```

### Principle 3: Consider Static Location for Non-Mobile Systems

**Recommendation**: For desktop systems that don't move, use static location source.

**Rationale**:
- Desktop PCs never move - why query WiFi databases?
- Eliminates all network requests for location
- Still provides accurate location for weather, timezone, etc.
- Zero overhead

**NixOS Configuration**:
```nix
services.geoclue2 = {
  enable = true;
  
  # Enable static source (disables all other sources automatically)
  enableStatic = true;
  staticLatitude = 37.7749;   # San Francisco
  staticLongitude = -122.4194;
  staticAltitude = 16.0;      # Meters above sea level
  staticAccuracy = 1000.0;    # Accuracy radius in meters
  
  # Application permissions (same as above)
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

location.provider = "geoclue2";
```

**Note**: `enableStatic = true` automatically disables WiFi, 3G, CDMA, ModemGPS, and NMEA sources to prevent conflicts.

### Principle 4: WiFi Location is Checked On-Demand, Not Periodically

**Important**: Geoclue does NOT continuously poll for location. It only queries when:
1. Application requests location via D-Bus
2. Application is already whitelisted or user approves request
3. Geoclue wakes up, queries WiFi/network sources, returns result
4. Geoclue exits after 60 seconds of inactivity

**This means**:
- ✅ Location is checked when you open GNOME Weather
- ✅ Location is checked when Calendar needs timezone info
- ✅ Location is checked when Maps app starts
- ❌ Location is NOT checked every N minutes in the background
- ❌ Location is NOT checked at boot (unless an application requests it)

**To check location at boot after WiFi connects**, you need to create a service that requests location.

## Recommended Configurations by Use Case

### Use Case 1: Laptop That Never Travels (Most Common)

**Scenario**: You work from home or office, stay in one timezone.

**Optimal Configuration**:
```nix
# Static timezone - no geoclue polling
time.timeZone = "America/Los_Angeles";

# WiFi-based location for weather/maps apps
services.geoclue2 = {
  enable = true;
  enableWifi = true;
  
  # Disable unneeded sources
  enable3G = false;
  enableCDMA = false;
  enableModemGPS = false;
  enableNmea = false;
  
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

location.provider = "geoclue2";
```

**Benefits**:
- Zero geoclue restarts (only runs when app requests location)
- Accurate location for weather/maps (20-100m via WiFi)
- No NetworkManager communication overhead
- Simple, reliable

### Use Case 2: Desktop PC That Never Moves

**Scenario**: Desktop computer with fixed location.

**Optimal Configuration**:
```nix
# Static timezone
time.timeZone = "America/Los_Angeles";

# Static location - zero network requests
services.geoclue2 = {
  enable = true;
  enableStatic = true;
  
  # Use location.* options for coordinates
  # These are inherited by geoclue2
};

# Set your exact location
location = {
  provider = "geoclue2";
  latitude = 37.7749;
  longitude = -122.4194;
};
```

**Benefits**:
- Absolutely zero network traffic for location
- No WiFi database queries
- Instant location responses (no network latency)
- Perfect for desktop PCs

### Use Case 3: Laptop That Travels Across Timezones

**Scenario**: You frequently travel and want automatic timezone updates.

**Optimal Configuration**:
```nix
# Enable automatic timezone detection
services.localtimed.enable = true;
# OR
# services.automatic-timezoned.enable = true;

# WiFi-based location (needed for timezone detection)
services.geoclue2 = {
  enable = true;
  enableWifi = true;
  
  enable3G = false;
  enableCDMA = false;
  enableModemGPS = false;
  enableNmea = false;
  
  # Allow localtimed to access location
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
    "localtimed" = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

location.provider = "geoclue2";

# Mitigate geoclue restart loop with systemd overrides
systemd.services.geoclue = {
  serviceConfig = {
    # Prevent excessive restarts
    Restart = "on-failure";
    RestartSec = "60s";
  };
};
```

**Trade-offs**:
- ✅ Automatic timezone when traveling
- ✅ Location for weather/maps apps
- ⚠️ More geoclue activity (for timezone polling)
- ⚠️ Requires working NetworkManager

**Note**: Even in this scenario, geoclue doesn't run continuously. It's activated periodically by localtimed, does its work, then exits.

### Use Case 4: Boot-Time Location Check

**Scenario**: You want location checked once at boot after WiFi connects (your requirement).

**Optimal Configuration**:
```nix
# Static timezone
time.timeZone = "America/Los_Angeles";

# WiFi-based location
services.geoclue2 = {
  enable = true;
  enableWifi = true;
  enable3G = false;
  enableCDMA = false;
  enableModemGPS = false;
  enableNmea = false;
  
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

location.provider = "geoclue2";

# Custom service to check location at boot
systemd.services.check-location-at-boot = {
  description = "Check location once after WiFi connects at boot";
  wantedBy = [ "multi-user.target" ];
  after = [ "network-online.target" "geoclue.service" ];
  wants = [ "network-online.target" ];
  
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  
  script = ''
    # Use geoclue demo client to trigger location lookup
    # This wakes up geoclue, which queries WiFi location
    ${pkgs.geoclue2}/libexec/geoclue-2.0/demos/where-am-i -t 5 || true
    
    # Location is now cached by geoclue for other applications
    echo "Location checked at boot: $(date)" >> /var/log/location-check.log
  '';
};
```

**How this works**:
1. System boots, NetworkManager connects to WiFi
2. `network-online.target` is reached
3. `check-location-at-boot.service` runs once
4. Triggers geoclue via demo client
5. Geoclue queries WiFi positioning service
6. Location is cached for other applications
7. Geoclue exits after 60 seconds
8. Service doesn't run again until next boot

**Benefits**:
- ✅ Location checked exactly once at boot
- ✅ Runs only after WiFi is connected
- ✅ Location available for apps that start at boot
- ✅ No continuous polling
- ✅ No geoclue restart loop

## NixOS-Specific Best Practices

### 1. Use Built-In Options, Not Manual Configuration

**Don't do this**:
```nix
environment.etc."geoclue/geoclue.conf".text = ''
  [wifi]
  enable=true
  # ...manual config...
'';
```

**Do this**:
```nix
services.geoclue2 = {
  enable = true;
  enableWifi = true;
  geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
};
```

**Rationale**: NixOS options are type-checked, have defaults, and integrate with systemd properly.

### 2. Inherit Location from `location.*` Options

**Pattern**:
```nix
# Set global location
location = {
  provider = "geoclue2";
  latitude = 37.7749;
  longitude = -122.4194;
};

# Geoclue static source inherits these automatically
services.geoclue2 = {
  enable = true;
  enableStatic = true;
  # staticLatitude defaults to location.latitude
  # staticLongitude defaults to location.longitude
  staticAltitude = 16.0;
  staticAccuracy = 1000.0;
};
```

**Source**: `nixos/modules/services/desktops/geoclue2.nix:280-281`

### 3. Application Permissions via `appConfig`

**Pattern**:
```nix
services.geoclue2.appConfig = {
  "org.gnome.Shell.LocationServices" = {
    isAllowed = true;
    isSystem = true;
  };
  "firefox" = {
    isAllowed = true;
    isSystem = false;
  };
};
```

**This generates** `/etc/geoclue/geoclue.conf` entries automatically.

### 4. Monitor Geoclue Activity

**Check if geoclue is restarting excessively**:
```bash
journalctl -fu geoclue.service
```

**Expected behavior** (healthy):
- Geoclue starts when application requests location
- "Service not used for 60 seconds. Shutting down.." after inactivity
- Next activation when next app requests location

**Problem behavior** (unhealthy):
- Continuous restart loop every 60 seconds
- "Service not used for 60 seconds" immediately followed by restart
- Indicates something is polling geoclue (likely localtimed/automatic-timezoned)

### 5. Test Location Services

**Check current location**:
```bash
# System-wide check (requires geoclue to be running)
/nix/store/*/libexec/geoclue-2.0/demos/where-am-i -t 5

# Or find the demo client
find /nix/store -name where-am-i -executable 2>/dev/null | head -1 | xargs -I {} {} -t 5
```

**Check geoclue configuration**:
```bash
cat /etc/geoclue/geoclue.conf
```

**Check which apps are allowed**:
```bash
grep -A3 "^\[" /etc/geoclue/geoclue.conf
```

## Recommended Configuration for Your System

Based on your requirements:
- **Use case**: Laptop that doesn't travel frequently
- **Requirement**: Check location once at boot after WiFi connects
- **Problem**: Avoid geoclue restart loop that exacerbates NetworkManager deadlocks

**Optimal Configuration**:
```nix
# Static timezone (San Francisco)
time.timeZone = "America/Los_Angeles";

# WiFi-based location for GNOME apps
services.geoclue2 = {
  enable = true;
  
  # Enable WiFi positioning
  enableWifi = true;
  
  # Disable unneeded sources
  enable3G = false;
  enableCDMA = false;
  enableModemGPS = false;
  enableNmea = false;
  
  # Use BeaconDB for WiFi geolocation (privacy-friendly)
  geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
  submitData = false;
  
  # Allow GNOME services to access location
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

# Keep geoclue as location provider for GNOME
location.provider = "geoclue2";

# Optional: Check location once at boot (if desired)
# systemd.services.check-location-at-boot = {
#   description = "Check location once after WiFi connects";
#   wantedBy = [ "multi-user.target" ];
#   after = [ "network-online.target" ];
#   wants = [ "network-online.target" ];
#   serviceConfig = {
#     Type = "oneshot";
#     RemainAfterExit = true;
#   };
#   script = ''
#     ${pkgs.geoclue2}/libexec/geoclue-2.0/demos/where-am-i -t 5 || true
#   '';
# };
```

**Why this works**:
1. ✅ No automatic timezone detection → no geoclue restart loop
2. ✅ Location available for GNOME Weather, Calendar, etc.
3. ✅ Geoclue only runs when apps request location
4. ✅ WiFi positioning accurate to 20-100 meters
5. ✅ No interference with NetworkManager (minimal communication)
6. ✅ If WiFi deadlocks occur, location requests fail gracefully (timeout)

## Migration Path

**Current state** (problematic):
```nix
services.localtimed.enable = true;  # Causes geoclue restart loop
```

**Step 1**: Disable automatic timezone (in configuration.nix:89):
```nix
# services.localtimed.enable = true;  # Commented out
time.timeZone = "America/Los_Angeles";
```

**Step 2**: Verify geoclue stops restarting:
```bash
sudo nixos-rebuild switch
journalctl -fu geoclue.service
# Should see: starts when app requests, exits after 60s, NO immediate restart
```

**Step 3**: Test location in GNOME Weather or Calendar
- Location should be fetched when you open these apps
- Check logs: `journalctl -u geoclue.service` should show activation

**Step 4**: (Optional) Add boot-time location check if needed

## Comparison: Different Approaches

| Approach | Network Requests | Geoclue Restarts | Location Accuracy | Best For |
|----------|-----------------|------------------|-------------------|----------|
| **Static location** | None | None | Exact (user-defined) | Desktop PCs |
| **WiFi + Static timezone** | On-demand only | On-demand only | 20-100m | Laptops (recommended) |
| **WiFi + Auto timezone** | Periodic | Periodic (every ~5min) | 20-100m | Frequent travelers |
| **WiFi + Boot check** | Boot + on-demand | Boot + on-demand | 20-100m | Special use cases |

## References

- **Geoclue Manual**: `man geoclue(5)` or Arch Wiki (most comprehensive)
- **NixOS Module**: `nixos/modules/services/desktops/geoclue2.nix`
- **Geoclue Source**: [GitLab FreeDesktop geoclue](https://gitlab.freedesktop.org/geoclue/geoclue)
- **WiFi Positioning Protocol**: [Ichnaea API](https://ichnaea.readthedocs.io/en/latest/api/geolocate.html)
- **Related Report**: `specs/reports/019_system_freeze_shutdown_analysis.md`

## Conclusion

**Key Takeaway**: For most NixOS laptop users, the optimal configuration is:
1. **Static timezone** (disable localtimed/automatic-timezoned)
2. **WiFi-based location** for applications
3. **On-demand activation** (default geoclue behavior)

This provides accurate location for GNOME apps while eliminating the geoclue restart loop that can exacerbate NetworkManager issues. Location is checked naturally when applications need it, not on a fixed schedule.

The "check location once at boot" requirement is best achieved by simply letting GNOME applications (Weather, Calendar) request location when they start, which happens automatically. No custom service needed unless you want to pre-cache location before any app starts.

---

**Implementation Status**: Configuration already applied in configuration.nix (refs: specs/reports/019_system_freeze_shutdown_analysis.md)
