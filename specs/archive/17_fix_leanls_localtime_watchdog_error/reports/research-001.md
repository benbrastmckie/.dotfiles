# Research Report: Task #17

- **Task**: 17 - fix_leanls_localtime_watchdog_error
- **Started**: 2026-02-04T17:08:00Z
- **Completed**: 2026-02-04T18:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: Builds on task #16 research (automatic-timezoned geoclue2 timeout)
- **Sources/Inputs**: NixOS source (locale.nix, automatic-timezoned.nix), chrono issues, system logs, geoclue config
- **Artifacts**: specs/17_fix_leanls_localtime_watchdog_error/reports/research-001.md
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- **Root Cause**: `/etc/localtime` does not exist because `time.timeZone = null` (set by automatic-timezoned module)
- **Why It's Missing**: NixOS locale.nix only creates `/etc/localtime` when `time.timeZone != null`
- **Why It Stays Missing**: automatic-timezoned never successfully sets timezone via timedatectl (geoclue2 D-Bus disconnect from task #16)
- **Impact**: Programs that read `/etc/localtime` (like Lean's watchdog, Rust chrono) fail with "no such file or directory (error code: 2)"
- **Most Elegant Solution**: Ensure `/etc/localtime` always exists by not letting automatic-timezoned set `time.timeZone = null`

## Context and Scope

Research focused on:
1. Why `/etc/localtime` is missing on this NixOS system
2. How NixOS timezone configuration interacts with automatic-timezoned
3. Why Lean LSP (leanls) needs `/etc/localtime`
4. Finding the most elegant NixOS solution to ensure `/etc/localtime` exists

## Problem Analysis

### Current System State

```
$ ls -la /etc/localtime
ls: cannot access '/etc/localtime': No such file or directory

$ timedatectl status
Time zone: UTC (UTC, +0000)

$ systemctl status automatic-timezoned
restart counter is at 51
```

### Causal Chain

1. **User configuration**: `time.timeZone = lib.mkDefault "America/Los_Angeles"` (priority ~1500)
2. **automatic-timezoned module**: Sets `time.timeZone = null` (priority ~1000, wins)
3. **locale.nix behavior**: Only creates `/etc/localtime` when `time.timeZone != null`
4. **Result**: No `/etc/localtime` symlink exists
5. **automatic-timezoned runtime**: Attempts to set timezone via timedatectl, but fails due to geoclue2 D-Bus disconnect (task #16)
6. **timedatectl would create**: `/etc/localtime` if successful, but never succeeds
7. **Lean LSP watchdog**: Reads `/etc/localtime` for time operations, fails with error code 2

### Why Lean LSP Needs /etc/localtime

The Lean 4 language server uses standard time libraries that read `/etc/localtime`. This is common in many programs:

- **Rust chrono**: Panics on `Local::now()` when `/etc/localtime` missing ([chrono#755](https://github.com/chronotope/chrono/issues/755))
- **glibc localtime()**: Needs `/etc/localtime` to determine local timezone
- **Lean watchdog**: Uses time functions for logging, scheduling, causing "no such file or directory (error code: 2)"

## Findings

### NixOS Timezone Architecture

#### locale.nix (Creates /etc/localtime)

```nix
# From nixpkgs/nixos/modules/config/locale.nix
environment.etc =
  {
    zoneinfo.source = tzdir;
  }
  // lib.optionalAttrs (config.time.timeZone != null) {
    localtime.source = "/etc/zoneinfo/${config.time.timeZone}";
    localtime.mode = "direct-symlink";
  };
```

**Key insight**: `/etc/localtime` is ONLY created when `time.timeZone` is not null.

#### automatic-timezoned.nix (Sets timeZone to null)

```nix
# From nixpkgs/nixos/modules/services/system/automatic-timezoned.nix
config = mkIf cfg.enable {
  time.timeZone = null;  # <-- This causes the problem
  # ...
};
```

The module sets `time.timeZone = null` at default priority (~1000), which overrides the user's `lib.mkDefault` (priority ~1500).

### Priority System in NixOS

| Priority | Function | Description |
|----------|----------|-------------|
| ~50 | `lib.mkForce` | Highest priority, overrides everything |
| ~100 | `lib.mkOverride 100` | High priority |
| ~1000 | Normal assignment | Default priority |
| ~1500 | `lib.mkDefault` | Low priority default |

Since `time.timeZone = null` (priority 1000) beats `lib.mkDefault "America/Los_Angeles"` (priority 1500), the timezone becomes null.

### geoclue Static Source Already Enabled

The current configuration has static source enabled:
```ini
[static-source]
enable=true
```

However, this doesn't help because automatic-timezoned still fails to get location data before geoclue shuts down (60-second hardcoded idle timeout).

## Solutions Analysis

### Option 1: Use lib.mkForce for timezone (RECOMMENDED)

**Approach**: Force the timezone to be set, ensuring `/etc/localtime` exists.

```nix
# Force timezone to always be set (creates /etc/localtime)
time.timeZone = lib.mkForce "America/Los_Angeles";

# Keep automatic-timezoned enabled - it will override via timedatectl when successful
services.automatic-timezoned.enable = true;
```

**How it works**:
1. `lib.mkForce` (priority ~50) beats automatic-timezoned's `null` (priority ~1000)
2. `/etc/localtime` is created pointing to America/Los_Angeles
3. automatic-timezoned can still update via timedatectl if geolocation succeeds
4. Programs always have a valid `/etc/localtime` to read

**Pros**:
- Always have a valid `/etc/localtime`
- automatic-timezoned can still work when geolocation succeeds
- Most elegant: single line change
- System functions correctly even if automatic-timezoned never succeeds

**Cons**:
- If geolocation works but conflicts with forced timezone, brief inconsistency (resolved by automatic-timezoned)

### Option 2: Manual /etc/localtime symlink

**Approach**: Create the symlink separately from time.timeZone.

```nix
environment.etc."localtime" = {
  source = "/etc/zoneinfo/America/Los_Angeles";
  mode = "direct-symlink";
};
```

**Pros**:
- Explicit control over symlink
- Doesn't conflict with automatic-timezoned's `time.timeZone = null`

**Cons**:
- More complex than Option 1
- May conflict with timedatectl updates
- Not idiomatic NixOS

### Option 3: Disable automatic-timezoned

**Approach**: Simply don't use automatic timezone detection.

```nix
# Remove this line or set to false:
services.automatic-timezoned.enable = false;

# Set static timezone
time.timeZone = "America/Los_Angeles";
```

**Pros**:
- Simplest configuration
- No geoclue complexity

**Cons**:
- Lose automatic timezone when traveling
- Not what user wants (per task 15 research)

### Option 4: Fix automatic-timezoned geoclue issues (Task #16)

**Approach**: Make automatic-timezoned actually work, so it sets timezone via timedatectl.

This is already being addressed in task #16. The restart-on-failure configuration helps but doesn't solve the fundamental geoclue 60-second timeout issue.

**Pros**:
- Addresses root cause
- Full automatic timezone functionality

**Cons**:
- Complex (geoclue has hardcoded timeout)
- Still needs fallback for when geolocation fails
- Doesn't help in the meantime

## Recommendations

### Priority 1: Use lib.mkForce for time.timeZone (MOST ELEGANT)

Change configuration.nix:

```nix
# California default with automatic detection override
# Use lib.mkForce to ensure /etc/localtime always exists
# automatic-timezoned can still override via timedatectl when geolocation works
time.timeZone = lib.mkForce "America/Los_Angeles";
```

This single change:
1. Ensures `/etc/localtime` always exists
2. Fixes Lean LSP and other programs
3. Preserves automatic-timezoned functionality
4. Provides sensible California default

### Priority 2: Continue Task #16 work

The geoclue/automatic-timezoned D-Bus disconnect issue should still be addressed for proper automatic timezone updates.

### Priority 3: Consider TZ environment variable

If specific programs need timezone without `/etc/localtime`, they can use:
```nix
environment.variables.TZ = "America/Los_Angeles";
```

But this is unnecessary if Option 1 is implemented.

## Implementation Strategy

### Minimal Change

```diff
-time.timeZone = lib.mkDefault "America/Los_Angeles";
+time.timeZone = lib.mkForce "America/Los_Angeles";
```

### Verification

After `sudo nixos-rebuild switch --flake .`:

```bash
# Verify /etc/localtime exists
ls -la /etc/localtime
# Should show: lrwxrwxrwx ... /etc/localtime -> /etc/zoneinfo/America/Los_Angeles

# Verify timedatectl
timedatectl status
# Should show: Time zone: America/Los_Angeles (PST, -0800) or (PDT, -0700)

# Test Lean LSP
nvim test.lean  # Should work without watchdog error
```

## Risks and Mitigations

### Risk: lib.mkForce is heavy-handed

**Concern**: Using mkForce might conflict with other modules.

**Mitigation**: No other module sets time.timeZone with force priority. The automatic-timezoned module explicitly expects users to manage priority conflicts.

### Risk: Timezone mismatch when traveling

**Concern**: If user travels to different timezone and geolocation fails, system stays on Los Angeles time.

**Mitigation**: This is acceptable behavior - user can manually run `timedatectl set-timezone` or wait for geolocation to succeed (with task #16 restart improvements).

### Risk: automatic-timezoned becomes ineffective

**Concern**: Maybe timedatectl can't override NixOS-managed /etc/localtime?

**Mitigation**: `timedatectl set-timezone` creates its own `/etc/localtime` symlink, which would override the NixOS-created one until next nixos-rebuild. This is the intended behavior documented by automatic-timezoned module.

## Appendix

### References

- [NixOS locale.nix source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/locale.nix)
- [NixOS automatic-timezoned.nix source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/system/automatic-timezoned.nix)
- [chrono#755 - Panic with missing /etc/localtime](https://github.com/chronotope/chrono/issues/755)
- [timedatectl man page](https://man.archlinux.org/man/timedatectl.1.en)
- [Lean.Server.Watchdog documentation](https://leanprover-community.github.io/mathlib4_docs/Lean/Server/Watchdog.html)
- [NixOS Discourse - Timezones on a laptop](https://discourse.nixos.org/t/timezones-how-to-setup-on-a-laptop/33853)

### System Configuration Context

Current timezone-related configuration from configuration.nix:
```nix
time.timeZone = lib.mkDefault "America/Los_Angeles";
services.automatic-timezoned.enable = true;
services.geoclue2 = {
  enable = true;
  enableWifi = lib.mkForce true;
  enableStatic = true;
  staticLatitude = 37.77;
  staticLongitude = -122.42;
  # ...
};
```

### Search Queries Used

1. "NixOS /etc/localtime missing automatic-timezoned timedatectl"
2. "NixOS time.timeZone /etc/localtime symlink not created"
3. "Lean LSP leanls localtime watchdog error NixOS"
4. "Lean 4 leanls watchdog localtime error code 2"
5. "Watchdog error /etc/localtime no such file Rust Go program"
6. "timedatectl set-timezone creates /etc/localtime symlink"
7. "NixOS time.timeZone lib.mkDefault automatic-timezoned override priority"

### Decision Summary

| Solution | Elegance | Reliability | Complexity |
|----------|----------|-------------|------------|
| lib.mkForce timezone | High | High | Low |
| Manual /etc/localtime | Low | Medium | Medium |
| Disable automatic-timezoned | Medium | High | Low |
| Fix geoclue (task #16) | High | Medium | High |

**Chosen**: `lib.mkForce` for `time.timeZone` - most elegant single-line fix.
