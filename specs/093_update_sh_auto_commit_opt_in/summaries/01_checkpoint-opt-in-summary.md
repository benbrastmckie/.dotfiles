# Implementation Summary: Task #93

**Completed**: 2026-07-05
**Duration**: ~25 minutes

## Overview

Made `scripts/update.sh`'s git checkpoint opt-in instead of unconditional, closing the hazard
behind incidents `6ba1f4e` and `02f806d` where an unconditional `git add -A && git commit` on a
dirty tree swept unrelated concurrent-session changes into misattributed commits. The script now
defaults to refusing (non-zero exit, clear stderr message) on a dirty tree unless `--checkpoint`
or `UPDATE_CHECKPOINT=1` is explicitly passed. Flag parsing was also refactored to a single
`for arg in "$@"` scan, fixing a pre-existing bug where `--no-check` was only checked at `$1`
(so `--update --no-check` silently ignored `--no-check`).

## What Changed

- `scripts/update.sh` — Added a `for arg in "$@"` flag-parsing loop setting `DO_UPDATE`,
  `DO_NO_CHECK`, and `CHECKPOINT` (from `UPDATE_CHECKPOINT` env var, overridable by
  `--checkpoint`); replaced the unconditional checkpoint block with an opt-in gate that commits
  only when `CHECKPOINT=1` and otherwise exits 1 with a stderr refusal message naming both
  remediation paths; `git add -A` now appears only inside that opt-in branch; `--update` and
  `--no-check` checks converted from positional (`$1`/`$2`) to boolean-flag checks.
- `README.md` — Corrected the Full Update section's inline comment at line 188 to state the new
  default (no auto-commit; refuses on a dirty tree) and mention `--checkpoint`.
- `docs/development.md` — Added a one-line cross-reference near line 71 pointing to the README's
  Full Update section for the `--checkpoint`, `--update`, and `--no-check` flag list.

## Decisions

- Kept the pre-existing `SKIP_CHECK` quirk (both rebuild invocations hard-code
  `--option allow-import-from-derivation false` regardless of `$SKIP_CHECK`) unchanged — it is
  out of scope per the plan's non-goals.
- Used a scratch git repository with stubbed rebuild/`nix flake update` commands to safely
  exercise the `--checkpoint` / `UPDATE_CHECKPOINT=1` commit path and the full flag matrix,
  since the real dotfiles working tree was naturally dirty from unrelated concurrent task work
  at verification time and running `--checkpoint` against it directly would have committed
  that unrelated work — exactly the hazard this task closes.

## Plan Deviations

- **Phase 3, no-flags refusal task** altered: verified against the real repo's naturally dirty
  tree (from concurrent unrelated work) instead of an artificially created throwaway file in the
  real repo; outcome (non-zero exit, stderr message, HEAD unchanged) matched the plan's intent.
- **Phase 3, checkpoint-commit task** altered: verified in an isolated scratch git repo with
  stubbed rebuild/`nix flake update` commands instead of the real dotfiles repo, to avoid
  `--checkpoint`'s `git add -A` sweeping unrelated in-flight task changes into a test commit.

## Verification

- `bash -n scripts/update.sh`: clean.
- Dirty tree (real repo, natural), no flags: refused, exit 1, stderr message, HEAD unchanged.
- Dirty tree (scratch repo), `--checkpoint`: checkpoint commit created, scoped to the scratch
  repo's tracked changes only.
- Dirty tree (scratch repo), `UPDATE_CHECKPOINT=1`: checkpoint commit created.
- `--update` (scratch repo): "Updating flake inputs..." printed, reached stubbed `nix flake
  update`.
- `--update --no-check` and `--no-check --update` (scratch repo): both flags honored in both
  orderings — confirms the ordering bug fix.
- `nix flake check` (real repo): "all checks passed!" (pre-existing unrelated
  `boot.zfs.forceImportRoot` evaluation warnings only).

## Notes

Scratch test repo was created under the session scratchpad directory and deleted after use; no
artifacts from it were committed to the dotfiles repo.
