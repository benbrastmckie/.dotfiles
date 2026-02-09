# Implementation Plan: Task #22

- **Task**: 22 - Update Himalaya documentation for SMTP fix
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 21 (Fix Himalaya SMTP sending for logos account) - completed
- **Research Inputs**: specs/22_update_himalaya_documentation_smtp_fix/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Update the Himalaya documentation to reflect the working SMTP configuration for the Protonmail logos account. Task 21 fixed the SMTP sending by correcting the auth.cmd syntax and encryption.type format. The documentation at docs/himalaya.md currently shows the old, non-working configuration syntax at lines 226-232 and needs to be updated to match the working configuration in home.nix.

### Research Integration

The research report identified the exact changes needed:
- Line 230: Change `encryption = "none"` to `encryption.type = "none"`
- Line 232: Change `auth.password.keyring = "protonmail-bridge benjamin@logos-labs.ai"` to `auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"`

No "Not Working Yet" or "Workaround" sections were found in the documentation.

## Goals & Non-Goals

**Goals**:
- Update the Protonmail SMTP configuration example to show working syntax
- Ensure documentation matches the actual working configuration in home.nix
- Maintain consistency between documentation and implementation

**Non-Goals**:
- Changing any other sections of the Himalaya documentation
- Modifying the actual Himalaya configuration in home.nix
- Adding new documentation sections

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Documentation diverges from home.nix again | Low | Low | Configuration example now matches verified working syntax |
| Other incorrect examples exist | Low | Low | Research confirmed only one SMTP config example for logos account |

## Implementation Phases

### Phase 1: Update Protonmail SMTP Configuration Example [COMPLETED]

**Goal**: Replace the incorrect SMTP configuration syntax with the working configuration from home.nix.

**Tasks**:
- [ ] Edit docs/himalaya.md lines 226-232
- [ ] Replace `message.send.backend.encryption = "none"` with `message.send.backend.encryption.type = "none"`
- [ ] Replace `message.send.backend.auth.password.keyring = "protonmail-bridge benjamin@logos-labs.ai"` with `message.send.backend.auth.cmd = "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"`

**Timing**: 15 minutes

**Files to modify**:
- `docs/himalaya.md` - Update Protonmail SMTP configuration section (lines 226-232)

**Verification**:
- The SMTP configuration example matches the working syntax from home.nix
- Both encryption.type and auth.cmd fields are correctly formatted

---

### Phase 2: Verify Documentation Accuracy [COMPLETED]

**Goal**: Confirm the documentation accurately reflects the working configuration.

**Tasks**:
- [ ] Compare updated docs/himalaya.md with home.nix SMTP configuration
- [ ] Verify encryption.type format is correct
- [ ] Verify auth.cmd secret-tool command matches exactly

**Timing**: 15 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- Documentation SMTP configuration exactly matches home.nix lines 570-577
- No discrepancies between documented and actual configuration

## Testing & Validation

- [ ] Documentation SMTP example has `encryption.type = "none"` (not `encryption = "none"`)
- [ ] Documentation SMTP example uses `auth.cmd` with secret-tool lookup command
- [ ] Configuration syntax matches the verified working configuration from home.nix

## Artifacts & Outputs

- `docs/himalaya.md` - Updated documentation with correct SMTP configuration
- `specs/22_update_himalaya_documentation_smtp_fix/summaries/implementation-summary-YYYYMMDD.md` - Implementation summary

## Rollback/Contingency

If the documentation update introduces issues:
1. Revert docs/himalaya.md to previous version using git checkout
2. The actual Himalaya configuration in home.nix is unaffected as this is documentation-only
