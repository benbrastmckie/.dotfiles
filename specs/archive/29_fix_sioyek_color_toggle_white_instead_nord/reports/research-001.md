# Research Report: Task #29

**Task**: 29 - fix_sioyek_color_toggle_white_instead_nord
**Started**: 2026-02-10T12:00:00Z
**Completed**: 2026-02-10T12:45:00Z
**Effort**: low
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, sioyek GitHub issues, sioyek documentation
**Artifacts**: specs/29_fix_sioyek_color_toggle_white_instead_nord/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The 'w' key toggle shows white because `toggle_custom_color` only toggles between custom colors ON (uses `custom_background_color`) and custom colors OFF (shows native PDF rendering - white)
- `dark_mode_background_color` and `background_color` only affect the application chrome (area around the PDF), not the PDF content itself
- The current config file contains **7 invalid configuration options** that are being silently rejected by sioyek
- **Solution**: Invert the color scheme logic - use Gruvbox light as the default (custom colors ON at startup), and use Nord dark as the "toggled" state by swapping which colors are in `custom_background_color`

## Context & Scope

The user wants to toggle between two color schemes:
1. **Day mode**: Gruvbox light (cream background, dark text) - current custom colors
2. **Night mode**: Nord dark (blue-grey background, light text) - desired when pressing 'w'

### Current Broken Behavior

- Start: Gruvbox light (custom colors enabled via startup_commands) - **WORKS**
- Press 'w': Shows white PDF background instead of Nord - **BROKEN**

### Root Cause

When `toggle_custom_color` is OFF, sioyek renders the PDF with its native colors (white background, black text). The settings `background_color` and `dark_mode_background_color` only control the application's window background (visible around page margins), not the PDF content.

## Findings

### How Sioyek Color Modes Work

From [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html):

| Setting | Scope | Purpose |
|---------|-------|---------|
| `background_color` | App chrome | Background color shown when page smaller than screen |
| `dark_mode_background_color` | App chrome | Background when dark mode enabled (still app chrome only) |
| `custom_background_color` | PDF content | PDF background when custom color mode is ON |
| `custom_text_color` | PDF content | PDF text when custom color mode is ON |

**Key insight**: There is no way to set a PDF background color when custom colors are OFF. The PDF will always render with its native colors (typically white) when custom color mode is disabled.

### toggle_custom_color vs toggle_dark_mode

| Command | Effect |
|---------|--------|
| `toggle_custom_color` | Switches between native PDF rendering and `custom_background_color`/`custom_text_color` |
| `toggle_dark_mode` | Inverts PDF colors (white becomes black, etc.) - not the same as using Nord colors |

`toggle_dark_mode` inverts rather than applying a specific palette, so it cannot be used to get Nord colors.

### Configuration Errors in Current prefs_user.config

Running sioyek with the current config shows these errors:

```
Error: text_color is not a valid configuration name
Error: dark_mode_text_color is not a valid configuration name
Error: custom_status_bar_color is not a valid configuration name
Error: custom_status_bar_text_color is not a valid configuration name
Error: required 4 values for color, but got 3
Error in config file: visual_mark_color 0.710 0.463 0.078
Error: should_draw_menubar is not a valid configuration name
Error: should_draw_toolbar is not a valid configuration name
```

These options appear to be from an older sioyek version or documentation errors.

### Valid Color Options (sioyek 2.0+)

Based on the [default prefs.config](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/prefs.config):

| Valid Option | Format | Example |
|--------------|--------|---------|
| `background_color` | R G B | `0.97 0.97 0.97` |
| `dark_mode_background_color` | R G B | `0.0 0.0 0.0` |
| `custom_background_color` | R G B | `0.180 0.204 0.251` |
| `custom_text_color` | R G B | `0.847 0.871 0.914` |
| `visual_mark_color` | R G B A | `0.0 0.0 0.0 0.1` (requires 4 values) |
| `status_bar_color` | R G B | `0 0 0` |
| `status_bar_text_color` | R G B | `1 1 1` |

**Not valid**: `text_color`, `dark_mode_text_color`, `custom_status_bar_color`, `custom_status_bar_text_color`, `should_draw_menubar`, `should_draw_toolbar`

### Alternative Approaches Considered

#### 1. Macro-based Theme Switching (Deprecated)

[Issue #397](https://github.com/ahrm/sioyek/issues/397) shows that sioyek's developer added `setconfig_custom_background_color` and `setconfig_custom_text_color` commands that could be used in macros. However, [Issue #1372](https://github.com/ahrm/sioyek/issues/1372) confirms these commands have been deprecated in recent versions and are no longer recognized.

#### 2. Multiple Config Files

Some users attempted using separate config files for different themes, but this is not supported by sioyek's configuration loading mechanism.

#### 3. Invert Color Logic (Recommended)

Since we can only have ONE set of custom colors, and the alternative to custom colors is white, the solution is to choose which color scheme is the "default" (custom colors ON at startup) and which is the "toggled" state (custom colors OFF).

**Problem with current approach**: We want Gruvbox as default and Nord as toggle, but when toggling OFF custom colors, we get white, not Nord.

**Solution**: Accept that we can only have ONE custom color scheme. Choose to use Nord as the custom colors (for night reading), and accept that toggling OFF shows the native PDF (white/light - good for day reading).

## Recommendations

### Option A: Nord Night Mode as Custom Colors (Recommended)

Use Nord as the custom colors, start with custom colors OFF for day reading:

```
# Remove startup toggle - start with native PDF rendering (white/day mode)
startup_commands turn_on_synctex

# Custom colors become the night mode (toggled with 'w')
custom_background_color 0.180 0.204 0.251
custom_text_color 0.847 0.871 0.914
```

**Behavior**:
- Start: Native PDF rendering (white background) - Day mode
- Press 'w': Nord blue-grey background - Night mode

### Option B: Gruvbox Day Mode as Custom Colors, Accept Limitations

Keep Gruvbox as custom colors, accept that pressing 'w' shows white (native PDF):

```
# Keep current startup toggle
startup_commands toggle_custom_color;turn_on_synctex

# Custom colors are Gruvbox light (day mode)
custom_background_color 0.922 0.859 0.698
custom_text_color 0.235 0.220 0.212
```

**Behavior**:
- Start: Gruvbox cream - Day mode (comfortable for sepia preference)
- Press 'w': Native PDF (white) - Reading mode without color tint

This is essentially the inverse of what was requested, but it provides two usable modes.

### Option C: Use toggle_dark_mode for Night Reading

Use `toggle_dark_mode` (F8 by default) for night reading instead of custom colors:

```
# Start with Gruvbox custom colors for day mode
startup_commands toggle_custom_color;turn_on_synctex

# Custom colors are Gruvbox light
custom_background_color 0.922 0.859 0.698
custom_text_color 0.235 0.220 0.212

# Set dark mode contrast for eye comfort
dark_mode_contrast 0.8
```

**Behavior**:
- Start: Gruvbox cream - Day mode
- Press 'w': Native PDF (white)
- Press 'F8': Inverted colors (approximates night mode)

### Config Cleanup Required

Regardless of approach, the following invalid options must be removed:

```diff
- text_color 0.847 0.871 0.914
- dark_mode_text_color 0.847 0.871 0.914
- custom_status_bar_color 0.835 0.769 0.631
- custom_status_bar_text_color 0.235 0.220 0.212
- visual_mark_color 0.710 0.463 0.078  # needs 4th value (alpha)
- should_draw_menubar 0
- should_draw_toolbar 0
```

And fix:
```diff
- visual_mark_color 0.710 0.463 0.078
+ visual_mark_color 0.710 0.463 0.078 0.5
```

## Decisions

1. **Recommendation**: Option A (Nord as custom colors, native PDF as day mode) provides the cleanest toggle between two distinct modes
2. **Config cleanup**: Remove all invalid options to prevent silent failures
3. **Alternative**: If user prefers Gruvbox sepia as default, use Option B and accept white as the toggle state

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| User prefers Gruvbox as default | Low | Offer Option B as alternative |
| Invalid config options causing other issues | Medium | Clean up all invalid options |
| Dark mode contrast not working as expected | Low | Test with `dark_mode_contrast` setting |

## References

- [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)
- [Sioyek Commands Documentation](https://sioyek-documentation.readthedocs.io/en/latest/commands.html)
- [GitHub Issue #521 - Dark mode behavior](https://github.com/ahrm/sioyek/issues/521)
- [GitHub Issue #397 - Custom dark-mode colors](https://github.com/ahrm/sioyek/issues/397)
- [GitHub Issue #1300 - background_color not working with custom_color](https://github.com/ahrm/sioyek/issues/1300)
- [GitHub Issue #1372 - setconfig deprecated](https://github.com/ahrm/sioyek/issues/1372)
- [Sioyek prefs.config on GitHub](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/prefs.config)

## Next Steps

1. Clean up invalid configuration options
2. Choose approach (A or B) based on user preference
3. Update sioyek-prefs.config with valid configuration
4. Test toggle behavior
