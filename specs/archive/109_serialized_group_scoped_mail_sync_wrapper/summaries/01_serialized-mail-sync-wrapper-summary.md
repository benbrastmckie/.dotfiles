# Implementation Summary: Task #109

**Completed**: 2026-07-13
**Duration**: ~1 session

## Overview

Created a single canonical, serialized, group-scoped `mail-sync` wrapper in
`modules/home/email/mail-sync.nix` (`pkgs.writeShellScriptBin`, matching the existing email
wrapper style) and repointed the two in-repo mbsync triggers -- the notmuch `preNew` hook and
aerc's `$` keybind -- to call it instead of invoking `mbsync` directly. The wrapper takes a
blocking `flock -w 300` before any mbsync call, is structurally incapable of `mbsync -a`, reindexes
via `notmuch new --no-hooks`, and detects the known `Maildir error: duplicate UID` failure with
message-only remediation guidance.

## What Changed

- `modules/home/email/mail-sync.nix` — new file: the `mail-sync` wrapper module
  (`pkgs.writeShellScriptBin "mail-sync"`). Allowlist `case "$MODE" in gmail|logos|both)` (no
  passthrough, no `-a`), single optional `--no-wait` flag (fail-fast `flock -n`) ahead of the
  default blocking `flock -w 300`, `mbsync` output capture idiom (`set +e; OUT=$(...); STATUS=$?;
  set -e`) matching `email-thaw`/`run_mbsync_reconcile`, duplicate-UID detection with an
  actionable 3-step manual-remediation message, auth-failure special-case, and a final
  `notmuch new --no-hooks` reindex inside the lock.
- `modules/home/default.nix` — added `./email/mail-sync.nix` to the email imports block (after
  `./email/aerc.nix`, before `./email/agent-tools`).
- `modules/home/email/notmuch.nix` — `preNew` repointed from `"mbsync gmail logos || true"` to
  `"mail-sync both || true"` (tolerance preserved); surrounding comment rewritten to describe
  `mail-sync` as the serialization/locking owner.
- `modules/home/email/aerc.nix` — `$` keybind repointed from
  `":exec mbsync gmail && notmuch new --no-hooks<Enter>"` to `":exec mail-sync gmail<Enter>"`
  (the wrapper performs the reindex internally); comment updated, gmail-only behavior preserved.
- `specs/109_serialized_group_scoped_mail_sync_wrapper/concurrency-test.sh` — new credential-free
  test harness (Phase 5 deliverable; not part of the built configuration).

## Decisions

- Followed the plan's minimal-flag-branch guidance: a single `if [ "${1:-}" = "--no-wait" ]`
  pre-check before the mode `case`, rather than a general argument-parsing loop.
- Duplicate-UID remediation echoes the actual matched `Maildir error: duplicate UID ...` line(s)
  from the captured mbsync output as the "extracted folder" evidence, rather than attempting a
  separate structured parse — simpler and strictly more faithful to the real error text.
- `both` mode runs `mbsync gmail` then `mbsync logos` sequentially inside the single lock
  acquisition (one `run_group` call each; overall exit status is non-zero if either fails, but
  both are attempted rather than short-circuiting on the first failure), matching
  `run_mbsync_reconcile`'s per-group failure handling style rather than aborting the whole
  `both` run on the first group's failure.

## Plan Deviations

- None (implementation followed plan).

## Verification

- `nix-instantiate --parse modules/home/email/mail-sync.nix`: parses without error.
- `nix flake check`: `all checks passed!` (exit 0). Note: the new file first had to be
  `git add`ed, since flakes only evaluate git-tracked files — this is expected Nix flake
  behavior, not a deviation.
- `home-manager build --flake .#benjamin`: builds successfully; 7 derivations built including
  `mail-sync.drv`; produced a `./result` symlink (already gitignored).
- `./result/home-path/bin/mail-sync --help`: prints the expected usage text; the heredoc-based
  help renders correctly (confirms Nix's automatic indented-string dedent behavior works as
  intended for the embedded heredoc).
- `mail-sync bogus` and bare `mail-sync` (no argument) both reject with exit 1 and an actionable
  error message — the allowlist rejects any argument outside `gmail|logos|both`.
- `grep -n "mbsync -a\|mbsync \"\$@\""` over `mail-sync.nix`: no executable occurrence (only
  appears inside comments/echo messages documenting the invariant).
- `grep -rn "mbsync gmail logos"` / aerc's old `$` string over `modules/`: no remaining live
  call site; only `mail-sync.nix`'s own motivation-comment quotes the pre-task-109 strings for
  historical context.
- Credential-free concurrency test (`concurrency-test.sh`), run twice: both times, two
  near-simultaneous `mail-sync gmail` invocations against a stub `mbsync` produced
  non-overlapping `[START, END]` windows (e.g. run 1: `[...987988880888, ...090496126442]` then
  `[...090509488702, ...093015671968]`), both invocations exited 0, the lockfile existed
  post-run, and the stub `notmuch`'s call log never referenced `mail-sync`/`preNew` (confirming
  no reentrancy from the internal `notmuch new --no-hooks` reindex step).

## Notes

- The concurrency test is standalone (`specs/109_serialized_group_scoped_mail_sync_wrapper/
  concurrency-test.sh`) and has no coupling to the built Home Manager configuration; it can be
  re-run any time by pointing it at a built `mail-sync` binary (defaults to
  `./result/home-path/bin/mail-sync`, i.e. the repo-root `result` symlink from
  `home-manager build --flake .#benjamin`).
- Non-goals from the plan were respected: no Neovim-side keybind change, no one-time maildir
  duplicate-UID data repair, `mail-guard.sh`'s frozen 5-binary allowlist was not touched, and
  `email-thaw`/mutation wrappers' `run_mbsync_reconcile` were not routed through the new lock
  (noted in the plan as a deferred follow-up, not implemented here).
