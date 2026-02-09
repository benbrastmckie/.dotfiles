# Implementation Plan: Task #20

- **Task**: 20 - Update Himalaya Setup from Manual Guide
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Protonmail Bridge installation and login (manual step)
- **Research Inputs**: specs/20_update_himalaya_setup/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

This task implements dual-account email support (Gmail + Protonmail) in the NixOS dotfiles by updating home.nix based on the manual setup guide. The existing Gmail-only configuration in himalaya config.toml, mbsyncrc, and the mail directory activation script will be extended to include the Logos Labs Protonmail account accessed via Protonmail Bridge.

### Research Integration

Research report research-001.md identified:
- Protonmail Bridge is not installed (must be added to home.packages)
- himalaya config.toml only has gmail account (must add logos account)
- mbsyncrc only has gmail channels (must add logos channels)
- Mail/Logos directory does not exist (must add to activation script)
- Bridge uses local ports 1143/1025 with SSLType None and LOGIN auth

## Goals & Non-Goals

**Goals**:
- Add protonmail-bridge to home.packages in home.nix
- Add logos account configuration to himalaya config.toml section in home.nix
- Add logos channels and group to mbsyncrc section in home.nix
- Add Logos maildir creation to the activation script

**Non-Goals**:
- Interactive Protonmail Bridge login (manual step)
- Storing bridge password in keyring (manual step)
- Neovim plugin configuration (handled in separate nvim config repo)
- Systemd service for auto-starting Bridge (optional future enhancement)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| home-manager switch fails after changes | H | L | All changes are additive; Gmail config unchanged |
| Protonmail folder names differ from expected | M | M | Using standard IMAP names (INBOX, Sent, Drafts, Trash) |
| Bridge not running when testing | M | M | Document prerequisite in implementation summary |
| Keyring password not set before mbsync test | M | H | Note manual steps must be completed before testing |

## Implementation Phases

### Phase 1: Add Protonmail Bridge Package [COMPLETED]

**Goal**: Install protonmail-bridge via home.packages

**Tasks**:
- [ ] Add `protonmail-bridge` to home.packages in home.nix (around line 146-189)

**Timing**: 10 minutes

**Files to modify**:
- `home.nix` - Add package to home.packages list

**Verification**:
- Run `nix eval .#homeConfigurations.benjamin.config.home.packages --apply 'pkgs: builtins.any (p: p.pname or "" == "protonmail-bridge") pkgs'` or verify visually in file

---

### Phase 2: Add Logos Account to Himalaya Config [COMPLETED]

**Goal**: Configure himalaya CLI with the logos (Protonmail) account

**Tasks**:
- [ ] Add `[accounts.logos]` section after the `[accounts.gmail]` section in the himalaya config.toml text block (lines 509-551)
- [ ] Configure maildir backend pointing to ~/Mail/Logos
- [ ] Configure SMTP via Protonmail Bridge (127.0.0.1:1025, no encryption, password auth from keyring)

**Timing**: 20 minutes

**Files to modify**:
- `home.nix` - Extend ".config/himalaya/config.toml".text block

**Verification**:
- Verify config syntax by reviewing the text block
- After home-manager switch: `grep -A 10 "\[accounts.logos\]" ~/.config/himalaya/config.toml`

---

### Phase 3: Add Logos Channels to mbsync Config [COMPLETED]

**Goal**: Configure mbsync to sync Protonmail via Bridge

**Tasks**:
- [ ] Add logos IMAPAccount section (127.0.0.1:1143, LOGIN auth, SSLType None)
- [ ] Add logos-remote IMAPStore
- [ ] Add logos-local MaildirStore with Maildir++ format
- [ ] Add channels: logos-inbox, logos-sent, logos-drafts, logos-trash, logos-archive
- [ ] Add logos group containing all channels

**Timing**: 30 minutes

**Files to modify**:
- `home.nix` - Extend ".mbsyncrc".text block (lines 555-645)

**Verification**:
- Verify config syntax by reviewing the text block
- After home-manager switch: `grep -A 5 "IMAPAccount logos" ~/.mbsyncrc`

---

### Phase 4: Add Logos Maildir to Activation Script [COMPLETED]

**Goal**: Ensure Mail/Logos directory structure is created on activation

**Tasks**:
- [ ] Add mkdir commands for ~/Mail/Logos and subdirectories (INBOX, Sent, Drafts, Trash, Archive) to home.activation.createMailDir

**Timing**: 10 minutes

**Files to modify**:
- `home.nix` - Extend home.activation.createMailDir block (lines 416-426)

**Verification**:
- After home-manager switch: `ls -la ~/Mail/Logos/`

---

### Phase 5: Build and Verify Configuration [COMPLETED]

**Goal**: Ensure configuration builds successfully and produces correct output files

**Tasks**:
- [ ] Run `nix flake check` to verify syntax
- [ ] Run `home-manager build --flake .#benjamin` to verify configuration builds
- [ ] Run `home-manager switch --flake .#benjamin` to apply configuration
- [ ] Verify ~/.config/himalaya/config.toml contains logos account
- [ ] Verify ~/.mbsyncrc contains logos channels
- [ ] Verify ~/Mail/Logos directory structure exists

**Timing**: 20 minutes

**Files to modify**: None (verification only)

**Verification**:
- All commands complete without errors
- Configuration files contain expected content
- Directory structure exists

---

## Testing & Validation

- [ ] `nix flake check` passes
- [ ] `home-manager build --flake .#benjamin` succeeds
- [ ] `home-manager switch --flake .#benjamin` applies without errors
- [ ] `grep -A 10 "\[accounts.logos\]" ~/.config/himalaya/config.toml` shows logos configuration
- [ ] `grep -A 5 "IMAPAccount logos" ~/.mbsyncrc` shows mbsync configuration
- [ ] `ls ~/Mail/Logos/` shows INBOX, Sent, Drafts, Trash, Archive directories
- [ ] `himalaya account list` shows both gmail and logos accounts (requires manual Bridge setup first)

## Artifacts & Outputs

- `home.nix` - Updated with protonmail-bridge package, logos himalaya account, logos mbsync channels, and Logos maildir activation
- `plans/implementation-001.md` - This plan file
- `summaries/implementation-summary-YYYYMMDD.md` - Created upon completion

## Rollback/Contingency

If the configuration fails to build or causes issues:
1. Revert home.nix to previous state: `git checkout home.nix`
2. Rebuild: `home-manager switch --flake .#benjamin`
3. All changes are additive (Gmail config unchanged), so partial rollback is possible by removing only the logos-related additions

## Manual Steps Required (Post-Implementation)

After the Nix configuration is applied, the user must complete these manual steps:

1. **Start Protonmail Bridge**: `protonmail-bridge`
2. **Login to Protonmail**: Enter credentials in Bridge GUI
3. **Store Bridge password in keyring**:
   ```bash
   secret-tool store --label="Protonmail Bridge - Logos Labs" \
     service protonmail-bridge \
     username benjamin@logos-labs.ai
   ```
4. **Test mbsync**: `mbsync logos-inbox` (requires Bridge running)
5. **Test Himalaya**: `himalaya list -a logos`

These steps are documented in `/home/benjamin/.config/nvim/docs/himalaya-manual-setup-guide.md`.
