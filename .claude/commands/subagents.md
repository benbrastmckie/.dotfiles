---
allowed-tools: Task, TodoWrite, Read, Bash
argument-hint: <phase-context> <task-list> [options]
description: Utility command for parallel task execution within /implement phases
command-type: utility
dependent-commands: implement
---

# Parallel Task Execution Utility

I'll analyze the provided tasks and execute suitable ones in parallel using subagents, then return consolidated results.

## Task Execution Engine

Let me parse your phase context and task list to determine the optimal execution strategy.

### 1. Input Parsing and Validation
First, I'll parse the provided arguments:
- Extract phase context (JSON object with phase info)
- Parse task list (array of task objects)
- Validate argument structure and completeness
- Set execution options (defaults or user-provided)

### 2. Task Analysis and Scoring
For each task in the list:
- Analyze task description for dependency keywords
- Extract file operation patterns (CREATE/MODIFY/READ)
- Calculate independence score (0-100)
- Identify potential file conflicts
- Group tasks by parallelizability

### 3. Execution Decision Matrix
Based on analysis results:
- **Score >= 70 AND >= 3 tasks**: Proceed with parallel execution
- **Score 40-69**: Use sequential execution with batching
- **Score < 40**: Fallback to sequential execution
- **Blocking conflicts detected**: Sequential execution required

### 4. Parallel Execution Orchestration
If parallelization is viable:
- Generate optimized prompts for each parallel group
- Execute tasks simultaneously using Task tool batch calls
- Monitor execution progress and collect results
- Handle partial failures gracefully
- Validate results against success criteria

### 5. Result Aggregation and Formatting
After execution completes:
- Parse individual agent responses
- Validate task completion status
- Aggregate results into structured format
- Generate summary for /implement consumption
- Report performance metrics and recommendations

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

## Parallel Execution Implementation

### Batch Task Invocation Strategy
When parallelization is approved, I'll use the Task tool with multiple simultaneous calls:

```
For each parallel group:
  1. Generate context-rich prompt using template engine
  2. Include phase context and success criteria
  3. Add structured output requirements
  4. Execute via Task tool with general-purpose agent
  5. Monitor for completion and collect results
```

### Result Parser Implementation

#### Expected Agent Response Format
Each agent returns structured markdown with:
```markdown
# Task Completion Report
## Status: COMPLETED|PARTIAL|FAILED
## Summary: [one-line description]
## Files Modified: [list with descriptions]
## Validation Results: [checklist of validations]
## Issues Encountered: [problems/warnings]
## Next Steps: [follow-up actions]
```

#### Parsing Algorithm
```
For each agent response:
  1. Extract status (COMPLETED/PARTIAL/FAILED)
  2. Parse files modified list
  3. Collect validation results
  4. Aggregate issues and warnings
  5. Compile next steps recommendations
```

### Task Completion Validator

#### Validation Levels
1. **Syntax Validation**: Check file syntax and structure
2. **Functional Validation**: Verify task objectives met
3. **Integration Validation**: Check compatibility with other changes
4. **Performance Validation**: Ensure no performance regressions

#### Validation Implementation
```
For each completed task:
  1. Verify all specified files exist
  2. Check file content against success criteria
  3. Run basic syntax validation where applicable
  4. Cross-check for conflicts with parallel task outputs
  5. Generate validation score (0-100)
```

### Partial Failure Handling Strategy

#### Failure Classification
- **Recoverable Failures**: Can be retried or fixed automatically
- **Dependency Failures**: Failed due to missing dependencies
- **Conflict Failures**: Failed due to file conflicts
- **Critical Failures**: Fundamental issues requiring human intervention

#### Recovery Procedures
```
On partial failure:
  1. Categorize failure type
  2. Determine if retry is viable
  3. Check if other tasks can continue
  4. Implement rollback if necessary
  5. Generate detailed failure report
```

### Result Formatting for /implement Integration

#### Standard Success Response
```json
{
  "execution_status": "success",
  "parallelization_used": true,
  "tasks_completed": 4,
  "tasks_failed": 0,
  "execution_time": "2.3s",
  "performance_improvement": "65% faster than sequential",
  "detailed_results": [
    {
      "task_id": 1,
      "description": "Create authentication module",
      "status": "completed",
      "files_modified": ["auth/user.js", "auth/session.js"],
      "validation_score": 95,
      "execution_time": "1.8s"
    }
  ],
  "next_phase_recommendations": "Continue to Phase 3 - all dependencies satisfied"
}
```

#### Partial Failure Response
```json
{
  "execution_status": "partial_success",
  "parallelization_used": true,
  "tasks_completed": 3,
  "tasks_failed": 1,
  "execution_time": "3.1s",
  "failed_tasks": [
    {
      "task_id": 4,
      "description": "Configure database connection",
      "failure_reason": "Missing database credentials",
      "recovery_suggestion": "Add DB_PASSWORD to environment",
      "blocking_next_phase": false
    }
  ],
  "success_tasks": [...],
  "next_phase_recommendations": "Fix failed task before Phase 3, or proceed with degraded functionality"
}
```

### Fallback to Sequential Execution

#### Trigger Conditions
- Parallelization score < 70
- High file conflict risk detected
- Critical phase (Phase 1 setup)
- Resource constraints (>10 agents)
- Previous parallel execution failures

#### Fallback Implementation
```
When fallback triggered:
  1. Log reason for fallback decision
  2. Return structured recommendation to /implement
  3. Preserve all task context and analysis
  4. Suggest optimal sequential execution order
  5. Provide performance estimates for sequential approach
```

#### Fallback Response Format
```json
{
  "execution_status": "fallback_recommended",
  "parallelization_used": false,
  "fallback_reason": "High file conflict risk detected",
  "recommended_sequence": [
    {"task_id": 1, "reason": "Creates foundation files"},
    {"task_id": 3, "reason": "Depends on task 1 outputs"},
    {"task_id": 2, "reason": "Modifies files from task 3"}
  ],
  "estimated_sequential_time": "4.2s",
  "parallel_risk_assessment": "85% chance of conflicts"
}
```

## Error Handling and Recovery

### Comprehensive Error Classification

#### Agent Execution Errors
- **Timeout Errors**: Agent exceeded time limit
- **Tool Errors**: Agent couldn't access required tools
- **Context Errors**: Insufficient context provided
- **Resource Errors**: System resource limitations

#### Task-Specific Errors
- **File Permission Errors**: Cannot write to target location
- **Dependency Errors**: Required files or modules missing
- **Validation Errors**: Output doesn't meet success criteria
- **Integration Errors**: Conflicts with existing code

### Recovery Strategies by Error Type

#### Automatic Recovery (No Human Intervention)
```
Timeout Errors:
  1. Retry with extended timeout
  2. Split task into smaller components
  3. Use different agent configuration

Tool Access Errors:
  1. Verify tool permissions
  2. Retry with reduced tool set
  3. Fall back to sequential execution
```

#### Semi-Automatic Recovery (Minimal Human Input)
```
Dependency Errors:
  1. Identify missing dependencies
  2. Suggest installation commands
  3. Offer to pause until dependencies resolved

Validation Errors:
  1. Show validation failure details
  2. Offer specific correction suggestions
  3. Provide manual fix guidance
```

#### Manual Recovery (Human Intervention Required)
```
Critical Integration Errors:
  1. Provide comprehensive error context
  2. Show conflict details and file diffs
  3. Suggest rollback or manual resolution
  4. Offer to continue with remaining tasks
```

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