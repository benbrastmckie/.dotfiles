---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: "<aggregation-type> [workflow-filter] [options]"
description: "Multi-workflow progress aggregation and synthesis"
command-type: utility
dependent-commands: workflow-status, coordination-hub
---

# Progress Aggregator

I'll provide comprehensive multi-workflow progress synthesis, priority-based reporting, and system-wide analytics with bottleneck identification and milestone tracking.

## Multi-Workflow Progress Synthesis Engine

Let me analyze your aggregation request and synthesize progress information across all active workflows.

### 1. Aggregation Type Classification

First, I'll determine the type of progress aggregation requested:
- **System Overview**: High-level dashboard of all workflow states
- **Priority Analysis**: Progress organized by workflow priority and criticality
- **Bottleneck Detection**: Identification and analysis of system bottlenecks
- **Milestone Tracking**: Progress toward major milestones and deadlines
- **Performance Analytics**: Comprehensive efficiency and trend analysis
- **Resource Impact**: Multi-workflow resource utilization and conflicts

### 2. System-Wide Progress Dashboard

#### Global Workflow Overview
```
╭─ System Progress Dashboard ─────────────────────────────────────────╮
│ Active Workflows: 4         Completed Today: 2         Failed: 0    │
│ Total Progress: ████████████████░░░░ 68% System Efficiency         │
│ System Health: ●●●●○ 85%    Agent Pool: 15/20 active               │
│ ETA Confidence: ●●●○○ 72%   Resource Usage: Moderate                │
├─────────────────────────────────────────────────────────────────────┤
│ 🔥 CRITICAL: workflow_789 - Security Patch (Phase 4/4 - 95%)       │
│ ⚡ HIGH: workflow_123 - Feature Release (Phase 3/5 - 60%)          │
│ 📋 MEDIUM: workflow_456 - Bug Fixes (Phase 2/3 - 45%)              │
│ 🔄 LOW: workflow_234 - Refactoring (Phase 1/4 - 20%)               │
╰─────────────────────────────────────────────────────────────────────╯
```

#### Multi-Workflow Progress Matrix
```json
{
  "system_progress": {
    "global_metrics": {
      "total_workflows": 4,
      "active_workflows": 4,
      "completed_today": 2,
      "failed_workflows": 0,
      "overall_progress": 68.2,
      "system_efficiency": 85.3,
      "agent_utilization": 75.0,
      "resource_health": "optimal"
    },
    "workflow_breakdown": [
      {
        "workflow_id": "workflow_789",
        "name": "Security Patch Deployment",
        "priority": "critical",
        "progress": 95.0,
        "phase": "4/4",
        "eta": "15m",
        "health": 92.0,
        "bottlenecks": [],
        "milestone_status": "on_track"
      },
      {
        "workflow_id": "workflow_123",
        "name": "Feature Release Pipeline",
        "priority": "high",
        "progress": 60.0,
        "phase": "3/5",
        "eta": "1h 30m",
        "health": 78.0,
        "bottlenecks": ["file_io_delays", "agent_load_imbalance"],
        "milestone_status": "at_risk"
      },
      {
        "workflow_id": "workflow_456",
        "name": "Bug Fix Sprint",
        "priority": "medium",
        "progress": 45.0,
        "phase": "2/3",
        "eta": "2h 15m",
        "health": 88.0,
        "bottlenecks": ["dependency_resolution"],
        "milestone_status": "on_track"
      },
      {
        "workflow_id": "workflow_234",
        "name": "Code Refactoring",
        "priority": "low",
        "progress": 20.0,
        "phase": "1/4",
        "eta": "4h 45m",
        "health": 95.0,
        "bottlenecks": [],
        "milestone_status": "ahead_of_schedule"
      }
    ]
  }
}
```

### 3. Priority-Based Progress Reporting

#### Critical Priority Analysis
```
CRITICAL WORKFLOWS STATUS:
┌─ workflow_789 ─ Security Patch Deployment ─────────────────────────┐
│ Progress: ███████████████████████████████░ 95% (Phase 4/4)        │
│ Health: ●●●●● 92%     ETA: 15m        Priority: 🔥 CRITICAL       │
│ Status: Final validation and deployment in progress                 │
│ Next: Complete deployment verification                              │
│ Blockers: None                    Risk Level: ●○○○○ Very Low       │
│ Milestone: Security patch release - ON TRACK                       │
└─────────────────────────────────────────────────────────────────────┘

HIGH PRIORITY WORKFLOWS:
┌─ workflow_123 ─ Feature Release Pipeline ──────────────────────────┐
│ Progress: ████████████████░░░░░░░░ 60% (Phase 3/5)                │
│ Health: ●●●○○ 78%     ETA: 1h 30m     Priority: ⚡ HIGH          │
│ Status: Implementation phase with performance bottlenecks          │
│ Bottlenecks: File I/O delays (agent_003), Load imbalance          │
│ Action: Redistributing tasks, optimizing file operations           │
│ Milestone: Feature release deadline - AT RISK (+15m)               │
└─────────────────────────────────────────────────────────────────────┘
```

#### Priority-Based Resource Allocation
```json
{
  "priority_analysis": {
    "resource_distribution": {
      "critical": {
        "agent_allocation": 4,
        "cpu_percentage": 35.0,
        "memory_allocation": "1.2GB",
        "priority_score": 100
      },
      "high": {
        "agent_allocation": 6,
        "cpu_percentage": 40.0,
        "memory_allocation": "1.8GB",
        "priority_score": 80
      },
      "medium": {
        "agent_allocation": 3,
        "cpu_percentage": 18.0,
        "memory_allocation": "0.8GB",
        "priority_score": 60
      },
      "low": {
        "agent_allocation": 2,
        "cpu_percentage": 7.0,
        "memory_allocation": "0.4GB",
        "priority_score": 40
      }
    },
    "reallocation_recommendations": [
      {
        "action": "transfer_agent",
        "from_workflow": "workflow_234",
        "to_workflow": "workflow_123",
        "reason": "high_priority_bottleneck_resolution",
        "impact": "reduce_eta_by_20m"
      }
    ]
  }
}
```

### 4. Comprehensive Bottleneck Identification

#### System-Wide Bottleneck Analysis
```
BOTTLENECK DETECTION SUMMARY:
┌─ Critical System Bottlenecks ──────────────────────────────────────┐
│ 🚨 SEVERE: File I/O contention (agent_003, workflow_123)           │
│   └─ Impact: 25% performance degradation                           │
│   └─ Resolution: Redistribute large file operations                │
│                                                                     │
│ ⚠️  MODERATE: Agent load imbalance (3 agents >90% utilization)     │
│   └─ Impact: Queue buildup, increased response times               │
│   └─ Resolution: Dynamic task redistribution active                │
│                                                                     │
│ ℹ️  MINOR: Memory pressure approaching threshold (78% usage)       │
│   └─ Impact: Potential performance degradation                     │
│   └─ Resolution: Monitor and prepare scaling options               │
└─────────────────────────────────────────────────────────────────────┘
```

#### Detailed Bottleneck Analysis
```json
{
  "bottleneck_analysis": {
    "identified_bottlenecks": [
      {
        "id": "bottleneck_001",
        "type": "file_io_contention",
        "severity": "severe",
        "affected_workflows": ["workflow_123", "workflow_456"],
        "affected_agents": ["agent_003", "agent_007"],
        "impact": {
          "performance_degradation": 25.0,
          "estimated_delay": "20m",
          "tasks_affected": 12
        },
        "root_cause": {
          "description": "Large file operations competing for disk I/O",
          "technical_details": "Multiple agents processing >100MB files simultaneously",
          "contributing_factors": ["concurrent_large_files", "storage_bandwidth_limit"]
        },
        "resolution_strategy": {
          "immediate": "redistribute_large_file_tasks",
          "short_term": "implement_file_operation_queuing",
          "long_term": "upgrade_storage_subsystem"
        },
        "timeline": {
          "detected_at": "2025-01-15T12:10:00Z",
          "estimated_resolution": "2025-01-15T12:35:00Z",
          "auto_mitigation_active": true
        }
      },
      {
        "id": "bottleneck_002",
        "type": "agent_load_imbalance",
        "severity": "moderate",
        "affected_workflows": ["workflow_123", "workflow_456", "workflow_234"],
        "affected_agents": ["agent_001", "agent_004", "agent_008"],
        "impact": {
          "performance_degradation": 15.0,
          "queue_buildup": 8,
          "response_time_increase": "45%"
        },
        "resolution_strategy": {
          "immediate": "dynamic_task_redistribution",
          "monitoring": "agent_performance_tracking_enhanced"
        }
      }
    ],
    "bottleneck_trends": {
      "file_io": {
        "frequency": "increasing",
        "last_24h_incidents": 3,
        "pattern": "occurs_during_large_file_processing"
      },
      "agent_overload": {
        "frequency": "stable",
        "affected_agents_pattern": "high_performing_agents_preferred",
        "correlation": "task_complexity_increase"
      }
    }
  }
}
```

### 5. Milestone Achievement Tracking

#### Project Milestone Dashboard
```
MILESTONE TRACKING OVERVIEW:
┌─ Security Release Milestone ───────────────────────────────────────┐
│ Target: 2025-01-15 13:00    Status: ✅ ON TRACK    ETA: 12:45     │
│ Progress: ████████████████████████████████░ 95%                   │
│ Dependencies: workflow_789 (critical) - 15m remaining              │
│ Risk Level: ●○○○○ Very Low                                        │
└─────────────────────────────────────────────────────────────────────┘

┌─ Feature Release Milestone ────────────────────────────────────────┐
│ Target: 2025-01-15 15:30    Status: ⚠️ AT RISK     ETA: 15:45    │
│ Progress: ████████████░░░░░░░░░░░░ 60%                            │
│ Dependencies: workflow_123 (high), workflow_456 (medium)           │
│ Risk Level: ●●●○○ Medium - File I/O bottlenecks causing delays    │
│ Mitigation: Active task redistribution, I/O optimization           │
└─────────────────────────────────────────────────────────────────────┘

┌─ Code Quality Milestone ───────────────────────────────────────────┐
│ Target: 2025-01-15 18:00    Status: ✅ AHEAD      ETA: 17:15     │
│ Progress: ████░░░░░░░░░░░░░░░░ 20%                                 │
│ Dependencies: workflow_234 (low priority)                          │
│ Risk Level: ●○○○○ Very Low - Ahead of schedule                    │
└─────────────────────────────────────────────────────────────────────┘
```

#### Milestone Risk Analysis
```json
{
  "milestone_tracking": {
    "active_milestones": [
      {
        "milestone_id": "security_release",
        "name": "Security Patch Release",
        "target_date": "2025-01-15T13:00:00Z",
        "status": "on_track",
        "progress": 95.0,
        "estimated_completion": "2025-01-15T12:45:00Z",
        "risk_level": "very_low",
        "dependent_workflows": [
          {
            "workflow_id": "workflow_789",
            "contribution": 100.0,
            "status": "on_track",
            "critical_path": true
          }
        ],
        "success_criteria": [
          {
            "criterion": "security_patches_deployed",
            "status": "in_progress",
            "completion": 90.0
          },
          {
            "criterion": "vulnerability_tests_passed",
            "status": "completed",
            "completion": 100.0
          }
        ]
      },
      {
        "milestone_id": "feature_release",
        "name": "Q1 Feature Release",
        "target_date": "2025-01-15T15:30:00Z",
        "status": "at_risk",
        "progress": 60.0,
        "estimated_completion": "2025-01-15T15:45:00Z",
        "risk_level": "medium",
        "delay_factors": [
          {
            "factor": "file_io_bottlenecks",
            "impact": "15m_delay",
            "mitigation": "active_task_redistribution"
          }
        ],
        "dependent_workflows": [
          {
            "workflow_id": "workflow_123",
            "contribution": 70.0,
            "status": "at_risk",
            "critical_path": true
          },
          {
            "workflow_id": "workflow_456",
            "contribution": 30.0,
            "status": "on_track",
            "critical_path": false
          }
        ]
      }
    ],
    "milestone_health": {
      "on_track": 2,
      "at_risk": 1,
      "delayed": 0,
      "overall_confidence": 78.5
    }
  }
}
```

### 6. Comprehensive Progress Analytics

#### Performance Trend Analysis
```
SYSTEM PERFORMANCE TRENDS (Last 4 Hours):
┌─ Workflow Completion Rate ─────────────────────────────────────────┐
│     │                                                               │
│ 100%│  ●─●─●─●─●                                                   │
│  80%│           ●─●─○                                              │
│  60%│                ●─●─●─●                                       │
│  40%│                        ●─●                                   │
│  20%│                            ●─●─●                            │
│     └─────────────────────────────────────────────────────────────│
│      09:00  10:00  11:00  12:00  13:00                            │
│                                                                     │
│ Trend: Stable completion rate with minor dip during I/O bottleneck │
│ Efficiency: 85.3% (target: 80%) - Above target                    │
└─────────────────────────────────────────────────────────────────────┘
```

#### Multi-Dimensional Analytics
```json
{
  "progress_analytics": {
    "efficiency_metrics": {
      "overall_system_efficiency": 85.3,
      "workflow_completion_rate": 92.5,
      "agent_utilization_optimality": 78.9,
      "resource_efficiency": 82.1,
      "bottleneck_resolution_time": "12.5m"
    },
    "trend_analysis": {
      "completion_velocity": {
        "current": "2.3 tasks/min",
        "trend": "stable",
        "vs_baseline": "+8.5%"
      },
      "quality_metrics": {
        "success_rate": 94.7,
        "rework_percentage": 3.2,
        "defect_detection_rate": 97.8
      },
      "predictive_insights": {
        "estimated_system_capacity": "18 concurrent workflows",
        "optimal_agent_pool_size": "22 agents",
        "peak_performance_window": "10:00-14:00"
      }
    },
    "comparative_analysis": {
      "vs_yesterday": {
        "efficiency_change": "+5.2%",
        "completion_rate_change": "+2.8%",
        "bottleneck_frequency_change": "-15.0%"
      },
      "vs_last_week": {
        "average_efficiency": 82.1,
        "performance_improvement": "+3.2%",
        "stability_score": 91.5
      }
    }
  }
}
```

### 7. Integration with Workflow Status and Coordination Hub

#### Status Data Aggregation
```bash
# Collect status from all active workflows
for workflow_id in $(coordination-hub list-workflows --active --format json | jq -r '.workflows[].id'); do
  workflow_status=$(workflow-status "$workflow_id" --json --detailed)
  echo "$workflow_status" >> /tmp/workflow_statuses.jsonl
done

# Aggregate progress data
cat /tmp/workflow_statuses.jsonl | jq -s '
  {
    system_progress: (
      map(.workflow_status) |
      {
        total_workflows: length,
        average_progress: (map(.overall_progress) | add / length),
        total_agents: (map(.agents | length) | add),
        combined_health: (map(.health_score) | add / length)
      }
    )
  }'
```

#### Real-Time Event Aggregation
```json
{
  "event_aggregation": {
    "subscription_config": {
      "event_patterns": [
        "workflow.*.progress_updated",
        "workflow.*.milestone_reached",
        "workflow.*.bottleneck_detected",
        "workflow.*.performance_alert",
        "system.*.resource_threshold"
      ],
      "aggregation_window": "5m",
      "delivery_method": "batch_analytics"
    },
    "aggregation_rules": {
      "progress_updates": "calculate_system_wide_progress",
      "milestone_events": "update_milestone_tracking",
      "bottleneck_events": "correlate_system_bottlenecks",
      "performance_events": "update_efficiency_metrics"
    }
  }
}
```

### 8. Interactive Progress Analysis

#### Dynamic Query Interface
```bash
# System overview with live updates
/progress-aggregator system-overview --live --refresh 10s

# Priority-focused analysis
/progress-aggregator priority-analysis --filter "critical,high" --include-recommendations

# Bottleneck deep-dive
/progress-aggregator bottleneck-analysis --include-root-cause --resolution-strategies

# Milestone tracking with risk assessment
/progress-aggregator milestone-tracking --include-risk-analysis --timeline 7d

# Performance analytics with trends
/progress-aggregator performance-analytics --timeframe 24h --include-predictions
```

#### Alert and Notification System
```json
{
  "alert_system": {
    "alert_thresholds": {
      "system_efficiency_below": 75.0,
      "milestone_risk_above": "medium",
      "bottleneck_severity_above": "moderate",
      "workflow_health_below": 70.0
    },
    "notification_rules": {
      "critical_milestone_risk": {
        "channels": ["immediate", "escalation"],
        "recipients": ["project_manager", "tech_lead"],
        "escalation_delay": "15m"
      },
      "system_performance_degradation": {
        "channels": ["monitoring", "slack"],
        "auto_mitigation": true
      }
    }
  }
}
```

## Aggregation Operations

### System Overview Generation
```bash
# Complete system status with all workflows
/progress-aggregator system-overview '{
  "include_completed": false,
  "detail_level": "summary",
  "sort_by": "priority"
}'
```

### Priority-Based Analysis
```bash
# Focus on high-priority workflows
/progress-aggregator priority-analysis '{
  "priority_filter": ["critical", "high"],
  "include_recommendations": true,
  "resource_optimization": true
}'
```

### Bottleneck Detection and Analysis
```bash
# Comprehensive bottleneck identification
/progress-aggregator bottleneck-analysis '{
  "severity_threshold": "minor",
  "include_predictions": true,
  "resolution_strategies": true
}'
```

### Milestone Progress Tracking
```bash
# Track milestone achievement progress
/progress-aggregator milestone-tracking '{
  "timeframe": "30d",
  "include_risk_analysis": true,
  "critical_path_analysis": true
}'
```

### Performance Analytics Generation
```bash
# System-wide performance analysis
/progress-aggregator performance-analytics '{
  "timeframe": "7d",
  "include_trends": true,
  "predictive_analysis": true,
  "comparative_baseline": "last_month"
}'
```

## Arguments

- **aggregation-type**: Type of progress aggregation (system-overview, priority-analysis, bottleneck-analysis, milestone-tracking, performance-analytics)
- **workflow-filter**: (Optional) Filter by specific workflows, priorities, or statuses
- **options**: (Optional) JSON configuration for aggregation parameters

### Available Options
- **--live**: Enable real-time updates with specified refresh interval
- **--include-predictions**: Add predictive analysis and forecasting
- **--detail-level**: Control output verbosity (summary, detailed, comprehensive)
- **--export-format**: Output format (json, csv, dashboard, report)
- **--timeframe**: Historical analysis timeframe (1h, 24h, 7d, 30d)
- **--alert-thresholds**: Custom thresholds for alerts and notifications

## Output Formats

### Dashboard View (Default)
```
╭─ Multi-Workflow Progress Aggregation ──────────────────────────────╮
│ System Status: ●●●●○ 85%    Active Workflows: 4    ETA: 1h 15m    │
│ Priority Distribution: 🔥1 ⚡1 📋1 🔄1    Bottlenecks: 2 detected  │
│ Milestone Status: 2 on-track, 1 at-risk    Overall Health: Good    │
├─────────────────────────────────────────────────────────────────────┤
│ Next Critical Events:                                               │
│ • 12:45 - Security patch deployment complete                       │
│ • 13:30 - Feature release milestone (at risk)                      │
│ • 15:00 - Performance optimization phase begins                    │
╰─────────────────────────────────────────────────────────────────────╯
```

### JSON Export Format
```json
{
  "aggregation_result": {
    "timestamp": "2025-01-15T12:30:00Z",
    "aggregation_type": "system-overview",
    "system_metrics": {
      "overall_progress": 68.2,
      "system_efficiency": 85.3,
      "active_workflows": 4,
      "total_agents": 15
    },
    "workflow_summaries": [...],
    "bottlenecks": [...],
    "milestones": [...],
    "recommendations": [...]
  }
}
```

### Performance Report Format
```
SYSTEM PERFORMANCE REPORT
Generated: 2025-01-15 12:30:00

EXECUTIVE SUMMARY:
• System operating at 85.3% efficiency (above 80% target)
• 4 active workflows with 68.2% average completion
• 2 bottlenecks identified with active mitigation
• 1 milestone at risk, 2 on track

KEY METRICS:
• Task completion rate: 2.3 tasks/min (stable trend)
• Agent utilization: 75% (optimal range)
• Resource efficiency: 82.1% (good)
• Success rate: 94.7% (excellent)

RECOMMENDATIONS:
• Redistribute agents from low-priority workflow_234 to workflow_123
• Implement file operation queuing to resolve I/O bottlenecks
• Scale agent pool to 18 agents for optimal performance
```

## Error Handling

### Aggregation Errors
```json
{
  "error_scenarios": {
    "insufficient_data": {
      "message": "Insufficient workflow data for meaningful aggregation",
      "suggestions": [
        "Ensure at least one active workflow exists",
        "Check workflow-status and coordination-hub connectivity"
      ]
    },
    "data_inconsistency": {
      "message": "Inconsistent data between workflow sources",
      "suggestions": [
        "Verify coordination-hub synchronization",
        "Check for stale workflow status data"
      ]
    },
    "analysis_timeout": {
      "message": "Aggregation analysis exceeded timeout limit",
      "suggestions": [
        "Reduce analysis timeframe or scope",
        "Use summary detail level for large datasets"
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
  "operation": "progress_aggregation",
  "timestamp": "2025-01-15T12:30:00Z",
  "aggregation_data": {
    "type": "system-overview",
    "scope": "all_active_workflows",
    "summary": "System-wide progress aggregation completed successfully"
  },
  "insights": [
    "System efficiency above target (85.3% vs 80%)",
    "File I/O bottleneck affecting 2 workflows",
    "Feature release milestone at risk (+15m delay)"
  ],
  "recommendations": [
    "Redistribute agents to resolve bottlenecks",
    "Implement I/O optimization strategies",
    "Monitor milestone progress closely"
  ]
}
```

---

## Integration Notes

This progress aggregator provides:

1. **Multi-Workflow Synthesis**: Comprehensive view across all active development workflows
2. **Priority-Based Analysis**: Focus on critical and high-priority workflow progress
3. **Bottleneck Identification**: System-wide detection and analysis of performance constraints
4. **Milestone Tracking**: Progress monitoring toward major project milestones
5. **Performance Analytics**: Comprehensive efficiency and trend analysis
6. **Real-Time Integration**: Live updates from workflow-status and coordination-hub systems