# Aerc terminal email client configuration with notmuch backend.
#
# Cross-file contract (invariants this module shares with the rest of the mail
# stack -- mbsync.nix, mail-sync.nix, notmuch.nix, mail-sync-timer.nix):
#   - Both accounts live under ONE shared ~/Mail maildir root indexed by a
#     single notmuch database; account scoping is expressed only via notmuch
#     `folder:` query tokens.
#   - `folder:` token semantics: bare `folder:Gmail` is an EXACT maildir-folder
#     match (INBOX only); `folder:/Gmail/` is a slash-delimited regex matching
#     the whole account subtree (`folder:Gmail*` glob syntax does NOT work --
#     see the querymap scoping note below).
#   - All three sync entry points -- the `$` keybind, check-mail-cmd, and the
#     systemd mail-sync-timer -- converge on the single flock-serialized
#     `mail-sync` wrapper, which reindexes internally.
#   - Deletion danger: the mbsync channels run with `Expunge Both` (see
#     mbsync.nix), so a local delete propagates to the server on the next sync.
_:
let
  # folders-exclude, shared by both accounts.conf blocks. Architectural note:
  # the two accounts deliberately share one maildir-store root (~/Mail), so
  # aerc's notmuch worker enumerates the WHOLE physical tree (Gmail/* and
  # Logos/*) into every sidebar on top of the query-map virtual folders.
  # folders-exclude is DISPLAY-ONLY -- it does not affect :archive's file move,
  # which resolves archive= against maildir-store independently -- and hides
  # only the raw physical tree: the `~` prefix marks a regex, and no query-map
  # name starts with Gmail/Logos. Considered and rejected: a `folders`
  # whitelist, and per-account maildir-account-path -- the shared-~/Mail-root
  # architecture is intentional. (task 112 and its follow-up regression fix)
  foldersExclude = "~^Gmail,~^Logos";

  # Generator for the per-account aerc query-map files. Both accounts share the
  # same virtual-folder shape; the intentional asymmetries (Gmail's Spam folder
  # and the Proposed-* triage views) are visible as data at the call sites.
  mkQuerymap =
    { prefix, archiveName, extraFolders ? [ ], extraTriage ? [ ] }:
    builtins.concatStringsSep "\n" (
      [
        "INBOX=folder:${prefix}"
        "Sent=folder:${prefix}/.Sent"
        "Drafts=folder:${prefix}/.Drafts"
        "Trash=folder:${prefix}/.Trash"
        "${archiveName}=folder:${prefix}/.${archiveName}"
      ]
      ++ extraFolders
      ++ [
        "Unread=tag:unread AND folder:/${prefix}/"
        "Flagged=tag:flagged AND folder:/${prefix}/"
      ]
      ++ extraTriage
    )
    + "\n";
in
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
        # Plaintext-first is a kept decision (html-first considered and
        # rejected): text/html is one keypress away via :next-part -- see the
        # `view` binds below.
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

        # Tab/S-Tab account-tab switching, matching the Neovim <Tab>/<S-Tab>
        # buffer-nav reflex; <C-n>/<C-p> (global) remain as fallback aliases. (task 105)
        "<Tab>" = ":next-tab<Enter>";
        "<S-Tab>" = ":prev-tab<Enter>";

        g = ":select 0<Enter>";
        G = ":select -1<Enter>";
        "<C-d>" = ":next 50%<Enter>";
        "<C-u>" = ":prev 50%<Enter>";
        "<C-f>" = ":next 100%<Enter>";
        "<C-b>" = ":prev 100%<Enter>";

        # Actions
        # Native d/D/a/A are human-only paths by design: the PreToolUse
        # mail-guard hook can only gate the agent's own Bash calls, not aerc's
        # Go worker, so these keys sit outside the agent guardrail. D (bare
        # :delete, no confirm) and A (bulk archive) are hardened with a :prompt
        # confirm; d already prompts. Single-message archive (a) is
        # deliberately UNPROMPTED -- a reversible file move with low blast
        # radius, matching mail-client convention -- while A/d/D stay prompted
        # because they act on larger or irreversible blast radii.
        # (task 72 phase 9, recorded in handoffs/mail-29-runbook.md; task 112)
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
        # Group-scoped + hook-bypassing by design: never `mbsync -a`, which
        # would also touch the deferred Logos/Bridge account and (via a plain
        # `notmuch new`) re-trigger the preNew hook's own `mbsync -a`. Routed
        # through the single canonical flock-serialized `mail-sync` wrapper,
        # which runs `notmuch new --no-hooks` internally after a successful
        # mbsync -- no separate reindex call is needed here. Kept gmail-only
        # deliberately; `mail-sync logos`/`mail-sync both` is a trivial future
        # extension. (task 72 phase 9; task 109)
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

      # Proposed-* review views (email-classify's +proposed-* candidates).
      # Confirm gestures retag +confirmed-{delete,archive} and :exec email-classify
      # --append-approved {{.MessageId}} to queue the Message-ID into the APPROVED manifest
      # (wrapper-contract.md §6) -- they NEVER mutate inline and NEVER use aerc's native
      # :delete-message/:archive (those run in aerc's Go worker and would bypass both the
      # mail-guard hook and the manifest/approval flow entirely). Reject rescues to
      # +proposed-keep. d/a deliberately SHADOW the native single-delete/archive keys ONLY
      # within these three curated views, replacing them with the safe wrapper-routed
      # gesture; d/D/a/A keep their native (human-only) behavior everywhere else.
      # (task 72 phase 9)
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
        # <Enter> aliases :next-part: aerc has no native "Enter to select" part
        # concept -- moving the part selection IS what displays it (text/html
        # renders via the w3m [filters] entry). Trade-off: Enter no longer
        # scrolls the pager one line; <Space>/<C-d>/<C-u> page instead.
        "<Enter>" = ":next-part<Enter>";
        J = ":next<Enter>";
        K = ":prev<Enter>";

        # Same Tab/S-Tab account-switch aliases as `messages` above. The BIND
        # duplication is intentional and required (different bind scopes);
        # only the rationale comment lives once, in `messages`.
        "<Tab>" = ":next-tab<Enter>";
        "<S-Tab>" = ":prev-tab<Enter>";

        # Actions
        # `-c` closes this viewer tab at reply-open time, so post-send focus
        # returns to the message list instead of a stale viewer; it is a safe
        # no-op from the list context (the `messages` r/R stay bare :reply) and
        # orthogonal to `-a` (no double-archive). NOTE: `-a -c` as two separate
        # flags is the verified syntax; the bundled `-ac` form was NOT verified.
        r = ":reply -c<Enter>";
        R = ":reply -a -c<Enter>";
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
        # Native archive-on-reply: `:send -a` archives the exact replied-to
        # message captured by reference at :reply time -- immune to list
        # reflow / cursor drift, unlike the removed Subject-sniffing mail-sent
        # hook (do NOT reintroduce that hook: it would double-archive). `-a` is
        # inert (never archives) on :forward, a fresh :compose, and :recall, so
        # this rebind is safe on every send path. (task 113)
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
    # aerc accounts configuration. Rationale for the non-obvious settings
    # (kept at Nix level so nothing here perturbs the rendered file):
    #
    # maildir-store + multi-file-strategy (both accounts): required for aerc's
    # notmuch worker to perform real :archive/:delete file moves -- without
    # them the worker gates all mutations and returns errUnsupported, the
    # mechanism behind a prior silent :archive no-op. Forward-compat caveat:
    # upstream aerc master has deprecated maildir-store in favor of
    # enable-maildir, but the installed nixpkgs aerc 0.21.0 still uses
    # maildir-store; remove the two lines (or switch to enable-maildir) if/when
    # the aerc derivation is bumped past that upstream change. (task 112)
    #
    # OPEN RISK (unresolved, never live-verified): `multi-file-strategy =
    # act-dir` resolves the current folder from the open TAB name, and the
    # INBOX querymap alias is not a physical-folder key, so multi-file archive
    # from the INBOX tab may fail with "refusing to act on multiple files" --
    # see specs/112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md
    # finding-7.
    #
    # folders-exclude (both accounts): see the architectural note on the
    # `foldersExclude` let binding at the top of this file.
    #
    # check-mail ([gmail]): while-aerc-is-open convenience sync, secondary to
    # the systemd mail-sync-timer (the primary "sync even when closed"
    # mechanism). --no-wait makes a lock-contended call fail fast against
    # mail-sync's flock (the timer will pick up the sync shortly regardless)
    # rather than hanging aerc's "Checking for new mail..." indicator for up
    # to 300s; check-mail-timeout is raised from its 10s default so a normal,
    # uncontended network mbsync round-trip is not spuriously killed. Wiring
    # check-mail-cmd also makes the `u = ":check-mail<Enter>"` keybind
    # functional (it previously errored "checkmail: no command specified").
    # DECISION: [logos] check-mail is deliberately left UNWIRED pending a
    # decided check-mail failure-surfacing policy (see task 114); wiring it now
    # would add a second undifferentiated failure surface. (task 109; task 113)
    ".config/aerc/accounts.conf".text = ''
      [gmail]
      source = notmuch://~/Mail
      maildir-store = ~/Mail
      multi-file-strategy = act-dir
      query-map = ~/.config/aerc/querymap-gmail
      folders-exclude = ${foldersExclude}
      default = INBOX
      from = Benjamin Brast-McKie <benbrastmckie@gmail.com>
      copy-to = Sent
      archive = All_Mail
      outgoing = smtps://benbrastmckie@gmail.com@smtp.gmail.com:465
      outgoing-cred-cmd = secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com
      check-mail = 10m
      check-mail-cmd = mail-sync gmail --no-wait
      check-mail-timeout = 30s

      [logos]
      source = notmuch://~/Mail
      maildir-store = ~/Mail
      multi-file-strategy = act-dir
      query-map = ~/.config/aerc/querymap-logos
      folders-exclude = ${foldersExclude}
      default = INBOX
      from = Benjamin Brast-McKie <benjamin@logos-labs.ai>
      copy-to = Sent
      archive = Archive
      outgoing = smtp://benjamin@logos-labs.ai@127.0.0.1:1025
      outgoing-cred-cmd = secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai
    '';

    # aerc query maps: per-account virtual folders, generated by mkQuerymap
    # (see the let block above); Gmail's Spam folder and its Proposed-* triage
    # views are the intentional asymmetries, visible as data below.
    #
    # Query scoping rationale (applies identically to both accounts):
    #   - Account scoping uses notmuch `folder:` tokens instead of `tag:gmail`,
    #     aligning aerc with the canonical folder-scoping convention CLAUDE.md
    #     mandates for the /email wrapper contract. NOTE: `folder:Gmail*` glob
    #     syntax (as CLAUDE.md's prose currently shows it) does NOT work as a
    #     literal notmuch query -- it matches zero messages; verified
    #     empirically that only `folder:/Gmail/` (slash-delimited regex) or an
    #     exact `folder:Gmail/SubDir` path reproduces the expected counts.
    #     Flagged for a CLAUDE.md accuracy follow-up. (task 34 phase 5/F5)
    #   - INBOX uses the bare exact-match form `folder:Gmail`/`folder:Logos`
    #     (true maildir-folder membership) rather than `tag:inbox AND
    #     folder:/Gmail/`: notmuch.nix's postNew hook applies `+inbox` once at
    #     delivery and never removes it on archive, so `tag:inbox` is a
    #     permanent "was delivered" marker, not a live inbox-membership signal;
    #     and the `/Gmail/` regex over-matches `Gmail/.All_Mail`. Together the
    #     old query returned ~12,580 messages instead of the true ~85-message
    #     inbox. (task 110)
    #   - `Unread`/`Flagged`/`Proposed-*` intentionally REMAIN account-wide
    #     (`folder:/Gmail/` / `folder:/Logos/`): they are tag-driven
    #     triage/search views, not folder-membership views, and re-scoping
    #     `Proposed-*` to the inbox would silently hide proposed-tagged
    #     messages touched by a prior triage pass, undermining the review
    #     gate. Do not re-scope them to match INBOX. (task 110)
    ".config/aerc/querymap-gmail".text = mkQuerymap {
      prefix = "Gmail";
      archiveName = "All_Mail";
      extraFolders = [ "Spam=folder:Gmail/.Spam" ];
      extraTriage = [
        "Proposed-Delete=tag:proposed-delete AND folder:/Gmail/"
        "Proposed-Archive=tag:proposed-archive AND folder:/Gmail/"
        "Proposed-Unsure=tag:proposed-unsure AND folder:/Gmail/"
      ];
    };

    ".config/aerc/querymap-logos".text = mkQuerymap {
      prefix = "Logos";
      archiveName = "Archive";
    };
  };
}
