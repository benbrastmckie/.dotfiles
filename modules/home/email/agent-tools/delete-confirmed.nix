# Part of the task-88 split of the former monolithic email/agent-tools.nix; see lib.nix in
# this directory for the full contract provenance and shared helpers (wrapper-contract.md).
#
# =======================================================================================
# email-delete-confirmed (mutation) — two-hop delete (move-to-Trash, then --expunge-trash)
# =======================================================================================
{ pkgs, ... }:
let
  inherit (import ./lib.nix) mkMutationPreamble;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "email-delete-confirmed" (
      mkMutationPreamble {
        name = "email-delete-confirmed";
        verb = "move approved-delete Message-IDs to Trash; --expunge-trash permanently removes";
        extraHelp = ''
          Mutation flags:
            --execute                    Perform the mutation (default: dry-run plan only)
            --confirm-manifest <sha256>  Required with --execute; sha256 of the approved manifest
            --manifest <path>            Approved manifest file
                                          (default: <manifest-dir>/approved-manifest.jsonl)
            --expunge-trash               Run the SECOND hop instead of the first: flag
                                          already-trashed approved-delete IDs \Deleted
                                          (verification-baseline.md §6 finding: plain expunge is
                                          a no-op on an un-flagged message) then
                                          'himalaya folder expunge Trash'. Also requires
                                          --execute --confirm-manifest. Move and expunge are
                                          independently human-gated (each needs its own
                                          --execute --confirm-manifest invocation); tracked in
                                          separate state files.
        '';
      }
      + ''
        EXPUNGE_TRASH=0
        DEL_ARGS=()
        for a in "$@"; do
          if [ "$a" = "--expunge-trash" ]; then
            EXPUNGE_TRASH=1
          else
            DEL_ARGS+=("$a")
          fi
        done
        set -- "''${DEL_ARGS[@]}"

        if [ "$EXPUNGE_TRASH" -eq 1 ]; then
          # Second hop gets its own companion state file: hop 1 ("executed" = moved to Trash)
          # and hop 2 ("executed" = \Deleted-flagged + expunged) are tracked independently so
          # each --execute --confirm-manifest invocation is idempotent on its own hop.
          TRASH_STATE_FILE="$STATE_FILE"
          STATE_FILE="''${MANIFEST_FILE}.expunge-state.jsonl"
          [ -f "$STATE_FILE" ] || : > "$STATE_FILE"
        fi

        enforce_batch_size "delete"
        ids=$(pending_ids_for_action "delete")
        if [ -z "$ids" ]; then
          log "No approved 'delete' IDs in $MANIFEST_FILE"
          exit 0
        fi

        executed_any=0

        if [ "$EXPUNGE_TRASH" -eq 0 ]; then
          # Hop 1: move to Trash (himalaya soft-delete; leaves flags :2,S, NOT \Deleted).
          while IFS= read -r mid; do
            [ -z "$mid" ] && continue
            status=$(state_status_for "$mid")
            if [ "$status" = "executed" ]; then
              log "SKIP (already moved to Trash): $mid"
              continue
            fi
            if ! resolve_envelope_id "$mid"; then
              [ "$EXECUTE" -eq 1 ] && state_set "$mid" "failed" "envelope id resolution failed"
              continue
            fi
            if [ "$EXECUTE" -eq 0 ]; then
              log "PLAN: move-to-Trash $mid (envelope $RESOLVED_ENVELOPE_ID in $RESOLVED_FOLDER)"
              continue
            fi
            log "EXECUTE: moving $mid (envelope $RESOLVED_ENVELOPE_ID in $RESOLVED_FOLDER) -> Trash"
            if himalaya message delete "''${HIMALAYA_ACCT[@]}" "$RESOLVED_ENVELOPE_ID" -f "$RESOLVED_FOLDER" >&2; then
              state_set "$mid" "executed"
              executed_any=1
            else
              state_set "$mid" "failed" "himalaya message delete (hop 1: move-to-Trash) failed"
            fi
          done <<< "$ids"
        else
          # Hop 2: only for IDs whose hop-1 state (TRASH_STATE_FILE) is "executed" (already in
          # Trash). Set \Deleted for each (message delete --folder Trash), THEN expunge once.
          any_flagged=0
          while IFS= read -r mid; do
            [ -z "$mid" ] && continue
            hop1_status=$(state_status_for "$mid" "$TRASH_STATE_FILE")
            if [ "$hop1_status" != "executed" ]; then
              log "SKIP (not yet moved to Trash — run without --expunge-trash first): $mid"
              continue
            fi
            hop2_status=$(state_status_for "$mid")
            if [ "$hop2_status" = "executed" ]; then
              log "SKIP (already expunged): $mid"
              continue
            fi
            if ! resolve_envelope_id "$mid"; then
              [ "$EXECUTE" -eq 1 ] && state_set "$mid" "failed" "envelope id resolution (Trash) failed"
              continue
            fi
            if [ "$EXECUTE" -eq 0 ]; then
              log "PLAN: flag \\Deleted $mid (envelope $RESOLVED_ENVELOPE_ID in Trash), then expunge Trash"
              continue
            fi
            log "EXECUTE: flagging \\Deleted $mid (envelope $RESOLVED_ENVELOPE_ID in Trash)"
            if himalaya message delete "''${HIMALAYA_ACCT[@]}" "$RESOLVED_ENVELOPE_ID" -f Trash >&2; then
              state_set "$mid" "executed"
              executed_any=1
              any_flagged=1
            else
              state_set "$mid" "failed" "himalaya message delete (hop 2: flag Deleted) failed"
            fi
          done <<< "$ids"

          if [ "$EXECUTE" -eq 1 ] && [ "$any_flagged" -eq 1 ]; then
            log "EXECUTE: himalaya folder expunge Trash"
            himalaya folder expunge "''${HIMALAYA_ACCT[@]}" Trash >&2
          fi
        fi

        if [ "$EXECUTE" -eq 1 ] && [ "$executed_any" -eq 1 ]; then
          run_mbsync_reconcile || exit 1
        fi
      ''
    ))
  ];
}
