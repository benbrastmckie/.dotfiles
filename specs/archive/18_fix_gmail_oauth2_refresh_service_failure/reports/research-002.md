# Research Report: Task #18 (Follow-up)

**Task**: Fix Gmail OAuth2 Refresh Service Failure
**Date**: 2026-02-04
**Focus**: Configuration consistency between himalaya wizard output, Home Manager config, and keyring

## Summary

The gmail-oauth2-refresh.service fails due to three interrelated issues: (1) the GMAIL_CLIENT_ID in home.nix points to the old Google Cloud project client ID while the OAuth2 tokens in the keyring were created with a different (new) client ID, (2) the client secret keyring entry exists but is empty, and (3) the config.toml inherits the wrong client ID via environment variable. Token refresh was verified working with the correct credentials.

## Findings

### Issue 1: Client ID Mismatch (Root Cause)

Two different Google OAuth2 client IDs are in play:

| Location | Client ID | Status |
|----------|-----------|--------|
| home.nix `GMAIL_CLIENT_ID` | `810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com` | OLD - does not match tokens |
| Wizard OAuth2 flow | `REDACTED_CLIENT_ID` | NEW - tokens bound to this |

The refresh token and access token in the GNOME Keyring were created by the wizard using the new client ID. OAuth2 refresh tokens are bound to the client ID that created them. Attempting to refresh with the old client ID returns `"invalid_client"` from Google's token endpoint.

**Verified empirically**:
- `curl` refresh with NEW client ID + correct secret: **SUCCESS** (returns new access_token)
- `curl` refresh with OLD client ID + any secret: **FAILURE** (`invalid_client`)

### Issue 2: Empty Client Secret in Keyring

The keyring entry `gmail-smtp-oauth2-client-secret` exists but contains an empty value:

```
[/8]
label = gmail-smtp-oauth2-client-secret@himalaya-cli:default (keyring v3.6.1)
secret =           <-- EMPTY
created = 2026-02-04 21:25:29
modified = 2026-02-04 22:00:41
```

The refresh script checks `[ -z "$CLIENT_SECRET" ]` and exits with:
```
Missing OAuth2 credentials. Please reconfigure: himalaya account configure gmail
```

The correct client secret for the new client ID is `REDACTED_CLIENT_SECRET` (visible in research-001.md from the wizard session).

The wizard likely used this secret during the interactive OAuth2 flow but stored an empty value in the keyring entry. This may be because the wizard's PKCE-based flow handles the secret differently from the keyring storage format.

### Issue 3: Config File References Wrong Client ID

The himalaya config at `~/.config/himalaya/config.toml` is a symlink to the Nix store (Home Manager managed):

```
/home/benjamin/.config/himalaya/config.toml -> /nix/store/aqz48h8cs9hianc0k8mrh9nh9s66d013-home-manager-files/.config/himalaya/config.toml
```

The config contains:
```toml
message.send.backend.auth.client-id = "${GMAIL_CLIENT_ID}"
```

This resolves at runtime to the old client ID `810486121108...` via environment variable. When himalaya itself attempts OAuth2 operations (e.g., refreshing during `himalaya message send`), it will use the wrong client ID.

### Issue 4: Token Endpoint Version Mismatch (Minor)

The refresh script uses `https://www.googleapis.com/oauth2/v4/token` while the himalaya config references `https://www.googleapis.com/oauth2/v3/token`. Both endpoints are functionally equivalent and supported by Google. This is not causing failures but should be aligned for consistency.

### Keyring State Summary

| Entry | Status | Value |
|-------|--------|-------|
| `gmail-smtp-oauth2-client-secret` | EXISTS, EMPTY | `` (zero-length) |
| `gmail-smtp-oauth2-refresh-token` | EXISTS, POPULATED | `1//069kNGHp...` (bound to new client ID) |
| `gmail-smtp-oauth2-access-token` | EXISTS, POPULATED | `ya29.a0AUMWg_LB...` (from wizard, may be expired) |

### Service Status

```
gmail-oauth2-refresh.service: failed (exit-code 1)
Error: "Missing OAuth2 credentials. Please reconfigure: himalaya account configure gmail"
```

The error comes from the empty client secret check, not from the client ID mismatch (which would be the next failure if the secret were present).

## Recommendations

### Required Changes (Implementation Plan)

#### Step 1: Update GMAIL_CLIENT_ID in home.nix

Change the client ID in two locations in `home.nix`:

```nix
# Line 451 (systemd.user.sessionVariables)
GMAIL_CLIENT_ID = "REDACTED_CLIENT_ID";

# Line 761 (home.sessionVariables)
GMAIL_CLIENT_ID = "REDACTED_CLIENT_ID";
```

#### Step 2: Store Client Secret in Keyring

```bash
echo -n "REDACTED_CLIENT_SECRET" | secret-tool store \
  --label="gmail-smtp-oauth2-client-secret@himalaya-cli:default (keyring v3.6.1)" \
  service himalaya-cli \
  username gmail-smtp-oauth2-client-secret \
  application rust-keyring \
  target default
```

#### Step 3: Rebuild Home Manager Configuration

```bash
cd ~/.dotfiles
home-manager switch --flake .#benjamin
```

This will:
- Update the `GMAIL_CLIENT_ID` environment variable
- Regenerate the himalaya config.toml with the correct client ID via env var
- Update the systemd service environment

#### Step 4: Restart and Verify Service

```bash
# Reset failed state
systemctl --user reset-failed gmail-oauth2-refresh.service

# Run the service manually
systemctl --user start gmail-oauth2-refresh.service

# Check status
systemctl --user status gmail-oauth2-refresh.service

# Verify timer
systemctl --user list-timers | grep gmail
```

### Optional Improvement: Align Token Endpoint

Update the refresh script's token endpoint from v4 to v3 to match the himalaya config:

```nix
# In the refresh script, change:
# https://www.googleapis.com/oauth2/v4/token
# to:
# https://www.googleapis.com/oauth2/v3/token
```

Both work, but consistency prevents confusion.

## Decisions

1. The new client ID (`436934406...`) is the correct one to use going forward since the tokens are bound to it
2. The client secret must be stored in the keyring with the exact attributes himalaya expects
3. The refresh script architecture is sound but depends on correct credentials alignment
4. PKCE is enabled but Google still requires client_secret for the refresh_token grant type

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| New client ID credentials revoked | Low | Service breaks | Keep Google Cloud Console access; can re-run wizard |
| Client secret exposed in research-001.md | Medium | Security concern | Rotate secret in Google Cloud Console if committed to public repo |
| Tokens expire during fix | Low | Need re-auth | Wizard can be re-run if needed |
| Home Manager rebuild breaks other services | Low | System disruption | Build-only first with `home-manager build`, then switch |

**Security Note**: The client secret `REDACTED_CLIENT_SECRET` and refresh token are visible in research-001.md. If this repository is public or shared, the client secret should be rotated in the Google Cloud Console after the fix is applied.

## References

- Previous research: `specs/18_fix_gmail_oauth2_refresh_service_failure/reports/research-001.md`
- [Google OAuth2 Token Endpoint Reference](https://developers.google.com/identity/protocols/oauth2/web-server#httprest_3)
- [PKCE for Google OAuth2](https://developers.google.com/identity/protocols/oauth2/native-app#exchange-authorization-code)

## Files Analyzed

- `/home/benjamin/.dotfiles/home.nix` (lines 165-453) - Full OAuth2 configuration
- `/home/benjamin/.config/himalaya/config.toml` - Symlink to Nix store, contains `${GMAIL_CLIENT_ID}`
- `/home/benjamin/.config/systemd/user/gmail-oauth2-refresh.service` - Generated service file
- GNOME Keyring entries (3 entries under `service=himalaya-cli`)

## Next Steps

Run `/plan 18` to create an implementation plan, or proceed directly with the fix since the changes are well-defined and verified.
