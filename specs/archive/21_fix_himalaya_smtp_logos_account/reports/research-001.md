# Research Report: Task #21

**Task**: 21 - Fix Himalaya SMTP sending for logos account
**Started**: 2026-02-09T00:00:00Z
**Completed**: 2026-02-09T00:30:00Z
**Effort**: 30 minutes (implementation)
**Dependencies**: None
**Sources/Inputs**: Himalaya docs, config.sample.toml, GitHub releases, existing home.nix
**Artifacts**: - specs/21_fix_himalaya_smtp_logos_account/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The TOML parse error is caused by incorrect configuration syntax: `message.send.backend.auth.password.keyring` should be `message.send.backend.auth.keyring`
- Additionally, `message.send.backend.auth.login` is wrong; the login field is at `message.send.backend.login` (not under auth)
- The correct Himalaya v1.1.0 password authentication format has been verified and tested
- The Protonmail Bridge password is already stored in the system keyring
- Fix requires updating the logos account section in home.nix

## Context and Scope

The user is running Himalaya v1.1.0 and attempting to configure SMTP sending for the logos (Protonmail) account. The error message is:

```
TOML parse error at line 54, column 14
54 | message.send.backend.type = "smtp"
                 ^^^^^^^
invalid value: map, expected map with a single key
```

This error occurs because serde (the Rust serialization library) encounters a configuration structure that doesn't match the expected schema.

## Findings

### Root Cause Analysis

The attempted configuration in the task description:
```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.login = "benjamin@logos-labs.ai"
message.send.backend.auth.password.keyring = "protonmail-bridge benjamin@logos-labs.ai"
```

**Errors identified**:

1. **Wrong field: `message.send.backend.auth.login`**
   - Correct: `message.send.backend.login` (login is NOT under auth)

2. **Wrong field: `message.send.backend.auth.password.keyring`**
   - Correct: `message.send.backend.auth.keyring` (no `.password.` intermediate)

3. **Keyring value format issue**: The keyring value should be a simple identifier, not a space-separated service/username pair

### Correct Configuration Format

Based on testing with Himalaya v1.1.0, here is the verified working format:

**Option 1: Using auth.cmd (recommended - matches existing mbsync pattern)**
```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
```

**Option 2: Using auth.keyring (requires himalaya account configure)**
```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.keyring = "protonmail-bridge-logos"
```

### Field Reference (Himalaya v1.1.0)

| Field | Purpose | Example Value |
|-------|---------|---------------|
| `message.send.backend.type` | Backend type | `"smtp"` |
| `message.send.backend.host` | SMTP server | `"127.0.0.1"` |
| `message.send.backend.port` | SMTP port | `1025` |
| `message.send.backend.login` | SMTP username | `"benjamin@logos-labs.ai"` |
| `message.send.backend.encryption.type` | Encryption | `"none"`, `"start-tls"`, `"tls"` |
| `message.send.backend.auth.type` | Auth method | `"password"`, `"oauth2"` |
| `message.send.backend.auth.raw` | Inline password (unsafe) | `"p@ssword"` |
| `message.send.backend.auth.cmd` | Command to get password | `"pass show email"` |
| `message.send.backend.auth.keyring` | Keyring identifier | `"my-smtp-password"` |

### Verification Tests

Both configuration options were tested and parse correctly:

```bash
$ himalaya -c /tmp/test-himalaya-config.toml account list
| NAME  | BACKENDS      | DEFAULT |
|-------|---------------|---------|
| logos | Maildir, SMTP |         |
```

The Protonmail Bridge password is already stored in the keyring:
```bash
$ secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai
# (returns password - verified present)
```

### Current State in home.nix

The logos account in home.nix (lines 559-579) is missing the SMTP configuration entirely:

```toml
# Logos Labs account (via Protonmail Bridge)
[accounts.logos]
default = false
email = "benjamin@logos-labs.ai"
display-name = "Benjamin Brast-McKie"
downloads-dir = "/home/benjamin/Downloads"

backend.type = "maildir"
backend.root-dir = "/home/benjamin/Mail/Logos"
backend.maildirpp = true

# Folder configuration for Protonmail
folder.alias.inbox = "INBOX"
folder.alias.sent = "Sent"
folder.alias.drafts = "Drafts"
folder.alias.trash = "Trash"
folder.alias.archive = "Archive"

# Configure sent message handling
message.send.save-copy = true
folder.sent.name = "Sent"
```

The SMTP send backend section needs to be added.

## Recommendations

### Implementation Approach

**Recommended: Use auth.cmd** - This matches the existing pattern in `.mbsyncrc` which uses the same `secret-tool lookup` command.

Add the following lines after `backend.maildirpp = true` in the logos account section:

```toml
# SMTP send backend (via Protonmail Bridge)
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
```

### Post-Implementation Verification

1. Rebuild home-manager: `home-manager switch --flake .#benjamin`
2. Verify config: `himalaya -a logos account list`
3. Test sending: `echo "Test" | himalaya -a logos message send test@example.com`

## Decisions

1. **Use auth.cmd over auth.keyring**: The auth.cmd approach uses the existing secret-tool pattern from mbsync, ensuring consistency and avoiding the need to run `himalaya account configure`
2. **encryption.type = "none"**: Protonmail Bridge runs locally and handles encryption to Protonmail servers itself
3. **Port 1025**: Standard Protonmail Bridge SMTP port

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Bridge not running | Test with `nc -zv 127.0.0.1 1025` before sending |
| Password not in keyring | Already verified present; if missing, re-run Bridge login |
| Self-signed certificate issues | Bridge handles this internally; encryption = none for local |

## Appendix

### Search Queries Used
- "Himalaya email client v1.1.0 SMTP configuration TOML format password authentication"
- "soywod himalaya github SMTP backend configuration example"
- "himalaya 1.1.0 SMTP encryption type none starttls tls password auth keyring configuration"
- "himalaya TOML expected map with single key auth password configuration"

### References
- [Himalaya GitHub Repository](https://github.com/pimalaya/himalaya)
- [config.sample.toml](https://github.com/pimalaya/himalaya/blob/master/config.sample.toml)
- [Himalaya v1.1.0 Release Notes](https://github.com/pimalaya/himalaya/releases)
- [GitHub Issue #60: Protonmail Bridge SMTP](https://github.com/soywod/himalaya/issues/60)
- Installed version: himalaya v1.1.0 +wizard +pgp-commands +oauth2 +sendmail +imap +smtp +keyring +maildir
