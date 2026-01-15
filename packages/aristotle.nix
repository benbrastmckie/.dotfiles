{ lib, writeShellScriptBin, uv }:

writeShellScriptBin "aristotle" ''
  exec ${uv}/bin/uvx --from aristotlelib@latest aristotle "$@"
''