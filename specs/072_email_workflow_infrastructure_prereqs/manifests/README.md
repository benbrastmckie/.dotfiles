# Email Wrapper Manifests

Git-tracked manifest directory for the task-72 email agent wrappers
(`modules/home/email/agent-tools.nix`). Default location resolved by all five wrapper
binaries when `$EMAIL_MANIFEST_DIR` is unset — see
`specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`.

Files (created at runtime, not seeded):

- `candidate-manifest.jsonl` — `email-classify`'s raw output. NOT approved; mutation
  wrappers never consume this file.
- `approved-manifest.jsonl` — the sole approved manifest, built one line at a time via the
  aerc review gesture (`email-classify --append-approved <message-id>`). Its sha256 is what
  `--confirm-manifest` verifies.
- `approved-manifest.jsonl.state.jsonl` — per-Message-ID execution status for
  `email-archive-confirmed` / `email-delete-confirmed`'s first mutation hop.
- `approved-manifest.jsonl.expunge-state.jsonl` — per-Message-ID execution status for
  `email-delete-confirmed --expunge-trash` (the second, independently-gated hop).

No live manifests are committed by task 72 — this README + `.gitkeep` exist only so the
directory itself is git-tracked.
