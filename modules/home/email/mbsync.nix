# mbsync IMAP synchronisation configuration for Gmail and Logos Labs mail.
# Gmail authenticates with a Gmail app password (consumer account + 2FA still
# supports IMAP app passwords in 2026); Logos uses Protonmail Bridge.
# App-password decision: task 72 Phase 3 (handoffs/oauth-gate.md) — avoids the
# restricted-scope CASA Tier 2 requirement that XOAUTH2 Production publishing needs.
#
# email-freeze/email-thaw (task 72 Phase 8): operator helpers, NOT part of the 5-binary
# agent-tools.nix contract (handoffs/wrapper-contract.md). Verified facts baked in (Phase 1,
# handoffs/verification-baseline.md §1, §5): there is NO mbsync systemd timer — mbsync's only
# trigger paths are notmuch's preNew hook (`mbsync -a`), aerc's `$` keybind
# (`mbsync -a && notmuch new`), and manual invocation; SyncState files live inside
# `~/Mail/Gmail/<folder>/.mbsyncstate*` (NOT `~/.mbsync/`). Thaw reconciles with group-scoped
# `mbsync gmail` — NEVER `mbsync -a`, which would also touch the deferred Logos/Bridge account.
{ pkgs, ... }:
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

  home.packages = [
    (pkgs.writeShellScriptBin "email-freeze" ''
      set -euo pipefail

      MAIL_ROOT="$HOME/Mail/Gmail"
      BACKUP_DIR="$HOME/Mail/.syncstate-backups"

      if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        echo "email-freeze - operator helper (task 72 Phase 8; NOT part of the 5-binary agent contract)"
        echo ""
        echo "Confirms no mbsync process is running, prints the trigger-path guards to observe"
        echo "while frozen, and backs up every ~/Mail/Gmail/**/.mbsyncstate* file to a"
        echo "timestamped tarball under ~/Mail/.syncstate-backups/. Pair with 'email-thaw'."
        exit 0
      fi

      echo "[email-freeze] Checking for a running mbsync process..." >&2
      if pgrep -x mbsync >/dev/null 2>&1; then
        echo "[email-freeze] ERROR: mbsync is currently running (pid(s): $(pgrep -x mbsync | tr '\n' ' '))." >&2
        echo "[email-freeze] Wait for it to finish, then re-run email-freeze." >&2
        exit 1
      fi
      echo "[email-freeze] No running mbsync process detected." >&2
      echo "" >&2
      echo "[email-freeze] TRIGGER-PATH GUARDS while frozen (verification-baseline.md §1: there" >&2
      echo "[email-freeze] is NO mbsync systemd timer -- these are mbsync's ONLY trigger paths):" >&2
      echo "[email-freeze]   1. notmuch's preNew hook is 'mbsync -a' -- run 'notmuch new --no-hooks'" >&2
      echo "[email-freeze]      instead of plain 'notmuch new' while frozen." >&2
      echo "[email-freeze]   2. aerc's '\$' keybind runs 'mbsync -a && notmuch new' -- do NOT press" >&2
      echo "[email-freeze]      '\$' in aerc while frozen." >&2
      echo "[email-freeze]   3. Do not invoke mbsync manually (any group) while frozen." >&2
      echo "" >&2

      mkdir -p "$BACKUP_DIR"
      TS=$(date -u +%Y%m%dT%H%M%SZ)
      TARBALL="$BACKUP_DIR/mbsyncstate-$TS.tar.gz"

      echo "[email-freeze] Enumerating .mbsyncstate* files under $MAIL_ROOT ..." >&2
      FILES=$(find "$MAIL_ROOT" -name '.mbsyncstate*' 2>/dev/null || true)
      if [ -z "$FILES" ]; then
        echo "[email-freeze] ERROR: no .mbsyncstate* files found under $MAIL_ROOT -- refusing to" >&2
        echo "[email-freeze] write an empty backup." >&2
        exit 1
      fi

      COUNT=$(printf '%s\n' "$FILES" | grep -c . || true)
      echo "[email-freeze] Found $COUNT file(s); writing $TARBALL ..." >&2
      printf '%s\n' "$FILES" | tar -czf "$TARBALL" -P -T - 2>&1
      echo "[email-freeze] Backup complete: $TARBALL" >&2
      echo "[email-freeze] FROZEN. Resume with 'email-thaw' when ready." >&2
    '')

    (pkgs.writeShellScriptBin "email-thaw" ''
      set -euo pipefail

      BACKUP_DIR="$HOME/Mail/.syncstate-backups"

      if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        echo "email-thaw - operator helper (task 72 Phase 8; NOT part of the 5-binary agent contract)"
        echo ""
        echo "Reconciles with a single group-scoped 'mbsync gmail' invocation (never the -a flag,"
        echo "which would also touch the deferred Logos/Bridge account). Applies the mbsync"
        echo "auth-failure fail-safe (oauth-gate.md section 4): halts cleanly on invalid_grant or"
        echo "[AUTHENTICATIONFAILED] without touching local SyncState, and prints the"
        echo "interrupted-run recovery procedure."
        exit 0
      fi

      is_auth_failure() {
        printf '%s' "$1" | grep -qE 'invalid_grant|\[AUTHENTICATIONFAILED\] Invalid credentials'
      }

      echo "[email-thaw] Reconciling with 'mbsync gmail' (group-scoped; NEVER the -a flag, which" >&2
      echo "[email-thaw] would also touch the deferred Logos/Bridge account)..." >&2

      set +e
      OUT=$(mbsync gmail 2>&1)
      STATUS=$?
      set -e
      echo "$OUT" >&2

      if [ "$STATUS" -ne 0 ]; then
        if is_auth_failure "$OUT"; then
          echo "" >&2
          echo "[email-thaw] AUTH FAILURE detected (invalid_grant or [AUTHENTICATIONFAILED])." >&2
          echo "[email-thaw] Halting. Local SyncState was not touched by this failed reconcile." >&2
          echo "[email-thaw] INTERRUPTED-RUN RECOVERY:" >&2
          echo "[email-thaw]   1. If local .mbsyncstate files look suspect, restore the most" >&2
          echo "[email-thaw]      recent backup from $BACKUP_DIR :" >&2
          echo "[email-thaw]      tar -xzf <backup>.tar.gz -C /" >&2
          echo "[email-thaw]   2. Fix mbsync auth (see handoffs/oauth-gate.md), then re-run email-thaw." >&2
          echo "[email-thaw]   3. Once mbsync gmail succeeds, run 'notmuch new --no-hooks' to reindex." >&2
          exit 1
        else
          echo "" >&2
          echo "[email-thaw] mbsync gmail exited non-zero for a reason OTHER than an auth failure" >&2
          echo "[email-thaw] (exit $STATUS). This may be the known gmail-spam NONEXISTENT-mailbox" >&2
          echo "[email-thaw] issue (task-46/mbsync scope; see verification-baseline.md §6a) --" >&2
          echo "[email-thaw] inspect the output above." >&2
          exit 1
        fi
      fi

      echo "[email-thaw] mbsync gmail: reconcile OK." >&2
      echo "[email-thaw] Run 'notmuch new --no-hooks' to reindex (folder/account tags re-apply" >&2
      echo "[email-thaw] via modules/home/email/notmuch.nix postNew)." >&2
      echo "[email-thaw] THAWED." >&2
    '')
  ];
}
