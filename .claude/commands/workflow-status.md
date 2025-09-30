---
allowed-tools: SlashCommand, Read, Write, TodoWrite
argument-hint: "[workflow-id] [--detailed] [--json]"
description: "Display real-time workflow status and progress"
command-type: dependent
dependent-commands: coordination-hub, resource-manager
---

# Workflow Status Monitor

I'll provide comprehensive real-time workflow monitoring and progress tracking with live status updates, interactive controls, and debugging capabilities.

## Real-Time Monitoring Engine

Let me analyze your monitoring request and provide appropriate workflow status information.

### 1. Status Operation Classification

First, I'll determine the type of status monitoring requested:
- **Live Monitoring**: Real-time status with continuous updates
- **Detailed Analysis**: Comprehensive workflow state breakdown
- **Performance Tracking**: Metrics, timings, and efficiency analysis
- **Interactive Control**: User intervention and manual override capabilities
- **Debug Information**: Troubleshooting data and error analysis

### 2. Standardized Coordination Protocols

This component implements standardized coordination protocols for workflow monitoring as defined in [`specs/standards/command-protocols.md`](../specs/standards/command-protocols.md).

#### Status Event Publishing

```bash
# Standard status update publishing
publish_status_update() {
  local workflow_id="$1"
  local status_data="$2"
  local update_type="${3:-progress}"

  local status_update="{
    \"status_update\": {
      \"update_id\": \"status_$(uuidgen)\",
      \"workflow_id\": \"$workflow_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"update_type\": \"$update_type\",
      \"current_status\": $(echo "$status_data" | jq '.status'),
      \"progress_percentage\": $(echo "$status_data" | jq '.progress'),
      \"phase_info\": $(echo "$status_data" | jq '.current_phase'),
      \"agent_status\": $(echo "$status_data" | jq '.agents'),
      \"performance_metrics\": $(echo "$status_data" | jq '.performance // {}'),
      \"health_indicators\": $(echo "$status_data" | jq '.health // {}')
    }
  }"

  # Publish status event
  publish_coordination_event "WORKFLOW_STATUS_UPDATED" "$workflow_id" "$(get_current_phase "$workflow_id")" "$status_update"
}
```

#### Real-Time Status Synchronization

```bash
# Synchronize status with coordination hub
sync_status_with_hub() {
  local workflow_id="$1"

  # Get current status from coordination hub
  local hub_status=$(send_coordination_request "coordination-hub" "get-status" "{\"workflow_id\": \"$workflow_id\", \"include_metrics\": true}")

  # Extract and update local status cache
  local hub_state=$(echo "$hub_status" | jq '.result.workflow_state')
  update_local_status_cache "$workflow_id" "$hub_state"

  # Get resource status from resource manager
  local resource_status=$(send_coordination_request "resource-manager" "monitor" "{\"workflow_id\": \"$workflow_id\", \"include_allocation\": true}")
  update_resource_status_cache "$workflow_id" "$(echo "$resource_status" | jq '.result')"

  # Combine and format for display
  generate_comprehensive_status "$workflow_id"
}
```

#### Interactive Control Protocol

```bash
# Standard user intervention handling
handle_user_control_request() {
  local workflow_id="$1"
  local control_action="$2"
  local parameters="$3"
  local user_id="${4:-system}"

  local control_request="{
    \"control_request\": {
      \"request_id\": \"ctrl_$(uuidgen)\",
      \"workflow_id\": \"$workflow_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"user_id\": \"$user_id\",
      \"action\": \"$control_action\",
      \"parameters\": $parameters,
      \"reason\": \"$(echo "$parameters" | jq -r '.reason // "User intervention"')\",
      \"approval_required\": $(requires_approval "$control_action")
    }
  }"

  case "$control_action" in
    "pause")
      # Send pause request to coordination hub
      send_coordination_request "coordination-hub" "pause-workflow" "$control_request"
      ;;
    "resume")
      # Send resume request to coordination hub
      send_coordination_request "coordination-hub" "resume-workflow" "$control_request"
      ;;
    "reassign")
      # Send task reassignment request
      send_coordination_request "coordination-hub" "reassign-task" "$control_request"
      ;;
    "emergency-stop")
      # Coordinate emergency shutdown
      coordinate_emergency_stop "$workflow_id" "$control_request"
      ;;
  esac

  # Publish control event
  publish_coordination_event "USER_INTERVENTION" "$workflow_id" "$(get_current_phase "$workflow_id")" "$control_request"
}
```

#### Status Aggregation and Reporting

```bash
# Aggregate status from multiple sources
aggregate_workflow_status() {
  local workflow_id="$1"
  local include_history="${2:-false}"

  # Collect status from all relevant components
  local hub_status=$(get_hub_status "$workflow_id")
  local resource_status=$(get_resource_status "$workflow_id")
  local performance_status=$(get_performance_status "$workflow_id")
  local recovery_status=$(get_recovery_status "$workflow_id")

  # Create comprehensive status report
  local aggregated_status="{
    \"workflow_status\": {
      \"workflow_id\": \"$workflow_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"overall_health\": $(calculate_overall_health "$hub_status" "$resource_status" "$performance_status"),
      \"coordination_data\": $hub_status,
      \"resource_data\": $resource_status,
      \"performance_data\": $performance_status,
      \"recovery_data\": $recovery_status,
      \"aggregation_confidence\": $(calculate_aggregation_confidence),
      \"last_sync\": \"$(get_last_sync_time "$workflow_id")\"
    }
  }"

  if [ "$include_history" = "true" ]; then
    local status_history=$(get_status_history "$workflow_id")
    aggregated_status=$(echo "$aggregated_status" | jq --argjson history "$status_history" '.workflow_status.history = $history')
  fi

  echo "$aggregated_status"
}
```

### 3. Workflow Status Dashboard

#### Active Workflow Overview
```
╭─ Workflow Status Dashboard ─────────────────────────────────────────╮
│ ID: workflow_123          Name: Feature Implementation               │
│ Status: ●RUNNING          Phase: 3/5 (Implementation)              │
│ Progress: ████████████░░░░ 60% Complete                           │
│ Started: 2025-01-15 10:30  Runtime: 1h 25m                        │
│ ETA: 45m remaining         Priority: HIGH                          │
├─────────────────────────────────────────────────────────────────────┤
│ Agents: 6/8 active        Tasks: 15 complete, 8 active, 12 pending │
│ Resources: CPU 45%, RAM 3.2GB, Storage 1.8GB                       │
│ Health: ●●●●○ 80%         Last Update: 2 seconds ago               │
╰─────────────────────────────────────────────────────────────────────╯
```

#### Live Phase Progress Tracking
```json
{
  "workflow_progress": {
    "current_phase": {
      "phase_id": 3,
      "name": "Implementation",
      "status": "in_progress",
      "progress_percent": 75.2,
      "started_at": "2025-01-15T11:45:00Z",
      "estimated_completion": "2025-01-15T12:30:00Z",
      "tasks": {
        "total": 24,
        "completed": 18,
        "active": 4,
        "pending": 2,
        "failed": 0
      },
      "performance": {
        "average_task_duration": "8.5m",
        "completion_rate": "2.1 tasks/min",
        "efficiency_score": 87.3
      }
    },
    "phase_timeline": [
      {
        "phase_id": 1,
        "name": "Setup",
        "status": "completed",
        "duration": "15m",
        "completion_time": "2025-01-15T10:45:00Z",
        "tasks_completed": 8,
        "success_rate": 100
      },
      {
        "phase_id": 2,
        "name": "Planning",
        "status": "completed",
        "duration": "25m",
        "completion_time": "2025-01-15T11:10:00Z",
        "tasks_completed": 12,
        "success_rate": 95.8
      }
    ]
  }
}
```

### 3. Live Status Updates System

#### Real-Time Progress Visualization
```
Current Activity Stream:
┌─ 12:15:32 ─ Agent_003 ─────────────────────────────────────────────┐
│ ✓ Completed: Update authentication module                          │
│ ⏱  Duration: 12m 34s                                              │
│ 📊 Performance: 95% efficiency                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─ 12:15:28 ─ Agent_001 ─────────────────────────────────────────────┐
│ 🔄 Working: Implement user profile component                       │
│ ⏱  Elapsed: 8m 15s / Est: 15m                                     │
│ 📈 Progress: ████████░░ 53%                                        │
└─────────────────────────────────────────────────────────────────────┘

┌─ 12:15:25 ─ System ────────────────────────────────────────────────┐
│ 📋 Task Queue: 12 pending tasks assigned to available agents       │
│ 🔧 Resource Status: All systems optimal                            │
└─────────────────────────────────────────────────────────────────────┘
```

#### Progress Indicators and Estimates
```json
{
  "live_indicators": {
    "overall_progress": {
      "percentage": 62.5,
      "visual_bar": "████████████████░░░░░░░░",
      "estimated_completion": "2025-01-15T13:15:00Z",
      "confidence_level": 85.2,
      "velocity_trend": "increasing"
    },
    "phase_breakdown": {
      "current_phase_progress": 75.2,
      "remaining_phases": [
        {"phase": 4, "name": "Testing", "estimated_duration": "30m"},
        {"phase": 5, "name": "Deployment", "estimated_duration": "15m"}
      ]
    },
    "milestone_tracking": {
      "next_milestone": "Phase 3 Complete",
      "estimated_time": "15m",
      "completion_criteria": [
        "All implementation tasks complete",
        "Code review passed",
        "Unit tests passing"
      ]
    }
  }
}
```

### 4. Interactive Control Capabilities

#### User Intervention Commands
```bash
# Pause workflow for manual intervention
/workflow-status workflow_123 --pause --reason "Manual review required"

# Resume paused workflow
/workflow-status workflow_123 --resume --checkpoint "last_stable"

# Override task assignment
/workflow-status workflow_123 --reassign task_456 --to agent_002

# Adjust workflow priority
/workflow-status workflow_123 --priority high --reason "Critical deadline"

# Manual checkpoint creation
/workflow-status workflow_123 --checkpoint --name "before_critical_change"

# Skip problematic task
/workflow-status workflow_123 --skip task_789 --reason "External dependency unavailable"
```

#### Manual Override Capabilities
```json
{
  "manual_overrides": {
    "workflow_controls": {
      "pause_workflow": {
        "command": "pause",
        "parameters": {
          "immediate": true,
          "preserve_state": true,
          "notification": "all_agents"
        }
      },
      "force_phase_transition": {
        "command": "force_next_phase",
        "parameters": {
          "skip_validation": false,
          "create_checkpoint": true,
          "reason": "Manual intervention"
        }
      },
      "emergency_stop": {
        "command": "emergency_stop",
        "parameters": {
          "save_progress": true,
          "cleanup_resources": true,
          "generate_report": true
        }
      }
    },
    "task_management": {
      "reassign_task": {
        "task_id": "task_456",
        "from_agent": "agent_003",
        "to_agent": "agent_001",
        "reason": "Performance optimization"
      },
      "modify_task_priority": {
        "task_id": "task_789",
        "new_priority": "critical",
        "impact_assessment": "may_delay_other_tasks"
      }
    }
  }
}
```

### 5. Debugging and Troubleshooting

#### Debug Information Access
```json
{
  "debug_information": {
    "workflow_health": {
      "status": "healthy",
      "issues_detected": 2,
      "warnings": [
        {
          "type": "performance_degradation",
          "agent": "agent_003",
          "severity": "medium",
          "description": "Task completion time increased by 15%",
          "suggested_action": "Consider agent reallocation"
        },
        {
          "type": "resource_constraint",
          "resource": "memory",
          "severity": "low",
          "description": "Memory usage at 78% of allocated",
          "suggested_action": "Monitor for potential allocation increase"
        }
      ]
    },
    "agent_diagnostics": {
      "agent_001": {
        "status": "active",
        "current_task": "task_456",
        "performance_score": 92.5,
        "last_response": "2025-01-15T12:15:45Z",
        "task_queue_size": 3,
        "recent_errors": 0
      },
      "agent_003": {
        "status": "degraded_performance",
        "current_task": "task_789",
        "performance_score": 73.2,
        "last_response": "2025-01-15T12:15:40Z",
        "task_queue_size": 5,
        "recent_errors": 1,
        "error_details": "Task timeout on file_operation_large_file.txt"
      }
    },
    "system_diagnostics": {
      "resource_utilization": {
        "cpu_usage": 45.2,
        "memory_usage": 78.3,
        "storage_io": "moderate",
        "network_latency": "normal"
      },
      "bottlenecks_identified": [
        {
          "type": "file_io",
          "severity": "medium",
          "description": "Large file operations causing delays",
          "affected_tasks": ["task_789", "task_790"]
        }
      ]
    }
  }
}
```

#### Error Analysis and Resolution
```
Debug Console:
┌─ Error Analysis ───────────────────────────────────────────────────┐
│ 🚨 Agent_003 Task Timeout (12:14:32)                              │
│ └─ Task: process_large_config_file.json                           │
│ └─ Timeout: 15m exceeded                                           │
│ └─ Action: Reassigned to agent_001 with increased timeout         │
│                                                                    │
│ ⚠️  Resource Warning (12:12:15)                                   │
│ └─ Memory usage approaching 80% threshold                         │
│ └─ Recommendation: Consider scaling agent pool                    │
│                                                                    │
│ ✓ Recovery Success (12:10:45)                                     │
│ └─ Workflow restored from checkpoint_phase2_complete               │
│ └─ All tasks resumed successfully                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 6. Integration with Coordination Hub

#### Status Data Synchronization
```bash
# Pull comprehensive status from coordination hub
coordination_hub_status=$(coordination-hub workflow_123 get-status '{
  "include_metrics": true,
  "agent_details": true,
  "recent_events": 10,
  "performance_data": true
}')

# Process and format for real-time display
echo "$coordination_hub_status" | jq '
  .workflow_state |
  {
    status: .status,
    current_phase: .current_phase,
    progress: .progress_percentage,
    agent_count: (.agent_assignments | length),
    active_tasks: (.phases[.current_phase].tasks | map(select(.status == "active")) | length)
  }'
```

#### Event Stream Integration
```json
{
  "event_stream_integration": {
    "subscription_config": {
      "event_patterns": [
        "workflow.*.task_completed",
        "workflow.*.task_failed",
        "workflow.*.phase_completed",
        "agent.*.performance_alert",
        "system.*.resource_warning"
      ],
      "delivery_method": "realtime",
      "callback": "workflow_status_updater"
    },
    "event_processing": {
      "task_completed": "update_progress_display",
      "task_failed": "show_error_alert",
      "phase_completed": "advance_phase_indicator",
      "performance_alert": "highlight_agent_status",
      "resource_warning": "show_resource_alert"
    }
  }
}
```

### 7. Resource Manager Integration

#### Resource Status Display
```bash
# Get current resource allocation status
resource_status=$(resource-manager monitor system '{
  "include_allocation": true,
  "include_conflicts": true,
  "include_forecasts": true
}')

# Display resource information in status dashboard
echo "$resource_status" | jq '
  .system_resources |
  {
    cpu_utilization: .compute.cpu_cores.utilization_percent,
    memory_usage: .compute.memory.utilization_percent,
    storage_available: .compute.storage.available_gb,
    active_conflicts: (.conflicts | length)
  }'
```

#### Resource Alert Integration
```json
{
  "resource_monitoring": {
    "alert_thresholds": {
      "cpu_usage": 80,
      "memory_usage": 85,
      "storage_available": 10,
      "conflict_count": 3
    },
    "alert_actions": {
      "cpu_high": "suggest_agent_reallocation",
      "memory_high": "recommend_workflow_scaling",
      "storage_low": "trigger_cleanup_operations",
      "conflicts_detected": "pause_conflicting_tasks"
    }
  }
}
```

## Live Monitoring Operations

### Continuous Status Updates
```bash
# Start live monitoring with auto-refresh
/workflow-status workflow_123 --live --refresh 5s

# Detailed status with full breakdown
/workflow-status workflow_123 --detailed --include-debug

# JSON output for integration
/workflow-status workflow_123 --json --include-all
```

### Interactive Control Session
```bash
# Interactive control mode
/workflow-status workflow_123 --interactive

# Available commands in interactive mode:
# - pause/resume workflow
# - reassign tasks
# - create checkpoints
# - view debug info
# - adjust priorities
# - force phase transitions
# - emergency stop
```

### Performance Monitoring
```bash
# Performance analysis mode
/workflow-status workflow_123 --performance --timeframe 1h

# Resource impact analysis
/workflow-status workflow_123 --resources --optimization-suggestions

# Agent efficiency tracking
/workflow-status workflow_123 --agents --performance-breakdown
```

## Arguments

- **workflow-id**: (Optional) Specific workflow to monitor; if omitted, shows all active workflows
- **--detailed**: Include comprehensive status breakdown with agent details and task queues
- **--json**: Output status information in JSON format for integration
- **--live**: Enable real-time monitoring with continuous updates
- **--interactive**: Start interactive control session for manual intervention
- **--performance**: Focus on performance metrics and efficiency analysis
- **--resources**: Include detailed resource utilization and conflict information
- **--debug**: Show debugging information and troubleshooting data

## Status Display Formats

### Summary View (Default)
```
Active Workflows:
┌─ workflow_123 ─ Feature Implementation ─ 60% ─ 45m remaining ──────┐
│ Phase 3/5: Implementation  ●●●○○  Agents: 6/8  Health: ●●●●○      │
└─────────────────────────────────────────────────────────────────────┘

┌─ workflow_456 ─ Bug Fix Sprint ─ 85% ─ 12m remaining ─────────────┐
│ Phase 4/4: Testing  ●●●●○  Agents: 3/4  Health: ●●●●●            │
└─────────────────────────────────────────────────────────────────────┘
```

### Detailed View
```
Workflow: workflow_123 (Feature Implementation)
Status: RUNNING | Phase: 3/5 (Implementation) | Progress: 60%
Runtime: 1h 25m | ETA: 45m | Priority: HIGH | Health: 80%

Current Phase Progress:
┌─ Phase 3: Implementation ──────────────────────────────────────────┐
│ Progress: ████████████████████░░░░░░░░ 75.2%                     │
│ Tasks: 18/24 complete, 4 active, 2 pending                        │
│ Duration: 45m elapsed / 60m estimated                             │
│ Performance: 87.3% efficiency, 2.1 tasks/min                      │
└─────────────────────────────────────────────────────────────────────┘

Active Agents:
┌─ Agent Pool Status ────────────────────────────────────────────────┐
│ agent_001: ●ACTIVE  | task_456 | 92.5% performance | 3 queued     │
│ agent_002: ●ACTIVE  | task_457 | 88.7% performance | 2 queued     │
│ agent_003: ⚠DEGRADED| task_789 | 73.2% performance | 5 queued     │
│ agent_004: ●ACTIVE  | task_790 | 95.1% performance | 1 queued     │
└─────────────────────────────────────────────────────────────────────┘

Resource Usage:
┌─ System Resources ─────────────────────────────────────────────────┐
│ CPU: ████████████████████░░░░░░ 45.2% (3.6/8 cores)             │
│ RAM: ████████████████████████░░░ 78.3% (3.2/4.1 GB)             │
│ Storage: ████████████████████████████████░░ 1.8 GB used          │
│ Network: Normal latency, no bottlenecks detected                   │
└─────────────────────────────────────────────────────────────────────┘
```

### JSON Output Format
```json
{
  "workflow_status": {
    "workflow_id": "workflow_123",
    "name": "Feature Implementation",
    "status": "running",
    "overall_progress": 60.0,
    "health_score": 80.0,
    "runtime": "1h 25m",
    "estimated_completion": "45m",
    "current_phase": {
      "id": 3,
      "name": "Implementation",
      "progress": 75.2,
      "tasks_total": 24,
      "tasks_completed": 18,
      "tasks_active": 4,
      "tasks_pending": 2
    },
    "agents": [
      {
        "id": "agent_001",
        "status": "active",
        "current_task": "task_456",
        "performance_score": 92.5,
        "queue_size": 3
      }
    ],
    "resources": {
      "cpu_percent": 45.2,
      "memory_percent": 78.3,
      "storage_used_gb": 1.8
    },
    "recent_events": [
      {
        "timestamp": "2025-01-15T12:15:32Z",
        "type": "task_completed",
        "agent": "agent_003",
        "task": "Update authentication module"
      }
    ]
  }
}
```

## Error Handling

### Status Monitoring Errors
```json
{
  "error_scenarios": {
    "workflow_not_found": {
      "message": "Workflow 'workflow_123' not found",
      "suggestions": [
        "Verify workflow ID with /coordination-hub list-workflows",
        "Check if workflow has completed or failed"
      ]
    },
    "connection_failed": {
      "message": "Unable to connect to coordination hub",
      "suggestions": [
        "Verify coordination hub is running",
        "Check system resource availability"
      ]
    },
    "permission_denied": {
      "message": "Insufficient permissions to monitor workflow",
      "suggestions": [
        "Verify user access rights",
        "Check workflow ownership"
      ]
    }
  }
}
```

## Output Format

### Success Response
```json
{
  "status": "success",
  "operation": "workflow_status",
  "timestamp": "2025-01-15T12:15:00Z",
  "workflow_data": {
    "summary": "Workflow status retrieved successfully",
    "active_workflows": 2,
    "monitoring_mode": "live",
    "refresh_rate": "5s"
  },
  "next_actions": [
    "Continue monitoring",
    "Review performance alerts",
    "Consider resource optimization"
  ]
}
```

### Interactive Control Response
```json
{
  "status": "interactive_mode",
  "available_commands": [
    "pause", "resume", "reassign", "checkpoint",
    "skip", "priority", "emergency-stop", "debug"
  ],
  "current_state": {
    "workflow_id": "workflow_123",
    "status": "running",
    "user_controls": "enabled"
  }
}
```

---

## Integration Notes

This workflow status monitor provides:

1. **Real-Time Monitoring**: Live updates with progress visualization and completion estimates
2. **Interactive Control**: User intervention capabilities with manual overrides
3. **Comprehensive Debugging**: Troubleshooting information and error analysis
4. **Hub Integration**: Seamless data exchange with coordination-hub for workflow state
5. **Resource Awareness**: Integration with resource-manager for system status
6. **Multiple Output Formats**: Summary, detailed, and JSON formats for various use cases