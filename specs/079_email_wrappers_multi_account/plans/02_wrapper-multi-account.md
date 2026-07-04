# Implementation Plan: Task #79

- **Task**: 79 - Extend the five email agent wrapper binaries in `modules/home/email/agent-tools.nix` to support the Logos (Protonmail Bridge) account via real per-account branching (gmail default preserved)
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: 72 (frozen wrapper contract + Logos backend scaffolding — already merged)
- **Research Inputs**: specs/079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md
- **Artifacts**: plans/02_wrapper-multi-account.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; nix.md
- **Type**: nix

## Overview

Task 79 lifts the frozen task-72 "Gmail-only" wrapper contract into a real per-account
dimension `{gmail, logos}` inside a single file, `modules/home/email/agent-tools.nix`. The
research report maps exactly 8 Gmail-hardcoded site clusters (13 line references) and prescribes
a single shared per-account resolver (`case "$ACCOUNT" in gmail|logos|*)`) in `mkPreamble` that
sets `ACCOUNT_FOLDER` / `ACCOUNT_MAILDIR_MARKER` / `ACCOUNT_MBSYNC_GROUP` / `ACCOUNT_ARCHIVE_FOLDER`
plus a `HIMALAYA_ACCT=(-a "$ACCOUNT")` array, then threads those resolved variables through the
read-only and mutation call sites. `gmail` stays the first `case` branch with byte-identical
literal values, so bare invocations (no `--account`) are behaviorally unchanged. Definition of
done: `home-manager build --flake .#benjamin` succeeds; `email-census --account logos` produces a
dry-run census against the real Logos folders; `email-census --account bogus` still rejects; bare
`email-census` output is byte-for-byte unchanged. Live mutation/switch is a manual user step; the
headless build is the automated gate.

### Research Integration

This plan is derived from `reports/02_wrapper-multi-account.md`. Key findings integrated:
- The 8 Gmail-hardcoded site clusters and their exact current line numbers (Finding 1 table).
- The concrete `case`-statement resolver design and per-site threading recipe (Finding 3).
- Live-confirmed Logos folder tokens: **INBOX (bare `folder:Logos`), Sent, Archive, Drafts,
  Trash** — no `All_Mail`, no `Spam` (Finding 2). Do NOT query the stray empty non-dot
  `~/Mail/Logos/{INBOX,Sent,Drafts,Trash,Archive}` subdirectories.
- Account scoping MUST key off `folder:` queries, never `tag:<account>` — the notmuch account
  tags are inert in the live database (Finding 2 / Executive Summary).
- Proton archive = move to `Archive`; delete = the existing account-agnostic two-hop
  (`message delete` -> Trash, `--expunge-trash` -> `folder expunge Trash`) (Finding 4).
- Safety invariants (`MAX_BATCH_SIZE=50`, `PLAN_EXPIRY_DAYS`, dry-run/`--execute`/
  `--confirm-manifest`, `never mbsync -a`, wrapper-only, no raw `rm`) are untouched (Finding 5).

### Prior Plan Reference

No prior plan for task 79 (this is round 02 following the round-02 research report; round 01 was
the out-of-scope nvim-extension handoff). The prior wrapper contract and verification convention
(`home-manager build --flake .#benjamin`) originate from task-72's
`plans/02_email-infra-wrappers.md`, cited by the research report.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch. This task is the enabling foundation for the
separately-owned nvim `email/` extension multi-account UX (out of scope, tracked in
`reports/01_nvim-extension-handoff.md`), which is hard-sequenced to depend on this task landing +
`home-manager switch` first.

## Goals & Non-Goals

**Goals**:
- Accept `--account logos` (and keep `gmail` as the default) via a shared per-account resolver in
  `mkPreamble`, still rejecting unknown accounts with an actionable error.
- Thread the resolved variables through every Gmail-hardcoded site so both accounts work: notmuch
  `folder:` scope, census folder set, maildir marker, `mbsync` group, himalaya `-a` flag, and
  archive move target.
- Keep the `gmail` branch's resolved values byte-identical to today's literals so bare
  invocations are behaviorally unchanged.
- Document that `--account` is now a real `{gmail, logos}` enum, superseding the task-72 frozen
  single-value reservation.
- `home-manager build --flake .#benjamin` succeeds.

**Non-Goals**:
- No changes to the nvim `email/` extension UX, `skill-email-cleanup`/`skill-email-sync`, command
  help in nvim, or `mail-guard.sh` (all out of scope — separate owner).
- No per-account manifest directories/files (manifests stay shared; out of scope per task).
- No fix to the inert notmuch `postNew` account-tag hook (a `notmuch.nix` issue, out of scope).
- No new safety mechanism or change to `MAX_BATCH_SIZE`, `PLAN_EXPIRY_DAYS`, the dry-run gate, or
  the `never mbsync -a` invariant.
- No revert of the uncommitted `CUSTOM_KEEP_SENDERS` hand-edit (agent-tools.nix:401-404).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bash-in-nix quoting/interpolation error in the new `case` block or `HIMALAYA_ACCT` array splice (`''${HIMALAYA_ACCT[@]}` inside a nix `''` string) | M | M | The `home-manager build` in Phase 4 evaluates the whole module and catches interpolation mistakes before runtime; keep `''${...}` escaping consistent with existing array splices in the file. |
| Gmail default path subtly changes (breaks byte-for-byte invariant) | H | L | Keep `gmail` as the FIRST `case` branch with values textually identical to today's literals; Phase 4 diffs bare `email-census` stdout against a pre-change capture. |
| Referencing a Logos folder that does not exist locally (e.g. inventing `.All_Mail`/`.Spam`, or the stray empty non-dot subdirs) | M | M | Carry Finding 2's verified folder table forward verbatim; Logos census uses only INBOX/Sent/Archive/Drafts/Trash; implementer re-confirms via `notmuch search --output=folders folder:Logos` before hardcoding. |
| The uncommitted `CUSTOM_KEEP_SENDERS` hand-edit (401-404) gets clobbered while editing the surrounding `email-classify` function | M | L | The classify body edits in Phase 2 touch only lines 334/344 (help + QUERY), far from 401-404; do not `git checkout`/revert the file; verify the three Proton addresses remain after edits. |
| Proton/Bridge down at manual `--execute` time (`mbsync logos` refused) | L | M | Out of automated scope — dry-run census/classify never touch Bridge; the existing generic non-auth-failure branch surfaces the raw error; documented as a manual-step caveat, no code change. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Per-account resolver + relaxed gate in mkPreamble [COMPLETED]

- **Goal:** Introduce the shared per-account resolver and the `HIMALAYA_ACCT` array, and relax the
  hard-reject gate to accept `gmail|logos` while still rejecting unknowns — with `gmail`'s resolved
  values byte-identical to today's hardcoded literals. This is the foundation every later phase
  consumes.
- **Tasks:**
  - [x] In `mkPreamble` (agent-tools.nix), replace the hard-reject block at **lines 70-74**
        (`if [ "$ACCOUNT" != "gmail" ]; then ... exit 1; fi`) with the `case "$ACCOUNT" in`
        resolver from research Finding 3: `gmail)` sets `ACCOUNT_FOLDER="Gmail"`,
        `ACCOUNT_MAILDIR_MARKER="/Mail/Gmail/"`, `ACCOUNT_MBSYNC_GROUP="gmail"`,
        `ACCOUNT_ARCHIVE_FOLDER="All_Mail"`; `logos)` sets `ACCOUNT_FOLDER="Logos"`,
        `ACCOUNT_MAILDIR_MARKER="/Mail/Logos/"`, `ACCOUNT_MBSYNC_GROUP="logos"`,
        `ACCOUNT_ARCHIVE_FOLDER="Archive"`; `*)` logs an actionable error naming the supported set
        and `exit 1`. Keep `gmail` as the FIRST branch.
  - [x] Immediately after the `esac`, add `HIMALAYA_ACCT=(-a "$ACCOUNT")` (mind the nix `''`
        escaping used by the surrounding array code).
  - [x] Leave `ACCOUNT="gmail"` default (line 37), `MAX_BATCH_SIZE`/`PLAN_EXPIRY_DAYS` (34-35),
        the flag-parse loop (57-68), and `mkdir -p "$MANIFEST_DIR"` (76) unchanged; the resolver
        is inserted between the flag loop's end and the `mkdir` (the ACCOUNT value is already
        finalized by then).
  - [x] Update the help text at **line 48** from `--account <gmail>  Reserved; only "gmail" is
        accepted` to `--account <gmail|logos>  Account to operate on (default: gmail)`.
- **Timing:** ~45 min
- **Depends on:** none
- **Files to modify:**
  - `modules/home/email/agent-tools.nix` — lines 48 (help), 70-74 (gate -> resolver + array).
- **Verification:**
  - `home-manager build --flake .#benjamin` succeeds (module evaluates; no bash/nix quoting error).
  - Grep the built/derived script or re-read the edited region to confirm the `case` has `gmail`
    first with the four byte-identical Gmail literals and `HIMALAYA_ACCT` is defined.

### Phase 2: Thread resolver through read-only paths [COMPLETED]

- **Goal:** Make the three read-only binaries (`email-census`, `email-classify`,
  `email-unsubscribe-extract`) account-aware by consuming `ACCOUNT_FOLDER` / `HIMALAYA_ACCT`,
  giving Logos its real, verified folder set while keeping the Gmail branch byte-identical.
- **Tasks:**
  - [x] `email-census` header line **295**: change `echo "=== email-census (account: gmail) ==="`
        to interpolate `$ACCOUNT`.
  - [x] `email-census` folder-count block **lines 298-303**: replace the fixed 6-line Gmail list
        with the per-account form from research Finding 3 — an `INBOX` row using
        `notmuch count "folder:$ACCOUNT_FOLDER"`, then a `case "$ACCOUNT"` printing the Gmail set
        (`All_Mail`/`Sent`/`Trash`/`Spam`/`Drafts` via the exact existing literal queries — Gmail
        branch byte-identical) vs the Logos set (`Sent`/`Archive`/`Trash`/`Drafts` via
        `folder:Logos/.Sent`, `folder:Logos/.Archive`, `folder:Logos/.Trash`,
        `folder:Logos/.Drafts`). No `All_Mail`/`Spam` rows for Logos.
  - [x] `email-census` date-bucket loop **line 313**: change `folder:Gmail and date:...` to
        `folder:$ACCOUNT_FOLDER and date:...` (rest of the loop is already generic).
  - [x] `email-census` himalaya sample **line 319**: splice `"''${HIMALAYA_ACCT[@]}"` into
        `himalaya envelope list ... -f INBOX -o json -s 10` so the sample is account-scoped.
  - [x] `email-classify` default query **line 344**: change `QUERY="folder:Gmail"` to
        `QUERY="folder:$ACCOUNT_FOLDER"`; update the help default at **line 334** to name the
        account's INBOX generically (e.g. `default: "folder:<Account>" = INBOX`).
  - [x] `email-unsubscribe-extract` default query **line 504**: change `QUERY="folder:Gmail"` to
        `QUERY="folder:$ACCOUNT_FOLDER"`; update the help default at **line 495** likewise.
  - [x] Do NOT touch the `CUSTOM_DELETE_DOMAINS`/`CUSTOM_KEEP_SENDERS` tables (lines 396-404),
        preserving the uncommitted 401-404 hand-edit verbatim.
- **Timing:** ~50 min
- **Depends on:** 1
- **Files to modify:**
  - `modules/home/email/agent-tools.nix` — lines 295, 298-303, 313, 319 (census); 334, 344
    (classify); 495, 504 (unsubscribe-extract).
- **Verification:**
  - `home-manager build --flake .#benjamin` succeeds.
  - Re-read the census block to confirm the Gmail `case` branch reproduces the original 6 literal
    queries exactly, and the Logos branch uses only the five verified folders (no `.All_Mail`/
    `.Spam`).
  - Confirm lines 401-404 still contain `noae@protonmail.com`, `rob.mckie1235@proton.me`,
    `andy.stace@protonmail.com`.

### Phase 3: Thread resolver through the mutation preamble and mutation binaries [NOT STARTED]

- **Goal:** Make the shared mutation infrastructure (`resolve_folder_from_path`,
  `resolve_envelope_id`, `run_mbsync_reconcile`) and the two mutation binaries
  (`email-archive-confirmed`, `email-delete-confirmed`) account-aware, preserving every frozen
  safety invariant untouched.
- **Tasks:**
  - [ ] `resolve_folder_from_path` **line 175**: change the hardcoded marker
        `local rel="''${filepath#*/Mail/Gmail/}"` to use the resolver variable
        `local rel="''${filepath#*$ACCOUNT_MAILDIR_MARKER}"`. The rest of the function
        (`cur|new|tmp -> INBOX`, `.*` strip, fallback) is already account-agnostic — no change.
  - [ ] `resolve_envelope_id` himalaya calls **lines 204, 207, 212**: splice
        `"''${HIMALAYA_ACCT[@]}"` into each `himalaya envelope list ...` and
        `himalaya message read ...` invocation so resolution runs against the correct account.
  - [ ] `run_mbsync_reconcile` **lines 255-277**: parameterize the literal group — change
        `out=$(mbsync gmail 2>&1)` (line 259) to `out=$(mbsync "$ACCOUNT_MBSYNC_GROUP" 2>&1)`;
        interpolate `$ACCOUNT_MBSYNC_GROUP` in the log strings that name "gmail" (lines 255, 268,
        271, 277). **Keep the `never mbsync -a` comment verbatim** — it remains true and important
        for both accounts; reword the stale "deferred Logos/Bridge account" phrasing in the
        255-256 comment (Logos is no longer deferred, just still isolated by the group-scoped call)
        — but see Phase 4 for the authoritative contract-doc rewording; a minimal in-line reword
        here is acceptable.
  - [ ] `email-archive-confirmed` **lines 549, 582, 585, 586**: replace the hardcoded `All_Mail`
        move target with `$ACCOUNT_ARCHIVE_FOLDER` in the comment (549), the two log lines
        (582, 585), and the call `himalaya message move All_Mail ...` (586); splice
        `"''${HIMALAYA_ACCT[@]}"` into that `himalaya message move` call. Gmail resolves to
        `All_Mail` (unchanged), Logos to `Archive`.
  - [ ] `email-delete-confirmed` **lines 669, 701, 712**: splice `"''${HIMALAYA_ACCT[@]}"` into the
        hop-1 `himalaya message delete ... -f "$RESOLVED_FOLDER"` (669), the hop-2
        `himalaya message delete ... -f Trash` (701), and `himalaya folder expunge Trash` (712).
        No folder-name parameterization needed: `Trash` is a real, identically-named folder for
        both accounts (Finding 4).
  - [ ] Leave the dry-run gate, `--execute`/`--confirm-manifest` verification, `MAX_BATCH_SIZE`
        enforcement, `PLAN_EXPIRY_DAYS`/mtime check, `MANIFEST_DIR`/`STATE_FILE` resolution, and
        the `is_mbsync_auth_failure` matcher entirely unchanged.
- **Timing:** ~55 min
- **Depends on:** 1
- **Files to modify:**
  - `modules/home/email/agent-tools.nix` — lines 175, 204, 207, 212 (resolve helpers); 255-277
    (mbsync reconcile); 549, 582, 585, 586 (archive); 669, 701, 712 (delete).
- **Verification:**
  - `home-manager build --flake .#benjamin` succeeds.
  - Re-read the mbsync reconcile block to confirm no code path constructs `mbsync -a` and the
    group is `$ACCOUNT_MBSYNC_GROUP`.
  - Confirm the archive move resolves to `All_Mail` for gmail and `Archive` for logos, and every
    himalaya call in the mutation preamble/binaries now carries `"''${HIMALAYA_ACCT[@]}"`.

### Phase 4: Contract-revision note + final verification [NOT STARTED]

- **Goal:** Document that the `--account` reservation is now a real `{gmail, logos}` dimension, and
  run the full automated verification gate.
- **Tasks:**
  - [ ] Update the in-file header comment block **lines 1-16** to note that `--account` now accepts
        a real second value (`logos`), superseding the "Logos/Bridge is deferred" framing; cite
        the new Logos maildir folder mapping (INBOX bare-root/Sent/Archive/Drafts/Trash) as
        verified against the live system alongside the existing Gmail note (lines 12-14).
  - [ ] Reword the `mkPreamble` comment at **lines 22-23** if it still frames `--account gmail` as
        a single-value reservation.
  - [ ] Add a short addendum to task-72's `wrapper-contract.md`
        (`specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`, the frozen
        contract the research report identifies) stating: the `--account` dimension is now a real
        enum `{gmail, logos}` rather than a frozen single literal; adding a third account means
        extending exactly the one `case` statement introduced here plus the account's backend
        prerequisites (mbsync IMAPAccount + Group, notmuch tag rule, maildir dirs, himalaya
        account, aerc account). Frame the "foundation for future multi-account" concretely as
        "extend one case statement," not "rewrite the wrappers."
  - [ ] Run the full verification suite (see Testing & Validation).
- **Timing:** ~40 min
- **Depends on:** 1, 2, 3
- **Files to modify:**
  - `modules/home/email/agent-tools.nix` — lines 1-16 (header), 22-23 (preamble comment).
  - `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` — contract
    addendum.
- **Verification:**
  - `home-manager build --flake .#benjamin` succeeds (authoritative automated gate).
  - `email-census --account logos` prints the five-row Logos folder set
    (INBOX/Sent/Archive/Drafts/Trash — no All_Mail/Spam) with live counts (dry-run, read-only).
  - `email-census --account bogus` (or any third value) exits 1 with the actionable error.
  - Bare `email-census` (Gmail default) output is byte-for-byte unchanged vs a pre-change capture.

## Testing & Validation

- [ ] `home-manager build --flake .#benjamin` succeeds after each phase and finally (evaluates the
      whole module; catches bash-in-nix interpolation/quoting mistakes in the `case` block and
      `HIMALAYA_ACCT` splices).
- [ ] Gmail regression: bare `email-census` (no `--account`) output diffs clean against a
      pre-change capture — six census lines, himalaya sample, and date-bucket loop unchanged.
- [ ] Logos dry-run smoke: `email-census --account logos` prints the five-row Logos folder set
      with live counts; `email-classify --account logos --limit 5` classifies against
      `folder:Logos` (dry-run, local-tags-only; safe to run — never touches IMAP/maildir).
- [ ] Unknown-account rejection: `email-census --account bogus` exits 1 with an actionable error.
- [ ] `CUSTOM_KEEP_SENDERS` hand-edit (agent-tools.nix:401-404) preserved verbatim after all edits.
- [ ] Manual-only (NOT part of the automated gate; performed by the user): any `--execute`
      mutation + `mbsync logos` reconcile against real Logos mail, requiring the Protonmail Bridge
      service running on 127.0.0.1:1143.

## Artifacts & Outputs

- `modules/home/email/agent-tools.nix` — the branched five-wrapper implementation (single-file
  change).
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` — contract
  addendum recording the `{gmail, logos}` enum revision.
- `specs/079_email_wrappers_multi_account/plans/02_wrapper-multi-account.md` — this plan.
- `specs/079_email_wrappers_multi_account/summaries/02_wrapper-multi-account-summary.md` — expected
  implementation summary (produced at /implement time), documenting the contract revision.

## Rollback/Contingency

- The change is confined to one source file (`agent-tools.nix`) plus one doc addendum. If a phase
  fails verification, fix forward (correct the interpolation/query) rather than discarding
  uncommitted work — the working tree also holds the unrelated `CUSTOM_KEEP_SENDERS` hand-edit
  that must not be lost. Do NOT run `git checkout --`/`git restore`/`git reset --hard` against the
  dirty tree.
- If a deeper problem emerges, revert only the task-79 hunks in `agent-tools.nix` (the resolver
  block and the threaded call sites), leaving lines 401-404 intact; `gmail`'s byte-identical
  branch means reverting restores the exact pre-task-79 Gmail behavior.
- The design is additive and isolated: no backend infra, manifest schema, or safety-gate change is
  made, so no cross-file rollback is required.
