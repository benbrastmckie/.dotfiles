---
allowed-tools: Task, TodoWrite, Read, Bash
argument-hint: <phase-context> <task-list> [options]
description: Utility command for parallel task execution within /implement phases
command-type: utility
dependent-commands: implement
---

# Parallel Task Execution Utility

I'll analyze the provided tasks and execute suitable ones in parallel using subagents, then return consolidated results.

## Arguments
- **phase-context**: JSON object with phase number, name, complexity, and file paths
- **task-list**: Array of task objects with descriptions and markers
- **options**: Configuration flags (--dry-run, --max-agents=N, --verbose)

## Integration with /implement

This utility command is designed to be called by `/implement` when it encounters phases suitable for parallelization.

### Invocation Criteria
/implement should call /subagents when:
- Phase has 3+ tasks in checklist format
- Tasks don't have explicit dependencies
- Tasks modify different files or create new ones
- Phase complexity is marked as Medium or High
- Not in a critical phase (like Phase 1 setup)

## Process

### 1. Task Analysis
I'll analyze the provided task list to determine:
- **Task independence**: Keywords like "Create", "Add", "Implement" vs "After", "Using", "Based on"
- **File conflicts**: Tasks that would modify the same files
- **Dependency chains**: Sequential relationships between tasks
- **Parallelizability score**: 0-100 based on independence and conflict analysis

### 2. Parallelization Decision
If parallelization score >= 70 and >= 3 independent tasks:
- Group tasks into parallel-safe batches
- Generate optimized prompts for each task
- Execute via parallel Task tool invocations
- Collect and validate results

Otherwise:
- Return recommendation for sequential execution
- Provide reasoning for the decision

### 3. Parallel Execution
For parallelizable tasks:
- Create phase-aware prompts with full context
- Include success validation criteria
- Add rollback instructions for failures
- Execute all tasks simultaneously using Task tool
- Monitor progress and collect results

### 4. Result Aggregation
- Parse individual agent responses
- Validate task completion against criteria
- Format results for /implement consumption
- Report any partial failures or issues
- Provide summary of work completed

## Task Dependency Detection Algorithm

### Independence Indicators (Positive Score)
- Keywords: "Create", "Add", "Implement", "Build", "Generate", "Write"
- Different file paths or new file creation
- No reference to other tasks in description
- Self-contained work that doesn't rely on previous steps

### Dependency Indicators (Negative Score)
- Keywords: "After", "Using", "Based on", "Update", "Modify", "Integration"
- References to variables/functions from other tasks
- Sequential numbering that implies order
- File modifications that could conflict

### File Conflict Detection
- Parse file paths from task descriptions
- Identify overlapping file modifications
- Group conflicting tasks for sequential execution
- Score based on independence of file operations

## Prompt Generation Strategy

Each parallel task receives a prompt containing:
- **Phase Context**: Phase number, name, objectives, complexity
- **Standards**: Project standards from CLAUDE.md
- **File Context**: Relevant file paths and existing code
- **Success Criteria**: Specific validation requirements
- **Output Format**: Structured response format for result parsing
- **Rollback Plan**: Instructions for undoing changes if needed

## Error Handling

### Partial Failures
- Continue with successful tasks
- Collect error details from failed tasks
- Provide clear failure report to /implement
- Suggest recovery strategies

### Complete Failure
- Fall back to sequential execution recommendation
- Preserve all context for /implement to continue
- Log failure reasons for future optimization

## Performance Metrics

Track and report:
- **Parallelization Rate**: Percentage of tasks executed in parallel
- **Time Savings**: Estimated vs actual execution time
- **Success Rate**: Percentage of successful parallel executions
- **Resource Usage**: Peak agent count and memory usage

## Output Format

Return structured results to /implement:

```json
{
  "status": "success|partial|failed",
  "parallelized": true|false,
  "tasks_completed": ["task1", "task2"],
  "tasks_failed": ["task3"],
  "execution_time": "2.5s",
  "agents_used": 4,
  "summary": "Completed 4/5 tasks in parallel, 1 failed due to...",
  "next_steps": ["Fix failing test in task3", "Continue with Phase 2"],
  "performance": {
    "time_saved": "1.2s",
    "parallelization_score": 85
  }
}
```

## Example Usage (Internal - Called by /implement)

```bash
# /implement detects parallelizable phase and calls:
/subagents '{
  "phase": 2,
  "name": "Core Implementation",
  "complexity": "High",
  "standards_file": "/path/to/CLAUDE.md"
}' '[
  {"id": 1, "description": "Create user authentication module", "files": ["auth/user.js"]},
  {"id": 2, "description": "Add database connection logic", "files": ["db/connection.js"]},
  {"id": 3, "description": "Implement API routes", "files": ["routes/api.js"]}
]' --max-agents=5
```

## Configuration

Default settings (can be overridden):
- **max_agents**: 10 (resource limit)
- **timeout_per_task**: 300s (5 minutes)
- **min_parallelization_score**: 70
- **min_task_count**: 3
- **critical_phases**: [1] (never parallelize setup phases)

---

## Integration Notes

This command enhances /implement's efficiency by:
1. **Automatic Detection**: No user intervention required
2. **Safe Parallelization**: Conservative scoring prevents issues
3. **Graceful Fallback**: Sequential execution if parallelization unsafe
4. **Performance Gains**: Significant speedup for suitable phases
5. **Full Integration**: Maintains all /implement workflows and safeguards