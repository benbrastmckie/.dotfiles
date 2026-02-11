# Supplementary Research Report: Task #29

**Task**: 29 - fix_sioyek_color_toggle_white_instead_nord
**Started**: 2026-02-10T12:00:00Z
**Completed**: 2026-02-10T12:30:00Z
**Effort**: low
**Dependencies**: None
**Sources/Inputs**: Online research - GitHub issues, sioyek documentation, community themes
**Artifacts**: specs/29_fix_sioyek_color_toggle_white_instead_nord/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- **SOLUTION FOUND**: Sioyek supports `setconfig_custom_background_color` and `setconfig_custom_text_color` commands that can be used in macros to dynamically switch between two color schemes at runtime
- The `new_macro` feature (Sioyek 2.0+) allows chaining these setconfig commands to create theme toggle macros
- GitHub Issue #397 confirms this approach was implemented by the maintainer as the official solution for toggling between multiple color schemes
- A workaround using two macros (one for each theme) bound to different keys provides the cleanest solution

## Context & Scope

Following the initial research (research-001.md), the user requested additional online research to find workarounds for toggling between two color schemes in sioyek. The initial research found that `toggle_custom_color` only toggles between custom colors ON/OFF, not between two custom palettes.

## Findings

### Key Discovery: Runtime setconfig Commands

From [GitHub Discussion #622](https://github.com/ahrm/sioyek/discussions/622) and [Sioyek 2.0 Release Notes](https://ahrm.github.io/jekyll/update/2022/12/12/sioyek-2.html):

Sioyek 2.0 added commands to set configuration options at runtime:
- `setconfig_custom_background_color` - Sets PDF background color dynamically
- `setconfig_custom_text_color` - Sets PDF text color dynamically

These commands accept color values in either:
- RGB format: `0.18 0.20 0.25`
- Hex format: `#2E3440`

**Important limitation**: Settings changed via setconfig commands do NOT persist across restarts. They are session-only.

### Macro-Based Theme Switching

From [GitHub Issue #397](https://github.com/ahrm/sioyek/issues/397) (CLOSED as COMPLETED):

The maintainer (@ahrm) confirmed that macro-based theme switching is the official solution:

> "Using the new features, what you want can be implemented in `prefs_user.config`... Now `_set_solaris_theme`, etc. are like commands that can be bound to keys"

**Macro syntax** from [Sioyek 2.0 Release Notes](https://ahrm.github.io/jekyll/update/2022/12/12/sioyek-2.html):
```
new_macro _macro_name command1;command2;command3
```

Key requirements:
- Macro names MUST start with underscore (`_`)
- Commands separated by semicolons
- Can be bound to keys in `keys_user.config`

### Proposed Solution: Two Theme Macros

Define two macros in `prefs_user.config`:

```
# Gruvbox Light theme (day mode)
new_macro _theme_gruvbox setconfig_custom_background_color(0.922 0.859 0.698);setconfig_custom_text_color(0.235 0.220 0.212)

# Nord theme (night mode)
new_macro _theme_nord setconfig_custom_background_color(0.180 0.204 0.251);setconfig_custom_text_color(0.847 0.871 0.914)
```

Then bind in `keys_user.config`:
```
_theme_gruvbox <C-1>
_theme_nord <C-2>
```

### Alternative: Single Toggle Macro (Complex)

A true toggle (single key for both directions) would require external state tracking, which sioyek doesn't support natively. Options:

1. **Shell script approach**: Use `new_command` to call an external script that:
   - Reads a state file
   - Toggles the state
   - Calls `sioyek --execute-command` with the appropriate setconfig

2. **Accept two-key solution**: Use Ctrl+1 for Gruvbox, Ctrl+2 for Nord (simpler, more reliable)

### Additional Configuration Option: custom_color_mode_empty_background_color

From [GitHub Issue #1100](https://github.com/ahrm/sioyek/issues/1100):

A new config option `custom_color_mode_empty_background_color` was added to control the background color of empty areas when custom colors are enabled. This helps create a consistent appearance:

```
custom_color_mode_empty_background_color #2E3440
```

### setconfig Command Verification

From [GitHub Issue #1372](https://github.com/ahrm/sioyek/issues/1372):

The `setconfig_*` commands are still functional in recent versions (September 2024+). The maintainer confirmed: "works for me both in the september release of sioyek and the latest development branch build"

### Community Theme Examples

From [Catppuccin Sioyek Theme](https://github.com/catppuccin/sioyek):
- Uses `startup_commands toggle_custom_color` to enable custom colors on launch
- Provides multiple "flavors" (Latte, Frappe, Macchiato, Mocha) as separate config files
- Users can manually switch by sourcing different config files

From [Dracula Theme](https://draculatheme.com/sioyek):
- Uses `source` command to include theme file
- Requires `toggle_custom_color` in startup_commands

## Recommendations

### Option 1: Two-Key Theme Switching (Recommended)

The cleanest solution with current sioyek capabilities:

**prefs_user.config**:
```
# Gruvbox Light - cream background, dark text (day mode)
new_macro _gruvbox setconfig_custom_background_color(0.922 0.859 0.698);setconfig_custom_text_color(0.235 0.220 0.212)

# Nord - blue-grey background, light text (night mode)
new_macro _nord setconfig_custom_background_color(0.180 0.204 0.251);setconfig_custom_text_color(0.847 0.871 0.914)

# Start with Gruvbox (day mode)
custom_background_color 0.922 0.859 0.698
custom_text_color 0.235 0.220 0.212
custom_color_mode_empty_background_color 0.922 0.859 0.698

startup_commands toggle_custom_color;turn_on_synctex
```

**keys_user.config**:
```
_gruvbox w
_nord <S-w>
```

**Behavior**:
- Press `w` for Gruvbox light (day mode)
- Press `Shift+w` for Nord dark (night mode)
- Always starts in Gruvbox (day mode)

### Option 2: External Script Toggle (Complex)

For a true single-key toggle, create a shell script:

**~/.local/bin/sioyek-theme-toggle.sh**:
```bash
#!/bin/bash
STATE_FILE="$HOME/.cache/sioyek-theme-state"

if [ ! -f "$STATE_FILE" ] || [ "$(cat "$STATE_FILE")" = "gruvbox" ]; then
    echo "nord" > "$STATE_FILE"
    sioyek --execute-command "setconfig_custom_background_color" --execute-command-data "0.180 0.204 0.251"
    sioyek --execute-command "setconfig_custom_text_color" --execute-command-data "0.847 0.871 0.914"
else
    echo "gruvbox" > "$STATE_FILE"
    sioyek --execute-command "setconfig_custom_background_color" --execute-command-data "0.922 0.859 0.698"
    sioyek --execute-command "setconfig_custom_text_color" --execute-command-data "0.235 0.220 0.212"
fi
```

**prefs_user.config**:
```
new_command _toggle_theme ~/.local/bin/sioyek-theme-toggle.sh
```

**keys_user.config**:
```
_toggle_theme w
```

**Caveats**:
- Requires external script
- May have timing issues with rapid toggles
- State persists in file (survives restarts but may get out of sync)

### Option 3: Accept toggle_custom_color Limitation

If white is acceptable as the "day mode":
- Keep Nord as custom_background_color
- Press `w` to toggle between Nord (custom ON) and white (custom OFF)
- This is the simplest solution with no macros needed

## Decisions

1. **Recommended approach**: Option 1 (two-key theme switching) provides reliable, native theme switching without external dependencies
2. **Alternative if single-key required**: Option 2 (external script) works but adds complexity
3. **Simplest fallback**: Option 3 (accept white as day mode) if user can accept this limitation

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| setconfig commands may change in future versions | Medium | Use documented syntax, test after updates |
| Macro syntax errors cause silent failures | Low | Test macros individually before combining |
| External script approach has timing issues | Low | Add small delay in script if needed |
| Two-key solution less intuitive than toggle | Low | Document key bindings clearly |

## References

- [Sioyek 2.0 Release Notes](https://ahrm.github.io/jekyll/update/2022/12/12/sioyek-2.html) - Macro and setconfig features
- [GitHub Issue #397](https://github.com/ahrm/sioyek/issues/397) - Custom dark-mode colors (CLOSED/COMPLETED)
- [GitHub Discussion #622](https://github.com/ahrm/sioyek/discussions/622) - setconfig persistence behavior
- [GitHub Issue #1100](https://github.com/ahrm/sioyek/issues/1100) - custom_color_mode_empty_background_color
- [GitHub Issue #1372](https://github.com/ahrm/sioyek/issues/1372) - setconfig command verification
- [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)
- [Sioyek Commands Documentation](https://sioyek-documentation.readthedocs.io/en/latest/commands.html)
- [Catppuccin Sioyek Theme](https://github.com/catppuccin/sioyek)
- [Dracula Sioyek Theme](https://draculatheme.com/sioyek)
- [Gruvbox Sioyek Theme](https://mil.ad/blog/2022/gruvbox-for-sioyek.html)

## Next Steps

1. Test the macro-based approach in current sioyek version to verify setconfig commands work
2. Implement Option 1 (two-key switching) or Option 2 (script toggle) based on preference
3. Clean up invalid configuration options identified in research-001.md
4. Update sioyek-prefs.config with the working solution
