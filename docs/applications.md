# Application Configurations

## Email (Himalaya)

Modern CLI email client with Gmail OAuth2 authentication and mbsync synchronization. 

**Complete documentation**: [`docs/himalaya.md`](himalaya.md)

## MCP-Hub Integration

Model Context Protocol Hub for enhanced AI tool integration with Neovim.

### Setup

MCP-Hub is configured as a standard Neovim plugin using lazy.nvim:
- Port: 37373
- Configuration: `~/.config/mcphub/servers.json`
- Integration with Avante for AI functionality

Use `~/.dotfiles/packages/test-mcphub.sh` to verify installation and troubleshoot issues.

## PDF Viewers

### Zathura (GTK-based)

- Uses server-side decorations
- Compatible with Unite GNOME extension for title bar removal
- Custom wrapper forces X11 for consistency

### Sioyek (Qt6-based)

- Uses client-side decorations on Wayland
- Custom wrapper forces X11 (`QT_QPA_PLATFORM=xcb`)
- Enables server-side decorations for Unite compatibility
- Original package excluded to prevent conflicts

## Terminal Configuration

Multiple terminal emulators configured:

- **Alacritty**: GPU-accelerated terminal
- **Kitty**: Feature-rich terminal with tabs and splits
- **Zellij**: Terminal multiplexer (configured via config.kdl)

## Shell Configuration

Fish shell with custom configuration:

- Aliases and functions in `config/config.fish`
- Integration with various CLI tools
- Custom prompt and completions