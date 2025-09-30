---
allowed-tools: Task, TodoWrite, Read, Bash
argument-hint: <phase-context> <task-list> [options]
description: Enhanced parallel task execution with cross-workflow coordination for orchestration
command-type: utility
dependent-commands: implement, coordination-hub, resource-manager
---

# Enhanced Parallel Task Execution with Cross-Workflow Coordination

I'll analyze the provided tasks and execute suitable ones in parallel using subagents with orchestration-level coordination capabilities, then return consolidated results. This enhanced utility provides cross-workflow resource management, conflict detection, and global performance optimization.

## Orchestration Enhancements

### Cross-Workflow Coordination Features
- **Global Resource Pool Management**: Coordinate resource allocation across multiple concurrent workflows
- **Workflow-Aware Task Scheduling**: Prioritize tasks based on workflow criticality and interdependencies
- **Cross-Workflow Conflict Detection**: Prevent resource conflicts and file collisions across workflows
- **Global Performance Metrics**: Collect and optimize performance across all active workflows
- **Orchestration Context Preservation**: Maintain workflow-specific context and optimization strategies

## Task Execution Engine

Let me parse your phase context and task list to determine the optimal execution strategy.

### 1. Enhanced Input Parsing and Workflow Registration
First, I'll parse the provided arguments with orchestration awareness:
- Extract phase context (JSON object with phase info)
- Parse task list (array of task objects)
- **Register workflow with coordination-hub** for cross-workflow tracking
- **Query resource-manager** for current resource availability
- Validate argument structure and completeness
- Set execution options (defaults or user-provided)
- **Extract workflow metadata**: priority, resource requirements, interdependencies

### 2. Enhanced Task Analysis with Cross-Workflow Awareness
For each task in the list:
- Analyze task description for dependency keywords
- Extract file operation patterns (CREATE/MODIFY/READ)
- Calculate independence score (0-100)
- Identify potential file conflicts
- **Query coordination-hub for active workflow conflicts**
- **Check resource-manager for resource availability and conflicts**
- **Apply workflow-aware priority scoring** based on workflow criticality
- Group tasks by parallelizability with cross-workflow considerations

### 3. Enhanced Execution Decision Matrix with Orchestration Logic
Based on analysis results and cross-workflow considerations:
- **Score >= 70 AND >= 3 tasks AND no cross-workflow conflicts**: Proceed with parallel execution
- **Score 40-69 OR minor cross-workflow conflicts**: Use sequential execution with batching
- **Score < 40 OR major resource contention**: Fallback to sequential execution
- **Blocking conflicts detected OR critical workflows active**: Sequential execution required
- **Resource pool exhausted**: Queue for later execution or coordinate with resource-manager

### 4. Enhanced Parallel Execution with Cross-Workflow Orchestration
If parallelization is viable:
- Generate optimized prompts for each parallel group
- **Reserve resources through resource-manager** before execution
- **Update coordination-hub with execution plan** for cross-workflow visibility
- Execute tasks simultaneously using Task tool batch calls
- **Monitor execution progress with global performance tracking**
- **Coordinate with other active workflows** to prevent conflicts
- Handle partial failures gracefully with workflow-aware recovery
- Validate results against success criteria
- **Release reserved resources** after completion

### 5. Enhanced Result Aggregation with Global Performance Tracking
After execution completes:
- Parse individual agent responses
- Validate task completion status
- Aggregate results into structured format
- **Update global performance metrics** in coordination-hub
- **Report cross-workflow performance impact** and optimizations
- Generate summary for /implement consumption
- **Calculate resource efficiency and utilization metrics**
- **Update workflow priority scores** based on performance data
- **Recommend global optimization strategies** across all workflows

## Arguments
- **phase-context**: JSON object with phase number, name, complexity, file paths, and **workflow metadata**
- **task-list**: Array of task objects with descriptions and markers
- **options**: Configuration flags (--dry-run, --max-agents=N, --verbose, **--workflow-priority=N**, **--coordination-mode=active|passive**, **--resource-reserve=N**)

## Cross-Workflow Coordination System

### Global Resource Pool Management

#### Resource Pool Architecture
```json
{
  "global_resource_pool": {
    "available_agents": 50,
    "reserved_agents": 15,
    "active_workflows": 3,
    "resource_allocation": {
      "workflow_A": {"agents": 10, "priority": "high", "estimated_completion": "2024-01-15T14:30:00Z"},
      "workflow_B": {"agents": 5, "priority": "medium", "estimated_completion": "2024-01-15T14:45:00Z"}
    },
    "queue": [
      {"workflow_id": "workflow_C", "requested_agents": 8, "priority": "low", "queued_at": "2024-01-15T14:20:00Z"}
    ]
  }
}
```

#### Resource Allocation Strategies
1. **Priority-Based Allocation**: High-priority workflows get resource preference
2. **Fair Share Scheduling**: Balanced resource distribution across workflows
3. **Critical Path Optimization**: Prioritize workflows on critical dependency paths
4. **Resource Pool Expansion**: Dynamic scaling based on demand patterns

#### Resource Conflict Resolution
```
Conflict Detection Algorithm:
1. Query resource-manager for current allocations
2. Calculate required resources for current workflow
3. Identify potential conflicts with active workflows
4. Apply resolution strategy:
   - QUEUE: Wait for resources to become available
   - NEGOTIATE: Reduce resource requirements
   - PREEMPT: Take resources from lower-priority workflows
   - SCALE: Request additional resources from infrastructure
```

### Workflow-Aware Task Scheduling

#### Scheduling Algorithm Components
1. **Workflow Criticality Assessment**:
   ```
   Critical Factors:
   - Workflow deadline proximity
   - Dependency chain impact
   - Resource utilization efficiency
   - Cross-workflow blocking potential
   ```

2. **Inter-Workflow Dependency Mapping**:
   ```json
   {
     "workflow_dependencies": {
       "workflow_A": {
         "blocks": ["workflow_C"],
         "blocked_by": [],
         "shared_resources": ["file_system_locks", "database_connections"]
       }
     }
   }
   ```

3. **Dynamic Priority Adjustment**:
   - Real-time priority scoring based on resource availability
   - Workflow aging to prevent starvation
   - Performance-based priority boosts

#### Task Scheduling Decision Matrix
```
High Priority Workflows (Score >= 90):
- Immediate resource allocation
- Preemption rights over lower-priority workflows
- Dedicated resource pool reservation

Medium Priority Workflows (Score 60-89):
- Standard resource allocation
- Fair share scheduling
- Queue position based on arrival time

Low Priority Workflows (Score < 60):
- Best-effort resource allocation
- Extended queue tolerance
- Background execution during low-demand periods
```

### Cross-Workflow Conflict Detection and Prevention

#### File System Conflict Detection
```
Conflict Detection Process:
1. Query coordination-hub for active file operations across all workflows
2. Build global file operation matrix:
   {
     "file_path": {
       "current_operations": ["READ", "WRITE"],
       "workflows": ["workflow_A", "workflow_B"],
       "lock_status": "exclusive_write",
       "estimated_completion": "2024-01-15T14:35:00Z"
     }
   }
3. Check proposed operations against active matrix
4. Flag conflicts and suggest resolution strategies
```

#### Resource Lock Management
- **Shared Read Locks**: Multiple workflows can read the same resources
- **Exclusive Write Locks**: Only one workflow can modify a resource
- **Hierarchical Locking**: Directory-level locks for file system operations
- **Timeout-Based Release**: Automatic lock release after timeout

#### Conflict Prevention Strategies
1. **Predictive Analysis**: Forecast potential conflicts based on task patterns
2. **Resource Partitioning**: Isolate workflows to non-overlapping resource sets
3. **Temporal Separation**: Schedule conflicting operations at different times
4. **Alternative Resource Mapping**: Redirect operations to equivalent resources

### Global Performance Metrics Collection

#### Metrics Collection Framework
```json
{
  "global_performance_metrics": {
    "timestamp": "2024-01-15T14:30:00Z",
    "system_wide": {
      "total_workflows_active": 3,
      "total_agents_utilized": 15,
      "average_task_completion_time": "2.3s",
      "resource_utilization_percentage": 78,
      "conflict_resolution_rate": 0.95
    },
    "workflow_specific": {
      "workflow_A": {
        "parallelization_efficiency": 0.85,
        "resource_allocation_score": 92,
        "cross_workflow_conflict_count": 2,
        "performance_trend": "improving"
      }
    },
    "optimization_opportunities": [
      {
        "type": "resource_reallocation",
        "description": "Workflow B could benefit from additional 2 agents",
        "estimated_improvement": "15% faster completion"
      }
    ]
  }
}
```

#### Performance Optimization Recommendations
1. **Resource Reallocation Suggestions**: Optimize resource distribution
2. **Workflow Sequencing Optimization**: Suggest better execution order
3. **Conflict Hotspot Identification**: Identify frequently conflicting resources
4. **Capacity Planning**: Recommend infrastructure scaling

### Integration with Coordination Infrastructure

#### Coordination-Hub Integration Points
```
Key Integration Functions:
1. workflow_register(workflow_id, metadata)
2. workflow_update_status(workflow_id, status, progress)
3. conflict_query(resource_list, operation_type)
4. performance_report(workflow_id, metrics)
5. global_optimization_request()
```

#### Resource-Manager Integration Points
```
Key Integration Functions:
1. resource_reserve(workflow_id, resource_count, duration)
2. resource_release(workflow_id, resource_list)
3. availability_query(resource_requirements)
4. conflict_notification(resource_id, conflict_type)
5. usage_metrics_report(workflow_id, resource_usage)
```

#### Orchestration Communication Protocol
```json
{
  "orchestration_message": {
    "type": "resource_request|conflict_notification|performance_update",
    "workflow_id": "subagents_workflow_001",
    "timestamp": "2024-01-15T14:30:00Z",
    "payload": {
      "requested_resources": 5,
      "estimated_duration": "3m",
      "priority": "medium",
      "dependencies": ["workflow_A_phase_2"]
    }
  }
}
```

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
    "parallelization_score": 85,
    "cross_workflow_efficiency": 0.92,
    "resource_utilization": 0.78,
    "conflict_resolution_count": 2
  },
  "orchestration": {
    "workflow_id": "subagents_workflow_001",
    "coordination_mode": "active",
    "resource_allocation": {
      "reserved": 4,
      "actually_used": 4,
      "peak_usage": 4,
      "efficiency": 1.0
    },
    "cross_workflow_interactions": {
      "conflicts_detected": 1,
      "conflicts_resolved": 1,
      "coordination_overhead": "0.3s",
      "parallel_workflows": ["workflow_B", "workflow_C"]
    },
    "global_impact": {
      "resource_pool_utilization": 0.68,
      "system_wide_efficiency_contribution": 0.15,
      "optimization_recommendations": [
        "Consider batching similar tasks across workflows",
        "Resource pool could benefit from 2 additional agents during peak hours"
      ]
    }
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
  "standards_file": "/path/to/CLAUDE.md",
  "workflow_metadata": {
    "workflow_id": "auth_system_implementation",
    "priority": "high",
    "estimated_duration": "5m",
    "dependencies": ["workflow_setup_phase"],
    "critical_path": true
  }
}' '[
  {"id": 1, "description": "Create user authentication module", "files": ["auth/user.js"]},
  {"id": 2, "description": "Add database connection logic", "files": ["db/connection.js"]},
  {"id": 3, "description": "Implement API routes", "files": ["routes/api.js"]}
]' --max-agents=5 --workflow-priority=8 --coordination-mode=active --resource-reserve=5

# Example with cross-workflow coordination:
/subagents '{
  "phase": 3,
  "name": "Frontend Integration",
  "complexity": "Medium",
  "standards_file": "/path/to/CLAUDE.md",
  "workflow_metadata": {
    "workflow_id": "frontend_integration",
    "priority": "medium",
    "estimated_duration": "3m",
    "dependencies": ["auth_system_implementation"],
    "shared_resources": ["api_documentation", "type_definitions"]
  }
}' '[
  {"id": 1, "description": "Create React components", "files": ["src/components/Auth.tsx"]},
  {"id": 2, "description": "Add API client", "files": ["src/api/auth.ts"]}
]' --workflow-priority=6 --coordination-mode=active
```

## Configuration

Default settings (can be overridden):
- **max_agents**: 10 (resource limit)
- **timeout_per_task**: 300s (5 minutes)
- **min_parallelization_score**: 70
- **min_task_count**: 3
- **critical_phases**: [1] (never parallelize setup phases)

### Cross-Workflow Coordination Settings:
- **default_workflow_priority**: 5 (scale 1-10, higher = more priority)
- **coordination_mode**: "active" (active|passive - active participates in global coordination)
- **resource_reserve_percentage**: 0.2 (reserve 20% of requested resources for conflicts)
- **cross_workflow_timeout**: 600s (10 minutes for cross-workflow operations)
- **conflict_resolution_retries**: 3 (attempts to resolve resource conflicts)
- **global_performance_reporting**: true (contribute to system-wide metrics)
- **workflow_aging_factor**: 1.1 (priority boost factor for waiting workflows)
- **resource_pool_query_interval**: 30s (frequency of resource availability checks)

---

## Integration Notes

This enhanced command provides orchestration-level capabilities while maintaining /implement efficiency:

### Core Capabilities (Preserved):
1. **Automatic Detection**: No user intervention required
2. **Safe Parallelization**: Conservative scoring prevents issues
3. **Graceful Fallback**: Sequential execution if parallelization unsafe
4. **Performance Gains**: Significant speedup for suitable phases
5. **Full Integration**: Maintains all /implement workflows and safeguards

### Enhanced Orchestration Features:
6. **Cross-Workflow Coordination**: Seamless integration with coordination-hub and resource-manager
7. **Global Resource Management**: Intelligent resource allocation across multiple concurrent workflows
8. **Conflict Prevention**: Proactive detection and resolution of cross-workflow conflicts
9. **Performance Optimization**: System-wide performance monitoring and optimization recommendations
10. **Workflow Prioritization**: Dynamic priority adjustment based on criticality and dependencies
11. **Scalable Architecture**: Supports large-scale orchestration with efficient resource utilization
12. **Backward Compatibility**: All existing /implement integrations continue to work without modification

### Orchestration Ecosystem Integration:
- **Coordination-Hub**: Provides workflow registration, status tracking, and conflict coordination
- **Resource-Manager**: Handles resource allocation, reservation, and release management
- **Global Performance Dashboard**: Contributes metrics to system-wide performance optimization
- **Cross-Workflow Communication**: Enables workflows to coordinate and share resources efficiently