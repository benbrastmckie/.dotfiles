# aristotle - AI theorem prover with Lean support, fetched via uvx on each invocation.
# Custom because aristotlelib is a PyPI/uvx-distributed tool, not packaged in nixpkgs.
{
  writeShellScriptBin,
  uv,
}:

writeShellScriptBin "aristotle" ''
  exec ${uv}/bin/uvx --from aristotlelib@latest aristotle "$@"
''
