# Terminal Configuration Guide

This document covers terminal emulator configurations for WezTerm and Kitty.

## WezTerm Configuration

### Startup Behavior
- **Maximized on startup**: Window automatically maximizes when WezTerm starts
- **No decorations**: Clean interface without window borders

### Performance Optimizations
- **Max FPS**: 120 - Ensures smooth rendering on high refresh rate displays
- **Animation FPS**: 60 - Provides fluid animations for transitions
- **Cursor Blink**: 500ms rate with constant easing for predictable behavior
- **GPU acceleration**: WebGpu frontend with high performance preference

These settings leverage GPU acceleration for optimal performance on Wayland.

## Visual Feedback

### Visual Bell
- **Disabled audio bell** - No more annoying beeps
- **Visual flash** - Cursor color briefly changes on bell events
- **Smooth fade** - 75ms fade in/out with easing functions

### Opacity Controls
- **Window opacity**: 0.9 (unchanged from original)
- **Text background opacity**: 1.0 - Ensures text remains fully opaque even with transparent window
- **Font size stability**: Window doesn't resize when changing font size

## Scrollback & Search Features

### Enhanced Scrollback
- **Buffer size**: 10,000 lines of history
- **Alternate buffer scroll**: 1 line per wheel tick for precise control in apps like vim
- **No scroll bar**: Clean interface without visual clutter

### Search Capabilities
- **Search mode**: `Leader + /` - Opens incremental search
- **Copy mode**: `Leader + [` - Enter vim-like navigation mode for scrollback

## Clipboard & Selection

### Mouse Interactions
- **Right-click**: Paste from clipboard (existing)
- **Middle-click**: Paste from primary selection (Linux-style)
- **Ctrl+Click**: Open URLs directly
- **Selection auto-copy**: Text selections automatically copy to both clipboard and primary selection

### Smart Selection Patterns
Double-click intelligently selects:
- **URLs**: `https://example.com/path`
- **File paths**: `/home/user/file.txt`
- **Email addresses**: `user@example.com`
- **IP addresses**: `192.168.1.1`
- **Hex colors**: `#ff5733` or `#333`

## Tab Management

### Existing Tab Management (Unchanged)
Your original keybindings remain:
- **Leader + c**: Create new tab
- **Leader + k**: Close current tab
- **Leader + n**: Next tab
- **Leader + p**: Previous tab

## Package Management

- **Updates via NixOS**: WezTerm updates are managed through NixOS/home-manager
- **No automatic checks**: Update notifications disabled as packages are managed declaratively

## Preserved Features

All your original configurations remain intact:
- **Leader key**: `Ctrl+Space` (matching Kitty)
- **Font**: RobotoMono Nerd Font Mono at size 12
- **Color scheme**: Your custom dark theme
- **Copy/Paste**: Ctrl+Shift+C/V
- **Font sizing**: Ctrl+Shift+Plus/Minus
- **Default shell**: Fish
- **Tab bar**: Bottom position with custom styling

## Quick Reference

### Most Useful Shortcuts

| Action | Keybinding | Description |
|--------|------------|-------------|
| Fullscreen | `Alt + Enter` | Toggle fullscreen mode |
| Command Palette | `Ctrl+Shift+P` | Discover all commands |
| Search | `Leader + /` | Find text in terminal |
| Copy Mode | `Leader + [` | Vim-like scrollback navigation |
| Open URL | `Ctrl+Click` | Open links in browser |

### Mouse Actions

| Action | Result |
|--------|--------|
| Select text | Copies to clipboard & primary selection |
| Right-click | Paste from clipboard |
| Middle-click | Paste from primary selection |
| Ctrl+Click on URL | Open in browser |
| Double-click | Smart select (URLs, paths, etc.) |

## Tips

1. **Copy Mode Navigation**: When in copy mode (`Leader + [`), use vim keys to navigate:
   - `h/j/k/l` for movement
   - `v` to start selection
   - `y` to yank (copy)
   - `Esc` to exit

2. **Smart Selection**: Double-clicking on different text types automatically selects the entire URL, file path, or other recognized patterns.

4. **Visual Bell**: If you see your cursor flash, it means a bell event occurred (useful for knowing when long-running commands complete).

### Configuration Files

- **WezTerm Config**: `~/.dotfiles/config/wezterm.lua`

### Useful WezTerm Commands

```bash
# Show all default keybindings in Lua format
wezterm show-keys --lua

# List available fonts
wezterm ls-fonts --list-system

# Check active terminal sessions
wezterm cli list-clients

# Generate shell completions
wezterm shell-completion --shell bash
```

## Kitty Configuration

Kitty is a fast, GPU-accelerated terminal emulator with extensive customization options.

### Key Features

- **GPU Rendering**: Hardware acceleration for smooth scrolling and rendering
- **Ligature Support**: Proper rendering of programming fonts with ligatures
- **Hyperlink Support**: Clickable links in terminal output
- **Image Protocol**: Native image display in terminal
- **Multiplexing**: Built-in window/tab/layout management
- **Remote Control**: Control kitty from scripts via `kitty @`

### Configuration Files

- **Main Config**: `~/.config/kitty/kitty.conf`
- **Session Files**: `~/.config/kitty/sessions/`
- **Themes**: `~/.config/kitty/themes/`

### Useful Kitty Commands

```bash
# Show version and config paths
kitty --version
kitty --debug-config

# List fonts (must run in kitty terminal)
kitty +list-fonts
kitty +list-fonts --psnames

# Interactive theme selection
kitty +kitten themes

# Edit file in overlay window
kitty +kitten edit-in-kitty file.txt

# Show mouse demo
kitty +kitten mouse-demo

# Remote control (requires allow_remote_control in config)
kitty @ --help
kitty @ ls  # List windows/tabs
kitty @ set-font-size 14
kitty @ set-colors --all ~/.config/kitty/theme.conf
```

### Common Keybindings

| Action | Default Keybinding | Description |
|--------|-------------------|-------------|
| New Tab | `Ctrl+Shift+T` | Create new tab |
| Close Tab | `Ctrl+Shift+Q` | Close current tab |
| Next Tab | `Ctrl+Shift+Right` | Switch to next tab |
| Previous Tab | `Ctrl+Shift+Left` | Switch to previous tab |
| New Window | `Ctrl+Shift+Enter` | Create new window in tab |
| Close Window | `Ctrl+Shift+W` | Close current window |
| Next Window | `Ctrl+Shift+]` | Focus next window |
| Previous Window | `Ctrl+Shift+[` | Focus previous window |
| Copy | `Ctrl+Shift+C` | Copy selection |
| Paste | `Ctrl+Shift+V` | Paste from clipboard |
| Increase Font | `Ctrl+Shift+Plus` | Increase font size |
| Decrease Font | `Ctrl+Shift+Minus` | Decrease font size |
| Reset Font | `Ctrl+Shift+0` | Reset font size |
| Show Hints | `Ctrl+Shift+E` | Open URL/path hints |
| Unicode Input | `Ctrl+Shift+U` | Unicode character input |
| Edit Config | `Ctrl+Shift+F2` | Edit kitty.conf |
| Reload Config | `Ctrl+Shift+F5` | Reload configuration |
| Debug Config | `Ctrl+Shift+F6` | Show config errors |

### Kitty vs WezTerm Comparison

| Feature | Kitty | WezTerm |
|---------|-------|----------|
| Platform | Linux/macOS primarily | Cross-platform |
| Config Format | Plain text (kitty.conf) | Lua scripting |
| GPU Acceleration | OpenGL | WebGPU/OpenGL |
| Multiplexing | Built-in | Built-in |
| Remote Control | `kitty @` commands | `wezterm cli` |
| Image Support | Kitty graphics protocol | iTerm2 protocol |
| Font Rendering | Custom engine | System/FreeType |
| Scripting | Python kittens | Lua configuration |
| Tab Bar | Top/Bottom | Top/Bottom |
| Ligatures | Yes | Yes |
| Hyperlinks | Yes | Yes |

### Documentation Access

```bash
# Man pages
man kitty
man kitty.conf
man kitten

# Built-in help
kitty --help
kitty @ --help
kitty +kitten --help

# Debug configuration
kitty --debug-config

# List all config options with defaults
kitty +runpy 'from kitty.config import defaults; import pprint; pprint.pprint(dir(defaults))'
```

## Tips for Both Terminals

1. **Performance**: Both terminals benefit from GPU acceleration - ensure your GPU drivers are properly installed
2. **Font Rendering**: Use a Nerd Font for proper icon support in both terminals
3. **Config Validation**: Always validate config changes before restarting:
   - WezTerm: `wezterm --config-file path/to/config.lua --skip-config`
   - Kitty: `kitty --debug-config`
4. **Session Management**: Both support saving/restoring sessions for complex layouts
5. **Remote Usage**: Both work well over SSH with proper configuration

The configuration is modular and well-commented, making it easy to adjust any settings to your preference.
