# Application Configurations

## Email (Himalaya)

Modern CLI email client with OAuth2 support for Gmail integration, managed declaratively through Nix.

### Configuration Approach

This configuration uses **Nix-managed config** for full declarative and reproducible email setup. The configuration is version-controlled and consistent across machines.

### Setup Requirements

1. **Google OAuth2 Credentials**:
   - Create project in Google Cloud Console
   - Enable Gmail API
   - Create OAuth client ID (Desktop application)

2. **Environment Configuration**:
   ```fish
   # In ~/.config/fish/private.fish
   set -x GMAIL_CLIENT_ID "your-client-id"
   ```

3. **OAuth2 Token Setup** (one-time):
   Since the config is Nix-managed, OAuth2 tokens must be set up manually in the keyring:
   ```bash
   # The Nix config will be applied, but you need to authenticate once
   himalaya account configure gmail  # This will use your Nix-managed config
   ```

### Configuration Details

The email configuration is managed in `home.nix` with:

- **Account**: `gmail` (matches the wizard-generated config)
- **Backend**: Maildir++ with local storage in `~/Mail/Gmail`
- **OAuth2**: Full OAuth2 setup with multiple scopes (mail, contacts, calendar, carddav)
- **SMTP**: TLS-encrypted sending via Gmail's SMTP server
- **Keyring**: Secure token storage using system keyring

### Features

- **Declarative Config**: Fully managed through Nix configuration
- **Maildir++ Storage**: Local email storage with Maildir++ format (INBOX in root, other folders as dot-prefixed subfolders)
- **Full OAuth2 Scopes**: Access to mail, contacts, calendar, and CardDAV
- **Integrated Tools**: Works with isync (mbsync), msmtp, pass, gnupg
- **NeoVim Ready**: Configuration ready for Neovim integration
- **Reproducible**: Same configuration across all machines

## MCP-Hub Integration

Model Context Protocol Hub for enhanced AI tool integration.

### Architecture

- Core binary provided by NixOS (via flake input)
- Extensions installed at runtime via NPM
- Configuration managed by Neovim, not NixOS
- Environment variables bridge NixOS and Neovim

### Environment Variables

- `MCP_HUB_PATH`: Path to mcp-hub binary
- `MCP_HUB_PORT`: Communication port (default: 37373)

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