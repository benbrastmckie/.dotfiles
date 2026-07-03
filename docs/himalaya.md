# Himalaya Email Client Configuration

This document describes the Himalaya email client setup with dual-account support (Gmail + Protonmail), app-password authentication, and mbsync synchronization.

> **Authentication update (2026-07-02) — Gmail is on an app password, not OAuth2.**
> As of task 72 Phase 3, Gmail authenticates end-to-end with a **Gmail app password** (both
> `mbsync` IMAP-in and Himalaya SMTP-out) via the `gmail-app-password` keyring entry — the same
> credential aerc uses. XOAUTH2 is no longer the active path, and the
> `gmail-oauth2-refresh.service`/`.timer` are **disabled**
> (`modules/home/services/gmail-oauth2.nix`).
>
> **Why:** the Gmail OAuth consent screen was stuck in Testing mode (7-day refresh-token expiry →
> repeated `invalid_grant`), and publishing to Production for the restricted `mail.google.com`
> scope requires a multi-week, paid, annually-renewed **CASA Tier 2** assessment. A consumer Gmail
> account with 2-Step Verification still accepts IMAP/SMTP app passwords in 2026, so the app
> password sidesteps OAuth entirely. Full rationale + sources:
> `specs/072_email_workflow_infrastructure_prereqs/handoffs/oauth-gate.md`.
>
> The XOAUTH2 sections below (SASL plugin, `refresh-gmail-oauth2`, systemd units, OAuth config
> keys) are **retained as the revert path** — not the current setup. To revert, re-enable the unit
> and re-point the auth blocks to XOAUTH2.

## Overview

Himalaya is configured as the primary email client with dual-account support:

### Accounts
- **Gmail** (benbrastmckie@gmail.com) - Default account, app-password authentication
- **Protonmail** (benjamin@logos-labs.ai) - Secondary account via Protonmail Bridge

### Components
- **Himalaya CLI**: Email client with keyring integration
- **mbsync (isync)**: IMAP synchronization with LOGIN auth (Gmail app password, Protonmail Bridge)
- **Protonmail Bridge**: Local IMAP/SMTP proxy for Protonmail access
- **Keyring**: Gmail app password and Bridge password stored via libsecret
  (legacy: OAuth2 token refresh via systemd — now disabled)

## Architecture

### Email Flow

**Gmail Account**:
1. **Incoming**: Gmail IMAP (app password) → mbsync → ~/Mail/Gmail/ → Himalaya
2. **Outgoing**: Himalaya → Gmail SMTP (app password)
3. **Authentication**: Gmail app password stored in system keyring via libsecret
   (`secret-tool` service `gmail-app-password`, username `benbrastmckie@gmail.com`)

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
  .*/            # Custom folders (synced via gmail-folders channel)
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
  .Labels/       # User-created labels (synced via logos-labels channel)
    .MyLabel/    # Example label
  .Folders/      # User-created folders (synced via logos-folders channel)
    .MyFolder/   # Example folder
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
# Active auth: Gmail app password (same credential mbsync/aerc use).
message.send.backend.auth.type = "password"
message.send.backend.auth.command = "secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com"

# Legacy XOAUTH2 send config (retained for revert; not active — see the callout at the top):
# message.send.backend.auth.type = "oauth2"
# message.send.backend.auth.method = "xoauth2"
# message.send.backend.auth.client-id = "${GMAIL_CLIENT_ID}"
# message.send.backend.auth.auth-url = "https://accounts.google.com/o/oauth2/auth"
# message.send.backend.auth.token-url = "https://www.googleapis.com/oauth2/v3/token"
# message.send.backend.auth.pkce = true
# message.send.backend.auth.redirect-scheme = "http"
# message.send.backend.auth.redirect-host = "localhost"
# message.send.backend.auth.redirect-port = 49152
# message.send.backend.auth.scopes = ["https://mail.google.com/", "https://www.googleapis.com/auth/contacts", "https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/auth/carddav"]
# message.send.backend.auth.client-secret.keyring = "gmail-smtp-oauth2-client-secret"
# message.send.backend.auth.access-token.keyring = "gmail-smtp-oauth2-access-token"
# message.send.backend.auth.refresh-token.keyring = "gmail-smtp-oauth2-refresh-token"

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
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
```

### mbsync Configuration
**Location**: `~/.mbsyncrc`

#### Gmail Account
```ini
# Gmail IMAP account — app-password auth (same credential himalaya/aerc use).
# Legacy XOAUTH2 (revert path): AuthMechs XOAUTH2 +
#   PassCmd "secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token"
IMAPAccount gmail
Host imap.gmail.com
Port 993
User benbrastmckie@gmail.com
AuthMechs LOGIN
PassCmd "secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com"
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
Patterns * ![Gmail]* !INBOX
Create Both
Expunge Both
Remove Both
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

Channel logos-labels
Far :logos-remote:
Near :logos-local:
Patterns "Labels/*"
Create Both
Expunge Both
Remove Both
SyncState *

Channel logos-folders
Far :logos-remote:
Near :logos-local:
Patterns "Folders/*"
Create Both
Expunge Both
Remove Both
SyncState *

Group logos
Channel logos-inbox
Channel logos-sent
Channel logos-drafts
Channel logos-trash
Channel logos-archive
Channel logos-labels
Channel logos-folders
```

## Usage

### Initial Setup

#### Gmail Account
1. **Create a Gmail app password**: with 2-Step Verification enabled, generate an app password at
   <https://myaccount.google.com/apppasswords>, then store it in the keyring:
   ```bash
   secret-tool store --label="Gmail App Password" \
     service gmail-app-password \
     username benbrastmckie@gmail.com
   ```

2. **Test authentication** (IMAP LOGIN should return `OK ... authenticated`):
   ```bash
   pw=$(secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com)
   printf 'a LOGIN "benbrastmckie@gmail.com" "%s"\nz LOGOUT\n' "$pw" \
     | openssl s_client -connect imap.gmail.com:993 -quiet -crlf 2>/dev/null | grep '^a '
   ```

3. **Initial sync**:
   ```bash
   mbsync gmail-inbox
   mbsync gmail
   ```

   *(Legacy XOAUTH2 setup — only if reverting: `himalaya account configure gmail` for the browser
   OAuth flow, then `refresh-gmail-oauth2`. Not needed on the app-password path.)*

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
himalaya envelope list          # NOTE: `himalaya message list` does not exist in v1.2.0
himalaya message read <id>

# Work with specific account
himalaya folder list -a logos
himalaya envelope list -a logos
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

### Check Gmail app password (active auth)
```bash
# Confirm the app password exists in the keyring
secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com

# Verify it authenticates IMAP (expect: "a OK ... authenticated (Success)")
pw=$(secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com)
printf 'a LOGIN "benbrastmckie@gmail.com" "%s"\nz LOGOUT\n' "$pw" \
  | openssl s_client -connect imap.gmail.com:993 -quiet -crlf 2>/dev/null | grep '^a '
```

If IMAP auth fails, regenerate the app password at
<https://myaccount.google.com/apppasswords> and re-`secret-tool store` it (2-Step Verification
must be enabled on the account).

### Legacy XOAUTH2 troubleshooting (only if reverted to OAuth2)
```bash
# OAuth token status
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-refresh-token
# Env + SASL plugin
echo "GMAIL_CLIENT_ID: $GMAIL_CLIENT_ID"; echo "SASL_PATH: $SASL_PATH"
ls -la (string split ':' $SASL_PATH)
# Refresh unit (disabled by default — modules/home/services/gmail-oauth2.nix)
systemctl --user status gmail-oauth2-refresh.timer
journalctl --user -u gmail-oauth2-refresh.service
refresh-gmail-oauth2
```
Note: on the app-password path there is **no token refresh** and **no `gmail-oauth2-refresh`
unit** — the app password does not expire, so a degraded/failed `gmail-oauth2-refresh.service` is
not expected (that unit is disabled).

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
- **App password**: A Gmail app password (not the account password) stored in the system keyring
  via libsecret (`gmail-app-password`); used by both mbsync (IMAP) and Himalaya SMTP. Requires
  2-Step Verification on the account. Long-lived and non-expiring; revoke from the Google account
  page if leaked.
- **Not committed**: the app password lives only in the keyring — never in version control or a
  Nix-declared file.
- *(Legacy OAuth2, retained as revert path: Client ID was semi-public; client secret + access/
  refresh tokens were keyring-stored. No longer active.)*

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

### Gmail Folder/Label Synchronization

Custom Gmail labels synchronize bidirectionally with Himalaya via mbsync. The `gmail-folders` channel uses wildcard patterns with exclusions:

```ini
Patterns * ![Gmail]* !INBOX
Create Both
Expunge Both
Remove Both
```

**Pattern Breakdown**:
- `*` - Sync all folders/labels
- `![Gmail]*` - Exclude Gmail system folders (Sent, Drafts, etc. - handled by dedicated channels)
- `!INBOX` - Exclude INBOX (handled by gmail-inbox channel)

**Directives**:
- `Create Both` - New folders created on either side sync to the other
- `Expunge Both` - Deleted messages sync in both directions
- `Remove Both` - Deleted folders sync in both directions

#### Folder Sync Workflows

**Creating a folder in Gmail**:
1. Create a new label in Gmail web interface
2. Run `mbsync gmail-folders` to sync
3. Folder appears in `himalaya folder list --account gmail`

**Creating a folder in Himalaya**:
1. Run `himalaya folder add MyFolder --account gmail`
2. Run `mbsync gmail-folders` to sync
3. Label appears in Gmail web interface

**Deleting a folder**:
1. Delete the folder/label in either Gmail or Himalaya
2. Run `mbsync gmail-folders` to propagate deletion
3. The `Remove Both` directive ensures the deletion syncs to the other side

**Note**: Folder operations only affect the gmail-folders channel. System folders (Inbox, Sent, Drafts, etc.) are managed by dedicated channels and are not affected by these patterns.

### Protonmail Folder/Label Synchronization

Protonmail uses two types of organizational structures:
- **Labels** - Can be applied to multiple messages (tagging/categorization)
- **Folders** - Each message belongs to exactly one folder (organization)

Both are exposed via Protonmail Bridge as IMAP folders under `Labels/*` and `Folders/*` respectively.

#### mbsync Configuration

Two channels handle bidirectional sync:

```ini
Channel logos-labels
Far :logos-remote:
Near :logos-local:
Patterns "Labels/*"
Create Both
Expunge Both
Remove Both
SyncState *

Channel logos-folders
Far :logos-remote:
Near :logos-local:
Patterns "Folders/*"
Create Both
Expunge Both
Remove Both
SyncState *
```

Both channels are included in the `logos` group for unified sync operations.

**Directives**:
- `Create Both` - New labels/folders created on either side sync to the other
- `Expunge Both` - Deleted messages sync in both directions
- `Remove Both` - Deleted labels/folders sync in both directions

#### Label/Folder Sync Workflows

**Creating a label/folder in Protonmail**:
1. Create a new label or folder in Protonmail web interface
2. Run `mbsync logos-labels` or `mbsync logos-folders` (or `mbsync logos` for all)
3. Folder appears in `himalaya folder list --account logos` as `Labels/YourLabel` or `Folders/YourFolder`

**Creating a label/folder in Himalaya**:
1. Run `himalaya folder add "Labels/MyLabel" --account logos` for a label
2. Or run `himalaya folder add "Folders/MyFolder" --account logos` for a folder
3. Run `mbsync logos-labels` or `mbsync logos-folders` to sync
4. Label/folder appears in Protonmail web interface

**Deleting a label/folder**:
1. Delete via Protonmail web interface, or remove from local Maildir
2. Run `mbsync logos-labels` or `mbsync logos-folders` to propagate deletion
3. The `Remove Both` directive ensures the deletion syncs to the other side

**Important Notes**:
- Protonmail Bridge must be running for sync to work
- Root-level folder creation is not allowed; all user items must be under `Labels/` or `Folders/`
- System folders (INBOX, Sent, Drafts, Trash, Archive) are managed by dedicated channels
- The "Password is being sent in the clear" warning is expected (Bridge runs on localhost)