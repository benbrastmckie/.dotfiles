# Implementation Summary: Task #72

**Task**: 72 - Email workflow infrastructure prereqs (.dotfiles mechanism; child of task 71)
**Status**: [PARTIAL COMPLETION — Phases 5-11 of 11; Phases 1-4 completed by a prior dispatch]
**Started**: 2026-07-02T18:00:00-07:00
**Completed**: 2026-07-02T18:50:00-07:00
**Effort**: ~3 hours (this dispatch)
**Dependencies**: Task 46 (Gmail OAuth2) — downgraded from blocker to optional per the Phase 3
decision (app-password switch)
**Artifacts**: plans/02_email-infra-wrappers.md; this summary
**Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

This dispatch resumed task 72 at Phase 5 (Phases 1-4 were already complete and committed) and
executed Phases 5 through 11 to completion: five nix-declared agent wrapper binaries, a
PreToolUse allowlist hook, mbsync freeze/thaw operator helpers, an aerc review flow, notmuch
junk-rule scaffolding, and the two cross-repo handoff documents. All work was implemented to
match the FROZEN `handoffs/wrapper-contract.md` interface and live-verified against the real
mail system (himalaya v1.2.0, notmuch 0.40, a 67,466-message index) — no live bulk mutation was
performed at any point.

## What Changed

- `modules/home/email/agent-tools.nix` (new) — `mkPreamble`/`mkMutationPreamble` nix functions
  interpolated into five self-contained `writeShellScriptBin` binaries: `email-census`,
  `email-classify` (with `--append-approved`), `email-unsubscribe-extract`,
  `email-archive-confirmed`, `email-delete-confirmed` (with `--expunge-trash`).
- `home.nix` — wired `agent-tools.nix` into the email module import list.
- `modules/home/email/mbsync.nix` — added `email-freeze`/`email-thaw` operator helpers.
- `modules/home/email/aerc.nix` — added `Proposed-Delete/Archive/Unsure` querymap entries and
  their folder-scoped confirm/reject keybinds; hardened `D`/`A` with `:prompt`; rebound `$` to
  the group-scoped, hook-bypassing form.
- `modules/home/email/notmuch.nix` — appended a commented junk-rule scaffold block to the
  existing `postNew` string (append-only).
- `.claude/hooks/mail-guard.sh` (new) — PreToolUse Bash-matcher allowlist/deny hook.
- `.claude/settings.json` — registered the hook's matcher; added 7 `permissions.deny` entries.
- `specs/072_email_workflow_infrastructure_prereqs/manifests/` — git-tracked manifest directory
  (README + `.gitkeep`).
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` — appended an
  "AS-BUILT ADDENDUM" (§10) with concrete manifest filenames, the envelope-id resolution
  algorithm, and the live-verified himalaya JSON schema.
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/mail-29-runbook.md` (new) — the
  ~/Mail #29 runbook.
- `docs/email-workflow.md` (new) — operator-facing overview of the wrapper mechanism.
- `docs/himalaya.md` — fixed two `himalaya message list` references to `envelope list`.

## Decisions

- Phases 5 and 6 (read-only wrappers vs. mutation wrappers) were implemented together in a
  single `agent-tools.nix` pass and committed together, since both target the same new file and
  share a design (the mutation preamble extends the base preamble).
- Message-ID -> current envelope-id resolution (contract §3) is implemented via notmuch `id:`
  lookup for the file path/folder, a `himalaya envelope list` query narrowed by the longest
  subject word (himalaya's query syntax does not reliably match multi-word quoted phrases), each
  candidate verified against `himalaya message read -p -H Message-Id` (preview mode — never
  marks Seen as a side effect of mere resolution).
- `email-delete-confirmed`'s two hops (move-to-Trash, then `--expunge-trash`) use independent
  companion state files (`.state.jsonl` / `.expunge-state.jsonl`) so each is idempotent on its
  own hop.
- Both mutation wrappers auto-run `mbsync gmail` after a successful `--execute` batch and apply
  the auth-failure fail-safe, matching the contract's "print/apply the reconcile step" language.
- Phase 9's two pre-decided calls were implemented as directed: native `d`/`D`/`a`/`A` stay
  human-only outside the three curated Proposed-* views (where `d`/`a` are deliberately
  repurposed to the safe wrapper-routed gesture); `$` rebound to
  `mbsync gmail && notmuch new --no-hooks`.

## Plan Deviations

- **Task 7 (`.claude/settings.json` edit)** altered in scope: the file carried pre-existing
  uncommitted, unrelated restructuring (Stop/memory-nudge/wezterm hooks) from before this
  session started. Since it is a single JSON file, the Phase 7 commit necessarily also contains
  that pre-existing content — noted in the commit message rather than silently absorbed.
- **Task 10 (notmuch postNew live exercise)** altered: the plan's verification step said to
  "manually exercise the postNew content once" against the live index. The live index currently
  carries `tag:new` on 67,466 messages and `tag:inbox` on 0 (Phase 1's documented backfill
  artifact) — running the pre-existing, unmodified `notmuch tag +inbox +unread -- tag:new` line
  would bulk-retag the entire mailbox, an explicitly out-of-scope live bulk mutation. Verified
  instead via `bash -n` syntax check on the built script plus the fact that the appended block
  is 100% comments.
- **Testing & Validation item "two-hop delete path tested"**: not re-run in this dispatch (would
  require a live himalaya expunge, explicitly out of scope). Phase 1's already-completed,
  already-committed result stands: local move-to-Trash hop verified; INBOX-label removal
  confirmed server-side on app-password; the final `\Deleted`-flag+expunge hop was deliberately
  deferred to human/interactive confirmation and is recorded as such, not faked.

## Verification

- Build: `home-manager build --flake .#benjamin` green after every nix-touching phase (5, 6, 8,
  9, 10) and at the end.
- Tests: all five wrapper binaries live-tested (`--help`, `--account logos` rejection, dry-run
  plans, all four mutation refusal paths, skip-already-executed via seeded state file,
  candidate-manifest JSONL validity, `--append-approved`); `mail-guard.sh` tested against 9
  synthetic PreToolUse payloads (7 deny cases, 2 allow, 1 pass-through); `email-freeze` tested
  against both an idle system and a synthetic running-`mbsync` process (comm-name spoofing via a
  direct-shebang script, since `exec -a`/`env` indirection do not survive into `/proc/comm`);
  backup tarball diffed byte-identical against the live `.mbsyncstate*` enumeration; built
  `email-thaw` grepped for zero `mbsync -a` occurrences; built `binds.conf` inspected directly
  for the 3 new sections and zero native mutation commands.
- Files verified: yes — all new/modified files read back from their built nix store outputs
  (not just the source), confirming the interpolated nix strings render correctly.

## Follow-ups

- `~/Mail #29` (the actual purge) can now proceed using `handoffs/mail-29-runbook.md`.
- nvim `#803` (the `email/` extension) can author against `handoffs/wrapper-contract.md`
  (including its new §10 as-built addendum).
- The `gmail-spam` channel's `NONEXISTENT` mailbox issue (surfaced by the first full `mbsync
  gmail` run, not caused by this task) remains open — see `verification-baseline.md` §6a and
  `mail-29-runbook.md` §2 for the two fix options.
- A future generic `confirmed-mutation-wrapper` framework is a recorded breadcrumb, not built.

## References

- Plan: `specs/072_email_workflow_infrastructure_prereqs/plans/02_email-infra-wrappers.md`
- Handoffs: `specs/072_email_workflow_infrastructure_prereqs/handoffs/{verification-baseline,email-preferences,oauth-gate,wrapper-contract,mail-29-runbook}.md`
- New docs: `docs/email-workflow.md`
