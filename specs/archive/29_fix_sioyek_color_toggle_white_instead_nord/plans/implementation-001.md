# Implementation Plan: Task #29

- **Task**: 29 - fix_sioyek_color_toggle_white_instead_nord
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/29_fix_sioyek_color_toggle_white_instead_nord/reports/research-001.md, specs/29_fix_sioyek_color_toggle_white_instead_nord/reports/research-002.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

This plan implements Option 1 from research-002.md: two-key theme switching using sioyek macros. The current configuration has invalid options causing silent failures and uses `toggle_custom_color` which only toggles between custom colors ON (Gruvbox) and OFF (white PDF), not between two color schemes. The solution uses `new_macro` with `setconfig_custom_background_color` and `setconfig_custom_text_color` to create runtime theme switching, with `w` for Gruvbox light and `Shift+w` for Nord dark.

### Research Integration

From research-001.md:
- Root cause: `toggle_custom_color` toggles between custom colors and native PDF rendering (white), not between two palettes
- 7 invalid configuration options identified that must be removed

From research-002.md:
- Sioyek 2.0+ supports `setconfig_*` commands in macros for runtime theme switching
- Macro-based approach confirmed working by sioyek maintainer (GitHub Issue #397)
- Two-macro solution (one per theme) is cleanest implementation

## Goals & Non-Goals

**Goals**:
- Enable switching between Gruvbox light (day mode) and Nord dark (night mode) via keyboard
- Clean up all invalid configuration options causing silent failures
- Create keys_user.config for sioyek keybindings
- Start in Gruvbox light (day mode) by default

**Non-Goals**:
- Single-key toggle (requires external state tracking, adds complexity)
- Persisting theme choice across restarts (setconfig changes are session-only by design)
- Modifying other sioyek settings beyond color theme

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| setconfig commands deprecated in future versions | Medium | Low | Use documented syntax, test after sioyek updates |
| Macro syntax errors cause silent failures | Low | Low | Test macros individually before deploying |
| keys_user.config not being loaded | Medium | Low | Verify file location and permissions after creation |

## Implementation Phases

### Phase 1: Clean up invalid configuration options [COMPLETED]

**Goal**: Remove all invalid configuration options from sioyek-prefs.config to eliminate silent errors.

**Tasks**:
- [ ] Remove `text_color` (line 6) - not a valid sioyek option
- [ ] Remove `dark_mode_text_color` (line 10) - not a valid sioyek option
- [ ] Remove `custom_status_bar_color` (line 17) - not a valid sioyek option
- [ ] Remove `custom_status_bar_text_color` (line 18) - not a valid sioyek option
- [ ] Fix `visual_mark_color` (line 39) - add 4th value (alpha channel)
- [ ] Remove `should_draw_menubar` (line 45) - not a valid sioyek option
- [ ] Remove `should_draw_toolbar` (line 46) - not a valid sioyek option
- [ ] Remove `default_dark_mode` (line 49) - not needed with macro approach

**Timing**: 15 minutes

**Files to modify**:
- `config/sioyek-prefs.config` - remove invalid options, fix visual_mark_color

**Verification**:
- Run sioyek and check for absence of "is not a valid configuration name" errors in console

---

### Phase 2: Add theme macros to configuration [COMPLETED]

**Goal**: Define macros for Gruvbox and Nord themes using setconfig commands.

**Tasks**:
- [ ] Add `new_macro _gruvbox` with Gruvbox light colors (cream background, dark text)
- [ ] Add `new_macro _nord` with Nord dark colors (blue-grey background, light text)
- [ ] Add `custom_color_mode_empty_background_color` for consistent appearance
- [ ] Ensure `startup_commands` includes `toggle_custom_color` to start with custom colors ON

**Timing**: 10 minutes

**Files to modify**:
- `config/sioyek-prefs.config` - add macro definitions at top of file

**Verification**:
- Verify macro syntax is correct (underscore prefix, semicolon-separated commands, parentheses for arguments)

---

### Phase 3: Create keys_user.config with keybindings [COMPLETED]

**Goal**: Create new keys configuration file with theme switching keybindings.

**Tasks**:
- [ ] Create `config/sioyek-keys.config` file
- [ ] Bind `_gruvbox` macro to `w` key
- [ ] Bind `_nord` macro to `<S-w>` (Shift+w) key
- [ ] Add comment header explaining the keybindings

**Timing**: 10 minutes

**Files to modify**:
- `config/sioyek-keys.config` - new file

**Verification**:
- Verify file exists and contains correct keybinding syntax

---

### Phase 4: Test and verify solution [COMPLETED]

**Goal**: Verify the complete solution works as expected.

**Tasks**:
- [ ] Open sioyek with a PDF document
- [ ] Verify starts in Gruvbox light (cream background)
- [ ] Press `w` - should stay in or switch to Gruvbox light
- [ ] Press `Shift+w` - should switch to Nord dark (blue-grey background)
- [ ] Press `w` again - should switch back to Gruvbox light
- [ ] Verify no configuration errors in console output

**Timing**: 10 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- Manual visual verification of theme switching
- Console output free of configuration errors

---

## Testing & Validation

- [ ] sioyek starts without configuration errors
- [ ] Default theme is Gruvbox light (cream background, dark text)
- [ ] Pressing `w` applies Gruvbox light theme
- [ ] Pressing `Shift+w` applies Nord dark theme
- [ ] Theme switching is instant (no flicker or delay)
- [ ] Status bar remains visible and readable

## Artifacts & Outputs

- `config/sioyek-prefs.config` - updated with macros, cleaned of invalid options
- `config/sioyek-keys.config` - new file with theme keybindings
- `specs/29_fix_sioyek_color_toggle_white_instead_nord/summaries/implementation-summary-YYYYMMDD.md` - completion summary

## Rollback/Contingency

If implementation fails:
1. Restore original `config/sioyek-prefs.config` from git
2. Delete `config/sioyek-keys.config` if created
3. Original sioyek behavior will be restored (toggle_custom_color between Gruvbox and white)

Alternative if macros don't work:
- Fall back to Option A from research-001.md: Use Nord as custom colors, native PDF as day mode
- This provides two distinct modes but inverts the toggle semantics
