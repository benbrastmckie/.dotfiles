# Implementation Plan: Task #82 - Dead Code Removal (NixOS/Home Manager dotfiles)

- **Task**: 82 - Remove dead code and orphaned files from the NixOS/Home Manager dotfiles repo (task 81 Tier 0, subtask blueprint #1)
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours (dominated by Nix build/verification time; edits themselves are minutes)
- **Dependencies**: None (Tier 0, parallel with tasks 83/84/85)
- **Research Inputs**: specs/082_dead_code_removal_nixos_repo/reports/02_dead-code-removal-research.md (seed: reports/01_seed.md)
- **Artifacts**: plans/02_dead-code-removal-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; git-workflow.md; state-management.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Remove a confirmed-dead set of files, directories, and stale comments from the NixOS/Home
Manager dotfiles repo. Every target was independently re-verified live (grep/ls/git ls-files) in
the research report as truly orphaned — none is imported, `callPackage`'d, or otherwise consumed
by any evaluated Nix path. The work is pure inertness cleanup with **no** structural or logic
changes: deletions plus four comment-only edits plus three doc-reference patches.

The definition of done is build-only inertness: after all deletions/edits are **staged**,
`nix flake check` passes, all three real hosts build (`.#nandi`, `.#hamsa`, `.#garuda`), the Home
Manager activation package builds, and `git status` shows only the expected deletions plus the
three (optionally four) doc edits — nothing added, nothing else modified.

### Research Integration

- The research report (`reports/02_dead-code-removal-research.md`) confirms all targets dead with
  exact line/path evidence and validates the Critic correction that `packages/test-mcphub.sh` is
  doc-referenced (3 exact locations), not orphaned — so its removal must patch those references
  in the same subtask.
- `config/rclone.conf` is confirmed already untracked (`git ls-files` empty) and gitignored
  (`.gitignore:35`); its "verify" step is correctly dropped — it appears here only as an explicit
  Non-Goal / no-op, never as a deletion.
- One advisory coverage gap surfaced by research: `packages/README.md`'s separate `### neovim.nix`
  doc section (lines 257-258) documents the soon-deleted `packages/neovim.nix` and is *not* one of
  the three literal `test-mcphub.sh` doc refs. Research recommends folding its removal into the
  same `packages/README.md` edit pass (zero build/eval risk, file already open) or deferring to
  subtask 91. This plan includes it as an explicitly-optional task in Phase 5.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but the `roadmap_flag` was not set for this dispatch, so no
ROADMAP.md review/update phases are added. This task advances the task-81 reorganization
queue (Tier 0 dead-code removal, subtask blueprint row 1); ROADMAP annotation, if any, is
handled at `/todo` archival time via the task's completion summary.

## Goals & Non-Goals

**Goals**:
- Delete `home-modules/` (both files) and remove the commented-out import at `home.nix:6` plus the
  two stale MCP-Hub comments (`modules/home/core/shell.nix:8`,
  `modules/home/packages/email-tools.nix:38-39`).
- Delete `modules/opencode.nix` (dead and broken — `../../config/opencode.json` resolves above
  repo root).
- Delete `packages/neovim.nix` (unreferenced `wrapNeovimUnstable` derivation — distinct from the
  live `modules/home/core/neovim.nix`, which is NOT touched).
- Delete `test-sasl.sh`, `test-update.md`, root `TODO.md`, and the five `wallpapers/` scaffolding
  files (`IMPLEMENTATION_COMPLETE.md`, `README.md`, `SETUP_INSTRUCTIONS.md`, `verify-setup.sh`,
  `SAVE_IMAGE_HERE.txt`) — `wallpapers/riverside.jpg` is KEPT (live asset).
- Delete `packages/test-mcphub.sh` AND patch its three doc references
  (`docs/packages.md:244`, `docs/applications.md:26`, `packages/README.md:260-283`).
- Prove build-only inertness across all three hosts + HM activation, with `git status` showing
  only the expected deletions and doc edits.

**Non-Goals**:
- Do NOT delete or touch `wallpapers/riverside.jpg`, `modules/home/core/neovim.nix`,
  `packages/opencode.nix`, or `config/opencode.json`.
- Do NOT act on `config/rclone.conf` (already untracked/gitignored — literal no-op).
- Do NOT touch root `README.md` (Module Map lines 75-76, 91) or `docs/configuration.md:20`; both
  reference `home-modules/` but are explicitly deferred to subtask 91 (documentation sync).
- No structural moves, no logic changes, no new files.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `flake.nix`'s `root = self` means the harness only sees git-tracked content; unstaged deletions produce a false-positive green against the stale tracked tree | H | M (guaranteed if protocol skipped) | MANDATORY: stage every deletion/edit with `git add <specific paths>` (a `git add` on a deleted path stages the removal) BEFORE running any verification. NEVER `git add -A` / `git add .`. Each deletion phase ends by staging its own paths; verification runs only after all are staged. |
| Accidentally deleting the live `modules/home/core/neovim.nix` instead of the dead `packages/neovim.nix` | H | L | Delete only the exact `packages/neovim.nix` path; Phase 3 tasks name the full path and a post-delete assertion that `modules/home/core/neovim.nix` still exists. |
| Over-staging pulls in the unrelated dirty file (`specs/tmp/claude-tts-notify.log`) or other stray edits | M | M | Targeted `git add <specific paths>` only; Phase 6 audits `git status --short` and `git diff --staged --stat` to confirm the staged set is exactly the intended deletions + doc edits. |
| Removing too much from `packages/README.md` (deleting live "MCPHub Integration"/"Implementation" prose that is about the plugin, not the script) | M | L | Phase 5 scopes edits to the `### test-mcphub.sh` section (260-261) and the `### Testing` block (273-283) only; the plugin-integration prose (263-272) is retained. |
| Doc edit leaves a dangling reference or malformed markdown | L | L | Phase 6 greps repo for `test-mcphub` and `home-modules` (excluding `specs/`) to confirm no live-tree references survive except the intentionally-deferred root README / docs/configuration.md ones. |
| Full verification (3 host builds + HM) is slow; failure attribution unclear if batched | L | L | All targets are confirmed non-imported, so a single end-of-run verification is sufficient; Phase 1 records a clean-tree baseline so any failure is attributable to the staged deletion set. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |
| 4 | 7 | 6 |

Phases within the same wave touch disjoint file sets and are logically independent. NOTE: if Wave
2 phases are run in parallel they share a single git index — serialize the `git add` staging steps
(the edits/deletes themselves are independent; only the staging must not race). For a normal
single-agent `/implement`, phases run sequentially and this is a non-issue.

### Phase 1: Baseline snapshot & clean-tree confirmation [COMPLETED]

- **Goal:** Establish an attributable starting point: confirm the working tree is clean of
  unrelated staged changes and record the pre-change `git status` so the final diff is verifiable.
- **Tasks:**
  - [ ] Run `git status --short` and record it; confirm nothing is already staged for this task.
  - [ ] Note the pre-existing unrelated dirty file `specs/tmp/claude-tts-notify.log` (M) so it is
        never staged as part of this task's commit.
  - [ ] (Recommended, fast) Run `nix flake check` on the current tree to confirm a green baseline
        before any deletion. If it is already red for unrelated reasons, STOP and report — do not
        proceed until the baseline is green.
  - [ ] Confirm the live files that MUST survive still exist: `modules/home/core/neovim.nix`,
        `packages/opencode.nix`, `config/opencode.json`, `wallpapers/riverside.jpg`.
- **Timing:** ~10 min (mostly `nix flake check`)
- **Depends on:** none
- **Verification:** `git status --short` recorded; baseline `nix flake check` green (or explicitly
  waived with reason); all four must-survive paths confirmed present.

### Phase 2: Delete `home-modules/` and remove stale MCP-Hub comments [COMPLETED]

- **Goal:** Remove the dead `home-modules/` directory and the four comment-only references to it.
- **Tasks:**
  - [ ] `git rm home-modules/mcp-hub.nix home-modules/README.md` (removes the directory; both are
        its only files).
  - [ ] Edit `home.nix`: remove line 6 `    # ./home-modules/mcp-hub.nix  # Disabled - using
        lazy.nvim approach` (comment-only; leave the surrounding `imports = [` list intact).
  - [ ] Edit `modules/home/core/shell.nix`: remove line 8
        `    # MCP_HUB_PATH is now managed by the MCP-Hub module` (keep the `NIXOS_OZONE_WL` and
        `SASL_PATH` lines that surround it).
  - [ ] Edit `modules/home/packages/email-tools.nix`: remove lines 38-39
        (`    # Required for running mcp-hub JavaScript tools` and
        `    # MCP-Hub is now managed by the home module`). Keep line 37
        (`# Note: libsecret is already installed system-wide...`) which is unrelated.
  - [ ] Stage: `git add home-modules/mcp-hub.nix home-modules/README.md home.nix
        modules/home/core/shell.nix modules/home/packages/email-tools.nix`
        (the deleted paths stage as removals). NEVER `git add -A`.
- **Timing:** ~10 min
- **Depends on:** 1
- **Files to modify:**
  - `home-modules/mcp-hub.nix`, `home-modules/README.md` - delete
  - `home.nix` - remove commented import (line 6)
  - `modules/home/core/shell.nix` - remove stale comment (line 8)
  - `modules/home/packages/email-tools.nix` - remove stale comments (lines 38-39)
- **Verification:** `git status --short` shows the two deletions (D) and three modifications (M);
  `grep -rn "home-modules" --include=*.nix .` returns no live-tree hits (only `specs/` artifacts).

### Phase 3: Delete dead standalone Nix files [COMPLETED]

- **Goal:** Remove `modules/opencode.nix` (dead + broken path) and `packages/neovim.nix`
  (unreferenced derivation), without touching their live namesakes.
- **Tasks:**
  - [ ] `git rm modules/opencode.nix` (self-referential comment only; no import anywhere; its
        `../../config/opencode.json` default resolves above repo root).
  - [ ] `git rm packages/neovim.nix` (unreferenced `wrapNeovimUnstable` derivation).
  - [ ] Assert the live files still exist and are NOT staged for deletion:
        `modules/home/core/neovim.nix` and `packages/opencode.nix`.
  - [ ] Stage: `git add modules/opencode.nix packages/neovim.nix`. NEVER `git add -A`.
- **Timing:** ~5 min
- **Depends on:** 1
- **Files to modify:**
  - `modules/opencode.nix`, `packages/neovim.nix` - delete
- **Verification:** `git status --short` shows exactly these two deletions;
  `grep -rn "opencode.nix\|neovim.nix" --include=*.nix .` shows no `import`/`callPackage` of the
  deleted paths (only the unrelated `packages/opencode.nix` overlay hit and `home.nix ->
  modules/home/core/neovim.nix`).

### Phase 4: Delete root/test cruft and wallpapers scaffolding [COMPLETED]

- **Goal:** Remove orphaned root files and the five `wallpapers/` scaffolding files while keeping
  `riverside.jpg`.
- **Tasks:**
  - [ ] `git rm test-sasl.sh test-update.md TODO.md` (root `TODO.md` is superseded by
        `specs/TODO.md`; the other two have zero live-tree references).
  - [ ] `git rm wallpapers/IMPLEMENTATION_COMPLETE.md wallpapers/README.md
        wallpapers/SETUP_INSTRUCTIONS.md wallpapers/verify-setup.sh
        wallpapers/SAVE_IMAGE_HERE.txt` (the self-referential scaffolding cluster).
  - [ ] Assert `wallpapers/riverside.jpg` still exists and is NOT staged for deletion (it is the
        live asset referenced by `modules/system/desktop.nix` and `modules/home/desktop/gnome.nix`).
  - [ ] Stage: `git add test-sasl.sh test-update.md TODO.md
        wallpapers/IMPLEMENTATION_COMPLETE.md wallpapers/README.md
        wallpapers/SETUP_INSTRUCTIONS.md wallpapers/verify-setup.sh
        wallpapers/SAVE_IMAGE_HERE.txt`. NEVER `git add -A`.
- **Timing:** ~5 min
- **Depends on:** 1
- **Files to modify:**
  - `test-sasl.sh`, `test-update.md`, `TODO.md` - delete
  - `wallpapers/{IMPLEMENTATION_COMPLETE.md,README.md,SETUP_INSTRUCTIONS.md,verify-setup.sh,SAVE_IMAGE_HERE.txt}` - delete
- **Verification:** `git status --short` shows the eight deletions; `ls wallpapers/` still contains
  `riverside.jpg`; root `TODO.md` gone but `specs/TODO.md` untouched.

### Phase 5: Delete `packages/test-mcphub.sh` and patch its doc references [COMPLETED]

- **Goal:** Remove the doc-referenced diagnostic script AND update the three (optionally four) docs
  that point at it or at the deleted `packages/neovim.nix`, leaving no dangling references and no
  malformed markdown.
- **Tasks:**
  - [ ] `git rm packages/test-mcphub.sh`.
  - [ ] Edit `docs/packages.md`: remove the `test-mcphub.sh` reference at the "## Package Testing"
        block (line 244 `Use \`packages/test-mcphub.sh\` as template...` and its immediate
        template bullets 245-247 if they only describe that script). Since the script no longer
        exists and no replacement is implied by any source, remove the reference; collapse or drop
        the now-empty "## Package Testing" heading rather than leave it dangling.
  - [ ] Edit `docs/applications.md`: remove line 26 `Use \`~/.dotfiles/packages/test-mcphub.sh\`
        to verify installation and troubleshoot issues.` under "## MCP-Hub Integration".
  - [ ] Edit `packages/README.md`: remove the `### test-mcphub.sh` section (lines 260-261) and the
        `### Testing` block that runs the script (lines 273-283, including the
        `bash ~/.dotfiles/packages/test-mcphub.sh` fence). KEEP the plugin-oriented
        "## MCPHub Integration" / "### Implementation" prose (263-272) — it is about the plugin,
        not the deleted script.
  - [ ] (OPTIONAL, advisory per research — zero build/eval risk, file already open) Also remove the
        `### neovim.nix` doc section at `packages/README.md:257-258` documenting the now-deleted
        `packages/neovim.nix`. If not done here, it is left to subtask 91 (documentation sync);
        note that choice in the implementation summary. *(deviation: deferred to task 91 — plan
        marks this optional/advisory, not required; orchestrator instructions specified deferring
        unless the plan marks it required)*
  - [ ] Stage: `git add packages/test-mcphub.sh docs/packages.md docs/applications.md
        packages/README.md`. NEVER `git add -A`.
- **Timing:** ~15 min
- **Depends on:** 1
- **Files to modify:**
  - `packages/test-mcphub.sh` - delete
  - `docs/packages.md` - remove test-mcphub reference (~line 244)
  - `docs/applications.md` - remove test-mcphub reference (line 26)
  - `packages/README.md` - remove `### test-mcphub.sh` + `### Testing` blocks (260-283); optionally
    `### neovim.nix` (257-258)
- **Verification:** `git status --short` shows one deletion (D `packages/test-mcphub.sh`) and three
  modifications (M docs); `grep -rn "test-mcphub" --include=*.md --include=*.nix --include=*.sh .`
  returns no hits outside `specs/`; edited markdown renders without orphaned headings.

### Phase 6: Full build-only inertness verification & staged-diff audit [COMPLETED]

- **Goal:** With the entire deletion/edit set staged, prove the tree still evaluates and builds
  everywhere, and that the staged change set is exactly the intended one.
- **Tasks:**
  - [ ] Confirm ALL prior phases' paths are staged: run `git status --short` and verify every
        expected D/M line is present and staged; confirm no unrelated file (e.g.
        `specs/tmp/claude-tts-notify.log`) is staged.
  - [ ] `nix flake check` — must pass.
  - [ ] `nixos-rebuild build --flake .#nandi` — must build.
  - [ ] `nixos-rebuild build --flake .#hamsa` — must build.
  - [ ] `nixos-rebuild build --flake .#garuda` — must build.
  - [ ] `nix build .#homeConfigurations.benjamin.activationPackage` — must build.
  - [ ] Final audit: `git diff --staged --stat` shows ONLY the intended deletions plus the doc
        edits (3 required, 4 if the advisory neovim.nix section was folded in); no additions, no
        other modifications.
  - [ ] Confirm intentionally-deferred references still exist and were NOT touched (out of scope):
        root `README.md` Module Map lines and `docs/configuration.md:20`.
- **Timing:** ~40 min (host builds dominate)
- **Depends on:** 2, 3, 4, 5
- **Verification:** all five build commands green; `git diff --staged --stat` matches the intended
  set exactly; deferred out-of-scope references untouched.

### Phase 7: Commit [PARTIAL]

- **Goal:** Record the verified-green cleanup as a single scoped commit.
- **Tasks:**
  - [x] Review `git diff --staged` one final time for sensitive/stray content. *(completed —
        staged set audited in Phase 6: exactly 12 deletions + 4 comment edits + 3 doc edits, no
        sensitive/stray content)*
  - [ ] Commit with message `task 82: complete implementation` (or
        `task 82 phase ...` per green-substep convention if committing incrementally), including
        the `Session: sess_1783217512_f16aa6_82` trailer. Do NOT use `git commit -am` (implicitly
        over-stages) — commit only the already-staged set. *(deviation: deferred — orchestrator
        instructions for this dispatch explicitly state the orchestrator creates the final commit,
        not the implementation agent; all changes are staged and verified green, ready for that
        commit)*
- **Timing:** ~5 min
- **Depends on:** 6
- **Verification:** commit contains only the staged deletion/edit set; `git status --short` clean
  afterward except the pre-existing unrelated `specs/tmp/claude-tts-notify.log`.

## Testing & Validation

- [ ] `nix flake check` passes with all targets staged for deletion.
- [ ] `nixos-rebuild build --flake .#nandi` builds.
- [ ] `nixos-rebuild build --flake .#hamsa` builds.
- [ ] `nixos-rebuild build --flake .#garuda` builds.
- [ ] `nix build .#homeConfigurations.benjamin.activationPackage` builds.
- [ ] `git status` / `git diff --staged --stat` shows ONLY the expected deletions plus 3 (or 4)
      doc edits — nothing added, nothing else modified.
- [ ] `grep -rn "home-modules\|test-mcphub" --include=*.nix --include=*.md --include=*.sh .`
      returns no live-tree hits (only `specs/` artifacts and the intentionally-deferred root
      README / docs/configuration.md references, which are out of scope for task 82).
- [ ] Live must-survive files intact: `modules/home/core/neovim.nix`, `packages/opencode.nix`,
      `config/opencode.json`, `wallpapers/riverside.jpg`.

## Artifacts & Outputs

- plans/02_dead-code-removal-plan.md (this file)
- summaries/02_dead-code-removal-summary.md (produced at /implement time)
- One git commit: `task 82: complete implementation` (deletions + doc edits only)

## Rollback/Contingency

- All changes are staged before verification and committed only after all builds are green, so a
  failed build never lands. If any build fails: inspect the failure, and since every target is
  confirmed non-imported, a genuine failure indicates either an unexpected reference (fix forward
  by restoring the specific offending path via `git restore --staged <path>` then
  `git checkout -- <path>`) or an unrelated pre-existing breakage (compare against the Phase 1
  baseline).
- Because nothing is committed until Phase 7, pre-commit rollback is simply un-staging
  (`git restore --staged <paths>`) and, if needed, restoring deleted files from HEAD
  (`git checkout -- <paths>`); no history rewrite is required.
- Post-commit rollback (if a defect is found later): `git revert <commit>` restores the deleted
  files and doc text cleanly, since the commit is scoped to only these changes.
