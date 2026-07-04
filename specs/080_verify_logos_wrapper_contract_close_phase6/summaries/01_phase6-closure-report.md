# Phase 6 Closure Report: Logos Multi-Account Wrapper Contract — VERIFIED, Ready to Apply

**Dual purpose**: this file is BOTH the `.dotfiles` task-80 implementation summary AND the
self-contained `/spawn`-ready handoff artifact for the `~/.config/nvim` repo. A fresh nvim agent
should be able to read ONLY this file and finish nvim task 815 Phase 6 with zero
back-references to any `.dotfiles` report.

**Direction**: `~/.dotfiles` (this repo, task 80, `verify_logos_wrapper_contract_close_phase6`)
-> `~/.config/nvim` (task 815, `revise_email_extension_multi_account`, Phase 6)
**Completed**: 2026-07-04
**Source task**: `.dotfiles` task 79 (`email_wrappers_multi_account`), status `COMPLETED` and
switched in via `home-manager switch` (live-confirmed below).

---

## 1. Status Banner

- **Task 79 has landed AND is switched in.** The wrapper binaries on `$PATH` are the real,
  live, `--account`-aware build — not the old reserved-gmail-only text. Live evidence:
  `email-census --help` (this session) prints the line
  `--account <gmail|logos>          Account to operate on (default: gmail)` verbatim, across all
  five wrapper binaries' `--help` output.
- **All 9 contract rows PASS. Zero divergence found.** See the verdict table in Section 2.
- **The nvim `/email --logos` precondition gate now PASSES.** The wrappers are live and switched
  in, all 9 rows are confirmed against real behavior, and a live census -> classify ->
  dry-run-mutation exercise against real Logos mail succeeded end-to-end with correct folder
  scoping (Section 4). Nothing blocks Phase 6 anymore.

---

## 2. Rows 1-9 Verdict Table

**Exact shipped flag spelling**: `--account <gmail|logos>` (long form) and its `=`-form
`--account=<value>` — identical across all five wrapper binaries. **Default when `--account` is
omitted**: `gmail` (preserves the pre-task-79 Gmail-only behavior byte-for-byte). **Unknown
account handling**: rejected with an actionable error and a non-zero exit code, never silently
coerced to Gmail.

| # | Assumption | Verdict | Evidence |
|---|------------|---------|----------|
| 1 | Every wrapper accepts `--account <gmail\|logos>` | **PASS** | `agent-tools.nix:59` help text `--account <gmail\|logos> Account to operate on (default: gmail)`; flag parsing at `agent-tools.nix:71-72` (`--account`/`--account=*`) inside `mkPreamble`, interpolated into all 5 binaries. Live: all five `--help` outputs show the identical line verbatim. |
| 2 | Default account when `--account` omitted is `gmail` | **PASS** | `agent-tools.nix:48` `ACCOUNT="gmail"`. Live: bare `email-census` (no `--account`) printed `=== email-census (account: gmail) ===` with the original 6-line Gmail folder block (INBOX 3382, All_Mail 65550, Sent 26019, Trash 55, Spam 0, Drafts 44). |
| 3 | Unknown account rejected with actionable error, never coerced | **PASS** | `agent-tools.nix:94-98`, the `case ... *)` fallthrough: `log "ERROR: --account only accepts 'gmail' or 'logos' (got: '$ACCOUNT')"`, `exit 1`. Live: `email-census --account work 2>&1` -> `[email-census] ERROR: --account only accepts 'gmail' or 'logos' (got: 'work')` / `[email-census] See wrapper-contract.md for the supported account set.`, exit code 1. |
| 4 | Gmail scope tokens unchanged: inbox `folder:Gmail`, archive `folder:Gmail/.All_Mail` | **PASS** | `agent-tools.nix:83-86` (`ACCOUNT_FOLDER="Gmail"`, `ACCOUNT_ARCHIVE_FOLDER="All_Mail"`); census block `agent-tools.nix:329-334` still literally queries `folder:Gmail/.All_Mail` etc. Live bare-`email-census` output matches the pre-task-79 shape exactly (byte-for-byte structure, same 6 rows). |
| 5 | Logos scope tokens: inbox `folder:Logos`, archive `folder:Logos/.Archive`; **no `.All_Mail`/`.Spam`** | **PASS** | `agent-tools.nix:88-92` (`ACCOUNT_FOLDER="Logos"`, `ACCOUNT_ARCHIVE_FOLDER="Archive"`); census block `agent-tools.nix:336-341` queries only `Sent`/`Archive`/`Trash`/`Drafts` under `folder:Logos/.*` — no `All_Mail`/`Spam` lines exist in the Logos case branch at all. Live `email-census --account logos` printed exactly `INBOX/Sent/Archive/Trash/Drafts` — 5 rows, no All_Mail/Spam row. |
| 6 | Logos real folders are `.Sent`/`.Archive`/`.Drafts`/`.Trash` only | **PASS** | Non-dot siblings on the Logos maildir are stray/empty (structural, previously live-confirmed). Live census counts this session (INBOX 62 / Sent 12 / Archive 54 / Drafts 10 / Trash 1764) are consistent with exactly these four real folders plus root-INBOX. |
| 7 | `folder:` scoping exclusive; `tag:logos`/`tag:gmail` inert | **PASS** | `agent-tools.nix:383` (`email-classify` `QUERY="folder:$ACCOUNT_FOLDER"`), `:543` (`email-unsubscribe-extract` same pattern), census `:327`/`:352` (`folder:$ACCOUNT_FOLDER`) — every query is `folder:`-scoped, no `tag:$ACCOUNT` construct anywhere in the file. Live: `notmuch count tag:logos` = `0`, `notmuch count tag:gmail` = `0`. |
| 8 | mbsync channels per-account, never `mbsync -a` | **PASS** | `agent-tools.nix:85,91` (`ACCOUNT_MBSYNC_GROUP="gmail"`/`"logos"`), `:286` (`mbsync "$ACCOUNT_MBSYNC_GROUP"` inside `run_mbsync_reconcile`), `:282-283` comment explicitly warns against `mbsync -a`. `mbsync.nix:114-119` (`Group gmail` with 5 gmail-* channels) and `:190-197` (`Group logos` with 7 logos-* channels) confirm the two named, disjoint groups exist and match the resolver's literals exactly. (No live `mbsync` invocation was run — out of scope for a read-only/dry-run verification pass; only a real `--execute` mutation ever calls `run_mbsync_reconcile`.) |
| 9 | No new binaries added | **PASS** | Live `which email-census email-classify email-archive-confirmed email-delete-confirmed email-unsubscribe-extract` resolves all 5 to `~/.nix-profile/bin/`, no 6th binary. `.claude/hooks/mail-guard.sh:23-27` allowlists exactly these 5 names. `git diff fcb5748^ 9b58578 -- .claude/hooks/mail-guard.sh` (the full task-79 commit range) is **empty** — confirmed unchanged. |

**Headline**: zero divergence across all 9 rows. The cross-repo handshake is confirmed clean —
the nvim extension's assumptions about the wrapper contract match the landed implementation
exactly, with no flag-spelling drift and no folder-token drift.

---

## 3. Contract Data Block — Ready to Apply to `wrapper-contracts.md` §2/§11

This section is written in a form that can be copied directly into
`~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
§2 (account contract) and §11 (folder-token reference).

**Confirmed `--account` enum**: `gmail` (default) | `logos`. Flag spelling exactly `--account
<value>` / `--account=<value>`. Unknown values rejected with a non-zero exit and an actionable
stderr error (see row 3 above) — never silently coerced to Gmail.

**Per-account folder-token table**:

| Account | Inbox query | Archive query | Real folders |
|---------|-------------|----------------|---------------|
| `gmail` | `folder:Gmail` | `folder:Gmail/.All_Mail` | `.All_Mail`, `.Sent`, `.Trash`, `.Spam`, `.Drafts` |
| `logos` | `folder:Logos` | `folder:Logos/.Archive` | `.Sent`, `.Archive`, `.Drafts`, `.Trash` (no `.All_Mail`, no `.Spam`) |

**mbsync channel mapping**:

| Account | mbsync invocation | mbsync.nix Group | Location |
|---------|--------------------|-------------------|----------|
| `gmail` | `mbsync gmail` | `Group gmail` (5 gmail-* channels) | `modules/home/email/mbsync.nix:114-119` |
| `logos` | `mbsync logos` | `Group logos` (7 logos-* channels) | `modules/home/email/mbsync.nix:190-197` |

Never `mbsync -a` in either code path (`agent-tools.nix:282-283` explicitly comments against
this).

**No-new-binaries fact**: the wrapper set is still exactly these 5 binaries, unchanged by task
79: `email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
`email-unsubscribe-extract`. `.claude/hooks/mail-guard.sh` (the binary allowlist gate) needed no
change — `git diff fcb5748^..9b58578 -- .claude/hooks/mail-guard.sh` (the full task-79 commit
range) is empty, i.e. byte-for-byte unchanged.

---

## 4. Live `/email --logos` Exercise Results

This exact command sequence was executed live (read-only / dry-run only, no `--execute`, no
`home-manager switch`, no `mbsync`) against the real switched-in system and proves the
precondition gate now passes end-to-end.

**Step 1 — Census (read-only)**:

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

All five Logos folders (INBOX, Sent, Archive, Drafts, Trash) are non-empty; Trash is the
largest bucket (1764).

**Step 2 — Classify (local-tags-only, read/tag-only, not gated by `--execute`)**:

```
$ email-classify --account logos --limit 2
[email-classify] NOTE: query matched 62 message(s); processing the first 2
Classified 2 message(s); candidate manifest: .../candidate-manifest.jsonl
Candidates are NOT approved — mutation wrappers never consume ... (contract §6)
```

This queries `folder:Logos` by default, writes a candidate manifest, and applies
`+proposed-{action}` notmuch tags. It never touches IMAP/maildir — the `--execute` gate only
applies to the two mutation binaries below.

**Step 3 — Mutation dry-run (scoping proof, no `--execute`)**: mutation binaries require an
*approved* manifest file to even dry-run (they check for its presence before the `--execute`
branch). A tiny hand-built approved manifest (one JSONL line: a real Logos `message_id` +
`proposed_action`) was fed to each binary in turn, with no `--execute`/`--confirm-manifest`
flag:

```
$ email-archive-confirmed --account logos
DRY-RUN (pass --execute --confirm-manifest <sha256> to mutate)
PLAN: move <message-id> (envelope 885 in INBOX) -> Archive
```

```
$ email-delete-confirmed --account logos
DRY-RUN (pass --execute --confirm-manifest <sha256> to mutate)
PLAN: move-to-Trash <message-id> (envelope 885 in INBOX)
```

**What this proves**: the `(envelope 885 in INBOX)` / `-> Archive` / `move-to-Trash` text is the
load-bearing signal. It shows the envelope resolver correctly located the test message in
`INBOX` under the `/Mail/Logos/` marker (not `/Mail/Gmail/`), and that the archive target
resolved to `Archive` (not `All_Mail`) — i.e. `folder:Logos` and `folder:Logos/.Archive` both
resolve correctly for real Logos mail. No IMAP/mbsync call happens in dry-run mode (only the
`--execute` branch calls it), so this exercise is safe to repeat against production Logos mail
at any time.

**Cleanup discipline observed**: the hand-built approved manifest and the classify step's
candidate manifest were both deleted after the dry-run confirmed scoping (neither is meant to be
committed per the manifests directory's convention of not committing live manifest state); the
two `+proposed-unsure` notmuch tags applied by the classify step were left in place as the
classify binary's normal, expected, reversible (local-tags-only) output.

**Conclusion**: the read-only/dry-run `/email --logos` exercise (census -> classify ->
archive/delete dry run) completes end-to-end with correct account scoping at every step. The
precondition gate now PASSES.

---

## 5. WHAT THE NVIM AGENT MUST DO

Concrete, self-contained action items for `~/.config/nvim` — everything needed to execute each
item is already inlined above; no other file needs to be opened to act.

- [ ] **Refresh** `~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
      §2 and §11 with the confirmed `--account <gmail|logos>` enum (default `gmail`, unknown
      rejected with error — Section 2 above) and the per-account folder-token + mbsync-channel
      table (Section 3 above). Copy the tables verbatim; they are already formatted for direct
      insertion.
- [ ] *(optional editorial)* **Generalize** the illustrative `folder:Gmail/.All_Mail` tokens in
      `~/.config/nvim/.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`
      to be account-neutral (i.e., phrase examples so they read correctly for either `gmail` or
      `logos`, referencing the Section 3 table above rather than hardcoding Gmail-only tokens).
- [ ] **Flip the Phase 6 marker** from `[BLOCKED]` to `[COMPLETED]` in
      `~/.config/nvim/specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md`.
      Update its Status/Dependencies lines to note that `.dotfiles` task 79
      (`email_wrappers_multi_account`) landed and is switched in, and that all 9 contract rows
      were confirmed PASS with zero divergence (cite this report, task 80,
      `verify_logos_wrapper_contract_close_phase6`, as the verification source).

Estimated effort once picked up: ~0.5 hour (matches the original Phase 6 estimate — only the
documentation edits remain; no further live verification is needed).

---

## 6. Cross-Repo Source Pointers

**`.dotfiles` side** (this repo):
- `modules/home/email/agent-tools.nix` — wrapper source. Key line references: `:48` (default
  `ACCOUNT="gmail"`), `:59` (help text), `:71-72` (flag parsing), `:83-92` (per-account
  folder/mbsync-group resolution), `:94-98` (unknown-account rejection), `:282-286` (mbsync
  reconcile, never `-a`), `:329-341` (census folder blocks), `:383` (classify query), `:543`
  (unsubscribe-extract query).
- `modules/home/email/mbsync.nix:114-119` (Group `gmail`), `:190-197` (Group `logos`).
- `.claude/hooks/mail-guard.sh:23-27` (binary allowlist, unchanged across task 79).
- `.dotfiles` task 79 dir: `specs/079_email_wrappers_multi_account/` (source implementation).
- `.dotfiles` task 80 dir (this task): `specs/080_verify_logos_wrapper_contract_close_phase6/`.

**nvim side** (`~/.config/nvim`):
- Extension directory: `~/.config/nvim/.claude/extensions/email/`.
- `~/.config/nvim/.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
  (the file to refresh, §2/§11).
- `~/.config/nvim/.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`
  (optional editorial generalization target).
- Task 815 directory: `~/.config/nvim/specs/815_revise_email_extension_multi_account/` — plan at
  `plans/01_email-multi-account-support.md` (the Phase 6 marker to flip).

---

## Verification (this task, Phase 2)

- Build: N/A (documentation/report artifact only, no code build).
- Tests: N/A (no test suite for this artifact type).
- Files verified: Yes — this report exists, is non-empty, and its six required sections
  (status banner, rows-1-9 table, contract data block, live exercise results, nvim checklist,
  cross-repo pointers) are all present, self-contained, and internally consistent (Logos archive
  is `folder:Logos/.Archive` with no `.All_Mail`/`.Spam` throughout; Gmail unchanged throughout).

## Plan Deviations

- None (implementation followed plan). No live mail commands were re-run; all content was
  sourced from and cross-checked against the task-80 research report, per the plan's explicit
  non-goal of re-verification.

## Notes

No nvim-repo file was edited by this task (out of scope). No `--execute` mutation,
`home-manager switch`, `mbsync` invocation, or nix build was run by this task. This report is
the sole deliverable and is intended to be handed directly to `/spawn` in the `~/.config/nvim`
repo to discharge nvim task 815's Phase 6.
