# Plan 011: GNOME Keyboard Shortcuts in Home Manager

**Status**: Planned  
**Created**: 2025-12-19  
**Priority**: Medium

## Problem Statement

Keyboard shortcuts are currently split between declarative configuration in `home.nix` and manual GNOME settings:

1. **Super+h/l** for workspace switching was manually added to GNOME and is now working
2. **Shift+Super+h/j/k/l** for moving windows between monitors is set in GNOME but not working
3. **Custom keybindings** (Super+z for Zotero, Super+d for dictation) are manually configured in GNOME

This split configuration reduces reproducibility - a fresh system rebuild won't have these shortcuts configured.

## Current State Analysis

### Already in home.nix (Lines 60-96)

```nix
"org/gnome/desktop/wm/keybindings" = {
  close = [ "<Super>q" ];
  cycle-windows = [ "<Super>space" ];
  cycle-windows-backward = [ "<Shift><Super>space" ];
  maximize = [ "<Shift><Control>k" ];
  move-to-monitor-down = [ "<Shift><Super>j" ];
  move-to-monitor-left = [ "<Shift><Super>h" ];
  move-to-monitor-right = [ "<Shift><Super>l" ];
  move-to-monitor-up = [ "<Shift><Super>k" ];
  move-to-workspace-left = [ "<Shift><Alt>h" ];
  move-to-workspace-right = [ "<Shift><Alt>l" ];
  unmaximize = [ "<Shift><Control>j" ];
};

"org/gnome/mutter/keybindings" = {
  toggle-tiled-left = [ "<Shift><Control>h" ];
  toggle-tiled-right = [ "<Shift><Control>l" ];
};

"org/gnome/settings-daemon/plugins/media-keys" = {
  control-center = [ "<Super>backslash" ];
  custom-keybindings = [
    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
  ];
  home = [ "<Super>f" ];
  screensaver = [ "<Super>grave" ];
  www = [ "<Super>b" ];
};

"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
  binding = "<Super>t";
  command = "wezterm";
  name = "Terminal";
};
```

### Missing from home.nix (Currently Manual in GNOME)

From `gsettings` output:

```bash
# Workspace switching (working after manual addition)
switch-to-workspace-left = ['<Super>h']
switch-to-workspace-right = ['<Super>l']

# Custom keybindings (manually configured)
custom1: binding='<Super>z', command='zotero', name='Zotero'
custom2: binding='<Super>d', command='whisper-dictate', name='Dictation'
```

### Issue: Shift+Super+h/j/k/l Not Working

The keybindings for moving windows between monitors are **already in home.nix** but not working:
- `move-to-monitor-left = [ "<Shift><Super>h" ]`
- `move-to-monitor-down = [ "<Shift><Super>j" ]`
- `move-to-monitor-up = [ "<Shift><Super>k" ]`
- `move-to-monitor-right = [ "<Shift><Super>l" ]`

**Root cause investigation needed**: These are correctly configured but may be:
1. Conflicting with other keybindings
2. Not working in single-monitor setup (need multiple monitors to test)
3. Overridden by GNOME Shell extensions (Unite extension is active)

## Proposed Changes

### 1. Add Workspace Switching Keybindings

Add to `"org/gnome/desktop/wm/keybindings"` section in `home.nix`:

```nix
switch-to-workspace-left = [ "<Super>h" ];
switch-to-workspace-right = [ "<Super>l" ];
```

### 2. Add Missing Custom Keybindings

Update the custom keybindings section:

```nix
"org/gnome/settings-daemon/plugins/media-keys" = {
  control-center = [ "<Super>backslash" ];
  custom-keybindings = [
    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
  ];
  home = [ "<Super>f" ];
  screensaver = [ "<Super>grave" ];
  www = [ "<Super>b" ];
};

# Terminal (already exists)
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
  binding = "<Super>t";
  command = "wezterm";
  name = "Terminal";
};

# Zotero (NEW)
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
  binding = "<Super>z";
  command = "zotero";
  name = "Zotero";
};

# Dictation (NEW)
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
  binding = "<Super>d";
  command = "whisper-dictate";
  name = "Dictation";
};
```

### 3. Investigate Shift+Super+h/j/k/l Issue

**Diagnostic steps**:

1. Check for keybinding conflicts:
   ```bash
   gsettings list-recursively | grep -E "(Shift.*Super.*[hjkl]|Super.*Shift.*[hjkl])"
   ```

2. Test with multiple monitors connected (may only work in multi-monitor setup)

3. Check if Unite extension is intercepting these keybindings:
   ```bash
   dconf dump /org/gnome/shell/extensions/unite/
   ```

4. Verify the keybindings are actually applied:
   ```bash
   gsettings get org.gnome.desktop.wm.keybindings move-to-monitor-left
   gsettings get org.gnome.desktop.wm.keybindings move-to-monitor-right
   # etc.
   ```

**Potential fixes**:
- If conflicting with other shortcuts, disable the conflicting ones
- If Unite extension is interfering, configure it to not override these keys
- If only works with multiple monitors, document this limitation

## Implementation Steps

### Step 1: Update home.nix

Edit `/home/benjamin/.dotfiles/home.nix`:

1. Add workspace switching keybindings to line ~60 in the `"org/gnome/desktop/wm/keybindings"` section:
   ```nix
   switch-to-workspace-left = [ "<Super>h" ];
   switch-to-workspace-right = [ "<Super>l" ];
   ```

2. Update custom keybindings list at line ~83:
   ```nix
   custom-keybindings = [
     "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
     "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
     "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
   ];
   ```

3. Add custom1 and custom2 definitions after custom0 (after line ~96):
   ```nix
   "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
     binding = "<Super>z";
     command = "zotero";
     name = "Zotero";
   };

   "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
     binding = "<Super>d";
     command = "whisper-dictate";
     name = "Dictation";
   };
   ```

### Step 2: Apply Configuration

```bash
cd ~/.dotfiles
home-manager switch --flake .#benjamin
```

### Step 3: Verify Changes

```bash
# Check workspace switching
gsettings get org.gnome.desktop.wm.keybindings switch-to-workspace-left
gsettings get org.gnome.desktop.wm.keybindings switch-to-workspace-right

# Check custom keybindings
dconf dump /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/

# Test the shortcuts
# Super+h/l - switch workspaces
# Super+z - open Zotero
# Super+d - start dictation
```

### Step 4: Investigate Monitor Movement Issue

```bash
# Check current values
gsettings get org.gnome.desktop.wm.keybindings move-to-monitor-left
gsettings get org.gnome.desktop.wm.keybindings move-to-monitor-down
gsettings get org.gnome.desktop.wm.keybindings move-to-monitor-up
gsettings get org.gnome.desktop.wm.keybindings move-to-monitor-right

# Look for conflicts
gsettings list-recursively | grep -E "(Shift.*Super.*[hjkl]|Super.*Shift.*[hjkl])"

# Check Unite extension settings
dconf dump /org/gnome/shell/extensions/unite/
```

If conflicts are found, add them to home.nix as empty arrays to disable:
```nix
conflicting-keybinding = [];
```

### Step 5: Update Documentation

Update `docs/gnome-settings.md` to reflect the new keybindings:

```markdown
### Window Manager Keybindings (Vim-style)
| Keybinding | Action |
|------------|--------|
| `Super+h/l` | Switch workspace left/right |
| `Shift+Alt+h/l` | Move window to workspace left/right |
| `Shift+Super+hjkl` | Move window to monitor (if multiple monitors) |
| ... (rest of table) ...

### Custom Application Keybindings
| Keybinding | Application |
|------------|-------------|
| `Super+t` | WezTerm (terminal) |
| `Super+z` | Zotero |
| `Super+d` | Whisper dictation |
| ... (rest of table) ...
```

## Expected Outcomes

1. ✅ **Super+h/l** workspace switching is declaratively managed in home.nix
2. ✅ **Super+z** (Zotero) and **Super+d** (dictation) are declaratively managed
3. ✅ All keyboard shortcuts survive system rebuilds
4. ⚠️ **Shift+Super+h/j/k/l** issue diagnosed and either fixed or documented

## Testing Checklist

- [ ] Super+h switches to workspace on the left
- [ ] Super+l switches to workspace on the right
- [ ] Super+z opens Zotero
- [ ] Super+d starts whisper dictation
- [ ] Super+t still opens WezTerm (existing)
- [ ] Shift+Alt+h/l still moves windows between workspaces (existing)
- [ ] Shift+Super+h/j/k/l moves windows between monitors (investigate)
- [ ] All shortcuts work after `home-manager switch`
- [ ] All shortcuts work after system reboot

## Rollback Plan

If issues occur:

```bash
# Revert home.nix changes
git checkout home.nix

# Reapply previous configuration
home-manager switch --flake .#benjamin

# Or manually reset specific keybindings
gsettings reset org.gnome.desktop.wm.keybindings switch-to-workspace-left
gsettings reset org.gnome.desktop.wm.keybindings switch-to-workspace-right
```

## Notes

- GNOME's workspace switching with Super+h/l may conflict with application shortcuts in some apps
- The move-to-monitor shortcuts may only work when multiple monitors are connected
- Unite extension may need configuration to avoid intercepting these shortcuts
- Consider adding Super+j/k for vertical workspace switching if using a grid layout

## References

- [Home Manager dconf module](https://nix-community.github.io/home-manager/options.html#opt-dconf.settings)
- [GNOME Keybindings Schema](https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas/-/blob/master/schemas/org.gnome.desktop.wm.keybindings.gschema.xml.in)
- Current configuration: `~/.dotfiles/home.nix` lines 38-97
- Documentation: `~/.dotfiles/docs/gnome-settings.md`
