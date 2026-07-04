# Implementation Summary: Task #79

- **Task**: 79 - Extend the five email agent wrapper binaries in `modules/home/email/agent-tools.nix` to support the Logos (Protonmail Bridge) account via real per-account branching (gmail default preserved)
- **Status**: [COMPLETED]
- **Started**: 2026-07-04T13:23:00-07:00
- **Completed**: 2026-07-04T13:45:00-07:00
- **Effort**: ~1 hour
- **Dependencies**: 72 (frozen wrapper contract + Logos backend scaffolding)
- **Artifacts**: plans/02_wrapper-multi-account.md, reports/02_wrapper-multi-account.md

## Overview

Task 79 lifted the frozen task-72 "Gmail-only" `--account` reservation in
`modules/home/email/agent-tools.nix` into a real two-value enum, `{gmail, logos}`, via a single
shared `case`-statement resolver in `mkPreamble`. All five wrapper binaries (`email-census`,
`email-classify`, `email-unsubscribe-extract`, `email-archive-confirmed`,
`email-delete-confirmed`) now branch on `$ACCOUNT` to scope notmuch `folder:` queries, the
maildir marker used for envelope-id resolution, the `mbsync` reconcile group, the archive move
target, and an explicit `himalaya -a "$ACCOUNT"` flag. `gmail` remains the first `case` branch
with values textually identical to the pre-task-79 hardcoded literals, so bare invocations (no
`--account` flag) are byte-for-byte unchanged — verified by diffing `email-census` stdout
against a pre-change capture from the currently-installed (pre-switch) binary.

## What Changed

- `modules/home/email/agent-tools.nix`:
  - `mkPreamble`: replaced the hard-reject `if [ "$ACCOUNT" != "gmail" ]` gate with a
    `case "$ACCOUNT" in gmail|logos|*)` resolver setting `ACCOUNT_FOLDER`,
    `ACCOUNT_MAILDIR_MARKER`, `ACCOUNT_MBSYNC_GROUP`, `ACCOUNT_ARCHIVE_FOLDER`, plus
    `HIMALAYA_ACCT=(-a "$ACCOUNT")`; updated `--account` help text.
  - `email-census`: account-aware header, folder-count block (Gmail's original 6-line block
    preserved verbatim in a `gmail)` branch; new `logos)` branch prints the real, live-confirmed
    Logos folder set — INBOX/Sent/Archive/Drafts/Trash, no All_Mail/Spam), date-bucket loop, and
    himalaya sample now scoped by `$ACCOUNT_FOLDER`/`$HIMALAYA_ACCT`.
  - `email-classify` / `email-unsubscribe-extract`: default `QUERY` now `folder:$ACCOUNT_FOLDER`;
    help text generalized to name "the account's INBOX".
  - `resolve_folder_from_path`: maildir marker strip now uses `$ACCOUNT_MAILDIR_MARKER` instead
    of the hardcoded `/Mail/Gmail/`.
  - `resolve_envelope_id`: all `himalaya envelope list`/`message read` calls now carry
    `"${HIMALAYA_ACCT[@]}"`.
  - `run_mbsync_reconcile`: `mbsync gmail` literal replaced with `mbsync "$ACCOUNT_MBSYNC_GROUP"`;
    log strings interpolate the group name; the stale "deferred Logos/Bridge account" phrasing
    was reworded (the `never mbsync -a` invariant itself is untouched and still enforced — the
    resolver only ever supplies a single group name to a group-scoped `mbsync` call).
  - `email-archive-confirmed`: hardcoded `All_Mail` move target replaced with
    `$ACCOUNT_ARCHIVE_FOLDER` (comment, log lines, and the `himalaya message move` call, which
    also now carries `$HIMALAYA_ACCT`).
  - `email-delete-confirmed`: `$HIMALAYA_ACCT` spliced into both delete hops and the
    `folder expunge Trash` call; no folder-name parameterization needed (`Trash` is real and
    identically named on both accounts).
  - File header comment (lines 1-16) and the `mkPreamble` section comment updated to describe
    `--account` as a real `{gmail, logos}` enum and cite the live-confirmed Logos folder mapping.
  - The pre-existing uncommitted `CUSTOM_KEEP_SENDERS` hand-edit (Proton keep-list addresses) was
    left untouched, as required.
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`: added a new
  §11 addendum documenting that `--account` is now a real `{gmail, logos}` enum (superseding
  §2/§10's single-value framing), the resolver mechanism, the live-confirmed Logos folder set,
  the "extend one case statement" path for a future third account, and the manual-step caveat
  for live Logos mutation.

## Decisions

- **Contract revision**: the task-72 `wrapper-contract.md` froze `--account gmail` as a
  reserved, single-valued flag ("Protonmail/Logos are out of scope... reserved for future
  multi-account support"). Task 79 is the anticipated follow-on: `--account` is now a real,
  extensible enum. Extending to a third account means adding one `case` branch plus that
  account's backend prerequisites (mbsync `IMAPAccount`/`Group`, notmuch tag rule, maildir
  dirs, himalaya account, aerc account) — not a wrapper rewrite.
- Account scoping is exclusively `folder:`-based, never `tag:<account>` (the notmuch `postNew`
  account-tag hook has never actually populated tags in the live database — a pre-existing,
  out-of-scope `notmuch.nix` gap).
- `himalaya -a "$ACCOUNT"` is now passed explicitly on every himalaya call for **both** accounts
  (not just Logos), for symmetry and to avoid relying on himalaya's own config-level default
  account.
- Manifests remain shared across accounts (no per-account manifest directories), per the plan's
  explicit non-goal; the operator must invoke mutation binaries with the same `--account` value
  used to classify a given manifest's rows.

## Impacts

- `email-census --account logos`, `email-classify --account logos`, and
  `email-unsubscribe-extract --account logos` are now real, working read-only operations against
  the live Logos/Proton mailbox (dry-run classify verified: 62 INBOX messages, 5 classified in a
  smoke test).
- `email-archive-confirmed --account logos` and `email-delete-confirmed --account logos` are
  wired to the correct folders (`Archive`, `Trash`) and account flag, but were exercised only in
  dry-run form here — no `--execute` was run against Logos.
- The out-of-scope nvim `email/` extension multi-account UX (tracked separately, see
  `reports/01_nvim-extension-handoff.md`) can now proceed once this task's `home-manager switch`
  manual step lands.

## Follow-ups

- **Manual user step (not run by this implementation)**: `home-manager switch --flake .#benjamin`
  to activate the new wrapper binaries on `$PATH`, followed by a live `--execute` test against
  real Logos mail (requires the Protonmail Bridge service on `127.0.0.1:1143`).
- Separately-owned nvim extension multi-account UX work (out of scope here).
- The inert notmuch `postNew` account-tag hook (`notmuch.nix`) remains an open, unrelated gap.

## Verification

- `home-manager build --flake .#benjamin`: succeeded after every phase and on the final
  Phase-4 re-check (nix module evaluates cleanly; no bash-in-nix interpolation/quoting errors).
- Gmail regression: bare `email-census` stdout from a freshly built binary diffed byte-for-byte
  identical against a captured pre-task-79 baseline (the still-installed pre-switch binary).
- Logos dry-run smoke: `email-census --account logos` printed the five-row Logos folder set
  (INBOX 62 / Sent 12 / Archive 54 / Trash 1764 / Drafts 10) with live counts and a correctly
  Logos-scoped himalaya sample (subjects referencing "Logos Labs"/"logos-labs.ai"); a scratch-dir
  `email-classify --account logos --limit 5` run classified 5 real Logos messages against
  `folder:Logos` without touching IMAP/maildir.
- Unknown-account rejection: `email-census --account bogus` exited 1 with the actionable
  `case ... *)` error.
- `CUSTOM_KEEP_SENDERS` hand-edit (the three Proton addresses) confirmed intact after all edits.
- No `--execute` mutation was run against Logos or Gmail during this implementation; live
  `home-manager switch` + real mutation testing is a manual user step (see Follow-ups).

## References

- `specs/079_email_wrappers_multi_account/plans/02_wrapper-multi-account.md`
- `specs/079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md`
- `modules/home/email/agent-tools.nix`
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`
