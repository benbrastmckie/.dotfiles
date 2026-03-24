{ lib, writeShellScriptBin, nodejs }:

writeShellScriptBin "claude" ''
  export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-4-6[1m]"
  exec ${nodejs}/bin/npx @anthropic-ai/claude-code@latest "$@"
''
