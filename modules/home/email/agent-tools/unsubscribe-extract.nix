# Part of the task-88 split of the former monolithic email/agent-tools.nix; see lib.nix in
# this directory for the full contract provenance and shared helpers (wrapper-contract.md).
#
# =======================================================================================
# email-unsubscribe-extract (read-only) — List-Unsubscribe header harvest, never fetches
# =======================================================================================
{ pkgs, ... }:
let
  inherit (import ./lib.nix) mkPreamble;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "email-unsubscribe-extract" (mkPreamble {
      name = "email-unsubscribe-extract";
      verb = "extract List-Unsubscribe headers to a review list (read-only)";
      safetyClass = "read-only";
      extraHelp = ''
        Flags:
          [QUERY]        notmuch query to scan (default: "folder:<Account>" = INBOX)
          --limit <N>    Cap messages scanned (default: 200)

        Extracts RFC 2369 List-Unsubscribe (and RFC 8058 List-Unsubscribe-Post, when present)
        headers only. NEVER fetches or POSTs the URLs found — see
        planetaryescape/list-unsubscribe and RFC 8058 for the one-click semantics this
        binary deliberately does NOT hand-roll. Classification use of the header is #803's.
      '';
    } + ''
      QUERY="folder:$ACCOUNT_FOLDER"
      LIMIT=200
      UX_ARGS=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --limit) LIMIT="''${2:-}"; shift 2 ;;
          --limit=*) LIMIT="''${1#--limit=}"; shift ;;
          *) UX_ARGS+=("$1"); shift ;;
        esac
      done
      set -- "''${UX_ARGS[@]}"
      if [ "$#" -gt 0 ]; then
        QUERY="$*"
      fi

      extract_header() {
        # Handles RFC 2822 header folding (continuation lines start with whitespace).
        local file="$1" header="$2"
        awk -v h="^''${header}:" 'BEGIN{IGNORECASE=1}
          $0 ~ h {capture=1; sub(h,""); printf "%s", $0; next}
          capture && /^[ \t]/ {printf " %s", $0; next}
          capture {exit}
        ' "$file" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
      }

      mids=$(notmuch search --output=messages "$QUERY" 2>/dev/null | sed 's/^id://' | head -n "$LIMIT" || true)
      n=0
      while IFS= read -r mid; do
        [ -z "$mid" ] && continue
        file=$(notmuch search --output=files "id:$mid" 2>/dev/null | head -n1 || true)
        [ -z "$file" ] && continue
        lu=$(extract_header "$file" "List-Unsubscribe")
        [ -z "$lu" ] && continue
        lup=$(extract_header "$file" "List-Unsubscribe-Post")
        from=$(notmuch show --format=json --body=false "id:$mid" 2>/dev/null \
          | jq -r 'if (.[0][0][0] | type) == "object" then (.[0][0][0].headers.From // "") else "" end' 2>/dev/null || true)
        jq -nc --arg mid "$mid" --arg sender "$from" --arg list_unsubscribe "$lu" \
          --arg list_unsubscribe_post "$lup" \
          '{message_id:$mid, sender:$sender, list_unsubscribe:$list_unsubscribe, list_unsubscribe_post:($list_unsubscribe_post|select(length>0)) }'
        n=$((n + 1))
      done <<< "$mids"
      log "Extracted List-Unsubscribe headers for $n of up to $LIMIT scanned message(s)."
    ''))
  ];
}
