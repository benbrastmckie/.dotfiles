# Implementation Summary: Task #91

**Completed**: 2026-07-05
**Duration**: ~1 hour (doc edits + full regression build harness)

## Overview

Task 91 is the capstone of the task-81 reorg blueprint: it resynced the repository's
documentation to match the tree produced by subtasks 82-90. All work was doc-only (no `.nix`
source changes). All line numbers cited in the plan/report were re-verified against the current
tree before editing and matched exactly. All 6 phases completed, including the optional Phase 5,
and the full-regression build harness passed green.

## What Changed

- `README.md` — dropped the 3 stale `(planned: task 66 ...)` annotations (overlays/, lib/,
  system/) and their explanatory note; replaced the obsolete inline `modules/` ASCII block
  (dead `modules/opencode.nix` reference, pre-aggregator flat layout) with a short pointer to
  `modules/system/` + `modules/home/` and the new `modules/README.md`; removed the dead
  `home-modules/` ASCII block and its "Directory Organization" bullet; added a `modules/` bullet
  pointing at `modules/README.md`; added `piper-bin.nix`, `piper-voices.nix`, and
  `opencode-discord-bot.nix` to the package list (`neovim.nix` was already absent, confirmed).
- `docs/README.md` — added the 6 missing-but-existing entries (`dual-home-manager.md`,
  `email-workflow.md`, `how-to-add-package.md`, `how-to-add-service.md`, `gnome-settings.md`,
  `video-editing.md`) into content-adjacent categories (a new "Configuration & Architecture"
  category plus existing "Applications & Desktop"); added a new "Docs verified against source,
  not fixed once" subsection to "Documentation Conventions", phrased for task 78 to cite/adopt
  without merging or creating a dependency on task 81/91.
- `modules/README.md` (NEW) — documents the `system/`+`home/` split, the aggregator convention
  (drawing directly from the header comments in `modules/system/default.nix` and
  `modules/home/default.nix`), the always-on vs. optional distinction with
  `modules/system/optional/discord-bot.nix` as the concrete example and an explicit note that no
  `modules/home/optional/` exists yet, a cross-reference to `.claude/rules/nix.md`'s "Optional /
  Host-Toggled Modules" section, a per-subdirectory index matching `find modules -type d`, and a
  "Verified Health Notes" subsection recording the flake.lock (v7, 26 nodes, intentional
  transitive pins) and stateVersion (24.11, matched in `configuration.nix` + `home.nix`)
  checked-no-action-needed notes.
- `docs/dual-home-manager.md` — added a one-line confirming note near the top stating task 69's
  `extraSpecialArgs` unification and "Keep both paths (Option A)" recommendation are verified
  current as of task 91; existing content untouched (no rewrite).
- `docs/configuration.md` — fixed the stale `modules/ # Stub scaffold (opencode.nix;
  home-modules/ stubs)` line to point at the current `modules/system/` + `modules/home/` split
  and `modules/README.md` (Phase 5, optional, folded in).
- `docs/unstable-packages.md` — dropped the stale `(planned: ... after task 66 Phase 2)` note on
  `overlays/unstable-packages.nix`, which exists and is wired into `flake.nix:59` (Phase 5,
  optional, folded in).

## Decisions

- Replaced the root README's inline `modules/` ASCII enumeration with a short pointer to the new
  `modules/README.md`, matching how `config/`, `docs/`, `hosts/`, and `packages/` are already
  handled by pointer rather than full inline enumeration.
- Added a new "Configuration & Architecture" category in `docs/README.md` for
  `dual-home-manager.md`/`how-to-add-package.md`/`how-to-add-service.md` rather than forcing them
  into "Getting Started".
- Folded in both optional Phase 5 single-line fixes since they were cheap, doc-only, and in the
  same staleness class already being fixed elsewhere in the task.

## Plan Deviations

- Phase 5 was scoped strictly to the two named single lines (`docs/configuration.md:20`,
  `docs/unstable-packages.md:12`) per explicit plan/task instruction. Two additional pieces of
  adjacent staleness were found in the same files during the edit but were **not** fixed, to
  avoid scope creep beyond the named single-line fixes:
  - `docs/configuration.md` lines 18-19 (`overlays/`/`lib/` still marked `(planned)` in the ASCII
    block) and lines 22-24 (a "Task 66 status" blockquote claiming Phases 2-6 are still gated on
    tasks 62/65) — both directories/phases are actually complete.
  - `docs/unstable-packages.md` lines 5-7 (a note about the overlay being "pending Phase 2
    extraction" — the extraction is already done).
  These are recorded here as a follow-up, not silently fixed and not silently ignored — same
  disposition pattern as the `packages/README.md` item below.

## Out-of-Scope Follow-Up (recorded, not fixed)

- `packages/README.md` documents a nonexistent `marker-pdf.nix` package (confirmed via
  `find . -iname "*marker*"` returning zero hits) and is missing standalone sections for
  `kooha.nix`, `opencode.nix`, and `slidev.nix` (all exist in `packages/*.nix`). This is a larger,
  separate file with no other task-91 touchpoint; recommended as a follow-up `/fix-it` or spawned
  task rather than expanding this capstone task's scope.
- See "Plan Deviations" above for the two smaller adjacent-staleness items in
  `docs/configuration.md` and `docs/unstable-packages.md`.

## Verification

- Build: Success — `nix flake check` ("all checks passed!"); `nixos-rebuild build --flake .#nandi`,
  `.#hamsa`, `.#garuda` all succeeded; `home-manager build --flake .#benjamin` succeeded (exit 0).
- Tests: N/A (doc-only task; no test suite).
- Drift check: zero residual drift — README package list vs. `find packages -maxdepth 1
  -name '*.nix'`; `modules/README.md`'s per-subdirectory index vs. `find modules -type d`;
  `docs/README.md` index vs. `ls docs/*.md` (all 24 files referenced).
- `git diff --staged --name-only` across all phase commits contains zero `.nix` source files —
  doc-only invariant held throughout.
- Files verified: Yes (all edited/created files read back and grep-verified against plan criteria).

## Notes

- Every phase was committed separately with targeted `git add <paths>` (never `git add -A`), so
  the concurrent in-flight edits from sibling tasks (069, 086, 087, 088, 089, 093 and
  `specs/TODO.md`/`state.json`) were never touched or staged by this implementation.
- This closes the task-81 reorg blueprint's Final tier (row 10). Task 78 can now cite the new
  "docs verified against source, not fixed once" convention in `docs/README.md`.
