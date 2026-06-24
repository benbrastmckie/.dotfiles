# /orchestrate State Machine Specification

**Status**: Current architecture — designed by Task 592, implemented by Task 596.

**See Also**: `architecture-spec.md` (Component 3), `handoff-schema.md`

---

## Overview

The `/orchestrate` command runs a fire-and-forget autonomous loop that drives a task through its
full lifecycle (research → plan → implement → complete) without user confirmation between phases.
The state machine is implemented inside `skill-orchestrate` (Pattern C: Orchestrator/Routing skill).

---

## Complete State Table

| State | Detected By | Action | Success Next | Failure Next |
|-------|-------------|--------|--------------|--------------|
| `not_started` | `state.json status = "not_started"` | `dispatch(research, task_n)` | `researched` | increment cycle, loop |
| `researching` | `status = "researching"` | Wait / re-check (status update in flight) | — | exit with warning |
| `researched` | `status = "researched"` | `dispatch(plan, task_n)` | `planned` | increment cycle, loop |
| `planning` | `status = "planning"` | Wait / re-check | — | exit with warning |
| `planned` | `status = "planned"` | `dispatch(implement, task_n, orchestrator_mode=true)` | `implemented` | check blockers |
| `implementing` | `status = "implementing"` | `dispatch(implement, task_n, orchestrator_mode=true)` — resume | `implemented` | check blockers |
| `partial` (with handoff) | `.orchestrator-handoff.json` has `continuation_context.handoff_path` | `dispatch(implement, task_n, continuation_context, orchestrator_mode=true)` | `implemented` | check blockers |
| `partial` (with blockers) | `.orchestrator-handoff.json` has non-empty `blockers` array | `dispatch_blocker_escalation()` → revise → implement | `implemented` | increment cycle |
| `partial` (no handoff, cycle limit) | `cycle_count >= MAX_CYCLES` | Report state, exit | — | — |
| `blocked` | `status = "blocked"` | Read blockers from `state.json`, `dispatch_blocker_escalation()` | `planned` | increment cycle |
| `completed` | `status = "completed"` | Report success, exit | — | — |
| `abandoned` | `status = "abandoned"` | Report abandoned status, exit | — | — |
| `expanded` | `status = "expanded"` | Report expanded status, exit | — | — |

---

## State Transition Diagram (ASCII)

```
               ┌─────────────────────────────────────────┐
               │           /orchestrate start             │
               └─────────────────────────────────────────┘
                                    │
                             read state.json
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
         not_started           researched             planned /
              │                     │               implementing /
              ▼                     ▼                  partial
         dispatch                dispatch                 │
         research                  plan                   ▼
              │                     │              dispatch implement
              │                     │              (orchestrator_mode)
              └─────────►─────────-─┘                     │
                                                           │
                                        ┌──────────────────┼──────────────────┐
                                        │                  │                  │
                                    success            partial+           partial+
                                        │              handoff            blockers
                                        ▼                  │                  │
                                   completed       re-dispatch            fork research
                                        │          implement               (warm cache)
                                        ▼           with                       │
                                      EXIT       continuation              read findings
                                              context                          │
                                                    │                     dispatch revise
                                                    │                          │
                                                    │                  re-dispatch implement
                                                    │                          │
                                                    └─────────►────────────────┘
                                                                               │
                                                                         cycle_count++
                                                                               │
                                                              ┌────────────────┤
                                                              │                │
                                                       < MAX_CYCLES      >= MAX_CYCLES
                                                              │                │
                                                           loop back         EXIT
                                                          to dispatch      (partial)
```

---

## MAX_CYCLES Enforcement

```bash
MAX_CYCLES=5    # Maximum dispatch cycles per /orchestrate invocation

# Loop guard file: specs/{NNN}_{SLUG}/.orchestrator-loop-guard
# Schema:
{
  "session_id": "sess_...",
  "cycle_count": 2,
  "max_cycles": 5,
  "current_state": "planned",
  "started": "2026-05-22T00:00:00Z",
  "last_updated": "2026-05-22T00:30:00Z"
}
```

The loop guard file is created at the start of an `/orchestrate` invocation and updated after each
dispatch cycle. It persists between conversational turns so a resumed `/orchestrate` invocation
sees the accumulated cycle count.

**On cycle limit**: The task is left in `partial` state. The orchestrator reports: "Task {N} reached
MAX_CYCLES limit. Run `/orchestrate {N}` again to continue, or `/implement {N}` to resume manually."

---

## Blocker Escalation: 5-Step Sequence

When a dispatch returns with non-empty `blockers` in the orchestrator handoff:

```
Step 1: DETECT
  Read .orchestrator-handoff.json
  blockers = jq -c '.blockers // []' handoff.json
  If blockers array is non-empty: escalate=true

Step 2: RESEARCH FORK (subagent_type: "fork")
  blocker_desc = jq -r '.[0].description' blockers
  Invoke Agent tool:
    subagent_type: "fork"
    prompt: "Research this blocker for task $N: $blocker_desc. Find root cause and solution path."
    context: { task_number, session_id, blocker, orchestrator_mode: false }
  Read .orchestrator-handoff.json → research findings

Step 3: READ FINDINGS
  findings = jq -r '.summary' .orchestrator-handoff.json
  artifact = jq -r '.artifacts[0].path' .orchestrator-handoff.json

Step 4: REVISE PLAN
  Invoke Agent tool:
    subagent_type: "reviser-agent"
    prompt: "Revise plan for task $N to address blocker: $blocker_desc. Findings: $findings"
    context: { task_number, session_id, research_findings, plan_path, orchestrator_mode: false }
  Reviser reads current plan + research findings, writes new plan version

Step 5: RE-DISPATCH IMPLEMENT
  Invoke Agent tool:
    subagent_type: $IMPLEMENT_AGENT  (resolved by task_type in Stage 1b)
    prompt: "Implement task $N following the revised plan."
    context: { task_number, session_id, orchestrator_mode: true, plan_path }
  Fresh implementation with revised plan
```

---

## Context Flatness Guarantee

The orchestrator NEVER reads research reports, plan files, or implementation summaries during its
state machine loop. After each dispatch it reads only:

```bash
handoff=$(cat "specs/${padded_num}_${project_name}/.orchestrator-handoff.json")
status=$(echo "$handoff" | jq -r '.status')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
```

The `.orchestrator-handoff.json` file is **≤ 400 tokens**. The orchestrator context grows by
only ~400 tokens per cycle, regardless of the complexity of the delegated work.

---

## Example Flows

### Normal Flow (3 phases, no blockers)

```
Cycle 1: status=not_started → dispatch research
         handoff: {status: "researched", summary: "Found 3 approaches..."}
         state.json: status → researched

Cycle 2: status=researched → dispatch plan
         handoff: {status: "planned", summary: "4-phase plan created..."}
         state.json: status → planned

Cycle 3: status=planned → dispatch implement (orchestrator_mode=true)
         handoff: {status: "implemented", summary: "All 4 phases complete..."}
         state.json: status → completed

EXIT: Task 593 completed successfully.
```

### Partial Recovery Flow

```
Cycle 1: status=planned → dispatch implement (orchestrator_mode=true)
         Agent context exhausted after phase 2
         Agent writes continuation handoff to handoffs/phase-2-handoff-T.md
         handoff: {
           status: "partial",
           continuation_context: {
             handoff_path: "specs/593_.../handoffs/phase-2-handoff-T.md",
             phases_completed: 2,
             phases_total: 4
           }
         }

Cycle 2: read continuation_context from handoff
         dispatch implement with continuation_context embedded
         (orchestrator_mode=true preserved in continuation_context)
         handoff: {status: "implemented", ...}

EXIT: Task 593 completed successfully.
```

### Blocker Escalation Flow

```
Cycle 1: status=planned → dispatch implement (orchestrator_mode=true)
         Implementation stuck: API not responding
         handoff: {
           status: "partial",
           blockers: [{
             description: "API endpoint returns 404; integration pattern unclear",
             phase: "phase-2",
             severity: "hard"
           }]
         }

Cycle 2: BLOCKER ESCALATION
  Step 2: fork research (is_blocker_escalation=true)
          Prompt: "Research: API endpoint 404 — integration pattern for..."
          Returns: {status: "researched", summary: "Found: use /v2 endpoint instead of /v1..."}

  Step 4: dispatch revise
          Prompt: "Revise plan using research findings: [findings text]"
          Returns: new plan version 02_revised-plan.md

  Step 5: re-dispatch implement (orchestrator_mode=true)
          handoff: {status: "implemented", ...}

EXIT: Task 593 completed successfully.
```

---

## MT Mode: Multi-Task Orchestration

MT mode drives multiple tasks through their full lifecycle (research -> plan -> implement -> completed) using a lifecycle-cycling loop with dependency-aware gating and parallel dispatch.

### Lifecycle-Cycling Loop (Stage MT-3)

```
┌──────────────────────────────────────────────────┐
│         MT Lifecycle-Cycling While Loop          │
│                                                  │
│  ┌─────────────────────────────────────────┐     │
│  │ 1. Refresh statuses from state.json     │     │
│  │    for every task in task_numbers[]     │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 2. All-terminal check                   │     │
│  │    all tasks in {completed, abandoned,  │     │─── YES ──► EXIT (success)
│  │    expanded, failed_tasks}?             │     │
│  └──────────────────┬──────────────────────┘     │
│                     │ NO                         │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 3. Build eligible_tasks[]               │     │
│  │    Filter each task:                    │     │
│  │    (a) not terminal                     │     │
│  │    (b) not in-flight (researching,      │     │
│  │        planning)                        │     │
│  │    (c) all predecessors terminal        │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 4. No-eligible circuit breaker          │     │
│  │    eligible_tasks[] is empty?           │     │─── YES ──► EXIT (partial)
│  └──────────────────┬──────────────────────┘     │
│                     │ NO                         │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 5. Phase-aware dispatch (Stage MT-4)    │     │
│  │    Group eligible_tasks by needed phase:│     │
│  │    research_tasks / plan_tasks /        │     │
│  │    implement_tasks                      │     │
│  │    ─────────────────────────────────    │     │
│  │    Issue ALL Agent calls in ONE message │     │
│  │    (concurrent parallel execution)      │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 6. Read handoffs for every dispatched   │     │
│  │    task (after ALL Agents complete)     │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 7. Per-task postflight                  │     │
│  │    skill_postflight_update + artifact   │     │
│  │    linking + multi-state update         │     │
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│  ┌──────────────────▼──────────────────────┐     │
│  │ 8. cycle_count++                        │     │
│  │    MAX_CYCLES_MT guard                  │     │─── HIT ──► EXIT (partial)
│  └──────────────────┬──────────────────────┘     │
│                     │                            │
│                     └──────────────────────────► │
│                        (back to step 1)          │
└──────────────────────────────────────────────────┘
```

### Dependency Gating Model

Tasks progress through lifecycle phases independently. A task becomes eligible when:
1. Its current status is not terminal (`completed`, `abandoned`, `expanded`) and not in `failed_tasks`
2. It is not in an in-flight state from a prior cycle (`researching`, `planning`)
3. All of its predecessors in the dependency graph are in a terminal state

If a predecessor is `failed`, the dependent task is immediately moved to `failed_tasks` with status `blocked`.

If a predecessor is still in-progress (e.g., `researched`, `planned`), the dependent task waits until the next cycle when the predecessor reaches terminal state.

### Exit Conditions

| Condition | Exit Status | Description |
|-----------|-------------|-------------|
| All tasks terminal | `completed` (if 0 failed) or `partial` | Normal completion |
| No eligible tasks | `partial` | Deadlock or all blocked |
| MAX_CYCLES_MT hit | `partial` | Cycle budget exhausted |

`MAX_CYCLES_MT = min(task_count * 5, 25)`

### MT Example Flow: 2 Independent Tasks

```
Initial: Task A (not_started), Task B (not_started)
         Dependency graph: {} (no dependencies between A and B)

--- Cycle 1 ---
Refresh: A=not_started, B=not_started
All-terminal: NO
Eligible: [A, B]  (both not_started, no dependencies)
Dispatch: research A + research B  (ONE message, 2 Agent calls)
After agents complete: read handoffs for A and B
Postflight: A -> researched, B -> researched
cycle_count: 1

--- Cycle 2 ---
Refresh: A=researched, B=researched
All-terminal: NO
Eligible: [A, B]  (researched is not terminal, not in-flight)
Dispatch: plan A + plan B  (ONE message, 2 Agent calls)
After agents complete: read handoffs for A and B
Postflight: A -> planned, B -> planned
cycle_count: 2

--- Cycle 3 ---
Refresh: A=planned, B=planned
All-terminal: NO
Eligible: [A, B]  (planned -> implement)
Dispatch: implement A + implement B  (ONE message, 2 Agent calls)
After agents complete: read handoffs for A and B
Postflight: A -> completed, B -> completed
cycle_count: 3

--- Cycle 4 ---
Refresh: A=completed, B=completed
All-terminal: YES -- break

EXIT: All 2 tasks completed. Cycles used: 3/10.
```
