# Implementation Plan: Task #83

- **Task**: 83 - Fix git hygiene in the NixOS/Home Manager dotfiles repo (untrack specs/tmp/, extend .gitignore, fix update.sh)
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None (Tier 0; fully parallel with tasks 82, 84; task 85 is serialized AFTER this task)
- **Research Inputs**: specs/083_git_hygiene_specs_tmp_nixos_repo/reports/01_git-hygiene-specs-tmp.md
- **Artifacts**: plans/01_git-hygiene-untrack-tmp.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/git-workflow.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Untrack three runtime scratch files under `specs/tmp/` (`claude-tts-notify.log`,
`claude-tts-last-notify`, `lit.md`) that are causing a perpetually-dirty working tree, and prevent
future tracking by extending `.gitignore` with a `specs/tmp/*` + `!specs/tmp/.gitkeep` pair. A
tracked `specs/tmp/.gitkeep` is added so the `specs/tmp/` **directory** survives fresh clones —
critical because `.claude/scripts/skill-base.sh:356,362` writes atomic temp output there with no
`mkdir -p` guard, so a vanished directory would silently break every skill postflight. Separately,
fix two mangled-heredoc artifacts in the root-level `update.sh` in place (line 1 `#\!/bin/bash` →
`#!/bin/bash`; line 55 stray `complete\!` → `complete!`). An optional bonus phase cleans a
pre-existing mangled-heredoc artifact in `.gitignore` (duplicate `.direnv/` + stray
`EOF < /dev/null`). Definition of done: `git status --porcelain` clean on `specs/tmp/` contents,
`specs/tmp/` directory still present on disk, `./update.sh` still executes, `nix flake check` green.

### Research Integration

Integrates `reports/01_git-hygiene-specs-tmp.md`. Key confirmed findings applied:
- All three files are tracked and covered by **no** existing ignore rule (`git check-ignore -v`
  returns nothing); `git rm --cached` leaves working-tree copies untouched (required — two files
  are live runtime files still being written).
- The `specs/tmp/*` + negated `!specs/tmp/.gitkeep` pattern (not a bare `specs/tmp/`) is mandatory
  to guarantee the directory is reconstructable from a fresh clone.
- `skill-base.sh:356,362` is the single unguarded consumer of `specs/tmp/` — the reason the
  directory must durably survive.
- `update.sh` has exactly two artifacts (lines 1 and 55, confirmed via `cat -A`); no other lines
  affected.
- `.gitignore` has a pre-existing duplicate `.direnv/` (line 31) plus stray line 32
  `EOF < /dev/null` — same failure class, in the file this task already edits.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided for this dispatch; task 81's `target-layout.md` §3/§6 row 2 is the
governing blueprint (this is subtask #2 of that Tier-0 git-hygiene work). No ROADMAP.md updates in
scope.

## Goals & Non-Goals

**Goals**:
- Untrack `specs/tmp/claude-tts-notify.log`, `specs/tmp/claude-tts-last-notify`, `specs/tmp/lit.md`
  via `git rm --cached` (working-tree copies preserved).
- Extend `.gitignore` with `specs/tmp/*` and `!specs/tmp/.gitkeep`.
- Add tracked `specs/tmp/.gitkeep` so the directory survives fresh clones.
- Fix `update.sh` in place: shebang line 1 and stray backslash line 55.
- (Optional bonus) Remove the `.gitignore` mangled-heredoc artifact (duplicate `.direnv/` + stray
  `EOF < /dev/null`).

**Non-Goals**:
- Do NOT move `update.sh` into `scripts/` — that is task 85, serialized to run after this task.
- Do NOT touch any content under `specs/` other than `specs/tmp/`, or anything under `.claude/`.
- Do NOT touch the Nix-managed tree (`flake.nix`, `modules/`, `hosts/`, `config/`, `overlays/`,
  `lib/`, `packages/`).
- Do NOT decouple `specs/tmp/lit.md` from `--lit` tooling — it is an unrelated mbsync note; only
  untrack it.
- Do NOT run `git rm` (without `--cached`), which would delete the live working-tree files.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git add -A`/`git add .` sweeps unrelated or concurrent-session edits into the commit (`flake.nix` sets `root = self`, so staged content is what Nix sees) | H | M | NEVER use `git add -A`/`.`; stage only explicit paths (`git add specs/tmp/.gitkeep .gitignore update.sh`); `git rm --cached` self-stages the removals. Review with `git status --short` + `git diff --staged` before commit. |
| Bare `specs/tmp/` ignore would not preserve the directory across fresh clones, later breaking `skill-base.sh:356,362` (unguarded write) | H | M | Use `specs/tmp/*` + `!specs/tmp/.gitkeep` and add a tracked `.gitkeep`; verify `git ls-files specs/tmp/` shows exactly `.gitkeep` afterward. |
| Editing only the rendered shebang misses the literal backslash (`#\!` renders like `#!`) | M | M | Match against the exact `cat -A`-confirmed byte string `#\!/bin/bash`; re-verify with `cat -A update.sh \| sed -n '1p'`. |
| Accidentally deleting live runtime files (using `git rm` not `git rm --cached`) | H | L | Use `--cached` exclusively; verify files still exist on disk (`ls -la specs/tmp/`) after the operation. |
| Scope creep into task 85 (moving update.sh) | M | L | Fix `update.sh` at root path only; do not create or reference a `scripts/` dir. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phase 4 is optional (bonus cleanup); if
dropped, Phase 5 depends on 1, 2, 3.

**Cross-cutting staging protocol (applies to every phase that stages)**: Stage ONLY explicit paths
with `git add <specific paths>`. NEVER `git add -A`, `git add .`, or `git commit -am`. `git rm
--cached` stages its own removals. Before any commit, review `git status --short` and
`git diff --staged`.

### Phase 1: Untrack specs/tmp/ files and add tracked .gitkeep [COMPLETED]

- **Goal:** Remove the three scratch files from the git index while preserving their working-tree
  copies, and add a tracked `.gitkeep` so the directory is reconstructable from a fresh clone.
- **Tasks:**
  - [x] Confirm baseline: `git ls-files specs/tmp/` lists the three files; `ls -la specs/tmp/`
    shows them present on disk.
  - [x] `git rm --cached specs/tmp/claude-tts-notify.log specs/tmp/claude-tts-last-notify specs/tmp/lit.md`
    (removes from index only; `--cached` leaves working-tree copies intact).
  - [x] Create empty tracked file `specs/tmp/.gitkeep` (e.g. `touch specs/tmp/.gitkeep`).
  - [x] Stage the keepfile: `git add specs/tmp/.gitkeep` (do NOT `git add -A`).
  - [x] Confirm the three working-tree files still exist on disk (`ls -la specs/tmp/`).
- **Timing:** 15 min
- **Depends on:** none
- **Files to modify:**
  - `specs/tmp/claude-tts-notify.log` - untrack (index removal only, file preserved)
  - `specs/tmp/claude-tts-last-notify` - untrack (index removal only, file preserved)
  - `specs/tmp/lit.md` - untrack (index removal only, file preserved)
  - `specs/tmp/.gitkeep` - create new, tracked
- **Verification:**
  - `git status --porcelain specs/tmp/` shows the three files staged as deleted (`D `) and
    `.gitkeep` staged as added (`A `) — no untracked working-tree entries yet (ignore rule lands in
    Phase 2).
  - All three original files still present on disk.

### Phase 2: Extend .gitignore to cover specs/tmp/ contents [COMPLETED]

- **Goal:** Add an ignore stanza so the now-untracked `specs/tmp/` contents never re-enter the
  index, while the `.gitkeep` stays tracked.
- **Tasks:**
  - [x] Append a new stanza to `.gitignore`:
    ```
    # Task-system scratch space — directory must persist (skill-base.sh atomic-write dependency)
    specs/tmp/*
    !specs/tmp/.gitkeep
    ```
  - [x] Stage: `git add .gitignore` (explicit path only).
  - [x] Verify ignore behavior: `git check-ignore -v specs/tmp/claude-tts-notify.log` now matches
    the `specs/tmp/*` rule; `git check-ignore specs/tmp/.gitkeep` returns nothing (negation wins).
- **Timing:** 10 min
- **Depends on:** 1
- **Files to modify:**
  - `.gitignore` - add `specs/tmp/*` + `!specs/tmp/.gitkeep` stanza
- **Verification:**
  - `git status --porcelain specs/tmp/` is clean of the three scratch files (they are now ignored
    and untracked); only `.gitkeep` remains as a staged addition and the deletions remain staged.
  - `git check-ignore -v` confirms the three files match `specs/tmp/*` and `.gitkeep` is exempt.

### Phase 3: Fix update.sh mangled-heredoc artifacts in place [COMPLETED]

- **Goal:** Repair the two backslash-escape artifacts at the root-level `update.sh` without moving
  the file.
- **Tasks:**
  - [x] Line 1: replace `#\!/bin/bash` with `#!/bin/bash`.
  - [x] Line 55: replace `echo "===> Dotfiles update complete\!"` with
    `echo "===> Dotfiles update complete!"`.
  - [x] Syntax check: `bash -n update.sh` (exit 0).
  - [x] Confirm direct execution works as a shebang: `head -1 update.sh` shows clean `#!/bin/bash`;
    `./update.sh` is invocable via its shebang (do not run a destructive `nixos-rebuild switch` /
    `home-manager switch` — a `bash -n` syntax check plus shebang inspection is sufficient here).
  - [x] Stage: `git add update.sh` (explicit path only).
- **Timing:** 10 min
- **Depends on:** none
- **Files to modify:**
  - `update.sh` - fix shebang (line 1) and stray backslash in completion echo (line 55)
- **Verification:**
  - `cat -A update.sh | sed -n '1p;55p'` shows `#!/bin/bash$` and
    `echo "===> Dotfiles update complete!"$` (no literal backslashes).
  - `bash -n update.sh` exits 0.

### Phase 4: (Optional bonus) Clean pre-existing .gitignore mangled-heredoc artifact [COMPLETED]

- **Goal:** Remove the duplicate `.direnv/` entry and the stray `EOF < /dev/null` line left by a
  prior mangled heredoc write. Optional; safely droppable without blocking completion.
- **Tasks:**
  - [x] Remove the stray line reading literally `EOF < /dev/null` (currently line 32).
  - [x] Remove the duplicate `.direnv/` under the `# Flake` header (line 31); keep the first
    `.direnv/` under `# Direnv` (line 27). If the `# Flake` header now has no entries, remove the
    now-empty header block too.
  - [x] Stage: `git add .gitignore` (explicit path only).
  - [x] Verify no functional change: `git check-ignore -v .direnv/somefile` still matches
    `.direnv/`.
- **Timing:** 10 min
- **Depends on:** 2
- **Files to modify:**
  - `.gitignore` - remove duplicate `.direnv/` and stray `EOF < /dev/null`
- **Verification:**
  - `.gitignore` contains exactly one `.direnv/` entry and no `EOF < /dev/null` line.
  - `.direnv/` still ignored (`git check-ignore` confirms).

### Phase 5: Final verification (build-only inertness) [COMPLETED]

- **Goal:** Confirm the full definition-of-done and that nothing in the Nix-managed tree regressed.
- **Tasks:**
  - [x] `git status --porcelain specs/tmp/` clean of the three scratch files; `git ls-files
    specs/tmp/` shows exactly `specs/tmp/.gitkeep`.
  - [x] `specs/tmp/` directory still present on disk with its runtime files intact
    (`ls -la specs/tmp/`).
  - [x] `./update.sh` executes via its shebang (`bash -n update.sh` green; shebang clean).
  - [x] `git diff --staged` review shows ONLY: index-deletions of the three files, new tracked
    `specs/tmp/.gitkeep`, `.gitignore` additions (and optional Phase 4 cleanup), and `update.sh`
    fixes — no stray/unrelated files.
  - [x] `nix flake check` green (expected no-op regression check; this task touches nothing under
    the `root = self` Nix tree, so no Nix-tree `git add` is required).
- **Timing:** 15 min
- **Depends on:** 1, 2, 3, 4
- **Files to modify:** none (verification only)
- **Verification:**
  - All four definition-of-done criteria pass: porcelain clean on `specs/tmp/`, directory present,
    `./update.sh` executes, `nix flake check` green.

## Testing & Validation

- [x] `git ls-files specs/tmp/` returns exactly `specs/tmp/.gitkeep`.
- [x] `git status --porcelain specs/tmp/` shows no untracked/modified scratch files.
- [x] `git check-ignore -v specs/tmp/claude-tts-notify.log` matches `specs/tmp/*`;
  `git check-ignore specs/tmp/.gitkeep` returns nothing.
- [x] `ls -la specs/tmp/` confirms `claude-tts-notify.log`, `claude-tts-last-notify`, `lit.md`, and
  `.gitkeep` all present on disk.
- [x] `cat -A update.sh | sed -n '1p;55p'` shows clean shebang and completion echo (no `\!`).
- [x] `bash -n update.sh` exits 0.
- [x] `.gitignore` has a single `.direnv/` and no `EOF < /dev/null` line (if Phase 4 done).
- [x] `nix flake check` green.
- [x] `git diff --staged` scope contains only the intended paths (specs/tmp/.gitkeep, .gitignore,
  update.sh, and the three index-deletions).

## Artifacts & Outputs

- `specs/tmp/.gitkeep` (new, tracked)
- `.gitignore` (extended; optionally de-mangled)
- `update.sh` (two-line fix, in place at repo root)
- Three files untracked from the index (working-tree copies preserved)
- `specs/083_git_hygiene_specs_tmp_nixos_repo/summaries/01_git-hygiene-untrack-tmp-summary.md`
  (implementation summary, produced at `/implement`)

## Rollback/Contingency

- Untracking is reversible: `git add specs/tmp/claude-tts-notify.log
  specs/tmp/claude-tts-last-notify specs/tmp/lit.md` re-stages them, or `git restore --staged` /
  `git checkout` from the pre-change commit restores index state. Working-tree files are never
  removed by `git rm --cached`, so no data is lost.
- `.gitignore` and `update.sh` edits are single-file and revertible via
  `git checkout HEAD -- .gitignore update.sh` (only after committing or with the changes staged;
  observe the "No Destructive Git on Uncommitted Work" rule — snapshot first if the tree is dirty).
- If `nix flake check` unexpectedly fails, it indicates an out-of-scope regression (this task
  touches no Nix-tree files); stop, do not force, and investigate before committing.
- If any phase leaves the tree partially staged, unstage with `git restore --staged <path>` (safe,
  non-destructive) and re-run the phase; never `git reset --hard` on a dirty tree.
