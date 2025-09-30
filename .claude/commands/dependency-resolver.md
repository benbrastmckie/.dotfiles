---
allowed-tools: Read, Grep, Glob, TodoWrite
argument-hint: <analysis-type> [workflow-file] [options]
description: Intelligent workflow dependency analysis and optimization
command-type: utility
dependent-commands: coordination-hub, workflow-template
---

# Workflow Dependency Resolver

I'll perform intelligent workflow dependency analysis, conflict detection, and optimization to enhance workflow efficiency and reliability.

## Dependency Analysis Engine

Let me parse your dependency analysis request and execute the appropriate analysis operation.

### 1. Analysis Classification and Routing

First, I'll analyze the requested analysis type:
- **Dependency Mapping**: analyze, map, trace, discover
- **Conflict Detection**: check-conflicts, validate, verify, detect-issues
- **Optimization Analysis**: optimize, recommend, improve, enhance
- **Path Analysis**: find-paths, alternative-routes, scenario-analysis
- **Visualization**: visualize, graph, report, diagram

### 2. Workflow Dependency Mapping System

#### Dependency Graph Architecture
```json
{
  "dependency_graph": {
    "workflow_id": "workflow_123",
    "analysis_timestamp": "2025-01-15T12:00:00Z",
    "nodes": {
      "phase_1": {
        "type": "phase",
        "name": "Setup and Planning",
        "dependencies": [],
        "dependents": ["phase_2", "phase_3"],
        "resources": ["config_files", "environment_setup"],
        "estimated_duration": "15m",
        "criticality": "high"
      },
      "phase_2": {
        "type": "phase",
        "name": "Core Implementation",
        "dependencies": ["phase_1"],
        "dependents": ["phase_4"],
        "resources": ["source_files", "build_tools"],
        "estimated_duration": "45m",
        "criticality": "critical"
      },
      "task_2_1": {
        "type": "task",
        "parent_phase": "phase_2",
        "name": "Database Schema Setup",
        "dependencies": ["task_1_3", "external_db_service"],
        "dependents": ["task_2_2", "task_3_1"],
        "resources": ["database_connection", "migration_files"],
        "estimated_duration": "12m",
        "criticality": "high"
      }
    },
    "edges": [
      {
        "from": "phase_1",
        "to": "phase_2",
        "type": "sequential_dependency",
        "strength": "hard",
        "reason": "configuration_required"
      },
      {
        "from": "task_1_3",
        "to": "task_2_1",
        "type": "data_dependency",
        "strength": "hard",
        "reason": "config_output_required"
      }
    ],
    "external_dependencies": {
      "services": ["database_service", "api_gateway", "authentication_service"],
      "tools": ["docker", "nodejs", "npm"],
      "files": ["package.json", "docker-compose.yml"],
      "environment": ["NODE_ENV", "DATABASE_URL", "API_KEY"]
    }
  }
}
```

#### Resource Conflict Matrix
```json
{
  "resource_conflicts": {
    "file_conflicts": [
      {
        "resource": "src/config/database.js",
        "conflicting_tasks": ["task_2_1", "task_3_2"],
        "conflict_type": "simultaneous_write",
        "severity": "high",
        "resolution_strategies": [
          "serialize_tasks",
          "split_file_responsibility",
          "implement_merge_strategy"
        ]
      }
    ],
    "service_conflicts": [
      {
        "resource": "database_connection",
        "conflicting_phases": ["phase_2", "phase_3"],
        "conflict_type": "connection_limit_exceeded",
        "severity": "medium",
        "resolution_strategies": [
          "connection_pooling",
          "sequential_database_operations",
          "temporary_database_instances"
        ]
      }
    ],
    "tool_conflicts": [
      {
        "resource": "port_3000",
        "conflicting_services": ["dev_server", "test_runner"],
        "conflict_type": "port_binding",
        "severity": "low",
        "resolution_strategies": [
          "dynamic_port_allocation",
          "service_coordination",
          "containerized_isolation"
        ]
      }
    ]
  }
}
```

### 3. Conflict Detection Algorithms

#### Multi-Level Conflict Analysis
```
Conflict Detection Layers:
1. Resource-Level Conflicts
   - File system conflicts (simultaneous reads/writes)
   - Network resource conflicts (ports, connections)
   - System resource conflicts (memory, CPU)
   - Tool conflicts (exclusive access requirements)

2. Timing-Based Conflicts
   - Race conditions between dependent tasks
   - Deadline conflicts and scheduling issues
   - Resource availability windows
   - Service uptime dependencies

3. Data Dependency Conflicts
   - Missing input data for dependent tasks
   - Version conflicts in shared dependencies
   - State consistency across parallel operations
   - Transaction isolation requirements

4. Logic Conflicts
   - Mutually exclusive task requirements
   - Contradictory configuration changes
   - Incompatible tool versions
   - Environment setup conflicts
```

#### Conflict Detection Implementation
```json
{
  "conflict_detection": {
    "analysis_scope": "full_workflow|single_phase|task_subset",
    "detection_rules": [
      {
        "rule_id": "file_write_conflict",
        "condition": "multiple_tasks_modify_same_file",
        "severity_logic": "high_if_no_merge_strategy",
        "resolution_templates": ["serialize", "branch_and_merge", "file_locking"]
      },
      {
        "rule_id": "resource_capacity_exceeded",
        "condition": "total_resource_demand > available_capacity",
        "severity_logic": "critical_if_no_alternatives",
        "resolution_templates": ["resource_scaling", "load_balancing", "scheduling"]
      },
      {
        "rule_id": "circular_dependency",
        "condition": "task_A_depends_on_B_depends_on_A",
        "severity_logic": "critical",
        "resolution_templates": ["break_cycle", "introduce_intermediary", "redesign_flow"]
      }
    ],
    "validation_steps": [
      "parse_workflow_dependencies",
      "build_dependency_graph",
      "detect_cycles_and_conflicts",
      "analyze_resource_requirements",
      "generate_conflict_report",
      "propose_resolution_strategies"
    ]
  }
}
```

### 4. Optimization Opportunity Identification

#### Performance Optimization Analysis
```json
{
  "optimization_opportunities": {
    "parallelization": [
      {
        "opportunity_id": "parallel_testing",
        "description": "Run unit tests and integration tests in parallel",
        "current_duration": "25m",
        "optimized_duration": "15m",
        "complexity": "low",
        "risk": "low",
        "implementation": {
          "approach": "split_test_phases",
          "requirements": ["separate_test_databases", "isolated_environments"],
          "validation": "ensure_test_isolation"
        }
      }
    ],
    "resource_optimization": [
      {
        "opportunity_id": "shared_build_cache",
        "description": "Implement shared build cache across similar tasks",
        "current_resource_usage": "high_cpu_per_task",
        "optimized_resource_usage": "shared_cache_minimal_rebuild",
        "complexity": "medium",
        "risk": "low",
        "implementation": {
          "approach": "centralized_build_cache",
          "requirements": ["cache_invalidation_strategy", "cache_storage"],
          "validation": "cache_hit_ratio_monitoring"
        }
      }
    ],
    "dependency_optimization": [
      {
        "opportunity_id": "early_dependency_resolution",
        "description": "Pre-fetch external dependencies before they're needed",
        "current_blocking_time": "5m_per_phase",
        "optimized_blocking_time": "minimal",
        "complexity": "medium",
        "risk": "medium",
        "implementation": {
          "approach": "predictive_dependency_fetching",
          "requirements": ["dependency_prediction_logic", "prefetch_storage"],
          "validation": "dependency_availability_monitoring"
        }
      }
    ]
  }
}
```

#### Workflow Path Optimization
```json
{
  "path_optimization": {
    "critical_path_analysis": {
      "current_critical_path": ["phase_1", "phase_2", "phase_4", "phase_5"],
      "critical_path_duration": "2h 15m",
      "bottleneck_phases": [
        {
          "phase": "phase_2",
          "bottleneck_type": "sequential_tasks",
          "optimization_potential": "30m_reduction",
          "recommended_action": "parallelize_independent_tasks"
        }
      ]
    },
    "alternative_paths": [
      {
        "path_id": "optimized_path_1",
        "description": "Parallel execution of phases 2 and 3",
        "path_sequence": ["phase_1", "parallel(phase_2, phase_3)", "phase_4", "phase_5"],
        "estimated_duration": "1h 50m",
        "risk_assessment": "medium",
        "requirements": ["resource_scaling", "conflict_resolution"]
      },
      {
        "path_id": "optimized_path_2",
        "description": "Early testing integration",
        "path_sequence": ["phase_1", "phase_2", "continuous_testing", "phase_4", "phase_5"],
        "estimated_duration": "2h 5m",
        "risk_assessment": "low",
        "requirements": ["test_environment_isolation"]
      }
    ]
  }
}
```

### 5. Alternative Workflow Path Analysis

#### Scenario-Based Path Generation
```
Path Generation Algorithm:
1. Analyze current workflow structure and dependencies
2. Identify parallelization opportunities within constraints
3. Generate alternative execution sequences
4. Evaluate each path for:
   - Total execution time
   - Resource requirements
   - Risk factors
   - Complexity implications
5. Rank paths by optimization criteria
6. Provide implementation recommendations
```

#### Risk Assessment Framework
```json
{
  "risk_assessment": {
    "risk_categories": {
      "execution_risk": {
        "low": "well_tested_optimizations",
        "medium": "new_parallelization_patterns",
        "high": "complex_dependency_restructuring",
        "critical": "circular_dependency_breaking"
      },
      "resource_risk": {
        "low": "within_current_capacity",
        "medium": "requires_scaling",
        "high": "near_capacity_limits",
        "critical": "exceeds_available_resources"
      },
      "integration_risk": {
        "low": "isolated_changes",
        "medium": "affects_multiple_components",
        "high": "requires_external_coordination",
        "critical": "breaks_existing_integrations"
      }
    },
    "mitigation_strategies": {
      "execution_risk": ["gradual_rollout", "fallback_plans", "monitoring"],
      "resource_risk": ["capacity_planning", "auto_scaling", "resource_pools"],
      "integration_risk": ["testing_harnesses", "staged_deployment", "rollback_capability"]
    }
  }
}
```

### 6. Dependency Visualization and Reporting

#### Visual Representation Formats
```json
{
  "visualization_formats": {
    "dependency_graph": {
      "format": "DOT_notation",
      "output_types": ["svg", "png", "interactive_html"],
      "features": [
        "color_coded_criticality",
        "interactive_node_details",
        "conflict_highlighting",
        "optimization_annotations"
      ]
    },
    "timeline_view": {
      "format": "gantt_chart",
      "output_types": ["html", "pdf", "json"],
      "features": [
        "resource_allocation_overlay",
        "conflict_markers",
        "optimization_scenarios",
        "progress_tracking"
      ]
    },
    "resource_matrix": {
      "format": "conflict_heatmap",
      "output_types": ["html_table", "csv", "json"],
      "features": [
        "conflict_severity_coloring",
        "resolution_strategy_links",
        "impact_assessment",
        "priority_ranking"
      ]
    }
  }
}
```

#### Report Generation System
```json
{
  "report_templates": {
    "executive_summary": {
      "sections": [
        "workflow_health_overview",
        "critical_issues_summary",
        "optimization_recommendations",
        "implementation_priorities"
      ],
      "target_audience": "project_managers",
      "detail_level": "high_level"
    },
    "technical_analysis": {
      "sections": [
        "detailed_dependency_mapping",
        "conflict_analysis_with_solutions",
        "performance_optimization_plans",
        "implementation_specifications"
      ],
      "target_audience": "developers",
      "detail_level": "comprehensive"
    },
    "optimization_guide": {
      "sections": [
        "step_by_step_optimization_plans",
        "risk_mitigation_strategies",
        "validation_procedures",
        "rollback_protocols"
      ],
      "target_audience": "implementation_teams",
      "detail_level": "actionable"
    }
  }
}
```

### 7. Integration with Workflow Templates

#### Template Optimization Analysis
```json
{
  "template_integration": {
    "optimization_feedback": {
      "workflow_template_id": "web_app_development",
      "analysis_results": {
        "common_bottlenecks": [
          "database_migration_serialization",
          "frontend_backend_integration_delays",
          "testing_environment_conflicts"
        ],
        "recommended_template_modifications": [
          {
            "modification": "parallel_migration_strategy",
            "impact": "30%_time_reduction",
            "complexity": "medium",
            "implementation": "split_migrations_by_table_groups"
          }
        ]
      }
    },
    "template_validation": {
      "dependency_consistency": "check_template_dependencies_are_resolvable",
      "resource_feasibility": "validate_resource_requirements_within_limits",
      "optimization_potential": "identify_template_optimization_opportunities"
    },
    "template_enhancement": {
      "smart_defaults": "suggest_optimal_default_configurations",
      "adaptive_parameters": "recommend_context_aware_parameter_adjustments",
      "best_practices": "incorporate_optimization_patterns_into_templates"
    }
  }
}
```

## Operations Implementation

### Dependency Analysis Operations
```bash
# Analyze workflow dependencies
/dependency-resolver analyze workflow-definition.yml '{
  "include_external": true,
  "depth": "full",
  "conflict_detection": true,
  "optimization_analysis": true
}'

# Map dependency graph
/dependency-resolver map current-workflow '{
  "visualization": "interactive_graph",
  "include_resources": true,
  "highlight_conflicts": true
}'

# Trace specific dependency chain
/dependency-resolver trace task_123 '{
  "direction": "both",
  "include_external": true,
  "show_alternatives": true
}'
```

### Conflict Detection Operations
```bash
# Check for conflicts in workflow
/dependency-resolver check-conflicts workflow-file.yml '{
  "scope": "full_workflow",
  "severity_threshold": "medium",
  "include_resolutions": true
}'

# Validate workflow dependencies
/dependency-resolver validate current-state '{
  "check_external_services": true,
  "verify_resource_availability": true,
  "test_dependency_chains": true
}'

# Detect specific conflict types
/dependency-resolver detect-issues '{
  "focus": ["resource_conflicts", "timing_conflicts"],
  "detailed_analysis": true,
  "propose_solutions": true
}'
```

### Optimization Operations
```bash
# Optimize workflow execution
/dependency-resolver optimize workflow-123 '{
  "optimization_goals": ["minimize_duration", "reduce_conflicts"],
  "constraints": ["current_resources", "no_major_restructuring"],
  "include_alternatives": true
}'

# Recommend improvements
/dependency-resolver recommend workflow-definition.yml '{
  "focus_areas": ["parallelization", "resource_optimization"],
  "risk_tolerance": "medium",
  "implementation_complexity": "low_to_medium"
}'

# Generate alternative paths
/dependency-resolver find-paths '{
  "start_phase": "phase_1",
  "end_phase": "phase_5",
  "optimization_criteria": "shortest_duration",
  "max_alternatives": 5
}'
```

### Visualization and Reporting
```bash
# Generate dependency visualization
/dependency-resolver visualize workflow-123 '{
  "format": "interactive_graph",
  "include_conflicts": true,
  "show_optimizations": true,
  "output_path": "reports/dependency-graph.html"
}'

# Create comprehensive report
/dependency-resolver report '{
  "workflow_id": "workflow_123",
  "report_type": "technical_analysis",
  "include_sections": ["all"],
  "output_format": "html"
}'

# Generate optimization guide
/dependency-resolver optimize-guide '{
  "target_audience": "implementation_team",
  "detail_level": "step_by_step",
  "include_validation": true
}'
```

## Integration with Coordination Hub

### Workflow State Synchronization
```
Dependency Resolver → Coordination Hub:
1. Analyze workflow dependencies and conflicts
2. Provide optimization recommendations
3. Monitor dependency resolution during execution
4. Alert on dependency-related issues
5. Suggest real-time workflow adjustments

Coordination Hub → Dependency Resolver:
1. Request dependency analysis for new workflows
2. Query conflict resolution strategies
3. Get optimization recommendations for performance issues
4. Validate workflow modifications against dependencies
5. Request alternative path analysis for failure recovery
```

### Real-Time Dependency Monitoring
```json
{
  "monitoring_integration": {
    "real_time_analysis": {
      "dependency_health_checks": "continuous_validation_of_external_dependencies",
      "conflict_detection": "ongoing_monitoring_for_emerging_conflicts",
      "performance_tracking": "dependency_resolution_time_monitoring"
    },
    "adaptive_optimization": {
      "dynamic_path_adjustment": "real_time_workflow_path_optimization",
      "resource_reallocation": "dependency_based_resource_redistribution",
      "conflict_prevention": "proactive_conflict_avoidance_measures"
    }
  }
}
```

## Arguments

- **analysis-type**: Type of dependency analysis (analyze, map, trace, check-conflicts, validate, detect-issues, optimize, recommend, find-paths, visualize, report, optimize-guide)
- **workflow-file**: Path to workflow definition file or workflow ID (optional for some operations)
- **options**: JSON object with analysis-specific configuration parameters

## Performance Metrics

### Analysis Performance Tracking
```json
{
  "performance_metrics": {
    "analysis_efficiency": {
      "dependency_graph_generation": "2.3s_for_complex_workflow",
      "conflict_detection_time": "1.8s_full_analysis",
      "optimization_recommendation": "4.1s_comprehensive_analysis"
    },
    "accuracy_metrics": {
      "conflict_detection_rate": 98.5,
      "false_positive_rate": 2.1,
      "optimization_success_rate": 89.3
    },
    "optimization_impact": {
      "average_time_reduction": "22.5%",
      "conflict_resolution_success": "94.2%",
      "resource_efficiency_improvement": "18.7%"
    }
  }
}
```

## Error Handling and Validation

### Analysis Error Recovery
```
Dependency Analysis Failures:
- Handle missing or malformed workflow definitions
- Gracefully manage external dependency unavailability
- Recover from complex circular dependency scenarios
- Provide meaningful error messages with resolution suggestions

Validation Failures:
- Detect and report incomplete dependency information
- Identify and flag potentially problematic configurations
- Validate external service connectivity and availability
- Check resource requirement feasibility

Optimization Failures:
- Handle scenarios where no optimization is possible
- Provide fallback recommendations when primary optimizations fail
- Validate optimization recommendations against constraints
- Ensure optimization suggestions don't introduce new conflicts
```

## Output Format

### Success Response
```json
{
  "status": "success",
  "analysis_type": "dependency_analysis_operation",
  "workflow_id": "workflow_123",
  "timestamp": "2025-01-15T12:00:00Z",
  "results": {
    "dependency_graph": "graph_data_structure",
    "conflicts_detected": "conflict_analysis_results",
    "optimization_recommendations": "optimization_suggestions",
    "alternative_paths": "alternative_execution_paths"
  },
  "metrics": {
    "analysis_time": "3.2s",
    "complexity_score": 7.5,
    "optimization_potential": "high"
  },
  "next_steps": ["Apply optimization recommendations", "Validate dependency changes"]
}
```

### Error Response
```json
{
  "status": "error",
  "analysis_type": "dependency_analysis_operation",
  "error": {
    "code": "DEPENDENCY_ANALYSIS_FAILED",
    "message": "Unable to resolve circular dependencies in workflow",
    "details": "Circular dependency detected between task_A and task_B"
  },
  "recovery_suggestions": [
    "Review task dependencies and remove circular references",
    "Consider breaking dependency cycle with intermediate tasks",
    "Use dependency-resolver trace to analyze dependency chain"
  ]
}
```

## Configuration

### Default Analysis Settings
```json
{
  "dependency_analysis_defaults": {
    "analysis_depth": "full",
    "include_external_dependencies": true,
    "conflict_detection_sensitivity": "medium",
    "optimization_aggressiveness": "moderate",
    "visualization_detail_level": "comprehensive",
    "report_verbosity": "detailed",
    "cache_analysis_results": true,
    "real_time_monitoring": false
  }
}
```

---

## Integration Notes

This dependency resolver provides intelligent workflow analysis and optimization capabilities:

1. **Comprehensive Dependency Analysis**: Deep workflow dependency mapping and analysis
2. **Intelligent Conflict Detection**: Multi-level conflict identification with resolution strategies
3. **Optimization Intelligence**: Performance optimization recommendations and alternative path analysis
4. **Visual Reporting**: Rich visualization and comprehensive reporting capabilities
5. **Template Integration**: Seamless integration with workflow templates for optimization feedback
6. **Real-Time Monitoring**: Continuous dependency health monitoring and adaptive optimization