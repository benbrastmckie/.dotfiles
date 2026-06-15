#!/usr/bin/env bash
# manage-topics.sh - Topic management utility for state.json active_topics
#
# Encapsulates mechanical state.json operations for topic management.
# Commands/skills call this script instead of inlining jq snippets.
#
# Usage:
#   manage-topics.sh list
#   manage-topics.sh add TOPIC
#   manage-topics.sh set TASK_NUM TOPIC
#   manage-topics.sh validate TOPIC
#
# Subcommands:
#   list              Print all active topics, one per line
#   add TOPIC         Add TOPIC to active_topics (idempotent; no-op if already present)
#   set TASK_NUM TOPIC  Set topic on task TASK_NUM and ensure TOPIC is in active_topics
#   validate TOPIC    Exit 0 if TOPIC is in active_topics, exit 1 if not (no stdout)
#
# Exit codes:
#   0 - Success (list/add/set) or topic found (validate)
#   1 - Topic not found (validate) or bad arguments
#   2 - state.json not found or read error
#   3 - jq write failure (tmp-file step)
#   4 - Task not found (set subcommand)
#
# Note: Uses tmp-file atomic write (jq -> .tmp && mv .tmp -> file).
# No flock is used; the codebase convention is tmp-file rename, which minimises
# the write window for single-threaded Claude Code agent sessions.

set -euo pipefail

# --- Path resolution (matches update-task-status.sh pattern) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"
TMP_DIR="$PROJECT_ROOT/specs/tmp"

# --- Cleanup trap ---
trap 'rm -f "$TMP_DIR/state.json.tmp" 2>/dev/null || true' EXIT

# --- Guard: state.json must exist ---
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: state.json not found at $STATE_FILE" >&2
  exit 2
fi

# --- Ensure tmp directory exists ---
mkdir -p "$TMP_DIR"

# --- Subcommand dispatch ---
SUBCMD="${1:-}"

case "$SUBCMD" in

  # ------------------------------------------------------------------
  # list: print active topics one per line
  # ------------------------------------------------------------------
  list)
    jq -r '.active_topics // [] | .[]' "$STATE_FILE"
    ;;

  # ------------------------------------------------------------------
  # add TOPIC: idempotent append to active_topics
  # ------------------------------------------------------------------
  add)
    TOPIC="${2:-}"
    if [[ -z "$TOPIC" ]]; then
      echo "Usage: $0 add TOPIC" >&2
      exit 1
    fi

    # Use index($t) == null pattern (safe under Claude Code Issue #1132 — no != operator)
    jq --arg t "$TOPIC" \
      'if ((.active_topics // []) | index($t)) == null
       then .active_topics = ((.active_topics // []) + [$t])
       else .
       end' \
      "$STATE_FILE" > "$TMP_DIR/state.json.tmp"

    if [[ $? -ne 0 ]]; then
      echo "Error: jq failed to update active_topics" >&2
      exit 3
    fi

    if ! jq empty "$TMP_DIR/state.json.tmp" 2>/dev/null; then
      echo "Error: jq produced invalid JSON" >&2
      exit 3
    fi

    mv "$TMP_DIR/state.json.tmp" "$STATE_FILE"
    ;;

  # ------------------------------------------------------------------
  # set TASK_NUM TOPIC: assign topic to task and add to active_topics
  # ------------------------------------------------------------------
  set)
    TASK_NUM="${2:-}"
    TOPIC="${3:-}"
    if [[ -z "$TASK_NUM" || -z "$TOPIC" ]]; then
      echo "Usage: $0 set TASK_NUM TOPIC" >&2
      exit 1
    fi

    if ! [[ "$TASK_NUM" =~ ^[0-9]+$ ]]; then
      echo "Error: TASK_NUM must be a positive integer, got '$TASK_NUM'" >&2
      exit 1
    fi

    # Validate task exists
    task_exists=$(jq -r --arg num "$TASK_NUM" \
      '[.active_projects[] | select(.project_number == ($num | tonumber))] | length' \
      "$STATE_FILE")

    if [[ "$task_exists" == "0" ]]; then
      echo "Error: task $TASK_NUM not found in state.json" >&2
      exit 4
    fi

    # Step 1: set topic on the task entry + ensure active_topics contains the topic
    jq --arg num "$TASK_NUM" --arg t "$TOPIC" \
      '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {topic: $t}
       | if ((.active_topics // []) | index($t)) == null
         then .active_topics = ((.active_topics // []) + [$t])
         else .
         end' \
      "$STATE_FILE" > "$TMP_DIR/state.json.tmp"

    if [[ $? -ne 0 ]]; then
      echo "Error: jq failed to update task topic" >&2
      exit 3
    fi

    if ! jq empty "$TMP_DIR/state.json.tmp" 2>/dev/null; then
      echo "Error: jq produced invalid JSON" >&2
      exit 3
    fi

    mv "$TMP_DIR/state.json.tmp" "$STATE_FILE"
    ;;

  # ------------------------------------------------------------------
  # validate TOPIC: exit 0 if present, exit 1 if not; no stdout
  # ------------------------------------------------------------------
  validate)
    TOPIC="${2:-}"
    if [[ -z "$TOPIC" ]]; then
      echo "Usage: $0 validate TOPIC" >&2
      exit 1
    fi

    found=$(jq -r --arg t "$TOPIC" \
      'if ((.active_topics // []) | index($t)) == null then "no" else "yes" end' \
      "$STATE_FILE")

    if [[ "$found" == "yes" ]]; then
      exit 0
    else
      exit 1
    fi
    ;;

  # ------------------------------------------------------------------
  # Unknown subcommand or no args
  # ------------------------------------------------------------------
  *)
    echo "manage-topics.sh — topic management utility for state.json" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  $0 list                    Print all active topics" >&2
    echo "  $0 add TOPIC               Add TOPIC to active_topics (idempotent)" >&2
    echo "  $0 set TASK_NUM TOPIC      Assign TOPIC to task and add to active_topics" >&2
    echo "  $0 validate TOPIC          Exit 0 if TOPIC exists, exit 1 if not" >&2
    echo "" >&2
    echo "Exit codes: 0=success/found, 1=not-found/bad-args, 2=state.json-error," >&2
    echo "            3=jq-write-failure, 4=task-not-found" >&2
    exit 1
    ;;

esac
