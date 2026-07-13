# Implementation Summary: Task #92

**Completed**: 2026-07-11
**Duration**: ~15 minutes

## Overview

Hardened the Logos (Protonmail Bridge) section of `modules/home/email/mbsync.nix` per
`plans/03_logos-mbsync-hardening.md`: added negative dotted-name `Patterns` guards to the
`logos-labels` and `logos-folders` channels, and added a new `Group logos-full` for explicit
on-demand full sync. The prior blocking bug (commit a8f65ad, task 826) is unaffected; this task
covers only the two residual hardening items identified by task 92's research.

## What Changed

- `modules/home/email/mbsync.nix` — `logos-labels` channel: `Patterns "Labels/*"` changed to
  `Patterns "Labels/*" "!Labels/*.*"`, with an inline comment explaining the exclusion.
- `modules/home/email/mbsync.nix` — `logos-folders` channel: `Patterns "Folders/*"` changed to
  `Patterns "Folders/*" "!Folders/*.*"`, with an inline comment explaining the exclusion.
- `modules/home/email/mbsync.nix` — added `Group logos-full` after the existing `Group logos`
  block, listing `logos-inbox`, `logos-sent`, `logos-drafts`, `logos-trash`, `logos-archive`,
  `logos-labels`, `logos-folders`, with a comment noting it is on-demand only (not used by any
  keymap or the wrapper reconcile path).

## Decisions

- Followed the exact pattern sketch from research report 01 (`"!Labels/*.*"` / `"!Folders/*.*"`,
  positive pattern first, negative pattern second).
- `Group logos-full` channel order matches the plan's listed order (core five channels, then
  `logos-labels`, then `logos-folders`).
- Did not touch `Group logos` (still contains `logos-folders`, per a8f65ad's documented
  rationale) — out of scope per the plan's Non-Goals.

## Plan Deviations

- None (implementation followed plan) for Phase 1 and the build/grep portions of Phase 2.
- Phase 2's live verification hand-off task (`mbsync logos-inbox`, `mbsync logos`, `mbsync -a`,
  `mbsync logos-full` after `home-manager switch`) is deferred to the user, as explicitly
  instructed: the agent must not run `home-manager switch` or perform live `mbsync` operations
  against the Proton Bridge account. This is a plan-anticipated deferral (see plan's Risks &
  Mitigations and Non-Goals), not an unplanned gap.

## Verification

- `home-manager build --flake .#benjamin` — succeeded (only the expected "Git tree is dirty"
  warning and an unrelated "unread home-manager news" notice; no errors).
- Inspected the built store output `result/home-files/.mbsyncrc` directly (not the runtime
  `~/.mbsyncrc` symlink, which was never touched) and confirmed the rendered config contains:
  - `Patterns "Labels/*" "!Labels/*.*"` on `Channel logos-labels`
  - `Patterns "Folders/*" "!Folders/*.*"` on `Channel logos-folders`
  - `Group logos-full` with all seven expected channel lines
- `grep -n '"!Labels\|"!Folders\|Group logos'` against the source file confirms both negative
  patterns and both `Group logos` / `Group logos-full` blocks are present in
  `modules/home/email/mbsync.nix`.
- Removed the `./result` build symlink after inspection (build-only artifact, not committed).

### Remaining — User-Gated Live Suite

Requires `home-manager switch` (to regenerate the runtime `~/.mbsyncrc` symlink) and a running
Proton Bridge session. Not run by this agent per task instructions:

- `mbsync logos-inbox` — expect exit 0.
- `mbsync logos` — expect exit 0; should propagate any pending Logos INBOX->Trash deletes to the
  Proton server.
- `mbsync -a` — expect exit 0 (exercises the `<leader>me` / `<leader>mN` nvim keymap path).
- `mbsync logos-full` — expect completion without any dotted-name fatal error.
- Non-fatal duplicate-UID warnings (`.Trash`/`.Archive`) and the one dateless local `Sent`
  message may still appear during these runs — expected per research report 01, not a failure.

## Notes

No option conflicts encountered. The edit is a ~15-line diff confined to
`modules/home/email/mbsync.nix`; rollback via `git checkout -- modules/home/email/mbsync.nix`
restores the a8f65ad (task 826) state per the plan's Rollback/Contingency section.
