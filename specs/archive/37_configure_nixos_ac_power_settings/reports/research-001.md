# Research Report: Configure NixOS AC Power Settings

- **Task**: 37 - Configure NixOS AC Power Settings
- **Started**: 2026-02-17T00:00:00Z
- **Completed**: 2026-02-17T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Local configuration files (home.nix, configuration.nix)
  - NixOS Discourse discussions
  - GNOME System Admin Guide
  - NixOS Wiki Power Management
- **Artifacts**: specs/37_configure_nixos_ac_power_settings/reports/research-001.md
- **Standards**: report-format.md, nix.md

## Executive Summary

- The user's existing configuration in home.nix already sets power management via dconf
- Screen blank is controlled by `org.gnome.desktop.session.idle-delay` (currently 300s = 5 minutes)
- System suspend/sleep is controlled by `org.gnome.settings-daemon.plugins.power.sleep-inactive-ac-timeout` (currently 900s = 15 minutes)
- To meet requirements (screen off at 5 min, no suspend for 1 hour), set `sleep-inactive-ac-timeout = 3600` (1 hour) and optionally `sleep-inactive-ac-type = "nothing"` to completely disable auto-suspend on AC
- All configuration can remain in home.nix using the existing dconf.settings pattern

## Context & Scope

The user wants to configure power settings for AC power on their NixOS system with GNOME desktop:
- **Screen timeout**: Turn off screen after 5 minutes of inactivity (already configured)
- **Process continuation**: Allow processes to continue running for up to an hour (requires change)
- **Declarative configuration**: Use NixOS/Home Manager configuration, not GNOME GUI settings

The system runs NixOS with GNOME desktop environment. Home Manager is used for user-level configuration.

## Findings

### Existing Configuration

The current home.nix (lines 52-61) already contains power management settings:

```nix
# Power management and sleep settings
"org/gnome/desktop/session" = {
  idle-delay = 300;  # 5 minutes - when screen dims/blanks
};

"org/gnome/settings-daemon/plugins/power" = {
  sleep-inactive-ac-timeout = 900;      # 15 minutes on AC power
  sleep-inactive-battery-timeout = 900; # 15 minutes on battery
  idle-dim = true;                      # Dim screen before blanking
};
```

### Key dconf Settings for GNOME Power Management

| dconf Path | Setting | Description | Current | Desired |
|------------|---------|-------------|---------|---------|
| `org/gnome/desktop/session` | `idle-delay` | Seconds until screen blanks | 300 (5 min) | 300 (5 min) - no change |
| `org/gnome/settings-daemon/plugins/power` | `sleep-inactive-ac-timeout` | Seconds until suspend on AC | 900 (15 min) | 3600 (60 min) |
| `org/gnome/settings-daemon/plugins/power` | `sleep-inactive-ac-type` | Action when AC timeout reached | (unset, defaults to suspend) | "nothing" (optional) |
| `org/gnome/settings-daemon/plugins/power` | `idle-dim` | Dim screen before blanking | true | true - no change |

### Understanding the Two Timeouts

1. **Screen Blank (`idle-delay`)**: Controls when the display turns off. Value of 300 means 5 minutes.

2. **Sleep/Suspend (`sleep-inactive-ac-timeout`)**: Controls when the system suspends AFTER becoming idle. This timeout starts counting AFTER the session becomes idle (after screen blanks).

3. **Sleep Action Type (`sleep-inactive-ac-type`)**: Determines what happens when the sleep timeout is reached:
   - `"suspend"` (default) - System suspends to RAM
   - `"hibernate"` - System hibernates to disk
   - `"nothing"` - No action (processes continue indefinitely)
   - `"blank"` - Only blanks screen (redundant with idle-delay)

### Recommended Configuration

To achieve "screen off at 5 min, processes continue for 1 hour on AC":

**Option A: Allow suspend after 1 hour**
```nix
"org/gnome/settings-daemon/plugins/power" = {
  sleep-inactive-ac-timeout = 3600;     # 60 minutes on AC power
  sleep-inactive-battery-timeout = 900; # 15 minutes on battery (unchanged)
  idle-dim = true;                      # Dim screen before blanking
};
```

**Option B: Disable auto-suspend entirely on AC**
```nix
"org/gnome/settings-daemon/plugins/power" = {
  sleep-inactive-ac-type = "nothing";   # Never auto-suspend on AC
  sleep-inactive-ac-timeout = 3600;     # Ignored when type is "nothing", but good for documentation
  sleep-inactive-battery-timeout = 900; # 15 minutes on battery
  idle-dim = true;                      # Dim screen before blanking
};
```

### Alternative: System-Level Configuration

If dconf settings prove unreliable (known issue in some NixOS versions), systemd logind can be used:

```nix
# In configuration.nix
services.logind.extraConfig = ''
  IdleAction=ignore
  IdleActionSec=3600
'';
```

However, GNOME typically overrides logind settings, so dconf is the preferred approach for GNOME desktop.

### Known Issues

1. **GNOME Settings Bug**: There's a known issue (nixpkgs#263008) where changing Power Mode in GNOME Settings GUI has no effect. Using declarative dconf settings bypasses this.

2. **Home Manager dconf Refresh**: If settings don't apply after `nixos-rebuild switch`, restart the home-manager service: `systemctl restart home-manager-$USER`

## Decisions

1. **Use Option A**: Set `sleep-inactive-ac-timeout = 3600` (1 hour) rather than disabling suspend entirely. This provides the requested 1-hour window while still allowing eventual suspend for power saving.

2. **Keep in home.nix**: Continue using the existing dconf.settings pattern in home.nix. This is the established pattern and provides per-user configuration.

3. **No logind changes**: Avoid modifying systemd logind since GNOME dconf settings take precedence for GNOME sessions.

## Recommendations

1. **Primary Change**: Update `sleep-inactive-ac-timeout` from 900 to 3600 in home.nix

2. **Consider Battery Settings**: The battery timeout is also currently 15 minutes. Consider if 1 hour is also appropriate for battery operation (not recommended due to battery drain).

3. **Test After Rebuild**: After running `nixos-rebuild switch`, verify settings applied:
   ```bash
   gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout
   # Should return: 3600
   ```

4. **Optional Enhancement**: Add `sleep-inactive-ac-type = "nothing"` if you want to completely prevent auto-suspend on AC power and rely on manual suspend/hibernate only.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Settings don't apply | Low | Restart home-manager service, logout/login |
| Battery drain if used on battery | Medium | Keep battery timeout at 15 minutes (unchanged) |
| Confusion between screen blank and suspend | Low | Document both settings with clear comments |

## Appendix

### References

- [NixOS Discourse: Sleep, Inactive, AC](https://discourse.nixos.org/t/sleep-inactive-ac/28996)
- [NixOS Wiki: Power Management](https://nixos.wiki/wiki/Power_Management)
- [GNOME Admin Guide: Lock Screen](https://help.gnome.org/admin/system-admin-guide/stable/desktop-lockscreen.html.en)
- [nixpkgs Issue #263008: GNOME Settings Power Mode](https://github.com/NixOS/nixpkgs/issues/263008)
- [Declarative GNOME Configuration with NixOS](https://hoverbear.org/blog/declarative-gnome-configuration-in-nixos/)

### gsettings Commands for Verification

```bash
# Check current screen blank timeout
gsettings get org.gnome.desktop.session idle-delay

# Check current AC sleep timeout
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout

# Check AC sleep action type
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type

# List all power settings
gsettings list-recursively org.gnome.settings-daemon.plugins.power
```

### Valid Values for sleep-inactive-*-type

- `"blank"` - Blank screen only
- `"suspend"` - Suspend to RAM (default)
- `"shutdown"` - Power off
- `"hibernate"` - Hibernate to disk
- `"interactive"` - Ask user
- `"nothing"` - Do nothing (disable auto-action)
- `"logout"` - Log out user
