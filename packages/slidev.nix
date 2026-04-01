{ lib, writeShellScriptBin, nodejs }:

writeShellScriptBin "slidev" ''
  exec ${nodejs}/bin/npx @slidev/cli@latest "$@"
''
