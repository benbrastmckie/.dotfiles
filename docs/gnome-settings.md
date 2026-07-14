# GNOME Settings Management

GNOME desktop settings are managed declaratively through Home Manager's `dconf.settings` module in `modules/home/desktop/gnome.nix`.

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

### Power Management
- **Idle delay**: 300 seconds (5 minutes) - screen dims/blanks
- **Idle suspend (AC)**: Disabled (`sleep-inactive-ac-type = "nothing"`) - the machine never
  auto-suspends on AC power so headless workloads (AI agents, builds) keep running; the
  60-minute `sleep-inactive-ac-timeout` value remains in the config but is inert
- **Sleep timeout (Battery)**: 900 seconds (15 minutes) - retained as battery/thermal protection
- **Idle dim**: Enabled

#### Lid-Close Behavior
- Closing the lid **locks the session and never suspends** the system, on AC or battery,
  with or without external monitors. This is set at the systemd-logind level
  (`HandleLidSwitch = "lock"` and `HandleLidSwitchExternalPower = "lock"` in
  `modules/system/power.nix`), which is the component that owns lid actions. The `lock`
  action never suspends anything; after locking, GNOME powers the internal panel off about
  30 seconds later (gsd-power's screensaver blank timeout), giving blank-but-awake. `lock`
  is used rather than `ignore` because mutter deliberately keeps the internal panel active
  when it is the only monitor — under `ignore` the panel would stay lit inside the closed
  lid until the 5-minute idle blank.
- Docked/external-monitor behavior is unchanged: while external monitors are attached,
  gsd-power holds a `handle-lid-switch` block inhibitor that makes the logind lid settings
  moot, so closing the lid still moves windows to the external display exactly as before —
  no lock, no suspend (`HandleLidSwitchDocked` also keeps its default `ignore` as a second
  layer).
- **Warning**: a lid-shut laptop on battery no longer suspends automatically. Putting the
  running machine in a bag risks heat buildup and battery drain - suspend explicitly
  (`systemctl suspend`) first. The 15-minute battery idle-suspend above remains as a backstop
  when the machine is idle.

**Note**: When using the Neovim sleep inhibitor (`<leader>rz`), the screen will still blank after 5 minutes of inactivity, but the system will not sleep. This allows the screen to save power while keeping long-running tasks active. Sleep inhibitors do not affect the lid action at all (`LidSwitchIgnoreInhibited=yes` is logind's default), so the logind `lock` setting above is the only reliable lid protection; inhibitors govern idle-suspend instead, and still matter on battery, where they block the 15-minute idle-suspend.

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
  - Enabled declaratively in `modules/home/desktop/gnome.nix` via `enabled-extensions` (omitting it causes `home-manager switch` to silently disable it)
  - Extension settings also managed in `modules/home/desktop/gnome.nix` under `org/gnome/shell/extensions/unite`

### GNOME 49 / XWayland Decoration Note

GNOME 49 ignores `_MOTIF_WM_HINTS` for XWayland windows, so forcing Qt apps to run via X11 (`QT_QPA_PLATFORM=xcb`) no longer suppresses titlebars. Apps that need decoration-free windows should instead run as native Wayland with Qt CSD disabled (`QT_WAYLAND_DISABLE_WINDOWDECORATION=1`). GNOME does not add server-side decorations to native Wayland apps, so no titlebar is shown without any extension involvement.

## How Declarative dconf Works

### Managed vs. Unmanaged Settings

**Managed settings** (defined in `modules/home/desktop/gnome.nix`):
- Written to dconf on every `home-manager switch`
- Any manual changes via GNOME Settings are overwritten on rebuild
- Source of truth is `modules/home/desktop/gnome.nix`

**Unmanaged settings** (not in `modules/home/desktop/gnome.nix`):
- Remain under manual control via GNOME Settings
- Home Manager does not touch these
- Examples: wallpaper, notification settings, app-specific preferences

### Temporary vs. Permanent Changes

| Method | Immediate Effect | Survives Rebuild |
|--------|------------------|------------------|
| GNOME Settings GUI | Yes | No (if setting is managed) |
| `dconf write` | Yes | No (if setting is managed) |
| Edit `modules/home/desktop/gnome.nix` + rebuild | Yes | Yes |

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

3. Add to `modules/home/desktop/gnome.nix`:
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
4. Add to `modules/home/desktop/gnome.nix` to make permanent

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
