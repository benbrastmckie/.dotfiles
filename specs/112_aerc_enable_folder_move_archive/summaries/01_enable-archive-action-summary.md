# Implementation Summary: Task #112

**Completed**: 2026-07-14
**Duration**: ~15 minutes (autonomous portion only)

## Overview

Enabled aerc's notmuch-backend `:archive`/`:delete` mutations, which were previously a silent
no-op because `maildir-store` was unset in `accounts.conf`. Added `maildir-store = ~/Mail` and
`multi-file-strategy = act-dir` to both `[gmail]` and `[logos]` account sections, plus two
documenting comments, and verified the change builds cleanly. This is the autonomous,
config-only portion of the task; the live-mail verification phases (3-6 of the plan) require
driving aerc's interactive TUI and mutating real Gmail/Logos mail, which an autonomous
orchestrator agent must not do, and are deferred to the user as a manual checklist below.

## What Changed

- `modules/home/email/aerc.nix`:
  - Added `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` to the `[gmail]` section
    of the `accounts.conf` `home.file` block, directly after `source = notmuch://~/Mail`.
  - Added the identical two lines to the `[logos]` section, directly after its `source =` line.
  - Added an inline forward-compat comment above the `[gmail]` addition: `maildir-store` is
    required by the installed nixpkgs aerc 0.21.0 notmuch worker (without it, `:archive`/`:delete`
    return `errUnsupported` — the mechanism behind the prior silent no-op); it is deprecated in
    favor of `enable-maildir` on upstream aerc master, and should be removed (or switched to
    `enable-maildir`) if/when the nixpkgs `aerc` derivation is bumped past that upstream change.
    The `[logos]` section cross-references this comment rather than repeating it.
  - Added a one-line comment next to the `a = ":archive flat<Enter>"` binding in the `messages`
    keymap section recording the deliberate decision to leave single-message archive unprompted.
  - No other line in `accounts.conf`, the keymaps, or elsewhere in the file was changed.
    `archive = All_Mail` / `archive = Archive` are unchanged. `maildir-account-path` was
    deliberately NOT set for either account, per the plan's non-goals.

## Decisions

- **`a`/`A`/`d`/`D` unprompted-vs-prompted split (finding 9, unchanged)**: single-message archive
  (`a`) is deliberately left unprompted — it is a reversible file move with low blast radius,
  matching standard mail-client convention. `A` (bulk archive), `d` (delete), and `D` (hard
  delete) remain behind `:prompt` confirmations because their blast radius is larger or
  irreversible. This decision is now recorded inline in `aerc.nix` next to the `a` binding, not
  just in this summary.
- **No `Proposed-*` / wrapper / `mail-guard.sh` changes**: confirmed per research finding 9 that
  none of the `Proposed-Delete`/`Proposed-Archive`/`Proposed-Unsure` view bindings, the five
  wrapper binaries, or the `mail-guard.sh` PreToolUse allowlist needed any change for this task.
  None were touched.
- **`maildir-store` forward-compat note added, not acted on**: upstream aerc master has already
  deprecated `maildir-store` in favor of `enable-maildir`, but the nixpkgs-packaged aerc 0.21.0
  still uses `maildir-store`. The comment flags this for a future maintainer bumping the
  derivation; no `enable-maildir` fallback was added now since it is not yet needed.
- **Commit deferred to orchestrator**: per the plan's explicit non-goal and this task's
  instructions, no `git add`/`git commit` was run by this agent. The working tree holds
  intermingled uncommitted hunks for tasks 111/113 in the same file; the orchestrator performs
  the final consolidated commit.

## Plan Deviations

- **Phase 2, sub-task "Activate/switch the new generation"**: skipped — deferred to manual user.
  Activating/switching the live home-manager generation changes the running system and is
  outside this autonomous agent's scope. Build-only verification (`home-manager build`) was
  performed instead; the user must run `home-manager switch --flake .#benjamin` (or equivalent)
  before aerc will read the new `accounts.conf` on disk.
- **Phase 3 (Live single-file archive verification, Gmail)**: marked `[PARTIAL]`, all tasks
  skipped — deferred to manual user. This phase requires driving aerc's interactive TUI and
  running `mail-sync gmail` against real mail. An autonomous orchestrator agent cannot drive a
  TUI and, per explicit task instructions, must not run any mail-sync/wrapper command or archive
  real mail. See the Manual Verification Checklist below.
- **Phase 4 (Live multi-file archive / act-dir/INBOX-tab risk, Gmail)**: marked `[PARTIAL]`, all
  tasks skipped for the same reason as Phase 3. The finding-7 risk (whether `act-dir`'s `curDir`
  resolution succeeds from the `INBOX` tab, or requires a `:cf Gmail<Enter>` switch first because
  the `INBOX` querymap alias may not match a physical `FolderMap` key) is untested by this agent
  and is the central open question in the checklist below.
- **Phase 5 (Live archive verification, Logos)**: marked `[PARTIAL]`, all tasks skipped for the
  same reason. Deferred to manual user.
- **Phase 6 (Record decisions and finalize)**: marked `[PARTIAL]`. The decisions that do not
  depend on live-mail results (the `a`-unprompted decision, the finding-9 no-change confirmation,
  the commit-deferral note) are recorded above. The tab-context result and any follow-up-keybind
  decision depend on the Phase 4 live outcome, which the user must report back after running the
  checklist below; only then can the follow-up-task decision (new task vs. none needed) be made.

## Verification

- `home-manager build --flake .#benjamin`: **Success** (exit 0). Built 3 derivations
  (`hm_.configaercaccounts.conf.drv`, `home-manager-files.drv`, `home-manager-generation.drv`)
  with no errors.
- Rendered output inspected directly from the build result
  (`result/home-files/.config/aerc/accounts.conf`): confirmed both `[gmail]` and `[logos]`
  sections contain `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` immediately after
  their respective `source =` lines, with `archive = All_Mail` / `archive = Archive` unchanged
  and no other line altered.
- No `nixos-rebuild` run — this is a Home Manager-only change (no NixOS module touched).
- No live-mail verification performed by this agent (see Manual Verification Checklist).

## Manual Verification Checklist (user-run, after `home-manager switch`)

The config change only **enables** the archive capability — no mail moves until you manually
drive aerc and sync. Run through this checklist yourself:

1. **Activate the new generation** (if not already done):
   ```
   home-manager switch --flake .#benjamin
   ```
   Then restart/reload aerc (quit and relaunch, or `:reload` if supported) so the notmuch worker
   re-reads `accounts.conf` — it only parses `maildir-store` in its `Configure`/`NewWorker` path.

2. **Archive one ordinary single-file message (Gmail, INBOX tab)**:
   - Pick a Gmail inbox message whose Message-ID has exactly one file on disk (e.g. via
     `notmuch search --output=files <query>` and counting files — pick one NOT among the ~35/85
     multi-file set).
   - From the INBOX tab, press `a` to archive it.
   - Confirm it disappears from the INBOX tab and appears under the `All_Mail` querymap tab
     locally (`:cf All_Mail<Enter>` or the corresponding tab).

3. **Archive one known multi-file message (Gmail, INBOX tab) — exercises the finding-7 risk**:
   - Pick a message known to have copies in both `Gmail/cur/` and `Gmail/.All_Mail/cur/` (one of
     the ~35/85 identified in research).
   - From the INBOX tab, press `a`. Two outcomes are possible:
     - **It succeeds** — the file moves and disappears from INBOX. Record this; it means the
       `curDir`-empty analysis from the source review did not manifest in practice for the
       `INBOX` tab.
     - **It fails with `refusing to act on multiple files`** — this confirms the finding-7 risk:
       `act-dir`'s current-folder resolution keys off the literal open tab name, and the `INBOX`
       querymap alias (from task 110) may not match a physical `FolderMap` key. **Retry**: switch
       to the literal folder tab with `:cf Gmail<Enter>`, then press `a` again on the same
       message. Record that the literal-folder tab was required.
   - Record the definitive result (which tab context made `act-dir` take effect) — this is the
     primary open knowledge output of this task, needed before deciding on any follow-up keybind
     change (e.g., binding `a` to `:cf`-first). Default per research: if the INBOX tab already
     works, no keybind change is needed; if the `:cf` workaround is required, prefer spinning up
     a **new task** for a keybind fix rather than expanding this one's scope.

4. **Sync to the server**:
   ```
   mail-sync gmail
   ```
   (or the `$` keybind inside aerc, which is bound to `:exec mail-sync gmail<Enter>`)

5. **Confirm in the Gmail web UI** (https://mail.google.com):
   - Both test messages (the single-file one and the multi-file one) no longer carry the `INBOX`
     label.
   - Both messages are still present in **All Mail** — i.e., archived, NOT trashed.
   - **No server-side duplicate** was created for the multi-file message (check All Mail search
     for the same Subject/Message-ID — there should be exactly one copy, not two). This guards
     against the finding-8 risk that `act-dir` can leave a UID-stripped duplicate under
     `All_Mail/cur/` that `mbsync` might push as a new message (the `gmail-all` channel is
     `Create Near`-only, so a push is not expected, but this must be confirmed empirically).

6. **Repeat for the Logos account**:
   - Confirm Protonmail Bridge connectivity first (task 108's CA-trust fix, commit `6c42117`, is
     already merged and is a prerequisite).
   - Pick one ordinary and, if present, one multi-file Logos inbox message.
   - Archive each from the INBOX tab (apply the `:cf Logos<Enter>` workaround for the multi-file
     case if step 3 showed the literal-folder tab is required for Gmail — the same mechanism
     should apply).
   - Run `mail-sync logos`.
   - In the Protonmail web UI, confirm each message left the inbox and landed in `Archive`
     (archived, not trashed), with no duplicate.
   - If the bridge is unavailable, treat the Gmail result as authoritative for this task and note
     the Logos check as still-pending rather than blocking anything.

7. **Report back** (optional but recommended): the tab-context outcome from step 3 determines
   whether a follow-up task is needed for a `:cf`-first keybind change. If you want that decision
   tracked, note the outcome and either confirm "no follow-up needed" or ask for a new task to be
   created for the keybind fix.

## Notes

- No `Proposed-*` binding, wrapper binary (`email-archive-confirmed`, etc.), or `mail-guard.sh`
  allowlist entry was touched — confirmed unnecessary per research finding 9.
- This task's git commit is intentionally NOT performed here (orchestrator-handled, consolidated
  commit across tasks 110-113 sharing `modules/home/email/aerc.nix`).
- Rollback: the config change is 4 lines + 2 comments in one file; reverting the edit and
  rebuilding restores the prior silent-no-op behavior. Archive itself is a reversible file move
  (moving a message back into the inbox folder, or re-labeling `INBOX` in the Gmail web UI and
  re-syncing, undoes it).
