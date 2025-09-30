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
**High Independence (+20-30 points each):**
- Keywords: "Create new", "Add new", "Implement standalone", "Build separate", "Generate fresh"
- New file creation with unique paths
- Module/component isolation
- No cross-references to other task outputs

**Medium Independence (+10-15 points each):**
- Keywords: "Create", "Add", "Implement", "Build", "Generate", "Write"
- Different file paths with no overlaps
- Self-contained functionality
- Clear scope boundaries

### Dependency Indicators (Negative Score)
**High Dependencies (-30-40 points each):**
- Keywords: "After completing", "Using results from", "Based on previous", "Integrate with"
- Explicit task ordering phrases ("First", "Then", "Finally")
- Variable/function references from other tasks
- Sequential numbering with implied dependencies

**Medium Dependencies (-15-20 points each):**
- Keywords: "Update", "Modify", "Extend", "Connect", "Link"
- File modifications in shared areas
- References to shared state or configuration
- Import/export relationships

**Low Dependencies (-5-10 points each):**
- Generic dependency words ("Using", "With", "For")
- Shared file access (read-only)
- Common configuration references

### File Conflict Detection Engine

#### Conflict Severity Scoring
1. **Parse File References**: Extract all file paths from task descriptions
2. **Categorize Operations**:
   - **CREATE**: New file creation (low conflict risk)
   - **MODIFY**: Existing file changes (high conflict risk)
   - **READ**: File access for context (no conflict)
   - **DELETE**: File removal (highest conflict risk)

3. **Conflict Matrix Analysis**:
   ```
   Task A + Task B Operations:
   CREATE + CREATE (different files): Score +10
   CREATE + CREATE (same directory): Score -5
   MODIFY + MODIFY (same file): Score -50 (blocking)
   MODIFY + READ (same file): Score -10
   READ + READ: Score +5
   ```

4. **Path Overlap Detection**:
   - Same file path: -50 points (blocking conflict)
   - Same directory: -10 points (potential conflict)
   - Related paths (parent/child): -15 points
   - Different directories: +5 points

### Task Grouping Algorithm

#### Grouping Rules
1. **Independent Groups**: Tasks with no file conflicts, score >= 70
2. **Sequential Groups**: Tasks with dependencies, execute in order
3. **Parallel-Safe Groups**: Related tasks that can run simultaneously
4. **Blocking Groups**: Tasks that must run alone due to conflicts

#### Grouping Process
```
For each task pair (A, B):
  dependency_score = analyze_dependencies(A, B)
  file_conflict_score = check_file_conflicts(A, B)
  total_score = dependency_score + file_conflict_score

  if total_score >= 70:
    add_to_parallel_group(A, B)
  elif total_score >= 40:
    add_to_sequential_group(A, B)
  else:
    mark_as_blocking(A, B)
```

## Advanced Prompt Generation Strategy

### Context-Aware Prompt Assembly

Each parallel task receives a comprehensive prompt with these sections:

#### 1. Executive Summary
```
Task: [Brief description]
Phase: [N] - [Phase Name] ([Complexity])
Priority: [High/Medium/Low] based on task criticality
Estimated Time: [Based on complexity analysis]
```

#### 2. Phase Context Integration
- **Phase Objectives**: Overall phase goals and success criteria
- **Phase Number**: Current phase in implementation sequence
- **Complexity Level**: Task complexity inherited from phase
- **Standards Reference**: Direct link to project CLAUDE.md
- **Previous Phase Context**: Summary of completed work (if Phase > 1)

#### 3. Task-Specific Context
- **File Operations**: Detailed list of files to create/modify/read
- **Dependencies**: Libraries, modules, or previous task outputs needed
- **Input Data**: Any data structures or configurations required
- **Integration Points**: How this task connects to the larger system

#### 4. Dynamic Success Criteria Generation

Based on task analysis, generate specific validation requirements:

**For File Creation Tasks:**
```
Success Criteria:
- File created at exact path: [path]
- File contains required sections: [list]
- File follows project style guide
- File passes syntax validation
- No conflicts with existing files
```

**For Implementation Tasks:**
```
Success Criteria:
- Feature implements specified behavior
- All tests pass (unit and integration)
- Code follows project patterns from [similar_files]
- Documentation updated if required
- Performance meets baseline requirements
```

**For Configuration Tasks:**
```
Success Criteria:
- Configuration validates against schema
- Service restarts successfully
- No regression in existing functionality
- Changes documented in appropriate location
```

#### 5. Structured Output Format Requirements

Request specific output format for easy parsing:

```markdown
# Task Completion Report

## Status
- [x] COMPLETED | [ ] PARTIAL | [ ] FAILED

## Summary
[One-line description of what was accomplished]

## Files Modified
- `path/to/file1.ext`: [Description of changes]
- `path/to/file2.ext`: [Description of changes]

## Validation Results
- [x] File syntax check passed
- [x] Tests passed: [test_names]
- [x] Integration check passed

## Issues Encountered
[Any problems or warnings encountered]

## Next Steps
[Any follow-up actions needed]
```

#### 6. Context-Sensitive Rollback Instructions

**For Code Changes:**
```
Rollback Plan:
1. If tests fail: `git checkout HEAD -- [files]`
2. If service fails: `systemctl restart [service] && systemctl status [service]`
3. If integration breaks: Revert to backup configuration at [backup_path]
4. Emergency contacts: [relevant team members or documentation]
```

**For Configuration Changes:**
```
Rollback Plan:
1. Restore backup: `cp [backup_file] [target_file]`
2. Restart affected services: `sudo systemctl restart [services]`
3. Verify system state: `[validation_commands]`
4. Check logs for errors: `journalctl -u [service] --since="1 hour ago"`
```

### Prompt Template Engine

#### Base Template Structure
```
# [TASK_TYPE] Task: [TASK_SUMMARY]

## Context
You are implementing Phase [PHASE_NUM] ([PHASE_NAME]) of an implementation plan.
This task is part of: [PROJECT_OVERVIEW]

## Standards and Guidelines
Project follows standards documented in: [STANDARDS_FILE]
Key patterns from this project:
[EXTRACTED_PATTERNS]

## Your Specific Task
[DETAILED_TASK_DESCRIPTION]

## Required Context Files
[AUTO_GENERATED_FILE_LIST]

## Success Validation
[GENERATED_SUCCESS_CRITERIA]

## Expected Output Format
[STRUCTURED_OUTPUT_TEMPLATE]

## Rollback Procedures
[CONTEXT_APPROPRIATE_ROLLBACK]

## Important Notes
- This task will be executed in parallel with: [PARALLEL_TASKS]
- Avoid conflicts with these file operations: [CONFLICT_WARNINGS]
- Integration testing will be performed after all parallel tasks complete
```

#### Template Customization by Task Type

**CREATE_FILE tasks:**
- Include file structure examples from similar files
- Add project-specific headers, imports, and patterns
- Include style guide compliance checks

**MODIFY_CODE tasks:**
- Provide surrounding code context
- Include related function/class definitions
- Add backward compatibility requirements

**CONFIGURE_SYSTEM tasks:**
- Include current configuration state
- Add service dependency information
- Include testing procedures for configuration changes

**TEST_IMPLEMENTATION tasks:**
- Include existing test patterns
- Add coverage requirements
- Include performance benchmarks

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