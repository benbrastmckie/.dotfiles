# Wrapper that fetches Claude Code via npx on each invocation.
# To pin a version, replace @latest with @X.Y.Z (e.g. @2.1.177).
# After changing this file, rebuild with: sudo nixos-rebuild switch --flake .#<host>
# The npx cache (~/.npm/_npx/) may also need clearing: rm -rf ~/.npm/_npx/
# Model selection is in config/claude/settings.json (ANTHROPIC_DEFAULT_OPUS_MODEL).
#
# Scope containment: each invocation runs inside its own transient systemd --user scope
# (unit `claude-$$-<epoch>.scope`), so all descendants -- including setsid/double-forked
# children and MCP server subprocesses -- are contained in one per-session cgroup instead of
# sharing wezterm's. This lets the reaper module
# (modules/home/services/claude-session-reaper.nix) find and stop a session's process tree
# after it exits, without ever touching processes outside that scope. See
# docs/claude-session-scopes.md for the full mechanism, the liveness-only guarantee, and the
# opt-out for deliberately-detached work.
#
# Escape hatch: export CLAUDE_NO_SCOPE=1 to bypass containment for the current shell with no
# rebuild (e.g. if the scope wrapper ever regresses interactive terminal behavior).
#
# No --pty (invalid in combination with --scope, and unnecessary: a scope's child is an
# ordinary foreground process of the invoking shell with fds 0/1/2 inherited). No -d/--same-dir
# or -E/--setenv: cwd and environment already propagate through plain `systemd-run --user
# --scope`. --collect was evaluated empirically and omitted: on this host's systemd, transient
# scope units already auto-unload from `systemctl --user list-units` on both clean and
# non-zero exit with no observable difference, so the flag is not load-bearing here.
#
# Self-heal: claude 2.x is a thin npm wrapper plus a ~300MB platform-native binary shipped as
# an optionalDependency (@anthropic-ai/claude-code-<platform>). When npx fetches the wrapper
# but not the native package -- a slow or interrupted download on a @latest bump is enough --
# bin/claude.exe is left as a 500-byte placeholder stub that prints an error and exits 1. The
# symptom is that `claude` closes the instant it opens, in every directory. `heal` finishes
# that install in place and the launch is retried once.
#
# The same stub appears for a second reason, which the fallback in `install_native` covers: the
# wrapper and its native packages are published separately, so a wrapper version can exist on
# the registry while the matching platform build does not (observed at 2.1.237, whose
# linux-x64 build was never published). npm skips the unresolvable optionalDependency without
# failing the install, leaving the stub -- and the version the stub asks for is the one version
# that cannot be fetched, so healing at the stub's own version can only fail. `install_native`
# therefore falls back to the newest platform build that exists.
#
# `launch` is deliberately not `exec`: the retry needs the wrapper to outlive the first
# attempt. The residual bash parent is inert -- it holds no fds of its own and exits with the
# child. Signals behave as before, since the child shares the wrapper's process group.
{
  writeShellScriptBin,
  nodejs,
}:

writeShellScriptBin "claude" ''
  launch() {
    # Bare exec when containment is waived, or when there is no working user manager to scope
    # against (e.g. an SSH session without lingering, or a container).
    if [ -n "''${CLAUDE_NO_SCOPE:-}" ] \
      || ! command -v systemd-run >/dev/null 2>&1 \
      || [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
      # Pinned fallback, kept for quick re-pinning:
      # ${nodejs}/bin/npx @anthropic-ai/claude-code@2.1.236 "$@"
      ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
      return
    fi

    # Pinned fallback, kept for quick re-pinning:
    # systemd-run --user --scope --unit="claude-$$-$(date +%s)" --quiet -- \
    #   ${nodejs}/bin/npx @anthropic-ai/claude-code@2.1.236 "$@"
    systemd-run --user --scope --unit="claude-$$-$(date +%s)" --quiet -- \
      ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
  }

  # Resolve npm's cache directory, which is where npx keeps its installs. It is ~/.npm by
  # default, and both npm_config_cache and an .npmrc `cache=` line move it. Ask npm rather than
  # guessing. This costs a subprocess, but heal only ever runs after a failed launch.
  #
  # `npm config get cache` alone is not enough: npm 11 treats `cache` as a protected option and
  # refuses to print it whenever it has been moved off the default -- exactly the case worth
  # resolving, so relying on it alone makes heal a silent no-op for anyone with a relocated
  # cache. The remaining sources are read directly instead of via `npm config ls`, which does
  # report an overridden cache but redacts token-like path segments (a path containing a UUID
  # comes back with `***` spliced into it), and a silently corrupted path is worse than none.
  npm_cache_dir() {
    local cache npmrc

    # An env override is authoritative, and is also the value npm will refuse to print back.
    if [ -n "''${npm_config_cache:-}" ]; then
      printf '%s\n' "''${npm_config_cache}"
      return 0
    fi

    # Succeeds whenever the cache sits at npm's default, which is the common case.
    if cache=$(${nodejs}/bin/npm config get cache 2>/dev/null) && [ -n "$cache" ]; then
      printf '%s\n' "$cache"
      return 0
    fi

    # Refused, so an .npmrc moved it. Last value wins, matching npm's own parsing.
    npmrc=''${npm_config_userconfig:-$HOME/.npmrc}
    cache=$(sed -n 's/^[[:space:]]*cache[[:space:]]*=[[:space:]]*//p' "$npmrc" 2>/dev/null | tail -1)
    cache=''${cache%\"}
    cache=''${cache#\"}
    case "$cache" in
      "~/"*) cache=$HOME/''${cache#\~/} ;;
    esac

    [ -n "$cache" ] || return 1
    printf '%s\n' "$cache"
  }

  # Install the platform-native package for the wrapper unpacked at $prefix.
  #
  # The wrapper's own version is tried first, then the newest platform build that exists. The
  # fallback matters because the two packages are published separately: a wrapper can land on
  # the registry minutes before -- or without -- its native counterpart, and then the version
  # the stub asks for is exactly the version that cannot be fetched. Retrying it forever is a
  # guaranteed hard failure, so we take the newest build actually published instead.
  #
  # The skew is safe: install.cjs resolves the native package by NAME (require.resolve) and
  # never compares versions, and the wrapper package is only a delivery shell -- the native
  # binary is the whole application. Healing to N-1 yields a working claude at N-1, which is
  # what pinning by hand would have produced anyway.
  install_native() {
    local prefix=$1 platform=$2 version=$3 pkg newest

    pkg="@anthropic-ai/claude-code-$platform"

    if ${nodejs}/bin/npm install --prefix "$prefix" --include=optional --no-save \
      "$pkg@$version" >&2; then
      return 0
    fi

    newest=$(${nodejs}/bin/npm view "$pkg@latest" version 2>/dev/null) || return 1
    # Nothing to fall back to: no dist-tag, or it points at the version that just failed.
    { [ -n "$newest" ] && [ "$newest" != "$version" ]; } || return 1

    echo "claude: no $platform build published for $version; healing to $newest instead." >&2
    ${nodejs}/bin/npm install --prefix "$prefix" --include=optional --no-save "$pkg@$newest" >&2
  }

  # Finish any npx install that is missing its native binary. Returns 0 only if it actually
  # repaired something, so an ordinary non-zero exit from claude never triggers a relaunch.
  heal() {
    local cache pkgdir prefix version platform healed=1

    cache=$(npm_cache_dir) || return 1
    [ -d "$cache/_npx" ] || return 1

    for pkgdir in "$cache"/_npx/*/node_modules/@anthropic-ai/claude-code; do
      [ -f "$pkgdir/bin/claude.exe" ] || continue
      # The real binary is ~300MB; only the placeholder stub is anywhere near this small.
      [ "$(stat -c %s "$pkgdir/bin/claude.exe" 2>/dev/null || echo 0)" -lt 1048576 ] || continue

      prefix=''${pkgdir%/node_modules/*}
      version=$(${nodejs}/bin/node -p "require('$pkgdir/package.json').version") || continue
      platform=$(${nodejs}/bin/node -p "process.platform + '-' + process.arch")

      echo "claude: native binary missing, finishing the install (~300MB, may take a few minutes)..." >&2
      install_native "$prefix" "$platform" "$version" \
        && ${nodejs}/bin/node "$pkgdir/install.cjs" >&2 \
        && healed=0
    done

    return $healed
  }

  launch "$@" && exit 0
  status=$?
  heal || exit $status
  launch "$@"
''
