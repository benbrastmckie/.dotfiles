# Aerc terminal email client configuration with notmuch backend.
# See: specs/045_add_terminal_email_client_to_nixos
{ ... }:
{
  # aerc - terminal email client with notmuch backend
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
    extraBinds = {
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
        J = ":next-folder<Enter>";
        K = ":prev-folder<Enter>";
        g = ":select 0<Enter>";
        G = ":select -1<Enter>";
        "<C-d>" = ":next 50%<Enter>";
        "<C-u>" = ":prev 50%<Enter>";
        "<C-f>" = ":next 100%<Enter>";
        "<C-b>" = ":prev 100%<Enter>";

        # Actions
        # Task 72 Phase 9 decision (recorded in handoffs/mail-29-runbook.md): native d/D/a/A
        # are KEPT as human-only paths, outside the agent guardrail by design (the PreToolUse
        # mail-guard hook can only gate the Claude Code agent's own Bash calls, not aerc's Go
        # worker). D (bare :delete, no confirm) and A (bulk archive) are hardened with a
        # :prompt confirm below; d already prompted.
        "<Enter>" = ":view<Enter>";
        d = ":prompt 'Delete message?' 'delete-message'<Enter>";
        D = ":prompt 'Hard delete (bypass the confirm-message prompt)?' 'delete'<Enter>";
        a = ":archive flat<Enter>";
        A = ":unmark -a<Enter>:mark -a<Enter>:prompt 'Archive ALL marked messages?' 'archive flat'<Enter>";

        # Compose
        c = ":compose<Enter>";
        r = ":reply<Enter>";
        R = ":reply -a<Enter>";
        f = ":forward<Enter>";

        # Tags
        t = ":modify-tags ";
        T = ":toggle-tag ";
        "*" = ":toggle-tag flagged<Enter>";

        # Search and filter
        "/" = ":search ";
        n = ":next-result<Enter>";
        N = ":prev-result<Enter>";
        v = ":filter ";
        V = ":clear<Enter>";

        # Selection
        x = ":toggle-select<Enter>:next<Enter>";
        X = ":toggle-select<Enter>:prev<Enter>";
        "<Space>" = ":toggle-select<Enter>";

        # Sync
        # Task 72 Phase 9 decision: rebound from 'mbsync -a && notmuch new' -- the -a form is
        # the same freeze-blast-radius hazard as the preNew hook (would also touch the
        # deferred Logos/Bridge account); notmuch new (no --no-hooks) would re-trigger the
        # preNew hook's own 'mbsync -a'. Group-scoped + hook-bypassing form only.
        "$" = ":exec mbsync gmail && notmuch new --no-hooks<Enter>";
        u = ":check-mail<Enter>";

        # Marks
        m = ":mark ";
        M = ":unmark -a<Enter>";
      };

      # Message view bindings (Drafts folder)
      "messages:folder=Drafts" = {
        "<Enter>" = ":recall<Enter>";
      };

      # Task 72 Phase 9: Proposed-* review views (email-classify's +proposed-* candidates).
      # Confirm gestures retag +confirmed-{delete,archive} and :exec email-classify
      # --append-approved {{.MessageId}} to queue the Message-ID into the APPROVED manifest
      # (wrapper-contract.md §6) -- they NEVER mutate inline and NEVER use aerc's native
      # :delete-message/:archive (those run in aerc's Go worker and would bypass both the
      # mail-guard hook and the manifest/approval flow entirely). Reject rescues to
      # +proposed-keep. d/a deliberately SHADOW the native single-delete/archive keys ONLY
      # within these three curated views, replacing them with the safe wrapper-routed
      # gesture; d/D/a/A keep their native (human-only) behavior everywhere else.
      "messages:folder=Proposed-Delete" = {
        d = ":modify-tags +confirmed-delete -proposed-delete<Enter>:exec email-classify --append-approved {{.MessageId}}<Enter>";
        k = ":modify-tags +proposed-keep -proposed-delete<Enter>";
      };

      "messages:folder=Proposed-Archive" = {
        a = ":modify-tags +confirmed-archive -proposed-archive<Enter>:exec email-classify --append-approved {{.MessageId}}<Enter>";
        k = ":modify-tags +proposed-keep -proposed-archive<Enter>";
      };

      "messages:folder=Proposed-Unsure" = {
        d = ":modify-tags +confirmed-delete -proposed-unsure<Enter>:exec email-classify --append-approved {{.MessageId}}<Enter>";
        a = ":modify-tags +confirmed-archive -proposed-unsure<Enter>:exec email-classify --append-approved {{.MessageId}}<Enter>";
        k = ":modify-tags +proposed-keep -proposed-unsure<Enter>";
      };

      view = {
        q = ":close<Enter>";

        # Navigation
        j = ":next-part<Enter>";
        k = ":prev-part<Enter>";
        J = ":next<Enter>";
        K = ":prev<Enter>";

        # Actions
        r = ":reply<Enter>";
        R = ":reply -a<Enter>";
        f = ":forward<Enter>";
        d = ":prompt 'Delete message?' 'delete-message'<Enter>";
        a = ":archive flat<Enter>";

        # Attachments
        o = ":open<Enter>";
        s = ":save<Enter>";
        S = ":save -a<Enter>";

        # Toggle
        h = ":toggle-headers<Enter>";
        H = ":toggle-key-passthrough<Enter>";

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
        y = ":send<Enter>";
        n = ":abort<Enter>";
        p = ":postpone<Enter>";
        q = ":abort<Enter>";
        e = ":edit<Enter>";
        a = ":attach<space>";
        d = ":detach<space>";
      };

      # Terminal bindings
      terminal = {
        "$noinherit" = "true";
        "$ex" = "<C-x>";
        "<C-p>" = ":prev-tab<Enter>";
        "<C-n>" = ":next-tab<Enter>";
      };
    };
  };

  # aerc email client accounts configuration
  home.file.".config/aerc/accounts.conf".text = ''
    [gmail]
    source = notmuch://~/Mail
    query-map = ~/.config/aerc/querymap-gmail
    default = INBOX
    from = Benjamin Brast-McKie <benbrastmckie@gmail.com>
    copy-to = Sent
    archive = All_Mail
    outgoing = smtps://benbrastmckie@gmail.com@smtp.gmail.com:465
    outgoing-cred-cmd = secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com

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

  # aerc query map for Gmail virtual folders
  home.file.".config/aerc/querymap-gmail".text = ''
    INBOX=tag:inbox AND tag:gmail
    Sent=folder:Gmail/.Sent
    Drafts=folder:Gmail/.Drafts
    Trash=folder:Gmail/.Trash
    All_Mail=folder:Gmail/.All_Mail
    Spam=folder:Gmail/.Spam
    Unread=tag:unread AND tag:gmail
    Flagged=tag:flagged AND tag:gmail
    Proposed-Delete=tag:proposed-delete AND tag:gmail
    Proposed-Archive=tag:proposed-archive AND tag:gmail
    Proposed-Unsure=tag:proposed-unsure AND tag:gmail
  '';

  # aerc query map for Logos virtual folders
  home.file.".config/aerc/querymap-logos".text = ''
    INBOX=tag:inbox AND tag:logos
    Sent=folder:Logos/.Sent
    Drafts=folder:Logos/.Drafts
    Trash=folder:Logos/.Trash
    Archive=folder:Logos/.Archive
    Unread=tag:unread AND tag:logos
    Flagged=tag:flagged AND tag:logos
  '';
}
