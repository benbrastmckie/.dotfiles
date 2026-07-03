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
      preNew = "mbsync -a";
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
      ignore = [ ".mbsyncstate" ".strstrings" ".lock" "dovecot*" ];
    };
    search = {
      excludeTags = [ "deleted" "spam" "trash" ];
    };
    maildir = {
      synchronizeFlags = true;
    };
  };
}
