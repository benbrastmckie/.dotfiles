# Research Report: Task #109

**Task**: 109 - serialized_group_scoped_mail_sync_wrapper
**Started**: 2026-07-13T20:58:00Z
**Completed**: 2026-07-13T21:20:00Z
**Effort**: Medium (single new nix-built wrapper + 2 call-site repoints + concurrency test)
**Dependencies**: None
**Sources/Inputs**: Local `modules/home/email/*.nix`, `.claude/hooks/mail-guard.sh`, archived task
  reports (072, 079, 080, 092, 105, 108), CLAUDE.md email-extension doctrine section
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- There is **no systemd timer** for mbsync (verified fact baked into `mbsync.nix` comments and
  `email-freeze`/`email-thaw` operator helpers). The only three trigger paths today are: (1) the
  notmuch `preNew` hook in `notmuch.nix` (`mbsync gmail logos || true`), (2) aerc's `$` keybind in
  `aerc.nix` (`mbsync gmail && notmuch new --no-hooks`), and (3) manual/external invocation
  (including the out-of-scope Neovim `<leader>me`/`<leader>mN` mappings in the separate nvim repo,
  which the task description says still call `mbsync -a` + hook-ful `notmuch new`).
- **No wrapper currently takes a lock.** Nothing in the repo uses `flock`. `mbsync.nix`'s
  `email-thaw`/`email-freeze` and `agent-tools/lib.nix`'s `run_mbsync_reconcile` all invoke
  `mbsync <group>` directly with no mutual exclusion — each is independently safe in isolation
  (never `-a`) but nothing stops two of these call sites from racing each other, which is exactly
  task 109's root-cause complaint.
- The two group-scoped `mbsync` groups already exist and are correctly scoped: `Group gmail`
  (5 channels, excludes gmail-trash/gmail-spam) and `Group logos` (6 channels, excludes
  logos-labels) in `modules/home/email/mbsync.nix`. A new `mail-sync` wrapper should reuse these
  group names verbatim and take an explicit `{gmail,logos}` (or `--account`) argument rather than
  inventing new grouping.
- The five agent-tools wrapper binaries (`email-census`, `email-classify`,
  `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract`) are a FROZEN,
  named-allowlist contract enforced by `.claude/hooks/mail-guard.sh` and documented in CLAUDE.md.
  The new `mail-sync` wrapper is **not** a sixth member of that contract — it belongs in the same
  "sanctioned non-wrapper exception" tier as `email-reindex` (index/sync-only, read/reconcile
  operations, no mail mutation). CLAUDE.md already names "the group-scoped `mbsync` reconcile" and
  "`email-reindex`" as the two sanctioned non-wrapper exceptions; `mail-sync` is a formalization of
  the first of those two, and `mail-guard.sh`'s deny-pattern set does not currently block bare
  `mbsync`/`notmuch new` calls, so no hook change is strictly required, though adding `mail-sync` to
  documentation (and optionally the audit log path) is recommended for consistency.
- Recommended lock semantics: **blocking flock** (not fail-fast) on a single lockfile under
  `$XDG_RUNTIME_DIR` (falls back to `$HOME/.cache`), using the `exec {fd}>lockfile; flock -x $fd`
  shell idiom via `pkgs.writeShellScriptBin`. Block-and-wait matches the actual trigger pattern
  (interactive keypress / hook-fired background call) better than fail-fast, which would silently
  drop a legitimate second sync request.
- `duplicate UID` is a known, previously-diagnosed mbsync failure mode (task 092 report,
  `~/Mail/Logos/.Trash` and `.Archive`) caused by two maildir files sharing the same `U=` token in
  their filename. The new wrapper's remediation path is detection + actionable message only
  (no repair) — grep mbsync's stderr for `Maildir error: duplicate UID`, extract the affected
  folder(s), and print a specific pointer to inspect/rename the colliding `,U=N:` file(s) or reset
  `.mbsyncstate`/`.uidvalidity`, explicitly declining to auto-repair.
- Verification: `nix flake check` from the repo root (flake already defines `homeConfigurations.benjamin`
  and no `checks` output, so `flake check` mainly validates evaluation/syntax); functional
  verification is `home-manager build --flake .#benjamin` (or `switch`) plus a manual concurrency
  test launching two near-simultaneous `mail-sync gmail` invocations and asserting the second
  blocks until the first releases the lock (observable via timestamps/PID trace, not by needing
  live IMAP credentials — the lock behavior can be tested by wrapping a stub `mbsync`).

## Context & Scope

Task 109 asks for a single canonical wrapper (nicknamed `mail-sync`) built by
`modules/home/email/` that becomes the ONE path through which every mbsync trigger runs, so that:
1. mutual exclusion (flock) prevents any two mbsync runs overlapping regardless of trigger,
2. the wrapper is structurally incapable of `mbsync -a` (group-scoped only, explicit channel arg),
3. reindexing always uses `notmuch new --no-hooks` (never re-triggers the preNew hook's own mbsync),
4. on the known `duplicate UID` failure, the wrapper prints actionable remediation guidance
   (detection + guidance only; the one-time data repair is explicitly out of scope).

Then every trigger *within this repo's control* — the notmuch `preNew` hook and aerc's `$` keybind —
is repointed at this wrapper. The Neovim `<leader>me`/`<leader>mN` repoint is an explicit non-goal
here (separate nvim-repo task), only needing to be *inventoried*, not touched.

## Findings

### 1. Current state of `modules/home/email/`

**Directory layout** (`modules/home/email/`):
```
notmuch.nix              -- programs.notmuch (Home Manager module), preNew/postNew hooks
mbsync.nix                -- .mbsyncrc file content + email-freeze/email-thaw operator helpers
aerc.nix                   -- programs.aerc (Home Manager module), keybinds incl. `$`
protonmail.nix             -- (not read in depth; Proton Bridge service config, out of scope)
agent-tools/
  default.nix              -- imports the 5 per-binary modules (task-88 split)
  lib.nix                  -- shared preamble builders: mkPreamble, mkMutationPreamble
  census.nix               -- email-census (read-only)
  classify.nix             -- email-classify
  archive-confirmed.nix    -- email-archive-confirmed (mutation; calls run_mbsync_reconcile)
  delete-confirmed.nix     -- email-delete-confirmed (mutation; calls run_mbsync_reconcile)
  unsubscribe-extract.nix  -- email-unsubscribe-extract
```

**Wiring**: `modules/home/default.nix` imports `./email/mbsync.nix`, `./email/protonmail.nix`,
`./email/notmuch.nix`, `./email/aerc.nix`, `./email/agent-tools` (directory import resolves to its
`default.nix`), plus `./packages/email-tools.nix` (the `mbsync-with-xoauth2` override, not
directly relevant here).

**Nix build pattern used for every wrapper binary today**: `pkgs.writeShellScriptBin "<name>" ''
...''` appended to `home.packages`, with `set -euo pipefail` as the first line of the script body.
No binary in this codebase uses `pkgs.writeShellApplication` — `writeShellScriptBin` is the
established convention and the new `mail-sync` wrapper should follow it for consistency (though
`writeShellApplication` would add automatic `shellcheck` + declared `runtimeInputs`, which is a
minor nice-to-have, not required to match existing style).

**PATH handling**: none of the existing wrappers declare explicit `runtimeInputs`/`PATH`
prepends — they rely on the ambient Home Manager PATH (which already includes `mbsync`,
`notmuch`, `himalaya`, `jq`, `secret-tool`, etc., installed via the other email/tooling modules).
The new wrapper should do the same (rely on ambient PATH from `home.packages`/`programs.*`), since
`mbsync` and `notmuch` are already guaranteed present via `mbsync.nix`'s `.mbsyncrc` config and
`notmuch.nix`'s `programs.notmuch.enable = true`.

**Where the mbsync channels/groups are defined**: entirely in `modules/home/email/mbsync.nix`,
inside a single `home.file.".mbsyncrc".text` heredoc (not a native Home Manager
`programs.mbsync`-style option set — this project hand-writes `.mbsyncrc` as a literal file).
Relevant groups:
- `Group gmail` (lines ~114-119): `gmail-inbox`, `gmail-sent`, `gmail-drafts`, `gmail-all`,
  `gmail-folders`. Deliberately excludes `gmail-trash`/`gmail-spam` (not IMAP-selectable, would
  abort the whole group with exit 1).
- `Group logos` (lines ~211-217): `logos-inbox`, `logos-sent`, `logos-drafts`, `logos-trash`,
  `logos-archive`, `logos-folders`. Deliberately excludes `logos-labels` (Proton label-mirroring
  causes Maildir++ dotted-name crashes and 86% file duplication; task 826 fix, referenced in
  the comment at lines 172-180).
- `Group logos-full` (lines ~223-230): on-demand full sync including `logos-labels`, never
  invoked by any keymap or wrapper — explicitly out of the agent/wrapper reconcile path.

**What the notmuch preNew hook currently runs** (`notmuch.nix` lines 19-37):
```nix
preNew = "mbsync gmail logos || true";
```
The `|| true` swallows mbsync's exit code entirely (documented rationale: mbsync exits 1 on
partial/transient failures — e.g. the known duplicate-UID collision — and without the tolerance
ANY hook-having `notmuch new` would abort both preNew and postNew). This is precisely the loop
task 109 flags: any hook-ful `notmuch new` (i.e. one that doesn't pass `--no-hooks`) silently
re-triggers a full `mbsync gmail logos` synchronously inside notmuch's own hook execution, with no
lock, no serialization with any concurrently-running mbsync from another trigger.

**How aerc's `$` keybind is currently defined** (`aerc.nix` line 123, `messages` bind context):
```nix
"$" = ":exec mbsync gmail && notmuch new --no-hooks<Enter>";
```
Note: **gmail-only** — Logos is not synced by this keybind at all today. The comment at lines
119-122 documents the task-72-Phase-9 rebind rationale (previously `mbsync -a && notmuch new`,
rebound because `-a` is the same freeze-blast-radius hazard as the preNew hook, and hook-ful
`notmuch new` would re-trigger preNew's own `mbsync -a`). This keybind is a good template for what
`mail-sync`'s internal notmuch-reindex step should look like, but a canonical `mail-sync` wrapper
should let the caller pick group(s) (gmail, logos, or "both", i.e. what the preNew hook needs)
rather than hardcoding gmail only.

**Agent-tools wrapper pattern** (`agent-tools/lib.nix`): every one of the 5 binaries is built by
interpolating `mkPreamble {...}` (read-only class) or `mkMutationPreamble {...}` (mutation class,
extends the read-only preamble) directly into a `pkgs.writeShellScriptBin` body — never
`source`d from an external file, so each produced binary is self-contained (deliberate two-layer
enforcement design: `mail-guard.sh` allowlists by binary NAME only, so a binary depending on a
separately-writable sourced script would be an unguarded escape hatch). The mutation preamble
already contains a `run_mbsync_reconcile()` bash function (lines 311-339 of `lib.nix`) that:
- Logs "Reconciling with 'mbsync $ACCOUNT_MBSYNC_GROUP' (group-scoped; NEVER mbsync -a...)"
- Runs `mbsync "$ACCOUNT_MBSYNC_GROUP"` capturing stdout+stderr and exit status
- On failure, distinguishes an auth failure (`invalid_grant` / `[AUTHENTICATIONFAILED] Invalid
  credentials` regex match) from any other failure, printing different remediation text for each
- On success, logs "reconcile OK"

This `run_mbsync_reconcile` function is the closest existing precedent for `mail-sync`'s core
logic, but it (a) has no flock, (b) is only invoked from inside the two mutation wrappers after
their own manifest-execute step (not standalone), and (c) has no duplicate-UID-specific
detection branch (only the auth-failure branch is special-cased; a generic non-zero exit
just says "inspect the output above").

### 2. Trigger inventory

| Trigger | Location | Current command | Uses `-a`? | Hook-ful `notmuch new`? | In scope to repoint |
|---|---|---|---|---|---|
| notmuch preNew hook | `modules/home/email/notmuch.nix:37` | `mbsync gmail logos \|\| true` | No (already group-scoped) | N/A (it *is* the hook) | Yes — repoint to call `mail-sync` for both groups |
| aerc `$` keybind | `modules/home/email/aerc.nix:123` | `mbsync gmail && notmuch new --no-hooks` | No | No (already `--no-hooks`) | Yes — repoint to call `mail-sync gmail` (or add Logos too) |
| Neovim `<leader>me` | separate nvim repo (external) | `mbsync -a` + hook-ful `notmuch new` (per task description) | **Yes** | **Yes** | **No** — explicit non-goal; companion nvim-repo task only |
| Neovim `<leader>mN` | separate nvim repo (external) | same pattern as `<leader>me` (per task description) | **Yes** | **Yes** | **No** — same as above |
| `email-thaw` (`mbsync.nix`) | operator helper, task 72 Phase 8 | `mbsync gmail` only (group-scoped, no lock) | No | N/A | Not mentioned by task description; consider whether it should call `mail-sync` internally for consistency, but out of the explicit deliverable list — flag as an open question for the plan |
| `run_mbsync_reconcile` (agent-tools `lib.nix`) | called from `archive-confirmed.nix` / `delete-confirmed.nix` mutation wrappers | `mbsync "$ACCOUNT_MBSYNC_GROUP"` (no lock) | No | N/A | Same open question as `email-thaw` — these already run under the mutation wrappers' own manifest-hash gate, but still race with e.g. aerc's `$` if a human presses `$` mid-mutation |
| Manual invocation | any terminal | `mbsync <anything>`, incl. accidentally `-a` | Possible | N/A | Cannot be prevented at the nix layer beyond providing `mail-sync` as the documented/easy path; `mail-guard.sh`'s deny-patterns don't currently block bare `mbsync` calls (Layer 1 only gates the agent's own Bash tool calls, not a human's terminal) |
| systemd timer | none exists | N/A | N/A | N/A | Confirmed absent — `mbsync.nix` and `email-freeze` comments explicitly document "there is NO mbsync systemd timer" as a verified fact from task 72 Phase 1 baseline |

Key structural point for the plan: **only two in-repo call sites need to change** (notmuch preNew
hook, aerc `$` keybind) to satisfy the explicit deliverable. `email-thaw` and
`run_mbsync_reconcile` are additional latent race sources not named in the task description —
worth flagging in the plan as an optional Phase (or explicitly deferring per the task's own
non-goals framing), since the task says "every sync trigger" but its own enumerated inventory list
names only preNew hook + aerc `$` + Neovim keys + manual invocation.

### 3. flock-based mutual exclusion pattern

Canonical POSIX-shell self-exclusive-lock idiom (bash, using an fd redirect + `flock`):

```bash
LOCKFILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/mail-sync.lock"
exec {LOCK_FD}>"$LOCKFILE"
if ! flock -w 300 "$LOCK_FD"; then
  echo "[mail-sync] ERROR: could not acquire lock within 300s (another sync stuck?)" >&2
  exit 1
fi
# ... critical section: mbsync <group> && notmuch new --no-hooks ...
# lock auto-released when $LOCK_FD closes at script exit (or explicit `flock -u "$LOCK_FD"`)
```

Design choices and rationale:

- **Lockfile location**: `$XDG_RUNTIME_DIR` (tmpfs, per-login-session, auto-cleaned on logout) is
  preferred over `$HOME/.cache` or a path under `~/Mail` — it avoids leaving stale lock state
  across reboots and avoids any risk of the lockfile itself living inside a synced/backed-up
  directory. Fall back to `$HOME/.cache/mail-sync` if `XDG_RUNTIME_DIR` is unset (e.g. non-systemd
  session), matching the existing fallback idiom already used in this codebase
  (`"${XDG_STATE_HOME:-$HOME/.local/state}/email-agent"` in `email-reindex`).
- **`exec {fd}>lockfile` (numeric auto-alloc, bash 4+) vs a fixed FD number**: prefer the
  `{LOCK_FD}` bash auto-allocation form — it avoids collisions with any FD the script or its
  subshells might already use, and is the modern idiomatic form (the older `9>lockfile; flock 9`
  convention hardcodes FD 9, which is fine here too since this script has no other FD usage, but
  the auto-alloc form is slightly more defensive).
- **Blocking vs `-n` (fail-fast)**: **recommend blocking with a timeout** (`flock -w <seconds>`),
  not fail-fast (`flock -n`). Rationale: the two real-world triggers being repointed are (a) an
  automatic hook fired synchronously inside `notmuch new`, and (b) an interactive aerc keypress.
  In both cases, silently *dropping* a legitimate sync request (fail-fast behavior) is worse than
  making the caller wait briefly — mbsync group syncs are typically fast (seconds), and the whole
  point of task 109 is that concurrent runs currently corrupt state rather than queue safely. A
  bounded wait (`-w 300` or similar, tunable) avoids a truly-stuck lock (e.g. a hung network mbsync
  process) blocking forever, while still serializing the common case. Pure fail-fast (`-n`) is
  worth exposing as an optional flag (e.g. `--no-wait`) for callers (like a future CI/test harness)
  that want to detect contention immediately rather than wait, but should not be the default.
- **Group serialization for "both" invocations**: when the wrapper is asked to sync both
  `gmail` and `logos` (the preNew-hook use case, which currently runs `mbsync gmail logos` as a
  single mbsync invocation covering both groups), the simplest safe design is to take the SAME
  single lock and run `mbsync gmail && mbsync logos` sequentially inside the one locked critical
  section (mirroring what a single `mbsync gmail logos` invocation already does — mbsync itself
  processes multiple named groups/channels sequentially within one process). This keeps "one
  lockfile, no two mbsync runs overlap regardless of trigger" simple and avoids needing per-group
  sub-locks; a caller wanting only one account still passes just that one group name.

### 4. Group-scoped-only enforcement (structurally preventing `mbsync -a`)

Recommended enforcement pattern, modeled directly on `agent-tools/lib.nix`'s existing
`--account {gmail,logos}` allowlist-and-reject idiom (lines 106-124 of `lib.nix`):

```bash
case "$1" in
  gmail|logos|both) GROUPS=... ;;
  *)
    echo "[mail-sync] ERROR: mail-sync only accepts 'gmail', 'logos', or 'both' (got: '${1:-}')" >&2
    echo "[mail-sync] mbsync -a (all channels) is never invoked by this wrapper." >&2
    exit 1
    ;;
esac
```

The wrapper's shell body must **never contain the literal substring `mbsync -a`** or any code path
that could construct it (e.g. no `mbsync "$@"` passthrough of arbitrary arguments to mbsync) —
the only `mbsync` invocations in the script body are the two literal, hardcoded forms
`mbsync gmail` and `mbsync logos`, selected by the validated positional/flag argument. This mirrors
the existing case-statement dispatch in `lib.nix`'s `mkPreamble` (lines 106-124) that maps
`gmail`/`logos` to `ACCOUNT_MBSYNC_GROUP` and rejects anything else outright — reusing that same
allowlist-and-reject shape (rather than inventing a new one) keeps the new wrapper consistent with
the existing five binaries' style, satisfying the plan's likely code-review expectations even
though `mail-sync` is not part of that 5-binary contract itself.

An explicit non-requirement worth noting for the plan: the wrapper does NOT need to reject the
literal string `-a` as a *user-supplied* argument via string matching (that would be a weaker,
bypassable defense) — the real structural guarantee comes from the allowlist `case` statement only
ever branching to the two hardcoded `mbsync gmail`/`mbsync logos` invocations, so there is no
code path through which `-a` (or any other raw mbsync flag) could reach the `mbsync` call at all.

### 5. duplicate-UID detection/remediation

**What the error looks like** (verified precedent, task 092 diagnosis report, live mbsync output):
```
Maildir error: duplicate UID 3 in /home/benjamin/Mail/Logos//.Trash.
Maildir error: duplicate UID 1 in /home/benjamin/Mail/Logos//.Archive.
```
Root cause pattern (from the task 092 investigation): two maildir filenames under the same folder
both carry the same `,U=N:` token, e.g.:
```
1770669071.1006834_3.hamsa,U=3:2,
1770669126.1007943_17.hamsa,U=3:2,S
```
mbsync treats this as fatal for that channel/group and the whole named group invocation exits 1
(other channels in the group may have already synced successfully before the fatal channel is
hit — per the task 092 finding, INBOX had already reconciled by the time the labels channel died).

**Recommended detection + remediation approach for `mail-sync`** (detection/guidance ONLY, no
repair — repair is an explicit non-goal):
1. Capture mbsync's combined stdout+stderr (`set +e; OUT=$(mbsync "$GROUP" 2>&1); STATUS=$?; set -e`),
   matching the existing `run_mbsync_reconcile`/`email-thaw` capture idiom already used twice in
   this codebase.
2. On non-zero exit, grep the captured output for the pattern
   `grep -qE 'Maildir error: duplicate UID [0-9]+ in'`.
3. If matched, extract the offending folder path(s) via `grep -oE 'duplicate UID [0-9]+ in [^.]+\.'`
   (or similar) and print an actionable message naming the specific folder(s), e.g.:
   ```
   [mail-sync] DUPLICATE UID detected in: /home/benjamin/Mail/Logos/.Trash
   [mail-sync] This is a known Maildir corruption mode (not caused by this run necessarily —
   [mail-sync] two files in that folder share the same ,U=N: token). This wrapper does NOT
   [mail-sync] repair Maildir state automatically. To investigate:
   [mail-sync]   1. ls -la <folder>/cur/ | grep ',U=<N>:'   # find the colliding pair
   [mail-sync]   2. Inspect both files; if one is a true duplicate, remove or rename it, or
   [mail-sync]      reset the folder's .mbsyncstate to force UID renumbering on next sync.
   [mail-sync]   3. Do this deliberately, not ad-hoc -- see task 092 diagnosis for a worked example.
   [mail-sync] Other channels in this group may have already synced successfully; this failure
   [mail-sync] does not necessarily mean nothing was synced.
   ```
4. If the failure does NOT match the duplicate-UID pattern, fall back to the existing generic
   "inspect the output above" style already used by `run_mbsync_reconcile`/`email-thaw`, plus the
   existing auth-failure special-case branch (`invalid_grant` / `[AUTHENTICATIONFAILED]`) which
   should be preserved/reused verbatim since it is independently valuable and already proven.
5. **A detector/repair *helper* alongside `census.nix`** is offered as an alternative/complement
   by the task description ("or invokes a detector/repair helper alongside census.nix"). Given
   census.nix is a read-only reporting binary (`email-census`), the natural analog would be a
   read-only `mail-sync-status` or an extension of `email-census`'s existing freshness-reporting
   section to also scan for `,U=` collisions per folder proactively (independent of an actual
   mbsync failure) — this is a reasonable Phase-2/optional enhancement, but the core task-109
   deliverable is satisfied by inline detection in `mail-sync` itself per points 1-4 above; a
   separate detector binary is not strictly required to meet the stated deliverable and should be
   scoped as optional in the plan rather than mandatory, to keep the wrapper count minimal.

### 6. Verification approach

**`nix flake check`**: run from the repo root (`/home/benjamin/.dotfiles`). The flake defines
`nixosConfigurations`, a standalone `homeConfigurations.benjamin` (via
`home-manager.lib.homeManagerConfiguration`), `formatter.${system}` (nixfmt), and
`devShells.${system}.default` — there is no explicit `checks.<system>` output, so `nix flake check`
primarily validates flake-level evaluation (syntax, that all outputs evaluate) rather than running
a dedicated test suite. This is fast and should be run after any edit to
`modules/home/email/*.nix` or a new `modules/home/email/mail-sync.nix`.

Fuller build-level verification (per the existing nix-implementation-agent convention documented
in this repo's archived task 7/8 plans, "prefer flake check (fast), full builds for final
verification"):
```bash
nix flake check                                    # fast: syntax + evaluation
home-manager build --flake .#benjamin               # builds the standalone home-manager closure,
                                                     # exercising modules/home/email/* end-to-end
                                                     # without requiring `switch`/root/live creds
```
`home-manager build` (not `switch`) is the safe verification step — it builds the derivation
(confirming `pkgs.writeShellScriptBin` compiles the new wrapper's shell body without syntax errors)
without activating it on the live system or requiring IMAP credentials to be present.

**Concurrency test construction**: the real `mbsync` requires live credentials and network access,
so a credential-free concurrency test should stub `mbsync` rather than exercise the real network
sync. Recommended approach:
1. Write a test harness script (not part of the nix module) that creates a temporary `PATH`
   directory containing a fake `mbsync` executable — e.g. a shell script that appends its PID +
   start-timestamp to a shared log file, sleeps 2-3 seconds (simulating sync duration), then
   appends its PID + end-timestamp, and exits 0.
2. Launch two `mail-sync gmail` invocations (with that temp directory prepended to `PATH` so the
   wrapper's `mbsync` calls resolve to the stub) at near-simultaneous wall-clock time (e.g.
   backgrounded with `&` a few milliseconds apart, or via `xargs -P2`).
3. Assert from the shared log file that the two invocations' [start, end] intervals do NOT
   overlap — i.e. invocation B's start timestamp is >= invocation A's end timestamp (or vice
   versa). This directly demonstrates flock serialization without touching real mail.
4. A secondary assertion: confirm the lockfile path exists after the run and that both wrapper
   invocations exited 0 (no corruption/error surfaced), matching the task's "must serialize rather
   than corrupt" requirement.

This test can live as a standalone script (e.g. `.claude/scripts/` or a `tests/` dir if one exists
in this repo — none was found; a new lightweight script under the task's own artifacts or under
`modules/home/email/` as a `checkPhase`-style script is reasonable) invoked manually during
implementation verification; it is not necessarily wired into `nix flake check` itself (which has
no `checks` output in this flake) unless the plan chooses to add one via a `pkgs.runCommand` test
derivation — that would be a nice-to-have but is not required for task 109's stated verification
bar ("Verify with `nix flake check` and a concurrency test", read as two separate, sequential
verification steps rather than one integrated check).

## Decisions

- Build `mail-sync` using `pkgs.writeShellScriptBin` (matching every existing wrapper in this
  codebase), NOT `pkgs.writeShellApplication`, for stylistic consistency with
  `mbsync.nix`/`agent-tools/*.nix`.
- Reuse the existing `Group gmail` / `Group logos` names from `mbsync.nix` verbatim — do not
  invent new mbsync groups; `mail-sync` is purely a call-site consolidation + locking wrapper, not
  a change to sync scope.
- `mail-sync` is a **sanctioned non-wrapper exception** alongside `email-reindex` and the
  group-scoped `mbsync` reconcile already named in CLAUDE.md — not a sixth member of the frozen
  5-binary `mail-guard.sh` allowlist contract. It performs index/sync only, never mail mutation
  (delete/archive/move), so it does not need to go through the propose-review-confirm-execute
  manifest gate that the two mutation wrappers use.
- Recommend blocking flock with a bounded wait (e.g. 300s) as the default; a `--no-wait` fail-fast
  flag is a reasonable optional addition but not the default.
- Lockfile path: `${XDG_RUNTIME_DIR:-$HOME/.cache}/mail-sync.lock` (or a subdirectory consistent
  with this repo's existing `${XDG_STATE_HOME:-$HOME/.local/state}/email-agent` naming pattern —
  the plan should pick one and note the fallback chain explicitly).
- Duplicate-UID handling is detection + actionable message only, inline in `mail-sync`'s failure
  path; a separate detector/repair helper alongside `census.nix` is optional/deferred, not
  required to satisfy the task's deliverable.
- In-repo call sites to repoint: notmuch `preNew` hook (`notmuch.nix`) and aerc's `$` keybind
  (`aerc.nix`). The Neovim `<leader>me`/`<leader>mN` repoint is explicitly out of scope (separate
  nvim-repo task, to be created/tracked separately per the task's own framing).
- `email-thaw` and `run_mbsync_reconcile` (used by `archive-confirmed.nix`/`delete-confirmed.nix`)
  are NOT named in the task's explicit trigger-repoint list; flag as an open question for the
  planner whether these should also route through `mail-sync`'s lock for full "no two mbsync runs
  can overlap regardless of trigger" coverage, or whether that is deferred to a follow-up task.

## Risks & Mitigations

- **Risk**: repointing the preNew hook to a blocking-wait `mail-sync` could make `notmuch new`
  (any hook-ful invocation) hang for up to the wait timeout if a stuck mbsync process is holding
  the lock. *Mitigation*: bounded wait (not infinite), plus the existing `preNew = "... || true"`
  tolerance pattern should be preserved so a `mail-sync` timeout/failure still doesn't abort the
  whole `notmuch new` run.
- **Risk**: if `mail-sync`'s internal reindex step (`notmuch new --no-hooks`) is added inside the
  SAME lock as the mbsync call, and the preNew hook itself calls `mail-sync` (which internally
  calls `notmuch new --no-hooks`), there is no reentrancy hazard since `--no-hooks` skips preNew
  entirely — but this should be explicitly tested/verified during implementation, not assumed.
- **Risk**: `home.file.".mbsyncrc"` and the wrapper are both declared in `modules/home/email/`,
  but if `mail-sync` is placed in a NEW file (e.g. `modules/home/email/mail-sync.nix`), it must be
  added to `modules/home/default.nix`'s import list or it won't be built at all — confirm this
  during implementation (mirrors how `agent-tools` needed its own import line).
- **Risk**: the concurrency test's stubbed-`mbsync` approach only proves flock serializes wrapper
  invocations; it does NOT prove the real mbsync/duplicate-UID interaction end-to-end (that would
  require live credentials or a maildir fixture). This is an acceptable scope boundary given the
  task's own non-goal framing (data repair is out of scope) — the plan should state this
  limitation explicitly rather than imply live-credential testing was performed.

## Appendix

### Files read
- `modules/home/email/notmuch.nix`
- `modules/home/email/mbsync.nix`
- `modules/home/email/aerc.nix`
- `modules/home/email/agent-tools/lib.nix`
- `modules/home/email/agent-tools/census.nix`
- `modules/home/email/agent-tools/default.nix`
- `.claude/hooks/mail-guard.sh`
- `flake.nix` (homeConfigurations/checks structure)
- `specs/archive/092_logos_mbsync_group_labels_fix/reports/01_mbsync-logos-diagnosis.md`
  (duplicate-UID precedent)
- `.claude/CLAUDE.md` Email Extension section (wrapper-only doctrine, sanctioned non-wrapper
  exceptions)

### Searches performed
- `grep -rn "mbsync"` across `modules/` and repo root to confirm no systemd timer/service exists
- `find` for `*.timer`/`*systemd*mail*` (none related to mail; only `claude-refresh.timer`)
- `grep -rln "flock"` across the repo (no existing flock usage found anywhere)
- `grep -rn "duplicate UID"` across `specs/` (found the task-092 precedent, only known live
  occurrence documented in this repo)
- `grep -rln "mail-sync\|mailSync"` (confirmed no wrapper of this name exists yet; only mentions
  are in specs/TODO.md and specs/state.json for task 109 itself, and unrelated archived reports)

### Open questions for the planner
1. Should `email-thaw` and the two mutation wrappers' `run_mbsync_reconcile` also acquire
   `mail-sync`'s lock (full coverage), or is that explicitly deferred since the task's own trigger
   inventory doesn't name them?
2. Should the aerc `$` keybind sync Logos too (today it's gmail-only), given the new wrapper makes
   a "both" mode trivial? This wasn't in scope of task 109's ask but is a natural adjacent
   improvement worth flagging as optional.
3. Exact lockfile path convention — `$XDG_RUNTIME_DIR` vs `$XDG_STATE_HOME`-style — should be
   decided once and documented, matching this repo's existing fallback-chain idioms.
