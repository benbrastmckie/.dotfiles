# Part of the task-88 split of the former monolithic email/agent-tools.nix; see lib.nix in
# this directory for the full contract provenance and shared helpers (wrapper-contract.md).
#
# =======================================================================================
# email-classify (local-tags-only) — deterministic rule scaffold + candidate manifest +
# --append-approved (the sole allowlisted target for the Phase 9 aerc confirm gesture)
# =======================================================================================
{ pkgs, ... }:
let
  inherit (import ./lib.nix) mkPreamble lower;
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "email-classify" (mkPreamble {
      name = "email-classify";
      verb = "apply provisional +proposed-* tags; emit candidate manifest; --append-approved";
      safetyClass = "local-tags-only";
      extraHelp = ''
        Classify flags:
          [QUERY]                 notmuch query to classify (default: "folder:<Account>" = INBOX)
          --limit <N>              Cap messages processed this run (default: MAX_BATCH_SIZE=50)
          --append-approved <mid>  Append ONE already-confirmed Message-ID to the APPROVED
                                    manifest (reads its tag:confirmed-{delete,archive}; the
                                    sole target the aerc confirm gesture is allowed to exec)

        This binary NEVER touches maildir/IMAP state — notmuch tags and manifest files only.
      '';
    } + ''
      APPEND_APPROVED=""
      QUERY="folder:$ACCOUNT_FOLDER"
      LIMIT="$MAX_BATCH_SIZE"
      CLS_ARGS=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --append-approved) APPEND_APPROVED="''${2:-}"; shift 2 ;;
          --append-approved=*) APPEND_APPROVED="''${1#--append-approved=}"; shift ;;
          --limit) LIMIT="''${2:-}"; shift 2 ;;
          --limit=*) LIMIT="''${1#--limit=}"; shift ;;
          *) CLS_ARGS+=("$1"); shift ;;
        esac
      done
      set -- "''${CLS_ARGS[@]}"
      if [ "$#" -gt 0 ]; then
        QUERY="$*"
      fi

      APPROVED_FILE="$MANIFEST_DIR/approved-manifest.jsonl"
      CANDIDATE_FILE="$MANIFEST_DIR/candidate-manifest.jsonl"

      # --- Approval-provenance mode (contract §6): append ONE confirmed Message-ID ---------
      if [ -n "$APPEND_APPROVED" ]; then
        json=$(notmuch show --format=json --body=false "id:$APPEND_APPROVED" 2>/dev/null \
          | jq -c 'if (.[0][0][0] | type) == "object" then .[0][0][0] else empty end' 2>/dev/null || true)
        if [ -z "$json" ]; then
          log "ERROR: no message found for id:$APPEND_APPROVED"
          exit 1
        fi
        tags=$(echo "$json" | jq -r '(.tags // []) | join(",")')
        subject=$(echo "$json" | jq -r '.headers.Subject // ""')
        from=$(echo "$json" | jq -r '.headers.From // ""')
        date=$(echo "$json" | jq -r '.headers.Date // ""')
        case ",$tags," in
          *,confirmed-delete,*) action="delete" ;;
          *,confirmed-archive,*) action="archive" ;;
          *)
            log "ERROR: id:$APPEND_APPROVED has no confirmed-{delete,archive} tag (tags: $tags)"
            log "The aerc confirm gesture must retag +confirmed-{delete,archive} before calling"
            log "--append-approved (wrapper-contract.md §6)."
            exit 1
            ;;
        esac
        jq -nc --arg mid "$APPEND_APPROVED" --arg sender "$from" --arg subject "$subject" \
          --arg date "$date" --arg action "$action" \
          '{message_id:$mid, sender:$sender, subject:$subject, date:$date, proposed_action:$action, reason:"aerc-confirmed", confidence:1.0}' \
          >> "$APPROVED_FILE"
        log "Appended $APPEND_APPROVED ($action, confidence 1.0) to $APPROVED_FILE"
        exit 0
      fi

      # --- Candidate classification mode ---------------------------------------------------
      # Tier 1: harvested hand-tuned rules (handoffs/email-preferences.md §1.5), confidence 0.98.
      CUSTOM_DELETE_DOMAINS=(
        "amazon.com" "voltagesupply.com" "protonmail.com" "zidedoor.com" "spotify.com"
        "sportsmans.com" "aveneusa" "lokvani.com" "espressoparts.com" "proton.me"
        "coinbase.com" "mithas.org" "reviews.io" "ambrosia.church"
      )
      CUSTOM_KEEP_SENDERS=(
        "onanyajoni@gmail.com"
        "noae@protonmail.com" "rob.mckie1235@proton.me" "andy.stace@protonmail.com"
      )

      # Tier 2: keyword-fallback ONLY (email-preferences.md §1.4). Header-based signals
      # (List-Unsubscribe, Precedence: bulk, reply-history, VIP allowlist) are the PRIMARY
      # tier and are #803's gap to fill (email-preferences.md §2) — these substrings are the
      # last resort, kept deliberately low-confidence.
      NEWSLETTER_KEYWORDS=(
        "newsletter" "digest" "weekly" "daily" "updates" "noreply" "no-reply" "donotreply"
        "notification" "news@" "info@" "marketing@" "promo"
      )
      NOTIFICATION_DOMAINS=(
        "github.com" "gitlab.com" "bitbucket.org" "linkedin.com" "twitter.com" "x.com"
        "slack.com" "discord.com" "trello.com" "jira" "atlassian" "asana.com" "circleci.com"
        "travis-ci.com"
      )

      classify_one() {
        local sender_lc="$1" d kw
        for d in "''${CUSTOM_KEEP_SENDERS[@]}"; do
          case "$sender_lc" in *"$d"*) echo "keep|0.98|custom-sender-keep:$d"; return ;; esac
        done
        for d in "''${CUSTOM_DELETE_DOMAINS[@]}"; do
          case "$sender_lc" in *"$d"*) echo "delete|0.98|custom-domain-delete:$d"; return ;; esac
        done
        for kw in "''${NEWSLETTER_KEYWORDS[@]}"; do
          case "$sender_lc" in *"$kw"*) echo "archive|0.60|keyword-fallback:newsletter:$kw"; return ;; esac
        done
        for d in "''${NOTIFICATION_DOMAINS[@]}"; do
          case "$sender_lc" in *"$d"*) echo "archive|0.55|keyword-fallback:notification-domain:$d"; return ;; esac
        done
        echo "unsure|0.50|default-unsure"
      }

      total=$(notmuch search --output=messages "$QUERY" 2>/dev/null | grep -c . || true)
      mids=$(notmuch search --output=messages "$QUERY" 2>/dev/null | sed 's/^id://' | head -n "$LIMIT" || true)
      if [ "$total" -gt "$LIMIT" ]; then
        log "NOTE: query matched $total message(s); processing the first $LIMIT (MAX_BATCH_SIZE=$MAX_BATCH_SIZE)."
        log "Re-run with a narrower QUERY or --limit to cover the remainder."
      fi

      : > "$CANDIDATE_FILE.tmp"
      n=0
      while IFS= read -r mid; do
        [ -z "$mid" ] && continue
        json=$(notmuch show --format=json --body=false "id:$mid" 2>/dev/null \
          | jq -c 'if (.[0][0][0] | type) == "object" then .[0][0][0] else empty end' 2>/dev/null || true)
        [ -z "$json" ] && continue
        subject=$(echo "$json" | jq -r '.headers.Subject // ""')
        from=$(echo "$json" | jq -r '.headers.From // ""')
        date=$(echo "$json" | jq -r '.headers.Date // ""')
        sender_lc=$(printf '%s' "$from" | ${lower})
        result=$(classify_one "$sender_lc")
        action="''${result%%|*}"
        rest="''${result#*|}"
        confidence="''${rest%%|*}"
        reason="''${rest#*|}"

        # Confidence correction (contract §5, tightened per email-preferences.md §1.3):
        # delete proposals require >= 0.90; below that, downgrade to unsure.
        if [ "$action" = "delete" ]; then
          below=$(awk -v c="$confidence" 'BEGIN{print (c < 0.90) ? 1 : 0}')
          if [ "$below" -eq 1 ]; then
            action="unsure"
            reason="''${reason};downgraded-below-0.90-delete-threshold"
          fi
        fi

        jq -nc --arg mid "$mid" --arg sender "$from" --arg subject "$subject" --arg date "$date" \
          --arg action "$action" --arg reason "$reason" --argjson confidence "$confidence" \
          '{message_id:$mid, sender:$sender, subject:$subject, date:$date, proposed_action:$action, reason:$reason, confidence:$confidence}' \
          >> "$CANDIDATE_FILE.tmp"

        notmuch tag -proposed-delete -proposed-archive -proposed-unsure -proposed-keep \
          "+proposed-$action" -- "id:$mid" 2>/dev/null || true
        n=$((n + 1))
      done <<< "$mids"

      mv "$CANDIDATE_FILE.tmp" "$CANDIDATE_FILE"
      log "Classified $n message(s); candidate manifest: $CANDIDATE_FILE"
      log "Candidates are NOT approved — mutation wrappers never consume $CANDIDATE_FILE (contract §6)."
    ''))
  ];
}
