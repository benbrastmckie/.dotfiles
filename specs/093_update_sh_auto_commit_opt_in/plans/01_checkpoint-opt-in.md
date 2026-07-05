# Implementation Plan: Task #93

- **Task**: 93 - Make scripts/update.sh's automatic git checkpoint commit opt-in instead of default
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None (parent_task 85 already completed)
- **Research Inputs**: specs/093_update_sh_auto_commit_opt_in/reports/01_update-sh-checkpoint-opt-in.md
- **Artifacts**: plans/01_checkpoint-opt-in.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

`scripts/update.sh:7-17` currently runs `git add -A && git commit` unconditionally whenever the
working tree is dirty, which during concurrent orchestration swept unrelated changes into
misattributed commits (incidents `6ba1f4e` and `02f806d`). This plan makes the checkpoint opt-in
behind a `--checkpoint` flag / `UPDATE_CHECKPOINT=1` env var (default OFF), mirroring the existing
task-61 `--update` opt-in pattern. When the checkpoint is OFF and the tree is dirty, the script
**refuses to proceed** with a clear stderr message and non-zero exit (research confirmed
refuse-not-skip as the intended posture; no automated caller depends on the exit code). The change
also folds in a `for arg in "$@"` flag-parsing refactor to fix the pre-existing `--no-check`
positional-only bug that a third flag would worsen, and corrects the two doc references
(`README.md:188`, `docs/development.md:71`). Definition of done: dirty tree no longer auto-commits
without the opt-in; `--update` still triggers `nix flake update`; `bash -n` clean; `nix flake
check` green.

### Research Integration

Integrated from `reports/01_update-sh-checkpoint-opt-in.md`:
- The hazard is exactly and only lines 7-17; everything else in the script is read-only w.r.t. git.
- Recommended design: compute `CHECKPOINT="${UPDATE_CHECKPOINT:-0}"` once near the top, set to `1`
  when `--checkpoint` appears in `"$@"`; refuse-with-clear-message + `exit 1` when dirty and OFF.
- `git add -A` must never be used to stage arbitrary changes; it is only reachable inside the
  explicit opt-in branch.
- Flag-parsing refactor: `--update` is checked at `$1`/`$2` and `--no-check` only at `$1`, so
  `./update.sh --update --no-check` silently fails to skip checks. Replace positional checks with a
  single `for arg in "$@"` scan covering `--update`, `--no-check`, and `--checkpoint`.
- Doc audit: only `README.md:188` states checkpoint behavior and is factually wrong under the new
  default; `docs/development.md:71` has no incorrect claim but is named in the task -- add a
  one-line cross-reference to README's Maintenance/Full Update section. No other markdown file
  asserts checkpoint behavior.
- No CI/hook/other script invokes `scripts/update.sh`, so the new non-zero-exit path is safe.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Make the git checkpoint opt-in via `--checkpoint` flag or `UPDATE_CHECKPOINT=1` env var, default OFF.
- Refuse to proceed (clear stderr message + non-zero exit) when the tree is dirty and the opt-in is absent.
- Never use `git add -A` outside the explicit opt-in branch.
- Refactor flag parsing to a single `for arg in "$@"` loop, fixing the `--no-check` ordering bug.
- Correct `README.md:188` and add a flag cross-reference at `docs/development.md:71`.
- Preserve existing `--update`, `--no-check`, and `NIX_MAX_JOBS` behavior.

**Non-Goals**:
- No `.nix` changes (script is not part of flake evaluation).
- No new shell-test harness (none exists in the repo; `bash -n` + manual dry run is the standard).
- No changes to the two rebuild invocations or hostname/job-cap logic beyond the flag refactor.
- No edits to the other doc files that merely mention `update.sh` without asserting checkpoint behavior.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Refusing on a dirty tree surprises users who relied on auto-checkpoint | M | M | Refusal message names both remediation paths (`--checkpoint` / `UPDATE_CHECKPOINT=1`, or commit/stash); this is the safety property the task requires |
| Flag-parsing refactor regresses `--update` or `--no-check` | H | L | Load-bearing manual dry-run verification in Phase 3 covers each flag and ordering; `bash -n` for syntax |
| `set -e` interaction: `git diff-index` non-zero exit misread as error | M | L | Keep existing `if ! git diff-index --quiet HEAD -- 2>/dev/null; then` guard structure; the explicit `exit 1` is intentional refusal, not an unhandled failure |
| Doc drift if `--checkpoint` documented in two places | L | M | development.md uses a cross-reference to README's Full Update section rather than duplicating flag semantics |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Refactor flag parsing and gate the checkpoint behind opt-in [COMPLETED]

**Goal**: Replace the unconditional checkpoint (lines 7-17) with a default-OFF opt-in gate, and
replace positional flag checks with a single `for arg in "$@"` loop.

**Tasks**:
- [x] Add a flag-parsing block near the top of the script (after `set -e`/echo) that scans
      `for arg in "$@"` and sets booleans: `DO_UPDATE`, `DO_NO_CHECK`, and
      `CHECKPOINT` (initialized from `CHECKPOINT="${UPDATE_CHECKPOINT:-0}"`, set to `1` when
      `--checkpoint` is seen).
- [x] Replace lines 7-17 checkpoint block: keep the `if ! git diff-index --quiet HEAD -- 2>/dev/null; then`
      dirty-tree guard, but inside it branch on `CHECKPOINT`: when `1`, run the existing
      `git add -A` + `git commit` checkpoint (this is the only place `git add -A` may appear);
      when not `1`, print an ERROR + refusal message to stderr naming `--checkpoint` /
      `UPDATE_CHECKPOINT=1` and `exit 1`. Keep the clean-tree `else` "No uncommitted changes" branch.
- [x] Add a comment block above the gate citing task 93 and incident `6ba1f4e`, mirroring the
      task-61 `--update` comment style (explains why default is OFF, what the else branch does).
- [x] Replace the positional `--update` check (line 23) with `if [ "$DO_UPDATE" = "1" ]; then`.
- [x] Replace the positional `--no-check` check (line 41) with `if [ "$DO_NO_CHECK" = "1" ]; then`.
- [x] Preserve `NIX_MAX_JOBS`, hostname detection, and both rebuild invocations unchanged.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `scripts/update.sh` - Add `for arg in "$@"` flag parser; convert checkpoint to opt-in refuse-by-default gate; convert `--update` and `--no-check` to boolean checks.

**Verification**:
- `bash -n scripts/update.sh` exits clean (deferred to Phase 3 for the full suite; a quick syntax
  check here is acceptable before handing off).
- Visual review: `git add -A` appears only inside the `CHECKPOINT=1` branch.

---

### Phase 2: Update documentation references [COMPLETED]

**Goal**: Correct the one factually-wrong doc reference and add a flag pointer where the task names it.

**Tasks**:
- [x] `README.md:188` - Replace the inline comment `# checkpoints, updates flake inputs, rebuilds
      NixOS + home-manager` so it reflects the new default (no auto-commit) and mentions
      `--checkpoint`, e.g. `# updates flake inputs, rebuilds NixOS + home-manager (pass --checkpoint to auto-commit a dirty tree first; default refuses on a dirty tree)`.
- [x] `docs/development.md` (near line 71) - Add a one-line note after the `~/.dotfiles/scripts/update.sh`
      invocation cross-referencing README's Full Update / Maintenance section for the flag list
      (`--checkpoint`, `--update`, `--no-check`). Do not duplicate full flag semantics inline.
- [x] Confirm no other markdown file asserts checkpoint behavior (research audit table already
      established only these two need changes; spot-check none regressed).

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `README.md` - Correct checkpoint comment at line 188.
- `docs/development.md` - Add flag cross-reference near line 71.

**Verification**:
- `grep -n "checkpoint" README.md docs/development.md` shows the new opt-in language.
- README no longer claims checkpointing as a default action.

---

### Phase 3: Verification [COMPLETED]

**Goal**: Confirm the definition of done via syntax check, dirty-tree dry runs, `--update` path, and flake check.

**Tasks**:
- [x] `bash -n scripts/update.sh` - syntax check, expect clean exit.
- [x] Create a throwaway dirty file (e.g. `touch /tmp/wip-test && cp /tmp/wip-test ./_wip_test`),
      run `./scripts/update.sh` with no flags, confirm it **refuses** (non-zero exit, stderr
      message) and creates **no** commit (`git log -1` unchanged, `git status --porcelain` still
      shows the dirty file). Remove the throwaway file afterward. *(deviation: altered — the
      real repo's tree was already naturally dirty from concurrent unrelated work at test time,
      so the no-flags refusal was verified directly against that natural dirty state (confirmed
      HEAD unchanged, non-zero exit, stderr message) rather than an artificial throwaway file in
      the real repo)*
- [x] With the same dirty file, run `UPDATE_CHECKPOINT=1 ./scripts/update.sh` (or `--checkpoint`)
      up to the point of confirming a checkpoint commit is created containing only the intended
      file (`git show --stat`); interrupt before the rebuild if a full rebuild is undesirable.
      Alternatively verify the checkpoint branch is reached via a dry echo. Clean up the test commit.
      *(deviation: altered — verified in an isolated scratch git repo
      (`/tmp/.../scratchpad/update-sh-test`) with the two rebuild invocations and `nix flake
      update` stubbed to `echo`, rather than against the real dotfiles repo, because the real
      tree's pre-existing unrelated dirty files meant `--checkpoint`'s `git add -A` would have
      committed other in-flight tasks' changes; both `--checkpoint` and `UPDATE_CHECKPOINT=1`
      were confirmed to create a correctly-scoped commit via `git show --stat`, and the scratch
      repo was deleted afterward)*
- [x] Confirm `--update` still reaches the `nix flake update` path (verify the "Updating flake
      inputs..." message prints, without necessarily completing the network update). *(verified
      in the same scratch repo; "Updating flake inputs..." printed and the stubbed
      `nix flake update` was reached)*
- [x] Confirm flag ordering: `./scripts/update.sh --update --no-check` now honors both flags
      (previously `--no-check` was ignored in this order) -- verify via the printed messages.
      *(verified both orderings, `--update --no-check` and `--no-check --update`, in the scratch
      repo; both printed "Updating flake inputs..." and "Skipping build checks...")*
- [x] `nix flake check` - expect green (script is outside flake evaluation; run to confirm no
      incidental regression). *(ran in the real repo; "all checks passed!", pre-existing
      unrelated `boot.zfs.forceImportRoot` evaluation warnings only)*

**Timing**: 25 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (verification only).

**Verification**:
- All checks above pass; dirty-tree default run produces no commit; opt-in run produces a
  correctly-scoped checkpoint; `--update` and combined-flag paths work; `nix flake check` green.

## Testing & Validation

- [x] `bash -n scripts/update.sh` clean.
- [x] Dirty tree + no flags -> refuses, non-zero exit, no commit created.
- [x] Dirty tree + `--checkpoint` (or `UPDATE_CHECKPOINT=1`) -> checkpoint commit created, correctly scoped.
- [x] `--update` still triggers the `nix flake update` path.
- [x] `--update --no-check` (both orderings) honors both flags.
- [x] `git add -A` present only inside the explicit opt-in branch.
- [x] `nix flake check` green.
- [x] `README.md:188` corrected; `docs/development.md` flag cross-reference added.

## Artifacts & Outputs

- `scripts/update.sh` - opt-in checkpoint gate + `for arg in "$@"` flag parser.
- `README.md` - corrected Full Update checkpoint comment.
- `docs/development.md` - added flag cross-reference.
- `specs/093_update_sh_auto_commit_opt_in/plans/01_checkpoint-opt-in.md` (this file).
- `specs/093_update_sh_auto_commit_opt_in/summaries/01_checkpoint-opt-in-summary.md` (on completion).

## Rollback/Contingency

Single-file logic change plus two doc edits; revert via `git checkout -- scripts/update.sh
README.md docs/development.md` (clean-tree exemption) or `git revert` of the implementation commit.
No state migration, no `.nix`/flake surface, and no automated consumers depend on the script's exit
code, so rollback is fully contained. If refuse-by-default proves too aggressive for interactive
local use, the fallback is to switch the OFF-branch from `exit 1` to a warning + skip-and-continue
(the branch is isolated, so this is a one-line change) -- record as a decision point, refuse is the
chosen default.
