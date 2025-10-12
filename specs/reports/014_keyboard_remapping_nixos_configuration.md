# Keyboard Remapping via NixOS Configuration

## Metadata
- **Date**: 2025-10-03
- **Scope**: Replace GNOME extensions for keyboard remapping with system-level NixOS/niri configuration
- **Primary Directory**: `/home/benjamin/.dotfiles`
- **Files Analyzed**: `configuration.nix`, `config/config.kdl`
- **Current Remapping**: Caps→Esc (via config.kdl:7), Ctrl↔Alt (via GNOME extension)

## Executive Summary

**Yes, you can eliminate GNOME extensions for keyboard remapping!** Your niri configuration already handles Caps Lock → Escape via XKB options in `config/config.kdl`. You just need to add **`ctrl:swap_lalt_lctl`** to swap left Ctrl and left Alt keys.

**Quick Solution**: Add `ctrl:swap_lalt_lctl` to your existing niri XKB options:
```kdl
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

This will:
- ✅ Swap Caps Lock with Escape (already working)
- ✅ Swap left Ctrl with left Alt (new)
- ✅ Keep right Alt as compose key (already configured)
- ✅ Work system-wide in niri, GNOME, and X11 sessions
- ✅ Eliminate need for GNOME extensions

## Current State Analysis

### What You Have Now

**File**: `config/config.kdl:1-12`
```kdl
input {
    keyboard {
        xkb {
            layout "us"
            // Enable common keyboard options
            options "caps:escape,compose:ralt"
        }
        repeat-delay 300
        repeat-rate 50
    }
}
```

**Active Remapping**:
1. ✅ **Caps Lock → Escape** (via `caps:escape`)
2. ✅ **Right Alt → Compose Key** (via `compose:ralt`)
3. ❌ **Left Ctrl ↔ Left Alt** (currently via GNOME extension)

**File**: `configuration.nix:167-169`
```nix
# Configure keymap in X11
services.xserver = {
  xkb.layout = "us";
  # xkb.options = "caps:escape";  # Optional: remap caps lock to escape
};
```

**Note**: The commented xkb.options line in `configuration.nix` is redundant - niri's config.kdl already handles this correctly.

### How It Works

**Niri Configuration (Wayland)**:
- `config/config.kdl` → libxkbcommon → Keyboard input
- Applies to **niri sessions only**
- Uses standard XKB option strings

**X11 Configuration (Fallback)**:
- `configuration.nix` → X server → Keyboard input
- Applies to **X11 sessions and GNOME (when not in Wayland)**
- Uses same XKB option strings

**Current Gap**:
- Niri session: Caps→Esc works ✅, Ctrl↔Alt missing ❌
- GNOME session: Both work via GNOME extension

## XKB Options Reference

### Standard XKB Option Format

XKB options use the format: `group:value` with comma separation for multiple options.

**Example**:
```kdl
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

### Available Caps Lock Options

| Option | Effect |
|--------|--------|
| `caps:escape` | **Caps Lock → Escape** (current) |
| `caps:swapescape` | Swap Caps Lock and Escape |
| `caps:ctrl_modifier` | Caps Lock → Control (additional Ctrl key) |
| `caps:nocaps` | Disable Caps Lock |
| `ctrl:swapcaps` | Swap Caps Lock and left Control |
| `ctrl:nocaps` | Caps Lock → Control (disable Caps Lock function) |

**Your current choice** (`caps:escape`) is ideal for Vim/Neovim users.

### Available Ctrl/Alt Options

| Option | Effect |
|--------|--------|
| **`ctrl:swap_lalt_lctl`** | **Swap left Ctrl and left Alt** (what you need!) |
| `ctrl:swap_ralt_rctl` | Swap right Ctrl and right Alt |
| `altwin:swap_lalt_lwin` | Swap left Alt and left Win/Super |
| `altwin:swap_alt_win` | Swap both Alt and Win/Super keys |

**Your needed option**: `ctrl:swap_lalt_lctl`

### Compose Key Options

| Option | Effect |
|--------|--------|
| `compose:ralt` | Right Alt → Compose key (current) |
| `compose:lwin` | Left Win/Super → Compose key |
| `compose:rwin` | Right Win/Super → Compose key |
| `compose:caps` | Caps Lock → Compose key |

**Your current choice** (`compose:ralt`) keeps right Alt functional for special characters.

## Implementation Options

### Option 1: Niri-Only Configuration (Recommended)

**Scope**: Affects niri Wayland sessions only
**Complexity**: Minimal - single line change
**Persistence**: Works immediately after config reload

**Implementation**:

Edit `config/config.kdl:7`:
```kdl
// Before
options "caps:escape,compose:ralt"

// After
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

**Apply Changes**:
```bash
# Method 1: Reload niri config (no logout required)
# Press Mod+Shift+r in niri session

# Method 2: Home Manager rebuild
home-manager switch --flake .#benjamin

# Method 3: Full system rebuild
sudo nixos-rebuild switch --flake .#nandi && home-manager switch --flake .#benjamin
```

**Testing**:
```bash
# After reload, test in terminal:
# Press left Ctrl - should act as left Alt
# Press left Alt - should act as left Ctrl
# Press Caps Lock - should act as Escape
```

**Pros**:
- ✅ Minimal change (one line)
- ✅ Works immediately in niri
- ✅ No X11 configuration needed
- ✅ Live reload with Mod+Shift+r

**Cons**:
- ⚠️ Only applies to niri sessions
- ⚠️ GNOME session would still need extension (if you use it)

---

### Option 2: System-Wide Configuration (For GNOME Compatibility)

**Scope**: Affects all sessions (niri, GNOME, X11)
**Complexity**: Low - changes in two files
**Persistence**: Works across all desktop sessions

**Implementation**:

**Step 1**: Update niri config (`config/config.kdl:7`):
```kdl
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

**Step 2**: Update X11 config (`configuration.nix:167-170`):
```nix
# Configure keymap in X11
services.xserver = {
  xkb.layout = "us";
  xkb.options = "caps:escape,compose:ralt,ctrl:swap_lalt_lctl";
};
```

**Apply Changes**:
```bash
# Rebuild both NixOS and Home Manager
sudo nixos-rebuild switch --flake .#nandi
home-manager switch --flake .#benjamin

# Log out and back in (or press Mod+Shift+r in niri)
```

**Testing**:
```bash
# Test in niri session
# Press left Ctrl → should act as left Alt
# Press left Alt → should act as left Ctrl

# Test in GNOME session (if you use it)
# Same behavior should apply
```

**Pros**:
- ✅ Consistent across all sessions
- ✅ Eliminates GNOME extension entirely
- ✅ Works in X11 fallback
- ✅ Single source of truth for keyboard config

**Cons**:
- ⚠️ Requires full system rebuild (slower)
- ⚠️ Affects GNOME session (if you switch back)

---

### Option 3: Niri + GNOME Hybrid (Current Approach)

**Scope**: Niri uses config.kdl, GNOME uses extension
**Complexity**: Low - keep current setup
**Why You Might Not Want This**: Duplicated configuration, reliance on extensions

**Status**: **Not recommended** - eliminates the benefit of declarative configuration.

---

## Recommended Implementation

### Step-by-Step Guide

**Recommendation**: Use **Option 1** (Niri-Only) if you primarily use niri, or **Option 2** (System-Wide) if you want consistency across all sessions.

### Quick Implementation (Option 1 - Niri Only)

**1. Edit config file**:
```bash
nvim ~/.dotfiles/config/config.kdl
```

**2. Update line 7**:
```kdl
// Old
options "caps:escape,compose:ralt"

// New
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

**3. Reload niri config**:
```bash
# In niri session, press: Mod+Shift+r
# Or reload via command:
niri msg reload-config
```

**4. Test immediately**:
- Press **left Ctrl** - should type Alt+key combinations
- Press **left Alt** - should type Ctrl+key combinations
- Press **Caps Lock** - should act as Escape
- Press **right Alt** - compose key still works

**5. Commit changes**:
```bash
cd ~/.dotfiles
git add config/config.kdl
git commit -m "feat(niri): add left Ctrl/Alt key swap via XKB options

Adds ctrl:swap_lalt_lctl to XKB options in niri config to swap
left Ctrl and left Alt keys, eliminating need for GNOME extension.

Remapping now configured via:
- caps:escape - Caps Lock acts as Escape
- compose:ralt - Right Alt as compose key
- ctrl:swap_lalt_lctl - Swap left Ctrl and left Alt

Related: specs/reports/014_keyboard_remapping_nixos_configuration.md"
```

**6. Apply with Home Manager** (optional, makes it permanent):
```bash
home-manager switch --flake .#benjamin
```

---

### Full Implementation (Option 2 - System-Wide)

**1. Edit niri config**:
```bash
nvim ~/.dotfiles/config/config.kdl
```

Update line 7:
```kdl
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

**2. Edit NixOS config**:
```bash
nvim ~/.dotfiles/configuration.nix
```

Update lines 167-170:
```nix
# Configure keymap in X11
services.xserver = {
  xkb.layout = "us";
  xkb.options = "caps:escape,compose:ralt,ctrl:swap_lalt_lctl";
};
```

**3. Rebuild system**:
```bash
sudo nixos-rebuild switch --flake .#nandi
home-manager switch --flake .#benjamin
```

**4. Log out and back in** (or press Mod+Shift+r in niri)

**5. Test in both sessions**:
```bash
# Test in niri
# Test in GNOME (if you use it)
# Both should have identical key behavior
```

**6. Disable GNOME extension**:
```bash
# In GNOME session, open Extensions app
# Disable the keyboard remapping extension
# Or remove it entirely:
gnome-extensions disable <extension-id>
```

**7. Commit changes**:
```bash
cd ~/.dotfiles
git add config/config.kdl configuration.nix
git commit -m "feat: add system-wide Ctrl/Alt swap via XKB configuration

Configure keyboard remapping at system level via XKB options:
- caps:escape - Caps Lock acts as Escape
- compose:ralt - Right Alt as compose key
- ctrl:swap_lalt_lctl - Swap left Ctrl and left Alt

Changes:
- config/config.kdl: Updated niri XKB options
- configuration.nix: Added X11 XKB options for GNOME/X11 sessions

This eliminates dependency on GNOME extensions for keyboard remapping
and provides consistent behavior across all desktop sessions.

Related: specs/reports/014_keyboard_remapping_nixos_configuration.md"
```

---

## Advantages Over GNOME Extensions

### Declarative Configuration
- ✅ **Version Controlled**: Changes tracked in git
- ✅ **Reproducible**: Same config on any NixOS machine
- ✅ **Documented**: Clear configuration in code

### Extension-Free
- ✅ **No GNOME Dependency**: Works without GNOME extensions
- ✅ **Faster**: No extension loading overhead
- ✅ **More Reliable**: XKB is kernel-level, not userspace

### Cross-Session Compatibility
- ✅ **Works in niri**: Primary session
- ✅ **Works in GNOME**: Fallback session
- ✅ **Works in X11**: Legacy compatibility
- ✅ **Works in TTY**: Console sessions too (with `console.useXkbConfig`)

### Maintainability
- ✅ **Single Source of Truth**: One configuration location
- ✅ **No Extension Updates**: XKB options don't break with GNOME updates
- ✅ **Clear Intent**: Explicit configuration vs. hidden extension settings

## Advanced Configuration

### Multiple Keyboard Layouts

If you need multiple layouts (e.g., US + Dvorak):

```kdl
input {
    keyboard {
        xkb {
            layout "us,us"
            variant ",dvorak"
            options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl,grp:win_space_toggle"
        }
    }
}
```

Options breakdown:
- `grp:win_space_toggle` - Win+Space to switch layouts
- Multiple layouts/variants with comma separation

### Console Keyboard Config

To apply XKB options to Linux console (TTY):

**Add to `configuration.nix`**:
```nix
console = {
  useXkbConfig = true;  # Use X keyboard config in console
};
```

This makes Caps→Esc and Ctrl↔Alt work even in TTY1-6 (Ctrl+Alt+F1-F6).

### Per-Application Overrides

Some applications (like Emacs) have their own keybindings that may conflict. XKB options work system-wide, but applications can override them.

**Example - Emacs**:
If Emacs uses Ctrl internally, it will see the swapped keys. This is usually desirable for Emacs users who prefer Alt as Meta and Ctrl for Ctrl.

### Right-Side Key Swapping

If you want to swap **both** left and right Ctrl/Alt:

```kdl
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl,ctrl:swap_ralt_rctl"
```

**Note**: This swaps right Alt, conflicting with `compose:ralt`. Choose one:
- Keep `compose:ralt` + only left-side swap (recommended)
- Use both swaps + lose compose key functionality

## Troubleshooting

### Issue 1: Changes Don't Apply in niri

**Symptom**: Edited config.kdl but keys still work the old way

**Solution**:
```bash
# Reload niri config
# Press Mod+Shift+r

# Or reload via command
niri msg reload-config

# Or restart niri session (logout/login)
```

### Issue 2: Changes Don't Apply in GNOME

**Symptom**: Keys work correctly in niri but not in GNOME

**Possible Cause**: GNOME gsettings override NixOS configuration

**Solution**:
```bash
# Reset GNOME keyboard settings
gsettings reset org.gnome.desktop.input-sources xkb-options
gsettings reset org.gnome.desktop.input-sources sources

# Reboot to ensure clean state
sudo reboot
```

**Alternative**: Add GNOME gsettings override to Home Manager:
```nix
# home.nix
dconf.settings = {
  "org/gnome/desktop/input-sources" = {
    xkb-options = [ "caps:escape" "compose:ralt" "ctrl:swap_lalt_lctl" ];
  };
};
```

### Issue 3: Wrong Keys Swapped

**Symptom**: Right Ctrl/Alt swap instead of left

**Check**: Verify exact option name
```bash
# Correct: Left-side only
options "ctrl:swap_lalt_lctl"

# Wrong: Would swap right side
options "ctrl:swap_ralt_rctl"
```

### Issue 4: Compose Key Stops Working

**Symptom**: Right Alt no longer types special characters

**Cause**: Swapping right Alt with right Ctrl

**Solution**: Only swap left-side keys:
```kdl
// Correct - right Alt remains as compose
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"

// Wrong - right Alt swapped, conflicts with compose
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl,ctrl:swap_ralt_rctl"
```

### Issue 5: Keys Work in Some Apps But Not Others

**Symptom**: Inconsistent behavior across applications

**Possible Causes**:
1. Application has internal keybinding overrides
2. Running via Flatpak with different keyboard settings
3. XWayland vs native Wayland application differences

**Solution**:
```bash
# Check if app is XWayland or native Wayland
xprop | grep -i wayland

# For Flatpak apps, ensure portal works
flatpak run --env=XDG_SESSION_TYPE=wayland <app>
```

## Testing Checklist

After configuration changes:

**Basic Functionality**:
- [ ] Left Ctrl acts as left Alt
- [ ] Left Alt acts as left Ctrl
- [ ] Caps Lock acts as Escape
- [ ] Right Alt still works as compose key
- [ ] Right Ctrl still works as Ctrl
- [ ] Right Alt still works as Alt (if not swapped)

**Application Testing**:
- [ ] Terminal (Kitty): Ctrl+C, Ctrl+D work correctly
- [ ] Browser (Brave): Ctrl+T, Ctrl+W work correctly
- [ ] Editor (Neovim): Escape key works from Caps Lock
- [ ] GNOME Settings: Settings open with previous Ctrl key
- [ ] Fuzzel launcher: Opens with Mod+P

**Session Testing** (if using Option 2):
- [ ] niri session: All keys work correctly
- [ ] GNOME session: All keys work correctly
- [ ] X11 fallback: All keys work correctly
- [ ] TTY console: Caps Lock → Escape works (if `console.useXkbConfig = true`)

**Compose Key Testing**:
```bash
# Test compose key (right Alt)
# Press: Right Alt + ' + e → é
# Press: Right Alt + ` + a → à
# Press: Right Alt + ~ + n → ñ
```

## Documentation Updates

After implementing keyboard remapping:

**Update `docs/niri.md`**:
```markdown
## Input Configuration

### Keyboard Settings

\`\`\`kdl
keyboard {
    xkb {
        layout "us"
        options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
    }
    repeat-delay 300
    repeat-rate 50
}
\`\`\`

**Active Remapping**:
- **Caps Lock → Escape**: Ideal for Vim/Neovim users
- **Left Ctrl ↔ Left Alt**: Swaps left-side modifier keys
- **Right Alt → Compose Key**: Special characters (e.g., é, ñ, à)

**Note**: Eliminates need for GNOME extensions for keyboard remapping.
```

**Update `CLAUDE.md`**:
Add to "Common Configuration Patterns" or "Input Configuration":
```markdown
### Keyboard Remapping

Keyboard remapping is configured via XKB options in `config/config.kdl`:
- Caps Lock → Escape: \`caps:escape\`
- Left Ctrl ↔ Left Alt: \`ctrl:swap_lalt_lctl\`
- Right Alt as Compose: \`compose:ralt\`

See: \`specs/reports/014_keyboard_remapping_nixos_configuration.md\`
```

## Related Configuration

### QMK Mechanical Keyboard

**File**: `configuration.nix:68-74`
```nix
# makes the split mechanical keyboard recognized
services.udev = {
  enable = true;
  packages = [
    pkgs.qmk-udev-rules
  ];
};
```

**Note**: If you have a QMK-compatible keyboard, you can program key swapping at the firmware level. This is complementary to XKB options.

**QMK Configuration** (if applicable):
- Flash firmware with `qmk flash`
- Configure key swapping in `keymap.c`
- More permanent than OS-level config
- Works across all operating systems

### Via Keyboard Configuration

**Package**: `configuration.nix:320`
```nix
via  # Keyboard configuration tool for QMK-powered keyboards
```

Via provides a GUI for configuring QMK keyboards without flashing firmware.

**Consideration**: If you use a QMK keyboard with Via, you could configure key swapping at either:
1. **Firmware level** (QMK/Via) - works on all OSes
2. **OS level** (XKB options) - more flexible, easier to change

Most users prefer OS-level config for software flexibility.

## Comparison: XKB vs GNOME Extensions

| Aspect | XKB Options (Recommended) | GNOME Extension |
|--------|---------------------------|-----------------|
| **Configuration** | Declarative (config files) | GUI/gsettings |
| **Version Control** | ✅ Git tracked | ❌ Not in dotfiles |
| **Reproducible** | ✅ Works on any NixOS | ❌ Manual install |
| **Speed** | ✅ Kernel-level | ⚠️ Userspace delay |
| **Reliability** | ✅ Always works | ⚠️ Can break with updates |
| **Cross-Session** | ✅ niri + GNOME + X11 | ❌ GNOME only |
| **Dependencies** | ✅ Built-in (XKB) | ❌ Requires extension |
| **Maintenance** | ✅ Zero | ⚠️ Update with GNOME |

**Verdict**: XKB options are superior for NixOS declarative configuration.

## References

### Files Modified
- `config/config.kdl:7` - Niri XKB options (niri sessions)
- `configuration.nix:167-170` - X11 XKB options (GNOME/X11 sessions)

### External Documentation
- [NixOS Wiki - Keyboard Layout Customization](https://nixos.wiki/wiki/Keyboard_Layout_Customization)
- [Niri Wiki - Configuration: Input](https://github.com/YaLTeR/niri/wiki/Configuration:-Input)
- [ArchWiki - Xorg/Keyboard configuration](https://wiki.archlinux.org/title/Xorg/Keyboard_configuration)
- [Niri Discussion #705 - Swap Ctrl and Caps Lock](https://github.com/YaLTeR/niri/discussions/705)

### Project Documentation
- `docs/niri.md` - Niri window manager documentation
- `docs/configuration.md` - NixOS configuration details
- `specs/reports/012_niri_with_gnome_integration.md` - Niri + GNOME integration

### XKB Option Locations
- `/usr/share/X11/xkb/rules/base.lst` - Complete XKB options list
- `/usr/share/X11/xkb/symbols/ctrl` - Ctrl key options definitions
- `/usr/share/X11/xkb/symbols/capslock` - Caps Lock options definitions

## Summary

**Problem**: Reliance on GNOME extensions for keyboard remapping (Caps↔Esc, Ctrl↔Alt)

**Solution**: Use XKB options in niri config and NixOS configuration

**Implementation**:
```kdl
// config/config.kdl:7
options "caps:escape,compose:ralt,ctrl:swap_lalt_lctl"
```

**Benefits**:
- ✅ Declarative configuration (version controlled)
- ✅ Works across all sessions (niri, GNOME, X11)
- ✅ No GNOME extension dependency
- ✅ Faster and more reliable
- ✅ Zero maintenance

**Next Steps**:
1. Add `ctrl:swap_lalt_lctl` to `config/config.kdl:7`
2. Reload niri config with Mod+Shift+r
3. Test key behavior
4. Optionally add to `configuration.nix` for GNOME compatibility
5. Disable/remove GNOME keyboard extension

**Estimated Time**: 5 minutes to implement, 2 minutes to test

**Risk**: None - easily reversible by removing the option
