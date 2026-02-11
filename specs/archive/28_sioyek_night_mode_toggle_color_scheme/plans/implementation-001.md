# Implementation Plan: Task #28

- **Task**: 28 - sioyek_night_mode_toggle_color_scheme
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/28_sioyek_night_mode_toggle_color_scheme/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Configure sioyek's 'w' key toggle to switch to a visually appealing night mode with soft grey-blue colors instead of the current light sepia mode. The implementation involves updating the `custom_background_color` and `custom_text_color` values in the sioyek preferences configuration to use a Nord-inspired color palette designed for eye comfort during extended reading sessions.

### Research Integration

From research-001.md:
- Current 'w' key toggles `toggle_custom_color` which uses light gruvbox theme (cream/sepia)
- Solution: Update custom colors to use Nord-inspired soft blue-grey palette
- Recommended colors: Nord0 (#2e3440) for background, Nord4 (#d8dee9) for text
- UI colors should be updated to complement the night mode theme

## Goals & Non-Goals

**Goals**:
- Update `custom_background_color` to soft grey-blue (Nord0: 0.180 0.204 0.251)
- Update `custom_text_color` to muted white (Nord4: 0.847 0.871 0.914)
- Verify the 'w' key toggle produces a comfortable night reading experience

**Non-Goals**:
- Changing the default startup colors (light gruvbox theme remains default)
- Modifying key bindings
- Updating UI colors (current UI matches the light theme which is the startup state)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Colors may not look as expected | Low | Low | Test with sample PDFs after configuration change |
| Contrast may be too low for readability | Low | Low | Nord palette is specifically designed for readability; can adjust if needed |

## Implementation Phases

### Phase 1: Update Custom Colors [COMPLETED]

**Goal**: Modify sioyek-prefs.config to use Nord-inspired night mode colors for the toggle_custom_color feature.

**Tasks**:
- [ ] Update `custom_background_color` from `0.922 0.859 0.698` to `0.180 0.204 0.251`
- [ ] Update `custom_text_color` from `0.235 0.220 0.212` to `0.847 0.871 0.914`
- [ ] Update the comment to reflect the new purpose (night mode instead of light theme)

**Timing**: 15 minutes

**Files to modify**:
- `config/sioyek-prefs.config` - Update custom_background_color and custom_text_color values

**Verification**:
- Launch sioyek with a PDF document
- Press 'w' to toggle custom colors
- Verify soft grey-blue background with light text appears
- Press 'w' again to toggle back to light sepia mode
- Confirm colors are comfortable for reading

---

## Testing & Validation

- [ ] Configuration file is syntactically valid (sioyek launches without errors)
- [ ] Pressing 'w' toggles to soft grey-blue night mode
- [ ] Pressing 'w' again returns to light sepia mode
- [ ] Night mode colors are comfortable for extended reading

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-YYYYMMDD.md (after completion)

## Rollback/Contingency

If the new colors are not satisfactory:
1. Revert the custom color values to original:
   - `custom_background_color 0.922 0.859 0.698`
   - `custom_text_color 0.235 0.220 0.212`
2. Alternative: Try Solarized Dark or Dracula palettes from research report
