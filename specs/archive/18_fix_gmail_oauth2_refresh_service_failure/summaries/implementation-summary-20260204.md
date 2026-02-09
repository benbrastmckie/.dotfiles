# Implementation Summary: Task #18

**Completed**: 2026-02-04
**Duration**: ~10 minutes

## Changes Made

Updated the GMAIL_CLIENT_ID environment variable in `home.nix` from the old Google OAuth2 client ID (`810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com`) to the new one (`REDACTED_CLIENT_ID`) in both locations where it was defined. This aligns the systemd service environment with the client ID that was used during the OAuth2 wizard flow and is bound to the existing keyring tokens.

## Files Modified

- `home.nix` - Updated GMAIL_CLIENT_ID in two locations:
  - Line 451: `systemd.user.sessionVariables` block
  - Line 761: `home.sessionVariables` block

## Verification

- `nix flake check`: Passed (all NixOS and Home Manager configurations evaluated successfully)
- `home-manager build --flake .#benjamin`: Passed (built gmail-oauth2-refresh.service with updated client ID)
- Verified no references to old client ID (`810486121108`) remain in home.nix
- Verified new client ID (`436934406`) present in both expected locations

## User Actions Required

Before running `home-manager switch`, the user must complete Phase 2 (store client secret in keyring):

```bash
# Store the client secret in GNOME Keyring
echo -n "REDACTED_CLIENT_SECRET" | secret-tool store \
  --label="gmail-smtp-oauth2-client-secret@himalaya-cli:default (keyring v3.6.1)" \
  service himalaya-cli \
  username gmail-smtp-oauth2-client-secret \
  application rust-keyring \
  target default

# Verify it was stored
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-client-secret
```

After storing the secret, apply the configuration and verify:

```bash
home-manager switch --flake .#benjamin
systemctl --user reset-failed gmail-oauth2-refresh.service
systemctl --user start gmail-oauth2-refresh.service
systemctl --user status gmail-oauth2-refresh.service
```

## Notes

- The `home-manager switch` command was intentionally NOT run to avoid applying changes before the user stores the client secret in the keyring
- The token endpoint version (v4 vs v3) was not changed as the optional alignment was deprioritized; both versions work
- The configuration builds cleanly, confirming the Nix syntax is correct and the change is safe to apply
