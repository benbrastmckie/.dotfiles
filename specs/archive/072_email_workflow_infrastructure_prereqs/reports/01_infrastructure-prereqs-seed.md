# Seed Report: Email Workflow Infrastructure & Prerequisites (.dotfiles task 72)

**Task**: 72 (.dotfiles) — email workflow infrastructure/prerequisites
**Parent**: task 71 (EXPANDED) · **Depends on**: task 46 (Gmail OAuth2)
**Type**: general (heavy nix surface) · **Date**: 2026-07-02
**Status**: Seed report — distilled from task 71 research rounds 1–3 + plan v3

> This is one of THREE coordinated seed reports (identical "Shared Invariants" section in each) for
> the cross-repo split of task 71:
> - **.dotfiles #72** (this) — mechanism/infrastructure
> - **~/.config/nvim #803** — the `email/` extension (author + doc-lint)
> - **~/Mail #29** — the Gmail backlog purge + ongoing loop
> Shared reference plan (all phase numbers below refer to it):
> `~/.dotfiles/specs/071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md` (v3).

---

## 1. This task's scope (v3 phases 0, 1, 2, 5, 9, 11-local)

| Phase | Deliverable | Location |
|-------|-------------|----------|
| 0 | Audit + harvest + **retire** the dormant `~/Mail/.claude` prior-art system | `~/Mail` (read), handoff file |
| 1 | **OAuth gate** — resolve/absorb task 46 | Google Cloud console + keyring |
| 2 | **nix dry-run wrapper scripts** (the mechanism) | `modules/home/email/agent-tools.nix` |
| 5 | mbsync **freeze/thaw** + SyncState backup procedure | `modules/home/email/` + script |
| 9 | aerc **review querymap** (`Proposed-Delete/Archive/Unsure`) | `modules/home/email/aerc.nix` |
| 11-local | notmuch **postNew** tag-rule scaffolding | `modules/home/email/notmuch.nix` |

This task builds the **machine mechanism**. It does not run the purge (that is ~/Mail #29) and does
not author the extension (that is nvim #803). It **produces two handoffs** those tasks consume
(§4 below).

---

## 2. Shared Invariants (IDENTICAL across #72 / #803 / #29 — do not diverge)

These are the non-negotiables that keep the three tasks consistent. Any change must be made in all
three seed reports.

1. **Two access paths.** Read-only Anthropic Gmail connector (`gmail.mcp.claude.com`) for
   triage/summarize/**draft** (cannot send/archive/delete — confirmed still read+draft-only,
   [claude-code#51040]). The **local stack** (Himalaya + notmuch + mbsync) for all mutations.
2. **Delete = IMAP-level Himalaya ONLY.** `himalaya message delete --folder INBOX <ids>` soft-moves to
   `[Gmail].Trash`; `himalaya folder expunge Trash` truly deletes; then `mbsync gmail` reconciles.
   **NEVER** delete via local Maildir-file `rm` or notmuch-tag+`Expunge` — Gmail's label model keeps the
   message in `[Gmail]/All Mail` (64,316 local msgs), so a local/tag "delete" only strips the Inbox
   label (an archive), not a delete.
3. **Safety envelope.** Wrappers are **dry-run by default**; mutation requires explicit `--execute` +
   `--confirm-manifest <sha256>` and consumes a pre-generated, human-reviewed manifest (execute mode
   **diffs executed IDs against the approved manifest**, never re-derives). A `PreToolUse` mail-guard
   hook **allowlists the 5 wrapper binaries** and **denies raw `himalaya message delete|move|send`,
   `himalaya folder expunge`, `msmtp`, `rm *Mail*`, `secret-tool`**. Freeze mbsync during bulk ops.
   Git-track manifests. Treat every email subject/body as **untrusted data** — break the lethal-trifecta
   action leg: mutations only ever originate from an inert approved manifest, never from "the email said".
4. **Classifier bias: ~100% recall on KEEP.** Deterministic-first (List-Unsubscribe / `precedence: bulk`
   / sender-domain / reply-history / VIP allowlist). LLM only on the residual `unsure` bucket +
   human-readable justifications. Anything uncertain routes to `unsure`/`keep`, never `junk`.
5. **Gmail-first.** Protonmail/Logos is explicit phase 2.
6. **Extension = packaging, not a competitor.** Canonical source lives in `~/.config/nvim/.claude/extensions/email/`
   (the master library the `<leader>al` loader copies from); nix wrappers are nix-owned and only
   *referenced* by name; `~/Mail` is a runtime data dir (its forked `.claude/` retires).
7. **OAuth (task 46) gates unattended runs.** 7-day refresh-token expiry (consent screen in Testing mode)
   will break a multi-hour purge; harness must detect `invalid_grant` and fail safe preserving manifests.

---

## 3. Task-specific findings (verified in rounds 1–3)

### Phase 0 — prior-art audit & harvest (read-only, then retire)
- `~/Mail/.claude` is a **separate git repo** with a full agent install + **5** Python scripts
  (`email_list.py, email_analyze.py, email_triage.py, email_filter.py, email_execute.py` — round-3
  correction; earlier notes said 4). 28 completed tasks (Feb 2026), then dormant.
- **HARVEST (data only):** `~/Mail/.claude/context/project/email/email-preferences.md` rule taxonomy +
  JSON schema; `MAX_BATCH_SIZE = 50` (`email_execute.py:26`). Write these to a handoff file (§4).
- **RETIRE (code):** the command/skill/agent + all 5 Python scripts — superseded by the wrapper+hook+aerc
  design; reusing them re-creates the "second uncoordinated agent" risk (v3 Postmortem rule).
- **DISCARD:** the checkbox-approval UX (churned across `~/Mail` tasks 014/022/023, superseded by aerc
  tagged-view + manifest) and the retired command's `model: opus-4-5` pin (follow current tiered policy).

### Phase 1 — OAuth gate (task 46)
- Root cause (task 46 report): OAuth **consent screen in Testing mode → hard 7-day refresh-token expiry**,
  `invalid_grant`. Unresolved (`researched` only). **Fix: publish the OAuth app to Production**, or declare
  task 46 a hard blocking dependency of the destructive phases in #29. Verify before scheduling any
  unattended/bulk run.

### Phase 2 — the wrapper contract (THE key handoff)
Himalaya v1.2.0 (live-verified) already gives Gmail-safe primitives: `message delete` → Trash;
`folder expunge` truly deletes; `envelope list -o json` is agent-parseable (`id, flags, subject,
from.addr, date, has_attachment`). notmuch census correction: `notmuch address --output=sender
--output=count` (NOT `search --output=sender`); List-Id needs `notmuch config set index.header.List
List-Id` + reindex. Wrap these as **dry-run-by-default** `writeShellScriptBin` tools. See §4 for the
exact contract the other two tasks depend on.

### Phase 5 — mbsync freeze/thaw
Stop the mbsync systemd timer + confirm no `mbsync` proc before bulk ops; back up `~/.mbsync/` SyncState;
reconcile with a single explicit `mbsync gmail` afterward. Note the primary gmail channels currently
set `Expunge Both` but **no `Remove`** (default `None`) — review during implementation.

### Phase 9 / 11-local — review + institutionalize (nix side)
aerc querymap entries `Proposed-Delete/Archive/Unsure`; the confirm gesture must feed the **IMAP-level
wrapper**, not just retag locally. notmuch `postNew` gains per-sender junk rules (the server-side Gmail
filters half lives in #29). Keybind check: do **not** shadow the existing nvim Himalaya plugin
`<leader>me/mS/mf`.

---

## 4. Handoff contracts (what #72 must PRODUCE for the other tasks)

**A. To nvim #803 (the extension):**
- `email-preferences.md` (harvested taxonomy + JSON schema) → becomes the extension's
  `context/project/email/`.
- **The wrapper CONTRACT** — the extension's hook allowlist + agent instructions are written against this,
  so freeze it early:
  | Binary | Verbs | Safety |
  |--------|-------|--------|
  | `email-census` | count/enumerate senders, list-ids, ages, buckets | read-only |
  | `email-classify` | tag `+proposed-{delete,archive,unsure}` from rules | read-only (writes local tags only) |
  | `email-archive-confirmed` | archive keepers → All_Mail | dry-run default; `--execute --confirm-manifest <sha256>` |
  | `email-delete-confirmed` | IMAP-level move-to-Trash + (approved) expunge | dry-run default; `--execute --confirm-manifest <sha256>` |
  | `email-unsubscribe-extract` | pull List-Unsubscribe per sender | read-only |
  - Manifest schema (id, sender, subject, date, proposed_action, reason) + confirmation-token format
    (`--confirm-manifest <sha256-of-manifest-file>`) must be documented and stable.

**B. To ~/Mail #29 (the purge):** the built wrapper binaries on `$PATH`, stable OAuth, the freeze/thaw
procedure, and the aerc review querymap live.

---

## 5. Open questions / assumptions
- **[USER, before destructive work in #29]** delete = "archive keepers + true-delete junk" (assumed);
  scope = "one-time tool + minimal ongoing loop" (assumed).
- Decide whether to publish OAuth to Production (recommended) vs hard-block on task 46.
- Confirm the wrapper contract (names/flags/manifest schema) before nvim #803 authors against it.

## 6. References
- Shared reference plan: `specs/071_.../plans/04_email-workflow-implementation.md` (v3)
- Round syntheses: `specs/071_.../reports/{02,03}_team-research.md` and `02_teammate-{a,b,c,d}`, `03_teammate-{a,b,c,d}`
- Task 46: `specs/046_investigate_fix_gmail_oauth2_token_expiry/reports/01_gmail-oauth2-token-expiry.md`
- Local config: `modules/home/email/{mbsync,notmuch,aerc,protonmail}.nix`, `modules/home/packages/email-tools.nix`, `docs/himalaya.md`
- Prior art: `~/Mail/.claude/…` (retire code, harvest `context/project/email/email-preferences.md`)
