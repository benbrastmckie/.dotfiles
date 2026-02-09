# Himalaya Email Client Configuration

This document describes the Himalaya email client setup with dual-account support (Gmail + Protonmail), OAuth2 authentication, and mbsync synchronization.

## Overview

Himalaya is configured as the primary email client with dual-account support:

### Accounts
- **Gmail** (benbrastmckie@gmail.com) - Default account with OAuth2 authentication
- **Protonmail** (benjamin@logos-labs.ai) - Secondary account via Protonmail Bridge

### Components
- **Himalaya CLI**: Email client with OAuth2 and keyring integration
- **mbsync (isync)**: IMAP synchronization with XOAUTH2 (Gmail) and LOGIN auth (Protonmail Bridge)
- **Protonmail Bridge**: Local IMAP/SMTP proxy for Protonmail access
- **OAuth2 Token Management**: Automatic Gmail token refresh via systemd

## Architecture

### Email Flow

**Gmail Account**:
1. **Incoming**: Gmail IMAP (OAuth2) → mbsync → ~/Mail/Gmail/ → Himalaya
2. **Outgoing**: Himalaya → Gmail SMTP (OAuth2)
3. **Authentication**: OAuth2 tokens stored in system keyring via libsecret

**Protonmail Account**:
1. **Incoming**: Protonmail → Bridge (localhost:1143) → mbsync → ~/Mail/Logos/ → Himalaya
2. **Outgoing**: Himalaya → Bridge (localhost:1025) → Protonmail
3. **Authentication**: Bridge password stored in system keyring via libsecret

### Directory Structure (Maildir++)

**Gmail**:
```
~/Mail/Gmail/
  cur/           # Inbox current messages
  new/           # Inbox new messages
  tmp/           # Temporary files
  .Sent/         # Sent messages
  .Drafts/       # Draft messages
  .Trash/        # Deleted messages
  .All_Mail/     # All mail archive
  .Spam/         # Spam messages
  EuroTrip/      # Custom folder
  CrazyTown/     # Custom folder
  Letters/       # Custom folder
```

**Protonmail (Logos)**:
```
~/Mail/Logos/
  INBOX/         # Inbox folder
    cur/         # Current messages
    new/         # New messages
    tmp/         # Temporary files
  .Sent/         # Sent messages
  .Drafts/       # Draft messages
  .Trash/        # Deleted messages
  .Archive/      # Archived messages
```

## NixOS Configuration

### Package Configuration

```nix
home.packages = with pkgs; [
  # Himalaya with OAuth2 and keyring support
  (pkgs-unstable.himalaya.overrideAttrs (oldAttrs: {
    cargoBuildFlags = (oldAttrs.cargoBuildFlags or []) ++ [ "--features=oauth2,keyring" ];
  }))

  # Custom mbsync with XOAUTH2 support
  (let
    cyrus-sasl-with-xoauth2 = pkgs.cyrus_sasl.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.cyrus-sasl-xoauth2 ];
      postInstall = (oldAttrs.postInstall or "") + ''
        cp ${pkgs.cyrus-sasl-xoauth2}/lib/sasl2/* $out/lib/sasl2/
      '';
    });

    mbsync-with-xoauth2 = pkgs-unstable.isync.override {
      cyrus_sasl = cyrus-sasl-with-xoauth2;
    };
  in mbsync-with-xoauth2)

  # Protonmail Bridge for local IMAP/SMTP proxy
  protonmail-bridge

  # Supporting packages
  pkgs.cyrus-sasl-xoauth2
  msmtp
  pass
  gnupg
  w3m
  curl
  jq
];
```

### Environment Variables

Environment variables are managed in `~/.config/fish/conf.d/private.fish`:

```fish
# Gmail OAuth2 configuration
set -gx GMAIL_CLIENT_ID "810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com"
set -gx SASL_PATH "/nix/store/ja75va5vkxrmm0y95gdzk04kxa0pmw1s-cyrus-sasl-xoauth2-0.2/lib/sasl2:/nix/store/f4spmcr74xb2zwin34n8973jj7ppn4bv-cyrus-sasl-2.1.28-bin/lib/sasl2"
```

**Variable Details**:
- **GMAIL_CLIENT_ID**: OAuth2 client identifier for Gmail API access
- **SASL_PATH**: Colon-separated paths to SASL plugin directories, including both the XOAUTH2 plugin and standard SASL plugins

### OAuth2 Token Refresh Script

A custom script handles automatic OAuth2 token refresh:

```bash
refresh-gmail-oauth2
```

The script:
- Retrieves OAuth2 credentials from the keyring
- Refreshes access tokens using Gmail's OAuth2 API
- Updates tokens in the keyring
- Handles error cases and token rotation

### Systemd Services

#### Token Refresh Service
```nix
systemd.user.services.gmail-oauth2-refresh = {
  Unit = {
    Description = "Refresh Gmail OAuth2 tokens";
    After = [ "graphical-session.target" ];
  };
  Service = {
    Type = "oneshot";
    ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/refresh-gmail-oauth2";
  };
};
```

#### Timer Configuration
```nix
systemd.user.timers.gmail-oauth2-refresh = {
  Unit = {
    Description = "Timer for Gmail OAuth2 token refresh";
    Requires = [ "gmail-oauth2-refresh.service" ];
  };
  Timer = {
    OnCalendar = "*:0/45";  # Every 45 minutes
    Persistent = true;
    RandomizedDelaySec = 300;  # Random delay up to 5 minutes
  };
  Install = {
    WantedBy = [ "timers.target" ];
  };
};
```

## Configuration Files

### Himalaya Configuration
**Location**: `~/.config/himalaya/config.toml`

#### Gmail Account
```toml
[accounts.gmail]
default = true
email = "benbrastmckie@gmail.com"
display-name = "benbrastmckie"
downloads-dir = "/home/benjamin/Downloads"

backend.type = "maildir"
backend.root-dir = "/home/benjamin/Mail/Gmail"
backend.maildirpp = true

message.send.backend.type = "smtp"
message.send.backend.host = "smtp.gmail.com"
message.send.backend.port = 465
message.send.backend.login = "benbrastmckie@gmail.com"
message.send.backend.encryption.type = "tls"
message.send.backend.auth.type = "oauth2"
message.send.backend.auth.method = "xoauth2"
message.send.backend.auth.client-id = "${GMAIL_CLIENT_ID}"
message.send.backend.auth.auth-url = "https://accounts.google.com/o/oauth2/auth"
message.send.backend.auth.token-url = "https://www.googleapis.com/oauth2/v3/token"
message.send.backend.auth.pkce = true
message.send.backend.auth.redirect-scheme = "http"
message.send.backend.auth.redirect-host = "localhost"
message.send.backend.auth.redirect-port = 49152
message.send.backend.auth.scopes = ["https://mail.google.com/", "https://www.googleapis.com/auth/contacts", "https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/auth/carddav"]
message.send.backend.auth.client-secret.keyring = "gmail-smtp-oauth2-client-secret"
message.send.backend.auth.access-token.keyring = "gmail-smtp-oauth2-access-token"
message.send.backend.auth.refresh-token.keyring = "gmail-smtp-oauth2-refresh-token"

# Folder configuration for Gmail's special folders
folder.alias.inbox = "INBOX"
folder.alias.sent = "[Gmail].Sent Mail"
folder.alias.drafts = "[Gmail].Drafts"
folder.alias.trash = "[Gmail].Trash"
folder.alias.spam = "[Gmail].Spam"
folder.alias.all = "[Gmail].All Mail"

# Configure sent message handling
message.send.save-copy = true
folder.sent.name = "[Gmail].Sent Mail"
```

#### Protonmail Account (via Bridge)
```toml
[accounts.logos]
default = false
email = "benjamin@logos-labs.ai"
display-name = "Benjamin Brast-McKie"
downloads-dir = "/home/benjamin/Downloads"

backend.type = "maildir"
backend.root-dir = "/home/benjamin/Mail/Logos"
backend.maildirpp = true

message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.password.keyring = "protonmail-bridge benjamin@logos-labs.ai"
```

### mbsync Configuration
**Location**: `~/.mbsyncrc`

#### Gmail Account
```ini
# Gmail IMAP account with XOAUTH2 support
IMAPAccount gmail
Host imap.gmail.com
Port 993
User benbrastmckie@gmail.com
AuthMechs XOAUTH2
PassCmd "secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token"
TLSType IMAPS

# Gmail remote store
IMAPStore gmail-remote
Account gmail

# Gmail local store - MAILDIR++ FORMAT
MaildirStore gmail-local
Inbox ~/Mail/Gmail/
SubFolders Maildir++

# Inbox channel - emails go to root cur/new directories
Channel gmail-inbox
Far :gmail-remote:INBOX
Near :gmail-local:
Create Both
Expunge Both
SyncState *

# Subfolders - Maildir++ adds dot prefix automatically
Channel gmail-sent
Far :gmail-remote:"[Gmail]/Sent Mail"
Near :gmail-local:Sent
Create Both
Expunge Both
SyncState *

Channel gmail-drafts
Far :gmail-remote:"[Gmail]/Drafts"
Near :gmail-local:Drafts
Create Both
Expunge Both
SyncState *

Channel gmail-trash
Far :gmail-remote:"[Gmail]/Trash"
Near :gmail-local:Trash
Create Both
Expunge Both
SyncState *

Channel gmail-all
Far :gmail-remote:"[Gmail]/All Mail"
Near :gmail-local:All_Mail
Create Both
Expunge Both
SyncState *

Channel gmail-spam
Far :gmail-remote:"[Gmail]/Spam"
Near :gmail-local:Spam
Create Both
Expunge Both
SyncState *

Channel gmail-folders
Far :gmail-remote:
Near :gmail-local:
Patterns "EuroTrip" "CrazyTown" "Letters"
Create Both
Expunge Both
SyncState *

# Group all channels together
Group gmail
Channel gmail-inbox
Channel gmail-sent
Channel gmail-drafts
Channel gmail-trash
Channel gmail-all
Channel gmail-spam
Channel gmail-folders
```

#### Protonmail Account (via Bridge)
```ini
# Logos Labs IMAP account (via Protonmail Bridge)
IMAPAccount logos
Host 127.0.0.1
Port 1143
User benjamin@logos-labs.ai
PassCmd "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
SSLType None
AuthMechs LOGIN

IMAPStore logos-remote
Account logos

MaildirStore logos-local
Inbox ~/Mail/Logos/
SubFolders Maildir++

Channel logos-inbox
Far :logos-remote:INBOX
Near :logos-local:
Create Both
Expunge Both
SyncState *

Channel logos-sent
Far :logos-remote:Sent
Near :logos-local:Sent
Create Both
Expunge Both
SyncState *

Channel logos-drafts
Far :logos-remote:Drafts
Near :logos-local:Drafts
Create Both
Expunge Both
SyncState *

Channel logos-trash
Far :logos-remote:Trash
Near :logos-local:Trash
Create Both
Expunge Both
SyncState *

Channel logos-archive
Far :logos-remote:Archive
Near :logos-local:Archive
Create Both
Expunge Both
SyncState *

Group logos
Channel logos-inbox
Channel logos-sent
Channel logos-drafts
Channel logos-trash
Channel logos-archive
```

## Usage

### Initial Setup

#### Gmail Account
1. **Configure OAuth2 credentials**:
   ```bash
   himalaya account configure gmail
   ```
   This opens a browser for Gmail OAuth2 authentication and stores credentials in the keyring.

2. **Test authentication**:
   ```bash
   refresh-gmail-oauth2
   ```

3. **Initial sync**:
   ```bash
   mbsync gmail-inbox
   mbsync gmail
   ```

#### Protonmail Account
1. **Start Protonmail Bridge**:
   ```bash
   protonmail-bridge
   ```

2. **Login to Protonmail** in the Bridge GUI with your credentials

3. **Store Bridge password** in keyring:
   ```bash
   secret-tool store --label="Protonmail Bridge - Logos Labs" \
     service protonmail-bridge \
     username benjamin@logos-labs.ai
   ```
   When prompted, paste the bridge password from Bridge GUI → Account Settings → Mailbox password

4. **Initial sync**:
   ```bash
   mbsync logos-inbox
   mbsync logos
   ```

### Daily Operations

#### Sync Email
```bash
# Sync specific account
mbsync gmail          # Gmail full sync
mbsync logos          # Protonmail full sync

# Sync all accounts
mbsync -a

# Sync specific folders
mbsync gmail-inbox
mbsync logos-inbox
```

#### Himalaya Commands
```bash
# List accounts
himalaya account list

# Work with default account (Gmail)
himalaya folder list
himalaya message list
himalaya message read <id>

# Work with specific account
himalaya folder list -a logos
himalaya message list -a logos
himalaya message read <id> -a logos

# Send email
himalaya message send                # From default account
himalaya message send -a logos       # From Protonmail account
```

### Neovim Integration

Himalaya integrates with Neovim through keyboard shortcuts and commands. The sync operation (`<leader>ms`) triggers mbsync to synchronize emails.

## Troubleshooting

### Gmail Rate Limiting
If you encounter "Account exceeded command or bandwidth limits":
```bash
# Wait before retrying
sleep 300  # Wait 5 minutes
mbsync gmail-inbox

# Check for competing processes
ps aux | grep mbsync
killall mbsync  # If any are stuck
```

### Check OAuth2 Token Status
```bash
# Check if tokens exist in keyring
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-refresh-token
```

### Verify Environment Variables
```bash
# Check required variables are set
echo "GMAIL_CLIENT_ID: $GMAIL_CLIENT_ID"
echo "SASL_PATH: $SASL_PATH"
```

### Verify XOAUTH2 Support
```bash
# Check if mbsync can find XOAUTH2 plugin
ls -la (string split ':' $SASL_PATH)
```

### Check Systemd Services
```bash
# Check timer status
systemctl --user status gmail-oauth2-refresh.timer

# Check service logs
journalctl --user -u gmail-oauth2-refresh.service
```

### Manual Token Refresh
```bash
# Force token refresh
refresh-gmail-oauth2

# Restart systemd timer
systemctl --user restart gmail-oauth2-refresh.timer
```

### Protonmail Bridge Issues

#### Check Bridge Status
```bash
# Check if Bridge is running
ps aux | grep protonmail-bridge

# Check if Bridge ports are listening
ss -tlnp | grep -E '1143|1025'
```

#### Bridge Authentication Errors
```bash
# Verify password is stored correctly
secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai

# Re-store password if needed
secret-tool store --label="Protonmail Bridge - Logos Labs" \
  service protonmail-bridge \
  username benjamin@logos-labs.ai
```

#### Restart Bridge
```bash
# Kill existing Bridge process
killall protonmail-bridge

# Start Bridge
protonmail-bridge
```

#### Bridge Logs
```bash
# Check Bridge logs for errors
ls -la ~/.cache/protonmail/bridge/logs/
tail -f ~/.cache/protonmail/bridge/logs/bridge.log
```

## Security Notes

### Gmail Account
- **OAuth2 Client ID**: Semi-public identifier, safe to include in version control
- **Client Secret**: Stored securely in system keyring via libsecret
- **Access/Refresh Tokens**: Stored securely in system keyring
- **No passwords**: Uses OAuth2 tokens exclusively, no Gmail password required

### Protonmail Account
- **Bridge Password**: Auto-generated by Bridge, stored securely in system keyring
- **Local Communication**: Bridge runs on localhost (127.0.0.1), no encryption needed
- **Authentication**: Uses LOGIN mechanism with Bridge password
- **Account Security**: Protected by Protonmail account password + 2FA (if enabled)

## Technical Details

### Environment Variable Management

Variables are set in `~/.config/fish/conf.d/private.fish` which:
- Automatically loads in all fish shell sessions
- Preserves existing oh-my-fish configuration
- Keeps credentials alongside other API keys
- Uses fish-native syntax (`set -gx`)

### XOAUTH2 Integration

The configuration uses SASL_PATH to locate the XOAUTH2 plugin:

1. **XOAUTH2 Plugin**: Located at `/nix/store/.../cyrus-sasl-xoauth2-0.2/lib/sasl2`
2. **Standard SASL Plugins**: Located at `/nix/store/.../cyrus-sasl-2.1.28-bin/lib/sasl2`
3. **SASL_PATH**: Colon-separated paths allowing mbsync to find both plugin types

### Gmail Folder Mapping

Gmail's special folders are mapped to standard names:
- `[Gmail]/Sent Mail` maps to `Sent`
- `[Gmail]/Drafts` maps to `Drafts`
- `[Gmail]/Trash` maps to `Trash`
- `[Gmail]/All Mail` maps to `All Mail`
- `[Gmail]/Spam` maps to `Spam`

This maintains compatibility while preserving Gmail's folder structure.