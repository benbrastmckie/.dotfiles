# Implementation Summary: Task #98

**Completed**: 2026-07-05
**Duration**: ~30 minutes

## Overview

Added `nix fmt` formatter and a `nix develop` devShell (nixfmt, statix, deadnix) to the
single-system flake, wired non-blocking statix/deadnix reporting into the existing CI job,
and applied a whole-tree `nixfmt` format pass across all 80 tracked `.nix` files (47
reformatted, 33 already conforming). All three phases verified green.

## What Changed

- `flake.nix` — Added `formatter.${system} = pkgs.nixfmt;` (RFC 166 official formatter,
  not the deprecated `nixfmt-rfc-style` alias) and
  `devShells.${system}.default = pkgs.mkShellNoCC { packages = [ pkgs.nixfmt pkgs.statix pkgs.deadnix ]; };`,
  additively after `homeConfigurations`. Also reformatted by the Phase 3 `nix fmt` pass
  itself (multi-line `outputs` argument list, multi-line `inherit` block, etc.).
- `.github/workflows/ci.yml` — Added two non-blocking steps after the existing
  `nix flake check` step: `statix (non-blocking)` (`nix develop --command statix check || true`)
  and `deadnix (non-blocking)` (`nix develop --command deadnix . || true`). `nix flake check`
  remains the sole hard-gating step; no new job, matrix, or config file was added.
- 47 of 80 tracked `.nix` files reformatted by `nix fmt` for `nixfmt` conformance (list
  includes `flake.nix`, `home.nix`, `lib/mkHost.nix`, all three `hosts/*/hardware-configuration.nix`,
  `hosts/iso/default.nix`, `hosts/usb-installer/{default,hardware-configuration}.nix`, most
  of `modules/{home,system}/**`, all three `overlays/*.nix`, and most of `packages/*.nix`
  — including task 96's package header comments and task 97's wrapper modules, as expected).
  This is a formatting-only diff (1214 insertions / 926 deletions across the 47 files); no
  semantic changes.
- Fixed stale group ownership (gid 1000, unresolvable on this machine) on
  `hosts/{garuda,nandi,usb-installer}/hardware-configuration.nix` via `chgrp users` — a
  prerequisite for nixfmt's atomic-write to succeed on those three files (see Decisions).

## Decisions

- Used `pkgs.nixfmt` directly per the plan/research finding that `nixfmt-rfc-style` is a
  deprecated alias of the same derivation in this repo's pinned `nixos-26.05` nixpkgs.
- Ran the Phase 3 format pass as `nix fmt $(git ls-files '*.nix')` (the 80 tracked files
  explicitly) rather than bare `nix fmt` or `nix fmt .` — see Plan Deviations below for why.
- Kept CI changes minimal: two `run:` lines appended to the single existing job step list,
  both ending in `|| true`, no `continue-on-error`, no new config files (`statix.toml` /
  deadnix excludes), matching the plan's non-goals exactly.

## Plan Deviations

- **Phase 3, Task 1** altered: bare `nix fmt` (no args) formats stdin/stdout only (nixfmt's
  "bare invocation" behavior), producing no file changes. `nix fmt .` then failed outright —
  it recursively walks the gitignored `./result` build-output symlink into the Nix store,
  which contains an unrelated pathologically deep/broken symlink chain
  (`@cloudflare/vite-plugin` fixture nested many levels), aborting with
  "Too many levels of symbolic links" before formatting anything. Worked around by invoking
  `nix fmt $(git ls-files '*.nix')` — the exact 80 tracked `.nix` files — which avoids
  `./result` entirely and matches "the whole tree" as tracked by git.
- **Phase 3, Task 1** altered (additional, same task): the first retry with the explicit
  file list still failed partway with `setOwnerAndGroup: permission denied` on
  `hosts/garuda/hardware-configuration.nix` (later also `hosts/nandi/...` and
  `hosts/usb-installer/...`), because those three files carried a stale gid 1000 not
  resolvable to any group on this machine — nixfmt's atomic rename-in-place tries to
  preserve the original file's group and fails when the caller isn't a member of that group.
  Fixed with `chgrp users` on the three affected files (verified via `stat -c %g` sweep
  across all 80 tracked files, confirming those were the only three with a non-standard
  gid), then re-ran the format pass to completion with exit 0.
- **Phase 3, Task 4** (commit as its own dedicated commit) skipped: `orchestrator_mode` is
  `true` for this dispatch. Per the delegation contract, all Phase 1-3 changes were staged
  with targeted `git add` (no `git add -A`) and left uncommitted for the orchestrator's
  postflight commit step, rather than the agent creating any commits itself.

No other deviations; Phases 1 and 2 followed the plan exactly.

## Verification

- Phase 1: `nix flake check` — all checks passed, `formatter.x86_64-linux` and
  `devShells.x86_64-linux.default` both evaluate; `nix develop --command deadnix --version`
  → `1.3.1`; `nix develop --command statix --help` resolves (statix has no `--version` flag
  but is confirmed on PATH and runnable).
- Phase 2: `.github/workflows/ci.yml` parses as valid YAML (`python3 -c "import yaml..."`);
  both new `run:` lines end in `|| true`; `nix flake check` line unchanged; locally,
  `nix develop --command statix check` exits 1 (33 warnings) and
  `nix develop --command deadnix .` exits 0 (findings present) — both would be absorbed by
  `|| true` in CI exactly as designed.
- Phase 3: `git ls-files '*.nix' | wc -l` → 80 tracked files; format pass changed exactly 47
  (matches plan estimate); `nix fmt -- --check $(git ls-files '*.nix')` reports zero files
  needing reformatting after the pass (idempotent); `nix flake check` passes again after the
  full-tree reformat; no `pkgs.nixfmt-rfc-style` code reference anywhere (only the intentional
  searchability comment in `flake.nix`).

## Notes

- Pre-existing 33 statix warnings and deadnix findings were intentionally left unfixed per
  the plan's Non-Goals — non-blocking CI now surfaces them going forward without gating the
  build. A future task can address them explicitly if desired.
- The `./result` symlink traversal issue and the stale-gid files are environment artifacts
  of this workstation, not code defects; both workarounds were operational (git-file-list
  invocation, `chgrp`) and left no trace in the committed diff.
- All changes (flake.nix, ci.yml, 47 reformatted `.nix` files) are staged via `git add` but
  NOT committed — orchestrator_mode is true, so the orchestrator's postflight owns the
  commit(s) for this task.
