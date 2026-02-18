# Implementation Summary: Task #37

**Completed**: 2026-02-17
**Duration**: ~10 minutes

## Changes Made

Updated the AC power sleep timeout in home.nix from 15 minutes (900 seconds) to 60 minutes (3600 seconds). This allows processes to continue running for up to an hour when on AC power before the system sleeps, while keeping the screen blank timeout at 5 minutes for energy efficiency.

## Files Modified

- `home.nix` - Changed `sleep-inactive-ac-timeout` from 900 to 3600 in dconf settings (line 58)

## Configuration Details

The power settings are managed via dconf under `org/gnome/settings-daemon/plugins/power`:

| Setting | Value | Description |
|---------|-------|-------------|
| `sleep-inactive-ac-timeout` | 3600 | 60 minutes on AC (changed from 15 min) |
| `sleep-inactive-battery-timeout` | 900 | 15 minutes on battery (unchanged) |
| `idle-dim` | true | Dim screen before blanking (unchanged) |

The screen blank timeout (`org/gnome/desktop/session` / `idle-delay = 300`) remains at 5 minutes as intended.

## Verification

- `nix flake check` - Passed without errors
- `nixos-rebuild build --flake .` - Build completed successfully

## Application

To apply the configuration:
```bash
sudo nixos-rebuild switch --flake .
```

After applying, verify with:
```bash
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
# Expected: 3600
```

Note: A logout/login may be required for dconf settings to take effect.

## Notes

- The declarative dconf approach via Home Manager ensures these settings persist across rebuilds
- Battery timeout remains unchanged at 15 minutes to conserve battery life
- Screen blanking at 5 minutes continues to work for display power saving
