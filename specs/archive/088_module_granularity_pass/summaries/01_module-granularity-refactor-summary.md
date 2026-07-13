# Implementation Summary: Task #88

**Completed**: 2026-07-05
**Duration**: ~1 hour

## Overview

Pure structural refactor of `modules/home/`: split the 761-line `email/agent-tools.nix` into a
per-binary directory, merged three tiny package fragments into `packages/misc.nix`, co-located
the two-halves memory system under a new `memory/` directory, and fixed the `core/shell.nix`
misnomer via `git mv` to `core/dotfiles.nix`. Every rename/split/merge was reflected in the
single hand-edit aggregator `modules/home/default.nix`, which now has exactly 29 `imports`
entries (was 31). `nix store diff-closures` against a pre-change baseline is empty, confirming
zero behavior/closure change.

## What Changed

- `modules/home/email/agent-tools.nix` (761 lines) — removed; content redistributed into:
  - `modules/home/email/agent-tools/lib.nix` (316 lines) — shared pure-string helpers
    (`manifestDirDefault`, `mkPreamble`, `mkMutationPreamble`, `lower`), plain non-module Nix.
  - `modules/home/email/agent-tools/census.nix` (57 lines)
  - `modules/home/email/agent-tools/classify.nix` (172 lines)
  - `modules/home/email/agent-tools/unsubscribe-extract.nix` (72 lines)
  - `modules/home/email/agent-tools/archive-confirmed.nix` (62 lines)
  - `modules/home/email/agent-tools/delete-confirmed.nix` (132 lines)
  - `modules/home/email/agent-tools/default.nix` (12 lines) — imports the five above.
- `modules/home/packages/{fonts,lean-math,ai-tools}.nix` — removed; merged into
  `modules/home/packages/misc.nix` (`{ pkgs, lectic, ... }:`, comment sub-grouped).
- `modules/home/misc.nix` — one-line disambiguating header comment added (no logic change),
  cross-referencing the new `packages/misc.nix` basename collision.
- `modules/home/scripts/memory-monitor.nix` -> `modules/home/memory/monitor.nix` (`git mv`).
- `modules/home/services/memory-services.nix` -> `modules/home/memory/services.nix` (`git mv`).
- `modules/home/core/shell.nix` -> `modules/home/core/dotfiles.nix` (`git mv` + header reword).
- `modules/home/default.nix` — updated for every path change above; 31 -> 29 entries.

## Decisions

- Kept all four `agent-tools` shared helpers in one `lib.nix` (316 lines, ~9% over the report's
  ~290-line estimate) rather than splitting `mkMutationPreamble` further, per the plan's own
  Non-Goals constraint against further splitting that function.
- Added a reciprocal disambiguating comment to the top-level `modules/home/misc.nix` (not just
  the new `packages/misc.nix`), since the plan's Non-Goals section explicitly sanctions this as
  the one allowed touch to that file.
- Used the directory-import form (`./email/agent-tools`) in the aggregator rather than the
  explicit `./email/agent-tools/default.nix`, per the research report's recommendation.

## Plan Deviations

- **Phase 1** altered: the baseline build was initially run after Phase 2 edits were already
  made (ordering slip). Corrected by `git stash`-ing the Phase 2 work, building the baseline on
  the genuinely clean tree, then `git stash pop` to restore Phase 2 before any commit. The
  recorded baseline store path is verified correct.
- **Phase 1** altered: working-tree cleanliness was scoped to `modules/home/`, `flake.nix`,
  `flake.lock`, `lib/mkHost.nix` rather than the whole repo, since unrelated in-flight tasks
  (086, 087, 089, 093, `specs/TODO.md`, `specs/state.json`) had pre-existing uncommitted changes
  outside this task's scope.
- **Phase 2** altered: `lib.nix` is 316 lines vs. the report's ~290-line estimate (see Decisions
  above); all five per-binary files are well within bound.
- **Phase 3** altered: added a disambiguating comment to the top-level `misc.nix` in addition to
  the new `packages/misc.nix`, sanctioned by the plan's Non-Goals wording.
- **Phase 4** skipped (no-op): neither memory file's header comment literally referenced the old
  `scripts/`/`services/` path string, so there was nothing stale to reword; content is
  byte-identical aside from the `git mv`.
- **Phase 4** noted: the Service group retained 4 (not 3, as the plan's verification text said)
  other unrelated entries after removing `memory-services.nix` — a wording nuance in the plan,
  not an implementation defect.

## Verification

- `nix eval .#homeConfigurations.benjamin.activationPackage.name` succeeded after every phase
  (2 through 5).
- All five `email-*` binaries built and responded correctly to `--help`.
- `lectic` resolved without a missing-argument error in `packages/misc.nix`.
- Aggregator entry count: 29 (confirmed via `grep -c '^\s*\./' modules/home/default.nix`).
- No untracked `.nix` files remained under `modules/home/` at any commit point.
- Final build: `nix build .#homeConfigurations.benjamin.activationPackage` succeeded — store path
  `/nix/store/fx21pk2pqqiqk46ai9ig2wvmjrdlk2hd-home-manager-generation`.
- `nix store diff-closures` against the Phase 1 baseline
  (`/nix/store/7zlz05l6ghw72r4sqmsq2hx4ljs2dhh5-home-manager-generation`) produced EMPTY output —
  byte-identical closure, confirming the refactor changed zero runtime behavior.
- `nix flake check` (additional, not required by the plan): all checks passed. Two pre-existing,
  unrelated `boot.zfs.forceImportRoot` evaluation warnings on the `hamsa`/`usb-installer`/`iso`
  hosts are untouched by this task.

## Notes

- Each phase was committed separately per the phase checkpoint protocol (5 commits:
  `d81cbf8`, `ac09e64`, `c2b3071`, `a6bbecb`, plus this summary commit), all scoped to
  `modules/home/` and the task's own plan file — no `git add -A` was used at any point.
- Stale documentation references (`README.md:71`, `docs/email-workflow.md:15`,
  `docs/how-to-add-service.md:121`) were left untouched per the plan's explicit Non-Goals
  (task 91's scope).
- `flake.nix`, `lib/mkHost.nix`, and everything outside `modules/home/` were not touched.
