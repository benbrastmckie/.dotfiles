# Research Report: Task #93

**Task**: 93 - Make scripts/update.sh's automatic git checkpoint commit opt-in instead of default
**Started**: 2026-07-05T05:13:50Z
**Completed**: 2026-07-05T05:35:00Z
**Effort**: Small (single-file bash edit + doc updates, no Nix evaluation surface)
**Dependencies**: None (parent_task 85, already completed)
**Sources/Inputs**: scripts/update.sh (current source), specs/085 summary (deviation note),
  specs/083 summary (commit-attribution note), repo-wide grep for `update.sh` references,
  `.claude/rules/git-workflow.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `scripts/update.sh:7-17` unconditionally runs `git add -A && git commit` whenever
  `git diff-index --quiet HEAD --` reports a dirty tree — this is the sole hazard; nothing else
  in the script touches git.
- Two real incidents are on record: commit `6ba1f4e` (this script's own checkpoint absorbed
  task-85's uncommitted changes during a verification run) and commit `02f806d` (a *plain*
  `git commit` — not update.sh — swept task-83's staged files under task-92's message). Only
  the first is update.sh's own bug; the second corroborates the general "concurrent dirty tree +
  broad staging = misattribution" hazard class this task exists to close off in this script.
- Recommended fix: gate the checkpoint on an explicit `--checkpoint` flag or `UPDATE_CHECKPOINT=1`
  env var (default off). When dirty and the flag/env is absent, **refuse to proceed** with a clear
  stderr message and non-zero exit — this matches the task description's stated preference
  ("prefer refusing... rather than silently staging everything") and is the safer default under
  `set -e` since it can't leave a rebuild running unexpectedly on unreviewed changes.
- The existing `--update` (line 23) and `--no-check` (line 41) flags use fragile positional
  `"$1"`/`"$2"` string comparisons that don't compose (three independent flags can't all be
  passed in arbitrary order with the current pattern). Adding a third flag is the natural trigger
  to refactor to a single `for arg in "$@"` scan — low-risk, contained to this file, not
  Nix-evaluated.
- Six markdown files reference `./scripts/update.sh`'s checkpoint behavior or general usage;
  only **README.md:188** actually documents the checkpoint (`# checkpoints, updates flake inputs...`)
  and needs correction. **docs/development.md** has only a bare invocation (no checkpoint
  language) — the task's instruction to update it is best satisfied by adding a short "Maintenance
  script flags" pointer there (or confirming README.md's Maintenance section is the canonical
  place and cross-referencing it), since development.md currently documents no flags at all.
- No CI/hook/other script invokes `scripts/update.sh` programmatically — the exit-code/refusal
  behavior change has no known automated consumer to break.

## Context & Scope

Researched the exact current content of `scripts/update.sh`, the two cited historical incidents
(specs/085 and specs/083 summaries), every repo-wide markdown reference to `update.sh` to scope
the doc-update requirement, and the existing flag-handling patterns already in the file (task 61's
`--update` opt-in, task 60's `NIX_MAX_JOBS` env var, the `--no-check` flag) to keep the new flag
idiomatically consistent with what's already there.

Out of scope: this is a plain bash script not consumed by Nix evaluation (confirmed via `nix flake
check` unaffected by non-flake shell scripts), so no `.nix` changes are needed. `bash -n` and a
manual dry run are sufficient verification; no test harness exists for shell scripts in this repo.

## Findings

### Existing Configuration (scripts/update.sh, current state)

Full current script (55 lines), key regions:

```bash
1  #!/bin/bash
2
3  set -e
4
5  echo "===> Updating dotfiles..."
6
7  # Create git checkpoint if there are uncommitted changes
8  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
9    echo "===> Creating git checkpoint before update..."
10   git add -A
11   git commit -m "checkpoint: auto-commit before update
12
13 Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
14   echo "===> Checkpoint created"
15 else
16   echo "===> No uncommitted changes, skipping checkpoint"
17 fi
18
19 # Update flake inputs — opt-in only (task 61). Auto-updating on every rebuild
20 # outran Hydra and forced local source builds. Run `./update.sh --update` to
21 # deliberately bump inputs (respecting Hydra cadence); the default path keeps
22 # the pinned flake.lock.
23 if [ "$1" == "--update" ] || [ "$2" == "--update" ]; then
24   echo "===> Updating flake inputs..."
25   nix flake update
26 else
27   echo "===> Keeping pinned flake.lock (pass --update to bump inputs)"
28 fi
```

Then hostname detection (line 31), `NIX_MAX_JOBS` job cap (lines 34-37, task 60), `--no-check`
handling as a bare `"$1"` check (lines 40-44), then the two rebuild invocations (lines 47-53).

**The hazard is exactly and only lines 7-17.** Everything else is read-only w.r.t. git.

**Existing opt-in precedent to mirror** (lines 19-28, task 61): comment block explains *why*
the flag defaults off, references the task number, and the `else` branch prints what the default
path does instead of silently doing nothing. The new checkpoint gate should follow the same
shape: comment citing task 93 and the two incident commits, explicit `else` messaging.

**Flag-parsing fragility already present**: `--update` is checked at both `"$1"` and `"$2"`
positions (to allow `./update.sh --no-check --update` or `./update.sh --update --no-check`), but
`--no-check` (line 41) is checked **only** at `"$1"`, so `./update.sh --update --no-check`
currently updates flake inputs but silently fails to skip checks. Adding a third independent flag
(`--checkpoint`) via the same positional pattern would require `$1`/`$2`/`$3` checks for every
flag to preserve arbitrary ordering — combinatorially worse. This is a pre-existing latent bug,
not something task 93 need fix, but it is the natural trigger to replace the positional checks
with a single loop over `"$@"` while adding the new flag, since the new flag's own tests would
otherwise inherit the same ordering trap.

### Incident Record (why this task exists)

1. **specs/085 summary, "Plan Deviations"**: Running `bash scripts/update.sh --no-check` during
   task-85's Phase 4 verification (with task-85's own Phase 1-3 changes still uncommitted)
   triggered the pre-existing checkpoint at lines 7-17, producing commit `6ba1f4e` ("checkpoint:
   auto-commit before update") that absorbed all of task-85's changes plus `specs/TODO.md` and
   `specs/state.json`. Verified harmless in that case (`git show --stat` showed only task-85
   content) but the summary explicitly flags it as an unintended side effect of invoking the
   script during verification, not a deliberate commit by the implementation agent.
2. **specs/083 summary, "Post-verification discovery"**: A *different* mechanism — a concurrent
   task's own `git commit` (not update.sh) — produced `02f806d` ("task 92: record confirmed
   .Trash duplicate-UID evidence...") which unexpectedly contained task-83's already-staged
   files (`.gitignore`, `specs/tmp/.gitkeep`, three `specs/tmp/` deletions, `update.sh`) because
   task-83 had left them staged for the orchestrator to commit and a parallel task's commit ran
   first. Confirmed via `git show --stat 02f806d`. This is not an update.sh bug, but the task
   description cites it as reinforcing the same hazard class (broad/ambient staging capturing
   unrelated concurrent work); it does not change what needs to be edited in update.sh, only
   underscores why the checkpoint's `git add -A` in particular is the part to remove/gate.

### Doc References Requiring Updates

Repo-wide grep for `update.sh` (post task-85 normalization to `scripts/` prefix) found these
files; only the first documents checkpoint behavior directly:

| File:Line | Current text | Needs update? |
|---|---|---|
| `README.md:188` | `` ./scripts/update.sh  # checkpoints, updates flake inputs, rebuilds NixOS + home-manager `` | **Yes** — the comment states checkpointing as a default action; must reflect new opt-in default (e.g. `# updates flake inputs, rebuilds NixOS + home-manager (pass --checkpoint to auto-commit a dirty tree first)`) |
| `docs/development.md:71` | bare `~/.dotfiles/scripts/update.sh` invocation, no flag/checkpoint language | **Task explicitly names this file** — no checkpoint text exists to correct, so the actionable interpretation is to *add* a short flags note here (or a cross-reference to README.md's Maintenance section) so a reader following the setup doc learns about `--checkpoint`/`--update`/`--no-check` at the point they first run the script |
| `docs/README.md:49` | `- **Full update**: \`./scripts/update.sh\`` | No — generic pointer, no checkpoint claim |
| `docs/testing.md:14,90,123-127` | flag usage examples for `--no-check`, general invocation | No — doesn't mention checkpoint |
| `docs/installation.md:30,45,63` | general invocation + one-line description "Updates flake inputs and rebuilds system" | No — doesn't mention checkpoint (description is already flake-inputs-opt-in-accurate per task 61) |
| `docs/usb-installer.md:453,493,632,755` | general invocation | No |
| `docs/dual-home-manager.md:12,25,29,49,58,64,85` | describes update.sh running both nixos-rebuild + home-manager switch | No — unrelated to checkpoint |
| `docs/unstable-packages.md:89,112` | general invocation + flag example | No |
| `packages/README.md:35` | passing mention | No |
| `hosts/README.md:46`, `hosts/nandi/README.md:24` | bare invocation in setup steps | No |

**Conclusion**: Only `README.md:188` contains text that becomes factually wrong under the new
default and must change. `docs/development.md` has no incorrect claim to fix but is named
explicitly in the task description as a doc to update — treat this as "add the flag
documentation somewhere a first-time-setup reader will see it," either inline or via a one-line
cross-reference to README.md's Maintenance section (recommend the latter, to avoid duplicating
flag semantics in two places that can drift).

### Recommendations

**1. Replace lines 7-17 with an opt-in gate.** Suggested shape (to be finalized in the plan):

```bash
# Create a git checkpoint only if explicitly requested — task 93. The prior
# unconditional `git add -A && git commit` here swept unrelated concurrent
# changes into misattributed commits (see commit 6ba1f4e, specs/085 summary).
# Pass --checkpoint or set UPDATE_CHECKPOINT=1 to opt in.
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  if [ "$CHECKPOINT" = "1" ]; then
    echo "===> Creating git checkpoint before update..."
    git add -A
    git commit -m "checkpoint: auto-commit before update

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
    echo "===> Checkpoint created"
  else
    echo "===> ERROR: working tree has uncommitted changes." >&2
    echo "===> Refusing to proceed without an explicit checkpoint (pass --checkpoint or set UPDATE_CHECKPOINT=1) to avoid sweeping unrelated changes into a commit." >&2
    exit 1
  fi
else
  echo "===> No uncommitted changes, skipping checkpoint"
fi
```

  - **Refuse vs. skip-and-continue**: the task description lists "refuse" first and calls it the
    preferred option ("prefer refusing to proceed... (or skipping the checkpoint)"). Refuse is
    recommended as the default because it forces a human/agent decision on unreviewed dirty-tree
    content before a `sudo nixos-rebuild switch` runs, rather than silently rebuilding against an
    unknown working-tree state. No CI or other script depends on update.sh's exit code (confirmed
    via repo-wide grep), so a new non-zero-exit-on-dirty-tree path is safe to introduce. The
    planner should still explicitly record this as a decision point in case skip-and-continue is
    preferred for interactive/local ergonomics.
  - `CHECKPOINT` should be computed once near the top, combining the flag and env var, e.g.
    `CHECKPOINT="${UPDATE_CHECKPOINT:-0}"` then set to `1` if `--checkpoint` appears in `"$@"`.

**2. Refactor flag parsing to a single `for arg in "$@"` loop** covering `--update`, `--no-check`,
  and the new `--checkpoint`, replacing the positional `"$1"`/`"$2"` checks at lines 23 and 41.
  This fixes the existing `--update --no-check` ordering bug as a side effect and avoids needing
  `"$3"` checks once three flags exist. Contained entirely to `scripts/update.sh`; no external
  callers pass positional args by convention that would break (repo-wide grep found no other
  script or doc invoking update.sh with more than one flag at a time).

**3. Doc updates**:
  - `README.md:188` — correct the inline comment to state the new default (no auto-commit) and
    mention `--checkpoint`.
  - `docs/development.md` — add a one-line cross-reference near line 71 pointing to README.md's
    Maintenance section for the full flag list (`--update`, `--no-check`, `--checkpoint`),
    or inline the flag list if the plan prefers development.md to be self-contained.
  - No other file needs changes (see table above) since none of them assert checkpoint behavior.

**4. Verification plan** (matches task's stated Definition of Done):
  - `bash -n scripts/update.sh` — syntax check.
  - Manual dry run: create a throwaway dirty file, run `./scripts/update.sh` with no flags,
    confirm it refuses (or skips, per final decision) and does **not** create a commit
    (`git log -1` unchanged, `git status --porcelain` still shows the dirty file).
  - Manual dry run with `--checkpoint` (or `UPDATE_CHECKPOINT=1`): confirm a commit is created
    and contains only the intended test file (`git show --stat`).
  - Confirm `--update` still triggers `nix flake update` (can verify by checking `flake.lock`
    mtime/hash change, or just that the "Updating flake inputs..." message prints, without
    actually letting the update run to completion if network access is undesired for the check).
  - `nix flake check` — green (this script is not part of flake evaluation, so this should be
    unaffected; run to confirm no incidental regression).

## Decisions

- Scope confirmed as `scripts/update.sh` plus `README.md` and `docs/development.md`; no other
  markdown file requires a checkpoint-related correction.
- Recommend refuse-with-clear-message as the default posture when the tree is dirty and the
  opt-in is not passed, per the task description's stated preference, while flagging it as a
  decision the plan should confirm rather than silently pick.
- Recommend bundling a `for arg in "$@"` flag-parsing refactor into the same change, since adding
  a third flag under the current positional scheme reintroduces a known ordering bug
  (`--no-check` only checked at `$1`).

## Risks & Mitigations

- **Risk**: Refusing to proceed on a dirty tree could surprise users who relied on the old
  auto-checkpoint to save WIP before a rebuild. **Mitigation**: the refusal message explicitly
  names both remediation paths (`--checkpoint` / `UPDATE_CHECKPOINT=1`, or commit/stash
  manually), and this is exactly the safety property the task requires.
- **Risk**: Refactoring flag parsing could regress `--update` or `--no-check` if the loop logic
  is wrong. **Mitigation**: covered by the manual dry-run verification steps above; `bash -n`
  catches syntax errors but not logic errors, so the dry runs are load-bearing.
- **Risk**: Doc drift if `--checkpoint` semantics are documented in two places (README.md and
  docs/development.md) that diverge later. **Mitigation**: prefer a cross-reference from
  development.md to README.md's Maintenance section over duplicating flag semantics.

## Appendix

### Search queries / commands used

- `nl -ba scripts/update.sh` (full current source)
- `grep -rn "update\.sh" --include="*.md" .` (repo-wide doc reference scope)
- `grep -n "checkpoint\|commit\|update.sh" docs/development.md`
- `git show --stat 02f806d`, `git log --oneline -3 -- scripts/update.sh`
- `grep -rn "update\.sh" --include="*.sh" .` (checked for other automated callers — none found)

### References

- `specs/085_root_scripts_relocation_scripts_dir/summaries/01_scripts-dir-relocation-summary.md`
  ("Plan Deviations" section, commit `6ba1f4e`)
- `specs/083_git_hygiene_specs_tmp_nixos_repo/summaries/01_git-hygiene-untrack-tmp-summary.md`
  ("Post-verification discovery" note, commit `02f806d`)
- `.claude/rules/git-workflow.md` (commit conventions, for context on how checkpoint commits
  relate to the task-scoped commit format — checkpoint commits are explicitly outside that
  scheme, which is itself part of why they're risky when made implicitly)
