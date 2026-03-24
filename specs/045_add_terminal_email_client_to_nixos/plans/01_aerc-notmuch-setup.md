# Implementation Plan: aerc + notmuch Email Setup

- **Task**: 45 - Add Terminal Email Client to NixOS
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: Existing mbsync, msmtp, w3m, protonmail-bridge configuration
- **Research Inputs**:
  - reports/01_terminal-email-clients.md
  - reports/02_aerc-vs-notmuch-comparison.md
- **Artifacts**: plans/01_aerc-notmuch-setup.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

This plan sets up aerc as a terminal email client with notmuch as the backend for powerful search and tagging, integrating with the existing mbsync/protonmail-bridge/himalaya infrastructure. The approach leverages aerc's polished vim-style TUI while gaining notmuch's Xapian-based full-text search and tag-based organization. The configuration will work alongside existing himalaya setup without conflict.

### Research Integration

From research reports:
- aerc v0.21.0 (March 2026) provides native vim keybindings and notmuch backend support
- notmuch v0.40 (January 2026) offers powerful Xapian-based search
- Hybrid approach recommended: aerc UI + notmuch search/tagging
- Existing mbsync XOAUTH2 configuration can be reused directly
- w3m already installed for HTML rendering

## Goals & Non-Goals

**Goals**:
- Install and configure notmuch to index existing Maildir (~/Mail)
- Install and configure aerc with notmuch backend
- Set up tag-based virtual folders for both Gmail and Logos accounts
- Create vim-style keybindings optimized for the user's workflow
- Integrate with Neovim (either notmuch.nvim plugin or terminal aerc)
- Provide unified search across all accounts

**Non-Goals**:
- Replacing himalaya (aerc/notmuch runs alongside it)
- Migrating away from mbsync (we leverage existing config)
- Setting up email encryption/signing (future enhancement)
- Calendar/contacts integration (out of scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| notmuch database corruption | H | L | Regular backups of ~/Mail/.notmuch, use XDG_DATA_HOME |
| Tag paradigm learning curve | M | M | Start with simple inbox/archive workflow, expand gradually |
| mbsync hook integration complexity | M | L | Use notmuch's built-in hooks, test incrementally |
| aerc filter configuration issues | M | M | Start with defaults, customize iteratively |
| Neovim plugin compatibility | L | M | Test notmuch.nvim first, fall back to terminal aerc |

## Implementation Phases

### Phase 1: notmuch Installation and Database Setup [COMPLETED]

**Goal**: Install notmuch and create initial index of existing Maildir

**Tasks**:
- [ ] Add `programs.notmuch.enable = true` to home.nix
- [ ] Configure notmuch database paths and initial tags
- [ ] Set up hooks for automatic indexing after mbsync
- [ ] Create initial notmuch database with `notmuch new`
- [ ] Verify indexing works for both Gmail and Logos accounts

**Timing**: 45 minutes

**Files to modify**:
- `home.nix` - Add notmuch configuration block

**Configuration snippet**:
```nix
programs.notmuch = {
  enable = true;
  hooks = {
    preNew = "mbsync -a";
    postNew = ''
      # Tag new mail
      notmuch tag +inbox +unread -- tag:new
      notmuch tag -new -- tag:new
      # Auto-tag by folder
      notmuch tag +sent -inbox -- folder:Gmail/.Sent OR folder:Logos/.Sent
      notmuch tag +trash -inbox -- folder:Gmail/.Trash OR folder:Logos/.Trash
      notmuch tag +spam -inbox -- folder:Gmail/.Spam
    '';
  };
  new = {
    tags = [ "new" ];
    ignore = [ ".mbsyncstate" ".strstrings" ".lock" "dovecot*" ];
  };
  search = {
    excludeTags = [ "deleted" "spam" "trash" ];
  };
  maildir = {
    synchronizeFlags = true;
  };
};
```

**Verification**:
- Run `notmuch new` - should index existing mail without errors
- Run `notmuch count` - should return total message count
- Run `notmuch search tag:inbox` - should list inbox messages
- Run `notmuch search from:benjamin` - should find sent messages

---

### Phase 2: aerc Installation and Basic Configuration [COMPLETED]

**Goal**: Install aerc and configure basic settings with notmuch backend

**Tasks**:
- [ ] Add `programs.aerc.enable = true` to home.nix
- [ ] Configure aerc general settings (unsafe-accounts-conf, index columns)
- [ ] Set up HTML and text filters using existing w3m
- [ ] Configure compose settings ($EDITOR = nvim)
- [ ] Test basic aerc startup

**Timing**: 45 minutes

**Files to modify**:
- `home.nix` - Add aerc configuration block

**Configuration snippet**:
```nix
programs.aerc = {
  enable = true;
  extraConfig = {
    general = {
      unsafe-accounts-conf = true;
      pgp-provider = "gpg";
      default-save-path = "~/Downloads";
    };
    ui = {
      index-columns = "date<20,name<20,flags>4,subject<*";
      column-separator = "  ";
      timestamp-format = "2006-01-02 15:04";
      this-day-time-format = "15:04";
      this-week-time-format = "Mon 15:04";
      this-year-time-format = "Jan 02";
      sidebar-width = 20;
      empty-message = "(no messages)";
      empty-dirlist = "(no folders)";
      mouse-enabled = false;
      new-message-bell = true;
      stylesets-dirs = [ "${config.xdg.configHome}/aerc/stylesets" ];
      styleset-name = "default";
    };
    viewer = {
      pager = "less -R";
      alternatives = "text/plain,text/html";
      show-headers = false;
      header-layout = "From|To,Cc|Bcc,Date,Subject";
    };
    compose = {
      editor = "nvim";
      header-layout = "To|From,Subject";
      address-book-cmd = "";
      reply-to-self = false;
    };
    filters = {
      "text/plain" = "colorize";
      "text/calendar" = "calendar";
      "message/delivery-status" = "colorize";
      "message/rfc822" = "colorize";
      "text/html" = "w3m -I UTF-8 -T text/html -o display_link_number=1";
    };
    openers = {
      "text/html" = "xdg-open";
      "application/pdf" = "zathura";
      "image/*" = "imv";
    };
  };
};
```

**Verification**:
- Run `aerc --help` - should show help without errors
- Check `~/.config/aerc/aerc.conf` exists and has correct content
- Run `aerc` - should start (will show no accounts yet)

---

### Phase 3: aerc Account Configuration with notmuch Backend [COMPLETED]

**Goal**: Configure aerc to use notmuch as backend for both Gmail and Logos accounts

**Tasks**:
- [ ] Create aerc accounts.conf with notmuch source
- [ ] Create query-map file for virtual folders
- [ ] Configure outgoing SMTP for both accounts (reusing existing credentials)
- [ ] Test account switching and folder listing

**Timing**: 1 hour

**Files to create/modify**:
- `home.nix` - Add accounts.conf configuration
- `config/aerc-querymap` - Virtual folder definitions

**accounts.conf configuration** (in home.nix):
```nix
home.file.".config/aerc/accounts.conf".text = ''
  [gmail]
  source = notmuch://~/Mail
  query-map = ~/.config/aerc/querymap-gmail
  default = INBOX
  from = Benjamin Brast-McKie <benbrastmckie@gmail.com>
  copy-to = Sent
  archive = All_Mail
  outgoing = smtp+plain://benbrastmckie@gmail.com@smtp.gmail.com:465
  outgoing-cred-cmd = secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token
  smtp-starttls = yes

  [logos]
  source = notmuch://~/Mail
  query-map = ~/.config/aerc/querymap-logos
  default = INBOX
  from = Benjamin Brast-McKie <benjamin@logos-labs.ai>
  copy-to = Sent
  archive = Archive
  outgoing = smtp://benjamin@logos-labs.ai@127.0.0.1:1025
  outgoing-cred-cmd = secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai
'';
```

**querymap-gmail** (virtual folders):
```
INBOX=tag:inbox AND folder:/Gmail/
Sent=folder:Gmail/.Sent
Drafts=folder:Gmail/.Drafts
Trash=folder:Gmail/.Trash
All_Mail=folder:Gmail/.All_Mail
Spam=folder:Gmail/.Spam
Unread=tag:unread AND folder:/Gmail/
Flagged=tag:flagged AND folder:/Gmail/
```

**querymap-logos** (virtual folders):
```
INBOX=tag:inbox AND folder:/Logos/
Sent=folder:Logos/.Sent
Drafts=folder:Logos/.Drafts
Trash=folder:Logos/.Trash
Archive=folder:Logos/.Archive
Unread=tag:unread AND folder:/Logos/
Flagged=tag:flagged AND folder:/Logos/
```

**Verification**:
- Run `aerc` - should show both accounts in sidebar
- Select gmail account - should list inbox messages
- Select logos account - should list inbox messages
- Test folder switching with Tab and number keys
- Compose test email (do not send) to verify SMTP config

---

### Phase 4: aerc Keybindings and Workflow Configuration [COMPLETED]

**Goal**: Configure vim-style keybindings and efficient email workflow

**Tasks**:
- [ ] Create comprehensive binds.conf with vim motions
- [ ] Add quick-access keybindings for common operations
- [ ] Configure archive/delete/tag workflows
- [ ] Set up sync keybinding to trigger mbsync + notmuch new
- [ ] Test all keybindings work as expected

**Timing**: 45 minutes

**Files to modify**:
- `home.nix` - Add aerc extraBinds configuration

**Configuration snippet**:
```nix
programs.aerc.extraBinds = {
  # Global bindings
  global = {
    "<C-p>" = ":prev-tab<Enter>";
    "<C-n>" = ":next-tab<Enter>";
    "<C-t>" = ":term<Enter>";
    "?" = ":help keys<Enter>";
  };

  # Message list bindings
  messages = {
    q = ":quit<Enter>";

    # Vim navigation
    j = ":next<Enter>";
    k = ":prev<Enter>";
    "J" = ":next-folder<Enter>";
    "K" = ":prev-folder<Enter>";
    "g" = ":select 0<Enter>";
    "G" = ":select -1<Enter>";
    "<C-d>" = ":next 50%<Enter>";
    "<C-u>" = ":prev 50%<Enter>";
    "<C-f>" = ":next 100%<Enter>";
    "<C-b>" = ":prev 100%<Enter>";

    # Actions
    "<Enter>" = ":view<Enter>";
    "d" = ":prompt 'Delete message?' 'delete-message'<Enter>";
    "D" = ":delete<Enter>";
    "a" = ":archive flat<Enter>";
    "A" = ":unmark -a<Enter>:mark -a<Enter>:archive flat<Enter>";

    # Compose
    "c" = ":compose<Enter>";
    "r" = ":reply<Enter>";
    "R" = ":reply -a<Enter>";
    "f" = ":forward<Enter>";

    # Tags
    "t" = ":modify-tags ";
    "T" = ":toggle-tag ";
    "*" = ":toggle-tag flagged<Enter>";

    # Search and filter
    "/" = ":search ";
    "n" = ":next-result<Enter>";
    "N" = ":prev-result<Enter>";
    "v" = ":filter ";
    "V" = ":clear<Enter>";

    # Selection
    "x" = ":toggle-select<Enter>:next<Enter>";
    "X" = ":toggle-select<Enter>:prev<Enter>";
    "<Space>" = ":toggle-select<Enter>";

    # Sync
    "$" = ":exec mbsync -a && notmuch new<Enter>";
    "u" = ":check-mail<Enter>";

    # Marks
    "m" = ":mark ";
    "M" = ":unmark -a<Enter>";
  };

  # Message view bindings
  "messages:folder=Drafts" = {
    "<Enter>" = ":recall<Enter>";
  };

  view = {
    q = ":close<Enter>";

    # Navigation
    j = ":next-part<Enter>";
    k = ":prev-part<Enter>";
    "J" = ":next<Enter>";
    "K" = ":prev<Enter>";

    # Actions
    "r" = ":reply<Enter>";
    "R" = ":reply -a<Enter>";
    "f" = ":forward<Enter>";
    "d" = ":prompt 'Delete message?' 'delete-message'<Enter>";
    "a" = ":archive flat<Enter>";

    # Attachments
    "o" = ":open<Enter>";
    "s" = ":save<Enter>";
    "S" = ":save -a<Enter>";

    # Toggle
    "h" = ":toggle-headers<Enter>";
    "H" = ":toggle-key-passthrough<Enter>";

    # Pager
    "<Space>" = ":page-down<Enter>";
    "<C-d>" = ":page-down<Enter>";
    "<C-u>" = ":page-up<Enter>";
  };

  # Compose bindings
  compose = {
    "$ex" = "<C-x>";
    "<C-k>" = ":prev-field<Enter>";
    "<C-j>" = ":next-field<Enter>";
    "<C-p>" = ":prev-tab<Enter>";
    "<C-n>" = ":next-tab<Enter>";
  };

  "compose::editor" = {
    "$noinherit" = "true";
    "$ex" = "<C-x>";
    "<C-k>" = ":prev-field<Enter>";
    "<C-j>" = ":next-field<Enter>";
    "<C-p>" = ":prev-tab<Enter>";
    "<C-n>" = ":next-tab<Enter>";
  };

  "compose::review" = {
    "y" = ":send<Enter>";
    "n" = ":abort<Enter>";
    "p" = ":postpone<Enter>";
    "q" = ":abort<Enter>";
    "e" = ":edit<Enter>";
    "a" = ":attach<space>";
    "d" = ":detach<space>";
  };

  # Terminal bindings
  terminal = {
    "$noinherit" = "true";
    "$ex" = "<C-x>";
    "<C-p>" = ":prev-tab<Enter>";
    "<C-n>" = ":next-tab<Enter>";
  };
};
```

**Verification**:
- Test j/k navigation in message list
- Test d to delete (with confirmation)
- Test a to archive
- Test c to compose
- Test $ to sync
- Test / to search
- Test t to modify tags
- Test Tab to switch accounts

---

### Phase 5: Neovim Integration [COMPLETED]

**Goal**: Enable email access from within Neovim using notmuch.nvim or terminal aerc

**Tasks**:
- [ ] Evaluate notmuch.nvim vs terminal aerc in Neovim
- [ ] Install and configure notmuch.nvim plugin (primary option)
- [ ] Set up keymappings for email operations
- [ ] Configure fallback: open aerc in terminal split
- [ ] Test email workflow from within Neovim

**Timing**: 1 hour

**Files to modify**:
- `lua/plugins/mail.lua` - New plugin file for email integration

**notmuch.nvim configuration**:
```lua
-- lua/plugins/mail.lua
return {
  {
    "yousefakbar/notmuch.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    cmd = { "NotmuchSearch", "NotmuchShow", "NotmuchCompose" },
    keys = {
      { "<leader>ms", "<cmd>NotmuchSearch tag:inbox<cr>", desc = "Search inbox" },
      { "<leader>mu", "<cmd>NotmuchSearch tag:unread<cr>", desc = "Search unread" },
      { "<leader>ma", "<cmd>NotmuchSearch *<cr>", desc = "Search all mail" },
      { "<leader>mc", "<cmd>NotmuchCompose<cr>", desc = "Compose email" },
      { "<leader>mm", "<cmd>NotmuchSearch<cr>", desc = "Search mail" },
    },
    opts = {
      maildir = os.getenv("HOME") .. "/Mail",
      notmuch_config = os.getenv("HOME") .. "/.notmuch-config",
      html_renderer = "w3m -I UTF-8 -T text/html",
      compose_editor = "split",
      thread_sort = "newest_first",
      date_format = "%Y-%m-%d %H:%M",
    },
  },

  -- Fallback: Open aerc in terminal
  {
    "akinsho/toggleterm.nvim",
    keys = {
      {
        "<leader>me",
        function()
          require("toggleterm.terminal").Terminal
            :new({ cmd = "aerc", direction = "float" })
            :toggle()
        end,
        desc = "Open aerc email client",
      },
    },
  },
}
```

**Alternative: terminal aerc integration** (if notmuch.nvim doesn't meet needs):
```lua
-- Simple terminal integration
vim.keymap.set("n", "<leader>me", function()
  vim.cmd("terminal aerc")
end, { desc = "Open aerc in terminal" })

-- Quick sync from Neovim
vim.keymap.set("n", "<leader>mS", function()
  vim.fn.jobstart({ "mbsync", "-a" }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.fn.jobstart({ "notmuch", "new" }, {
          on_exit = function()
            vim.notify("Mail synced successfully", vim.log.levels.INFO)
          end,
        })
      else
        vim.notify("Mail sync failed", vim.log.levels.ERROR)
      end
    end,
  })
end, { desc = "Sync mail" })
```

**Verification**:
- Open Neovim and run `<leader>ms` - should show inbox
- Test reading a message with Enter
- Test composing with `<leader>mc` or c in search view
- Test `<leader>mS` sync keybinding
- Verify w3m renders HTML emails properly

---

### Phase 6: Testing and Verification [COMPLETED]

**Goal**: Comprehensive testing of all components and workflows

**Tasks**:
- [ ] Test complete email receive workflow (mbsync -> notmuch -> aerc)
- [ ] Test complete email send workflow (compose -> SMTP)
- [ ] Test search across both accounts
- [ ] Test tag operations (add, remove, toggle)
- [ ] Test Neovim integration end-to-end
- [ ] Verify no conflicts with existing himalaya setup
- [ ] Document any issues encountered

**Timing**: 30 minutes

**Verification checklist**:
- [ ] `mbsync -a` syncs both Gmail and Logos without errors
- [ ] `notmuch new` indexes new messages correctly
- [ ] `notmuch search tag:inbox` returns expected results
- [ ] aerc starts and shows both accounts
- [ ] Can read emails in aerc
- [ ] Can compose and send test email from aerc
- [ ] Can archive/delete/tag messages
- [ ] Can search across all mail
- [ ] Neovim `<leader>ms` shows inbox
- [ ] himalaya CLI still works: `himalaya message list`

## Testing & Validation

- [ ] mbsync syncs both accounts without errors
- [ ] notmuch indexes all mail (check with `notmuch count`)
- [ ] aerc shows both accounts with correct folder counts
- [ ] Email composition and sending works
- [ ] Search finds messages across both accounts
- [ ] Tags persist after sync
- [ ] Neovim plugin integrates smoothly
- [ ] No interference with existing himalaya setup

## Artifacts & Outputs

- plans/01_aerc-notmuch-setup.md (this file)
- Modified `home.nix` with notmuch and aerc configuration
- New `config/aerc-querymap-gmail` file
- New `config/aerc-querymap-logos` file
- New `lua/plugins/mail.lua` for Neovim integration
- summaries/02_implementation-summary.md (after completion)

## Rollback/Contingency

If issues arise:
1. **notmuch database issues**: Remove `~/Mail/.notmuch/` and re-run `notmuch new`
2. **aerc configuration issues**: Remove `~/.config/aerc/` and rebuild with home-manager
3. **Neovim plugin issues**: Disable mail.lua plugin, use terminal aerc
4. **Full rollback**: Remove notmuch/aerc blocks from home.nix, run `home-manager switch`

Himalaya remains unaffected as a parallel email client option.
