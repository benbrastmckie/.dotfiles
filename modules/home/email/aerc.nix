# Aerc terminal email client configuration with notmuch backend.
# See: specs/045_add_terminal_email_client_to_nixos
_: {
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
        # Neovim's built-in mail ftplugin sets textwidth=72 and formatoptions+=t,
        # which HARD-wraps paragraphs as you type (the "breaks lines at ~80" symptom).
        # Override both for the compose buffer so each paragraph stays a single long
        # line; combined with format-flowed below, recipients' clients then soft-wrap
        # to their own width instead of showing fixed-column hard breaks.
        editor = "nvim -c 'setlocal textwidth=0 formatoptions-=t'";
        header-layout = "To|From,Subject";
        address-book-cmd = "";
        reply-to-self = false;
        # Emit RFC3676 "text/plain; format=flowed" bodies so long, un-hard-wrapped
        # lines reflow on the receiving side rather than appearing broken at a column.
        format-flowed = true;
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

        # Task 105: Tab/S-Tab account-tab switching (Neovim <Tab>/<S-Tab>
        # buffer-nav reflex). <C-n>/<C-p> (global) remain as fallback aliases.
        "<Tab>" = ":next-tab<Enter>";
        "<S-Tab>" = ":prev-tab<Enter>";

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
        # Task 112: single-message archive is deliberately left UNPROMPTED (reversible
        # file move, low blast radius, matches mail-client convention), while A/d/D
        # remain prompted since they act on larger or irreversible blast radii.
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
        # Task 109: repointed to 'mail-sync gmail', the single canonical flock-serialized
        # entry point shared with the notmuch preNew hook -- the wrapper already runs
        # 'notmuch new --no-hooks' internally after a successful mbsync, so no separate
        # reindex call is needed here. Kept gmail-only to preserve current behavior;
        # 'mail-sync logos'/'mail-sync both' is a trivial future extension, out of scope here.
        "$" = ":exec mail-sync gmail<Enter>";
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

        # Task 105: Tab/S-Tab account-tab switching (Neovim <Tab>/<S-Tab>
        # buffer-nav reflex). <C-n>/<C-p> (global) remain as fallback aliases.
        "<Tab>" = ":next-tab<Enter>";
        "<S-Tab>" = ":prev-tab<Enter>";

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
        # Task 113: native archive-on-reply. aerc 0.21.0's `:send -a` (Send.Archive,
        # commands/compose/send.go) is consumed by msg/reply.go's OnClose closure, which
        # archives the exact models.MessageInfo captured by reference at :reply time --
        # immune to list reflow / cursor drift (unlike the removed Subject-sniffing
        # mail-sent hook). `-a` is inert (never archives) on :forward, a fresh :compose,
        # and :recall, so this rebind is safe on every send path. Independently scoped
        # from `R` (:reply -a, reply-all below) -- no collision.
        y = ":send -a flat<Enter>";
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

  home.file = {
    # aerc email client accounts configuration
    ".config/aerc/accounts.conf".text = ''
      [gmail]
      source = notmuch://~/Mail
      # Task 112: required for aerc's notmuch worker to perform real :archive/:delete
      # file moves (without it, the worker gates all mutations and returns
      # errUnsupported -- the mechanism behind the prior silent no-op). Upstream aerc
      # master has deprecated maildir-store in favor of enable-maildir, but the
      # installed nixpkgs aerc 0.21.0 still uses maildir-store; remove these two
      # lines (or switch to enable-maildir) if/when the aerc derivation is bumped
      # past that upstream change.
      maildir-store = ~/Mail
      multi-file-strategy = act-dir
      query-map = ~/.config/aerc/querymap-gmail
      # Regression fix (follow-up to task 112): setting maildir-store above makes the
      # notmuch worker ALSO enumerate every physical maildir folder under the shared
      # ~/Mail root -- so BOTH accounts' Gmail/* and Logos/* dirs stacked into every
      # sidebar on top of the query-map virtual folders. folders-exclude is display-only
      # (it does NOT affect :archive's file move, which resolves archive= against
      # maildir-store independently), so it restores the clean, per-account query-map
      # folder list. The ~ prefix marks a regex; no query-map name starts with
      # Gmail/Logos, so this hides only the raw physical tree.
      folders-exclude = ~^Gmail,~^Logos
      default = INBOX
      from = Benjamin Brast-McKie <benbrastmckie@gmail.com>
      copy-to = Sent
      archive = All_Mail
      outgoing = smtps://benbrastmckie@gmail.com@smtp.gmail.com:465
      outgoing-cred-cmd = secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com
      # Task 113: while-aerc-is-open convenience sync, secondary to the systemd
      # mail-sync-timer (primary "sync even when closed" mechanism). --no-wait makes
      # a lock-contended call fail fast (task 109's mail-sync flock; the systemd timer
      # will pick up the sync shortly regardless) rather than hanging aerc's "Checking
      # for new mail..." indicator for up to 300s. check-mail-timeout is raised from
      # its 10s default so a normal, uncontended network mbsync round-trip is not
      # spuriously killed. Wiring check-mail-cmd also makes the pre-existing
      # `u = ":check-mail<Enter>"` keybind functional (it previously errored
      # "checkmail: no command specified"). [logos] is intentionally left unwired,
      # matching the existing gmail-only `$` keybind convention (out of scope).
      check-mail = 10m
      check-mail-cmd = mail-sync gmail --no-wait
      check-mail-timeout = 30s

      [logos]
      source = notmuch://~/Mail
      # Task 112: see the [gmail] maildir-store/multi-file-strategy comment above --
      # same forward-compat caveat applies here.
      maildir-store = ~/Mail
      multi-file-strategy = act-dir
      query-map = ~/.config/aerc/querymap-logos
      # Regression fix (follow-up to task 112): see the [gmail] folders-exclude comment.
      # Same shared-~/Mail enumeration applies here, so exclude the same physical tree.
      folders-exclude = ~^Gmail,~^Logos
      default = INBOX
      from = Benjamin Brast-McKie <benjamin@logos-labs.ai>
      copy-to = Sent
      archive = Archive
      outgoing = smtp://benjamin@logos-labs.ai@127.0.0.1:1025
      outgoing-cred-cmd = secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai
    '';

    # aerc query map for Gmail virtual folders.
    #
    # Task 34 (decouple aerc/himalaya stacks, Phase 5 / F5): account scoping uses
    # `folder:/Gmail/` (notmuch's slash-delimited regex form) instead of `tag:gmail`,
    # aligning aerc with the canonical folder-scoping convention CLAUDE.md mandates
    # for the /email wrapper contract. NOTE: `folder:Gmail*` glob syntax (as CLAUDE.md's
    # prose currently shows it) does NOT work as a literal notmuch query -- it matches
    # zero messages; verified empirically against the working `tag:gmail`-scoped
    # baseline that only `folder:/Gmail/` (or an exact `folder:Gmail/SubDir` path)
    # reproduces the same counts. Flagged for a CLAUDE.md accuracy follow-up.
    #
    # Task 110: INBOX below uses the bare exact-match form `folder:Gmail`/`folder:Logos`
    # (INBOX-only, true maildir-folder membership) rather than `tag:inbox AND folder:/Gmail/`,
    # because `notmuch.nix`'s postNew hook applies `+inbox` once at delivery and never removes
    # it on archive (only on the Sent/Trash/Spam auto-tag rules), so `tag:inbox` is a permanent
    # "was delivered" marker, not a live inbox-membership signal; and `folder:/Gmail/` regex
    # over-matches `Gmail/.All_Mail`. Together the old query returned ~12,580 messages instead
    # of the true ~85-message inbox. The `Unread`/`Flagged`/`Proposed-*` entries below
    # intentionally REMAIN account-wide (`folder:/Gmail/` / `folder:/Logos/`) -- they are
    # tag-driven triage/search views, not folder-membership views, and scoping `Proposed-*` to
    # the inbox would silently hide proposed-tagged messages touched by a prior triage pass,
    # undermining the review gate. Do not re-scope them to match INBOX.
    ".config/aerc/querymap-gmail".text = ''
      INBOX=folder:Gmail
      Sent=folder:Gmail/.Sent
      Drafts=folder:Gmail/.Drafts
      Trash=folder:Gmail/.Trash
      All_Mail=folder:Gmail/.All_Mail
      Spam=folder:Gmail/.Spam
      Unread=tag:unread AND folder:/Gmail/
      Flagged=tag:flagged AND folder:/Gmail/
      Proposed-Delete=tag:proposed-delete AND folder:/Gmail/
      Proposed-Archive=tag:proposed-archive AND folder:/Gmail/
      Proposed-Unsure=tag:proposed-unsure AND folder:/Gmail/
    '';

    # aerc query map for Logos virtual folders. See Gmail querymap comment above
    # (task 34, Phase 5 / F5; task 110) -- same `folder:/Logos/` regex-form rationale and
    # same INBOX-vs-triage-view scope-asymmetry rationale.
    ".config/aerc/querymap-logos".text = ''
      INBOX=folder:Logos
      Sent=folder:Logos/.Sent
      Drafts=folder:Logos/.Drafts
      Trash=folder:Logos/.Trash
      Archive=folder:Logos/.Archive
      Unread=tag:unread AND folder:/Logos/
      Flagged=tag:flagged AND folder:/Logos/
    '';
  };
}
