# Research Report: Terminal Email Clients for NixOS in 2026

- **Task**: 45 - Add Terminal Email Client to NixOS
- **Started**: 2026-03-24T12:00:00Z
- **Completed**: 2026-03-24T12:30:00Z
- **Effort**: ~30 minutes
- **Dependencies**: None
- **Sources/Inputs**: Web research, NixOS community documentation, GitHub repositories, Home Manager source
- **Artifacts**: This report
- **Standards**: report-format.md, artifact-formats.md

## Executive Summary

- **Himalaya** is the strongest recommendation for Neovim integration and AI agent extensibility through its JSON output, $EDITOR composing, and emerging MCP ecosystem
- **aerc** offers the best standalone terminal email experience with native vim-style keybindings and embedded terminal support
- **NeoMutt** remains the most mature option with the largest community but requires more configuration
- **notmuch.nvim** provides deep Neovim integration but requires notmuch as backend (more complex setup)
- All candidates have Home Manager module support (`programs.aerc`, `programs.neomutt`, `programs.himalaya`)
- Gmail MCP servers now enable Claude Code to manage email directly via the Model Context Protocol

## Context & Scope

The user requires a vim-compatible terminal email client for NixOS configuration, specifically evaluating:
1. Vim motion/keybinding support
2. Neovim integration capabilities
3. AI/plugin extensibility (Claude Code integration)
4. NixOS packaging support (Home Manager)
5. Active development status in 2026

The existing dotfiles already include email-adjacent tools: `vdirsyncer`, `khard`, `swaks`, `mailutils`, and `protonmail-bridge` (service).

## Findings

### 1. Himalaya

**Overview**: Rust-based CLI email client with modular backend support.

| Attribute | Details |
|-----------|---------|
| **Language** | Rust |
| **Vim Support** | Via $EDITOR (composes in Neovim) |
| **Backends** | IMAP, Maildir, Notmuch, SMTP, Sendmail |
| **NixOS Module** | `programs.himalaya.enable` (Home Manager) |
| **Development** | Active - NGI Zero Core funding through 2026, recent v1.x release |

**Neovim Integration Options**:
- [himalaya-vim](https://github.com/pimalaya/himalaya-vim) - Official Vim/Neovim frontend
- [himalaya.nvim](https://github.com/JostBrand/himalaya.nvim) - Pure Neovim Lua plugin
- [mountaineer.nvim](https://github.com/elmarsto/mountaineer.nvim) - Telescope extension for Himalaya

**AI/Plugin Extensibility**:
- JSON output mode (`--output json`) enables script integration
- Can be wrapped as MCP tool for Claude Code
- No native AI features, but composable with external tools

**Unique Features**:
- OAuth 2.0 support for Gmail/Outlook
- System keyring integration for secrets
- Proton Mail support via Proton Bridge
- 50% faster sync than mbsync, 370% faster than OfflineIMAP

### 2. aerc

**Overview**: Go-based terminal email client with tmux-style interface.

| Attribute | Details |
|-----------|---------|
| **Language** | Go |
| **Vim Support** | Native vim-style keybindings (j/k navigation, etc.) |
| **Backends** | IMAP, Maildir, Notmuch, Mbox, JMAP |
| **NixOS Module** | `programs.aerc.enable` (Home Manager) |
| **Development** | Active - maintained by Robin Jarry on sr.ht |

**Key Features**:
- Embedded terminal for composing (opens $EDITOR)
- Tabbed interface for multiple accounts
- ex-command system for automation
- Filters for syntax highlighting emails
- PGP signing/encryption
- JMAP support (modern protocol)

**Home Manager Configuration Note**:
Must set `programs.aerc.extraConfig.general.unsafe-accounts-conf = true` for credential handling.

**AI/Plugin Extensibility**:
- Unix philosophy: integrates with external scripts
- No plugin architecture per se, but filters and ex-commands enable automation
- [aerc-vim](https://github.com/rafo/aerc-vim) provides enhanced vim keybindings

### 3. NeoMutt

**Overview**: Fork of Mutt with modern features, most mature option.

| Attribute | Details |
|-----------|---------|
| **Language** | C |
| **Vim Support** | Configurable via muttrc (not native, but well-documented) |
| **Backends** | IMAP, Maildir, POP3 |
| **NixOS Module** | `programs.neomutt.enable` (Home Manager) |
| **Development** | Active - releases in Jan 2026, Dec 2025, Sep 2025, May 2025 |

**Key Features**:
- `vimKeys = true` option in Home Manager module
- Sidebar navigation (now upstream in Mutt)
- Notmuch integration for search
- Header caching for performance
- Massive configuration flexibility

**AI/Plugin Extensibility**:
- Macros and hooks for automation
- Can pipe messages to external scripts
- No native AI integration

**NeoMutt vs Mutt**:
NeoMutt is the recommended choice - same config compatibility but with active development and additional features.

### 4. notmuch + notmuch.nvim

**Overview**: Search-based email system with native Neovim frontend.

| Attribute | Details |
|-----------|---------|
| **Language** | C (notmuch), Lua (notmuch.nvim) |
| **Vim Support** | Native - runs entirely inside Neovim |
| **Backends** | Maildir (requires mbsync/offlineimap for IMAP) |
| **NixOS Module** | `programs.notmuch.enable` (Home Manager) |
| **Development** | Active - notmuch.nvim requires NeoVim 0.10+ |

**[notmuch.nvim](https://github.com/yousefakbar/notmuch.nvim) Features**:
- Asynchronous search through large mailboxes
- Thread viewing with folding
- Tag management (add/remove/toggle)
- Attachment handling
- HTML rendering via w3m
- Maildir sync via mbsync
- Exposes `vim.b.notmuch_thread` for statusline integration

**Complexity Note**: Requires notmuch + mbsync/offlineimap setup. More complex but most integrated with Neovim.

### 5. mutt (Original)

**Recommendation**: Use NeoMutt instead. Mutt has slower development and NeoMutt includes all upstream features plus enhancements.

### 6. AI Integration: Gmail MCP for Claude Code

**Overview**: Multiple Gmail MCP servers enable Claude Code to manage email directly.

**Available Implementations**:
- [Gmail-MCP-Server](https://github.com/GongRzhe/Gmail-MCP-Server) - OAuth 2.0 with auto-auth
- [Composio Gmail MCP](https://composio.dev/toolkits/gmail/framework/claude-code) - Managed integration
- Custom CLI approach per [raf.dev/blog/gmail-cli](https://raf.dev/blog/gmail-cli)

**Capabilities**:
- Search, read, send, archive, label emails
- Batch operations (1000 messages per API call)
- Natural language email management
- 19 tools for emails, drafts, labels, threads, attachments

**Key Insight**: "A CLI beats browser automation" - wrapping Gmail API in a CLI gives Claude Code faster, structured access than DOM scraping.

## Comparison Matrix

| Feature | Himalaya | aerc | NeoMutt | notmuch.nvim |
|---------|----------|------|---------|--------------|
| **Vim Keybindings** | Via $EDITOR | Native | Configurable | Native (in NeoVim) |
| **Neovim Integration** | 3 plugins available | None | None | Full (is NeoVim plugin) |
| **AI Extensibility** | JSON output, scriptable | Filters, ex-commands | Macros, pipes | Lua API |
| **Home Manager Module** | Yes | Yes | Yes | Yes (notmuch) |
| **JMAP Support** | No | Yes | No | No |
| **OAuth 2.0** | Yes | Via external | Via external | Via mbsync |
| **Learning Curve** | Low | Medium | High | High |
| **2026 Development** | Active (funded) | Active | Active | Active |

## Recommendations

### Primary Recommendation: Himalaya

**Rationale**:
1. Best Neovim integration with three plugin options
2. JSON output enables Claude Code/MCP integration
3. Simplest setup with OAuth 2.0 support
4. NGI Zero funding ensures continued development
5. Proton Mail compatible (user has protonmail-bridge configured)

**Configuration Approach**:
```nix
# home.nix
programs.himalaya = {
  enable = true;
  # See himalaya config.sample.toml for options
};
```

Install `himalaya.nvim` or `mountaineer.nvim` via lazy.nvim for Neovim integration.

### Secondary Recommendation: aerc

**Rationale**:
1. Best standalone terminal email experience
2. Native vim keybindings without configuration
3. JMAP support for modern email providers
4. Embedded terminal workflow matches user's tmux/wezterm setup

**Use Case**: If Neovim integration is less important than a polished terminal UI.

### For Maximum Neovim Integration: notmuch + notmuch.nvim

**Rationale**:
1. Runs entirely inside Neovim
2. Exposes Lua API for custom automation
3. Full vim motions for everything

**Use Case**: If willing to accept more complex setup (mbsync + notmuch + plugin).

### Claude Code Email Integration

**Parallel Recommendation**: Configure a Gmail MCP server alongside the terminal client.

This enables:
- Claude Code to triage/summarize/draft emails
- Terminal client for reading/composing
- Hybrid workflow with AI assistance

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Himalaya v1 recently released, potential bugs | Pin to specific version, monitor releases |
| OAuth 2.0 token refresh complexity | Use passwordCommand with keyring |
| Proton Bridge latency | Use Maildir caching |
| notmuch setup complexity | Start with Himalaya, migrate later if needed |

## Decisions

1. **Primary client**: Himalaya (best balance of features, Neovim integration, and simplicity)
2. **Neovim plugin**: himalaya.nvim or mountaineer.nvim (depends on Telescope usage)
3. **AI integration**: Consider Gmail MCP server for Claude Code workflows
4. **NixOS approach**: Use Home Manager `programs.himalaya` module

## Appendix

### Search Queries Used
- "best terminal email client 2026 vim keybindings neomutt aerc himalaya comparison"
- "terminal email client AI plugin integration Claude LLM 2026"
- "himalaya email CLI neovim integration 2026"
- "aerc email client NixOS home-manager programs.aerc configuration 2026"
- "neomutt NixOS home-manager programs.neomutt configuration 2026"
- "Gmail MCP server Claude Code email integration terminal 2026"

### References

**Himalaya**:
- [GitHub - pimalaya/himalaya](https://github.com/pimalaya/himalaya)
- [himalaya-vim](https://github.com/pimalaya/himalaya-vim)
- [himalaya.nvim](https://github.com/JostBrand/himalaya.nvim)
- [mountaineer.nvim](https://github.com/elmarsto/mountaineer.nvim)
- [NLnet Himalaya funding](https://nlnet.nl/project/Himalaya/)

**aerc**:
- [aerc-mail.org](https://aerc-mail.org/)
- [git.sr.ht/~rjarry/aerc](https://git.sr.ht/~rjarry/aerc)
- [Home Manager aerc module](https://github.com/nix-community/home-manager/blob/master/modules/programs/aerc.nix)
- [aerc-vim keybindings](https://github.com/rafo/aerc-vim)

**NeoMutt**:
- [neomutt.org](https://neomutt.org/)
- [GitHub - neomutt/neomutt](https://github.com/neomutt/neomutt)
- [NeoMutt for NixOS](https://neomutt.org/distro/nixos)
- [Home Manager neomutt module](https://github.com/nix-community/home-manager/tree/master/modules/programs/neomutt)

**notmuch**:
- [notmuchmail.org](https://notmuchmail.org/)
- [notmuch.nvim](https://github.com/yousefakbar/notmuch.nvim)

**Gmail MCP / Claude Code**:
- [Gmail MCP Integration with Claude Code](https://composio.dev/toolkits/gmail/framework/claude-code)
- [Build a Gmail CLI for Claude Code](https://raf.dev/blog/gmail-cli/)
- [Gmail-MCP-Server](https://github.com/GongRzhe/Gmail-MCP-Server)

**Home Manager Documentation**:
- [Home Manager Configuration Options](https://nix-community.github.io/home-manager/options.xhtml)
- [MyNixOS programs.himalaya](https://mynixos.com/home-manager/option/programs.himalaya.enable)
- [MyNixOS programs.aerc](https://mynixos.com/home-manager/options/programs.aerc)
