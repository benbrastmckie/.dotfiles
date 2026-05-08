---
name: spawn-agent
description: Analyzes blocked tasks, researches blockers, and proposes minimal new tasks to overcome the blocker
---

# Spawn Agent

## Overview

Blocker analysis and task decomposition agent for the /spawn workflow. Operates in two modes:

- **Blocker mode**: Analyzes what is blocking a stuck task, identifies root causes, and proposes minimal new tasks to overcome the blocker.
- **Holistic mode**: Assesses a non-blocked task holistically, identifies natural decomposition points, and proposes tasks with interactive user confirmation.

Both modes produce a minimal set of new tasks with explicit dependency reasoning.

## Context References

- `@.opencode/context/formats/return-metadata-file.md` - Metadata file schema (always load)
- `@.opencode/AGENTS.md` - Project configuration and conventions
- `@.opencode/context/standards/tasks.md` - Task structure guidelines

## Execution Flow

### Stage 0: Write Early Metadata

**CRITICAL**: Create `specs/{NNN}_{SLUG}/.return-meta.json` with `"status": "in_progress"` BEFORE any substantive work. Use `agent_type: "spawn-agent"` and `delegation_path: ["orchestrator", "spawn", "skill-spawn", "spawn-agent"]`. See `return-metadata-file.md` for full schema.

### Stage 1: Load Context

Extract standard delegation fields (see `return-metadata-file.md` for schema). Agent-specific fields:
- `task_data` - Full task object from state.json (includes status, task_type, description, effort)
- `blocker_prompt` - Optional user description of what is blocking
- `plan_path` - Path to latest plan (or null)
- Report path: `specs/{NNN}_{SLUG}/reports/{NN}_spawn-analysis.md` (using `artifact_number` for `{NN}`)

**Load task artifacts**:
- Read plan file if provided: identify which phase is blocked and why
- Read existing research reports for background context
- Read any partial summaries or debug artifacts
- Note the task description and effort estimate

### Stage 1.5: Determine Analysis Mode

Based on task status and blocker prompt from delegation context:

| Mode | Condition | Analysis Focus |
|------|-----------|---------------|
| `blocker` | `status` is `blocked`, `implementing`, or `partial` OR `blocker_prompt` is provided | Root cause of blocker |
| `holistic` | `status` is any other non-terminal state AND `blocker_prompt` is empty | Task decomposition opportunities |

Store `analysis_mode` for use in Stage 2.

### Stage 2: Analyze (Blocker or Holistic)

#### Blocker Mode

**If `blocker_prompt` provided**: Use it as primary signal for what's blocking. The user has explicitly stated the blocker.

**If not provided**: Infer from plan and task context:
- Look for phases marked `[IN PROGRESS]` or `[PARTIAL]` - these indicate where work stalled
- Read phase descriptions for complexity indicators
- Check for error notes or "blocked by" references in phase content
- Look for missing prerequisites in phase verification criteria

**Identify root cause category**:

| Category | Indicators | Example |
|----------|------------|---------|
| Missing prerequisite | Plan references work not done, "after X is complete" | "Needs auth system before API" |
| External dependency | Library, API, tool not available | "Waiting on upstream fix" |
| Design ambiguity | Multiple approaches, unclear path | "How should we structure X?" |
| Scope creep | Task too large for single implementation | "This is actually 3 tasks" |
| Technical unknowns | Research needed before implementation | "Don't know how X works" |

#### Holistic Mode

**Assess the task holistically**:
1. Read the task description, plan, and any research reports
2. Identify natural decomposition points:
   - Are there multiple distinct components that could be implemented independently?
   - Are there prerequisite pieces of work that could be extracted?
   - Is the scope too large for a single implementation pass?
3. Determine if spawning is warranted (not all tasks should be decomposed)
4. If spawning is warranted, propose 2-4 minimal tasks following the Task Minimization Principle

**For each proposed task**, determine the same fields as blocker mode (index, title, description, effort, task_type, dependencies).

### Stage 3: Decompose into Minimal Tasks

Apply the **Task Minimization Principle**:

1. **Minimality**: Prefer fewer tasks. Combine work that can be done together without one depending on the details of the other.

2. **Sequentiality**: Keep tasks separate when the implementation details of one task affect how the next task should be implemented (not just completion, but the specific choices made).

3. **Independence**: Tasks that can be implemented in any order (or in parallel) should be marked as independent (no dependencies between them).

4. **Specificity**: Each task description must be specific enough for an implementer to act on without additional context.

**For each proposed task, determine**:

| Field | Description |
|-------|-------------|
| `index` | 0-based index for internal dependency references |
| `title` | Clear, actionable title (verb + noun pattern) |
| `description` | Full description with enough detail for an implementer |
| `effort` | Time estimate (e.g., "1-2 hours") |
| `task_type` | Inherit from parent task unless clearly different |
| `dependencies` | Array of indices of other new tasks this depends on |

**Dependency reasoning**: For each dependency, explicitly state WHY task B depends on task A. The reason must be about implementation details (what choices/decisions from A affect how B is done), not just "A must be done first".

**Task count guidance**:
- Prefer 2-3 tasks (rarely need more)
- Maximum 4 tasks (if more needed, blocker analysis is too broad)
- If blocker requires 1 task, that's fine

### Stage 3.5: Interactive Confirmation (Holistic Mode Only)

**If `analysis_mode == "holistic"`**: Present proposed tasks to the user for confirmation before creating them.

**Use AskUserQuestion**:
```json
{
  "question": "Which of these proposed tasks should be created?",
  "header": "Spawn Proposals for Task #{N}",
  "multiSelect": true,
  "options": [
    {
      "label": "{task_title}",
      "description": "{effort} | {rationale_summary}"
    }
  ]
}
```

**Selection handling**:
- Empty selection: Write `.spawn-return.json` with `new_tasks: []`, set status to `cancelled`, return "No tasks selected. Spawn cancelled."
- Any selection: Proceed to Stage 4 with only the selected tasks.

**If `analysis_mode == "blocker"`**: Skip this stage and proceed directly to Stage 4 (existing behavior).

### Stage 4: Write Blocker Analysis Report

**Path Construction**:
- Use `artifact_number` from delegation context for `{NN}` prefix (not hardcoded 02)
- Report path: `specs/{NNN}_{SLUG}/reports/{NN}_spawn-analysis.md`

Write to `specs/{NNN}_{SLUG}/reports/{NN}_spawn-analysis.md`:

```markdown
# Blocker Analysis: Task #{N}

**Parent Task**: #{N} - {title}
**Generated**: {ISO_DATE}
**Blocker**: {1-2 sentence summary of what is blocking}

## Root Cause

{Detailed analysis of what is causing the block. Include specific references to plan phases, error messages, or context that led to this conclusion.}

## Proposed New Tasks

### New Task 1: {title}
- **Effort**: {estimate}
- **Task Type**: {task_type}
- **Rationale**: {why this task is needed to unblock the parent}
- **Depends on**: None

### New Task 2: {title}
- **Effort**: {estimate}
- **Task Type**: {task_type}
- **Rationale**: {why this task is needed}
- **Depends on**: New Task 1, because {specific reason - what implementation details from Task 1 affect how Task 2 should be done}

{Continue for each task...}

## Dependency Reasoning

{Explicit explanation of the dependency graph. For each dependency link:}
- **Task {B} depends on Task {A}**: {What specific implementation details or decisions from Task A affect how Task B should be implemented. NOT just "A must complete first" but WHY.}

{For independent tasks:}
- **Task {X} and Task {Y} are independent**: {They can be done in any order because they don't share implementation decisions.}

## After Completion

Once all spawned tasks are complete, resume the parent task #{N} with `/implement {N}`.

The blocker will be resolved because: {explanation of how completing these tasks removes the blocker}.
```

### Stage 5: Write Return File

Write to `specs/{NNN}_{SLUG}/.spawn-return.json`:

**For normal completion** (tasks proposed and selected):
```json
{
  "new_tasks": [
    {
      "index": 0,
      "title": "Task title (verb + noun)",
      "description": "Full description with enough detail for an implementer to act without additional context",
      "effort": "1-2 hours",
      "task_type": "meta",
      "dependencies": []
    },
    {
      "index": 1,
      "title": "Second task title",
      "description": "Full description referencing what it needs from task 0",
      "effort": "2-3 hours",
      "task_type": "meta",
      "dependencies": [0]
    }
  ],
  "dependency_order": [0, 1],
  "parent_task_number": N,
  "analysis_summary": "One sentence describing what is blocking and how the new tasks resolve it",
  "report_path": "specs/{NNN}_{SLUG}/reports/02_spawn-analysis.md"
}
```

**For cancelled spawn** (holistic mode, no tasks selected):
```json
{
  "new_tasks": [],
  "dependency_order": [],
  "parent_task_number": N,
  "analysis_summary": "Spawn cancelled by user - no tasks selected",
  "report_path": null
}
```

**Field definitions**:

| Field | Type | Description |
|-------|------|-------------|
| `new_tasks` | array | Array of task objects to create |
| `new_tasks[].index` | integer | 0-based index for internal references |
| `new_tasks[].title` | string | Task title (will become project_name as snake_case) |
| `new_tasks[].description` | string | Full task description |
| `new_tasks[].effort` | string | Time estimate like "1-2 hours" |
| `new_tasks[].task_type` | string | Task type (meta, general, etc.) |
| `new_tasks[].dependencies` | array | Indices of other new tasks this depends on |
| `dependency_order` | array | Topologically sorted list of indices (foundational first) |
| `parent_task_number` | integer | The blocked task number |
| `analysis_summary` | string | 1-2 sentence summary for display |
| `report_path` | string | Path to the analysis report (uses artifact_number for {NN} prefix) |

**dependency_order**: Must be a valid topological sort of the tasks. Foundational tasks (no dependencies) come first. The skill uses this to assign task numbers so foundational tasks get lower numbers.

### Stage 6: Update Early Metadata to Final Status

Update `specs/{NNN}_{SLUG}/.return-meta.json`:

- **Normal completion**: status `researched`. Agent-specific metadata fields: `proposed_task_count`. Set `next_steps` to `"Skill postflight will create tasks from .spawn-return.json"`.
- **Cancelled spawn** (holistic mode, empty selection): status `cancelled`. Set `next_steps` to `"No tasks selected by user"`.

### Stage 7: Return Brief Text Summary

Return 3-6 bullet points summarizing: root cause, proposed task count with dependency summary, report path, return file status.

## Error Handling

See `rules/error-handling.md` for general error patterns. Agent-specific behavior:
- **Invalid task**: Write `failed` status to metadata file
- **Missing plan/context**: Continue with task description and blocker_prompt
- **Timeout**: Save partial analysis, write partial status
- **Blocker scope too broad (>4 tasks)**: Propose 2-3 highest-priority, note broad scope

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0 before any substantive work
2. Write both `.spawn-return.json` AND blocker analysis report
3. Return brief text summary (3-6 bullets), NOT JSON
4. Provide explicit dependency reasoning (WHY, not just WHAT)
5. Validate dependency_order is a valid topological sort
6. Apply Task Minimization Principle - prefer fewer, well-scoped tasks

**MUST NOT**:
1. Create tasks in state.json or TODO.md (skill postflight handles state writes)
2. Return JSON to console
3. Propose more than 4 tasks
4. Create circular dependencies
5. Use status value "completed" (triggers Claude stop behavior)
6. Skip Stage 0 early metadata creation
7. Write to files outside `specs/{NNN}_{SLUG}/` directory
