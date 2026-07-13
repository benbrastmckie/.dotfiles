# Implementation Plan: Logos mbsync Dotted-Name Hardening

- **Task**: 92 - logos_mbsync_group_labels_fix
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/01_mbsync-logos-diagnosis.md, reports/02_task-still-needed.md, reports/03_cross-repo-nvim-sync-linkage.md
- **Artifacts**: plans/03_logos-mbsync-hardening.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/nix.md
- **Type**: nix

## Overview

The original blocking bug (the wrapper's post-mutation `mbsync logos` reconcile exiting non-zero
because `Group logos` chained `logos-labels` onto the dotted Gmail-import label
`benbrastmckie@gmail.com` under `SubFolders Maildir++`) is ALREADY FIXED by commit a8f65ad, which
removed `logos-labels` from `Group logos` (landed via nvim task 826). This plan does NOT re-plan
that fix. It covers only the two residual hardening items in the Logos section of
`modules/home/email/mbsync.nix`: (1, high priority) negative dotted-name patterns on the
`logos-labels` and `logos-folders` channels so no dotted mailbox name can ever reach the Maildir++
store, and (2, low priority) a new `Group logos-full` for explicit on-demand full sync. Definition
of done: `home-manager build` evaluates cleanly with both changes, and the live `mbsync`
verification suite (a user-gated switch/sync step) passes.

### Research Integration

- **reports/01_mbsync-logos-diagnosis.md** — live diagnosis of the dotted-label crash under
  `SubFolders Maildir++`; supplies the exact negative-pattern sketch (`"!Labels/*.*"` /
  `"!Folders/*.*"`) and the `Group logos-full` shape, plus the verification commands.
- **reports/02_task-still-needed.md** — confirms a8f65ad fixed the blocking crash and that
  proposal parts 2 (`Group logos-full`) and 3 (negative patterns) remain unimplemented; narrows
  the task to exactly those two residual items.
- **reports/03_cross-repo-nvim-sync-linkage.md** — establishes that nvim task 851 wired `mbsync -a`
  (which runs `Group logos`, still containing `logos-folders`) onto hot keymaps `<leader>me` /
  `<leader>mN`, making the `logos-folders` negative pattern the single highest-value residual item;
  and that a single live `mbsync` check credits both this task and nvim task 851's remaining item.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Add `"!Labels/*.*"` to the `logos-labels` channel `Patterns` line and `"!Folders/*.*"` to the
  `logos-folders` channel `Patterns` line so dotted mailbox names never reach the Maildir++ store.
- Add a new `Group logos-full` covering the five core channels plus `logos-labels` and
  `logos-folders` for explicit on-demand full sync.
- Confirm `home-manager build` evaluates cleanly after the edits.
- Define the live `mbsync` verification suite for the user to run after `home-manager switch`.

**Non-Goals**:
- Re-planning or re-implementing the a8f65ad group-slimming fix (already done).
- Removing `logos-folders` from `Group logos` (it stays, per a8f65ad's documented rationale).
- Fixing the secondary data-level issues: duplicate-UID warnings in `.Trash`/`.Archive` and the
  malformed 144-byte dateless `Sent` message. These are not config changes and are out of scope.
- Editing the runtime `~/.mbsyncrc` (a home-manager /nix/store symlink — never edit directly).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Malformed `Patterns` line (wrong quoting/order) breaks channel selection | M | L | Follow the exact sketch from report 01: positive pattern first, then negative `"!.../*.*"`; verify with `home-manager build`. |
| `home-manager switch` / live `mbsync` require the user's machine and Proton Bridge | L | H | Agent builds only; switch + live `mbsync` runs are deferred to the user as a gated live operation (documented in Testing & Validation). |
| Non-fatal duplicate-UID / dateless-Sent warnings mistaken for a failure | L | M | Note in verification that these warnings may still appear and do NOT fail the reconcile (per report 01). |
| Edit to the wrong file (`~/.mbsyncrc` symlink) | M | L | All edits land in `modules/home/email/mbsync.nix` only; symlink is never touched. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add negative dotted-name patterns [COMPLETED]

**Goal**: Guard the `logos-labels` and `logos-folders` channels so no dotted mailbox name can ever
reach the Maildir++ store — the highest-value residual item, since `logos-folders` is still in
`Group logos`, which the hot nvim keymaps `<leader>me` / `<leader>mN` run via `mbsync -a`.

**Tasks**:
- [x] In `modules/home/email/mbsync.nix`, change the `logos-labels` channel `Patterns` line
      (currently `Patterns "Labels/*"`, ~line 184) to `Patterns "Labels/*" "!Labels/*.*"`.
- [x] Change the `logos-folders` channel `Patterns` line (currently `Patterns "Folders/*"`,
      ~line 193) to `Patterns "Folders/*" "!Folders/*.*"`.
- [x] Optionally add a short inline comment noting the negative pattern skips dotted names that
      Maildir++ cannot represent (consistent with the file's existing exclusion comments).
- [x] Run `home-manager build` (see Testing & Validation for the exact flake target) and confirm
      it evaluates cleanly.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `modules/home/email/mbsync.nix` — add `"!Labels/*.*"` to the `logos-labels` channel Patterns
  line and `"!Folders/*.*"` to the `logos-folders` channel Patterns line (Logos section, verify
  current line numbers before editing).

**Verification**:
- `home-manager build` evaluates without error.
- `grep` confirms both Patterns lines now carry their negative exclusion.

---

### Phase 2: Add Group logos-full and run live verification [COMPLETED]

**Goal**: Add an explicit on-demand full-sync group covering the core channels plus
`logos-labels` and `logos-folders`, rebuild, and define/run the shared live `mbsync` verification
suite (the live portion is user-gated).

**Tasks**:
- [x] In `modules/home/email/mbsync.nix`, after the existing `Group logos` block (~lines 207-213),
      add a new `Group logos-full` listing: `logos-inbox`, `logos-sent`, `logos-drafts`,
      `logos-trash`, `logos-archive`, `logos-labels`, `logos-folders`.
- [x] Optionally add a short comment noting `logos-full` is an on-demand full sync not used by any
      keymap or wrapper reconcile path.
- [x] Run `home-manager build` and confirm clean evaluation with both Phase 1 and Phase 2 changes.
- [ ] Hand off the live verification suite to the user (requires `home-manager switch` + Proton
      Bridge): `mbsync logos-inbox`, `mbsync logos`, `mbsync -a`, and `mbsync logos-full`.
      *(deviation: deferred to user — requires `home-manager switch` and a live Proton Bridge
      session per the plan's Risks & Mitigations and Non-Goals; agent performed build-only
      verification only, per explicit task instructions not to run `home-manager switch`.)*

**Timing**: 30 minutes (build by agent; live switch/sync deferred to user)

**Depends on**: 1

**Files to modify**:
- `modules/home/email/mbsync.nix` — add the `Group logos-full` block after `Group logos`.

**Verification**:
- `home-manager build` evaluates without error.
- `grep -n "logos-full" modules/home/email/mbsync.nix` shows the new group with all seven channels.
- Live (user-gated, after `home-manager switch`): `mbsync logos-inbox`, `mbsync logos`, and
  `mbsync -a` all exit 0 and propagate any pending Logos INBOX->Trash deletes to the Proton
  server; `mbsync logos-full` completes without any dotted-name fatal error.

---

## Testing & Validation

- [x] `home-manager build` evaluates cleanly after Phase 1 (use the repo's flake target, e.g.
      `home-manager build --flake .#<user>`; confirm the exact attribute from `flake.nix`).
      Ran `home-manager build --flake .#benjamin`; succeeded (target attribute confirmed from
      `flake.nix` `homeConfigurations.benjamin`).
- [x] `home-manager build` evaluates cleanly after Phase 2 (both changes present).
- [x] `grep` confirms `"!Labels/*.*"`, `"!Folders/*.*"`, and `Group logos-full` are present.
- [ ] **User-gated live suite** (requires the user's machine, `home-manager switch`, and a running
      Proton Bridge — the agent can build but switching/syncing is a live operation deferred to the
      user). This single live check credits both this task and nvim task 851's one remaining open
      item:
  - `mbsync logos-inbox` — exit 0.
  - `mbsync logos` — exit 0; propagates pending Logos INBOX->Trash deletes to the Proton server.
  - `mbsync -a` — exit 0 (exercises the `<leader>me` / `<leader>mN` path end to end).
  - `mbsync logos-full` — completes without any dotted-name fatal error.
  *(deviation: deferred to user — not run by the agent; see Phase 2 task annotation.)*
- [ ] Non-fatal duplicate-UID warnings (`.Trash`/`.Archive`) and the one dateless local `Sent`
      message (report 01) may still appear but do NOT fail the reconcile — expected, not a failure.
      *(informational note for the user during the live suite; not independently verifiable by the
      agent without a live sync.)*

## Artifacts & Outputs

- `modules/home/email/mbsync.nix` — edited Logos section: negative dotted-name patterns on
  `logos-labels` and `logos-folders`; new `Group logos-full` block.
- `specs/092_logos_mbsync_group_labels_fix/plans/03_logos-mbsync-hardening.md` — this plan.
- (On implementation) an execution summary and a `home-manager build` verification result.

## Rollback/Contingency

- The change is a ~10-15 line diff confined to one file. To revert, `git checkout --
  modules/home/email/mbsync.nix` (or revert the task commit) and re-run `home-manager build` /
  `home-manager switch` to restore the a8f65ad state.
- If `home-manager build` fails after an edit, the malformed `Patterns` line or `Group logos-full`
  block is the likely cause: re-check quoting and channel names against the sketch in report 01;
  the pre-edit file already builds, so a clean revert is always available.
- The runtime `~/.mbsyncrc` symlink is regenerated by `home-manager switch`; no manual cleanup of
  the symlink is ever required.
