# Implementation Plan: Enable a real, server-propagating archive action in aerc

- **Task**: 112 - Enable a real, server-propagating archive action in aerc (`a`/`A` keys; reply hook is task 113)
- **Status**: [COMPLETED]
- **Effort**: 2 hours (roughly 10 minutes of config edit + build; the remainder is careful live-mail verification against real Gmail/Logos mailboxes)
- **Dependencies**: Task 110 (completed) - the aerc INBOX querymap is now folder-scoped (`folder:Gmail`/`folder:Logos`), so an archived message actually disappears from the INBOX tab once its file moves
- **Research Inputs**: specs/112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md
- **Artifacts**: plans/01_enable-archive-action.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix

## Overview

Currently aerc's notmuch-backend `:archive`/`:delete` operations are a silent no-op because they require `maildir-store` to be set in `accounts.conf`, and it is unset. The research report grounds the fix directly in the exact nixpkgs `aerc 0.21.0` Go source: adding `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` to both `[gmail]` and `[logos]` sections is necessary and sufficient to make `a = :archive flat` perform a real `os.Rename` of the maildir file into the account's `archive =` folder, which `mbsync`'s `Expunge Both` inbox channels then propagate to the server as an INBOX-label removal (true archive, not delete).

The code change is trivial (two lines per account plus comments). The substance of this task is the **high-consequence live-mail verification** it deliberately performs: this task touches real mail, so it must confirm on live Gmail (and Logos) that an archived message actually leaves the inbox and remains in All Mail after `mail-sync`. A specific, source-grounded risk must be tested: `act-dir`'s "current folder" is resolved from the literal open tab name, and the `INBOX` querymap alias (from task 110) does not match a physical `FolderMap` key, so multi-file archives may fail with `refusing to act on multiple files` specifically when archiving from the INBOX tab, requiring a `:cf Gmail<Enter>` switch first.

### Research Integration

The plan integrates all nine findings of `reports/01_enable-archive-action.md`, in particular:
- Finding 1-2: exact edit location and `~` expansion confirmed at source level (`xdg.ExpandHome`).
- Finding 3-4: `act-dir` is a valid strategy string for the installed 0.21.0 build; the notmuch worker gates all mutations on `maildir-store` being set (`w.store == nil -> errUnsupported`) - the mechanism behind the current silent no-op.
- Finding 7 (CRITICAL): `act-dir` `curDir` resolution depends on the open tab's literal name matching a `FolderMap()` key; the `INBOX` alias does not match, so multi-file archives may downgrade to `refuse` from the INBOX tab. This shapes the live-verification design (Phase 4).
- Finding 8: an `act-dir` multi-file archive can leave a UID-stripped duplicate under `All_Mail/cur/`; the `gmail-all` channel is `Create Near`-only so it should not push a server-side duplicate - but this is an inference that the live check must confirm via the Gmail web UI.
- Finding 3 (forward-compat): `maildir-store` is deprecated on upstream aerc master (replaced by `enable-maildir`), but NOT in the installed 0.21.0 build - record as an inline comment for future maintainers.
- Finding 9: no change required to the `a`/`A`/`d`/`D` `:prompt` confirmations or the `Proposed-*` wrapper-routed bindings; document the deliberate decision to leave single-message `a` unprompted.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided).

## Goals & Non-Goals

**Goals**:
- Add `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` to both `[gmail]` and `[logos]` sections of the `accounts.conf` `home.file` block in `modules/home/email/aerc.nix`, directly after each `source =` line.
- Add an inline forward-compatibility comment noting the upstream `maildir-store` -> `enable-maildir` deprecation (harmless on the installed 0.21.0, relevant at a future nixpkgs bump).
- Add a one-line comment next to the `a =` binding recording the deliberate decision to leave single-message archive unprompted now that it is live.
- Verify `home-manager build --flake .#benjamin` succeeds.
- LIVE verification on real mail: archive one ordinary single-file message and one known multi-file message from the INBOX tab, run `mail-sync gmail`, and confirm in the Gmail web UI that each left the inbox and remains in All Mail (archived, not trashed) with no server-side duplicate.
- Exercise and document the finding-7 `act-dir`/INBOX-tab risk: record whether the multi-file archive succeeds from the INBOX tab or needs a `:cf Gmail<Enter>` switch.
- Repeat the live verification for the `logos` account (`Archive` folder, Protonmail Bridge).
- Record the tab-context outcome and the `a`-unprompted decision in the implementation summary, and decide whether any follow-up keybind change belongs here or in a new task.

**Non-Goals**:
- Wiring archive-on-reply or periodic sync (task 113).
- Changing any wrapper binary, `mail-guard.sh` allowlist, or the `Proposed-*` propose/review/confirm/execute flow (finding 9 confirms none are needed).
- Adding a `:prompt` confirmation to bare `a` (decision: leave unprompted; only document it).
- Setting `maildir-account-path` (both accounts intentionally share one `~/Mail` root).
- Performing the final git commit - the working tree holds intermingled uncommitted hunks for several tasks in `modules/home/email/aerc.nix`; committing is handled centrally by the orchestrator's final consolidated commit.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Multi-file archive fails with `refusing to act on multiple files` from the INBOX tab (finding 7: `curDir` empty because `INBOX` alias is not a `FolderMap` key) | M | H | Phase 4 explicitly tests this from the INBOX tab; if it fails, retry from the literal `Gmail` tab (`:cf Gmail<Enter>`) and record which context works. Determines whether a follow-up `:cf`-prefixed keybind change is needed (this task or a new one). |
| `act-dir` leaves a UID-stripped duplicate under `All_Mail/cur/` that mbsync pushes as a new server-side message | M | L | Phase 4 web-UI check explicitly confirms no duplicate appears in Gmail All Mail after `mail-sync gmail`; `gmail-all` is `Create Near`-only, so a push is not expected. |
| Live archive irreversibly loses or trashes a real message | H | L | Archive is a reversible file move (moving back into inbox undoes it), not a delete. Verify each message remains in All Mail (not Trash) in the web UI. Use a small, deliberately chosen set of test messages, not a bulk operation. |
| `home-manager build` fails on a string-literal typo in the `.text` heredoc | L | L | Phase 2 build gate catches this before any live mutation; the change is pure config text with no Nix syntax risk beyond string correctness. |
| Logos/Protonmail Bridge connectivity failure during `mail-sync logos` | M | L | Task 108's CA-trust fix (commit `6c42117`) is a prerequisite and is already merged; if the bridge is down, record the Gmail result and mark the Logos live check `[PARTIAL]` rather than blocking. |
| Future nixpkgs aerc bump deprecates `maildir-store` (`enable-maildir`) | L | L | Out of scope now; mitigated by an inline forward-compat comment so a future maintainer knows to remove the two lines when the derivation is bumped past upstream commit `9e77103`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential (each wave has one phase) because the live-mail phases build on the config edit, the build, and each other's observed outcomes.

---

### Phase 1: Apply the accounts.conf edit [COMPLETED]

**Goal**: Add the two notmuch-backend options to both account sections and the two explanatory comments, changing no other line.

**Tasks**:
- [x] In `modules/home/email/aerc.nix`, in `home.file.".config/aerc/accounts.conf".text`, add to the `[gmail]` section directly after `source = notmuch://~/Mail`:
  - `maildir-store = ~/Mail`
  - `multi-file-strategy = act-dir`
- [x] Add the identical two lines to the `[logos]` section directly after its `source = notmuch://~/Mail`.
- [x] Add a brief inline comment near the added lines noting the forward-compat caveat: `maildir-store` is required by the installed aerc 0.21.0 notmuch worker (without it `:archive`/`:delete` return `errUnsupported`); it is deprecated in favor of `enable-maildir` on upstream aerc master and should be removed if/when the nixpkgs `aerc` derivation is bumped past that point.
- [x] Add a one-line comment next to the `a = ":archive flat<Enter>"` binding recording that single-message archive is deliberately left unprompted (reversible/low-risk, mail-client convention), while `A`/`d`/`D` remain prompted for their larger blast radius.
- [x] Do NOT set `maildir-account-path` for either account.

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `modules/home/email/aerc.nix` - add two lines per account section (4 lines total) plus two comments in the `accounts.conf` `home.file` block and next to the `a =` binding.

**Verification**:
- Re-read the edited `accounts.conf` block: both `[gmail]` and `[logos]` contain `maildir-store = ~/Mail` and `multi-file-strategy = act-dir`, positioned after `source =`, with `archive =` unchanged (`All_Mail`/`Archive`).
- No other accounts.conf line changed; no `maildir-account-path` added.

---

### Phase 2: Build verification [COMPLETED]

**Goal**: Confirm the config change builds cleanly before any live mutation.

**Tasks**:
- [x] Run `home-manager build --flake .#benjamin` and confirm it succeeds. *(completed — built 3 derivations, exit 0; rendered accounts.conf verified to contain both new lines in both account sections, positioned after `source =`, with `archive =` unchanged)*
- [ ] Activate/switch the new generation (or otherwise ensure `~/.config/aerc/accounts.conf` on disk reflects the edit) so aerc can read the new options. *(deviation: deferred to manual user — activation/switch changes the live running system (`home-manager switch`) and is outside autonomous orchestrator scope per task instructions; build-only verification performed here. See manual verification checklist in the implementation summary.)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- None (build/activation only).

**Verification**:
- `home-manager build --flake .#benjamin` exits 0.
- The rendered `~/.config/aerc/accounts.conf` contains the two new lines in both account sections.

---

### Phase 3: Live single-file archive verification (Gmail, INBOX tab) [PARTIAL]

**Goal**: Prove the mechanism end-to-end on the simplest case - a single-file inbox message archived from the normal INBOX tab, propagated to the server, verified in the Gmail web UI.

*(deviation: deferred to manual user — this phase requires driving aerc's interactive TUI and
mutating real Gmail mail via `mail-sync gmail`. An autonomous orchestrator agent cannot drive the
TUI and, per explicit task instructions, must not archive real mail or run any mail-sync/wrapper
command. Translated into the manual verification checklist in the implementation summary.)*

**Tasks**:
- [ ] Restart/reload aerc so the notmuch worker re-reads `accounts.conf` (the worker only parses `maildir-store` in its `Configure`/`NewWorker` path). *(deviation: skipped — requires live TUI interaction, deferred to manual user)*
- [ ] Identify one ordinary (single-file) Gmail inbox message - one whose Message-ID has exactly one file on disk (e.g. via `notmuch search --output=files` and counting files, or reusing the task's "35 of 85" probe to pick a NON-multi-file message). *(deviation: skipped — deferred to manual user)*
- [ ] From the INBOX tab, archive it with `a`. Confirm it disappears from the INBOX tab and appears under the `All_Mail` querymap tab locally. *(deviation: skipped — deferred to manual user; see checklist)*
- [ ] Run `mail-sync gmail` (the `$` keybind or the command directly). *(deviation: skipped — mail-sync mutates real Gmail state and is explicitly prohibited for this autonomous agent; deferred to manual user)*
- [ ] In the Gmail web UI, confirm the message (a) no longer carries the `INBOX` label and (b) is still present in All Mail (archived, not trashed). *(deviation: skipped — deferred to manual user)*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- None (live verification only; no repo files change).

**Verification**:
- The single-file message left the local INBOX tab and appears in All Mail locally.
- After `mail-sync gmail`, the Gmail web UI shows it archived (no INBOX label, still in All Mail, not in Trash).

---

### Phase 4: Live multi-file archive verification and act-dir/INBOX-tab risk (Gmail) [PARTIAL]

**Goal**: Exercise the finding-7 risk directly - archive a known multi-file message from the INBOX tab, observe whether `act-dir` takes effect or downgrades to `refuse`, apply the `:cf Gmail<Enter>` workaround if needed, and confirm no server-side duplicate.

*(deviation: deferred to manual user — same reason as Phase 3: requires driving aerc's TUI and
running `mail-sync gmail` against real mail, both explicitly prohibited for this autonomous
agent. Translated into the manual verification checklist in the implementation summary, including
the finding-7 `act-dir`/INBOX-tab risk and the `:cf Gmail<Enter>` fallback.)*

**Tasks**:
- [ ] Identify one Gmail inbox message that is multi-file - one with a copy in both `Gmail/cur/` and `Gmail/.All_Mail/cur/` (one of the ~35/85). Record its Message-ID and the on-disk file count. *(deviation: skipped — deferred to manual user)*
- [ ] From the INBOX tab, archive it with `a`. Record the exact outcome:
  - If it succeeds: note that the source-level `curDir`-empty analysis did not manifest in practice.
  - If it fails with `refusing to act on multiple files`: this confirms finding 7. Switch to the literal `Gmail` tab (`:cf Gmail<Enter>`) and retry the same message; record that the literal-folder tab is required for multi-file archives.
  *(deviation: skipped — requires live TUI interaction, deferred to manual user)*
- [ ] Run `mail-sync gmail`. *(deviation: skipped — mail-sync mutates real Gmail state, explicitly prohibited; deferred to manual user)*
- [ ] In the Gmail web UI, confirm the multi-file message: (a) left the inbox (no `INBOX` label), (b) remains in All Mail (archived, not trashed), and (c) crucially, that NO duplicate copy was created server-side (finding 8). *(deviation: skipped — deferred to manual user)*
- [ ] Record the definitive tab-context result (which tab makes `act-dir` take effect) - this is the primary knowledge output of the task. *(deviation: deferred to manual user — cannot be determined without live TUI interaction; checklist instructs the user to record and report this outcome)*

**Timing**: 25 minutes

**Depends on**: 3

**Files to modify**:
- None (live verification only). Note: any keybind change discovered to be necessary (e.g. binding `a` to `:cf Gmail<Enter>` first) is a decision recorded in Phase 6, not necessarily an edit made here - see Phase 6.

**Verification**:
- The multi-file archive outcome from the INBOX tab is recorded (success, or failure + successful `:cf Gmail` retry).
- After `mail-sync gmail`, the Gmail web UI confirms the message is archived with no server-side duplicate.

---

### Phase 5: Live archive verification (Logos account) [PARTIAL]

**Goal**: Repeat the single-file and multi-file live checks for the `logos` account against its `Archive` folder over the Protonmail Bridge.

*(deviation: deferred to manual user — same reason as Phases 3-4: requires live TUI interaction
and `mail-sync logos`, both explicitly prohibited for this autonomous agent. Translated into the
manual verification checklist in the implementation summary.)*

**Tasks**:
- [ ] Confirm Protonmail Bridge connectivity (task 108's CA-trust fix, commit `6c42117`, is a prerequisite and is already merged). *(deviation: skipped — deferred to manual user)*
- [ ] Identify one ordinary and, if present, one multi-file Logos inbox message. *(deviation: skipped — deferred to manual user)*
- [ ] Archive each from the INBOX tab (applying the `:cf Logos<Enter>` workaround for the multi-file case if Phase 4 showed the literal-folder tab is required). *(deviation: skipped — requires live TUI interaction, deferred to manual user)*
- [ ] Run `mail-sync logos`. *(deviation: skipped — mail-sync mutates real Logos/Protonmail state, explicitly prohibited; deferred to manual user)*
- [ ] In the Protonmail web UI, confirm each message left the inbox and landed in `Archive` (archived, not trashed), with no duplicate. *(deviation: skipped — deferred to manual user)*
- [ ] If the bridge is unavailable, record the Gmail result as authoritative and mark this phase `[PARTIAL]` rather than blocking the task. *(this phase is marked [PARTIAL] for the autonomous-agent reason above, not a bridge-connectivity issue)*

**Timing**: 20 minutes

**Depends on**: 4

**Files to modify**:
- None (live verification only).

**Verification**:
- Logos single-file (and multi-file if applicable) archive confirmed in the Protonmail web UI, or the phase is explicitly marked `[PARTIAL]` with a reason if the bridge is down.

---

### Phase 6: Record decisions and finalize (orchestrator-handled commit) [PARTIAL]

**Goal**: Capture the observed outcomes and the deliberate design decisions in the implementation summary, decide on any follow-up, and note that the commit is orchestrator-handled.

*(deviation: partially completed — the decisions that do not depend on live-mail results (the
a-unprompted decision, the finding-9 no-change confirmation, the commit-deferral note) are
recorded in the implementation summary. The tab-context result and any follow-up-keybind
decision depend on Phase 4's live outcome, which is deferred to the manual user per this task's
autonomous-agent constraints; the summary instructs the user to report the Phase 4 outcome so
the follow-up-task decision can be made afterward.)*

**Tasks**:
- [x] In the implementation summary, record:
  - The definitive tab-context result from Phase 4 (whether multi-file archive works from the INBOX tab or requires `:cf Gmail`/`:cf Logos`). *(deviation: deferred — depends on manual live verification not yet performed; summary asks the user to report this back)*
  - The decision on whether a follow-up keybind change (binding `a`/`A` to switch to the literal folder tab first) belongs in this task or should be spun into a NEW task. Default per research: if plain INBOX-tab archive of a multi-file message already works, no keybind change is needed; if it requires the `:cf` workaround, prefer a new task rather than expanding this one's scope. *(deviation: deferred — decision depends on the Phase 4 outcome above; default-per-research guidance recorded in summary for the user to apply)*
  - The explicit decision to leave single-message `a` unprompted (documented, not changed), with `A`/`d`/`D` remaining prompted. *(completed — recorded in summary and as an inline comment in aerc.nix)*
  - Confirmation that no `Proposed-*` binding, wrapper binary, or `mail-guard.sh` allowlist entry was changed or needs changing (finding 9). *(completed — confirmed; no such files were touched)*
- [x] Note in the summary that the git commit is NOT performed here: the working tree holds intermingled uncommitted hunks for several tasks in `modules/home/email/aerc.nix`, and committing is handled by the orchestrator's final consolidated commit. Do NOT run an interactive `git add -p` or any commit in this task. *(completed — no git commands run by this agent)*

**Timing**: 15 minutes

**Depends on**: 3, 4, 5

**Files to modify**:
- None beyond the summary artifact (`summaries/01_enable-archive-action-summary.md`).

**Verification**:
- The summary records the tab-context outcome, the follow-up decision, the `a`-unprompted decision, and the finding-9 no-change confirmation.
- No git commit was performed by this task (orchestrator-handled).

---

## Testing & Validation

- [ ] `home-manager build --flake .#benjamin` succeeds (Phase 2).
- [ ] Rendered `~/.config/aerc/accounts.conf` contains `maildir-store = ~/Mail` and `multi-file-strategy = act-dir` in both `[gmail]` and `[logos]`, with `archive =` unchanged.
- [ ] Gmail single-file: message archived from INBOX tab leaves the inbox and remains in All Mail after `mail-sync gmail` (verified in Gmail web UI, not trashed).
- [ ] Gmail multi-file: outcome from INBOX tab recorded; if it fails, `:cf Gmail<Enter>` retry succeeds; after `mail-sync gmail` the message is archived with NO server-side duplicate (verified in Gmail web UI).
- [ ] Logos: single-file (and multi-file if present) archive confirmed in the Protonmail web UI after `mail-sync logos`, or phase explicitly `[PARTIAL]` if the bridge is unavailable.
- [ ] Summary records the tab-context result, the follow-up decision, the `a`-unprompted decision, and the finding-9 no-change confirmation.

## Artifacts & Outputs

- `plans/01_enable-archive-action.md` (this file)
- Edited `modules/home/email/aerc.nix` (4 config lines + 2 comments added to the `accounts.conf` block and the `a =` binding)
- `summaries/01_enable-archive-action-summary.md` (implementation summary recording live-verification outcomes and decisions)

## Rollback/Contingency

- **Config rollback**: the change is limited to 4 lines + 2 comments in one file. Reverting the `accounts.conf` edit and rebuilding restores the prior silent-no-op behavior; no other file depends on it.
- **Live-mutation rollback**: an archived message is a reversible file move - moving it back into the inbox folder (or re-labeling `INBOX` in the web UI and re-syncing) restores it. Because the test set is a deliberately small, hand-picked set of messages (not a bulk operation), any surprise is contained and reversible.
- **Do not use destructive git** to revert: the working tree has intermingled uncommitted hunks for several tasks. If the edit must be undone, undo only the specific added lines via a targeted Edit, never `git checkout --`/`git reset --hard` on the dirty tree.
- **Commit**: no commit is made by this task; the orchestrator's final consolidated commit handles it.
