# zot (zotero-cli-cc) - Zotero CLI for Claude Code, fetched via uvx on each invocation.
# Custom because zotero-cli-cc is a PyPI/uvx-distributed tool, not packaged in nixpkgs.
# Consumed by the literature extension's Zotero write-back path in ~/.config/nvim.
# @latest matches the aristotle.nix precedent (zero-maintenance, tracks upstream releases).
#
# --with httpx works around an upstream packaging bug: zotero_cli_cc imports httpx in four
# modules (core/writer.py, metadata_resolver.py, semantic_scholar.py, local_bridge.py) but never
# declares it in Requires-Dist. It used to arrive transitively via openai and pyzotero; both have
# since moved to httpx2 (the httpx 2.x PyPI rename, module `httpx2`), so the accidental provider
# vanished and every `zot` invocation died with ModuleNotFoundError: No module named 'httpx'.
# Note: pinning zotero-cli-cc@0.10.0 would NOT have prevented this -- the drift was in the
# transitive graph (openai>=2.33.0 floating to 3.11.0), which a tool-version pin leaves free.
# Drop this flag once upstream declares httpx (or migrates its imports to httpx2).
{
  writeShellScriptBin,
  uv,
}:

writeShellScriptBin "zot" ''
  exec ${uv}/bin/uvx --with httpx --from zotero-cli-cc@latest zot "$@"
''
