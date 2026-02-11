# Implementation Plan: Task #31

- **Task**: 31 - Implement sioyek 'w' key toggle between Gruvbox and Nord themes
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/31_implement_sioyek_w_key_toggle_gruvbox_nord/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Implement a true single-key toggle between Gruvbox and Nord themes in sioyek using an external shell script with state tracking. The script will be created as a Nix derivation via `writeShellScriptBin` in home.nix, invoked through sioyek's `new_command` directive.

### Research Integration

The research report identified that sioyek macros are stateless and cannot implement toggle logic natively. The recommended solution uses an external script that:
1. Maintains state in `~/.cache/sioyek-theme-state`
2. Reads current state and toggles appropriately
3. Uses `sioyek --execute-command setconfig_*` for runtime color changes

## Goals & Non-Goals

**Goals**:
- Single 'w' key toggles between Gruvbox (light) and Nord (dark) themes
- State persists across key presses within a session
- Clean declarative implementation via Nix/Home Manager
- Maintain existing startup behavior (Gruvbox light as default)

**Non-Goals**:
- Persisting theme choice across sioyek restarts (startup always uses Gruvbox)
- Supporting additional themes beyond Gruvbox and Nord
- Modifying sioyek's native toggle_dark_mode or toggle_custom_color behavior

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script execution delay | Low | High | Delay is ~50-100ms, acceptable for theme toggle |
| State file out of sync if colors changed manually | Medium | Low | Document that manual color changes will desync state |
| sioyek binary not found when script runs | High | Low | Use full path from Nix store or rely on PATH |
| Cache directory doesn't exist | Low | Low | Script creates directory with mkdir -p |

## Implementation Phases

### Phase 1: Create Theme Toggle Script [COMPLETED]

**Goal**: Define the toggle script as a Nix derivation in home.nix

**Tasks**:
- [ ] Add `sioyek-theme-toggle` script using `writeShellScriptBin`
- [ ] Script reads state from `~/.cache/sioyek-theme-state`
- [ ] Script toggles between gruvbox and nord based on current state
- [ ] Script uses `sioyek --execute-command` to set colors
- [ ] Script updates state file after toggle

**Timing**: 0.5 hours

**Files to modify**:
- `home.nix` - Add writeShellScriptBin derivation to home.packages

**Implementation details**:

The script should be added to `home.packages` using `pkgs.writeShellScriptBin`:

```nix
(writeShellScriptBin "sioyek-theme-toggle" ''
  STATE_FILE="$HOME/.cache/sioyek-theme-state"
  mkdir -p "$(dirname "$STATE_FILE")"

  # Default to gruvbox if state file doesn't exist
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
'')
```

**Verification**:
- Run `nix flake check` to verify syntax
- After rebuild, verify script exists in PATH: `which sioyek-theme-toggle`
- Verify script is executable and has correct content

---

### Phase 2: Update Sioyek Configuration [COMPLETED]

**Goal**: Configure sioyek to use the toggle script via new_command

**Tasks**:
- [ ] Add `new_command _toggle_theme sioyek-theme-toggle` to prefs_user.config
- [ ] Remove or comment out existing `_gruvbox` and `_nord` macro definitions (or keep for direct access)
- [ ] Update keys_user.config to bind `_toggle_theme` to 'w' instead of `_nord`
- [ ] Update comments to reflect new toggle behavior

**Timing**: 0.5 hours

**Files to modify**:
- `config/sioyek-prefs.config` - Add new_command directive
- `config/sioyek/keys_user.config` - Change binding from `_nord` to `_toggle_theme`

**Implementation details**:

In `config/sioyek-prefs.config`, add after the macro definitions:
```
# Theme toggle command - uses external script with state tracking
new_command _toggle_theme sioyek-theme-toggle
```

In `config/sioyek/keys_user.config`, change:
```
# From:
_nord w

# To:
_toggle_theme w
```

**Verification**:
- Configuration files have valid syntax (no parse errors on sioyek startup)
- `w` key invokes the toggle command

---

### Phase 3: Test and Verify [COMPLETED]

**Goal**: Verify the toggle works correctly in both directions

**Tasks**:
- [ ] Run `home-manager switch` to apply changes
- [ ] Open a PDF in sioyek
- [ ] Verify initial state is Gruvbox (cream background)
- [ ] Press 'w' and verify switch to Nord (blue-grey background)
- [ ] Press 'w' again and verify switch back to Gruvbox
- [ ] Check state file reflects current theme: `cat ~/.cache/sioyek-theme-state`
- [ ] Restart sioyek and verify it starts in Gruvbox (startup_commands behavior)

**Timing**: 0.5 hours

**Files to modify**:
- None (testing only)

**Verification**:
- 'w' toggles from Gruvbox to Nord
- 'w' toggles from Nord back to Gruvbox
- State file correctly tracks current theme
- Sioyek startup behavior unchanged (Gruvbox by default)

---

## Testing & Validation

- [ ] `nix flake check` passes without errors
- [ ] `home-manager switch` succeeds
- [ ] `which sioyek-theme-toggle` returns valid path
- [ ] `sioyek-theme-toggle` executes without errors
- [ ] Theme toggles correctly in both directions
- [ ] State file is created and updated correctly
- [ ] Sioyek startup shows Gruvbox theme

## Artifacts & Outputs

- Modified `home.nix` with writeShellScriptBin for toggle script
- Modified `config/sioyek-prefs.config` with new_command directive
- Modified `config/sioyek/keys_user.config` with updated keybinding
- State file `~/.cache/sioyek-theme-state` created at runtime

## Rollback/Contingency

If the implementation fails or causes issues:

1. **Revert home.nix**: Remove the writeShellScriptBin definition
2. **Revert config files**: Restore `_nord w` binding, remove `new_command _toggle_theme`
3. **Rebuild**: Run `home-manager switch` to apply reverted configuration
4. **Clean state**: Remove `~/.cache/sioyek-theme-state` if it exists

The original macros (`_gruvbox` and `_nord`) are preserved in prefs_user.config and can be re-bound if needed.
