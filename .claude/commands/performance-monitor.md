---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: <monitoring-type> [workflow-id] [options]
description: Performance monitoring and analytics for workflow optimization
command-type: utility
dependent-commands: coordination-hub, resource-manager
---

# Performance Monitor and Analytics Engine

I'll provide comprehensive performance monitoring, analytics, and optimization recommendations for orchestrated development workflows with real-time metrics collection and intelligent optimization insights.

## Performance Analytics Engine

Let me parse your monitoring request and execute the appropriate performance analysis operation.

### 1. Monitoring Operation Classification and Routing

First, I'll analyze the requested monitoring operation:
- **Real-Time Monitoring**: monitor, live-metrics, dashboard, alerts
- **Historical Analysis**: trends, patterns, comparative, regression
- **Efficiency Metrics**: throughput, resource-efficiency, agent-performance, bottlenecks
- **Optimization Engine**: recommendations, tune-suggestions, capacity-planning, predictions
- **Workflow Analytics**: execution-analysis, phase-performance, task-optimization, parallel-efficiency

### 2. Execution Time and Resource Monitoring System

#### Comprehensive Metrics Collection Architecture
```json
{
  "performance_metrics": {
    "execution_timing": {
      "workflow_execution": {
        "total_duration": "2h 15m 34s",
        "phase_durations": [
          {"phase": 1, "name": "setup", "duration": "8m 42s", "efficiency": 95.2},
          {"phase": 2, "name": "implementation", "duration": "1h 32m 15s", "efficiency": 87.4},
          {"phase": 3, "name": "testing", "duration": "23m 18s", "efficiency": 92.1},
          {"phase": 4, "name": "deployment", "duration": "11m 19s", "efficiency": 89.7}
        ],
        "task_level_timing": {
          "fastest_task": {"id": "task_045", "duration": "1.2s", "type": "file_read"},
          "slowest_task": {"id": "task_012", "duration": "12m 34s", "type": "complex_build"},
          "average_task_time": "3m 47s",
          "median_task_time": "2m 12s"
        }
      },
      "agent_response_times": {
        "average_response": "1.8s",
        "p95_response": "4.2s",
        "p99_response": "8.7s",
        "timeout_rate": 0.3,
        "response_distribution": [1.2, 1.8, 2.1, 1.9, 2.3, 1.7, 1.5]
      }
    },
    "resource_utilization": {
      "cpu_metrics": {
        "average_utilization": 67.8,
        "peak_utilization": 94.2,
        "idle_periods": 12.4,
        "efficiency_score": 85.6,
        "core_distribution": [75.2, 68.9, 72.1, 65.4, 70.8, 58.9, 73.2, 69.1]
      },
      "memory_metrics": {
        "peak_usage_gb": 14.7,
        "average_usage_gb": 8.9,
        "allocation_efficiency": 78.4,
        "garbage_collection_impact": 2.1,
        "memory_leaks_detected": 0
      },
      "io_metrics": {
        "disk_reads_mb": 2847.3,
        "disk_writes_mb": 1392.8,
        "network_requests": 156,
        "cache_hit_rate": 89.7,
        "io_wait_percentage": 5.2
      },
      "agent_pool_metrics": {
        "total_agents": 12,
        "active_agents": 9,
        "idle_agents": 3,
        "utilization_rate": 75.0,
        "task_distribution_balance": 92.4
      }
    }
  }
}
```

#### Real-Time Performance Data Storage
```
.claude/performance-monitor/
├── real_time/
│   ├── current_metrics.json      # Live performance data
│   ├── execution_traces.jsonl    # Detailed execution traces
│   ├── resource_usage.jsonl      # Real-time resource consumption
│   └── agent_performance.jsonl   # Agent-specific performance data
├── historical/
│   ├── daily_summaries/          # Daily performance aggregations
│   │   ├── 2025-01-15.json
│   │   └── 2025-01-14.json
│   ├── weekly_trends/            # Weekly trend analysis
│   └── monthly_reports/          # Monthly performance reports
├── analytics/
│   ├── efficiency_analysis.json  # Efficiency trend analysis
│   ├── bottleneck_reports.json   # Performance bottleneck identification
│   ├── optimization_history.json # Past optimization implementations
│   └── prediction_models.json    # Performance prediction data
└── benchmarks/
    ├── baseline_metrics.json     # Performance baselines
    ├── regression_tests.json     # Performance regression tracking
    └── comparative_analysis.json # Cross-workflow performance comparison
```

### 3. Efficiency Metrics and Performance Trend Analysis

#### Multi-Dimensional Efficiency Calculation
```
Efficiency Scoring Algorithm:

1. Time Efficiency:
   - Actual vs Estimated completion time
   - Parallel vs Sequential execution gains
   - Agent idle time minimization
   - Phase transition overhead reduction

2. Resource Efficiency:
   - CPU utilization optimization (target: 75-85%)
   - Memory allocation efficiency
   - Agent pool utilization balance
   - I/O operation optimization

3. Quality Efficiency:
   - Task success rate vs resource consumption
   - Error rate minimization
   - Retry overhead reduction
   - Quality metrics per resource unit

4. Workflow Efficiency:
   - Cross-phase optimization
   - Dependency resolution efficiency
   - Conflict resolution speed
   - Recovery time minimization

Overall Efficiency Score = (Time * 0.3 + Resource * 0.3 + Quality * 0.25 + Workflow * 0.15)
```

#### Performance Trend Analysis Engine
```json
{
  "trend_analysis": {
    "temporal_patterns": {
      "hourly_performance": {
        "peak_hours": [9, 10, 14, 15],
        "low_performance_hours": [12, 17, 18],
        "efficiency_variation": 15.7,
        "predictable_patterns": true
      },
      "daily_trends": {
        "weekday_average": 84.2,
        "weekend_average": 78.9,
        "monday_effect": -8.3,
        "friday_effect": -5.7
      },
      "workflow_lifecycle": {
        "startup_overhead": "2m 15s",
        "peak_performance_phase": 2,
        "degradation_pattern": "gradual",
        "cleanup_efficiency": 91.4
      }
    },
    "performance_regression": {
      "detected_regressions": [
        {
          "metric": "agent_response_time",
          "regression_start": "2025-01-14T15:30:00Z",
          "magnitude": 23.4,
          "probable_cause": "memory_pressure",
          "status": "investigating"
        }
      ],
      "improvement_trends": [
        {
          "metric": "parallel_efficiency",
          "improvement_rate": 2.1,
          "timeframe": "7_days",
          "contributing_factors": ["better_task_distribution", "agent_specialization"]
        }
      ]
    }
  }
}
```

### 4. Optimization Recommendation Engine

#### Intelligent Optimization Analysis
```
Optimization Recommendation Algorithm:

1. Performance Bottleneck Identification:
   - CPU-bound task detection and optimization
   - Memory allocation pattern analysis
   - I/O bottleneck identification
   - Agent pool imbalance detection

2. Resource Allocation Optimization:
   - Dynamic agent pool sizing recommendations
   - Memory allocation strategy adjustments
   - CPU core affinity optimization
   - Storage optimization suggestions

3. Workflow Structure Optimization:
   - Parallel execution opportunity identification
   - Dependency chain optimization
   - Phase structure improvement suggestions
   - Task batching optimization

4. Agent Performance Optimization:
   - Specialization effectiveness analysis
   - Load balancing improvement suggestions
   - Agent pairing optimization
   - Performance-based agent selection
```

#### Actionable Optimization Insights
```json
{
  "optimization_recommendations": {
    "immediate_actions": [
      {
        "priority": "high",
        "category": "resource_allocation",
        "recommendation": "Increase agent pool size by 3 agents",
        "rationale": "Current utilization at 94% causing queue delays",
        "expected_improvement": "25% reduction in execution time",
        "implementation_effort": "low",
        "estimated_impact": {
          "execution_time": -18.2,
          "resource_efficiency": +12.7,
          "overall_score": +8.9
        }
      },
      {
        "priority": "medium",
        "category": "task_optimization",
        "recommendation": "Implement task batching for file operations",
        "rationale": "45% of tasks are small file operations with high overhead",
        "expected_improvement": "15% reduction in I/O wait time",
        "implementation_effort": "medium",
        "code_changes_required": true
      }
    ],
    "strategic_improvements": [
      {
        "category": "workflow_architecture",
        "recommendation": "Redesign phase 2 for better parallelization",
        "rationale": "Current phase 2 has 67% sequential dependencies",
        "expected_improvement": "30% reduction in phase 2 duration",
        "implementation_effort": "high",
        "breaking_changes": false,
        "timeline": "2-3 weeks"
      }
    ],
    "experimental_optimizations": [
      {
        "category": "agent_specialization",
        "recommendation": "Implement GPU-accelerated agents for specific tasks",
        "rationale": "12% of tasks are compute-intensive and GPU-suitable",
        "expected_improvement": "40% reduction for applicable tasks",
        "implementation_effort": "very_high",
        "proof_of_concept_required": true
      }
    ]
  }
}
```

### 5. Comparative Performance Analysis

#### Cross-Workflow Performance Benchmarking
```json
{
  "comparative_analysis": {
    "workflow_comparison": {
      "current_workflow": "workflow_456",
      "baseline_workflow": "workflow_baseline",
      "comparison_metrics": {
        "execution_time": {
          "current": "2h 15m",
          "baseline": "2h 45m",
          "improvement": "+18.2%",
          "significance": "statistically_significant"
        },
        "resource_efficiency": {
          "current": 84.7,
          "baseline": 76.3,
          "improvement": "+11.0%",
          "rank": "top_25_percentile"
        },
        "error_rate": {
          "current": 2.1,
          "baseline": 3.7,
          "improvement": "+43.2%",
          "trend": "improving"
        }
      }
    },
    "historical_comparison": {
      "performance_evolution": {
        "6_months_ago": 72.4,
        "3_months_ago": 78.9,
        "1_month_ago": 82.1,
        "current": 84.7,
        "improvement_rate": 2.8,
        "projection_next_month": 87.1
      },
      "best_performing_period": {
        "timeframe": "2025-01-10 to 2025-01-12",
        "average_score": 91.2,
        "conditions": ["low_system_load", "optimized_agent_pool", "minimal_conflicts"],
        "reproducibility": "high"
      }
    },
    "peer_benchmarking": {
      "similar_workflows": [
        {"id": "workflow_123", "score": 82.4, "similarity": 0.89},
        {"id": "workflow_789", "score": 78.9, "similarity": 0.76},
        {"id": "workflow_321", "score": 86.1, "similarity": 0.82}
      ],
      "percentile_rank": 75,
      "performance_gap_to_leader": 5.8,
      "improvement_potential": "medium_high"
    }
  }
}
```

#### Performance Pattern Recognition
```json
{
  "pattern_recognition": {
    "success_patterns": [
      {
        "pattern": "high_parallelization_with_specialized_agents",
        "frequency": 78,
        "average_performance": 88.9,
        "conditions": ["task_count > 15", "agent_specialization_rate > 70%"],
        "applicability": "broad"
      },
      {
        "pattern": "optimal_resource_reservation_timing",
        "frequency": 65,
        "average_performance": 85.2,
        "conditions": ["resource_reserved_15min_before", "no_resource_conflicts"],
        "applicability": "medium"
      }
    ],
    "failure_patterns": [
      {
        "pattern": "resource_contention_cascade",
        "frequency": 12,
        "performance_impact": -24.7,
        "warning_indicators": ["memory_usage > 90%", "agent_queue_length > 10"],
        "prevention_strategy": "early_resource_scaling"
      }
    ],
    "emerging_patterns": [
      {
        "pattern": "seasonal_performance_variation",
        "confidence": 0.72,
        "potential_impact": 8.3,
        "monitoring_required": true,
        "validation_timeline": "30_days"
      }
    ]
  }
}
```

## Operations Implementation

### Real-Time Monitoring Operations
```bash
# Start real-time performance monitoring
/performance-monitor monitor workflow_123 '{
  "metrics": ["execution", "resources", "agents"],
  "frequency": "5s",
  "alerts": true,
  "dashboard": true
}'

# Get live performance dashboard
/performance-monitor live-metrics '{
  "include_trends": true,
  "time_window": "1h",
  "detail_level": "full"
}'

# Monitor specific workflow performance
/performance-monitor dashboard workflow_456 '{
  "layout": "compact",
  "refresh_rate": "10s",
  "include_predictions": true
}'
```

### Historical Analysis Operations
```bash
# Analyze performance trends
/performance-monitor trends '{
  "timeframe": "30_days",
  "metrics": ["efficiency", "execution_time", "resource_usage"],
  "detect_patterns": true,
  "include_correlations": true
}'

# Compare workflow performance
/performance-monitor comparative workflow_123 '{
  "compare_against": ["workflow_456", "baseline"],
  "metrics": ["all"],
  "statistical_significance": true
}'

# Generate regression analysis
/performance-monitor regression '{
  "baseline_date": "2025-01-01",
  "current_date": "2025-01-15",
  "significance_threshold": 5.0,
  "auto_investigate": true
}'
```

### Efficiency Analysis Operations
```bash
# Calculate comprehensive efficiency metrics
/performance-monitor efficiency workflow_789 '{
  "dimensions": ["time", "resource", "quality", "workflow"],
  "benchmark_against": "historical_average",
  "include_breakdown": true
}'

# Identify performance bottlenecks
/performance-monitor bottlenecks '{
  "analysis_depth": "detailed",
  "include_solutions": true,
  "priority_ranking": true,
  "cross_workflow": true
}'

# Analyze agent performance
/performance-monitor agent-performance '{
  "agent_ids": ["agent_001", "agent_002"],
  "metrics": ["response_time", "success_rate", "efficiency"],
  "time_range": "24h"
}'
```

### Optimization Operations
```bash
# Generate optimization recommendations
/performance-monitor recommendations '{
  "scope": "workflow_and_system",
  "priority_filter": "high_medium",
  "implementation_effort": "low_medium",
  "expected_roi": ">10%"
}'

# Tune performance parameters
/performance-monitor tune-suggestions '{
  "target_metric": "overall_efficiency",
  "current_score": 84.7,
  "target_score": 90.0,
  "constraints": ["no_breaking_changes"]
}'

# Plan capacity optimization
/performance-monitor capacity-planning '{
  "time_horizon": "3_months",
  "growth_projection": 25,
  "optimization_goals": ["efficiency", "cost"],
  "include_scenarios": true
}'
```

### Predictive Analytics Operations
```bash
# Generate performance predictions
/performance-monitor predictions '{
  "forecast_horizon": "7_days",
  "confidence_interval": 0.95,
  "include_scenarios": ["best_case", "worst_case", "likely"],
  "factors": ["workload", "resources", "external"]
}'

# Analyze performance patterns
/performance-monitor patterns '{
  "pattern_types": ["success", "failure", "emerging"],
  "confidence_threshold": 0.7,
  "actionable_only": true
}'
```

## Integration with Coordination Hub and Resource Manager

### Performance-Aware Workflow Coordination
```
Performance Monitor → Coordination Hub Integration:

1. Real-Time Performance Feedback:
   - Continuous workflow performance monitoring
   - Performance degradation alerts to coordination-hub
   - Optimization recommendations for workflow adjustments
   - Predictive performance warnings

2. Historical Performance Context:
   - Performance-based workflow scheduling recommendations
   - Agent assignment optimization based on performance history
   - Resource allocation guidance from performance analysis
   - Workflow pattern optimization suggestions

3. Cross-Workflow Performance Optimization:
   - Global performance impact analysis
   - Cross-workflow resource contention detection
   - System-wide optimization coordination
   - Performance-based priority adjustments
```

### Resource-Optimized Performance Monitoring
```
Performance Monitor → Resource Manager Integration:

1. Resource-Performance Correlation:
   - Resource allocation impact on performance
   - Resource efficiency optimization recommendations
   - Performance-guided resource scaling decisions
   - Resource bottleneck identification and resolution

2. Capacity Planning Support:
   - Performance-based capacity requirement predictions
   - Resource optimization opportunity identification
   - Performance degradation early warning system
   - Resource allocation ROI analysis

3. Dynamic Performance Optimization:
   - Real-time resource reallocation recommendations
   - Performance-based resource priority adjustments
   - Automated performance-resource optimization loops
   - Resource conflict performance impact assessment
```

### State Synchronization Protocol
```json
{
  "performance_coordination_sync": {
    "coordination_hub_updates": {
      "performance_alerts": {
        "workflow_degradation": "performance_threshold_breach",
        "optimization_opportunities": "efficiency_improvement_available",
        "resource_recommendations": "resource_adjustment_suggested"
      },
      "workflow_performance_context": {
        "execution_efficiency": "real_time_efficiency_score",
        "resource_utilization": "current_resource_efficiency",
        "predicted_completion": "performance_based_eta"
      }
    },
    "resource_manager_updates": {
      "resource_performance_impact": {
        "allocation_efficiency": "resource_allocation_performance_score",
        "optimization_suggestions": "resource_optimization_recommendations",
        "capacity_requirements": "performance_based_capacity_needs"
      },
      "performance_guided_scaling": {
        "scale_triggers": "performance_degradation_thresholds",
        "optimization_targets": "performance_improvement_goals",
        "efficiency_metrics": "resource_efficiency_tracking"
      }
    }
  }
}
```

## Arguments

- **monitoring-type**: Performance monitoring operation (monitor, live-metrics, dashboard, trends, comparative, regression, efficiency, bottlenecks, agent-performance, recommendations, tune-suggestions, capacity-planning, predictions, patterns)
- **workflow-id**: Optional workflow identifier for targeted analysis
- **options**: JSON object with monitoring-specific configuration, filters, and analysis parameters

## Advanced Analytics Features

### Machine Learning Performance Prediction
```json
{
  "ml_predictions": {
    "performance_forecasting": {
      "model_type": "time_series_lstm",
      "prediction_accuracy": 87.3,
      "forecast_horizon": "7_days",
      "confidence_intervals": {
        "80%": [82.1, 88.9],
        "95%": [78.4, 92.6]
      }
    },
    "anomaly_detection": {
      "model_type": "isolation_forest",
      "sensitivity": "medium",
      "false_positive_rate": 2.1,
      "detected_anomalies": [
        {
          "timestamp": "2025-01-15T14:23:00Z",
          "metric": "agent_response_time",
          "anomaly_score": 0.89,
          "probable_cause": "network_latency_spike"
        }
      ]
    },
    "optimization_suggestions": {
      "model_type": "reinforcement_learning",
      "training_data_days": 90,
      "recommendation_confidence": 0.91,
      "expected_improvement": 12.4
    }
  }
}
```

### Performance Alert System
```json
{
  "alert_system": {
    "performance_alerts": [
      {
        "type": "efficiency_degradation",
        "severity": "medium",
        "threshold_breach": "efficiency < 80%",
        "current_value": 76.8,
        "trend": "declining",
        "recommendation": "Investigate agent pool utilization"
      },
      {
        "type": "response_time_spike",
        "severity": "high",
        "threshold_breach": "response_time > 5s",
        "current_value": 7.2,
        "impact": "workflow_delay",
        "recommendation": "Check resource allocation and system load"
      }
    ],
    "optimization_alerts": [
      {
        "type": "optimization_opportunity",
        "severity": "info",
        "opportunity": "parallel_execution_improvement",
        "potential_gain": "22% execution time reduction",
        "implementation_effort": "medium"
      }
    ]
  }
}
```

## Error Handling and Recovery

### Performance Monitoring Resilience
```
Performance Monitoring Failure Scenarios:

1. Metrics Collection Failure:
   - Fallback to reduced metric set
   - Maintain core performance tracking
   - Alert on data collection issues
   - Implement metric reconstruction from logs

2. Analysis Engine Failures:
   - Graceful degradation to basic metrics
   - Cache last known good analysis results
   - Retry analysis with reduced complexity
   - Manual analysis mode availability

3. Storage System Issues:
   - In-memory metric buffering
   - Compressed metric storage
   - Distributed storage redundancy
   - Metric data recovery procedures

4. Integration Failures:
   - Standalone monitoring mode
   - Cached coordination state
   - Manual resource monitoring
   - Integration health monitoring
```

## Output Format

### Success Response
```json
{
  "status": "success",
  "operation": "performance_monitoring_operation",
  "workflow_id": "workflow_123",
  "timestamp": "2025-01-15T12:00:00Z",
  "result": {
    "performance_data": "operation_specific_performance_metrics",
    "analysis_results": "detailed_performance_analysis",
    "recommendations": "actionable_optimization_suggestions"
  },
  "metrics": {
    "monitoring_overhead": "0.3%",
    "data_collection_time": "1.2s",
    "analysis_accuracy": 94.7
  },
  "next_steps": [
    "Monitor implementation of recommendations",
    "Schedule follow-up performance review in 24h"
  ]
}
```

### Error Response
```json
{
  "status": "error",
  "operation": "performance_monitoring_operation",
  "workflow_id": "workflow_123",
  "error": {
    "code": "INSUFFICIENT_PERFORMANCE_DATA",
    "message": "Not enough performance data available for analysis",
    "details": "Minimum 1 hour of execution data required for trend analysis"
  },
  "fallback_options": [
    "Use real-time monitoring instead",
    "Run analysis with reduced confidence",
    "Wait for more data collection"
  ]
}
```

## Configuration

### Default Performance Monitoring Settings
```json
{
  "performance_monitoring_defaults": {
    "collection_intervals": {
      "real_time_metrics": "5s",
      "resource_sampling": "30s",
      "performance_analysis": "5m",
      "trend_calculation": "1h"
    },
    "alert_thresholds": {
      "efficiency_warning": 75.0,
      "efficiency_critical": 65.0,
      "response_time_warning": 3.0,
      "response_time_critical": 8.0
    },
    "optimization_settings": {
      "recommendation_confidence": 0.8,
      "implementation_effort_preference": "low_medium",
      "minimum_improvement_threshold": 5.0,
      "breaking_change_tolerance": false
    },
    "retention_policies": {
      "real_time_data": "24h",
      "daily_summaries": "90d",
      "weekly_trends": "1y",
      "optimization_history": "permanent"
    }
  }
}
```

---

## Integration Notes

This performance monitor serves as the intelligence and optimization engine for orchestrated development workflows, providing:

1. **Comprehensive Performance Tracking**: Real-time and historical performance monitoring across all dimensions
2. **Intelligent Optimization Engine**: ML-powered recommendations and predictive optimization suggestions
3. **Efficiency Analytics**: Multi-dimensional efficiency analysis with actionable insights
4. **Comparative Analysis**: Cross-workflow benchmarking and performance trend identification
5. **Predictive Intelligence**: Performance forecasting and proactive optimization recommendations
6. **Seamless Integration**: Native coordination with coordination-hub and resource-manager for global optimization