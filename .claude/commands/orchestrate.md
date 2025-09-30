---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob
argument-hint: "\"<workflow-description>\" [--dry-run] [--template=<template-name>] [--priority=<high|medium|low>]"
description: "Multi-agent workflow orchestration for complete research → planning → implementation workflows"
command-type: orchestration
dependent-commands: coordination-hub, resource-manager, workflow-status, report, plan, implement, debug, refactor, document, test, test-all, subagents
---

# Multi-Agent Workflow Orchestration

I'll coordinate a complete development workflow from your description through research, planning, implementation, and testing phases using intelligent multi-agent coordination.

## Workflow Orchestration Engine

Let me parse your workflow description and orchestrate a comprehensive development process.

### 1. Workflow Analysis and Planning

First, I'll analyze your workflow description to determine:
- **Workflow Type**: Feature development, bug fix, research project, documentation update
- **Complexity Assessment**: Resource requirements, estimated duration, parallelization opportunities
- **Phase Requirements**: Which phases are needed (research, planning, implementation, testing, documentation)
- **Dependencies**: External services, tools, or knowledge domains required

### 2. Infrastructure Initialization

#### Coordination Hub Integration
```bash
# Create workflow in coordination hub
/coordination-hub create-workflow '{
  "description": "[USER_DESCRIPTION]",
  "phases": ["research", "planning", "implementation", "testing", "documentation"],
  "priority": "[high|medium|low]",
  "estimated_duration": "[ESTIMATED_TIME]",
  "parallelization_potential": "[HIGH|MEDIUM|LOW]"
}'
```

#### Resource Management Setup
```bash
# Analyze and allocate resources
/resource-manager analyze-requirements '{
  "workflow_type": "[WORKFLOW_TYPE]",
  "complexity": "[COMPLEXITY_ASSESSMENT]",
  "phases": ["[PHASE_LIST]"],
  "concurrent_workflows": "[CURRENT_LOAD]"
}'

# Request resource allocation
/resource-manager allocate '{
  "workflow_id": "[WORKFLOW_ID]",
  "priority": "[PRIORITY]",
  "resources": {
    "agents": "[ESTIMATED_AGENTS]",
    "memory": "[ESTIMATED_MEMORY]",
    "duration": "[ESTIMATED_DURATION]"
  }
}'
```

#### Monitoring Infrastructure
```bash
# Initialize workflow monitoring
/workflow-status initialize '[WORKFLOW_ID]' '{
  "phases": ["[PHASE_LIST]"],
  "milestones": ["[MILESTONE_LIST]"],
  "notification_preferences": "realtime"
}'
```

### 3. Workflow Execution Engine

#### Phase Coordination Framework

Each phase follows a standardized coordination pattern:

**Phase Structure:**
```yaml
phase_execution:
  pre_phase:
    - context_validation
    - resource_verification
    - dependency_checking
    - checkpoint_creation

  execution:
    - agent_coordination
    - parallel_task_management
    - progress_monitoring
    - error_handling

  post_phase:
    - results_validation
    - context_handoff_preparation
    - checkpoint_update
    - next_phase_preparation
```

#### Research Phase Coordination
```bash
# Coordinate research activities based on workflow description
/subagents '{
  "phase": "research",
  "workflow_id": "[WORKFLOW_ID]",
  "context": "[WORKFLOW_CONTEXT]"
}' '[
  {
    "command": "/report",
    "topic": "[RESEARCH_TOPIC_1]",
    "depth": "comprehensive"
  },
  {
    "command": "/debug",
    "scope": "[DEBUG_SCOPE]",
    "analysis_type": "root_cause"
  },
  {
    "command": "/refactor",
    "target": "[REFACTOR_TARGET]",
    "assessment_type": "opportunity_analysis"
  }
]' --orchestrated
```

#### Planning Phase Coordination
```bash
# Synthesize research into implementation plan
/plan '[FEATURE_DESCRIPTION]' \
  --reports="[RESEARCH_REPORT_PATHS]" \
  --workflow-context="[WORKFLOW_ID]" \
  --orchestrated
```

#### Implementation Phase Coordination
```bash
# Execute implementation with orchestration context
/implement '[PLAN_FILE_PATH]' \
  --orchestrated \
  --workflow-id="[WORKFLOW_ID]" \
  --resource-allocation="[ALLOCATION_ID]"
```

#### Testing Phase Coordination
```bash
# Coordinate testing based on implementation changes
/test '[IMPLEMENTATION_SCOPE]' \
  --workflow-context="[WORKFLOW_ID]" \
  --orchestrated

/test-all \
  --workflow-context="[WORKFLOW_ID]" \
  --coverage-analysis \
  --orchestrated
```

#### Documentation Phase Coordination
```bash
# Update documentation based on changes
/document '[CHANGE_DESCRIPTION]' \
  --workflow-context="[WORKFLOW_ID]" \
  --scope="affected_areas" \
  --orchestrated
```

### 4. Workflow State Management

#### Context Preservation
```json
{
  "workflow_context": {
    "workflow_id": "workflow_[UUID]",
    "description": "[USER_DESCRIPTION]",
    "current_phase": "[CURRENT_PHASE]",
    "phase_results": {
      "research": {
        "reports": ["[REPORT_PATHS]"],
        "insights": ["[KEY_INSIGHTS]"],
        "dependencies": ["[DISCOVERED_DEPENDENCIES]"]
      },
      "planning": {
        "plan_file": "[PLAN_PATH]",
        "phases": "[IMPLEMENTATION_PHASES]",
        "resource_requirements": "[RESOURCE_ANALYSIS]"
      },
      "implementation": {
        "completed_phases": ["[PHASE_LIST]"],
        "files_modified": ["[FILE_LIST]"],
        "tests_passing": true
      }
    },
    "resource_allocation": {
      "allocation_id": "[ALLOCATION_ID]",
      "agents_allocated": "[AGENT_COUNT]",
      "resource_utilization": "[UTILIZATION_METRICS]"
    }
  }
}
```

#### Checkpoint Management
```bash
# Create checkpoints at phase boundaries
/coordination-hub checkpoint '[WORKFLOW_ID]' '{
  "checkpoint_type": "phase_boundary",
  "phase": "[CURRENT_PHASE]",
  "context": "[PHASE_CONTEXT]",
  "validation_passed": true
}'
```

### 5. Error Handling and Recovery

#### Multi-Level Error Handling
```yaml
error_handling:
  task_level:
    - retry_with_context
    - agent_reallocation
    - fallback_strategies

  phase_level:
    - checkpoint_recovery
    - context_reconstruction
    - alternative_approach

  workflow_level:
    - workflow_recovery
    - resource_reallocation
    - graceful_degradation
```

#### Recovery Integration
```bash
# Integrate with workflow recovery system
/workflow-recovery analyze-failure '[WORKFLOW_ID]' '{
  "failure_context": "[ERROR_CONTEXT]",
  "recovery_priority": "maintain_progress",
  "fallback_options": ["checkpoint_restore", "phase_restart", "manual_intervention"]
}'
```

### 6. Real-Time Monitoring and Control

#### Progress Tracking
```bash
# Monitor workflow progress in real-time
/workflow-status '[WORKFLOW_ID]' --detailed --realtime

# Aggregate progress across phases
/progress-aggregator workflow-summary '[WORKFLOW_ID]' '{
  "include_predictions": true,
  "bottleneck_analysis": true,
  "optimization_suggestions": true
}'
```

#### Performance Monitoring
```bash
# Monitor and optimize workflow performance
/performance-monitor workflow '[WORKFLOW_ID]' '{
  "metrics": ["execution_time", "resource_efficiency", "agent_utilization"],
  "optimization": "continuous",
  "recommendations": "realtime"
}'
```

### 7. Workflow Completion and Summary

#### Results Synthesis
After all phases complete:
1. **Aggregate Results**: Collect outputs from all phases
2. **Generate Summary**: Create comprehensive workflow summary
3. **Update Documentation**: Cross-link all generated artifacts
4. **Performance Report**: Analyze orchestration efficiency
5. **Resource Cleanup**: Release allocated resources
6. **Archive State**: Store workflow state for future reference

#### Success Validation
```bash
# Validate workflow completion
/coordination-hub validate-completion '[WORKFLOW_ID]' '{
  "validation_criteria": [
    "all_phases_completed",
    "tests_passing",
    "documentation_updated",
    "artifacts_cross_linked"
  ]
}'
```

## Workflow Templates

### Template Integration
```bash
# Use predefined workflow templates
/workflow-template apply '[TEMPLATE_NAME]' '{
  "customization": "[CUSTOMIZATION_PARAMETERS]",
  "workflow_description": "[USER_DESCRIPTION]"
}'
```

### Available Templates
- **feature-development**: Complete feature development workflow
- **bug-fix**: Focused bug investigation and resolution
- **research-implementation**: Research-heavy development workflow
- **documentation-update**: Documentation-focused workflow
- **refactoring**: Code quality improvement workflow

## Command Options

### Core Arguments
- **workflow-description**: Natural language description of the desired workflow
- **--dry-run**: Preview the orchestration plan without execution
- **--template**: Use a predefined workflow template
- **--priority**: Set workflow priority (high, medium, low)

### Advanced Options
- **--max-agents**: Limit concurrent agents (default: based on resource availability)
- **--timeout**: Overall workflow timeout (default: 4 hours)
- **--checkpoint-interval**: Checkpoint frequency (default: per phase)
- **--monitoring-level**: Monitoring detail level (minimal, standard, verbose)
- **--recovery-strategy**: Failure recovery approach (aggressive, conservative, manual)

## Integration Patterns

### Command Dependencies
The orchestrate command coordinates with all ecosystem commands:
- **Infrastructure**: coordination-hub, resource-manager, workflow-status
- **Research**: report, debug, refactor
- **Planning**: plan, dependency-resolver, workflow-template
- **Implementation**: implement, subagents
- **Testing**: test, test-all
- **Documentation**: document
- **Monitoring**: performance-monitor, progress-aggregator
- **Recovery**: workflow-recovery

### Event-Driven Coordination
```yaml
event_integration:
  workflow_events:
    - phase_started
    - phase_completed
    - checkpoint_created
    - error_encountered
    - recovery_initiated

  coordination_events:
    - resource_allocated
    - agent_assigned
    - conflict_detected
    - optimization_applied
```

## Orchestration Intelligence

### Adaptive Workflow Management
- **Dynamic Resource Allocation**: Adjust resources based on real-time needs
- **Intelligent Phase Sequencing**: Optimize phase order based on dependencies
- **Automatic Parallelization**: Identify and exploit parallelization opportunities
- **Context-Aware Decision Making**: Adapt strategies based on workflow context

### Learning and Optimization
- **Performance Pattern Recognition**: Learn from previous workflow executions
- **Resource Utilization Optimization**: Improve resource allocation over time
- **Error Pattern Analysis**: Proactively prevent common failure modes
- **Template Refinement**: Enhance templates based on execution outcomes

## Usage Examples

### Basic Feature Development
```bash
/orchestrate "Add user authentication with JWT tokens to the web application"
```

### Research-Heavy Project
```bash
/orchestrate "Research and implement microservices architecture for better scalability" --template=research-implementation
```

### Bug Fix Workflow
```bash
/orchestrate "Fix the memory leak in the data processing pipeline" --template=bug-fix --priority=high
```

### Complex Multi-Phase Project
```bash
/orchestrate "Implement real-time collaboration features with websockets, including presence indicators, live cursors, and conflict resolution" --max-agents=8 --timeout=8h
```

## Success Metrics

### Workflow Efficiency
- **Time to Completion**: Total workflow execution time
- **Resource Utilization**: Efficiency of agent and system resource usage
- **Parallelization Effectiveness**: Speedup achieved through parallel execution
- **Context Preservation**: Accuracy of context handoffs between phases

### Quality Metrics
- **Test Coverage**: Comprehensive testing of implemented features
- **Documentation Quality**: Completeness and accuracy of generated documentation
- **Cross-Linking**: Integration quality in specs directory
- **Error Rate**: Frequency of workflow failures and recovery success

### User Experience
- **Workflow Clarity**: Clarity of orchestration plan and progress reporting
- **Intervention Needs**: Frequency of required manual intervention
- **Predictability**: Accuracy of time and resource estimates
- **Satisfaction**: Overall user satisfaction with orchestrated workflows

---

The `/orchestrate` command transforms the development experience from manual command coordination to intelligent, automated workflow orchestration, providing unprecedented efficiency and quality in complex development tasks while maintaining full transparency and control over the process.