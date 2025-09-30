# Integration Examples Template

## Comprehensive Integration Examples for Orchestration Commands

This template provides standardized formats for documenting command integration patterns, ensuring consistent and thorough coverage of coordination scenarios.

## Helper Command Integration Examples

### Coordination Hub Integration

#### Multi-Workflow Coordination
```markdown
### Integration Example: Multi-Workflow Coordination

**Scenario**: Managing multiple concurrent workflows with resource coordination and conflict resolution

**Command Sequence**:
```bash
# Create primary workflow
/coordination-hub create-workflow '{
  "workflow_id": "feature_dev_001",
  "name": "User Authentication Feature",
  "priority": "high",
  "phases": ["research", "planning", "implementation", "testing"],
  "resource_requirements": {"agents": 3, "memory": "2GB", "duration": "4h"},
  "dependencies": ["database_migration", "security_review"]
}'

# Create secondary workflow
/coordination-hub create-workflow '{
  "workflow_id": "bug_fix_002",
  "name": "Login Performance Issue",
  "priority": "medium",
  "phases": ["investigation", "fix", "testing"],
  "resource_requirements": {"agents": 2, "memory": "1GB", "duration": "2h"},
  "dependencies": ["user_reports", "performance_data"]
}'

# Monitor coordination
/workflow-status feature_dev_001 --detailed --include-dependencies
/progress-aggregator system-overview --include-conflicts --resource-analysis
```

**Coordination Flow**:
1. Coordination hub receives workflow creation requests
2. Resource manager analyzes requirements and availability
3. Dependency resolver validates workflow dependencies
4. Workflows are prioritized and scheduled based on resource constraints
5. Progress aggregator provides system-wide view of coordination
6. Performance monitor tracks resource utilization and optimization opportunities

**Event Sequence**:
```
WORKFLOW_CREATED:feature_dev_001:setup:{"priority":"high","resources":{"agents":3}}
WORKFLOW_CREATED:bug_fix_002:setup:{"priority":"medium","resources":{"agents":2}}
RESOURCE_ANALYSIS_REQUESTED:system:coordination:{"total_agents":5,"conflicts":false}
WORKFLOW_SCHEDULED:feature_dev_001:ready:{"start_time":"immediate","estimated_completion":"4h"}
WORKFLOW_QUEUED:bug_fix_002:waiting:{"queue_position":1,"estimated_start":"30m"}
```

**Expected Results**:
- Feature development workflow starts immediately with allocated resources
- Bug fix workflow queued with realistic start time estimate
- System maintains optimal resource utilization
- No resource conflicts or agent contention
- Real-time visibility into coordination decisions
```

#### State Synchronization Across Commands
```markdown
### Integration Example: State Synchronization Across Commands

**Scenario**: Maintaining consistent workflow state across multiple coordinating commands

**Command Sequence**:
```bash
# Initialize workflow with state tracking
/coordination-hub workflow_123 create '{
  "name": "Database Migration",
  "state_sync": {"enabled": true, "frequency": "realtime", "checkpoints": "phase_boundary"},
  "monitoring": {"performance": true, "resources": true, "dependencies": true}
}'

# Subscribe to state changes
/workflow-status workflow_123 --subscribe --events=["state_change", "checkpoint", "error"]
/performance-monitor workflow_123 --track-state --optimization=adaptive
/progress-aggregator --workflow=workflow_123 --sync-state --predictive-analysis

# Execute state-changing operations
/coordination-hub workflow_123 start-phase 1
/coordination-hub workflow_123 checkpoint "pre_migration_validation"
/coordination-hub workflow_123 assign-agents '[{"agent_id":"agent_001","role":"database"}]'
```

**State Synchronization Protocol**:
1. Coordination hub publishes state changes to event system
2. All subscribed commands receive state updates in real-time
3. Commands validate state consistency and report conflicts
4. Automatic conflict resolution maintains system coherence
5. Checkpoint system ensures recoverability at any point

**Integration Benefits**:
- Consistent state view across all commands
- Automatic conflict detection and resolution
- Real-time coordination without manual synchronization
- Robust recovery capabilities through distributed checkpoints
```

### Resource Manager Integration

#### Predictive Resource Allocation
```markdown
### Integration Example: Predictive Resource Allocation

**Scenario**: Optimizing resource allocation using historical data and workflow analysis

**Command Sequence**:
```bash
# Enable predictive allocation
/resource-manager configure '{
  "prediction_mode": "enabled",
  "learning_data": "historical_workflows",
  "optimization_strategy": "adaptive",
  "conflict_prevention": "proactive"
}'

# Request allocation with prediction
/resource-manager allocate '{
  "workflow_id": "complex_feature_001",
  "workflow_type": "feature_development",
  "estimated_complexity": "high",
  "time_constraints": {"deadline": "2d", "priority": "high"},
  "prediction_context": {
    "similar_workflows": ["auth_feature", "payment_integration"],
    "team_performance": "current_team_metrics",
    "system_load": "current_utilization"
  }
}'

# Monitor allocation effectiveness
/performance-monitor allocation-efficiency workflow_complex_feature_001
/progress-aggregator resource-prediction-accuracy --historical-comparison
```

**Predictive Analysis Flow**:
1. Resource manager analyzes similar historical workflows
2. Machine learning model predicts resource needs and bottlenecks
3. Proactive allocation prevents resource conflicts
4. Continuous monitoring validates prediction accuracy
5. System learns from outcomes to improve future predictions

**Integration with Other Commands**:
- **Workflow-Status**: Real-time resource utilization reporting
- **Performance-Monitor**: Allocation efficiency tracking
- **Progress-Aggregator**: Prediction accuracy analysis
- **Coordination-Hub**: Resource conflict prevention
```

### Progress Aggregator Integration

#### System-Wide Progress Visualization
```markdown
### Integration Example: System-Wide Progress Visualization

**Scenario**: Comprehensive progress tracking across multiple concurrent workflows

**Command Sequence**:
```bash
# Configure system-wide monitoring
/progress-aggregator configure '{
  "scope": "system_wide",
  "aggregation_level": "detailed",
  "visualization": "real_time_dashboard",
  "prediction": "enabled",
  "bottleneck_detection": "automatic"
}'

# Monitor multiple workflows
/progress-aggregator track-workflows '[
  {"workflow_id": "feature_A", "weight": "high", "critical_path": true},
  {"workflow_id": "bugfix_B", "weight": "medium", "critical_path": false},
  {"workflow_id": "refactor_C", "weight": "low", "critical_path": false}
]'

# Generate comprehensive reports
/progress-aggregator system-report '{
  "include": ["progress", "resources", "predictions", "bottlenecks"],
  "format": "dashboard",
  "update_frequency": "realtime"
}'
```

**Progress Aggregation Flow**:
1. Collect progress data from all active workflows
2. Analyze interdependencies and critical paths
3. Identify system-wide bottlenecks and optimization opportunities
4. Generate predictive completion estimates
5. Provide real-time dashboard with actionable insights

**Multi-Command Coordination**:
- **Coordination-Hub**: Workflow lifecycle events
- **Resource-Manager**: Resource utilization data
- **Performance-Monitor**: Efficiency metrics
- **Workflow-Status**: Detailed progress information
```

## Real Workflow Scenarios

### Complete Feature Development Workflow
```markdown
### Real Workflow: Complete Feature Development

**Scenario**: Implementing user authentication with comprehensive workflow coordination

**Phase 1: Research and Analysis**
```bash
/orchestrate "Research authentication best practices and JWT implementation patterns" --template=research-implementation

# Orchestration creates research workflow
/coordination-hub create-workflow research_auth_001 --priority=high
/resource-manager allocate research_auth_001 --agents=2 --specialization=research

# Parallel research execution
/subagents '{
  "phase": "research",
  "workflow_id": "research_auth_001",
  "coordination": "parallel"
}' '[
  {"command": "/report", "topic": "JWT security best practices", "depth": "comprehensive"},
  {"command": "/report", "topic": "authentication flow patterns", "depth": "comprehensive"},
  {"command": "/debug", "scope": "current_auth_system", "analysis": "security_audit"}
]'
```

**Phase 2: Planning and Architecture**
```bash
# Synthesize research into implementation plan
/plan "Implement JWT-based authentication system" \
  --reports="$(find specs/reports -name '*auth*' -o -name '*jwt*')" \
  --workflow-context="research_auth_001" \
  --coordination="orchestrated"

# Resource reallocation for planning phase
/resource-manager transition research_auth_001 planning_auth_001 --preserve-context
```

**Phase 3: Implementation Coordination**
```bash
# Execute implementation with full coordination
/implement specs/plans/005_jwt_authentication.md \
  --orchestrated \
  --workflow-id="impl_auth_001" \
  --resource-coordination="adaptive" \
  --monitoring="comprehensive"

# Parallel implementation tasks
/subagents '{
  "phase": "implementation",
  "workflow_id": "impl_auth_001",
  "coordination": "dependency_aware"
}' '[
  {"command": "/implement", "phase": 1, "scope": "backend_auth_service"},
  {"command": "/implement", "phase": 2, "scope": "frontend_auth_components"},
  {"command": "/implement", "phase": 3, "scope": "database_migrations"}
]'
```

**Phase 4: Testing and Validation**
```bash
# Comprehensive testing coordination
/test authentication --comprehensive --workflow-context="impl_auth_001"
/test-all --affected-areas --coverage-analysis --performance-validation

# Security validation
/debug authentication_flow --security-analysis --penetration-testing
```

**Phase 5: Documentation and Finalization**
```bash
# Update all affected documentation
/document "JWT authentication implementation" --scope=comprehensive --cross-reference
/orchestrate finalize-workflow impl_auth_001 --validation=complete
```

**Complete Coordination Events**:
```
RESEARCH_STARTED:research_auth_001:research:{"agents":2,"estimated_duration":"2h"}
RESEARCH_COMPLETED:research_auth_001:research:{"reports_generated":3,"insights":15}
PLAN_STARTED:planning_auth_001:planning:{"context_preserved":true}
PLAN_COMPLETED:planning_auth_001:planning:{"phases":5,"complexity":"high"}
IMPLEMENTATION_STARTED:impl_auth_001:implementation:{"parallel_tracks":3}
PHASE_COMPLETED:impl_auth_001:backend:{"duration":"45m","tests_passing":true}
PHASE_COMPLETED:impl_auth_001:frontend:{"duration":"60m","tests_passing":true}
PHASE_COMPLETED:impl_auth_001:database:{"duration":"30m","tests_passing":true}
TESTING_COMPLETED:impl_auth_001:testing:{"coverage":95,"security_passed":true}
WORKFLOW_COMPLETED:impl_auth_001:finalization:{"total_duration":"4h","success":true}
```
```

### Error Handling and Recovery Workflow
```markdown
### Real Workflow: Error Handling and Recovery

**Scenario**: Managing complex workflow failure with intelligent recovery

**Initial Workflow Setup**:
```bash
/orchestrate "Implement microservices architecture migration" --priority=high --complex

# Workflow encounters critical error
ERROR_ENCOUNTERED:microservices_migration_001:database_migration:{"error":"connection_timeout","impact":"critical"}
```

**Automatic Error Detection and Analysis**:
```bash
# Error automatically triggers recovery analysis
/workflow-recovery analyze-failure microservices_migration_001 '{
  "error_context": "database_migration_timeout",
  "failure_impact": "workflow_blocked",
  "recovery_priority": "maintain_progress"
}'

# Resource reallocation due to failure
/resource-manager handle-failure microservices_migration_001 '{
  "failed_component": "database_service",
  "impact_assessment": "medium",
  "reallocation_strategy": "isolate_and_recover"
}'
```

**Recovery Coordination**:
```bash
# Coordination hub manages recovery workflow
/coordination-hub microservices_migration_001 recovery-mode '{
  "recovery_strategy": "checkpoint_restore",
  "fallback_options": ["manual_intervention", "alternative_approach"],
  "maintain_partial_progress": true
}'

# Progress aggregator tracks recovery effectiveness
/progress-aggregator recovery-analysis microservices_migration_001 '{
  "track_recovery_time": true,
  "impact_on_other_workflows": true,
  "learning_for_prevention": true
}'
```

**Recovery Execution**:
```bash
# Restore from last successful checkpoint
/coordination-hub microservices_migration_001 restore '{
  "checkpoint_id": "pre_database_migration",
  "validate_state": true,
  "prepare_alternative": true
}'

# Execute alternative approach
/orchestrate "Implement gradual database migration with rollback safety" \
  --continue-from="microservices_migration_001" \
  --strategy="conservative" \
  --recovery-mode
```

**Recovery Success Validation**:
```bash
# Validate recovery effectiveness
/performance-monitor recovery-success microservices_migration_001
/workflow-status microservices_migration_001 --recovery-report --lessons-learned
```
```

## Performance Optimization Examples

### Large-Scale Workflow Optimization
```markdown
### Performance Optimization: Large-Scale Workflows

**Scenario**: Optimizing performance for complex multi-phase workflows with resource constraints

**Baseline Measurement**:
```bash
# Establish performance baseline
/performance-monitor benchmark '{
  "workflow_type": "feature_development",
  "complexity": "high",
  "metrics": ["execution_time", "resource_utilization", "agent_efficiency"],
  "baseline_period": "last_30_days"
}'

# Results: 45min average, 3.2 agents average, 85% efficiency, 75% resource utilization
```

**Optimization Implementation**:
```bash
# Enable predictive resource allocation
/resource-manager optimize '{
  "strategy": "predictive_adaptive",
  "learning_enabled": true,
  "optimization_target": "total_time_with_quality"
}'

# Configure intelligent event batching
/coordination-hub configure-performance '{
  "event_batching": {"enabled": true, "size": 20, "timeout": "3s"},
  "state_sync": {"strategy": "incremental", "frequency": "adaptive"},
  "checkpoint_optimization": {"compression": true, "differential": true}
}'

# Enable parallel processing optimization
/subagents configure '{
  "parallel_optimization": true,
  "dependency_analysis": "automatic",
  "load_balancing": "dynamic",
  "agent_specialization": "adaptive"
}'
```

**Advanced Optimization Strategies**:
```bash
# Implement workflow caching
/coordination-hub enable-caching '{
  "cache_level": "workflow_patterns",
  "invalidation_strategy": "smart",
  "cache_sharing": "team_wide"
}'

# Enable predictive prefetching
/resource-manager prefetch '{
  "prediction_horizon": "2_phases",
  "confidence_threshold": 0.8,
  "resource_buffer": "10_percent"
}'

# Implement adaptive checkpoint frequency
/coordination-hub adaptive-checkpoints '{
  "base_frequency": "15m",
  "risk_based_adjustment": true,
  "performance_impact_awareness": true
}'
```

**Optimization Results Validation**:
```bash
# Measure optimization effectiveness
/performance-monitor compare-optimization '{
  "baseline": "pre_optimization_period",
  "current": "post_optimization_period",
  "metrics": ["time", "resources", "quality", "reliability"]
}'

# Results: 32min average (-29%), 2.8 agents average (-12%), 92% efficiency (+8%), 89% resource utilization (+19%)
```

**Continuous Performance Learning**:
```bash
# Enable continuous optimization learning
/performance-monitor enable-learning '{
  "learning_scope": "team_workflows",
  "optimization_sharing": true,
  "performance_prediction": "enabled",
  "adaptive_tuning": "continuous"
}'
```
```

## Integration Testing Examples

### End-to-End Integration Validation
```markdown
### Integration Testing: Complete Ecosystem Validation

**Scenario**: Comprehensive testing of command integration and coordination

**Integration Test Setup**:
```bash
# Initialize test environment
/coordination-hub create-test-workflow test_integration_001 '{
  "test_type": "integration",
  "scope": "full_ecosystem",
  "validation_criteria": ["coordination", "performance", "error_handling"]
}'

# Configure test monitoring
/performance-monitor test-mode '{
  "detailed_tracking": true,
  "integration_metrics": true,
  "failure_analysis": "automatic"
}'
```

**Multi-Command Coordination Testing**:
```bash
# Test workflow orchestration
/orchestrate "Test multi-phase integration workflow" --test-mode --validation=comprehensive

# Test resource coordination
/resource-manager test-allocation '{
  "scenarios": ["normal_load", "high_contention", "failure_recovery"],
  "validation": ["allocation_accuracy", "conflict_resolution", "performance"]
}'

# Test progress aggregation
/progress-aggregator test-integration '{
  "multi_workflow": true,
  "real_time_updates": true,
  "prediction_accuracy": true
}'
```

**Error Injection and Recovery Testing**:
```bash
# Test error handling robustness
/workflow-recovery test-scenarios '[
  {"error_type": "agent_failure", "impact": "medium"},
  {"error_type": "resource_exhaustion", "impact": "high"},
  {"error_type": "network_partition", "impact": "critical"}
]'

# Validate recovery effectiveness
/coordination-hub validate-recovery test_integration_001 '{
  "recovery_time_limit": "60s",
  "data_consistency": "strict",
  "performance_degradation_limit": "20_percent"
}'
```

**Integration Success Criteria**:
- All commands coordinate seamlessly without manual intervention
- Resource allocation optimizes automatically under various load conditions
- Error recovery maintains workflow progress and data consistency
- Performance remains within acceptable bounds under stress conditions
- Event system maintains real-time coordination across all components
```