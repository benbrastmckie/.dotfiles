# Part of the task-88 split of the former monolithic email/agent-tools.nix; see lib.nix in
# this directory for the full contract provenance and shared helpers (wrapper-contract.md).
#
# =======================================================================================
# email-archive-confirmed (mutation) — move approved 'archive' IDs to the account's archive
# folder (ACCOUNT_ARCHIVE_FOLDER: All_Mail for gmail, Archive for logos)
# =======================================================================================
{ pkgs, ... }:
let
  inherit (import ./lib.nix) mkMutationPreamble;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "email-archive-confirmed" (mkMutationPreamble {
      name = "email-archive-confirmed";
      verb = "move approved-archive Message-IDs to All Mail";
      extraHelp = ''
        Mutation flags:
          --execute                    Perform the mutation (default: dry-run plan only)
          --confirm-manifest <sha256>  Required with --execute; sha256 of the approved manifest
          --manifest <path>            Approved manifest file
                                        (default: <manifest-dir>/approved-manifest.jsonl)
      '';
    } + ''
      enforce_batch_size "archive"
      ids=$(pending_ids_for_action "archive")
      if [ -z "$ids" ]; then
        log "No approved 'archive' IDs in $MANIFEST_FILE"
        exit 0
      fi

      executed_any=0
      while IFS= read -r mid; do
        [ -z "$mid" ] && continue
        status=$(state_status_for "$mid")
        if [ "$status" = "executed" ]; then
          log "SKIP (already executed): $mid"
          continue
        fi
        if ! resolve_envelope_id "$mid"; then
          [ "$EXECUTE" -eq 1 ] && state_set "$mid" "failed" "envelope id resolution failed"
          continue
        fi
        if [ "$EXECUTE" -eq 0 ]; then
          log "PLAN: move $mid (envelope $RESOLVED_ENVELOPE_ID in $RESOLVED_FOLDER) -> $ACCOUNT_ARCHIVE_FOLDER"
          continue
        fi
        log "EXECUTE: moving $mid (envelope $RESOLVED_ENVELOPE_ID in $RESOLVED_FOLDER) -> $ACCOUNT_ARCHIVE_FOLDER"
        if himalaya message move "''${HIMALAYA_ACCT[@]}" "$ACCOUNT_ARCHIVE_FOLDER" "$RESOLVED_ENVELOPE_ID" -f "$RESOLVED_FOLDER" >&2; then
          state_set "$mid" "executed"
          executed_any=1
        else
          state_set "$mid" "failed" "himalaya message move failed"
        fi
      done <<< "$ids"

      if [ "$EXECUTE" -eq 1 ] && [ "$executed_any" -eq 1 ]; then
        run_mbsync_reconcile || exit 1
      fi
    ''))
  ];
}
