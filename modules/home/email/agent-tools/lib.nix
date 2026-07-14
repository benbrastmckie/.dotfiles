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
#
# Task 79: `--account` is now a real two-value enum (`gmail` | `logos`), superseding the
# task-72 framing of Protonmail/Logos as "out of scope, flag reserved for future multi-account
# support" (see the addendum to wrapper-contract.md). The Logos backend (mbsync Group `logos`,
# notmuch index, maildir, himalaya + aerc `[logos]` accounts, Protonmail Bridge on
# 127.0.0.1:1143) was already merged by task 72; task 79 only threads a per-account resolver
# through this file. Verified against the live system (task 79 research report, Finding 2):
# Logos's real maildir++ folders are the bare root (`INBOX`), `.Sent`, `.Archive`, `.Drafts`,
# `.Trash` — there is NO `.All_Mail` and NO `.Spam` for Logos (Proton is folder-based, not
# Gmail's label model); the non-dot `INBOX`/`Sent`/`Drafts`/`Trash`/`Archive` subdirectories
# under `~/Mail/Logos/` are stray, always-empty directories and must never be queried.
#
# Task 88: split out of the former monolithic `email/agent-tools.nix` (761 lines). Carries
# ONLY the shared pure-string helpers used by the five per-binary modules in this directory
# (census/classify/unsubscribe-extract/archive-confirmed/delete-confirmed, wired by
# default.nix). PLAIN Nix expression, not a Home Manager module — no `pkgs`/`config` args;
# consumers `import ./lib.nix` directly and `inherit` the helpers they need.
let
  manifestDirDefault = "$HOME/.local/state/email-agent/manifests";

  # ---------------------------------------------------------------------------------------
  # Shared preamble (contract §2): global flags, `--account {gmail,logos}` per-account resolver
  # (task 79), manifest-dir resolution, logging. Interpolated into ALL five binaries.
  # ---------------------------------------------------------------------------------------
  mkPreamble =
    {
      name,
      verb,
      safetyClass,
      extraHelp ? "",
    }:
    ''
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
                                 ${manifestDirDefault}/)
        --help                  Show this help
      ${extraHelp}
      HELPEOF
          }

          ACCOUNT_EXPLICIT=0
          ARGS=()
          while [ "$#" -gt 0 ]; do
            case "$1" in
              --account) ACCOUNT="''${2:-}"; ACCOUNT_EXPLICIT=1; shift 2 ;;
              --account=*) ACCOUNT="''${1#--account=}"; ACCOUNT_EXPLICIT=1; shift ;;
              --manifest-dir) MANIFEST_DIR="''${2:-}"; shift 2 ;;
              --manifest-dir=*) MANIFEST_DIR="''${1#--manifest-dir=}"; shift ;;
              --help|-h) print_help; exit 0 ;;
              gmail|logos)
                if [ "$ACCOUNT_EXPLICIT" -eq 1 ]; then
                  # --account already given explicitly; treat this token as an ordinary
                  # positional arg (e.g. email-classify/email-unsubscribe-extract's [QUERY]).
                  ARGS+=("$1")
                else
                  log "NOTE: interpreting bare positional '$1' as '--account $1' (pass --account explicitly to silence this note)"
                  ACCOUNT="$1"
                  ACCOUNT_EXPLICIT=1
                fi
                shift
                ;;
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
  mkMutationPreamble =
    {
      name,
      verb,
      extraHelp ? "",
    }:
    (mkPreamble {
      inherit name verb extraHelp;
      safetyClass = "mutation";
    })
    + ''
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
        local rel="''${filepath#*$ACCOUNT_MAILDIR_MARKER}"
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
          candidates=$(himalaya envelope list "''${HIMALAYA_ACCT[@]}" -f "$folder" -o json -s 5000 "subject $subject_word" 2>/dev/null \
            | jq -r '.[].id' 2>/dev/null || true)
        else
          candidates=$(himalaya envelope list "''${HIMALAYA_ACCT[@]}" -f "$folder" -o json -s 5000 2>/dev/null \
            | jq -r '.[].id' 2>/dev/null || true)
        fi

        for eid in $candidates; do
          raw_mid=$(himalaya message read "''${HIMALAYA_ACCT[@]}" "$eid" -f "$folder" -p -H Message-Id 2>/dev/null \
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
      # Sole detection point: the `mbsync $ACCOUNT_MBSYNC_GROUP` reconcile step. Matches BOTH
      # the legacy XOAUTH2 failure and the app-password failure so the fail-safe survives
      # either auth model. Himalaya wrapper calls (local maildir, app-password) never check
      # for this.
      is_mbsync_auth_failure() {
        printf '%s' "$1" | grep -qE 'invalid_grant|\[AUTHENTICATIONFAILED\] Invalid credentials'
      }

      run_mbsync_reconcile() {
        log ""
        log "Reconciling with 'mbsync $ACCOUNT_MBSYNC_GROUP' (group-scoped; NEVER mbsync -a —"
        log "that would touch every configured account instead of just $ACCOUNT_MBSYNC_GROUP)..."
        local out status
        set +e
        out=$(mbsync "$ACCOUNT_MBSYNC_GROUP" 2>&1)
        status=$?
        set -e
        echo "$out" >&2
        if [ "$status" -ne 0 ]; then
          if is_mbsync_auth_failure "$out"; then
            log "AUTH FAILURE detected (invalid_grant or [AUTHENTICATIONFAILED])."
            log "Halting before further mutation. The approved manifest ($MANIFEST_FILE) and"
            log "state file ($STATE_FILE) are preserved untouched by this failure."
            log "Resume: fix auth, re-run 'mbsync $ACCOUNT_MBSYNC_GROUP' manually, then re-run"
            log "this wrapper with --execute --confirm-manifest $ACTUAL_HASH (already-executed"
            log "IDs are skipped)."
          else
            log "mbsync $ACCOUNT_MBSYNC_GROUP exited non-zero for a reason OTHER than an auth"
            log "failure (exit $status). This may be the known gmail-spam NONEXISTENT-mailbox"
            log "issue (task-46/mbsync scope; see handoffs/verification-baseline.md §6a) —"
            log "inspect the output above."
          fi
          return 1
        fi
        log "mbsync $ACCOUNT_MBSYNC_GROUP: reconcile OK"
        return 0
      }
    '';

  lower = "tr '[:upper:]' '[:lower:]'";
in
{
  inherit
    manifestDirDefault
    mkPreamble
    mkMutationPreamble
    lower
    ;
}
