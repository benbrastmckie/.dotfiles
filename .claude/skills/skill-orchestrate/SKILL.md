---
name: skill-orchestrate
description: Autonomous state machine that drives a task through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases. Invoke for /orchestrate command.
allowed-tools: Agent, Bash, Read, Edit
---

# Orchestrate Skill

Fire-and-forget autonomous loop implementing the 10-state task lifecycle state machine.
Drives research, planning, implementation, and blocker escalation without user interaction.

## Context References

Architecture documentation (load as needed):
- `.claude/docs/architecture/orchestrate-state-machine.md` - Complete state table and transition diagram
- `.claude/docs/architecture/handoff-schema.md` - Orchestrator handoff JSON schema

Infrastructure (source as needed):
- `.claude/scripts/skill-base.sh` - Shared skill lifecycle functions

---

## Execution Flow

### Stage 0: Multi-Task Mode Detection

Parse `multi_task_mode` from the delegation context. If true, branch to multi-task stages (MT-1 through MT-5) in the **Multi-Task Mode** section below. If false or absent, fall through to Stage 1 (single-task mode).

Read from delegation context:
- `multi_task_mode` (default: false)
- `session_id`
- `focus_prompt` (default: "")
- `lit_flag` (default: "false")

If `multi_task_mode` is true: skip Stages 1-8 entirely and proceed to Stage MT-1.

---

### Stage 1: Input Validation

Read from delegation context:
- `task_number` (from `task_context.task_number`)
- `session_id`, `focus_prompt`, `lit_flag`

Resolve from `specs/state.json`:
```bash
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DATA=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)
```

If `TASK_DATA` is empty: exit with error "Task $task_number not found in state.json".

Extract: `PROJECT_NAME`, `TASK_TYPE` (default: "general"), `DESCRIPTION`, `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"`.

### Stage 1b: Resolve Task-Type Routing

Map task_type to the correct research and implementation agents using extension manifests.

```bash
# Resolve agents by task_type — consult extension manifests for non-core types
case "$TASK_TYPE" in
  lean4|lean)
    RESEARCH_AGENT="lean-research-agent"
    IMPLEMENT_AGENT="lean-implementation-agent"
    ;;
  neovim)
    RESEARCH_AGENT="neovim-research-agent"
    IMPLEMENT_AGENT="neovim-implementation-agent"
    ;;
  nix)
    RESEARCH_AGENT="nix-research-agent"
    IMPLEMENT_AGENT="nix-implementation-agent"
    ;;
  *)
    RESEARCH_AGENT="general-research-agent"
    IMPLEMENT_AGENT="general-implementation-agent"
    ;;
esac
echo "[orchestrate] Task type: $TASK_TYPE → research=$RESEARCH_AGENT, implement=$IMPLEMENT_AGENT"
```

**Extension resolution**: If a task_type is not in the case table above, check for an extension manifest:
```bash
manifest=".claude/extensions/${TASK_TYPE}/manifest.json"
if [ -f "$manifest" ]; then
  ext_research=$(jq -r ".routing.research[\"$TASK_TYPE\"] // empty" "$manifest")
  ext_implement=$(jq -r ".routing.implement[\"$TASK_TYPE\"] // empty" "$manifest")
  # Map skill names to agent names (skill-X-Y -> X-Y-agent)
  if [ -n "$ext_research" ]; then
    RESEARCH_AGENT=$(echo "$ext_research" | sed 's/^skill-//' | sed 's/$/-agent/')
  fi
  if [ -n "$ext_implement" ]; then
    IMPLEMENT_AGENT=$(echo "$ext_implement" | sed 's/^skill-//' | sed 's/$/-agent/')
  fi
fi
```

### Stage 2: Preflight — Loop Guard

Create or read the loop guard file. This tracks cycle count across conversational turns.

```bash
MAX_CYCLES=5
loop_guard_file="${TASK_DIR}/.orchestrator-loop-guard"
handoff_file="${TASK_DIR}/.orchestrator-handoff.json"

mkdir -p "$TASK_DIR"

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  # Resume: read existing guard
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES"
else
  # Fresh start: create guard
  cycle_count=0
  jq -n \
    --arg session_id "$session_id" \
    --argjson max_cycles "$MAX_CYCLES" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "session_id": $session_id,
      "cycle_count": 0,
      "max_cycles": $max_cycles,
      "current_state": "reading",
      "started": $started,
      "last_updated": $started
    }' > "$loop_guard_file"
  echo "[orchestrate] Starting fresh — MAX_CYCLES=$MAX_CYCLES"
fi

# Blocker escalation counter (reset each /orchestrate invocation)
blocker_escalation_count=0
MAX_BLOCKER_ESCALATIONS=2

# Drift detection constants (reset each /orchestrate invocation)
drift_inspection_count=0
MAX_DRIFT_INSPECTIONS=1
DRIFT_COMPLETION_THRESHOLD=0.70
DRIFT_REVISION_THRESHOLD=0.30
```

### Stage 3: State Machine Loop

The loop runs until a terminal condition is reached or MAX_CYCLES is hit.

```
while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do
```

At the top of each iteration:

**3a. Read current task status**

```bash
current_status=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .status' \
  specs/state.json)
echo "[orchestrate] Cycle $((cycle_count + 1))/$MAX_CYCLES — status: $current_status"
```

**3b. Update loop guard with current state**

```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

**3c. Dispatch by state** (see State Handlers in Stage 4)

---

### Stage 4: State Handlers

#### State: `not_started` or `not started`

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Research task $task_number: $DESCRIPTION" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: false, lit_flag }` |

After Agent tool returns: read handoff (Stage 5). Increment cycle_count.

#### State: `researching`

In-flight state (another session is actively researching). Exit with warning.

```
echo "[orchestrate] WARNING: Task $task_number is currently being researched in another session."
echo "Wait for the research to complete, then run /orchestrate $task_number again."
EXIT (partial)
```

#### State: `researched`

Read research artifact path from state.json:
```bash
research_artifact=$(jq -r --argjson num "$task_number" \
  '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | select(.type == "report")] | .[0].path // ""' \
  specs/state.json)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"planner-agent"` |
| `prompt` | "Create implementation plan for task $task_number" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: false, lit_flag }` |

After Agent tool returns: read handoff. Increment cycle_count.

#### State: `planning`

In-flight state. Exit with warning (same pattern as `researching`).

#### State: `planned` or `implementing`

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, lit_flag }` |

After Agent tool returns: read handoff. Increment cycle_count.

#### State: `partial`

Read `.orchestrator-handoff.json` to determine sub-state:

```bash
handoff=$(cat "$handoff_file" 2>/dev/null || echo '{}')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
blocker_count=$(echo "$blockers" | jq 'length')
```

**Sub-state: continuation available** (continuation != null AND has handoff_path):

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Resume implementation for task $task_number from continuation handoff" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, continuation_context, lit_flag }` |

**Sub-state: blockers present** (blocker_count > 0):

Invoke blocker escalation (Stage 6). Increment cycle_count after escalation.

**Sub-state: no handoff, no blockers** (cycle limit or stuck):

```
echo "[orchestrate] Task $task_number in partial state with no continuation and no blockers."
echo "Cycle $cycle_count/$MAX_CYCLES consumed. Run /orchestrate $task_number to retry or /implement $task_number for manual resume."
EXIT (partial, cycle_count)
```

#### State: `blocked`

Read blockers from state.json (not handoff — task was blocked outside orchestrator context):

```bash
blocker_desc=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .blockers // "Unspecified blocker"' \
  specs/state.json)
```

Invoke blocker escalation (Stage 6) with blocker_desc.

#### State: `completed`

```
echo "[orchestrate] Task $task_number completed successfully."
# Clean up loop guard
rm -f "$loop_guard_file"
EXIT (success)
```

#### States: `abandoned`, `expanded`

```
echo "[orchestrate] Task $task_number is in terminal state [$current_status]. No action taken."
EXIT (no-op)
```

#### Unknown state

```
echo "[orchestrate] WARNING: Unrecognized state '$current_status' for task $task_number."
EXIT (partial)
```

---

### Stage 5: Handoff Reading (after each dispatch)

After every Agent tool invocation, read the orchestrator handoff to learn the outcome.
Never read the full research report, plan, or implementation summary — only the handoff.

```bash
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
  echo "This may mean orchestrator_mode was not propagated correctly."
  # Increment cycle and continue — state.json may still have been updated
else
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  blockers=$(echo "$handoff" | jq -c '.blockers // []')
  continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
  next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  echo "[orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
  [ "$phases_total" -gt 0 ] && echo "[orchestrate] Phase progress: $phases_completed/$phases_total"

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork)
  if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
    # Use awk for floating-point comparison (bash only does integer math)
    completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
    is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
    if [ "$is_below_threshold" = "yes" ]; then
      echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
      invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
    fi
  fi

  # Postflight status update: trigger state.json + TODO.md Task Order regeneration
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      ;;
    *)
      echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac

  # Artifact linking: extract artifact path/type from handoff and link in TODO.md + state.json
  handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
  handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
  handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
  if [ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]; then
    case "$handoff_artifact_type" in
      report)
        field_name='**Research**'
        next_field='**Plan**'
        ;;
      plan)
        field_name='**Plan**'
        next_field='**Description**'
        ;;
      summary)
        field_name='**Summary**'
        next_field='**Description**'
        ;;
      *)
        field_name='**Summary**'
        next_field='**Description**'
        ;;
    esac
    skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
      "$handoff_artifact_summary" "$field_name" "$next_field"
  fi
fi

# Increment cycle_count
cycle_count=$((cycle_count + 1))
```

---

### Stage 5a: Drift Inspection

Called from Stage 5 when phase completion is below DRIFT_COMPLETION_THRESHOLD and dispatch_status is "partial".
Capped at MAX_DRIFT_INSPECTIONS=1 per /orchestrate invocation.

1. If `drift_inspection_count >= MAX_DRIFT_INSPECTIONS`: log warning and return (skip inspection).

2. Increment `drift_inspection_count`. Log: "[orchestrate] Drift inspection attempt N/MAX".

3. Invoke the Agent tool (fork — to inspect the plan file):

| Field | Value |
|-------|-------|
| `subagent_type` | `"fork"` |
| `prompt` | "Read the plan file at '$plan_path'. Count: (1) total checklist items matching '- [ ]' or '- [x]', (2) completed items matching '- [x]', (3) deviation annotations matching '*(deviation:'. Calculate drift_pct as: deviation_count / max(total_items, 1). Write compact JSON to '${TASK_DIR}/.drift-inspection.json' with fields: drift_pct (float), deviation_count (int), total_items (int), completed_items (int), summary (string, one sentence). Return a brief summary of findings." |
| `context` | `{ task_number, session_id, plan_path, orchestrator_mode: false }` |

4. After Agent tool returns: read `${TASK_DIR}/.drift-inspection.json`.
   - If file exists: extract `drift_pct` and `drift_summary`.
   - If file missing: log warning, set `drift_pct=0`, `drift_summary="Inspection output missing"`.

5. If `drift_pct > DRIFT_REVISION_THRESHOLD`: trigger plan revision:

   Invoke the Agent tool (reviser):

   | Field | Value |
   |-------|-------|
   | `subagent_type` | `"reviser-agent"` |
   | `prompt` | "Revise the implementation plan for task $task_number to address plan drift (drift_pct=$drift_pct). Summary: $drift_summary" |
   | `context` | `{ task_number, session_id, plan_path, revision_reason: "drift", drift_pct, orchestrator_mode: false }` |

   After Agent tool returns: read handoff to confirm revision.

6. If `drift_pct <= DRIFT_REVISION_THRESHOLD`: log "Drift check passed. Continuing."

---

### Stage 6: Blocker Escalation (5-Step Sequence)

Called when: `partial` state with non-empty blockers, or `blocked` state.
Capped at MAX_BLOCKER_ESCALATIONS=2 per /orchestrate invocation.

**If `blocker_escalation_count >= MAX_BLOCKER_ESCALATIONS`**: log error and return. Manual intervention required. Suggest: (1) `/research $task_number`, (2) `/revise $task_number`, (3) `/implement $task_number`.

Increment `blocker_escalation_count`. Log escalation attempt and blocker description.

**Step 1: DETECT** — blocker_desc is passed in by caller (from handoff or state.json).

**Step 2: RESEARCH FORK** — Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"fork"` |
| `prompt` | "Research this specific blocker for task $task_number: $blocker_desc. Find the root cause and a concrete solution path." |
| `context` | `{ task_number, session_id, blocker: blocker_desc, orchestrator_mode: false }` |

After Agent tool returns: read `$handoff_file` for research findings.

**Step 3: READ FINDINGS** — From handoff:
```bash
findings_summary=$(jq -r '.summary // "No findings"' "$handoff_file")
findings_artifact=$(jq -r '.artifacts[0].path // ""' "$handoff_file")
```

**Step 4: REVISE PLAN** — Read latest plan path, then invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"reviser-agent"` |
| `prompt` | "Revise the implementation plan for task $task_number to address this blocker: $blocker_desc. Research findings: $findings_summary" |
| `context` | `{ task_number, session_id, research_findings: findings_summary, plan_path, orchestrator_mode: false }` |

After Agent tool returns: read handoff to confirm revision.

**Step 5: RE-DISPATCH IMPLEMENT** — Read revised plan path, then invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the revised plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, session_id, orchestrator_mode: true, plan_path: revised_plan_path }` |

After Agent tool returns: read handoff.

---

### Stage 7: Loop Guard Update (end of each cycle)

After each cycle (whether dispatch succeeded or failed):

```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

If MAX_CYCLES reached (cycle_count >= MAX_CYCLES):

```
echo "[orchestrate] MAX_CYCLES ($MAX_CYCLES) reached for task $task_number."
echo "Current state: $current_status. Run /orchestrate $task_number to continue."
EXIT (partial)
```

---

### Stage 8: Postflight

On clean exit (task completed or terminal state):

```bash
# Remove loop guard on success
rm -f "$loop_guard_file"
# Clean up drift inspection artifact if present
rm -f "${TASK_DIR}/.drift-inspection.json"
echo "[orchestrate] Task $task_number: orchestration complete."
echo "Final status: $current_status | Cycles used: $cycle_count/$MAX_CYCLES"
```

On partial exit (MAX_CYCLES, in-flight warning, escalation cap):

```bash
# Preserve loop guard for next /orchestrate invocation
echo "[orchestrate] Task $task_number: orchestration paused."
echo "Status: $current_status | Cycles: $cycle_count/$MAX_CYCLES | Run /orchestrate $task_number to continue."
```

Write metadata file.

On clean exit:

```bash
mkdir -p "${TASK_DIR}/summaries"
jq -n \
  --arg status "completed" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '{
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "${TASK_DIR}/.return-meta.json"
```

On partial exit:

```bash
mkdir -p "${TASK_DIR}/summaries"
jq -n \
  --arg status "partial" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '{
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "${TASK_DIR}/.return-meta.json"
```

---

## Multi-Task Mode

Entered when `multi_task_mode=true` in the delegation context (detected in Stage 0).
All single-task stages (1-8) are skipped. The skill receives a pre-computed wave schedule
from `orchestrate.md` and manages all tasks in a single orchestrator instance.

### Stage MT-1: Parse Multi-Task Context

Read from delegation context:
- `task_numbers` — array of task numbers to manage
- `dependency_graph` — map of task_number -> [predecessor_task_numbers]
- `waves` — pre-computed topological wave schedule
- `session_id`, `lit_flag`

Compute: `task_count = length(task_numbers)`, `MAX_CYCLES_MT = min(task_count * 5, 25)`.

Initialize `mt_state_file = "specs/.orchestrator-multi-state.json"` with fields: `session_id`, `task_numbers`, `waves`, `max_cycles`, `cycle_count: 0`, `failed_tasks: []`, `completed_tasks: []`, `current_statuses: {}`, `task_dirs: {}`, `research_agents: {}`, `implement_agents: {}`.

### Stage MT-2: Build Per-Task Routing Table

For each task in `task_numbers`, read `state.json` to get `task_type`, `project_name`. Compute `task_dir = "specs/${padded}_${project_name}"`. Resolve `research_agent` and `implement_agent` using the same routing table as Stage 1b:

| task_type | research_agent | implement_agent |
|-----------|----------------|-----------------|
| `lean4` / `lean` | `lean-research-agent` | `lean-implementation-agent` |
| `neovim` | `neovim-research-agent` | `neovim-implementation-agent` |
| `nix` | `nix-research-agent` | `nix-implementation-agent` |
| *(default)* | `general-research-agent` | `general-implementation-agent` |

Check `.claude/extensions/${task_type}/manifest.json` for override routing. Populate all per-task maps into `mt_state_file`.

### Stage MT-3: Lifecycle-Cycling Loop

Initialize `cycle_count = 0`. Loop while `cycle_count < MAX_CYCLES_MT`:

1. **Status refresh**: For each task in `task_numbers`, read current status from `state.json` and update `mt_state_file.current_statuses`.

2. **All-terminal check**: If every task is in `{completed, abandoned, expanded}` or in `failed_tasks` — break loop (exit success or partial).

3. **Build eligible_tasks**: For each task, include it if ALL of the following are true:
   - Status is NOT `{completed, abandoned, expanded}` and NOT in `failed_tasks`
   - Status is NOT `{researching, planning}` (in-flight from prior cycle)
   - All predecessors from `dependency_graph[task_num]` are in terminal state or `failed_tasks`
   
   If a predecessor is in `failed_tasks`: mark this task in `failed_tasks` with status `blocked` and skip it.
   If a predecessor is still in-progress: skip this task (wait for next cycle).

4. **No-eligible circuit breaker**: If `eligible_tasks` is empty, log warning with list of stuck tasks and break loop (exit partial).

5. **Dispatch** (Stage MT-4) — see below.

6. **Increment cycle_count**, update `mt_state_file.cycle_count`. If `cycle_count >= MAX_CYCLES_MT`: log partial status and break.

### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight

> **BATCHING RULE**: ALL Agent tool calls for the current cycle's dispatch batch MUST be issued in a SINGLE orchestrator message with multiple tool-use content blocks. Do NOT issue calls across multiple messages — Claude Code processes all calls in a single message concurrently; multiple messages force sequential execution.

> **COMPLETION SEQUENCING**: After ALL Agent tool calls complete (Claude Code returns control after all calls in the single message finish), read handoffs for every dispatched task. Do NOT read handoffs interleaved with dispatches.

**Phase grouping** — Classify each eligible task by its current status:

| Task status | Group | Agent |
|-------------|-------|-------|
| `not_started` | research_tasks | `research_agents[task_num]` |
| `researched` | plan_tasks | `planner-agent` |
| `planned`, `implementing` | implement_tasks | `implement_agents[task_num]` |
| `partial` with continuation | implement_tasks | `implement_agents[task_num]` |
| `partial` with blockers | failed_tasks (mark blocked) | — |
| `partial` with no handoff | implement_tasks | `implement_agents[task_num]` |
| `blocked`, `researching`, `planning`, unknown | skip | — |

**Dispatch all groups in ONE message**:

For each task in `research_tasks`:
- Invoke Agent tool: `subagent_type = research_agents[task_num]`, prompt = "Research task $task_num: $description", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: false, lit_flag }`

For each task in `plan_tasks`:
- Read `research_artifact` path from `state.json` artifacts (type=report)
- Invoke Agent tool: `subagent_type = "planner-agent"`, prompt = "Create implementation plan for task $task_num", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", research_artifacts: [research_artifact], orchestrator_mode: false, lit_flag }`

For each task in `implement_tasks`:
- Read `plan_path` from `task_dir/plans/` (latest .md)
- Read `continuation` from `task_dir/.orchestrator-handoff.json` (or null)
- Invoke Agent tool: `subagent_type = implement_agents[task_num]`, prompt = "Implement task $task_num following the plan", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: true, plan_path, continuation_context: continuation, lit_flag }`

**After all Agent tool calls complete**, read handoffs and run per-task postflight for each dispatched task:

For each task in `research_tasks + plan_tasks + implement_tasks`:
1. Read `task_dir/.orchestrator-handoff.json`. If missing: mark task in `failed_tasks`, skip.
2. Extract `dispatch_status`, `dispatch_summary`, artifact path/type/summary.
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → `skill_postflight_update task_num "research" "${session_id}_${task_num}" researched`
   - `dispatch_status = "planned"` → `skill_postflight_update task_num "plan" "${session_id}_${task_num}" planned`
   - `dispatch_status = "implemented"` → `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented`
   - Other → no postflight update
4. Call `skill_link_artifacts` if artifact path is present (same field mapping as Stage 5).
5. Re-read fresh status from `state.json` (postflight may have updated it). Update `mt_state_file.current_statuses[task_num]`:
   - If `fresh_status = "completed"`: also add to `completed_tasks`.
   - If `dispatch_status` is `"failed"` or `"blocked"`: add to `failed_tasks`.
   - Otherwise: set `current_statuses[task_num] = fresh_status`.

### Stage MT-5: Multi-Task Postflight

After the lifecycle-cycling loop exits (all terminal, no eligible tasks, or MAX_CYCLES_MT reached):

1. Read from `mt_state_file`: `completed_tasks`, `failed_tasks`, `cycles_used`, counts.
2. Determine `exit_status`:
   - `failed_count == 0` → `"completed"` (remove `mt_state_file`)
   - `failed_count > 0` → `"partial"` (preserve `mt_state_file` for diagnostics)
3. Write `specs/.return-meta-multi.json`:
```bash
jq -n \
  --arg status "$exit_status" \
  --argjson tasks_completed "$completed_tasks" \
  --argjson tasks_failed "$failed_tasks" \
  --argjson cycles_used "$cycles_used" \
  '{
    "status": $status,
    "metadata": {
      "tasks_completed": $tasks_completed,
      "tasks_failed": $tasks_failed,
      "cycles_used": $cycles_used,
      "multi_task_mode": true
    }
  }' > "specs/.return-meta-multi.json"
```

---

## MUST NOT (Context Flatness Constraint)

This skill MUST NOT:

1. **Read research reports** (`reports/*.md`) during the state machine loop
2. **Read plan files** (`plans/*.md`) during the state machine loop
3. **Read implementation summaries** (`summaries/*.md`) during the state machine loop
4. **Read continuation handoff files** (`handoffs/*.md`) — pass the path, not the content

The ONLY file read after each dispatch is `.orchestrator-handoff.json` (≤400 tokens).
This ensures context grows by only ~450 tokens per cycle regardless of artifact complexity.

## Skill-to-Agent Mapping

| Operation | `subagent_type` | Notes |
|-----------|----------------|-------|
| Research dispatch | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: false` |
| Plan dispatch | `"planner-agent"` | Fresh context; `orchestrator_mode: false` |
| Implement dispatch | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Blocker research | `"fork"` | Inherits parent cache; fast blocker research |
| Plan revision (blocker) | `"reviser-agent"` | Fresh context; `orchestrator_mode: false` |
| Drift inspection | `"fork"` | Inherits parent cache; reads plan file, writes .drift-inspection.json |
| Plan revision (drift) | `"reviser-agent"` | Triggered when drift_pct > DRIFT_REVISION_THRESHOLD |

Default agents: `general-research-agent`, `general-implementation-agent`. Extension agents resolved in Stage 1b.
