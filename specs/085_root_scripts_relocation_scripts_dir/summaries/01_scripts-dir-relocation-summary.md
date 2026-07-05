# Implementation Summary: Task #85

**Completed**: 2026-07-04
**Duration**: ~25 minutes

## Overview

Relocated `install.sh`, `update.sh`, and `build-usb-installer.sh` from the repo root into a new
`scripts/` directory via `git mv`, then updated every live documentation reference (3 explicitly
named docs + 8 additional live docs = 12 files) to use `scripts/`-prefixed paths. A repo-wide
re-grep confirms no bare-name live references remain outside the intentionally-ignored set
(`flake.nix` comments, `.claude/` false positives, `specs/` history).

## What Changed

- `install.sh` -> `scripts/install.sh` (git mv, mode 100755 preserved, contents unchanged)
- `update.sh` -> `scripts/update.sh` (git mv, mode 100755 preserved, contents unchanged — carries
  task-83's shebang fix, untouched by this task)
- `build-usb-installer.sh` -> `scripts/build-usb-installer.sh` (git mv, mode 100755 preserved)
- `README.md` — 3x `update.sh` refs -> `scripts/update.sh`
- `docs/testing.md` — 4x `update.sh` refs -> `scripts/`-prefixed
- `docs/usb-installer.md` — 4x `update.sh` + 2x `build-usb-installer.sh` refs -> `scripts/`-prefixed
- `docs/installation.md` — 3x `update.sh` refs + `install.sh` table entry -> `scripts/`-prefixed
  (the only live doc referencing `install.sh`)
- `docs/dual-home-manager.md` — 7x `update.sh` prose mentions -> `scripts/update.sh`
- `docs/development.md` — 1x `update.sh` ref -> `scripts/update.sh`
- `docs/unstable-packages.md` — 2x `update.sh` refs -> `scripts/`-prefixed
- `docs/README.md` — 1x `update.sh` ref -> `scripts/update.sh`
- `packages/README.md` — 1x `update.sh` ref -> `scripts/update.sh`
- `docs/ryzen-ai-300-support-summary.md` — 1x `build-usb-installer.sh` ref -> `scripts/`-prefixed
- `hosts/README.md` — 1x `update.sh` ref -> `scripts/update.sh`
- `hosts/nandi/README.md` — 1x `update.sh` ref -> `scripts/update.sh`

## Decisions

- Phase 1 baseline grep matched the research inventory exactly — no new hits surfaced, so no
  additional files were added to the Phase 3 scope.
- Left `update.sh`'s own internal comments referencing `./update.sh`/`update.sh` (lines 20, 35 —
  self-referential usage examples inside the script) untouched, consistent with the "move only,
  do not edit script contents" constraint; these are not doc references.
- Left `flake.nix`'s two bare-name comment mentions untouched (inert, not Nix-evaluated), per
  explicit non-goal.

## Plan Deviations

- **Phase 4 verification step** (running the moved scripts) triggered `scripts/update.sh`'s
  pre-existing (unmodified by this task) git-checkpoint logic: because Phase 1-3 changes were
  present in the working tree when `bash scripts/update.sh --no-check` was run to confirm
  post-move path resolution, the script's own `git add -A && git commit` checkpoint fired and
  committed everything as commit `6ba1f4e` ("checkpoint: auto-commit before update"). This
  included all task-85 changes (3 script renames + 12 doc edits) plus `specs/TODO.md`,
  `specs/state.json`, and this task's own metadata/plan/report files — verified via
  `git show --stat` to contain no files from other tasks. The working tree is now clean.
  **This commit was not created directly by the implementation agent** — it is a side effect of
  invoking the script's own pre-existing checkpoint feature. The orchestrator should treat
  `6ba1f4e` as the record of this task's Phase 1-4 changes and should NOT create a duplicate
  commit for the same content.

## Verification

- Baseline + repo-wide re-grep: `grep -rn -e 'install\.sh' -e 'update\.sh' -e 'build-usb-installer\.sh' . --exclude-dir=.git`
  — every hit outside `specs/` (history), `.claude/` (false positives), `flake.nix` (inert
  comments), and `scripts/update.sh`'s own internal comments is `scripts/`-prefixed. No live doc
  reference remains bare-name.
- `git ls-files -s scripts/` — all three scripts show mode `100755`.
- `bash scripts/update.sh --no-check` and `bash scripts/install.sh` — both executed from the repo
  root, resolved the flake ref (`hamsa`) correctly, and reached the `sudo nixos-rebuild switch`
  step with no shebang or path-resolution error (failed only on `sudo: a password is required`,
  which is expected/desired — no actual system switch occurred).
- `nix flake check` — all checks passed (exit 0), including all 4 NixOS configurations
  (`nandi`, `hamsa`, `garuda`, `iso`/`usb-installer`) and `homeConfigurations`.

## Notes

- Direct `./scripts/update.sh` invocation failed with "No such file or directory" in this
  execution sandbox because `/bin/bash` does not exist here (only `/bin/sh` -> nix store bash).
  This is a sandbox characteristic, not a regression from the move — `bash scripts/update.sh`
  (explicit interpreter) confirmed the script content and path resolution are correct. Target
  NixOS hosts provide `/bin/bash` via system configuration, so `./scripts/update.sh` will resolve
  normally there.
- `build-usb-installer.sh` was also spot-checked (`bash scripts/build-usb-installer.sh`) and
  correctly started its build sequence (reached `nix flake update`, which failed only on a
  network fetch timeout in this sandboxed environment — no path/shebang issue). `flake.lock` was
  confirmed unmodified by this attempt.
