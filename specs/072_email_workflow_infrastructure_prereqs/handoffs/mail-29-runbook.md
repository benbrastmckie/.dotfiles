# ~/Mail #29 Runbook — Gmail Backlog Purge (Task 72, Phase 11)

**Date**: 2026-07-02
**Purpose**: Everything `~/Mail #29` (the actual Gmail backlog purge, run in its own repo/task)
needs to execute against the mechanism this task built. **Cross-repo ordering is
documentation-only** (Critic F6): nothing here is machine-enforced across repos; this document
is the shared source of truth by convention.

Task 72 did **NOT** run the purge and did **NOT** perform any bulk mail mutation. The only
live-mail operation performed during this task's own verification was the Phase 1
single-disposable-message test (recoverable from Gmail's 30-day Trash), plus a handful of
read-only/local-tag-only smoke tests during Phases 5–10 (cleaned up afterward).

---

## 1. Built binaries (on `$PATH` after `home-manager switch`)

`email-census`, `email-classify`, `email-unsubscribe-extract`, `email-archive-confirmed`,
`email-delete-confirmed` — see `handoffs/wrapper-contract.md` for the full frozen interface and
its as-built addendum (§10). `email-freeze` / `email-thaw` (operator helpers, not part of the
5-binary contract) are also on `$PATH` from `modules/home/email/mbsync.nix`.

**Precondition**: none of these exist until `home-manager switch --flake .#benjamin` activates
the generation that includes `modules/home/email/agent-tools.nix` and `mbsync.nix`. This task
only ran `home-manager build` (verification), never `switch` — #29 must switch before starting.

## 2. OAuth / auth status

Per `handoffs/oauth-gate.md` (Phase 3, user-confirmed decision, Option c): `mbsync` was switched
from XOAUTH2 to the existing `gmail-app-password` keyring credential. himalaya/aerc were already
on app-password. **Task 46 (Gmail OAuth2 Production verification) is downgraded from a #29
blocker to optional** — no CASA Tier 2 assessment is required for this purge.

**Server-side delete verification is UNBLOCKED** (per `verification-baseline.md` §6a addendum):
`mbsync gmail` authenticates successfully on app-password, and the Phase 1 disposable test
message's INBOX-label removal was confirmed to propagate server-side via direct IMAP SEARCH.
Full All-Mail removal (the expunge hop) was characterized but deliberately not executed on the
test message during Phase 1 (left for #29 or explicit interactive confirmation).

**Known pre-existing issue** (NOT caused by task 72, surfaced by the first full `mbsync gmail`
run): the `gmail-spam` channel fails because `[Gmail]/Spam` is `NONEXISTENT` over IMAP on this
account (Gmail's "Show in IMAP" setting). This makes `mbsync gmail` exit 1 even on an otherwise
clean sync. `run_mbsync_reconcile` (baked into both mutation wrappers and `email-thaw`)
distinguishes this from an auth failure and prints a pointer to this note rather than treating it
as a halt condition needing manifest preservation. Fix options (task-46/mbsync scope, #29's
call): enable Spam "Show in IMAP" in Gmail settings, or drop the `gmail-spam` channel from the
`mbsync.nix` group.

## 3. Freeze / thaw + SyncState recovery

Before any bulk operation, run `email-freeze`. It:
1. Refuses if a process named `mbsync` is currently running.
2. Prints the trigger-path guards: there is **no mbsync systemd timer** — the only trigger paths
   are notmuch's `preNew` hook (`mbsync -a`) and aerc's `$` keybind. While frozen, run
   `notmuch new --no-hooks` (never plain `notmuch new`) and do not press `$` in aerc.
3. Backs up every `~/Mail/Gmail/**/.mbsyncstate*` file to a timestamped tarball under
   `~/Mail/.syncstate-backups/`.

When ready to reconcile, run `email-thaw`. It runs a single group-scoped `mbsync gmail` (never
`-a`, which would also touch the deferred Logos/Bridge account) and applies the auth-failure
fail-safe (halts cleanly on `invalid_grant` or `[AUTHENTICATIONFAILED]`, preserving local
SyncState untouched).

**Interrupted-run recovery**: if a reconcile fails, restore the most recent
`~/Mail/.syncstate-backups/*.tar.gz` with `tar -xzf <backup>.tar.gz -C /` if local
`.mbsyncstate` files look suspect, fix auth, re-run `email-thaw`, then `notmuch new --no-hooks`
to reindex.

## 4. aerc review flow

Three new querymap views in `querymap-gmail`: `Proposed-Delete`, `Proposed-Archive`,
`Proposed-Unsure` (tag-scoped to `tag:proposed-{delete,archive,unsure} AND tag:gmail`).

Confirm gestures (folder-scoped keybinds, see `modules/home/email/aerc.nix`):
- `Proposed-Delete` view: `d` retags `+confirmed-delete -proposed-delete` and runs
  `email-classify --append-approved {{.MessageId}}`; `k` rescues to `+proposed-keep`.
- `Proposed-Archive` view: `a` retags `+confirmed-archive -proposed-archive` and appends;
  `k` rescues to `+proposed-keep`.
- `Proposed-Unsure` view: `d`/`a` resolve to confirmed-delete/confirmed-archive respectively
  (same append behavior); `k` rescues to `+proposed-keep`.

None of these gestures use aerc's native `:delete-message`/`:archive` — they only retag and
queue the Message-ID into the approved manifest via the wrapper. The actual mutation happens
later, out-of-band, via `email-archive-confirmed`/`email-delete-confirmed --execute
--confirm-manifest <sha256>`.

**Recorded decisions** (Phase 9, pre-decided and not re-litigated during implementation):
- Native `d`/`D`/`a`/`A` (outside the three Proposed-* views) are **KEPT as human-only paths**,
  explicitly outside the agent guardrail by design — the PreToolUse `mail-guard.sh` hook can
  only gate the Claude Code agent's own Bash tool calls, not aerc's Go worker. `D` (bare
  `:delete`, previously no confirmation) and `A` (bulk archive) are now `:prompt`-confirmed.
  `d`/`a` deliberately shadow the native single-delete/archive keys *only* within the three
  Proposed-* views, replacing them with the safe wrapper-routed gesture there.
- The `$` sync keybind was rebound from `:exec mbsync -a && notmuch new` to
  `:exec mbsync gmail && notmuch new --no-hooks` — the same freeze-blast-radius (`-a`) and
  index-corruption (`preNew` re-triggering `mbsync -a`) hazards applied to the old binding.

## 5. Manifest directory + approval provenance

Default location: `specs/072_email_workflow_infrastructure_prereqs/manifests/` (git-tracked;
override with `EMAIL_MANIFEST_DIR`). Files (see the directory's own `README.md`):
`candidate-manifest.jsonl` (never consumed by mutation wrappers), `approved-manifest.jsonl` (the
sole input to `--confirm-manifest`), `approved-manifest.jsonl.state.jsonl` (hop-1 execution
state), `approved-manifest.jsonl.expunge-state.jsonl` (delete's hop-2 execution state).

Approval provenance is exactly the aerc gesture above — `email-classify` never self-approves,
and mutation wrappers refuse to run without a manifest file that already carries `pending`
status semantics through the `.state.jsonl` companion.

## 6. Verified delete recipe (Phase 1 + as-built)

1. `himalaya message delete --folder <source> <id>` — moves to Trash (leaves flags `:2,S`, NOT
   `\Deleted`; a plain `folder expunge Trash` is a no-op on this).
2. `himalaya message delete --folder Trash <id>` — sets `\Deleted` on the now-in-Trash copy.
3. `himalaya folder expunge Trash` — removes `\Deleted`-flagged messages.
4. `mbsync gmail` (group-scoped) — pushes the removal server-side.

`email-delete-confirmed` implements steps 1 as its default `--execute` action and steps 2–3
together as `--execute --confirm-manifest ... --expunge-trash`; step 4 runs automatically after
either successful `--execute` batch via `run_mbsync_reconcile`.

**Recommended #29 batch discipline**: respect `MAX_BATCH_SIZE=50` (the wrappers refuse to
execute more than 50 IDs of a given action in one manifest — split larger batches), and
`PLAN_EXPIRY_DAYS=7` (re-approve via aerc if a manifest goes stale).

## 7. Memory-candidate breadcrumb (generic pattern, framework NOT built)

A reusable pattern emerged from this build worth a future generic
`confirmed-mutation-wrapper` primitive (dry-run default + sha256-confirmed manifest + PreToolUse
allowlist hook + execution-state companion file for idempotent replay). This is a breadcrumb for
a future task — task 72 deliberately did not build a generic framework, only this one
domain-specific instantiation.
