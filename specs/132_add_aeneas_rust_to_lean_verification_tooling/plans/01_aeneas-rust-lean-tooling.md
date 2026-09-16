# Implementation Plan: Task #132

- **Task**: 132 - Add Aeneas Rust-to-Lean verification tooling
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours (plus unattended first-build time for charon/aeneas from source)
- **Dependencies**: None
- **Research Inputs**: specs/132_add_aeneas_rust_to_lean_verification_tooling/reports/01_aeneas-rust-lean-tooling.md
- **Artifacts**: plans/01_aeneas-rust-lean-tooling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add Charon and Aeneas to this NixOS/home-manager config as a system-level flake input
(`aeneas.url = "github:AeneasVerif/aeneas"`, deliberately without `inputs.nixpkgs.follows`),
pre-resolving `aeneas.packages.${system}.charon` and `.aeneas` and threading them to
home-manager the same way `lectic` is threaded today, then consuming them in
`modules/home/packages/misc.nix`'s "Lean 4 and formal mathematics tools" group. No binary cache
is added (none is documented upstream). The Lean side of Aeneas (Lake `require` of
`backends/lean`) is documented as Verification-repo instructions in `docs/development.md`, not
configured here. Done when both home-manager paths evaluate, `charon --help` and `aeneas -help`
run from PATH after a switch, and the docs section exists.

### Research Integration

- Approach 1 (system-level flake input) chosen over a project-local dev shell: the Verification
  repo has no `flake.nix` at all, this repo has an exercised precedent (`lectic`), and the
  Aeneas/Charon closures are hermetic (own pinned nixpkgs, Rust nightly, OCaml 5.2), so they do
  not collide with `modules/home/packages/rust.nix`.
- Live-verified output names: `packages.x86_64-linux.charon` and `packages.x86_64-linux.aeneas`
  (`ocaml5.2.1-aeneas-0.1.0`, binary `aeneas`).
- No public Cachix cache documented for these outputs (`hacl.cachix.org` is an internal CI cache)
  -> leave `nix.settings.substituters`/`trusted-public-keys` untouched.
- The Verification repo's pending recommendation task is itself asking the same install-path
  question and has not started; it does not redirect the decision.
- `aeneas -help` (single dash, OCaml CLI) and `charon --help` (double dash, clap) are both
  correct as written.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path in dispatch).

## Goals & Non-Goals

**Goals**:
- Add the `aeneas` flake input with an explanatory comment on why it does not follow nixpkgs.
- Thread resolved `charon` and `aeneas` packages to both home-manager paths (NixOS-integrated via
  `lib/mkHost.nix`, standalone via `hmExtraSpecialArgs`).
- Install both binaries via `home.packages` in `modules/home/packages/misc.nix`.
- Verify `charon --help` and `aeneas -help` after rebuild.
- Document Verification-repo-local configuration (Lake `require`, toolchain compatibility, usage
  commands) in `docs/development.md`.

**Non-Goals**:
- Touching `elan`, `modules/home/packages/rust.nix`, or adding `lean4`/`rustup`.
- Adding any substituter or trusted public key.
- Creating a `flake.nix` or editing any file in `/home/benjamin/Projects/Logos/Verification`
  (instructions only).
- Installing `aeneas-release`, `aeneas-static*`, or `charon-ml` variants.
- Adding a new `context/project/nix/patterns/` doc (research suggestion; out of scope here).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| First build compiles charon (Rust nightly) and aeneas (OCaml) from source; slow, may look hung | M | H | Run builds with `run_in_background`/long timeouts; build the two packages alone first (`nix build .#...` style targeted build) before a full switch; note it in the summary |
| Upstream `main` changes output names or breaks build between research and implement | M | L | Phase 1 re-checks `nix flake show` output names after `flake.lock` pins the input; `flake.lock` then freezes the revision |
| Second nixpkgs evaluation increases eval time/disk | L | H | Expected; documented in the input comment |
| `hmExtraSpecialArgs` also feeds the `iso` config, so the ISO image would pull in charon/aeneas | L | M | Accept (ISO shares home.nix by design); mention in summary. Do not special-case unless ISO eval fails |
| `sudo nixos-rebuild switch` unavailable to the agent | M | M | Verify via standalone `home-manager switch --flake .#benjamin` (no sudo, and `~/.nix-profile` takes PATH priority) plus `nix build` of the host toplevel for the NixOS path; leave the sudo switch to the user if needed |
| Charon version expected by Aeneas mismatches | L | L | Both come from the same Aeneas flake (its `charon` input), so they are pinned together by construction; never source charon separately |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add aeneas flake input and thread packages [COMPLETED]

**Goal**: Declare the input and make resolved `charon`/`aeneas` derivations available as
home-manager specialArgs on both home-manager paths.

**Tasks**:
- [x] In `flake.nix` `inputs`, add `aeneas.url = "github:AeneasVerif/aeneas";` with NO
  `inputs.nixpkgs.follows`, preceded by a comment (matching the `lean4` input's comment style)
  explaining: upstream pins its own nixpkgs for OCaml 5.2 and Charon pins its own Rust nightly,
  so following our nixpkgs would break the build; no public binary cache is documented, so the
  first build is from source. *(completed)*
- [x] Add `aeneas` to the `outputs` function argument set. *(completed)*
- [x] Add to `hmExtraSpecialArgs`: `aeneas-charon = aeneas.packages.${system}.charon;` and
  `aeneas-aeneas = aeneas.packages.${system}.aeneas;` (or equivalent clear names; pick one naming
  and use it consistently — must not shadow the flake input name inside `flake.nix`).
  *(completed)*
- [x] Pass `aeneas` into the `import ./lib/mkHost.nix { ... }` inherit list. *(completed)*
- [x] In `lib/mkHost.nix`, add `aeneas` to the argument set and add the same two resolved
  entries to the home-manager `extraSpecialArgs` block (the NixOS-level `specialArgs` does not
  need them; only home modules consume them). *(completed)*
- [x] Run `nix flake lock --update-input aeneas` (or `nix flake lock`) so `flake.lock` records the
  pinned revision; confirm with `nix flake metadata` that only the `aeneas` subtree was added.
  *(completed)*
- [x] Re-confirm output names against the locked revision: run
  `nix flake show github:AeneasVerif/aeneas/<locked-rev>` (rev from
  `jq -r '.nodes.aeneas.locked.rev' flake.lock`) and check `packages.x86_64-linux.charon` and
  `.aeneas` exist. *(completed: confirmed packages.x86_64-linux.charon and .aeneas exist at rev
  86158eb2)*
- [x] `nixfmt` the two edited files (repo uses the RFC 166 formatter declared in `flake.nix`).
  *(completed: no additional formatting changes needed)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: Exactly three edit sites need the resolved packages for home-manager:
`flake.nix` `hmExtraSpecialArgs` (covers standalone `homeConfigurations.benjamin` and the `iso`
config), `flake.nix`'s `mkHost` import inherit list, and `lib/mkHost.nix`'s home-manager
`extraSpecialArgs`. Confirm with `grep -n "lectic" flake.nix lib/mkHost.nix` and check that every
home-manager `extraSpecialArgs` site either is or merges `hmExtraSpecialArgs` or is the mkHost
block.

**Files to modify**:
- `flake.nix` - new input + comment, outputs arg, `hmExtraSpecialArgs`, mkHost inherit
- `lib/mkHost.nix` - new arg, home-manager `extraSpecialArgs` entries
- `flake.lock` - new locked `aeneas` (and transitive `charon`, `fstar`, etc.) nodes

**Verification**:
- `nix flake metadata` shows the `aeneas` input locked.
- Evaluation still succeeds with the new (not yet consumed) specialArgs:
  `nix eval .#homeConfigurations.benjamin.activationPackage.drvPath` and
  `nix eval .#nixosConfigurations.$(hostname).config.system.build.toplevel.drvPath`.

---

### Phase 2: Install charon and aeneas via home.packages and verify [COMPLETED]

**Goal**: Put both binaries on PATH through home-manager and confirm they run.

**Tasks**:
- [x] In `modules/home/packages/misc.nix`, extend the module signature with the two new
  specialArgs and add both to the "Lean 4 and formal mathematics tools" group with one-line
  comments (Charon: Rust MIR -> LLBC extractor; Aeneas: LLBC -> Lean/Coq/F*/HOL4 translator).
  Since the list uses `with pkgs;`, reference the specialArg names directly (hyphenated names are
  valid Nix identifiers; if a name would be shadowed by a `pkgs` attribute, rename to avoid it —
  e.g. `pkgs.charon` may exist in nixpkgs, which is why the non-colliding `aeneas-charon` naming
  is preferred). *(completed)*
- [x] Update `misc.nix`'s header comment only if needed to mention Rust-to-Lean tooling.
  *(completed)*
- [x] Build the two packages alone first to absorb the from-source compile, in the background
  with a long timeout, e.g.
  `nix build --no-link --print-out-paths .#homeConfigurations.benjamin.activationPackage`
  (this builds charon/aeneas as dependencies). Expect a long first build. *(completed: built
  successfully, output /nix/store/cwj9xjkhr10s3whznwcs5ipwrfi0q1wl-home-manager-generation)*
- [x] Evaluate the NixOS path for the current host:
  `nix build --no-link .#nixosConfigurations.$(hostname).config.system.build.toplevel` (or at
  minimum `nix eval ...drvPath` if a full build is too costly). *(completed: full build succeeded
  for host hamsa)*
- [x] Activate without sudo: `home-manager switch --flake .#benjamin`. *(completed)*
- [x] Run `charon --help` and `aeneas -help`; both must exit successfully and print usage.
  Record `which charon aeneas` output. *(completed: both exit 0;
  /home/benjamin/.nix-profile/bin/charon and /home/benjamin/.nix-profile/bin/aeneas)*
- [x] Confirm untouched toolchains: `rustc --version`, `cargo --version`, `elan --version` still
  resolve to the same paths as before (capture before/after), and no `rustup`/`lean4` entries
  were added (`git diff` review). *(completed: identical paths/versions before and after; no
  rustup/lean4 additions in the diff)*
- [ ] If `sudo nixos-rebuild switch --flake .#<host>` is not runnable by the agent, state in the
  summary that the user should run `scripts/update.sh` (which runs both paths) to sync the
  NixOS-integrated profile. *(deviation: skipped — sudo unavailable to the agent per the plan's
  own risk mitigation; noted for the summary instead)*

**Timing**: 45 minutes of active work (build wall-clock time may be substantially longer)

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `modules/home/packages/misc.nix` - module args + two `home.packages` entries

**Verification**:
- `charon --help` and `aeneas -help` both succeed from a fresh shell.
- `git diff` shows no changes to `modules/home/packages/rust.nix`, `modules/system/packages.nix`,
  or any `nix.settings` block.

---

### Phase 3: Document Verification-repo local configuration [COMPLETED]

**Goal**: Produce specific, durable instructions for what the Verification repo must configure
itself (the Lean side), placed in this repo's user-facing development docs.

**Tasks**:
- [x] Add an "Aeneas (Rust-to-Lean verification)" subsection to `docs/development.md`, under or
  next to the existing "Lean 4 Development" section, covering:
  - What this config provides (`charon`, `aeneas` on PATH via home-manager; from the Aeneas
    flake, pinned in `flake.lock`; update with `nix flake lock --update-input aeneas`; first
    build is from source, no binary cache).
  - Why system-wide rather than a project-local dev shell (short rationale).
  - Pipeline usage: from the Rust crate directory run `charon cargo --preset=aeneas` to produce
    the `.llbc`, then `aeneas -backend lean <file>.llbc` to generate Lean.
  - Verification-repo-local steps (NOT done by this config): add a Lake dependency to the Lean
    project's `lakefile.toml`:
    ```toml
    [[require]]
    name = "aeneas"
    git = { url = "https://github.com/AeneasVerif/aeneas", subDir = "backends/lean" }
    rev = "<commit>"
    ```
    pinning `rev` to the same Aeneas commit as this repo's `flake.lock` so the generated code and
    the Lean library agree; check `backends/lean/lean-toolchain` at that commit against the
    project's own `lean-toolchain` before adding (mismatch must be reconciled in the project, not
    here); note that adding the `require` makes a currently dependency-free Lake build fetch from
    the network, which should be called out in that project's README; run `lake update aeneas`
    then `lake build`.
  - Explicit non-actions: Lean stays elan-managed, no `lean4`/`rustup` from Nix.
  *(completed)*
- [x] Use durable anchors only (file paths, section names) — no task-number references in this
  deliverable (`.claude/rules/no-task-references-in-deliverables.md`). *(completed)*
- [x] Reference the helper command for reading the locked rev, e.g.
  `jq -r '.nodes.aeneas.locked.rev' flake.lock`. *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `docs/development.md` - new Aeneas subsection

**Verification**:
- Section renders as valid markdown; TOML block matches the upstream README's documented form.
- `grep -nE "task [0-9]+" docs/development.md` finds no new task references.

---

### Phase 4: Final gate and cleanup review [NOT STARTED]

**Goal**: Confirm the whole change set is consistent and nothing out of scope was touched.

**Tasks**:
- [ ] `nix flake check --no-build` (or the repo's usual evaluation check) passes.
- [ ] `statix check` (repo has `statix.toml`) reports no new warnings in edited files.
- [ ] Re-run `charon --help` and `aeneas -help`.
- [ ] Review full `git diff` / `git status --short`: only `flake.nix`, `flake.lock`,
  `lib/mkHost.nix`, `modules/home/packages/misc.nix`, `docs/development.md` changed.
- [ ] If Phase 3 docs embed a rev placeholder, confirm the lookup command against the real
  `flake.lock`.

**Timing**: 30 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None expected (fixups only)

**Verification**:
- All checks above green; diff limited to the five listed files.

## Testing & Validation

- [ ] `nix flake metadata` lists a locked `aeneas` input without a `nixpkgs` follows override.
- [ ] Standalone home-manager activation package builds; `home-manager switch --flake .#benjamin`
  succeeds.
- [ ] NixOS toplevel for the current host evaluates (and builds if feasible).
- [ ] `charon --help` exits 0.
- [ ] `aeneas -help` exits 0.
- [ ] `rustc`/`cargo`/`elan` paths unchanged; no substituters added.
- [ ] `docs/development.md` contains the Verification-repo instructions.

## Artifacts & Outputs

- `flake.nix`, `flake.lock`, `lib/mkHost.nix`, `modules/home/packages/misc.nix` (config changes)
- `docs/development.md` (Aeneas subsection with Verification-repo instructions)
- `specs/132_add_aeneas_rust_to_lean_verification_tooling/summaries/01_aeneas-rust-lean-tooling-summary.md`

## Rollback/Contingency

All changes are confined to five tracked files and are committed per phase, so rollback is a
`git revert` of the task's phase commits followed by `home-manager switch --flake .#benjamin`
(and `scripts/update.sh` for the NixOS-integrated profile); previous home-manager generations
also remain available via `home-manager generations`. If the Aeneas flake fails to build on the
locked revision, pin the input to a known-good commit (`github:AeneasVerif/aeneas/<rev>`) rather
than adding `nixpkgs.follows`; if still broken, stop and report rather than falling back to a
project-local dev shell without user input. For any rollback that must discard uncommitted work,
follow `context/contracts/recovery.md`'s rollback rung for the snapshot invocation shape.
