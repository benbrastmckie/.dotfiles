# Configuration Files

This directory contains configuration files for various applications managed by Home Manager. All files are symlinked to their appropriate locations in `~/.config/` or `~/` when the NixOS configuration is activated.

## File Organization

Files are organized by application and deployment pattern:
- **Root level files**: Application-specific configs (e.g., `kitty.conf`, `himalaya-config.toml`)
- **Subdirectories**: Groups of related files (e.g., `sioyek/`)

## Terminal Emulators

| File | Deployed To | Description |
|------|-------------|-------------|
| `alacritty.toml` | `~/.config/alacritty/alacritty.toml` | Alacritty terminal emulator configuration |
| `kitty.conf` | `~/.config/kitty/kitty.conf` | Kitty terminal emulator configuration |
| `wezterm.lua` | `~/.config/wezterm/wezterm.lua` | WezTerm GPU-accelerated terminal configuration |

## Shell & Multiplexers

| File | Deployed To | Description |
|------|-------------|-------------|
| `config.fish` | `~/.config/fish/config.fish` | Fish shell configuration and aliases |
| `.tmux.conf` | `~/.tmux.conf` | tmux terminal multiplexer configuration |

## Window Manager

| File | Deployed To | Description |
|------|-------------|-------------|
| `config.kdl` | `~/.config/niri/config.kdl` | Niri Wayland compositor configuration |

## Document Viewers

| File | Deployed To | Description |
|------|-------------|-------------|
| `zathurarc` | `~/.config/zathura/zathurarc` | Zathura PDF viewer configuration |
| `sioyek/prefs_user.config` | `~/.config/sioyek/prefs_user.config` | Sioyek PDF viewer preferences (research papers) |
| `sioyek/keys_user.config` | `~/.config/sioyek/keys_user.config` | Sioyek keyboard shortcuts |

## Development Tools

| File | Deployed To | Description |
|------|-------------|-------------|
| `claude-settings.json` | `~/.claude/settings.json` | Claude Code CLI settings |
| `opencode.json` | `~/.config/opencode/opencode.json` | OpenCode configuration |
| `latexmkrc` | `~/.latexmkrc` | LaTeX build automation configuration |

## Email

| File | Deployed To | Description |
|------|-------------|-------------|
| `himalaya-config.toml` | `~/.config/himalaya/config.toml` | Himalaya email client configuration |

## Cloud Storage

| File | Deployed To | Description |
|------|-------------|-------------|
| `rclone.conf` | `~/.config/rclone/rclone.conf` | Rclone cloud storage sync configuration |

## System Information

| File | Deployed To | Description |
|------|-------------|-------------|
| `fastfetch.jsonc` | `~/.config/fastfetch/config.jsonc` | Fastfetch system info display configuration |

## Notes

- All configurations are declaratively managed through `home.nix`
- Changes to these files require running `home-manager switch` to take effect
- Some configs are also copied to `~/.config/config-files/` for version control backup
- See `home.nix` lines 803-988 for complete deployment mappings

[← Back to main README](../README.md)