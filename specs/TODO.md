---
next_project_number: 82
---

# TODO

## Task Order

*Updated 2026-07-04. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,69,77,81 | -- | nixos-config, nix-infrastructure, desktop, ... |
| 2 | 78 | 77 | desktop |

**Grouped by Topic** (indented = depends on parent):

### Nixos Config

81 [RESEARCHED] — Design and orchestrate a systematic reorganization of the NixOS/H

### Nix Infrastructure

67 [NOT STARTED] — Migrate R environment back to stable nixpkgs once nixos-26.05 fix
68 [NOT STARTED] — The iso and usb-installer nixosConfigurations fail to build becau
69 [NOT STARTED] — Consolidate the dual home-manager setup so there is a single sour

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

## Tasks

### 81. Reorganize nixos dotfiles repository design
- **Status**: [RESEARCHED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**:
  - [081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md]
  - [081_reorganize_nixos_dotfiles_repository_design/reports/02_teammate-a-findings.md]
  - [081_reorganize_nixos_dotfiles_repository_design/reports/02_teammate-b-findings.md]
  - [081_reorganize_nixos_dotfiles_repository_design/reports/02_teammate-c-findings.md]
  - [081_reorganize_nixos_dotfiles_repository_design/reports/02_teammate-d-findings.md]
  - [081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md]

**Description**: Design and orchestrate a systematic reorganization of the NixOS/Home Manager dotfiles repository: research and design the ideal target directory layout (modules/, hosts/, lib/, overlays/, packages/, config/, secrets/, wallpapers/, docs/, root files), then decompose the refactor into ordered implementation subtasks, creating each subtask with its own seed research report. A comprehensive repo review has already been completed and is seeded as this task's first research report.

---

### 80. Verify logos wrapper contract close phase6
- **Status**: [COMPLETED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: Task 79
- **Research**: [080_verify_logos_wrapper_contract_close_phase6/reports/01_contract-verification-research.md]
- **Plan**: [080_verify_logos_wrapper_contract_close_phase6/plans/01_phase6-closure-plan.md]
- **Summary**: [080_verify_logos_wrapper_contract_close_phase6/summaries/01_phase6-closure-report.md]

**Description**: Close out the cross-repo Phase-6 loop for email multi-account by LIVE-VERIFYING the task-79 wrapper contract against a switched-in system and producing the closure note the nvim email/ extension consumes. Reciprocal of specs/079_email_wrappers_multi_account/reports/03_nvim-extension-followup-handoff.md (nvim task 815 Phases 1-5 landed; its Phase 6 was [BLOCKED] only on task 79 going live). Task 79 is [COMPLETED] and committed, BUT as of task creation it is NOT yet switched in — the live PATH binary ~/.nix-profile/bin/email-census still reports `--account <gmail> Reserved; only "gmail" is accepted`, i.e. the OLD Gmail-only build. HARD MANUAL PRECONDITION (external to this task; the user runs it): `home-manager switch --flake .#benjamin` to make the task-79 --account-aware wrappers live. This task MUST first check `email-census --help` and if it does NOT show `--account <gmail|logos>` (still shows the reserved gmail-only text), HALT immediately with a clear message telling the user to run home-manager switch first — do not attempt the Logos exercise against the stale binary. SCOPE (all read-only / dry-run — NEVER pass --execute; this is verification, not mutation): (1) Confirm the switch applied: `email-census --help` shows the real `--account <gmail|logos>` enum. (2) Confirm rows 1-9 of the contract table in report 03 §2 against BOTH the live wrappers and the landed modules/home/email/agent-tools.nix source: every wrapper accepts --account <gmail|logos>; default is gmail; unknown account (e.g. --account work) is rejected with an actionable error, never coerced to gmail; Gmail scope tokens unchanged (inbox folder:Gmail, archive folder:Gmail/.All_Mail); Logos scope tokens inbox folder:Logos, archive folder:Logos/.Archive with NO .All_Mail and NO .Spam; Logos real folders .Sent/.Archive/.Drafts/.Trash (dot-prefixed maildir++); account scope resolved by folder: queries EXCLUSIVELY (tag:logos/tag:gmail are inert — must not be used); mbsync channels per-account (gmail->mbsync gmail, logos->mbsync logos, never mbsync -a); task 79 added NO new binaries (so hooks/mail-guard.sh allowlist needed no change). Record the EXACT --account flag spelling actually shipped (guard against a spelling shift during task-79 impl) and flag any divergence from what the nvim extension assumed. (3) Exercise /email --logos end-to-end LIVE against the real Logos maildir using only the allowlisted wrappers: email-census --account logos (folder counts non-empty and correct: expected roughly INBOX/Sent/Archive/Drafts/Trash per report 02), email-classify --account logos --limit <small> (read/tag-only), and a SMALL email-archive-confirmed / email-delete-confirmed run in DRY-RUN only (no --execute, no --confirm-manifest) to confirm folder:Logos and folder:Logos/.Archive scoping resolve correctly and the nvim precondition gate would now PASS. (4) DELIVERABLE — write a ready-to-apply closure note (to this task's reports/ dir) that the nvim side consumes to refresh ~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md (§2/§11): include the confirmed real --account enum, the per-account folder-token table (Gmail inbox/archive; Logos inbox folder:Logos / archive folder:Logos/.Archive / folders .Sent/.Archive/.Drafts/.Trash / no All_Mail/Spam), the mbsync channel mapping, the no-new-binaries fact, the rows-1-9 pass/divergence results, and an explicit statement of whether the /email --logos precondition gate now passes. OUT OF SCOPE (belongs to the nvim repo, created separately by the user via /spawn 815): editing wrapper-contracts.md / archive-mode-risk.md and flipping the task-815 plan Phase 6 marker [BLOCKED]->[COMPLETED] — this task only PRODUCES the note those edits apply. VERIFY: this task's own success = precondition-gate check performed, rows 1-9 confirmed (or divergences documented), live /email --logos census+classify+dry-run exercised, and the closure note written and self-consistent. No home-manager switch, no --execute mutation, no nvim-repo file edits performed by this task.

---

### 79. Email wrappers multi account
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: Task 72
- **Research**:
  - [079_email_wrappers_multi_account/reports/01_nvim-extension-handoff.md]
  - [079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md]
  - [079_email_wrappers_multi_account/reports/03_nvim-extension-followup-handoff.md]
- **Plan**: [079_email_wrappers_multi_account/plans/02_wrapper-multi-account.md]
- **Summary**: [079_email_wrappers_multi_account/summaries/02_wrapper-multi-account-summary.md]

**Description**: Extend the five email agent wrapper binaries in modules/home/email/agent-tools.nix to support the Logos (Protonmail Bridge) account, generalizing the Gmail-only task-72 contract into real per-account branching (foundation for future multi-account). CRITICAL FRAMING — the Logos BACKEND ALREADY EXISTS as deferred task-72 scaffolding; the SOLE gap is the wrapper binaries. Already present: mbsync.nix:121-197 has a full `logos` IMAPAccount (Protonmail Bridge 127.0.0.1:1143, secret-tool service protonmail-bridge) + Group logos (channels logos-inbox/sent/drafts/trash/archive/labels/folders); notmuch.nix:26-31 tags +logos and auto-tags folder:Logos/.Sent and folder:Logos/.Trash (other_email=benjamin@logos-labs.ai); misc.nix:19-24 creates ~/Mail/Logos/{INBOX,Sent,Drafts,Trash,Archive} (physically present); aerc.nix:237 has a [logos] account + querymap-logos virtual folders (INBOX=tag:inbox AND tag:logos, Sent/Drafts/Trash/Archive=folder:Logos/.*); himalaya has a configured `logos` account (Maildir+SMTP, verified via himalaya account list); protonmail.nix enables the protonmail-bridge service. THE GAP: the five wrappers (email-census, email-classify, email-archive-confirmed, email-delete-confirmed, email-unsubscribe-extract) hard-reject --account != gmail (agent-tools.nix:70-72) and hardcode Gmail everywhere (folder:Gmail queries, mbsync gmail reconcile, ~/Mail/Gmail/ maildir path at line 175, himalaya -a gmail, Gmail census folders .All_Mail/.Sent/.Trash/.Spam/.Drafts). SCOPE — real per-account branching in agent-tools.nix ONLY: (1) accept --account logos in the shared preamble gate (keep gmail as default; still reject unknown accounts with the existing actionable error); (2) parameterize the notmuch folder/tag scope — gmail: folder:Gmail + tag:gmail; logos: folder:Logos + tag:logos (note aerc's INBOX view uses `tag:inbox AND tag:logos`), with the default QUERY resolved per account; (3) census counts must use the Logos folder set actually synced locally (INBOX/Sent/Drafts/Trash/Archive per Group logos + misc.nix), NOT Gmail's .All_Mail/.Spam set — Proton is folder-based, not Gmail's label/All-Mail model; implementer MUST verify exact local folder names first via `notmuch search --output=folders folder:Logos` before hardcoding; (4) maildir path resolution ~/Mail/Gmail/ -> ~/Mail/Logos/ (the rel="${filepath#*/Mail/Gmail/}" line 175); (5) mbsync reconcile step in the sync/thaw path: `mbsync gmail` -> `mbsync logos` (the group already exists) for the logos account, preserving the NEVER-`mbsync -a` invariant that keeps the accounts isolated; (6) himalaya envelope list and any himalaya mutation: -a gmail -> -a logos; (7) delete/archive recipe must respect Proton semantics — Proton has a REAL Archive folder and Trash-is-a-real-move (unlike Gmail's label model where IMAP delete leaves the message in All_Mail, the task-72 correctness concern): archive = move to Logos/Archive, delete = move to Logos/Trash (then optional expunge), still IMAP/maildir-level Himalaya, NEVER a raw filesystem rm against Maildir. PRESERVE ALL task-72 SAFETY INVARIANTS unchanged: dry-run-by-default, --execute + --confirm-manifest <sha256> gate, MAX_BATCH_SIZE=50 frozen, PLAN_EXPIRY_DAYS mtime-preserve, wrapper-only mutation. NOTE: the working tree already has a partial hand-edit adding Proton senders (noae@protonmail.com, rob.mckie1235@proton.me, andy.stace@protonmail.com) to CUSTOM_KEEP_SENDERS at agent-tools.nix:402-403 — reconcile/keep it. CONTRACT REVISION: this revises the frozen task-72 wrapper contract (the --account gmail reservation becomes a real per-account dimension) — document the contract change in the task summary. OUT OF SCOPE (handled separately by the user in the ~/.config/nvim email/ extension with another agent; a handoff report is written to this task's reports/01_nvim-extension-handoff.md): the skill-email-cleanup account-selector/routing UX (e.g. /email --logos or --account), Logos-tuned classify preferences, command help text, and the mail-guard.sh PreToolUse allowlist. VERIFY: home-manager build --flake .#benjamin succeeds with the branched wrappers; email-census --account logos runs a dry-run census against the real Logos folders; wrappers still reject unknown accounts; the Gmail (default) path is byte-for-byte behaviorally unchanged.

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

### 76. Niri laptop hardware keys
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: None
- **Research**: [076_niri_laptop_hardware_keys/reports/01_niri-hardware-keys.md]
- **Plan**: [076_niri_laptop_hardware_keys/plans/01_niri-hardware-keys.md]
- **Summary**: [076_niri_laptop_hardware_keys/summaries/01_niri-hardware-keys-summary.md]

**Description**: Add laptop hardware-key handling for the niri session. This machine is a laptop (primary output eDP-1 at 2560x1600, per modules/home/desktop/kanshi.nix). In the GNOME session gnome-settings-daemon (gsd-media-keys) handles brightness function keys, but niri owns keybindings so gsd will NOT grab them — currently nothing controls display brightness in the niri session: there are no XF86MonBrightnessUp/Down binds in config/config.kdl and brightnessctl is not installed. Fix: add pkgs.brightnessctl and bind XF86MonBrightnessUp and XF86MonBrightnessDown in config/config.kdl (e.g. spawn brightnessctl set 5%+ and brightnessctl set 5%-; consider a small floor to avoid blacking out the panel). Also confirm the existing XF86Audio volume/mute binds (wpctl, config.kdl:181-183) behave correctly in the niri session. GNOME backend unchanged. VERIFY: after switch, brightness up/down keys visibly adjust the laptop panel in the niri session.

---

### 75. Niri keybinding dependencies
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: None
- **Research**: [075_niri_keybinding_dependencies/reports/01_niri-keybinding-deps.md]
- **Plan**: [075_niri_keybinding_dependencies/plans/01_niri-keybinding-deps.md]
- **Summary**: [075_niri_keybinding_dependencies/summaries/01_niri-keybinding-deps-summary.md]

**Description**: Make every keybinding in config/config.kdl resolve to an installed binary in the niri session (GNOME stack unaffected). (1) grimshot MISSING: Mod+Shift+S (config.kdl:169) and Print (config.kdl:170) spawn 'grimshot', which is in no package list, so full-screen and area screenshots via those keys fail. Fix: add pkgs.sway-contrib.grimshot to packages, OR rewrite both binds to the grim/slurp form already used by Mod+Shift+A (config.kdl:171), which works because grim, slurp, and satty are already present. (2) playerctl MISSING: XF86AudioPlay / XF86AudioNext / XF86AudioPrev (config.kdl:184-186) call playerctl, which is not installed, so media-transport keys fail. Fix: add pkgs.playerctl. (3) Mod+C WRONG BINARY: config.kdl:165 spawns 'code', but only vscodium is installed (its binary is 'codium', not 'code'). Fix: change the bind to spawn 'codium'. Note the XF86Audio volume/mute binds already use wpctl correctly and need no change. VERIFY: after switch, exercise each affected key (area+full screenshot, play/next/prev, Mod+C) in the niri session.

---

### 74. Niri session startup services
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: None
- **Research**: [074_niri_session_startup_services/reports/01_niri-startup-services.md]
- **Plan**: [074_niri_session_startup_services/plans/01_niri-startup-services.md]
- **Summary**: [074_niri_session_startup_services/summaries/01_niri-startup-services-summary.md]

**Description**: Fix the niri-session runtime services that are configured but never actually started, so a niri login (dual-session with GNOME via GDM) is usable on first try. All three fixes are niri-session-only; GNOME remains the backend. (1) WAYBAR NOT STARTED: modules/home/desktop/waybar.nix defines programs.waybar settings but sets no systemd.enable, and config/config.kdl has no spawn; waybar is not D-Bus-activatable so nothing launches it, yet layout.struts reserves 32px at top (config.kdl:57), producing an empty gap with no bar/tray/clock/battery. Fix: add spawn-at-startup "waybar" to the autostart section of config/config.kdl. Prefer this over programs.waybar.systemd.enable, which binds to graphical-session.target and would also spawn a stray second bar inside the GNOME session. (2) NO POLKIT AGENT: polkit_gnome is commented out at modules/system/packages.nix:32 and never started. In the GNOME session gnome-shell IS the polkit authentication agent, but niri has none, and gnome-keyring is NOT a polkit agent. GUI privilege escalation (mounting disks, some Settings actions, updates) silently fails. Fix: install pkgs.polkit_gnome and spawn-at-startup the agent binary (<polkit_gnome>/libexec/polkit-gnome-authentication-agent-1) in config/config.kdl. (3) WALLPAPER BROKEN: config.kdl:250 runs swaybg -i ~/.wallpapers/current; niri spawns without a shell so ~ is NOT expanded, and ~/.wallpapers/current is created by no module (only /etc/wallpapers/riverside.jpg exists, via modules/system/desktop.nix:33). Fix: point swaybg at the absolute path /etc/wallpapers/riverside.jpg (or wrap the spawn in sh -c so ~ expands). VERIFY: nixos-rebuild + home-manager switch, then log into the niri session and confirm the bar appears, the wallpaper draws, and a privileged GUI action (e.g. mounting a disk in GNOME Disks) shows an authentication dialog.

---

### 73. Gnome wayland focus follows mouse keyboard override
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: desktop
- **Dependencies**: None
- **Research**: [073_gnome_wayland_focus_follows_mouse_keyboard_override/reports/01_focus-follows-mouse-keyboard-override.md]
- **Plan**: [073_gnome_wayland_focus_follows_mouse_keyboard_override/plans/01_mouse-follows-focus-extension.md]
- **Summary**: [073_gnome_wayland_focus_follows_mouse_keyboard_override/summaries/01_mouse-follows-focus-extension-summary.md]

**Description**: Research (do not implement) how to make GNOME/Mutter focus behavior on WAYLAND stop snapping focus back to the window under the mouse pointer. DESIRED BEHAVIOR: moving the mouse onto a window switches focus to it (focus-follows-mouse), BUT after using a keybinding to switch focus to a different window, focus must STAY on the keyboard-selected window and NOT jump back to whatever window the (stationary) mouse happens to be hovering over. SYMPTOM: currently whatever window the mouse hovers over holds focus no matter what; keyboard focus switches are immediately overridden by pointer position. ENVIRONMENT: GNOME on Wayland (XDG_SESSION_TYPE=wayland, Mutter compositor); config is Home Manager dconf in modules/home/desktop/gnome.nix. PRIOR FAILED ATTEMPT (important — the obvious settings are ALREADY set and did NOT fix it): org/gnome/desktop/wm/preferences focus-mode="sloppy" (gnome.nix:66) and org/gnome/mutter focus-change-on-pointer-rest=false (gnome.nix:88). Research MUST go beyond these two keys since they are the failed attempt. Investigate: (1) exact semantics of focus-change-on-pointer-rest and whether =true (wait for pointer to REST before changing focus) actually helps the keyboard-override case, vs =false; (2) difference between focus-mode 'sloppy' vs 'mouse' vs 'click' and how each interacts with keyboard focus commands under Mutter/Wayland specifically; (3) whether Mutter re-evaluates pointer-based focus on any input event / motion vs only on real motion, and if a stationary pointer after a keyboard switch is what re-steals focus; (4) Mutter source / known upstream bugs on GNOME GitLab about keyboard focus being overridden by hover under Wayland; (5) GNOME Shell extensions that alter focus policy (e.g. options to disable focus-follows-mouse re-trigger, focus-on-click hybrids); (6) whether the desired hybrid (hover-to-focus that yields to keyboard until next real mouse motion) is even achievable natively on Wayland or requires an extension / patch; (7) any relevant timeouts or 'raise' interactions (auto-raise, raise-on-click). DELIVERABLE: a research report enumerating candidate approaches with tradeoffs, feasibility on Wayland, and a recommended Home-Manager-expressible fix (dconf keys and/or a specific extension) that the user can then plan/implement. Note the user has already tried and failed at least once, so shallow 'just set focus-mode=sloppy' answers are insufficient.

---

### 72. Email workflow infrastructure prereqs
- **Status**: [COMPLETED]
- **Task Type**: general
- **Topic**: services
- **Dependencies**: Task 46
- **Research**:
  - [072_email_workflow_infrastructure_prereqs/reports/01_infrastructure-prereqs-seed.md]
  - [072_email_workflow_infrastructure_prereqs/reports/02_team-research.md]
  - [072_email_workflow_infrastructure_prereqs/reports/02_teammate-a-findings.md]
  - [072_email_workflow_infrastructure_prereqs/reports/02_teammate-b-findings.md]
  - [072_email_workflow_infrastructure_prereqs/reports/02_teammate-c-findings.md]
  - [072_email_workflow_infrastructure_prereqs/reports/02_teammate-d-findings.md]
- **Plan**: [072_email_workflow_infrastructure_prereqs/plans/02_email-infra-wrappers.md]
- **Summary**: [072_email_workflow_infrastructure_prereqs/summaries/02_email-infra-wrappers-summary.md]

**Description**: Email workflow INFRASTRUCTURE + PREREQUISITES (child of task 71; .dotfiles-owned mechanism). Reference plan: specs/071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md (v3). Scope = v3 phases: (0) audit the dormant ~/Mail/.claude prior-art system (5 python scripts: email_list/email_analyze/email_triage/email_filter/email_execute), HARVEST email-preferences.md rule taxonomy+JSON schema and MAX_BATCH_SIZE=50 into a handoff file for the nvim extension task, RETIRE the ~/Mail harness (commands/email.md, skill-email, email-agent.md, 5 py scripts), DISCARD checkbox-approval UX + opus model pin; (1) OAuth gate: resolve/absorb task 46 (Gmail OAuth2 7-day refresh-token expiry, consent screen in Testing mode) — publish OAuth app to Production or declare blocking; (2) nix-declared dry-run-by-default wrapper scripts in modules/home/email/agent-tools.nix (email-census, email-classify, email-archive-confirmed, email-delete-confirmed, email-unsubscribe-extract) requiring explicit --execute + --confirm-manifest <sha256>, consuming a pre-generated manifest; (5) mbsync freeze/thaw + SyncState backup procedure; (9) aerc review querymap entries (Proposed-Delete/Archive/Unsure) in aerc.nix; (11-local) notmuch.nix postNew tag-rule scaffolding for institutionalized junk rules. IMPORTANT: delete mechanism is IMAP-level Himalaya only (never local Maildir/notmuch-tag+Expunge — Gmail label model leaves msgs in All_Mail, 64,316 baseline). Blocks the nvim extension task (needs harvested prefs + wrapper contract) and the ~/Mail purge task (needs wrappers+OAuth ready). Verify: nixos-rebuild/home-manager build with the new wrappers; wrappers refuse to mutate without --execute.

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

### 70. Restore piper tts prebuilt binary
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [070_restore_piper_tts_prebuilt_binary/reports/01_restore-piper-prebuilt.md]
- **Plan**: [070_restore_piper_tts_prebuilt_binary/plans/01_restore-piper-prebuilt.md]
- **Summary**: [070_restore_piper_tts_prebuilt_binary/summaries/01_restore-piper-prebuilt-summary.md]

**Description**: Restore Piper TTS with the en_US-lessac-medium neural voice via a prebuilt binary (fetchurl) instead of SVOX Pico (pico2wave), reclaiming the natural voice without compiling onnxruntime. Task 62 (commit fd23e98) had replaced piper-tts with picotts to cut rebuild times because piper-tts pulled in onnxruntime (~500MB heavy compile). Scope: (1) add packages/piper-bin.nix fetching the official rhasspy/piper prebuilt Linux x86_64 release tarball (bundles libonnxruntime, no source build) via fetchurl, following the packages/claude-code.nix pattern; (2) restore packages/piper-voices.nix fetching the en_US-lessac-medium ONNX model + config json from HuggingFace; (3) restore the flake.nix overlay entry and ~/.local/share/piper home.file symlink; (4) swap picotts -> piper-bin in modules/system/packages.nix:159; (5) rewire .claude/hooks/tts-notify.sh from the pico2wave temp-file approach back to the piper stdout pipe (piper --model ... --output_file - | aplay/paplay), restoring PIPER_MODEL env var and model-existence check; (6) update README.md and docs/applications.md. Verify: nixos-rebuild builds with no onnxruntime compilation, pico2wave fully removed, tts-notify.sh speaks a test phrase in the lessac voice.

---

### 69. Consolidate dual home manager config
- **Status**: [NOT STARTED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None

**Description**: Consolidate the dual home-manager setup so there is a single source of truth. Both the NixOS-integrated path (home-manager.users.benjamin via lib/mkHost.nix) and the standalone path (homeConfigurations.benjamin) import home.nix but pass subtly different extraSpecialArgs - notably lectic as the raw flake input (integrated) vs the resolved package (standalone). This asymmetry caused the lectic regression caught in task 66 phase 9. Decide the intended behavior (likely: both should ship the built lectic package), unify the specialArgs, and document in docs/dual-home-manager.md. See the open question recorded there.

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

### 66. Review refactor nixos configuration
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: Task 62, Task 65, Task 63, Task 64
- **Research**:
  - [066_review_refactor_nixos_configuration/reports/01_team-research.md]
  - [066_review_refactor_nixos_configuration/reports/01_teammate-a-findings.md]
  - [066_review_refactor_nixos_configuration/reports/01_teammate-b-findings.md]
  - [066_review_refactor_nixos_configuration/reports/01_teammate-c-findings.md]
  - [066_review_refactor_nixos_configuration/reports/01_teammate-d-findings.md]
- **Plan**: [066_review_refactor_nixos_configuration/plans/01_refactor-nixos-config.md]
- **Summary**: [066_review_refactor_nixos_configuration/summaries/01_refactor-nixos-config-summary.md]

**Description**: Systematically review all aspects of my current NixOS configuration, researching best practices online as of June 2026 in order to design a careful refactor that improves organization, documentation, and modularity, producing a maintainable and high performance configuration

---

### 65. Migrate python312 pins to default python3
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: packaging
- **Dependencies**: Task 60, Task 61, Task 63, Task 64
- **Research**: [065_migrate_python312_pins_to_default_python3/reports/01_python312-to-python3-migration.md]
- **Plan**: [065_migrate_python312_pins_to_default_python3/plans/01_implementation-plan.md]
- **Summary**: [065_migrate_python312_pins_to_default_python3/summaries/01_implementation-summary.md]

**Description**: Migrate explicit python312 pins to the default python3 (currently 3.13.13 on the nixpkgs pin) for binary cache coverage: Hydra fully caches only the default python3Packages set, so the pinned 3.12 env can source-build heavy packages like torch (same failure class as onnxruntime). Change home.nix:352 python312.withPackages to python3.withPackages (env includes torch, jupyter, scipy stack, custom vosk package, z3-solver, cvc5, pynvim) and evaluate migrating the Discord bot pin at configuration.nix:10 (check the bot library against Python 3.13 PEP 594 stdlib removals: cgi, telnetlib, etc.). Verify custom vosk package and z3-solver/cvc5 bindings build on 3.13. Build-only verification; sequence after tasks 60/61 land so cache hits and memory guardrails are in place for the full env rebuild

---

### 64. Clean regenerable caches reclaim disk space
- **Status**: [COMPLETED]
- **Task Type**: general
- **Topic**: maintenance
- **Dependencies**: None
- **Plan**: [064_clean_regenerable_caches_reclaim_disk_space/plans/01_cache-cleanup.md]
- **Research**: [064_clean_regenerable_caches_reclaim_disk_space/reports/01_cache-cleanup.md]

**Description**: Clean regenerable caches and reclaim disk space (root filesystem at 94%, 28GB free). Targets: ~/.local/share/Trash (4.2GB), ~/.cache/loogle (7.4GB), ~/.cache/pip (3GB), ~/.cache/nix (2.1GB), ~/.cache/uv (2GB), ~/.npm (8.5GB), ~/.local/share/memory-monitor logs (1.8GB), and audit ~/.local/share/opencode (11GB, mostly storage/) and ~/.local/share/protonmail (14GB local mail cache) for safe pruning. Roughly 25-30GB recoverable without touching personal files. Consider adding periodic cache cleanup (e.g. systemd-tmpfiles or a cleanup script) so these do not regrow unbounded

---

### 63. User level nix gc expire home manager generations
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: maintenance
- **Dependencies**: None
- **Plan**: [063_user_level_nix_gc_expire_home_manager_generations/plans/01_user-nix-gc.md]
- **Research**: [063_user_level_nix_gc_expire_home_manager_generations/reports/01_user-nix-gc.md]

**Description**: Enable automatic user-level Nix garbage collection and expire old home-manager generations. 62 home-manager generations spanning Mar 13 - Jun 11 act as GC roots pinning ~3 months of unstable closures in the 99GB /nix/store; the root-level nix.gc.automatic (weekly, 30d) never touches user profiles. Add nix.gc automatic settings to home.nix (home-manager equivalent of the system GC), run a one-time home-manager expire-generations "-30 days" plus user and root nix-collect-garbage to reclaim space, and verify store size afterward

---

### 62. Replace piper with svox pico drop onnxruntime
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: packaging
- **Dependencies**: None
- **Research**: [062_replace_piper_with_svox_pico_drop_onnxruntime/reports/01_replace-piper-svox-pico.md]
- **Plan**: [062_replace_piper_with_svox_pico_drop_onnxruntime/plans/01_implementation-plan.md]

**Description**: Replace piper-tts with svox pico (pico2wave) and drop onnxruntime from the system closure. DECISION: use pico. Nix changes: swap piper-tts for the svox pico package in configuration.nix:635, remove packages/piper-voices.nix and its flake.nix overlay entry (line 99), remove the home.nix:1199 .local/share/piper link, and handle the second onnxruntime consumer markitdown (home.nix:401, via magika) - remove it or run on-demand via nix shell. Agent system changes: update all 5 copies of tts-notify.sh to use pico2wave instead of piper (~/.config/nvim/.claude/hooks/, ~/.config/nvim/.claude/extensions/core/hooks/, ~/.config/nvim/.opencode/hooks/, ~/.config/nvim/.opencode/extensions/core/hooks/, ~/.dotfiles/.claude/hooks/) - replace the piper --model pipeline and PIPER_MODEL env var with pico2wave, keep the TTS_ENABLED toggle contract so which-key.lua <leader> TTS toggle keeps working unchanged. Update tts-stt-integration.md and neovim-integration.md guides in both repos to document pico. settings.json hook registrations need no change. Note: spans two git repos (.dotfiles and .config/nvim)

---

### 61. Pin nixpkgs stable channel binary cache hits
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Plan**: [061_pin_nixpkgs_stable_channel_binary_cache_hits/plans/01_pin-nixpkgs-stable.md]
- **Research**: [061_pin_nixpkgs_stable_channel_binary_cache_hits/reports/01_pin-nixpkgs-stable.md]

**Description**: Pin nixpkgs flake input to a stable release channel (nixos-26.05) to maximize binary cache hits and stop source-building heavy packages. The flake currently tracks nixos-unstable and update.sh runs nix flake update on every rebuild, outrunning Hydra and causing local compiles (29 packages on last update). Evaluate which inputs should stay on unstable (e.g. nix-ai-tools follows nixpkgs-unstable), align home-manager release-26.05 with the new pin, and consider making update.sh flake updates opt-in rather than automatic

---

### 60. Add nix build resource limits prevent oom
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Plan**: [060_add_nix_build_resource_limits_prevent_oom/plans/01_build-resource-limits.md]
- **Research**: [060_add_nix_build_resource_limits_prevent_oom/reports/01_build-resource-limits.md]

**Description**: Add Nix build resource limits to prevent OOM during rebuilds: set nix.settings.max-jobs and nix.settings.cores in configuration.nix (24-core Ryzen AI 9 HX 370, 30GB RAM; onnxruntime builds currently exhaust memory via 24 parallel jobs x 24 cores). Choose values that balance build speed against the ~1-2GB/compile-unit cost of heavy C++ packages, and consider a --max-jobs override in update.sh

---

### 52. Sleep inhibition claude opencode
- **Status**: [ABANDONED]
- **Task Type**: nix
- **Topic**: maintenance
- **Dependencies**: None
- **Research**: [052_sleep_inhibition_claude_opencode/reports/01_sleep_inhibition_claude_opencode.md]
- **Plan**: [052_sleep_inhibition_claude_opencode/plans/01_sleep-inhibition-implementation.md]

---

### 50. Fix sleep inhibitor pgrep self matching
- **Status**: [ABANDONED]
- **Task Type**: nix
- **Topic**: maintenance
- **Dependencies**: None
- **Research**: [050_fix_sleep_inhibitor_pgrep_self_matching/reports/01_sleep-inhibitor-research.md]

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
