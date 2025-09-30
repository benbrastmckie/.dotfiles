---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: "<operation> [resource-type] [parameters]"
description: "System resource allocation and conflict prevention"
command-type: utility
dependent-commands: coordination-hub, subagents
---

# System Resource Manager

I'll manage comprehensive system resource allocation, monitoring, and conflict prevention for orchestrated development workflows.

## Resource Management Engine

Let me parse your resource operation request and execute the appropriate resource management operation.

### 1. Operation Classification and Routing

First, I'll analyze the requested operation:
- **Monitoring Operations**: monitor, status, usage, capacity
- **Allocation Operations**: allocate, reserve, release, reallocate
- **Conflict Prevention**: check-conflicts, resolve-conflicts, prevent-conflicts
- **Optimization Operations**: optimize, tune, balance, scale
- **Planning Operations**: plan-capacity, forecast, analyze-trends

### 2. System Resource Tracking Architecture

#### Resource Categories
```json
{
  "system_resources": {
    "compute": {
      "cpu_cores": {
        "total": 8,
        "available": 6,
        "allocated": 2,
        "reserved": 1,
        "utilization_percent": 25.5
      },
      "memory": {
        "total_gb": 16,
        "available_gb": 12.5,
        "allocated_gb": 3.5,
        "buffer_gb": 2.0,
        "utilization_percent": 21.9
      },
      "storage": {
        "total_gb": 500,
        "available_gb": 350,
        "temp_usage_gb": 15,
        "cache_usage_gb": 25,
        "utilization_percent": 30.0
      }
    },
    "workflow_resources": {
      "agent_pool": {
        "max_agents": 20,
        "active_agents": 8,
        "idle_agents": 3,
        "reserved_agents": 2,
        "failed_agents": 1
      },
      "concurrent_workflows": {
        "max_workflows": 5,
        "active_workflows": 2,
        "queued_workflows": 1,
        "paused_workflows": 0
      },
      "tool_instances": {
        "bash_shells": 12,
        "file_operations": 8,
        "search_operations": 4,
        "web_requests": 2
      }
    }
  }
}
```

#### Resource State Storage
```
.claude/resource-manager/
├── current_state/
│   ├── system_resources.json     # Real-time resource status
│   ├── allocations.json         # Current resource allocations
│   ├── reservations.json        # Future resource reservations
│   └── conflicts.json           # Active and resolved conflicts
├── monitoring/
│   ├── usage_history.jsonl      # Historical usage patterns
│   ├── performance_metrics.jsonl # Performance tracking
│   └── alerts.jsonl             # Resource alerts and warnings
├── policies/
│   ├── allocation_rules.json    # Resource allocation policies
│   ├── priority_matrix.json     # Priority-based allocation rules
│   └── limits.json              # Resource limits and quotas
└── optimization/
    ├── capacity_plans.json      # Capacity planning data
    ├── usage_forecasts.json     # Predicted resource usage
    └── optimization_reports.json # Performance optimization results
```

### 3. Intelligent Resource Allocation System

#### Priority-Based Scheduling Algorithm
```
Resource Allocation Process:
1. Analyze incoming resource request
2. Check current system availability
3. Evaluate requester priority level
4. Calculate resource requirements vs capacity
5. Check for potential conflicts
6. Apply allocation policies and limits
7. Reserve resources with timeout
8. Monitor allocation usage
9. Auto-release on completion/timeout

Priority Levels:
- CRITICAL (90-100): System maintenance, recovery operations
- HIGH (70-89): Active implementations, user-initiated commands
- MEDIUM (40-69): Background tasks, monitoring, optimization
- LOW (0-39): Cleanup, archival, analytics
```

#### Allocation Schema
```json
{
  "resource_allocation": {
    "allocation_id": "alloc_789",
    "workflow_id": "workflow_123",
    "requester": "coordination_hub",
    "timestamp": "2025-01-15T11:30:00Z",
    "priority": "high",
    "status": "active|reserved|expired|released",
    "resources": {
      "cpu_cores": 2,
      "memory_gb": 4,
      "agents": 3,
      "tool_instances": {
        "bash": 2,
        "file_ops": 4,
        "search": 1
      }
    },
    "constraints": {
      "max_duration": "2h",
      "exclusive_access": ["critical_file.nix"],
      "conflict_avoidance": ["other_workflow_456"]
    },
    "performance_requirements": {
      "min_response_time": "500ms",
      "max_memory_per_agent": "1GB",
      "storage_iops": 100
    },
    "auto_release": {
      "on_completion": true,
      "on_timeout": true,
      "on_failure": true,
      "grace_period": "5m"
    }
  }
}
```

### 4. Conflict Prevention Mechanisms

#### Multi-Level Conflict Detection
```
Conflict Detection Layers:

1. File-Level Conflicts:
   - Simultaneous write operations to same files
   - Lock file detection and management
   - Directory structure modifications
   - Configuration file overlaps

2. Resource-Level Conflicts:
   - CPU/Memory contention
   - Agent pool exhaustion
   - Tool instance limitations
   - Network bandwidth constraints

3. Workflow-Level Conflicts:
   - Incompatible simultaneous operations
   - Dependency chain conflicts
   - State corruption risks
   - Recovery procedure overlaps

4. System-Level Conflicts:
   - Critical system resource exhaustion
   - Security policy violations
   - Hardware limitation breaches
   - External dependency conflicts
```

#### Conflict Resolution Strategies
```json
{
  "conflict_resolution": {
    "file_conflicts": {
      "strategy": "queue_and_serialize",
      "methods": [
        "file_locking",
        "copy_on_write",
        "merge_changes",
        "priority_override"
      ],
      "timeout": "10m"
    },
    "resource_conflicts": {
      "strategy": "intelligent_queuing",
      "methods": [
        "priority_preemption",
        "resource_scaling",
        "load_balancing",
        "graceful_degradation"
      ],
      "auto_scale": true
    },
    "workflow_conflicts": {
      "strategy": "coordination_based",
      "methods": [
        "dependency_reordering",
        "phase_adjustment",
        "parallel_reduction",
        "checkpoint_isolation"
      ],
      "coordination_required": true
    }
  }
}
```

### 5. Performance Optimization Engine

#### Dynamic Resource Tuning
```
Optimization Algorithms:

1. Load Balancing:
   - Monitor agent performance metrics
   - Redistribute tasks based on capacity
   - Adjust concurrent operation limits
   - Scale resources up/down dynamically

2. Memory Management:
   - Track memory usage patterns
   - Implement intelligent caching
   - Garbage collection optimization
   - Memory leak detection

3. CPU Optimization:
   - Process priority adjustment
   - CPU affinity optimization
   - Concurrent operation tuning
   - Background task scheduling

4. I/O Optimization:
   - File operation batching
   - Disk cache management
   - Network request optimization
   - Temporary file lifecycle management
```

#### Performance Metrics Collection
```json
{
  "performance_metrics": {
    "system_performance": {
      "cpu_efficiency": 78.5,
      "memory_efficiency": 82.1,
      "disk_io_efficiency": 91.3,
      "network_efficiency": 87.9
    },
    "agent_performance": {
      "average_response_time": "1.2s",
      "task_completion_rate": 94.7,
      "error_rate": 2.1,
      "resource_utilization": 76.8
    },
    "workflow_performance": {
      "parallel_efficiency": 83.4,
      "resource_waste": 5.2,
      "conflict_resolution_time": "0.8s",
      "overall_throughput": 152.3
    },
    "trends": {
      "hourly_usage": [65, 72, 78, 85, 91, 88, 76],
      "daily_peaks": [91, 89, 94, 87, 92],
      "weekly_average": 81.4,
      "growth_rate": 2.3
    }
  }
}
```

### 6. Capacity Planning and Analysis

#### Capacity Planning System
```
Capacity Analysis Components:

1. Historical Usage Analysis:
   - Parse usage patterns from monitoring data
   - Identify peak usage times and patterns
   - Calculate resource utilization trends
   - Predict future capacity needs

2. Workload Forecasting:
   - Analyze workflow complexity trends
   - Estimate resource requirements for planned work
   - Model seasonal and project-based variations
   - Account for growth in development activity

3. Scalability Assessment:
   - Evaluate current resource scalability limits
   - Identify bottlenecks and constraints
   - Recommend infrastructure improvements
   - Cost-benefit analysis for upgrades

4. Risk Assessment:
   - Identify single points of failure
   - Calculate resource exhaustion risks
   - Assess backup and recovery capacity
   - Evaluate disaster recovery scenarios
```

#### Capacity Planning Reports
```json
{
  "capacity_plan": {
    "analysis_date": "2025-01-15T12:00:00Z",
    "current_capacity": {
      "cpu_cores": 8,
      "memory_gb": 16,
      "max_agents": 20,
      "storage_gb": 500
    },
    "utilization_analysis": {
      "peak_cpu_usage": 95.2,
      "peak_memory_usage": 88.7,
      "peak_agent_usage": 18,
      "average_daily_usage": 67.3
    },
    "forecasted_needs": {
      "next_month": {
        "cpu_increase": 15,
        "memory_increase": 25,
        "agent_increase": 5
      },
      "next_quarter": {
        "cpu_increase": 35,
        "memory_increase": 50,
        "agent_increase": 12
      }
    },
    "recommendations": [
      {
        "type": "immediate",
        "action": "increase_agent_pool",
        "details": "Current peak usage approaches limits",
        "priority": "high"
      },
      {
        "type": "planned",
        "action": "memory_upgrade",
        "details": "Memory usage trending upward",
        "timeline": "next_month"
      }
    ]
  }
}
```

## Operations Implementation

### Resource Monitoring Operations
```bash
# Monitor current system resource usage
/resource-manager monitor system '{
  "include_trends": true,
  "detail_level": "full",
  "export_format": "json"
}'

# Check specific resource type status
/resource-manager status agents '{
  "include_performance": true,
  "time_range": "1h",
  "group_by": "specialization"
}'

# Get resource usage for specific workflow
/resource-manager usage workflow_123 '{
  "breakdown_by_phase": true,
  "include_efficiency": true,
  "compare_baseline": true
}'
```

### Resource Allocation Operations
```bash
# Allocate resources for new workflow
/resource-manager allocate '{
  "workflow_id": "workflow_456",
  "priority": "high",
  "resources": {
    "cpu_cores": 4,
    "memory_gb": 8,
    "agents": 6
  },
  "duration": "3h",
  "exclusive_files": ["critical_config.nix"]
}'

# Reserve resources for future use
/resource-manager reserve '{
  "reservation_id": "res_789",
  "start_time": "2025-01-15T15:00:00Z",
  "duration": "2h",
  "resources": {"agents": 8},
  "priority": "medium"
}'

# Release allocated resources
/resource-manager release '{
  "allocation_id": "alloc_456",
  "force": false,
  "cleanup": true
}'
```

### Conflict Prevention Operations
```bash
# Check for potential conflicts before allocation
/resource-manager check-conflicts '{
  "proposed_allocation": {
    "workflow_id": "workflow_789",
    "resources": {"agents": 10, "memory_gb": 12},
    "files": ["home.nix", "flake.nix"]
  },
  "check_future": true,
  "time_horizon": "4h"
}'

# Resolve active conflicts
/resource-manager resolve-conflicts '{
  "conflict_id": "conf_123",
  "strategy": "priority_based",
  "notify_affected": true
}'

# Set conflict prevention policies
/resource-manager prevent-conflicts '{
  "policy_type": "file_locking",
  "scope": "global",
  "enforcement": "strict",
  "exceptions": ["read_only_operations"]
}'
```

### Optimization Operations
```bash
# Optimize current resource allocation
/resource-manager optimize '{
  "target": "efficiency",
  "constraints": ["maintain_performance"],
  "apply_immediately": false,
  "dry_run": true
}'

# Tune system performance parameters
/resource-manager tune '{
  "component": "agent_pool",
  "metric": "response_time",
  "target_value": "1.0s",
  "auto_adjust": true
}'

# Balance workload across resources
/resource-manager balance '{
  "scope": "active_workflows",
  "strategy": "even_distribution",
  "consider_specialization": true
}'
```

### Capacity Planning Operations
```bash
# Generate capacity plan
/resource-manager plan-capacity '{
  "time_horizon": "3_months",
  "growth_assumptions": {"workflow_increase": 25},
  "include_recommendations": true,
  "cost_analysis": false
}'

# Forecast resource usage
/resource-manager forecast '{
  "metric": "cpu_usage",
  "period": "next_week",
  "confidence_interval": 0.95,
  "include_peaks": true
}'

# Analyze usage trends
/resource-manager analyze-trends '{
  "timeframe": "30_days",
  "metrics": ["cpu", "memory", "agents"],
  "detect_anomalies": true,
  "export_charts": false
}'
```

## Integration with Coordination System

### Resource-Aware Workflow Scheduling
```
Workflow → Resource Manager Integration:

1. Pre-Allocation Phase:
   - Workflow requests resource estimate
   - Resource manager analyzes requirements
   - Conflicts checked and prevention applied
   - Resources allocated or queued

2. Runtime Monitoring:
   - Continuous resource usage monitoring
   - Performance metric collection
   - Dynamic reallocation if needed
   - Conflict detection and resolution

3. Completion Cleanup:
   - Automatic resource release
   - Performance metrics archival
   - Capacity data updates
   - Conflict policy adjustments
```

### State Synchronization Protocol
```json
{
  "resource_workflow_sync": {
    "allocation_request": {
      "workflow_id": "workflow_123",
      "estimated_resources": "resource_estimate_object",
      "priority_level": "high|medium|low",
      "duration_estimate": "ISO_duration",
      "conflict_sensitivity": "high|medium|low"
    },
    "allocation_response": {
      "allocation_id": "alloc_456",
      "granted_resources": "actual_resource_allocation",
      "restrictions": "resource_usage_constraints",
      "monitoring_config": "performance_tracking_setup"
    },
    "runtime_updates": {
      "usage_reports": "periodic_usage_data",
      "performance_alerts": "performance_issue_notifications",
      "reallocation_events": "resource_adjustment_notifications"
    }
  }
}
```

## Arguments

- **operation**: Resource management operation (monitor, status, usage, allocate, reserve, release, check-conflicts, resolve-conflicts, optimize, tune, balance, plan-capacity, forecast, analyze-trends)
- **resource-type**: Optional resource type filter (system, agents, workflows, cpu, memory, storage)
- **parameters**: JSON object with operation-specific configuration and options

## Performance and Monitoring

### Real-Time Metrics Dashboard
```json
{
  "dashboard_metrics": {
    "system_health": {
      "overall_status": "healthy|warning|critical",
      "cpu_status": "optimal",
      "memory_status": "optimal",
      "storage_status": "warning",
      "agent_pool_status": "healthy"
    },
    "active_allocations": 8,
    "resource_efficiency": 84.2,
    "conflict_count": 0,
    "optimization_score": 91.7,
    "capacity_utilization": {
      "current": 67.3,
      "projected_24h": 74.8,
      "safe_threshold": 80.0
    }
  }
}
```

### Alert and Notification System
```json
{
  "alert_system": {
    "resource_alerts": [
      {
        "type": "capacity_warning",
        "severity": "medium",
        "message": "CPU utilization approaching 80% threshold",
        "recommended_action": "Consider scaling agent pool"
      },
      {
        "type": "conflict_detected",
        "severity": "high",
        "message": "File access conflict detected for home.nix",
        "recommended_action": "Implement file locking"
      }
    ],
    "performance_alerts": [
      {
        "type": "degraded_performance",
        "severity": "low",
        "message": "Agent response times increased by 15%",
        "recommended_action": "Monitor and investigate if continues"
      }
    ]
  }
}
```

## Error Handling and Recovery

### Resource Exhaustion Management
```
Resource Exhaustion Scenarios:

1. CPU Overload:
   - Reduce concurrent operations
   - Pause non-critical workflows
   - Implement CPU throttling
   - Scale resources if possible

2. Memory Exhaustion:
   - Trigger garbage collection
   - Release cached resources
   - Pause memory-intensive operations
   - Implement memory limits

3. Agent Pool Exhaustion:
   - Queue incoming requests
   - Optimize agent utilization
   - Scale agent pool dynamically
   - Implement agent recycling

4. Storage Exhaustion:
   - Clean temporary files
   - Compress archived data
   - Move data to external storage
   - Implement storage quotas
```

### Recovery Procedures
```json
{
  "recovery_procedures": {
    "resource_leak_detection": {
      "monitoring_interval": "5m",
      "leak_threshold": 15,
      "auto_cleanup": true,
      "escalation_timeout": "30m"
    },
    "performance_degradation": {
      "detection_method": "baseline_comparison",
      "degradation_threshold": 25,
      "auto_optimization": true,
      "manual_intervention": false
    },
    "conflict_resolution": {
      "detection_speed": "realtime",
      "resolution_timeout": "5m",
      "escalation_strategy": "priority_based",
      "fallback_method": "manual_intervention"
    }
  }
}
```

## Output Format

### Success Response
```json
{
  "status": "success",
  "operation": "resource_operation_name",
  "timestamp": "2025-01-15T12:00:00Z",
  "result": {
    "operation_specific_data": "varies_by_operation",
    "resource_state": "current_resource_snapshot",
    "performance_impact": "minimal|moderate|significant"
  },
  "metrics": {
    "execution_time": "0.8s",
    "resources_affected": 3,
    "efficiency_gain": 12.5
  },
  "recommendations": [
    "Monitor performance for next hour",
    "Consider memory upgrade within next month"
  ]
}
```

### Error Response
```json
{
  "status": "error",
  "operation": "resource_operation_name",
  "error": {
    "code": "RESOURCE_EXHAUSTED",
    "message": "Insufficient memory available for allocation",
    "details": "Requested 8GB, only 3GB available",
    "affected_resources": ["memory"]
  },
  "recovery_suggestions": [
    "Reduce resource request size",
    "Wait for current allocations to release",
    "Scale system resources"
  ],
  "alternative_options": [
    "Queue request for later execution",
    "Use degraded performance mode"
  ]
}
```

## Configuration

### Default Resource Policies
```json
{
  "resource_policies": {
    "allocation_limits": {
      "max_cpu_per_workflow": 6,
      "max_memory_per_workflow": 12,
      "max_agents_per_workflow": 15,
      "max_duration": "6h"
    },
    "priority_weights": {
      "critical": 1.0,
      "high": 0.8,
      "medium": 0.6,
      "low": 0.4
    },
    "optimization_targets": {
      "efficiency_threshold": 80.0,
      "response_time_target": "1.0s",
      "utilization_target": 75.0,
      "conflict_tolerance": 0.1
    },
    "monitoring_intervals": {
      "resource_check": "30s",
      "performance_sample": "5m",
      "capacity_analysis": "1h",
      "trend_analysis": "24h"
    }
  }
}
```

---

## Integration Notes

This resource manager serves as the foundational resource management system for orchestrated development workflows, providing:

1. **Intelligent Resource Allocation**: Priority-based allocation with conflict prevention
2. **Real-Time Monitoring**: Comprehensive system and workflow resource tracking
3. **Conflict Prevention**: Multi-layer conflict detection and resolution
4. **Performance Optimization**: Dynamic tuning and load balancing
5. **Capacity Planning**: Predictive analysis and scaling recommendations
6. **Integration Ready**: Native compatibility with coordination-hub and subagents