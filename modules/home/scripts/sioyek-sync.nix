# Sioyek ctrl+click inverse-search dispatcher.
#
# Sioyek binds `control_click_command` globally, with no per-filetype hook, so one
# handler has to serve both kinds of document and decide which it is looking at:
#
#   * a LaTeX PDF, recognised by the SyncTeX file beside it, is handed back to Sioyek's
#     own `synctex_under_cursor`, which already knows how to use `inverse_search_command`
#     to reach VimTeX. The mouse has not moved, so the click resolves as it always did.
#
#   * a Typst PDF has no SyncTeX file, because Typst emits none. Its position mapping
#     lives in tinymist instead, reached through the per-project sync daemon that Neovim
#     starts. The registry file -- written by `neotex.util.typst_sync`, keyed by the first
#     twelve hex digits of the SHA-256 of the PDF path -- is what connects a click in a
#     detached viewer back to the Neovim instance editing that document.
#
# Resolution is left to Neovim rather than done here, so one implementation owns the
# coordinate conventions and the user sees failures as ordinary notifications. Only the
# three numbers Sioyek reports and that hex key cross into the remote expression, so no
# document path is ever subjected to shell or Vimscript quoting.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "sioyek-inverse-search" ''
      set -u
      PATH=${pkgs.jq}/bin:${pkgs.coreutils}/bin:$PATH

      pdf="''${1:-}"
      page="''${2:-}"
      x="''${3:-}"
      y="''${4:-}"

      [ -n "$pdf" ] || exit 0

      # LaTeX keeps its existing SyncTeX path.
      base="''${pdf%.pdf}"
      if [ -e "$base.synctex.gz" ] || [ -e "$base.synctex" ]; then
        exec sioyek --nofocus --execute-command synctex_under_cursor
      fi

      # Typst needs a full document position; a click outside any page has none.
      if [ -z "$page" ] || [ -z "$x" ] || [ -z "$y" ]; then
        exit 0
      fi

      key=$(printf '%s' "$pdf" | sha256sum | cut -c1-12)
      registry="''${XDG_CACHE_HOME:-$HOME/.cache}/nvim/typst-sync/$key.json"
      [ -r "$registry" ] || exit 0

      server=$(jq -r '.servername // empty' "$registry")
      [ -n "$server" ] || exit 0
      [ -e "$server" ] || exit 0

      exec nvim --server "$server" --remote-expr \
        "luaeval('require(\"neotex.util.typst_sync\").inverse_rpc(_A)', [$page, $x, $y, \"$key\"])" \
        >/dev/null 2>&1
    '')
  ];
}
