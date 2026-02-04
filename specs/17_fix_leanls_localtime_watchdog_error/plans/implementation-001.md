# Implementation Plan: Task #17

- **Task**: 17 - fix_leanls_localtime_watchdog_error
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: Task #16 research (understanding of automatic-timezoned behavior)
- **Research Inputs**: specs/17_fix_leanls_localtime_watchdog_error/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Fix the Lean LSP (leanls) "Watchdog error: no such file or directory (error code: 2) file: /etc/localtime" by ensuring `/etc/localtime` always exists. The root cause is that NixOS's automatic-timezoned module sets `time.timeZone = null` (priority ~1000), which overrides the user's `lib.mkDefault` (priority ~1500), causing locale.nix to not create the `/etc/localtime` symlink. The fix is a single-line change: use `lib.mkForce` instead of `lib.mkDefault` for the timezone setting.

### Research Integration

Key findings from research-001.md:
- NixOS locale.nix only creates `/etc/localtime` when `time.timeZone != null`
- automatic-timezoned module sets `time.timeZone = null` at priority ~1000
- `lib.mkDefault` has priority ~1500 (loses to ~1000)
- `lib.mkForce` has priority ~50 (wins over everything)
- automatic-timezoned can still update timezone via timedatectl when geolocation succeeds

## Goals & Non-Goals

**Goals**:
- Ensure `/etc/localtime` always exists on system boot
- Fix Lean LSP watchdog error caused by missing `/etc/localtime`
- Preserve automatic-timezoned functionality (can still update via timedatectl)
- Use the most elegant single-line solution

**Non-Goals**:
- Fix the underlying geoclue2/automatic-timezoned D-Bus disconnect issue (covered by task #16)
- Change the default timezone from America/Los_Angeles
- Disable automatic timezone detection

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| lib.mkForce conflicts with other modules | L | L | No other module sets time.timeZone with force priority |
| Timezone mismatch when traveling | L | M | automatic-timezoned can still override via timedatectl; user can manually set |
| Build failure from syntax error | M | L | Verify with `nix flake check` before applying |

## Implementation Phases

### Phase 1: Apply Configuration Change [NOT STARTED]

**Goal**: Change `lib.mkDefault` to `lib.mkForce` for time.timeZone in configuration.nix

**Tasks**:
- [ ] Edit configuration.nix line 101 to change `lib.mkDefault` to `lib.mkForce`
- [ ] Add explanatory comment about why mkForce is needed
- [ ] Run `nix flake check` to verify configuration syntax

**Timing**: 10 minutes

**Files to modify**:
- `configuration.nix` - Change timezone priority from mkDefault to mkForce

**Verification**:
- `nix flake check` passes without errors
- Configuration diff shows only the intended change

---

### Phase 2: Build and Apply System Configuration [NOT STARTED]

**Goal**: Rebuild NixOS with the new configuration and verify /etc/localtime exists

**Tasks**:
- [ ] Run `sudo nixos-rebuild switch --flake .` to apply configuration
- [ ] Verify `/etc/localtime` symlink exists and points to correct timezone
- [ ] Verify `timedatectl status` shows America/Los_Angeles timezone

**Timing**: 5 minutes

**Files to modify**:
- None (system rebuild only)

**Verification**:
- `ls -la /etc/localtime` shows symlink to `/etc/zoneinfo/America/Los_Angeles`
- `timedatectl status` shows `Time zone: America/Los_Angeles`

---

### Phase 3: Verify Lean LSP Functionality [NOT STARTED]

**Goal**: Confirm the Lean LSP no longer produces watchdog errors

**Tasks**:
- [ ] Open a Lean file in Neovim to trigger leanls
- [ ] Verify no "Watchdog error: no such file or directory" errors appear
- [ ] Confirm LSP functionality works (hover, completion, diagnostics)

**Timing**: 5 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- No watchdog errors in `:LspLog` or `:messages`
- Lean LSP provides completions and diagnostics normally

## Testing & Validation

- [ ] `/etc/localtime` symlink exists after nixos-rebuild
- [ ] `timedatectl status` shows correct timezone
- [ ] `nix flake check` passes
- [ ] Lean LSP starts without watchdog error
- [ ] Lean files can be edited with full LSP support (hover, completions, diagnostics)

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-YYYYMMDD.md (after completion)

## Rollback/Contingency

If the change causes issues:
1. Revert configuration.nix change: `git checkout configuration.nix`
2. Rebuild: `sudo nixos-rebuild switch --flake .`
3. Report issue for further investigation

The change is minimal and easily reversible. Since it only affects the NixOS priority system for timezone configuration, there is no risk of data loss or system instability.
