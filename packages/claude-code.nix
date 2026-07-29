# Wrapper that fetches Claude Code via npx on each invocation.
# To pin a version, replace @latest with @X.Y.Z (e.g. @2.1.177).
# After changing this file, rebuild with: sudo nixos-rebuild switch --flake .#<host>
# The npx cache (~/.npm/_npx/) may also need clearing: rm -rf ~/.npm/_npx/
# Model selection is in config/claude/settings.json (ANTHROPIC_DEFAULT_OPUS_MODEL).
#
# Scope containment: each invocation execs inside its own transient systemd --user scope
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
{
  writeShellScriptBin,
  nodejs,
}:

writeShellScriptBin "claude" ''
  # Escape hatch: skip containment entirely when requested (no rebuild needed).
  if [ -n "''${CLAUDE_NO_SCOPE:-}" ]; then
    exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
  fi

  # Fall back to a bare exec when there is no working user manager to scope against
  # (e.g. an SSH session without lingering, or a container).
  if ! command -v systemd-run >/dev/null 2>&1 || [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
    exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
  fi

  UNIT="claude-$$-$(date +%s)"
  exec systemd-run --user --scope --unit="$UNIT" --quiet -- \
    ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''
