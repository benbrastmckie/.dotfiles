# landrun: a Landlock-based sandbox used by Comparator (leanprover/comparator) to isolate the
# `lake build` and `lean4export` steps it runs against untrusted Lean submissions.
#
# Why this is pinned at v0.1.17 rather than nixpkgs' own `landrun` (0.1.15 as of this writing),
# deliberately -- not a stylistic preference:
#
# Comparator hardcodes `--best-effort --ro / --rw /dev --ldd --add-exec` on every sandboxed
# invocation (both the `lake build` step and the `lean4export` step; see the upstream
# `buildLandrunArgs` in Comparator's `Main.lean`). `--ldd`'s implementation changed between
# 0.1.15 and v0.1.16/v0.1.17/main:
#   - 0.1.15: shells out to the system `ldd` binary and parses its text output -- a SHALLOW
#     (non-recursive) dependency scan that only sees a binary's direct shared-library deps.
#   - v0.1.16+/main: an internal ELF parser (`elfdeps.GetLibraryDependencies`) that walks
#     dependencies breadth-first and RECURSIVELY (landrun PRs #38, #40). This is a real
#     correctness fix in exactly the flag combination Comparator exercises, not a hypothetical
#     one -- and more likely to matter on NixOS, where binaries commonly have several layers of
#     /nix/store shared-library indirection that a shallow scan is prone to miss.
#   - Also relevant to a sandboxed `lake build`: PR #49 ("use Restrict() to avoid REFER
#     permission denial") fixes cross-directory rename/link failing with EXDEV even when the
#     target directory is granted `--rw` -- a plausible failure mode for `lake build`'s
#     write-to-temp-then-rename artifact production, present in 0.1.15 and fixed after it.
#   - go-landlock was bumped to v0.9.0 (Landlock ABI V9, up from 0.1.15's effective V5 ceiling)
#     between v0.1.16 and v0.1.17 (upstream-documented BREAKING CHANGE in go-landlock). Because
#     Comparator always passes `--best-effort`, this degrades gracefully on older kernels rather
#     than hard-failing, but 0.1.15 enforces a materially weaker sandbox on any kernel that
#     supports more.
#   - `main` (as of this pin) is only 4 purely cosmetic commits ahead of the `v0.1.17` tag
#     (README/CI text, a funding file) -- functionally `main == v0.1.17`, so the tag is pinned
#     as the more stable target rather than a floating branch.
#
# This host's probed Landlock ABI level (via a `landlock_create_ruleset(NULL, 0,
# LANDLOCK_CREATE_RULESET_VERSION)` syscall probe) is 9 -- i.e. it matches go-landlock v0.9.0's
# ABI V9 ceiling exactly, so this pin buys the full sandboxing strength v0.1.17 offers on this
# host, not just a degraded --best-effort fallback.
#
# Deliberate overlay shadow: this attribute name intentionally shadows nixpkgs' own `landrun`
# (0.1.15) in overlays/unstable-packages.nix -- see the comment there (same pattern as
# `playwright-mcp`'s deliberate shadow of nixpkgs' stale packaging).
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule (finalAttrs: {
  pname = "landrun";
  version = "0.1.17";

  src = fetchFromGitHub {
    owner = "Zouuup";
    repo = "landrun";
    tag = "v${finalAttrs.version}";
    # Pinned by tag; the tag's commit is 62823c05e58ec22c1f91b4c8468318c1f97f2d32.
    hash = "sha256-BjIRO5qDd5lnNZEE8gmMJP0CN6ZOAIFEb/DzDRD2fu8=";
  };

  vendorHash = "sha256-gmmXTffuHFPbPKNY2DrFApXT2xazwnvmM4/aQiepMuY=";

  # Upstream's test.sh requires heavy sandbox patching (see nixpkgs' own package.nix for the
  # scale of substituteInPlace that needs) and exercises real network restriction behaviour that
  # doesn't fit a Nix build sandbox. We rely instead on versionCheckHook plus a direct
  # `--best-effort` smoke invocation, which is enough to prove the binary runs and reports the
  # pinned version -- the full behavioural proof (accepting/rejecting Comparator fixtures) is a
  # separate, later verification step (see packages/README.md).
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  postInstallCheck = ''
    set +e
    $out/bin/landrun --best-effort --rox ${builtins.storeDir} -- sh -c 'exit'
    status=$?
    set -e
    if [ "$status" != 0 ]; then
      echo "landrun --best-effort smoke invocation failed with status $status" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Lightweight, secure sandbox for running Linux processes using Landlock LSM (pinned v0.1.17, not nixpkgs' 0.1.15 -- see header comment)";
    mainProgram = "landrun";
    homepage = "https://github.com/Zouuup/landrun";
    changelog = "https://github.com/Zouuup/landrun/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
})
