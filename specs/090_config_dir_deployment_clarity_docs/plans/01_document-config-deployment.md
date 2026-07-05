# Implementation Plan: Task #90

- **Task**: 90 - Document config/ deployment mechanisms in the NixOS/Home Manager dotfiles repo
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 88 (completed — renamed `modules/home/core/shell.nix` -> `modules/home/core/dotfiles.nix`)
- **Research Inputs**: specs/090_config_dir_deployment_clarity_docs/reports/01_config-deployment-mechanisms.md
- **Artifacts**: plans/01_document-config-deployment.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Doc-only task: expand `config/README.md` to authoritatively document all three deployment
mechanisms that live in `modules/home/core/dotfiles.nix`, add the two required naming-hazard
callouts, preserve-and-flag the intended force-overwrite behavior for `config/claude/*`, add a
back-reference from `dotfiles.nix`'s header comment, and fix one bonus stale-doc row (`.zuliprc`).
Only two files are touched: `config/README.md` (primary) and `modules/home/core/dotfiles.nix`
(one added comment line). Definition of done: a stale-reference grep confirms `config/README.md`
accurately reflects the three current mechanisms and both callouts are present, with staging done
via explicit `git add <paths>` (never `-A`).

### Research Integration

The plan is grounded entirely in `reports/01_config-deployment-mechanisms.md`, which locates every
claim by file:line in the current tree:
- Mechanism 1 (`home.file.*.source` store symlinks): `dotfiles.nix:19-40`, `:57` (`.zuliprc`).
- Mechanism 2 (`builtins.readFile` mirrors into `~/.config/config-files/`): `dotfiles.nix:42-49`
  — exactly 7 files: `config.fish`, `kitty.conf`, `zathurarc`, `alacritty.toml`, `wezterm.lua`,
  `.tmux.conf`, `latexmkrc`; the other ~6 mechanism-1 files get no mirror (asymmetry to state).
- Mechanism 3 (activation-script `cp`): `home.activation.claudeSettings`, `dotfiles.nix:59-68` —
  unconditional `rm -f` + `cp` + `chmod u+w` on every switch for `config/claude/{settings,keybindings}.json`.
- Header comment with no cross-reference: `dotfiles.nix:1-2` (addition, not a no-op verify).
- Bonus stale row: `config/README.md`'s "Chat" table describes `.zuliprc` as activation-created;
  it is actually mechanism 1 (a plain `home.file.".zuliprc".source` symlink at `:57`).
- The report also flags `config/rclone.conf` as untracked/gitignored with zero deployment
  mechanism today — out of scope; do not add it as a fourth mechanism.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path/roadmap_flag in delegation context). This task is
subtask blueprint #9 of parent task 81 (Tier 2, optional).

## Goals & Non-Goals

**Goals**:
- Document all three deployment mechanisms in `config/README.md` as a named, structured section,
  naming the mechanism and its source file (`modules/home/core/dotfiles.nix`).
- Add both required callouts: (a) `config/` directory vs Nix `config` module-argument shadowing;
  (b) the three-way `.claude/` vs `config/claude/` vs `~/.claude/` "claude" naming collision.
- Preserve-and-flag (do NOT fix) the intended force-overwrite semantics for `config/claude/*`.
- Add a `See config/README.md` cross-reference line to `dotfiles.nix`'s header comment.
- Fix the stale `.zuliprc` "Chat" row (mechanism 1, not an activation script).
- Verify via stale-reference grep; stage only the two touched files with explicit paths.

**Non-Goals**:
- Any change to `dotfiles.nix` behavior (no touching the activation script, `home.file`, or
  `readFile` logic). This is doc-only.
- Adding safety/merge/diff logic to the `config/claude/` force-overwrite (explicitly forbidden).
- Documenting `config/rclone.conf` as a deployment mechanism (it has none; out of scope).
- Editing anything under `.claude/`, `.memory/`, `.opencode/`, or `specs/` (agent-orchestration
  tree, out of scope for task 81 and all subtasks).
- Running `home-manager switch` or any rebuild (doc-only; no activation).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-conflating the three "claude"-named entities in prose | M | M | Always name each by full path (`.claude/`, `config/claude/`, `~/.claude/`); never write bare "claude directory". Per report Risk #1. |
| Tempted to "fix" the force-overwrite gap by editing the activation script | H | L | Task is doc-only; phase 2 documents it as intended behavior only. Non-Goals forbids touching `dotfiles.nix` logic. Per report Risk #2. |
| Leaving the stale `.zuliprc` row uncorrected (treating task as purely additive) | M | M | Phase 3 explicitly corrects it; verification grep in phase 5 checks for the stale "activation script" wording on the `.zuliprc`/Chat row. Per report Risk #3. |
| Over-staging with `git add -A` pulling in unrelated tree changes | M | L | Phase 5 stages only `config/README.md` and `modules/home/core/dotfiles.nix` by explicit path; `git add -A` is forbidden. |
| Duplicated/contradictory prose between new mechanism section and old Notes bullets | L | M | Phase 3 reconciles the existing "Notes" bullets (symlink-vs-activation sentence, `config-files/` bullet) against the new sections. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1, 2, 3 all edit `config/README.md`
and are therefore sequenced to avoid same-file edit conflicts; phase 4 edits a different file
(`dotfiles.nix`) and runs in parallel with phase 1.

### Phase 1: Add "Deployment Mechanisms" section to config/README.md [COMPLETED]

**Goal**: Give `config/README.md` a new, clearly-headed section enumerating the three mechanisms,
each naming its source file and behavior, replacing the current under-specified prose.

**Tasks**:
- [x] Add a `## Deployment Mechanisms` section (before or supplementing the existing per-app
      tables) with three subsections. *(completed)*
- [x] Mechanism 1 — `home.file.*.source` store symlinks: describe as immutable Nix-store symlinks
      placed by `home-manager switch`; edits must go through `config/` + rebuild. Reference
      `modules/home/core/dotfiles.nix` lines 19-40 and line 57 (`.zuliprc`). *(completed)*
- [x] Mechanism 2 — `builtins.readFile` mirrors into `~/.config/config-files/`: describe as a
      second, parallel version-control-visible copy; list exactly the 7 mirrored files
      (`config.fish`, `kitty.conf`, `zathurarc`, `alacritty.toml`, `wezterm.lua`, `.tmux.conf`,
      `latexmkrc`) and state the asymmetry that the other mechanism-1 files get no mirror.
      Reference `dotfiles.nix` lines 42-49. *(completed)*
- [x] Mechanism 3 — activation-script `cp` (`home.activation.claudeSettings`): describe as
      copying `config/claude/{settings,keybindings}.json` to `~/.claude/` as plain writable
      (non-symlink) files so Claude Code can write to them at runtime. Reference `dotfiles.nix`
      lines 59-68. (The force-overwrite WARNING is added in Phase 2.) *(completed)*

**Timing**: 30 min

**Depends on**: none

**Files to modify**:
- `config/README.md` - add the `## Deployment Mechanisms` section.

**Verification**:
- Section names all three mechanisms and cites `modules/home/core/dotfiles.nix`.
- The 7 mechanism-2 files are listed by name; the mirror asymmetry is stated.

---

### Phase 2: Add "Naming Hazards" callouts + force-overwrite flag [COMPLETED]

**Goal**: Add the two required callouts as their own clearly-headed subsections, and the
preserve-and-flag force-overwrite warning as part of describing mechanism 3.

**Tasks**:
- [x] Add a `## Naming Hazards` section with two subsections. *(completed)*
- [x] Callout (a) — `config/` vs Nix `config` argument shadowing: explain that inside
      `dotfiles.nix` the `{ config, pkgs, ... }` argument `config` is the Home Manager
      module-system attrset (e.g. `config.home.homeDirectory`, `config.lib.dag.entryAfter`) and is
      unrelated to the repo-root `config/` directory, which is always referenced via relative
      paths like `../../../config/...`. *(completed)*
- [x] Callout (b) — three-way "claude" collision: name all three distinctly — this repo's
      `.claude/` agent-orchestration system (out of scope, untouched), this repo's `config/claude/`
      dotfiles source (in scope), and the deployed runtime target `~/.claude/` in `$HOME` (the
      user's actual Claude Code CLI config dir). State they must never be conflated. *(completed)*
- [x] Add the force-overwrite WARNING to mechanism 3 (from Phase 1), worded as intentional/
      documented behavior: every `home-manager switch` unconditionally `rm -f` + `cp`s over
      `~/.claude/settings.json` and `~/.claude/keybindings.json` with no merge — a manual edit to
      those runtime files is destroyed on the next rebuild unless copied back into
      `config/claude/` first. Frame as a documented constraint, explicitly NOT a bug being fixed.
      *(deviation: altered — this warning was written inline as part of the mechanism-3 prose
      during Phase 1's edit, rather than deferred to Phase 2, since it reads naturally attached to
      the mechanism it warns about; content and framing match this task's requirement exactly)*

**Timing**: 30 min

**Depends on**: 1

**Files to modify**:
- `config/README.md` - add `## Naming Hazards` section and the mechanism-3 force-overwrite warning.

**Verification**:
- Both callouts present under `## Naming Hazards`, each naming all relevant full paths.
- Force-overwrite warning present and framed as intended behavior, not a defect.

---

### Phase 3: Fix stale .zuliprc row + reconcile Notes prose [COMPLETED]

**Goal**: Correct the bonus stale-doc finding and remove now-duplicated/contradictory prose so the
doc is internally consistent.

**Tasks**:
- [x] Fix the "Chat" table row for `.zuliprc`: it is mechanism 1 (a plain
      `home.file.".zuliprc".source` symlink, `dotfiles.nix:57`), NOT an activation script. Replace
      the `*(activation script)*` / "created via activation script, not symlinked" wording with an
      accurate symlink description (source `config/zuliprc` -> `~/.zuliprc`). *(completed)*
- [x] Reconcile the existing "Notes" section against the new sections: update the
      "Most configs are deployed as symlinks; `claude/`, `rclone.conf`, and `.zuliprc` use
      activation scripts..." bullet (stale re `.zuliprc`) and the `~/.config/config-files/` bullet
      so they point to / agree with the new `## Deployment Mechanisms` section rather than
      contradicting it. Do not re-introduce `rclone.conf` as a documented mechanism. *(completed:
      rclone.conf left untouched in its own Cloud Storage row, out of scope per Non-Goals)*

**Timing**: 20 min

**Depends on**: 2

**Files to modify**:
- `config/README.md` - correct Chat row and reconcile Notes bullets.

**Verification**:
- No remaining doc text describes `.zuliprc` as activation-script-deployed.
- Notes bullets are consistent with the new mechanism/hazard sections.

---

### Phase 4: Add cross-reference to dotfiles.nix header comment [COMPLETED]

**Goal**: Add the required back-reference from `dotfiles.nix`'s header comment to
`config/README.md`. Comment-only; no behavior change.

**Tasks**:
- [x] Append a line to the header comment at `modules/home/core/dotfiles.nix:1-2`, e.g.
      `# See config/README.md for the full deployment-mechanism reference.` *(completed)*
- [x] Confirm the change is comment-only (no code touched; `home.file`, `readFile`, and the
      activation script are unchanged). *(completed: verified via targeted diff, only 2 comment lines added)*

**Timing**: 10 min

**Depends on**: none

**Files to modify**:
- `modules/home/core/dotfiles.nix` - add one comment line to the header (lines 1-2).

**Verification**:
- Header comment now contains a `config/README.md` pointer.
- `git diff` for this file shows only an added comment line.

---

### Phase 5: Verify (stale-reference grep) and scoped staging [NOT STARTED]

**Goal**: Confirm the doc accurately reflects the three mechanisms and both callouts, then stage
only the two touched files by explicit path.

**Tasks**:
- [ ] Run stale-reference greps against `config/README.md`, e.g.:
      - `grep -n "config-files" config/README.md` (mechanism 2 documented).
      - `grep -niE "activation" config/README.md` and confirm `.zuliprc`/Chat row no longer claims
        activation deployment; only mechanism-3 / `config/claude/` legitimately mentions activation.
      - `grep -niE "Deployment Mechanisms|Naming Hazards" config/README.md` (required sections present).
      - `grep -niE "\.claude/|config/claude/|~/\.claude/" config/README.md` (all three claude paths named).
- [ ] Cross-check the three mechanism descriptions against current `dotfiles.nix` line ranges
      (19-40/57, 42-49, 59-68) to confirm no stale line/behavior claims.
- [ ] Stage ONLY the touched files with explicit paths:
      `git add config/README.md modules/home/core/dotfiles.nix` — never `git add -A` / `-am`.
- [ ] Review with `git status --short` and `git diff --staged` before any commit; confirm no
      unrelated or `.claude/`-tree files are staged.

**Timing**: 15 min

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None (verification + staging only).

**Verification**:
- All greps pass (required sections present, no stale `.zuliprc` activation claim).
- `git diff --staged` shows only `config/README.md` and `modules/home/core/dotfiles.nix`.

---

## Testing & Validation

- [ ] `## Deployment Mechanisms` section present in `config/README.md`, naming all three mechanisms
      and citing `modules/home/core/dotfiles.nix`.
- [ ] The 7 mechanism-2 mirror files are listed; mirror asymmetry stated.
- [ ] `## Naming Hazards` section present with both callouts (config-argument shadowing; three-way
      claude collision naming all three full paths).
- [ ] Force-overwrite behavior documented as intended, not fixed or widened.
- [ ] `.zuliprc` correctly described as a mechanism-1 symlink; no residual activation-script claim.
- [ ] `dotfiles.nix` header comment contains a `config/README.md` pointer (comment-only diff).
- [ ] Staging limited to the two touched files via explicit `git add` paths (no `-A`).

## Artifacts & Outputs

- `config/README.md` (expanded: Deployment Mechanisms + Naming Hazards sections, corrected Chat
  row, reconciled Notes).
- `modules/home/core/dotfiles.nix` (one added header-comment cross-reference line).
- `specs/090_config_dir_deployment_clarity_docs/plans/01_document-config-deployment.md` (this plan).
- `specs/090_config_dir_deployment_clarity_docs/summaries/01_document-config-deployment-summary.md`
  (produced at implementation time).

## Rollback/Contingency

Doc-only and confined to two files. To revert: `git checkout config/README.md
modules/home/core/dotfiles.nix` (only if the tree is otherwise clean / changes are staged for
these paths — see git-workflow.md "No Destructive Git on Uncommitted Work"), or revert the single
task-90 commit. No rebuild/activation is performed, so there is no runtime state to unwind.
