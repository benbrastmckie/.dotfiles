# Implementation Plan: Task #37

- **Task**: 37 - Configure NixOS AC Power Settings
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/37_configure_nixos_ac_power_settings/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Modify a single configuration value in home.nix to increase the AC power sleep timeout from 15 minutes (900 seconds) to 1 hour (3600 seconds). The existing dconf-based power management configuration structure is already in place; only the timeout value needs adjustment.

### Research Integration

The research report confirmed:
- Existing configuration at home.nix lines 57-61 already manages power settings via dconf
- Screen blank (`idle-delay = 300`) is correctly set to 5 minutes - no change needed
- Only `sleep-inactive-ac-timeout` needs updating from 900 to 3600
- Battery timeout remains at 15 minutes as intended

## Goals & Non-Goals

**Goals**:
- Increase AC power sleep timeout to 1 hour (3600 seconds)
- Maintain existing screen blank timeout at 5 minutes
- Keep declarative NixOS/Home Manager configuration approach

**Non-Goals**:
- Modify battery power settings (remain at 15 minutes)
- Add new power management features
- Change to system-level logind configuration

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Settings don't apply after rebuild | Low | Low | Logout/login or restart home-manager service |
| Wrong line edited | Low | Low | Verify with gsettings command after rebuild |

## Implementation Phases

### Phase 1: Update AC Power Timeout [NOT STARTED]

**Goal**: Change sleep-inactive-ac-timeout from 900 to 3600 in home.nix

**Tasks**:
- [ ] Edit home.nix line 58: change `sleep-inactive-ac-timeout = 900;` to `sleep-inactive-ac-timeout = 3600;`
- [ ] Update comment to reflect new value (60 minutes instead of 15 minutes)
- [ ] Run `nix flake check` to validate syntax
- [ ] Run `nixos-rebuild switch --flake .` to apply configuration

**Timing**: 15 minutes

**Files to modify**:
- `home.nix` - Change line 58 value from 900 to 3600, update comment

**Verification**:
- `nix flake check` passes without errors
- `nixos-rebuild switch` completes successfully
- `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout` returns 3600

---

### Phase 2: Verify and Document [NOT STARTED]

**Goal**: Confirm settings are active and functioning as expected

**Tasks**:
- [ ] Verify gsettings shows correct value (3600)
- [ ] Confirm screen still blanks after 5 minutes (optional live test)
- [ ] Create implementation summary

**Timing**: 15 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- gsettings command returns expected value
- Implementation summary created

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `nixos-rebuild switch --flake .` completes successfully
- [ ] `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout` returns `3600`
- [ ] `gsettings get org.gnome.desktop.session idle-delay` still returns `300` (unchanged)

## Artifacts & Outputs

- Modified `home.nix` with updated AC power timeout
- Implementation summary at `specs/37_configure_nixos_ac_power_settings/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

To rollback if issues occur:
1. Revert home.nix line 58 back to `sleep-inactive-ac-timeout = 900;`
2. Run `nixos-rebuild switch --flake .`
3. Verify with `gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout`

Alternatively, use NixOS generation rollback:
```bash
nixos-rebuild switch --rollback
```
