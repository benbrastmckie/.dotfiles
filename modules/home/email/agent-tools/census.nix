# Part of the task-88 split of the former monolithic email/agent-tools.nix; see lib.nix in
# this directory for the full contract provenance and shared helpers (wrapper-contract.md).
#
# =======================================================================================
# email-census (read-only) — sender/folder/date census
# =======================================================================================
{ pkgs, ... }:
let
  inherit (import ./lib.nix) mkPreamble;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "email-census" (
      mkPreamble {
        name = "email-census";
        verb = "report sender/folder/date census (read-only)";
        safetyClass = "read-only";
      }
      + ''
        echo "=== email-census (account: $ACCOUNT) ==="
        echo ""
        echo "--- Folder counts (folder-scoped queries; verification-baseline.md §4) ---"
        printf "%-10s %s\n" "INBOX" "$(notmuch count "folder:$ACCOUNT_FOLDER")"
        case "$ACCOUNT" in
          gmail)
            printf "%-10s %s\n" "All_Mail" "$(notmuch count 'folder:Gmail/.All_Mail')"
            printf "%-10s %s\n" "Sent" "$(notmuch count 'folder:Gmail/.Sent')"
            printf "%-10s %s\n" "Trash" "$(notmuch count 'folder:Gmail/.Trash')"
            printf "%-10s %s\n" "Spam" "$(notmuch count 'folder:Gmail/.Spam')"
            printf "%-10s %s\n" "Drafts" "$(notmuch count 'folder:Gmail/.Drafts')"
            ;;
          logos)
            printf "%-10s %s\n" "Sent" "$(notmuch count 'folder:Logos/.Sent')"
            printf "%-10s %s\n" "Archive" "$(notmuch count 'folder:Logos/.Archive')"
            printf "%-10s %s\n" "Trash" "$(notmuch count 'folder:Logos/.Trash')"
            printf "%-10s %s\n" "Drafts" "$(notmuch count 'folder:Logos/.Drafts')"
            ;;
        esac
        echo ""
        echo "--- Index freshness: INBOX on-disk (himalaya) vs notmuch-indexed FILES ---"
        echo "(divergence beyond tolerance => notmuch index is stale for INBOX; reconcile with"
        echo " 'email-reindex' before a coverage-promising --all sweep.)"
        # (a) file-vs-file. notmuch(1): --output=files returns EVERY known file for a matching message,
        # incl. duplicates in other folders/accounts, so post-filter to the exact maildir path prefix.
        INBOX_ONDISK=$(himalaya envelope list "''${HIMALAYA_ACCT[@]}" -f INBOX -o json -s 100000 2>/dev/null \
          | jq 'length' 2>/dev/null)
        INBOX_ONDISK="''${INBOX_ONDISK:-?}"
        INBOX_INDEXED=$(notmuch search --output=files \
            "path:$ACCOUNT_FOLDER/cur or path:$ACCOUNT_FOLDER/new" 2>/dev/null \
          | grep -cE "/$ACCOUNT_FOLDER/(cur|new)/" || true)
        # (b) bounded tolerance instead of strict equality: on-disk (himalaya envelope count) and
        # indexed (notmuch file count) drift transiently between an mbsync pull and 'email-reindex',
        # so gate on a bounded divergence rather than an exact match to keep [ok] reachable. Tolerance
        # is max(5, ceil(10% * on-disk)); the reindex= field below is the secondary staleness signal.
        if printf '%s' "$INBOX_ONDISK" | grep -qE '^[0-9]+$'; then
          DIVERGENCE=$(( INBOX_ONDISK - INBOX_INDEXED ))
          AD=''${DIVERGENCE#-}                              # absolute value
          PCT_TOL=$(( (INBOX_ONDISK * 10 + 99) / 100 ))     # ceil(10% * on-disk)
          TOL=$(( PCT_TOL > 5 ? PCT_TOL : 5 ))              # floor of 5
          if [ "$AD" -le "$TOL" ]; then FRESH="ok"; else FRESH="STALE"; fi
        else
          DIVERGENCE="?"; TOL="?"; FRESH="STALE"
        fi
        # (c) reindex-run marker (informational secondary signal).
        REINDEX_MARKER="''${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex"
        if [ -r "$REINDEX_MARKER" ]; then REINDEX_AT=$(cat "$REINDEX_MARKER" 2>/dev/null); else REINDEX_AT="never"; fi
        printf "%-16s on-disk=%s  indexed-files=%s  divergence=%s  tol=%s  reindex=%s  [%s]\n" \
          "INBOX freshness" "$INBOX_ONDISK" "$INBOX_INDEXED" "$DIVERGENCE" "$TOL" "$REINDEX_AT" "$FRESH"
        echo ""
        echo "--- Sender census: top 25 by message count ---"
        echo "(verified invocation: notmuch address --output=sender --output=count --deduplicate=address -- '*')"
        notmuch address --output=sender --output=count --deduplicate=address -- '*' 2>/dev/null \
          | sort -rn | head -25 || true
        echo ""
        echo "--- Date bucket counts (INBOX, by year) ---"
        CUR_YEAR=$(date +%Y)
        for y in $(seq $((CUR_YEAR - 4)) "$CUR_YEAR"); do
          n=$(notmuch count "folder:$ACCOUNT_FOLDER and date:$y-01-01..$y-12-31" 2>/dev/null || echo 0)
          printf "%-10s %s\n" "$y" "$n"
        done
        echo ""
        echo "--- himalaya envelope sample (INBOX, up to 10, via 'envelope list -o json') ---"
        echo "(verified: 'himalaya message list' does NOT exist in v1.2.0 — envelope list only)"
        himalaya envelope list "''${HIMALAYA_ACCT[@]}" -f INBOX -o json -s 10 2>/dev/null \
          | jq -c '.[] | {id, subject, from: .from.addr, date}' 2>/dev/null \
          || echo "(himalaya envelope list unavailable — is the $ACCOUNT account configured?)"
      ''
    ))
  ];
}
