# Research Report: Provision the Comparator Lean Proof-Verification Toolchain

**Task**: 130 - Provision the Comparator Lean proof-verification toolchain (landrun, lean4export, comparator)
**Started**: 2026-09-07
**Completed**: 2026-09-07
**Effort**: Medium-large (3 new packages/derivations + 1 resolver script + home-manager wiring + real
verification runs)
**Dependencies**: None blocking research; implementation depends on network access to GitHub and the
Lean toolchain release CDN during the Nix build
**Sources/Inputs**: `leanprover/comparator` README + `Main.lean` + `lakefile.toml` (fetched via `gh api`
at commit reachable from `master`, pushed 2026-08-30), `leanprover/lean4export` README + `lakefile.toml`
(`master`, pushed 2026-08-25), `Zouuup/landrun` full commit history and `cmd/landrun/main.go` at
`v0.1.15`/`v0.1.16`/`v0.1.17`/`main`, nixpkgs `pkgs/by-name/la/landrun/package.nix` (pins `v0.1.15`),
local repo files (`flake.nix`, `packages/loogle.nix`, `packages/aristotle.nix`, `packages/README.md`,
`modules/home/packages/dev-tools.nix`, `modules/system/nix.nix`, `overlays/unstable-packages.nix`), and
the four sibling nvim agent-system tasks (153-156) in `~/.config/nvim/specs/state.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **(a) landrun**: nixpkgs' `0.1.15` does **not** satisfy Comparator's README requirement. Verified by
  reading source at both revisions: Comparator invokes landrun with `--ldd --add-exec`, and landrun's
  own `--ldd` implementation was rewritten between `0.1.15` and `main` — `0.1.15` shells out to the
  system `ldd` binary with a **shallow** (non-recursive) dependency scan; `main`/`v0.1.17` use an
  internal, **recursive** ELF dependency resolver (fixing exactly this shallow-scan bug, PR #38/#40).
  `main` is also 4 purely cosmetic commits ahead of the `v0.1.17` tag (README/CI text, a funding file) —
  functionally `main == v0.1.17`. Also relevant: a REFER-permission fix for cross-directory
  rename/link under `--rw` (PR #49, fixes #48) landed after `0.1.15`, directly relevant to `lake build`
  writing build artifacts. **Recommendation: package landrun from a pinned `main`/`v0.1.17` commit, not
  nixpkgs' `0.1.15`.**
- **(b) lean4export**: version-matching is real and structural, not incidental. `lean4export` links
  against a specific Lean release's environment/`.olean` representation; it must be built with the same
  (or ABI-compatible) Lean toolchain as the project it is exporting, which varies per checked project.
  A single system-wide `lean4export` binary is the wrong shape. Worse: tracing Comparator's own
  `Main.lean` shows the sandboxed `lean4export` invocation is given `writablePaths := #[]` and no
  network — a resolver **cannot** build-on-demand from inside the sandboxed call. Recommendation:
  provide a standalone, Nix-packaged **resolver script** invoked by the calling harness *before*
  `comparator` runs, that builds/caches a `lean4export` binary keyed by the target project's exact
  `lean-toolchain` string, with a sidecar file recording that string so a mismatch is structurally
  prevented and machine-detectable (see "Design: lean4export resolver" below).
- **(c) comparator**: has no `flake.nix` of its own (nor does `lean4export`) — both rely purely on
  `lean-toolchain` + `lake`. Its dependency footprint is light (Lean core + `lean4export` only, no
  Mathlib), which makes a **real, pinned Nix derivation** far more tractable than the `loogle.nix`
  precedent (which depends on Mathlib and explicitly trades reproducibility for laziness).
  Recommendation: do not copy `loogle.nix`'s silent-rebuild-in-`~/.cache` pattern for `comparator`
  itself — build it as a real, pinned derivation (see "Design: comparator derivation" below), with
  reasoning recorded explicitly per the task's instruction.
- **(d) nanoda**: defer, explicitly. Its only benefit (a second, independent kernel) is not required
  for the acceptance criteria in this task, and Comparator's own built-in Lean kernel replay already
  gives a first trustworthy verdict. Do not silently omit — record the deferral and leave
  `COMPARATOR_NANODA` unset/undefined so Comparator's own `nanoda_bin` PATH fallback degrades in a
  detectable way if `enable_nanoda` is ever turned on downstream.
- **(e)** `COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`, `COMPARATOR_NANODA` is exactly the contract
  already relied upon by the four nvim-side sibling tasks (153-156, verified by reading
  `~/.config/nvim/specs/state.json`) — no second contract needs to be invented; this task should wire
  Home Manager to export `COMPARATOR_LANDRUN` (fixed path, since landrun is a normal pinned package)
  and leave `COMPARATOR_LEAN4EXPORT` **unset globally** (it must be set per-invocation by the calling
  harness after running the resolver — a fixed global value would be actively wrong once any project
  uses a different Lean version than whatever the resolver last cached).

## Context & Scope

This is a Nix-provisioning task: install/build `landrun`, `lean4export`, and `comparator` so they are
invocable on this host, decide the packaging shape for each (real derivation vs. wrapper), resolve the
per-project `lean4export` version-matching problem, and expose the `COMPARATOR_*` env-var contract that
four sibling tasks in `~/.config/nvim/` (the actual Comparator *caller*) already assume. `nanoda` is
explicitly optional/deferred. The research below verifies claims against primary sources (GitHub API via
`gh`, not web-search summaries) rather than assuming the task description's claims, per its own
instruction to "check this rather than assuming."

## Findings

### Existing Local Configuration

- `flake.nix` already declares a `lean4` input (`github:leanprover/lean4`, `nixpkgs` follows) but it is
  **unused** anywhere in the tree (`grep -rn "lean4\b" --include="*.nix"` finds only the input
  declaration and a commented-out `lean4` line in `modules/system/packages.nix`). It cannot be relied on
  to supply a version-pinned Lean toolchain matching Comparator's `v4.34.0-rc2` without deliberately
  pinning its own `rev`.
- `packages/loogle.nix` is a `writeShellScriptBin` wrapper: on first run it `git clone`s
  `nomeata/loogle` into `~/.cache/loogle`, then builds via `nix develop . --command lake exe cache get
  && lake build loogle` — i.e. it delegates toolchain resolution to **loogle's own flake.nix**, which
  provides `elan` + build tools and lets `elan`/`lake` do their own non-Nix, network-fetching thing
  (Lean toolchain from lean-lang.org's release CDN, Mathlib cache from a separate CDN). `packages/README.md`
  documents this explicitly as a "zero maintenance ... trades reproducibility" choice, justified by
  loogle's heavy Mathlib dependency.
  **This precedent does not transfer to Comparator as-is**: neither `leanprover/comparator` nor
  `leanprover/lean4export` ships a `flake.nix` (confirmed via `gh api .../contents/flake.nix` → 404 on
  both), so there is no upstream Nix entry point to delegate to; and Comparator's own README explicitly
  discourages an implicit "first invocation silently builds/mutates state" shape for a trust-critical
  tool as strongly as the task description does independently.
- `packages/aristotle.nix` is the other Lean-adjacent package (uvx wrapper, zero Nix build at all) — not
  a useful analogue since it never compiles anything.
- Packaging convention (from `overlays/unstable-packages.nix` and `packages/README.md`): new packages
  live at `packages/<name>.nix`, are wired via `final.callPackage ../packages/<name>.nix { }` in
  `overlays/unstable-packages.nix`, documented in `packages/README.md`, and exposed to users via
  `home.packages` in `modules/home/packages/{dev-tools,misc}.nix`.
- `modules/system/nix.nix` already runs `programs.nix-ld` for elan/Lean toolchains and other foreign
  (non-NixOS-patched) binaries — the same nix-ld handling will be needed for any Go/Rust binaries we
  build that dynamically link against a glibc expecting FHS paths, and is *already* needed for
  `~/.elan/bin/{lean,lake}` today, so no new nix-ld work is implied by this task, only continuity of it.
- `modules/home/packages/dev-tools.nix` is the conventional `home.packages` home for developer tooling;
  it currently has no Lean-specific entries (loogle lives in `misc.nix` instead, per `grep` above) — either
  file is a reasonable home, but co-locating with `loogle`/`aristotle` in a manner consistent with
  existing precedent should be a planning-time decision, not invented here.

### (a) landrun: main branch vs. nixpkgs 0.1.15 — evidence, not assumption

nixpkgs' `pkgs/by-name/la/landrun/package.nix` pins:
```
pname = "landrun"; version = "0.1.15";
src = fetchFromGitHub { owner = "Zouuup"; repo = "landrun"; tag = "v0.1.15"; ... };
```//local `nix search nixpkgs#landrun` on this host confirms `0.1.15` is what this flake's pinned
nixpkgs (`nixos-26.05`) actually resolves.

Comparator's own sandbox-argument builder (`Main.lean:80-86`) is:
```lean
def buildLandrunArgs (spawnArgs : LandrunArgs) : Array String :=
  let args := #["--best-effort", "--ro", "/", "--rw", "/dev", "-ldd", "-add-exec"]
  ...
```
So Comparator **always** invokes landrun with the `--ldd` (or `-ldd`, urfave/cli treats single- and
double-dash the same) and `--add-exec` flags on every sandboxed call (both the `lake build` step and
the `lean4export` step). Diffing landrun's `cmd/landrun/main.go` at each tag:

| Ref | `--ldd` implementation |
|---|---|
| `v0.1.15` | `osexec.Command("ldd", binary)` — shells out to the system `ldd` binary, parses its text output, **shallow** (only direct dependencies, not transitive) |
| `v0.1.16` / `v0.1.17` / `main` | `elfdeps.GetLibraryDependencies(binary)` — internal ELF parser, **breadth-first recursive** transitive-dependency resolution (landrun PR #38 "Implement ELF library dependency resolution", PR #40 "fix: implement recursive dependency resolution") |

This is a genuine, concrete gap between `0.1.15` and `main` in exactly the code path Comparator
exercises, not a hypothetical one. On NixOS specifically — where binaries commonly have several layers
of `/nix/store` shared-library indirection — a shallow scan is more likely to miss a transitive
dependency than on an FHS distro, making this fix more relevant here, not less.

Two other post-`0.1.15` changes on `main`/`v0.1.17` also matter for a sandboxed `lake build`:
- PR #49 "fix: use Restrict() to avoid REFER permission denial" — fixes cross-directory rename/link
  failing with `EXDEV` even when the target directory is granted `--rw`. `lake build` commonly does
  write-to-temp-then-rename when producing build artifacts; this is a plausible, concrete failure mode
  for `0.1.15` inside the `.lake` `--rw` boundary Comparator grants.
- The `go-landlock` upgrade to `v0.9.0` (Landlock ABI **V9**, up from the `V5`-max pseudo-version
  `0.1.15` used) landed in `v0.1.16`→`v0.1.17` (confirmed via `go.mod` diff at each ref), and is a
  documented **BREAKING CHANGE** upstream. Since Comparator always passes `--best-effort`, this degrades
  gracefully rather than hard-failing on kernels below V9, but it does mean `0.1.15` enforces a
  materially weaker (older ABI) sandbox even where the kernel supports more.

`main` (HEAD `811cfff5`) is only 4 commits ahead of the `v0.1.17` tag, all cosmetic (test wording,
README, a funding file) — so for practical purposes **`main` and `v0.1.17` are the same landrun**, and
either can be pinned; a tagged commit is the more stable thing to pin in a Nix derivation than a
literal floating `main` ref.

**Verdict**: nixpkgs' `0.1.15` does not satisfy the README's "compiled from the `main` branch's source"
requirement in a way that is merely pedantic — it lacks a correctness fix (recursive ELF dependency
resolution) in the exact flag combination Comparator hardcodes, plus a filesystem-semantics fix
plausibly relevant to `lake build`. **Package landrun from a pinned `main`/`v0.1.17` commit, not from
nixpkgs.**

### (b) lean4export: why "one build" is structurally wrong, and what to do instead

`lean4export`'s own `lean-toolchain` currently reads `leanprover/lean4:v4.34.0-rc2` (same as
Comparator's, today — but this is not guaranteed to stay true, since `lean4export` tracks Lean-core
release cadence and Comparator pins its own toolchain independently). `lean4export` works by loading a
target project's compiled environment (`.olean`) through Lean's own environment/import machinery and
walking it — this means the `lean4export` **binary itself** is built against, and must be
ABI/format-compatible with, whatever Lean version produced the `.olean` files it is asked to read. This
is exactly why Comparator's README says lean4export must be "at a version that is compatible with
whatever Lean version your project is targeting" rather than "the same version as Comparator."

Comparator's own dev recipe (README "Development" section) builds `lean4export` as a `[[require]]`
dependency of Comparator's own Lake workspace (`rev = "master"` in `lakefile.toml`), which means that
particular built binary is compiled under **Comparator's own** toolchain (`v4.34.0-rc2`) — correct only
for checking projects that also target `v4.34.0-rc2`, and silently wrong for any other target project.
A single fixed system-wide `lean4export` (whether built via Comparator's own recipe or packaged directly
in Nix) is therefore the wrong shape for a general-purpose Comparator installation, exactly as the task
description anticipates.

**A second, load-bearing constraint** was found by reading `Main.lean` directly, not assumed: the
sandboxed `lean4export` invocation (`safeExport`, `Main.lean:134-150`) is given
`writablePaths := #[]` (no writable paths at all) and only `--env PATH HOME LEAN_PATH
LEAN_ABORT_ON_PANIC` passed through (no network-related env, and landrun's default posture is
deny-all-unlisted). This means **no version-resolution or build logic can run from inside the
`COMPARATOR_LEAN4EXPORT`-pointed binary at invocation time** — whatever path that env var names must
already be a fully-built, static executable *before* Comparator is invoked. Any "detect the project's
toolchain and build/cache lean4export on demand" logic must live in the calling harness, executed
*before* `lake env comparator config.json` runs, never inside it.

**Design: lean4export resolver.** Package a standalone script/derivation (not a fixed binary) —
call it `comparator-lean4export-resolve` — that:
1. Takes a target project directory (or an explicit `lean-toolchain` string) as its argument.
2. Reads the exact contents of that project's `lean-toolchain` file (the same convention already used
   by the nvim-side `skill-lean-version` skill, which does `cat lean-toolchain` — reuse that
   convention, don't invent a second toolchain-detection mechanism).
3. Computes a filesystem-safe cache key from that exact string (e.g.
   `~/.cache/comparator/lean4export/<slug-of-toolchain-string>/`).
4. If that cache directory does not already contain a built `lean4export` binary: checks out
   `leanprover/lean4export` (pinned rev — see below), overwrites its `lean-toolchain` file with the
   **target project's** toolchain string (so `elan`/`lake` build it under the target's Lean version,
   not lean4export's own upstream default), runs `lake build`, and copies the resulting binary plus a
   sidecar file (e.g. `lean4export.toolchain`, containing the exact toolchain string it was built
   against) into the cache directory.
5. Prints the resolved binary path to stdout (for `COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve <dir>)`),
   and exits non-zero with a clear message if the build fails (e.g. because the target's Lean version is
   too old/new for `lean4export`'s export format to apply) — this must be a loud, distinguishable failure,
   not something that produces a stale binary silently.
6. Because the cache path itself is keyed by the exact `lean-toolchain` string, and the sidecar file
   records what was actually built, a **mismatch becomes structurally hard to produce** (you cannot
   silently get a `v4.9.0`-built binary out of a cache slot keyed to `v4.34.0-rc2`), and a caller —
   including the nvim-side "doctor mode" from sibling task 154 — can trivially verify a match by
   comparing the sidecar file's contents to the target project's `lean-toolchain` byte-for-byte, whether
   `COMPARATOR_LEAN4EXPORT` came from this resolver's default cache path or was overridden by hand to
   point somewhere else (in the override case, the doctor should require the same sidecar convention or
   refuse to certify a match — record this expectation for task 154, but do not implement task 154
   itself, which lives in `~/.config/nvim/`, not this repository).

This script is a reasonable candidate for a `writeShellScriptBin` package (network + build happens at
*resolve* time, which is deliberately outside any landrun sandbox, so there is no purity/impurity
conflict with a Nix derivation the way there would be for `comparator` itself). Pin `lean4export`'s
source via `fetchFromGitHub` at a specific commit the same way as `comparator`/`landrun` (see below) —
but the resolver clones fresh per distinct target toolchain rather than baking a single rev in, since a
future target project may need a `lean4export` state months newer or older than whatever this task
pins on 2026-09-07. Record the initially-pinned rev in the script as a documented default, with a way to
override it (env var or flag) if a target project's toolchain predates what that rev's `lean4export` can
read.

### (c) comparator: real derivation vs. wrapper — the decision, argued

The task explicitly asks for a deliberate argument rather than copying `loogle.nix`. Reasons **not** to
copy the loogle pattern for `comparator`:
1. **Trust semantics.** Comparator's entire purpose is to be the trustworthy party in an adversarial
   check. A wrapper that clones `master` and rebuilds silently on first use (or after a
   `rm -rf ~/.cache/comparator`) means the actual binary being trusted at verification time is
   whatever `leanprover/comparator@master` happened to be on some unrecorded date, with no Nix-store
   provenance and no way to reproduce or audit exactly what ran for a past verdict. That is a bad fit
   for a component whose green/red verdict downstream tasks (153-156) are relying on for a Lean
   proof-verification trust boundary.
2. **Tractability differs from loogle's case.** loogle depends on Mathlib (thousands of files, ~7-8
   minutes and hundreds of MB on first build) — a real Nix derivation for it would be a substantial,
   slow-to-reproduce undertaking, which is why the wrapper trade-off was reasonable there. Comparator's
   dependency graph is Lean core + `lean4export` only (confirmed via `lakefile.toml`: one `[[require]]`
   entry, no Mathlib) — this is light enough that a pinned, offline-buildable Nix derivation is
   realistic.
3. **Neither upstream repo ships a flake.nix** (confirmed 404 on both), so unlike loogle there is no
   upstream Nix entry point to delegate version-resolution to even if we wanted to.

**Recommendation: package `comparator` (and its own bundled `lean4export`, used only for Comparator's
own build/self-tests, which are fixed to Comparator's own `v4.34.0-rc2` toolchain and therefore do not
have the per-project version problem from (b)) as a real, pinned Nix derivation**, at
`packages/comparator.nix`. Concretely, at implementation time:
- Pin `leanprover/comparator` via `fetchFromGitHub` at a specific commit (current `master` HEAD as of
  this research, or whatever HEAD is at implementation time) rather than a floating branch.
- Pin `leanprover/lean4export` the same way, at a commit compatible with Comparator's *own*
  `v4.34.0-rc2` toolchain (this resolves the `[[require]] rev = "master"` floating dependency in
  Comparator's own `lakefile.toml` into something Nix-reproducible — worth noting as an existing
  looseness in Comparator's own build that this packaging effort tightens, not something introduced by
  this task).
- Obtain a Lean `v4.34.0-rc2` toolchain deterministically. Options, in order of preference to evaluate
  during implementation: (i) a `fetchurl` of the official prebuilt Linux x86_64 release tarball for that
  exact tag as a fixed-output derivation (content-addressed, reproducible, no need to build Lean from
  source) if that tag has a GitHub Release with prebuilt binaries; (ii) delegate toolchain acquisition to
  `elan` itself, wrapped so that the *acquisition* step is a fixed-output derivation (network-permitted,
  hash-pinned output) while the actual `lake build` of Comparator runs in a normal, offline, sandboxed
  derivation against the already-fetched toolchain. Do not attempt to build Lean 4 itself from source
  here — that is unnecessary weight for what this task needs.
- Vendor the `lean4export` dependency into an offline-buildable form (a `path`-style local override in
  Comparator's Lake manifest pointing at the `fetchFromGitHub`-fetched source, or an equivalent
  offline-assembly step) so the actual `lake build lean4export comparator` step runs without network
  access inside the Nix build sandbox, consistent with normal Nix derivation purity — rather than
  marking the whole build fixed-output just to allow network access mid-build (a much less safe/auditable
  shortcut that should only be a fallback if the offline-vendoring approach proves impractical during
  implementation; if it comes to that, say so explicitly in the plan/implementation artifacts rather than
  slipping into it silently).
- Ship the `tests/projects/` fixture tree as part of the derivation's source (or reference it directly
  from the pinned Comparator checkout) so the acceptance-criteria verification runs
  (`simple_mismatch`, `def_hole`, `def_hole_axiom_issue`, `def_hole_type_mismatch`, `olean_issue`,
  `opaque_value` — all confirmed present in the current repo tree via `gh api .../git/trees/master`) are
  available without a second network fetch at verification time.
- Wire `scripts/fake-landrun.sh` (from the pinned Comparator checkout) into the package/dev-shell output
  too, since sibling task 153 in `~/.config/nvim/` already depends on it as its development substitute
  for real `landrun` and should not need a second copy of Comparator's source tree to get it.

This is more implementation work than a wrapper, and the exact FOD-vs-vendoring mechanics should be
finalized during planning/implementation (this is a packaging decision with real trial-and-error, not
something to lock down purely from reading source) — but the direction (real, pinned derivation; not a
silent-rebuild wrapper) is the deliberate answer the task asked for, with the reasoning above recorded.

### (d) nanoda: deferral, stated explicitly

Nanoda buys exactly one thing: an independent second kernel implementation, catching the case where
Lean's own kernel (used identically by Comparator's `runBuiltinKernel`) has a bug that both proves and
"verifies" a bad solution. None of this task's acceptance criteria require it (they can all be
demonstrated using Comparator's built-in kernel path — `enable_nanoda` defaults to `false`/absent). Given
the task's own "(d) ... it is reasonable to defer" framing, and the added Rust-toolchain-provisioning
surface a `cargo build --release`-based package would add for a bit of extra assurance not needed yet:
**defer nanoda in this task.** Concretely:
- Do not add `packages/nanoda.nix` in this task.
- Do not set `COMPARATOR_NANODA` in Home Manager.
- Leave Comparator's own fallback (`nanodaOverride?.getD "nanoda_bin"`, i.e. a bare `nanoda_bin` looked
  up on `PATH`) as-is — since `nanoda_bin` will not be installed, `enable_nanoda: true` in any config
  will fail loudly (binary-not-found) rather than silently skip, which is the correct "degrade loudly"
  behavior the sibling tasks require.
- Record this explicitly in whatever packaging documentation this task produces (e.g. a header comment
  in `packages/comparator.nix` or a short note in `packages/README.md`), so a future reader sees a
  deliberate deferral, not an oversight.

### (e) Env-var contract and Home Manager wiring

Verified directly against `Main.lean:334-338`:
```lean
let whichLean4Export := (← IO.getEnv "COMPARATOR_LEAN4EXPORT").getD "lean4export"
let whichLandrun := (← IO.getEnv "COMPARATOR_LANDRUN").getD "landrun"
...
let nanodaOverride? ← IO.getEnv "COMPARATOR_NANODA"
```
This is exactly the contract the four nvim-side sibling tasks already assume (confirmed by reading task
153's full description in `~/.config/nvim/specs/state.json`: *"Resolve binaries via COMPARATOR_LANDRUN /
COMPARATOR_LEAN4EXPORT / COMPARATOR_NANODA when set, falling back to PATH. Degrade LOUDLY, never
silently..."*). No second contract needs to be invented or coordinated — this task should simply make
the three env vars resolvable the way the nvim-side harness expects:

- **`COMPARATOR_LANDRUN`**: set unconditionally in Home Manager (e.g.
  `home.sessionVariables.COMPARATOR_LANDRUN = "${pkgs.landrun-main}/bin/landrun";` in whichever
  home-manager module ends up owning this, most likely alongside the `home.packages` entry) — this is
  safe because landrun is not per-project-versioned, unlike lean4export.
- **`COMPARATOR_LEAN4EXPORT`**: do **not** set a fixed global value. Per (b) above, the correct binary
  is a function of the target project being checked, and a fixed global path would be silently *wrong*
  for any project not matching whatever toolchain the resolver last cached under that name. The calling
  harness (task 153, `lean-comparator-run.sh`, in `~/.config/nvim/`) should invoke the
  `comparator-lean4export-resolve` package/script per run and export
  `COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve "$project_dir")` itself, immediately before
  invoking `comparator`. This task's job is to make that resolver script exist, buildable, and on
  `PATH` — not to pre-decide a value for the env var.
- **`COMPARATOR_NANODA`**: leave unset (see (d)).
- Also install the `comparator` binary itself (and, per fixture reuse above, ideally its
  `tests/projects/` and `scripts/fake-landrun.sh`) on `PATH` via `home.packages`, most likely in
  `modules/home/packages/dev-tools.nix` given its role as developer tooling infrastructure (co-locating
  with or near `loogle`/`aristotle` in whichever file already holds them is also acceptable — this is a
  file-placement detail for planning, not a research finding).

## Decisions

1. Package `landrun` from a pinned `main`/`v0.1.17`-equivalent commit, not nixpkgs' `0.1.15` — justified
   by a concrete, sourced correctness gap (shallow vs. recursive ELF dependency resolution) in the exact
   flag combination (`--ldd --add-exec`) Comparator hardcodes, plus a REFER-permission fix relevant to
   `lake build`'s rename/link patterns.
2. Do not attempt a single system-wide `lean4export` binary. Build a toolchain-keyed resolver script
   (`comparator-lean4export-resolve`) that the *calling harness* runs before every Comparator invocation,
   because the sandboxed `lean4export` call itself has no write or network access to build anything
   on-the-fly.
3. Package `comparator` as a real, pinned Nix derivation rather than a `loogle.nix`-style silent-rebuild
   wrapper — justified by Comparator's light (Mathlib-free) dependency footprint making a real derivation
   tractable, and by the trust-sensitivity argument the task itself raises.
4. Defer `nanoda` entirely for this task; record the deferral explicitly rather than omitting it
   silently.
5. `COMPARATOR_LANDRUN` gets a fixed Home Manager env var; `COMPARATOR_LEAN4EXPORT` deliberately does
   not, and must be set per-invocation by the calling harness via the resolver script;
   `COMPARATOR_NANODA` stays unset. This matches, without alteration, the contract already assumed by
   the four sibling nvim-side tasks (153-156).

## Risks & Mitigations

- **Computing `vendorHash`/build hashes for a from-`main` landrun derivation, and any fixed-output hash
  for a fetched Lean toolchain tarball, cannot be done from this research pass** (no local Nix build was
  attempted; only source/metadata was inspected via `gh api` and the local nixpkgs pin). Mitigation:
  implementation must compute these via a real `nix build` attempt (`lib.fakeHash` → real hash), budget
  time for at least one failed-hash iteration per new fetch.
- **Offline-vendoring `lean4export` into Comparator's own Lake build (to avoid a network-permitted
  fixed-output derivation) is the least-proven part of the design** — if `lake`'s manifest format does
  not cooperate with a simple local-path override cleanly, implementation may need to fall back to a
  fixed-output derivation for the whole `comparator` build. If so, this must be stated explicitly in the
  implementation artifacts (per the task's "state the reasoning either way" instruction), not adopted
  silently.
- **Kernel Landlock ABI level on this host was not independently queried** (no landrun binary was
  installed yet to probe it); the systemd-run wrapper requirement is retained regardless per the task's
  own instruction not to drop it "on the strength of this host's kernel alone."
- **The acceptance criteria's live-run requirements** (invoke each binary with `--version`/`--help`; run
  Comparator against a passing *and* a rejecting fixture pair) are unverified by this research pass by
  design — research does not build or run anything; they are the implementation phase's job and are
  restated here so planning sizes them as real, non-optional phases rather than assuming derivation
  evaluation is sufficient.

## Appendix: Verification Commands Used

```
gh api repos/leanprover/comparator --jq '{pushed_at,default_branch,license:.license.spdx_id}'
gh api repos/leanprover/comparator/contents/README.md --jq '.content' | base64 -d
gh api repos/leanprover/comparator/contents/lakefile.toml --jq '.content' | base64 -d
gh api repos/leanprover/comparator/contents/lean-toolchain --jq '.content' | base64 -d
gh api repos/leanprover/comparator/contents/Main.lean --jq '.content' | base64 -d
gh api repos/leanprover/comparator/git/trees/master?recursive=true --jq '.tree[].path'
gh api repos/leanprover/lean4export --jq '{pushed_at,default_branch}'
gh api repos/leanprover/lean4export/contents/lakefile.toml --jq '.content' | base64 -d
gh api repos/leanprover/lean4export/contents/README.md --jq '.content' | base64 -d
gh api repos/NixOS/nixpkgs/contents/pkgs/by-name/la/landrun/package.nix --jq '.content' | base64 -d
gh api repos/Zouuup/landrun --jq '{pushed_at,default_branch}'
gh api repos/Zouuup/landrun/tags --jq '.[] | {name,commit:.commit.sha}'
gh api repos/Zouuup/landrun/compare/v0.1.17...main --jq '{ahead_by,behind_by,status}'
gh api repos/Zouuup/landrun/compare/v0.1.15...main --jq '{ahead_by,behind_by,status}'
gh api repos/Zouuup/landrun/contents/cmd/landrun/main.go?ref=<v0.1.15|v0.1.16|v0.1.17|main>
gh api repos/Zouuup/landrun/contents/go.mod?ref=<v0.1.15|v0.1.17|main> | grep landlock
nix search nixpkgs#landrun landrun --json
gh api repos/ammkrn/nanoda_lib --jq '{pushed_at,default_branch}'
grep -rn "comparator\|COMPARATOR" ~/.config/nvim/specs/state.json
```

References consulted directly (all fetched via `gh api`, not summarized second-hand):
- https://github.com/leanprover/comparator (README, `Main.lean`, `lakefile.toml`, `lean-toolchain`, test fixture tree)
- https://github.com/leanprover/lean4export (README, `lakefile.toml`, `lean-toolchain`)
- https://github.com/Zouuup/landrun (full tag list, `cmd/landrun/main.go` diffs across `v0.1.15`/`v0.1.16`/`v0.1.17`/`main`, `go.mod` diffs)
- https://github.com/NixOS/nixpkgs `pkgs/by-name/la/landrun/package.nix`
- https://github.com/ammkrn/nanoda_lib (README, repo metadata only — not built)
- Local: `flake.nix`, `packages/loogle.nix`, `packages/aristotle.nix`, `packages/README.md`,
  `overlays/unstable-packages.nix`, `modules/home/packages/dev-tools.nix`, `modules/system/nix.nix`
- `~/.config/nvim/specs/state.json` (tasks 153-156, full descriptions) for the consumer-side env-var
  contract and sandbox-invocation details
