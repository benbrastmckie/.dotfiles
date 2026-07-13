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
        # (a2) INBOX-scoped literal-filename set-diff, UID-joined: renamed/removed/added. This is
        # the authoritative rename/deletion-aware signal, distinct from the file-COUNT check
        # above: a same-count divergence (e.g. a maildir flag-rename, which changes a filename but
        # not the total file count) is structurally invisible to (a)/(b) but visible here.
        # Reuses the SAME query form as INBOX_INDEXED above (notmuch search --output=files
        # "path:...", never count/tag:) to avoid reintroducing the search.exclude_tags
        # false-positive trap (wrapper-contracts.md §13) -- do NOT "simplify" this to a
        # tag:-based or notmuch-count-based query.
        INDEXED_FILES=$(notmuch search --output=files \
            "path:$ACCOUNT_FOLDER/cur or path:$ACCOUNT_FOLDER/new" 2>/dev/null \
          | grep -E "/$ACCOUNT_FOLDER/(cur|new)/" || true)
        # himalaya's JSON envelope output does not expose literal maildir filenames, so a
        # -maxdepth 1-scoped find over exactly cur/new is used instead (INBOX is, by definition,
        # exactly those two dirs at the account maildir root, so this is not the untrustworthy
        # whole-account find count staleness-detection.md warns about).
        ONDISK_FILES=$(find "$HOME/Mail/$ACCOUNT_FOLDER/cur" "$HOME/Mail/$ACCOUNT_FOLDER/new" \
            -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true)
        ONDISK_FILE_COUNT=$(printf '%s\n' "$ONDISK_FILES" | grep -c . || true)
        # Guard: only trust the filename-level join if find's file count agrees with the
        # already-computed himalaya on-disk count; otherwise degrade safely to "?" (matching the
        # existing DIVERGENCE/TOL parse-failure convention) rather than trust a possibly-wrong
        # filename source.
        if printf '%s' "$INBOX_ONDISK" | grep -qE '^[0-9]+$' \
            && [ "$ONDISK_FILE_COUNT" = "$INBOX_ONDISK" ]; then
          SETDIFF=$(awk '
            FNR == NR {
              if ($0 == "") next
              base = $0; sub(/.*\//, "", base)
              if (match(base, /,U=[0-9]+:/)) {
                uid = substr(base, RSTART + 3, RLENGTH - 4)
                indexed[uid] = base
              }
              next
            }
            {
              if ($0 == "") next
              if (match($0, /,U=[0-9]+:/)) {
                uid = substr($0, RSTART + 3, RLENGTH - 4)
                ondisk[uid] = $0
              }
            }
            END {
              renamed = 0; removed = 0; added = 0
              for (u in indexed) {
                if (u in ondisk) { if (indexed[u] != ondisk[u]) renamed++ } else { removed++ }
              }
              for (u in ondisk) { if (!(u in indexed)) added++ }
              printf "%d %d %d", renamed, removed, added
            }
          ' <(printf '%s\n' "$INDEXED_FILES") <(printf '%s\n' "$ONDISK_FILES"))
          RENAMED=$(printf '%s' "$SETDIFF" | awk '{print $1}')
          REMOVED=$(printf '%s' "$SETDIFF" | awk '{print $2}')
          ADDED=$(printf '%s' "$SETDIFF" | awk '{print $3}')
        else
          RENAMED="?"; REMOVED="?"; ADDED="?"
        fi
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
        # (b2) exact-set check (authoritative, verdict-affecting on its own): flip to STALE if the
        # UID-joined set-diff above found ANY rename/removal/addition, or if it fell back to "?"
        # (parse-failure convention) -- this is what closes the false-green gap, since (b) alone
        # can read divergence=0 while renamed/removed/added are nonzero (staleness-detection.md).
        # SETDIFF_TOL=0: back-to-back live runs with no intervening mail activity were stable at
        # renamed=0 removed=0 added=0, so no slack is granted for in-flight-write jitter.
        SETDIFF_TOL=0
        if printf '%s' "$RENAMED" | grep -qE '^[0-9]+$' \
            && printf '%s' "$REMOVED" | grep -qE '^[0-9]+$' \
            && printf '%s' "$ADDED" | grep -qE '^[0-9]+$'; then
          SETDIFF_TOTAL=$(( RENAMED + REMOVED + ADDED ))
          if [ "$SETDIFF_TOTAL" -gt "$SETDIFF_TOL" ]; then FRESH="STALE"; fi
        else
          FRESH="STALE"
        fi
        # (c) reindex-run marker (informational secondary signal).
        REINDEX_MARKER="''${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex"
        if [ -r "$REINDEX_MARKER" ]; then REINDEX_AT=$(cat "$REINDEX_MARKER" 2>/dev/null); else REINDEX_AT="never"; fi
        printf "%-16s on-disk=%s  indexed-files=%s  divergence=%s  tol=%s  reindex=%s  renamed=%s  removed=%s  added=%s  [%s]\n" \
          "INBOX freshness" "$INBOX_ONDISK" "$INBOX_INDEXED" "$DIVERGENCE" "$TOL" "$REINDEX_AT" \
          "$RENAMED" "$REMOVED" "$ADDED" "$FRESH"
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
