# zot (zotero-cli-cc) - Zotero CLI for Claude Code, fetched via uvx on each invocation.
# Custom because zotero-cli-cc is a PyPI/uvx-distributed tool, not packaged in nixpkgs.
# Consumed by the literature extension's Zotero write-back path in ~/.config/nvim.
# @latest matches the aristotle.nix precedent (zero-maintenance, tracks upstream releases);
# pinning (zotero-cli-cc@0.10.0) is a one-line change here if version drift becomes a problem.
{
  writeShellScriptBin,
  uv,
}:

writeShellScriptBin "zot" ''
  exec ${uv}/bin/uvx --from zotero-cli-cc@latest zot "$@"
''
