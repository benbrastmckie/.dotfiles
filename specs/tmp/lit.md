# Issue: `mbsync gmail` exits 1 on the `gmail-spam` channel (and emits `[Gmail]/Trash ALREADYEXISTS` noise)

**Repo/location:** the home-manager module that generates `~/.mbsyncrc` (symlinked to the nix
store — likely `modules/home/email/*.nix`, the block with the
`# Gmail IMAP account — app-password auth` comment).

## Symptom

Every `mbsync gmail` group reconcile — both the one the email wrappers run internally after a
mutation, and the explicit `/email --sync` — exits non-zero with:

```
IMAP command 'CREATE "[Gmail]/Trash"' returned an error: [ALREADYEXISTS] Duplicate folder name (Failure)
Error: channel gmail-spam: far side box [Gmail]/Spam cannot be opened anymore.
Channels: 7    Boxes: 9    Far: +0 *16 #0 -16    Near: +3 *0 #0 -0
=== mbsync exit: 1 ===
```

The actual inbox/Trash/All-Mail reconcile **succeeds** (`Far: -16` shows the moves propagated);
the exit-1 comes entirely from two config problems below. But the non-zero exit is confusing and
makes wrapper post-mutation reconciles look like they failed.

## Root cause 1 — `gmail-spam` channel can't open `[Gmail]/Spam` (this is what makes exit != 0)

Current generated stanza:

```
Channel gmail-spam
Far :gmail-remote:"[Gmail]/Spam"
Near :gmail-local:Spam
Create Both
Expunge Both
SyncState *
```

`[Gmail]/Spam` cannot be `SELECT`ed over IMAP — Gmail only exposes the Spam label via IMAP when
**Settings -> Labels -> Spam -> "Show in IMAP"** is enabled, and even then it's flaky. Because
`gmail-spam` is a member of `Group gmail`, the whole group sync inherits its failure and exits 1.

## Root cause 2 — `Create Both` on Gmail's system folders -> `ALREADYEXISTS` noise

`Create Both` tells mbsync to create the far-side folder if missing. For Gmail's special-use
folders (`[Gmail]/Trash`, `[Gmail]/Sent Mail`, `[Gmail]/Drafts`, `[Gmail]/All Mail`,
`[Gmail]/Spam`) the folder **always already exists server-side**, so the `CREATE` throws
`[ALREADYEXISTS]`. You never need to create Gmail's system folders remotely — only locally.

## Proposed fix (nix-side, both changes)

1. **Drop `gmail-spam` from `Group gmail`** so the group reconcile no longer hard-fails. Keep the
   channel definition if you want to sync Spam manually, but remove it from the group member
   list:

   ```
   Group gmail
   Channel gmail-inbox
   Channel gmail-sent
   Channel gmail-drafts
   Channel gmail-trash
   Channel gmail-all
   Channel gmail-folders
   # gmail-spam removed — [Gmail]/Spam is not reliably IMAP-selectable
   ```

   (Optional: if syncing Spam is actually wanted, instead enable "Show in IMAP" for the Spam
   label in Gmail's web settings — that's a server-side toggle, not a nix change.)

2. **Change `Create Both` -> `Create Near`** on the four/five Gmail system-folder channels
   (`gmail-trash`, `gmail-sent`, `gmail-drafts`, `gmail-all`, and `gmail-spam` if kept). Leave
   `Create Both` only on `gmail-folders` (user labels legitimately may need creating either
   direction). This silences the `[Gmail]/Trash ALREADYEXISTS` error. Example:

   ```
   Channel gmail-trash
   Far :gmail-remote:"[Gmail]/Trash"
   Near :gmail-local:Trash
   Create Near      # was: Create Both
   Expunge Both
   SyncState *
   ```

## Expected result

After `home-manager switch`, `mbsync gmail` exits 0, the wrappers' internal post-mutation
reconcile stops reporting a spurious failure, and `/email --sync` reports clean. Note the same
two-account file also defines a `logos` group via Protonmail Bridge — these changes are scoped to
the `gmail` channels only and don't touch `logos`.

## Reference: current full generated `~/.mbsyncrc` (Gmail section)

```
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
```
