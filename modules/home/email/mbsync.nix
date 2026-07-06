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
    Create Near
    Expunge Both
    SyncState *

    Channel gmail-drafts
    Far :gmail-remote:"[Gmail]/Drafts"
    Near :gmail-local:Drafts
    Create Near
    Expunge Both
    SyncState *

    # gmail-trash is defined for manual sync only; it is intentionally NOT a member of
    # Group gmail below. On this account "[Gmail]/Trash" returns [NONEXISTENT] over IMAP
    # (Trash system label has "Show in IMAP" off), so including it in the group made the
    # whole `mbsync gmail` reconcile exit 1.
    Channel gmail-trash
    Far :gmail-remote:"[Gmail]/Trash"
    Near :gmail-local:Trash
    Create Near
    Expunge Both
    SyncState *

    Channel gmail-all
    Far :gmail-remote:"[Gmail]/All Mail"
    Near :gmail-local:All_Mail
    Create Near
    Expunge Both
    SyncState *

    # gmail-spam is defined for manual sync only; it is intentionally NOT a member of
    # Group gmail below. [Gmail]/Spam is not reliably IMAP-selectable (requires
    # Settings -> Labels -> Spam -> "Show in IMAP"), so including it in the group made
    # the whole `mbsync gmail` reconcile exit 1.
    Channel gmail-spam
    Far :gmail-remote:"[Gmail]/Spam"
    Near :gmail-local:Spam
    Create Near
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

    # Group all channels together.
    # gmail-trash and gmail-spam are intentionally omitted: this account does NOT expose
    # Gmail's Trash/Spam system labels over IMAP (Settings -> Labels -> "Show in IMAP" is
    # off), so the server returns [NONEXISTENT] Unknown Mailbox for both "[Gmail]/Trash"
    # and "[Gmail]/Spam" and the whole `mbsync gmail` group reconcile exits 1. The channel
    # definitions are kept for manual use if "Show in IMAP" is later enabled for those
    # labels (a Gmail web-settings toggle). Consequence: local deletions move mail to
    # ~/Mail/Gmail/.Trash but do NOT propagate to Gmail's server-side trash.
    Group gmail
    Channel gmail-inbox
    Channel gmail-sent
    Channel gmail-drafts
    Channel gmail-all
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

    # logos-labels is defined for manual/inspection sync only; it is intentionally NOT a member
    # of Group logos below (task 826). Protonmail Bridge exposes labels as additive virtual IMAP
    # mailboxes (like Gmail's label-as-mailbox model) -- every message carrying one or more
    # labels is mirrored as a SEPARATE physical file under the corresponding .Labels.* Maildir++
    # folder, on top of its copy in the canonical folder (INBOX/.Archive/.Sent/etc). Including
    # this channel in the group duplicated 38,041 files (86% of the ~/Mail/Logos tree) and, once
    # a label containing a dot appeared (.Labels.benbrastmckie@gmail.com), crashed the whole-group
    # reconcile on the Maildir++ dotted-folder name. The channel definition is kept for optional
    # manual inspection (`mbsync logos-labels`); it is never invoked by the agent-facing sync path.
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

    # Group all channels together.
    # logos-labels is intentionally omitted (task 826): Protonmail Bridge mirrors every
    # additive label as a separate local Maildir++ folder (.Labels.*), so including it here
    # duplicated every labeled message on disk and crashed the whole-group reconcile the moment
    # a dotted label name (.Labels.benbrastmckie@gmail.com) appeared. The channel definition
    # above is kept for optional manual inspection only. logos-folders is kept in the group:
    # Proton Folders are exclusive (a message lives in exactly one Folder), so no duplication
    # risk exists there.
    Group logos
    Channel logos-inbox
    Channel logos-sent
    Channel logos-drafts
    Channel logos-trash
    Channel logos-archive
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
          echo "[email-thaw] (exit $STATUS). Note: gmail-trash and gmail-spam are no longer in" >&2
          echo "[email-thaw] Group gmail (their [Gmail]/Trash and [Gmail]/Spam far boxes are" >&2
          echo "[email-thaw] [NONEXISTENT] over IMAP unless 'Show in IMAP' is enabled for those" >&2
          echo "[email-thaw] labels), so this is a NEW failure -- inspect the output above." >&2
          exit 1
        fi
      fi

      echo "[email-thaw] mbsync gmail: reconcile OK." >&2
      echo "[email-thaw] Run 'notmuch new --no-hooks' to reindex (folder/account tags re-apply" >&2
      echo "[email-thaw] via modules/home/email/notmuch.nix postNew)." >&2
      echo "[email-thaw] THAWED." >&2
    '')

    (pkgs.writeShellScriptBin "email-reindex" ''
      set -euo pipefail

      if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        echo "email-reindex - operator helper (task 824; NOT part of the 5-binary agent contract)"
        echo ""
        echo "Reconciles the notmuch index to the on-disk maildir by running"
        echo "'notmuch new --no-hooks'. The --no-hooks form is deliberate:"
        echo "  * skips the preNew hook ('mbsync -a'), preserving the never-'mbsync -a' invariant"
        echo "    and staying safe to run during an email-freeze;"
        echo "  * skips the postNew auto-tagging (+inbox/+gmail/+logos), so folder-scoped queries"
        echo "    (folder:Gmail / folder:Logos, used by email-classify) are made current, while"
        echo "    tag-based views (+inbox) may lag until a later full 'notmuch new' runs."
        echo ""
        echo "This does NOT fetch new mail from the server. If the server has mail not yet on"
        echo "disk, run a group-scoped 'mbsync <gmail|logos>' (or 'email-thaw') FIRST, then"
        echo "'email-reindex'. This is the sanctioned reindex path for the /email skill's"
        echo "staleness remediation (skill-email-cleanup); it is index-only and mutates no mail."
        exit 0
      fi

      echo "[email-reindex] Reconciling notmuch index to on-disk maildir via 'notmuch new --no-hooks'..." >&2
      echo "[email-reindex] (index-only; does NOT sync the server. Run 'mbsync <group>' first if you" >&2
      echo "[email-reindex]  need to pull new server mail before reindexing.)" >&2
      BEFORE=$(notmuch count '*' 2>/dev/null || echo '?')
      notmuch new --no-hooks
      AFTER=$(notmuch count '*' 2>/dev/null || echo '?')
      echo "[email-reindex] Done. Total indexed messages: $BEFORE -> $AFTER." >&2
      echo "[email-reindex] NOTE: --no-hooks skipped postNew auto-tagging (+inbox/+gmail/+logos);" >&2
      echo "[email-reindex] folder-scoped classification is now current, tag-based views may lag." >&2
    '')
  ];
}
