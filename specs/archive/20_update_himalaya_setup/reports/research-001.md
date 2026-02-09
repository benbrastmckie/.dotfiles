# Research Report: Task #20

**Task**: 20 - Update Himalaya Setup
**Started**: 2026-02-09T12:00:00Z
**Completed**: 2026-02-09T12:30:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: Task 51 (referenced but appears to be in Neovim config repo)
**Sources/Inputs**: himalaya-manual-setup-guide.md, home.nix, existing nvim himalaya plugin
**Artifacts**: - specs/20_update_himalaya_setup/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The manual setup guide describes adding a second email account (Protonmail via Bridge) to the existing Gmail-only setup
- Current configuration in home.nix and himalaya config.toml only has Gmail configured - no Protonmail account exists yet
- Protonmail Bridge is not installed on the system
- The Neovim himalaya plugin has extensive multi-account support infrastructure but is configured for Gmail only
- Implementation requires both Nix configuration changes (home.nix) and manual steps (Bridge login, keyring storage)

## Context and Scope

The manual setup guide at `/home/benjamin/.config/nvim/docs/himalaya-manual-setup-guide.md` was created for Task #51 in the Neovim config repository. It describes a 6-phase implementation plan for adding a Protonmail account (benjamin@logos-labs.ai) alongside the existing Gmail account (benbrastmckie@gmail.com).

This research analyzes what changes need to be made to the dotfiles repository to support the dual-account configuration described in the guide.

## Findings

### Current Configuration State

**Himalaya CLI Configuration** (`~/.config/himalaya/config.toml`):
- Nix-managed symlink pointing to `/nix/store/.../home-manager-files/.config/himalaya/config.toml`
- Only contains `[accounts.gmail]` section
- No `[accounts.logos]` section exists
- Gmail configured with OAuth2 authentication for SMTP, maildir backend for reading

**mbsync Configuration** (`~/.mbsyncrc`):
- Nix-managed via home.nix
- Only contains Gmail account configuration
- No Protonmail/Logos account channels defined
- Gmail uses XOAUTH2 authentication

**Maildir Structure** (`~/Mail/`):
- `~/Mail/Gmail/` exists with proper structure
- `~/Mail/Logos/` does NOT exist
- No Protonmail maildir directories created

**Protonmail Bridge**:
- NOT installed (verified via `which protonmail-bridge`)
- Guide recommends adding to home.packages in home.nix

**Neovim Plugin Configuration** (`~/.config/nvim/lua/neotex/plugins/tools/himalaya/config/accounts.lua`):
- Default account is `gmail` with mbsync channel mappings
- No `logos` account configuration present
- Plugin infrastructure supports multiple accounts but only one is configured

### Configuration Files Requiring Updates

1. **`/home/benjamin/.dotfiles/home.nix`**:
   - Add `protonmail-bridge` to `home.packages` (line ~146 area)
   - Update `".config/himalaya/config.toml".text` block (line ~509-551) to add logos account
   - Update `".mbsyncrc".text` block (line ~555-645) to add logos account channels
   - Add maildir activation for `~/Mail/Logos/` in `home.activation.createMailDir` (line ~416-426)

2. **Manual Steps (cannot be automated)**:
   - Install and run Protonmail Bridge
   - Log in to benjamin@logos-labs.ai via Bridge GUI
   - Copy Bridge-generated password
   - Store password in GNOME keyring via secret-tool

### Guide vs Current Configuration Comparison

| Component | Guide Recommendation | Current State | Action Required |
|-----------|---------------------|---------------|-----------------|
| Protonmail Bridge | Install via Nix | Not installed | Add to home.packages |
| himalaya config logos | Add [accounts.logos] section | Only gmail exists | Add to home.nix text block |
| mbsync logos channels | Add IMAPAccount logos + channels | Only gmail channels | Add to home.nix text block |
| Mail/Logos directory | Create with activation script | Does not exist | Add to createMailDir |
| Bridge password | Store in keyring | N/A | Manual step |
| Neovim plugin | Add logos to accounts.lua | Gmail only | Optional - in nvim repo |

### Recommended Implementation Approach

**Phase 1: Nix Configuration Updates (in dotfiles repo)**
1. Add `protonmail-bridge` to home.packages
2. Add logos account section to himalaya config.toml text block
3. Add logos channels to mbsyncrc text block
4. Add Logos maildir creation to activation script
5. Run `home-manager switch`

**Phase 2: Manual Bridge Setup**
1. Run `protonmail-bridge`
2. Log in with Protonmail credentials
3. Copy bridge password
4. Store in keyring: `secret-tool store --label="Protonmail Bridge - Logos Labs" service protonmail-bridge username benjamin@logos-labs.ai`

**Phase 3: Verification**
1. Verify Bridge is running on ports 1143/1025
2. Test mbsync: `mbsync logos-inbox`
3. Test Himalaya: `himalaya list -a logos`

### Key Configuration Blocks from Guide

**Himalaya logos account** (to add to home.nix):
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
message.send.backend.encryption = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.login = "benjamin@logos-labs.ai"
message.send.backend.auth.password.keyring = "protonmail-bridge benjamin@logos-labs.ai"
```

**mbsync logos channels** (to add to home.nix):
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

Group logos
Channel logos-inbox
Channel logos-sent
Channel logos-drafts
Channel logos-trash
```

## Decisions

1. **Configuration approach**: Update home.nix directly since both himalaya config and mbsyncrc are Nix-managed symlinks
2. **Bridge password storage**: Use secret-tool with service "protonmail-bridge" as specified in guide
3. **Maildir format**: Use Maildir++ format (SubFolders Maildir++) to match existing Gmail setup
4. **SSL settings**: Use `SSLType None` for Bridge (runs locally without TLS)
5. **Authentication**: Use `AuthMechs LOGIN` for Bridge (not XOAUTH2 like Gmail)

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Bridge not available in home-manager switch session | Bridge login is a manual post-switch step |
| Keyring password not set before mbsync test | Guide clearly documents the sequence |
| Protonmail folder names differ from Gmail | Using standard names (INBOX, Sent, Drafts, Trash) |
| Large initial sync | Can sync inbox-only first (`mbsync logos-inbox`) |
| Nix rebuild fails | All changes are additive; no breaking changes to Gmail config |

## Appendix

### Search Queries Used
- Glob for himalaya files in dotfiles and nvim config
- Grep for "himalaya" across dotfiles
- Read of manual setup guide, home.nix, accounts.lua, config/init.lua, mbsync.lua

### References
- `/home/benjamin/.config/nvim/docs/himalaya-manual-setup-guide.md` - Primary source
- `/home/benjamin/.config/nvim/specs/051_complete_himalaya_email_configuration/plans/implementation-002.md` - Related task plan
- `/home/benjamin/.dotfiles/home.nix` - Current configuration (lines ~509-645 for email config)
- `/home/benjamin/.dotfiles/docs/himalaya.md` - Existing himalaya documentation
