---
next_project_number: 109
---

# TODO

## Task Order

*Updated 2026-07-13. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 15,19,23,41,42,43,46,67,68,77,108 | -- | nix-infrastructure, services, desktop, ... |
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
108 [PLANNED] — Make the email census freshness signal rename/deletion-aware in m

### Packaging

41 [BLOCKED] — reenable_pdf2docx_nixpkgs_fix
42 [BLOCKED] — reenable_jupytext_nixpkgs_fix

### Maintenance

15 [RESEARCHED] — configure_timezone_location_based

### Desktop

77 [NOT STARTED] — Verify and reconcile background-service behavior in the niri+GNOM
  └─ 78 [NOT STARTED] — Rewrite docs/niri.md to match the actual, settled niri+GNOME-stac

## Tasks

### 108. Census freshness rename deletion aware
- **Status**: [PLANNED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [108_census_freshness_rename_deletion_aware/reports/01_freshness-signal-research.md]
- **Plan**: [108_census_freshness_rename_deletion_aware/plans/01_freshness-set-diff-signal.md]

**Description**: Make the email census freshness signal rename/deletion-aware in modules/home/email/agent-tools/census.nix. The freshness line is currently an INBOX file-count-with-tolerance proxy that cannot detect maildir flag-renames (e.g. U=5202:2, -> U=5202:2,S) or phantom index drift (observed 84 files on disk vs 122 in notmuch = 38 phantom entries), which produced a false-green that let aerc launch onto a stale notmuch index. Enhance the freshness contract to surface a rename/deletion-aware signal (not just a bounded file count) that downstream consumers can treat as authoritative. Scope: ONLY the .dotfiles census.nix freshness-line enhancement. Out of scope: the ~/Mail duplicate-UID data repair, the one-time notmuch new reindex, and the nvim mail.lua gate hardening (those live in ~/Mail and ~/.config/nvim).

---

### 107. Fix WezTerm Leader+c new-tab opening in a stale Neovim working directory
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: terminal
- **Dependencies**: None
- **Research**: [107_fix_wezterm_leader_c_stale_cwd/reports/01_wezterm-leader-c-stale-cwd.md]
- **Plan**: [107_fix_wezterm_leader_c_stale_cwd/plans/01_wezterm-leader-c-stale-cwd.md]
- **Summary**: [107_fix_wezterm_leader_c_stale_cwd/summaries/01_wezterm-leader-c-stale-cwd-summary.md]

**Description**: New WezTerm tabs opened with LEADER+c start in a stale project directory instead of the shell's real cwd (~). Root cause (confirmed in nvim-repo task 87): the LEADER+c binding act.SpawnTab("CurrentPaneDomain") (config/wezterm.lua:456) spawns the new shell in WezTerm's cached OSC-7 cwd, which Neovim pollutes when it emits OSC 7 for a worktree tcd/cd and never re-emits on exit; new fish shells are physically chdir'd to the stale dir (verified via /proc). The get_foreground_process_info().cwd fix was already written (commit 3af0978) and reverted with no rationale (3d82539) — determine why before re-applying, harden the nil fallback to $HOME (never back to stale SpawnTab), decide the new-tab-while-nvim-open policy, then apply via home-manager switch. Config owned by this repo at config/wezterm.lua, wired via modules/home/core/dotfiles.nix:37.

---

### 106. Root cause fix mt7925e wifi kernel panics
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [106_root_cause_fix_mt7925e_wifi_kernel_panics/reports/01_mt7925e-panic-upstream-fix.md]
- **Plan**: [106_root_cause_fix_mt7925e_wifi_kernel_panics/plans/01_mt7925e-kernel-fix.md]
- **Summary**: [106_root_cause_fix_mt7925e_wifi_kernel_panics/summaries/01_mt7925e-kernel-fix-summary.md]

**Description**: Root-cause and permanently fix the recurring mt7925e WiFi kernel panic freezes on hamsa (Framework 13, Ryzen AI 9 HX 370) — follow-up to task 104. Task 104 confirmed via pstore dumps that the freezes are kernel panics from a wcid/poll_list linked-list corruption race in the MediaTek mt7925e/mt76 driver (kernel BUG at lib/list_debug.c:32, __list_add_valid_or_report -> mt76_wcid_add_poll -> mt7925_mac_add_txs/mt7925_queue_rx_skb on the threaded NAPI RX/TXS path), triggered during heavy AP roaming. Task 104 only shipped a MITIGATION (panic=10 auto-reboot, kernel 7.1.1->7.1.2) but verified BOTH published upstream fixes were already present, so this is a still-unfixed variant of the race. The freeze just recurred and the machine auto-rebooted as intended. GOAL: identify a CORRECT solution, not another mitigation, via proper online research. Research: current state of the mt76/mt7925 poll_list/wcid race upstream (linux-wireless / linux-mediatek mailing lists, netdev, git.kernel.org mt76 tree, openwrt/mt76 issue #1023 and related, zbowling/mt7925 tracker, Framework community forum reports for the RZ717/mt7925 on Ryzen AI 300); whether a newer kernel or a specific pending patch series fixes THIS exact backtrace; whether boot.kernelPatches with a cherry-picked upstream commit is viable and which commit; whether driver options (mt7925e disable_aspm/power_save, threaded NAPI toggle, roaming/band-steering aggressiveness) meaningfully reduce trigger surface; and the Intel AX210 hardware-swap fallback. Collect the current pstore dumps from /var/lib/systemd/pstore/ as fresh evidence and report this trace upstream if still uncatalogued. Deliver a concrete, verifiable fix recommendation with the exact nix config changes. Machine: hosts/hamsa; modules/system/boot.nix already carries amdgpu.dcdebugmask=0x10, mt7925e disable_aspm=1 power_save=0, hung_task_timeout_secs=60, panic=10. Reference: specs/104_fix_mt7925e_wifi_kernel_panic_freezes/reports/01_mt7925e-panic-root-cause.md

---

### 105. Aerc keybindings nvim himalaya alignment
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: email-infrastructure
- **Dependencies**: None
- **Research**: [105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md]
- **Plan**: [105_aerc_keybindings_nvim_himalaya_alignment/plans/01_aerc-tab-switching.md]
- **Summary**: [105_aerc_keybindings_nvim_himalaya_alignment/summaries/01_aerc-tab-switching-summary.md]

**Description**: Align the aerc terminal email client's keybindings with the user's Neovim core + Himalaya-plugin navigation conventions so muscle memory transfers across all three clients.

TWO SEED ASKS: (1) switch aerc account tabs with <Tab>/<S-Tab> (the Neovim next/prev-buffer keys) instead of <C-n>/<C-p>; (2) navigate aerc like Neovim panes with <C-h/j/k/l>.

CRITICAL FINDING (see reports/01): aerc runs inside a Neovim floating toggleterm (launched by ~/.config/nvim/.../tools/mail.lua via <leader>me), and Neovim installs terminal-mode maps on every term:// buffer (autocmds.lua:25 -> set_terminal_keymaps keymaps.lua:116). That layer INTERCEPTS <C-h/j/k/l> (->wincmd) and <Esc> (->exit terminal mode) before aerc sees them, but passes <Tab>/<S-Tab>/<C-n>/<C-p> through. Therefore Ask 1 is viable in aerc.nix alone; Ask 2 is blocked at the Neovim layer and also has no aerc pane model to map onto.

RECOMMENDATION A (low risk, .dotfiles only): in modules/home/email/aerc.nix extraBinds, add <Tab>=:next-tab / <S-Tab>=:prev-tab to [messages] and [view] (NOT global/compose, to avoid stealing Tab from text fields), keeping <C-n>/<C-p> as fallback aliases; optional s=sync alias reusing the safe scoped exec. RECOMMENDATION B (optional, cross-repo follow-up in ~/.config/nvim): special-case the aerc terminal in set_terminal_keymaps() to skip the <C-hjkl>->wincmd and <Esc> remaps (like the existing is_claude/is_opencode cases), then bind <C-h>/<C-l>=prev/next-folder in aerc.

SAFETY (must not regress): native d/D/a/A are human-only mutation paths outside the agent guardrail (D/A/d :prompt-hardened; A=archive-all is WHY account-switch cannot reuse A); the Proposed-Delete/Archive/Unsure folder overrides route d/a/k through email-classify --append-approved (manifest approval), never aerc-native delete/archive; $ sync is deliberately scoped to `mbsync gmail && notmuch new --no-hooks` (never mbsync -a). Ref .dotfiles task 72 Phase 9.

EDIT/DEPLOY: edit modules/home/email/aerc.nix (source of truth); ~/.config/aerc/binds.conf is a read-only nix-store symlink. Verify with home-manager build, then switch; manually confirm Tab/S-Tab switch tabs, aliases still work, no safety-bind regression, and Shift-Tab is distinguishable in WezTerm.

CROSS-REPO: research performed from ~/Mail; report + task homed in .dotfiles because aerc.nix lives here. Recommendation B, if adopted, needs a companion task in ~/.config/nvim.

---

### 104. Fix mt7925e wifi kernel panic freezes
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [104_fix_mt7925e_wifi_kernel_panic_freezes/reports/01_mt7925e-panic-root-cause.md]

**Description**: Fix recurring system freezes from mt7925e WiFi kernel panics: update kernel via flake bump and add panic=10 auto-reboot kernel param

---

### 103. Reorganize discord bot in repo
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: services
- **Dependencies**: None
- **Research**: [103_reorganize_discord_bot_in_repo/reports/01_discord-bot-reorg-research.md]
- **Summary**: [103_reorganize_discord_bot_in_repo/summaries/01_discord-bot-reorg-summary.md]
- **Plan**: [103_reorganize_discord_bot_in_repo/plans/01_discord-bot-reorg.md]

**Description**: Reorganize the opencode-discord-bot in-repo (do NOT extract to a separate repository). Two goals. (1) Fix host-wiring drift: the discord-bot systemd service is currently running on hamsa (the primary machine) even though only hosts/nandi/default.nix opts in via services.discordBot.enable = true. Make services.discordBot.enable cleanly enableable on ANY host and enable it on hamsa so the tracked config matches reality; decide whether nandi should stay enabled. (2) Declutter the repo root: relocate the in-tree Python source from root opencode-discord-bot/ (16 tracked files) to sit next to its derivation (recommended target packages/opencode-discord-bot/, co-located with packages/opencode-discord-bot.nix), updating the derivation's src from ../opencode-discord-bot to the new relative path (e.g. ./opencode-discord-bot), plus .gitignore entries and any references. Note the file/dir naming caveat if using packages/ (packages/opencode-discord-bot.nix file alongside a packages/opencode-discord-bot/ dir); research/plan may pick an alternative co-location target (e.g. a new pkgs/ or apps/ dir) if cleaner. Keep everything else in .dotfiles unchanged: sops secrets, the optional module, systemd wiring (opencode-serve + discord-bot, LoadCredential, StateDirectory, watchdog). Update docs to reflect the new source path and host wiring: docs/discord-bot.md, packages/README.md, modules/README.md, README.md (note the tree diagram at README.md line ~43). Verify nix flake check passes and the discord-bot service still builds/runs on hamsa after nixos-rebuild. Explicitly rejected alternative: extracting to a standalone flake-input repo (adds cross-repo iteration friction and maintenance surface for reuse/versioning benefits this personal, tightly-coupled service does not need). Follows task 89 (bot packaging, complete).

---

### 102. Gate ci on lint
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: Task 101
- **Research**: [102_gate_ci_on_lint/reports/01_gate-ci-on-lint.md]
- **Plan**: [102_gate_ci_on_lint/plans/01_gate-ci-on-lint.md]
- **Summary**: [102_gate_ci_on_lint/summaries/01_gate-ci-on-lint-summary.md]

**Description**: Gate CI on lint: promote the warn-only statix/deadnix lint steps (added in task 98) from advisory to CI-blocking now that task 101 made the tree lint-clean (statix + deadnix both zero-finding). Update .github/workflows/ci.yml so the statix check and deadnix --exclude 'hosts/*/hardware-configuration.nix' steps exit non-zero (remove any continue-on-error / warn-only shielding) and gate the workflow, so future lint regressions fail the build. Preserve the existing hardware-configuration.nix path exclusions (statix.toml ignore glob + deadnix --exclude flag). Verify the gated workflow passes on the current clean tree. Follows task 98 (lint tooling), depends on task 101 (lint-clean baseline).

---

### 101. Nix lint findings cleanup
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [101_nix_lint_findings_cleanup/reports/01_lint-findings-cleanup.md]
- **Plan**: [101_nix_lint_findings_cleanup/plans/01_lint-findings-cleanup.md]
- **Summary**: [101_nix_lint_findings_cleanup/summaries/01_lint-findings-cleanup-summary.md]

**Description**: Clear the statix and deadnix findings surfaced by the warn-only lint tooling added in task 98, so the tree is lint-clean (enabling a future decision to gate CI on lint if desired). Two linters, concrete findings as of task 98 completion: (1) statix — 33 warnings across 4 rule classes: 18x 'repeated keys in attribute sets' (the home-manager.useGlobalPkgs/useUserPackages/users block in flake.nix:155-157, collapse into one home-manager = { ... } attrset), 11x 'empty pattern in function argument' ({ ... }: -> _: where the args are unused), 3x 'assignment instead of inherit from' (overlays/unstable-packages.nix:6,12 and flake.nix:55), 1x 'unnecessary parentheses'. (2) deadnix — 23 unused lambda declarations across 16 files (unused lib/pkgs/prev/final/old args), e.g. modules/system/{boot,nix,desktop}.nix (lib), overlays/{claude-squad,python-packages}.nix (prev/final/old), flake.nix:45, home.nix:2, packages/{aristotle,claude-code,polkit-gnome-agent-wrapper,slidev}.nix. NOTE: 4 of the deadnix hits are in auto-generated hosts/*/hardware-configuration.nix (unused pkgs pattern) — decide whether to fix those (risk: overwritten by nixos-generate-config) or exclude them via a deadnix exclude rather than editing. Prefer 'statix fix' / 'deadnix --edit' assisted passes but hand-verify each change; some unused args (final/prev in overlays) may be intentional signature conventions worth keeping with a deadnix skip comment. Verify with nix flake check (must stay green) and re-run statix check + deadnix to confirm zero findings (or a documented, deliberately-excluded remainder). Follow-on to task 98 (specs/098_nix_formatter_lint_tooling).

---

### 100. Strip niri doc emoji
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**: [100_strip_niri_doc_emoji/reports/01_emoji-strip-inventory.md]
- **Plan**: [100_strip_niri_doc_emoji/plans/01_strip-niri-doc-emoji.md]
- **Summary**: [100_strip_niri_doc_emoji/summaries/01_strip-niri-doc-emoji-summary.md]

**Description**: Strip the ~58 emoji glyphs from docs/niri.md (1035 lines) to conform to the emoji convention added in task 91, preserving arrows/structural characters. Purely mechanical, no config verification needed. Carried over from task 94 deferred Phase 8. See specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md (Group F).

---

### 99. Ryzen docs niri framing
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research_report**: [099_ryzen_docs_niri_framing/reports/01_ryzen-docs-niri-framing-research.md]
- **Plan**: [099_ryzen_docs_niri_framing/plans/01_ryzen-docs-niri-framing.md]
- **Summary**: [099_ryzen_docs_niri_framing/summaries/01_ryzen-docs-niri-framing-summary.md]

**Description**: Consolidate the two near-duplicate Ryzen AI 300 docs (docs/ryzen-ai-300-compatibility.md and docs/ryzen-ai-300-support-summary.md) into a single authoritative doc, and re-confirm docs/niri.md 'Recommended Usage Strategy' testing-phase framing against actual daily-driver usage (update if stale). Carried over from task 94 deferred Phase 8 - needs user confirmation on how to consolidate/reframe. See specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md (Group E) and specs/094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md (Phase 8).

---

### 98. Nix formatter lint tooling
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: Task 97
- **Research_report**: [098_nix_formatter_lint_tooling/reports/01_formatter-lint-tooling.md]
- **Plan**: [098_nix_formatter_lint_tooling/plans/01_formatter-lint-tooling.md]
- **Summary**:
  - [flake.nix]
  - [.github/workflows/ci.yml]
  - [47 of 80 tracked .nix files]
  - [098_nix_formatter_lint_tooling/summaries/01_formatter-lint-tooling-summary.md]

**Description**: Add Nix formatter and lint tooling to the flake (none configured today; CI only runs nix flake check). Standardize on nixfmt (RFC 166 / nixfmt-rfc-style, the official formatter) as the flake formatter output, and add statix + deadnix for linting/dead-code detection. Decide and document whether to gate CI on formatting/lint (needs user confirmation on strictness). Apply an initial format pass. Depends on task 97 as both touch flake.nix. See specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md (Group D).

---

### 97. Refactor dead comment cleanup
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research_report**: [097_refactor_dead_comment_cleanup/reports/01_wrapper-extraction-mcphub-fix.md]
- **Plan**: [097_refactor_dead_comment_cleanup/plans/01_wrapper-extraction-mcphub-fix.md]
- **Summary**: [097_refactor_dead_comment_cleanup/summaries/01_wrapper-extraction-mcphub-fix-summary.md]

**Description**: Small refactor and dead-comment cleanup: extract the 3 inline writeShellScriptBin wrappers from modules/system/packages.nix into their own packages/*.nix files for consistency with the rest of the package layout, and fix the confirmed contradictory MCPHub comment pair in flake.nix (lines 33 vs 62). Verify with nix flake check. See specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md (Group C).

---

### 96. Documentation completeness gaps
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: Task 95
- **Research_report**: [096_documentation_completeness_gaps/reports/01_documentation-completeness-research.md]
- **Plan**: [096_documentation_completeness_gaps/plans/01_hamsa-readme-pkg-headers.md]
- **Summary**: [096_documentation_completeness_gaps/summaries/01_hamsa-readme-pkg-headers-summary.md]

**Description**: Fill documentation completeness gaps: add a missing hosts/hamsa/README.md (the daily-driver AMD Ryzen AI 9 HX 370 machine, currently the only host without a README - reuse the corrected wording from task 95 rather than the stale nandi/garuda phrasing), and add header comments to the 9 of 13 packages/*.nix files that lack them. See specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md (Group B).

---

### 95. Post reorg documentation sweep
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research_report**: [095_post_reorg_documentation_sweep/reports/01_post-reorg-doc-sweep.md]
- **Plan**: [095_post_reorg_documentation_sweep/plans/01_stale-doc-pointer-sweep.md]
- **Summary**: [095_post_reorg_documentation_sweep/summaries/01_stale-doc-pointer-sweep-summary.md]

**Description**: Complete the post-reorg documentation sweep: fix all remaining docs that still point contributors at configuration.nix/home.nix for content that now lives in modules/system/* and modules/home/**. Covers root README.md (4 spots), hosts/nandi/README.md, hosts/garuda/README.md, and 6 topic docs (docs/dictation.md, docs/neovim.md, docs/gnome-settings.md, docs/discord-bot.md, docs/installation.md, docs/development.md). Also fix docs/dictation.md stale package name, broken line reference, and dead wtype references that contradict its own text. See specs/094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md (Group A).

---

### 94. Review nixos config documentation
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nixos-config
- **Dependencies**: None
- **Research**:
  - [094_review_nixos_config_documentation/reports/01_nixos-config-doc-review.md]
  - [094_review_nixos_config_documentation/reports/02_remaining-cleanup-backlog.md]
- **Plan**: [094_review_nixos_config_documentation/plans/01_nixos-doc-config-improvements.md]
- **Summary**: [094_review_nixos_config_documentation/summaries/01_nixos-doc-config-improvements-summary.md]

**Description**: Systematically review my nixos config to improve the documentation (and the config) where relevant

---

### 93. Update sh auto commit opt in
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Research**: [093_update_sh_auto_commit_opt_in/reports/01_update-sh-checkpoint-opt-in.md]
- **Plan**: [093_update_sh_auto_commit_opt_in/plans/01_checkpoint-opt-in.md]
- **Summary**: [093_update_sh_auto_commit_opt_in/summaries/01_checkpoint-opt-in-summary.md]

**Description**: Make scripts/update.sh's automatic git checkpoint commit opt-in instead of default (hazard surfaced during tasks 82-85 parallel orchestration). scripts/update.sh:7-17 currently runs `git add -A && git commit` unconditionally whenever the working tree is dirty, which during concurrent work swept unrelated staged changes from other tasks into misattributed commits (e.g. commit 6ba1f4e "checkpoint: auto-commit before update" absorbed task-85 changes, and commit 02f806d absorbed task-83's work under task 92's message). Fix: make the checkpoint opt-in behind a flag/env var, mirroring the existing task-61 `--update` opt-in pattern already in this file (lines 19-28) — e.g. add a `--checkpoint` flag or `UPDATE_CHECKPOINT=1` env var, defaulting OFF. When the checkpoint is OFF and the tree is dirty, prefer refusing to proceed with a clear message (or skipping the checkpoint) rather than silently staging everything. CRITICAL: never use `git add -A` to stage arbitrary unrelated changes — if a checkpoint is made, it must be explicit/opt-in. Update docs/development.md and any README/doc reference to `./scripts/update.sh` to document the new flag (grep repo-wide for `update.sh` references — task 85 already normalized these to the scripts/ prefix). Verification: `./scripts/update.sh` with a dirty tree no longer creates an auto-commit unless the opt-in flag/env is passed; the `--update` flake-input path still works; `bash -n scripts/update.sh` clean; `nix flake check` green. Seed context: this session's orchestration of tasks 82-85 (see specs/085_root_scripts_relocation_scripts_dir/summaries/01_scripts-dir-relocation-summary.md deviation note) and specs/083_git_hygiene_specs_tmp_nixos_repo/summaries/01_git-hygiene-untrack-tmp-summary.md commit-attribution note.

---

### 92. Logos mbsync group labels fix
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: email-infrastructure
- **Dependencies**: None
- **Research**:
  - [092_logos_mbsync_group_labels_fix/reports/01_mbsync-logos-diagnosis.md]
  - [092_logos_mbsync_group_labels_fix/reports/02_task-still-needed.md]
  - [092_logos_mbsync_group_labels_fix/reports/03_cross-repo-nvim-sync-linkage.md]
- **Plan**: [092_logos_mbsync_group_labels_fix/plans/03_logos-mbsync-hardening.md]
- **Summary**: [092_logos_mbsync_group_labels_fix/summaries/03_logos-mbsync-hardening-summary.md]

**Description**: [RESCOPED 2026-07-11 after research reports 02 + 03] Harden the Logos (Protonmail Bridge) mbsync config. The ORIGINAL blocking bug -- the wrappers' post-mutation `mbsync logos` reconcile exiting non-zero because `Group logos` chained `logos-labels` and hit the dotted Gmail-import label `benbrastmckie@gmail.com` under `SubFolders Maildir++` -- is ALREADY FIXED by commit a8f65ad (removed logos-labels from Group logos; landed via nvim task 826). Two residual hardening items remain (see reports/02_task-still-needed.md and reports/03_cross-repo-nvim-sync-linkage.md).

RESIDUAL ITEM 1 (HIGHEST PRIORITY -- negative dotted-name patterns): Add `"!Labels/*.*"` to the `logos-labels` channel Patterns and `"!Folders/*.*"` to the `logos-folders` channel Patterns in modules/home/email/mbsync.nix, so no dotted mailbox name can ever reach the Maildir++ store. This is now the top item because `logos-folders` is STILL a member of `Group logos` (line ~207-213), and this session's nvim task 851 wired `mbsync -a` (which runs Group logos) onto hot interactive keymaps `<leader>me` (open aerc) and `<leader>mN` (full sync). If Proton ever exposes a dotted Folder name, `<leader>me` would break in the user's face on a common keystroke. The pattern also makes a8f65ad's own commit-message claim that logos-labels is safe "for manual inspection" actually true (currently a manual `mbsync logos-labels` would still crash on the dotted label).

RESIDUAL ITEM 2 (LOW PRIORITY -- operator convenience): Add a new `Group logos-full` = core channels (logos-inbox, logos-sent, logos-drafts, logos-trash, logos-archive) PLUS logos-labels + logos-folders, for explicit on-demand full sync. No keymap depends on it; purely a convenience so the slimmed `Group logos` still has a full-sync counterpart.

FILES: modules/home/email/mbsync.nix (Logos section). The runtime ~/.mbsyncrc is a home-manager /nix/store symlink -- never edit it directly.

VERIFICATION (shared with nvim task 851's one remaining open item -- one live check credits both repos): `home-manager build` evaluates; after `home-manager switch`: `mbsync logos-inbox` (the `<leader>ms` leg), `mbsync logos` (wrapper reconcile), and `mbsync -a` (the `<leader>me`/`<leader>mN` path) all exit 0; and once logos-full exists, `mbsync logos-full` completes without any dotted-name fatal error. Non-fatal duplicate-UID warnings and the one dateless local Sent message (report 01) may still appear but do not fail the reconcile.

OUT OF SCOPE (unchanged): the secondary data-level issues -- duplicate-UID warnings in .Trash/.Archive and the malformed 144-byte Sent message missing a `Date:` header -- are not config fixes and are not addressed by this task.

SEED/CROSS-REPO: original diagnosis in ~/Mail (specs/email-manifests/logos/). Relates to .dotfiles email tasks 72/79 and nvim task 851.

---

### 91. Documentation sync reorg final
- **Status**: [COMPLETED]
- **Task Type**: markdown
- **Topic**: nix-infrastructure
- **Dependencies**: Task 82, Task 83, Task 84, Task 85, Task 86, Task 87, Task 88, Task 89, Task 90
- **Research**:
  - [091_documentation_sync_reorg_final/reports/01_documentation-sync-final.md]
  - [091_documentation_sync_reorg_final/reports/01_seed.md]
- **Plan**: [091_documentation_sync_reorg_final/plans/01_documentation-sync-final.md]
- **Summary**: [091_documentation_sync_reorg_final/summaries/01_documentation-sync-final-summary.md]

**Description**: Perform final documentation sync across the NixOS/Home Manager dotfiles repo (task 81 Final tier, subtask blueprint #10, gated on ALL of subtasks 82-90 landing first, since it documents the tree those subtasks produce). Update root README.md's Module Map to drop the stale '(planned: task 66 Phase 2/3/4)' annotations (task 66 is long completed) and its package list to drop neovim.nix (removed by subtask 82) and add piper-bin.nix/piper-voices.nix. Complete the docs/README.md index to list dual-home-manager.md, email-workflow.md, how-to-add-package.md, how-to-add-service.md, gnome-settings.md, and video-editing.md (all exist on disk but are currently unlisted). Add a new modules/README.md documenting the system/home split, the aggregator convention introduced by subtask 86, and the meaning of optional/. Record one-line 'checked, no action needed' notes for flake.lock health and stateVersion values (Critic-verified non-issues — prevent a future pass from rediscovering these as false positives). Resolve task 69's dual-home-manager documentation closure here (Option A retained, documented) if subtask 86 did not already do so. Establish the 'docs verified against source, not fixed once' convention explicitly so task 78 (niri docs rewrite) can cite it — task 78 should ADOPT but NOT be merged with or made dependent on this reorg's doc convention. Inherited cross-cutting protocol: `git add <specific paths>` before verification. Verification level: full regression — re-run the complete build harness (nix flake check + nandi/hamsa/garuda builds + HM activation) as a final check, plus a manual README-vs-`find` drift check across the whole tree. Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("Documentation drift" section), reports/02_team-research.md (Conflicts Resolved #4, Coverage Gap #6/#8/#9, subtask blueprint row 10), and design/target-layout.md §3 (Subtask Blueprint row 10), §5 (gap #6, #8, #9 dispositions), and §5.3 (Roadmap Linkage Note).

---

### 90. Config dir deployment clarity docs
- **Status**: [COMPLETED]
- **Task Type**: markdown
- **Topic**: nix-infrastructure
- **Dependencies**: Task 88
- **Research**:
  - [090_config_dir_deployment_clarity_docs/reports/01_config-deployment-mechanisms.md]
  - [090_config_dir_deployment_clarity_docs/reports/01_seed.md]
- **Plan**: [090_config_dir_deployment_clarity_docs/plans/01_document-config-deployment.md]
- **Summary**: [090_config_dir_deployment_clarity_docs/summaries/01_document-config-deployment-summary.md]

**Description**: Document config/ deployment mechanisms in the NixOS/Home Manager dotfiles repo (task 81 Tier 2, optional/low-priority, subtask blueprint #9, depends on subtask 88 [module granularity pass, which renames home/core/shell.nix to dotfiles.nix] so this doc's cross-reference target already exists under its new name). Expand config/README.md to document all three existing deployment mechanisms (home.file.*.source store symlinks; builtins.readFile copies mirrored into ~/.config/config-files/; the activation-script cp for config/claude/{settings,keybindings}.json into ~/.claude/), and explicitly note: (a) the config/ vs Nix `config` module-argument shadowing, and (b) the separate .claude/ (agent-orchestration system, out of scope for task 81) vs config/claude/ (deployed dotfiles, in scope) naming collision — flag it so it is never conflated. Cross-reference from dotfiles.nix's (renamed from shell.nix by subtask 88) header comment. Preserve and explicitly flag (do not fix or silently widen) the pre-existing intended behavior that config/claude/ activation force-overwrites ~/.claude/settings.json / keybindings.json on every switch — any manual edit not round-tripped into config/claude/ is destroyed; this is documented behavior, not a bug this subtask should change. This subtask is explicitly optional/do-only-if-a-slow-week-presents-itself, not required for the reorg's core value. Inherited cross-cutting protocol: `git add <specific paths>` before any verification (doc-only, but still nix-tree-adjacent). Verification level: doc-only — stale-reference grep confirms config/README.md accurately reflects the current three mechanisms and the two callouts above are present. Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("config/" section), reports/02_team-research.md (Coverage Gap #3/#4, Design-Question Decision table row 7, subtask blueprint row 9), and design/target-layout.md §1.2 (naming collision), §1.3 (config/README.md), §2 (row 7), §3 (Subtask Blueprint row 9), and §5 (gap #4 disposition).

---

### 89. Opencode discord bot packaging
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: Task 86
- **Research**:
  - [089_opencode_discord_bot_packaging/reports/02_opencode-discord-bot-packaging.md]
  - [089_opencode_discord_bot_packaging/reports/01_seed.md]
- **Plan**: [089_opencode_discord_bot_packaging/plans/02_package-via-buildpythonapplication.md]
- **Summary**: [089_opencode_discord_bot_packaging/summaries/02_package-via-buildpythonapplication-summary.md]

**Description**: Package opencode-discord-bot via buildPythonApplication in the NixOS/Home Manager dotfiles repo (task 81 Tier 2, subtask blueprint #8, depends on subtask 86 [module convention + per-host discord-bot opt-in] so the service is already wired as an explicit per-host option before its packaging changes underneath it). Add a pyproject.toml to opencode-discord-bot/ and convert its packaging to buildPythonApplication under packages/ (near-term, low-risk destination — NOT extraction to its own repo, which is a later strategic follow-on once the bot's interface stabilizes, mirroring the email-extension precedent already in this repo; document that follow-on but do not implement it here). Point the systemd unit's ExecStart/PYTHONPATH at the built nix-store path instead of ~/.dotfiles/opencode-discord-bot (modules/system/optional/discord-bot.nix:105). Fix the discord-bot.nix:20 comment path typo (cites opencode-discord-bot/src/bot.py; real path is opencode_discord_bot/src/bot.py). Resolve the untracked-.opencode/-vs-tracked-opencode.json inconsistency (root opencode.json currently points at a now-gitignored .opencode/agent/... path). THIS SUBTASK IS EXPLICITLY BEHAVIOR-CHANGING: the closure gains the packaged bot and its runtime execution path changes from a working-tree PYTHONPATH import to a nix-store path — NOT covered by the standard build-only inertness harness. Inherited cross-cutting protocol: `git add <specific paths>` (never `-A`) before verification. Verification level: RUNTIME + BUILD — build harness PLUS an explicit runtime check (`systemctl cat`/dry-run showing ExecStart/working directory resolves to a /nix/store/... path, not a $HOME path); document the expected closure delta as intentional, not a regression. Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("opencode-discord-bot/" section), reports/02_team-research.md (Conflicts Resolved #1, Design-Question Decision table row 8, subtask blueprint row 8), and design/target-layout.md §1.3 (opencode-discord-bot/ pyproject.toml), §2 (row 8), §3 (Subtask Blueprint row 8), and §4.3 (Runtime Verification Requirement).

---

### 88. Module granularity pass
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: Task 86
- **Research**:
  - [088_module_granularity_pass/reports/01_seed.md]
  - [088_module_granularity_pass/reports/01_module-granularity-boundaries.md]
- **Plan**: [088_module_granularity_pass/plans/01_module-granularity-refactor.md]
- **Summary**: [088_module_granularity_pass/summaries/01_module-granularity-refactor-summary.md]

**Description**: Run a module granularity pass over modules/home/ in the NixOS/Home Manager dotfiles repo (task 81 Tier 2, subtask blueprint #7, depends on subtask 86 [module convention + aggregators] so new/renamed files register in the new aggregators rather than needing a second hand-edit). Split modules/home/email/agent-tools.nix (761 lines, 5 wrapper binaries) into modules/home/email/agent-tools/{default.nix, per-wrapper}.nix — exact split boundaries are NOT prescribed here; finalize them during this subtask's own planning by reading the full file first. Merge tiny fragment files into modules/home/packages/misc.nix: packages/fonts.nix (8 lines), packages/lean-math.nix (8 lines), packages/ai-tools.nix (10 lines). Co-locate the memory system's split files (scripts/memory-monitor.nix + services/memory-services.nix) so they sit together / are named consistently. Rename modules/home/core/shell.nix to modules/home/core/dotfiles.nix (it deploys config/, not shell configuration — misnomer fix); treat further splitting deployment logic out to each owning module as a future direction, not mandatory within this subtask's granularity pass. Inherited cross-cutting protocol: `git add <specific paths>` / use `git mv` for renames (never `-A`) before verification — flake.nix's `root = self` makes this especially important for renames. Verification level: build-only inertness — `nix build .#homeConfigurations.benjamin.activationPackage`; `nix store diff-closures` against the pre-change baseline must be EMPTY (pure structural refactor, no closure change expected). Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("modules/" section — size outliers and tiny fragments), reports/02_team-research.md (subtask blueprint row 7, Design-Question Decision table row 11), and design/target-layout.md §1.3 (modules/home/ tree with agent-tools/ split and dotfiles.nix rename), §2 (row 11), and §3 (Subtask Blueprint row 7).

---

### 87. Hosts structural cleanup
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: Task 86
- **Research**:
  - [087_hosts_structural_cleanup/reports/01_seed.md]
  - [087_hosts_structural_cleanup/reports/01_hosts_readme_iso_extraction.md]
- **Plan**: [087_hosts_structural_cleanup/plans/01_hosts-structural-cleanup.md]
- **Summary**: [087_hosts_structural_cleanup/summaries/01_hosts-structural-cleanup-summary.md]

**Description**: Clean up hosts/ structure and documentation in the NixOS/Home Manager dotfiles repo (task 81 Tier 2, subtask blueprint #6, depends on subtask 86 [module convention + aggregators] landing first so the mkHost pattern and per-host wiring convention are settled). Rewrite hosts/README.md's obsolete inline-nixosSystem example (hosts/README.md:28-37) to document the current mkHost factory pattern — this folds into subtask 86's doc edit if not already done there. As an EXPLICITLY OPTIONAL stretch step only, extract the ~60-line ISO inline config block (flake.nix:118-175) to hosts/iso/default.nix for symmetry with other hosts — scope strictly to wiring, do NOT touch task 68's broken zfs-kernel state, and exclude iso/usb-installer from the build-diff harness entirely (they are not reliably buildable regardless of this task's changes; task 68 lineage). Inherited cross-cutting protocol: `git add <specific paths>` (never `-A`) before verification. Verification level: build-only inertness — `nix flake check`; iso/usb-installer build state must remain exactly as (un)buildable as before (no new regression attributable to this subtask). Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("hosts/" and "lib/" sections), reports/02_team-research.md (subtask blueprint row 6), and design/target-layout.md §1.3 (hosts/ tree), §3 (Subtask Blueprint row 6), and §4.2 (Baseline Verification Harness, iso/usb-installer exclusion).

---

### 86. Module convention discord bot opt in
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Research**:
  - [086_module_convention_discord_bot_opt_in/reports/01_module-convention-discord-bot-opt-in.md]
  - [086_module_convention_discord_bot_opt_in/reports/01_seed.md]
- **Plan**: [086_module_convention_discord_bot_opt_in/plans/01_module-convention-opt-in.md]
- **Summary**: [086_module_convention_discord_bot_opt_in/summaries/01_module-convention-opt-in-summary.md]

**Description**: Adopt the module convention (options + aggregators) and make the Discord bot a real per-host opt-in in the NixOS/Home Manager dotfiles repo (task 81 Tier 1 — the strategic core, sequence BEFORE task 77's dispatch; subtask blueprint #5; self-contained, no dependencies). Work: (1) amend .claude/rules/nix.md to scope the options-pattern requirement to optional/host-toggled modules only, not a blanket 43-file rewrite (the other ~40 always-on modules remain plain config sets); (2) introduce modules/system/default.nix and modules/home/default.nix aggregators, replacing configuration.nix's and home.nix's flat hand-maintained import lists; (3) convert modules/system/optional/discord-bot.nix to `options.services.discordBot.enable` + `mkIf` and remove it from the shared/default aggregator; (4) wire it explicitly per-host (e.g. hosts/nandi/default.nix sets `services.discordBot.enable = true`) via `extraModules` in flake.nix — explicit wiring, NOT a generic pathExists/readDir auto-discovery layer (Conflicts Resolved #2 in research); (5) delete garuda's empty-body hosts/garuda/default.nix now, re-add only with real content plus explicit flake.nix wiring when garuda actually needs an opt-in module; (6) update docs/discord-bot.md:25. Fold task 69's dual-home-manager Option-A documentation-only resolution in here (or defer to subtask 91/documentation-sync if more natural there). THIS SUBTASK IS EXPLICITLY BEHAVIOR-CHANGING: a host that silently got the Discord bot before will legitimately stop getting it — it is NOT covered by the standard build-only inertness harness. Inherited cross-cutting protocol: `git add <specific paths>` (never `-A`) before verification. Verification level: RUNTIME + BUILD — full harness (`nix flake check` + build nandi/hamsa/garuda + HM activation) PLUS `nixos-rebuild switch` + `systemctl status`/`journalctl` confirming hamsa's closure no longer includes the Discord bot's Python closure and nandi's does; build-only diff cannot observe this class of change. Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("modules/" and "hosts/" sections), reports/02_team-research.md (Conflicts Resolved #2, Design-Question Decisions table, subtask blueprint row 5), and design/target-layout.md §1.3, §2 (rows 1,2,10), §3 (Subtask Blueprint row 5), and §4.3 (Runtime Verification Requirement).

---

### 85. Root scripts relocation scripts dir
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Research**:
  - [085_root_scripts_relocation_scripts_dir/reports/01_scripts-relocation-research.md]
  - [085_root_scripts_relocation_scripts_dir/reports/01_seed.md]
- **Plan**: [085_root_scripts_relocation_scripts_dir/plans/01_scripts-dir-relocation.md]
- **Summary**: [085_root_scripts_relocation_scripts_dir/summaries/01_scripts-dir-relocation-summary.md]

**Description**: Relocate root shell scripts into a new scripts/ directory in the NixOS/Home Manager dotfiles repo (task 81 Tier 0, subtask blueprint #4, no dependencies). Move install.sh, update.sh, and build-usb-installer.sh into scripts/ (test-sasl.sh is deleted by subtask 82, not moved here). Update all direct references to these scripts in root README.md, docs/testing.md, and docs/usb-installer.md in the SAME subtask so no doc goes stale. Inherited cross-cutting protocol: use `git mv` or `git add` on the new/old paths (never `git add -A`) before running verification, since flake.nix's `root = self` means the harness only sees git-tracked content — an unstaged move looks like a stale-success or a confusing 'file not found' failure. Verification level: build-only inertness — `grep` across docs shows only `scripts/`-prefixed paths; `./scripts/update.sh` and `./scripts/install.sh` run; `nix flake check` green (these scripts are not consumed by Nix evaluation but doc/README references must be exact). Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("Root files" table), reports/02_team-research.md (subtask blueprint row 4, decision table row 5), and design/target-layout.md §1.3 (Target Directory Layout, scripts/ section), §2 (Decision Table row 5), and §3 (Subtask Blueprint row 4).

---

### 84. Nix flake check ci gate
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Plan**: [084_nix_flake_check_ci_gate/plans/01_ci-flake-check-gate.md]
- **Summary**: [084_nix_flake_check_ci_gate/summaries/01_ci-flake-check-gate-summary.md]
- **Research**: [084_nix_flake_check_ci_gate/reports/01_seed.md]

**Description**: Add a `nix flake check` CI gate to the NixOS/Home Manager dotfiles repo (task 81 Tier 0, subtask blueprint #3 — NEW subtask, no dependencies). Add a GitHub Actions workflow under .github/workflows/ that runs `nix flake check` on push/PR (the repo already has a GitHub remote, free for personal repos), and/or a local pre-commit hook as a complement. This closes the exact gap that let tasks 67 (R env/ICU), 68 (zfs-kernel), and 69 (lectic specialArgs) go undetected until an unrelated task's audit surfaced them — cheap (one workflow file), high ROI, and explicitly first-class Tier-0 so it is in place before the bulk of the remaining reorg subtasks land. Inherited cross-cutting protocol: stage the new workflow file with `git add <specific path>` before verifying locally. Verification level: build-only inertness — workflow runs green on a trivial PR/push; local `nix flake check` still passes. Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md ("NEW — CI gate" subtask and "CI-gate rationale" in Migration Philosophy), and design/target-layout.md §3 (Subtask Blueprint row 3) and §4.4 (CI-Gate Rationale).

---

### 83. Git hygiene specs tmp nixos repo
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Research**:
  - [083_git_hygiene_specs_tmp_nixos_repo/reports/01_git-hygiene-specs-tmp.md]
  - [083_git_hygiene_specs_tmp_nixos_repo/reports/01_seed.md]
- **Plan**: [083_git_hygiene_specs_tmp_nixos_repo/plans/01_git-hygiene-untrack-tmp.md]
- **Summary**: [083_git_hygiene_specs_tmp_nixos_repo/summaries/01_git-hygiene-untrack-tmp-summary.md]

**Description**: Fix git hygiene in the NixOS/Home Manager dotfiles repo (task 81 Tier 0, subtask blueprint #2, no dependencies). Untrack specs/tmp/* contents (specs/tmp/claude-tts-notify.log, specs/tmp/claude-tts-last-notify, specs/tmp/lit.md) via `git rm --cached` and extend .gitignore to cover specs/tmp/ contents — but the specs/tmp/ DIRECTORY ITSELF must continue to exist on disk (Critic correction: .claude/scripts/skill-base.sh's atomic state-write pattern, skill-base.sh:356,362, depends on the directory being present). Note specs/tmp/lit.md is an unrelated mbsync troubleshooting note, not --lit tooling — no decoupling work needed. Fix update.sh's mangled shebang (`#\!/bin/bash` from a heredoc write) and stray `complete\!` text. Inherited cross-cutting protocol: stage changes with `git add <specific paths>` (never `git add -A`) before verification (flake.nix's `root = self`). Scope boundary: this subtask touches specs/tmp/ and .gitignore/update.sh only — it does NOT touch any other content under specs/ or .claude/. Verification level: build-only inertness — `git status --porcelain` clean on specs/tmp/ contents, directory still present, `./update.sh` still executes, `nix flake check` green. Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("Git hygiene" section), reports/02_team-research.md (Critic correction on specs/tmp/, subtask blueprint row 2), and design/target-layout.md §3 (Subtask Blueprint row 2) and §4.1 (git-add-before-verify protocol).

---

### 82. Dead code removal nixos repo
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: None
- **Research**:
  - [082_dead_code_removal_nixos_repo/reports/02_dead-code-removal-research.md]
  - [082_dead_code_removal_nixos_repo/reports/01_seed.md]
- **Plan**: [082_dead_code_removal_nixos_repo/plans/02_dead-code-removal-plan.md]
- **Summary**: [082_dead_code_removal_nixos_repo/summaries/02_dead-code-removal-summary.md]

**Description**: Remove dead code and orphaned files from the NixOS/Home Manager dotfiles repo (task 81 Tier 0, subtask blueprint #1, no dependencies). Delete: home-modules/ directory (mcp-hub.nix + its README, plus the commented-out import at home.nix:6 and stale comments at modules/home/core/shell.nix:8 and modules/home/packages/email-tools.nix:38), modules/opencode.nix (dead AND broken — references ../../config/opencode.json above repo root), packages/neovim.nix (unreferenced wrapNeovimUnstable derivation — NOT modules/home/core/neovim.nix, confirmed a different, live file), test-sasl.sh, test-update.md, root TODO.md (superseded by specs/TODO.md), and 5 wallpapers/ scaffolding files (IMPLEMENTATION_COMPLETE.md, README.md, SETUP_INSTRUCTIONS.md, verify-setup.sh, SAVE_IMAGE_HERE.txt). Widen packages/test-mcphub.sh removal to also patch its 3 doc references (docs/packages.md:244, docs/applications.md:26, packages/README.md:260-277) in the SAME subtask — it is doc-referenced, not orphaned (Critic correction). Drop the config/rclone.conf 'verify' step entirely — already untracked/resolved, nothing to do. Inherited cross-cutting protocol: stage each deletion/edit with `git add <specific paths>` (never `git add -A`) before running verification, since flake.nix's `root = self` means the harness only sees git-tracked content. Verification level: build-only inertness — `nix flake check` + `nixos-rebuild build --flake .#nandi/.#hamsa/.#garuda` + `nix build .#homeConfigurations.benjamin.activationPackage`; `git status` shows only deletions + the 3 doc edits; harness green (none of these files are imported anywhere). Seed context: specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md ("home-modules/", "packages/" sections), reports/02_team-research.md (subtask blueprint row 1), and design/target-layout.md §3 (Subtask Blueprint row 1) and §4 (Migration Safety & Verification).

---

### 81. Reorganize nixos dotfiles repository design
- **Status**: [COMPLETED]
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
- **Plan**: [081_reorganize_nixos_dotfiles_repository_design/plans/03_reorg-design-and-subtasks.md]
- **Design**: [081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md]

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
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: nix-infrastructure
- **Dependencies**: Task 86
- **Research**: [069_consolidate_dual_home_manager_config/reports/01_verify-task-86-fold-in.md]
- **Plan**: [069_consolidate_dual_home_manager_config/plans/01_unify-lectic-specialargs.md]
- **Summary**: [069_consolidate_dual_home_manager_config/summaries/01_unify-lectic-specialargs-summary.md]

**Description**: SCOPE UPDATE (2026-07): now depends on task 86 and is serialized after it. Task 81's design decomposition folded this task's resolution into subtask 86 (and, failing that, subtask 91) as Option A — DOCUMENTATION-ONLY. Do NOT run concurrently with 86: they both touch docs/dual-home-manager.md, home.nix, lib/mkHost.nix and flake.nix. After 86 lands, first VERIFY whether 86 already unified the extraSpecialArgs and closed docs/dual-home-manager.md; if so, this task is a verification-only close-out (mark completed, no code changes). Only if 86 did NOT fold it, complete the Option-A documentation resolution here — do NOT redo 86's aggregator/wiring code changes. Original framing follows. --- Consolidate the dual home-manager setup so there is a single source of truth. Both the NixOS-integrated path (home-manager.users.benjamin via lib/mkHost.nix) and the standalone path (homeConfigurations.benjamin) import home.nix but pass subtly different extraSpecialArgs - notably lectic as the raw flake input (integrated) vs the resolved package (standalone). This asymmetry caused the lectic regression caught in task 66 phase 9. Decide the intended behavior (likely: both should ship the built lectic package), unify the specialArgs, and document in docs/dual-home-manager.md. See the open question recorded there.

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
