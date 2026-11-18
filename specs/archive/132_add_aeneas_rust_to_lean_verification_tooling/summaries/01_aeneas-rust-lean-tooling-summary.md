# Implementation Summary: Task #132

- **Task**: 132 - Add Aeneas Rust-to-Lean verification tooling
- **Status**: [COMPLETED]
- **Started**: 2026-09-16T18:11:18Z
- **Completed**: 2026-09-16T19:45:00Z
- **Effort**: ~2.5 hours active work, plus one from-source build of charon/aeneas (~1h40m
  wall-clock, unattended)
- **Dependencies**: None
- **Artifacts**: plans/01_aeneas-rust-lean-tooling.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added Charon and Aeneas (Rust-to-Lean formal verification tooling) to this NixOS/home-manager
config as a system-level flake input, threaded to both home-manager paths (NixOS-integrated and
standalone) the same way `lectic` already is, and installed both binaries via `home.packages`.
Documented the Verification-repo-local Lake configuration needed on the Lean side. All four plan
phases completed; both home-manager paths evaluate/build, `charon --help` and `aeneas -help` both
exit 0 after activation, and the existing Rust/Lean toolchains are unchanged.

## What Changed

- `flake.nix` — added the `aeneas` flake input (`github:AeneasVerif/aeneas`, deliberately without
  `inputs.nixpkgs.follows`, with an explanatory comment); added `aeneas` to the `outputs`
  function argument set; added `aeneas-charon`/`aeneas-aeneas` resolved-package entries to
  `hmExtraSpecialArgs`; passed `aeneas` into the `mkHost` import's inherit list.
- `lib/mkHost.nix` — added `aeneas` to the argument set; added the same
  `aeneas-charon`/`aeneas-aeneas` resolved entries to the NixOS-integrated home-manager path's
  `extraSpecialArgs` block.
- `flake.lock` — locked the new `aeneas` input (and its transitive `charon`, `fstar`, etc. nodes)
  at revision `86158eb2e18944c5225959712efb96bce188f40d`; no other input's lock changed.
- `modules/home/packages/misc.nix` — extended the module signature with `aeneas-charon` and
  `aeneas-aeneas`; added both to the "Lean 4 and formal mathematics tools" `home.packages` group
  with one-line comments.
- `docs/development.md` — added an "Aeneas (Rust-to-Lean verification)" subsection under "Lean 4
  Development" covering what this config provides, why system-wide over a project-local dev
  shell, pipeline usage (`charon cargo --preset=aeneas` then `aeneas -backend lean`), and the
  Verification-repo-local Lake `require` steps (with toolchain-compatibility and rev-pinning
  guidance), plus explicit non-actions (Lean stays elan-managed, no `lean4`/`rustup` added).

## Decisions

- Chose the system-level flake-input approach (not a project-local dev shell in the Verification
  repo) per the plan's Research Integration: the Verification repo has no `flake.nix` at all,
  this repo has an exercised precedent (`lectic`) for exactly this threading pattern, and the
  Aeneas/Charon closures are hermetic (own pinned nixpkgs, Rust nightly, OCaml 5.2) so they don't
  collide with this config's own Rust toolchain.
- Named the resolved packages `aeneas-charon`/`aeneas-aeneas` (not `charon`/`aeneas`) to avoid
  shadowing any same-named `pkgs` attribute inside the `with pkgs;` package list.
- Left `nix.settings.substituters`/`trusted-public-keys` untouched: no public binary cache is
  documented for these packages (confirmed again during implementation — only cache hits seen
  during the build were pre-existing nixpkgs store paths, not a dedicated Aeneas/Charon cache).

## Plan Deviations

- **Task 2.7** skipped: the plan's own contingency step ("if `sudo nixos-rebuild switch` is not
  runnable by the agent, state in the summary that the user should run `scripts/update.sh`") was
  never runnable by this agent (no sudo access), exactly as the plan's own risk table
  anticipated. The NixOS-integrated path was verified via `nix build
  .#nixosConfigurations.hamsa.config.system.build.toplevel` instead (full build succeeded). **The
  user should run `scripts/update.sh` (or `sudo nixos-rebuild switch --flake .#hamsa`) to sync the
  NixOS-integrated home-manager profile** — the standalone profile (`~/.nix-profile`) was already
  activated and takes PATH priority, so `charon`/`aeneas` are already usable today, but the
  system-level profile has not yet been switched.

## Verification

- Build: Success — `nix build --no-link --print-out-paths
  .#homeConfigurations.benjamin.activationPackage` completed (from-source build of `charon` and
  `ocaml5.2.1-aeneas-0.1.0`); `nix build --no-link
  .#nixosConfigurations.hamsa.config.system.build.toplevel` also completed.
- Tests: N/A (no test suite; verification was functional — see below)
- Files verified: Yes
- `nix flake metadata` / `nix flake show github:AeneasVerif/aeneas/86158eb2...` — confirmed
  `packages.x86_64-linux.charon` and `packages.x86_64-linux.aeneas` exist at the locked rev.
- `home-manager switch --flake .#benjamin` — activated successfully.
- `charon --help` and `aeneas -help` — both exit 0 from a fresh shell, resolving to
  `/home/benjamin/.nix-profile/bin/{charon,aeneas}`.
- `rustc --version` / `cargo --version` / `elan --version` — identical paths and versions before
  and after (rustc 1.95.0, cargo 1.95.0, elan 4.2.1); `git diff` confirms no `rustup`/`lean4`
  additions and no changes to `modules/home/packages/rust.nix`, `modules/system/packages.nix`,
  or any `nix.settings` block.
- `nix flake check --no-build` — "all checks passed!" (pre-existing ZFS eval warnings on
  `nandi`/`usb-installer` are unrelated to this change).
- `statix check` — no new warnings on `flake.nix`, `lib/mkHost.nix`,
  `modules/home/packages/misc.nix`, or `docs/development.md`.
- Full diff scope confirmed limited to exactly the five expected files: `flake.nix`,
  `flake.lock`, `lib/mkHost.nix`, `modules/home/packages/misc.nix`, `docs/development.md`.

## Impacts

- `charon` and `aeneas` are now available on `PATH` for the `benjamin` user via the standalone
  home-manager profile immediately, and will also reach the NixOS-integrated profile (and the
  `iso` image, which shares `hmExtraSpecialArgs`) on the next `sudo nixos-rebuild switch` /
  `scripts/update.sh` run.
- A second nixpkgs evaluation is now pulled in via the `aeneas` flake input's own pinned nixpkgs;
  this is an accepted, documented cost (see the input's comment in `flake.nix`), not a defect.
- The Verification project (`/home/benjamin/Projects/Logos/Verification`) was not modified; its
  own Lean-side Lake `require` of `backends/lean` remains to be added there, per the new
  `docs/development.md` instructions.

## Follow-ups

- Run `scripts/update.sh` (or `sudo nixos-rebuild switch --flake .#hamsa`) to sync the
  NixOS-integrated home-manager profile with the newly-installed `charon`/`aeneas` (the
  standalone profile is already active and usable).
- In the Verification repo, add the Lake `[[require]]` block for `aeneas`'s `backends/lean`
  subdirectory (pinned to revision `86158eb2e18944c5225959712efb96bce188f40d`, the same commit
  locked here) once that repo's pending recommendation task resolves — see
  `docs/development.md`'s new "Aeneas (Rust-to-Lean verification)" subsection for the full steps,
  including the `lean-toolchain` compatibility check.

## References

- specs/132_add_aeneas_rust_to_lean_verification_tooling/plans/01_aeneas-rust-lean-tooling.md
- specs/132_add_aeneas_rust_to_lean_verification_tooling/reports/01_aeneas-rust-lean-tooling.md
- docs/development.md ("Aeneas (Rust-to-Lean verification)" subsection)
