# Research Report: Task #15

- **Task**: 15 - configure_timezone_location_based
- **Started**: 2026-02-04T12:00:00Z
- **Completed**: 2026-02-04T12:15:00Z
- **Effort**: 15 minutes
- **Dependencies**: None
- **Sources/Inputs**: NixOS documentation, NixOS Discourse, GitHub nixpkgs issues, MyNixOS option documentation, existing configuration.nix
- **Artifacts**: specs/15_configure_timezone_location_based/reports/research-001.md
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- Existing configuration already implements automatic timezone detection using `services.automatic-timezoned` and `geoclue2`
- Configuration is well-structured but lacks a California default fallback
- NixOS now defaults to BeaconDB for geolocation since Mozilla Location Service was retired in June 2024
- The `time.timeZone` option should remain unset (null) when using automatic detection, or use `lib.mkDefault` for a fallback
- Two services exist for automatic timezone: `automatic-timezoned` (recommended) and `localtimed` (known issues)
- Adding `time.timeZone = lib.mkDefault "America/Los_Angeles"` provides California fallback when geolocation fails

## Context and Scope

Research focused on:
1. How to set timezone statically in NixOS configuration
2. How to enable automatic timezone detection based on geolocation
3. Best practices for timezone configuration with a default fallback
4. Relevant NixOS services (localtime, geoclue2)
5. Home Manager integration if applicable

## Findings

### Existing Configuration Analysis

The current `configuration.nix` (lines 71-95) already implements a comprehensive timezone configuration:

```nix
# Time and location configuration
services.geoclue2 = {
  enable = true;
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
    automatic-timezone = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

# Enable location services
location.provider = "geoclue2";

# Choose ONE of the following approaches:
# Option 1: Use automatic timezone detection (recommended with GNOME)
services.automatic-timezoned.enable = true;
# services.localtimed.enable = true;  # Don't enable both services

# Option 2: Or set a static timezone (uncomment if you prefer this)
# time.timeZone = "America/New_York";
```

**Key observations**:
- `automatic-timezoned` is enabled (recommended choice)
- geoclue2 is properly configured with app permissions
- No static timezone is set (commented out)
- No California default fallback exists

### NixOS Timezone Options

#### Static Timezone (`time.timeZone`)

- **Type**: `null or string without spaces`
- **Default**: `null`
- **Example**: `"America/Los_Angeles"` for California
- **Behavior when null**: Defaults to UTC, can be set imperatively with `timedatectl`
- **Source**: `nixos/modules/config/locale.nix`

#### Automatic Timezone Services

**`services.automatic-timezoned`** (Recommended)
- Uses geoclue2 for location detection
- Uses systemd-timedated to set timezone
- Written in Rust
- Actively maintained
- Waits for location updates from GeoClue

**`services.localtimed`**
- Alternative daemon for timezone detection
- Known issues with permissions ("Failed to set timezone" errors)
- Less reliable than automatic-timezoned
- **Not recommended** due to historical issues

### Geoclue2 Configuration

#### Mozilla Location Service Retirement

**Critical Update**: Mozilla shut down their location service on June 12, 2024. This affects all NixOS systems relying on the default geoclue2 configuration.

**Solution**: NixOS now defaults to BeaconDB:
- **Option**: `services.geoclue2.geoProviderUrl`
- **New Default**: `https://api.beacondb.net/v1/geolocate`
- **Source**: `nixos/modules/services/desktops/geoclue2.nix`
- **PR #391845** addressed this with warning messages

**Current configuration may already use the new default**. Verify by checking the nixpkgs version in flake.lock.

#### Geoclue2 App Configuration

The existing configuration correctly sets up app permissions:
```nix
services.geoclue2.appConfig = {
  "org.gnome.Shell.LocationServices" = { isAllowed = true; isSystem = true; };
  automatic-timezone = { isAllowed = true; isSystem = true; };
};
```

This allows both GNOME shell and the automatic-timezone service to access location data.

### Default Fallback Strategy

When using automatic timezone detection, a fallback can be set using priority functions:

```nix
# Set California as default, but allow automatic service to override
time.timeZone = lib.mkDefault "America/Los_Angeles";
```

**Priority explanation**:
- `lib.mkDefault` sets a default value with lower priority
- `lib.mkForce` would prevent overriding
- Automatic timezone service can override `mkDefault` values

**Important**: The NixOS documentation warns:
> "To avoid silent overriding by the service, if you have explicitly set a timezone, either remove it or ensure that it is set with a lower priority than the default value using `lib.mkDefault` or `lib.mkOverride`."

### Home Manager Integration

Home Manager does not directly manage system timezone (that's a system-level setting). However:
- Home Manager can set user-level timezone environment variables
- Home Manager sessions inherit the system timezone
- No additional Home Manager configuration is needed for timezone

### Alternative: tzupdate Service

For simpler one-shot timezone detection:
```nix
services.tzupdate.enable = true;
```
- Uses GeoIP-based location (less accurate than geoclue)
- Runs on-demand via `systemctl start tzupdate`
- Not as accurate as geoclue for WiFi-based location

## Decisions

1. **Keep automatic-timezoned**: The existing choice is correct
2. **Add California default**: Use `lib.mkDefault "America/Los_Angeles"`
3. **Verify geoclue provider**: Ensure using BeaconDB (check nixpkgs version)
4. **No Home Manager changes needed**: Timezone is system-level

## Recommendations

### Priority 1: Add California Default Fallback

Add to configuration.nix:
```nix
# California default, overridden by automatic-timezoned when geolocation works
time.timeZone = lib.mkDefault "America/Los_Angeles";
```

### Priority 2: Verify BeaconDB Provider

Ensure the nixpkgs version includes the BeaconDB default (post-PR #391845). If using an older version, explicitly set:
```nix
services.geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
```

### Priority 3: Clean Up Configuration Comments

The existing configuration has helpful comments but could be simplified now that the approach is confirmed.

### Recommended Final Configuration

```nix
# Timezone Configuration
# California default with automatic detection via geolocation

# Set California default (overridden when geolocation works)
time.timeZone = lib.mkDefault "America/Los_Angeles";

# Enable geolocation service
services.geoclue2 = {
  enable = true;
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
    automatic-timezone = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

# Enable location provider
location.provider = "geoclue2";

# Enable automatic timezone detection
services.automatic-timezoned.enable = true;
```

## Risks and Mitigations

### Risk: Geolocation Fails in Airplane Mode or No WiFi

**Mitigation**: The `lib.mkDefault` fallback ensures California timezone is used when geolocation is unavailable.

### Risk: BeaconDB Service Outage

**Mitigation**: BeaconDB is open-source and actively maintained. If outage occurs, the fallback timezone will be used.

### Risk: Privacy Concerns with Geolocation

**Mitigation**: Geolocation is opt-in and only used for timezone. Users can disable `automatic-timezoned` and rely on static timezone.

### Risk: Timezone Boundary Edge Cases

**Mitigation**: The `tzf-rs` library used by automatic-timezoned may have reduced accuracy near timezone boundaries. This is acceptable for most use cases.

## Appendix

### References

- [services.automatic-timezoned.enable - MyNixOS](https://mynixos.com/nixpkgs/option/services.automatic-timezoned.enable)
- [time.timeZone - MyNixOS](https://mynixos.com/nixpkgs/option/time.timeZone)
- [services.geoclue2.geoProviderUrl - MyNixOS](https://mynixos.com/nixpkgs/option/services.geoclue2.geoProviderUrl)
- [Timezones - How to setup on a laptop? - NixOS Discourse](https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853)
- [nixos/geoclue2: not working because Mozilla Location Service is retiring - GitHub Issue #321121](https://github.com/NixOS/nixpkgs/issues/321121)
- [automatic-timezoned GitHub Repository](https://github.com/maxbrunet/automatic-timezoned)
- [NixOS locale.nix module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/locale.nix)
- [NixOS geoclue2.nix module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktops/geoclue2.nix)

### Search Queries Used

1. "NixOS timezone configuration automatic geolocation geoclue2 2026"
2. "NixOS automatic-timezoned localtimed timezone detection service"
3. "NixOS time.timeZone default fallback automatic timezone geoclue"
4. "NixOS geoclue2 geoProviderUrl beacondb mozilla location service 2024 2025"

### California Timezone Identifier

- IANA identifier: `America/Los_Angeles`
- Covers Pacific Time Zone (PT)
- Observes Pacific Daylight Time (PDT) and Pacific Standard Time (PST)
