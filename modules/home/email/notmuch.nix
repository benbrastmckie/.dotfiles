# Notmuch email indexer and full-text search configuration.
# Works alongside mbsync for offline IMAP synchronisation.
# See: specs/045_add_terminal_email_client_to_nixos
{ config, ... }:
{
  programs.notmuch = {
    enable = true;
    # Required: primary email for notmuch
    extraConfig = {
      user = {
        name = "Benjamin Brast-McKie";
        primary_email = "benbrastmckie@gmail.com";
        other_email = "benjamin@logos-labs.ai";
      };
      database = {
        path = "${config.home.homeDirectory}/Mail";
      };
    };
    hooks = {
      # Sync via `mail-sync both` -- never `mbsync -a`. `mail-sync` (task 109) is the single
      # canonical, flock-serialized entry point into mbsync shared with aerc's `$` keybind; it
      # takes a blocking flock before invoking mbsync so this hook-triggered sync can never
      # overlap a manual aerc-triggered sync. Internally it runs `mbsync gmail` then
      # `mbsync logos` sequentially (never `-a`, never a passthrough channel), which per
      # `man mbsync` runs only the named Groups' member channels -- avoiding the orphan
      # `logos-labels` channel (deliberately excluded from `Group logos` in mbsync.nix, task
      # 826), which would otherwise re-import every Proton label as a duplicated .Labels.*
      # Maildir++ folder. (~/.dotfiles handoff; tasks 826-828, 109.)
      #
      # `|| true`: notmuch aborts the ENTIRE `notmuch new` run (skipping both the disk
      # scan and postNew below) if preNew exits non-zero. `mail-sync`/mbsync currently exit
      # non-zero on partial/transient failures unrelated to notmuch's own indexing job -- e.g. a
      # single channel's far-side box failing to open, or the known pre-existing
      # duplicate-UID collision in Gmail/.All_Mail (~Mail task 34 baseline; tracked
      # separately as .dotfiles task 852/853). Without this tolerance, any hook-having
      # `notmuch new` invocation fails outright, which is what made this hook an
      # unreliable auto-reindex authority (~Mail task 34, Phase 4). `--no-hooks`
      # call sites (email-reindex, `mail-sync`'s own internal reindex step) are unaffected
      # either way since they skip this hook entirely -- so preNew calling `mail-sync`, which
      # itself runs `notmuch new --no-hooks`, is not reentrant.
      preNew = "mail-sync both || true";
      postNew = ''
        # Tag new mail
        notmuch tag +inbox +unread -- tag:new
        notmuch tag -new -- tag:new
        # Auto-tag by folder
        notmuch tag +sent -inbox -- folder:Gmail/.Sent OR folder:Logos/.Sent
        notmuch tag +trash -inbox -- folder:Gmail/.Trash OR folder:Logos/.Trash
        notmuch tag +spam -inbox -- folder:Gmail/.Spam
        # Tag by account
        notmuch tag +gmail -- folder:/Gmail/
        notmuch tag +logos -- folder:/Logos/

        # --- per-sender junk rules (managed: task 72 scaffold; populated via ~/Mail #29) ---
        # SCAFFOLDING ONLY -- no live rules land in task 72. Real per-sender junk rules are
        # populated here by ~/Mail #29, sourced from the tag:proposed-*/confirmed-* review
        # flow (see specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md).
        # afew was considered and REJECTED as a second config surface for this: tagging stays
        # in this single postNew string so there is exactly one ownership point.
        # Example rule (commented out; not live):
        # notmuch tag +junk -inbox -- from:sender@example.test
      '';
    };
    new = {
      tags = [ "new" ];
      ignore = [
        ".mbsyncstate"
        ".strstrings"
        ".lock"
        "dovecot*"
      ];
    };
    search = {
      excludeTags = [
        "deleted"
        "spam"
        "trash"
      ];
    };
    maildir = {
      synchronizeFlags = true;
    };
  };
}
