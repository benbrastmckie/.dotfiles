# Research Report: Task #80

**Task**: 80 - Live-verify the task-79 email wrapper multi-account contract against the
switched-in system and gather everything needed to plan (a) a live `/email --logos` exercise
and (b) a closure note that the nvim email/ extension consumes to refresh its
wrapper-contracts.md and close its Phase 6.
**Started**: 2026-07-04T21:15:00Z
**Completed**: 2026-07-04T22:05:00Z
**Effort**: Small (verification-only; no code changes)
**Dependencies**: task 79 (`email_wrappers_multi_account`, COMPLETED)
**Sources/Inputs**: `specs/079_email_wrappers_multi_account/reports/03_nvim-extension-followup-handoff.md`
(the contract table), `specs/079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md`
(prior live-confirmed Logos folder tokens), `modules/home/email/agent-tools.nix` (landed
wrapper source, full read), `modules/home/email/mbsync.nix` (full read), `.claude/hooks/mail-guard.sh`,
live read-only/dry-run wrapper invocations against the real switched-in system (`email-census`,
`email-classify`, `email-archive-confirmed`, `email-delete-confirmed` — all non-`--execute`),
live `notmuch count` probes, `git log`/`git diff` across the task-79 commit range.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **All 9 contract rows PASS. No divergence found.** The task-79 implementation landed exactly
  as report-02 recommended: `--account <gmail|logos>` (default `gmail`), unknown accounts
  rejected with an actionable error, Gmail tokens byte-identical to pre-task-79, Logos tokens
  are `folder:Logos` (INBOX) / `folder:Logos/.Archive` with no `.All_Mail`/`.Spam`, real Logos
  folders are exactly `.Sent`/`.Archive`/`.Drafts`/`.Trash`, `folder:` scoping is exclusive
  (`tag:logos`/`tag:gmail` both live-confirmed `0`), mbsync channels are per-account
  (`gmail`/`logos`, never `-a`), and zero new binaries were added (`mail-guard.sh` diff across
  the entire task-79 commit range `fcb5748^..9b58578` is empty).
- Live `email-census --account logos` returns real, non-zero counts: INBOX 62, Sent 12,
  Archive 54, Trash 1764, Drafts 10 — matching report-02's prior probe exactly (mail arrived
  since: 2023 bucket now shows 1 vs 0 before, immaterial to the contract).
- The read-only/dry-run exercise sequence for `/email --logos` is fully proven end-to-end in
  this pass: `email-census --account logos` -> `email-classify --account logos --limit 2`
  (real live tag-only classify against 2 Logos messages, succeeded) -> a hand-built tiny
  approved manifest fed to `email-archive-confirmed --account logos` and
  `email-delete-confirmed --account logos` in dry-run (no `--execute`), both correctly resolved
  the test message's envelope in `INBOX` and planned a move to `Archive` / a move-to-`Trash`
  respectively. This is the exact command sequence the implement phase should replay for the
  `--logos` exercise.
- **The nvim `/email --logos` precondition gate now PASSES.** The closure note (Finding 4 below)
  is ready to be handed to the nvim side to refresh `wrapper-contracts.md` §2/§11.
- No blockers. No divergence to report. This is a clean confirmation pass.

## Context & Scope

This is a **read-only verification** pass over the already-completed task 79. No code was
changed. All wrapper invocations in this research were either genuinely read-only
(`email-census`, `notmuch count`) or safely bounded: the one `email-classify` invocation is
the wrapper's own "local-tags-only" safety class (never touches IMAP/maildir, only notmuch
tags + a candidate manifest file — explicitly sanctioned by the task's goal 3), and the two
mutation-binary invocations (`email-archive-confirmed`, `email-delete-confirmed`) were run
**without** `--execute`/`--confirm-manifest`, using a hand-built, temporary approved manifest
that was deleted immediately after the dry-run confirmed scoping (per report-02's own
recommended verification approach in its Finding 7.3). The transient
`candidate-manifest.jsonl` produced by the classify run was also removed afterward, consistent
with `manifests/README.md`'s "no live manifests are committed" convention; the two notmuch
`+proposed-unsure` tags applied by the classify run were left in place as normal, expected
side effects of running that binary (the tagging **is** the binary's documented function, not
an incidental mutation).

## Findings

### 1. Contract rows 1-9 (report-03 §2) — verdicts

| # | Assumption | Verdict | Evidence |
|---|------------|---------|----------|
| 1 | Every wrapper accepts `--account <gmail\|logos>` | **PASS** | `agent-tools.nix:59` help text `--account <gmail\|logos> Account to operate on (default: gmail)`; flag parse at `agent-tools.nix:71-72` (`--account`/`--account=*`) inside `mkPreamble`, interpolated into all 5 binaries. Live: all five `--help` outputs (this session) show the identical line verbatim. |
| 2 | Default account when `--account` omitted is `gmail` | **PASS** | `agent-tools.nix:48` `ACCOUNT="gmail"`. Live: bare `email-census` (no `--account`) printed `=== email-census (account: gmail) ===` with the original 6-line Gmail folder block (INBOX 3382, All_Mail 65550, Sent 26019, Trash 55, Spam 0, Drafts 44). |
| 3 | Unknown account rejected with actionable error, never coerced | **PASS** | `agent-tools.nix:94-98`, the `case ... *)` fallthrough: `log "ERROR: --account only accepts 'gmail' or 'logos' (got: '$ACCOUNT')"`, `exit 1`. Live: `email-census --account work 2>&1` -> `[email-census] ERROR: --account only accepts 'gmail' or 'logos' (got: 'work')` / `[email-census] See wrapper-contract.md for the supported account set.`, exit code 1. |
| 4 | Gmail scope tokens unchanged: inbox `folder:Gmail`, archive `folder:Gmail/.All_Mail` | **PASS** | `agent-tools.nix:83-86` (`ACCOUNT_FOLDER="Gmail"`, `ACCOUNT_ARCHIVE_FOLDER="All_Mail"`); census block `agent-tools.nix:329-334` still literally queries `folder:Gmail/.All_Mail` etc. Live bare-`email-census` output matches report-02's pre-task-79 shape exactly (byte-for-byte structure, same 6 rows). |
| 5 | Logos scope tokens: inbox `folder:Logos`, archive `folder:Logos/.Archive`; **no `.All_Mail`/`.Spam`** | **PASS** | `agent-tools.nix:88-92` (`ACCOUNT_FOLDER="Logos"`, `ACCOUNT_ARCHIVE_FOLDER="Archive"`); census block `agent-tools.nix:336-341` queries only `Sent`/`Archive`/`Trash`/`Drafts` under `folder:Logos/.*` — no `All_Mail`/`Spam` lines exist in the Logos case branch at all. Live `email-census --account logos` printed exactly `INBOX/Sent/Archive/Trash/Drafts` — 5 rows, no All_Mail/Spam row. |
| 6 | Logos real folders are `.Sent`/`.Archive`/`.Drafts`/`.Trash` only | **PASS** | Matches report-02 Finding 2 (live-confirmed non-dot siblings are stray/empty, re-confirmed not re-tested this session since report-02's probe is definitive and structural, per its own Risk mitigation). Live census counts this session (62/12/54/10/1764) are consistent with those four real folders plus root-INBOX. |
| 7 | `folder:` scoping exclusive; `tag:logos`/`tag:gmail` inert | **PASS** | `agent-tools.nix:383` (`email-classify` `QUERY="folder:$ACCOUNT_FOLDER"`), `:543` (`email-unsubscribe-extract` same pattern), census `:327`/`:352` (`folder:$ACCOUNT_FOLDER`) — every query is `folder:`-scoped, no `tag:$ACCOUNT` construct anywhere in the file. Live: `notmuch count tag:logos` = `0`, `notmuch count tag:gmail` = `0` (re-confirmed this session, matching report-02). |
| 8 | mbsync channels per-account, never `mbsync -a` | **PASS** | `agent-tools.nix:85,91` (`ACCOUNT_MBSYNC_GROUP="gmail"`/`"logos"`), `:286` (`mbsync "$ACCOUNT_MBSYNC_GROUP"` inside `run_mbsync_reconcile`), `:282-283` comment explicitly warns against `mbsync -a`. `mbsync.nix:114-119` (`Group gmail` with 5 gmail-* channels) and `:190-197` (`Group logos` with 7 logos-* channels) confirm the two named, disjoint groups exist and match the resolver's literals exactly. No live mbsync invocation was run in this pass (out of scope for a read-only verification; census/classify/dry-run mutation never call `run_mbsync_reconcile` — only an `--execute` mutation with `executed_any=1` would). |
| 9 | No new binaries added | **PASS** | Live `which email-census email-classify email-archive-confirmed email-delete-confirmed email-unsubscribe-extract` resolves all 5 to `~/.nix-profile/bin/`, no 6th binary. `.claude/hooks/mail-guard.sh:23-27` allowlists exactly these 5 names. `git diff fcb5748^ 9b58578 -- .claude/hooks/mail-guard.sh` (the full task-79 commit range) is **empty** — confirmed unchanged, matching report-02's prediction. |

**Exact flag spelling shipped**: `--account <gmail|logos>` (and its `=`-form `--account=<value>`),
verified verbatim in all five `--help` outputs this session. No drift from what report-03 assumed.

**Headline**: zero divergence across all 9 rows. The cross-repo handshake (report-03 §5's
stated single most important deliverable) is confirmed clean.

### 2. Live Logos probe (for exercise-output prediction)

```
$ email-census --account logos
=== email-census (account: logos) ===
--- Folder counts ---
INBOX      62
Sent       12
Archive    54
Trash      1764
Drafts     10
--- Date bucket counts (INBOX, by year) ---
2022       5
2023       1
(rest of the 5-year window: 0)
```

```
$ email-census                     # bare, default gmail — confirms unchanged default path
=== email-census (account: gmail) ===
--- Folder counts ---
INBOX      3382
All_Mail   65550
Sent       26019
Trash      55
Spam       0
Drafts     44
```

Both outputs match report-02's prior probe (62/12/54/10/1764 for Logos) with only immaterial
drift (a couple of newly-arrived Logos messages landing in the historical date-bucket rows,
not the folder-count rows the plan will assert against). **Non-empty Logos folders for the
exercise**: INBOX, Sent, Archive, Drafts, Trash — all five are non-empty; Trash is by far the
largest (1764).

### 3. Proven read-only/dry-run exercise sequence for `/email --logos`

This exact sequence was executed live this session and is ready to be replayed (or scripted)
by the implement phase:

1. **Census**: `email-census --account logos` — read-only, no dry-run concept needed (safety
   class `read-only`). Confirms folder counts (Finding 2 above).
2. **Classify (read/tag-only)**: `email-classify --account logos --limit 2` — safety class
   `local-tags-only`; **not gated by `--execute`** (that gate only exists on the two mutation
   binaries). It queries `folder:Logos` by default (confirmed: `[email-classify] NOTE: query
   matched 62 message(s); processing the first 2`), writes `candidate-manifest.jsonl`, and
   applies `+proposed-{action}` notmuch tags. It never touches IMAP/maildir. Live output:
   `Classified 2 message(s); candidate manifest: .../candidate-manifest.jsonl` /
   `Candidates are NOT approved — mutation wrappers never consume ... (contract §6)`.
3. **Mutation dry-run (scoping proof, no `--execute`)**: mutation binaries require an
   *approved* manifest file to even dry-run (they check `[ -f "$MANIFEST_FILE" ]` before the
   `--execute` branch) — invoking them with no approved manifest present correctly errors
   `approved manifest not found` (live-confirmed both binaries do this identically). To
   actually exercise scoping, a tiny hand-built approved manifest is required (report-02's own
   recommended approach, Finding 7.3): one JSONL line with a real Logos `message_id` and
   `proposed_action: "archive"` (or `"delete"`), written to
   `specs/072_email_workflow_infrastructure_prereqs/manifests/approved-manifest.jsonl`. Then:
   - `email-archive-confirmed --account logos` (no `--execute`) -> live output:
     `DRY-RUN (pass --execute --confirm-manifest <sha256> to mutate)` then
     `PLAN: move <message-id> (envelope 885 in INBOX) -> Archive` — **proves** `folder:Logos`
     resolution (envelope found in `INBOX`) and `folder:Logos/.Archive` targeting (`-> Archive`,
     not `All_Mail`) both resolve correctly.
   - `email-delete-confirmed --account logos` (no `--execute`, manifest's action changed to
     `"delete"`) -> live output: `PLAN: move-to-Trash <message-id> (envelope 885 in INBOX)` —
     proves the two-hop delete's hop-1 planning also resolves the Logos envelope/folder
     correctly.
   - **Cleanup discipline**: the hand-built `approved-manifest.jsonl` (and any
     `.state.jsonl`/`.expunge-state.jsonl` companions) must be deleted after the dry-run test,
     since `manifests/README.md` states no live manifests are committed and dry-run testing
     must not leave stray approved-manifest state for a future real `--execute` run to
     accidentally pick up. This was done in this session (verified via `git status --porcelain`
     showing a clean `manifests/` dir afterward).
4. **What proves scoping is correct**: the `(envelope N in INBOX)` / `-> Archive` /
   `move-to-Trash` text in the PLAN lines is the load-bearing signal — it shows
   `resolve_envelope_id`/`resolve_folder_from_path` correctly stripped the `/Mail/Logos/`
   marker (not `/Mail/Gmail/`) and that `$ACCOUNT_ARCHIVE_FOLDER` resolved to `Archive` (not
   `All_Mail`). No mbsync/himalaya IMAP call happens in dry-run mode (only in the `[ "$EXECUTE"
   -eq 1 ]` branch), so this is fully safe to run against production Logos mail as many times
   as needed.

### 4. What the nvim closure note must contain

The following is ready to hand to the nvim side (`~/.config/nvim`) to refresh
`.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` §2/§11. (Per
task scope, no nvim-repo file was edited by this task — this is the content only.)

- **Confirmed `--account` enum**: `gmail` (default) | `logos`, flag spelling exactly
  `--account <value>` / `--account=<value>`, unchanged from what nvim assumed.
- **Per-account folder-token table**:

  | Account | Inbox query | Archive query | Real folders |
  |---------|-------------|----------------|---------------|
  | gmail | `folder:Gmail` | `folder:Gmail/.All_Mail` | `.All_Mail`, `.Sent`, `.Trash`, `.Spam`, `.Drafts` |
  | logos | `folder:Logos` | `folder:Logos/.Archive` | `.Sent`, `.Archive`, `.Drafts`, `.Trash` (no `.All_Mail`/`.Spam`) |

- **mbsync channel mapping**: `gmail` account -> `mbsync gmail` (Group `gmail`,
  `mbsync.nix:114-119`); `logos` account -> `mbsync logos` (Group `logos`, `mbsync.nix:190-197`).
  Never `mbsync -a` in either code path (`agent-tools.nix:282-283`).
- **No-new-binaries fact**: the same 5 binaries (`email-census`, `email-classify`,
  `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract`) as before
  task 79; `mail-guard.sh` needed no change (empty diff across the full task-79 commit range).
- **Rows 1-9 results**: all PASS, zero divergence (Finding 1 table above — safe to copy
  verbatim into wrapper-contracts.md).
- **Precondition gate status**: **now PASSES.** The wrappers are switched in
  (`~/.nix-profile/bin/email-census` shows the real `--account <gmail|logos>` enum, not the old
  reserved-gmail-only text), rows 1-9 are confirmed against live behavior, and a live
  census -> classify -> dry-run-mutation exercise against real Logos mail succeeded end-to-end
  with correct folder scoping. The nvim-side Phase 6 checklist's first four items (switch
  confirmed, flag spelling confirmed, `/email --logos` exercised end-to-end, contract data
  ready) are all satisfiable from this report; only the fifth (actually editing
  `wrapper-contracts.md`) and the optional `archive-mode-risk.md` generalization remain, and
  those are nvim-repo-side edits out of this task's scope.

## Decisions

- Verification was performed entirely via already-allowlisted wrappers plus `notmuch count`
  and `which`/`git log`/`git diff` — no raw `himalaya`/`notmuch` mutation, no `--execute`, no
  `home-manager switch` (already confirmed applied per task precondition).
- A tiny hand-built approved manifest was used (then deleted) to prove mutation-binary
  scoping in dry-run mode, following report-02's own recommended verification approach rather
  than inventing a new method.
- The transient `candidate-manifest.jsonl` produced by the sanctioned `email-classify` live
  test was deleted afterward to respect `manifests/README.md`'s "no live manifests are
  committed" convention; the two `+proposed-unsure` notmuch tags applied to the classified
  Logos messages were left in place as the classify binary's normal, expected, and reversible
  (local-tags-only) output.

## Risks & Mitigations

- **None identified as blocking.** All 9 rows passed; there is no divergence requiring
  cross-repo reconciliation.
- **Minor/non-blocking observation**: `mbsync logos`/`mbsync gmail` reconcile behavior itself
  was not live-exercised in this pass (would require an actual `--execute` mutation with
  `executed_any=1`, which is correctly out of scope for a read-only verification task).
  Mitigation: this is inherent to the safety model (reconcile only fires after a real
  mutation) and is not something a dry-run-only verification pass can or should probe; the
  Bridge-availability risk noted in report-02 (Proton Bridge must be running for `mbsync
  logos` to succeed) remains an operational note for whenever a real `--execute` run happens,
  not a defect found here.

## Context Extension Recommendations

- None. No gaps in existing `.claude/context/` documentation were surfaced by this
  verification pass — the relevant conventions (wrapper contract, manifest lifecycle,
  mail-guard allowlist) are already fully documented in the `specs/072_.../handoffs/` and
  `specs/079_.../reports/` artifacts referenced throughout this report.

## Appendix

### Commands used (all read-only / dry-run; none executed a real mutation)

```bash
which email-census email-classify email-archive-confirmed email-delete-confirmed email-unsubscribe-extract
email-census --help ; email-classify --help ; email-archive-confirmed --help
email-delete-confirmed --help ; email-unsubscribe-extract --help
email-census --account work 2>&1                 # unknown-account rejection (exit 1)
notmuch count tag:logos ; notmuch count tag:gmail  # both 0 (inert)
email-census                                      # bare, default gmail
email-census --account logos                      # Logos folder counts
email-classify --account logos --limit 2          # live read/tag-only classify (2 msgs)
notmuch search --output=files "id:<mid>"          # located test message's folder (INBOX)
# hand-built tiny approved-manifest.jsonl (archive, then delete action) fed to:
email-archive-confirmed --account logos           # DRY-RUN, no --execute -> PLAN ... -> Archive
email-delete-confirmed --account logos            # DRY-RUN, no --execute -> PLAN move-to-Trash
# cleanup: rm approved-manifest.jsonl + candidate-manifest.jsonl (both untracked, non-committed)
git log --oneline -- .claude/hooks/mail-guard.sh  # empty (never touched)
git diff fcb5748^ 9b58578 -- .claude/hooks/mail-guard.sh  # empty (unchanged across task-79 range)
```

### References

- `specs/079_email_wrappers_multi_account/reports/03_nvim-extension-followup-handoff.md` §2
  (contract table), §4 (Phase-6 checklist), §5 (rows-1-9 framing).
- `specs/079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md` (prior design +
  live-confirmed Logos folder tokens, Finding 2, Finding 7 verification approach).
- `modules/home/email/agent-tools.nix:48,59,71-99,282-341,383,543` (resolver, census, classify,
  archive/delete mutation logic).
- `modules/home/email/mbsync.nix:114-119,190-197` (per-account mbsync groups).
- `.claude/hooks/mail-guard.sh:23-27` (binary allowlist, unchanged).
