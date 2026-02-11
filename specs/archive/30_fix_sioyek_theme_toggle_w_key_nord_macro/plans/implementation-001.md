# Implementation Plan: Task #30

- **Task**: 30 - Fix sioyek theme toggle: 'w' key should switch from Gruvbox to Nord
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/30_fix_sioyek_theme_toggle_w_key_nord_macro/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

The sioyek keybindings are not loading because the file has the wrong name and is not symlinked. Sioyek requires keybindings to be in `keys_user.config` (not `sioyek-keys.config`) and the file must be symlinked to `~/.config/sioyek/keys_user.config`. This is a simple configuration fix requiring file rename, content update, and home.nix modification.

### Research Integration

Research report identified three issues:
1. Wrong filename (`sioyek-keys.config` should be `keys_user.config`)
2. Missing symlink in `home.nix`
3. Keybindings were backwards (w bound to gruvbox, S-w to nord)

Per user clarification: only 'w' to Nord is needed; no Shift+w binding required.

## Goals & Non-Goals

**Goals**:
- Make 'w' key switch sioyek to Nord night mode
- Rename keybindings file to correct name
- Add proper symlink in home.nix

**Non-Goals**:
- Implementing Shift+w to return to Gruvbox (user will restart sioyek instead)
- Modifying the theme colors themselves (already defined in task 29)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Home Manager build fails | M | L | Use `nix flake check` before rebuild |
| Keybinding conflicts with default 'w' | L | L | Sioyek's `keys_user.config` overrides defaults |

## Implementation Phases

### Phase 1: Rename and Update Keybindings File [COMPLETED]

**Goal**: Create properly named keybindings file with correct binding

**Tasks**:
- [ ] Delete old `config/sioyek-keys.config` file
- [ ] Create new `config/sioyek/keys_user.config` with correct content
- [ ] Verify file contains `_nord w` binding only

**Timing**: 5 minutes

**Files to modify**:
- Delete: `config/sioyek-keys.config`
- Create: `config/sioyek/keys_user.config`

**Verification**:
- File exists at `config/sioyek/keys_user.config`
- Contains `_nord w` binding

---

### Phase 2: Add Symlink in home.nix [COMPLETED]

**Goal**: Configure Home Manager to symlink keybindings file

**Tasks**:
- [ ] Add symlink entry for `keys_user.config` in `home.file` section of `home.nix`
- [ ] Run `nix flake check` to validate configuration

**Timing**: 10 minutes

**Files to modify**:
- `home.nix` - Add symlink near existing sioyek prefs symlink (line 781)

**Verification**:
- `nix flake check` passes
- Entry added: `".config/sioyek/keys_user.config".source = ./config/sioyek/keys_user.config;`

---

### Phase 3: Rebuild and Test [COMPLETED]

**Goal**: Deploy configuration and verify keybinding works

**Tasks**:
- [ ] Run `home-manager switch --flake .#benjamin`
- [ ] Verify symlink exists at `~/.config/sioyek/keys_user.config`
- [ ] Open a PDF in sioyek
- [ ] Press 'w' to verify it switches to Nord theme

**Timing**: 5 minutes

**Verification**:
- Symlink exists: `ls -la ~/.config/sioyek/keys_user.config`
- Sioyek switches to Nord (blue-grey background) when 'w' is pressed

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `home-manager switch` completes without errors
- [ ] Symlink exists at `~/.config/sioyek/keys_user.config`
- [ ] Pressing 'w' in sioyek switches to Nord night mode

## Artifacts & Outputs

- `config/sioyek/keys_user.config` - New keybindings file
- `home.nix` - Updated with keybindings symlink
- `specs/30_fix_sioyek_theme_toggle_w_key_nord_macro/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

If keybinding causes issues:
1. Remove symlink entry from `home.nix`
2. Run `home-manager switch` to restore previous state
3. Sioyek will use default keybindings again
