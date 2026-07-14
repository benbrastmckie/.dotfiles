---
next_project_number: 117
---

# TODO

Warning: 2 task(s) have no topic and will render under Uncategorized: 115, 116 (non-fatal)
## Task Order

*Updated 2026-07-14. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,77,115,116 | -- | nix-infrastructure, services, desktop, ... |
| 2 | 78 | 77 | desktop |

**Grouped by Topic** (indented = depends on parent):

### Nix Infrastructure

67 [NOT STARTED] — Migrate R environment back to stable nixpkgs once nixos-26.05 fix
68 [NOT STARTED] — The iso and usb-installer nixosConfigurations fail to build becau

### Services

19 [RESEARCHED] — install_setup_mcp_servers_web_development
23 [PLANNED] — install_simple_webcam_recording_software
43 [RESEARCHED] — install_forgejo_self_hosted_git
46 [RESEARCHED] — Investigate and fix Gmail OAuth2 token expiry - tokens keep expir

### Packaging

41 [BLOCKED] — reenable_pdf2docx_nixpkgs_fix
42 [BLOCKED] — reenable_jupytext_nixpkgs_fix

### Maintenance

15 [RESEARCHED] — configure_timezone_location_based

### Desktop

77 [NOT STARTED] — Verify and reconcile background-service behavior in the niri+GNOM
  └─ 78 [NOT STARTED] — Rewrite docs/niri.md to match the actual, settled niri+GNOME-stac

### Uncategorized

115 [NOT STARTED] — Consolidate and refactor the aerc email configuration (modules/ho
116 [NOT STARTED] — Investigate and safely remediate a misplaced non-mail filesystem 

## Tasks

### 116. Mail specs stray tree cleanup
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Dependencies**: None

**Description**: Investigate and safely remediate a misplaced non-mail filesystem tree at ~/Mail/specs/ (8.4MB, ~219 files) discovered during task 114. It is a stray copy of task-management/email-cleanup artifacts (TODO.md, state.json, ROADMAP.md, .meta-return.json, a full archive/ of dozens of email-cleanup task dirs, task dirs 027/029/072, and email-manifests/logos/ *.jsonl manifest+state data), created ~2026-07-13/14 by email-cleanup tooling running with cwd=~/Mail and writing RELATIVE specs/... paths there instead of into the repo. Impact: because modules/home/email/notmuch.nix sets the notmuch database path to ~/Mail, every 'notmuch new' walks all ~219 files and logs 'Ignoring non-mail file' for each (minor perf/noise cost). It is NOT inside a maildir folder, so mbsync never scans it and it is NOT a sync blocker (distinct from the task-114 in-maildir 'specs,U=67297' dir, which was already removed). SCOPE: (1) Determine provenance precisely -- which tool/run wrote it (candidates: /email cleanup for logos, tasks 027/029/072 tooling); confirm whether ANY file here is the ONLY copy of real data (esp. email-manifests/logos/*.jsonl and their .state.jsonl) vs. a stale duplicate of the repo's own specs/ tree -- diff against ~/.dotfiles/specs/ before removing anything. (2) Safely relocate any unique/valuable artifacts into the repo (or an appropriate location) and remove the rest; do NOT blindly rm 8.4MB that may contain unique manifests. (3) Add a durable guard so this cannot recur: e.g. a notmuch new.ignore / exclude entry for non-mail paths under ~/Mail, and/or fix the email-cleanup tooling that writes relative specs/ paths so it always writes absolute repo paths (root-cause). SAFETY: nothing here is a maildir message and mbsync does not touch it, so there is NO Expunge-Both server-deletion risk; but treat email-manifests/ data as potentially unique until proven duplicate. NON-GOALS: re-doing task 114; any live-mail mutation; touching actual maildir folders. Task type intentionally set to 'general' (filesystem cleanup + optional notmuch.nix guard), NOT the wrapper-only 'email' type, despite mail-related keywords.

---

### 115. Aerc config consolidation refactor
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Dependencies**: None

**Description**: Consolidate and refactor the aerc email configuration (modules/home/email/aerc.nix, 384 lines) for maintainability and coherence, WITHOUT changing behavior unless the plan makes an explicit justified decision. A complete self-contained session hand-off brief ALREADY EXISTS at specs/115_aerc_config_consolidation_refactor/reports/00_session-context-and-handoff.md and MUST be read first by the research phase and built forward from -- do not re-derive the history. That brief documents: (1) the full 2026-07-13/14 changelog (tasks 110-113 batch + follow-up fixes: INBOX querymap real-folder, compose format-flowed, enable :archive via maildir-store+act-dir, native :send -a flat archive-on-reply + systemd mail-sync timer, folders-exclude sidebar fix, :reply -c return-to-list, <Enter> part-cycle); (2) current architecture across aerc.nix/mbsync.nix/mail-sync.nix/notmuch.nix/mail-sync-timer.nix; (3) outstanding/deferred items (task 114 Gmail/.All_Mail duplicate-UID HIGH-RISK Expunge-Both remediation; 112/113 live-mail verification still user-pending; how check-mail should treat known-vs-real failures; the -a -c parser caveat; 17 accreted Task-NN comment markers to consolidate); (4) refactor goals (consolidate task-number comment archaeology into forward-looking docs; holistically reconsider folders-exclude-vs-folders-whitelist, text/plain-vs-text/html default, Enter-binding trade-off, logos check-mail, querymap de-duplication); (5) INVARIANTS to preserve (no agent live-mail mutation, Expunge-Both deletion danger, wrapper-only /email mutation, folder: token scoping, keep home-manager build green, no double-archive/tag:inbox regressions); (6) verification (build green + rendered-config semantic-equivalence diff + manual user checklist for TUI/live-mail). NON-GOALS: task 114 maildir remediation (separate task), redesigning behavior, home-manager switch or any live-mail action. This task is safe to orchestrate: it is config-refactor + build-verify only.

---

### 114. Gmail allmail duplicate uid remediation
- **Status**: [COMPLETED]
- **Task Type**: general
- **Dependencies**: None
- **Research**: [114_gmail_allmail_duplicate_uid_remediation/reports/01_duplicate-uid-diagnosis.md]
- **Plan**: [114_gmail_allmail_duplicate_uid_remediation/plans/01_duplicate-uid-remediation.md]
- **Summary**: [114_gmail_allmail_duplicate_uid_remediation/summaries/01_duplicate-uid-remediation-summary.md]

**Description**: Safely remediate the pre-existing duplicate-UID collision in ~/Mail/Gmail/.All_Mail that makes `mbsync gmail` (and thus `mail-sync gmail`) exit non-zero, which task 113 surfaced as a recurring aerc check-mail error banner and a failing mail-sync-timer unit. Root cause (live-verified 2026-07-14): two DIFFERENT messages both carry maildir UID tag ,U=15 in Gmail/.All_Mail/cur (subjects: "eNTERTAINMENT cENTER" and "A message from our CEO Nick Slape"); .mbsyncstate has a single legit mapping `34 15 S` (far UID 34 <-> near UID 15), so one file is a stray that erroneously got ,U=15 (likely from historical email dedup/migration tooling). HIGH RISK: gmail-all channel is `Expunge Both`, so removing/moving a synced local file can permanently delete a real message from Gmail All Mail. SAFE approach (validate first): identify the stray, then RENAME (never delete) it to strip its ,U=15 suffix -- collision clears, `Create Near` means the de-UID`d local-only file is never uploaded (no server duplicate), no file removed means no Expunge propagation (no server deletion), fully reversible. See reports/01_duplicate-uid-diagnosis.md for the full grounded analysis, open questions (confirm which file is the stray via read-only IMAP FETCH 34 or notmuch corroboration; notmuch re-index after rename; optional mail-sync.nix benign-duplicate guard; sweep for OTHER duplicate UIDs), and verification steps (mbsync exits 0, both messages still present in Gmail web UI, aerc banner clears). Do NOT rm or move any maildir file out of the folder. NON-GOAL: re-doing tasks 110-113.

---

### 113. Aerc archive on reply and periodic sync
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: Task 112
- **Research**: [113_aerc_archive_on_reply_and_periodic_sync/reports/01_archive-on-reply-and-periodic-sync.md]
- **Plan**: [113_aerc_archive_on_reply_and_periodic_sync/plans/01_archive-on-reply-periodic-sync.md]
- **Summary**: [113_aerc_archive_on_reply_and_periodic_sync/summaries/01_archive-on-reply-periodic-sync-summary.md]

**Description**: Deliver the end-user goal: replying to a message in aerc archives it, aerc updates immediately, and Gmail-in-the-browser stays in sync occasionally (non-immediate sync is acceptable per the user). TWO PARTS in modules/home/email/aerc.nix. (A) Archive-on-reply: a `[hooks]` `mail-sent` entry gated on the outgoing `Re:` subject prefix that runs `aerc :archive flat` on the selected (replied-to) message. This is ALREADY DRAFTED in the working tree (uncommitted) but only becomes functional once task 112 enables `:archive`. Verify it archives exactly the replied message and does nothing on a fresh `:compose` (whose subject is not `Re:`). Re-evaluate the known caveat that it archives the list-SELECTED message (correct in the normal select->r->reply->send flow) and decide whether to keep as-is or harden. (B) Periodic sync: nothing currently runs mbsync on a schedule — sync only fires via aerc's `$`/`u` keys or the notmuch preNew hook. Add occasional automatic sync through the existing serialized, flock-guarded `mail-sync` wrapper (from task 109, modules/home/email/mail-sync.nix): either aerc `[account]` `check-mail = 10m` + `check-mail-cmd = mail-sync gmail` (syncs while aerc is open) and/or a systemd user timer running `mail-sync both` (syncs even when aerc is closed). Prefer the least surprising option; document the choice. DEPENDS ON task 112 (archive must actually work for archive-on-reply to be meaningful, and for the sync to have an archive to propagate). VERIFY end-to-end: reply to a test message, confirm it leaves the aerc INBOX immediately, then let the periodic sync run (or trigger `mail-sync gmail`) and confirm in the Gmail browser that the message is archived (out of inbox, still in All Mail).

---

### 112. Aerc enable folder move archive
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: Task 110
- **Research**: [112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md]
- **Plan**: [112_aerc_enable_folder_move_archive/plans/01_enable-archive-action.md]
- **Summary**: [112_aerc_enable_folder_move_archive/summaries/01_enable-archive-action-summary.md]

**Description**: Enable a real, server-propagating archive action in aerc (the `a`/`A` keys and, later, the reply hook). Currently aerc's notmuch-backend `:archive`/`:delete` are DISABLED because they require `maildir-store` to be set in accounts.conf and it is unset (modules/home/email/aerc.nix, home.file accounts.conf). So `a = :archive flat` is a silent no-op — verified: replied messages remain in Gmail/cur with tag:inbox, unmoved. FIX in accounts.conf for BOTH [gmail] and [logos]: add `maildir-store = ~/Mail`, and add `multi-file-strategy = act-dir`. The multi-file-strategy is REQUIRED, not optional: a live probe shows 35 of the 85 inbox messages ALSO have a copy in All_Mail (Gmail's label model), and aerc's default `refuse` strategy will refuse to archive multi-file messages; `act-dir` scopes the operation to the file in the current (inbox) folder. Archive semantics with this in place: `:archive flat` moves the inbox-folder file to the account's `archive=` folder (All_Mail for gmail, Archive for logos), and mbsync's `gmail-inbox` channel — which is `Expunge Both` (mbsync.nix) — propagates that as an INBOX-label removal on Gmail at the next sync. This matches the repo's already-proven mutation in email-archive-confirmed.nix (`himalaya message move All_Mail <id> -f INBOX`). DEPENDS ON task 110 so that an archived (moved-out-of-inbox) message actually disappears from the now-folder-based INBOX view. VERIFY CAREFULLY ON LIVE MAIL before trusting broadly (85 real messages, 35 multi-file): archive ONE ordinary message and ONE known multi-file message, run `mail-sync gmail`, and confirm in the Gmail browser that each left the inbox and remains in All Mail (i.e. archived, not trashed). Also review whether the existing `a`/`A` :prompt confirmations and the Proposed-* wrapper-routed gestures need any adjustment given archive is now live. Do NOT wire archive-on-reply or periodic sync here (task 113).

---

### 111. Aerc compose line wrapping
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [111_aerc_compose_line_wrapping/reports/01_aerc-compose-flowed-verification.md]
- **Summary**: [111_aerc_compose_line_wrapping/plans/01_verify-compose-flowed.md]

**Description**: Stop aerc-composed/replied email from hard-wrapping at ~72-80 columns; lines should stay soft-wrappable so recipients' clients reflow to their own width. Root cause (live-verified): the compose editor is nvim, and nvim's built-in `mail` ftplugin sets textwidth=72 and formatoptions=jtcql (the `t` flag auto-hard-wraps as you type). FIX in modules/home/email/aerc.nix `[compose]` (extraConfig.compose): (1) `editor = "nvim -c 'setlocal textwidth=0 formatoptions-=t'"` so the compose buffer never inserts hard breaks regardless of the (unmanaged) nvim config; (2) `format-flowed = true` so aerc emits RFC3676 `text/plain; format=flowed`, letting long unwrapped lines reflow on the receiving side instead of appearing broken at a fixed column. Both are complementary and both are needed. NOTE: these two edits are ALREADY DRAFTED in the working tree (uncommitted) as of this task's creation — this task is to verify and commit them, not author from scratch. Independent of the inbox/archive/sync tasks (110/112/113). VERIFY: `home-manager build --flake .#benjamin`; send a test message to yourself with a long paragraph and confirm (a) no hard line breaks were inserted and (b) the sent message carries a `Content-Type: text/plain; format=flowed` header. Then commit the aerc.nix compose changes.

---

### 110. Aerc inbox querymap real folder
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [110_aerc_inbox_querymap_real_folder/reports/01_inbox-querymap-real-folder.md]
- **Plan**: [110_aerc_inbox_querymap_real_folder/plans/01_inbox-querymap-real-folder.md]
- **Summary**: [110_aerc_inbox_querymap_real_folder/plans/01_inbox-querymap-real-folder.md]

**Description**: Fix the aerc INBOX virtual folder so it reflects the real inbox. In modules/home/email/aerc.nix the querymaps define `INBOX=tag:inbox AND folder:/Gmail/` (querymap-gmail) and `INBOX=tag:inbox AND folder:/Logos/` (querymap-logos). This is wrong on two counts: (1) `tag:inbox` is applied ONCE at delivery by notmuch.nix postNew (`notmuch tag +inbox`) and is never removed on archive, and (2) `folder:/Gmail/` is a notmuch regex that also matches Gmail/.All_Mail. So the INBOX tab returns everything ever tagged inbox, including the ~64k-message archive. Live-verified on 2026-07-13: `notmuch count folder:Gmail` = 85 (the true inbox) vs `notmuch count 'tag:inbox AND folder:/Gmail/'` = 12,580. This is the root cause of the user's report that replied/handled mail never leaves the aerc inbox. FIX: change the INBOX querymap entries to the exact inbox maildir folder — `INBOX=folder:Gmail` and `INBOX=folder:Logos` (bare exact-match form = INBOX-only, per CLAUDE.md's verified folder-token table and the email-census wrapper which already treats INBOX as `folder:$ACCOUNT_FOLDER`). This makes the tab show the true inbox AND makes any message moved out of the inbox folder (i.e. archived) disappear from the view. Also decide and document whether the Unread/Flagged/Proposed-* querymap entries (which also use `folder:/Gmail/` = whole-account) should remain account-wide or be scoped to the inbox — they are a separate concern from INBOX and account-wide is likely correct for search/triage. NON-GOAL: enabling archive itself (task 112) and periodic sync (task 113). VERIFY: `home-manager build --flake .#benjamin`; open aerc and confirm the INBOX tab shows ~85 messages, not ~12k. Low-risk: this is a read-only view definition change with no mail mutation.

---

### 109. Serialized group scoped mail sync wrapper
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [109_serialized_group_scoped_mail_sync_wrapper/reports/01_serialized-mail-sync-wrapper.md]
- **Plan**: [109_serialized_group_scoped_mail_sync_wrapper/plans/01_serialized-mail-sync-wrapper.md]
- **Summary**: [109_serialized_group_scoped_mail_sync_wrapper/summaries/01_serialized-mail-sync-wrapper-summary.md]

**Description**: Provide a single canonical, serialized, group-scoped, hook-safe mail-sync command in the email module (modules/home/email/) that every sync trigger invokes, eliminating the concurrent/overlapping mbsync invocations that cause `duplicate UID` Maildir corruption and abort server sync (exit 1). Root cause: multiple independent triggers run mbsync with no mutual exclusion, and some use the forbidden `mbsync -a` (all-channels) form plus hook-ful `notmuch new` — whose pre-new hook itself runs `mbsync gmail logos` — so a single action can launch two overlapping mbsync runs writing the same maildir (e.g. Gmail/.All_Mail), producing duplicate-UID errors. The dotfiles email module already codifies the correct doctrine (notmuch.nix: never `mbsync -a`, group-scoped only; aerc.nix: `$` rebound to a group-scoped + hook-bypassing form; wrappers use `notmuch new --no-hooks`), but the invariant is enforced per-caller and can still be bypassed. Current trigger inventory: the notmuch pre-new hook (`mbsync gmail logos`), aerc's `$` keybind, the Neovim `<leader>me`/`<leader>mN` mappings (which still call `mbsync -a` + hook-ful `notmuch new`), and manual invocation. Deliverable: a nix-built wrapper (e.g. `mail-sync`) that (1) takes an flock on one lockfile so no two mbsync runs can overlap regardless of trigger; (2) is group-scoped only (`mbsync gmail`/`mbsync logos`) and structurally incapable of `mbsync -a`; (3) reindexes with `notmuch new --no-hooks` to avoid re-triggering the pre-new mbsync loop; (4) on the known `duplicate UID` failure prints actionable remediation (or invokes a detector/repair helper alongside census.nix). Then repoint every trigger — the notmuch pre-new hook and aerc's `$`, plus (via a companion Neovim-repo task) `<leader>me`/`<leader>mN` — at this one wrapper, so the never-`mbsync -a`, never-concurrent, `--no-hooks` invariants cannot be bypassed from any editor, keybind, or hook. Non-goals: the one-time maildir data repair of an existing duplicate-UID collision, and the Neovim-side change to call the wrapper (separate nvim-repo task). Verify with `nix flake check` and a concurrency test: two near-simultaneous invocations must serialize rather than corrupt.

---

### 78. Niri documentation rewrite
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: Task 74, Task 75, Task 76, Task 77

**Description**: Rewrite docs/niri.md to match the actual, settled niri+GNOME-stack configuration after tasks 74-77 land. The current doc is ~60% stale/aspirational: it is dominated by PaperWM material, cross-references archived specs (specs/reports/012_niri_with_gnome_integration.md and specs/plans/010_niri_gnome_portal_integration.md) that no longer drive the config, and its keybinding tables contradict config/config.kdl — e.g. the doc claims Mod+m = maximize and Mod+r = resize mode, but the config binds Mod+M = spotify and Mod+R = switch-preset-column-width; the doc's window-rule examples also use the old match{} block syntax instead of the current top-level window-rule blocks. Fix: (a) trim or clearly quarantine the PaperWM content so it is not presented as the active setup; (b) regenerate the keybinding reference directly from config/config.kdl so it is accurate; (c) remove dead spec cross-references; (d) add a concise 'GNOME-stack hybrid architecture' section documenting the two-layer model — GNOME services/backends (gnome-keyring, polkit-gnome, xdg portals, gnome-settings-daemon, gnome-control-center, Nautilus) vs niri surface tools (waybar, swaybg, mako, swaylock/swayidle, brightnessctl) — and how they compose. Depends on 74-77 so it documents the final state (including whatever reconciliation task 77 decides).

---

### 77. Niri gnome service reconciliation
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: Task 74, Task 75, Task 76

**Description**: Verify and reconcile background-service behavior in the niri+GNOME hybrid session, resolving overlaps rather than leaving gaps. Depends on tasks 74-76 being applied so the session reflects its intended final state. (1) xwayland-satellite: pkgs.xwayland-satellite is installed (modules/system/packages.nix:19; the inline comment claims auto-detection since niri 25.08). Confirm it actually auto-spawns and exports DISPLAY in the niri session — run 'echo $DISPLAY' in a niri terminal and launch an X11 app (e.g. zoom-us). If DISPLAY is empty, add an explicit xwayland-satellite spawn and DISPLAY export. (2) NOTIFICATIONS: services.mako (modules/home/desktop/mako.nix) is enabled and is expected to D-Bus-activate on org.freedesktop.Notifications without explicit startup. Confirm with 'notify-send test' in the niri session; if nothing appears, add an explicit mako startup. (3) gsd/swayidle OVERLAP: gnome-settings-daemon is enabled system-wide (services.gnome.gnome-settings-daemon in modules/system/desktop.nix) while swayidle is spawned in config.kdl:261 for idle-lock/suspend/before-sleep. Some gsd helpers (notably gsd-power for lid-close and idle) may partially run under niri and double-act with swayidle/logind (e.g. double-suspend, or fighting over lid events). Confirm there is no double-suspend or conflicting idle/lid behavior; if there is, disable the overlapping gsd component for the niri session or reconcile logind/swayidle timeouts. Document findings inline and adjust configuration as needed.

---

### 71. Design ai email management workflow
- **Status**: [EXPANDED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: Task 46
- **Research**:
  - [071_design_ai_email_management_workflow/reports/01_ai-email-workflow.md]
  - [071_design_ai_email_management_workflow/reports/02_team-research.md]
  - [071_design_ai_email_management_workflow/reports/03_team-research.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-a-findings.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-b-findings.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-c-findings.md]
  - [071_design_ai_email_management_workflow/reports/02_teammate-d-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-a-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-b-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-c-findings.md]
  - [071_design_ai_email_management_workflow/reports/03_teammate-d-findings.md]
- **Plan**:
  - [071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md]
  - [071_design_ai_email_management_workflow/plans/02_email-workflow-implementation.md]

**Description**: Design a streamlined AI-assisted email management workflow across the existing dual-account stack (Gmail via OAuth2 + Protonmail via Bridge; Himalaya CLI, aerc TUI, notmuch, mbsync) and the connected Anthropic Gmail connector (gmail.mcp.claude.com). Goal: agents that clean up the inbox (remove junk, unsubscribe noise) and draft responses for review, with the largest task being a safe one-time purge of backlogged mail - delete junk, archive what is worth keeping, delete all else. Key finding from the seed report: the Anthropic Gmail connector is read-only + draft-creation (cannot send/archive/delete), so backlog cleanup must be driven through the local stack (notmuch/Himalaya/mbsync) under a drafts-first, human-approved, guardrailed agent harness with Gmail trash-then-expunge semantics. Follow-up /research 71 should resolve the seven open questions (harness form-factor, approval UX, account scope, backlog scale census, guardrail enforcement, classifier quality, injection hardening) before planning.

---

### 68. Fix broken zfs kernel installer builds
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None

**Description**: The iso and usb-installer nixosConfigurations fail to build because zfs-kernel is broken on the current kernel (7.1.1): installation-cd-minimal.nix pulls in ZFS via supportedFilesystems. Restore buildable installer images by one of: disabling ZFS in the installer (boot.supportedFilesystems exclude zfs), pinning a kernel that ZFS supports for the installer only, or waiting for upstream zfs compatibility then bumping. Pre-existing issue surfaced during task 66 final audit; affects both pre- and post-refactor trees equally (not a regression).

---

### 67. Migrate r env back to stable nixpkgs
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None

**Description**: Migrate R environment back to stable nixpkgs once nixos-26.05 fixes r-V8. The R wrapper in configuration.nix (rWrapper with survival/tidyverse/gtsummary/mice/languageserver/styler/lintr etc.) is currently sourced from pkgs-unstable as a workaround: stable nixpkgs-26.05 ships r-V8 8.0.1 which expects ICU 78 but stable provides ICU 76.1, with no standalone v8 package to bridge it, causing a link failure (undefined icu_78 symbols) that cascades through gt -> gtsummary -> R-wrapper -> system-path and breaks the whole hamsa build. The fix gate is upstream: nixpkgs-26.05 must align r-V8/nodejs-slim libv8/ICU (version bump or backport). Test procedure: after a ./update.sh --update advances the 26.05 pin, flip two lines in configuration.nix back (pkgs-unstable.rWrapper -> rWrapper, pkgs-unstable.rPackages -> rPackages) and run nixos-rebuild build --flake .#hamsa; if r-V8 builds, migrate back and keep it, otherwise revert the flip and wait for the next stable advance. Restores the binary-cache-hit benefit of the task 61 stable pin for the heavy R+texlive stack. Follow-up of task 61.

---

### 46. Investigate fix gmail oauth2 token expiry
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research_report**: [046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md]

**Description**: Investigate and fix Gmail OAuth2 token expiry - tokens keep expiring requiring repeated re-authentication with himalaya account configure gmail

---

### 43. Install forgejo self hosted git
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research**: [43_install_forgejo_self_hosted_git/reports/research-001.md]

---

### 42. Reenable jupytext nixpkgs fix
- **Status**: [BLOCKED]
- **Task Type**: general
- **Topic**: packaging
- **Dependencies**: None

---

### 41. Reenable pdf2docx nixpkgs fix
- **Status**: [BLOCKED]
- **Task Type**: general
- **Topic**: packaging
- **Dependencies**: None

---

### 23. Install simple webcam recording software
- **Status**: [PLANNED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research**: [23_install_simple_webcam_recording_software/reports/research-001.md]
- **Plan**: [23_install_simple_webcam_recording_software/plans/implementation-001.md]

---

### 19. Install setup mcp servers web development
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: None
- **Research**: [19_install_setup_mcp_servers_web_development/reports/research-001.md]

---

### 15. Configure timezone location based
- **Status**: [RESEARCHED]
- **Task Type**: general
- **Topic**: maintenance
- **Dependencies**: None
- **Research**: [15_configure_timezone_location_based/reports/research-001.md]
