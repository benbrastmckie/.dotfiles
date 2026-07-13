# Implementation Plan: Rename/Deletion-Aware Census Freshness Signal

- **Task**: 108 - census freshness rename/deletion-aware signal
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_freshness-signal-research.md
- **Artifacts**: plans/01_freshness-set-diff-signal.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; nix.md
- **Type**: nix

## Overview

Enhance the INBOX index-freshness line in `modules/home/email/agent-tools/census.nix` so it is
rename/deletion-aware rather than a pure count-with-tolerance proxy. The current line compares two
counts (`himalaya` on-disk envelope count vs a path-prefix-filtered `notmuch --output=files` count)
and is structurally blind to same-count identity churn — a live-verified false-green (`divergence=0`
coexisting with a real `U=5202` flag-rename plus two phantom entries) let aerc launch onto a stale
notmuch index. This plan adds a second, authoritative INBOX-scoped, UID-joined literal-filename
set-diff that emits new `renamed=`/`removed=`/`added=` fields (appended before the trailing
`[ok|STALE]` bracket) and flips the verdict to `[STALE]` when either the existing count check or the
new exact-set check fires.

### Research Integration

This plan implements Approach 1 (RECOMMENDED) from `reports/01_freshness-signal-research.md`: a full
literal-filename set-diff, INBOX-scoped, joined on the stable `U=<uid>` maildir token so a flag-only
rename classifies as `renamed` rather than a spurious `removed`+`added` pair. Key constraints carried
from the research:

- Reuse the EXISTING query form `notmuch search --output=files "path:$ACCOUNT_FOLDER/cur or
  path:$ACCOUNT_FOLDER/new"` (changing `grep -cE` to `grep -E` to keep the matching lines, not just
  their count) — never switch to a `notmuch count`/`tag:`-based form, which would reintroduce the
  `search.exclude_tags` false-positive trap (`wrapper-contracts.md` §13 / lines 359-385).
- Source on-disk filenames via a `-maxdepth 1`-scoped `find` over exactly
  `$ACCOUNT_FOLDER/{cur,new}` (himalaya's JSON does not expose literal maildir filenames;
  live-verified that this `find` reproduces himalaya's on-disk count of 86 exactly).
- Apply the identical `/$ACCOUNT_FOLDER/(cur|new)/` post-filter to the indexed filename LIST, not
  just to a count, to strip the `--output=files` cross-folder/cross-account duplicate-inclusion
  quirk.
- Keep every existing `key=value` token unchanged in name, order, and computation; the trailing
  bracketed verdict MUST remain the LAST token on the line (that is what `skill-email-cleanup`
  Stage 1 keys on).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` provided). This task advances the tasks-823/824/827
staleness-detection contract by closing the same-count-churn false-green gap it left open.

## Goals & Non-Goals

**Goals**:
- Emit an INBOX-scoped, UID-joined literal-filename set-diff as new `renamed=<R> removed=<X>
  added=<A>` fields on the existing `INBOX freshness` line.
- Make that exact-set signal verdict-affecting: `[STALE]` when either the existing
  `|divergence| > tol` check OR the exact-set check fires.
- Preserve byte-for-byte backward compatibility of every existing token and the trailing
  `[ok|STALE]` bracket position, so `skill-email-cleanup` Stage 1's named-token + trailing-bracket
  parser keeps working unchanged.
- Keep the signal bounded to INBOX scope and read-only (find/notmuch/himalaya only; no mutation).
- Document the new fields and authoritative contract in the email-extension docs.

**Non-Goals** (explicitly out of scope per the task description and research §Context & Scope):
- The `~/Mail` duplicate-UID data repair (fixing the underlying phantom entries).
- The one-time `notmuch new` reindex / any self-heal that invokes `email-reindex` from within
  `email-census` (`email-census` stays `safetyClass = "read-only"`).
- Hardening the nvim `mail.lua` aerc-launch gate (lives in `~/.config/nvim`, a separate repo not
  present under `.dotfiles`).
- Extending the set-diff to `All_Mail` (~64k messages) — deferred follow-up (research Approach 4).
- Updating `skill-email-cleanup` SKILL.md's Stage 1 parser to branch on the new fields (a separate
  follow-up noted in research Risks; the doc updates here only describe the new contract).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A properly-scoped `find` diverges from himalaya's INBOX resolution on a differently-configured maildir | M | L | Assert `find`'s file COUNT equals the already-computed `$INBOX_ONDISK` before trusting the filename list; on mismatch emit `renamed=? removed=? added=?` (matching the existing `"?"` convention) and set `FRESH=STALE` |
| Transient false positives from an in-flight mbsync write straddling the census read | M | M | Allow a small nonzero tolerance on the exact-set signal (decided via a live back-to-back repeatability check in Phase 3); document the line as a point-in-time read |
| A future maintainer "simplifies" the query to `notmuch count`/`tag:` and reintroduces the `search.exclude_tags` false positive | H | L | Keep an inline comment cross-referencing `wrapper-contracts.md` §13 constraint at the new set-diff code, mirroring the existing comment at census.nix:43-44 |
| awk/shell join mishandles maildir filenames (commas/colons) | M | L | Use a POSIX `awk` UID-keyed associative-array join over basenames rather than pure shell array indexing; unit-check on a synthetic fixture in Phase 3 |
| Downstream consumer never updated to act on new fields (richer signal computed but not consulted) | M | M | Out of scope here, but explicitly documented as a required follow-up in the doc updates (Phase 4) and Non-Goals |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential (one phase per
wave).

### Phase 1: Implement the UID-joined set-diff computation [NOT STARTED]

**Goal**: Add the INBOX-scoped literal-filename set-diff to the census wrapper script, computing
`RENAMED`/`REMOVED`/`ADDED` counts, without yet touching the verdict logic or output line.

**Tasks**:
- [ ] In `census.nix`, immediately after the existing `INBOX_INDEXED` count computation
      (lines 48-50), add a second computation that retains the matching indexed filename LIST:
      reuse the same `notmuch search --output=files "path:$ACCOUNT_FOLDER/cur or
      path:$ACCOUNT_FOLDER/new"` call, filter with `grep -E "/$ACCOUNT_FOLDER/(cur|new)/"`
      (non-`-c`), and reduce to basenames (`sed 's#.*/##'`).
- [ ] Build the on-disk filename list via
      `find "$HOME/Mail/$ACCOUNT_FOLDER/cur" "$HOME/Mail/$ACCOUNT_FOLDER/new" -maxdepth 1 -type f
      -printf '%f\n'` (basenames only), guarded so a missing directory does not abort the script.
- [ ] Add a guard: assert the `find` file count equals the already-computed `$INBOX_ONDISK`; if it
      does not, set `RENAMED=REMOVED=ADDED="?"` and skip the join (fallback path).
- [ ] Implement the UID-keyed join over the two basename lists using a single POSIX `awk` pass
      (extract `U=([0-9]+):` as key): UID in both under different full basenames -> `renamed`;
      UID only in indexed -> `removed`; UID only in on-disk -> `added`. Emit the three counts into
      shell variables `RENAMED`, `REMOVED`, `ADDED`.
- [ ] Add an inline comment cross-referencing the `wrapper-contracts.md` §13 required-query-form
      constraint (mirroring the existing comment at census.nix:43-44), so the `search`/`path:`
      query form is not "simplified" into the exclude-tags trap.
- [ ] Keep all reads within the sanctioned set (`find`, `notmuch search`, `himalaya`) — no
      mutation, no `email-reindex` call; preserve `safetyClass = "read-only"`.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `modules/home/email/agent-tools/census.nix` - insert the set-diff computation block after the
  existing `INBOX_INDEXED` count (around lines 50-51), before the tolerance block.

**Verification**:
- `nix flake check` passes (script string still evaluates; no Nix syntax errors).
- Reading the modified script confirms `RENAMED`/`REMOVED`/`ADDED` are assigned on both the
  normal and the count-mismatch fallback paths, and that the indexed query form is unchanged.

---

### Phase 2: Wire the exact-set check into the verdict and output line [NOT STARTED]

**Goal**: Make the new signal verdict-affecting and append the new fields to the freshness line,
preserving backward-compatible field ordering and the trailing bracket position.

**Tasks**:
- [ ] Extend the verdict logic (census.nix:55-63): after computing `FRESH` from the existing
      `|divergence| <= tol` check, flip `FRESH="STALE"` if the exact-set signal exceeds its
      threshold — i.e. `RENAMED + REMOVED + ADDED > SETDIFF_TOL` (with `SETDIFF_TOL` a named
      variable, default 0, to be finalized in Phase 3). Treat a `"?"` fallback for any of the three
      as `STALE` (parse-failure convention).
- [ ] Guard the arithmetic so a `"?"` value never enters a `$(( ))` expression (branch on the
      numeric-regex check already used for `INBOX_ONDISK`).
- [ ] Extend the `printf` format string (census.nix:67-68) to append `  renamed=%s  removed=%s
      added=%s` AFTER `reindex=%s` and BEFORE the trailing `  [%s]` verdict bracket, passing
      `$RENAMED $REMOVED $ADDED` in order. Confirm the bracketed verdict remains the LAST token.
- [ ] Do NOT alter the name, relative order, or computation of any existing token (`on-disk=`,
      `indexed-files=`, `divergence=`, `tol=`, `reindex=`).

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `modules/home/email/agent-tools/census.nix` - verdict block (55-63) and the `printf` line
  (67-68).

**Verification**:
- `nix flake check` passes.
- Reading the modified `printf` confirms field order:
  `on-disk indexed-files divergence tol reindex renamed removed added [verdict]` with the bracket
  last.
- The verdict variable is set to `STALE` on any of: count-tolerance breach, exact-set breach, or a
  `"?"` fallback.

---

### Phase 3: Build and verify against the live INBOX [NOT STARTED]

**Goal**: Build the agent-tools and run `email-census` against the real Gmail INBOX to confirm the
new fields appear, behave, and are repeatable; finalize `SETDIFF_TOL`.

**Tasks**:
- [ ] Run `nix flake check` and build the home-manager configuration (or build the `email-census`
      package directly, e.g. `nix build .#homeConfigurations...` / `home-manager build --flake`) so
      the updated wrapper is on `$PATH`.
- [ ] Confirm the `email-census` binary is on `$PATH` (wrapper-only `$PATH` precondition) before
      invoking it.
- [ ] Run `email-census` (default `account=gmail`) and confirm the `INBOX freshness` line now shows
      `renamed=<R> removed=<X> added=<A>` before the `[ok|STALE]` bracket, and that existing tokens
      are unchanged.
- [ ] Run `email-census` twice back-to-back with no intervening mail activity and confirm the
      exact-set counts are stable (ideally `renamed=0 removed=0 added=0` both times, or a small
      stable residual). Use the observed jitter to finalize `SETDIFF_TOL` (0 if stable; 1-2 only if
      a genuine in-flight-write residual is observed) and update Phase 2's threshold accordingly.
- [ ] If feasible, exercise a synthetic flag-rename case: identify an INBOX `U=<uid>` file, and
      WITHOUT running `notmuch new`, confirm the census reports `renamed>=1` (i.e. notmuch's stale
      record vs the on-disk name) — reproducing the research's `U=5202:2,` -> `U=5202:2,S` finding.
      Do this read-only against existing drift where possible; if manufacturing drift, restore any
      test state and DO NOT run a reindex as part of this task.
- [ ] Confirm the count-mismatch fallback path renders `renamed=? removed=? added=?` and `[STALE]`
      (can be checked by reasoning/inspection if the live counts always agree).

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `modules/home/email/agent-tools/census.nix` - only if Phase 3 finalizes a nonzero `SETDIFF_TOL`
  (small edit to the threshold constant).

**Verification**:
- `nix flake check` passes and the build succeeds.
- Live `email-census` output shows the three new fields with sane values and a correct verdict.
- Back-to-back runs are stable within the chosen tolerance.

---

### Phase 4: Update email-extension documentation [NOT STARTED]

**Goal**: Document the new freshness-line fields and the authoritative rename/deletion-aware
contract in the extension docs.

**Tasks**:
- [ ] Update `wrapper-contracts.md` §13 freshness-line format: add `renamed=`/`removed=`/`added=` to
      the documented line shape (after `reindex=`, before the bracket), describe each field's
      meaning, and state the new verdict rule ([STALE] if EITHER count-tolerance OR exact-set
      fires). Reaffirm the required query form (`notmuch search --output=files "path:..."`, never
      `count`/`tag:`).
- [ ] Update `domain/staleness-detection.md`: describe the UID-joined set-diff as the authoritative
      rename/deletion-aware signal, the INBOX-only scope (explicitly noting All_Mail is a deferred
      follow-up), the `find`-based on-disk filename source and its count-equality guard, and the
      `"?"` fallback convention.
- [ ] Note explicitly in the docs that `skill-email-cleanup` Stage 1 parser branching on the new
      fields is a required FOLLOW-UP (out of scope here) — the census change alone does not close
      the aerc false-green loop until a consumer acts on it.
- [ ] Verify no task-number references leak into these deliverable docs (per
      `no-task-references-in-deliverables.md`); keep descriptions contract-oriented.

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.claude/context/project/email/domain/wrapper-contracts.md` - §13 freshness-line format.
- `.claude/context/project/email/domain/staleness-detection.md` - new signal description.

**Verification**:
- Both docs describe the new fields, scope, verdict rule, and required-query-form constraint.
- The documented line shape matches the actual `printf` in `census.nix` byte-for-byte in token
  order.

## Testing & Validation

- [ ] `nix flake check` passes after Phases 1, 2, and 3.
- [ ] Build succeeds: `home-manager build --flake .#<user>` (or the equivalent `nix build` of the
      configuration that provides `email-census`), and `email-census` is on `$PATH`.
- [ ] `email-census` (account gmail) prints an `INBOX freshness` line containing, in order,
      `on-disk= indexed-files= divergence= tol= reindex= renamed= removed= added= [ok|STALE]` with
      the bracket LAST.
- [ ] Existing tokens (`on-disk`, `indexed-files`, `divergence`, `tol`, `reindex`) are byte-for-byte
      unchanged in name and relative order.
- [ ] Back-to-back `email-census` runs with no mail activity produce stable exact-set counts within
      the chosen `SETDIFF_TOL`.
- [ ] Synthetic (or found) flag-rename drift is reported as `renamed>=1` with verdict `[STALE]`
      (read-only; no reindex performed).
- [ ] The count-mismatch fallback renders `renamed=? removed=? added=?` and `[STALE]`.
- [ ] `email-census` remains read-only: no `email-reindex`/`mbsync`/mutation is invoked; only
      `find`, `notmuch search`, and `himalaya envelope list` reads occur.
- [ ] Signal stays INBOX-scoped: no `All_Mail` / `folder:Gmail/.All_Mail` set-diff is performed.

## Artifacts & Outputs

- Modified `modules/home/email/agent-tools/census.nix` (set-diff computation + verdict + output
  line).
- Updated `.claude/context/project/email/domain/wrapper-contracts.md` (§13 freshness-line format).
- Updated `.claude/context/project/email/domain/staleness-detection.md` (authoritative signal
  description).
- A verified `email-census` freshness line exposing `renamed=`/`removed=`/`added=` fields.

## Rollback/Contingency

- The change is confined to one wrapper script plus two doc files, with no data mutation and no new
  binaries — a `git revert` of the task's commits fully restores the prior count-only freshness
  line; downstream `skill-email-cleanup` Stage 1 (which parses by named tokens + trailing bracket)
  is unaffected by the removal since it never required the new fields.
- If the live verification (Phase 3) shows the exact-set signal is too noisy to stabilize even with
  a small `SETDIFF_TOL`, fall back to computing and PRINTING the `renamed=`/`removed=`/`added=`
  fields as informational-only (leaving the verdict driven solely by the existing count-tolerance
  check, like `reindex=` today), and record the noise finding as a follow-up — this preserves the
  richer diagnostic output without risking a chronic false-STALE.
- If `find`'s count reliably disagrees with `$INBOX_ONDISK` on this machine's maildir layout, the
  count-equality guard makes the signal degrade safely to `renamed=? removed=? added=? [STALE]`
  rather than emitting wrong numbers; investigate the layout before hardening.
