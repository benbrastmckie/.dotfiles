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
    (pkgs.writeShellScriptBin "email-census" (mkPreamble {
      name = "email-census";
      verb = "report sender/folder/date census (read-only)";
      safetyClass = "read-only";
    } + ''
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
    ''))
  ];
}
