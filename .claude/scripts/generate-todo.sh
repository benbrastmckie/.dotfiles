#!/usr/bin/env bash
#
# generate-todo.sh - Generate the entire TODO.md from state.json
#
# Usage:
#   generate-todo.sh [OPTIONS]
#
# Options:
#   --todo FILE       Path to output TODO.md (default: specs/TODO.md)
#   --state FILE      Path to state.json (default: specs/state.json)
#   --dry-run         Print generated content to stdout; do not write file
#   --log FILE        Path to log file (default: .claude/logs/generate-todo.log)
#   --no-log          Suppress all log output
#
# The generated file contains:
#   1. YAML frontmatter: ---\nnext_project_number: N\n---
#   2. # TODO heading
#   3. ## Task Order section (delegated to generate-task-order.sh --print)
#   4. ## Tasks section with all entries in descending project_number order
#
# Terminal tasks (completed/abandoned/expanded) appear in ## Tasks but not ## Task Order.
# Atomic write via mktemp + mv ensures no partial/corrupted output.
#
# Logging: append-only to .claude/logs/generate-todo.log with ISO timestamps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ============================================================================
# Default Values
# ============================================================================

TODO_FILE="${PROJECT_ROOT}/specs/TODO.md"
STATE_FILE="${PROJECT_ROOT}/specs/state.json"
DRY_RUN=0
LOG_FILE="${PROJECT_ROOT}/.claude/logs/generate-todo.log"
NO_LOG=0

# ============================================================================
# Parse Arguments
# ============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    --todo)
      shift
      TODO_FILE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --state)
      shift
      STATE_FILE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --log)
      shift
      LOG_FILE="${1:-}"
      [[ $# -gt 0 ]] && shift
      ;;
    --no-log)
      NO_LOG=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: generate-todo.sh [--todo FILE] [--state FILE] [--dry-run] [--log FILE] [--no-log]" >&2
      exit 1
      ;;
  esac
done

# ============================================================================
# Logging
# ============================================================================

START_TIME=$(date +%s)

log() {
  local level="$1"
  shift
  local message="$*"
  if [[ "$NO_LOG" -eq 1 ]]; then
    return
  fi
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '[%s] generate-todo: %s %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE"
}

log_error() {
  log "ERROR" "$@"
  echo "ERROR: $*" >&2
}

# ============================================================================
# Validation
# ============================================================================

if [[ ! -f "$STATE_FILE" ]]; then
  log_error "state.json not found at ${STATE_FILE}"
  exit 1
fi

# ============================================================================
# Status Mapping
# ============================================================================

format_status() {
  local raw="$1"
  case "$raw" in
    not_started)  printf '%s' "NOT STARTED" ;;
    researching)  printf '%s' "RESEARCHING" ;;
    researched)   printf '%s' "RESEARCHED" ;;
    planning)     printf '%s' "PLANNING" ;;
    planned)      printf '%s' "PLANNED" ;;
    implementing) printf '%s' "IMPLEMENTING" ;;
    completed)    printf '%s' "COMPLETED" ;;
    blocked)      printf '%s' "BLOCKED" ;;
    abandoned)    printf '%s' "ABANDONED" ;;
    partial)      printf '%s' "PARTIAL" ;;
    expanded)     printf '%s' "EXPANDED" ;;
    pr_ready)     printf '%s' "PR READY" ;;
    *)            printf '%s' "$(echo "$raw" | tr '[:lower:]' '[:upper:]')" ;;
  esac
}

# ============================================================================
# Artifact Type Mapping
# ============================================================================

format_artifact_type() {
  local atype="$1"
  case "$atype" in
    research|report) printf '%s' "Research" ;;
    plan)            printf '%s' "Plan" ;;
    summary|implementation) printf '%s' "Summary" ;;
    *)
      # Capitalize first letter of unknown types
      local first="${atype:0:1}"
      local rest="${atype:1}"
      printf '%s' "$(echo "$first" | tr '[:lower:]' '[:upper:]')${rest}"
      ;;
  esac
}

# ============================================================================
# Generate Task Entry
# ============================================================================

# generate_task_entry: outputs a complete TODO.md task entry for one project_number
# All state.json fields are read inside via jq for the given project_number
generate_task_entry() {
  local task_num="$1"

  # Extract all fields for this task in one jq call (use @base64 to handle newlines in description)
  local task_json
  task_json=$(jq -r --argjson num "$task_num" '
    .active_projects[] | select(.project_number == $num) |
    {
      project_number: .project_number,
      project_name: (.project_name // ""),
      title: (.title // ""),
      status: (.status // "not_started"),
      task_type: (.task_type // "general"),
      topic: (.topic // ""),
      effort: (.effort // ""),
      dependencies: (.dependencies // []),
      artifacts: (.artifacts // []),
      description: (.description // "")
    }
  ' "$STATE_FILE")

  # Parse individual fields
  local title status task_type topic effort description
  title=$(printf '%s' "$task_json" | jq -r '.title')
  local project_name
  project_name=$(printf '%s' "$task_json" | jq -r '.project_name')
  status=$(printf '%s' "$task_json" | jq -r '.status')
  task_type=$(printf '%s' "$task_json" | jq -r '.task_type')
  topic=$(printf '%s' "$task_json" | jq -r '.topic')
  effort=$(printf '%s' "$task_json" | jq -r '.effort')
  description=$(printf '%s' "$task_json" | jq -r '.description')

  # Title fallback: derive from project_name if title is empty
  if [[ -z "$title" || "$title" == "null" ]]; then
    if [[ -n "$project_name" && "$project_name" != "null" ]]; then
      # Replace underscores with spaces and capitalize first letter
      title="${project_name//_/ }"
      title="${title^}"
    else
      title="Task ${task_num}"
    fi
  fi

  # Format status
  local status_display
  status_display=$(format_status "$status")

  # Heading
  printf '### %s. %s\n' "$task_num" "$title"

  # Effort (omit if empty/null)
  if [[ -n "$effort" && "$effort" != "null" ]]; then
    printf -- '- **Effort**: %s\n' "$effort"
  fi

  # Status
  printf -- '- **Status**: [%s]\n' "$status_display"

  # Task Type
  if [[ -n "$task_type" && "$task_type" != "null" ]]; then
    printf -- '- **Task Type**: %s\n' "$task_type"
  fi

  # Topic (omit if empty/null)
  if [[ -n "$topic" && "$topic" != "null" ]]; then
    printf -- '- **Topic**: %s\n' "$topic"
  fi

  # Dependencies
  local deps_json
  deps_json=$(printf '%s' "$task_json" | jq -r '.dependencies | length')
  if [[ "$deps_json" -eq 0 ]]; then
    printf -- '- **Dependencies**: None\n'
  else
    local dep_list
    dep_list=$(printf '%s' "$task_json" | jq -r '.dependencies | map("Task " + tostring) | join(", ")')
    printf -- '- **Dependencies**: %s\n' "$dep_list"
  fi

  # Artifacts: group by logical type
  # Types: research/report -> Research, plan -> Plan, summary/implementation -> Summary, other -> Capitalized
  local artifacts_len
  artifacts_len=$(printf '%s' "$task_json" | jq -r '.artifacts | length')

  if [[ "$artifacts_len" -gt 0 ]]; then
    # Collect artifacts by logical type
    # We need to group artifacts by their display type and render each group
    # Strategy: extract all artifacts with their display types, then group by type

    # Get all artifacts as type|path pairs
    local artifacts_raw
    artifacts_raw=$(printf '%s' "$task_json" | jq -r '.artifacts[] | (.type // "unknown") + "|" + (.path // "")')

    # Track which display types we've already rendered headers for
    declare -A rendered_types=()
    declare -A type_artifacts=()   # display_type -> newline-separated paths
    declare -a type_order=()       # order of first appearance

    while IFS='|' read -r atype apath; do
      [[ -z "$apath" ]] && continue
      local display_type
      display_type=$(format_artifact_type "$atype")
      if [[ -z "${type_artifacts[$display_type]+x}" ]]; then
        type_order+=("$display_type")
        type_artifacts["$display_type"]=""
      fi
      # Strip specs/ prefix from path
      local short_path="${apath#specs/}"
      if [[ -z "${type_artifacts[$display_type]}" ]]; then
        type_artifacts["$display_type"]="$short_path"
      else
        type_artifacts["$display_type"]="${type_artifacts[$display_type]}
${short_path}"
      fi
    done <<< "$artifacts_raw"

    # Render each type group
    for display_type in "${type_order[@]}"; do
      local paths_str="${type_artifacts[$display_type]}"
      # Count paths by counting newlines + 1
      local path_count
      path_count=$(printf '%s' "$paths_str" | grep -c '' || true)

      if [[ "$path_count" -le 1 ]]; then
        # Single artifact: inline format
        printf -- '- **%s**: [%s]\n' "$display_type" "$paths_str"
      else
        # Multiple artifacts: multi-line list
        printf -- '- **%s**:\n' "$display_type"
        while IFS= read -r p; do
          [[ -z "$p" ]] && continue
          printf '  - [%s]\n' "$p"
        done <<< "$paths_str"
      fi
    done

    unset rendered_types type_artifacts type_order
  fi

  # Description (omit if empty/null)
  if [[ -n "$description" && "$description" != "null" ]]; then
    printf '\n'
    printf '**Description**: %s\n' "$description"
  fi
}

# ============================================================================
# Generate TODO.md Content
# ============================================================================

generate_todo() {
  # --- YAML frontmatter ---
  local next_num
  next_num=$(jq -r '.next_project_number' "$STATE_FILE")
  printf -- '---\n'
  printf 'next_project_number: %s\n' "$next_num"
  printf -- '---\n'
  printf '\n'

  log "INFO" "frontmatter written (next_project_number=${next_num})"

  # --- Title heading ---
  printf '# TODO\n'
  printf '\n'

  # --- Task Order section ---
  # generate-task-order.sh --print uses its own default state.json path.
  # We pass our STATE_FILE via a temporary symlink workaround if it differs, but
  # normally both scripts share the same PROJECT_ROOT/specs/state.json default.
  local task_order_output
  if task_order_output=$("${SCRIPT_DIR}/generate-task-order.sh" --print 2>&1); then
    printf '%s\n' "$task_order_output"
  else
    local exit_code=$?
    log_error "generate-task-order.sh failed with exit code ${exit_code}: ${task_order_output}"
    exit 1
  fi

  log "INFO" "Task Order section written"

  # --- Tasks section ---
  printf '\n'
  printf '## Tasks\n'
  printf '\n'

  # Get all project numbers sorted descending
  local task_numbers
  task_numbers=$(jq -r '.active_projects[].project_number' "$STATE_FILE" | sort -rn)

  local total_count=0
  local active_count=0
  local terminal_count=0
  local first_entry=1

  while IFS= read -r task_num; do
    [[ -z "$task_num" ]] && continue
    total_count=$((total_count + 1))

    # Check if terminal
    local task_status
    task_status=$(jq -r --argjson num "$task_num" \
      '.active_projects[] | select(.project_number == $num) | .status' \
      "$STATE_FILE")

    case "$task_status" in
      completed|abandoned|expanded) terminal_count=$((terminal_count + 1)) ;;
      *) active_count=$((active_count + 1)) ;;
    esac

    # Separator between entries (not before the first)
    if [[ "$first_entry" -eq 0 ]]; then
      printf '\n---\n\n'
    fi
    first_entry=0

    generate_task_entry "$task_num"

  done <<< "$task_numbers"

  log "INFO" "Tasks section written (total=${total_count} active=${active_count} terminal=${terminal_count})"

  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - START_TIME))
  log "OK" "tasks=${total_count} (active=${active_count}, terminal=${terminal_count}) elapsed=${elapsed}s"
}

# ============================================================================
# Main
# ============================================================================

log "START" "state=${STATE_FILE} todo=${TODO_FILE}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  generate_todo
else
  # Atomic write: write to temp file, then mv
  TEMP_FILE=""
  cleanup_temp() {
    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
      rm -f "$TEMP_FILE"
    fi
  }
  trap cleanup_temp EXIT

  TEMP_FILE=$(mktemp -p "$(dirname "$TODO_FILE")" "todo.XXXXXX")
  generate_todo > "$TEMP_FILE"
  mv "$TEMP_FILE" "$TODO_FILE"
  TEMP_FILE=""  # Prevent cleanup from removing the now-moved file

  log "WROTE" "${TODO_FILE}"
fi
