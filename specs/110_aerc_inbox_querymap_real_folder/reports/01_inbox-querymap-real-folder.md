# Research Report: Task #110

**Task**: 110 - Fix the aerc INBOX virtual folder so it reflects the real inbox
**Started**: 2026-07-13T16:16:52-07:00
**Completed**: 2026-07-13
**Effort**: Small (single-file, two-line semantic change + one documentation decision)
**Dependencies**: None
**Sources/Inputs**: modules/home/email/aerc.nix, modules/home/email/notmuch.nix, modules/home/email/agent-tools/census.nix, CLAUDE.md folder-token semantics table, live `notmuch count` verification (already run by task author)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Root cause confirmed by direct source inspection: `notmuch.nix` `postNew` applies `+inbox`
  exactly once, at delivery (`notmuch tag +inbox +unread -- tag:new`), and never removes it.
  Nothing in the repo ever runs `notmuch tag -inbox` on archive. `tag:inbox` is therefore a
  permanent "was delivered" marker, not a "currently in the inbox folder" marker.
- `folder:/Gmail/` and `folder:/Logos/` are notmuch's slash-delimited **regex** folder-match
  form (per CLAUDE.md's verified folder-token table), which matches every sub-folder under the
  account, including `Gmail/.All_Mail`. Combined with the permanent `tag:inbox`, the current
  `INBOX=tag:inbox AND folder:/Gmail/` querymap entry returns effectively the entire
  ever-delivered corpus (~12,580 messages per the task's live count) instead of the ~85
  messages actually sitting in the `Gmail` maildir folder today.
- The fix is a pure query-definition change with no mail mutation: replace
  `INBOX=tag:inbox AND folder:/Gmail/` -> `INBOX=folder:Gmail` (and the Logos analogue) in both
  querymap files. This is the same bare exact-match form CLAUDE.md documents and that
  `census.nix` already relies on (`folder:$ACCOUNT_FOLDER`) for its own "true inbox" count.
- Recommendation on the secondary question: leave `Unread`/`Flagged`/`Proposed-*` querymap
  entries as account-wide (`folder:/Gmail/` / `folder:/Logos/`), unchanged. They are tag-driven
  triage/search views, not inbox-membership views, and account-wide scope is what makes them
  useful for reviewing/triaging archived mail too. This should be recorded as an explicit
  decision in the plan/implementation, not silently left ambiguous.

## Context & Scope

Task 110 is a narrow, read-only view-definition fix inside
`modules/home/email/aerc.nix`'s two `home.file` blocks that write
`~/.config/aerc/querymap-gmail` and `~/.config/aerc/querymap-logos`. These querymap files map
aerc's virtual per-account folder names (INBOX, Sent, Drafts, Trash, etc.) to notmuch queries
run against the single shared `notmuch://~/Mail` source. Nothing about the underlying mail
store, tags, or sync behavior changes — only which messages the INBOX tab's query selects.

Explicitly out of scope (per task description): enabling archive itself (task 112) and
periodic sync (task 113).

## Findings

### Existing Configuration

`modules/home/email/aerc.nix` (current state, lines 294-318):

```
".config/aerc/querymap-gmail".text = ''
  INBOX=tag:inbox AND folder:/Gmail/
  Sent=folder:Gmail/.Sent
  Drafts=folder:Gmail/.Drafts
  Trash=folder:Gmail/.Trash
  All_Mail=folder:Gmail/.All_Mail
  Spam=folder:Gmail/.Spam
  Unread=tag:unread AND folder:/Gmail/
  Flagged=tag:flagged AND folder:/Gmail/
  Proposed-Delete=tag:proposed-delete AND folder:/Gmail/
  Proposed-Archive=tag:proposed-archive AND folder:/Gmail/
  Proposed-Unsure=tag:proposed-unsure AND folder:/Gmail/
'';

".config/aerc/querymap-logos".text = ''
  INBOX=tag:inbox AND folder:/Logos/
  Sent=folder:Logos/.Sent
  Drafts=folder:Logos/.Drafts
  Trash=folder:Logos/.Trash
  Archive=folder:Logos/.Archive
  Unread=tag:unread AND folder:/Logos/
  Flagged=tag:flagged AND folder:/Logos/
'';
```

Note the existing comment directly above `querymap-gmail` (task 34, Phase 5/F5) already
documents that `folder:/Gmail/` is the slash-delimited **regex** form chosen because
`folder:Gmail*` glob syntax does not work as a literal notmuch query (matches zero messages).
That comment is correct about the glob-vs-regex distinction but does not flag that the regex
form also over-matches sub-folders — which is precisely the bug this task fixes for the INBOX
entry specifically.

Every non-INBOX folder entry in both querymaps (`Sent`, `Drafts`, `Trash`, `All_Mail`, `Spam`,
`Archive`) already uses the bare **exact-match** form (`folder:Gmail/.Sent`, `folder:Logos/.Archive`,
etc.) with no leading/trailing slashes — i.e., every entry except `INBOX` is already using the
correct exact-match idiom. `INBOX` is the sole outlier still combining a permanent tag with a
whole-account regex.

### notmuch.nix postNew hook (root cause of the tag half of the bug)

`modules/home/email/notmuch.nix`, `hooks.postNew`:

```
postNew = ''
  # Tag new mail
  notmuch tag +inbox +unread -- tag:new
  notmuch tag -new -- tag:new
  # Auto-tag by folder
  notmuch tag +sent -inbox -- folder:Gmail/.Sent OR folder:Logos/.Sent
  notmuch tag +trash -inbox -- folder:Gmail/.Trash OR folder:Logos/.Trash
  notmuch tag +spam -inbox -- folder:Gmail/.Spam
  # Tag by account
  notmuch tag +gmail -- folder:/Gmail/
  notmuch tag +logos -- folder:/Logos/
  ...
'';
```

Confirmed: `+inbox` is applied once, at first indexing (`tag:new`), and is proactively removed
(`-inbox`) ONLY for three specific folder-based auto-tag rules: `sent`, `trash`, `spam`. There
is **no** rule that removes `inbox` when a message is moved to `All_Mail`/`Archive` (i.e.,
archived). This is exactly the mechanism the task description describes: `tag:inbox` sticks
forever unless a message happens to land in Sent/Trash/Spam. The `+gmail`/`+logos`
account-tagging rules at the bottom use the same `folder:/Gmail/` and `folder:/Logos/`
whole-account regex form — appropriately, since those tags are meant to be account-wide, not
inbox-scoped.

This confirms both halves of the bug as described in the task: (1) the permanent tag, and (2)
the regex folder match that also captures `All_Mail`/`Archive`.

### CLAUDE.md folder-token semantics table (ground truth for the fix form)

CLAUDE.md's Email Extension section documents the three live-verified folder-token forms:

| Form | Example | Live behavior |
|------|---------|---------------|
| Glob (broken, never in wrapper source) | `folder:Gmail*` | 0 matches — notmuch `folder:` does not glob |
| Bare exact-match (the `/email` wrappers, by design) | `folder:Gmail` | INBOX-only exact maildir-folder match |
| Regex (aerc querymap) | `folder:/Gmail/` | Whole-account match across all folders |

This table is the direct grounding for the fix: `folder:Gmail` (bare, no tag, no slashes) is
the documented, live-verified INBOX-only form. The task's proposed replacement —
`INBOX=folder:Gmail` and `INBOX=folder:Logos` — is exactly this form, and requires no new
verification beyond what CLAUDE.md and the wrapper contract already established.

### Corroboration from email-census wrapper (modules/home/email/agent-tools/census.nix)

`census.nix` already treats `folder:$ACCOUNT_FOLDER` as the canonical "true inbox" query,
independent of this task:

```
printf "%-10s %s\n" "INBOX" "$(notmuch count "folder:$ACCOUNT_FOLDER")"
```

where `ACCOUNT_FOLDER` resolves to `Gmail` or `Logos` depending on `--account`. This is the
same wrapper the task description cites ("per ... the email-census wrapper which already
treats INBOX as `folder:$ACCOUNT_FOLDER`"), confirmed present in the codebase. It independently
validates that `folder:Gmail` / `folder:Logos` (no tag, no regex slashes) is already the
established, working convention for "the real inbox" elsewhere in this same codebase — the
aerc querymap's `INBOX` entry is the one place that diverged from this convention.

### Live count verification (from task description, not re-run here)

The task description states these live counts, captured 2026-07-13, which this report treats
as given (read-only counting commands, no mutation risk, and re-running is not necessary to
ground the fix — the querymap-file/postNew-hook logic already fully explains why the two
numbers must differ this way):

- `notmuch count folder:Gmail` = 85 (true inbox, bare exact-match form)
- `notmuch count 'tag:inbox AND folder:/Gmail/'` = 12,580 (current INBOX querymap query,
  regex form, includes All_Mail-archived messages that still carry the never-removed
  `inbox` tag)

### Community/Documentation Patterns

No external web research was needed for this task: the fix is fully grounded in local
first-party sources (the querymap files themselves, the notmuch hook that produces the tag
semantics, and CLAUDE.md's own verified folder-token table, which was itself produced by prior
tasks in this same repository, e.g. task 34's "flagged for CLAUDE.md accuracy follow-up" comment
already visible in aerc.nix). notmuch's own `notmuch-search-terms(7)` semantics for `folder:`
(exact match unless wrapped in `/regex/`) are consistent with what CLAUDE.md documents and what
this repo's own comments already state, so no additional external verification is required.

### Recommendations

**Primary fix** — in `modules/home/email/aerc.nix`, `home.file.".config/aerc/querymap-gmail".text`:

```
INBOX=folder:Gmail
```

replacing the current:

```
INBOX=tag:inbox AND folder:/Gmail/
```

And in `home.file.".config/aerc/querymap-logos".text`:

```
INBOX=folder:Logos
```

replacing the current:

```
INBOX=tag:inbox AND folder:/Logos/
```

No other lines in either querymap need to change for the INBOX fix itself.

**Secondary decision (Unread/Flagged/Proposed-\* scope)** — recommend **leaving these
account-wide**, i.e. do NOT change:

```
Unread=tag:unread AND folder:/Gmail/
Flagged=tag:flagged AND folder:/Gmail/
Proposed-Delete=tag:proposed-delete AND folder:/Gmail/
Proposed-Archive=tag:proposed-archive AND folder:/Gmail/
Proposed-Unsure=tag:proposed-unsure AND folder:/Gmail/
```

(and the Logos `Unread`/`Flagged` analogues).

Rationale:
1. These are tag-driven triage/search views, not folder-membership views. Their entire
   purpose (especially `Proposed-*`, which back the `/email` classify-review-confirm workflow
   per CLAUDE.md's Email Extension section) is to surface tagged candidates for review
   regardless of which folder they currently sit in — including messages already moved during
   a prior partial triage pass, or messages under review before an archive/delete decision is
   finalized.
2. Scoping `Proposed-*` to the inbox folder only would silently hide any proposed-tagged
   message that a background classify sweep already touched or that sits outside the inbox
   folder for any reason, undermining the review gate's completeness guarantee.
3. `Unread`/`Flagged` as global "everything I still need to look at / marked important" views
   are a normal and expected mail-client convention (most clients' "Flagged"/"Starred" virtual
   folders are global, not inbox-scoped).
4. This is explicitly a separate concern from `INBOX` per the task's own NON-GOAL framing —
   `INBOX` must reflect true folder membership (a location), while these other four/five
   entries are legitimately queries over tags (a status), and conflating the two fix
   rationales would risk over-scoping the change.

**Documentation**: the implementation should add a one-line comment in aerc.nix next to the
`INBOX=` entries recording this decision (why INBOX is folder-scoped but Unread/Flagged/
Proposed-* remain account-wide), so a future reader does not "fix" them inconsistently. This
report treats that comment as part of the required deliverable per the task's instruction to
"decide and document" the scope question.

### Verification Plan

1. `home-manager build --flake .#benjamin` — must succeed (pure text-file content change, no
   syntax risk beyond string literal correctness).
2. After activation, `notmuch count folder:Gmail` should equal what the INBOX tab shows in
   aerc (~85 at time of research; will drift with new mail).
3. Open aerc, confirm INBOX tab message count is in the tens, not ~12k.
4. Confirm a message that is archived (moved out of the `Gmail` maildir folder into
   `Gmail/.All_Mail`) disappears from the INBOX tab — this is the core acceptance criterion
   the task names ("makes any message moved out of the inbox folder ... disappear from the
   view"). Note this criterion depends on archive actually relocating the underlying maildir
   file to a different folder; verifying that relocation mechanism itself is task 112's
   concern (NON-GOAL here), but the querymap fix is what makes the INBOX view correctly reflect
   it once it happens.
5. Confirm `Unread`, `Flagged`, and (Gmail-only) `Proposed-Delete`/`Proposed-Archive`/
   `Proposed-Unsure` tabs are unaffected (same counts as before the change), since those
   querymap lines are untouched.

## Decisions

- **INBOX querymap fix**: change `INBOX=tag:inbox AND folder:/Gmail/` ->
  `INBOX=folder:Gmail`, and `INBOX=tag:inbox AND folder:/Logos/` -> `INBOX=folder:Logos`, in
  `modules/home/email/aerc.nix`.
- **Unread/Flagged/Proposed-\* scope**: keep account-wide (`folder:/Gmail/` / `folder:/Logos/`
  regex form), unchanged. Document this decision with an inline comment in aerc.nix.
- No changes needed to `modules/home/email/notmuch.nix` (postNew hook) or
  `modules/home/email/agent-tools/census.nix` for this task — both are consistent with, and
  in census.nix's case already exemplify, the fix being applied.

## Risks & Mitigations

- **Risk**: Nix multi-line string (`''...''`) syntax error from a stray character during edit.
  **Mitigation**: minimal, mechanical line replacement; `home-manager build` will catch any
  syntax break immediately, and the change is a pure string-literal edit with no interpolation.
- **Risk**: Someone later assumes ALL querymap tag-based entries should be folder-scoped like
  INBOX, re-introducing scope creep into Unread/Flagged/Proposed-*. **Mitigation**: the
  documented inline comment (see Recommendations) explicitly records the rationale for the
  asymmetry.
- **Risk**: User expects INBOX to also show unread-flag/read-state correctly. Out of scope —
  `synchronizeFlags = true` in notmuch.nix already handles maildir flag sync; this task only
  touches which messages are *selected*, not their flags.
- **No mail-mutation risk**: this is purely a client-side view/query definition rendered by
  Home Manager into a dotfile; it cannot delete, move, or retag any message.

## Appendix

- Files read: `modules/home/email/aerc.nix` (full), `modules/home/email/notmuch.nix` (full),
  `modules/home/email/agent-tools/census.nix` (grep for `ACCOUNT_FOLDER`/`INBOX`/`folder:Gmail`/
  `folder:Logos` occurrences).
- CLAUDE.md section consulted: "Email Extension" > "Account isolation, folder-scoped only"
  folder-token table.
- No web search was performed; this task is fully grounded in first-party repository sources
  and this repository's own previously-verified documentation (CLAUDE.md), consistent with the
  nix-research-agent's local-first search priority.
- state.json confirms task 110 metadata: task_type=nix, file_scope=["modules/home/email/aerc.nix"],
  dependencies=[] — consistent with this report's scope.
