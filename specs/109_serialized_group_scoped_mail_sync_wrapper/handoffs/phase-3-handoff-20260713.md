# Phase 3 Handoff: Task #109

**Immediate Next Action**: Run Phase 4 build verification (`nix flake check`,
`home-manager build --flake .#benjamin`).

**Current State**: Phases 1-3 completed. Plan file is current (checkboxes and phase headings
updated).

**Key Decisions Made**:
- `mail-sync` uses `case "$MODE" in gmail|logos|both)` after a single optional `--no-wait`
  pre-check, matching the plan's minimal-flag-branch guidance.
- Lock acquired via `exec {LOCK_FD}>"$LOCKFILE"; flock -w 300 "$LOCK_FD"` (or `-n` for
  `--no-wait`) BEFORE any mbsync invocation, held across the whole `both` (gmail+logos)
  sequential run.
- Duplicate-UID remediation prints the actual matched `Maildir error: duplicate UID ...` line(s)
  from mbsync's captured stderr/stdout as the "extracted folder" evidence, plus a fixed
  3-step manual remediation block (no auto-repair).
- `notmuch.nix` preNew comment rewritten to describe `mail-sync` as the serialization owner;
  `|| true` tolerance preserved verbatim.
- `aerc.nix` `$` keybind repointed to `mail-sync gmail` only (no `notmuch new --no-hooks`
  suffix needed — the wrapper does that internally).

**Deviations from Plan**:
- None.

**What NOT to Try**:
- Do not add `mail-sync` to `mail-guard.sh`'s allowlist — it is a sanctioned non-wrapper
  exception, out of scope per task constraints.
- Do not attempt real maildir duplicate-UID data repair — non-goal.

**References**: Plan at
`specs/109_serialized_group_scoped_mail_sync_wrapper/plans/01_serialized-mail-sync-wrapper.md`,
current phase 3 of 5.
