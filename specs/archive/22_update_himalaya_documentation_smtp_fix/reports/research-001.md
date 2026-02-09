# Research Report: Task #22

**Task**: 22 - Update Himalaya documentation for SMTP fix
**Started**: 2026-02-09T00:00:00Z
**Completed**: 2026-02-09T00:15:00Z
**Effort**: 15 minutes
**Dependencies**: Task 21 (Fix Himalaya SMTP sending for logos account) - completed
**Sources/Inputs**: docs/himalaya.md, home.nix, task 21 artifacts
**Artifacts**: - specs/22_update_himalaya_documentation_smtp_fix/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The current `docs/himalaya.md` shows **incorrect** SMTP configuration syntax at lines 226-232
- The incorrect format uses `auth.password.keyring` which causes TOML parse errors
- Task 21 fixed this by using `auth.cmd` with a secret-tool command
- Documentation update requires replacing the logos account SMTP configuration example with the working syntax

## Context and Scope

Task 21 fixed Himalaya SMTP sending for the logos (Protonmail) account. The fix involved:
1. Moving `login` field from under `auth` to the backend level directly
2. Changing `encryption = "none"` to `encryption.type = "none"`
3. Changing `auth.password.keyring` to `auth.cmd` with a secret-tool lookup command

The documentation at `docs/himalaya.md` still shows the old, non-working configuration and needs to be updated to reflect the working configuration.

## Findings

### Current Documentation State

The `docs/himalaya.md` file at lines 214-233 shows the Protonmail Account configuration:

**Current (incorrect) configuration in docs**:
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

**Issues with current documentation**:
1. Line 230: `encryption = "none"` should be `encryption.type = "none"`
2. Line 232: `auth.password.keyring` is wrong - should be `auth.cmd` with secret-tool command

### Working Configuration

From `home.nix` lines 570-577, the working configuration is:

```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
```

### No "Not Working Yet" Sections Found

After reviewing the entire `docs/himalaya.md` file (597 lines), there are no explicit sections titled:
- "Not Working Yet"
- "Workaround"
- "Known Issues with SMTP"
- Any other section indicating SMTP doesn't work

The documentation simply showed the incorrect configuration syntax without indicating it was broken.

### Key Syntax Differences

| Aspect | Old (Broken) | New (Working) |
|--------|-------------|---------------|
| Encryption | `encryption = "none"` | `encryption.type = "none"` |
| Password auth | `auth.password.keyring = "..."` | `auth.cmd = "secret-tool lookup ..."` |

## Recommendations

### Changes Required

**Location**: `docs/himalaya.md` lines 226-232

**Replace this section**:
```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.password.keyring = "protonmail-bridge benjamin@logos-labs.ai"
```

**With**:
```toml
message.send.backend.type = "smtp"
message.send.backend.host = "127.0.0.1"
message.send.backend.port = 1025
message.send.backend.login = "benjamin@logos-labs.ai"
message.send.backend.encryption.type = "none"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
```

### Implementation Approach

This is a straightforward documentation update:
1. Read `docs/himalaya.md`
2. Edit the Protonmail SMTP configuration section (lines 226-232)
3. Replace incorrect syntax with working syntax
4. No other sections need to be removed since there were no "Not Working Yet" markers

## Decisions

1. **Scope is limited**: Only the configuration example needs updating - no prose sections about SMTP not working exist
2. **Use auth.cmd pattern**: This matches the mbsync configuration pattern and is verified working
3. **Keep encryption.type format**: The nested `.type` format is required for Himalaya v1.1.0

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Missing additional incorrect examples | Full file search performed - only one SMTP config example found for logos |
| Future configuration changes | Documentation now matches actual working home.nix configuration |

## Next Steps

1. Create implementation plan with single phase
2. Edit `docs/himalaya.md` to update lines 226-232
3. Verify documentation matches home.nix configuration

## Appendix

### Files Reviewed
- `/home/benjamin/.dotfiles/docs/himalaya.md` (597 lines)
- `/home/benjamin/.dotfiles/home.nix` (logos account section, lines 560-590)
- `/home/benjamin/.dotfiles/specs/21_fix_himalaya_smtp_logos_account/summaries/implementation-summary-20260209.md`
- `/home/benjamin/.dotfiles/specs/21_fix_himalaya_smtp_logos_account/reports/research-001.md`

### Search Queries
- Grep for "Not Working" in docs/himalaya.md - no results
- Grep for "Workaround" in docs/himalaya.md - no results
- Grep for "accounts.logos" to find configuration section
