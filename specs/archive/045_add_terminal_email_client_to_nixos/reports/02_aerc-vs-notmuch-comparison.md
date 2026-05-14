# Research Report: aerc vs notmuch Deep Comparison

- **Task**: 45 - Add Terminal Email Client to NixOS
- **Started**: 2026-03-24T12:00:00Z
- **Completed**: 2026-03-24T13:30:00Z
- **Effort**: ~90 minutes (follow-up research)
- **Dependencies**: Prior research report (01_terminal-email-clients.md)
- **Sources/Inputs**: GitHub/SourceHut repositories, official documentation, Arch Wiki, Home Manager source, community configurations
- **Artifacts**: This report
- **Standards**: report-format.md, artifact-formats.md

## Executive Summary

- **aerc** is a standalone terminal email client (v0.21.0, March 2026) with native vim-style keybindings, direct IMAP/JMAP support, and active development (2,921 commits, 237 GitHub stars)
- **notmuch** is an email indexing/search library (v0.40, January 2026) using tag-based organization rather than folders, with 7,680 commits and 196 GitHub stars
- **Key distinction**: aerc is a complete MUA (Mail User Agent) while notmuch is a search backend that requires a frontend (Emacs, alot, aerc, neomutt)
- **Hybrid approach**: aerc can use notmuch as a backend, combining aerc's UI with notmuch's powerful tagging/search
- **For your setup**: Given existing mbsync/protonmail-bridge configuration, aerc-with-notmuch provides best balance of usability and power

## Context & Scope

This follow-up research focuses specifically on aerc and notmuch per user request, analyzing:
1. Development activity and maintenance status
2. Workflow differences (folder-based vs tag-based)
3. Feature comparison (HTML, attachments, encryption, etc.)
4. NixOS/Home Manager integration completeness

The user's existing configuration includes:
- mbsync with XOAUTH2 for Gmail
- ProtonMail Bridge for Proton account
- msmtp for sending
- w3m for HTML rendering
- pass/gnupg for credentials

## Findings

### 1. Development Activity Comparison

#### aerc

| Metric | Value |
|--------|-------|
| **Primary Repository** | git.sr.ht/~rjarry/aerc |
| **GitHub Mirror Stars** | 237 |
| **GitHub Mirror Forks** | 10 |
| **Total Commits** | 2,921 |
| **Language** | Go |
| **Current Version** | 0.21.0 |
| **Maintainer** | Robin Jarry (since 2021, employed by Red Hat) |
| **Original Creator** | Drew DeVault (2019) |

**Recent Release History**:
| Version | Date | Key Features |
|---------|------|--------------|
| 0.21.0 | March 2026 | Latest stable |
| 0.20.1 | Feb 2025 | Bug fixes, CVE-2025-49466 patch |
| 0.20.0 | Jan 2025 | Multi-folder copy-to, skip-editor flags |
| 0.19.0 | Jan 2025 | Forwarded flag support, notmuch search |

**Development Velocity**: ~4 releases per year, consistent commits with 3-hour-old activity as of research date

**Community Engagement**:
- FOSDEM 2024 and 2025 talks by maintainer
- Active mailing lists: aerc-devel (patches), aerc-discuss (users)
- IRC: #aerc on libera.chat

#### notmuch

| Metric | Value |
|--------|-------|
| **Primary Repository** | git.notmuchmail.org/git/notmuch |
| **GitHub Mirror Stars** | 196 |
| **GitHub Mirror Forks** | 52 |
| **Total Commits** | 7,680 |
| **Language** | C (library), various (bindings) |
| **Current Version** | 0.40 |
| **Core Maintainers** | David Bremner, multiple contributors |
| **Original Creator** | Carl Worth (2009) |

**Recent Release History**:
| Version | Date | Key Features |
|---------|------|--------------|
| 0.40 | Jan 2026 | Latest stable |
| 0.39 | Mar 2025 | Emacs 29 compatibility |
| 0.38.3 | 2024 | Bug fixes, performance improvements |
| 0.38 | 2024 | New search/edit commands |

**Development Velocity**: ~2-3 releases per year, mature and stable codebase

**Community Engagement**:
- Active mailing list: notmuch@notmuchmail.org
- OpenHub project page with activity metrics
- Long-standing project (since 2009)

### 2. Workflow Comparison

#### aerc Workflow (Folder-Based or Hybrid)

```
[IMAP Server] --(sync)--> [aerc]
                              |
                         Message List View
                              |
                         Tab per Account
                              |
                         Compose in $EDITOR
```

**Direct IMAP Mode**:
1. Configure account in `accounts.conf` with IMAP source
2. aerc connects directly to IMAP server
3. Browsing folders, reading, composing all within aerc
4. Changes sync immediately to server

**Maildir/Notmuch Mode**:
1. External tool (mbsync) syncs mail to local Maildir
2. notmuch indexes the Maildir
3. aerc uses `notmuch://` source to query
4. Tag-based virtual folders via notmuch queries

#### notmuch Workflow (Tag-Based)

```
[IMAP Server] --(mbsync)--> [Maildir] --(notmuch new)--> [notmuch DB]
                                                              |
                                                    [Frontend: Emacs/alot/aerc]
```

1. **Fetch**: `mbsync -a` pulls messages to local Maildir
2. **Index**: `notmuch new` scans Maildir, adds to Xapian database
3. **Tag**: Initial tagging via hooks or afew
4. **Read**: Frontend queries notmuch database
5. **Archive**: Remove `inbox` tag (message stays in place)
6. **Search**: Full-text search across all accounts

**Key Paradigm Difference**:
- **Folders**: Message lives in one location (traditional)
- **Tags**: Message can have multiple labels (Gmail-like)

### 3. Feature Comparison

| Feature | aerc | notmuch |
|---------|------|---------|
| **Email Fetching** | Built-in IMAP/JMAP | No (requires mbsync/offlineimap) |
| **Email Sending** | Built-in SMTP | No (requires msmtp/sendmail) |
| **Search** | Basic + notmuch syntax | Powerful Xapian-based full-text |
| **Organization** | Folders or tags (via notmuch) | Tags only |
| **Threading** | Yes (client-side and server) | Yes (native) |
| **Multiple Accounts** | Native tab interface | Single database (queries by path) |
| **Vim Keybindings** | Native | Via frontend (emacs evil-mode, etc.) |
| **HTML Rendering** | w3m/lynx filters, sixel support | Via frontend |
| **Attachment Handling** | Open in $PAGER, save, pipe | Via frontend |
| **GPG/PGP** | Built-in signing/encryption | Index encrypted content |
| **Calendar/Contacts** | CardDAV address completion | Limited (frontend-dependent) |
| **Offline Mode** | Maildir backend | Native (works on local files) |

### 4. Search Capabilities

#### aerc Search

In direct IMAP mode, aerc uses server-side search. With notmuch backend, full notmuch syntax available:

```
:filter tag:inbox                    # By tag
:filter from:alice                   # By sender
:filter date:today..                 # By date
:filter subject:"urgent"             # By subject
:query tag:work and not tag:read     # Complex query (creates virtual folder)
```

#### notmuch Search

Notmuch provides sophisticated search syntax powered by Xapian:

```bash
notmuch search tag:inbox               # Tag search
notmuch search from:alice@example.com  # Sender
notmuch search date:yesterday..today   # Date range
notmuch search subject:meeting         # Subject
notmuch search "full text phrase"      # Body search
notmuch search tag:inbox and not tag:spam and from:boss  # Boolean
notmuch search thread:{tag:important}  # Entire threads
```

**Search Prefixes**:
- `from:`, `to:`, `subject:`, `body:` - Content fields
- `tag:` - Tag filter
- `folder:`, `path:` - Location
- `date:` - Temporal (supports natural language: "yesterday", "last week")
- `id:`, `thread:` - Message/thread ID

### 5. HTML Rendering

#### aerc HTML

aerc uses filters to process MIME types. Default HTML handling:

```ini
# ~/.config/aerc/aerc.conf
[filters]
text/html = w3m -T text/html -o display_link_number=1

# With sixel image support (terminal must support)
text/html = html-unsafe -sixel
```

**Capabilities**:
- Interactive w3m browser embedded in terminal
- Sixel image rendering (if terminal supports)
- Kitty terminal graphics protocol support
- Links displayed as numbered references

#### notmuch HTML

HTML rendering depends entirely on the frontend:
- **notmuch-emacs**: Uses Emacs' built-in shr.el or eww
- **alot**: Uses w3m or html2text
- **neomutt with notmuch**: Uses mailcap configuration
- **notmuch.nvim**: Uses w3m for rendering

### 6. Encryption Support

#### aerc GPG

```ini
# ~/.config/aerc/aerc.conf
[compose]
sign-key = YOUR_KEY_ID
sign-by-default = true

# Per account in accounts.conf
pgp-key-id = YOUR_KEY_ID
pgp-auto-sign = true
pgp-self-encrypt = true
```

**Features**:
- Sign outgoing messages
- Encrypt to recipients
- Verify and decrypt incoming
- Auto-encrypt when recipient key available

#### notmuch GPG

Notmuch can index decrypted content for searching:

```bash
# Enable indexing of encrypted content
notmuch config set index.decrypt true
```

**Features**:
- Index cleartext of encrypted messages (when gpg-agent has key)
- Store decryption status as property (`index.decryption=success`)
- Search within encrypted message content
- Actual encryption/signing handled by frontend

### 7. NixOS/Home Manager Setup

#### aerc Home Manager Module

**Available Options** (7 total):

```nix
programs.aerc = {
  enable = true;

  # Main configuration (aerc.conf)
  extraConfig = {
    general = {
      unsafe-accounts-conf = true;  # Required for passwordCommand
    };
    ui = {
      index-columns = "date<20,name<20,flags>4,subject<*";
    };
    filters = {
      "text/plain" = "colorize";
      "text/html" = "w3m -T text/html -o display_link_number=1";
    };
  };

  # Keybindings (binds.conf)
  extraBinds = {
    messages = {
      q = ":quit<Enter>";
      j = ":next<Enter>";
      k = ":prev<Enter>";
    };
  };

  # Custom themes
  stylesets = {
    "custom" = ''
      *.default = true
      title.bg = blue
    '';
  };

  # Message templates
  templates = {
    "new_message" = ''
      X-Mailer: aerc
    '';
  };
};

# Account configuration via accounts.email
accounts.email.accounts.gmail = {
  primary = true;
  address = "user@gmail.com";
  realName = "User Name";
  aerc = {
    enable = true;
    extraConfig = {
      ui = {
        sidebar-width = 20;
      };
    };
  };
};
```

**Required Companion Tools**: None (built-in IMAP/SMTP)

**Optional Companions**:
- mbsync (for offline Maildir)
- notmuch (for tag-based workflow)
- pass/gpg (for credential storage)
- w3m (for HTML rendering)

#### notmuch Home Manager Module

**Available Options**:

```nix
programs.notmuch = {
  enable = true;

  # Hook to sync before indexing
  hooks = {
    preNew = "mbsync -a";
    postNew = ''
      notmuch tag +inbox -unread -- tag:unread and from:me@example.com
    '';
  };

  # Initial tag configuration
  new = {
    tags = [ "inbox" "unread" ];
    ignore = [ ".mbsyncstate" ".strstrings" ];
  };

  # Search configuration
  search = {
    excludeTags = [ "deleted" "spam" ];
  };

  # Maildir configuration
  maildir = {
    synchronizeFlags = true;
  };
};

# mbsync for mail fetching
programs.mbsync = {
  enable = true;
};

# msmtp for sending
programs.msmtp = {
  enable = true;
};

# Account configuration
accounts.email.accounts.gmail = {
  primary = true;
  address = "user@gmail.com";
  notmuch = {
    enable = true;
    mailboxes = {
      inbox = "tag:inbox";
      sent = "folder:Sent";
    };
  };
  mbsync = {
    enable = true;
    create = "maildir";
  };
  msmtp.enable = true;
};
```

**Required Companion Tools**:
- mbsync or offlineimap (mail fetching)
- msmtp or sendmail (mail sending)
- Frontend (Emacs, alot, aerc, neomutt)

**Optional Companions**:
- afew (automatic tagging)
- lieer (Gmail API instead of IMAP)
- pass/gpg (credentials)

### 8. Configuration Complexity Comparison

| Aspect | aerc | notmuch |
|--------|------|---------|
| **Minimum Config** | accounts.conf + aerc.conf | notmuch config + mbsync + msmtp + frontend |
| **Files to Manage** | 3 (accounts, config, binds) | 5+ (notmuch, mbsync, msmtp, frontend, hooks) |
| **Time to Working Setup** | ~15 minutes | ~45-60 minutes |
| **Home Manager Coverage** | Good (7 options + accounts.email) | Good (notmuch + mbsync + msmtp modules) |
| **Learning Curve** | Moderate (familiar TUI) | Steep (paradigm shift to tags) |

### 9. Hybrid Setup: aerc + notmuch

The optimal setup for power users combines both:

```nix
# home.nix
programs.aerc = {
  enable = true;
  extraConfig = {
    general.unsafe-accounts-conf = true;
    ui.index-columns = "date<20,name<20,flags>4,subject<*";
    filters = {
      "text/plain" = "colorize";
      "text/html" = "w3m -T text/html -o display_link_number=1";
    };
  };
};

programs.notmuch = {
  enable = true;
  hooks.preNew = "mbsync -a";
  new.tags = [ "inbox" "unread" ];
};

programs.mbsync.enable = true;
programs.msmtp.enable = true;

accounts.email.accounts.gmail = {
  primary = true;
  address = "user@gmail.com";
  realName = "User";

  # Use notmuch as aerc backend
  aerc = {
    enable = true;
    extraConfig = {
      source = "notmuch://~/Mail";
      query-map = "~/.config/aerc/querymap";
    };
  };

  notmuch.enable = true;
  mbsync = {
    enable = true;
    create = "maildir";
  };
  msmtp.enable = true;
};
```

**Benefits of Hybrid**:
- aerc's polished TUI interface
- notmuch's powerful search and tagging
- Offline-first with full local Maildir
- Works with your existing mbsync configuration

## Recommendations

### For Your Setup (Existing mbsync + ProtonMail Bridge)

**Primary Recommendation**: aerc with notmuch backend

**Rationale**:
1. You already have mbsync configured with XOAUTH2
2. You have w3m installed for HTML rendering
3. aerc provides polished vim-style interface
4. notmuch adds powerful search/tagging on top
5. Minimal additional configuration needed

**Implementation Steps**:
1. Add `programs.aerc.enable = true` with extraConfig
2. Add `programs.notmuch.enable = true` with hooks
3. Configure aerc to use `notmuch://` source
4. Keep existing mbsync/msmtp configuration

### Alternative: Pure aerc (Simpler)

If you prefer fewer moving parts:
1. Configure aerc with direct IMAP source
2. Skip notmuch entirely
3. Loses powerful tagging but simpler setup

### Alternative: notmuch + Emacs (Most Powerful)

If you use Emacs:
1. notmuch-emacs is the most mature frontend
2. Deep integration with org-mode, mu4e alternative
3. Best search experience

## Decisions Made

1. **Workflow Model**: Hybrid (aerc UI + notmuch backend) recommended over pure folder or pure tag approach
2. **HTML Handling**: Use existing w3m with aerc filters
3. **Multiple Accounts**: Unified notmuch database, per-account queries
4. **Encryption**: aerc handles GPG for compose, notmuch indexes decrypted content

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Learning curve for tagging paradigm | Start with simple inbox/archive workflow, expand tags gradually |
| Complex multi-component setup | Use Home Manager declarative config for reproducibility |
| notmuch database corruption | Regular backups of ~/Mail/.notmuch |
| OAuth token refresh issues | Already solved with existing cyrus-sasl-xoauth2 setup |

## Appendix

### Search Queries Used
- "aerc email client GitHub repository 2026 development activity"
- "notmuch email GitHub repository 2026 development releases"
- "aerc vs notmuch email client comparison workflow features"
- "aerc email NixOS Home Manager configuration"
- "notmuch email NixOS Home Manager configuration mbsync"
- "aerc 0.21 release notes changelog"
- "notmuch 0.39 0.40 release date"

### References

**aerc**:
- [Official Site](https://aerc-mail.org/)
- [SourceHut Repository](https://git.sr.ht/~rjarry/aerc)
- [GitHub Mirror](https://github.com/rjarry/aerc)
- [Arch Wiki - aerc](https://wiki.archlinux.org/title/Aerc)
- [FOSDEM 2025 Talk](https://aerc-mail.org/fosdem-2025/)
- [Home Manager Module](https://github.com/nix-community/home-manager/blob/master/modules/programs/aerc.nix)
- [MyNixOS aerc Options](https://mynixos.com/home-manager/options/programs.aerc)
- [aerc-vim Keybindings](https://github.com/rafo/aerc-vim)
- [aerc-notmuch Integration](https://man.sr.ht/~rjarry/aerc/integrations/notmuch.md)

**notmuch**:
- [Official Site](https://notmuchmail.org/)
- [GitHub Mirror](https://github.com/notmuch/notmuch)
- [Arch Wiki - Notmuch](https://wiki.archlinux.org/title/Notmuch)
- [Search Syntax](https://notmuchmail.org/doc/latest/man7/notmuch-search-terms.html)
- [Home Manager Module](https://github.com/nix-community/home-manager/tree/master/modules/programs/notmuch)
- [Release News](https://notmuchmail.org/news/)
- [Emacs Tips](https://notmuchmail.org/emacstips/)
- [afew Automatic Tagging](https://github.com/afewmail/afew)

**Community Configurations**:
- [beb.ninja Email Setup](https://beb.ninja/post/email/)
- [sbr.pm Email Setup](https://sbr.pm/configurations/mails.html)
- [Email Complete Guide](https://bence.ferdinandy.com/2023/07/20/email-in-the-terminal-a-complete-guide-to-the-unix-way-of-email/)
- [wilw.dev aerc Daily Use](https://wilw.dev/blog/2024/10/22/aerc/)
- [aerc + notmuch Hybrid](https://blog.theadamcooper.com/terminal-delight-with-aerc-and-notmuch)
