# Research Report: Task #28

**Task**: 28 - sioyek_night_mode_toggle_color_scheme
**Started**: 2026-02-10T00:00:00Z
**Completed**: 2026-02-10T00:15:00Z
**Effort**: low
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, sioyek GitHub repository, sioyek documentation, Dracula/Nord theme references
**Artifacts**: specs/28_sioyek_night_mode_toggle_color_scheme/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The 'w' key in sioyek toggles `toggle_custom_color` which uses `custom_background_color` and `custom_text_color` from prefs.config
- Current configuration has `custom_background_color` set to a light gruvbox theme (cream/sepia), toggling 'w' switches to light mode not night mode
- Solution: Swap the color roles - make default startup use light colors, and configure `custom_background_color`/`custom_text_color` to use soft grey-blue night mode colors
- Recommended night mode palette: Nord-inspired soft blue-grey background with muted white text for eye comfort

## Context & Scope

The user wants to reconfigure sioyek's 'w' key behavior. Currently pressing 'w' toggles to a light cream/sepia mode. The goal is to make 'w' toggle to a visually appealing night mode with soft grey-blue colors instead.

### Current Configuration Analysis

From `/home/benjamin/.dotfiles/config/sioyek-prefs.config`:

```
# Default colors (dark gruvbox-inspired):
background_color 0.114 0.125 0.129
text_color 0.922 0.859 0.698

# Dark mode same as default:
dark_mode_background_color 0.114 0.125 0.129

# Custom colors (currently light theme - toggled with 'w'):
custom_background_color 0.922 0.859 0.698
custom_text_color 0.235 0.220 0.212

# Startup command:
startup_commands toggle_custom_color;turn_on_synctex
```

**Current behavior**: App starts by executing `toggle_custom_color`, which activates the light cream theme. Pressing 'w' toggles back to the dark default.

**Desired behavior**: App starts in light/sepia mode for day reading, pressing 'w' toggles to a soft grey-blue night mode.

## Findings

### How toggle_custom_color Works

From [Sioyek documentation](https://sioyek-documentation.readthedocs.io/en/latest/commands.html):
- `toggle_custom_color` switches between normal rendering and custom colors
- Custom colors are defined by `custom_background_color` and `custom_text_color`
- By default, 'w' is NOT bound to any command (F8 is bound to `toggle_dark_mode`)
- The 'w' key binding must come from a custom `keys_user.config` file (not present in dotfiles)

**Investigation needed**: The 'w' key must be bound somewhere. Since no `keys_user.config` exists in the dotfiles, sioyek may have a default 'w' binding or there's a system-level config.

After checking [sioyek keys.config on GitHub](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/keys.config), the default bindings show:
- `toggle_custom_color` is commented out (not bound by default)
- `toggle_dark_mode` is bound to `<f8>`

**Conclusion**: The 'w' key is likely bound to `toggle_custom_color` in sioyek's default distribution, or the user has customized it outside the dotfiles.

### Color Configuration Options

From [sioyek prefs.config](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/prefs.config):

| Setting | Purpose |
|---------|---------|
| `background_color r g b` | Application background (not PDF) |
| `dark_mode_background_color r g b` | Background when dark mode enabled |
| `custom_background_color r g b` | PDF background with toggle_custom_color |
| `custom_text_color r g b` | PDF text color with toggle_custom_color |
| `dark_mode_contrast 0.0-1.0` | Reduces white brightness on dark backgrounds |

### Recommended Night Mode Color Palettes

#### Option 1: Nord-Inspired (Recommended)

Soft blue-grey palette designed for eye comfort:

| Color | Hex | RGB (0-1) | Use |
|-------|-----|-----------|-----|
| Nord0 | #2e3440 | 0.180 0.204 0.251 | Background |
| Nord4 | #d8dee9 | 0.847 0.871 0.914 | Text |

**Notably**, these are already sioyek's **defaults** for `custom_background_color` and `custom_text_color` in the upstream config.

#### Option 2: Solarized Dark

Classic precision color scheme:

| Color | Hex | RGB (0-1) | Use |
|-------|-----|-----------|-----|
| base03 | #002b36 | 0.000 0.169 0.212 | Background |
| base0 | #839496 | 0.514 0.580 0.588 | Text |

#### Option 3: Dracula Theme

Popular purple-tinted dark theme:

| Color | Hex | RGB (0-1) | Use |
|-------|-----|-----------|-----|
| Background | #282a36 | 0.157 0.165 0.212 | Background |
| Foreground | #f8f8f2 | 0.973 0.973 0.949 | Text |

From [Dracula for Sioyek](https://github.com/dracula/sioyek/blob/main/dracula.config).

#### Option 4: Soft Blue-Grey (Custom)

Muted blue-grey from community configs:

| Purpose | RGB (0-1) | Notes |
|---------|-----------|-------|
| Background | 0.086 0.098 0.145 | Deep blue-grey |
| Text | 1.0 1.0 1.0 | Pure white |
| Contrast | 0.7 | Reduces eye strain |

From [sioyek discussions #182](https://github.com/ahrm/sioyek/discussions/182).

### Implementation Strategy

The solution requires swapping the color logic:

1. **Default startup colors** should be the light/sepia theme (for day reading)
2. **Custom colors** (toggled with 'w') should be the night mode

**Configuration changes needed**:

```
# Make defaults use light gruvbox theme (what was previously custom)
background_color 0.922 0.859 0.698
text_color 0.235 0.220 0.212

# Set custom colors to night mode (Nord-inspired)
custom_background_color 0.180 0.204 0.251
custom_text_color 0.847 0.871 0.914

# Remove startup toggle (start in light mode)
startup_commands turn_on_synctex
```

Or alternatively, keep the current dark default and make custom colors into a softer night mode:

```
# Keep dark default
background_color 0.114 0.125 0.129
text_color 0.922 0.859 0.698

# Set custom colors to soft grey-blue night mode
custom_background_color 0.180 0.204 0.251
custom_text_color 0.847 0.871 0.914

# Keep startup command
startup_commands toggle_custom_color;turn_on_synctex
```

### UI Color Considerations

When changing the PDF colors, consider updating UI elements to match:

```
# Match UI to the active theme
ui_background_color 0.180 0.204 0.251
ui_text_color 0.847 0.871 0.914
ui_selected_background_color 0.267 0.278 0.353
ui_selected_text_color 0.847 0.871 0.914
status_bar_color 0.180 0.204 0.251
status_bar_text_color 0.847 0.871 0.914
```

## Decisions

1. **Recommended color scheme**: Nord-inspired soft grey-blue for night mode
2. **Implementation approach**: Update `custom_background_color` and `custom_text_color` to use Nord palette
3. **Startup behavior**: Depends on user preference - could start in light or dark mode

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Color values don't look as expected | Low | Test with sample PDFs after configuration |
| UI colors mismatch with PDF colors | Low | Update UI colors to complement theme |
| W key not working as expected | Low | Verify key binding with `:set_key` or check for keys_user.config |

## Implementation Recommendations

### Minimal Change (Preferred)

Simply update the custom colors to use Nord palette. The 'w' toggle will then switch to a soft grey-blue night mode instead of the current light sepia mode:

```
# Custom colors (soft grey-blue night mode)
custom_background_color 0.180 0.204 0.251
custom_text_color 0.847 0.871 0.914
```

### Full Theme Update

For a complete experience, also update:
- UI colors to match the night theme
- Add `dark_mode_contrast 0.8` for eye comfort
- Consider highlight colors that work with both modes

## Appendix

### Search Queries Used
- "sioyek pdf viewer toggle_custom_color w key color scheme configuration"
- "sioyek custom_background_color dark_mode_background_color prefs.config documentation"
- "soft grey blue night mode color scheme hex RGB eye comfortable reading"
- "solarized dark color scheme RGB values"
- "nord color scheme dark mode background foreground RGB values"

### References
- [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)
- [Sioyek Commands Documentation](https://sioyek-documentation.readthedocs.io/en/latest/commands.html)
- [Sioyek prefs.config on GitHub](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/prefs.config)
- [Sioyek keys.config on GitHub](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/keys.config)
- [Dracula Theme for Sioyek](https://github.com/dracula/sioyek)
- [Nord Theme Colors](https://www.nordtheme.com/docs/colors-and-palettes/)
- [Sioyek Config Discussion #182](https://github.com/ahrm/sioyek/discussions/182)
