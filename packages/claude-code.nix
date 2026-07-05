# Wrapper that fetches Claude Code via npx on each invocation.
# To pin a version, replace @latest with @X.Y.Z (e.g. @2.1.177).
# After changing this file, rebuild with: sudo nixos-rebuild switch --flake .#<host>
# The npx cache (~/.npm/_npx/) may also need clearing: rm -rf ~/.npm/_npx/
# Model selection is in config/claude/settings.json (ANTHROPIC_DEFAULT_OPUS_MODEL).
{
  writeShellScriptBin,
  nodejs,
}:

writeShellScriptBin "claude" ''
  exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''
