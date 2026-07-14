# Implementation Plan: Task #115

- **Task**: 115 - Consolidate and refactor the aerc email configuration
- **Status**: [NOT STARTED]
- **Effort**: 5 hours
- **Dependencies**: None (task 114 is explicitly out of scope; its artifacts are referenced read-only)
- **Research Inputs**:
  - specs/115_aerc_config_consolidation_refactor/reports/00_session-context-and-handoff.md (session hand-off brief; build forward from it)
  - specs/115_aerc_config_consolidation_refactor/reports/01_aerc-config-consolidation-research.md (validated brief, 11 rationale clusters, five resolved KEEP decisions)
- **Artifacts**: plans/01_aerc-config-consolidation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, .claude/rules/nix.md, .claude/context/project/nix/standards/nix-style-guide.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Refactor `modules/home/email/aerc.nix` (384 lines) for maintainability and coherence with **zero
behavior change**: consolidate ~16 `Task NN`/"Regression fix" comment citations into 11
forward-looking rationale clusters (task numbers demoted to trailing citations, rationale never
deleted), and de-duplicate `querymap-gmail`/`querymap-logos` plus the repeated
`folders-exclude` line via a let-bound Nix generator targeting byte-identical rendered output.
Definition of done: `home-manager build --flake .#benjamin` green; four of the five rendered
config files byte-identical to a captured baseline; `accounts.conf` identical in comment-stripped
(parsed) form; all 11 rationale clusters demonstrably preserved; manual user checklist delivered.

### Research Integration

The research phase (report 01) RESOLVED all five holistic-reconsideration decision points as
KEEP with documented rationale. **This plan implements those decisions as-documented and does
not re-open them** (see Decision Log D1-D5). The research left exactly two questions for this
plan, both decided below (D6, D7). The report's 11-cluster comment inventory (report §"Current
structure", table of rationale groups) is the authoritative input for Phase 3's mapping table.

### Prior Plan Reference

No prior plan (this is plan round 01 for task 115).

### Roadmap Alignment

No ROADMAP.md consultation requested (no roadmap_path in delegation context).

## Decision Log

All decisions below are binding on the implementer. D1-D5 restate the research phase's resolved
decisions (implement as-documented, do not re-litigate). D6-D8 are this plan's own decisions on
the questions research left open.

| # | Decision | Disposition |
|---|----------|-------------|
| D1 | `folders-exclude = ~^Gmail,~^Logos` blacklist | **KEEP** the mechanism unchanged (not a `folders` whitelist, not `maildir-account-path` — task 112 research explicitly rejected the latter for this shared-`~/Mail` architecture). De-duplicate the identical literal via a shared let binding; rewrite the comment as an architectural note, not a "Regression fix". |
| D2 | `alternatives = "text/plain,text/html"` (plaintext-first) | **KEEP**. Document as considered-and-rejected: one line noting text/html is one `<Enter>`/`j`/`k` press away via `:next-part` (see `[view]` binds). |
| D3 | `<Enter> = :next-part` in `view` scope | **KEEP**. Trim the 7-line comment to ~2 lines, preserving the trade-off statement (Enter no longer scrolls one line; `<Space>`/`<C-d>`/`<C-u>` cover paging). |
| D4 | `[logos]` check-mail unwired | **KEEP** unwired. Replace the implicit "matching convention" comment with an explicit decision: not wired pending a decided check-mail failure-surfacing policy (cite task 114); wiring now would add a second undifferentiated failure surface. |
| D5 | Comment consolidation approach | Consolidate 16 citations into the 11 forward-looking rationale clusters per the research table; demote task numbers to trailing parenthetical citations; NEVER delete underlying rationale. |
| D6 | **Nix generator idiom** (open question 1): top-level `let ... in` before the module attrset (module signature stays `_:` — no `lib` argument added), containing (a) `foldersExclude = "~^Gmail,~^Logos";` and (b) a small local function `mkQuerymap` built from an explicit list of lines joined with `builtins.concatStringsSep "\n"` plus a trailing `"\n"`. camelCase let-binding names per nix-style-guide.md. `lib.generators` is rejected: it has no key=value-without-spaces/querymap format, and adopting it would force changing the module signature for zero expressiveness gain. Explicit line lists give the tightest control over byte-identical output. | **DECIDED** |
| D7 | **Task-112 finding-7 pointer** (open question 2): YES — add a short (1-2 line) **Nix-level** comment adjacent to the `multi-file-strategy = act-dir` rationale flagging the unresolved curDir/INBOX-tab risk ("act-dir resolves the current folder from the open TAB name; the INBOX querymap alias is not a physical-folder key, so multi-file archive from the INBOX tab may fail with 'refusing to act on multiple files' — unresolved, never live-verified; see specs/112_aerc_enable_folder_move_archive/reports/01_enable-archive-action.md finding-7"). Rationale: the risk is currently discoverable only by reading task 112's report in full; a pointer at the point of configuration carries it forward visibly without resolving or masking it. Placed as a Nix comment (not inside the rendered accounts.conf text) so it cannot perturb the rendered file. | **DECIDED** |
| D8 | **accounts.conf comment placement** (consequence of D5): the current rationale comments at aerc.nix lines 278-296, 303-315, 319-326 live INSIDE the `home.file.".config/aerc/accounts.conf".text` string and are therefore rendered into the deployed accounts.conf. Consolidating them necessarily changes accounts.conf's rendered bytes. Decision: **hoist all rationale comments out of the rendered text to Nix-level comments** (consistent with how the querymap and binds rationale already work — Nix comments, never rendered). Consequence, explicitly accepted and justified: the rendered accounts.conf will differ from baseline by removed `#` comment lines ONLY; its parsed (comment-stripped) form must be byte-identical. Verification in Phases 3-4 enforces this with a comment-stripped normalized diff plus a raw-diff review confirming every changed line starts with `#`. This is a documentation-placement change, not a behavior change (aerc's INI parser ignores `#` lines). | **DECIDED** |

## Goals & Non-Goals

**Goals**:
- Consolidate ~16 Task-NN comment citations into 11 forward-looking rationale clusters with trailing citations (D5), so a reader who never saw tasks 34-114 understands the config.
- De-duplicate `querymap-gmail`/`querymap-logos` and the repeated `folders-exclude` line via a let-bound generator (D6), byte-identical rendered output.
- Record the five KEEP decisions (D1-D4 plus the querymap generator) explicitly in the file's comments where relevant.
- Add the finding-7 pointer comment (D7) — carry the open risk forward visibly.
- Add a short file-header contract note: shared `~/Mail` maildir root + single notmuch source, the three sync entry points (`$` keybind, check-mail-cmd, systemd timer) all converging on the flock-serialized `mail-sync` wrapper, `folder:` token semantics (bare exact-match vs `/regex/`), and the `Expunge Both` deletion danger (pointer to mbsync.nix).
- Keep `home-manager build --flake .#benjamin` green at every phase; verify via rendered-config diffs against a captured baseline.
- Deliver a manual user checklist for TUI/live-mail items the agent cannot verify.

**Non-Goals**:
- Task 114 maildir remediation (duplicate-UID) — out of scope entirely; referenced by name only.
- Any behavior redesign: no querymap query changes, no bind changes, no `[viewer]`/`[compose]` value changes, no check-mail policy work.
- `home-manager switch`, live-mail mutation, driving aerc's TUI, or any `mbsync`/`mail-sync` invocation against live servers.
- Resolving the finding-7 curDir/INBOX-tab risk or the `-a -c` parser caveat (both are preserved as flagged open items, not fixed).
- Changes to `mbsync.nix`, `mail-sync.nix`, `notmuch.nix`, `mail-sync-timer.nix`, or the `/email` wrapper contract (read-only cross-reference targets).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Generator introduces a subtle formatting difference (trailing newline, join separator, ordering) changing querymap bytes | M | M | Phase 2 gates on a byte-for-byte diff of both querymap files against baseline before any commit; iterate until zero diff |
| Comment consolidation drops load-bearing rationale (e.g. `-a -c` two-flag caveat, CLAUDE.md `folder:Gmail*` glob-inaccuracy flag, nixpkgs `maildir-store` deprecation caveat, Expunge-Both danger) | H | M | Phase 3 works from the explicit 11-cluster mapping table below (every cluster has a stated destination); Phase 4 runs a rationale-preservation audit checking each cluster's key phrases exist in the refactored file |
| A non-comment line in accounts.conf accidentally changes while hoisting comments (D8) | H | L | Comment-stripped normalized diff must be empty AND raw diff reviewed line-by-line to confirm only `#` lines changed (Phases 3-4) |
| `''` string / interpolation edge cases (e.g. `${` literal) corrupt rendered text | M | L | Neither querymap nor accounts.conf content contains `${` or `''` sequences (verified in research); byte-diff catches any surprise |
| Accidental `home-manager switch` or live-mail action | H | L | Invariant restated in every phase: build-only (`home-manager build`), never switch, never invoke mail-sync/mbsync/aerc |
| Baseline captured from a stale/dirty tree | M | L | Phase 1 verifies `git status` for modules/home/email/** is clean before capturing, and records baseline sha256sums |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Fully sequential: all phases operate on the same file and each gates on the previous phase's
rendered-diff verification. Each phase is sized for a single agent run.

### Phase 1: Capture green baseline of the five rendered config files [COMPLETED]

**Goal**: A committed-nothing, reproducible baseline of the rendered aerc config from a green
build, against which every later phase diffs.

**Tasks**:
- [x] Confirm `modules/home/email/aerc.nix` is untouched vs HEAD (`git status --porcelain modules/home/email/` shows no aerc.nix entry; the pre-existing unrelated dirty `modules/system/packages.nix` is expected and must be left alone) *(completed — modules/home/email/ clean vs HEAD)*
- [x] Run `home-manager build --flake .#benjamin` (build ONLY — never switch); require exit 0 *(completed — exit 0)*
- [x] Resolve the `home-manager-files` derivation from the build (e.g. `hm_files=$(nix-store -qR ./result | grep home-manager-files | head -1)`; fall back to `result/home-files` if the store query form differs) *(completed — /nix/store/2kdb6g08v3jxfz8d1vgq24wndw13vzrv-home-manager-files)*
- [x] `mkdir -p specs/115_aerc_config_consolidation_refactor/.baseline` and copy (dereferencing symlinks, `cp -L`) the five files: `$hm_files/.config/aerc/{accounts.conf,aerc.conf,binds.conf,querymap-gmail,querymap-logos}` *(completed — all five non-empty)*
- [x] Record `sha256sum` of all five into `.baseline/SHA256SUMS` and note the store paths in a `.baseline/PROVENANCE.txt` *(completed)*
- [x] Do NOT commit `.baseline/` contents (scratch verification data; leave unstaged — targeted staging only, never `git add -A`) *(honored — .baseline/ left unstaged)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `specs/115_aerc_config_consolidation_refactor/.baseline/*` — new scratch files (uncommitted)

**Verification**:
- Build exits 0; all five baseline files exist, are non-empty, and have recorded sha256sums

---

### Phase 2: Let-bound generator for querymaps and folders-exclude (byte-identical) [COMPLETED]

**Goal**: Structural de-duplication with zero rendered-byte change on ALL five files. Comments
are NOT touched in this phase (that is Phase 3), so full byte-identity is the gate here.

**Tasks**:
- [x] Convert the module opening from `_: {` to `_:` + top-level `let ... in {` (per D6; do not add module arguments) *(completed)*
- [x] Add `foldersExclude = "~^Gmail,~^Logos";` to the `let` block and interpolate it as `folders-exclude = ${foldersExclude}` in BOTH the `[gmail]` and `[logos]` blocks of the accounts.conf text (existing comments stay exactly where they are for now) *(completed)*
- [x] Add the `mkQuerymap` function per D6. Reference shape (implementer may adjust names, not semantics): *(completed — used the reference shape verbatim)*

  ```nix
  mkQuerymap =
    { prefix, archiveName, extraFolders ? [ ], extraTriage ? [ ] }:
    builtins.concatStringsSep "\n" (
      [
        "INBOX=folder:${prefix}"
        "Sent=folder:${prefix}/.Sent"
        "Drafts=folder:${prefix}/.Drafts"
        "Trash=folder:${prefix}/.Trash"
        "${archiveName}=folder:${prefix}/.${archiveName}"
      ]
      ++ extraFolders
      ++ [
        "Unread=tag:unread AND folder:/${prefix}/"
        "Flagged=tag:flagged AND folder:/${prefix}/"
      ]
      ++ extraTriage
    )
    + "\n";
  ```
- [x] Replace `".config/aerc/querymap-gmail".text` with `mkQuerymap { prefix = "Gmail"; archiveName = "All_Mail"; extraFolders = [ "Spam=folder:Gmail/.Spam" ]; extraTriage = [ the three existing Proposed-* lines verbatim ]; }` — the Gmail/Logos parity and the intentional Spam-line and Proposed-*-lines asymmetry become visible as data *(completed)*
- [x] Replace `".config/aerc/querymap-logos".text` with `mkQuerymap { prefix = "Logos"; archiveName = "Archive"; }` *(completed)*
- [x] Keep the existing querymap Nix comments (lines 335-356, 371-373) in place, attached to the generator call sites (they are consolidated in Phase 3, not here) *(completed — comments untouched)*
- [x] Rebuild: `home-manager build --flake .#benjamin` (build only); diff all five rendered files against `.baseline/` *(completed — exit 0)*
- [x] Iterate on the generator until `diff` is empty for every file, then commit (targeted staging: `modules/home/email/aerc.nix` only) as `task 115 phase 2: querymap and folders-exclude generator` *(completed first iteration — home-manager-files store path identical to baseline: /nix/store/2kdb6g08v3jxfz8d1vgq24wndw13vzrv)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `modules/home/email/aerc.nix` — add let block, generator, call sites; remove the two literal querymap bodies and the duplicated folders-exclude literal

**Verification**:
- Build exit 0; ALL FIVE rendered files byte-identical to baseline (`diff` empty; sha256sums match `.baseline/SHA256SUMS`)

---

### Phase 3: Consolidate the 11 rationale clusters and record decisions [NOT STARTED]

**Goal**: Rewrite the comment archaeology into forward-looking documentation per D5, D7, D8:
every rationale survives, task numbers become trailing citations, accounts.conf in-string
comments hoist to Nix level, and the five KEEP decisions plus the finding-7 pointer are recorded
in-file.

**Cluster mapping table** (authoritative work list; source line numbers refer to the pre-Phase-2
file — locate by content after Phase 2 shifts lines). Every "must preserve" phrase is audited in
Phase 4:

| # | Cluster (current lines) | Target treatment | Must preserve |
|---|------------------------|------------------|---------------|
| 1 | File header (1-2) | Rewrite as the cross-file contract note (shared ~/Mail root + single notmuch source; three sync entry points converge on flock-serialized `mail-sync`; `folder:` bare-exact vs `/regex/` semantics; Expunge-Both danger pointer to mbsync.nix) | All four contract statements |
| 2 | Tab/S-Tab (79-82, duplicated verbatim at 194-197) | Full 2-line rationale once in `messages`; 1-line cross-reference in `view` ("same Tab/S-Tab account-switch aliases as messages"). The BINDS stay duplicated in both scopes (required — different bind scopes), only the comment de-duplicates; note this duplication is intentional | Neovim buffer-nav reflex rationale; `<C-n>`/`<C-p>` fallback note |
| 3 | d/D/a/A hardening + unprompted single-archive (92-104) | One consolidated block: native keys are human-only by design (mail-guard hook cannot gate aerc's Go worker); single-archive deliberately unprompted (reversible, low blast radius) vs prompted D/A | Both safety rationales; trailing citations (task 72 Ph9, task 112) |
| 4 | `$` mail-sync keybind history (130-138) | Compress to: group-scoped + hook-bypassing by design (never `-a`, which would touch the deferred account and re-trigger preNew); routed through the single flock-serialized `mail-sync` wrapper which reindexes internally; gmail-only kept, `mail-sync logos`/`both` a trivial future extension | Why not `-a`; why no separate reindex; gmail-only is intentional |
| 5 | Proposed-* review views (152-160) | Keep essentially intact (this block is the wrapper-contract safety documentation — already forward-looking); demote task number to trailing citation | NEVER-native-delete/archive rationale; manifest/approval flow; d/a shadowing scoped to these three views only |
| 6 | `<Enter>` part-cycle (183-190) | Trim to ~2 lines per D3 | No native part-select concept; trade-off statement (Enter no longer scrolls; Space/C-d/C-u page) |
| 7 | `:reply -c` viewer-return (199-206) | Compress to ~3 lines: `-c` closes the viewer tab at reply-open so post-send focus returns to the list; safe no-op from the list; orthogonal to `-a` | The **`-a -c` two-flag-is-the-verified-syntax caveat (bundled `-ac` NOT verified)** — must survive verbatim in substance |
| 8 | `:send -a flat` archive-on-reply (246-253) | Compress to ~3 lines: native send-archive acts on the exact replied-to message by reference (immune to cursor drift), replaced the removed Subject-sniffing hook (re-adding it would double-archive); `-a` inert on forward/compose/recall | Do-not-reintroduce-the-hook warning; inert-on-other-paths note |
| 9 | maildir-store/multi-file-strategy (278-284, 319-322, in-string) | Hoist to ONE Nix-level block above the accounts.conf `home.file` entry (D8): required for real `:archive` (worker returns errUnsupported without it); nixpkgs 0.21.0 still uses `maildir-store`, upstream renamed to `enable-maildir` — revisit on derivation bump. Add the D7 finding-7 pointer here (1-2 lines) | errUnsupported mechanism; forward-compat caveat; **new finding-7 pointer (D7)** |
| 10 | folders-exclude (288-296, 324-326, in-string) | Hoist to ONE Nix-level architectural note (per D1) near the `foldersExclude` let binding or the accounts block: both accounts share one maildir-store root by design, so the worker enumerates the whole physical tree; folders-exclude is display-only (does not affect `:archive`'s file move) and hides only the raw physical tree (`~` = regex; no querymap name starts with Gmail/Logos). State D1: whitelist and maildir-account-path considered and rejected (task 112 research; shared-root architecture is intentional) | Display-only clarification; regex-prefix explanation; considered-and-rejected note |
| 11 | check-mail (303-315, in-string) + querymap scoping (337-356, 372-373) | check-mail: hoist to Nix level; keep secondary-to-systemd-timer framing, `--no-wait` fail-fast rationale, 30s timeout rationale, `u` keybind note; replace the `[logos]`-unwired sentence with the explicit D4 decision citing task 114. Querymap scoping: consolidate the two comment blocks into ONE above the generator call sites: why bare `folder:Gmail` for INBOX (tag:inbox is a permanent delivered-marker; `/Gmail/` regex over-matches .All_Mail); why Unread/Flagged/Proposed-* stay account-wide (tag-driven triage views; re-scoping Proposed-* would hide triaged messages and undermine the review gate — do not re-scope); keep the `folder:Gmail*` glob-does-NOT-work empirical note and its CLAUDE.md-accuracy-follow-up flag | D4 explicit decision text; do-not-re-scope warning; glob-inaccuracy flag; ~12,580-vs-~85 over-match consequence may be summarized but the mechanism must remain |

**Additional tasks**:
- [ ] Add the D2 considered-and-rejected line at `viewer.alternatives` (Nix comment: plaintext-first kept; html one keypress away via `:next-part`)
- [ ] After hoisting, the rendered accounts.conf must contain only `[section]` and `key = value` lines (plus blank lines exactly as before) — no content lines added, removed, or reordered
- [ ] Rebuild (build only) and run the Phase 3 diff gate below; iterate until it passes
- [ ] Commit (`modules/home/email/aerc.nix` only) as `task 115 phase 3: consolidate rationale clusters`

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:
- `modules/home/email/aerc.nix` — comments only (plus the physical relocation of accounts.conf comment text from inside the `''` string to Nix level; no key=value or bind changes)

**Verification**:
- Build exit 0
- `aerc.conf`, `binds.conf`, `querymap-gmail`, `querymap-logos`: byte-identical to baseline
- `accounts.conf`: `diff <(grep -v '^[[:space:]]*#' .baseline/accounts.conf) <(grep -v '^[[:space:]]*#' <new>)` is EMPTY, and the raw `diff` output contains ONLY removed/changed lines beginning with `#` (D8 gate)

---

### Phase 4: Verification audit, rationale-preservation check, and manual user checklist [NOT STARTED]

**Goal**: Final gates, proof that no rationale was lost, and the deliverables the user needs to
manually verify TUI behavior.

**Tasks**:
- [ ] Final full re-diff of all five rendered files against `.baseline/` (same gates as Phase 3; catches any drift from late edits)
- [ ] Rationale-preservation audit: for each of the 11 clusters, grep the refactored aerc.nix for its "must preserve" anchor phrases (e.g. `-ac`/two-flag caveat, `errUnsupported`, `enable-maildir`, `folder:Gmail*` glob note, "do not re-scope", Expunge, finding-7 pointer, task 114 citation in the check-mail decision). Record the cluster-by-cluster result table in the summary. Any missing item: fix in aerc.nix and re-run the Phase 3 diff gate before proceeding
- [ ] Confirm every demoted task number survives as a trailing citation where the mapping table says so (spot-check clusters 3, 5, 9, 10, 11)
- [ ] Line-count sanity check: report before (384) vs after; expect a net reduction from the querymap/comment de-duplication
- [ ] Run `nix flake check` if inexpensive, else rely on the already-green `home-manager build`
- [ ] Write `specs/115_aerc_config_consolidation_refactor/summaries/01_aerc-config-consolidation-summary.md` containing: what changed and why; the Decision Log outcomes (D1-D8); the diff-verification evidence (sha256 table); the rationale-audit table; and the **manual user checklist** below
- [ ] Note in the summary that `.baseline/` is retained (uncommitted) for the user's own re-verification and may be deleted afterwards
- [ ] Commit summary + any final aerc.nix touch-ups as `task 115: complete implementation`

**Manual user checklist** (agent MUST NOT perform these — TUI/live-mail invariant):
1. Open aerc: per-account sidebars still show only querymap virtual folders (no physical Gmail/*, Logos/* clutter, no cross-account bleed)
2. INBOX tab shows the true inbox (~85-message scale, not ~12.5k)
3. Reply from list and from viewer -> send -> replied message archives -> focus returns to the message list
4. In the viewer, `<Enter>`/`j`/`k` cycle text/plain <-> text/html
5. `u` (check-mail) still triggers a sync attempt; the "Mail sync + reindex complete" toast appears on success (a gmail sync failure is expected until task 114 is fixed — known, out of scope)
6. Carried forward, still user-pending (from tasks 112/113, unchanged by this refactor): the live archive -> mbsync -> confirm-in-Gmail-web end-to-end check, and the finding-7 multi-file-archive-from-INBOX-tab probe

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `specs/115_aerc_config_consolidation_refactor/summaries/01_aerc-config-consolidation-summary.md` — new
- `modules/home/email/aerc.nix` — only if the audit finds a dropped rationale

**Verification**:
- All Phase 3 diff gates pass on final state; audit table shows 11/11 clusters preserved; summary exists and contains the manual checklist

## Testing & Validation

- [ ] `home-manager build --flake .#benjamin` exits 0 after every phase (build ONLY; `home-manager switch` is forbidden for agents)
- [ ] Byte-identity: `aerc.conf`, `binds.conf`, `querymap-gmail`, `querymap-logos` match baseline sha256s at Phases 2, 3, and 4
- [ ] `accounts.conf`: comment-stripped diff empty; raw diff `#`-lines-only (Phases 3-4, per D8)
- [ ] Rationale-preservation audit: 11/11 clusters' anchor phrases present (Phase 4)
- [ ] Invariants held throughout: no live-mail mutation, no mbsync/mail-sync invocation, no wrapper-contract or folder:-token changes, no edits to mbsync.nix/mail-sync.nix/notmuch.nix/mail-sync-timer.nix, finding-7 risk carried forward (D7) not resolved
- [ ] Manual user checklist delivered in the summary (TUI/live-mail items remain user-pending by design)

## Artifacts & Outputs

- plans/01_aerc-config-consolidation.md (this file)
- Refactored `modules/home/email/aerc.nix` (behavior-preserving; expected net line reduction)
- `specs/115_aerc_config_consolidation_refactor/.baseline/` — uncommitted rendered-config baseline + SHA256SUMS + PROVENANCE.txt
- summaries/01_aerc-config-consolidation-summary.md — decision outcomes, diff evidence, rationale-audit table, manual user checklist

## Rollback/Contingency

- Each phase is a single scoped commit touching only `modules/home/email/aerc.nix` (plus the
  summary in Phase 4): revert with `git revert <sha>` per phase, newest first. No generated or
  live state to unwind (build-only; nothing was switched or synced).
- If Phase 2's generator cannot reach byte-identity after reasonable iteration, fall back to
  de-duplicating ONLY the `folders-exclude` literal (trivially byte-safe) and keep the two
  literal querymap blocks, recording the fallback as an explicit deviation in the summary —
  comment consolidation (Phase 3) proceeds regardless.
- If the Phase 3 accounts.conf gate keeps failing on non-comment lines, restore the in-string
  text verbatim from git and re-apply comment hoisting in smaller steps (one comment block per
  edit, diffing between each).
- The uncommitted `.baseline/` directory and the pre-existing dirty `modules/system/packages.nix`
  must never be reset/cleaned; use targeted staging only (never `git add -A`).
