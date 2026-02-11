# Research Report: Task #30

**Task**: Fix sioyek theme toggle: 'w' key should switch from Gruvbox to Nord
**Date**: 2026-02-11
**Focus**: Why sioyek keybindings in config/sioyek-keys.config are not being loaded

## Summary

The issue is that sioyek keybindings are not being loaded because the wrong filename is used. The custom keybindings file should be named `keys_user.config` (not `sioyek-keys.config`) and must be symlinked in `~/.config/sioyek/` directory. The current configuration only symlinks `prefs_user.config` but not the keybindings file.

## Findings

### Sioyek Configuration File Names

Sioyek uses a specific set of configuration file names:

1. **Preferences files**:
   - `prefs.config` - Default preferences (shipped with sioyek)
   - `prefs_user.config` - User-modified preferences (overrides defaults)

2. **Keybinding files**:
   - `keys.config` - Default keybindings (shipped with sioyek)
   - `keys_user.config` - User-modified keybindings (overrides defaults)

The naming convention is strict: sioyek specifically looks for files with `_user` suffix for user customizations. Files with other names (like `sioyek-keys.config`) are **not loaded**.

**Source**: [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html)

### Linux File Locations

On Linux, sioyek expects configuration files in the XDG Base Directory location:

- **Config directory**: `~/.config/sioyek/`
- **User preferences**: `~/.config/sioyek/prefs_user.config`
- **User keybindings**: `~/.config/sioyek/keys_user.config`

**Source**: [Sioyek GitHub Issue #26](https://github.com/ahrm/sioyek/issues/26)

### Current Dotfiles Configuration

The `home.nix` file currently only symlinks the preferences file:

```nix
".config/sioyek/prefs_user.config".source = ./config/sioyek-prefs.config;
```

It does **not** symlink the keybindings file at all. This is why the custom keybindings in `config/sioyek-keys.config` are not being loaded.

### Task 29 Created the Wrong Filename

In task 29, a keybindings file was created with the name `config/sioyek-keys.config`:

```
_gruvbox w
_nord <S-w>
```

However, this file:
1. Has the wrong name (should be `keys_user.config` for sioyek to recognize it)
2. Is not symlinked in `home.nix`

### Why the Default Behavior Still Works

The 'w' key currently triggers the default `toggle_custom_color` command because:
1. Sioyek loads its built-in `keys.config` file (default keybindings)
2. The default keybindings include `toggle_custom_color w`
3. No `keys_user.config` file exists to override this default
4. Therefore, pressing 'w' executes the built-in toggle command instead of the `_nord` macro

## Recommendations

### 1. Rename the Keybindings File

Rename `config/sioyek-keys.config` to `config/sioyek-keys_user.config` to match the naming convention used for the preferences file (`config/sioyek-prefs.config` → `prefs_user.config`).

This maintains consistency in the dotfiles structure:
- Source file: `config/sioyek-keys_user.config`
- Symlink target: `.config/sioyek/keys_user.config`

### 2. Add Symlink in home.nix

Add a symlink entry in the `xdg.configFile` section of `home.nix`:

```nix
".config/sioyek/keys_user.config".source = ./config/sioyek-keys_user.config;
```

This should be added right after the existing `prefs_user.config` symlink (line 781).

### 3. Verify File Contents

The keybindings file should contain:

```
# Sioyek Keys Configuration - Custom keybindings
#
# Theme switching:
# w     - Nord dark (night mode) - blue-grey background with light text
# S-w   - Gruvbox light (day mode) - cream background with dark text

_nord w
_gruvbox <S-w>
```

Note that the macro assignments were **backwards** in task 29. According to the task description:
- 'w' should switch **to Nord** (dark mode)
- Shift+w should switch **to Gruvbox** (light mode)

But the current file has:
- 'w' bound to `_gruvbox`
- Shift+w bound to `_nord`

This should be corrected during the fix.

## References

- [Sioyek Configuration Documentation](https://sioyek-documentation.readthedocs.io/en/latest/configuration.html) - Official documentation on configuration files
- [Sioyek Usage Documentation](https://sioyek-documentation.readthedocs.io/en/latest/usage.html) - Usage patterns and commands
- [Sioyek GitHub Issue #26](https://github.com/ahrm/sioyek/issues/26) - Discussion of standardized config locations
- [Default keys.config](https://github.com/ahrm/sioyek/blob/main/pdf_viewer/keys.config) - Reference for default keybindings

## Next Steps

The implementation should:
1. Rename `config/sioyek-keys.config` → `config/sioyek-keys_user.config`
2. Fix the macro bindings (swap w and S-w)
3. Add symlink in `home.nix` for `keys_user.config`
4. Rebuild home-manager configuration
5. Test that 'w' now switches to Nord and Shift+w switches to Gruvbox
