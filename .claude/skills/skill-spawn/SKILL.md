---
name: skill-spawn
description: Research blockers and spawn new tasks to overcome them, updating parent task dependencies
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Spawn Skill

Thin wrapper that delegates blocker analysis to `spawn-agent` subagent, then handles all state management in postflight: creates new task entries, establishes parent-child relationships, and updates dependencies.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (task creation, dependency linking, git commit) before returning. This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task status is not terminal (completed, abandoned, expanded)
- /spawn command is invoked with a valid task number

---

## Execution Flow

### Stage 1: Parse Delegation Context

Parse inputs from the /spawn command:

```bash
# Extract from delegation context
task_number=$1
session_id="$2"
blocker_prompt="$3"  # May be empty

# Lookup task data
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  echo "Error: Task $task_number not found"
  exit 1
fi

# Extract fields
project_name=$(echo "$task_data" | jq -r '.project_name')
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
description=$(echo "$task_data" | jq -r '.description // ""')
parent_topic=$(echo "$task_data" | jq -r '.topic // ""')  # Inherited by spawned tasks
```

**Mode B Fallback Picker**: If `parent_topic` is empty, the parent task has no topic. Show a full Mode A interactive picker to let the user assign one now (which will also be inherited by spawned tasks):

```bash
if [[ -z "$parent_topic" ]]; then
  # Get existing active topics from state.json
  mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
  # Show Mode A picker (existing topics + "New topic..." + "Skip (no topic)")
fi
```

AskUserQuestion:
```json
{
  "question": "Assign a topic to this task (will be inherited by spawned tasks)?",
  "header": "Topic",
  "multiSelect": false,
  "options": ["<existing-topic-1>", "<existing-topic-2>", "New topic...", "Skip (no topic)"]
}
```

- If user selects an existing topic → `parent_topic="$selected"`
- If user selects "New topic..." → show free-text follow-up and capture as `parent_topic`
- If user selects "Skip (no topic)" → `parent_topic=""` (no topic assigned)

---

### Stage 2: Preflight Status Update

Determine spawn type and preserve original status before updating.

**Spawn type detection**:
- If `status` is `blocked`, `implementing`, or `partial` -> Blocker-driven spawn
- If `status` is any other non-terminal state -> Holistic decomposition

**Note**: `[BLOCKED]` means "has unmet dependencies", not "encountered an error". The parent task transitions to `blocked` because it now depends on spawned subtasks.

**Update state.json** (preserve `previous_status`):
```bash
padded_num=$(printf "%03d" "$task_number")
previous_status=$(echo "$task_data" | jq -r '.status')

jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "blocked" \
   --arg prev "$previous_status" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    previous_status: $prev,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 3: (Removed — state.json is authoritative for status)

The state.json update in Stage 2 already sets status to "blocked". TODO.md will be regenerated via generate-todo.sh in Stage 14b after all task writes complete.

---

### Stage 4: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-spawn",
  "task_number": ${task_number},
  "operation": "spawn",
  "reason": "Postflight pending: task creation, dependency linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 5: Prepare Delegation Context

Find the latest plan path (if exists):

```bash
plan_path=""
if [ -d "specs/${padded_num}_${project_name}/plans" ]; then
  plan_path=$(ls -t "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | head -1)
fi
```

Determine analysis mode for the agent:

```bash
analysis_mode="holistic"
if [ "$status" = "blocked" ] || [ "$status" = "implementing" ] || [ "$status" = "partial" ] || [ -n "$blocker_prompt" ]; then
    analysis_mode="blocker"
fi
```

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 2,
  "delegation_path": ["orchestrator", "spawn", "skill-spawn"],
  "timeout": 1800,
  "task_number": N,
  "task_data": {
    "project_number": N,
    "project_name": "{slug}",
    "status": "blocked",
    "task_type": "{task_type}",
    "description": "{description}",
    "effort": "{effort}"
  },
  "blocker_prompt": "{optional user description}",
  "plan_path": "{path to latest plan or null}",
  "analysis_mode": "blocker" | "holistic",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 6: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "spawn-agent"
  - prompt: [Include task_number, task_data, blocker_prompt, plan_path, metadata_file_path, session_id]
  - description: "Analyze blocker for task {N} and propose new tasks"
```

**DO NOT** use `Skill(spawn-agent)` - this will FAIL.

The subagent will:
- Load task context and plan
- Analyze the blocker and identify root cause
- Propose minimal new tasks with dependencies
- Write blocker analysis report
- Write `.spawn-return.json` with task definitions
- Return a brief text summary (NOT JSON)

---

### Stage 6b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 6b). Do NOT skip these stages for any reason.

### Stage 7: Read Return Metadata

Read the spawn return file:

```bash
spawn_file="specs/${padded_num}_${project_name}/.spawn-return.json"

if [ -f "$spawn_file" ] && jq empty "$spawn_file" 2>/dev/null; then
    new_tasks=$(jq -r '.new_tasks' "$spawn_file")
    task_count=$(jq '.new_tasks | length' "$spawn_file")

    if [ "$task_count" -eq 0 ]; then
        echo "Spawn cancelled: no tasks selected."
        # Cleanup and restore parent status if needed
        rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
        rm -f "specs/${padded_num}_${project_name}/.spawn-return.json"
        exit 0
    fi

    dependency_order=$(jq -r '.dependency_order' "$spawn_file")
    analysis_summary=$(jq -r '.analysis_summary' "$spawn_file")
    report_path=$(jq -r '.report_path' "$spawn_file")
else
    echo "Error: Invalid or missing spawn return file"
    exit 1
fi
```

---

### Stage 8: Get Next Task Numbers

Get the next available task numbers from state.json:

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)

# Calculate task numbers for each new task based on dependency_order
# First task gets next_num, second gets next_num+1, etc.
```

---

### Stage 9: Apply Topological Sort (Kahn's Algorithm)

The agent provides `dependency_order` which is already topologically sorted (foundational tasks first). Map internal indices to actual task numbers:

```bash
# Example: dependency_order = [0, 1] means task at index 0 is foundational
# If next_num = 242:
#   - Index 0 -> Task 242 (foundational)
#   - Index 1 -> Task 243 (depends on 242)

# Build index->task_number mapping
declare -A task_num_map
order_idx=0
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    task_num_map[$idx]=$((next_num + order_idx))
    order_idx=$((order_idx + 1))
done
```

---

### Stage 10: Create New Task Directories

For each new task, create directory structure:

```bash
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}
    new_padded=$(printf "%03d" "$new_task_num")

    # Get task data from spawn return
    task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$spawn_file")
    task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')

    # Create directory with research artifact stub
    mkdir -p "specs/${new_padded}_${task_slug}/reports"

    # Copy spawn analysis as initial research for first task
    # (or create stub pointing to parent's spawn analysis)
done
```

---

### Stage 11: Update state.json with New Tasks

Insert new tasks in topological order (foundational first):

```bash
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}

    # Extract task fields
    task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$spawn_file")
    task_desc=$(jq -r --argjson i "$idx" '.new_tasks[$i].description' "$spawn_file")
    task_effort=$(jq -r --argjson i "$idx" '.new_tasks[$i].effort' "$spawn_file")
    task_lang=$(jq -r --argjson i "$idx" '.new_tasks[$i].task_type' "$spawn_file")
    internal_deps=$(jq -r --argjson i "$idx" '.new_tasks[$i].dependencies' "$spawn_file")

    # Convert internal deps to task numbers
    resolved_deps="[]"
    for dep_idx in $(echo "$internal_deps" | jq -r '.[]'); do
        dep_num=${task_num_map[$dep_idx]}
        resolved_deps=$(echo "$resolved_deps" | jq --argjson n "$dep_num" '. + [$n]')
    done

    # Create task slug
    task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')

    # Add to state.json (inherit parent topic if available)
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson num "$new_task_num" \
       --arg name "$task_slug" \
       --arg desc "$task_desc" \
       --arg effort "$task_effort" \
       --arg lang "$task_lang" \
       --argjson deps "$resolved_deps" \
       --argjson parent "$task_number" \
       --arg topic "$parent_topic" \
       --arg report "$report_path" \
      '.active_projects += [{
        "project_number": $num,
        "project_name": $name,
        "status": "researched",
        "task_type": $lang,
        "description": $desc,
        "effort": $effort,
        "parent_task": $parent,
        "topic": (if ($topic == "") then null else $topic end),
        "dependencies": $deps,
        "created": $ts,
        "last_updated": $ts,
        "artifacts": [{"type": "research", "path": $report, "summary": "Spawn analysis from parent task"}]
      } | if .topic == null then del(.topic) else . end]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
done

# Update next_project_number
jq --argjson next "$((next_num + task_count))" \
  '.next_project_number = $next' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 12: (Removed — state.json is authoritative for task entries)

The state.json updates in Stage 11 already write all task data. TODO.md will be regenerated via generate-todo.sh in Stage 14b after all task writes complete.

---

### Stage 13: Update Parent Task Dependencies

Add new task numbers to parent task's dependencies in state.json:

```bash
# Build array of new task numbers
new_task_nums="[]"
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_nums=$(echo "$new_task_nums" | jq --argjson n "${task_num_map[$idx]}" '. + [$n]')
done

# Update parent task dependencies (use "| not" pattern for Issue #1132)
jq --argjson new_deps "$new_task_nums" \
   --argjson num "$task_number" \
  '(.active_projects[] | select(.project_number == $num) | .dependencies) =
   ((.active_projects[] | select(.project_number == $num) | .dependencies) // [] + $new_deps)' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 14: (Removed — state.json is authoritative for dependencies)

The state.json update in Stage 13 already writes the dependencies array. TODO.md will be regenerated via generate-todo.sh in Stage 14b after all task writes complete.

---

### Stage 14a: Assign Topics via manage-topics.sh (Non-Blocking)

For each new task created in Stage 11, assign the inherited `parent_topic` via `manage-topics.sh set`. The `set` subcommand updates both the task's `topic` field and the `active_topics` array atomically (must be called AFTER the task entry exists in state.json from Stage 11):

```bash
# Call set for each new task (parent_topic already written to each task entry in Stage 11)
if [[ -n "$parent_topic" ]]; then
  for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}
    bash .claude/scripts/manage-topics.sh set "$new_task_num" "$parent_topic" \
      2>/dev/null || echo "Warning: manage-topics.sh set failed for task $new_task_num (non-fatal)" >&2
  done
fi
```

---

### Stage 14b: Regenerate TODO.md (Non-Blocking)

After all state.json writes are complete (parent status blocked, new tasks, parent dependencies), regenerate the entire TODO.md from state.json. This single call replaces all direct TODO.md writes:

```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

---

### Stage 15: Git Commit

Commit all changes with session ID:

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: spawn {M} tasks to resolve blocker

Session: {session_id}

EOF
)"
```

Commit failure is non-blocking (log and continue).

---

### Stage 16: Cleanup

Remove temporary files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.spawn-return.json"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 17: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Spawned {M} tasks to unblock task {N}:
- Task #{X}: {title} (no dependencies)
- Task #{Y}: {title} (depends on #{X})
- Parent task #{N} now depends on: #{X}, #{Y}
- Status: Parent [BLOCKED], spawned tasks [RESEARCHED]
- Next: /plan {first_spawned_task_num}
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found or status invalid.

### Spawn Return File Missing
If subagent didn't write spawn return file:
1. Keep status as "blocked"
2. Do not cleanup postflight marker
3. Report error to user

### Empty Task Selection (Cancelled Spawn)
If user selected no tasks in holistic mode:
1. `task_count` will be 0
2. Exit gracefully with informative message
3. Cleanup temporary files
4. Parent task remains `[BLOCKED]` (it still has the dependency intent)

### Invalid Dependency Graph
If dependency_order contains cycles or invalid indices:
1. Log error
2. Fall back to sequential ordering by index
3. Report warning to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### jq Parse Failure
If jq commands fail (Issue #1132):
1. Log error
2. Retry using "| not" pattern
3. See jq-escaping-workarounds.md

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Perform research or analysis** - Analysis is done by agent
2. **Make decisions about task breakdown** - Agent decides decomposition
3. **Write implementation files** - Only state files in specs/
4. **Modify files outside specs/** - All changes confined to specs/

The postflight phase is LIMITED TO:
- Reading agent spawn return file
- Creating task directories
- Updating state.json with new tasks
- Updating TODO.md with new task entries
- Updating parent task dependencies
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The structured data is processed internally.

Example successful return:
```
Spawned 2 tasks to unblock task 241:
- Task #242: Create state validation utilities (no dependencies)
- Task #243: Implement recovery workflow (depends on #242)
- Parent task #241 now depends on: #242, #243
- Status: Parent [BLOCKED], spawned tasks [RESEARCHED]
- Next: /plan 242
```

Example partial return:
```
Spawn partially completed for task 241:
- Blocker analyzed, 2 tasks proposed
- Task creation failed at Task #243
- Partial state may exist, run /task --sync to reconcile
```
