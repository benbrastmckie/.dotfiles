# Implementation Summary: Task #20

**Completed**: 2026-02-09
**Duration**: ~30 minutes

## Changes Made

Added dual-account email support (Gmail + Protonmail via Bridge) to the NixOS home.nix configuration. The existing Gmail-only setup has been extended to include the Logos Labs Protonmail account accessed via Protonmail Bridge running locally.

## Files Modified

- `home.nix` - Four changes:
  1. Added `protonmail-bridge` package to home.packages (line ~185)
  2. Added `[accounts.logos]` section to himalaya config.toml with maildir backend and SMTP via Bridge
  3. Added logos IMAPAccount, stores, and channels to mbsyncrc for IMAP sync via Bridge
  4. Added ~/Mail/Logos directory structure to createMailDir activation script

## Configuration Details

### Himalaya Config (logos account)
- Backend: maildir at ~/Mail/Logos with Maildir++ format
- SMTP: via Bridge at 127.0.0.1:1025, no encryption, password auth from keyring
- Folders: INBOX, Sent, Drafts, Trash, Archive

### mbsync Config (logos channels)
- IMAP: via Bridge at 127.0.0.1:1143 with LOGIN auth, no SSL
- Channels: logos-inbox, logos-sent, logos-drafts, logos-trash, logos-archive
- Group: logos (syncs all channels)

### Maildir Structure
Created by activation script:
- ~/Mail/Logos/INBOX/{cur,new,tmp}
- ~/Mail/Logos/Sent/{cur,new,tmp}
- ~/Mail/Logos/Drafts/{cur,new,tmp}
- ~/Mail/Logos/Trash/{cur,new,tmp}
- ~/Mail/Logos/Archive/{cur,new,tmp}

## Verification

- `home-manager build --flake .#benjamin` - Build succeeded
- protonmail-bridge package fetched from cache (3.21.2)
- himalaya config.toml and mbsyncrc derivations built successfully

## Manual Steps Required (Post-Switch)

After running `home-manager switch --flake .#benjamin`:

1. **Start Protonmail Bridge**: `protonmail-bridge`
2. **Login to Protonmail**: Enter credentials in Bridge GUI
3. **Store Bridge password in keyring**:
   ```bash
   secret-tool store --label="Protonmail Bridge - Logos Labs" \
     service protonmail-bridge \
     username benjamin@logos-labs.ai
   ```
   (Enter the bridge-generated password when prompted)
4. **Test mbsync**: `mbsync logos-inbox`
5. **Test Himalaya**: `himalaya list -a logos`

## Notes

- Bridge uses local ports 1143 (IMAP) and 1025 (SMTP) with no encryption (localhost only)
- Password stored in GNOME keyring using secret-tool with service "protonmail-bridge"
- All changes are additive; Gmail configuration unchanged
- nix flake check was rate-limited by GitHub but home-manager build verified the configuration
