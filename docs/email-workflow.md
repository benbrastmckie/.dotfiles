# Email Agent Workflow (Wrapper Mechanism)

Task 72 built the `.dotfiles`-owned MECHANISM for AI-assisted Gmail triage: five nix-declared,
dry-run-by-default wrapper binaries, a PreToolUse allowlist hook, mbsync freeze/thaw helpers,
and an aerc review flow. This doc is a short operator-facing overview; the authoritative,
FROZEN interface spec lives in
`specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`.

**Cross-repo note**: this mechanism is consumed by two other repos (the `email/` Claude Code
extension in the nvim config, and the `~/Mail` purge task). That coupling is
**documentation-only** — nothing here enforces a machine dependency across repos.

## The five binaries

Built by `modules/home/email/agent-tools.nix`, on `$PATH` after `home-manager switch`:

| Binary | Safety class | What it does |
|--------|--------------|--------------|
| `email-census` | read-only | Sender/folder/date census |
| `email-classify` | local-tags-only | Rule-scaffold classification -> `+proposed-*` tags + candidate manifest; `--append-approved` writes to the approved manifest |
| `email-unsubscribe-extract` | read-only | Extracts `List-Unsubscribe` headers (never fetches/POSTs) |
| `email-archive-confirmed` | mutation | Moves approved `archive` IDs to All Mail |
| `email-delete-confirmed` | mutation | Moves approved `delete` IDs to Trash; `--expunge-trash` permanently removes |

Every binary supports `--help`, `--account gmail` (the only accepted value), and
`--manifest-dir <path>` (default `$EMAIL_MANIFEST_DIR`, else
`specs/072_email_workflow_infrastructure_prereqs/manifests/`).

## Dry-run / confirm flow

1. `email-classify` (dry-run by default in the sense that it never touches maildir/IMAP) scans
   a notmuch query, applies `+proposed-{delete,archive,unsure,keep}` tags, and writes a
   **candidate** manifest. Candidates are never consumed by the mutation wrappers.
2. In aerc, the `Proposed-Delete` / `Proposed-Archive` / `Proposed-Unsure` querymap views
   surface the candidates. The confirm keybind in each view retags
   `+confirmed-{delete,archive}` and runs
   `email-classify --append-approved {{.MessageId}}`, which appends that one Message-ID to the
   git-tracked **approved** manifest. This is the sole approval act.
3. `email-archive-confirmed` / `email-delete-confirmed` are dry-run by default — they print the
   per-ID plan and do nothing else. Mutation requires
   `--execute --confirm-manifest <sha256-of-the-approved-manifest-file>`. The sha256 is
   recomputed at run time and the wrapper refuses on any mismatch (guards against an edited or
   substituted manifest).
4. `email-delete-confirmed`'s two hops are independently gated: the default invocation moves
   approved `delete` IDs to Trash; `--expunge-trash` (its own `--execute --confirm-manifest`)
   flags them `\Deleted` and expunges. This mirrors the verified Himalaya behavior — a plain
   `folder expunge` is a no-op on a message that was only soft-deleted.
5. After a successful `--execute` batch, both mutation wrappers run
   `mbsync gmail` (group-scoped; never `-a`) to reconcile server-side, and halt cleanly if the
   output shows an auth failure (`invalid_grant` or `[AUTHENTICATIONFAILED]`), preserving the
   manifest and the execution-state companion file so a re-run is safe and idempotent.

## The mail-guard hook (agent-side enforcement)

`.claude/hooks/mail-guard.sh` is registered as a `Bash` PreToolUse matcher in
`.claude/settings.json`. It allowlists Bash commands that invoke one of the five binaries above
and denies raw `himalaya message delete|move|send`, `himalaya folder expunge`, `msmtp`,
`secret-tool`, and `rm *Mail*`. `permissions.deny` carries the same seven patterns as a backstop.

This is **layer 1** of a two-layer model — it only gates the Claude Code agent's own top-level
Bash tool calls, not the wrappers' internal subprocesses (that would break the wrappers), and
not a human typing commands directly in a terminal or in aerc. **Layer 2** is the wrapper
binaries themselves: the hash/staleness/batch checks are baked into the git-tracked, nix-built
scripts, so the safety properties hold even outside an agent session.

## Operator helpers (not part of the 5-binary contract)

`modules/home/email/mbsync.nix` also provides `email-freeze` / `email-thaw`: `email-freeze`
refuses if `mbsync` is currently running, backs up every `.mbsyncstate*` file, and reminds you
of the freeze hazards (there is no mbsync systemd timer — the only trigger paths are notmuch's
`preNew` hook and aerc's `$` keybind, both of which must be avoided or run in a hook-bypassing
form while frozen). `email-thaw` reconciles with `mbsync gmail` and applies the same
auth-failure fail-safe as the mutation wrappers.

## Further reading

- `specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` — the FROZEN
  interface (manifest schema, constants, approval provenance, delete invariant).
- `specs/072_email_workflow_infrastructure_prereqs/handoffs/mail-29-runbook.md` — the runbook
  for the actual Gmail backlog purge.
- `docs/himalaya.md` — general Himalaya/mbsync/aerc setup (not agent-specific).
