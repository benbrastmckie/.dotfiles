# Implementation Plan: Task #110

- **Task**: 110 - Fix the aerc INBOX virtual folder so it reflects the real inbox
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/110_aerc_inbox_querymap_real_folder/reports/01_inbox-querymap-real-folder.md
- **Artifacts**: plans/01_inbox-querymap-real-folder.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Change the two aerc INBOX querymap entries in `modules/home/email/aerc.nix` from the buggy
`INBOX=tag:inbox AND folder:/Gmail/` (and Logos analogue) to the bare exact-match form
`INBOX=folder:Gmail` / `INBOX=folder:Logos`. This is a pure client-side view-definition change
rendered by Home Manager into `~/.config/aerc/querymap-{gmail,logos}`: it changes only which
messages the INBOX tab selects, with no mail mutation. The `Unread`/`Flagged`/`Proposed-*`
entries are deliberately left account-wide, with a documenting inline comment added to record
why the asymmetry is intentional. Verification is a single `home-manager build --flake .#benjamin`.

### Research Integration

The research report (01_inbox-querymap-real-folder.md) confirmed the root cause by direct source
inspection: (1) `notmuch.nix` `postNew` applies `+inbox` once at delivery and only removes it for
Sent/Trash/Spam auto-tag rules, never on archive, so `tag:inbox` is a permanent "was delivered"
marker; and (2) `folder:/Gmail/` is notmuch's slash-delimited regex form that also matches
`Gmail/.All_Mail`. Combined, the current query returns ~12,580 messages instead of the ~85 in the
true inbox. The bare `folder:Gmail` form is the live-verified INBOX-only idiom per CLAUDE.md's
folder-token table and is already used by `census.nix` (`folder:$ACCOUNT_FOLDER`) and by every
non-INBOX querymap entry. The report explicitly recommends leaving `Unread`/`Flagged`/`Proposed-*`
account-wide because they are tag-driven triage/search views (not folder-membership views), and
scoping `Proposed-*` to the inbox would silently hide proposed-tagged messages touched by a prior
triage pass, undermining the review gate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (no roadmap context loaded; roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- INBOX tab in aerc reflects true maildir-folder membership for both accounts (~85 for Gmail,
  not ~12k), so archived/handled mail leaves the view.
- Record an explicit, durable rationale in `aerc.nix` for why INBOX is folder-scoped while
  `Unread`/`Flagged`/`Proposed-*` remain account-wide, preventing future inconsistent "fixes".
- Home Manager configuration continues to build cleanly.

**Non-Goals**:
- Enabling archive itself (task 112).
- Enabling periodic sync (task 113).
- Changing `Unread`/`Flagged`/`Proposed-*` querymap scope (kept account-wide by decision).
- Modifying `notmuch.nix` postNew hook or `census.nix` (both already consistent with the fix).
- Changing message flags/read-state (handled by `synchronizeFlags` in notmuch.nix).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nix multi-line string (`''...''`) syntax break during edit | M | L | Minimal mechanical line replacement, no interpolation; `home-manager build` catches any break immediately |
| Future maintainer re-scopes Unread/Flagged/Proposed-* to match INBOX (scope creep) | L | M | Add documenting inline comment recording the intentional asymmetry (Phase 1) |
| INBOX count still looks wrong post-build | L | L | Verification step compares `notmuch count folder:Gmail` against the INBOX tab; count drift with new mail is expected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix INBOX querymap entries and document scope decision [COMPLETED]

**Goal**: Replace both INBOX querymap entries with the bare exact-match form and add an inline
comment recording why Unread/Flagged/Proposed-* stay account-wide.

**Tasks**:
- [x] In `querymap-gmail`, change `INBOX=tag:inbox AND folder:/Gmail/` to `INBOX=folder:Gmail`.
- [x] In `querymap-logos`, change `INBOX=tag:inbox AND folder:/Logos/` to `INBOX=folder:Logos`.
- [x] Add a comment (near the INBOX entries, e.g. above `querymap-gmail`) explaining: INBOX uses
      the bare exact-match `folder:Gmail`/`folder:Logos` form (INBOX-only, true folder membership)
      because `tag:inbox` is never removed on archive and `folder:/Gmail/` regex over-matches
      `.All_Mail`; the `Unread`/`Flagged`/`Proposed-*` entries intentionally REMAIN account-wide
      (`folder:/Gmail/` / `folder:/Logos/`) since they are tag-driven triage/search views, not
      folder-membership views (do not re-scope them to match INBOX).
- [x] Leave all other querymap lines (Sent, Drafts, Trash, All_Mail, Spam, Archive, Unread,
      Flagged, Proposed-*) unchanged.

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `modules/home/email/aerc.nix` - Two INBOX querymap lines changed to bare exact-match form; one
  documenting comment added recording the INBOX-vs-triage scope asymmetry.

**Verification**:
- `querymap-gmail` INBOX line reads exactly `INBOX=folder:Gmail`.
- `querymap-logos` INBOX line reads exactly `INBOX=folder:Logos`.
- No other querymap lines changed (Unread/Flagged/Proposed-* still use `folder:/Gmail/` /
  `folder:/Logos/`).
- The scope-decision comment is present and legible.

---

### Phase 2: Build verification [COMPLETED]

**Goal**: Confirm the Home Manager configuration builds with the edited querymaps.

**Tasks**:
- [x] Run `home-manager build --flake .#benjamin` and confirm it succeeds.
- [x] (Optional, post-activation, user-facing) Note in the summary that after activation the
      INBOX tab should show ~tens of messages (matching `notmuch count folder:Gmail`), not ~12k,
      and that archived mail leaving the INBOX view depends on task 112's relocation mechanism.

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- `home-manager build --flake .#benjamin` exits 0 with no evaluation errors.

---

## Testing & Validation

- [x] `home-manager build --flake .#benjamin` succeeds.
- [x] Rendered `querymap-gmail` INBOX entry is `INBOX=folder:Gmail`; `querymap-logos` is
      `INBOX=folder:Logos`.
- [x] `Unread`, `Flagged`, and Gmail `Proposed-Delete`/`Proposed-Archive`/`Proposed-Unsure`
      querymap lines are byte-for-byte unchanged.
- [x] Scope-decision comment present in `aerc.nix`.

## Artifacts & Outputs

- Modified `modules/home/email/aerc.nix` (two INBOX lines + one comment).
- Execution summary at `specs/110_aerc_inbox_querymap_real_folder/summaries/01_*-summary.md`.

## Rollback/Contingency

Single-file, git-tracked change with no mail mutation. To revert: `git checkout --
modules/home/email/aerc.nix` (or restore the two INBOX lines to
`INBOX=tag:inbox AND folder:/Gmail/` and `INBOX=tag:inbox AND folder:/Logos/`) and rebuild. No
data-loss risk since nothing mutates the mail store, tags, or sync state.
