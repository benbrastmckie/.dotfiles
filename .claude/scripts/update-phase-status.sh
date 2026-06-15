#!/usr/bin/env bash
# update-phase-status.sh - Update a single phase heading status in a plan file
# Usage: .claude/scripts/update-phase-status.sh TASK_NUMBER PROJECT_NAME PHASE_NUMBER NEW_STATUS
#
# NEW_STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, PARTIAL, BLOCKED
# Outputs: Updated plan file path on success, empty on failure/no-op
#
# Phase heading format: ### Phase N: {name} [STATUS]
# Logs transitions to: .claude/logs/phase-transitions.log

set -euo pipefail

task_number="${1:-}"
project_name="${2:-}"
phase_number="${3:-}"
new_status="${4:-}"

# Validate inputs
if [[ -z "$task_number" || -z "$project_name" || -z "$phase_number" || -z "$new_status" ]]; then
    echo "Usage: $0 TASK_NUMBER PROJECT_NAME PHASE_NUMBER STATUS" >&2
    echo "  STATUS values: IN_PROGRESS, NOT_STARTED, COMPLETED, PARTIAL, BLOCKED" >&2
    exit 1
fi

# Normalize NEW_STATUS: case-insensitive input to canonical display form (with spaces)
case "$new_status" in
    IN_PROGRESS|in_progress|IN\ PROGRESS|in\ progress)
        new_status_display="IN PROGRESS" ;;
    NOT_STARTED|not_started|NOT\ STARTED|not\ started)
        new_status_display="NOT STARTED" ;;
    COMPLETED|completed)
        new_status_display="COMPLETED" ;;
    PARTIAL|partial)
        new_status_display="PARTIAL" ;;
    BLOCKED|blocked)
        new_status_display="BLOCKED" ;;
    *)
        echo "Unknown status: $new_status" >&2
        echo "Valid values: IN_PROGRESS, NOT_STARTED, COMPLETED, PARTIAL, BLOCKED" >&2
        exit 1 ;;
esac

# Determine the script's working directory — find repo root by locating .claude/
# Script may be called from any working directory, so resolve relative to this script's location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

# Find plan directory (padded task number with fallback to unpadded)
padded_num=$(printf "%03d" "$task_number")
plan_dir="${repo_root}/specs/${padded_num}_${project_name}/plans"

if [[ ! -d "$plan_dir" ]]; then
    # Try unpadded (legacy)
    plan_dir="${repo_root}/specs/${task_number}_${project_name}/plans"
fi

if [[ ! -d "$plan_dir" ]]; then
    echo "Plan directory not found for task $task_number (tried padded and unpadded)" >&2
    exit 1
fi

# Get latest plan file
plan_file=$(ls -t "$plan_dir"/*.md 2>/dev/null | head -1)
if [[ -z "$plan_file" ]]; then
    echo "No plan file found in $plan_dir" >&2
    exit 1
fi

plan_basename=$(basename "$plan_file")

# Find the exact line number of the phase heading
# Pattern: ^### Phase {phase_number}: (anything) [STATUS]
# Use || true to prevent set -e from aborting when grep finds no match (exit code 1)
line_number=$(grep -n "^### Phase ${phase_number}:" "$plan_file" 2>/dev/null | head -1 | cut -d: -f1 || true)

if [[ -z "$line_number" ]]; then
    echo "Phase ${phase_number} not found in $plan_file" >&2
    exit 1
fi

# Extract current status from that line using sed capture
current_status=$(sed -n "${line_number}s/.*\[\(.*\)\]$/\1/p" "$plan_file")

if [[ -z "$current_status" ]]; then
    echo "Could not extract status from phase ${phase_number} heading in $plan_file" >&2
    echo "Line ${line_number}: $(sed -n "${line_number}p" "$plan_file")" >&2
    exit 1
fi

# Idempotency check: if current status equals target status, exit 0 silently (no-op)
if [[ "$current_status" == "$new_status_display" ]]; then
    # Already at target status, no-op
    exit 0
fi

# Replace status on the specific line (line-specific replacement to avoid touching plan-level header)
sed -i "${line_number}s/\[.*\]/[${new_status_display}]/" "$plan_file"

# Verify the replacement succeeded
updated_line=$(sed -n "${line_number}p" "$plan_file")
updated_status=$(echo "$updated_line" | sed 's/.*\[\(.*\)\]$/\1/')

if [[ "$updated_status" != "$new_status_display" ]]; then
    echo "Failed to update phase ${phase_number} status in $plan_file" >&2
    echo "Wanted '${new_status_display}', got '${updated_status}'" >&2
    exit 1
fi

# Ensure log directory exists
log_dir="${repo_root}/.claude/logs"
mkdir -p "$log_dir"
log_file="${log_dir}/phase-transitions.log"

# Append log entry: [ISO8601] task N filename.md phase P: OLD_STATUS -> NEW_STATUS
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[${timestamp}] task ${task_number} ${plan_basename} phase ${phase_number}: ${current_status} -> ${new_status_display}" >> "$log_file"

# Output the updated plan file path on success
echo "$plan_file"
