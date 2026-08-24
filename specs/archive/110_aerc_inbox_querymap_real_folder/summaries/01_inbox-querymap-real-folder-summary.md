# Implementation Summary: Task #110

**Completed**: 2026-07-13
**Duration**: ~10 minutes

## Overview

Fixed the aerc INBOX virtual folder so it reflects true maildir-folder membership instead of
the permanent `tag:inbox` delivery marker combined with an over-matching account regex. Both
account querymaps now scope INBOX with the bare exact-match `folder:Gmail` / `folder:Logos`
form, and a documenting comment records why `Unread`/`Flagged`/`Proposed-*` deliberately remain
account-wide.

## What Changed

- `modules/home/email/aerc.nix` — Changed `INBOX=tag:inbox AND folder:/Gmail/` to
  `INBOX=folder:Gmail` in `querymap-gmail`; changed `INBOX=tag:inbox AND folder:/Logos/` to
  `INBOX=folder:Logos` in `querymap-logos`; added an inline comment above `querymap-gmail`
  (plus a short cross-reference above `querymap-logos`) explaining the root cause
  (`tag:inbox` is never removed on archive; `folder:/Gmail/` regex over-matches `.All_Mail`)
  and recording that `Unread`/`Flagged`/`Proposed-*` intentionally stay account-wide as
  tag-driven triage/search views, not folder-membership views.

Pre-existing uncommitted edits belonging to other tasks in the same file (the `compose` block
editor/format-flowed change for task 111, and the `hooks` archive-on-reply block for task 113)
were left untouched — verified via `git diff` before and after this change.

## Decisions

- Followed the plan exactly: no scope creep into `Unread`/`Flagged`/`Proposed-*`, which remain
  account-wide by design (documented rationale added per the plan's Phase 1 task).

## Plan Deviations

- None (implementation followed plan).

## Verification

- `home-manager build --flake .#benjamin`: Success (exit 0, 4 derivations built, no evaluation
  errors).
- Rendered `querymap-gmail` output confirmed via `nix-store -q --outputs` on the built
  derivation: `INBOX=folder:Gmail`, all other lines (Sent/Drafts/Trash/All_Mail/Spam/
  Unread/Flagged/Proposed-Delete/Proposed-Archive/Proposed-Unsure) unchanged.
- Rendered `querymap-logos` output confirmed likewise: `INBOX=folder:Logos`, all other lines
  (Sent/Drafts/Trash/Archive/Unread/Flagged) unchanged.

## Notes

Post-activation (user-facing, not run here): the INBOX tab should show roughly tens of
messages (matching `notmuch count folder:Gmail`), not the previous ~12,580, and archived mail
leaving the INBOX view depends on task 112's relocation mechanism (out of scope here). No
mail mutation, mbsync, or notmuch tag changes were performed as part of this task — this is a
pure client-side view-definition change.
