# Implementation Summary: Task #45

**Completed**: 2026-03-24
**Duration**: ~20 minutes
**Status**: Implemented

## Overview

Added aerc terminal email client with notmuch backend to NixOS configuration, providing a vim-compatible email workflow that works alongside the existing himalaya setup.

## Changes Made

### 1. notmuch Email Indexer (home.nix)

Configured notmuch with:
- Primary email: benbrastmckie@gmail.com
- Secondary email: benjamin@logos-labs.ai
- Database path: ~/Mail
- Automatic tagging by folder and account (gmail/logos tags)
- Pre-new hook to run mbsync
- Post-new hook for tag management
- Sync flags with Maildir

### 2. aerc Email Client (home.nix)

Configured aerc with:
- notmuch backend for both Gmail and Logos accounts
- Vim-style keybindings (j/k navigation, d/a for delete/archive)
- HTML rendering via w3m
- Compose with nvim as editor
- Query maps for virtual folders per account
- Unified search across all mail

### 3. aerc Account Configuration (home.file)

Created:
- `~/.config/aerc/accounts.conf` - Account definitions with SMTP
- `~/.config/aerc/querymap-gmail` - Gmail virtual folders
- `~/.config/aerc/querymap-logos` - Logos virtual folders

### 4. Neovim Integration

Created `/home/benjamin/.config/nvim/lua/neotex/plugins/tools/mail.lua`:
- `<leader>me` - Open aerc in floating terminal
- `<leader>mS` - Sync mail (mbsync + notmuch)
- `<leader>mf` - Search mail with notmuch via Telescope

## Files Modified

| File | Change |
|------|--------|
| `home.nix` | Added programs.notmuch, programs.aerc, accounts.conf, querymaps |
| `lua/neotex/plugins/tools/mail.lua` | Created - Neovim mail integration |
| `lua/neotex/plugins/tools/init.lua` | Added mail module import |

## Verification

- nix flake check: Success
- home-manager build: Success
- Neovim module load: Success
- aerc 0.21.0 and notmuch 0.40 installed

## Usage

### Terminal
```bash
# Sync mail
mbsync -a && notmuch new

# Open aerc
aerc

# Search mail
notmuch search tag:inbox
notmuch search from:someone@example.com
```

### In aerc
- `j/k` - Navigate messages
- `Enter` - View message
- `d` - Delete (with confirmation)
- `a` - Archive
- `c` - Compose
- `r/R` - Reply / Reply-all
- `/` - Search
- `$` - Sync mail
- `Tab` - Switch accounts

### In Neovim
- `<leader>me` - Open aerc
- `<leader>mS` - Sync mail
- `<leader>mf` - Search mail

## Post-Implementation Steps

User needs to:
1. Run `home-manager switch --flake .#benjamin` to activate
2. Run `notmuch new` to create initial database
3. Verify mail accounts work with `aerc`

## Notes

- Configuration works alongside existing himalaya setup
- Uses existing mbsync XOAUTH2/password credentials
- Gmail uses app password via secret-tool
- Logos uses protonmail-bridge credentials
- HTML emails rendered via w3m (already installed)
