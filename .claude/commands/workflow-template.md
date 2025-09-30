---
allowed-tools: Read, Write, Grep, Glob
argument-hint: <operation> [template-name] [parameters]
description: Workflow template management and generation
command-type: dependent
dependent-commands: dependency-resolver, coordination-hub
---

# Workflow Template Management and Generation

I'll provide comprehensive workflow template creation, storage, validation, and intelligent generation capabilities with seamless integration to dependency analysis and coordination systems.

## Template Operations Engine

Let me parse your template operation request and execute the appropriate template management function.

### 1. Operation Classification and Routing

First, I'll analyze the requested operation type:
- **Template Creation**: create, generate, new, build
- **Template Management**: list, show, edit, update, modify
- **Template Validation**: validate, check, verify, test
- **Template Optimization**: optimize, improve, enhance, analyze
- **Template Application**: apply, use, instantiate, deploy
- **Intelligence Operations**: analyze-project, recommend, suggest, auto-generate

### 2. Intelligent Template Generation System

#### Project Analysis Engine
```json
{
  "project_analysis": {
    "codebase_structure": {
      "languages": ["typescript", "javascript", "python"],
      "frameworks": ["react", "express", "fastapi"],
      "patterns": ["mvc", "microservices", "component_based"],
      "testing_frameworks": ["jest", "pytest", "cypress"],
      "build_tools": ["webpack", "vite", "docker"],
      "deployment_targets": ["aws", "kubernetes", "vercel"]
    },
    "complexity_indicators": {
      "file_count": 150,
      "dependency_depth": 4,
      "integration_points": 8,
      "external_services": ["database", "redis", "s3"],
      "estimated_team_size": "medium",
      "development_stage": "mature"
    },
    "workflow_patterns": {
      "common_operations": ["build", "test", "deploy", "migrate"],
      "typical_phases": ["setup", "development", "testing", "deployment"],
      "parallel_opportunities": ["tests", "builds", "documentation"],
      "sequential_requirements": ["migrations", "deployments", "rollbacks"]
    }
  }
}
```

#### Template Generation Algorithm
```
Intelligent Template Creation Process:
1. Analyze project structure and identify technology stack
2. Detect existing workflow patterns and development practices
3. Identify optimization opportunities and bottlenecks
4. Generate phase structure based on project complexity
5. Create task breakdown with dependency analysis
6. Optimize for parallelization and resource efficiency
7. Validate template against project constraints
8. Integrate best practices and industry standards
```

### 3. Template Storage and Management System

#### Template Repository Structure
```
.claude/templates/
├── workflows/
│   ├── core/                    # Built-in workflow templates
│   │   ├── web_application.yml
│   │   ├── api_service.yml
│   │   ├── microservice.yml
│   │   └── data_pipeline.yml
│   ├── custom/                  # User-created templates
│   │   ├── project_specific.yml
│   │   └── team_workflows.yml
│   └── generated/               # AI-generated templates
│       ├── auto_web_app_001.yml
│       └── optimized_deployment_002.yml
├── phases/                      # Reusable phase templates
│   ├── setup_phases/
│   │   ├── environment_setup.yml
│   │   ├── dependency_install.yml
│   │   └── configuration_init.yml
│   ├── development_phases/
│   │   ├── feature_implementation.yml
│   │   ├── api_development.yml
│   │   └── ui_development.yml
│   └── deployment_phases/
│       ├── build_process.yml
│       ├── testing_validation.yml
│       └── production_deploy.yml
├── tasks/                       # Atomic task templates
│   ├── code_tasks/
│   ├── config_tasks/
│   ├── test_tasks/
│   └── deploy_tasks/
└── metadata/
    ├── template_registry.json
    ├── usage_analytics.json
    └── optimization_history.json
```

#### Template Schema Definition
```yaml
# Workflow Template Schema
template_metadata:
  id: "web_application_v2.1"
  name: "Modern Web Application Workflow"
  description: "Full-stack web application development with testing and deployment"
  version: "2.1.0"
  author: "Claude Template Engine"
  created_date: "2025-01-15T10:00:00Z"
  updated_date: "2025-01-15T12:30:00Z"
  tags: ["web", "frontend", "backend", "api", "deployment"]
  complexity: "high"
  estimated_duration: "3h 30m"
  target_project_types: ["react_app", "express_api", "full_stack"]

project_requirements:
  min_file_count: 20
  required_technologies: ["javascript", "nodejs"]
  optional_technologies: ["typescript", "react", "express"]
  required_directories: ["src", "public"]
  required_files: ["package.json"]

workflow_structure:
  phases:
    - phase_id: 1
      name: "Environment Setup and Configuration"
      description: "Initialize development environment and project configuration"
      complexity: "medium"
      estimated_duration: "30m"
      prerequisites: []
      parallel_execution: false
      critical_path: true

      tasks:
        - task_id: "setup_001"
          name: "Verify development environment"
          description: "Check Node.js, npm, and required tools"
          task_type: "verification"
          estimated_duration: "5m"
          dependencies: []
          file_operations:
            - type: "read"
              paths: ["package.json", ".nvmrc"]
          success_criteria:
            - "Node.js version >= 16.0.0"
            - "npm is accessible"
            - "Required packages are installable"

        - task_id: "setup_002"
          name: "Install project dependencies"
          description: "Install npm packages and setup development tools"
          task_type: "installation"
          estimated_duration: "10m"
          dependencies: ["setup_001"]
          file_operations:
            - type: "read"
              paths: ["package.json", "package-lock.json"]
            - type: "write"
              paths: ["node_modules/"]
          success_criteria:
            - "All dependencies installed successfully"
            - "No security vulnerabilities detected"
            - "Development server can start"

dependency_configuration:
  external_dependencies:
    - name: "database_service"
      type: "postgresql"
      required: true
      fallback_available: false
    - name: "redis_cache"
      type: "redis"
      required: false
      fallback_available: true

  inter_phase_dependencies:
    - from_phase: 1
      to_phase: 2
      dependency_type: "hard"
      reason: "Configuration required for development"
    - from_phase: 2
      to_phase: 3
      dependency_type: "soft"
      reason: "Basic functionality needed for testing"

optimization_hints:
  parallelization_opportunities:
    - phase_range: [2, 3]
      tasks: ["frontend_development", "api_development"]
      resource_requirements: "medium"
      conflict_potential: "low"

  resource_optimization:
    - optimization_type: "build_cache"
      applicable_phases: [2, 3, 4]
      estimated_savings: "25%"
      implementation_complexity: "low"

  performance_targets:
    - metric: "total_execution_time"
      target: "< 3h"
      critical: true
    - metric: "parallel_efficiency"
      target: "> 75%"
      critical: false

validation_rules:
  pre_execution:
    - rule: "verify_project_structure"
      description: "Ensure project matches template requirements"
      severity: "error"
    - rule: "check_dependency_availability"
      description: "Verify external dependencies are accessible"
      severity: "warning"

  post_execution:
    - rule: "validate_deliverables"
      description: "Ensure all expected outputs are created"
      severity: "error"
    - rule: "run_integration_tests"
      description: "Execute template-specific validation tests"
      severity: "warning"
```

### 4. Template Validation and Quality Assurance

#### Multi-Level Validation System
```json
{
  "validation_framework": {
    "structural_validation": {
      "schema_compliance": "validate_against_template_schema",
      "dependency_consistency": "check_task_dependencies_are_resolvable",
      "phase_logical_flow": "verify_phase_sequence_makes_sense",
      "resource_availability": "validate_required_resources_exist"
    },
    "semantic_validation": {
      "task_completeness": "ensure_tasks_cover_all_objectives",
      "success_criteria_adequacy": "verify_success_criteria_are_measurable",
      "rollback_feasibility": "check_rollback_procedures_are_practical",
      "error_handling_coverage": "validate_error_scenarios_are_addressed"
    },
    "performance_validation": {
      "execution_time_estimates": "verify_time_estimates_are_realistic",
      "resource_utilization": "check_resource_usage_is_optimal",
      "parallelization_safety": "validate_parallel_tasks_dont_conflict",
      "scalability_assessment": "evaluate_template_scales_with_project_size"
    },
    "compatibility_validation": {
      "project_type_matching": "ensure_template_fits_project_characteristics",
      "technology_compatibility": "verify_template_works_with_tech_stack",
      "environment_requirements": "check_environment_dependencies_are_met",
      "integration_compatibility": "validate_integration_with_existing_workflows"
    }
  }
}
```

#### Quality Metrics and Scoring
```json
{
  "quality_assessment": {
    "completeness_score": {
      "task_coverage": 0.95,
      "documentation_quality": 0.88,
      "error_handling": 0.92,
      "validation_completeness": 0.90,
      "overall_completeness": 0.91
    },
    "optimization_score": {
      "parallelization_potential": 0.78,
      "resource_efficiency": 0.85,
      "execution_time_optimization": 0.82,
      "dependency_optimization": 0.79,
      "overall_optimization": 0.81
    },
    "maintainability_score": {
      "template_clarity": 0.94,
      "modification_ease": 0.87,
      "reusability": 0.91,
      "documentation_quality": 0.89,
      "overall_maintainability": 0.90
    },
    "reliability_score": {
      "error_resilience": 0.88,
      "rollback_capability": 0.93,
      "dependency_robustness": 0.86,
      "validation_coverage": 0.91,
      "overall_reliability": 0.90
    }
  },
  "recommendations": [
    {
      "category": "optimization",
      "priority": "high",
      "description": "Add parallel execution for independent testing phases",
      "estimated_improvement": "20% time reduction",
      "implementation_effort": "medium"
    },
    {
      "category": "reliability",
      "priority": "medium",
      "description": "Enhance error handling for network-dependent tasks",
      "estimated_improvement": "15% failure reduction",
      "implementation_effort": "low"
    }
  ]
}
```

### 5. Template Customization and Modification Engine

#### Dynamic Template Customization
```json
{
  "customization_engine": {
    "parameter_injection": {
      "project_variables": {
        "project_name": "${PROJECT_NAME}",
        "technology_stack": "${TECH_STACK}",
        "deployment_target": "${DEPLOY_TARGET}",
        "team_size": "${TEAM_SIZE}"
      },
      "dynamic_configuration": {
        "conditional_phases": "include_phases_based_on_project_type",
        "scalable_task_lists": "adjust_task_complexity_based_on_team_size",
        "environment_specific": "customize_tasks_for_deployment_environment",
        "performance_tuning": "optimize_based_on_available_resources"
      }
    },
    "template_merging": {
      "base_template": "core_workflow_template",
      "overlay_templates": ["security_hardening", "performance_optimization"],
      "merge_strategy": "additive_with_conflict_resolution",
      "conflict_resolution_rules": [
        {
          "conflict_type": "duplicate_tasks",
          "resolution": "merge_and_enhance"
        },
        {
          "conflict_type": "contradictory_requirements",
          "resolution": "user_selection_prompt"
        }
      ]
    },
    "adaptive_optimization": {
      "learning_from_execution": "adjust_estimates_based_on_actual_performance",
      "pattern_recognition": "identify_common_modifications_for_auto_suggestion",
      "performance_feedback": "optimize_templates_based_on_success_metrics",
      "usage_analytics": "prioritize_improvements_based_on_template_usage"
    }
  }
}
```

#### Template Modification Interface
```json
{
  "modification_interface": {
    "interactive_editing": {
      "phase_editor": "add_remove_modify_phases_with_validation",
      "task_editor": "detailed_task_modification_with_dependency_check",
      "dependency_editor": "visual_dependency_management_interface",
      "optimization_editor": "performance_tuning_parameter_adjustment"
    },
    "batch_modifications": {
      "pattern_replacement": "bulk_replace_patterns_across_template",
      "conditional_updates": "apply_modifications_based_on_conditions",
      "version_management": "track_changes_and_provide_rollback",
      "validation_pipeline": "automatic_validation_after_modifications"
    },
    "ai_assisted_editing": {
      "suggestion_engine": "ai_powered_improvement_suggestions",
      "conflict_detection": "automatic_identification_of_logical_conflicts",
      "optimization_recommendations": "ai_generated_performance_improvements",
      "best_practice_integration": "automatic_incorporation_of_industry_standards"
    }
  }
}
```

### 6. Integration with Dependency Resolver

#### Template Optimization Feedback Loop
```json
{
  "dependency_integration": {
    "template_analysis_request": {
      "template_id": "web_application_v2.1",
      "analysis_type": "comprehensive_optimization",
      "focus_areas": ["dependency_optimization", "conflict_detection", "performance_analysis"],
      "project_context": {
        "existing_files": ["src/", "public/", "package.json"],
        "technology_stack": ["react", "express", "postgresql"],
        "resource_constraints": {"max_execution_time": "3h", "max_parallel_agents": 8}
      }
    },
    "dependency_resolver_feedback": {
      "optimization_opportunities": [
        {
          "type": "parallelization",
          "description": "Frontend and backend development can run in parallel",
          "estimated_improvement": "30% time reduction",
          "implementation_changes": [
            "Split phase 2 into parallel sub-phases",
            "Add resource isolation for parallel tasks",
            "Update dependency chain to remove artificial sequencing"
          ]
        }
      ],
      "conflict_warnings": [
        {
          "type": "resource_conflict",
          "description": "Database migration and testing phases both access database",
          "severity": "medium",
          "resolution_suggestions": [
            "Use separate test database",
            "Serialize database operations",
            "Implement database connection pooling"
          ]
        }
      ],
      "dependency_recommendations": [
        {
          "recommendation": "early_dependency_resolution",
          "description": "Pre-fetch npm packages before they're needed",
          "implementation": "Add dependency prefetch task in phase 1",
          "estimated_benefit": "10% faster subsequent phases"
        }
      ]
    },
    "template_enhancement": {
      "auto_apply_optimizations": "automatically_incorporate_safe_optimizations",
      "flag_manual_review": "highlight_changes_requiring_human_approval",
      "version_with_improvements": "create_optimized_template_version",
      "performance_validation": "validate_improvements_maintain_template_integrity"
    }
  }
}
```

#### Continuous Template Improvement
```
Template Optimization Cycle:
1. Execute template in real workflow
2. Collect performance and success metrics
3. Analyze bottlenecks and inefficiencies via dependency-resolver
4. Generate optimization recommendations
5. Apply improvements to template
6. Validate enhanced template
7. Update template repository
8. Share improvements across similar templates
```

### 7. Integration with Coordination Hub

#### Template Execution Coordination
```json
{
  "coordination_integration": {
    "template_deployment": {
      "workflow_registration": {
        "template_id": "web_application_v2.1",
        "instance_id": "webapp_deploy_001",
        "estimated_resources": {"agents": 6, "duration": "3h 30m"},
        "priority": "medium",
        "dependencies": ["environment_ready", "source_code_available"]
      },
      "resource_planning": {
        "phase_resource_requirements": [
          {"phase": 1, "agents": 2, "duration": "30m", "critical_path": true},
          {"phase": 2, "agents": 4, "duration": "90m", "parallel_safe": true},
          {"phase": 3, "agents": 3, "duration": "60m", "dependencies": ["phase_2"]}
        ],
        "resource_optimization": "coordinate_with_other_workflows_for_efficient_resource_usage"
      }
    },
    "real_time_adaptation": {
      "performance_monitoring": "track_actual_vs_estimated_execution_metrics",
      "dynamic_adjustments": "modify_remaining_phases_based_on_current_performance",
      "resource_reallocation": "coordinate_resource_changes_with_coordination_hub",
      "failure_recovery": "implement_template_specific_recovery_procedures"
    },
    "template_analytics": {
      "usage_tracking": "monitor_template_usage_patterns_across_workflows",
      "success_metrics": "collect_completion_rates_and_quality_scores",
      "performance_benchmarks": "establish_baseline_performance_for_template_types",
      "improvement_identification": "identify_commonly_modified_template_sections"
    }
  }
}
```

## Operations Implementation

### Template Creation and Generation
```bash
# Create new template from project analysis
/workflow-template create web-app-advanced '{
  "analyze_project": true,
  "project_path": "/path/to/project",
  "complexity": "high",
  "include_deployment": true,
  "optimization_level": "aggressive"
}'

# Generate template from existing workflow
/workflow-template generate from-workflow '{
  "workflow_file": "specs/plans/web_development.md",
  "template_name": "custom_web_workflow",
  "generalize": true,
  "extract_patterns": true
}'

# Create template from scratch with AI assistance
/workflow-template create ai-assisted '{
  "project_type": "microservice",
  "technology_stack": ["nodejs", "docker", "kubernetes"],
  "team_size": "medium",
  "deployment_complexity": "high"
}'
```

### Template Management Operations
```bash
# List available templates
/workflow-template list '{
  "category": "all|core|custom|generated",
  "filter": {"complexity": "high", "tags": ["web", "api"]},
  "sort_by": "usage_count|last_modified|quality_score"
}'

# Show template details
/workflow-template show web-application-v2.1 '{
  "include_metrics": true,
  "show_optimization_opportunities": true,
  "validate_current_project": true
}'

# Edit template with AI assistance
/workflow-template edit web-application-v2.1 '{
  "modifications": ["add_security_phase", "optimize_parallelization"],
  "ai_suggestions": true,
  "validate_changes": true
}'
```

### Template Validation and Optimization
```bash
# Validate template quality and completeness
/workflow-template validate web-application-v2.1 '{
  "validation_level": "comprehensive",
  "check_dependencies": true,
  "performance_analysis": true,
  "compatibility_check": true
}'

# Optimize template using dependency resolver
/workflow-template optimize web-application-v2.1 '{
  "optimization_goals": ["minimize_time", "maximize_parallelization"],
  "resource_constraints": {"max_agents": 8, "max_duration": "3h"},
  "apply_improvements": true
}'

# Analyze template for specific project
/workflow-template analyze web-application-v2.1 '{
  "project_path": "/current/project",
  "compatibility_check": true,
  "customization_suggestions": true,
  "performance_estimate": true
}'
```

### Template Application and Instantiation
```bash
# Apply template to current project
/workflow-template apply web-application-v2.1 '{
  "project_variables": {
    "project_name": "MyWebApp",
    "deployment_target": "aws",
    "database_type": "postgresql"
  },
  "customizations": ["skip_mobile_phase", "add_monitoring"],
  "dry_run": false
}'

# Create workflow plan from template
/workflow-template instantiate microservice-deployment '{
  "output_format": "implementation_plan",
  "output_path": "specs/plans/microservice_deploy.md",
  "include_validation": true,
  "optimize_for_project": true
}'
```

### Intelligence and Analytics Operations
```bash
# Analyze project and recommend template
/workflow-template analyze-project '{
  "project_path": "/path/to/analyze",
  "recommend_templates": true,
  "suggest_modifications": true,
  "performance_predictions": true
}'

# Get template recommendations
/workflow-template recommend '{
  "project_characteristics": {
    "type": "web_application",
    "complexity": "medium",
    "team_size": 4,
    "timeline": "2_weeks"
  },
  "include_custom_options": true,
  "optimization_focus": "speed"
}'

# Generate usage and performance analytics
/workflow-template analytics '{
  "report_type": "usage_summary|performance_analysis|optimization_opportunities",
  "time_range": "last_30_days",
  "include_recommendations": true
}'
```

## Template Quality Framework

### Quality Metrics Definition
```json
{
  "quality_framework": {
    "completeness_metrics": {
      "task_coverage_ratio": "percentage_of_project_requirements_covered",
      "documentation_completeness": "percentage_of_tasks_with_adequate_documentation",
      "validation_coverage": "percentage_of_tasks_with_success_criteria",
      "error_handling_coverage": "percentage_of_failure_scenarios_addressed"
    },
    "optimization_metrics": {
      "parallelization_efficiency": "ratio_of_parallel_to_sequential_tasks",
      "resource_utilization": "optimal_use_of_available_resources",
      "execution_time_optimization": "ratio_of_optimized_to_baseline_execution_time",
      "dependency_minimization": "reduction_in_unnecessary_dependencies"
    },
    "reliability_metrics": {
      "execution_success_rate": "percentage_of_successful_template_executions",
      "rollback_success_rate": "percentage_of_successful_failure_recoveries",
      "cross_environment_compatibility": "success_rate_across_different_environments",
      "maintainability_score": "ease_of_template_modification_and_updates"
    },
    "usability_metrics": {
      "adoption_rate": "frequency_of_template_usage",
      "customization_frequency": "how_often_templates_require_modification",
      "user_satisfaction": "feedback_scores_from_template_users",
      "learning_curve": "time_required_to_effectively_use_template"
    }
  }
}
```

### Automated Quality Improvement
```
Quality Improvement Process:
1. Collect execution metrics from template usage
2. Identify patterns in failures and inefficiencies
3. Generate improvement recommendations using AI
4. Apply safe optimizations automatically
5. Flag complex improvements for human review
6. Test improved templates in controlled environments
7. Deploy improvements to template repository
8. Monitor impact of improvements on subsequent usage
```

## Advanced Template Features

### Smart Template Inheritance
```yaml
# Template inheritance example
template_metadata:
  id: "advanced_web_app"
  inherits_from: "web_application_base"

inheritance_rules:
  override_phases: [3, 4]  # Override testing and deployment phases
  extend_phases: [2]       # Add tasks to development phase
  merge_configurations: true

overrides:
  phases:
    - phase_id: 3
      name: "Advanced Testing Suite"
      tasks:
        - task_id: "test_001"
          name: "End-to-end testing with Playwright"
          # ... enhanced testing tasks

extensions:
  phases:
    - phase_id: 2
      additional_tasks:
        - task_id: "dev_005"
          name: "API documentation generation"
          # ... additional development task
```

### Context-Aware Template Adaptation
```json
{
  "adaptive_templates": {
    "context_detection": {
      "project_size": "detect_based_on_file_count_and_complexity",
      "technology_maturity": "analyze_dependency_versions_and_patterns",
      "team_experience": "infer_from_code_quality_and_patterns",
      "performance_requirements": "extract_from_existing_configurations"
    },
    "automatic_adjustments": {
      "task_complexity": "adjust_based_on_team_experience_level",
      "resource_allocation": "scale_based_on_project_size",
      "validation_rigor": "increase_for_production_deployments",
      "parallelization_aggressiveness": "adjust_based_on_available_resources"
    },
    "smart_defaults": {
      "technology_specific": "use_best_practices_for_detected_stack",
      "environment_aware": "adjust_for_development_vs_production",
      "team_specific": "customize_based_on_team_preferences_history",
      "project_phase": "adapt_for_greenfield_vs_maintenance_projects"
    }
  }
}
```

### Template Performance Prediction
```json
{
  "performance_prediction": {
    "execution_time_model": {
      "base_factors": ["project_size", "complexity", "resource_availability"],
      "historical_data": "learn_from_previous_executions",
      "adjustment_factors": ["team_efficiency", "environmental_constraints"],
      "confidence_intervals": "provide_realistic_time_ranges"
    },
    "resource_requirement_prediction": {
      "agent_count_optimization": "predict_optimal_agent_allocation",
      "memory_usage_estimation": "estimate_peak_memory_requirements",
      "storage_requirements": "predict_temporary_storage_needs",
      "network_bandwidth": "estimate_external_dependency_traffic"
    },
    "success_probability_analysis": {
      "risk_factors": "identify_potential_failure_points",
      "mitigation_strategies": "suggest_risk_reduction_approaches",
      "success_indicators": "define_measurable_success_criteria",
      "contingency_planning": "prepare_alternative_execution_paths"
    }
  }
}
```

## Arguments

- **operation**: Template operation type (create, generate, list, show, edit, validate, optimize, analyze, apply, instantiate, analyze-project, recommend, analytics)
- **template-name**: Template identifier or name (required for specific template operations)
- **parameters**: JSON object with operation-specific configuration and options

## Performance Monitoring

### Template Execution Analytics
```json
{
  "performance_analytics": {
    "execution_metrics": {
      "average_completion_time": "2h 45m",
      "success_rate": 94.2,
      "resource_efficiency": 78.5,
      "user_satisfaction": 4.3
    },
    "optimization_impact": {
      "time_reduction_from_optimization": "18.5%",
      "parallelization_improvement": "32%",
      "resource_utilization_improvement": "15%",
      "error_reduction": "22%"
    },
    "usage_patterns": {
      "most_used_templates": ["web_application", "api_service", "microservice"],
      "common_customizations": ["deployment_target", "testing_framework"],
      "failure_hotspots": ["database_migration", "environment_setup"],
      "optimization_opportunities": ["parallel_testing", "build_caching"]
    }
  }
}
```

## Error Handling and Recovery

### Template Validation Failures
```
Template Validation Error Types:
- Schema validation failures (missing required fields)
- Logical inconsistencies (circular dependencies)
- Resource constraint violations (impossible requirements)
- Compatibility issues (unsupported technology combinations)

Recovery Strategies:
- Automatic fixing of minor schema issues
- Dependency cycle detection and resolution suggestions
- Resource requirement adjustment recommendations
- Alternative template suggestions for compatibility issues
```

### Template Execution Failures
```
Execution Failure Categories:
- Template application failures (project mismatch)
- Resource allocation failures (insufficient resources)
- Dependency resolution failures (missing dependencies)
- Performance degradation (exceeding time/resource limits)

Recovery Approaches:
- Template compatibility analysis and modification suggestions
- Dynamic resource scaling and reallocation
- Alternative dependency resolution strategies
- Performance optimization and resource constraint adjustment
```

## Output Format

### Success Response
```json
{
  "status": "success",
  "operation": "template_operation_name",
  "template_id": "web_application_v2.1",
  "timestamp": "2025-01-15T12:00:00Z",
  "result": {
    "operation_specific_data": "varies_by_operation",
    "template_metadata": {
      "quality_score": 0.89,
      "optimization_level": "high",
      "compatibility_rating": 0.95
    }
  },
  "performance": {
    "operation_time": "1.2s",
    "validation_time": "0.3s",
    "optimization_analysis_time": "0.8s"
  },
  "recommendations": [
    "Consider parallelizing testing phases for 20% time improvement",
    "Add caching layer for dependency resolution optimization"
  ]
}
```

### Error Response
```json
{
  "status": "error",
  "operation": "template_operation_name",
  "template_id": "invalid_template",
  "error": {
    "code": "TEMPLATE_VALIDATION_FAILED",
    "message": "Template contains circular dependencies",
    "details": "Circular dependency detected: task_A → task_B → task_C → task_A"
  },
  "recovery_suggestions": [
    "Use dependency-resolver to analyze and fix circular dependencies",
    "Consider breaking dependency cycle with intermediate tasks",
    "Review task dependencies and remove unnecessary connections"
  ]
}
```

## Configuration

### Default Template Settings
```json
{
  "template_defaults": {
    "quality_threshold": 0.80,
    "optimization_level": "moderate",
    "validation_strictness": "standard",
    "auto_apply_optimizations": false,
    "cache_analysis_results": true,
    "enable_ai_suggestions": true,
    "performance_tracking": true,
    "usage_analytics": true,
    "template_versioning": true,
    "backup_on_modification": true
  }
}
```

---

## Integration Notes

This workflow template system provides comprehensive template management with intelligent capabilities:

1. **Intelligent Template Generation**: AI-powered analysis and creation based on project characteristics
2. **Quality Assurance Framework**: Multi-level validation and continuous quality improvement
3. **Dynamic Optimization**: Integration with dependency-resolver for performance optimization
4. **Seamless Coordination**: Integration with coordination-hub for workflow execution
5. **Advanced Customization**: Context-aware adaptation and smart defaults
6. **Performance Analytics**: Comprehensive monitoring and improvement tracking
7. **Scalable Architecture**: Support for large-scale template repositories and usage patterns