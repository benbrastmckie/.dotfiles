# Approved Manifests (git-tracked)

Default storage for **approved** JSONL manifests consumed by the mutation wrappers
(`email-archive-confirmed`, `email-delete-confirmed`). Override with `EMAIL_MANIFEST_DIR`.

- Schema + approval provenance: `../handoffs/wrapper-contract.md` (§3, §4, §6).
- Each approved manifest has a companion `<name>.state.jsonl` execution-status file.
- `--execute --confirm-manifest <sha256>` verifies the sha256 over the raw manifest bytes.

No live manifests are committed by task 72 (scaffolding only; real manifests land via ~/Mail #29).
