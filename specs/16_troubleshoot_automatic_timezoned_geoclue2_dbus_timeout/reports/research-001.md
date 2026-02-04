# Research Report: Task #16

- **Task**: 16 - troubleshoot_automatic_timezoned_geoclue2_dbus_timeout
- **Started**: 2026-02-04T12:00:00Z
- **Completed**: 2026-02-04T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None (builds on task #15 research)
- **Sources/Inputs**: System logs, nixpkgs issues, upstream automatic-timezoned, geoclue documentation, NixOS Discourse
- **Artifacts**: specs/16_troubleshoot_automatic_timezoned_geoclue2_dbus_timeout/reports/research-001.md
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The D-Bus timeout error is caused by geoclue2 shutting down after 60 seconds of idle time, which is **hardcoded behavior** in geoclue
- automatic-timezoned waits for a location update signal from geoclue, but geoclue shuts down before returning a location
- The 60-second idle timeout in geoclue is not configurable via geoclue.conf or NixOS options
- BeaconDB is correctly configured as the geolocation provider, but the issue is the daemon lifecycle, not the provider
- Multiple workaround options exist: restart-on-failure, static source fallback, or timer-based restart

## Context and Scope

Research focused on:
1. Root cause analysis of the D-Bus "Message recipient disconnected" error
2. Understanding geoclue2's idle timeout behavior
3. Evaluating NixOS configuration options for mitigation
4. Identifying workarounds and fixes

## Problem Analysis

### Timeline of Failure (Feb 2, 2026)

From journal logs:
```
09:08:24 - automatic-timezoned starts
09:08:27 - geoclue starts (D-Bus activated)
09:08:27 - automatic-timezoned-geoclue-agent starts
09:09:28 - geoclue: "Service not used for 60 seconds. Shutting down.."
09:09:28 - automatic-timezoned: Error (D-Bus NoReply - recipient disconnected)
09:09:28 - automatic-timezoned: Failed with exit-code
```

### Root Cause

The issue is a **timing/lifecycle mismatch**:

1. **geoclue2 is a D-Bus activated service** that only runs when clients are actively using it
2. **geoclue has a hardcoded 60-second idle timeout** - if no client makes a successful request within 60 seconds, it shuts down
3. **automatic-timezoned waits passively** for location update signals from geoclue
4. **geoclue fails to get location data** from BeaconDB within 60 seconds (possibly due to WiFi scan timing or network latency)
5. **geoclue shuts down** while automatic-timezoned is still waiting for a location signal
6. **D-Bus error occurs** because the recipient (geoclue) disconnected from the bus

### Why geoclue Fails to Return Location in 60 Seconds

Several factors may contribute:
- **WiFi scanning takes time**: geoclue needs WiFi access point data to query BeaconDB
- **BeaconDB query may be slow or fail**: Network latency or service unavailability
- **No error handling in automatic-timezoned**: The daemon crashes instead of retrying

### Current Configuration Analysis

The current configuration.nix (lines 71-95, 538-545) has:
```nix
services.geoclue2 = {
  enable = true;
  appConfig = {
    "automatic-timezone" = { isAllowed = true; isSystem = true; };
    # ... other apps
  };
};
location.provider = "geoclue2";
time.timeZone = lib.mkDefault "America/Los_Angeles";
services.automatic-timezoned.enable = true;
```

And in systemd.services:
```nix
geoclue = {
  serviceConfig = {
    TimeoutStopSec = "15s";
    Restart = "on-failure";
    RestartSec = "60s";
  };
};
```

**Issues identified:**
1. `automatic-timezoned` service has no restart configuration
2. `automatic-timezoned-geoclue-agent` service runs but cannot prevent geoclue shutdown
3. The geoclue restart configuration only helps after geoclue crashes, not after normal idle shutdown

## Findings

### Geoclue2 Idle Timeout is Hardcoded

The 60-second idle timeout is **hardcoded in geoclue source code** (gclue-service-manager.c). It was increased to 60 seconds in version 2.4.13 from an even shorter timeout. This is **not configurable** via:
- geoclue.conf
- NixOS `services.geoclue2` options
- Environment variables
- Meson build options

**Reference**: [GeoClue 2.4.13 Release Notes](https://www.announcebuddy.co.uk/2018/10/geoclue-2-4-13/)

### automatic-timezoned Design Limitation

From the [automatic-timezoned README](https://github.com/maxbrunet/automatic-timezoned):
- "The daemon waits for the location updated signal from GeoClue, and repeats the process when it happens"
- It does not actively poll or keep geoclue alive
- It crashes on D-Bus errors instead of retrying

### NixOS Module Does Not Expose Restart Options

The [automatic-timezoned NixOS module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/automatic-timezoned.nix) does not configure `Restart=on-failure` for the service. The service runs once and fails permanently if geoclue disconnects.

### Mozilla Location Service Retirement (June 2024)

While BeaconDB is now configured as default, the MLS retirement caused many geoclue issues. The current configuration correctly uses BeaconDB:
```
[wifi]
url=https://api.beacondb.net/v1/geolocate
```

**Reference**: [GitHub Issue #321121](https://github.com/NixOS/nixpkgs/issues/321121)

### localtimed is Not Recommended

localtimed (`services.localtimed.enable`) has been broken since 2019 with permission issues and should not be used as an alternative.

**Reference**: [NixOS Discourse - Localtimed broken since 2019](https://discourse.nixos.org/t/localtimed-broken-since-2019/25039)

## Recommendations

### Priority 1: Add Restart-on-Failure to automatic-timezoned

The most practical fix is to configure automatic-timezoned to restart on failure:

```nix
systemd.services.automatic-timezoned = {
  serviceConfig = {
    Restart = "on-failure";
    RestartSec = "30s";
    # Limit restart attempts to avoid infinite loops
    StartLimitBurst = 10;
    StartLimitIntervalSec = "300s";  # 10 attempts per 5 minutes
  };
};
```

**Rationale**: After geoclue shuts down and automatic-timezoned fails, systemd will restart it. On restart, it will D-Bus activate geoclue again, which may succeed on a subsequent attempt when WiFi data is available.

### Priority 2: Configure geoclue Static Source as Fallback

Enable geoclue's static source to provide a fallback location when network location fails:

```nix
services.geoclue2 = {
  enableStatic = true;
  # Use California coordinates as fallback
  staticLatitude = 37.7749;   # San Francisco
  staticLongitude = -122.4194;
  staticAccuracy = 10000;     # 10km accuracy
};
```

**Rationale**: This ensures geoclue always has a location to return, even if BeaconDB fails. The timezone will be correct for California, and will update if network location succeeds later.

### Priority 3: Keep Geoclue Agent Running Permanently

Modify the geoclue agent service to not depend on geoclue lifecycle:

```nix
systemd.services.automatic-timezoned-geoclue-agent = {
  serviceConfig = {
    Restart = "always";
    RestartSec = "10s";
  };
};
```

### Priority 4: Consider Timer-Based Restart (Alternative Approach)

Create a systemd timer to periodically restart automatic-timezoned:

```nix
systemd.timers.automatic-timezoned-restart = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "2min";
    OnUnitActiveSec = "30min";
    Unit = "automatic-timezoned.service";
  };
};
```

**Rationale**: This ensures periodic retry even if the service is not marked as failed.

### Not Recommended: tzupdate

While `services.tzupdate.enable` is simpler, it uses GeoIP which is less accurate than geoclue's WiFi-based location.

## Implementation Strategy

### Recommended Configuration Block

```nix
# Timezone Configuration with Robust Fallback
# Addresses geoclue2 idle timeout issue (Task #16)

# California default (used when geolocation fails)
time.timeZone = lib.mkDefault "America/Los_Angeles";

# Enable geolocation service with static fallback
services.geoclue2 = {
  enable = true;
  enableStatic = true;  # Fallback location
  staticLatitude = 37.7749;
  staticLongitude = -122.4194;
  staticAccuracy = 10000;
  appConfig = {
    "org.gnome.Shell.LocationServices" = { isAllowed = true; isSystem = true; };
    automatic-timezone = { isAllowed = true; isSystem = true; };
  };
};

location.provider = "geoclue2";

# Enable automatic timezone detection
services.automatic-timezoned.enable = true;

# Robust restart configuration for geoclue-dependent services
systemd.services = {
  # ... existing services ...

  automatic-timezoned = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
      StartLimitBurst = 10;
      StartLimitIntervalSec = "300s";
    };
  };

  automatic-timezoned-geoclue-agent = {
    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
    };
  };
};
```

## Risks and Mitigations

### Risk: Restart Loop

If geoclue consistently fails, automatic-timezoned will restart repeatedly.

**Mitigation**: `StartLimitBurst` and `StartLimitIntervalSec` limit restarts to 10 per 5 minutes.

### Risk: Static Location Inaccurate When Traveling

Static fallback location will return California timezone even when user is in a different timezone.

**Mitigation**: Static location is only used when network location fails. When network location succeeds, it overrides the static source. The `mkDefault` timezone provides a reasonable fallback.

### Risk: BeaconDB Service Unavailable

BeaconDB may have outages or rate limits.

**Mitigation**: The restart-on-failure approach allows recovery when the service becomes available again.

## Testing Plan

After implementing changes:

1. **Rebuild and switch**: `sudo nixos-rebuild switch --flake .`
2. **Restart services**:
   ```bash
   sudo systemctl restart automatic-timezoned
   sudo systemctl restart automatic-timezoned-geoclue-agent
   ```
3. **Check status**:
   ```bash
   systemctl status automatic-timezoned
   systemctl status geoclue
   timedatectl
   ```
4. **Monitor logs**:
   ```bash
   journalctl -u automatic-timezoned -u geoclue -f
   ```
5. **Verify timezone after success**:
   ```bash
   timedatectl | grep "Time zone"
   # Expected: Time zone: America/Los_Angeles (PST, -0800)
   ```

## Manual Workaround (Immediate)

Until configuration is updated, manually set timezone:
```bash
sudo timedatectl set-timezone America/Los_Angeles
```

## Appendix

### References

- [automatic-timezoned GitHub Repository](https://github.com/maxbrunet/automatic-timezoned)
- [GeoClue not providing location anymore - Issue #424](https://github.com/maxbrunet/automatic-timezoned/issues/424)
- [NixOS/nixpkgs Issue #321121 - Mozilla Location Service Retirement](https://github.com/NixOS/nixpkgs/issues/321121)
- [geoclue.5 man page - Arch Linux](https://man.archlinux.org/man/geoclue.5)
- [NixOS Discourse - Timezones on Laptop](https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853)
- [geoclue2.nix NixOS Module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktops/geoclue2.nix)
- [localtimed broken since 2019 - NixOS Discourse](https://discourse.nixos.org/t/localtimed-broken-since-2019/25039)

### Search Queries Used

1. "NixOS automatic-timezoned geoclue2 D-Bus timeout disconnect error 2024 2025"
2. "geoclue2 idle timeout configuration Service not used for 60 seconds"
3. "nixpkgs automatic-timezoned issue geoclue github"
4. "automatic-timezoned github issue D-Bus disconnect geoclue poll timeout workaround"
5. "NixOS localtimed vs automatic-timezoned which is better 2024 2025"
6. "geoclue inactivity_timeout compile time meson option configure hardcoded"
7. "systemd service geoclue keep-alive prevent idle shutdown"
8. "NixOS systemd.services automatic-timezoned override Restart on-failure configuration"

### Current geoclue.conf Contents

```ini
[wifi]
enable=true
submission-nick=geoclue
submission-url=https://api.beacondb.net/v2/geosubmit
submit-data=false
url=https://api.beacondb.net/v1/geolocate

[automatic-timezoned]
allowed=true
system=true
users=326

[static-source]
enable=false
```

### Service Dependencies

```
automatic-timezoned
  └── Requires: automatic-timezoned-geoclue-agent
                  └── Requires: geoclue
                                  └── D-Bus activated, 60s idle timeout
```
