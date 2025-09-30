---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task
argument-hint: "[plan-file] [starting-phase] [--orchestrated]"
description: "Execute implementation plan with automated testing and commits (auto-resumes most recent incomplete plan if no args)"
command-type: primary
dependent-commands: list-plans, update-plan, list-summaries, revise, debug, document, subagents
---

# Execute Implementation Plan

I'll help you systematically implement the plan file with automated testing and commits at each phase.

## Plan Information
- **Plan file**: $1 (or I'll find the most recent incomplete plan)
- **Starting phase**: $2 (default: resume from last incomplete phase or 1)
- **Orchestration mode**: $3 (--orchestrated flag enables orchestration features)

## Auto-Resume Feature
If no plan file is provided, I will:
1. Search for the most recently modified implementation plan
2. Check if it has incomplete phases or tasks
3. Resume from the first incomplete phase
4. If all recent plans are complete, show a list to choose from

## Orchestration Mode Detection

I'll first detect if this implementation should run in orchestration mode:

### Orchestration Mode Criteria
1. **Explicit Flag**: `--orchestrated` argument provided
2. **Environment Detection**: Running within orchestrated workflow context
3. **Coordination Hub Active**: Existing workflow state in coordination hub
4. **Resource Manager Integration**: Resource allocation requests present

### Orchestration vs Standalone Mode

#### Standalone Mode (Traditional)
- Direct file operations and testing
- Simple git commits
- Linear phase execution
- Local state management

#### Orchestration Mode (Enhanced)
- Progress broadcasting to coordination hub
- Resource allocation through resource manager
- Context preservation for workflow handoffs
- Enhanced error handling and recovery
- Real-time state synchronization

## Process

Let me first detect the execution mode and locate the implementation plan:

1. **Mode Detection and Initialization**:
   - Detect orchestration mode (flag, environment, or context)
   - Initialize coordination hub integration if orchestrated
   - Set up progress broadcasting and state management
   - Configure resource allocation if needed
2. **Parse the plan** to identify:
   - Phases and tasks
   - Referenced research reports (if any)
   - Standards file path
   - Resource requirements (CPU, memory, agents)
3. **Check for research reports**:
   - Extract report paths from plan metadata
   - Note reports for summary generation
4. **Resource Allocation** (Orchestration Mode):
   - Analyze resource requirements for the plan
   - Request allocation through resource manager
   - Handle allocation conflicts and queuing
5. **For each phase**:
   - **Orchestration**: Broadcast phase start event
   - Display the phase name and tasks
   - **Orchestration**: Check for context handoffs
   - Implement the required changes
   - Run tests to verify the implementation
   - **Orchestration**: Update workflow state in coordination hub
   - Update the plan file with completion markers
   - Create a git commit with a structured message
   - **Orchestration**: Broadcast phase completion event
   - Move to the next phase
6. **After all phases complete**:
   - **Orchestration**: Broadcast implementation completion
   - Generate implementation summary
   - Update referenced reports if needed
   - Link plan and reports in summary
   - **Orchestration**: Release allocated resources
   - **Orchestration**: Archive workflow state

## Orchestration Infrastructure

### Progress Broadcasting System

In orchestration mode, I'll broadcast real-time progress events:

```json
{
  "event_type": "phase_started|task_completed|phase_completed|implementation_completed",
  "workflow_id": "workflow_123",
  "plan_file": "/path/to/plan.md",
  "phase_number": 2,
  "phase_name": "Core Implementation",
  "task_id": "task_456",
  "progress_percentage": 45.5,
  "timestamp": "2025-01-15T11:30:00Z",
  "context": {
    "files_modified": ["home.nix", "flake.nix"],
    "tests_status": "passed",
    "commit_hash": "abc123",
    "resource_usage": {
      "cpu_cores": 2,
      "memory_gb": 3.5,
      "agents_used": 4
    }
  }
}
```

### Context Preservation for Workflow Handoffs

Between phases, I'll preserve comprehensive context:

```json
{
  "handoff_context": {
    "phase_transition": {
      "from_phase": 2,
      "to_phase": 3,
      "completion_status": "success|partial|failed"
    },
    "implementation_state": {
      "files_modified": ["list_of_files_with_checksums"],
      "dependencies_installed": ["package_list"],
      "services_configured": ["service_list"],
      "tests_passing": true
    },
    "resource_context": {
      "allocation_id": "alloc_456",
      "current_usage": "resource_snapshot",
      "performance_metrics": "efficiency_data"
    },
    "error_context": {
      "warnings_encountered": ["warning_list"],
      "recoveries_performed": ["recovery_actions"],
      "known_issues": ["issue_list"]
    }
  }
}
```

### Workflow-Aware Error Handling

Enhanced error handling for orchestrated environments:

```
Error Handling Levels:

1. Task-Level Errors:
   - Retry with exponential backoff
   - Fallback to sequential execution
   - Report to coordination hub
   - Preserve partial progress

2. Phase-Level Errors:
   - Create checkpoint before failure
   - Analyze error context and dependencies
   - Attempt intelligent recovery
   - Escalate to workflow coordinator

3. Workflow-Level Errors:
   - Broadcast critical failure event
   - Save complete workflow state
   - Release allocated resources
   - Provide recovery recommendations

4. System-Level Errors:
   - Coordinate with resource manager
   - Check for resource conflicts
   - Implement graceful degradation
   - Notify all dependent workflows
```

## Phase Execution Protocol

For each phase, I will:

### 1. Phase Initialization

#### Standalone Mode
Show the current phase number, name, and all tasks that need to be completed.

#### Orchestration Mode
1. **Broadcast Phase Start Event**:
   ```bash
   /coordination-hub $WORKFLOW_ID publish-event '{
     "event_type": "phase_started",
     "phase_number": N,
     "phase_name": "Phase Name",
     "estimated_duration": "30m",
     "tasks_count": 5
   }'
   ```

2. **Check for Context Handoffs**:
   ```bash
   /coordination-hub $WORKFLOW_ID get-status '{
     "include_context": true,
     "phase_transition": true
   }'
   ```

3. **Verify Resource Allocation**:
   ```bash
   /resource-manager status $ALLOCATION_ID '{
     "verify_availability": true,
     "check_conflicts": true
   }'
   ```

4. **Display Enhanced Phase Information**:
   - Phase number, name, and tasks
   - Resource allocation status
   - Context from previous phases
   - Dependencies and prerequisites

### 2. Implementation

#### Pre-Implementation (Orchestration Mode)
1. **Resource Validation**:
   ```bash
   /resource-manager check-conflicts '{
     "proposed_files": ["list_of_files_to_modify"],
     "estimated_resources": {"cpu_cores": 2, "memory_gb": 4},
     "duration": "estimated_phase_duration"
   }'
   ```

2. **Context Integration**:
   - Load handoff context from previous phase
   - Verify file states and checksums
   - Check dependency satisfaction
   - Validate prerequisites

#### Core Implementation
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

**Standalone Mode:**
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

**Orchestration Mode:**
```bash
# Enhanced /subagents call with orchestration context
/subagents '{
  "phase": [PHASE_NUMBER],
  "name": "[PHASE_NAME]",
  "complexity": "[PHASE_COMPLEXITY]",
  "standards_file": "[PATH_TO_CLAUDE_MD]",
  "plan_file": "[CURRENT_PLAN_PATH]",
  "orchestration": {
    "workflow_id": "[WORKFLOW_ID]",
    "coordination_hub": true,
    "resource_manager": {
      "allocation_id": "[ALLOCATION_ID]",
      "max_agents": "[ALLOCATED_AGENTS]"
    },
    "progress_broadcasting": true,
    "context_preservation": true
  }
}' '[TASK_LIST_JSON]' --orchestrated
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

#### Standalone Mode
Run tests by:
- Looking for test commands in the phase tasks
- Checking for common test patterns (npm test, pytest, make test)
- Running language-specific test commands based on project type

#### Orchestration Mode
1. **Pre-Test Resource Check**:
   ```bash
   /resource-manager status $ALLOCATION_ID '{
     "check_availability": true,
     "verify_test_resources": true
   }'
   ```

2. **Broadcast Test Start**:
   ```bash
   /coordination-hub $WORKFLOW_ID publish-event '{
     "event_type": "testing_started",
     "phase_number": N,
     "test_types": ["unit", "integration"]
   }'
   ```

3. **Enhanced Test Execution**:
   - Run tests with resource monitoring
   - Capture detailed test metrics
   - Monitor for resource conflicts
   - Preserve test context for handoffs

4. **Broadcast Test Results**:
   ```bash
   /coordination-hub $WORKFLOW_ID publish-event '{
     "event_type": "testing_completed",
     "phase_number": N,
     "test_results": {
       "status": "passed|failed",
       "duration": "5m",
       "coverage": 95.2
     }
   }'
   ```

### 4. Plan Update

#### Standalone Mode
- Mark completed tasks with `[x]` instead of `[ ]`
- Add `[COMPLETED]` marker to the phase heading
- Save the updated plan file

#### Orchestration Mode
1. **Update Workflow State**:
   ```bash
   /coordination-hub $WORKFLOW_ID save-state '{
     "phase_completed": N,
     "tasks_completed": ["task_list"],
     "files_modified": ["file_list"],
     "resource_usage": "usage_snapshot"
   }'
   ```

2. **Enhanced Plan Update**:
   - Mark completed tasks with `[x]` and timestamps
   - Add `[COMPLETED - timestamp]` marker to phase heading
   - Include resource usage in completion notes
   - Save context for next phase handoff
   - Update plan file with orchestration metadata

3. **Create Phase Checkpoint**:
   ```bash
   /coordination-hub $WORKFLOW_ID checkpoint '{
     "name": "phase_N_complete",
     "include_files": true,
     "validate_state": true
   }'
   ```

### 5. Git Commit

#### Standalone Mode
Create a structured commit:
```
feat: implement Phase N - Phase Name

Automated implementation of phase N from implementation plan
All tests passed successfully

Co-Authored-By: Claude <noreply@anthropic.com>
```

#### Orchestration Mode
Create an enhanced orchestration-aware commit:
```
feat: implement Phase N - Phase Name [ORCHESTRATED]

Automated implementation of phase N from implementation plan
Workflow ID: workflow_123
Resource Allocation: alloc_456
All tests passed successfully

Orchestration Context:
- Agents Used: 4
- Parallel Execution: Yes
- Resource Usage: CPU 2 cores, Memory 3.5GB
- Duration: 25 minutes
- Handoff Context: Preserved for Phase N+1

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

#### Post-Commit Actions (Orchestration Mode)
1. **Broadcast Phase Completion**:
   ```bash
   /coordination-hub $WORKFLOW_ID publish-event '{
     "event_type": "phase_completed",
     "phase_number": N,
     "commit_hash": "$COMMIT_HASH",
     "duration": "actual_duration",
     "resource_efficiency": efficiency_score
   }'
   ```

2. **Update Resource Usage**:
   ```bash
   /resource-manager usage $ALLOCATION_ID '{
     "phase_completed": N,
     "actual_usage": "usage_metrics",
     "efficiency_score": score
   }'
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

### Standalone Mode
If tests fail or issues arise:
1. I'll show the error details
2. We'll fix the issues together
3. Re-run tests before proceeding
4. Only move forward when tests pass

### Orchestration Mode Enhanced Error Handling

#### Task-Level Error Recovery
```bash
# Broadcast error event
/coordination-hub $WORKFLOW_ID publish-event '{
  "event_type": "task_failed",
  "phase_number": N,
  "task_id": "task_456",
  "error": {
    "type": "test_failure",
    "message": "Unit tests failed",
    "recovery_strategy": "retry_with_context"
  }
}'

# Create error checkpoint
/coordination-hub $WORKFLOW_ID checkpoint '{
  "name": "error_phase_N_task_456",
  "error_context": true,
  "preserve_state": true
}'
```

#### Phase-Level Error Recovery
1. **Error Analysis**:
   - Analyze error context and dependencies
   - Check for resource conflicts
   - Evaluate recovery options

2. **Intelligent Recovery**:
   - Attempt automated fixes
   - Retry with different resource allocation
   - Fallback to sequential execution
   - Preserve successful partial progress

3. **Context Preservation**:
   ```bash
   /coordination-hub $WORKFLOW_ID save-state '{
     "error_state": true,
     "partial_completion": "completion_status",
     "recovery_context": "recovery_data",
     "next_actions": ["recommended_actions"]
   }'
   ```

#### Workflow-Level Error Handling
```bash
# Broadcast critical failure
/coordination-hub $WORKFLOW_ID publish-event '{
  "event_type": "workflow_failed",
  "severity": "critical",
  "error": {
    "phase": N,
    "root_cause": "error_analysis",
    "impact": "workflow_impact"
  },
  "recovery_plan": {
    "checkpoint_available": true,
    "last_good_state": "checkpoint_id",
    "recommended_action": "restore_and_retry"
  }
}'

# Release resources on critical failure
/resource-manager release '{
  "allocation_id": "$ALLOCATION_ID",
  "reason": "workflow_failure",
  "preserve_metrics": true
}'
```

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

## Resource Integration

### Resource Allocation Workflow

#### Pre-Implementation Resource Analysis
```bash
# Analyze plan for resource requirements
/resource-manager plan-capacity '{
  "workflow_type": "implementation",
  "plan_file": "$PLAN_FILE",
  "phases": N,
  "estimated_duration": "2h",
  "complexity": "medium|high|low"
}'

# Request resource allocation
/resource-manager allocate '{
  "workflow_id": "$WORKFLOW_ID",
  "priority": "high",
  "resources": {
    "cpu_cores": 4,
    "memory_gb": 8,
    "agents": 6,
    "duration": "2h"
  },
  "files": ["exclusive_access_files"],
  "conflict_prevention": true
}'
```

#### Runtime Resource Monitoring
```bash
# Monitor resource usage during implementation
/resource-manager monitor '{
  "allocation_id": "$ALLOCATION_ID",
  "track_efficiency": true,
  "alert_thresholds": {
    "cpu_usage": 80,
    "memory_usage": 85,
    "agent_utilization": 90
  }
}'
```

#### Resource Optimization
```bash
# Optimize resource allocation during execution
/resource-manager optimize '{
  "allocation_id": "$ALLOCATION_ID",
  "target": "efficiency",
  "constraints": ["maintain_performance"],
  "auto_adjust": true
}'
```

#### Post-Implementation Resource Cleanup
```bash
# Release resources and generate usage report
/resource-manager release '{
  "allocation_id": "$ALLOCATION_ID",
  "generate_report": true,
  "archive_metrics": true,
  "cleanup_temp_resources": true
}'
```

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

#### Standalone Mode Metrics
When /subagents was used, include:
- **Phases Parallelized**: Number and percentage of phases that used parallel execution
- **Time Savings**: Estimated time saved through parallelization
- **Success Rate**: Percentage of successful parallel executions
- **Fallback Rate**: How often sequential execution was required
- **Task Distribution**: Average tasks per parallel group

#### Orchestration Mode Metrics
When orchestration was used, include comprehensive metrics:
- **Workflow Orchestration**:
  - Total workflow duration vs estimated
  - Resource allocation efficiency
  - Context handoff success rate
  - Error recovery instances
- **Resource Utilization**:
  - CPU efficiency per phase
  - Memory usage patterns
  - Agent pool utilization
  - Resource conflict incidents
- **Coordination Performance**:
  - Event broadcasting latency
  - State synchronization time
  - Checkpoint creation overhead
  - Recovery operation duration
- **Integration Efficiency**:
  - Coordination hub response times
  - Resource manager operation latency
  - Subagents orchestration overhead
  - Cross-component communication efficiency

### Summary Format

#### Standalone Mode Summary
```markdown
# Implementation Summary: [Feature Name]

## Metadata
- **Date Completed**: [YYYY-MM-DD]
- **Plan**: [Link to plan file]
- **Research Reports**: [Links to reports used]
- **Phases Completed**: [N/N]
- **Execution Mode**: Standalone

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

#### Orchestration Mode Summary
```markdown
# Implementation Summary: [Feature Name] [ORCHESTRATED]

## Metadata
- **Date Completed**: [YYYY-MM-DD]
- **Plan**: [Link to plan file]
- **Research Reports**: [Links to reports used]
- **Phases Completed**: [N/N]
- **Execution Mode**: Orchestrated
- **Workflow ID**: [workflow_123]
- **Resource Allocation**: [alloc_456]

## Implementation Overview
[Brief description of what was implemented]

## Orchestration Performance
- **Total Duration**: [actual vs estimated]
- **Resource Efficiency**: [efficiency_score]%
- **Parallel Execution**: [phases_parallelized]/[total_phases]
- **Context Handoffs**: [successful_handoffs]/[total_handoffs]
- **Error Recoveries**: [recovery_count] (all successful)

## Resource Utilization
- **CPU Usage**: Peak [peak]%, Average [avg]%
- **Memory Usage**: Peak [peak]GB, Average [avg]GB
- **Agents Used**: Max [max], Average [avg]
- **Conflicts Resolved**: [conflict_count]

## Key Changes
- [Major change 1] (Phase N, Duration: Xm)
- [Major change 2] (Phase M, Duration: Ym)

## Test Results
[Summary of test outcomes with orchestration metrics]

## Coordination Metrics
- **Event Broadcasting**: [event_count] events, [avg_latency]ms avg latency
- **State Synchronization**: [sync_operations] operations, [success_rate]% success
- **Checkpoints Created**: [checkpoint_count]
- **Recovery Operations**: [recovery_count]

## Resource Management
- **Allocation Efficiency**: [efficiency_score]%
- **Conflict Prevention**: [conflicts_prevented] conflicts avoided
- **Performance Optimization**: [optimization_actions] optimizations applied
- **Cleanup Status**: All resources released successfully

## Report Integration
[How research informed implementation]

## Integration Performance
- **Coordination Hub**: [response_time]ms avg response
- **Resource Manager**: [operation_time]ms avg operation time
- **Subagents**: [efficiency_score]% orchestration efficiency

## Lessons Learned
[Insights from implementation]

## Orchestration Benefits
- **Time Savings**: [time_saved] vs standalone execution
- **Resource Optimization**: [resource_savings]% resource efficiency gain
- **Error Resilience**: [error_recovery_rate]% successful error recovery
- **Scalability**: [scalability_metrics] scalability improvements
```

## Workflow Completion and Cleanup

### Orchestration Mode Completion

After all phases are complete and the summary is generated, orchestration mode performs additional cleanup:

#### 1. Final State Archival
```bash
# Archive final workflow state
/coordination-hub $WORKFLOW_ID complete '{
  "cleanup_resources": true,
  "archive_state": true,
  "generate_report": true,
  "notify_stakeholders": ["team"]
}'

# Save final state to coordination hub
/coordination-hub $WORKFLOW_ID save-state '{
  "final_state": true,
  "implementation_summary": "$SUMMARY_FILE",
  "success_metrics": "$PERFORMANCE_METRICS",
  "archive_location": "$ARCHIVE_PATH"
}'
```

#### 2. Resource Cleanup and Reporting
```bash
# Generate final resource usage report
/resource-manager usage $ALLOCATION_ID '{
  "final_report": true,
  "efficiency_analysis": true,
  "recommendations": true,
  "export_metrics": true
}'

# Release all allocated resources
/resource-manager release '{
  "allocation_id": "$ALLOCATION_ID",
  "cleanup_temp_files": true,
  "archive_metrics": true,
  "generate_efficiency_report": true
}'
```

#### 3. Final Progress Broadcast
```bash
# Broadcast implementation completion
/coordination-hub $WORKFLOW_ID publish-event '{
  "event_type": "implementation_completed",
  "status": "success",
  "total_duration": "$TOTAL_DURATION",
  "phases_completed": "$TOTAL_PHASES",
  "summary_file": "$SUMMARY_FILE",
  "performance_metrics": {
    "resource_efficiency": "$EFFICIENCY_SCORE",
    "parallel_phases": "$PARALLEL_COUNT",
    "error_recoveries": "$RECOVERY_COUNT",
    "overall_success_rate": "100%"
  }
}'
```

#### 4. Integration Verification
```bash
# Verify all integrations completed successfully
echo "Verifying orchestration cleanup..."
echo "✓ Coordination hub state archived"
echo "✓ Resources released and metrics saved"
echo "✓ Final events broadcasted"
echo "✓ Integration points cleaned up"
echo "✓ Workflow marked as completed"
```

### Backward Compatibility

All orchestration features are additive and preserve full backward compatibility:

- **No orchestration flag**: Runs in traditional standalone mode
- **Existing scripts**: Continue to work without modification
- **Plan format**: No changes required to existing plan files
- **Command interface**: All existing arguments and behaviors preserved
- **Output format**: Standalone mode output unchanged

### Integration Summary

The enhanced `/implement` command now provides:

1. **Dual-Mode Operation**: Seamless switching between standalone and orchestrated execution
2. **Progress Broadcasting**: Real-time event publishing for workflow monitoring
3. **Resource Management**: Intelligent resource allocation and conflict prevention
4. **Context Preservation**: Comprehensive state management for workflow handoffs
5. **Enhanced Error Handling**: Workflow-aware recovery mechanisms
6. **Performance Optimization**: Resource usage monitoring and optimization
7. **Comprehensive Reporting**: Detailed metrics for both execution modes

This implementation maintains the existing functionality while adding powerful orchestration capabilities that integrate seamlessly with the coordination-hub and resource-manager systems.

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

## Orchestration Mode Initialization

### Mode Detection Logic

```bash
# Check for explicit orchestration flag
ORCHESTRATED_MODE=false
if [[ "$3" == "--orchestrated" ]]; then
    ORCHESTRATED_MODE=true
fi

# Check for existing workflow context
if [[ -f ".claude/coordination/workflows/active/"*.json ]]; then
    ORCHESTRATED_MODE=true
fi

# Check for orchestration environment variables
if [[ -n "$CLAUDE_WORKFLOW_ID" ]] || [[ -n "$CLAUDE_ORCHESTRATION_MODE" ]]; then
    ORCHESTRATED_MODE=true
fi
```

### Orchestration Setup (When Detected)

#### 1. Workflow Registration
```bash
# Create or connect to workflow in coordination hub
/coordination-hub ${WORKFLOW_ID:-$(uuidgen)} create '{
  "name": "Implementation: [Plan Name]",
  "description": "Automated implementation plan execution",
  "phases": ["extracted_from_plan"],
  "agent_requirements": {
    "min_agents": 2,
    "max_agents": 10,
    "specialized_roles": ["code", "test", "docs"]
  },
  "timeout": "4h",
  "priority": "high"
}'
```

#### 2. Resource Allocation Request
```bash
# Analyze plan for resource requirements
ESTIMATED_RESOURCES=$(analyze_plan_resources "$PLAN_FILE")

# Request resource allocation
/resource-manager allocate '{
  "workflow_id": "$WORKFLOW_ID",
  "priority": "high",
  "resources": $ESTIMATED_RESOURCES,
  "conflict_prevention": true,
  "auto_optimize": true
}'
```

#### 3. Progress Broadcasting Setup
```bash
# Initialize event subscriptions
/coordination-hub $WORKFLOW_ID subscribe-event '{
  "patterns": ["*.phase_completed", "*.error", "*.recovery"],
  "delivery": "realtime",
  "callback": "implementation_monitor"
}'

# Set up progress tracking
echo "Orchestration mode enabled for workflow: $WORKFLOW_ID"
echo "Resource allocation: $ALLOCATION_ID"
echo "Progress broadcasting: Active"
```

Let me start by finding your implementation plan.