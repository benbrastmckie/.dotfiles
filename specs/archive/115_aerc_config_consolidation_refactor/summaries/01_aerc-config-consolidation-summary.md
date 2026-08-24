# Implementation Summary: Task #115

**Completed**: 2026-07-14
**Duration**: ~35 minutes (4 phases, all gates passed first iteration)

## Overview

Behavior-preserving consolidation refactor of `modules/home/email/aerc.nix`. The two querymap
files and the duplicated `folders-exclude` literal are now produced by a let-bound `mkQuerymap`
generator and a shared `foldersExclude` binding (byte-identical rendered output), and the ~16
`Task NN`/"Regression fix" comment citations were consolidated into 11 forward-looking rationale
clusters with task numbers demoted to trailing citations. No key, value, bind, or query changed.

## What Changed

- `modules/home/email/aerc.nix` — the only source file touched (384 -> 431 lines):
  - New top-level `let ... in` (module signature stays `_:`) with `foldersExclude` and
    `mkQuerymap` (explicit line lists + `builtins.concatStringsSep`, per D6); both querymap
    `home.file` bodies replaced by generator calls; the Gmail Spam-line and Proposed-* triage
    asymmetries are now visible as call-site data.
  - File header rewritten as the cross-file contract note (shared `~/Mail` root + single notmuch
    source; three sync entry points converging on the flock-serialized `mail-sync` wrapper;
    `folder:` bare-exact vs `/regex/` token semantics; `Expunge Both` deletion danger pointer to
    mbsync.nix).
  - All accounts.conf in-string rationale comments hoisted to Nix level (D8); the rendered
    accounts.conf now contains only `[section]` and `key = value` lines (plus the original blank
    line).
  - The five KEEP decisions recorded in-file: folders-exclude blacklist (D1, at the
    `foldersExclude` binding, with the considered-and-rejected whitelist/maildir-account-path
    note), plaintext-first viewer (D2, at `viewer.alternatives`), `<Enter>` = `:next-part`
    trimmed with trade-off kept (D3), `[logos]` check-mail explicitly UNWIRED pending a
    failure-surfacing policy citing task 114 (D4), and the querymap generator itself (D6).
  - The task-112 finding-7 curDir/INBOX-tab risk carried forward as an explicitly flagged
    OPEN RISK Nix comment next to the `multi-file-strategy` rationale (D7) — not resolved, not
    masked.

## Decision Log Outcomes (D1-D8)

| # | Decision | Outcome |
|---|----------|---------|
| D1 | folders-exclude blacklist KEEP | Implemented: mechanism unchanged; literal de-duplicated via `foldersExclude`; comment rewritten as architectural note with considered-and-rejected record |
| D2 | Plaintext-first KEEP | Implemented: considered-and-rejected comment at `viewer.alternatives` |
| D3 | `<Enter>` = `:next-part` KEEP | Implemented: 7-line comment trimmed to 4, trade-off statement preserved |
| D4 | `[logos]` check-mail KEEP unwired | Implemented: explicit DECISION comment citing task 114 replaces the "matching convention" framing |
| D5 | 16 citations -> 11 clusters | Implemented per the plan's authoritative mapping table; no rationale deleted; task numbers demoted to trailing citations |
| D6 | Generator idiom | Implemented with the plan's reference shape verbatim; module signature stays `_:` |
| D7 | Finding-7 pointer | Implemented as a Nix-level OPEN RISK comment (cannot perturb the rendered file) |
| D8 | accounts.conf comment hoisting | Implemented; comment-stripped diff empty; raw diff shows only removed `#` lines |

## Verification

- `home-manager build --flake .#benjamin`: exit 0 after every phase (build only, never switch)
- `nix flake check --no-build`: all checks passed
- Phase 2 gate: the entire `home-manager-files` derivation hashed identically to baseline
  (`/nix/store/2kdb6g08v3jxfz8d1vgq24wndw13vzrv-home-manager-files`) — all five files
  byte-identical by construction
- Final (Phase 4) rendered sha256 vs baseline:

| File | Baseline sha256 (prefix) | Final sha256 (prefix) | Gate | Result |
|------|--------------------------|----------------------|------|--------|
| aerc.conf | f81046b92a7fa816 | f81046b92a7fa816 | byte-identity | PASS |
| binds.conf | c630fe8eac45a9ca | c630fe8eac45a9ca | byte-identity | PASS |
| querymap-gmail | 745ba80d92639e97 | 745ba80d92639e97 | byte-identity | PASS |
| querymap-logos | 27e4e878481138ec | 27e4e878481138ec | byte-identity | PASS |
| accounts.conf | fdf254ea07376d6a | 128026103dbf379c | comment-stripped diff EMPTY + raw diff only removed `#` lines (D8) | PASS |

  accounts.conf differs from baseline exclusively by the 29 removed in-string `#` comment lines
  (0 non-`#` change lines; the rendered file now contains 0 `#` lines); aerc's INI parser ignored
  those lines, so parsed behavior is unchanged.

## Rationale-Preservation Audit (11/11 clusters)

| Cluster | Anchor phrases checked | Result |
|---------|------------------------|--------|
| 1 File-header contract | shared ~/Mail maildir root; flock-serialized; Expunge Both; EXACT maildir-folder vs regex semantics | PASS |
| 2 Tab/S-Tab | buffer-nav reflex; fallback aliases; bind "duplication is intentional" note | PASS |
| 3 d/D/a/A hardening | human-only; mail-guard hook; deliberately UNPROMPTED; trailing citations (task 72 phase 9; task 112) | PASS |
| 4 `$` mail-sync | never `mbsync -a`; `notmuch new --no-hooks` (no separate reindex); gmail-only intentional; (task 72 phase 9; task 109) | PASS |
| 5 Proposed-* views | NEVER mutate inline; APPROVED manifest; d/a SHADOW scoped to the three views; (task 72 phase 9) | PASS |
| 6 `<Enter>` part-cycle | no native "Enter to select" concept; Enter no longer scrolls, Space/C-d/C-u page instead | PASS |
| 7 `:reply -c` | `-a -c` two-separate-flags verified syntax, bundled `-ac` NOT verified; safe no-op from list; orthogonal to -a | PASS |
| 8 `:send -a flat` | do NOT reintroduce the removed hook (double-archive); `-a` inert on forward/compose/recall; (task 113) | PASS |
| 9 maildir-store | errUnsupported mechanism; enable-maildir forward-compat caveat; finding-7 OPEN RISK pointer with "refusing to act on multiple files" (D7) | PASS |
| 10 folders-exclude | DISPLAY-ONLY clarification; `~` regex-prefix explanation; considered-and-rejected note; (task 112) | PASS |
| 11 check-mail + querymap scoping | D4 UNWIRED decision citing task 114; `folder:Gmail*` glob-does-NOT-work note + CLAUDE.md accuracy follow-up flag; "Do not re-scope" warning; ~12,580-vs-~85 over-match mechanism; (task 34 phase 5/F5; task 109; task 110; task 113) | PASS |

Trailing-citation spot-check (clusters 3, 5, 9, 10, 11): all demoted task numbers present as
trailing parenthetical citations.

## Plan Deviations

- **Line-count expectation not met** (Phase 4 sanity check, not a gate): 384 -> 431 lines
  (+47), where the plan expected a net reduction. The de-duplication savings (two querymap
  literal bodies, duplicated comments) were outweighed by the plan's own mandated additions:
  the 16-line cross-file contract header (cluster 1), the explicit KEEP-decision records
  (D1-D4), the finding-7 OPEN RISK pointer (D7), and the generator's let block. All additions
  are plan-mandated content; no gate depended on the line count.
- Otherwise none — implementation followed the plan, and every diff gate passed on its first
  iteration (Phase 2's fallback contingency was never needed).

## Manual User Checklist (agent MUST NOT perform these — TUI/live-mail invariant)

1. Open aerc: per-account sidebars still show only querymap virtual folders (no physical
   Gmail/*, Logos/* clutter, no cross-account bleed)
2. INBOX tab shows the true inbox (~85-message scale, not ~12.5k)
3. Reply from list and from viewer -> send -> replied message archives -> focus returns to the
   message list
4. In the viewer, `<Enter>`/`j`/`k` cycle text/plain <-> text/html
5. `u` (check-mail) still triggers a sync attempt; the "Mail sync + reindex complete" toast
   appears on success (a gmail sync failure is expected until task 114 is fixed — known, out of
   scope)
6. Carried forward, still user-pending (from tasks 112/113, unchanged by this refactor): the
   live archive -> mbsync -> confirm-in-Gmail-web end-to-end check, and the finding-7
   multi-file-archive-from-INBOX-tab probe

Note: these deployed files only change after a `home-manager switch` (user-performed); this task
was build-only.

## Notes

- `specs/115_aerc_config_consolidation_refactor/.baseline/` is retained UNCOMMITTED (rendered
  baseline + SHA256SUMS + PROVENANCE.txt) for your own re-verification; it may be deleted
  afterwards.
- Invariants held: no `home-manager switch`; no live-mail action (no himalaya/notmuch/msmtp/
  mbsync mutation); no wrapper-contract or `folder:` token changes; no edits to mbsync.nix,
  mail-sync.nix, notmuch.nix, or mail-sync-timer.nix; task 114 untouched; finding-7 carried
  forward as flagged open risk, not resolved.
