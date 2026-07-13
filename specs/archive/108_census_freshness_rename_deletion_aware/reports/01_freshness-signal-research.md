# Research Report: Task #108

**Task**: 108 - census_freshness_rename_deletion_aware
**Started**: 2026-07-13T00:00:00Z
**Completed**: 2026-07-13T19:47:00Z
**Effort**: Medium (single-file shell logic change, no new binaries)
**Dependencies**: None
**Sources/Inputs**: `modules/home/email/agent-tools/census.nix`, `modules/home/email/agent-tools/lib.nix`, `modules/home/email/mbsync.nix`, `.claude/context/project/email/domain/staleness-detection.md`, `.claude/context/project/email/domain/wrapper-contracts.md` §11/§13, `.claude/skills/skill-email-cleanup/SKILL.md` Stage 1, live `notmuch`/`himalaya`/`find` probes against the real Gmail maildir (2026-07-13)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, `.claude/rules/nix.md`

## Executive Summary

- `census.nix:40-68` computes an INBOX freshness line from **two counts only** (himalaya's
  on-disk envelope count vs. a path-prefix-filtered `notmuch --output=files` FILE count),
  compared with a ±10%/min-5 tolerance. A count comparison is structurally blind to any
  operation that swaps one filename for another without changing the total N — which is
  exactly what a maildir flag-rename and an add/remove pair that happen to cancel out both do.
- **Live-verified on the real mailbox right now** (not hypothetical): on-disk INBOX = 86 files,
  filtered notmuch-indexed INBOX = 86 files — the current freshness line would print
  `divergence=0 tol=13 [ok]`. Yet a literal filename set-diff between the same two sources
  shows **3 real, distinct divergences hiding inside that "0"**: one pure flag-rename
  (`U=5202:2,` indexed vs `U=5202:2,S` on disk — the Seen flag was added and notmuch's record
  wasn't refreshed), two phantom/removed entries indexed under filenames
  (`U=5206:2,`, `U=5209:2,S`) that no longer exist anywhere under `Gmail/{cur,new}`, offset by
  two genuinely new, unindexed arrivals (`U=5210`, `U=5211`). Count-based tolerance logic
  cannot distinguish "0 real changes" from "3 renames/removals that happen to net to 0" —
  this is the root cause of the false-green that let aerc launch on a stale index.
- **Recommended approach**: keep the existing on-disk/indexed-files count line for backward
  compatibility (nothing downstream breaks), and add a second, independent **exact filename-set
  diff** (scoped to INBOX only, bounded to a few hundred entries, cheap) that reports
  `renamed=<R> removed=<X> added=<A>` counts computed by comparing the literal on-disk maildir
  filenames (himalaya's on-disk COUNT is trustworthy but its `id`/JSON output does not expose
  literal filenames — a properly INBOX-scoped `find` reproduces the same count and does give
  literal filenames) against the same path-prefix-filtered `notmuch --output=files` listing
  already computed today, using the `U=<n>` UID token as the join key so a flag-only change is
  classified as `renamed` rather than a spurious add+remove pair. The verdict flips to
  `[STALE]` if **either** the existing count-tolerance check **or** the new exact-set check
  fires — this is what closes the false-green gap, since the set check can trip even when
  `divergence=0`.

## Context & Scope

In scope: `modules/home/email/agent-tools/census.nix`'s freshness-line computation and output
shape only. Out of scope (explicitly, per task description): repairing ~/Mail duplicate UIDs,
running a one-time reindex, and hardening the nvim `mail.lua` gate (that file lives in
`~/.config/nvim`, a separate repo not present under `.dotfiles` — confirmed via repo-wide
grep, no `mail.lua` or `<leader>me` binding exists in this repository).

## Findings

### Existing Configuration: how census.nix computes and emits the freshness line today

`modules/home/email/agent-tools/census.nix:40-68` (full block, quoted verbatim):

```nix
echo "--- Index freshness: INBOX on-disk (himalaya) vs notmuch-indexed FILES ---"
echo "(divergence beyond tolerance => notmuch index is stale for INBOX; reconcile with"
echo " 'email-reindex' before a coverage-promising --all sweep.)"
# (a) file-vs-file. notmuch(1): --output=files returns EVERY known file for a matching message,
# incl. duplicates in other folders/accounts, so post-filter to the exact maildir path prefix.
INBOX_ONDISK=$(himalaya envelope list "${HIMALAYA_ACCT[@]}" -f INBOX -o json -s 100000 2>/dev/null \
  | jq 'length' 2>/dev/null)
INBOX_ONDISK="${INBOX_ONDISK:-?}"
INBOX_INDEXED=$(notmuch search --output=files \
    "path:$ACCOUNT_FOLDER/cur or path:$ACCOUNT_FOLDER/new" 2>/dev/null \
  | grep -cE "/$ACCOUNT_FOLDER/(cur|new)/" || true)
# (b) bounded tolerance instead of strict equality: on-disk (himalaya envelope count) and
# indexed (notmuch file count) drift transiently between an mbsync pull and 'email-reindex',
# so gate on a bounded divergence rather than an exact match to keep [ok] reachable. Tolerance
# is max(5, ceil(10% * on-disk)); the reindex= field below is the secondary staleness signal.
if printf '%s' "$INBOX_ONDISK" | grep -qE '^[0-9]+$'; then
  DIVERGENCE=$(( INBOX_ONDISK - INBOX_INDEXED ))
  AD=${DIVERGENCE#-}                              # absolute value
  PCT_TOL=$(( (INBOX_ONDISK * 10 + 99) / 100 ))     # ceil(10% * on-disk)
  TOL=$(( PCT_TOL > 5 ? PCT_TOL : 5 ))              # floor of 5
  if [ "$AD" -le "$TOL" ]; then FRESH="ok"; else FRESH="STALE"; fi
else
  DIVERGENCE="?"; TOL="?"; FRESH="STALE"
fi
# (c) reindex-run marker (informational secondary signal).
REINDEX_MARKER="${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex"
if [ -r "$REINDEX_MARKER" ]; then REINDEX_AT=$(cat "$REINDEX_MARKER" 2>/dev/null); else REINDEX_AT="never"; fi
printf "%-16s on-disk=%s  indexed-files=%s  divergence=%s  tol=%s  reindex=%s  [%s]\n" \
  "INBOX freshness" "$INBOX_ONDISK" "$INBOX_INDEXED" "$DIVERGENCE" "$TOL" "$REINDEX_AT" "$FRESH"
```

Inputs used, precisely:

| Variable | Source | What it is |
|---|---|---|
| `INBOX_ONDISK` | `himalaya envelope list -a $ACCOUNT -f INBOX -o json -s 100000 \| jq length` | Count of on-disk maildir files in INBOX (himalaya resolves the maildir++ folder mapping correctly; this is documented as the authoritative on-disk ground truth — `staleness-detection.md:29`) |
| `INBOX_INDEXED` | `notmuch search --output=files "path:$ACCOUNT_FOLDER/cur or path:$ACCOUNT_FOLDER/new"` piped through `grep -cE "/$ACCOUNT_FOLDER/(cur\|new)/"` | Count of notmuch-indexed files whose recorded path is literally under the INBOX maildir (the `grep` strips the `--output=files` cross-folder/cross-account duplicate-inclusion quirk — `staleness-detection.md:35-53`) |
| `DIVERGENCE` | `INBOX_ONDISK - INBOX_INDEXED` | Signed count delta |
| `TOL` | `max(5, ceil(0.10 * INBOX_ONDISK))` | Bounded tolerance, chosen so real steady-state residuals (task 827's Logos 22/341≈6.5% case) stay `[ok]` |
| `FRESH` | `"ok"` if `|DIVERGENCE| <= TOL` else `"STALE"` | The verdict |
| `REINDEX_AT` | `${XDG_STATE_HOME}/email-agent/last-reindex`, written by `email-reindex` (`modules/home/email/mbsync.nix:343-377`) | ISO-8601 timestamp of last sanctioned reindex, or `"never"` |

Output (verbatim format string, `census.nix:67-68`):
```
INBOX freshness  on-disk=<D>  indexed-files=<F>  divergence=<Δ>  tol=<T>  reindex=<ISO|never>  [ok|STALE]
```

Neither `INBOX_ONDISK` nor `INBOX_INDEXED` retains any per-file identity — they are `jq length`
and `grep -c` counts respectively. No filename, UID, or flag information survives past the
count reduction, and no set of "which files diverged" is ever computed or available for the
freshness line to report on.

### Root cause: why counts are blind to renames and to phantom drift, with live evidence

**Why a flag-rename is invisible to a count.** A maildir filename under `cur/` encodes flags as
a trailing `:2,<FLAGS>` suffix appended to a stable per-message unique token (in this
mbsync-managed maildir, the token is `U=<uid>`, e.g. `1783928439.2607160_1.hamsa,U=5202:2,`).
When a client (aerc, himalaya, the IMAP server via mbsync) marks a message Seen, the OS-level
maildir operation is a **rename** of the file from `...,U=5202:2,` to `...,U=5202:2,S` — the
file is not deleted and no new file is created. `notmuch new` (run with hooks, or `--no-hooks`
via `email-reindex`) is what teaches notmuch's Xapian database the new filename for that
message; until that runs, notmuch's database still points at the OLD filename string. The
**count** of files under `Gmail/cur` is unchanged by a rename (still N files, before and
after), so `INBOX_ONDISK` and a raw file count of `INBOX_INDEXED` are both numerically
unaffected — the census freshness line has literally no way to see this class of drift, by
construction, regardless of tolerance.

**Why phantom/deleted-file drift can hide inside a matching count.** If one message is deleted
or moved out of INBOX (on-disk count -1) at the same time a new message arrives (on-disk count
+1) faster than the index catches up, the NET count divergence can be zero even though the
*identity* of what's indexed vs. what's on disk has completely changed. Renames compound this:
a rename looks like "one file removed (old name) + one file added (new name)" to any diff that
doesn't know the two names are the same message.

**Live confirmation on the actual mailbox (2026-07-13), reproducing the task's illustrative
example almost exactly:**

```
$ himalaya envelope list -a gmail -f INBOX -o json -s 100000 | jq length
86
$ notmuch search --output=files "path:Gmail/cur or path:Gmail/new" | grep -cE "/Gmail/(cur|new)/"
86
```

Under the current logic this prints `divergence=0 tol=13 [ok]` — a clean green. But diffing the
literal filename sets (on-disk via a properly INBOX-scoped `find`, which reproduces himalaya's
86 exactly, confirming it is a safe filename source for this specific comparison — see Approach
1 below for why this scoping is safe) against the same notmuch `--output=files` listing used
today shows:

```
indexed but not on disk (notmuch's stale record):
  Gmail/cur/1783928439.2607160_1.hamsa,U=5202:2,       <- flag-rename: notmuch has the PRE-Seen name
  Gmail/cur/1783955442.2951979_1.hamsa,U=5206:2,       <- phantom: no file with this UID anywhere in cur/new
  Gmail/cur/1783965340.3234226_1.hamsa,U=5209:2,S      <- phantom: no file with this UID anywhere in cur/new

on disk but not indexed (notmuch hasn't seen yet):
  Gmail/cur/1783928439.2607160_1.hamsa,U=5202:2,S      <- flag-rename: the POST-Seen name (same UID as above)
  Gmail/new/1783970917.3437912_1.hamsa,U=5210:2,       <- genuinely new, unindexed arrival
  Gmail/new/1783971817.3472513_1.hamsa,U=5211:2,       <- genuinely new, unindexed arrival
```

This is a live instance of the task's illustrative `U=5202:2,` → `U=5202:2,S` rename, plus two
UIDs (`5206`, `5209`) that notmuch believes exist under `Gmail/cur` but that are absent from the
maildir entirely — real phantom entries, not a `search.exclude_tags` false positive (that
specific false-positive mechanism, documented in `wrapper-contracts.md:359-385`, applies to
default `notmuch search`/`count` silently excluding `tag:trash`/`tag:spam`/`tag:deleted`
messages; here the check is on the raw `--output=files` listing, which is not tag-filtered by
`search.exclude_tags` in the same way a `notmuch count` would be). **Three real divergences
(1 rename + 2 removed) are exactly offset by two new arrivals, producing `divergence=0`.** This
is direct, reproducible proof that the count-with-tolerance design cannot be patched by tuning
`TOL` — it is blind by construction to same-count identity churn, and only a set-level
comparison can see it.

### Existing staleness-detection contract (tasks 823-824-827) — what stays consistent

Summarized from `.claude/context/project/email/domain/staleness-detection.md` and
`wrapper-contracts.md` §13 (both files are extension-side summaries of `.dotfiles` facts, kept
here as the contract this enhancement must not break):

- **File-vs-file, never file-vs-message-count** (task 827): compare `himalaya envelope list`
  (on-disk FILE count, maildir++-aware) against a **path-prefix post-filtered**
  `notmuch --output=files` FILE count — never `notmuch count folder:X` (deduped Message-ID
  count, structurally the wrong unit whenever an account has real Message-ID duplication, e.g.
  Logos on-disk=341 vs `notmuch count`=318 permanently `[STALE]` under the old equality rule).
- **The `--output=files` cross-folder/cross-account duplicate-inclusion quirk**: `--output=files`
  returns every known file for a matching message across ALL folders/accounts, not just the
  folder implied by the query's `path:`/`folder:` term (verified: `notmuch count --output=files
  folder:Gmail` = 238 vs 128 real on-disk files, live task-827 example). The fix is the
  `grep -cE "/$ACCOUNT_FOLDER/(cur|new)/"` post-filter already in `census.nix:50`. Any new
  set-based comparison must apply the identical post-filter to the filename list it builds, not
  just to a count.
- **Bounded tolerance, not strict equality** for the existing count check: `T = max(5,
  ceil(0.10 * on-disk))`. This must remain byte-for-byte for backward compatibility (see
  Consumers below) — the enhancement adds a second signal, it does not replace this one.
- **`reindex=<ISO|never>` marker**: informational only, does not itself flip `[ok]`/`[STALE]`,
  written by `email-reindex` (`mbsync.nix:343-377`, `notmuch new --no-hooks`). Any new field
  added to the freshness line should sit consistently with this convention (informational
  fields do not silently change the verdict semantics of *other* fields, but — per the
  Recommendation below — the new exact-set signal is deliberately verdict-affecting, unlike
  `reindex=`).
- **Known false-positive trap** (`wrapper-contracts.md:359-385`): a naive "on-disk minus
  indexed" diff using a DEFAULT (non-`--exclude=false`) notmuch search/output-files/count
  silently drops any message carrying an excluded tag (`trash`, `spam`, `deleted` by
  `search.exclude_tags` default), which previously produced a false "22 permanently-unindexed
  files" conclusion that was later retracted. **Any new set-diff implementation must reuse
  exactly the query form `census.nix` already uses today** (`notmuch search --output=files
  "path:$ACCOUNT_FOLDER/cur or path:$ACCOUNT_FOLDER/new"`, i.e. `search`, not `count`, with a
  `path:` term, not `tag:`) — this form is not exclude-tag-filtered in a way that would recreate
  the historical false positive, but the implementer should NOT switch to a `tag:`-based query
  without re-reading this caveat.
- **`email-census` is read-only.** The enhancement must only READ (`notmuch search`, `find`,
  `himalaya envelope list`) — it must never call `email-reindex` or any mutation itself; that
  remains an explicit, separately-gated remediation step per the existing Stage 1 contract.

### Downstream consumers and what signal shape they need

1. **`skill-email-cleanup` SKILL.md, Stage 1 (`--all` mode)** parses the exact line
   `INBOX freshness  on-disk=<D>  indexed-files=<F>  divergence=<Δ>  tol=<T>  reindex=<ISO|never>
   [ok|STALE]` (quoted verbatim in `SKILL.md:325-350`) and gates on the trailing `[ok|STALE]`
   token: `[ok]` proceeds to the count probe; `[STALE]` routes to staleness remediation
   (offer `email-reindex`, re-census, re-check) or, in autonomous mode, STOPs if
   `reindex=never`, or reports a persistent residual if `reindex=<ISO>`. **This consumer parses
   by named `key=value` tokens plus the trailing bracketed verdict, not by rigid field
   position** (the prose explicitly enumerates `on-disk=<D> indexed-files=<F> divergence=<Δ>
   tol=<T> reindex=<ISO|never>` as named fields) — appending additional `key=value` tokens
   before the final bracket is additive and should not break this parser, but the bracketed
   verdict token must remain the LAST token on the line, since that is what is keyed on for the
   proceed/stop branch.
2. **`--all` autonomous/orchestrator-mode branch** additionally reads `reindex=<ISO|never>` to
   distinguish "never attempted" from "ran, residual persists." A new exact-set signal should be
   consumable the same way: e.g. autonomous mode could treat a nonzero `renamed=`/`removed=`
   count the same as it treats `[STALE]` today (STOP if reindex never attempted, else report as
   residual) — reusing the same never/ISO branching logic rather than inventing a third state.
3. **nvim `mail.lua` gate** (out of scope to modify — lives in `~/.config/nvim`, confirmed absent
   from this repo). Per the task description this is the consumer that launched aerc onto a
   stale index despite a `[ok]` census; the shape it needs is exactly what this task calls
   "authoritative": a signal it can trust to mean "the index and the maildir agree," which the
   current count-tolerance line cannot honestly claim (as demonstrated above, `[ok]` does not
   imply "no drift," only "no *net* count drift"). Whatever shape this task settles on should be
   parseable the same way the existing line is (a `grep`-able `key=value`/bracket format on
   stdout), since that is the only integration surface `email-census` exposes to any consumer
   (wrapper-only invariant — no separate machine-readable file/socket exists).

### Ranked technical approaches

**1. Full literal-filename set-diff, INBOX-scoped, UID-joined (RECOMMENDED).**
   Compare the on-disk filename set for `Gmail/{cur,new}` against the same
   path-prefix-filtered `notmuch --output=files "path:$ACCOUNT_FOLDER/cur or
   path:$ACCOUNT_FOLDER/new"` listing already computed for `INBOX_INDEXED`, but keep the full
   listing (not just its count) on both sides. Extract the `U=<n>` token from each filename as
   the join key (regex `,U=([0-9]+):` — this token is stable across flag changes, per how
   mbsync names files) and classify:
   - UID present in both sets, but full filename differs → **renamed** (flag change).
   - UID only in the indexed set → **removed** (phantom: notmuch has a stale record).
   - UID only in the on-disk set → **added** (genuinely new/unindexed).
   - **On-disk source**: himalaya's JSON envelope output does not expose maildir filenames
     (confirmed live: `himalaya envelope list -o json` fields are `id, flags, subject, from, to,
     date, has_attachment` — `id` is an internal himalaya id, e.g. `"3602"`, not a filename). A
     properly INBOX-scoped `find "$HOME/Mail/$ACCOUNT_FOLDER"/cur "$HOME/Mail/$ACCOUNT_FOLDER"/new
     -maxdepth 1 -type f` is required instead. This reintroduces `find`, which
     `staleness-detection.md`'s comparison table marks untrustworthy as a raw COUNT proxy — but
     that caution is about maildir++ folder-name ambiguity (stray `.Label.*` dirs, wrong
     directory level) when scanning an *entire account*; INBOX is, by definition, exactly
     `cur`+`new` at the account maildir root with no `.`-prefixed sibling ambiguity, so a
     `-maxdepth 1`-scoped `find` restricted to those two literal directories is the same scope
     himalaya itself resolves for "INBOX." **Verified live**: this exact `find` invocation
     returns 86 files, matching himalaya's `jq length` of 86 exactly — the two sources agree,
     so using `find` for filenames (not as a whole-account count proxy) is safe here.
   - **What it detects**: renames (flag changes), phantom/removed entries, and unindexed
     additions — the complete set of drift classes described in the task, including the
     "count matches but drift is real" case demonstrated above.
   - **What it misses**: nothing within INBOX scope; it is exhaustive by construction (it's the
     full set, not a sample).
   - **Cost**: bounded by INBOX size (currently 86 files; historically observed up to a few
     hundred). Two `find`/`notmuch search` calls plus an in-shell sort/join (`comm`, or an
     associative array keyed by UID) — sub-second, same order of magnitude as the existing
     `INBOX_INDEXED` computation it reuses.
   - **Implementation complexity**: moderate. Requires a UID-extraction regex, two sorted
     temp-file (or shell array) builds, and a three-way classification loop — more code than
     the current two `wc -l`-style counts, but entirely shell/coreutils, no new dependencies
     beyond what `census.nix` already uses (`notmuch`, `find`, `grep`, `sed`/`awk`).

**2. UID-only token set membership diff (no rename detection).**
   Same as Approach 1 but strip the `:2,<FLAGS>` suffix before diffing, so a flag-only change is
   invisible (UID present in both sets → no diff reported at all).
   - **Detects**: additions and true removals (deletions/moves out of INBOX).
   - **Misses**: exactly the flag-rename case that is half of this task's stated problem — the
     `U=5202:2,` → `U=5202:2,S` case would NOT be flagged, since the UID `5202` is present on
     both sides. This directly fails the task's stated requirement ("cannot detect maildir
     flag-renames") and is included here only to make explicit why the full-filename join
     (Approach 1) is necessary, not the cheaper UID-only join.
   - **Cost/complexity**: slightly cheaper and simpler than Approach 1, but insufficient alone.

**3. mtime-based freshness (newest maildir file mtime vs. last `notmuch new` time).**
   Compare `stat -c %Y` of the newest file under `Gmail/{cur,new}` against the
   `reindex=<ISO|never>` marker's timestamp (already available).
   - **Detects**: "something on disk changed after the last reindex ran" — a coarse
     staleness-likely signal.
   - **Misses**: WHAT changed or how much; cannot distinguish "1 message arrived" from "the
     3-way rename/phantom/add churn demonstrated above." Also a flag-rename via `mv` typically
     updates the FILE's own mtime but not necessarily the parent directory's mtime in a way
     that's reliable across filesystems/sync tools; and the known hook-race hazard
     (`wrapper-contracts.md:337-357`) means a `notmuch new` timestamp existing does not
     guarantee everything before it was actually captured. Purely time-based signals cannot
     produce the `renamed=/removed=/added=` counts this task asks for.
   - **Cost**: cheapest of all options (`stat` calls only).
   - **Complexity**: low, but does not meet the task's bar of "surface a rename/deletion-aware
     signal," only "surface a maybe-something-changed signal." Rejected as insufficient alone;
     could be added later as a cheap pre-filter (skip the full set-diff if mtimes show no
     on-disk change since last reindex) but is not a substitute.

**4. Extend the diff to All Mail (~64k messages) instead of INBOX-only.**
   Same mechanism as Approach 1 but scoped to `folder:Gmail/.All_Mail`.
   - **Detects**: the same drift classes, but across the whole archive, which is what `--all`
     sweeps and `--archive` mode actually need coverage guarantees for.
   - **Cost**: two ~64k-line listings, a UID-keyed join over tens of thousands of entries —
     still tractable in `comm`/`awk` (seconds, not minutes) but a qualitatively different cost
     tier than INBOX-only, and `email-census` currently only computes the freshness line for
     INBOX (`--archive` scope reuses the same census tooling per `wrapper-contracts.md` §11 but
     the freshness line itself is INBOX-only today).
   - **Recommendation**: out of scope for this task's stated freshness-line enhancement (which
     is specifically about the INBOX proxy per the task description's illustrative numbers,
     84 on-disk vs 122 notmuch-indexed — an INBOX-scale example). Flag as a natural follow-up
     once the INBOX mechanism is proven, reusing the same UID-join logic parameterized by
     folder, gated behind its own cost/complexity review (a full All_Mail scan on every
     `email-census` invocation would materially slow down a currently-fast read-only command).

**5. Self-heal by invoking `email-reindex` from within `email-census`.**
   Rejected outright: `email-census` is contractually `read-only`
   (`census.nix:17`, `safetyClass = "read-only"`), and `email-reindex` is explicitly a
   separately-gated, human/skill-orchestrated remediation step
   (`staleness-detection.md`'s "End-to-end flow" diagram routes STALE → offer `email-reindex` →
   re-census, never an automatic chain). This task's own scope explicitly excludes "the one-time
   `notmuch new` reindex." Not a candidate.

### Recommendation: concrete direction and proposed output shape

**Adopt Approach 1** (full literal-filename, UID-joined set-diff, INBOX-scoped), layered
alongside — not replacing — the existing count-tolerance check, for full backward
compatibility.

**Proposed freshness-line shape** (new fields appended before the trailing verdict, preserving
every existing `key=value` token and the existing count-tolerance semantics byte-for-byte):

```
INBOX freshness  on-disk=<D>  indexed-files=<F>  divergence=<Δ>  tol=<T>  reindex=<ISO|never>  renamed=<R>  removed=<X>  added=<A>  [ok|STALE]
```

- `renamed=<R>`: count of UIDs present in both the on-disk and indexed filename sets under
  different full filenames (flag changes).
- `removed=<X>`: count of UIDs present in the indexed set with no on-disk file at all (phantom
  entries — notmuch's record is stale/wrong, distinct from a rename because there is no
  matching UID on disk at all).
- `added=<A>`: count of UIDs present on disk with no indexed record (unindexed arrivals — this
  overlaps conceptually with `divergence` when it's positive, but is now precise per-UID rather
  than a net count).
- **Verdict**: `[STALE]` if EITHER the existing `|divergence| > tol` check fires OR
  `renamed + removed + added > 0` (i.e., the exact-set signal is authoritative and
  verdict-affecting on its own — this is what closes the false-green gap, since the live
  example above shows `divergence=0` can coexist with `renamed=1 removed=2 added=2`). A small
  nonzero tolerance on the exact-set signal (e.g., allow up to 1-2 to absorb a single in-flight
  mbsync write straddling the census read) may be warranted in practice and should be decided
  during planning/implementation with a quick live-repeatability check (run `email-census`
  twice in a row with no mail activity in between and confirm `renamed=0 removed=0 added=0`
  both times before hardening the threshold).
- **Backward compatibility**: every existing token (`on-disk=`, `indexed-files=`, `divergence=`,
  `tol=`, `reindex=`) is unchanged in name, position (relative order preserved), and computation.
  `skill-email-cleanup` SKILL.md's Stage 1 parser (keys off named tokens + the trailing bracket)
  should require no changes to keep working; it should be updated separately (a follow-up
  implementation/plan concern, not this research task) to ALSO branch on `renamed=`/`removed=`/
  `added=` for richer remediation messaging, and to teach the autonomous-mode STOP/residual
  logic (`SKILL.md:339-347`) to treat a nonzero exact-set signal the same way it treats
  `[STALE]` today.

**Implementation sketch for the planning phase** (informational, not this task's deliverable):
build two sorted lists — on-disk via `find "$HOME/Mail/$ACCOUNT_FOLDER"/cur
"$HOME/Mail/$ACCOUNT_FOLDER"/new -maxdepth 1 -type f -printf '%f\n'` (basenames only, to match
the basename shape `notmuch --output=files` full paths reduce to after the same
`sed 's#.*/##'`), and indexed via the EXISTING `notmuch search --output=files "path:...cur or
path:...new"` call filtered by the EXISTING `grep -cE` pattern (changed to `grep -E`, non-`-c`,
to retain the matching lines instead of only counting them), also reduced to basenames. Extract
`U=([0-9]+):` as the join key with `sed -E` or `grep -oE`, then classify via a single pass over
both sorted-by-UID lists (comparable to a merge-join, or simply two associative arrays in a
POSIX-compatible `awk` invocation given the maildir filenames contain characters — commas,
colons — that are awkward for pure shell array indexing).

## Decisions

- Keep the existing count-tolerance signal unchanged for backward compatibility; add the
  exact-set signal as new, additional, verdict-affecting fields rather than replacing the line
  format.
- Scope the new signal to INBOX only, matching the existing freshness line's scope; explicitly
  defer All Mail-scale set-diffing (Approach 4) as an out-of-scope follow-up.
- Source on-disk filenames via a `-maxdepth 1`-scoped `find` over exactly
  `$ACCOUNT_FOLDER/{cur,new}` (verified live to reproduce himalaya's authoritative on-disk COUNT
  exactly), since himalaya's own JSON output does not expose literal maildir filenames.
- Join on the `U=<uid>` token (stable across flag renames) rather than the full filename, so a
  flag-only change classifies as `renamed`, not as a spurious `removed`+`added` pair.

## Risks & Mitigations

- **Risk**: a properly-scoped `find` might diverge from himalaya's INBOX resolution on a
  differently-configured maildir (e.g. if `ACCOUNT_MAILDIR_MARKER`/folder layout ever changes).
  **Mitigation**: the implementation should assert `find`'s file COUNT equals `$INBOX_ONDISK`
  (already computed) before trusting the filename list, and fall back to reporting
  `renamed=? removed=? added=?` (matching the existing `"?"` convention for
  `DIVERGENCE`/`TOL` on parse failure) if they disagree, rather than silently trusting a
  possibly-wrong filename source.
- **Risk**: transient false positives from an in-flight mbsync write mid-census (a file being
  renamed exactly while `find` and `notmuch search` run at slightly different instants).
  **Mitigation**: a small nonzero tolerance on the exact-set signal (see Recommendation), and/or
  documenting that `email-census` output is a point-in-time read like the existing count check
  already is.
- **Risk**: reintroducing the `search.exclude_tags` false-positive trap
  (`wrapper-contracts.md:359-385`) if a future maintainer "simplifies" the query to use
  `notmuch count`/`tag:`-based forms. **Mitigation**: this report explicitly documents the
  required query form (`notmuch search --output=files "path:..."`, not `count`/`tag:`); the
  implementation should keep a comment cross-referencing this constraint, mirroring the existing
  comment at `census.nix:43-44`.
- **Risk**: downstream consumer (`skill-email-cleanup` SKILL.md) not updated to act on the new
  fields, so the richer signal is computed but never consulted for the actual `--all`
  proceed/stop decision. **Mitigation**: flag explicitly in Decisions/next-steps that a
  follow-up implementation/plan pass should update `SKILL.md`'s Stage 1 gate parsing alongside
  (or immediately after) the `census.nix` change — the freshness line change alone does not
  close the aerc false-green loop until a consumer branches on it.

## Appendix

### Search queries / commands used

- `notmuch search --output=files "path:Gmail/cur or path:Gmail/new" | grep -cE "/Gmail/(cur|new)/"`
  (reproducing `census.nix`'s exact `INBOX_INDEXED` computation)
- `himalaya envelope list -a gmail -f INBOX -o json -s 100000 | jq length` (reproducing
  `INBOX_ONDISK`)
- `himalaya envelope list -a gmail -f INBOX -o json -s 2` (schema probe — confirmed fields:
  `id, flags, subject, from, to, date, has_attachment`; no literal filename)
- `find ~/Mail/Gmail/cur ~/Mail/Gmail/new -type f` vs. the filtered `notmuch --output=files`
  listing, diffed via `comm -23` / `comm -13` on sorted lists — the live set-diff that produced
  the `renamed=1 removed=2 added=2` finding reported above.
- `grep -rl "index-architecture" .claude` — confirmed `domain/index-architecture.md` is
  referenced by `CLAUDE.md`/`skill-email-cleanup`/`commands/email.md` but does not exist as a
  file under `.claude/context/project/email/domain/`; the equivalent content (folder-token
  table, per-account semantics) lives in `wrapper-contracts.md` §11 instead, which this report
  cites directly.

### Files read

- `modules/home/email/agent-tools/census.nix` (full, 90 lines)
- `modules/home/email/agent-tools/lib.nix` (full, 352 lines — `mkPreamble`/`mkMutationPreamble`)
- `modules/home/email/mbsync.nix:335-378` (`email-thaw`/`email-reindex`)
- `.claude/context/project/email/domain/staleness-detection.md` (full)
- `.claude/context/project/email/domain/wrapper-contracts.md` (full, 386 lines)
- `.claude/skills/skill-email-cleanup/SKILL.md:300-360` (Stage 1 staleness gate)
