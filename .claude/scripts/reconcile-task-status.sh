#!/usr/bin/env bash
# reconcile-task-status.sh - Self-healing reconciliation for stuck tasks
#
# Detects tasks stuck in in-flight states (researching, planning, implementing, partial)
# when artifacts already exist on disk, then replays the missed postflight to promote
# their status. Addresses the failure mode where an agent writes artifacts but crashes
# before postflight runs.
#
# Usage:
#   .claude/scripts/reconcile-task-status.sh <task_number> <session_id> [--dry-run]
#
# Arguments:
#   task_number  - Task number (integer)
#   session_id   - Session identifier string
#   --dry-run    - Print what would be done without modifying state
#
# Artifact-to-phase mapping:
#   reports/*.md    -> research phase   (researching -> researched)
#   plans/*.md      -> planning phase   (planning -> planned)
#   summaries/*.md  -> implement phase  (implementing -> completed)
#   partial state   -> check handoff for continuation_context
#
# Exit codes:
#   0 - Success or no-op (nothing to reconcile, or reconciliation applied)
#   1 - Validation error (bad arguments or state.json missing)
#   2 - state.json read error

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- Parse arguments ---
DRY_RUN=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

task_number="${POSITIONAL_ARGS[0]:-}"
session_id="${POSITIONAL_ARGS[1]:-}"

# --- Validation ---
if [[ -z "$task_number" || -z "$session_id" ]]; then
  echo "Usage: $0 <task_number> <session_id> [--dry-run]" >&2
  exit 1
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "Error: task_number must be a positive integer, got '$task_number'" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 1
fi

# --- Read current task status from state.json ---
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  "$STATE_FILE" 2>/dev/null) || {
  echo "Error: failed to read state.json for task $task_number" >&2
  exit 2
}

if [[ -z "$task_data" ]]; then
  # Task not found — no-op (not an error, task may have been archived)
  exit 0
fi

current_status=$(echo "$task_data" | jq -r '.status // "not_started"')
project_name=$(echo "$task_data" | jq -r '.project_name')

# --- Resolve task directory ---
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DIR="$PROJECT_ROOT/specs/${PADDED_NUM}_${project_name}"

# --- Helper: find latest artifact in a subdirectory ---
find_latest_artifact() {
  local subdir="$1"
  local artifact_dir="${TASK_DIR}/${subdir}"
  if [[ -d "$artifact_dir" ]]; then
    ls -1 "${artifact_dir}/"*.md 2>/dev/null | sort -V | tail -1
  fi
}

# --- Helper: check if artifact is already linked in state.json ---
artifact_already_linked() {
  local artifact_path="$1"
  local artifact_type="$2"
  # Normalize to relative path (specs/...)
  local rel_path="${artifact_path#$PROJECT_ROOT/}"
  jq -r --argjson num "$task_number" \
    '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | .path] | .[]' \
    "$STATE_FILE" 2>/dev/null | grep -qF "$rel_path" && return 0 || return 1
}

# --- Helper: link artifact in state.json and TODO.md ---
link_artifact() {
  local artifact_path="$1"
  local artifact_type="$2"    # report | plan | summary
  local artifact_summary="$3"

  # Normalize to relative path for state.json and TODO.md
  local rel_path="${artifact_path#$PROJECT_ROOT/}"

  if artifact_already_linked "$artifact_path" "$artifact_type"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Artifact already linked in state.json: $rel_path — skipping"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[reconcile] Would link artifact in state.json: type=$artifact_type path=$rel_path"
  else
    mkdir -p "$PROJECT_ROOT/specs/tmp"
    # Step 1: Remove existing artifacts of same type (Issue #1132-safe pattern)
    jq --arg atype "$artifact_type" \
      --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == $atype | not)]' \
      "$STATE_FILE" > "$PROJECT_ROOT/specs/tmp/state.json" \
      && mv "$PROJECT_ROOT/specs/tmp/state.json" "$STATE_FILE"
    # Step 2: Add new artifact entry
    jq --arg path "$rel_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
       --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      "$STATE_FILE" > "$PROJECT_ROOT/specs/tmp/state.json" \
      && mv "$PROJECT_ROOT/specs/tmp/state.json" "$STATE_FILE"
    echo "[reconcile] Linked $artifact_type artifact in state.json: $rel_path"
  fi

  # Step 3: Regenerate TODO.md from state.json
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[reconcile] Would regenerate TODO.md via generate-todo.sh"
  else
    "$SCRIPT_DIR/generate-todo.sh" || {
      echo "[reconcile] WARNING: generate-todo.sh failed for $rel_path (non-fatal)" >&2
    }
  fi
}

# --- Main reconciliation dispatch ---
case "$current_status" in

  researching)
    # Check for completed research artifact
    report_file=$(find_latest_artifact "reports")
    if [[ -z "$report_file" ]]; then
      # No artifact — genuine in-progress, no-op
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=researching, no report artifact found — no-op"
      fi
      exit 0
    fi

    report_basename=$(basename "$report_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=researching, found report $report_basename"
      echo "[reconcile] Would promote: researching -> researched via postflight research"
      link_artifact "$report_file" "report" "Research report: $report_basename"
    else
      echo "[reconcile] Task $task_number: status=researching but report exists ($report_basename) — replaying postflight"
      link_artifact "$report_file" "report" "Research report: $report_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "research" "$session_id"
      echo "[reconcile] Task $task_number: promoted researching -> researched"
    fi
    ;;

  planning)
    # Check for completed plan artifact
    plan_file=$(find_latest_artifact "plans")
    if [[ -z "$plan_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=planning, no plan artifact found — no-op"
      fi
      exit 0
    fi

    plan_basename=$(basename "$plan_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=planning, found plan $plan_basename"
      echo "[reconcile] Would promote: planning -> planned via postflight plan"
      link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
    else
      echo "[reconcile] Task $task_number: status=planning but plan exists ($plan_basename) — replaying postflight"
      link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id"
      echo "[reconcile] Task $task_number: promoted planning -> planned"
    fi
    ;;

  implementing)
    # Check for completed summary artifact
    summary_file=$(find_latest_artifact "summaries")
    if [[ -z "$summary_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=implementing, no summary artifact found — no-op"
      fi
      exit 0
    fi

    summary_basename=$(basename "$summary_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=implementing, found summary $summary_basename"
      echo "[reconcile] Would promote: implementing -> completed via postflight implement"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
    else
      echo "[reconcile] Task $task_number: status=implementing but summary exists ($summary_basename) — replaying postflight"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"
      echo "[reconcile] Task $task_number: promoted implementing -> completed"
    fi
    ;;

  partial)
    # For partial state, check if there's a summary (stuck after final phase)
    summary_file=$(find_latest_artifact "summaries")
    if [[ -z "$summary_file" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[reconcile] Task $task_number: status=partial, no summary artifact found — no-op"
      fi
      exit 0
    fi

    # Only promote partial->completed if the handoff indicates "implemented" status
    handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
    if [[ -f "$handoff_file" ]]; then
      handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
      if [[ "$handoff_status" != "implemented" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[reconcile] Task $task_number: status=partial, handoff status=$handoff_status (not 'implemented') — no-op"
        fi
        exit 0
      fi
    fi

    summary_basename=$(basename "$summary_file")
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[reconcile] Task $task_number: status=partial, found summary $summary_basename with implemented handoff"
      echo "[reconcile] Would promote: partial -> completed via postflight implement"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
    else
      echo "[reconcile] Task $task_number: status=partial but summary exists ($summary_basename) with implemented handoff — replaying postflight"
      link_artifact "$summary_file" "summary" "Implementation summary: $summary_basename"
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"
      echo "[reconcile] Task $task_number: promoted partial -> completed"
    fi
    ;;

  *)
    # All other statuses (not_started, researched, planned, completed, blocked, abandoned, expanded)
    # are either terminal or already at a stable state — no-op
    exit 0
    ;;
esac

exit 0
