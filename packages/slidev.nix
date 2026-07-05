# slidev - presentation slides from Markdown, fetched via npx on each invocation.
# Custom because @slidev/cli is an npm-distributed tool, not packaged in nixpkgs.
{
  writeShellScriptBin,
  nodejs,
}:

writeShellScriptBin "slidev" ''
  exec ${nodejs}/bin/npx @slidev/cli@latest "$@"
''
