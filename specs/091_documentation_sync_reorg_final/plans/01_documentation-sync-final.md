# Implementation Plan: Task #91 - Final Documentation Sync (Reorg Capstone)

- **Task**: 91 - Final documentation sync across the NixOS/Home Manager dotfiles repo (task 81 Final tier, blueprint row 10)
- **Status**: [NOT STARTED]
- **Effort**: 3 hours (doc edits ~1.25h; full-regression build harness + drift check ~1.75h)
- **Dependencies**: 82, 83, 84, 85, 86, 87, 88, 89, 90 (all `completed`)
- **Research Inputs**: specs/091_documentation_sync_reorg_final/reports/01_documentation-sync-final.md
- **Artifacts**: plans/01_documentation-sync-final.md (this file); handoffs/01_orchestrator-handoff.json
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; git-workflow.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Task 91 is the capstone of the task-81 reorg blueprint: it makes the repository's documentation
match the tree that subtasks 82-90 produced. All work is DOC-ONLY (no `.nix` source changes), but
it closes with a full-regression build harness (`nix flake check` + nandi/hamsa/garuda builds + HM
activation) as a final sanity check that no doc edit accidentally touched an evaluated path, plus a
manual README-vs-`find` drift check across the tree. Definition of done: the six named doc targets
are resynced, the two verified-non-issue notes are recorded, the two convention/closure notes are
written, the full regression passes green, and every change is staged with explicit `git add <paths>`
(never `-A`).

### Research Integration

Grounded entirely in `reports/01_documentation-sync-final.md`, which verified against the CURRENT
tree (not just the seed): exact stale `README.md` Module Map lines (49/54/59 annotations, 84-85 note,
the fully-obsolete 57-76 `modules/`+`home-modules/` ASCII block, the dead `home-modules/` bullet at
line 91), the `docs/README.md` disk-vs-index diff (6 missing entries, confirmed present on disk), the
real `modules/system/` + `modules/home/` aggregator structure and `optional/` convention drawn from
the two `default.nix` header comments and `modules/system/optional/discord-bot.nix`, the
flake.lock (v7, 26 nodes) and stateVersion (24.11 matched) verified-non-issue values, the already-
complete task-69 dual-home-manager closure in `docs/dual-home-manager.md`, and three out-of-scope
drift findings with an explicit (a)-fold-in / (b)-follow-up disposition.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied to this planning run; no ROADMAP phases injected. Task 91 advances the
task-81 reorg blueprint (row 10, Final tier) and unblocks task 78's ability to cite the new
"docs verified against source" convention. Any ROADMAP annotation is deferred to `/todo` at
completion via `completion_summary`.

## Goals & Non-Goals

**Goals**:
- Resync root `README.md` Module Map: drop 3 stale `(planned: task 66 ...)` annotations + their
  explanatory note; rewrite the obsolete inline `modules/` + `home-modules/` ASCII block to a short
  pointer reflecting the real `modules/system/` + `modules/home/` split; fix the package list
  (add `piper-bin.nix`, `piper-voices.nix`, `opencode-discord-bot.nix`); fix the "Directory
  Organization" list (drop dead `home-modules/` bullet, add `modules/` bullet).
- Complete the `docs/README.md` index with the 6 unlisted-but-existing entries.
- Create a new `modules/README.md` documenting the system/home split, the aggregator convention
  (subtask 86), and the meaning of `optional/`.
- Record the flake.lock-health and stateVersion "checked, no action needed" one-liners so a future
  pass does not rediscover them as false positives.
- Add a confirming note that task 69's dual-home-manager closure is already complete.
- Establish the "docs verified against source, not fixed once" convention explicitly (as a sibling
  subsection in `docs/README.md`'s "Documentation Conventions"), so task 78 can ADOPT-but-not-merge.
- Pass the full-regression build harness and a manual README-vs-`find` drift check.

**Non-Goals**:
- No `.nix` source changes (this is doc-only; the build harness is a regression check, not a fix pass).
- No dependency-graph change to task 78 (it already correctly excludes 81/91).
- No rewrite of `packages/README.md` (the `marker-pdf.nix`/missing-sections drift is left as an
  explicit out-of-scope follow-up, not silently fixed and not silently ignored).
- No new resolution content for task 69 (a one-line confirming note only; the resolution already
  exists in `docs/dual-home-manager.md`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rewriting the Module Map's `modules/` block too tersely drops useful detail | M | M | Point to the new `modules/README.md` (created in Phase 3) as the detail destination, mirroring how `config/`/`docs/`/`hosts/`/`packages/` are already handled by pointer, not inline enumeration |
| Scope creep from the "Additional Drift Findings" balloons the capstone | M | M | Explicit (a)/(b) split: only the two trivial single-line fixes are folded in (Phase 5, clearly marked OPTIONAL); `packages/README.md` is left as a flagged follow-up |
| Full-regression harness is a real time cost on a doc-only task | L | H | Intentional per target-layout §3 row 10 ("Full harness once more as final regression check") — last chance to catch residual regression from the whole 82-90 chain; not overkill for task 91's own zero-risk edits |
| A doc edit accidentally touches an evaluated path (e.g. a stray `.nix`-adjacent change) | H | L | The full harness is precisely the guard; staging is scoped with explicit `git add <paths>` so an accidental edit outside the doc set is visible in `git status` before commit |
| Over-staging pulls unrelated/concurrent edits into the commit | M | L | Mandatory `git add <specific paths>` only, never `git add -A`/`git commit -am`; review `git status --short` + `git diff --staged` before commit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 5 | -- |
| 2 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel (each edits a disjoint file set). Phase 6 is the
single gating regression + staging phase and depends on all edit phases.

### Phase 1: Resync root README.md Module Map [COMPLETED]

**Goal**: Bring `README.md`'s Module Map (lines 23-95) into agreement with the current tree.

**Tasks**:
- [x] Drop the 3 stale `(planned: task 66 ...)` annotations: line 49 (`overlays/`), line 54 (`lib/`),
      line 59 (`system/`) — remove only the `# (planned: ...)` tails; keep the real directory entries. *(completed)*
- [x] Remove the explanatory note block at lines 84-85 (`> **Note**: Directories marked "(planned:
      task 66)" ...`) — no `(planned: task 66)` markers remain after the above. *(completed)*
- [x] Rewrite the obsolete inline `modules/` block (lines 57-73): drop the nonexistent standalone
      `modules/opencode.nix` and the pre-aggregator flat enumeration; replace with a short pointer
      form showing `modules/system/` and `modules/home/` and cross-referencing the new
      `modules/README.md` (created in Phase 3) for the full breakdown. *(completed)*
- [x] Remove the obsolete `home-modules/` ASCII block (lines 75-76, `home-modules/mcp-hub.nix`) —
      directory no longer exists on disk. *(completed)*
- [x] Package list (lines 37-47): add `piper-bin.nix`, `piper-voices.nix`, and
      `opencode-discord-bot.nix` (all on disk, all absent from the list). Confirm `neovim.nix` is
      already absent (it is — no removal needed). *(completed)*
- [x] "Directory Organization" list: remove the dead `home-modules/` bullet (line 91) and its
      "Neovim configuration" phrasing on the `packages/` bullet (line 93, stale since `neovim.nix`
      removed); add a `modules/` bullet pointing at the new `modules/README.md`. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `README.md` — Module Map ASCII tree, package list, Directory Organization list

**Verification**:
- `grep -n "planned: task 66" README.md` returns nothing.
- `grep -n "home-modules" README.md` returns nothing.
- `grep -nE "piper-bin|piper-voices|opencode-discord-bot" README.md` returns 3 hits in the package list.
- ASCII tree no longer contains `modules/opencode.nix`; contains `modules/system/` + `modules/home/`.

### Phase 2: Complete docs/README.md index + add source-verification convention [NOT STARTED]

**Goal**: Add the 6 missing index entries and write the "docs verified against source, not fixed
once" convention — both edits land in the single file `docs/README.md`, grouped to avoid churn.

**Tasks**:
- [ ] Add the 6 unlisted-but-existing entries to the "Documentation Files" index, integrated into
      the existing content-adjacent categories (not a catch-all section):
      `dual-home-manager.md`, `how-to-add-package.md`, `how-to-add-service.md` (near
      `configuration.md`); `email-workflow.md` (near `himalaya.md`); `gnome-settings.md` (near
      `applications.md`/`niri.md`); `video-editing.md` (near `dictation.md`).
- [ ] Add a fifth sibling subsection to the existing "Documentation Conventions" section stating the
      "docs verified against source, not fixed once" convention verbatim (this repo is the first
      place it is written down). Phrase it so task 78 can cite/ADOPT it without merging or creating
      a dependency on task 81/91.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `docs/README.md` — Documentation Files index; Documentation Conventions section

**Verification**:
- For each of the 6 files: `grep -c "{name}.md" docs/README.md` >= 1.
- A "Documentation Conventions" subsection matching `grep -in "verified against source" docs/README.md`
  exists and reads as adopt-but-not-merge for task 78.

### Phase 3: Create modules/README.md (structure + verified health notes) [NOT STARTED]

**Goal**: Document the `system/` + `home/` split, the aggregator convention, and `optional/`; record
the flake.lock and stateVersion verified-non-issue one-liners in a "Verified Health Notes" subsection.

**Tasks**:
- [ ] Write `modules/README.md` overview of the `system/`+`home/` split (mirrors NixOS-vs-Home-Manager
      config-vs-user-environment framing already in root `README.md` lines 9-10).
- [ ] Document the aggregator convention (`default.nix` per subtree, one import per module, grouped/
      commented by category) drawing directly from the header comments already in
      `modules/system/default.nix` and `modules/home/default.nix` — cite them as the live example
      rather than re-describing from scratch.
- [ ] Document the always-on vs. optional distinction and `optional/`'s current single-file,
      system-only scope, using `modules/system/optional/discord-bot.nix` as the concrete example
      (`options.services.discordBot.enable` gated under `lib.mkIf`, wired per-host via
      `hosts/nandi/default.nix` + `flake.nix` `extraModules`). Explicitly note there is NO
      `modules/home/optional/` yet (do not imply parity).
- [ ] Cross-reference `.claude/rules/nix.md`'s "Optional / Host-Toggled Modules" section rather than
      duplicating it.
- [ ] Add a short per-subdirectory index (`system/`: 12 flat files + `optional/`; `home/`: `core/`,
      `desktop/`, `email/` + `email/agent-tools/`, `memory/`, `packages/`, `scripts/`, `services/`,
      `misc.nix`).
- [ ] Add a "Verified Health Notes" subsection recording the two one-liners from research §4:
      (1) flake.lock's multiple nixpkgs/systems/utils pins (26 nodes, lock v7) are expected transitive
      duplication from independently-versioned inputs, not corruption — checked, no action needed;
      (2) `stateVersion` is `24.11` in both `configuration.nix` and `home.nix` (matched, frozen per
      NixOS/HM convention — never bump to "update") — checked, no action needed.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `modules/README.md` (NEW)

**Verification**:
- `test -f modules/README.md`.
- `grep -in "optional" modules/README.md` documents `discord-bot.nix` and the no-`home/optional/` caveat.
- `grep -in "flake.lock\|stateVersion" modules/README.md` shows both verified-non-issue notes.
- Section list matches the real `find modules -type d` output (no invented subdirectories).

### Phase 4: Confirming note for task 69 dual-home-manager closure [NOT STARTED]

**Goal**: Record a one-line confirming note that task 69's `extraSpecialArgs` asymmetry and the
Option A/B/C question are already closed and documented — NOT new resolution content.

**Tasks**:
- [ ] Add a one-line confirming note near the top of `docs/dual-home-manager.md` stating that task 69's
      dual-home-manager closure (the `extraSpecialArgs` unification and the "Keep both paths / Option A"
      recommendation already present in this file) is verified current as of task 91 — no further action.

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `docs/dual-home-manager.md` — one-line confirming note

**Verification**:
- `grep -in "task 91\|verified current" docs/dual-home-manager.md` shows the confirming note.
- The existing "extraSpecialArgs unified (task 69)" bullet and "Keep both paths (Option A)"
  recommendation are untouched (no rewrite).

### Phase 5: [OPTIONAL] Fold-in single-line drift fixes [NOT STARTED]

**Goal**: Opportunistically fix the two trivial, same-staleness-class single-line drift items the
drift check surfaced (research recommendation (a)). Clearly marked OPTIONAL — if time/scope pressure
appears, defer to `/fix-it`; the phase is self-contained and its omission does not affect Phases 1-4
or the regression in Phase 6.

**Tasks**:
- [ ] `docs/configuration.md:20` — replace the stale `modules/ # Stub scaffold (opencode.nix;
      home-modules/ stubs)` description (both referents gone) with the current `modules/system/` +
      `modules/home/` reality (pointer to `modules/README.md`).
- [ ] `docs/unstable-packages.md:12` — drop the stale `(planned: ... after task 66 Phase 2)` note on
      `overlays/unstable-packages.nix` (the file exists and is wired into `flake.nix:59`).
- [ ] EXPLICITLY document (in the implementation summary, not by silent edit) that
      `packages/README.md`'s nonexistent `marker-pdf.nix` section and its missing `kooha.nix`/
      `opencode.nix`/`slidev.nix` sections are OUT OF SCOPE for task 91 and recommended as a
      follow-up `/fix-it`/spawned task (research recommendation (b)).

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `docs/configuration.md` — line ~20 stale `modules/` description
- `docs/unstable-packages.md` — line ~12 stale `(planned: task 66 ...)` note

**Verification**:
- `grep -n "home-modules\|planned: task 66\|Stub scaffold" docs/configuration.md docs/unstable-packages.md`
  returns nothing.
- `packages/README.md` is left untouched (`git status` shows it unmodified) and the follow-up is
  recorded in the summary.

### Phase 6: Full-regression verification, drift check, and scoped staging [NOT STARTED]

**Goal**: Run the complete build harness as the task-81-lineage final regression, run the manual
README-vs-`find` drift check, then stage ONLY the touched doc paths with explicit `git add <paths>`.

**Tasks**:
- [ ] `nix flake check` — passes.
- [ ] Build each host config: `nixos-rebuild build --flake .#nandi`, `.#hamsa`, `.#garuda` — all succeed.
- [ ] Home Manager activation build: `home-manager build --flake .#<user>` (or the repo's HM build
      entrypoint) — succeeds. This is the sanity check that no doc edit touched an evaluated path.
- [ ] Manual README-vs-`find` drift check: `find packages -name '*.nix'` vs. the README package list;
      `find modules -type d` vs. `modules/README.md`'s subdirectory index; `ls docs/*.md` vs.
      `docs/README.md` index — confirm zero residual drift on the touched targets.
- [ ] Stage ONLY the touched paths with explicit enumeration (NEVER `git add -A` / `git commit -am`):
      `README.md`, `docs/README.md`, `modules/README.md`, `docs/dual-home-manager.md`, and (if Phase 5
      ran) `docs/configuration.md`, `docs/unstable-packages.md`, plus the task artifacts under
      `specs/091_documentation_sync_reorg_final/`. Review `git status --short` + `git diff --staged`
      before any commit; confirm no `.nix` source file is staged.

**Timing**: 1 hour (dominated by build wait)

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- None (verification + staging only)

**Verification**:
- `nix flake check` exit 0; all three `nixos-rebuild build` invocations exit 0; HM build exit 0.
- `git diff --staged --name-only` lists only the intended doc paths + task artifacts — zero `.nix`
  source files.
- Drift check reports zero residual drift on README package list, `modules/README.md` index, and
  `docs/README.md` index.

## Testing & Validation

- [ ] `nix flake check` passes.
- [ ] `nixos-rebuild build --flake .#nandi` / `.#hamsa` / `.#garuda` all succeed.
- [ ] Home Manager activation build succeeds.
- [ ] `grep -n "planned: task 66" README.md docs/*.md` returns nothing across touched files.
- [ ] `grep -rn "home-modules" README.md docs/configuration.md` returns nothing.
- [ ] All 6 previously-missing docs are present in `docs/README.md`.
- [ ] `modules/README.md` exists and its subdirectory index matches `find modules -type d`.
- [ ] `git diff --staged --name-only` contains zero `.nix` source files (doc-only invariant held).

## Artifacts & Outputs

- `README.md` (modified) — resynced Module Map, package list, Directory Organization.
- `docs/README.md` (modified) — 6 index entries + source-verification convention subsection.
- `modules/README.md` (NEW) — system/home split, aggregator convention, `optional/`, health notes.
- `docs/dual-home-manager.md` (modified) — task-69 confirming note.
- `docs/configuration.md`, `docs/unstable-packages.md` (modified, Phase 5 only) — single-line drift fixes.
- `specs/091_documentation_sync_reorg_final/plans/01_documentation-sync-final.md` (this plan).
- `specs/091_documentation_sync_reorg_final/handoffs/01_orchestrator-handoff.json` (handoff).
- `specs/091_documentation_sync_reorg_final/summaries/01_documentation-sync-final-summary.md` (at implement time).

## Rollback/Contingency

- All changes are doc-only and confined to enumerated paths; if the regression surprises with a
  failure, it is (by construction) NOT caused by these edits — investigate the offending evaluated
  path rather than reverting docs. Fix forward per `.claude/rules/error-handling.md`; never discard
  uncommitted work to reach a green build.
- If a specific doc edit must be reverted, revert that single file (`git checkout -- <path>` only on a
  clean-or-snapshotted tree per git-workflow.md) — the phases are file-disjoint, so reverts are isolated.
- Phase 5 is optional and independently revertible; omitting or reverting it does not affect the
  required deliverables (Phases 1-4) or the regression (Phase 6).
