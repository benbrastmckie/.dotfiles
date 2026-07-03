# Wrapper Contract — FROZEN (Task 72, Phase 4)

**Date**: 2026-07-02
**Status**: FROZEN. This is the interface that **nvim #803** (the `email/` extension) authors
against and **~/Mail #29** (the purge) executes against. Change only via a task-72 revision.
**Cross-repo coupling is documentation-only** (Critic F6): no machine-enforced dependency exists;
this document is the shared source of truth by convention.

Inputs: Phase 1 (`verification-baseline.md`), Phase 2 (`email-preferences.md`), Phase 3
(`oauth-gate.md`). All corrections from `reports/02_team-research.md` are encoded.

---

## 1. The five binaries

| Binary | Verb | Safety class | Mutates? |
|--------|------|--------------|----------|
| `email-census` | report sender/folder/date census | **read-only** | no |
| `email-classify` | apply provisional `+proposed-*` notmuch tags; emit candidate manifest; `--append-approved` | **local-tags-only** | notmuch tags only (never maildir/IMAP) |
| `email-unsubscribe-extract` | extract `List-Unsubscribe` headers to a review list | **read-only** | no (never fetches/POSTs URLs) |
| `email-archive-confirmed` | move approved-`archive` IDs to All Mail | **mutation** | yes (maildir move) |
| `email-delete-confirmed` | move approved-`delete` IDs to Trash; `--expunge-trash` permanently removes | **mutation** | yes (maildir move + expunge) |

## 2. Global flag contract (all five signatures)

- **Dry-run by default.** Mutation binaries do nothing but print the plan unless `--execute` is
  passed. The flag is **positive `--execute`** (never `--no-dry-run`).
- **`--execute` requires `--confirm-manifest <sha256>`.** The sha256 is computed over the **raw
  bytes of the approved manifest file**; the wrapper recomputes it at run time and **refuses on
  mismatch** (guards against edited/substituted manifests).
- **`--account gmail` reserved on all five.** Default and sole accepted value is `gmail`; any other
  value is a hard error. (Protonmail/Logos are explicitly out of scope; the flag exists so #803/#29
  signatures are stable when multi-account lands later.)
- **`--manifest-dir <path>`** overrides manifest storage; default resolves `EMAIL_MANIFEST_DIR`,
  falling back to `specs/072_email_workflow_infrastructure_prereqs/manifests/` (git-tracked).
- Standard: `--help` on every binary prints its verb, safety class, and flags.

## 3. Manifest schema (JSONL, keyed on Message-ID)

One JSON object per line. **The key is the `message_id` (RFC 5322 Message-ID header)** — never a
Himalaya envelope id.

```json
{"message_id": "<id@host>", "sender": "a@b.com", "subject": "...", "date": "2026-02-16T21:18:00Z",
 "proposed_action": "delete|archive|unsure|keep", "reason": "...", "confidence": 0.94}
```

- **Himalaya envelope ids are per-folder and change on move** (Phase 1 finding: a delete moves the
  file and mints a new id). They may appear as auxiliary debug fields but are **NEVER keys** and
  **never persisted across steps**. Execute mode resolves the *current* envelope id from the
  Message-ID at run time (notmuch `id:<message_id>` → file path → folder →
  `himalaya envelope list -f <folder>` match).
- Read verb everywhere is **`himalaya envelope list -o json`** (`himalaya message list` does NOT
  exist in v1.2.0).

## 4. Companion execution-state file (`<manifest>.state.jsonl`)

Per-Message-ID execution status, kept **separate** from the approved manifest so the approved
manifest's bytes (and therefore its sha256) stay immutable across a run:

```json
{"message_id": "<id@host>", "status": "pending|executed|failed", "timestamp": "...", "error": null}
```

- `--execute` initializes/updates this file; it **skips IDs already `executed`** (idempotent
  re-run after a halt) and records `failed` with error text.
- This makes `--execute` safely re-runnable after the mbsync fail-safe (§7) halts a batch.

## 5. Constants & policies

| Policy | Value | Source |
|--------|-------|--------|
| Max IDs mutated per `--execute` run | `MAX_BATCH_SIZE = 50` | prior art (`email_execute.py:26`) |
| Approved-manifest staleness limit | `PLAN_EXPIRY_DAYS = 7` | prior art (`email_execute.py:27`) |
| Min confidence to auto-propose **delete** | **≥ 0.90** (below → `unsure`) | Phase 2 correction (prior 0.70–0.80 caused churn) |
| Execute-mode target derivation | **diff executed IDs against the approved manifest; NEVER re-derive** | team report |

Manifests older than `PLAN_EXPIRY_DAYS` are refused by `--execute`. Batches exceeding
`MAX_BATCH_SIZE` are refused (split required).

## 6. Approval provenance (who writes an *approved* manifest)

1. `email-classify` (dry-run) emits a **candidate** manifest + applies `+proposed-{delete,archive,
   unsure}` tags. Candidates are NOT approved and are never consumed by mutation wrappers.
2. The **aerc review gesture** (Phase 9) is the sole approval act: confirming a message retags
   `+confirmed-*` and `:exec`s `email-classify --append-approved <message-id>`, which appends that
   Message-ID line to the **approved** manifest.
3. Mutation wrappers (`email-archive-confirmed`, `email-delete-confirmed`) consume **ONLY approved
   manifests** — never `email-classify`'s raw candidate output.

Approved manifests live under the git-tracked manifest dir (§2); their sha256 is what
`--confirm-manifest` verifies.

## 7. Delete invariant + mbsync fail-safe (corrected)

**Corrected delete invariant** (team report + Phase 1): Himalaya's backend is `maildir`, so safety
is the **sequence**, not an IMAP-vs-local transport distinction:

1. `himalaya message delete --folder INBOX <id>` → **move to Trash** (leaves flags `:2,S`).
2. To remove locally, the file must be **`\Deleted`-flagged first**:
   `himalaya message delete --folder Trash <id>` (sets `\Deleted`) **then**
   `himalaya folder expunge Trash`. **Phase 1 finding:** `expunge` alone is a no-op on an
   unflagged message — `email-delete-confirmed --expunge-trash` MUST set the flag before expunging.
3. `mbsync gmail` (**group-scoped, never `-a`**) pushes the change so the message leaves
   `[Gmail]/All Mail` server-side.

**mbsync auth-failure fail-safe** (Phase 3, now app-password — see `oauth-gate.md`): the **sole
detection point is the `mbsync gmail` reconcile step**. Detection matches `invalid_grant`
(legacy XOAUTH2) **or** `[AUTHENTICATIONFAILED] Invalid credentials` (app-password). On detection:
halt before further mutation, **preserve** the approved manifest bytes and the `.state.jsonl`
file, print resume instructions. Himalaya wrapper calls (app-password, local maildir) never check
for auth failure.

## 8. Two-layer enforcement model

1. **PreToolUse `mail-guard.sh` hook** (Phase 7) gates the **agent's own top-level Bash calls**:
   allowlists only the five wrapper binaries; denies raw `himalaya message delete|move|send`,
   `himalaya folder expunge`, `msmtp`, `secret-tool`, `rm *Mail*`. It does **not** police the
   wrappers' own subprocesses (that would break them).
2. **The git-tracked, nix-built wrapper source** is layer 2: the mutation logic (hash check,
   staleness, batch cap, state file) is baked into the binaries themselves, so safety holds even
   for a human invoking a wrapper directly outside an agent session.

nvim #803 packages the same allowlist/deny **data block** for its consuming repos; keep that block
copy-liftable (isolated arrays).

## 9. What #803 and #29 each consume

- **#803** authors classification/preferences and the extension against §1–§6, §8 (binary names,
  verbs, manifest schema, approval flow, the liftable allowlist). It must add a `$PATH` precondition
  check that fails actionably when the wrapper binaries aren't built.
- **#29** runs the built binaries end-to-end (dry-run → aerc approve → `--execute --confirm-manifest`
  → `mbsync gmail`), relying on §5 constants, §7 delete recipe + fail-safe, and the app-password
  mbsync state (server-side verification is unblocked per `oauth-gate.md` decision).
