# Implementation Summary: Task #21

**Completed**: 2026-02-09
**Duration**: 15 minutes

## Changes Made

Added SMTP backend configuration to the logos (Protonmail) account in home.nix using the correct Himalaya v1.1.0 configuration format:

```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
```

**Key fixes from research**:
- `login` field is at backend level (not `auth.login`)
- Password retrieved via `auth.cmd` (not `auth.keyring` or `auth.password.keyring`)
- Uses secret-tool to retrieve Bridge password from keyring

## Files Modified

- `home.nix` - Added SMTP backend configuration to logos account (lines 570-577)

## Verification

- `home-manager switch` completed successfully
- `himalaya account list` shows logos with both Maildir and SMTP backends
- Configuration parses without TOML errors

## Notes

- Protonmail Bridge must be running for sending to work (localhost:1025)
- Bridge password was already stored in keyring during manual setup
- Encryption is "none" for local connection (Bridge handles encryption to Protonmail servers)
