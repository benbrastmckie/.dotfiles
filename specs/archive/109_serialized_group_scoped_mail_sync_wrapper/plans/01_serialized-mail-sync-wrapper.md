# Implementation Plan: Task #109

- **Task**: 109 - serialized_group_scoped_mail_sync_wrapper
- **Status**: [COMPLETED]
- **Effort**: 3.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/109_serialized_group_scoped_mail_sync_wrapper/reports/01_serialized-mail-sync-wrapper.md
- **Artifacts**: plans/01_serialized-mail-sync-wrapper.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Introduce a single canonical, serialized, group-scoped mail-sync wrapper (`mail-sync`) built in
`modules/home/email/` via `pkgs.writeShellScriptBin`, then repoint the two in-repo sync triggers
(the notmuch `preNew` hook and aerc's `$` keybind) at it. The wrapper takes a blocking flock on one
lockfile under `$XDG_RUNTIME_DIR` so no two mbsync runs overlap regardless of trigger; is
structurally incapable of `mbsync -a` (an allowlist `case` statement branching only to hardcoded
`mbsync gmail`/`mbsync logos`); reindexes with `notmuch new --no-hooks`; and on the known
`duplicate UID` mbsync failure prints actionable remediation (detection/guidance only). Definition
of done: `nix flake check` passes, `home-manager build --flake .#benjamin` builds the closure, a
credential-free stub-`mbsync` concurrency test proves two near-simultaneous `mail-sync` invocations
serialize (non-overlapping windows), and both triggers invoke `mail-sync`.

### Research Integration

Key findings integrated from report `01_serialized-mail-sync-wrapper.md`:
- Every existing wrapper uses `pkgs.writeShellScriptBin` (never `writeShellApplication`) and relies
  on ambient Home Manager PATH — `mail-sync` matches this exactly (report §1).
- Groups `Group gmail` and `Group logos` already exist verbatim in `mbsync.nix`; the wrapper reuses
  those names and never invents new grouping (report §1, Decisions).
- The `--account {gmail,logos}` allowlist-and-reject `case` in `agent-tools/lib.nix` (lines 106-124)
  is the enforcement template to mirror for structural `-a` prevention (report §4).
- Blocking flock with a bounded wait (e.g. `flock -w 300` on `${XDG_RUNTIME_DIR:-$HOME/.cache}`)
  is the recommended lock semantics over fail-fast (report §3).
- `mail-sync` is a sanctioned non-wrapper index/sync exception alongside `email-reindex`, NOT a
  sixth member of the frozen 5-binary `mail-guard.sh` allowlist; `mail-guard.sh` is NOT modified
  (report §1, Decisions).
- Duplicate-UID detection: grep captured mbsync stderr for `Maildir error: duplicate UID`; on hit
  print an actionable message, no repair (report §5).
- Two in-repo triggers to repoint: `notmuch.nix:37` preNew (`mbsync gmail logos || true`) and
  `aerc.nix:123` `$` keybind (`mbsync gmail && notmuch new --no-hooks`) (report §2).
- Grounded line references confirmed during planning: `modules/home/default.nix` imports the email
  modules at lines 20-24 (new `mail-sync.nix` must be added there); `notmuch.nix` preNew is line 37
  and the `|| true` tolerance rationale is documented in the surrounding comment (lines 27-36); the
  aerc `$` bind at line 123 is deliberately gmail-only per its task-72-Phase-9 comment (lines
  119-122); the lib.nix `case "$ACCOUNT"` allowlist is at lines 106-124.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (no roadmap flag / path provided).

## Goals & Non-Goals

**Goals**:
- Build one canonical `mail-sync` wrapper: flock-serialized, group-scoped (`gmail`/`logos`/`both`),
  structurally incapable of `mbsync -a`, reindexing via `notmuch new --no-hooks`.
- Detect the known `duplicate UID` mbsync failure and print actionable remediation (message only).
- Repoint the two in-repo triggers (notmuch `preNew` hook, aerc `$` keybind) to call `mail-sync`,
  preserving the preNew `|| true` tolerance.
- Verify via `nix flake check`, `home-manager build --flake .#benjamin`, and a credential-free
  stub-`mbsync` concurrency test asserting serialized (non-overlapping) execution windows.

**Non-Goals**:
- One-time Maildir data repair for existing `duplicate UID` corruption (detection/guidance only).
- The Neovim `<leader>me`/`<leader>mN` repoint (separate nvim-repo task) — inventory only, no edit.
- Routing `email-thaw` and the mutation wrappers' `run_mbsync_reconcile` through the new lock
  (latent race sources not named in the task's explicit trigger inventory) — deferred; noted as an
  open follow-up, not implemented here.
- Adding `mail-sync` to the frozen 5-binary `mail-guard.sh` allowlist (it is a sanctioned
  non-wrapper exception; `mail-guard.sh` is not touched).
- A separate detector/repair helper alongside `census.nix` (optional/deferred; inline detection in
  `mail-sync` satisfies the deliverable).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Repointed preNew to blocking `mail-sync` could hang `notmuch new` up to the wait timeout if a stuck mbsync holds the lock | M | L | Bounded wait (`-w 300`, not infinite); preserve `... \|\| true` tolerance so a `mail-sync` timeout/failure never aborts the whole `notmuch new` run |
| Reentrancy: preNew calls `mail-sync`, which internally runs `notmuch new --no-hooks` | M | L | `--no-hooks` skips preNew entirely, so no reentry; verify explicitly in Phase 5, do not assume |
| New `mail-sync.nix` file not wired into `modules/home/default.nix` imports → not built at all | H | M | Phase 2 is a dedicated wiring step; Phase 4 build verification fails loudly if the binary is absent |
| Stub-`mbsync` concurrency test only proves flock serialization, not real duplicate-UID interaction | L | H | Accepted scope boundary (data repair is a non-goal); state the limitation explicitly in the test and summary |
| Accidental `mbsync -a` code path (e.g. arg passthrough) | H | L | Allowlist `case` branches only to hardcoded `mbsync gmail`/`mbsync logos`; script body contains no `mbsync "$@"` passthrough and never the literal `mbsync -a` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Create the `mail-sync` wrapper module [COMPLETED]

**Goal**: Author `modules/home/email/mail-sync.nix` defining the `mail-sync` binary via
`pkgs.writeShellScriptBin`, encoding flock serialization, group-scope allowlist enforcement,
`notmuch new --no-hooks` reindex, and duplicate-UID detection/remediation.

**Tasks**:
- [x] Create `modules/home/email/mail-sync.nix` as a Home Manager module
  (`{ pkgs, ... }:`) appending a `pkgs.writeShellScriptBin "mail-sync" ''...''` to `home.packages`,
  matching the existing wrapper style (no `writeShellApplication`, no explicit `runtimeInputs`;
  rely on ambient PATH). First script line: `set -euo pipefail`.
- [x] Argument allowlist: a `case "$1" in gmail|logos|both) ... ;; *) <reject + exit 1> ;; esac`
  mirroring `agent-tools/lib.nix` lines 106-124. Map `gmail`->run `mbsync gmail`; `logos`->run
  `mbsync logos`; `both`->run `mbsync gmail` then `mbsync logos` sequentially in the one locked
  section. No `mbsync "$@"` passthrough; the literal `mbsync -a` must not appear anywhere.
- [x] Blocking flock: `LOCKFILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/mail-sync.lock"`, then
  `exec {LOCK_FD}>"$LOCKFILE"; flock -w 300 "$LOCK_FD" || { echo "[mail-sync] ERROR: lock not
  acquired within 300s" >&2; exit 1; }`. Create the `$HOME/.cache` fallback dir if used.
- [x] Optional `--no-wait` flag (fail-fast `flock -n`) parsed but defaulting to blocking; document
  it as opt-in for a future CI/test harness (keep minimal — a single flag branch).
- [x] Reindex step inside the lock after a successful mbsync: `notmuch new --no-hooks`.
- [x] mbsync output capture per the existing idiom: `set +e; OUT=$(mbsync <group> 2>&1); STATUS=$?;
  set -e`; echo `$OUT` through so the caller still sees mbsync output.
- [x] Duplicate-UID detection: on non-zero `$STATUS`, `grep -qE 'Maildir error: duplicate UID
  [0-9]+ in'` over `$OUT`; on match, extract the folder(s) and print the actionable remediation
  block from report §5 (inspect colliding `,U=N:` files / reset `.mbsyncstate`; no auto-repair;
  note other channels may have synced). On a non-duplicate-UID failure, preserve the existing
  auth-failure special-case (`invalid_grant` / `[AUTHENTICATIONFAILED]`) plus a generic
  "inspect output above" fallback, mirroring `run_mbsync_reconcile`.
- [x] Add a short module header comment documenting `mail-sync` as a sanctioned non-wrapper
  index/sync exception (alongside `email-reindex`), NOT a member of the 5-binary allowlist.

**Timing**: ~1.5 hours

**Depends on**: none

**Files to modify**:
- `modules/home/email/mail-sync.nix` - new file; the wrapper derivation and its script body.

**Verification**:
- `nix-instantiate --parse modules/home/email/mail-sync.nix` (or rely on Phase 4 `nix flake check`)
  parses without error.
- Manual read-through confirms: no `mbsync -a` / no `mbsync "$@"`; `case` rejects anything outside
  `gmail|logos|both`; flock precedes every mbsync call; reindex uses `--no-hooks`.

---

### Phase 2: Wire the new module into the import list [COMPLETED]

**Goal**: Ensure `mail-sync.nix` is actually built by adding it to `modules/home/default.nix`.

**Tasks**:
- [x] Add `./email/mail-sync.nix` to the imports list in `modules/home/default.nix` alongside the
  existing email module imports (lines 20-24).

**Timing**: ~0.25 hour

**Depends on**: 1

**Files to modify**:
- `modules/home/default.nix` - add one import line for `./email/mail-sync.nix`.

**Verification**:
- `grep -n "mail-sync" modules/home/default.nix` shows the new import line.
- Deferred build confirmation happens in Phase 4.

---

### Phase 3: Repoint the two in-repo triggers [COMPLETED]

**Goal**: Route the notmuch `preNew` hook and aerc's `$` keybind through `mail-sync`.

**Tasks**:
- [x] `modules/home/email/notmuch.nix` line 37: change `preNew = "mbsync gmail logos || true";` to
  `preNew = "mail-sync both || true";`. Preserve the `|| true` tolerance and update the surrounding
  comment (lines 27-36) to reflect that serialization/locking now lives in `mail-sync`.
- [x] `modules/home/email/aerc.nix` line 123: change
  `"$" = ":exec mbsync gmail && notmuch new --no-hooks<Enter>";` to
  `"$" = ":exec mail-sync gmail<Enter>";` (the wrapper already performs the `notmuch new
  --no-hooks` reindex internally). Keep gmail-only to preserve current behavior; note in the
  comment that `mail-sync logos`/`mail-sync both` is a trivial future extension (optional, out of
  scope per task).
- [x] Confirm no other in-repo call site references the old inline commands (grep for `mbsync
  gmail logos` and the aerc `$` string). Verified: only remaining occurrences are inside
  `mail-sync.nix`'s own motivation/history comment, quoting the pre-task-109 strings for context.

**Timing**: ~0.5 hour

**Depends on**: 1

**Files to modify**:
- `modules/home/email/notmuch.nix` - repoint preNew hook, update comment.
- `modules/home/email/aerc.nix` - repoint `$` keybind, update comment.

**Verification**:
- `grep -n "mail-sync" modules/home/email/notmuch.nix modules/home/email/aerc.nix` shows both
  repointed call sites.
- `grep -rn "mbsync gmail logos" modules/` returns no remaining live trigger (only comments/history
  if any).

---

### Phase 4: Build verification [COMPLETED]

**Goal**: Confirm the whole configuration evaluates and builds with the new wrapper and repointed
triggers.

**Tasks**:
- [x] Run `nix flake check` from `/home/benjamin/.dotfiles` (fast: syntax + evaluation of all
  outputs). Result: `all checks passed!` (exit 0). (New file had to be `git add`ed first since
  flakes only see git-tracked files -- expected, not a deviation.)
- [x] Run `home-manager build --flake .#benjamin` (builds the standalone home-manager closure,
  compiling `mail-sync`'s shell body via `writeShellScriptBin` without activating or needing IMAP
  credentials). Result: built successfully (7 derivations built including
  `mail-sync.drv`), `./result` symlink produced.
- [x] Confirm the built `mail-sync` binary appears in the result closure (e.g. inspect
  `./result/home-path/bin/mail-sync` or `nix path-info` on the built profile). Confirmed:
  `./result/home-path/bin/mail-sync --help` runs and prints the expected usage text; an
  unrecognized mode (`mail-sync bogus`) and a missing mode (`mail-sync`) both reject with exit 1.

**Timing**: ~0.5 hour

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only). Fix-forward into Phase 1-3 files if a build error surfaces.

**Verification**:
- `nix flake check` exits 0.
- `home-manager build --flake .#benjamin` exits 0 and produces a `result` symlink.
- `mail-sync` binary present in the built closure.

---

### Phase 5: Credential-free concurrency test [COMPLETED]

**Goal**: Prove flock serialization: two near-simultaneous `mail-sync` invocations run in
non-overlapping windows rather than concurrently, without touching real mail/credentials.

**Tasks**:
- [x] Write a standalone test harness script (under
  `specs/109_serialized_group_scoped_mail_sync_wrapper/` or `modules/home/email/tests/`) that
  creates a temp dir containing a stub `mbsync` executable: appends `PID START <epoch-ns>` to a
  shared log, sleeps ~2-3s, appends `PID END <epoch-ns>`, exits 0. Optionally stub `notmuch` too
  so the wrapper's reindex step is a no-op. Written to
  `specs/109_serialized_group_scoped_mail_sync_wrapper/concurrency-test.sh`.
- [x] Prepend the stub dir to `PATH`, then launch two `mail-sync gmail` invocations near-
  simultaneously (backgrounded `&` a few ms apart, or `xargs -P2`), pointing at the built wrapper
  from Phase 4 (or `nix build` just the wrapper derivation). Uses the Phase 4
  `./result/home-path/bin/mail-sync` build output by default (overridable via `$1`).
- [x] Assert from the shared log that the two [START, END] intervals do NOT overlap (invocation B
  START >= invocation A END, or vice versa) — direct evidence of serialization. Confirmed
  non-overlapping across two separate runs (see summary for timestamps).
- [x] Secondary assertions: both invocations exit 0; the lockfile path exists after the run.
  Confirmed both times.
- [x] Verify the reentrancy assumption explicitly: with a stub `notmuch`, confirm the wrapper's
  internal `notmuch new --no-hooks` does not re-invoke `mail-sync`/preNew. Confirmed: the stub
  notmuch's call log never references mail-sync/preNew (the stub shells out to nothing).
- [x] Document in the test header that this proves lock serialization only, not real
  mbsync/duplicate-UID behavior (credential-free scope boundary).

**Timing**: ~1 hour

**Depends on**: 4

**Files to modify**:
- `specs/109_serialized_group_scoped_mail_sync_wrapper/` (or `modules/home/email/tests/`) - new
  concurrency test harness script.

**Verification**:
- Test script runs and prints PASS: the two intervals are non-overlapping and both invocations
  exited 0.
- Re-running the test is deterministic (serialization holds across repeated runs).

---

- [x] `nix flake check` passes from the repo root.
- [x] `home-manager build --flake .#benjamin` builds the closure and includes `mail-sync`.
- [x] Stub-`mbsync` concurrency test asserts non-overlapping [START, END] windows for two
  near-simultaneous `mail-sync gmail` invocations; both exit 0; lockfile exists post-run.
- [x] Static review confirms the wrapper has no `mbsync -a` / no `mbsync "$@"` path and rejects any
  argument outside `gmail|logos|both`.
- [x] `grep` confirms both triggers (`notmuch.nix` preNew, `aerc.nix` `$`) call `mail-sync`, and
  the preNew `|| true` tolerance is preserved.
- [x] Reentrancy check: `notmuch new --no-hooks` inside `mail-sync` does not re-fire the preNew
  hook.

## Artifacts & Outputs

- `modules/home/email/mail-sync.nix` - new `mail-sync` wrapper module.
- `modules/home/default.nix` - updated import list.
- `modules/home/email/notmuch.nix` - repointed preNew hook.
- `modules/home/email/aerc.nix` - repointed `$` keybind.
- Concurrency test harness script (under the task dir or `modules/home/email/tests/`).
- `specs/109_serialized_group_scoped_mail_sync_wrapper/summaries/01_serialized-mail-sync-wrapper-summary.md`
  (produced at implementation time).

## Rollback/Contingency

- All changes are additive or localized single-line edits. To revert: remove
  `modules/home/email/mail-sync.nix`, drop its import line from `modules/home/default.nix`, and
  restore the two original trigger strings in `notmuch.nix` (`mbsync gmail logos || true`) and
  `aerc.nix` (`mbsync gmail && notmuch new --no-hooks`).
- If `home-manager build` fails, fix-forward in the Phase 1-3 files (never discard uncommitted
  work); the prior config remains active until `switch` is run, so a failed `build` has no live
  impact.
- The concurrency test is a standalone script with no config coupling; it can be removed or
  iterated on freely without affecting the built configuration.
