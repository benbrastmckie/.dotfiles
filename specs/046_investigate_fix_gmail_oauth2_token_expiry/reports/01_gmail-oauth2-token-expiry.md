# Research Report: Task #46

**Task**: 46 - investigate_fix_gmail_oauth2_token_expiry
**Started**: 2026-03-24T17:45:00Z
**Completed**: 2026-03-24T18:10:00Z
**Effort**: 25 minutes
**Dependencies**: None
**Sources/Inputs**: Local configuration analysis, systemd logs, Google OAuth2 documentation, himalaya documentation
**Artifacts**: specs/046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- **Root Cause Identified**: The Gmail OAuth2 tokens are expiring due to Google's **Testing Mode 7-day refresh token expiry limit**
- The OAuth consent screen in Google Cloud Console is likely still in "Testing" status, causing refresh tokens to expire after 7 days
- The `gmail-oauth2-refresh.service` is failing with `invalid_grant` errors, indicating the refresh token itself has been revoked/expired
- Two authentication paths exist: mbsync uses OAuth2/XOAUTH2, while himalaya/aerc currently use app-specific passwords
- **Primary Solution**: Publish the OAuth app to Production mode in Google Cloud Console to get permanent refresh tokens
- **Alternative Solution**: Continue using app-specific passwords for SMTP (currently working) and fix OAuth2 only for mbsync

## Context & Scope

The user experiences repeated Gmail OAuth2 token expiry, requiring frequent re-authentication via `himalaya account configure gmail`. This affects the email synchronization workflow.

### Current Architecture

The system has **two parallel authentication mechanisms**:

| Component | Auth Method | Status |
|-----------|-------------|--------|
| mbsync (IMAP sync) | OAuth2/XOAUTH2 | **Broken** - tokens expiring |
| himalaya (CLI) | App password | **Working** |
| aerc (TUI) | App password | **Working** |

**Key Files**:
- `~/.mbsyncrc` - Uses XOAUTH2 with `gmail-smtp-oauth2-access-token`
- `~/.config/himalaya/config.toml` - Uses app password via `gmail-app-password`
- `~/.config/aerc/accounts.conf` - Uses app password via `gmail-app-password`
- `home.nix` - Defines `refresh-gmail-oauth2` script and systemd timer

### Token Refresh Flow

```
gmail-oauth2-refresh.timer (every 45 min)
    |
    v
gmail-oauth2-refresh.service
    |
    v
refresh-gmail-oauth2 script
    |
    +-- Reads from keyring:
    |   - CLIENT_ID (env var)
    |   - CLIENT_SECRET (himalaya-cli/gmail-smtp-oauth2-client-secret)
    |   - REFRESH_TOKEN (himalaya-cli/gmail-smtp-oauth2-refresh-token)
    |
    +-- POSTs to https://www.googleapis.com/oauth2/v4/token
    |
    +-- On success: stores new ACCESS_TOKEN to keyring
```

## Findings

### 1. Current Error State

The systemd service is failing consistently with `invalid_grant`:

```
Mar 24 17:04:11 hamsa refresh-gmail-oauth2[2385196]: Failed to refresh OAuth2 token. Response: {
Mar 24 17:04:11 hamsa refresh-gmail-oauth2[2385196]:   "error": "invalid_grant",
Mar 24 17:04:11 hamsa refresh-gmail-oauth2[2385196]:   "error_description": "Bad Request"
Mar 24 17:04:11 hamsa refresh-gmail-oauth2[2385196]: }
```

This error indicates the **refresh token itself is invalid/expired**, not just the access token.

### 2. Keyring State

All required tokens are present in GNOME Keyring:

| Entry | Status |
|-------|--------|
| `gmail-smtp-oauth2-refresh-token` | Present (starts with `1//06dCyD...`) |
| `gmail-smtp-oauth2-access-token` | Present (starts with `ya29.a0ATk...`) |
| `gmail-smtp-oauth2-client-secret` | Present (starts with `GOCSPX-jDoc...`) |

The tokens exist but the refresh token has been **revoked by Google**.

### 3. Root Cause Analysis: Testing Mode 7-Day Expiry

Based on Google's OAuth2 documentation, the most likely cause is:

**Testing Mode Limitation**: When an OAuth consent screen is configured as:
- User type: **External**
- Publishing status: **Testing**

Google enforces a **7-day refresh token expiry**. This means:
- Every 7 days, the refresh token becomes invalid
- The user must re-authenticate via `himalaya account configure gmail`
- This behavior is intentional and documented by Google

From Google documentation:
> "Authorizations by a test user will expire seven days from the time of consent. If your OAuth client requests an offline access type and receives a refresh token, that token will also expire."

### 4. Other Possible Causes

| Cause | Likelihood | Evidence |
|-------|------------|----------|
| Testing mode 7-day expiry | **High** | Matches symptom pattern, previous task 18 history |
| Password change with Gmail scopes | Low | Would revoke immediately, not periodically |
| Token limit exceeded (100/client) | Low | Single user, unlikely to hit limit |
| 6-month inactivity | Low | Timer runs every 45 min, token is used |
| Admin/workspace policies | Low | Personal Gmail account |
| Client ID mismatch | Low | Task 18 previously fixed this issue |

### 5. Historical Context (Task 18)

Previous task 18 addressed a related issue where:
1. The `GMAIL_CLIENT_ID` in home.nix didn't match the client ID used during OAuth wizard
2. The client secret keyring entry was empty
3. These were fixed by updating the client ID to `REDACTED_CLIENT_ID`

The current tokens are bound to this client ID. The `invalid_grant` errors suggest the **refresh token is now expired due to Testing mode**, not a client ID mismatch.

### 6. Current Dual-Authentication Design

The system evolved to use two auth methods:

**OAuth2 (for mbsync IMAP sync)**:
- Required for XOAUTH2 authentication with Gmail IMAP
- Tokens stored in keyring under `service=himalaya-cli`
- Refresh handled by systemd timer

**App Password (for himalaya/aerc SMTP)**:
- Simpler, no token refresh needed
- Stored in keyring under `service=gmail-app-password`
- Currently working

This hybrid approach was likely adopted because:
1. mbsync requires XOAUTH2 for Gmail IMAP (less secure apps disabled)
2. himalaya/aerc SMTP can use app passwords more simply
3. OAuth2 was causing recurring issues

## Recommendations

### Option 1: Publish OAuth App to Production (Recommended)

**Effort**: Low (5-10 minutes)
**Reliability**: High
**Trade-off**: Requires Google Cloud Console access, potential verification for sensitive scopes

**Steps**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select the project with client ID `REDACTED_CLIENT_ID`
3. Navigate to APIs & Services > OAuth consent screen
4. Click "Publish App" to move from Testing to Production
5. If prompted about verification:
   - For personal use with standard Gmail scopes, no verification typically required
   - If sensitive scopes (Gmail API full access), may need verification
6. Re-run `himalaya account configure gmail` to get new permanent tokens
7. Verify `systemctl --user status gmail-oauth2-refresh.service`

**Result**: Refresh tokens will no longer expire after 7 days.

### Option 2: Switch mbsync to App Password (Simpler Alternative)

**Effort**: Low (10-15 minutes)
**Reliability**: High
**Trade-off**: Requires Gmail 2FA and app password; less secure than OAuth2

If OAuth2 continues to be problematic, mbsync can use an app password instead of XOAUTH2:

1. Generate Gmail app password at https://myaccount.google.com/apppasswords
2. Store in keyring:
   ```bash
   echo -n "YOUR_APP_PASSWORD" | secret-tool store \
     --label="Gmail App Password for mbsync" \
     service gmail-mbsync \
     username benbrastmckie@gmail.com
   ```
3. Update `~/.mbsyncrc`:
   ```ini
   IMAPAccount gmail
   Host imap.gmail.com
   Port 993
   User benbrastmckie@gmail.com
   AuthMechs LOGIN
   PassCmd "secret-tool lookup service gmail-mbsync username benbrastmckie@gmail.com"
   TLSType IMAPS
   ```
4. Disable OAuth2 refresh timer (optional):
   ```bash
   systemctl --user disable gmail-oauth2-refresh.timer
   ```

**Result**: No token refresh needed; app password doesn't expire.

### Option 3: Keep OAuth2 with Enhanced Error Handling

**Effort**: Medium
**Reliability**: Medium (still requires periodic re-auth in Testing mode)

If staying in Testing mode, improve the user experience:

1. Add notification on token failure
2. Add automatic browser-based re-auth prompt
3. Consider using himalaya's built-in OAuth2 handling instead of custom script

### Option 4: Use Restricted Scopes (Exempt from 7-Day Limit)

**Effort**: Low
**Reliability**: High
**Trade-off**: May not work if full Gmail API access is needed

Google exempts these scopes from the 7-day expiry:
- `userinfo.email`
- `userinfo.profile`
- `openid`

However, Gmail IMAP/SMTP requires `https://mail.google.com/` which is **not exempt**.

## Configuration Changes Required

### For Option 1 (Production Mode)

No code changes needed. Only Google Cloud Console configuration change + re-authentication.

### For Option 2 (App Password for mbsync)

**File**: `home.nix` (or `~/.mbsyncrc` if not managed by Home Manager)

Change mbsync Gmail account from XOAUTH2 to LOGIN:

```ini
# Before (OAuth2)
IMAPAccount gmail
AuthMechs XOAUTH2
PassCmd "secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token"

# After (App Password)
IMAPAccount gmail
AuthMechs LOGIN
PassCmd "secret-tool lookup service gmail-mbsync username benbrastmckie@gmail.com"
```

## Decisions

1. **Primary recommendation**: Publish OAuth app to Production mode
2. If Production mode verification is problematic, fall back to app passwords for mbsync
3. Keep existing app password setup for himalaya/aerc SMTP (already working)
4. The custom `refresh-gmail-oauth2` script design is sound; the issue is Google's Testing mode limitation

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Production mode requires verification | Medium | Delays fix | Check scope requirements; basic scopes often exempt |
| App password compromise | Low | Account access | Revoke at myaccount.google.com if compromised |
| Google deprecates app passwords | Low | Future breakage | App passwords are still supported as of 2026 |
| Re-auth required after Production publish | Certain | One-time | Run `himalaya account configure gmail` once |

## Appendix

### References

- [Google OAuth2 Token Expiry in Testing Mode](https://support.google.com/cloud/answer/15549945)
- [Google OAuth invalid_grant Errors](https://nango.dev/blog/google-oauth-invalid-grant-token-has-been-expired-or-revoked)
- [Gmail OAuth 2.0 Authentication Changes 2026](https://www.getmailbird.com/gmail-oauth-authentication-changes-user-guide/)
- [Using OAuth 2.0 to Access Google APIs](https://developers.google.com/identity/protocols/oauth2)
- [Gmail App Passwords](https://support.google.com/mail/answer/185833)
- [Himalaya GitHub](https://github.com/pimalaya/himalaya)

### Files Analyzed

| File | Purpose |
|------|---------|
| `~/.dotfiles/home.nix` | Home Manager configuration with OAuth2 script |
| `~/.config/himalaya/config.toml` | Himalaya account config (uses app password) |
| `~/.mbsyncrc` | mbsync config (uses XOAUTH2) |
| `~/.config/aerc/accounts.conf` | aerc config (uses app password) |
| `~/.config/systemd/user/gmail-oauth2-refresh.service` | Systemd service for token refresh |

### Commands Used

```bash
# Check service status
systemctl --user status gmail-oauth2-refresh.service

# View service logs
journalctl --user -u gmail-oauth2-refresh.service -n 50

# Check keyring entries
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-refresh-token

# Re-authenticate Gmail OAuth2
himalaya account configure gmail
```

### Google Cloud Console Client ID

```
Client ID: REDACTED_CLIENT_ID
```

This is the client ID configured in `home.nix` and bound to the current OAuth2 tokens.
