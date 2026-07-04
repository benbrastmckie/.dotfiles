# Task 72 (Phases 5-6): five nix-declared, dry-run-by-default agent wrapper binaries
# implementing the FROZEN interface at
# specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md.
#
# Design constraint (contract §8, two-layer enforcement): each binary's preamble is
# INTERPOLATED into the script (never `source`d from an external file), so every produced
# binary is fully self-contained. The Phase 7 PreToolUse `mail-guard.sh` hook allowlists by
# binary NAME only — a binary that depended on a separately-writable sourced file would be an
# unguarded escape hatch around that allowlist.
#
# Verified against the live system (Phase 1: handoffs/verification-baseline.md) and this
# implementation's own live read-only probes: `himalaya envelope list -o json` schema,
# `himalaya message read -p -H Message-Id` (preview mode — never marks Seen), maildir++
# folder-name mapping (`.All_Mail` -> `All_Mail`, root -> `INBOX`), and the two-hop delete
# path (`message delete` twice: once to move to Trash, once inside Trash to set `\Deleted`,
# then `folder expunge Trash`).
{ pkgs, ... }:
let
  manifestDirDefault = "specs/072_email_workflow_infrastructure_prereqs/manifests";

  # ---------------------------------------------------------------------------------------
  # Shared preamble (contract §2): global flags, `--account gmail` reservation, manifest-dir
  # resolution, logging. Interpolated into ALL five binaries.
  # ---------------------------------------------------------------------------------------
  mkPreamble = { name, verb, safetyClass, extraHelp ? "" }: ''
    set -euo pipefail

    BINARY_NAME="${name}"
    VERB="${verb}"
    SAFETY_CLASS="${safetyClass}"

    # Contract §5 constants (harvested from prior art, email_execute.py:26-27; see
    # handoffs/email-preferences.md §1.1).
    MAX_BATCH_SIZE=50
    PLAN_EXPIRY_DAYS=7

    ACCOUNT="gmail"
    MANIFEST_DIR="''${EMAIL_MANIFEST_DIR:-${manifestDirDefault}}"

    log() { echo "[$BINARY_NAME] $*" >&2; }

    print_help() {
      cat <<HELPEOF
$BINARY_NAME - $VERB
Safety class: $SAFETY_CLASS

Global flags (wrapper-contract.md §2):
  --account <gmail|logos> Account to operate on (default: gmail)
  --manifest-dir <path>   Override manifest storage (default: \$EMAIL_MANIFEST_DIR, else
                           ${manifestDirDefault}/ relative to the current working directory —
                           normally the .dotfiles repo root)
  --help                  Show this help
${extraHelp}
HELPEOF
    }

    ARGS=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --account) ACCOUNT="''${2:-}"; shift 2 ;;
        --account=*) ACCOUNT="''${1#--account=}"; shift ;;
        --manifest-dir) MANIFEST_DIR="''${2:-}"; shift 2 ;;
        --manifest-dir=*) MANIFEST_DIR="''${1#--manifest-dir=}"; shift ;;
        --help|-h) print_help; exit 0 ;;
        *) ARGS+=("$1"); shift ;;
      esac
    done
    set -- "''${ARGS[@]}"

    case "$ACCOUNT" in
      gmail)
        ACCOUNT_FOLDER="Gmail"
        ACCOUNT_MAILDIR_MARKER="/Mail/Gmail/"
        ACCOUNT_MBSYNC_GROUP="gmail"
        ACCOUNT_ARCHIVE_FOLDER="All_Mail"
        ;;
      logos)
        ACCOUNT_FOLDER="Logos"
        ACCOUNT_MAILDIR_MARKER="/Mail/Logos/"
        ACCOUNT_MBSYNC_GROUP="logos"
        ACCOUNT_ARCHIVE_FOLDER="Archive"
        ;;
      *)
        log "ERROR: --account only accepts 'gmail' or 'logos' (got: '$ACCOUNT')"
        log "See wrapper-contract.md for the supported account set."
        exit 1
        ;;
    esac
    HIMALAYA_ACCT=(-a "$ACCOUNT")

    mkdir -p "$MANIFEST_DIR"
  '';

  # ---------------------------------------------------------------------------------------
  # Mutation preamble (contract §2, §4, §5, §7). Extends mkPreamble with: dry-run-by-default
  # gating, `--execute --confirm-manifest <sha256>` verification, staleness/batch checks, the
  # `<manifest>.state.jsonl` companion, Message-ID -> envelope-id resolution, and the mbsync
  # auth-failure fail-safe. Interpolated into the two mutation binaries only.
  # ---------------------------------------------------------------------------------------
  mkMutationPreamble = { name, verb, extraHelp ? "" }:
    (mkPreamble {
      inherit name verb extraHelp;
      safetyClass = "mutation";
    }) + ''
      # --- mutation gate (contract §2, §4, §5) -------------------------------------------
      EXECUTE=0
      CONFIRM_HASH=""
      MANIFEST_FILE=""

      MUT_ARGS=()
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --execute) EXECUTE=1; shift ;;
          --confirm-manifest) CONFIRM_HASH="''${2:-}"; shift 2 ;;
          --confirm-manifest=*) CONFIRM_HASH="''${1#--confirm-manifest=}"; shift ;;
          --manifest) MANIFEST_FILE="''${2:-}"; shift 2 ;;
          --manifest=*) MANIFEST_FILE="''${1#--manifest=}"; shift ;;
          *) MUT_ARGS+=("$1"); shift ;;
        esac
      done
      set -- "''${MUT_ARGS[@]}"

      if [ -z "$MANIFEST_FILE" ]; then
        MANIFEST_FILE="$MANIFEST_DIR/approved-manifest.jsonl"
      fi
      STATE_FILE="''${MANIFEST_FILE}.state.jsonl"

      if [ "$EXECUTE" -eq 1 ] && [ -z "$CONFIRM_HASH" ]; then
        log "ERROR: --execute requires --confirm-manifest <sha256> (positive flag; never --no-dry-run)"
        exit 1
      fi

      if [ ! -f "$MANIFEST_FILE" ]; then
        log "ERROR: approved manifest not found: $MANIFEST_FILE"
        log "Mutation wrappers consume ONLY approved manifests written via the aerc review"
        log "gesture + 'email-classify --append-approved' (contract §6) — never candidate output."
        exit 1
      fi

      ACTUAL_HASH=$(sha256sum "$MANIFEST_FILE" | awk '{print $1}')

      if [ "$EXECUTE" -eq 1 ]; then
        if [ "$ACTUAL_HASH" != "$CONFIRM_HASH" ]; then
          log "ERROR: --confirm-manifest hash mismatch — refusing to mutate"
          log "  expected (yours): $CONFIRM_HASH"
          log "  actual (file):    $ACTUAL_HASH"
          exit 1
        fi

        MTIME=$(stat -c %Y "$MANIFEST_FILE")
        NOW=$(date +%s)
        AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
        if [ "$AGE_DAYS" -gt "$PLAN_EXPIRY_DAYS" ]; then
          log "ERROR: manifest is $AGE_DAYS day(s) old (limit PLAN_EXPIRY_DAYS=$PLAN_EXPIRY_DAYS) — refusing to mutate"
          log "Re-approve via the aerc review flow to refresh the manifest."
          exit 1
        fi
        log "Manifest hash verified ($ACTUAL_HASH); age $AGE_DAYS day(s) — proceeding with EXECUTE."
      else
        log "DRY-RUN (pass --execute --confirm-manifest $ACTUAL_HASH to mutate)"
      fi

      [ -f "$STATE_FILE" ] || : > "$STATE_FILE"

      # state_status_for <message-id> [state-file] -> last known status, or empty
      state_status_for() {
        local mid="$1" sf="''${2:-$STATE_FILE}"
        jq -r --arg mid "$mid" 'select(.message_id == $mid) | .status' "$sf" 2>/dev/null | tail -n1
      }

      # state_set <message-id> <status> [error] [state-file] -- append-only log, last line wins
      state_set() {
        local mid="$1" status="$2" error="''${3:-}" sf="''${4:-$STATE_FILE}"
        if [ -z "$error" ]; then
          jq -nc --arg mid "$mid" --arg status "$status" --arg ts "$(date -Iseconds)" \
            '{message_id:$mid, status:$status, timestamp:$ts, error:null}' >> "$sf"
        else
          jq -nc --arg mid "$mid" --arg status "$status" --arg ts "$(date -Iseconds)" --arg err "$error" \
            '{message_id:$mid, status:$status, timestamp:$ts, error:$err}' >> "$sf"
        fi
      }

      # --- Message-ID -> current envelope-id resolution (contract §3) --------------------
      # Envelope ids are per-folder and change on move; NEVER persisted as keys. Resolution:
      # notmuch id: lookup -> file path -> folder name, then a subject-narrowed
      # `himalaya envelope list` query, verified against the raw Message-Id header read in
      # preview mode (-p; never marks the message Seen as a side effect of resolution).
      resolve_folder_from_path() {
        local filepath="$1"
        local rel="''${filepath#*/Mail/Gmail/}"
        local dir="''${rel%%/*}"
        case "$dir" in
          cur|new|tmp) echo "INBOX" ;;
          .*) echo "''${dir#.}" ;;
          *) echo "$dir" ;;
        esac
      }

      resolve_envelope_id() {
        local message_id="$1"
        RESOLVED_ENVELOPE_ID=""
        RESOLVED_FOLDER=""
        local filepath folder subject subject_word candidates eid raw_mid

        filepath=$(notmuch search --output=files "id:$message_id" 2>/dev/null | head -n1 || true)
        if [ -z "$filepath" ]; then
          log "ERROR: notmuch has no file for id:$message_id (index stale? run notmuch new)"
          return 1
        fi
        folder=$(resolve_folder_from_path "$filepath")
        subject=$(notmuch show --format=json --body=false "id:$message_id" 2>/dev/null \
          | jq -r 'if (.[0][0][0] | type) == "object" then (.[0][0][0].headers.Subject // empty) else empty end' 2>/dev/null || true)
        # Prefer the LONGEST alnum token (>= 4 chars) as the narrowing filter — more
        # distinctive than the first word (subjects often start with a common greeting).
        subject_word=$(printf '%s' "$subject" | grep -oE '[[:alnum:]]{4,}' \
          | awk '{ print length, $0 }' | sort -rn | head -n1 | cut -d' ' -f2- || true)

        if [ -n "$subject_word" ]; then
          candidates=$(himalaya envelope list -f "$folder" -o json -s 5000 "subject $subject_word" 2>/dev/null \
            | jq -r '.[].id' 2>/dev/null || true)
        else
          candidates=$(himalaya envelope list -f "$folder" -o json -s 5000 2>/dev/null \
            | jq -r '.[].id' 2>/dev/null || true)
        fi

        for eid in $candidates; do
          raw_mid=$(himalaya message read "$eid" -f "$folder" -p -H Message-Id 2>/dev/null \
            | grep -im1 '^Message-Id:' \
            | sed -E 's/^[Mm]essage-[Ii]d:[[:space:]]*<?//; s/>?[[:space:]]*$//')
          if [ "$raw_mid" = "$message_id" ]; then
            RESOLVED_ENVELOPE_ID="$eid"
            RESOLVED_FOLDER="$folder"
            return 0
          fi
        done
        log "ERROR: could not resolve envelope id for $message_id in folder $folder"
        return 1
      }

      # pending_ids_for_action <action> [manifest-file] -- Message-IDs with proposed_action == $1
      pending_ids_for_action() {
        local action="$1" mf="''${2:-$MANIFEST_FILE}"
        jq -r --arg action "$action" 'select(.proposed_action == $action) | .message_id' "$mf"
      }

      count_ids_for_action() {
        pending_ids_for_action "$1" "''${2:-$MANIFEST_FILE}" | grep -c . || true
      }

      # enforce_batch_size <action> -- refuse (never partial-process) over MAX_BATCH_SIZE
      enforce_batch_size() {
        local action="$1" count
        count=$(count_ids_for_action "$action")
        if [ "$count" -gt "$MAX_BATCH_SIZE" ]; then
          log "ERROR: $count '$action' ID(s) in manifest exceeds MAX_BATCH_SIZE=$MAX_BATCH_SIZE — split required"
          exit 1
        fi
      }

      # --- mbsync auth-failure fail-safe (contract §7, oauth-gate.md §4) -----------------
      # Sole detection point: the `mbsync gmail` reconcile step. Matches BOTH the legacy
      # XOAUTH2 failure and the app-password failure so the fail-safe survives either auth
      # model. Himalaya wrapper calls (local maildir, app-password) never check for this.
      is_mbsync_auth_failure() {
        printf '%s' "$1" | grep -qE 'invalid_grant|\[AUTHENTICATIONFAILED\] Invalid credentials'
      }

      run_mbsync_reconcile() {
        log ""
        log "Reconciling with 'mbsync gmail' (group-scoped; NEVER mbsync -a — that would also"
        log "touch the deferred Logos/Bridge account)..."
        local out status
        set +e
        out=$(mbsync gmail 2>&1)
        status=$?
        set -e
        echo "$out" >&2
        if [ "$status" -ne 0 ]; then
          if is_mbsync_auth_failure "$out"; then
            log "AUTH FAILURE detected (invalid_grant or [AUTHENTICATIONFAILED])."
            log "Halting before further mutation. The approved manifest ($MANIFEST_FILE) and"
            log "state file ($STATE_FILE) are preserved untouched by this failure."
            log "Resume: fix auth, re-run 'mbsync gmail' manually, then re-run this wrapper with"
            log "--execute --confirm-manifest $ACTUAL_HASH (already-executed IDs are skipped)."
          else
            log "mbsync gmail exited non-zero for a reason OTHER than an auth failure (exit $status)."
            log "This may be the known gmail-spam NONEXISTENT-mailbox issue (task-46/mbsync scope;"
            log "see handoffs/verification-baseline.md §6a) — inspect the output above."
          fi
          return 1
        fi
        log "mbsync gmail: reconcile OK"
        return 0
      }
    '';

  lower = "tr '[:upper:]' '[:lower:]'";
in
{
  home.packages = [

    # =======================================================================================
    # email-census (read-only) — sender/folder/date census
    # =======================================================================================
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

    # =======================================================================================
    # email-classify (local-tags-only) — deterministic rule scaffold + candidate manifest +
    # --append-approved (the sole allowlisted target for the Phase 9 aerc confirm gesture)
    # =======================================================================================
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

    # =======================================================================================
    # email-unsubscribe-extract (read-only) — List-Unsubscribe header harvest, never fetches
    # =======================================================================================
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

    # =======================================================================================
    # email-archive-confirmed (mutation) — move approved 'archive' IDs to All_Mail
    # =======================================================================================
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
          log "PLAN: move $mid (envelope $RESOLVED_ENVELOPE_ID in $RESOLVED_FOLDER) -> All_Mail"
          continue
        fi
        log "EXECUTE: moving $mid (envelope $RESOLVED_ENVELOPE_ID in $RESOLVED_FOLDER) -> All_Mail"
        if himalaya message move All_Mail "$RESOLVED_ENVELOPE_ID" -f "$RESOLVED_FOLDER" >&2; then
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

    # =======================================================================================
    # email-delete-confirmed (mutation) — two-hop delete (move-to-Trash, then --expunge-trash)
    # =======================================================================================
    (pkgs.writeShellScriptBin "email-delete-confirmed" (mkMutationPreamble {
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
    } + ''
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
          if himalaya message delete "$RESOLVED_ENVELOPE_ID" -f "$RESOLVED_FOLDER" >&2; then
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
          if himalaya message delete "$RESOLVED_ENVELOPE_ID" -f Trash >&2; then
            state_set "$mid" "executed"
            executed_any=1
            any_flagged=1
          else
            state_set "$mid" "failed" "himalaya message delete (hop 2: flag Deleted) failed"
          fi
        done <<< "$ids"

        if [ "$EXECUTE" -eq 1 ] && [ "$any_flagged" -eq 1 ]; then
          log "EXECUTE: himalaya folder expunge Trash"
          himalaya folder expunge Trash >&2
        fi
      fi

      if [ "$EXECUTE" -eq 1 ] && [ "$executed_any" -eq 1 ]; then
        run_mbsync_reconcile || exit 1
      fi
    ''))
  ];
}
