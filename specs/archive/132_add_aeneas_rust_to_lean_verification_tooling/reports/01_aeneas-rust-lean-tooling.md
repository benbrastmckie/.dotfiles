# Research Report: Task #132

- **Task**: 132 - Add Aeneas Rust-to-Lean verification tooling
- **Started**: 2026-09-16T18:00:00Z
- **Completed**: 2026-09-16T18:10:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: `flake.nix`, `lib/mkHost.nix`, `modules/home/packages/{rust,misc,dev-tools}.nix`, `modules/home/default.nix`, `modules/system/packages.nix`, `overlays/unstable-packages.nix`, `packages/README.md`
  - Live flake introspection: `nix flake show github:AeneasVerif/aeneas --all-systems`, `nix eval github:AeneasVerif/aeneas#packages.x86_64-linux ...`
  - Upstream docs: `AeneasVerif/aeneas` README + `flake.nix`, `AeneasVerif/charon` README, `AeneasVerif/aeneas` `.github/workflows/ci.yml`
  - Sibling project: `/home/benjamin/Projects/Logos/Verification/specs/TODO.md` (task 24), `framed_channel/{rust,lean}` sources
- **Artifacts**:
  - This report
- **Standards**: report-format.md, subagent-return.md, nix.md

## Executive Summary

- **Recommendation: system-level flake input (Approach 1)**, not a project-local dev shell.
  Add `aeneas.url = "github:AeneasVerif/aeneas"` to this repo's `flake.nix` with **no**
  `inputs.nixpkgs.follows`, and expose `charon`/`aeneas` via `home.packages` alongside the
  existing Lean/formal-verification tooling in `modules/home/packages/misc.nix`.
- Real flake output names confirmed live: `aeneas.packages.x86_64-linux.charon` (package
  `charon`) and `aeneas.packages.x86_64-linux.aeneas` (package `ocaml5.2.1-aeneas-0.1.0`,
  binary `aeneas`). Both exist for `x86_64-linux`, the only system this config targets.
  `aeneas-release`/`aeneas-static`/`aeneas-static-release`/`charon-ml` also exist but are not
  needed for this use case (they are release/static-linking/OCaml-library variants).
- Aeneas's own `flake.nix` pins a **separate, unrelated nixpkgs revision**
  (`github:NixOS/nixpkgs/b3d51a0365f6695e7dd5cdf3e180604530ed33b4`) specifically to keep OCaml
  5.2 buildable, and Charon (Aeneas's own `charon` input) pins its own Rust nightly toolchain
  via `oxalica/rust-overlay` + `ipetkov/crane`. This confirms the dispatch's premise: do **not**
  add `inputs.nixpkgs.follows = "nixpkgs"` on the `aeneas` input — doing so would fight the
  upstream flake's own pinning and risk breaking the OCaml 5.2/Rust-nightly build.
- **No binary cache should be added.** Neither project's README documents a public Cachix
  cache for the `charon`/`aeneas` package outputs. The only Cachix reference found is
  `hacl.cachix.org`, used internally by Aeneas's CI for a HACL*/F* dependency in one CI job
  (with `skipAddingSubstituter: true`), and a private, auth-token-gated `cachix push` target
  named `hacl` — neither is a documented public read cache for `charon`/`aeneas` consumers.
  Per the dispatch's "only if documented" instruction, `nix.settings.substituters` /
  `trusted-public-keys` should be left untouched. First rebuild will build both packages from
  source (a real Rust + OCaml compile; budget rebuild time/disk accordingly).
- Existing config precedent strongly favors home-manager (`home.packages`), not
  `environment.systemPackages`, for this class of tool: the Rust toolchain
  (`modules/home/packages/rust.nix`), the Comparator Lean proof-verification toolchain
  (`landrun`/`comparator`/`comparator-lean4export-resolve` in `dev-tools.nix`), and `lectic`/
  `loogle` (in `misc.nix`'s "Lean 4 and formal mathematics tools" section) are all
  home-manager. `environment.systemPackages` is used for `elan` (the Lean version manager)
  and broad desktop/CLI tooling, not for per-toolchain formal-verification binaries — Aeneas/
  Charon fit the home-manager pattern, not the system one.
- The sibling Verification repo's own task 24 (`[NOT STARTED]`, in
  `specs/TODO.md`) is the "pending recommendation task" named in this task's description. It
  asks whether to install via "nix flake github:aeneasverif/aeneas vs rustup+opam" — i.e. it
  defers the install-path decision to wherever the tools actually get installed, which is this
  dotfiles task. It has not reached a decision (status `[NOT STARTED]`) and does not block or
  redirect this task's system-vs-project-local choice; it does, however, confirm the two
  concrete verification commands (`charon cargo --preset=aeneas`, `aeneas -backend lean`) this
  task's `charon --help`/`aeneas -help` checks should validate.

## Context & Scope

Researched how to add Aeneas (Rust-to-Lean verification toolchain: Charon extracts Rust MIR to
an IR called LLBC; Aeneas translates LLBC to a Lean/Coq/F*/HOL4 backend) to this NixOS/home-manager
config, without touching the existing Lean (`elan`-managed) or Rust (`rustc`/`cargo`/`clippy`/
`rustfmt` via `modules/home/packages/rust.nix`) toolchains, and without adding `lean4` or
`rustup`. Scope covers: (1) system-level flake input vs. project-local dev shell decision, (2)
real, live-verified flake output attribute names, (3) whether a binary cache should be added,
(4) where in this config's existing conventions the packages should be wired, and (5) what
belongs in the Verification repo instead (the Lean-side `require aeneas from ...` dependency).

## Findings

### Codebase Patterns

- **Flake input + specialArg threading pattern** (the precedent to mirror): `lectic` is
  declared as a flake input in `flake.nix` (`lectic.url = "github:gleachkr/lectic"`, with
  `inputs.nixpkgs.follows = "nixpkgs"` — unlike Aeneas, lectic *does* follow the shared
  nixpkgs, which is precisely the contrast the dispatch draws). The *resolved package* —
  `lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic` — is
  computed identically in three places: `flake.nix`'s `hmExtraSpecialArgs` (for the standalone
  `homeConfigurations.benjamin`), and twice in `lib/mkHost.nix` (once in the NixOS-integrated
  home-manager `extraSpecialArgs`, once in the bare `nixosConfigurations` `specialArgs`). The
  consuming module, `modules/home/packages/misc.nix`, declares `{ pkgs, lectic, ... }:` and uses
  `lectic` directly in its `home.packages` list, under a comment header "Lean 4 and formal
  mathematics tools" that already groups `lectic` and `loogle` together.
- **Raw-flake-passthrough pattern** (alternative, currently unused downstream): `nix-ai-tools`
  is instead passed as the *whole flake* (not pre-resolved to a package) through the same three
  specialArgs sites, but nothing in `modules/` currently consumes it — there is no established
  precedent yet for a consumer resolving `.packages.${system}.X` itself inside a module. The
  lectic pattern (pre-resolve at the flake/mkHost level, pass the resolved derivation) is the
  only *exercised* precedent, and is the one to follow for `charon`/`aeneas` since two packages
  need resolving here (mirror it twice: `aeneasCharon` and `aeneasAeneas`, or thread the flake
  input itself as one specialArg named `aeneas` and resolve `aeneas.packages.${system}.charon`/
  `.aeneas` at the point of use — either is consistent with existing style; pre-resolving two
  named specialArgs is more consistent with lectic's exercised precedent and keeps
  `modules/home/packages/misc.nix` free of `${system}` bookkeeping).
- **home.packages is the established home for formal-verification/Lean-adjacent dev tooling**:
  `modules/home/packages/rust.nix` (rustc/cargo/clippy/rustfmt/rust-analyzer, with
  `RUST_SRC_PATH` set for rust-analyzer), `modules/home/packages/dev-tools.nix`'s Comparator
  block (`landrun`, `comparator`, `comparator-lean4export-resolve`, each sourced from
  `overlays/unstable-packages.nix` via `callPackage ../packages/*.nix`, with a documented
  decision record in `packages/README.md`), and `modules/home/packages/misc.nix`'s `lectic`/
  `loogle`. `environment.systemPackages` (`modules/system/packages.nix`) instead carries `elan`
  (the Lean *version manager*, deliberately left alone per the task description) and broad
  desktop/CLI tools — not per-toolchain formal-verification binaries.
- **`overlays/unstable-packages.nix` pattern is for custom/overridden derivations, not
  external-flake passthroughs**: packages built via `final.callPackage ../packages/*.nix { }`
  (Comparator, landrun, loogle, etc.) are *this repo's own* derivations or deliberate
  version-pin overrides of nixpkgs packages. `charon`/`aeneas` are neither — they are complete,
  already-packaged outputs of an upstream flake with its own pinned toolchain, so they belong
  as a **flake input + specialArg**, matching `lectic`, not as an overlay entry.
- **No existing `nix.settings.substituters`/`trusted-public-keys` block anywhere in this repo**
  (`configuration.nix`, `modules/system/*.nix`, `modules/home/**`) — confirmed by repo-wide
  grep. Adding one for Aeneas would be a first-of-its-kind addition, which is moot here since no
  cache is documented (see below).
- `modules/home/default.nix` is the explicit import aggregator for all home-manager package
  modules (`./packages/dev-tools.nix`, `./packages/rust.nix`, `./packages/misc.nix`, etc.) —
  `misc.nix` is already imported, so extending it (rather than adding a new file to the
  aggregator) is the lower-footprint integration path, consistent with `misc.nix`'s own header
  comment that it merges "each too small to justify its own file" groups. Given Aeneas needs
  only ~2 packages (no wrapper scripts, no session variables beyond what's already shown
  possible in this file), extending `misc.nix`'s existing Lean section is the natural fit
  rather than introducing a new `packages/aeneas.nix` module.

### External Resources — Live Flake Introspection

Ran `nix flake show github:AeneasVerif/aeneas --all-systems` and targeted `nix eval` against
the live flake (network-fetched during this research session, not from memory):

- `packages.x86_64-linux` attribute names: `aeneas`, `aeneas-release`, `aeneas-static`,
  `aeneas-static-release`, `charon`, `charon-ml`, `default` (== `aeneas`).
  - `packages.x86_64-linux.aeneas` → derivation `ocaml5.2.1-aeneas-0.1.0`.
  - `packages.x86_64-linux.charon` → derivation `charon` (built via `oxalica/rust-overlay` +
    `ipetkov/crane`, confirming Charon's own separate, non-`nixpkgs.follows` Rust nightly pin).
  - `charon-ml` is the OCaml library half of Charon (`ocaml5.2.1-charon-0.1.0`) — not needed
    for CLI usage of `charon`/`aeneas`.
  - `aeneas-static*` variants exist for musl/static distribution (release artifacts), not
    relevant to a Nix-store-based home-manager install.
  - `checks.x86_64-linux` includes `aeneas-tests`, `aeneas-verify-{coq,fstar,hol4}`,
    `check-charon-pin`, `aeneas-check-tidiness` — CI-only, not consumed here.
  - `devShells.<system>.default` also exists on every system — this is the shape Approach 2
    (project-local `nix develop`) would have used, confirming a dev shell is available upstream
    if that path were ever chosen instead.
- Aeneas's `flake.nix` inputs: `charon.url = "github:aeneasverif/charon"`,
  `flake-utils.follows = "charon/flake-utils"`, its own pinned `nixpkgs` (a specific revision,
  explicitly commented as pinned to keep `ocaml5.2` / `ocaml-lsp 1.21` buildable), and
  `fstar.url = "github:FStarLang/fstar"`. No `nixpkgs.follows` back to a consumer's nixpkgs
  anywhere in its own inputs — this is upstream's own deliberate isolation, matching the
  dispatch's premise exactly.
- Binary/CLI usage confirmed from upstream READMEs: `charon cargo --preset=aeneas` (run from
  inside the target Rust crate) produces the `.llbc` file; `aeneas -backend lean [OPTIONS]
  LLBC_FILE` (binary at `./bin/aeneas` when built from source; on Nix, `aeneas` on `PATH`)
  consumes it. `aeneas --help` and `charon --help`/`charon cargo --preset=aeneas --help`-style
  invocations are the documented way to see full flag listings — matching the dispatch's
  verification step.
- **Cachix / binary cache check**: grepped both READMEs (`AeneasVerif/aeneas`,
  `AeneasVerif/charon`) for "cachix", "binary cache", "substituter" — no matches. Fetched
  `AeneasVerif/aeneas/.github/workflows/ci.yml` directly and found `cachix/cachix-action@v17`
  used with `name: hacl` and `skipAddingSubstituter: true`, gated on
  `secrets.CACHIX_AUTH_TOKEN` being present (i.e. a private, maintainer-only push target for a
  HACL*/F* dependency used in one CI job, referenced as `extra-substituters =
  https://hacl.cachix.org` for *that* build). This is not a documented, public read cache for
  the `charon`/`aeneas` package outputs themselves. Conclusion: no substituter to add.

### Verification Repo Findings (what NOT to configure here)

- `/home/benjamin/Projects/Logos/Verification` has **no `flake.nix` at all** at present —
  only `framed_channel/rust/Cargo.toml` (plain cargo project, no nix) and
  `framed_channel/lean/lakefile.toml` (a Lake project pinned to
  `leanprover/lean4:v4.27.0-rc1` via `lean-toolchain`, with **no `require` directive today** —
  it builds against core Lean + bundled `Std` only, explicitly documented as deliberate in the
  lakefile's header comment).
- Verification repo task 24 (`specs/TODO.md`, `[NOT STARTED]`, topic "framed-channel",
  depends on task 22) is the "pending recommendation task" referenced in this task's
  description. Its scope: extract `framed_channel/rust/src`'s ring buffer (and possibly
  channel/varint/crc8) via `charon cargo --preset=aeneas` + `aeneas -backend lean`, then
  reconcile against the existing hand-written `QueueModel`/`BoundedQueueLaws`/refinement Lean
  code. It explicitly lists "install path on NixOS (nix flake github:aeneasverif/aeneas vs
  rustup+opam)" as one of the things *its own* research must assess — i.e., it is itself asking
  the same install-path question this task answers, not providing an answer to defer to. It has
  not started, so there is no existing decision in that repo to reconcile against.
- **What belongs in the Verification repo instead of this NixOS config** (per the dispatch):
  the Lean-side Aeneas dependency is a **per-project Lake `require`**, not a system package.
  Once `charon`/`aeneas` produce `.lean` files that `import Aeneas`, the
  `framed_channel/lean/lakefile.toml` would need a block such as:
  ```toml
  [[require]]
  name = "aeneas"
  git = { url = "https://github.com/AeneasVerif/aeneas", subDir = "backends/lean" }
  rev = "COMMIT_HASH_HERE"
  ```
  (per `AeneasVerif/aeneas`'s own README "Usage" section, "additional steps for the Lean
  backend"). This is Lake-fetched per-project, exactly as the dispatch anticipated, and is
  **out of scope for this NixOS/home-manager task** — it belongs in a future Verification-repo
  task (likely folded into, or following, task 24). Two things worth flagging for whoever picks
  that up: (a) the `aeneas` Lean backend package's `lean-toolchain` (inside
  `backends/lean`) must be checked for compatibility with `framed_channel/lean`'s pinned
  `v4.27.0-rc1` before adding the `require` — Aeneas's own README instructs "Overwrite the
  `lean-toolchain` with the one inside `./backends/lean`" when starting a *new* package, which
  will not directly apply to an existing pinned project and needs reconciling; (b) the
  `framed_channel/lean` project's Lake manifest currently has zero dependencies (a deliberately
  network-free clean build, per its own header comment), so adding this `require` changes that
  property and should be called out explicitly in that project's README when it happens.

## Decisions

- **Use Approach 1 (system-level flake input in this dotfiles repo's `flake.nix`)**, not
  Approach 2 (project-local Verification-repo dev shell). Rationale: (a) the Verification repo
  has no flake at all today, so Approach 2 would require introducing net-new nix infrastructure
  there, outside this task's scope; (b) this repo already has an established, working pattern
  for exactly this shape of dependency (external flake, own pinned toolchain, exposed via
  `home.packages`) in the `lectic` and Comparator precedents; (c) Charon/Aeneas's own hermetic
  build (independent nixpkgs/Rust-nightly/OCaml pins) means installing them system-wide carries
  no version-conflict risk with the existing `rustc`/`cargo`/`clippy`/`rustfmt` in
  `modules/home/packages/rust.nix` — Aeneas's toolchain never touches the PATH-level Rust
  toolchain, only its own build closure; (d) Rust-to-Lean verification tooling is
  general-purpose (useful to any future Rust project, not framed_channel-specific), matching
  this repo's "install once system-wide" convention for Lean/Rust dev tooling.
- **Do not add `inputs.nixpkgs.follows`** on the new `aeneas` flake input — confirmed necessary
  by inspecting Aeneas's own `flake.nix`, which pins its own nixpkgs revision and does not
  follow a consumer's nixpkgs anywhere in its own input graph.
- **Do not add any `nix.settings.substituters`/`trusted-public-keys` entries** — no public
  binary cache is documented for the `charon`/`aeneas` package outputs; the only Cachix
  reference found (`hacl.cachix.org`) is an internal CI dependency cache, gated and
  auth-token-scoped, not intended for end-consumer substitution.
- **Wire the two packages via home-manager, extending `modules/home/packages/misc.nix`'s
  existing "Lean 4 and formal mathematics tools" section**, following the exercised `lectic`
  specialArg-threading pattern (pre-resolve `aeneas.packages.${system}.charon` and
  `aeneas.packages.${system}.aeneas` in `flake.nix` + both spots in `lib/mkHost.nix`, pass as
  two new `hmExtraSpecialArgs`/`extraSpecialArgs` entries, consume in `misc.nix`'s module
  signature).
- **Do not touch** `elan`, the existing `rust.nix` module, or add `lean4`/`rustup` anywhere —
  none of the research surfaced any reason to.

## Risks & Mitigations

- **First-build cost**: with no binary cache, the first `nixos-rebuild switch` (or
  `home-manager switch`) after adding the input will compile `charon` (Rust) and `aeneas`
  (OCaml) from source, which is a real, possibly multi-minute-to-tens-of-minutes build (plus
  Aeneas's own pinned nixpkgs revision may itself need substantial store-path fetching the
  first time it's evaluated). Mitigation: this is a one-time cost; note it in the plan so it
  isn't mistaken for a hang, and do not attempt to work around it by adding an undocumented
  cache.
- **Two independent nixpkgs evaluations**: because Aeneas's flake pins its own nixpkgs (not
  `follows`), `nix flake show`/evaluation of this repo's flake will now transitively evaluate a
  second nixpkgs tree for the `aeneas` input specifically. This is expected and matches how
  `lectic` (which *does* follow) differs in shape from `aeneas` (which does not) — worth a
  one-line comment in `flake.nix` at the input declaration explaining why, mirroring the
  existing explanatory comment style already used for the `lean4` input in this repo's
  `flake.nix`.
- **`aeneas -help` vs `--help`**: the dispatch description uses `aeneas -help` (single dash,
  matching OCaml-CLI convention seen in the README's `aeneas -backend ...` usage) while
  `charon --help` uses the double-dash Rust/clap convention. Both are correct as written in the
  dispatch and should be used as-is at verification time — this is not a typo to fix, it
  reflects each tool's own CLI parser convention (OCaml vs Rust).
- **Lean-side toolchain mismatch** (Verification repo, out of scope here but worth flagging
  forward): Aeneas's `backends/lean` package's own `lean-toolchain` may not match
  `framed_channel/lean`'s pinned `v4.27.0-rc1`; this is a Verification-repo concern for
  whichever task adds the Lake `require`, not something this task's Nix wiring can pre-empt.

## Context Extension Recommendations

- **Topic**: External-flake-input + specialArg wiring pattern for exposing upstream flake
  packages (as opposed to overlay-based custom derivations).
- **Gap**: `.claude/context/project/nix/patterns/*` does not currently document the
  lectic-style "resolve `input.packages.${system}.X` once, thread through 3 specialArg sites,
  consume by name in a `modules/home/packages/*.nix` module" pattern as a named pattern,
  despite it being an established, repeated idiom in this repo (`lectic`, and now `aeneas`).
- **Recommendation**: consider adding a short pattern doc (e.g.
  `context/project/nix/patterns/external-flake-package-passthrough.md`) generalizing this from
  the `lectic` precedent, since it will likely recur for future formal-verification or
  Lean-ecosystem flake inputs.

## Appendix

- Search queries / commands used: `nix flake show github:AeneasVerif/aeneas --all-systems`;
  `nix eval github:AeneasVerif/aeneas#packages.x86_64-linux --apply builtins.attrNames`;
  `curl https://raw.githubusercontent.com/AeneasVerif/aeneas/main/{README.md,flake.nix}`;
  `curl https://raw.githubusercontent.com/AeneasVerif/charon/main/README.md`;
  `curl https://raw.githubusercontent.com/AeneasVerif/aeneas/main/.github/workflows/ci.yml`;
  repo greps for `clippy|rustfmt|rust-analyzer|cargo`, `elan|lean`, `nix.settings|substituters|
  cachix`, `nix-ai-tools`.
- References: `AeneasVerif/aeneas` (README, flake.nix, ci.yml), `AeneasVerif/charon` (README),
  this repo's `flake.nix`, `lib/mkHost.nix`, `modules/home/packages/{rust,misc,dev-tools}.nix`,
  `modules/home/default.nix`, `modules/system/packages.nix`,
  `/home/benjamin/Projects/Logos/Verification/specs/TODO.md` (task 24),
  `/home/benjamin/Projects/Logos/Verification/framed_channel/{rust/Cargo.toml,lean/lakefile.toml,lean/lean-toolchain}`.
