# Research Report: Task #115

**Task**: 115 - Consolidate and refactor the aerc email configuration
**Started**: 2026-07-14T20:02:30Z
**Completed**: 2026-07-14T20:45:00Z
**Effort**: medium (single-file nix config refactor, no behavior redesign)
**Dependencies**: None (task 114 is explicitly out of scope / separate)
**Sources/Inputs**: `specs/115_.../reports/00_session-context-and-handoff.md`, `modules/home/email/{aerc,mbsync,mail-sync,notmuch}.nix`, `modules/home/services/mail-sync-timer.nix`, locally-installed `aerc 0.21.0 +notmuch-5.7.0` man pages (`aerc-accounts(5)`, `aerc-notmuch(5)`), task 112/113 reports and summaries, live `home-manager build --flake .#benjamin` baseline
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The handoff brief (`00_session-context-and-handoff.md`) is accurate and current; this report
  builds forward from it without re-deriving history. Its architecture table, changelog, invariants,
  and outstanding-items list (§1-§7) all check out against the live files.
- `modules/home/email/aerc.nix` is 384 lines with roughly **16 distinct `Task NN`/"Regression fix"
  comment markers** spread across 4 structurally identical clusters (binds rationale, accounts.conf
  rationale, querymap rationale, tab-switch rationale) — consolidation should extract each cluster's
  *durable rationale* into a short prose block near the top of the relevant section, not delete the
  reasoning.
- **Querymap de-duplication is straightforward**: `querymap-gmail`/`querymap-logos` are structurally
  identical (same 5-10 line shape, differing only in the literal `Gmail`/`Logos` token and the
  archive-folder name `All_Mail`/`Archive`). A `let`-bound Nix function generating both from a small
  per-account record removes ~20 lines of duplication with zero behavior change (byte-identical
  rendered output achievable).
- **`folders-exclude` (blacklist) should be KEPT, not switched to a `folders` whitelist or to
  `maildir-account-path`.** Task 112's research already evaluated and explicitly rejected
  `maildir-account-path` for this exact architecture (both accounts intentionally share one
  `maildir-store = ~/Mail` root and one notmuch `source`), and a `folders` whitelist has the
  identical "must ignore the other account's physical tree" requirement as the current blacklist,
  so it buys no clarity. The consolidation-worthy improvement is de-duplicating the *identical*
  `folders-exclude = ~^Gmail,~^Logos` line that is currently repeated verbatim in both account
  blocks, and reframing the comment as an architectural note rather than a "regression fix."
- **`text/plain`-first `alternatives` should be KEPT as the default**, with a documented, low-cost
  escape hatch (`:next-part`/`<Enter>`) already in place for switching to `text/html` per-message.
  Flipping the *global* default to `text/html`-first is a genuine behavior change with real
  downsides (top-level `viewer.alternatives` is not per-view, HTML rendering depends on the `w3m`
  filter being invisibly correct, and plaintext-first is the safer/faster/more private default) —
  recommend documenting this as a considered-and-rejected alternative rather than silently flipping it.
- **The `<Enter>` = `:next-part` binding in `view` should be KEPT**, with the trade-off (loses
  Enter-to-scroll-one-line) documented in one line rather than the current five-line essay; `<Space>`/
  `<C-d>`/`<C-u>` already fully cover pager scrolling, so nothing is lost in practice.
- **`[logos]` `check-mail` should remain unwired** (recommend documenting the "why", not adding it):
  wiring it either duplicates the same non-actionable "sync failed" signal the gmail-side already
  produces from a **known**, unfixed cause (task 114's duplicate-UID `Expunge Both` exit-1), or
  requires deciding how `check-mail-cmd` should distinguish a known-benign failure from a real one —
  which is explicitly task 114's problem, not this task's, per the NON-GOALS in the task description.
- Verification approach: diff the **rendered config** (`aerc.conf`, `binds.conf`, `accounts.conf`,
  `querymap-gmail`, `querymap-logos`) resolved from the home-manager build's
  `home-manager-files` derivation, before vs. after the refactor, plus `home-manager build
  --flake .#benjamin` staying green. A baseline build was run during this research session and
  succeeded (exit 0); the five rendered files each resolve to their own individually-diffable Nix
  store path (see §6 below), which makes a byte-for-byte or semantically-normalized diff
  mechanically cheap.

## Context & Scope

Task 115 asks for a **maintainability/coherence refactor** of `modules/home/email/aerc.nix`
(384 lines) — consolidating the accreted task-number comment archaeology into forward-looking
documentation, and holistically reconsidering a short list of decisions that were made
incrementally under time pressure across tasks 34, 72, 105, 109, 110, 112, 113 and several
follow-up commits. It is explicitly **not** a redesign: behavior changes require an explicit,
justified decision recorded in the plan, and task 114 (Gmail `.All_Mail` duplicate-UID remediation)
is out of scope entirely.

This report reads and confirms the pre-existing handoff brief, analyzes the current file in
detail, enumerates concrete consolidation opportunities, works through each of the five
holistic-reconsideration decision points with a recommendation grounded in the actual aerc
source/man-page behavior (not assumption), and lays out the verification approach.

## Findings

### Handoff brief validation

The brief at `specs/115_aerc_config_consolidation_refactor/reports/00_session-context-and-handoff.md`
was read in full first, per the task instructions. Cross-checking its claims against the live
files confirms all of the following are accurate as of this research pass:

- The architecture table (§1) matches the five files inspected (`aerc.nix`, `mbsync.nix`,
  `mail-sync.nix`, `notmuch.nix`, `mail-sync-timer.nix`) exactly — roles, wiring, and the
  `gmail-all` `Expunge Both` risk all check out.
- The changelog (§2) matches the live `aerc.nix` content line-for-line: `INBOX=folder:Gmail`
  (line 358), `format-flowed = true` (line 45), `maildir-store`/`multi-file-strategy = act-dir`
  (lines 285-286, 321-322), `:send -a flat` in `compose::review` (line 254), the
  `mail-sync-timer` systemd unit (confirmed live in `modules/home/services/mail-sync-timer.nix`),
  `folders-exclude = ~^Gmail,~^Logos` (lines 296, 326), `:reply -c` / `:reply -a -c` (lines
  207-208), and `<Enter> = :next-part` in `view` (line 190) are all present and match the
  brief's description.
- The outstanding-items list (§4) is current: task 114 exists as its own task
  (`specs/114_gmail_allmail_duplicate_uid_remediation/`), the `-a -c` two-flag caveat is unresolved
  in the file (no test/comment records a definitive answer), and the "17 Task-NN markers" figure
  is close to this research pass's own count (~16, see below — likely an off-by-one in how
  cross-referenced/repeated blocks are counted, immaterial to the consolidation plan).
- The invariants (§6) and verification approach (§7) are both actionable as written and are used
  directly as the basis for this report's recommendations.

**One addition beyond the brief**: task 112's own research report
(`specs/112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md`, "finding-7")
documents a still-unresolved, source-grounded risk that is *adjacent* to but distinct from the
brief's "112/113 live-mail verification still user-pending" item: aerc's notmuch worker resolves
the "current folder" (`curDir`) used by `act-dir` from the **currently-open tab's name**
(`w.currentQueryName`), which must be an exact key in the physical folder map built by walking
`maildir-store`. The default/most-used tab, `INBOX` (the querymap alias), is **not** such a key —
only the literal `Gmail`/`Logos` folder names are. If this analysis is correct, archiving a
**multi-file** message (one with a copy in both `Gmail/cur/` and `Gmail/.All_Mail/cur/`) while
sitting on the `INBOX` tab silently downgrades `act-dir` to `refuse` and fails with `refusing to
act on multiple files`, even though `multi-file-strategy = act-dir` is correctly configured.
Single-file messages are unaffected. This was flagged in task 112 as the first thing live
verification should check, and per that task's summary it was never actually exercised
(Phase 4 marked `[PARTIAL]`, skipped for the same "no live-mail mutation by an agent" reason).
**This refactor must not silently resolve or paper over this open risk** (e.g. by rebinding `a` to
change tabs first) without an explicit, justified decision — it belongs in the same
"deferred/outstanding" bucket as task 114, not folded into a "cleanup."

### Current `modules/home/email/aerc.nix` structure (384 lines)

The file has four top-level sections:

1. **`programs.aerc.extraConfig`** (lines 5-59): `general`, `ui`, `viewer`, `compose`, `filters`,
   `openers` — mostly stable, low-comment-churn settings. `compose` carries the one substantial
   rationale comment (format-flowed/textwidth, lines 34-38, 43-45) which is accurate and worth
   keeping essentially as-is (it explains a genuinely non-obvious nvim-ftplugin interaction).
2. **`programs.aerc.extraBinds`** (lines 60-269): the largest section, 8 bind-scopes (`global`,
   `messages`, `messages:folder=Drafts`, three `messages:folder=Proposed-*`, `view`, `compose`,
   `compose::editor`, `compose::review`, `terminal`). This is where most of the `Task NN` comment
   density lives — 4 separate task-numbered rationale blocks in `messages` alone (lines 79, 92,
   100, 130-138), one in `view` (183-189, 199-206, 246-253 — three separate multi-line essays), one
   duplicated verbatim between `messages` and `view` for `<Tab>`/`<S-Tab>` (lines 79-82 and
   194-197 are byte-identical).
3. **`home.file.".config/aerc/accounts.conf"`** (lines 273-333): per-account INI-style text block,
   `[gmail]` and `[logos]`, each carrying near-duplicate task-numbered comments for
   `maildir-store`/`multi-file-strategy` (278-284, 319-322) and `folders-exclude` (288-296,
   324-326) — these four comment blocks are the clearest "same rationale, said twice" duplication
   in the file.
4. **Two `home.file` querymap blocks** (`querymap-gmail` lines 335-369, `querymap-logos` lines
   371-382): near-identical 5- and 7-line query-map bodies, each preceded by a long shared-rationale
   comment (337-356) that is *itself* repeated in abbreviated form above `querymap-logos`
   (372-373, "See Gmail querymap comment above").

**Comment-marker inventory** (grepped directly from the file; used to ground the "17 markers"
claim rather than re-assert it): distinct `Task NN`/"Regression fix" citations appear at lines 79,
92, 100, 130, 134, 152, 194, 247, 278, 288, 303, 319, 324, 337, 346, 372 — 16 citations, clustering
into these rationale groups:

| Group | Lines | Rationale (to preserve) |
|---|---|---|
| Tab/S-Tab account-switching (task 105) | 79-82, 194-197 | Duplicated verbatim between `messages` and `view`; same rationale, same bind |
| d/D/a/A hardening + unprompted single-archive (task 72 Ph9, task 112) | 92-104 | Native delete/archive kept human-only outside the mail-guard hook's reach; single-archive intentionally unprompted (low blast radius) vs. D/A prompted |
| `$`/mail-sync gmail keybind history (task 72 Ph9, task 109) | 130-138 | Why group-scoped, why not `-a`, why wrapper-routed |
| Proposed-* review-view wrapper routing (task 72 Ph9) | 152-160 | Why these views shadow native d/a with wrapper-routed tag-and-queue gestures |
| View-tab reply-close (`-c`) rationale (follow-up commit, no task number) | 199-206 | Source-verified safety of `-c`, orthogonal to `-a`, `-a -c` caveat |
| `<Enter>` part-cycle rationale (follow-up commit, no task number) | 183-190 | No native "select" concept; trade-off vs. pager-scroll |
| Native `:send -a flat` archive-on-reply (task 113) | 246-253 | Why native flag over the removed hook; immune to cursor drift |
| `maildir-store`/`multi-file-strategy` (task 112, x2) | 278-284, 319-322 | Why required for real `:archive`; nixpkgs-version forward-compat caveat |
| `folders-exclude` (task 112 follow-up "Regression fix", x2) | 288-296, 324-326 | Why needed once `maildir-store` was added; display-only, doesn't affect `:archive` |
| `check-mail` (task 113) | 303-315 | Secondary/convenience vs. systemd timer; `--no-wait`; logos intentionally unwired |
| INBOX/querymap folder-scoping rationale (task 34, task 110, x2 for gmail/logos) | 337-356, 372-373 | Why `folder:Gmail` not `tag:inbox`; why Unread/Flagged/Proposed-* stay account-wide |

This is 11 rationale groups behind 16 numbered citations — a workable unit of consolidation:
each group becomes one forward-looking prose paragraph (stating the *current* contract and *why*,
not the task-by-task narration of how it got there), with the task numbers optionally preserved as
a trailing parenthetical for archaeology rather than as the load-bearing explanation.

### Querymap de-duplication

`querymap-gmail` and `querymap-logos` differ only in:
- The literal account folder prefix (`Gmail` vs `Logos`)
- The archive-folder display name (`All_Mail` vs `Archive` — this mirrors `mbsync.nix`'s
  `Near :gmail-local:All_Mail` / `Near :logos-local:Archive` and `accounts.conf`'s
  `archive = All_Mail` / `archive = Archive`, so it is a genuine per-account value, not
  incidental drift)
- Gmail has one extra line (`Spam=folder:Gmail/.Spam`) that Logos does not (correct: task 112's
  own report confirms Gmail's `[Gmail]/Spam` is IMAP-selectable and synced via `mbsync.nix`'s
  `Channel gmail-spam` for manual use, while Logos has no equivalent spam channel)

A `let`-bound generator function (e.g. `mkQuerymap = { prefix, archiveName, extra ? [] }: ''...''`)
producing both files from two small per-account records would collapse ~30 lines of near-duplicate
text into one template + two ~4-line data records, and is a textbook case for byte-identical
rendered output (the template just needs to reproduce the exact existing strings). This is one of
the lowest-risk, highest-value consolidation opportunities in the file precisely because the two
querymaps are structurally identical apart from data, not because of any deeper logic.

### Holistic-reconsideration decision points

The task description and handoff brief name five specific decisions to revisit. Each is addressed
below with a recommendation grounded in the actual aerc 0.21.0 behavior (verified via the
locally-installed man pages `aerc-accounts(5)` / `aerc-notmuch(5)`, and task 112's own prior
source-level research), not assumption.

#### 1. `folders-exclude` blacklist vs. a `folders` whitelist vs. `maildir-account-path`

Per `aerc-notmuch(5)` (verified locally, `/nix/store/.../share/man/man5/aerc-notmuch.5.gz`):
`maildir-account-path` is "used to achieve traditional maildir one tab per account behavior" and
would scope each account's folder listing to a subtree of `maildir-store` (e.g. `Gmail` vs.
`Logos`) instead of the whole shared root. This looks, at first glance, like the "real fix" for
the sidebar-bleed problem that `folders-exclude` currently patches over with a regex blacklist.

**However, task 112's own research already evaluated this exact option and explicitly rejected
it** (`specs/112_.../reports/01_enable-archive-action.md`, line 52 and line 73): "Both accounts
already share `source = notmuch://~/Mail` — a single shared notmuch database root, with
per-account scoping done entirely via `query-map`/`folder:` queries... `maildir-account-path`
should NOT be set for either account: both accounts already share the same `~/Mail` maildir-store
root exactly as they already share the same notmuch `source` root." This is an intentional,
load-bearing architectural choice (one shared notmuch database, two accounts scoped purely by
query), not an oversight — introducing `maildir-account-path` would be a structural change to how
the two accounts relate to the shared mail store, well beyond a "maintainability" refactor, and
was already correctly out-of-scope reasoning in task 112.

A `folders` whitelist (per `aerc-accounts(5)`: "Specifies the comma separated list of folders to
display... By default, all folders are displayed") has the *identical* requirement as the current
blacklist — it too must be aware of, and exclude, the other account's physical subtree, since
`folders` and `folders-exclude` operate on the same physical-folder namespace and the man page
states `folders-exclude` "overrides anything from `folders`" (i.e. even a whitelisted folder is
hidden if it also matches `folders-exclude`). Switching to a whitelist buys no clarity: it would
require enumerating every querymap virtual-folder-equivalent physical name explicitly, which is
strictly more verbose than the current 2-token regex exclude, for zero behavior difference.

**Recommendation: keep `folders-exclude = ~^Gmail,~^Logos`, unchanged.** The consolidation-worthy
action is de-duplicating the identical literal value between `[gmail]` and `[logos]` (a `let`
binding or the same account-record refactor proposed for querymaps above covers this for free),
and rewriting the comment as a forward-looking architectural note: "both accounts share one
`maildir-store` root by design (§ shared notmuch database); `folders-exclude` hides the raw
physical tree so only the query-map virtual folders show" — rather than "Regression fix (follow-up
to task 112)."

#### 2. `text/plain`-first vs. `text/html`-first `viewer.alternatives` default

Current: `alternatives = "text/plain,text/html"` (line 29) — aerc tries `text/plain` first, falls
back to `text/html` only if a message has no plaintext part. The handoff brief notes the user
"finds html a little better" as a mild preference signal, not a complaint.

This is a **global, per-account-independent** setting (there's no per-view or per-sender override
in `[viewer]`), so flipping it changes rendering for every HTML-capable message, not just ones
where plaintext genuinely renders worse. Plaintext-first is also the safer default in a terminal
mail client context: it avoids depending on the `w3m -I UTF-8 -T text/html` filter being correct
for every message's HTML (encoding quirks, malformed markup, tracking-pixel/remote-image
considerations are not filtered), and it's faster (no `w3m` subprocess spawn) for the common case.
The existing `<Enter>`/`j`/`k` `:next-part` cycle (task from the 25b8691 commit) already gives a
one-keystroke way to view the `text/html` alternative on any message where the user actually wants
it — the "little better" preference is already served by an opt-in mechanism, at essentially zero
marginal cost per message.

**Recommendation: keep `text/plain,text/html` as the default.** Document this explicitly as a
considered-and-rejected alternative in the `[viewer]` comment (one line: "text/plain-first kept as
the default; text/html is one `<Enter>`/`j`/`k` press away via `:next-part` -- see `[view]`
binds") so a future reader doesn't re-litigate it from scratch. If the user's preference hardens
over time, revisit as its own small task rather than folding a rendering-default change into a
"no behavior change" refactor.

#### 3. `<Enter>` = `:next-part` vs. losing Enter-to-scroll

Per the existing (accurate) in-file comment: aerc has no native "Enter to select" concept for
multipart messages — moving the part cursor via `:next-part`/`:prev-part` **is** what displays the
selected alternative, so the only real question is which key triggers it. The current binding
aliases `<Enter>` to `:next-part` in the `view` scope, at the cost of `<Enter>` no longer scrolling
the pager one line.

Checking the full `view` bind table (lines 177-226): `<Space>`, `<C-d>`, `<C-u>` already cover
page-down/page-up, and `j`/`k` remain available as the non-Enter part-cycle keys. So the "lost"
capability (Enter-scrolls-one-line) has no *unique* substitute, but it was redundant with
`<Space>`/`<C-d>`/`<C-u>` for the page-level scrolling that matters in practice, and one-line-at-a-
time scrolling via Enter is a `less`-pager convention that doesn't obviously fit a mail-viewer
workflow. No alternative key was found in the man pages or current binds that would give both
capabilities without a scope-conditional bind (e.g. "Enter scrolls until end-of-part, then
cycles") — aerc's bind system doesn't support that kind of stateful conditional out of the box.

**Recommendation: keep `<Enter> = :next-part`.** Trim the comment from 5 lines to roughly 2
("no native part-select in aerc; :next-part cycling *is* the selection; <Space>/<C-d>/<C-u>
cover pager scrolling so Enter is free for this"), preserving the trade-off statement but not the
full essay.

#### 4. `[logos]` `check-mail` — wire it up, or leave it unwired?

Current: only `[gmail]` has `check-mail`/`check-mail-cmd`/`check-mail-timeout`; `[logos]` has none.
Both accounts already get periodic sync from the systemd `mail-sync-timer` (runs `mail-sync both`
every 15 minutes, covering Logos too) — `check-mail-cmd` is explicitly the *secondary*,
while-aerc-is-open convenience layer per the existing comment (lines 303-306), not the only sync
path for either account.

Per `aerc-accounts(5)` (verified locally), `check-mail-cmd` surfaces its command's exit status as a
UI error — this is by design, not a bug. Wiring `[logos] check-mail-cmd = mail-sync logos --no-wait`
today would produce a UI-visible failure signal whenever `mail-sync gmail`'s sibling group fails
for an unrelated, already-tracked reason... actually more precisely: `mail-sync logos` is
independent of gmail's known duplicate-UID failure (task 114), so wiring logos check-mail would
*not* directly inherit gmail's specific failure mode. The real argument for leaving it unwired is
narrower and already correctly identified in the handoff brief's outstanding item #3: **the
project has not yet decided how `check-mail-cmd` failures should be surfaced (known/benign vs.
real)**, and task 114 is precisely the "known failure" case motivating that decision for gmail.
Wiring a second account into the same undifferentiated failure-surfacing mechanism before that
policy exists just doubles the surface area of an already-open question, for a Logos account whose
Bridge-based sync is comparatively less actively used day-to-day than Gmail's (per the account's
`~54`-message archive scale noted elsewhere in this task's context vs. Gmail's ~64k).

**Recommendation: leave `[logos]` `check-mail` unwired, but change the "why" documented from
implicit ("gmail-only, matching the existing convention") to explicit**: "not wired pending a
decided check-mail failure-surfacing policy (see task 114); wiring it now would add a second
undifferentiated failure surface before that policy exists." This turns a silent omission into a
recorded decision, which is exactly what the refactor's goal calls for, without taking on task
114's actual policy work.

#### 5. De-duplicate `querymap-gmail`/`querymap-logos` via a generator

Already covered in "Querymap de-duplication" above — recommend implementing this as the
lowest-risk, highest-value structural change: same rendered bytes, ~30 fewer source lines, and it
mechanically forces the Gmail/Logos parity (or intentional Spam-line asymmetry) to be visible in
one place instead of two near-identical blocks that must be kept in sync by hand.

### Cross-file consistency check (aerc.nix vs. mbsync.nix vs. notmuch.nix vs. mail-sync.nix)

Verified during this research pass, to ground "verify internal consistency" from the brief's §5:

- **Folder names**: `mbsync.nix`'s `Near :gmail-local:All_Mail` / `:logos-local:Archive` match
  `aerc.nix`'s `archive = All_Mail` / `archive = Archive` and the querymap entries
  `All_Mail=folder:Gmail/.All_Mail` / `Archive=folder:Logos/.Archive`. Consistent.
- **Tag semantics**: `notmuch.nix`'s `postNew` applies `+inbox +unread` once at delivery and never
  removes `-inbox` on archive (confirmed at lines 44-49 of `notmuch.nix`) — this is exactly why
  `aerc.nix`'s querymap INBOX entries correctly avoid `tag:inbox` (task 110's fix). Consistent.
  `Unread`/`Flagged` querymap entries correctly use `tag:unread`/`tag:flagged` which notmuch DOES
  maintain live (via `synchronizeFlags = true` in `notmuch.nix`'s `maildir` block). Consistent.
- **Sync entry points**: `aerc.nix`'s `$` keybind (`:exec mail-sync gmail<Enter>`) and
  `check-mail-cmd = mail-sync gmail --no-wait` both route through the same `mail-sync` wrapper
  (`mail-sync.nix`) that `notmuch.nix`'s `preNew` hook also uses (`mail-sync both || true`) — all
  three entry points are flock-serialized through the same choke point. Consistent, and this
  three-way convergence is itself worth stating as one forward-looking sentence in a consolidated
  aerc.nix header rather than leaving the reader to reconstruct it from three separate files.
- **One residual naming asymmetry worth flagging, not fixing**: the `$` keybind is gmail-only
  (`mail-sync gmail`) while `check-mail-cmd` is also gmail-only, but the systemd timer runs
  `mail-sync both`. This is already correctly explained inline (line 138: "`mail-sync
  logos`/`mail-sync both` is a trivial future extension, out of scope here") and matches the
  brief's non-goals — no action needed, just worth carrying the existing rationale forward
  verbatim rather than re-deriving it.

## Decisions

- **Consolidate, do not delete, the 16 `Task NN` comment citations** by regrouping them into the
  11 rationale clusters identified above, each as forward-looking prose with task numbers demoted
  to an optional trailing citation.
- **De-duplicate `querymap-gmail`/`querymap-logos`** via a small Nix generator function; target
  byte-identical rendered output.
- **De-duplicate the identical `folders-exclude = ~^Gmail,~^Logos` line** between `[gmail]` and
  `[logos]` account blocks (via the same or a similar `let`-bound per-account record approach used
  for querymaps, or a shared string binding).
- **No behavior change** on any of the five reconsideration points: keep `folders-exclude`
  (not whitelist, not `maildir-account-path`), keep `text/plain,text/html` alternatives order, keep
  `<Enter> = :next-part`, keep `[logos]` check-mail unwired. Each decision gets a short, explicit,
  forward-looking "why," replacing narration-by-task-number with a stated rationale.
- **Do not touch task 114's territory**: the `check-mail-cmd` known-vs-real-failure policy and the
  duplicate-UID remediation remain fully out of scope; this refactor should reference task 114 by
  name where relevant (e.g. the `[logos]` check-mail rationale above) rather than attempting to
  resolve it.
- **Do not silently resolve the task-112 finding-7 `curDir`/INBOX-tab `act-dir` risk** — carry it
  forward as an explicitly flagged, still-open item (it is currently only discoverable by reading
  task 112's report in full; the plan should decide whether to at least surface a one-line pointer
  comment near the `multi-file-strategy` config, without attempting a live-verified fix here).

## Risks & Mitigations

- **Risk**: a "consolidation" edit that trims comments could accidentally drop load-bearing
  rationale (e.g. the `-a -c` two-flag-vs-bundled-`-ac` caveat, or the `act-dir`/INBOX-tab risk),
  since both currently exist only as prose, not as tests. **Mitigation**: the plan phase should
  produce an explicit before/after mapping of every one of the 11 rationale clusters (which prose
  survives, where it moves to), and the render-diff verification step (below) catches any
  *config-value* regression but not a *documentation-content* regression — a manual read-through
  checklist item should cross-check that every distinct rationale point in the table above still
  appears somewhere in the refactored file.
- **Risk**: the querymap/folders-exclude generator function could introduce a subtle Nix
  string-formatting difference (trailing whitespace, line-ending, quoting) that changes rendered
  bytes even though the *logical* config is identical. **Mitigation**: the render-diff verification
  (below) is a byte-for-byte diff specifically to catch this class of regression before it ships.
- **Risk**: reflowing binds across scopes (e.g. deduplicating the byte-identical `<Tab>`/`<S-Tab>`
  block shared between `messages` and `view`) could, if implemented via a shared Nix binding used
  in both `extraBinds.messages` and `extraBinds.view`, still be fine (both scopes end up with the
  same bind = same behavior) but is worth explicitly noting as intentional in the plan, since a
  careless reader might think it's a mistake to see the same binding "twice."

## Appendix

### Search / verification commands used
```
man -w aerc-accounts | xargs zcat | col -b | grep -n -A8 'folders-exclude\|^folders\b\|check-mail'
zcat .../aerc-notmuch.5.gz | col -b   # query-map, maildir-store, maildir-account-path, multi-file-strategy
which aerc && aerc --version          # confirms locally-installed 0.21.0 +notmuch-5.7.0
home-manager build --flake .#benjamin # baseline: exit 0, green
nix-store -qR <generation> | grep home-manager-files
find <home-manager-files>/.config/aerc -maxdepth 1   # confirms all 5 rendered files individually resolvable
```

### Rendered-config paths for the semantic-equivalence diff (baseline captured this session)

From a green `home-manager build --flake .#benjamin` (result symlink -> `home-manager-generation`
derivation), the five files under `.config/aerc/` in the `home-manager-files` derivation each
resolve to their own store path:
```
.config/aerc/accounts.conf   -> hm_.configaercaccounts.conf
.config/aerc/aerc.conf       -> hm_homebenjamin.configaercaerc.conf
.config/aerc/binds.conf      -> hm_homebenjamin.configaercbinds.conf
.config/aerc/querymap-gmail  -> hm_.configaercquerymapgmail
.config/aerc/querymap-logos  -> hm_.configaercquerymaplogos
```
Recommended verification procedure for the implementation phase: capture these five files (e.g.
`cp $(readlink -f .../each) /tmp/baseline/`) before editing, rebuild after the refactor, and `diff`
each pair — a pure-consolidation refactor should produce zero diffs (or trivially-explainable
whitespace/comment-only diffs inside `aerc.conf`'s comments, which aerc's own config parser
strips, so even those should not appear in `aerc.conf`'s parsed form). `binds.conf`, `accounts.conf`,
and both `querymap-*` files should be byte-identical if no behavior decision changed their content.

### References

- `specs/115_aerc_config_consolidation_refactor/reports/00_session-context-and-handoff.md` (read first, per task instructions)
- `specs/112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md` (maildir-account-path rejection rationale; finding-7 curDir/act-dir risk)
- `specs/112_aerc_enable_folder_move_archive/summaries/01_enable-archive-action-summary.md`
- `specs/113_aerc_archive_on_reply_and_periodic_sync/reports/01_archive-on-reply-and-periodic-sync.md`
- `aerc-accounts(5)`, `aerc-notmuch(5)` man pages, aerc 0.21.0 (locally installed, `/nix/store/9fdjd926ig83369xasxagfcng70i0jbg-aerc-0.21.0/share/man/man5/`)
