# Implementation Plan: Provision the Comparator Lean proof-verification toolchain

- **Task**: 130 - Provision the Comparator Lean proof-verification toolchain (landrun, lean4export, comparator)
- **Status**: [IMPLEMENTING]
- **Effort**: 14.5 hours
- **Dependencies**: None (blocking). Requires network access to GitHub and the Lean release CDN during implementation; requires a `nixos-rebuild`/`home-manager switch` to be performed by the implementer.
- **Research Inputs**: specs/130_provision_comparator_verification_toolchain/reports/01_comparator-toolchain-provisioning.md
- **Artifacts**: plans/01_comparator-toolchain-provisioning.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Provision `landrun`, a version-matched `lean4export`, and `comparator` so the Comparator
proof-verification path is actually runnable on this host, and expose them under the
`COMPARATOR_LANDRUN` / `COMPARATOR_LEAN4EXPORT` / `COMPARATOR_NANODA` contract the four
sibling agent-system tasks in `~/.config/nvim/` already assume. The research pass settled the
four open design questions (landrun from a pinned `main`/`v0.1.17` commit rather than nixpkgs'
`0.1.15`; a toolchain-keyed resolver script instead of one system-wide `lean4export`; a real
pinned derivation for `comparator` rather than a `loogle.nix`-style silent-rebuild wrapper;
`nanoda` explicitly deferred), so this plan is a packaging and live-verification effort, not a
design exploration. Definition of done is behavioural, not evaluative: each of the three binaries
must be run with a real flag after a rebuild, and Comparator must be shown both accepting a
matching Challenge/Solution pair and rejecting a mismatching one.

### Research Integration

The plan takes the following verified findings from
`reports/01_comparator-toolchain-provisioning.md` as settled inputs and does not re-litigate them:

- **landrun**: `0.1.15`'s `--ldd` shells out to the system `ldd` with a shallow (non-recursive)
  scan; `v0.1.16`+ use an internal breadth-first recursive ELF resolver (PRs #38/#40). Comparator
  hardcodes `--ldd --add-exec` on every sandboxed call (`Main.lean:80-86`), so this gap sits
  directly in the exercised code path. `main` is 4 cosmetic commits ahead of `v0.1.17`. Phase 1
  therefore pins `v0.1.17` (a tag, not a floating branch) and records the evidence.
- **lean4export**: the sandboxed export call (`safeExport`, `Main.lean:134-150`) is given
  `writablePaths := #[]` and no network, so nothing can build or resolve on demand from inside it.
  Resolution must be hoisted to the caller, before `comparator` runs. Phase 5 implements that
  resolver.
- **comparator**: `lakefile.toml` has exactly one `[[require]]` (lean4export) and no Mathlib, so a
  real pinned derivation is tractable in a way loogle's was not; and neither upstream repo ships a
  `flake.nix` (confirmed 404 on both), so there is no upstream Nix entry point to delegate to.
- **Env-var contract**: `Main.lean:334-338` confirms the three env vars verbatim; no second
  contract is invented here.
- **Hash unknowns**: the research pass ran no Nix build, so `vendorHash` and any fixed-output hash
  are unknown and must be obtained by a real failed-build iteration. Phases 1 and 2 budget for that.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but contains no items (Phase 1 is the placeholder
`- [ ] (No items yet -- add roadmap items here)`). No roadmap alignment applies, and this plan
does not modify ROADMAP.md.

### File Scope Deviation (declare before implementing)

The task's declared `file_scope` is `packages/comparator.nix`, `packages/lean4export.nix`,
`modules/home/packages/dev-tools.nix`, `flake.nix`. The research findings require touching four
additional files, listed here so the deviation is deliberate rather than silent:

| File | Status | Why |
|------|--------|-----|
| `packages/comparator.nix` | in scope | real pinned derivation |
| `packages/lean4export.nix` | in scope | hosts the `comparator-lean4export-resolve` resolver package (the file name is kept; the package it defines is a resolver, not a fixed binary) |
| `modules/home/packages/dev-tools.nix` | in scope | `home.packages` + `COMPARATOR_LANDRUN` |
| `flake.nix` | in scope | resolve the currently-unused `lean4` input question |
| `packages/landrun.nix` | **added** | pinned `v0.1.17` build; nixpkgs' `0.1.15` is rejected on evidence |
| `packages/lean-toolchain-bin.nix` | **added** | deterministic Lean `v4.34.0-rc2` acquisition, shared by the comparator derivation |
| `overlays/unstable-packages.nix` | **added** | the repo's only wiring point for `packages/*.nix` (`final.callPackage`) |
| `packages/README.md` | **added** | this repo's documented convention is that every `packages/*.nix` gets a README entry; it is also where the decision record and sandbox caveat land |

## Goals & Non-Goals

**Goals**:

- `landrun` built from a pinned `v0.1.17` commit (not nixpkgs' `0.1.15`), installed, and
  demonstrated by an actual `landrun --version` run after a rebuild.
- `comparator` built as a real, pinned, reproducible Nix derivation and demonstrated by an actual
  `comparator --help` run after a rebuild.
- A `comparator-lean4export-resolve` script that produces a `lean4export` binary keyed by a target
  project's exact `lean-toolchain` string, with a sidecar file recording what it was built against,
  demonstrated by an actual `lean4export --help` run on its output.
- Comparator demonstrated both **accepting** a matching Challenge/Solution fixture pair and
  **rejecting** a mismatching pair, with real captured output.
- A caller-detectable `lean4export` mismatch mechanism, with the version-matching decision and its
  reasoning written down.
- The `landrun` `main`-vs-`0.1.15` question answered in-repo with the source-level evidence.
- The `systemd-run` sandbox-escape wrapper caveat documented alongside the packaging.
- `COMPARATOR_LANDRUN` exported; `COMPARATOR_LEAN4EXPORT` and `COMPARATOR_NANODA` deliberately not
  exported, with the reason recorded at the site of the omission.

**Non-Goals**:

- Packaging `nanoda` / `nanoda_bin` (deferred explicitly; the deferral is documented, not silent).
- Building Lean 4 itself from source.
- Implementing anything on the consumer side — the runner script, snapshot mechanism, `--compare`
  flag, and trust-boundary docs live in `~/.config/nvim/` (sibling tasks 153-156) and are out of
  scope here. This plan only records the contract those tasks depend on.
- Upstreaming the landrun bump to nixpkgs.
- Making `comparator` a general-purpose multi-Lean-version checker beyond what the resolver provides.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `vendorHash` / FOD hashes cannot be known ahead of a real build | M | H (certain) | Phases 1 and 2 explicitly budget a `lib.fakeHash` -> real-hash iteration; treat the first failed build as expected, not as a defect |
| Offline-vendoring `lean4export` into Comparator's Lake workspace does not cooperate with lake's manifest format | H | M | Phase 3 is a dedicated, separately-verified phase so the failure surfaces before the derivation is written. Documented fallback: a network-permitted fixed-output derivation for the whole build — which, per the task's "state the reasoning either way" instruction, MUST be stated explicitly in Phase 8's documentation and the implementation summary if used, never slipped into silently |
| No prebuilt GitHub release tarball exists for the exact `v4.34.0-rc2` tag | M | M | Phase 2 evaluates two acquisition routes in order (direct `fetchurl` FOD of the release tarball; `elan`-mediated acquisition wrapped as an FOD) and picks whichever resolves first; both are content-addressed |
| Host Landlock ABI level is below what `v0.1.17`'s go-landlock v0.9.0 targets | L | L | Comparator always passes `--best-effort`, so this degrades rather than hard-fails. Phase 1 probes the actual ABI level and records it |
| Comparator's fixture run fails for an environment reason (nix-ld, PATH, `lake env`) rather than a real verdict | M | M | Phase 7 runs the fixtures under the README's `systemd-run` wrapper form and captures full stderr; a green fixture is only accepted when the *rejecting* fixture also rejects, which distinguishes a working checker from a broken one |
| The resolver's `lake build` needs network at run time and is invoked from somewhere that forbids it | M | L | The resolver is documented as deliberately outside any sandbox and is invoked by the harness *before* `comparator`; Phase 5 makes a build failure loud and non-zero rather than returning a stale binary |
| `flake.nix`'s unused `lean4` input misleads a future reader into thinking the toolchain comes from it | L | M | Phase 2 resolves it explicitly: either pin its `rev` and use it, or leave it with a comment stating it is not the toolchain source for comparator |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 5 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 6 | 1, 4, 5 |
| 5 | 7 | 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Package landrun from a pinned v0.1.17 commit [COMPLETED]

**Goal**: A `landrun` derivation built from the pinned tag the research pass identified, built and
run successfully, with the `0.1.15`-vs-`main` evidence captured for the eventual documentation.

**Tasks**:

- [x] Create `packages/landrun.nix` as a `buildGoModule` derivation with
      `src = fetchFromGitHub { owner = "Zouuup"; repo = "landrun"; tag = "v0.1.17"; hash = ...; }`,
      pinned by the tag's commit SHA rather than a floating `main` ref *(completed; pinned tag
      commit 62823c05e58ec22c1f91b4c8468318c1f97f2d32)*
- [x] Start with `hash`/`vendorHash` set to `lib.fakeHash`, run `nix build`, and substitute the
      real hashes from the mismatch errors (expect at least two build attempts) *(completed; two
      hash-mismatch iterations, real hashes substituted)*
- [x] Add a header comment recording *why* nixpkgs' `0.1.15` was rejected: `--ldd` shallow shell-out
      to system `ldd` vs. internal recursive ELF resolution (PRs #38/#40), the PR #49
      REFER-permission fix relevant to `lake build`'s write-then-rename, and the go-landlock
      v0.9.0 / ABI V9 upgrade *(completed)*
- [x] Register in `overlays/unstable-packages.nix` under a name that does not silently shadow
      nixpkgs' `landrun` by accident — prefer an explicit attribute (e.g. `landrun` with a comment
      stating the deliberate shadow, matching the `playwright-mcp` precedent already in that file)
      *(completed)*
- [x] Probe and record this host's actual Landlock ABI level for the Phase 8 documentation
      *(completed; probed via a landlock_create_ruleset(LANDLOCK_CREATE_RULESET_VERSION) syscall
      on hamsa: ABI version 9)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:

- `packages/landrun.nix` - new `buildGoModule` derivation pinned at `v0.1.17`
- `overlays/unstable-packages.nix` - `landrun = final.callPackage ../packages/landrun.nix { };`

**Verification**:

- `nix build` of the landrun attribute succeeds with real (non-fake) hashes
- `$(nix build --no-link --print-out-paths ...)/bin/landrun --version` is **actually executed** and
  prints a `0.1.17`-consistent version — evaluation alone is not sufficient
- `landrun --help` shows `--ldd` and `--add-exec` among its flags (confirming the flags Comparator
  hardcodes exist in this build)

---

### Phase 2: Deterministic Lean v4.34.0-rc2 toolchain acquisition [COMPLETED]

**Goal**: A reproducible, content-addressed way to obtain the exact Lean toolchain Comparator's own
`lean-toolchain` pins (`leanprover/lean4:v4.34.0-rc2`), usable as a build input by the Phase 4
derivation, plus a resolved answer for `flake.nix`'s currently-unused `lean4` input.

**Tasks**:

- [x] Determine whether the `v4.34.0-rc2` tag has a GitHub Release carrying a prebuilt
      `linux x86_64` toolchain tarball *(completed; confirmed via `gh api
      repos/leanprover/lean4/releases/tags/v4.34.0-rc2` -- `lean-4.34.0-rc2-linux.tar.zst` asset
      exists)*
- [x] Route (i), preferred: `fetchurl` that tarball as a fixed-output derivation, unpack it, and
      expose `bin/lean`, `bin/lake` — no source build of Lean *(completed)*
- [x] Route (ii), fallback if no prebuilt release exists: wrap `elan`'s acquisition step as a
      fixed-output (network-permitted, hash-pinned) derivation, keeping the *build* step in Phase 4
      offline and pure *(not needed; route (i) succeeded)*
- [x] Compute the real fixed-output hash via a `lib.fakeHash` iteration *(the GitHub Releases API
      response includes a `digest: sha256:...` field for the asset; converted directly to SRI via
      `nix hash convert` and confirmed correct on the first `nix build` -- no fakeHash mismatch
      iteration was needed since the true hash was obtained from the API rather than guessed)*
- [x] Add nix-ld / patchelf handling only if the unpacked binaries actually fail to execute
      (`modules/system/nix.nix` already runs `programs.nix-ld` for elan toolchains; do not duplicate)
      *(completed; used `autoPatchelfHook` + `stdenv.cc.cc.lib`/`gmp`/`libuv` instead of nix-ld,
      since this is a Nix derivation with buildInputs available at build time, not a
      user-`~/.elan`-managed binary -- autoPatchelfHook is the standard in-derivation mechanism;
      `lean --version` and `lake --version` both execute successfully post-patch)*
- [x] Resolve `flake.nix`'s `lean4` input: either pin its `rev` and use it as the toolchain source,
      or leave it in place with an explicit comment stating it is not the source for the Comparator
      toolchain and why. Do not leave the ambiguity unaddressed *(completed; comment-and-keep --
      see flake.nix)*
- [x] Record which route was taken, for Phase 8 *(completed; recorded in this checklist and in
      packages/lean-toolchain-bin.nix's header comment, to be cross-referenced from
      packages/README.md in Phase 8)*

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:

- `packages/lean-toolchain-bin.nix` - new; deterministic Lean `v4.34.0-rc2` acquisition
- `flake.nix` - resolve the unused `lean4` input (pin-and-use, or comment-and-keep)

**Verification**:

- `nix build` of the toolchain derivation succeeds with a real hash
- `$out/bin/lean --version` is **actually executed** and prints a version string containing
  `4.34.0-rc2`
- `$out/bin/lake --version` executes successfully
- `nix flake check` still passes after the `flake.nix` edit

---

### Phase 3: Offline lake-dependency vendoring for comparator [COMPLETED]

**Goal**: Prove, before writing the derivation, that Comparator's Lake workspace can build with its
`lean4export` dependency supplied from a pinned local path and with no network access — or
establish that it cannot and that the FOD fallback is required.

**Tasks**:

- [x] Fetch `leanprover/comparator` and `leanprover/lean4export` at pinned commits via
      `fetchFromGitHub` (comparator: current `master` HEAD; lean4export: a commit compatible with
      Comparator's own `v4.34.0-rc2` toolchain), computing real hashes *(completed for the scratch
      harness via plain `git clone`/`git checkout`; comparator pinned at its current `master` HEAD
      `2312244ac716564a61cc0bf4e107d9abf1757a61`, lean4export pinned at
      `cacf989bd75f608700820f6afc595f32e7a99a4d` -- the exact commit Comparator's OWN
      `lake-manifest.json` already resolved `rev = "master"` to at that same comparator commit, so
      this is not a new pin invented here, just made explicit and Nix-fetched. Real
      `fetchFromGitHub` hashes are computed in Phase 4, since that's where they become
      derivation inputs)*
- [x] Resolve Comparator's `[[require]] rev = "master"` floating dependency into the pinned
      lean4export source — via a local `path`-style override in the Lake manifest, a pre-populated
      `.lake/packages/` layout, or an equivalent offline-assembly step *(completed; the `path`-style
      override works cleanly: replacing the `[[require]] scope/rev` block with
      `[[require]] name = "lean4export" \n path = "../lean4export"` and deleting the stale
      `lake-manifest.json` -- lake regenerates a fresh manifest locally, no fetch)*
- [x] In a scratch harness using the Phase 2 toolchain, run `lake build lean4export comparator`
      with the network unavailable and confirm it completes without attempting a fetch *(completed;
      ran under `unshare -rn` (unprivileged user+network namespace, confirmed to actually block
      network via a failed `curl` probe first) with `PATH` pointed at the Phase 2
      `lean-toolchain-bin` output -- NOT elan -- and `lake build lean4export comparator` completed
      all 20/20 build jobs successfully, producing both `comparator` and `lean4export` executables.
      No files under `$HOME` were touched during the build)*
- [ ] If offline vendoring proves impractical, stop and record the specific failure verbatim
      (lake's error, the manifest shape that resisted) — the FOD fallback is then permitted, but
      Phase 8 MUST state it explicitly per the task's "state the reasoning either way" instruction
      *(not applicable -- offline vendoring worked; no FOD fallback needed. Recorded explicitly per
      the task's "state the reasoning either way" instruction: the path-style require was
      sufficient and the network-permitted FOD fallback was NOT used)*
- [x] Capture the exact vendoring recipe that worked, so Phase 4 transcribes rather than
      rediscovers it *(completed; recipe: fetch both sources via fetchFromGitHub at the pinned
      commits above, `cp -r` each into sibling writable directories inside the derivation's build
      dir, rewrite comparator's `[[require]]` block to `path = "../lean4export"` via
      `substituteInPlace`/`sed` on `lakefile.toml`, delete `lake-manifest.json`, put the Phase 2
      `lean-toolchain-bin` on `PATH`, run `lake build lean4export comparator`)*

**Timing**: 2 hours

**Depends on**: 2

**Files to modify**:

- (scratch/experimental only in this phase; the recipe lands in `packages/comparator.nix` in Phase 4)

**Verification**:

- `lake build lean4export comparator` completes in an offline scratch harness against the pinned
  sources, producing a `comparator` executable
- Confirmed with network disabled — a build that merely succeeds while online does not verify this
  phase
- The written-down recipe is concrete enough that Phase 4 needs no further experimentation, OR the
  documented failure and FOD-fallback decision is recorded

---

### Phase 4: packages/comparator.nix real pinned derivation [NOT STARTED]

**Goal**: A real, reproducible Nix derivation producing the `comparator` binary plus the fixture
tree and `fake-landrun.sh` the sibling tasks need — not a `loogle.nix`-style wrapper.

**Tasks**:

- [ ] Write `packages/comparator.nix` transcribing the Phase 3 vendoring recipe, using the Phase 2
      toolchain as a build input
- [ ] Install `bin/comparator`
- [ ] Ship `tests/projects/` from the pinned checkout into the derivation output so Phase 7's
      fixture runs need no second network fetch
- [ ] Ship `scripts/fake-landrun.sh` into the output, since sibling task 153 depends on it as its
      development substitute and should not need a second copy of Comparator's source tree
- [ ] Add a header comment recording the real-derivation-vs-wrapper decision and its reasoning
      (trust semantics of a checker whose provenance must be auditable; Mathlib-free dependency
      footprint making a real derivation tractable where loogle's was not; no upstream `flake.nix`
      to delegate to), and the `nanoda` deferral
- [ ] Register in `overlays/unstable-packages.nix`

**Timing**: 2 hours

**Depends on**: 3

**Files to modify**:

- `packages/comparator.nix` - new real pinned derivation
- `overlays/unstable-packages.nix` - `comparator = final.callPackage ../packages/comparator.nix { };`

**Verification**:

- `nix build` of the comparator attribute succeeds
- `$out/bin/comparator --help` is **actually executed** and produces usage output
- `$out/share/comparator/tests/projects/` (or the chosen output path) contains the fixture triples
  including `simple_mismatch`
- `fake-landrun.sh` is present and executable in the output

---

### Phase 5: comparator-lean4export-resolve toolchain-keyed resolver [COMPLETED]

**Goal**: A standalone resolver script that returns a `lean4export` binary matched to a *target
project's* Lean toolchain, with a sidecar making a mismatch structurally hard to produce and
trivially detectable by a caller.

**Tasks**:

- [x] Write `packages/lean4export.nix` as a `writeShellScriptBin`-style package defining
      `comparator-lean4export-resolve` *(completed; used `writeShellApplication` instead of the
      lower-level `writeShellScriptBin` for the free `shellcheck` build-time check — same
      package family, stricter build)*
- [x] Accept a target project directory (or an explicit toolchain string) as its argument
      *(completed; `<target-dir>` reads `<target-dir>/lean-toolchain`, `--toolchain <string>`
      takes an explicit string)*
- [x] Read the exact contents of the target's `lean-toolchain` file — reuse this existing
      convention rather than inventing a second toolchain-detection mechanism *(completed)*
- [x] Derive a filesystem-safe cache key from that exact string; cache under
      `~/.cache/comparator/lean4export/<slug>/` *(completed)*
- [x] On a cache miss: check out `leanprover/lean4export` at a documented default pinned rev,
      overwrite its `lean-toolchain` with the **target's** string so elan/lake build it under the
      target's Lean version, `lake build`, and install the binary plus a sidecar
      `lean4export.toolchain` containing the exact toolchain string it was built against
      *(completed; default rev pinned to lean4export's current HEAD
      411dce7db58a3afc60ecab2d211acd1042b593dc, captured 2026-09-07)*
- [x] Print only the resolved binary path on stdout, so
      `COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve "$dir")` works *(completed; all
      diagnostic output goes to stderr)*
- [x] Exit non-zero with a clear, distinguishable message on build failure — never return a stale
      or unmatched binary silently *(completed; verified live against a deliberately-nonexistent
      Lean release `v0.0.0-does-not-exist` — exits 1, stderr shows the real `lake`/elan error,
      stdout is empty)*
- [x] Provide an env-var or flag override for the pinned lean4export rev, for target projects whose
      toolchain predates what the default rev can read *(completed;
      `COMPARATOR_LEAN4EXPORT_REV` env var; `COMPARATOR_LEAN4EXPORT_CACHE` also added to override
      the cache root, useful for the Phase 7 fixture runs)*
- [x] Register in `overlays/unstable-packages.nix` *(completed, as
      `comparator-lean4export-resolve`)*

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:

- `packages/lean4export.nix` - new; defines the `comparator-lean4export-resolve` package
- `overlays/unstable-packages.nix` - callPackage wiring

**Verification**:

- `comparator-lean4export-resolve --help` executes and documents its contract
- Run against a project pinned to `v4.34.0-rc2`: a binary and a sidecar appear under the
  toolchain-keyed cache path
- `"$(comparator-lean4export-resolve <dir>)" --help` is **actually executed** and produces
  lean4export usage output
- Sidecar contents match the target's `lean-toolchain` byte-for-byte
- **Mismatch demonstration**: point the resolver at a project with a *different* toolchain string
  and confirm it resolves to a different cache slot (not the first binary), and that a caller
  comparing sidecar-to-`lean-toolchain` detects a hand-overridden mismatch
- A deliberately-broken build exits non-zero with a legible message rather than emitting a path

---

### Phase 6: Home Manager wiring and rebuild [NOT STARTED]

**Goal**: All three binaries on `PATH` after a real rebuild, with the env-var contract exposed
exactly as the sibling tasks assume — and each binary demonstrated by an actual invocation.

**Tasks**:

- [ ] Add `landrun`, `comparator`, and the resolver package to `home.packages` in
      `modules/home/packages/dev-tools.nix`
- [ ] Set `home.sessionVariables.COMPARATOR_LANDRUN = "${pkgs.landrun}/bin/landrun";` (safe as a
      fixed path — landrun is not per-project-versioned)
- [ ] Do **not** set `COMPARATOR_LEAN4EXPORT`; add a comment at that exact site explaining that a
      fixed global value would be silently *wrong* for any project whose toolchain differs from
      whatever the resolver last cached, and that the calling harness must set it per-invocation
      from the resolver's output
- [ ] Do **not** set `COMPARATOR_NANODA`; add a comment recording the deliberate `nanoda` deferral
      and that leaving it unset makes `enable_nanoda: true` fail loudly (binary-not-found) rather
      than silently skip
- [ ] Rebuild (`nixos-rebuild switch` / `home-manager switch`) and start a fresh login shell so
      `sessionVariables` is actually in effect

**Timing**: 1.5 hours

**Depends on**: 1, 4, 5

**Files to modify**:

- `modules/home/packages/dev-tools.nix` - `home.packages` entries + `COMPARATOR_LANDRUN` +
  the two deliberate-omission comments

**Verification** (this phase satisfies acceptance criterion 1 — run, do not evaluate):

- `landrun --version` executed from a plain shell, printing a version
- `comparator --help` executed from a plain shell, printing usage
- `comparator-lean4export-resolve --help` executed, and
  `"$(comparator-lean4export-resolve <project>)" --help` executed, printing lean4export usage
- `echo "$COMPARATOR_LANDRUN"` prints a `/nix/store/...` path that exists and is executable
- `echo "$COMPARATOR_LEAN4EXPORT"` prints empty, and `echo "$COMPARATOR_NANODA"` prints empty
  (deliberate)

---

### Phase 7: End-to-end fixture verification, pass and rejection [NOT STARTED]

**Goal**: Demonstrate Comparator producing a correct verdict in **both** directions against its own
shipped fixtures — a checker that only ever accepts proves nothing.

**Tasks**:

- [ ] Choose a matching Challenge/Solution fixture from `tests/projects/` expected to **pass**
- [ ] Choose `simple_mismatch` (and optionally one of `def_hole` /
      `def_hole_axiom_issue` / `def_hole_type_mismatch` / `olean_issue` / `opaque_value`) as the
      **rejection** case
- [ ] For each run, resolve the export binary first:
      `export COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve "$fixture_dir")`
- [ ] Invoke under the README's recommended wrapper form:
      `systemd-run --property=RestrictAddressFamilies=~AF_UNIX --user --pty -E PATH="$PATH"
      --working-directory $(pwd) -- bash -c 'lake env comparator config.json'`
- [ ] Capture full stdout/stderr transcripts for both runs
- [ ] Confirm the pass case produces the fixture's expected accepting verdict, and the mismatch case
      produces an explicit **rejection** — not a crash, not a tooling error. A non-zero exit from a
      missing binary or a sandbox setup failure does NOT count as a rejection; distinguish these in
      the transcript
- [ ] If a run fails for an environment reason, fix and re-run rather than recording the failure as
      a verdict

**Timing**: 2 hours

**Depends on**: 6

**Files to modify**:

- (none; verification runs only — transcripts go into the implementation summary)

**Verification** (this phase satisfies acceptance criterion 2):

- A real transcript showing a matching pair accepted
- A real transcript showing a mismatching pair rejected, with the rejection distinguishable from a
  tooling failure
- Both runs performed under the `systemd-run` wrapper form, confirming the wrapper is compatible
  with this packaging

---

### Phase 8: Documentation and decision record [NOT STARTED]

**Goal**: Every decision the task asked to have written down is written down, in the repo, next to
the packaging — not only in the specs directory.

**Tasks**:

- [ ] Add `packages/README.md` entries for `landrun.nix`, `comparator.nix`, `lean4export.nix`
      (resolver), and `lean-toolchain-bin.nix`, following the existing entry style
      (Implementation / Benefits / Updating / Wired via)
- [ ] Record the **landrun `main`-vs-`0.1.15` answer with evidence**: shallow system-`ldd` shell-out
      vs. internal recursive ELF resolution (PRs #38/#40) in the exact `--ldd --add-exec` path
      Comparator hardcodes; PR #49 REFER-permission fix relevant to `lake build`; go-landlock v0.9.0
      / ABI V9; `main` being 4 cosmetic commits ahead of `v0.1.17`, hence pinning the tag; and this
      host's probed Landlock ABI level from Phase 1
- [ ] Record the **lean4export version-matching decision** and its reasoning: why one system-wide
      binary is structurally wrong, why resolution cannot happen inside the sandbox
      (`writablePaths := #[]`, no network), the toolchain-keyed cache + sidecar design, and the
      **caller-side mismatch detection contract** (compare sidecar to the target's `lean-toolchain`
      byte-for-byte; refuse to certify a hand-overridden `COMPARATOR_LEAN4EXPORT` that does not
      carry the sidecar) — recorded as the expectation for the consuming side, without implementing
      it here
- [ ] Record the **real-derivation-vs-wrapper argument** for comparator, and — if Phase 3's fallback
      was taken — state explicitly that a network-permitted fixed-output derivation was used
      instead of offline vendoring, and why
- [ ] Record the **nanoda deferral** explicitly: what it buys (a second independent kernel), why it
      is not needed for these acceptance criteria, that `COMPARATOR_NANODA` is intentionally unset,
      and that `enable_nanoda: true` will therefore fail loudly rather than silently skip
- [ ] Record the **systemd-run sandbox-escape wrapper caveat**: the README's recommended wrapper,
      that it guards a landrun sandbox-escape vulnerability stated to be fixed in Linux 7.1, that
      this host runs 7.1.3 and is past that fix, and that the wrapper is retained for portability
      and must not be dropped on the strength of this host's kernel alone
- [ ] Record the env-var contract as consumed by the sibling agent-system tasks, so a future reader
      sees why two of the three vars are deliberately unset

**Timing**: 1.5 hours

**Depends on**: 7

**Files to modify**:

- `packages/README.md` - four new package entries plus the decision record and sandbox caveat

**Verification**:

- Every one of the five task-mandated records (landrun evidence, lean4export decision + mismatch
  detection, nanoda deferral, systemd-run caveat, derivation-vs-wrapper reasoning) is present and
  locatable by grep in `packages/README.md` or the relevant `packages/*.nix` header
- If the Phase 3 FOD fallback was used, it is stated explicitly rather than absent
- No task-number citations appear in `packages/**` (per
  `.claude/rules/no-task-references-in-deliverables.md`) — reference durable anchors instead

---

## Testing & Validation

- [ ] `nix flake check` passes after all `.nix` changes
- [ ] Each of the four new/changed derivations builds with real (non-`fakeHash`) hashes
- [ ] `landrun --version` runs and prints a version, from a post-rebuild login shell
- [ ] `comparator --help` runs and prints usage, from a post-rebuild login shell
- [ ] `"$(comparator-lean4export-resolve <project>)" --help` runs and prints lean4export usage
- [ ] `COMPARATOR_LANDRUN` resolves to an existing executable; `COMPARATOR_LEAN4EXPORT` and
      `COMPARATOR_NANODA` are unset
- [ ] Comparator accepts a matching Challenge/Solution fixture pair (transcript captured)
- [ ] Comparator rejects a mismatching fixture pair (transcript captured, distinguished from a
      tooling failure)
- [ ] Resolver produces distinct cache slots for distinct toolchain strings, and its sidecar matches
      the target's `lean-toolchain` byte-for-byte
- [ ] Resolver exits non-zero and legibly on a failed build rather than emitting a stale path
- [ ] Both fixture runs succeed under the `systemd-run` wrapper form

## Artifacts & Outputs

- `packages/landrun.nix` - pinned `v0.1.17` `buildGoModule` derivation
- `packages/lean-toolchain-bin.nix` - deterministic Lean `v4.34.0-rc2` acquisition
- `packages/comparator.nix` - real pinned comparator derivation (binary + fixtures + fake-landrun.sh)
- `packages/lean4export.nix` - `comparator-lean4export-resolve` toolchain-keyed resolver package
- `overlays/unstable-packages.nix` - callPackage wiring for the four packages
- `modules/home/packages/dev-tools.nix` - `home.packages` entries, `COMPARATOR_LANDRUN`, and the two
  deliberate-omission comments
- `flake.nix` - resolved `lean4` input question
- `packages/README.md` - package entries plus the five mandated decision records
- `specs/130_provision_comparator_verification_toolchain/summaries/01_*-summary.md` - implementation
  summary carrying the Phase 6 invocation output and both Phase 7 fixture transcripts

## Rollback/Contingency

- All changes are additive `.nix` files plus small edits to three existing files; reverting is
  `git revert` of the task's commits followed by `nixos-rebuild switch` / `home-manager switch`.
- The only mutable state outside the Nix store is `~/.cache/comparator/lean4export/`, which is
  safe to `rm -rf` — the resolver rebuilds on the next call.
- No system service, no secret, and no existing package is replaced except the deliberate `landrun`
  shadow of nixpkgs' `0.1.15`; dropping the overlay line restores nixpkgs' version.
- Per-phase contingencies: Phase 2 has a documented route (ii) fallback; Phase 3 has a documented
  FOD fallback that must be stated explicitly if taken. If Phase 7's fixture runs cannot be made to
  pass, the task should be marked `[PARTIAL]` with the failing transcript preserved rather than
  marked complete on the strength of a successful build — the acceptance criteria are explicitly
  behavioural.
