# Implementation Plan: Fix Gmail OAuth2 Refresh Service Failure

- **Task**: 18 - fix_gmail_oauth2_refresh_service_failure
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/18_fix_gmail_oauth2_refresh_service_failure/reports/research-001.md, specs/18_fix_gmail_oauth2_refresh_service_failure/reports/research-002.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

The gmail-oauth2-refresh.service systemd user service fails because of a client ID mismatch between the Home Manager configuration and the OAuth2 tokens stored in GNOME Keyring, combined with an empty client secret keyring entry. The fix requires updating the GMAIL_CLIENT_ID environment variable in home.nix to match the client ID that was used during the OAuth2 wizard flow, storing the correct client secret in the keyring, and rebuilding the Home Manager configuration. Research confirmed via curl tests that the new client ID successfully refreshes tokens while the old one returns `invalid_client`.

### Research Integration

Two research reports were produced for this task:

- **research-001.md**: Initial investigation identified the service architecture, confirmed himalaya installation, and found the missing/empty keyring entries. Recommended running the OAuth2 wizard.
- **research-002.md**: Follow-up investigation identified the root cause as a client ID mismatch (old `810486121108...` in home.nix vs new `436934406...` used by wizard), confirmed the client secret keyring entry is empty, and verified the correct credentials work via curl. Provided exact line references and fix commands.

## Goals & Non-Goals

**Goals**:
- Fix the gmail-oauth2-refresh.service so it successfully refreshes OAuth2 access tokens
- Align the GMAIL_CLIENT_ID environment variable with the client ID bound to the existing keyring tokens
- Populate the empty client secret keyring entry with the correct value
- Verify the service runs successfully after the fix
- Optionally align the token endpoint version (v4 to v3) for consistency

**Non-Goals**:
- Rotating the client secret in Google Cloud Console (can be done later as a security measure)
- Changing the overall OAuth2 architecture or refresh script logic
- Migrating away from GNOME Keyring or himalaya

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Client secret visible in research reports | Medium | Medium | Repository is private; rotate secret in Google Cloud Console if ever made public |
| Home Manager rebuild breaks other services | Medium | Low | Run `home-manager build` (dry run) before `home-manager switch` |
| Keyring entry stored with wrong attributes | High | Low | Use exact attribute format verified in research (service, username, application, target) |
| Refresh token expired or revoked | Medium | Low | Re-run `himalaya account configure gmail` wizard if token refresh still fails |

## Implementation Phases

### Phase 1: Update GMAIL_CLIENT_ID in home.nix [COMPLETED]

**Goal:** Replace the old Google OAuth2 client ID with the new one in both locations in home.nix so the environment variable matches the client ID bound to the existing keyring tokens.

**Tasks:**
- [ ] Read home.nix to confirm current GMAIL_CLIENT_ID locations and values
- [ ] Update GMAIL_CLIENT_ID in `systemd.user.sessionVariables` (approximately line 451) from `810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com` to `REDACTED_CLIENT_ID`
- [ ] Update GMAIL_CLIENT_ID in `home.sessionVariables` (approximately line 761) from `810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com` to `REDACTED_CLIENT_ID`
- [ ] (Optional) Align token endpoint in refresh script from v4 to v3 for consistency with himalaya config

**Timing:** 15 minutes

**Files to modify:**
- `home.nix` - Update GMAIL_CLIENT_ID in two locations (systemd session variables and home session variables); optionally update token endpoint URL in refresh script

**Verification:**
- `grep -n "GMAIL_CLIENT_ID" home.nix` shows the new client ID in both locations
- No other references to the old client ID remain in home.nix

---

### Phase 2: Store Client Secret in Keyring [COMPLETED]

**Goal:** Populate the empty `gmail-smtp-oauth2-client-secret` keyring entry with the correct client secret value.

**Tasks:**
- [ ] **USER ACTION REQUIRED**: Run the following command interactively to store the client secret in GNOME Keyring:
  ```bash
  echo -n "REDACTED_CLIENT_SECRET" | secret-tool store \
    --label="gmail-smtp-oauth2-client-secret@himalaya-cli:default (keyring v3.6.1)" \
    service himalaya-cli \
    username gmail-smtp-oauth2-client-secret \
    application rust-keyring \
    target default
  ```
- [ ] Verify the secret was stored correctly:
  ```bash
  secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-client-secret
  ```
  This should output the client secret value (non-empty).

**Timing:** 5 minutes

**Files to modify:** None (keyring operation only)

**Verification:**
- `secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-client-secret` returns a non-empty value

**Note:** This phase requires interactive user action because it involves writing a secret to the GNOME Keyring. The client secret must not be hardcoded in Nix configuration files. The user must execute the `secret-tool store` command in a terminal session with access to the GNOME Keyring (typically a graphical desktop session).

---

### Phase 3: Rebuild and Verify [COMPLETED]

**Goal:** Rebuild the Home Manager configuration to propagate the updated GMAIL_CLIENT_ID, then verify the service runs successfully.

**Tasks:**
- [ ] Run `home-manager build --flake .#benjamin` to verify the configuration builds without errors (dry run)
- [ ] Run `home-manager switch --flake .#benjamin` to apply the configuration
- [ ] Reset the failed service state: `systemctl --user reset-failed gmail-oauth2-refresh.service`
- [ ] Start the service manually: `systemctl --user start gmail-oauth2-refresh.service`
- [ ] Check service status: `systemctl --user status gmail-oauth2-refresh.service` (should show success, exit code 0)
- [ ] Verify the timer is active: `systemctl --user list-timers | grep gmail`
- [ ] Verify the refreshed access token in keyring: `secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token` (should be non-empty and recently updated)
- [ ] Optionally test sending a mail via himalaya to confirm end-to-end flow

**Timing:** 15 minutes

**Files to modify:** None (rebuild and verification only)

**Verification:**
- `systemctl --user status gmail-oauth2-refresh.service` shows `Active: inactive (dead)` with exit code 0 (success for a oneshot service)
- `systemctl --user list-timers | grep gmail` shows the timer active and waiting
- `journalctl --user -xeu gmail-oauth2-refresh.service --since "5 minutes ago"` shows successful token refresh (no error messages)

## Testing & Validation

- [ ] `grep "GMAIL_CLIENT_ID" home.nix` shows the new client ID (`436934406...`) in both locations
- [ ] `secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-client-secret` returns non-empty value
- [ ] `home-manager build --flake .#benjamin` succeeds without errors
- [ ] `systemctl --user status gmail-oauth2-refresh.service` shows successful exit after manual start
- [ ] `journalctl --user -xeu gmail-oauth2-refresh.service --since "5 minutes ago"` shows no errors
- [ ] Timer continues to trigger at the expected interval (~45 minutes)

## Artifacts & Outputs

- `specs/18_fix_gmail_oauth2_refresh_service_failure/plans/implementation-001.md` (this file)
- `specs/18_fix_gmail_oauth2_refresh_service_failure/summaries/implementation-summary-20260204.md` (after implementation)
- Modified `home.nix` with updated GMAIL_CLIENT_ID

## Rollback/Contingency

If the fix does not resolve the service failure:

1. **Revert home.nix**: `git checkout home.nix` to restore the old GMAIL_CLIENT_ID values
2. **Re-run wizard**: If tokens are corrupted or expired, run `himalaya account configure gmail` to re-initialize the full OAuth2 flow with the correct client ID
3. **Rotate credentials**: If the client secret has been compromised, generate a new client secret in Google Cloud Console, re-run the wizard, and update the keyring entry
4. **Rebuild**: `home-manager switch --flake .#benjamin` after any revert to propagate changes
