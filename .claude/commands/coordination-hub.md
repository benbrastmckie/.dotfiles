---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: <workflow-id> <operation> [parameters]
description: Central workflow coordination and state management
command-type: utility
dependent-commands: orchestrate
---

# Workflow Coordination Hub

I'll manage comprehensive workflow lifecycle operations, agent pool coordination, and persistent state management for orchestrated development workflows.

## Workflow Operations Engine

Let me parse your workflow request and execute the appropriate coordination operation.

### 1. Operation Classification and Routing

First, I'll analyze the requested operation:
- **Lifecycle Operations**: create, start, pause, resume, complete, cleanup
- **State Management**: save-state, load-state, get-status, list-workflows
- **Agent Coordination**: assign-agents, redistribute-tasks, monitor-pool
- **Event System**: publish-event, subscribe-event, get-events
- **Recovery Operations**: checkpoint, restore, rollback

### 2. Workflow Lifecycle Management

#### Create Workflow
```json
{
  "workflow_id": "unique_identifier",
  "operation": "create",
  "parameters": {
    "name": "Workflow Name",
    "description": "Workflow description",
    "phases": ["phase1", "phase2", "phase3"],
    "agent_requirements": {
      "min_agents": 2,
      "max_agents": 10,
      "specialized_roles": ["code", "test", "docs"]
    },
    "dependencies": ["external_service", "database"],
    "timeout": "2h",
    "priority": "high|medium|low"
  }
}
```

#### Start/Resume Workflow
```json
{
  "workflow_id": "workflow_123",
  "operation": "start",
  "parameters": {
    "resume_from_phase": 2,
    "agent_pool_size": 5,
    "checkpoint_interval": "15m",
    "failure_tolerance": "medium"
  }
}
```

#### Complete/Cleanup Workflow
```json
{
  "workflow_id": "workflow_123",
  "operation": "complete",
  "parameters": {
    "cleanup_resources": true,
    "archive_state": true,
    "generate_report": true,
    "notify_stakeholders": ["team", "pm"]
  }
}
```

### 3. Persistent State Management System

#### State Storage Architecture
```
.claude/coordination/
├── workflows/
│   ├── active/          # Currently running workflows
│   │   ├── workflow_123.json
│   │   └── workflow_456.json
│   ├── completed/       # Archived completed workflows
│   └── failed/          # Failed workflow states for analysis
├── checkpoints/         # Incremental state snapshots
│   ├── workflow_123/
│   │   ├── phase_1_checkpoint.json
│   │   ├── phase_2_checkpoint.json
│   │   └── latest.json
├── events/              # Event log storage
│   ├── workflow_123_events.jsonl
│   └── global_events.jsonl
└── agent_pools/         # Agent allocation tracking
    ├── pool_assignments.json
    └── agent_performance.json
```

#### State Schema Definition
```json
{
  "workflow_state": {
    "id": "workflow_123",
    "name": "Feature Implementation Workflow",
    "status": "running|paused|completed|failed",
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-15T11:45:00Z",
    "current_phase": 2,
    "total_phases": 5,
    "progress_percentage": 45.5,
    "phases": [
      {
        "phase_id": 1,
        "name": "Setup and Planning",
        "status": "completed",
        "started_at": "2025-01-15T10:30:00Z",
        "completed_at": "2025-01-15T10:45:00Z",
        "tasks": [
          {
            "task_id": "setup_env",
            "description": "Setup development environment",
            "status": "completed",
            "assigned_agent": "agent_001",
            "execution_time": "5m"
          }
        ]
      }
    ],
    "agent_assignments": {
      "agent_001": {
        "role": "code_implementation",
        "current_task": "task_456",
        "performance_score": 85.2,
        "tasks_completed": 12
      }
    },
    "dependencies": {
      "external": ["database_connection", "api_keys"],
      "internal": ["phase_1_output", "config_files"]
    },
    "configuration": {
      "max_agents": 8,
      "checkpoint_interval": "15m",
      "timeout": "2h",
      "priority": "high"
    },
    "metrics": {
      "total_execution_time": "1h 15m",
      "tasks_completed": 25,
      "tasks_failed": 2,
      "agent_efficiency": 78.3,
      "resource_utilization": 65.4
    }
  }
}
```

### 4. Agent Pool Coordination System

#### Dynamic Agent Assignment Algorithm
```
Agent Selection Process:
1. Analyze task requirements (code, test, docs, config)
2. Check agent availability and current load
3. Match agent specializations to task needs
4. Consider agent performance history
5. Balance workload across available agents
6. Assign tasks with conflict avoidance

Load Balancing Strategy:
- Monitor agent response times and success rates
- Redistribute tasks from overloaded agents
- Scale agent pool up/down based on demand
- Maintain specialized agent roles (code vs test vs docs)
```

#### Agent Performance Tracking
```json
{
  "agent_pool": {
    "total_agents": 6,
    "available_agents": 4,
    "active_assignments": 8,
    "performance_metrics": {
      "agent_001": {
        "specialization": "code_implementation",
        "success_rate": 94.2,
        "average_task_time": "12m",
        "current_load": 2,
        "max_concurrent_tasks": 3,
        "preferred_task_types": ["create_file", "modify_code"],
        "recent_performance": [95, 92, 98, 88, 94]
      },
      "agent_002": {
        "specialization": "testing",
        "success_rate": 87.8,
        "average_task_time": "8m",
        "current_load": 1,
        "max_concurrent_tasks": 4,
        "preferred_task_types": ["run_tests", "validate_code"],
        "recent_performance": [89, 91, 85, 88, 87]
      }
    }
  }
}
```

### 5. Event Hub Architecture

#### Event Publishing System
```json
{
  "event": {
    "event_id": "evt_789",
    "workflow_id": "workflow_123",
    "timestamp": "2025-01-15T11:30:00Z",
    "event_type": "phase_completed|task_failed|agent_assigned|checkpoint_created",
    "severity": "info|warning|error|critical",
    "source": "coordination_hub|agent_001|external_system",
    "data": {
      "phase_id": 2,
      "completion_time": "25m",
      "tasks_completed": 8,
      "next_phase": 3
    },
    "subscribers": ["workflow_monitor", "progress_tracker", "notification_system"],
    "metadata": {
      "correlation_id": "corr_456",
      "causation_id": "cause_123",
      "tags": ["performance", "milestone"]
    }
  }
}
```

#### Subscription Management
```json
{
  "subscriptions": {
    "workflow_monitor": {
      "event_patterns": [
        "workflow.*.phase_completed",
        "workflow.*.failed",
        "agent.*.performance_degraded"
      ],
      "delivery_method": "realtime|batch|webhook",
      "retry_policy": {
        "max_retries": 3,
        "backoff_strategy": "exponential"
      }
    },
    "progress_tracker": {
      "event_patterns": [
        "workflow.*.task_completed",
        "workflow.*.checkpoint_created"
      ],
      "filters": {
        "severity": ["info", "warning"],
        "workflow_id": ["workflow_123", "workflow_456"]
      }
    }
  }
}
```

### 6. Checkpoint and Recovery System

#### Automatic Checkpoint Creation
```
Checkpoint Triggers:
- Phase completion
- Configurable time intervals (default: 15 minutes)
- Before risky operations (file deletions, system changes)
- On agent failures or timeouts
- Manual checkpoint requests

Checkpoint Contents:
- Complete workflow state snapshot
- All modified files and their checksums
- Agent assignments and task queue states
- Dependency resolution status
- Performance metrics up to checkpoint
```

#### Recovery Coordination
```json
{
  "recovery_plan": {
    "checkpoint_id": "chkpt_789",
    "workflow_id": "workflow_123",
    "recovery_strategy": "full_restore|partial_restore|rollback",
    "restoration_steps": [
      {
        "step": 1,
        "action": "restore_workflow_state",
        "parameters": {"checkpoint": "phase_2_complete"}
      },
      {
        "step": 2,
        "action": "reassign_failed_tasks",
        "parameters": {"exclude_agents": ["agent_003"]}
      },
      {
        "step": 3,
        "action": "validate_dependencies",
        "parameters": {"check_external": true}
      }
    ],
    "fallback_options": [
      "restart_from_last_successful_phase",
      "manual_intervention_required",
      "abort_workflow"
    ]
  }
}
```

### 7. Task Distribution Optimization

#### Intelligent Task Assignment
```
Task Analysis Factors:
1. Task complexity and estimated duration
2. Required skills and agent specializations
3. File dependency conflicts
4. Agent current workload and availability
5. Historical performance on similar tasks
6. Resource requirements (memory, CPU, tools)

Optimization Algorithm:
- Calculate optimal task-to-agent mapping
- Minimize total completion time
- Balance agent workloads
- Avoid resource contention
- Maximize parallel execution opportunities
```

#### Dynamic Redistribution
```json
{
  "redistribution_trigger": {
    "trigger_type": "agent_failure|performance_degradation|load_imbalance",
    "affected_agent": "agent_003",
    "pending_tasks": ["task_789", "task_790"],
    "redistribution_strategy": {
      "method": "performance_based|round_robin|specialization_match",
      "constraints": {
        "preserve_task_order": true,
        "minimize_context_switching": true,
        "respect_agent_limits": true
      },
      "new_assignments": [
        {"task_id": "task_789", "target_agent": "agent_001", "reason": "best_match"},
        {"task_id": "task_790", "target_agent": "agent_004", "reason": "available_capacity"}
      ]
    }
  }
}
```

## Operations Implementation

### Workflow Creation and Initialization
```bash
# Create new workflow
/coordination-hub workflow_123 create '{
  "name": "Feature Implementation",
  "phases": ["setup", "implementation", "testing", "deployment"],
  "agent_requirements": {"min": 3, "max": 8},
  "timeout": "2h"
}'

# Initialize state storage and event subscriptions
# Create workflow directory structure
# Set up checkpoint schedule
# Configure agent pool requirements
```

### State Management Operations
```bash
# Save current workflow state
/coordination-hub workflow_123 save-state '{
  "include_checkpoints": true,
  "compress": true,
  "backup_location": "/backup/workflows/"
}'

# Load and restore workflow state
/coordination-hub workflow_123 load-state '{
  "checkpoint_id": "chkpt_456",
  "verify_integrity": true,
  "restore_agents": true
}'

# Get workflow status
/coordination-hub workflow_123 get-status '{
  "include_metrics": true,
  "agent_details": true,
  "recent_events": 10
}'
```

### Agent Pool Management
```bash
# Assign agents to workflow
/coordination-hub workflow_123 assign-agents '{
  "agent_count": 5,
  "specializations": ["code", "test", "docs"],
  "performance_threshold": 80
}'

# Redistribute tasks due to agent issues
/coordination-hub workflow_123 redistribute-tasks '{
  "failed_agent": "agent_003",
  "strategy": "performance_based",
  "preserve_order": true
}'
```

### Event System Operations
```bash
# Publish workflow event
/coordination-hub workflow_123 publish-event '{
  "event_type": "phase_completed",
  "data": {"phase": 2, "duration": "25m"},
  "severity": "info"
}'

# Subscribe to workflow events
/coordination-hub workflow_123 subscribe-event '{
  "patterns": ["*.task_completed", "*.failed"],
  "delivery": "realtime",
  "callback": "workflow_monitor"
}'
```

### Recovery and Maintenance
```bash
# Create manual checkpoint
/coordination-hub workflow_123 checkpoint '{
  "name": "before_critical_phase",
  "include_files": true,
  "validate_state": true
}'

# Restore from checkpoint
/coordination-hub workflow_123 restore '{
  "checkpoint_id": "chkpt_789",
  "strategy": "full_restore",
  "verify_dependencies": true
}'

# Cleanup completed workflow
/coordination-hub workflow_123 cleanup '{
  "archive_state": true,
  "remove_temp_files": true,
  "generate_report": true
}'
```

## Integration with Orchestrate Command

### Workflow Handoff Protocol
```
Orchestrate → Coordination Hub:
1. Orchestrate creates workflow via coordination-hub
2. Transfers control with workflow state
3. Monitors progress via event subscriptions
4. Receives completion notification
5. Processes final results

Coordination Hub → Orchestrate:
1. Accepts workflow from orchestrate
2. Manages execution lifecycle
3. Publishes progress events
4. Handles failures and recovery
5. Returns control on completion
```

### State Synchronization
```json
{
  "handoff_protocol": {
    "orchestrate_to_hub": {
      "workflow_definition": "complete_workflow_spec",
      "initial_state": "phase_0_ready",
      "agent_preferences": "role_specifications",
      "monitoring_config": "event_subscription_rules"
    },
    "hub_to_orchestrate": {
      "completion_status": "success|partial|failed",
      "final_state": "workflow_end_state",
      "execution_metrics": "performance_data",
      "artifact_locations": "output_file_paths"
    }
  }
}
```

## Arguments

- **workflow-id**: Unique identifier for the workflow being managed
- **operation**: Lifecycle operation (create, start, pause, resume, complete, cleanup, save-state, load-state, get-status, assign-agents, redistribute-tasks, publish-event, subscribe-event, checkpoint, restore)
- **parameters**: JSON object with operation-specific configuration

## Performance Monitoring

### Metrics Collection
```json
{
  "performance_metrics": {
    "workflow_efficiency": {
      "total_execution_time": "1h 45m",
      "planned_vs_actual": 0.95,
      "phase_completion_rate": 98.5,
      "resource_utilization": 73.2
    },
    "agent_performance": {
      "average_task_completion": "8.5m",
      "success_rate": 92.3,
      "error_recovery_time": "2.1m",
      "parallel_efficiency": 78.9
    },
    "system_health": {
      "memory_usage": "2.1GB",
      "cpu_utilization": 45.2,
      "storage_consumption": "1.2GB",
      "network_latency": "12ms"
    }
  }
}
```

## Error Handling and Resilience

### Failure Recovery Strategies
```
Agent Failures:
- Detect unresponsive agents via heartbeat monitoring
- Automatically reassign tasks to available agents
- Maintain task execution history for recovery
- Scale agent pool if persistent failures occur

State Corruption:
- Validate state integrity on load/save operations
- Maintain multiple checkpoint versions
- Implement state repair mechanisms
- Fallback to last known good state

Resource Exhaustion:
- Monitor system resource usage
- Implement task queuing and throttling
- Dynamic scaling of agent pool
- Graceful degradation of non-critical features
```

## Output Format

### Success Response
```json
{
  "status": "success",
  "operation": "workflow_operation_name",
  "workflow_id": "workflow_123",
  "timestamp": "2025-01-15T12:00:00Z",
  "result": {
    "operation_specific_data": "varies_by_operation"
  },
  "metrics": {
    "execution_time": "2.3s",
    "resources_used": "minimal",
    "agents_affected": 3
  },
  "next_steps": ["Continue with phase 3", "Monitor agent performance"]
}
```

### Error Response
```json
{
  "status": "error",
  "operation": "workflow_operation_name",
  "workflow_id": "workflow_123",
  "error": {
    "code": "WORKFLOW_NOT_FOUND",
    "message": "Workflow workflow_123 does not exist",
    "details": "Check workflow ID or create new workflow first"
  },
  "recovery_suggestions": [
    "List available workflows with 'list-workflows'",
    "Create new workflow with 'create' operation"
  ]
}
```

## Configuration

### Default Settings
```json
{
  "coordination_defaults": {
    "checkpoint_interval": "15m",
    "max_agent_pool_size": 20,
    "workflow_timeout": "4h",
    "state_compression": true,
    "event_retention": "7d",
    "performance_monitoring": true,
    "auto_recovery": true,
    "heartbeat_interval": "30s"
  }
}
```

---

## Integration Notes

This coordination hub serves as the central nervous system for orchestrated development workflows, providing:

1. **Comprehensive State Management**: Persistent, recoverable workflow states
2. **Intelligent Agent Coordination**: Dynamic load balancing and specialization matching
3. **Event-Driven Architecture**: Real-time communication and monitoring
4. **Robust Recovery Systems**: Checkpoint-based failure recovery
5. **Performance Optimization**: Continuous monitoring and adaptive resource allocation
6. **Seamless Integration**: Native compatibility with orchestrate command workflows