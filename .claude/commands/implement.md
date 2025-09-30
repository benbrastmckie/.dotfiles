---
allowed-tools: Read, Edit, MultiEdit, Write, Bash, Grep, Glob, TodoWrite, SlashCommand
argument-hint: [plan-file] [starting-phase]
description: Execute implementation plan with automated testing and commits (auto-resumes most recent incomplete plan if no args)
command-type: primary
dependent-commands: list-plans, update-plan, list-summaries, revise, debug, document, subagents
---

# Execute Implementation Plan

I'll help you systematically implement the plan file with automated testing and commits at each phase.

## Plan Information
- **Plan file**: $1 (or I'll find the most recent incomplete plan)
- **Starting phase**: $2 (default: resume from last incomplete phase or 1)

## Auto-Resume Feature
If no plan file is provided, I will:
1. Search for the most recently modified implementation plan
2. Check if it has incomplete phases or tasks
3. Resume from the first incomplete phase
4. If all recent plans are complete, show a list to choose from

## Process

Let me first locate the implementation plan:

1. **Parse the plan** to identify:
   - Phases and tasks
   - Referenced research reports (if any)
   - Standards file path
2. **Check for research reports**:
   - Extract report paths from plan metadata
   - Note reports for summary generation
3. **For each phase**:
   - Display the phase name and tasks
   - Implement the required changes
   - Run tests to verify the implementation
   - Update the plan file with completion markers
   - Create a git commit with a structured message
   - Move to the next phase
4. **After all phases complete**:
   - Generate implementation summary
   - Update referenced reports if needed
   - Link plan and reports in summary

## Phase Execution Protocol

For each phase, I will:

### 1. Display Phase Information
Show the current phase number, name, and all tasks that need to be completed.

### 2. Implementation
Analyze the phase for parallelization opportunities, then create or modify the necessary files according to the plan specifications.

#### Parallelization Analysis
Before implementing tasks, I'll analyze the phase to determine if /subagents should be used:

**Parallelization Criteria:**
1. **Task Count**: Phase has 3+ checklist tasks (`- [ ]` format)
2. **Independence Score**: Tasks have minimal dependencies
3. **File Conflicts**: Tasks work on different files or create new ones
4. **Phase Type**: Not a critical setup phase (typically Phase 1)
5. **Complexity**: Phase marked as Medium or High complexity

**Analysis Process:**
```
For each phase:
  1. Extract all checklist tasks from phase content
  2. Analyze task descriptions for dependency keywords:
     - Independence: "Create", "Add", "Implement", "Build"
     - Dependencies: "After", "Using", "Based on", "Update"
  3. Check for file operation conflicts
  4. Calculate parallelization score (0-100)
  5. If score >= 70 AND >= 3 tasks: Use /subagents
  6. Otherwise: Execute sequentially as normal
```

#### /subagents Integration
When parallelization criteria are met:

```bash
# Call /subagents with phase context and task list
/subagents '{
  "phase": [PHASE_NUMBER],
  "name": "[PHASE_NAME]",
  "complexity": "[PHASE_COMPLEXITY]",
  "standards_file": "[PATH_TO_CLAUDE_MD]",
  "plan_file": "[CURRENT_PLAN_PATH]"
}' '[TASK_LIST_JSON]' --max-agents=10
```

#### Parallel Execution Workflow
1. **Pre-execution**: Validate parallelization decision
2. **Execution**: Let /subagents handle parallel task coordination
3. **Post-execution**: Process /subagents results and continue with normal workflow
4. **Fallback**: If /subagents recommends sequential execution, proceed normally

#### Result Integration
/subagents returns structured results that I'll integrate into the normal phase workflow:
- **Success**: Mark tasks as completed and proceed to testing
- **Partial Success**: Handle failed tasks individually, continue with successful ones
- **Fallback**: Execute remaining tasks sequentially
- **Failure**: Fall back to full sequential execution

### 3. Testing
Run tests by:
- Looking for test commands in the phase tasks
- Checking for common test patterns (npm test, pytest, make test)
- Running language-specific test commands based on project type

### 4. Plan Update
- Mark completed tasks with `[x]` instead of `[ ]`
- Add `[COMPLETED]` marker to the phase heading
- Save the updated plan file

### 5. Git Commit
Create a structured commit:
```
feat: implement Phase N - Phase Name

Automated implementation of phase N from implementation plan
All tests passed successfully

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Test Detection Patterns

I'll look for and run:
- Commands containing `:lua.*test`
- Commands with `:Test`
- Standard test commands: `npm test`, `pytest`, `make test`
- Project-specific test commands based on configuration files

## Resuming Implementation

If we need to stop and resume later, you can use:
```
/implement <plan-file> <phase-number>
```

This will start from the specified phase number.

## Error Handling

If tests fail or issues arise:
1. I'll show the error details
2. We'll fix the issues together
3. Re-run tests before proceeding
4. Only move forward when tests pass

### Parallel Execution Error Handling
When using /subagents, additional error scenarios may occur:
- **Parallelization Failure**: /subagents cannot execute tasks in parallel
- **Partial Completion**: Some parallel tasks succeed, others fail
- **Agent Timeout**: Individual agents exceed time limits
- **Resource Constraints**: Too many parallel agents requested

**Recovery Strategies:**
1. **Graceful Degradation**: Continue with successful tasks, handle failures sequentially
2. **Full Fallback**: Revert to sequential execution for the entire phase
3. **Retry Logic**: Attempt failed tasks individually with full context
4. **Performance Monitoring**: Track parallel vs sequential execution times

## Summary Generation

After completing all phases, I'll:

### 1. Create Summary Directory
- Location: Same directory as the plan, in `specs/summaries/`
- Create if it doesn't exist

### 2. Generate Summary File
- Format: `NNN_implementation_summary.md`
- Number matches the plan number
- Contains:
  - Implementation overview
  - Plan executed with link
  - Reports referenced (if any)
  - Key changes made
  - Test results
  - Lessons learned
  - **Parallelization metrics** (if /subagents was used)

### 3. Update Reports (if referenced)
If the plan referenced research reports:
- Add implementation notes to each report
- Cross-reference the summary
- Note which recommendations were implemented

### 4. Performance Metrics (Enhanced)
When /subagents was used, include additional metrics:
- **Phases Parallelized**: Number and percentage of phases that used parallel execution
- **Time Savings**: Estimated time saved through parallelization
- **Success Rate**: Percentage of successful parallel executions
- **Fallback Rate**: How often sequential execution was required
- **Task Distribution**: Average tasks per parallel group

### Summary Format
```markdown
# Implementation Summary: [Feature Name]

## Metadata
- **Date Completed**: [YYYY-MM-DD]
- **Plan**: [Link to plan file]
- **Research Reports**: [Links to reports used]
- **Phases Completed**: [N/N]

## Implementation Overview
[Brief description of what was implemented]

## Key Changes
- [Major change 1]
- [Major change 2]

## Test Results
[Summary of test outcomes]

## Report Integration
[How research informed implementation]

## Lessons Learned
[Insights from implementation]
```

## Finding the Implementation Plan

### Auto-Detection Logic (when no arguments provided):
```bash
# 1. Find all plan files, sorted by modification time
find . -path "*/specs/plans/*.md" -type f -exec ls -t {} + 2>/dev/null

# 2. For each plan, check for incomplete markers:
# - Look for unchecked tasks: "- [ ]"
# - Look for phases without [COMPLETED] marker
# - Skip plans marked with "IMPLEMENTATION COMPLETE"

# 3. Select the first incomplete plan
```

### If no plan file provided:
I'll search for the most recent incomplete implementation plan by:
1. Looking in all `specs/plans/` directories
2. Sorting by modification time (most recent first)
3. Checking each plan for:
   - Unchecked tasks `- [ ]`
   - Phases without `[COMPLETED]` marker
   - Absence of `IMPLEMENTATION COMPLETE` header
4. Selecting the first incomplete plan found
5. Determining the first incomplete phase to resume from

### If a plan file is provided:
I'll use the specified plan file directly and:
1. Check its completion status
2. Find the first incomplete phase (if any)
3. Resume from that phase or start from phase 1

### Plan Status Detection Patterns:
- **Complete Plan**: Contains `## ✅ IMPLEMENTATION COMPLETE` or all phases marked `[COMPLETED]`
- **Incomplete Phase**: Phase heading without `[COMPLETED]` marker
- **Incomplete Task**: Checklist item with `- [ ]` instead of `- [x]`

Let me start by finding your implementation plan.