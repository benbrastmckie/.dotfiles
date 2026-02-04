# Implementation Plan: Task #16

- **Task**: 16 - troubleshoot_automatic_timezoned_geoclue2_dbus_timeout
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/16_troubleshoot_automatic_timezoned_geoclue2_dbus_timeout/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Fix the automatic-timezoned service failing due to geoclue2's 60-second idle timeout causing D-Bus disconnection. The root cause is a timing/lifecycle mismatch: geoclue shuts down before returning location data while automatic-timezoned passively waits. The fix involves adding systemd restart-on-failure configuration to both automatic-timezoned and its geoclue agent, plus enabling geoclue's static source as a location fallback.

### Research Integration

Key findings from research-001.md:
- geoclue2 has a hardcoded 60-second idle timeout (not configurable)
- automatic-timezoned crashes on D-Bus errors instead of retrying
- NixOS module does not configure Restart=on-failure by default
- Static source provides fallback location when BeaconDB fails

## Goals & Non-Goals

**Goals**:
- Make automatic-timezoned resilient to geoclue shutdown
- Provide fallback location when network geolocation fails
- Ensure timezone detection works across system reboots

**Non-Goals**:
- Modifying geoclue's 60-second timeout (hardcoded in source)
- Using alternative timezone services (tzupdate uses less accurate GeoIP)
- Patching automatic-timezoned to handle D-Bus errors internally

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Restart loop if geoclue consistently fails | Medium | Medium | Use StartLimitBurst/StartLimitIntervalSec to cap restarts |
| Static location inaccurate when traveling | Low | Low | Static is fallback only; network location takes precedence |
| BeaconDB service outages | Low | Low | Restart mechanism allows recovery when service returns |

## Implementation Phases

### Phase 1: Add Restart Configuration for automatic-timezoned [NOT STARTED]

**Goal**: Make automatic-timezoned restart automatically when geoclue disconnects

**Tasks**:
- [ ] Add automatic-timezoned service override to systemd.services in configuration.nix
- [ ] Configure Restart=on-failure with 30s RestartSec
- [ ] Add StartLimitBurst=10 and StartLimitIntervalSec=300s to prevent infinite loops

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add automatic-timezoned service override in systemd.services block (lines 520-546)

**Verification**:
- `nix flake check` passes
- `systemctl cat automatic-timezoned` shows Restart=on-failure after rebuild

---

### Phase 2: Configure geoclue Agent Service [NOT STARTED]

**Goal**: Keep the geoclue agent running to maintain connection attempts

**Tasks**:
- [ ] Add automatic-timezoned-geoclue-agent service override
- [ ] Configure Restart=always with 10s RestartSec for the agent

**Timing**: 20 minutes

**Files to modify**:
- `configuration.nix` - Add automatic-timezoned-geoclue-agent entry in systemd.services

**Verification**:
- `nix flake check` passes
- `systemctl cat automatic-timezoned-geoclue-agent` shows Restart=always after rebuild

---

### Phase 3: Enable Static Source Fallback [NOT STARTED]

**Goal**: Provide fallback location when BeaconDB fails or is slow

**Tasks**:
- [ ] Investigate NixOS geoclue2 options for static source (enableStatic, staticLatitude, etc.)
- [ ] If options exist: Add static source configuration with California coordinates
- [ ] If options do not exist: Document as future enhancement (geoclue.conf must be edited upstream)

**Timing**: 30 minutes

**Files to modify**:
- `configuration.nix` - Add static source options to services.geoclue2 block (lines 72-84)

**Verification**:
- `cat /etc/geoclue/geoclue.conf` shows static-source enabled (if supported)
- Or document limitation if NixOS module lacks static source options

---

### Phase 4: Test and Verify [NOT STARTED]

**Goal**: Confirm the fix resolves the D-Bus timeout issue

**Tasks**:
- [ ] Run `sudo nixos-rebuild switch --flake .`
- [ ] Restart services: `sudo systemctl restart automatic-timezoned`
- [ ] Monitor logs: `journalctl -u automatic-timezoned -u geoclue -f`
- [ ] Wait for geoclue idle shutdown (60 seconds) and verify automatic-timezoned restarts
- [ ] Verify timezone is set correctly: `timedatectl | grep "Time zone"`
- [ ] Document results in implementation summary

**Timing**: 40 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- automatic-timezoned restarts after geoclue shuts down (observed in logs)
- No restart loop occurs (limited by StartLimitBurst)
- Timezone shows America/Los_Angeles or correct detected zone

## Testing & Validation

- [ ] `nix flake check` passes without errors
- [ ] `nixos-rebuild switch` completes successfully
- [ ] `systemctl status automatic-timezoned` shows active (running)
- [ ] After 60+ seconds, automatic-timezoned recovers from geoclue shutdown
- [ ] `timedatectl` shows correct timezone
- [ ] No more than 10 restarts per 5 minutes (StartLimitBurst working)

## Artifacts & Outputs

- `configuration.nix` - Updated with systemd service overrides
- `specs/16_troubleshoot_automatic_timezoned_geoclue2_dbus_timeout/summaries/implementation-summary-YYYYMMDD.md` - Final results

## Rollback/Contingency

If the changes cause issues:
1. Remove the added systemd.services entries for automatic-timezoned and automatic-timezoned-geoclue-agent
2. Run `sudo nixos-rebuild switch --flake .` to restore previous configuration
3. Manually set timezone: `sudo timedatectl set-timezone America/Los_Angeles`
4. Consider disabling automatic-timezoned entirely: `services.automatic-timezoned.enable = false;`
