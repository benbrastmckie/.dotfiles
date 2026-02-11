# Research Report: Task #31

**Task**: 31 - Implement sioyek 'w' key toggle between Gruvbox and Nord themes
**Started**: 2026-02-11T00:00:00Z
**Completed**: 2026-02-11T00:30:00Z
**Effort**: low
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, sioyek documentation, GitHub issues
**Artifacts**: specs/31_implement_sioyek_w_key_toggle_gruvbox_nord/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- **Root Cause**: The current `_nord w` binding only sets Nord colors; there is no mechanism to detect current theme state and toggle back to Gruvbox
- **Key Insight**: Sioyek has no built-in state-tracking for macros; macros execute unconditionally regardless of current color state
- **Recommended Solution**: Implement an external shell script with state file that tracks current theme and toggles appropriately, invoked via `new_command`

## Context & Scope

Task 30 successfully configured sioyek so that pressing 'w' switches to Nord night mode via the `_nord` macro. The issue is that pressing 'w' again does not switch back to Gruvbox - it simply re-executes the `_nord` macro which has no effect since Nord is already active.

### Current Configuration

**prefs_user.config** (lines 7-8):
```
new_macro _gruvbox setconfig_custom_background_color(0.922 0.859 0.698);setconfig_custom_text_color(0.235 0.220 0.212)
new_macro _nord setconfig_custom_background_color(0.180 0.204 0.251);setconfig_custom_text_color(0.847 0.871 0.914)
```

**keys_user.config**:
```
_nord w
```

### Problem Statement

Sioyek macros are stateless - they execute the same commands every time regardless of the current application state. There is no built-in "if current theme is X, switch to Y, else switch to X" logic.

## Findings

### 1. Sioyek Macro System Limitations

From [Sioyek 2.0 Release Notes](https://ahrm.github.io/jekyll/update/2022/12/12/sioyek-2.html):

- Macros chain commands using semicolons: `new_macro _name cmd1;cmd2;cmd3`
- Macro names must start with underscore (`_`)
- Macros have no conditional logic or state awareness
- `setconfig_*` commands change settings at runtime but don't persist

From [GitHub Issue #397](https://github.com/ahrm/sioyek/issues/397):

> "The way themes work in sioyek is that you can define macros that set colors, and then bind those macros to keys"

This confirms macros are designed for one-directional theme setting, not toggling.

### 2. Available Toggle Commands

From [Sioyek Commands Documentation](https://sioyek-documentation.readthedocs.io/en/latest/commands.html):

| Command | Behavior |
|---------|----------|
| `toggle_custom_color` | Toggles between custom colors ON (uses `custom_background_color`) and OFF (native PDF rendering - white) |
| `toggle_dark_mode` | Inverts PDF colors (not the same as applying Nord palette) |

**Neither of these provides toggle between two custom color palettes.**

### 3. External Script Approach

From [Sioyek Scripting Documentation](https://sioyek-documentation.readthedocs.io/en/latest/scripting.html):

Scripts can communicate with sioyek via command-line:

```bash
sioyek --execute-command command_name
sioyek --execute-command command_name --execute-command-data "data"
```

**Key capability**: The `new_command` directive in `prefs_user.config` allows defining custom commands that execute external scripts:

```
new_command _toggle_theme /path/to/script.sh
```

### 4. Solution Design

The only way to achieve true toggle behavior with a single key is to use an external script that:

1. Maintains state in a file (e.g., `~/.cache/sioyek-theme-state`)
2. Reads the current state when invoked
3. Executes the appropriate `setconfig_*` commands via `sioyek --execute-command`
4. Updates the state file

## Recommendations

### Option A: External Script Toggle (Recommended)

Create a shell script that manages toggle state:

**Script: `~/.local/bin/sioyek-theme-toggle.sh`**
```bash
#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/sioyek-theme-state"

# Ensure state file exists with default value
if [ ! -f "$STATE_FILE" ]; then
    echo "gruvbox" > "$STATE_FILE"
fi

CURRENT_THEME=$(cat "$STATE_FILE")

if [ "$CURRENT_THEME" = "gruvbox" ]; then
    # Switch to Nord
    sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.180 0.204 0.251"
    sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.847 0.871 0.914"
    echo "nord" > "$STATE_FILE"
else
    # Switch to Gruvbox
    sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.922 0.859 0.698"
    sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.235 0.220 0.212"
    echo "gruvbox" > "$STATE_FILE"
fi
```

**prefs_user.config addition:**
```
new_command _toggle_theme ~/.local/bin/sioyek-theme-toggle.sh
```

**keys_user.config change:**
```
_toggle_theme w
```

**Advantages:**
- True single-key toggle between two themes
- State persists across sioyek restarts
- Clean user experience matching the original request

**Considerations:**
- Requires external script (managed via Home Manager)
- Small delay when executing (shell spawn overhead)
- State file can get out of sync if colors changed manually

### Option B: Two-Key Solution (Simpler)

Keep separate keys for each theme:

**keys_user.config:**
```
_gruvbox w
_nord <S-w>
```

**Advantages:**
- No external dependencies
- Always predictable behavior
- Faster execution (no shell spawn)

**Disadvantages:**
- Requires remembering two keybindings
- Less elegant than true toggle

### Option C: Alias 'w' to toggle_custom_color

Use sioyek's built-in toggle between custom colors and native (white) PDF:

**prefs_user.config:**
- Set `custom_background_color` to Nord
- Remove startup `toggle_custom_color`

**keys_user.config:**
```
toggle_custom_color w
```

**Behavior:**
- Start: Native white PDF
- Press 'w': Nord dark mode
- Press 'w' again: Back to white

**Disadvantages:**
- Doesn't provide Gruvbox - only toggles between Nord and white
- Not what was requested

## Decisions

1. **Recommended approach**: Option A (external script toggle) provides the cleanest single-key toggle experience
2. **Implementation location**: Script should be defined in `home.nix` as a `writeShellScriptBin` for declarative management
3. **State file location**: `~/.cache/sioyek-theme-state` (respects XDG conventions for temporary/cache data)
4. **Startup behavior**: Initialize state file to match `startup_commands` default (Gruvbox)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Script execution delay | Low | Shell script is lightweight; delay is ~50-100ms |
| State file gets corrupted | Low | Script handles missing file gracefully |
| Theme out of sync with state | Medium | Document that manual color changes will desync state |
| sioyek not in PATH when script runs | Medium | Use full path to sioyek binary |

## Implementation Steps

1. Create shell script as `writeShellScriptBin` in `home.nix`
2. Add `new_command _toggle_theme` to `prefs_user.config`
3. Update `keys_user.config` to bind `_toggle_theme` to 'w'
4. Ensure script is executable and sioyek path is correct
5. Test toggle behavior in both directions

## References

- [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)
- [Sioyek Commands Documentation](https://sioyek-documentation.readthedocs.io/en/latest/commands.html)
- [Sioyek Scripting Documentation](https://sioyek-documentation.readthedocs.io/en/latest/scripting.html)
- [Sioyek 2.0 Release Notes](https://ahrm.github.io/jekyll/update/2022/12/12/sioyek-2.html)
- [GitHub Issue #397 - Custom dark-mode colors](https://github.com/ahrm/sioyek/issues/397)
- [GitHub Discussion #622 - setconfig persistence](https://github.com/ahrm/sioyek/discussions/622)
- [GitHub Issue #1372 - setconfig verification](https://github.com/ahrm/sioyek/issues/1372)

## Next Steps

1. Run `/plan 31` to create implementation plan
2. Implement Option A (external script toggle)
3. Verify toggle works in both directions
4. Document the keybinding for user reference
