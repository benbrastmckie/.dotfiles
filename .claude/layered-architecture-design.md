# 4-Layer Dependency Architecture Design

## Architecture Overview

This document defines the 4-layer dependency architecture that resolves circular dependencies and establishes clear command hierarchies.

## Layer Structure

### Layer 1: Core Foundation Services
**Commands**: `coordination-hub`, `resource-manager`
**Responsibility**: Foundation services that provide basic infrastructure
**Dependencies**: None (no dependencies on other orchestration commands)
**Key Principle**: These commands provide services TO other commands but do not depend on them

```yaml
layer_1_core:
  commands:
    - coordination-hub
    - resource-manager
  responsibilities:
    - Basic workflow state management
    - Resource allocation and monitoring
    - Event publishing infrastructure
    - State storage and persistence
  dependencies: []
  provides_services_to: [layer_2, layer_3, layer_4]
```

### Layer 2: Monitoring and Status Services
**Commands**: `workflow-status`, `performance-monitor`
**Responsibility**: Monitoring and status reporting services
**Dependencies**: Layer 1 only (coordination-hub, resource-manager)
**Key Principle**: Consume services from Layer 1, provide monitoring data to higher layers

```yaml
layer_2_monitoring:
  commands:
    - workflow-status
    - performance-monitor
  responsibilities:
    - Real-time workflow monitoring
    - Performance analytics and metrics
    - System health reporting
    - Live status dashboards
  dependencies: [coordination-hub, resource-manager]
  provides_services_to: [layer_3, layer_4]
```

### Layer 3: Advanced Workflow Services
**Commands**: `workflow-recovery`, `progress-aggregator`, `dependency-resolver`
**Responsibility**: Advanced workflow management and optimization
**Dependencies**: Layer 1 + Layer 2 (coordination-hub, resource-manager, workflow-status, performance-monitor)
**Key Principle**: Build on foundation and monitoring layers to provide advanced capabilities

```yaml
layer_3_advanced:
  commands:
    - workflow-recovery
    - progress-aggregator
    - dependency-resolver
  responsibilities:
    - Advanced recovery and rollback operations
    - Multi-workflow progress synthesis
    - Dependency analysis and optimization
    - Complex workflow orchestration logic
  dependencies: [coordination-hub, resource-manager, workflow-status, performance-monitor]
  provides_services_to: [layer_4]
```

### Layer 4: Complete Workflow Orchestration
**Commands**: `orchestrate`
**Responsibility**: Complete workflow coordination using all lower layers
**Dependencies**: All layers (all orchestration commands as needed)
**Key Principle**: Top-level orchestration that coordinates all other services

```yaml
layer_4_orchestration:
  commands:
    - orchestrate
  responsibilities:
    - Complete workflow orchestration
    - Multi-phase project coordination
    - High-level workflow decision making
    - User-facing workflow management
  dependencies: [coordination-hub, resource-manager, workflow-status, performance-monitor, workflow-recovery, progress-aggregator, dependency-resolver]
  provides_services_to: [users]
```

## Circular Dependency Resolution

### Issues Resolved

1. **coordination-hub ↔ orchestrate circular dependency**
   - **Before**: coordination-hub → orchestrate, orchestrate → coordination-hub
   - **After**: coordination-hub (Layer 1) has no orchestration dependencies, orchestrate (Layer 4) can depend on coordination-hub

2. **resource-manager ↔ coordination-hub circular dependency**
   - **Before**: resource-manager → coordination-hub, coordination-hub → resource-manager (implicit)
   - **After**: Both in Layer 1, no interdependencies - they are peer services

3. **Complex multi-way dependencies**
   - **Before**: workflow-status, performance-monitor, workflow-recovery all had overlapping dependencies
   - **After**: Clear layered hierarchy eliminates confusion

### Dependency Injection Pattern

Instead of circular dependencies, we implement a service provider pattern:

```yaml
service_provider_pattern:
  layer_1_services:
    coordination-hub:
      provides: [workflow_state_management, event_publishing, checkpoint_storage]
      consumes: []
    resource-manager:
      provides: [resource_allocation, conflict_prevention, performance_monitoring]
      consumes: []

  layer_2_services:
    workflow-status:
      provides: [real_time_monitoring, status_dashboards, interactive_control]
      consumes: [workflow_state_management, resource_allocation]
    performance-monitor:
      provides: [metrics_collection, performance_analytics, optimization_insights]
      consumes: [workflow_state_management, resource_allocation]

  layer_3_services:
    workflow-recovery:
      provides: [recovery_operations, rollback_capabilities, failure_analysis]
      consumes: [workflow_state_management, resource_allocation, real_time_monitoring]
    progress-aggregator:
      provides: [multi_workflow_synthesis, bottleneck_identification]
      consumes: [real_time_monitoring, workflow_state_management]
    dependency-resolver:
      provides: [dependency_analysis, conflict_detection, optimization]
      consumes: [workflow_state_management]

  layer_4_services:
    orchestrate:
      provides: [complete_workflow_orchestration, multi_phase_coordination]
      consumes: [all_lower_layer_services]
```

## Initialization Order

Commands must be initialized in layer order to ensure services are available when needed:

```yaml
initialization_sequence:
  phase_1_core_services:
    order: [coordination-hub, resource-manager]
    parallel: true  # These can start simultaneously
    validation: ensure_storage_directories_exist

  phase_2_monitoring_services:
    order: [workflow-status, performance-monitor]
    parallel: true
    validation: ensure_layer_1_services_responding

  phase_3_advanced_services:
    order: [workflow-recovery, progress-aggregator, dependency-resolver]
    parallel: true
    validation: ensure_layer_1_and_2_services_responding

  phase_4_orchestration:
    order: [orchestrate]
    parallel: false  # Single orchestration command
    validation: ensure_all_lower_layers_responding
```

## Communication Patterns

### Service Discovery
Commands locate services through a registry pattern rather than direct dependencies:

```yaml
service_registry:
  coordination_hub:
    endpoint: "/.claude/coordination/workflow-state"
    services: [create_workflow, get_status, publish_event, checkpoint]
  resource_manager:
    endpoint: "/.claude/resource-manager/allocations"
    services: [allocate, monitor, check_conflicts, optimize]
```

### Event-Driven Communication
Higher layers subscribe to events from lower layers:

```yaml
event_subscriptions:
  workflow-status:
    subscribes_to:
      - coordination_hub.workflow_events
      - resource_manager.allocation_events
  performance-monitor:
    subscribes_to:
      - coordination_hub.workflow_events
      - resource_manager.performance_events
  orchestrate:
    subscribes_to:
      - workflow_status.monitoring_events
      - performance_monitor.optimization_events
      - workflow_recovery.recovery_events
```

## Validation Rules

### Layer Compliance Rules
1. **Downward Dependencies Only**: Commands can only depend on lower layers
2. **No Peer Dependencies**: Commands within the same layer cannot depend on each other
3. **Service Interface Contracts**: All inter-layer communication through defined service interfaces
4. **Event-Driven Updates**: Higher layers receive updates via events, not direct calls

### Dependency Validation Scripts
Scripts to enforce architectural compliance:

```bash
# Validate layer compliance
validate_layer_compliance() {
  for command in $(list_commands_in_layer $layer); do
    deps=$(get_dependencies $command)
    for dep in $deps; do
      dep_layer=$(get_command_layer $dep)
      if [ $dep_layer -ge $layer ]; then
        error "Invalid dependency: $command (Layer $layer) depends on $dep (Layer $dep_layer)"
      fi
    done
  done
}

# Check for circular dependencies
detect_circular_dependencies() {
  python3 scripts/dependency_analyzer.py --check-cycles --report-violations
}
```

## Migration Strategy

### Phase 1: Update Core Layer (coordination-hub, resource-manager)
- Remove circular dependencies from coordination-hub
- Ensure resource-manager doesn't implicitly depend on coordination-hub
- Implement service provider interfaces

### Phase 2: Update Monitoring Layer (workflow-status, performance-monitor)
- Update dependencies to only reference Layer 1
- Implement event subscription patterns
- Test monitoring functionality

### Phase 3: Update Advanced Layer (workflow-recovery, progress-aggregator, dependency-resolver)
- Update dependencies to reference Layer 1 + 2 only
- Implement advanced service patterns
- Test recovery and aggregation functionality

### Phase 4: Update Orchestration Layer (orchestrate)
- Remove circular dependency references
- Implement full orchestration using all lower layers
- Test complete workflow orchestration

## Benefits of Layered Architecture

1. **Elimination of Circular Dependencies**: Clear unidirectional dependency flow
2. **Improved Maintainability**: Changes in lower layers don't affect higher layers unexpectedly
3. **Better Testability**: Each layer can be tested independently
4. **Clear Separation of Concerns**: Each layer has well-defined responsibilities
5. **Scalability**: Layers can be optimized or replaced independently
6. **Predictable Initialization**: Clear startup order prevents race conditions

## Next Steps

1. Update command YAML frontmatter to reflect new layer dependencies
2. Implement validation scripts to enforce architectural compliance
3. Test each layer independently and in combination
4. Create monitoring for architectural violations
5. Document service interfaces between layers