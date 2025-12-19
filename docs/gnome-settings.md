# GNOME Settings Management

GNOME desktop settings are managed declaratively through Home Manager's `dconf.settings` module in `home.nix`.

## Current Configuration

The following settings are managed by Home Manager:

### Keyboard & Input
- **Layout**: US keyboard
- **XKB Options**:
  - `caps:swapescape` - Caps Lock acts as Escape
  - `ctrl:swap_lalt_lctl` - Swap Left Alt and Left Ctrl
  - `lv3:ralt_switch` - Right Alt as level 3 switch

### Interface
- **Color scheme**: `prefer-dark`
- **Focus mode**: `sloppy` (focus follows mouse)

### Mouse & Touchpad
- Custom speed settings
- Two-finger scrolling enabled

### Window Manager Keybindings (Vim-style)
| Keybinding | Action |
|------------|--------|
| `Super+q` | Close window |
| `Super+Space` | Cycle windows |
| `Shift+Super+Space` | Cycle windows backward |
| `Ctrl+Shift+h` | Tile left |
| `Ctrl+Shift+l` | Tile right |
| `Ctrl+Shift+k` | Maximize |
| `Ctrl+Shift+j` | Unmaximize |
| `Shift+Super+hjkl` | Move window to monitor |
| `Shift+Alt+h/l` | Move window to workspace left/right |

### Custom Application Keybindings
| Keybinding | Application |
|------------|-------------|
| `Super+t` | WezTerm (terminal) |
| `Super+z` | Zotero |
| `Super+d` | Whisper dictation |
| `Super+b` | Web browser |
| `Super+f` | File manager |
| `Super+\` | Settings |
| `Super+n` | Notification tray |
| `Super+`` | Lock screen |

### Shell Extensions
- **Unite** (`unite@hardpixel.eu`): Hides window titlebars, reduces panel spacing

## How Declarative dconf Works

### Managed vs. Unmanaged Settings

**Managed settings** (defined in `home.nix`):
- Written to dconf on every `home-manager switch`
- Any manual changes via GNOME Settings are overwritten on rebuild
- Source of truth is `home.nix`

**Unmanaged settings** (not in `home.nix`):
- Remain under manual control via GNOME Settings
- Home Manager does not touch these
- Examples: wallpaper, notification settings, app-specific preferences

### Temporary vs. Permanent Changes

| Method | Immediate Effect | Survives Rebuild |
|--------|------------------|------------------|
| GNOME Settings GUI | Yes | No (if setting is managed) |
| `dconf write` | Yes | No (if setting is managed) |
| Edit `home.nix` + rebuild | Yes | Yes |

## Maintenance Workflow

### Making Permanent Changes

1. Find the dconf path for the setting:
   ```bash
   # Search for a setting
   gsettings list-recursively | grep -i "keyword"

   # Or browse interactively
   dconf-editor
   ```

2. Read the current value:
   ```bash
   dconf read /org/gnome/desktop/wm/preferences/focus-mode
   ```

3. Add to `home.nix`:
   ```nix
   dconf.settings = {
     "org/gnome/desktop/wm/preferences" = {
       focus-mode = "sloppy";
     };
   };
   ```

4. Apply:
   ```bash
   home-manager switch --flake .#benjamin
   ```

### Experimenting with Settings

1. Use GNOME Settings or `dconf write` to try changes
2. Test until satisfied
3. Dump the final value:
   ```bash
   dconf read /path/to/setting
   ```
4. Add to `home.nix` to make permanent

### Viewing All Current Settings

```bash
# Dump all GNOME settings
dconf dump /org/gnome/

# Dump specific sections
dconf dump /org/gnome/desktop/wm/keybindings/
dconf dump /org/gnome/shell/extensions/

# List keys in a path
dconf list /org/gnome/desktop/interface/
```

### Comparing Current vs. Managed

To see if your current settings differ from what Home Manager will apply:

```bash
# Check a specific value
dconf read /org/gnome/desktop/wm/preferences/focus-mode

# After rebuild, compare again to see if it changed
```

## Special Syntax Notes

### Tuples (for input sources)

GVariant tuples require special syntax:
```nix
# Correct
sources = [ (lib.hm.gvariant.mkTuple [ "xkb" "us" ]) ];

# Wrong - will fail
sources = [ ("xkb" "us") ];
```

### Empty Arrays

Empty arrays disable keybindings:
```nix
# Disables the minimize shortcut
minimize = [];
```

### Strings vs. Arrays

Some settings are strings, others are arrays of strings:
```nix
# String value
focus-mode = "sloppy";

# Array value (even for single keybinding)
close = [ "<Super>q" ];
```

## Troubleshooting

### Settings Not Applied

1. Log out and back in (required for shell extensions)
2. Restart GNOME Shell: `Alt+F2` → `r` → `Enter` (X11 only)
3. Verify the setting was written:
   ```bash
   dconf read /org/gnome/path/to/setting
   ```

### Finding the Correct Path

GNOME Settings paths follow this pattern:
- GUI location: Settings → Keyboard → Shortcuts
- dconf path: `/org/gnome/desktop/wm/keybindings/` or `/org/gnome/settings-daemon/plugins/media-keys/`

Use `dconf watch /` while changing a setting in GNOME Settings to see the exact path:
```bash
dconf watch /
# Then change something in GNOME Settings - the path will appear
```

### Type Errors

If you get type errors, check the GVariant type:
```bash
dconf read /path/to/key
# Output like 'value' = string, ['value'] = array, @as [] = empty string array
```

## Reference

- [Home Manager dconf module](https://nix-community.github.io/home-manager/options.html#opt-dconf.settings)
- [GNOME dconf documentation](https://wiki.gnome.org/Projects/dconf)
- [GSettings schemas](https://gitlab.gnome.org/GNOME/gsettings-desktop-schemas)
