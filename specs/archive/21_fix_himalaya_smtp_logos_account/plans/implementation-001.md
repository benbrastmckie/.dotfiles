# Implementation Plan: Task #21

**Task**: Fix Himalaya SMTP sending for logos account
**Version**: 001
**Created**: 2026-02-09
**Language**: neovim

## Overview

Add correct SMTP backend configuration to the logos account in home.nix. The research identified that the previous configuration had incorrect field paths (`auth.login` instead of `login`, `auth.password.keyring` instead of `auth.cmd`).

## Phases

### Phase 1: Add SMTP Backend Configuration [COMPLETED]

**Estimated effort**: 15 minutes
**Status**: [COMPLETED]

**Objectives**:
1. Add SMTP backend configuration to logos account section in home.nix

**Files to modify**:
- `home.nix` - Add SMTP send backend lines after `backend.maildirpp = true`

**Steps**:
1. Locate the logos account section (around line 559-579)
2. Add SMTP backend configuration after `backend.maildirpp = true`:
   ```toml
   message.send.backend.type = "smtp"
   message.send.backend.host = "127.0.0.1"
   message.send.backend.port = 1025
   message.send.backend.login = "benjamin@logos-labs.ai"
   message.send.backend.encryption.type = "none"
   message.send.backend.auth.type = "password"
   message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
   ```

**Verification**:
- File saves without syntax errors
- Configuration uses `auth.cmd` (not `auth.keyring`)
- `login` is at backend level (not under auth)

---

### Phase 2: Rebuild and Verify [COMPLETED]

**Estimated effort**: 10 minutes
**Status**: [COMPLETED]

**Objectives**:
1. Rebuild home-manager configuration
2. Verify Himalaya can parse the config
3. Verify SMTP backend is listed

**Files to modify**: None (verification only)

**Steps**:
1. Run `home-manager switch --flake .#benjamin`
2. Run `himalaya account list` to verify logos shows "Maildir, SMTP"
3. Optionally test sending: `echo "Test" | himalaya -a logos message send --dry-run`

**Verification**:
- `home-manager switch` completes without errors
- `himalaya account list` shows logos with SMTP backend
- No TOML parsing errors

---

## Dependencies

- Protonmail Bridge must be running for send tests (localhost:1025)
- Bridge password must be stored in keyring (already done)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Bridge not running during test | Low | Verify ports with `ss -tlnp \| grep 1025` |
| Keyring password missing | Low | Already verified in research phase |

## Success Criteria

- [ ] home.nix contains correct SMTP configuration for logos account
- [ ] `himalaya account list` shows logos with Maildir and SMTP backends
- [ ] No TOML parsing errors when running Himalaya commands
