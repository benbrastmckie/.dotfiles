# Research Report: Task #83

**Task**: 83 - Fix git hygiene in the NixOS/Home Manager dotfiles repo (task 81 Tier 0, subtask blueprint #2)
**Started**: 2026-07-04T19:07:00-07:00
**Completed**: 2026-07-04T19:14:00-07:00
**Effort**: Small (no-dependency, near-zero-risk hygiene subtask)
**Dependencies**: None (Tier 0, fully parallel with tasks 82, 84, 85)
**Sources/Inputs**: Live repo inspection (`git status`, `git ls-files`, `git check-ignore`, `git log`), `.claude/scripts/skill-base.sh`, `update.sh`, `.gitignore`, task 81 seed report and team-research report, `specs/081_.../design/target-layout.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three files (`specs/tmp/claude-tts-notify.log`, `specs/tmp/claude-tts-last-notify`,
  `specs/tmp/lit.md`) are confirmed **tracked** in git (`git ls-files` lists all three;
  `git check-ignore -v` returns nothing for any of them — no existing ignore rule covers them).
  `claude-tts-notify.log` is currently modified in the working tree (`git status --porcelain`
  shows ` M specs/tmp/claude-tts-notify.log`), confirming the "perpetually dirty tree" problem
  from the seed report.
- `update.sh` has exactly two mangled-heredoc artifacts, confirmed byte-for-byte: line 1 is
  `#\!/bin/bash` (literal backslash before `!`, not a valid shebang) and line 55 is
  `echo "===> Dotfiles update complete\!"` (stray literal backslash before `!`). No other lines
  in the file are affected.
- `skill-base.sh`'s `skill_link_artifacts` function (lines 344-366) has a **hard, unguarded
  dependency** on `specs/tmp/` existing: lines 356 and 362 both redirect
  `jq ... specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json`
  with **no `mkdir -p` guard**, unlike every other script that touches `specs/tmp/`
  (`update-task-status.sh`, `manage-topics.sh`, `reconcile-artifacts.sh`,
  `reconcile-task-status.sh`, `roadmap-sync.sh`, `setup-lean-mcp.sh` all call `mkdir -p` first).
  This is the single point of failure the Critic correction is protecting against — if
  `specs/tmp/` disappears, `skill_link_artifacts` fails hard mid-write with no defensive
  recovery.
- Recommended fix: `git rm --cached` the three files (working-tree copies are untouched by
  `--cached`, so nothing is lost), add a `specs/tmp/*` + `!specs/tmp/.gitkeep` ignore pair to
  `.gitignore`, and create `specs/tmp/.gitkeep` (tracked) so the directory survives fresh
  clones/checkouts even after all its current contents become gitignored.
- Bonus finding (in-scope, since `.gitignore` is explicitly touched by this subtask): the
  existing `.gitignore` already has its own mangled-heredoc artifact — a duplicate `.direnv/`
  entry (lines 27 and 31) followed by a stray line 32 reading literally `EOF < /dev/null`. This
  is the same failure signature as `update.sh`'s mangled shebang (a heredoc write where `!`
  triggered history-expansion/`< /dev/null` injection — the same class of issue documented in
  `.claude/context/patterns/jq-escaping-workarounds.md` for `!=` in jq, generalized to shell
  heredocs). Recommend cleaning this stray line up in the same edit that adds the `specs/tmp/`
  rule, since it sits in the exact file this subtask is already modifying.

## Context & Scope

This is subtask #2 (blueprint numbering) / real task 83 of task 81's Tier-0 git-hygiene work,
per `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md` §3 row 2 and
§6 row 2. Scope is explicitly bounded to:
- `specs/tmp/` contents (untrack, gitignore) — directory itself must survive on disk
- `.gitignore` (extend to cover `specs/tmp/` contents)
- `update.sh` at its **current root location** (task 85, serialized to run after this task,
  will later move it into `scripts/` — this task fixes it in place, not in a new location)

Out of scope: any other content under `specs/`, `.claude/`, or the Nix-managed tree
(`modules/`, `hosts/`, `config/`, `overlays/`, `lib/`, `packages/`). No dependencies block this
subtask; it is fully parallel with tasks 82, 84, 85.

The design doc's cross-cutting protocol (target-layout.md §4.1) requires `git add <specific
paths>` (never `git add -A`) before running the nix verification harness, because
`flake.nix:96` sets `root = self`, so `nix flake check` / `nixos-rebuild build` only see
git-tracked content. This subtask's own verification is "build-only inertness" per the design
table (row 2): `git status --porcelain` clean on `specs/tmp/` contents, directory still present,
`./update.sh` still executes, `nix flake check` green — no build/closure diffing is required
since nothing under the Nix-managed tree changes.

## Findings

### Existing Configuration — specs/tmp/ tracked-file state

```
$ git ls-files specs/tmp/
specs/tmp/claude-tts-last-notify
specs/tmp/claude-tts-notify.log
specs/tmp/lit.md

$ git status --porcelain specs/tmp/
 M specs/tmp/claude-tts-notify.log

$ git check-ignore -v specs/tmp/claude-tts-notify.log specs/tmp/claude-tts-last-notify specs/tmp/lit.md
(no output — none of the three files are currently ignored by any existing rule)
```

All three files are confirmed tracked and none is covered by any existing `.gitignore` pattern.
`claude-tts-notify.log` (a TTS notification hook log, 26.9 KB, last modified minutes before this
report) is the file actively causing tree churn; `claude-tts-last-notify` (11 bytes) is a small
state marker for the same hook; `lit.md` (5.4 KB, last modified 2026-07-03) is confirmed — per
both the task 81 team-research Critic correction and direct content inspection — to be an
unrelated mbsync/IMAP troubleshooting note that happens to share a name with `--lit` tooling; it
requires no decoupling, only untracking like the other two.

`git log --oneline -- specs/tmp/claude-tts-notify.log specs/tmp/claude-tts-last-notify
specs/tmp/lit.md` shows these files churning across dozens of unrelated task commits going back
to task 59-era history (including several `checkpoint: auto-commit before update` commits from
`update.sh`'s own auto-checkpoint logic), confirming the "perpetually dirty tree" diagnosis from
the seed report (`01_repo-organization-review.md:162-166`).

### .gitignore — current state and required extension

Current full contents (32 lines) confirmed via direct read:

```
 1  # Nix build outputs
 2  result
 3  result-*
 4
 5  # Temporary files
 6  *.swp
 7  *.swo
 8  *~
 9  \#*\#
10  .\#*
11
12  # OS generated files
13  .DS_Store
...
26  # Direnv
27  .direnv/
28  .envrc
29
30  # Flake
31  .direnv/
32  EOF < /dev/null
33
34  # Secrets
35  config/rclone.conf
36  config/zuliprc
37
38  # Agent system directories — untracked and scrubbed from git history 2026-07-02.
39  # Kept on disk (gitignored), not version-controlled here.
40  /.claude/
41  /.opencode/
```

No existing entry covers `specs/tmp/`, `specs/`, or any tmp/scratch directory pattern. The
required addition is a new stanza, e.g.:

```
# Task-system scratch space — directory must persist (skill-base.sh atomic-write dependency)
specs/tmp/*
!specs/tmp/.gitkeep
```

The `specs/tmp/*` + negated `.gitkeep` pattern (rather than a bare `specs/tmp/` directory-level
ignore) is the correct choice here specifically *because* the directory itself must continue to
exist and be reconstructable from a fresh clone. A bare `specs/tmp/` ignore would still leave the
directory present on the *current* disk (since `git rm --cached` never touches the working tree)
but would not guarantee the directory exists after a fresh `git clone` — nothing would be tracked
inside it. Adding a tracked `specs/tmp/.gitkeep` (empty file) alongside the negation line closes
that gap permanently.

Line 32's stray `EOF < /dev/null` (and the duplicate `.direnv/` at lines 27/31) is a pre-existing
mangled-heredoc artifact unrelated to this task's assigned untracking work, but it lives in the
exact file this subtask already edits and is the same failure class as `update.sh`'s mangled
shebang — worth a one-line cleanup in the same pass since it's already open, though not required
to satisfy the subtask's stated verification criteria.

### update.sh — confirmed mangled shebang and stray text

Full file read (55 lines) confirms exactly two artifacts:

- **Line 1**: `#\!/bin/bash` — a literal backslash-escaped `!`, not a valid POSIX shebang. As
  written, `env`/`execve` will not recognize `#\!` as a shebang prefix (it requires
  `#!` with no intervening characters), so `./update.sh` currently only works if invoked as
  `bash update.sh` or if the caller's shell falls back to sh-execution on shebang-parse failure.
  Fix: replace with plain `#!/bin/bash`.
- **Line 55**: `echo "===> Dotfiles update complete\!"` — cosmetic only (prints a literal
  backslash before the exclamation mark in terminal output), but confirms the same mangled-write
  origin (a heredoc `cat <<'EOF'`-style script write where the historical write path improperly
  escaped `!`, matching the `.gitignore` artifact and the general `!=`/`!`-escaping class
  documented in `.claude/context/patterns/jq-escaping-workarounds.md`). Fix: replace with
  `echo "===> Dotfiles update complete!"`.

No other lines are affected — `grep -n "complete"` returns only line 55, and `cat -A` inspection
of the full file shows no other stray backslash-escaped characters.

Per the coordination note in the task description, this subtask fixes `update.sh` **at its
current root-level path** (`/home/benjamin/.dotfiles/update.sh`). Task 85 (serialized to run
after this task) will later move the already-fixed file into `scripts/update.sh` and update
doc references — no forward-looking path changes belong in this subtask.

### skill-base.sh — confirmed dependency on specs/tmp/ directory existing

`skill_link_artifacts()` (`.claude/scripts/skill-base.sh:344-366`) is called from
`skill_cleanup`-adjacent postflight flows to update `state.json`'s artifacts array. Its
two-step jq pattern (documented as "safe" for Issue #1132 `!=` escaping) writes intermediate
output directly to `specs/tmp/state.json`:

```bash
# line 356:
specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
# line 362 (second step, same pattern):
specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Neither line is preceded by `mkdir -p specs/tmp` inside this function or anywhere earlier in
`skill-base.sh`. This is a genuine, unguarded dependency: if `specs/tmp/` did not exist on disk,
the `jq ... > specs/tmp/state.json` redirect would fail (bash cannot open a file for writing in a
nonexistent directory), the `&&` would short-circuit, and `state.json` would be left in its prior
state without producing the intended artifact-link update — a silent-ish failure mode with no
recovery path in this function.

By contrast, every *other* script under `.claude/scripts/` that writes into `specs/tmp/`
defensively calls `mkdir -p` first:
- `update-task-status.sh:147` — `mkdir -p "$TMP_DIR"` before any `$TMP_DIR` writes
- `manage-topics.sh:48` — same pattern
- `reconcile-artifacts.sh:126`, `reconcile-task-status.sh:124` — `mkdir -p` inline before use
- `setup-lean-mcp.sh:75` — `mkdir -p specs/tmp` before `mktemp -p specs/tmp ...`
- `roadmap-sync.sh:89,298` — `mkdir -p` before use

`skill-base.sh`'s two call sites are the sole exception, and they are on a hot path exercised by
essentially every `/research`, `/plan`, and `/implement` postflight — which is exactly why the
Critic flagged "the `specs/tmp/` directory itself must continue to exist on disk" as a hard
correction to the seed report's "just untrack and gitignore it" framing: a naive
directory-level `.gitignore` entry combined with a fresh clone (no working-tree files left to
keep the directory alive) would silently break this function the first time any skill tried to
link an artifact.

### Verification path (build-only inertness, per design table)

The subtask's verification bar (target-layout.md row 2, and blueprint report 02 row 2) is:
1. `git status --porcelain` clean on `specs/tmp/` contents — achieved once the three files are
   `git rm --cached`'d and `.gitignore` covers them (their now-untracked working-tree copies
   stop appearing as modified/untracked, since they match the new ignore pattern).
2. `specs/tmp/` directory still present on disk — true immediately after `git rm --cached`
   (working tree is untouched by `--cached`), and durably true going forward once
   `specs/tmp/.gitkeep` is added and tracked.
3. `./update.sh` still executes — verify post-fix with `bash -n update.sh` (syntax check) and,
   if safe/non-destructive in this environment, `./update.sh --no-check` up to the point before
   any actual `nixos-rebuild switch`/`home-manager switch` invocation; at minimum confirm the
   shebang line makes `./update.sh` (direct exec, not `bash update.sh`) work.
4. `nix flake check` green — this subtask touches nothing under the Nix-managed tree
   (`flake.nix`, `modules/`, `hosts/`, etc.), so this should be a no-op regression check, not a
   consequence of any actual Nix-tree change. Per target-layout.md §4.1, no `git add` of
   Nix-tree paths is needed for this subtask specifically, since none are touched — the git-add-
   before-verify protocol matters most for subtasks that move/create/delete files *inside* the
   `root = self` tree, which this one does not.

## Decisions

- Use the `specs/tmp/*` + `!specs/tmp/.gitkeep` gitignore pattern (rather than a bare
  `specs/tmp/` line) specifically to guarantee the directory survives fresh clones, satisfying
  the Critic's "directory itself must continue to exist on disk" correction durably, not just
  in the current working tree.
- `git rm --cached` (not `git rm`) is the correct operation for all three files — it removes
  them from the index/history-going-forward while leaving the working-tree copies untouched,
  which is required since `claude-tts-notify.log` and `claude-tts-last-notify` are live,
  actively-written runtime files that must keep existing on disk.
- `update.sh` is fixed **in place** at the repo root in this subtask; the move into `scripts/`
  is explicitly deferred to task 85, which is serialized to run after this task completes.
- The `.gitignore` line-32 `EOF < /dev/null` / duplicate `.direnv/` cleanup is recommended as a
  low-risk bonus fix bundled into the same edit (since `.gitignore` is already in scope and
  already being edited), but is not required by the subtask's stated verification bar and can
  be dropped without blocking completion if a stricter reading of scope is preferred.

## Risks & Mitigations

- **Risk**: Untracking `specs/tmp/lit.md` could be mistaken for `--lit` literature-tooling
  decoupling work. **Mitigation**: Confirmed via direct content/context inspection (and the
  task 81 Critic correction) that this file is an unrelated mbsync troubleshooting note; no
  `--lit`-related code, config, or documentation references `specs/tmp/lit.md` as a literature
  artifact. No decoupling action needed.
- **Risk**: A bare `.gitignore` directory-level ignore (`specs/tmp/`) could look sufficient but
  silently fail to preserve the directory across fresh clones, later breaking
  `skill_link_artifacts`. **Mitigation**: use the `specs/tmp/*` + `!specs/tmp/.gitkeep` pattern
  and add a tracked `.gitkeep` file, as detailed above.
- **Risk**: Editing `update.sh`'s shebang could be missed if only the visible/rendered text is
  inspected (the mangled `#\!/bin/bash` renders close to a normal shebang in many viewers).
  **Mitigation**: confirmed via `cat -A` byte-level inspection, showing the literal
  backslash-escape (`#\!/bin/bash$`) rather than a clean `#!/bin/bash$`.
- **Risk**: Scope creep into task 85's territory (moving `update.sh` into `scripts/`).
  **Mitigation**: explicitly fix `update.sh` at its current root path only; do not create or
  reference a `scripts/` directory in this subtask.

## Appendix

Commands used:
```
git status --porcelain specs/tmp/
git ls-files specs/tmp/
git check-ignore -v specs/tmp/claude-tts-notify.log specs/tmp/claude-tts-last-notify specs/tmp/lit.md
git log --oneline -- specs/tmp/claude-tts-notify.log specs/tmp/claude-tts-last-notify specs/tmp/lit.md
git log --oneline -- .gitignore
grep -n "complete" update.sh
cat -A update.sh | head -50
grep -n "root = self" flake.nix
grep -rn "specs/tmp" .claude/scripts/*.sh
ls -la specs/tmp/.gitkeep   # confirmed absent
```

References:
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/01_repo-organization-review.md:162-166`
- `specs/081_reorganize_nixos_dotfiles_repository_design/reports/02_team-research.md:22-24,156`
- `specs/081_reorganize_nixos_dotfiles_repository_design/design/target-layout.md:166,197-211,330-346`
- `.claude/scripts/skill-base.sh:344-366`
- `.claude/scripts/update-task-status.sh:30,147`
- `.claude/scripts/manage-topics.sh:36,48`
- `.claude/context/patterns/jq-escaping-workarounds.md`
