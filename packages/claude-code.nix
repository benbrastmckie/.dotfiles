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
      ${nodejs}/bin/npx @anthropic-ai/claude-code@2.1.236 "$@"
      return
    fi

    systemd-run --user --scope --unit="claude-$$-$(date +%s)" --quiet -- \
      ${nodejs}/bin/npx @anthropic-ai/claude-code@2.1.236 "$@"
  }

  # Finish any npx install that is missing its native binary. Returns 0 only if it actually
  # repaired something, so an ordinary non-zero exit from claude never triggers a relaunch.
  heal() {
    local cache pkgdir prefix version platform healed=1

    # npx keeps its installs under npm's cache directory, which is only ~/.npm by default --
    # npm_config_cache or an .npmrc moves both. Ask npm rather than guessing. This costs a
    # subprocess, but heal only ever runs after a failed launch.
    cache=$(${nodejs}/bin/npm config get cache 2>/dev/null) || return 1
    [ -d "$cache/_npx" ] || return 1

    for pkgdir in "$cache"/_npx/*/node_modules/@anthropic-ai/claude-code; do
      [ -f "$pkgdir/bin/claude.exe" ] || continue
      # The real binary is ~300MB; only the placeholder stub is anywhere near this small.
      [ "$(stat -c %s "$pkgdir/bin/claude.exe" 2>/dev/null || echo 0)" -lt 1048576 ] || continue

      prefix=''${pkgdir%/node_modules/*}
      version=$(${nodejs}/bin/node -p "require('$pkgdir/package.json').version") || continue
      platform=$(${nodejs}/bin/node -p "process.platform + '-' + process.arch")

      echo "claude: native binary missing, finishing the install (~300MB, may take a few minutes)..." >&2
      ${nodejs}/bin/npm install --prefix "$prefix" --include=optional --no-save \
        "@anthropic-ai/claude-code-$platform@$version" >&2 \
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
