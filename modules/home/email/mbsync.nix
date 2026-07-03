# mbsync IMAP synchronisation configuration for Gmail and Logos Labs mail.
# Gmail authenticates with a Gmail app password (consumer account + 2FA still
# supports IMAP app passwords in 2026); Logos uses Protonmail Bridge.
# App-password decision: task 72 Phase 3 (handoffs/oauth-gate.md) — avoids the
# restricted-scope CASA Tier 2 requirement that XOAUTH2 Production publishing needs.
{ ... }:
{
  home.file.".mbsyncrc".text = ''
    # Gmail IMAP account — app-password auth (same credential himalaya/aerc use)
    IMAPAccount gmail
    Host imap.gmail.com
    Port 993
    User benbrastmckie@gmail.com
    AuthMechs LOGIN
    PassCmd "secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com"
    TLSType IMAPS

    # Gmail remote store
    IMAPStore gmail-remote
    Account gmail

    # Gmail local store - MAILDIR++ FORMAT
    MaildirStore gmail-local
    Inbox ~/Mail/Gmail/
    SubFolders Maildir++

    # Inbox channel - emails go to root cur/new directories
    Channel gmail-inbox
    Far :gmail-remote:INBOX
    Near :gmail-local:
    Create Both
    Expunge Both
    SyncState *

    # Quick inbox channel - syncs only the 50 most recent emails
    Channel gmail-inbox-quick
    Far :gmail-remote:INBOX
    Near :gmail-local:
    Create Both
    Expunge Both
    SyncState *
    MaxMessages 50
    ExpireUnread yes

    # Subfolders - Maildir++ adds dot prefix automatically
    Channel gmail-sent
    Far :gmail-remote:"[Gmail]/Sent Mail"
    Near :gmail-local:Sent
    Create Both
    Expunge Both
    SyncState *

    Channel gmail-drafts
    Far :gmail-remote:"[Gmail]/Drafts"
    Near :gmail-local:Drafts
    Create Both
    Expunge Both
    SyncState *

    Channel gmail-trash
    Far :gmail-remote:"[Gmail]/Trash"
    Near :gmail-local:Trash
    Create Both
    Expunge Both
    SyncState *

    Channel gmail-all
    Far :gmail-remote:"[Gmail]/All Mail"
    Near :gmail-local:All_Mail
    Create Both
    Expunge Both
    SyncState *

    Channel gmail-spam
    Far :gmail-remote:"[Gmail]/Spam"
    Near :gmail-local:Spam
    Create Both
    Expunge Both
    SyncState *

    Channel gmail-folders
    Far :gmail-remote:
    Near :gmail-local:
    Patterns * ![Gmail]* !INBOX !Sent !Drafts !Trash !All_Mail !Spam
    Create Both
    Expunge Both
    Remove Both
    SyncState *

    # Group all channels together
    Group gmail
    Channel gmail-inbox
    Channel gmail-sent
    Channel gmail-drafts
    Channel gmail-trash
    Channel gmail-all
    Channel gmail-spam
    Channel gmail-folders

    # Logos Labs IMAP account (via Protonmail Bridge)
    IMAPAccount logos
    Host 127.0.0.1
    Port 1143
    User benjamin@logos-labs.ai
    PassCmd "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
    TLSType None
    AuthMechs LOGIN

    IMAPStore logos-remote
    Account logos

    MaildirStore logos-local
    Inbox ~/Mail/Logos/
    SubFolders Maildir++

    Channel logos-inbox
    Far :logos-remote:INBOX
    Near :logos-local:
    Create Both
    Expunge Both
    SyncState *

    Channel logos-sent
    Far :logos-remote:Sent
    Near :logos-local:Sent
    Create Both
    Expunge Both
    SyncState *

    Channel logos-drafts
    Far :logos-remote:Drafts
    Near :logos-local:Drafts
    Create Both
    Expunge Both
    SyncState *

    Channel logos-trash
    Far :logos-remote:Trash
    Near :logos-local:Trash
    Create Both
    Expunge Both
    SyncState *

    Channel logos-archive
    Far :logos-remote:Archive
    Near :logos-local:Archive
    Create Both
    Expunge Both
    SyncState *

    Channel logos-labels
    Far :logos-remote:
    Near :logos-local:
    Patterns "Labels/*"
    Create Both
    Expunge Both
    Remove Both
    SyncState *

    Channel logos-folders
    Far :logos-remote:
    Near :logos-local:
    Patterns "Folders/*"
    Create Both
    Expunge Both
    Remove Both
    SyncState *

    Group logos
    Channel logos-inbox
    Channel logos-sent
    Channel logos-drafts
    Channel logos-trash
    Channel logos-archive
    Channel logos-labels
    Channel logos-folders
  '';
}
