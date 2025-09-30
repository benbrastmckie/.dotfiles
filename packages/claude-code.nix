{ lib, writeShellScriptBin, nodejs }:

writeShellScriptBin "claude" ''
  exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''