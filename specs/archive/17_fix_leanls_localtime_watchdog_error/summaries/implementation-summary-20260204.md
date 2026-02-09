# Implementation Summary: Task #17

**Completed**: 2026-02-04
**Duration**: ~10 minutes

## Changes Made

Fixed the Lean LSP (leanls) "Watchdog error: no such file or directory (error code: 2) file: /etc/localtime" by ensuring `/etc/localtime` always exists on system boot.

**Root Cause**: NixOS's automatic-timezoned module sets `time.timeZone = null` at priority ~1000, which overrides the user's `lib.mkDefault "America/Los_Angeles"` (priority ~1500). When `time.timeZone` is null, NixOS's locale.nix module does not create the `/etc/localtime` symlink. Applications like leanls that rely on this file fail with "no such file or directory" errors.

**Solution**: Changed `lib.mkDefault` to `lib.mkForce` for the timezone setting. `lib.mkForce` has priority ~50, which wins over automatic-timezoned's null setting, ensuring the `/etc/localtime` symlink is always created at boot. The automatic-timezoned service can still update the timezone via timedatectl when geolocation works.

## Files Modified

- `configuration.nix` - Changed timezone priority from `lib.mkDefault` to `lib.mkForce` and added explanatory comments documenting the issue and solution

## Configuration Change

```nix
# Before (line 99-101)
# California default with automatic detection override
# The lib.mkDefault allows automatic-timezoned to override when geolocation works
time.timeZone = lib.mkDefault "America/Los_Angeles";

# After
# California default with forced priority to ensure /etc/localtime always exists
# Problem: automatic-timezoned sets time.timeZone = null (priority ~1000), which
# overrides lib.mkDefault (~1500) and causes NixOS to not create /etc/localtime.
# Applications like leanls fail with "no such file or directory: /etc/localtime".
# Solution: lib.mkForce (~50) ensures the symlink always exists at boot, while
# automatic-timezoned can still update the timezone via timedatectl when geolocation works.
time.timeZone = lib.mkForce "America/Los_Angeles";
```

## Verification

- `nix flake check` passes without errors
- Configuration diff shows only the intended change with explanatory comments

## Next Steps (User Required)

1. Run `sudo nixos-rebuild switch --flake .` to apply the configuration
2. Verify `/etc/localtime` symlink exists: `ls -la /etc/localtime`
3. Verify timezone is set: `timedatectl status` (should show America/Los_Angeles)
4. Open a Lean file in Neovim to confirm leanls no longer produces watchdog errors

## Notes

This is a minimal, elegant fix that:
- Requires only a single-line code change (plus explanatory comments)
- Preserves automatic timezone detection functionality
- Ensures system-level file existence rather than per-application workarounds
- Is easily reversible if needed (change `mkForce` back to `mkDefault`)

The fix addresses the symptom (missing /etc/localtime) while task #16 addresses the root cause (automatic-timezoned/geoclue2 D-Bus disconnection issues).
