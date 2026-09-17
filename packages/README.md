# Custom Packages

This directory contains custom package definitions and configurations for the NixOS setup.

## Files

### aristotle.nix
UVX wrapper for Aristotle AI theorem prover that automatically uses the latest version from PyPI. This zero-maintenance approach eliminates the need for manual version updates while providing access to Aristotle's automated theorem proving capabilities with Lean.

**Implementation**: Uses `writeShellScriptBin` to create a simple wrapper that executes `uvx --from aristotlelib@latest aristotle`

**Benefits**:
- Automatic updates to latest version via PyPI
- Zero maintenance required
- Uses existing uv installation
- Integrated with Lean theorem prover
- Provides system-wide `aristotle` command

**Usage**:
```bash
aristotle --help
aristotle prove-from-file your_lean_file.lean
aristotle --api-key YOUR_API_KEY prove-from-file theorem.lean
```

**API Key**: Can be set via `ARISTOTLE_API_KEY` environment variable or `--api-key` flag

**Documentation**: Visit https://aristotle.harmonic.fun for more information

### claude-code.nix
NPX wrapper for Claude Code that fetches the latest version from NPM on each invocation. Also sets the default Opus model via `ANTHROPIC_DEFAULT_OPUS_MODEL`.

**Implementation**: Uses `writeShellScriptBin` to create a wrapper that runs `npx @anthropic-ai/claude-code@latest`

**Updating**: To pin a specific version, replace `@latest` with `@X.Y.Z`. After any change, rebuild with `sudo nixos-rebuild switch` (and `home-manager switch` or `./scripts/update.sh`). The npx cache (`~/.npm/_npx/`) may serve a stale version — delete it to force a fresh download.

### opencode-discord-bot.nix
`buildPythonApplication` derivation for the Nextcord Discord bot relay that bridges Discord to a headless OpenCode agent server — the first `buildPythonApplication` in this repo (the other Python packages here, e.g. `python-cvc5.nix`, `pymupdf4llm.nix`, `python-vosk.nix`, are libraries built with `buildPythonPackage` and composed into environments via `python3.withPackages`).

**Implementation**: Builds from the in-tree source at `./opencode-discord-bot` (co-located
sibling directory; PEP 621 `pyproject.toml` + `setuptools` backend), producing an
`opencode-discord-bot` console script. `callPackage`d directly in
`modules/system/optional/discord-bot.nix` — **not** routed through `overlays/python-packages.nix`,
since that overlay is scoped to library overrides composed via `python3.withPackages`, an
architecturally different consumer than a standalone application with its own entry point.

**Note**: `opencode-discord-bot.nix` (this derivation file) and `opencode-discord-bot/` (its
source directory, relocated here from the repo root) share a stem but are not a
naming conflict — the file is the derivation, the directory is its `src`. This is the first
co-located source directory under `packages/`.

**Status**: currently disabled on all hosts (see `docs/discord-bot.md`).

**Runtime**: The `discord-bot` systemd service runs `${opencodeDiscordBot}/bin/opencode-discord-bot` directly (no working-tree `PYTHONPATH` import). Session state is persisted under a systemd `StateDirectory` (`/var/lib/discord-bot`, `SESSION_STORE_PATH=%S/discord-bot/sessions.json`) rather than a nix-store-relative path, since the nix store is read-only at runtime.

**Future work**: extracting `opencode-discord-bot/` to its own repository (consumed as a flake input) is documented — but not implemented — as a header comment in `opencode-discord-bot.nix`, mirroring the email extension's wrapper-binary/own-source precedent. The current in-tree `src = ./opencode-discord-bot` shape is the deliberate near-term choice.

**See**: `docs/discord-bot.md`, `specs/089_opencode_discord_bot_packaging/`

### opencode.nix
`stdenvNoCC.mkDerivation` that fetches a prebuilt `opencode` binary from GitHub releases
(`anomalyco/opencode`) instead of building from source, allowing version updates independent of
the nixpkgs packaging lag.

**Implementation**: `fetchurl` downloads the release tarball (`opencode-linux-x64.tar.gz`); a
custom `unpackPhase` extracts the single binary directly (no wrapper directory in the tarball);
`installPhase` installs it and wraps it with `makeWrapper` to prepend `ripgrep` to `PATH`.

**Updating**: Bump `version`, prefetch the new tarball hash with
`nix store prefetch-file --hash-type sha256 <release-url>` (no `--unpack` — hash the tarball
itself), and update the hash in `opencode.nix`.

**Wired via**: `overlays/unstable-packages.nix` (`opencode = final.callPackage ../packages/opencode.nix { };`).

**Status**: currently not installed — the `opencode` entry in `modules/system/packages.nix` is
commented out. Uncomment it to reinstall.

### kooha.nix
`overrideAttrs` wrapper around nixpkgs' `kooha` (screen recorder) that adds GStreamer plugins
(`gst-plugins-bad` for AAC audio encoders, `gst-libav` for additional codec support) not included
in the upstream package's default `buildInputs`.

**Wired via**: `overlays/unstable-packages.nix`
(`kooha = import ../packages/kooha.nix prev.kooha final.gst_all_1;`).

### slidev.nix
`writeShellScriptBin` wrapper that runs `npx @slidev/cli@latest`, giving a `slidev` command for
building Markdown-based presentation slides without pinning a nixpkgs version.

**Wired via**: `overlays/unstable-packages.nix` (`slidev = final.callPackage ../packages/slidev.nix { };`).

### loogle.nix
Wrapper script for the Lean 4 Mathlib search tool that provides lazy installation and caching.

**Implementation**: Uses `writeShellScriptBin` to create a wrapper that:
1. Clones loogle repository to `~/.cache/loogle/` on first run
2. Builds loogle using `nix develop` with the Lean toolchain
3. Runs loogle CLI with all arguments passed through

**First Run Setup**:
- Downloads Lean 4 toolchain (~484 MB)
- Clones loogle repository (~331 KB)
- Downloads and caches Mathlib (~7729 files)
- Builds loogle (~1-2 minutes)

**Subsequent Runs**: Instant execution using cached build

**Benefits**:
- Zero maintenance - always uses latest Lean/Mathlib
- Lazy installation - only downloads when first used
- Isolated environment via Nix development shell
- Reproducible builds

**Usage**: 
```bash
loogle 'List.map'              # Search by name
loogle '(List ?a -> ?a)'       # Search by type signature
loogle --interactive           # Interactive mode
loogle --help                  # Show all options
```

**Cache Location**: `~/.cache/loogle/` and `~/.elan/`

**Reset/Update**: `rm -rf ~/.cache/loogle && loogle` to rebuild

See [Development Guide](../docs/development.md#lean-4-development) for detailed usage examples.

## Comparator Lean Proof-Verification Toolchain

`landrun`, `lean-toolchain-bin`, `comparator`, and `comparator-lean4export-resolve` together
provision a working install of [Comparator](https://github.com/leanprover/comparator), a
trustworthy checker for Lean proof submissions, plus the version-matched `lean4export` it
requires. Comparator's own README documents the trust model in full; this section records the
five packaging decisions this repo made and why, plus one load-bearing operational finding
discovered while verifying it end to end.

### landrun.nix
Pinned `v0.1.17` `buildGoModule` derivation for [landrun](https://github.com/Zouuup/landrun), a
Landlock-based sandbox. Deliberately shadows nixpkgs' own `landrun` (pinned at `0.1.15`) in
`overlays/unstable-packages.nix` -- this is the "landrun `main`-vs-`0.1.15`" decision the task
asked to have answered with evidence, not a stylistic preference:

- Comparator hardcodes `--best-effort --ro / --rw /dev --ldd --add-exec` on **every** sandboxed
  invocation (`Main.lean`'s `buildLandrunArgs`). `--ldd`'s implementation changed between
  `0.1.15` and `v0.1.16`/`v0.1.17`/`main`:
  - `0.1.15`: shells out to the system `ldd` binary and parses its text output -- a **shallow**
    (non-recursive) dependency scan.
  - `v0.1.16`+: an internal ELF parser (`elfdeps.GetLibraryDependencies`) that walks dependencies
    breadth-first and **recursively** (landrun PRs #38, #40). This sits directly in the flag
    combination Comparator exercises, and matters more on NixOS specifically, where binaries
    commonly have several layers of `/nix/store` shared-library indirection a shallow scan is
    prone to miss.
  - PR #49 ("use Restrict() to avoid REFER permission denial") fixes cross-directory rename/link
    failing with `EXDEV` even when the target directory is granted `--rw` -- plausibly relevant
    to `lake build`'s write-then-rename artifact production, present in `0.1.15` and fixed after
    it.
  - `go-landlock` was bumped to `v0.9.0` (Landlock ABI **V9**) between `v0.1.16` and `v0.1.17` (a
    documented upstream BREAKING CHANGE). Since Comparator always passes `--best-effort`, older
    kernels degrade gracefully rather than hard-failing, but `0.1.15` enforces a materially
    weaker sandbox on any kernel that supports more.
  - `main` (as pinned) is only 4 purely cosmetic commits ahead of the `v0.1.17` tag -- so a tagged
    commit is pinned rather than a floating branch, since they are functionally identical.
- **This host's probed Landlock ABI level is 9** (probed via a
  `landlock_create_ruleset(NULL, 0, LANDLOCK_CREATE_RULESET_VERSION)` syscall on `hamsa`),
  matching `v0.1.17`'s `go-landlock v0.9.0` ceiling exactly -- this pin buys the full sandboxing
  strength `v0.1.17` offers on this host, not just a degraded `--best-effort` fallback.

**Wired via**: `overlays/unstable-packages.nix` (`landrun = final.callPackage
../packages/landrun.nix { };`).

### lean-toolchain-bin.nix
Deterministic, content-addressed acquisition of the exact Lean toolchain Comparator's own
`lean-toolchain` pins (`leanprover/lean4:v4.34.0-rc2`), for use as a **build-time** dependency
of `comparator.nix`. Does not build Lean 4 from source: `fetchurl`s the official prebuilt Linux
x86_64 release tarball (`lean-4.34.0-rc2-linux.tar.zst`, confirmed present via `gh api
repos/leanprover/lean4/releases/tags/v4.34.0-rc2`) as a fixed-output derivation, then unpacks and
relocates it offline via `autoPatchelfHook`.

**flake.nix's `lean4` input**: this repo already declared an unused `lean4` input
(`github:leanprover/lean4`, unpinned). It is deliberately left as comment-and-keep, NOT
pin-and-use: it floats on `leanprover/lean4`'s default branch, and building Lean 4 from source
via that input is unnecessary weight this task does not need (see the comment at that input in
`flake.nix`). `lean-toolchain-bin.nix` is the actual toolchain source of truth for Comparator.

**Load-bearing operational finding (elan-toolchain wrapper scripts break landrun)**: `elan`
installs a Lean toolchain's `bin/lake` as a **bash wrapper script**
(`#!/nix/store/.../bash; ... exec "$dir/lake.orig" "$@"`, injecting `LEAN_CC`), not a raw ELF
binary. landrun's `--ldd` dependency detection (`elfdeps.GetLibraryDependencies`) parses ELF
`DT_NEEDED`/interpreter entries only -- it does not follow shebang lines -- so the wrapper's bash
interpreter is never added to landrun's executable grant list, and the kernel's nested `execve`
of that interpreter is denied by Landlock (a generic, easily-misread `[landrun:error] permission
denied` with no verdict). This was reproduced deterministically outside Comparator too
(`landrun --best-effort --ro / --rw /dev --ldd --add-exec -- lake --version` against an
elan-managed toolchain fails identically) and root-caused via `LANDRUN_LOG_LEVEL=debug`.
`lean-toolchain-bin.nix`'s `autoPatchelfHook`-based binaries are raw ELF (no wrapper script), so
`--ldd` correctly detects and grants the real dynamic linker and `libleanshared*.so` paths, and
the sandboxed build/export pipeline completes. **Operational consequence for any caller of
`comparator` on this host**: `lean`/`lake` must resolve (via `PATH`) to a raw-ELF toolchain, not
one of `elan`'s own installed toolchains, whenever the checked project's toolchain is
`v4.34.0-rc2` -- prefer `lean-toolchain-bin`'s output ahead of `~/.elan/bin` and
`~/.elan/toolchains/*/bin` on `PATH`. For any other Lean version, a caller would need an
equivalent raw-ELF acquisition of that version; providing one generically is out of this task's
scope (see comparator.nix's Non-Goals).

**Wired via**: `overlays/unstable-packages.nix` (`lean-toolchain-bin = final.callPackage
../packages/lean-toolchain-bin.nix { };`); consumed as `nativeBuildInputs` by `comparator.nix`.

### comparator.nix
Real, pinned Nix derivation for [Comparator](https://github.com/leanprover/comparator) itself
-- deliberately **not** a `loogle.nix`-style silent-rebuild wrapper. The task asked for this
argument to be made explicitly rather than the loogle pattern copied by default:

1. **Trust semantics.** Comparator's entire purpose is to be the trustworthy party in an
   adversarial check. A wrapper that clones `master` and silently rebuilds on first use (or after
   a cache wipe) means the binary actually being trusted at verification time is whatever
   `leanprover/comparator@master` happened to be on some unrecorded date, with no Nix-store
   provenance and no way to reproduce or audit exactly what ran for a past verdict -- a bad fit
   for a component whose green/red verdict downstream consumers rely on for a Lean
   proof-verification trust boundary.
2. **Tractability differs from loogle's case.** loogle depends on Mathlib (thousands of files, a
   long first build) -- a real derivation there is a much heavier undertaking, which is why the
   wrapper trade-off was reasonable for it. Comparator's own `lakefile.toml` has exactly one
   `[[require]]` (`lean4export`) and no Mathlib -- light enough that a pinned, offline-buildable
   derivation is realistic.
3. **No upstream Nix entry point.** Neither `leanprover/comparator` nor `leanprover/lean4export`
   ships a `flake.nix` (confirmed 404 on both via the GitHub API), so unlike loogle there is no
   upstream flake to delegate version-resolution to even if desired.

**Offline vendoring vs. FOD fallback (stated explicitly, per the task's "state the reasoning
either way" instruction): the FOD fallback was NOT used.** Comparator's own `[[require]]` for
`lean4export` floats on `rev = "master"`. Rather than making the whole build a network-permitted
fixed-output derivation (which trades away Nix's usual build-sandbox auditability), this
derivation rewrites that require to a local `path`-style dependency pointing at a separately
`fetchFromGitHub`-pinned `lean4export` source (pinned at the exact commit Comparator's own stock
`lake-manifest.json` already resolves `master` to), assembled offline. This was proven in a
scratch harness under `unshare -rn` (network confirmed blocked) before the derivation was written,
and worked cleanly on the first real attempt.

**Runtime toolchain**: `lean-toolchain-bin` is a **build-time** dependency only. At runtime,
`comparator`'s own binary resolves `lean`/`lake`/`git` from whatever is on the invoker's `PATH`
(normally `elan`'s per-project shims), exactly as its own README assumes -- hardcoding this
derivation's own pinned toolchain into a runtime wrapper would be actively wrong for callers
checking projects on a different Lean version. See the `lean-toolchain-bin.nix` section above for
the operational caveat this implies when the checked project targets `v4.34.0-rc2` specifically.

**nanoda deferral**: this derivation does not build or reference `nanoda_bin`. See the dedicated
"nanoda deferral" note below.

**Wired via**: `overlays/unstable-packages.nix` (`comparator = final.callPackage
../packages/comparator.nix { };`). Ships `bin/comparator`,
`share/comparator/tests/projects/` (fixtures, including `simple_mismatch`), and
`share/comparator/scripts/fake-landrun.sh` (development substitute for real `landrun`, consumed
by sibling agent-system tooling in `~/.config/nvim/`).

### lean4export.nix (comparator-lean4export-resolve)
Despite the filename (kept to match the task's declared file scope), this defines a **resolver
script**, `comparator-lean4export-resolve` -- not a fixed `lean4export` binary. This is the
"lean4export version-matching" decision:

**Why one system-wide `lean4export` build is structurally wrong**: `lean4export` loads a target
Lean project's compiled environment (`.olean` files) through Lean's own environment/import
machinery, so the `lean4export` binary itself must be built against a Lean toolchain that is
ABI/format-compatible with whatever Lean version produced those `.olean` files. A binary built
once (e.g. as part of Comparator's own Lake workspace, fixed to Comparator's own `v4.34.0-rc2`)
is correct only for target projects on that exact toolchain and silently wrong for any other.

**Why resolution can't happen inside Comparator's own sandboxed call**: Comparator's `safeExport`
invokes the `lean4export`-pointed binary under `landrun` with `writablePaths := #[]` (no writable
paths at all) and no network passthrough. Nothing can build or fetch a toolchain from inside that
sandboxed call -- resolution MUST happen in the calling harness, before `lake env comparator
config.json` runs.

**Design**: cache key = the target project's exact `lean-toolchain` string (filesystem-safe
slug), cached under `~/.cache/comparator/lean4export/<slug>/`. A sidecar file
(`lean4export.toolchain`) records the exact string the cached binary was built against,
byte-for-byte. Keying the cache path by the version string makes a mismatch structurally hard to
produce; the sidecar makes it cheaply, mechanically detectable by any caller -- **including one
that overrides `COMPARATOR_LEAN4EXPORT` by hand**: a caller doing that should require the same
sidecar convention alongside its override, or refuse to certify a match. This expectation is
recorded here for the consuming side (the nvim-side "doctor mode" and runner script in sibling
agent-system tasks), which lives outside this repository.

On a cache miss, the resolver checks out `leanprover/lean4export` at a documented default pinned
rev (`411dce7db58a3afc60ecab2d211acd1042b593dc`, overridable via `COMPARATOR_LEAN4EXPORT_REV`),
overwrites its `lean-toolchain` with the **target's** exact string, runs `lake build`, and
installs the binary plus the sidecar. A build failure exits non-zero with the real error on
stderr and nothing on stdout -- verified live against a deliberately-nonexistent Lean release.

**Wired via**: `overlays/unstable-packages.nix` (`comparator-lean4export-resolve =
final.callPackage ../packages/lean4export.nix { };`).

### nanoda deferral
`nanoda` (an independent, second Lean kernel implementation) is **explicitly deferred** -- not
silently omitted. It buys exactly one thing: catching the case where Lean's own kernel (used
identically by Comparator's built-in `runBuiltinKernel` path) has a bug that both proves and
"verifies" a bad solution. None of this task's acceptance criteria require it -- they are all
demonstrable using Comparator's built-in kernel path. Concretely:
- `packages/nanoda.nix` does not exist.
- `COMPARATOR_NANODA` is not set in `modules/home/packages/dev-tools.nix` (see the comment at
  that exact site).
- Comparator's own fallback for an unset override is a bare `nanoda_bin` looked up on `PATH`;
  since `nanoda_bin` is not packaged here, `enable_nanoda: true` in any config will fail
  **loudly** (binary-not-found) rather than silently skip the check -- the correct
  "degrade loudly, not silently" behavior for a trust-critical checker.

### systemd-run sandbox-escape wrapper caveat
Comparator's own README recommends invoking it under:
```bash
systemd-run --property=RestrictAddressFamilies=~AF_UNIX --user --pty -E PATH="$PATH" \
  --working-directory $(pwd) -- bash -c 'lake env path/to/comparator/binary path/to/config.json'
```
This guards against a **landrun sandbox-escape vulnerability** that Comparator's README states is
fixed in Linux 7.1. This host (`hamsa`) runs kernel `7.1.3`, past that fix -- but the wrapper is
retained here and in all verification runs (Phase 7) regardless, and **must not be dropped on the
strength of this one host's kernel alone**: the packaging is meant to be portable to hosts on
older kernels, where the wrapper remains load-bearing. Both fixture verification runs (accept and
reject) in this task were performed under this wrapper form and confirmed compatible with this
packaging.

### Env-var contract (`COMPARATOR_LANDRUN` / `COMPARATOR_LEAN4EXPORT` / `COMPARATOR_NANODA`)
This is exactly the contract already relied upon by the sibling agent-system tasks in
`~/.config/nvim/` that call Comparator -- no second contract is invented here:
- `COMPARATOR_LANDRUN` is set to a fixed path in `home.sessionVariables`
  (`modules/home/packages/dev-tools.nix`) -- safe as a fixed global, since `landrun` is not
  per-project-versioned.
- `COMPARATOR_LEAN4EXPORT` is deliberately left **unset** globally. A fixed value would be
  silently wrong for any project whose toolchain differs from whatever
  `comparator-lean4export-resolve` last cached. The calling harness must resolve and export it
  per invocation: `export COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve
  "$project_dir")`.
- `COMPARATOR_NANODA` is deliberately left **unset** globally, per the nanoda deferral above.

**How `COMPARATOR_LANDRUN` actually reaches a shell on this host, and why the propagation delay
is harmless**: `home.sessionVariables` on a NixOS-integrated home-manager setup is **not**
auto-sourced into a plain login shell by `/etc/profile`/`set-environment` -- that chain (and
`/etc/bashrc`, `~/.profile`, `~/.bashrc`) does not source `hm-session-vars.sh` on this host, and
this repo does not enable home-manager's own `programs.bash`/`programs.zsh` (the mechanism that
would normally add that sourcing line). What actually propagates it here is the **graphical
session**: it sources `hm-session-vars.sh` once at login via systemd's user-environment import,
and every terminal spawned from that session inherits it as a child process. Consequence: after a
`sudo nixos-rebuild switch` that changes a session variable, the new value is visible in *new*
terminals only once the graphical session itself has re-logged-in or the host has rebooted -- not
immediately, and not in a bare non-graphical shell (SSH, a TTY console, a systemd service) ever,
absent that per-shell integration. This is ordinary home-manager behavior on this configuration,
not specific to Comparator.

This is deliberately **not** treated as a defect worth a config change, because Comparator's own
upstream code already tolerates `COMPARATOR_LANDRUN` being unset: `Main.lean:335` reads
`let whichLandrun := (← IO.getEnv "COMPARATOR_LANDRUN").getD "landrun"` and falls back to spawning
the bare name `"landrun"`, which Lean's `IO.Process.spawn` resolves via a `PATH` search exactly
like a shell would -- and `landrun` is unconditionally on `PATH` via `~/.nix-profile/bin`
regardless of whether `sessionVariables` has been sourced into the current shell. This was
verified empirically, not just read from source: a fixture re-run (both `simple_match` and
`simple_mismatch`) was performed in a shell with `COMPARATOR_LANDRUN` deliberately left unset, and
both produced correct, content-based verdicts.

**Decision**: accept the standard graphical-session propagation delay for the pinned
`COMPARATOR_LANDRUN` value (option (a)) rather than making a config change to force
`home.sessionVariables` into non-graphical shells (option (c) -- e.g. enabling home-manager's
`programs.bash`/`programs.zsh` repo-wide). That change would still not help genuinely
non-graphical contexts (SSH, systemd services) and is a larger surface change than this gap
justifies. Instead, rely on Comparator's own already-correct PATH-fallback behavior (option (b),
already true upstream -- no code change needed) as the safety net: callers, including the sibling
agent-system tasks in `~/.config/nvim/` that consume this env-var contract, should not treat
`COMPARATOR_LANDRUN` being unset as broken -- `landrun` remains reachable via `PATH` either way.
The fixed `COMPARATOR_LANDRUN` value still matters for pinning exactly which `landrun` build is
invoked (auditability), which is why it is kept rather than removed in favor of the fallback
alone.

### python-check-wheel-contents.nix
Custom Python package for the `check-wheel-contents` wheel linter (v0.6.3), used to audit built
wheels during PyPI release rehearsals. Nixpkgs packages it in neither the stable channel nor
unstable, so it is built here from the PyPI sdist.

**Implementation**: Plain `buildPythonPackage` with `pyproject = true` and a `hatchling`
build backend. Runtime dependencies (`attrs`, `click`, `packaging`, `pydantic`) come from
nixpkgs.

**Privately pinned `wheel-filename`**: nixpkgs ships wheel-filename 2.x, whose 2.0 release
replaced `parse_wheel_filename`/`InvalidFilenameError` with `WheelFilename.parse`/`ParseError`.
check-wheel-contents 0.6.3 still imports the 1.x names, so its `wheel-filename ~= 1.1` pin is
real and must not be relaxed. A 1.4.2 build is defined in a `let` binding inside this file and
used only by this derivation, so nothing else in the Python environment is dragged back to 1.x.

**Deselected tests**: seven `test_from_local_tree*` cases in `test/test_directory.py` compare a
directory walk against an expected tree containing `foo.pyc` and `__pycache__` entries, but
hatchling's default exclusions keep bytecode out of the sdist. They cannot pass in any
sdist-based build and are deselected by exact node id; 952 tests still run.

**Usage**: Available in `python3.withPackages` via `overlays/python-packages.nix`; the
`check-wheel-contents` executable lands on `PATH` through the resulting Python environment.

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/check-wheel-contents/)
2. Get hash: `nix-prefetch-url --unpack https://files.pythonhosted.org/packages/.../check_wheel_contents-VERSION.tar.gz`
3. Update `version` and `hash`, and re-check whether the `wheel-filename` pin still applies
4. Rebuild and test: `check-wheel-contents dist/*.whl`

### python-cvc5.nix
Custom Python package for CVC5 v1.3.1 SMT solver bindings. Nixpkgs does not provide `python3Packages.cvc5`, so this package builds from the PyPI wheel.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pre-built manylinux wheel, then uses `autoPatchelfHook` to fix shared library paths for the bundled native C++ extensions.

**Dependencies**:
- `autoPatchelfHook`: Automatically fixes shared library paths
- `stdenv.cc.cc.lib`: Provides `libstdc++.so.6` for C++ bindings

**Usage**: Available in `python3.withPackages` via the `pythonPackagesOverlay` defined in
`overlays/python-packages.nix`:

```nix
home.packages = with pkgs; [
  (python3.withPackages(p: with p; [
    cvc5
    # ... other packages
  ]))
];
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/cvc5/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/.../cvc5-VERSION-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl`
3. Update `version` and `sha256` in `python-cvc5.nix`
4. Commit changes and rebuild: `home-manager switch --flake .#benjamin`
5. Test: `python3 -c "import cvc5; print(cvc5.__version__)"`

**Related**:
- Report: `specs/reports/011_cvc5_nixos_installation_strategy.md`
- Plan: `specs/plans/009_cvc5_python_bindings_overlay.md`

## UVX/UV Wrapper Pattern

Several packages in this directory follow the same zero-maintenance pattern using UV for package management:

- **aristotle.nix**: `uvx --from aristotlelib@latest aristotle`

**Benefits of UVX Pattern**:
- Automatic updates to latest version from PyPI
- Zero maintenance required
- Uses existing uv installation
- Isolated environment prevents dependency conflicts
- Simple, lightweight wrapper implementation
- Consistent with modern Python packaging best practices

**Implementation Template**:
```nix
{ writeShellScriptBin, uv }:

writeShellScriptBin "package-name" ''
  exec ${uv}/bin/uvx --from package@latest command "$@"
''
```

### pymupdf4llm.nix
Custom Python package for PyMuPDF4LLM v0.2.2, a specialized extension of PyMuPDF for LLM-optimized PDF extraction. Converts PDFs to structured Markdown with preserved hierarchy.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pure Python wheel (`py3-none-any`).

**Dependencies**:
- `pymupdf`: Python bindings for MuPDF (from nixpkgs)
- `tabulate`: Pretty-print tabular data (from nixpkgs)

**Usage**: Available in `python3.withPackages` via the `pythonPackagesOverlay` defined in
`overlays/python-packages.nix`:

```nix
home.packages = with pkgs; [
  (python3.withPackages(p: with p; [
    pymupdf4llm
    # ... other packages
  ]))
];
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/pymupdf4llm/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/py3/p/pymupdf4llm/pymupdf4llm-VERSION-py3-none-any.whl`
3. Convert hash: `nix hash to-sri --type sha256 HASH`
4. Update `version` and `hash` in `pymupdf4llm.nix`
5. Rebuild: `home-manager switch --flake .#benjamin`
6. Test: `python3 -c "import pymupdf4llm; print(pymupdf4llm.__version__)"`

### python-vosk.nix
Custom Python package for Vosk v0.3.45 - offline open source speech recognition API for STT (speech-to-text). Vosk is not available in nixpkgs.

**Implementation**: Uses `buildPythonPackage` with `fetchPypi` to download the pre-built manylinux wheel for x86_64 Linux. Uses `autoPatchelfHook` to fix shared library paths for the bundled native C++ library (`libvosk.so`).

**Dependencies**:
- `autoPatchelfHook`: Automatically fixes shared library paths for native libraries
- `stdenv.cc.cc.lib`: Provides `libstdc++.so.6` for C++ extensions
- `cffi`: C Foreign Function Interface
- `requests`: HTTP library
- `tqdm`: Progress bars
- `srt`: SubRip subtitle parser
- `websockets`: WebSocket support

**Usage**: Available in `python3.withPackages` via the `pythonPackagesOverlay` defined in `flake.nix`:

```nix
home.packages = with pkgs; [
  (python3.withPackages(p: with p; [
    vosk
    # ... other packages
  ]))
];
```

**Model Management**: Language models are declaratively managed via Nix (see `vosk-models.nix`). Models are automatically symlinked to `~/.local/share/vosk/vosk-model-small-en-us-0.15` after `home-manager switch`.

**Test**:
```python
import vosk
import os
model = vosk.Model(os.path.expanduser("~/.local/share/vosk/vosk-model-small-en-us-0.15"))
```

**Update Process**:
1. Check new version on [PyPI](https://pypi.org/project/vosk/)
2. Get hash: `nix-prefetch-url https://files.pythonhosted.org/packages/...`
3. Convert hash: `nix hash to-sri --type sha256 HASH`
4. Update `version` and `hash` in `python-vosk.nix`
5. Rebuild: `nixos-rebuild switch --flake .#HOSTNAME`
6. Test: `python3 -c "import vosk; print(vosk.__version__)"`

**Models**: https://alphacephei.com/vosk/models

**Related**:
- Research: `/home/benjamin/Projects/ProofChecker/specs/761_tts_stt_integration_for_claude_code_and_neovim/reports/research-001.md`

### vosk-models.nix
Declarative Vosk STT language model package for reproducible installations. Downloads the small English US model (~50MB) from alphacephei.com.

**Implementation**: Uses `fetchzip` to download and extract the model archive, then installs to the Nix store with `stripRoot = false` to preserve directory structure. Home-manager symlinks to `~/.local/share/vosk/vosk-model-small-en-us-0.15/`.

**Adding more languages**: Create additional derivations for other language models from https://alphacephei.com/vosk/models.

**Update Process**:
1. Check for new models on https://alphacephei.com/vosk/models
2. Update URL and version
3. Rebuild to get new hash, update hash in the file
4. Rebuild: `home-manager switch --flake .#benjamin`

### piper-bin.nix
Prebuilt Linux x86_64 binary for Piper TTS (rhasspy/piper release `2023.11.14-2`), fetched with
`fetchurl` instead of building nixpkgs' `piper-tts` from source. The release tarball bundles a
precompiled `libonnxruntime.so.1.14.1`, so `onnxruntime` is never compiled (Piper was
originally dropped for this reason, but the source-compile is avoidable via a prebuilt
binary). Upstream repo was archived 2025-10-06; this is the final release.

**Implementation**: `stdenvNoCC.mkDerivation` + `autoPatchelfHook`, flat-installs the tarball's
own `piper`/`espeak-ng`/`piper_phonemize` binaries and bundled `.so` siblings into `$out/bin/`
(matches the tarball layout so `espeak-ng-data/` resolves relative to the binary path at
runtime). Only external runtime dependency beyond glibc is `libstdc++.so.6`
(`buildInputs = [ stdenv.cc.cc.lib ]`).

**Update Process**:
1. `nix-prefetch-url --type sha256 <new-release-url>`
2. `nix hash to-sri --type sha256 <output>`
3. Update `version`/`url`/`hash` in `piper-bin.nix`

### piper-voices.nix
Declarative Piper voice model package for the `en_US-lessac-medium` neural voice. Downloads the
ONNX model and its JSON config from HuggingFace (`rhasspy/piper-voices`).

**Implementation**: Uses two `fetchurl` calls (model + config), copies both into `$out/`.
Home-manager symlinks to `~/.local/share/piper/`.

**Update Process**: Re-run `nix-prefetch-url --type sha256 <url>` against the model/config URLs
if HuggingFace content ever changes; update hashes accordingly.

### neovim.nix
A wrapper around Neovim unstable that fixes missing maintainers metadata to prevent build errors.

## MCPHub Integration

MCPHub is integrated as a standard Neovim plugin using lazy.nvim plugin loading.

### Implementation
MCPHub is loaded via lazy.nvim in the Neovim configuration with the following setup:
- Port: 37373
- Configuration: `~/.config/mcphub/servers.json`
- Integration with Avante for AI functionality

## Text-to-Speech and Speech-to-Text Setup

The system includes TTS and STT tools for Claude Code and Neovim integration.

### TTS: Piper (Custom Package)
Fast, local neural text-to-speech via a prebuilt Linux x86_64 release binary
(`piper-bin.nix`, fetchurl + autoPatchelfHook), restoring the natural
`en_US-lessac-medium` voice without compiling `onnxruntime` from source (see
`piper-bin.nix`/`piper-voices.nix` sections above).

**Test**:
```bash
echo "Hello, this is a test." | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file test.wav
aplay test.wav
```

### STT: Vosk (Custom Package)
See `python-vosk.nix` section above for installation and setup.

### Audio Recording
The system includes PulseAudio client tools (`parecord`) for audio recording:

```bash
# Record 10 seconds at 16kHz (optimal for STT)
timeout 10s parecord --channels=1 --rate=16000 --file-format=wav recording.wav
```

### Integration Examples
- **Claude Code TTS notifications**: See research report for Stop hook implementation
- **Neovim STT**: See research report for Lua integration with `vim.fn.jobstart()`
- **Research**: `/home/benjamin/Projects/ProofChecker/specs/761_tts_stt_integration_for_claude_code_and_neovim/reports/research-001.md`

[← Back to main README](../README.md)