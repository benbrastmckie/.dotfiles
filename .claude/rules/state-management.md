---
paths: specs/**/*
---

# State Management Rules

## File Synchronization

TODO.md is generated from state.json. Agents update state.json only; `generate-todo.sh` handles TODO.md synchronization. Never edit TODO.md directly for status or artifact changes.

### Canonical Sources
- **state.json**: Machine-readable source of truth and sole authoritative state
  - next_project_number
  - active_projects array with status, task_type
  - Faster to query (12ms vs 100ms for TODO.md parsing)

- **TODO.md**: User-facing rendered view (generated from state.json)
  - Human-readable task list with descriptions
  - Status markers in brackets: [STATUS]
  - Single `## Tasks` section (new tasks prepended at top)

## Status Transitions

### Permissive Model

Any command can run from any non-terminal status. Only terminal states block transitions:

```
Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]

Any non-terminal status -> any command (research, plan, implement, revise)
Any status -> [BLOCKED] (with reason)
Any status -> [ABANDONED] (moves to archive)
Any non-terminal -> [EXPANDED] (when divided into subtasks)
[IMPLEMENTING] -> [PARTIAL] (on timeout/error)
[IMPLEMENTING] -> [PR READY] (implementation complete, awaiting PR submission)
[PR READY] -> [IMPLEMENTING] (if issues found during PR review)
[PR READY] -> [COMPLETED] (after /merge PR submission)
```

### Restrictions
- Cannot transition from terminal states (completed, abandoned, expanded)
- Cannot mark COMPLETED without all phases done

## State-First Update Pattern

When updating task status:

1. **Write state.json** via `jq` (machine state is the sole source of truth)
2. **Regenerate TODO.md** by calling `bash .claude/scripts/generate-todo.sh`

`update-task-status.sh` performs both steps automatically. Agents must not Edit TODO.md directly for status or artifact changes — `generate-todo.sh` handles all TODO.md rendering from state.json.

```bash
# Full state-first update (preferred)
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"

# Manual regeneration after state.json update
bash .claude/scripts/generate-todo.sh
```

## Error Handling

### On Write Failure
1. Do not update either file partially
2. Log error with context
3. Preserve original state
4. Return error to caller

### On Inconsistency Detection
1. Log the inconsistency
2. Use git blame to determine latest
3. Sync to latest version
4. Use git for recovery of overwritten versions

## Schema Reference

For complete field schemas, status values mapping, artifact linking formats, and directory creation patterns, see:
- [State Management Schema](.claude/context/reference/state-management-schema.md)
