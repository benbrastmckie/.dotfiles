# comparator-lean4export-resolve: a toolchain-keyed resolver for `lean4export`, NOT a fixed
# `lean4export` binary. This file keeps its plan-declared name (packages/lean4export.nix) but
# defines a resolver package -- see the "why a resolver, not a binary" rationale below.
#
# Why one system-wide lean4export build is structurally wrong (verified by reading
# leanprover/lean4export and leanprover/comparator source, not assumed): `lean4export` loads a
# target Lean project's compiled environment (`.olean` files) through Lean's own
# environment/import machinery, so the `lean4export` binary itself must be built against a Lean
# toolchain that is ABI/format-compatible with whatever Lean version produced those `.olean`
# files. A binary built once (e.g. as part of Comparator's own Lake workspace, fixed to
# Comparator's own `v4.34.0-rc2`) is correct only for target projects on that exact toolchain and
# silently wrong for any other.
#
# Why the resolution can't happen inside Comparator's own sandboxed call: Comparator's
# `safeExport` (Main.lean) invokes the `lean4export`-pointed binary under `landrun` with
# `writablePaths := #[]` (no writable paths at all) and no network passthrough. Nothing can
# build or fetch a toolchain from inside that sandboxed call -- resolution MUST happen in the
# calling harness, before `lake env comparator config.json` runs. This script is exactly that
# hoisted-out resolution step; it is deliberately outside any landrun sandbox itself (it needs
# both write access, for the cache, and network, to fetch a toolchain/lean4export source), so
# there is no purity conflict with a Nix derivation the way there would be for `comparator`
# itself (see packages/comparator.nix's header for that argument).
#
# Design: cache key = the target project's exact `lean-toolchain` string (a filesystem-safe
# slug of it); a sidecar `lean4export.toolchain` file records the exact string the cached binary
# was built against, byte-for-byte. Keying the cache path by the version string makes a mismatch
# structurally hard to produce; the sidecar makes it cheaply, mechanically detectable by any
# caller -- including one that overrides `COMPARATOR_LEAN4EXPORT` by hand (a caller doing that
# should require the same sidecar convention alongside its override, or refuse to certify a
# match; this is the expectation recorded here for the consuming side, which lives outside this
# repository -- see packages/README.md).
{
  writeShellApplication,
  git,
  elan,
  coreutils,
  gnused,
}:

writeShellApplication {
  name = "comparator-lean4export-resolve";
  runtimeInputs = [
    git
    elan
    coreutils
    gnused
  ];
  text = ''
    # comparator-lean4export-resolve: resolve (build/cache, or reuse a cached) lean4export
    # binary matched to a TARGET project's exact Lean toolchain.
    #
    # Usage:
    #   comparator-lean4export-resolve <target-dir>          # reads <target-dir>/lean-toolchain
    #   comparator-lean4export-resolve --toolchain <string>  # explicit toolchain string
    #   comparator-lean4export-resolve --help
    #
    # On success, prints ONLY the resolved lean4export binary's absolute path on stdout, so:
    #   export COMPARATOR_LEAN4EXPORT=$(comparator-lean4export-resolve "$project_dir")
    #
    # Env overrides:
    #   COMPARATOR_LEAN4EXPORT_REV    - override the pinned leanprover/lean4export commit
    #   COMPARATOR_LEAN4EXPORT_CACHE  - override the cache root
    #                                   (default: ~/.cache/comparator/lean4export)
    #
    # Exit codes: 0 on success (path printed to stdout). Non-zero, with a message on stderr and
    # NO stdout output, on any failure -- a caller must never receive a stale or partial path.

    set -euo pipefail

    # Default pinned rev: leanprover/lean4export @ master as of this packaging (2026-09-07),
    # which currently pins the same v4.34.0-rc2 toolchain as Comparator's own lakefile. This is
    # a *default* clone point only -- the script always overwrites the checked-out
    # lean-toolchain file with the TARGET's string before building, so the resolved binary is
    # always built under the target's toolchain regardless of this rev. Override via
    # COMPARATOR_LEAN4EXPORT_REV for a target project whose toolchain predates what this rev's
    # lean4export sources can read (e.g. a since-renamed export format).
    default_rev="411dce7db58a3afc60ecab2d211acd1042b593dc"
    rev="''${COMPARATOR_LEAN4EXPORT_REV:-$default_rev}"
    cache_root="''${COMPARATOR_LEAN4EXPORT_CACHE:-$HOME/.cache/comparator/lean4export}"

    print_help() {
      cat <<'HELP'
    comparator-lean4export-resolve - toolchain-keyed lean4export resolver for Comparator

    Usage:
      comparator-lean4export-resolve <target-dir>
      comparator-lean4export-resolve --toolchain <lean-toolchain-string>
      comparator-lean4export-resolve --help

    Prints the resolved lean4export binary's absolute path to stdout on success.
    Builds and caches a lean4export binary keyed by the target's exact lean-toolchain string;
    a sidecar file (lean4export.toolchain) records the exact string it was built against.

    Env overrides:
      COMPARATOR_LEAN4EXPORT_REV    override the pinned leanprover/lean4export commit
      COMPARATOR_LEAN4EXPORT_CACHE  override the cache root
    HELP
    }

    if [ "$#" -eq 0 ]; then
      echo "comparator-lean4export-resolve: missing argument (target dir or --toolchain <string>); see --help" >&2
      exit 2
    fi

    toolchain=""
    case "$1" in
      --help|-h)
        print_help
        exit 0
        ;;
      --toolchain)
        if [ "$#" -lt 2 ]; then
          echo "comparator-lean4export-resolve: --toolchain requires an argument" >&2
          exit 2
        fi
        toolchain="$2"
        ;;
      *)
        target_dir="$1"
        if [ ! -f "$target_dir/lean-toolchain" ]; then
          echo "comparator-lean4export-resolve: $target_dir/lean-toolchain not found" >&2
          exit 2
        fi
        toolchain="$(cat "$target_dir/lean-toolchain")"
        ;;
    esac

    if [ -z "$toolchain" ]; then
      echo "comparator-lean4export-resolve: resolved an empty toolchain string" >&2
      exit 2
    fi

    # Filesystem-safe slug: keep alnum/dot/dash/underscore, replace everything else (":", "/")
    # with "-". This is a many-to-one-safe simplification only in the sense that DIFFERENT
    # toolchain strings that happen to collide after slugging would share a cache slot; the
    # sidecar file (checked below on every cache hit) is the actual correctness guarantee, not
    # the slug alone.
    slug="$(printf '%s' "$toolchain" | sed -e 's/[^A-Za-z0-9._-]/-/g')"
    cache_dir="$cache_root/$slug"
    bin_path="$cache_dir/lean4export"
    sidecar_path="$cache_dir/lean4export.toolchain"

    if [ -x "$bin_path" ] && [ -f "$sidecar_path" ]; then
      cached_toolchain="$(cat "$sidecar_path")"
      if [ "$cached_toolchain" = "$toolchain" ]; then
        printf '%s\n' "$bin_path"
        exit 0
      fi
      echo "comparator-lean4export-resolve: cache slot $cache_dir exists but its sidecar ($cached_toolchain) does not match the requested toolchain ($toolchain) -- refusing to return a possibly-mismatched binary; remove $cache_dir to force a rebuild" >&2
      exit 1
    fi

    echo "comparator-lean4export-resolve: cache miss for toolchain '$toolchain' (slot: $slug); building..." >&2

    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT

    if ! git clone --quiet https://github.com/leanprover/lean4export.git "$work_dir/src" >&2; then
      echo "comparator-lean4export-resolve: git clone of leanprover/lean4export failed" >&2
      exit 1
    fi

    (
      cd "$work_dir/src"
      if ! git checkout --quiet "$rev"; then
        echo "comparator-lean4export-resolve: git checkout of rev $rev failed" >&2
        exit 1
      fi
    )

    # Overwrite with the TARGET's exact toolchain string so elan/lake build lean4export under
    # the target's Lean version, not lean4export's own upstream default.
    printf '%s' "$toolchain" > "$work_dir/src/lean-toolchain"

    build_log="$work_dir/build.log"
    if ! (cd "$work_dir/src" && lake build lean4export) >"$build_log" 2>&1; then
      echo "comparator-lean4export-resolve: lake build failed for toolchain '$toolchain' (rev $rev); see build log below" >&2
      cat "$build_log" >&2
      exit 1
    fi

    built_bin="$work_dir/src/.lake/build/bin/lean4export"
    if [ ! -x "$built_bin" ]; then
      echo "comparator-lean4export-resolve: build reported success but $built_bin is missing or not executable" >&2
      exit 1
    fi

    mkdir -p "$cache_dir"
    install -m755 "$built_bin" "$bin_path.tmp"
    printf '%s' "$toolchain" > "$sidecar_path.tmp"
    mv "$bin_path.tmp" "$bin_path"
    mv "$sidecar_path.tmp" "$sidecar_path"

    printf '%s\n' "$bin_path"
  '';

  meta = {
    description = "Toolchain-keyed resolver that builds/caches a lean4export binary matched to a target Lean project's exact lean-toolchain, for Comparator's COMPARATOR_LEAN4EXPORT contract";
  };
}
