# Command Integration Templates and Patterns

Date: 2025-01-15

## Overview

This document provides integration templates and patterns for implementing standardized coordination protocols between helper commands in the orchestration ecosystem. All implementations must conform to the specifications defined in [`specs/standards/command-protocols.md`](../specs/standards/command-protocols.md).

## Standard Coordination Patterns

### 1. Request-Response Pattern

Use for synchronous operations requiring immediate feedback.

#### Template Implementation

```bash
# Function: send_coordination_request
send_coordination_request() {
  local target_component="$1"
  local operation="$2"
  local parameters="$3"
  local timeout="${4:-30}"

  local request_id="req_$(uuidgen)"
  local correlation_id="corr_$(uuidgen)"

  local request_message="{
    \"message_type\": \"request\",
    \"request_id\": \"$request_id\",
    \"correlation_id\": \"$correlation_id\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"target_component\": \"$target_component\",
    \"operation\": \"$operation\",
    \"parameters\": $parameters,
    \"response_required\": true,
    \"timeout_seconds\": $timeout
  }"

  # Send request and wait for response
  local response=$(echo "$request_message" | coordination_send_and_wait "$timeout")

  # Validate response format
  if ! echo "$response" | jq -e '.response_to == "'$request_id'"' >/dev/null 2>&1; then
    log_error "Invalid response format or correlation mismatch"
    return 1
  fi

  echo "$response"
}

# Function: handle_coordination_request
handle_coordination_request() {
  local request="$1"

  local request_id=$(echo "$request" | jq -r '.request_id')
  local correlation_id=$(echo "$request" | jq -r '.correlation_id')
  local operation=$(echo "$request" | jq -r '.operation')
  local parameters=$(echo "$request" | jq -r '.parameters')

  # Process request
  local result=$(process_operation "$operation" "$parameters")
  local status=$?

  # Generate response
  local response="{
    \"message_type\": \"response\",
    \"response_id\": \"resp_$(uuidgen)\",
    \"request_id\": \"$request_id\",
    \"correlation_id\": \"$correlation_id\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"status\": \"$([ $status -eq 0 ] && echo 'success' || echo 'error')\",
    \"result\": $result,
    \"response_to\": \"$request_id\"
  }"

  coordination_send_response "$response"
}
```

### 2. Event Publishing Pattern

Use for asynchronous notifications and state changes.

#### Template Implementation

```bash
# Function: publish_workflow_event
publish_workflow_event() {
  local event_type="$1"
  local workflow_id="$2"
  local phase="$3"
  local data="$4"

  # Validate event type
  if ! validate_event_type "$event_type"; then
    log_error "Invalid event type: $event_type"
    return 1
  fi

  # Format event message according to standard
  local event_message="${event_type}:${workflow_id}:${phase}:${data}"

  # Create full event structure
  local event_payload="{
    \"event_id\": \"evt_$(uuidgen)\",
    \"event_type\": \"$event_type\",
    \"workflow_id\": \"$workflow_id\",
    \"phase\": \"$phase\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"source_component\": \"$(get_component_id)\",
    \"message\": \"$event_message\",
    \"data\": $data,
    \"routing_key\": \"${event_type}.${workflow_id}.${phase}\",
    \"priority\": \"$(get_event_priority $event_type)\",
    \"ttl_seconds\": 3600
  }"

  # Publish event
  coordination_publish_event "$event_payload"

  log_info "Published event: $event_type for workflow $workflow_id"
}

# Function: subscribe_to_events
subscribe_to_events() {
  local component_id="$1"
  local event_patterns=("${@:2}")

  local subscription="{
    \"subscriber_id\": \"$component_id\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"event_patterns\": [$(printf '\"%s\",' "${event_patterns[@]}" | sed 's/,$//')],,
    \"delivery_method\": \"push\",
    \"callback_function\": \"handle_coordination_event\",
    \"retry_policy\": {
      \"max_retries\": 3,
      \"backoff_strategy\": \"exponential\",
      \"initial_delay\": \"1s\"
    },
    \"filters\": {
      \"min_priority\": \"info\",
      \"max_age_hours\": 24
    }
  }"

  coordination_subscribe "$subscription"
}

# Function: handle_coordination_event
handle_coordination_event() {
  local event="$1"

  local event_type=$(echo "$event" | jq -r '.event_type')
  local workflow_id=$(echo "$event" | jq -r '.workflow_id')
  local phase=$(echo "$event" | jq -r '.phase')
  local data=$(echo "$event" | jq -r '.data')

  case "$event_type" in
    "WORKFLOW_STARTED")
      handle_workflow_started "$workflow_id" "$data"
      ;;
    "PHASE_COMPLETED")
      handle_phase_completed "$workflow_id" "$phase" "$data"
      ;;
    "RESOURCE_ALLOCATED")
      handle_resource_allocated "$workflow_id" "$data"
      ;;
    "ERROR_ENCOUNTERED")
      handle_error_event "$workflow_id" "$phase" "$data"
      ;;
    *)
      log_warning "Unhandled event type: $event_type"
      ;;
  esac
}
```

### 3. Resource Allocation Pattern

Use for requesting and managing system resources.

#### Template Implementation

```bash
# Function: request_resource_allocation
request_resource_allocation() {
  local workflow_id="$1"
  local resource_spec="$2"
  local priority="${3:-medium}"

  local allocation_request="{
    \"allocation_request\": {
      \"request_id\": \"req_$(uuidgen)\",
      \"workflow_id\": \"$workflow_id\",
      \"requester\": \"$(get_component_id)\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"priority\": \"$priority\",
      \"resources\": $resource_spec,
      \"constraints\": {
        \"max_wait_time\": \"10m\",
        \"conflict_tolerance\": \"low\",
        \"isolation_level\": \"moderate\"
      },
      \"fallback_options\": {
        \"reduce_agents\": true,
        \"queue_if_unavailable\": true
      }
    }
  }"

  # Send allocation request to resource manager
  local response=$(send_coordination_request "resource-manager" "allocate" "$allocation_request")

  # Process response
  local status=$(echo "$response" | jq -r '.result.allocation_response.status')

  case "$status" in
    "approved")
      local allocation_id=$(echo "$response" | jq -r '.result.allocation_response.allocation_id')
      log_info "Resource allocation approved: $allocation_id"
      echo "$allocation_id"
      return 0
      ;;
    "queued")
      log_info "Resource allocation queued"
      return 2
      ;;
    "denied")
      log_error "Resource allocation denied"
      return 1
      ;;
    *)
      log_error "Unknown allocation status: $status"
      return 1
      ;;
  esac
}

# Function: release_resource_allocation
release_resource_allocation() {
  local allocation_id="$1"
  local reason="${2:-completed}"

  local release_request="{
    \"allocation_id\": \"$allocation_id\",
    \"release_reason\": \"$reason\",
    \"cleanup_required\": true,
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  send_coordination_request "resource-manager" "release" "$release_request"
}
```

### 4. State Synchronization Pattern

Use for maintaining consistent state across components.

#### Template Implementation

```bash
# Function: sync_workflow_state
sync_workflow_state() {
  local workflow_id="$1"
  local local_state="$2"
  local force_update="${3:-false}"

  # Get current state version from coordination hub
  local hub_state=$(send_coordination_request "coordination-hub" "get-state" "{\"workflow_id\": \"$workflow_id\"}")
  local hub_version=$(echo "$hub_state" | jq -r '.result.workflow_state.state_version // 0')
  local local_version=$(echo "$local_state" | jq -r '.state_version // 0')

  # Check for version conflicts
  if [ "$local_version" -gt "$hub_version" ]; then
    # Local state is newer - push update
    sync_push_state "$workflow_id" "$local_state"
  elif [ "$local_version" -lt "$hub_version" ] || [ "$force_update" = "true" ]; then
    # Hub state is newer - pull update
    sync_pull_state "$workflow_id"
  else
    # States are synchronized
    log_debug "State already synchronized for workflow $workflow_id"
  fi
}

# Function: sync_push_state
sync_push_state() {
  local workflow_id="$1"
  local state="$2"

  local state_update="{
    \"workflow_state\": {
      \"message_type\": \"state_sync\",
      \"workflow_id\": \"$workflow_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"state_version\": $(echo "$state" | jq '.state_version + 1'),
      \"source_component\": \"$(get_component_id)\",
      \"state_data\": $state,
      \"validation_required\": [\"state_integrity\", \"dependency_consistency\"],
      \"metadata\": {
        \"last_update_source\": \"$(get_component_id)\",
        \"synchronization_confidence\": 0.95
      }
    }
  }"

  send_coordination_request "coordination-hub" "update-state" "$state_update"
}

# Function: sync_pull_state
sync_pull_state() {
  local workflow_id="$1"

  local state_request="{
    \"workflow_id\": \"$workflow_id\",
    \"include_history\": false,
    \"validate_integrity\": true
  }"

  local response=$(send_coordination_request "coordination-hub" "get-state" "$state_request")
  local new_state=$(echo "$response" | jq '.result.workflow_state')

  # Update local state
  update_local_state "$workflow_id" "$new_state"

  log_info "Synchronized state for workflow $workflow_id"
}
```

## Error Reporting and Recovery Patterns

### 1. Standardized Error Reporting

#### Template Implementation

```bash
# Function: report_coordination_error
report_coordination_error() {
  local error_category="$1"
  local error_type="$2"
  local error_message="$3"
  local context="$4"
  local severity="${5:-medium}"

  local error_report="{
    \"error_report\": {
      \"error_id\": \"err_$(uuidgen)\",
      \"workflow_id\": \"$(get_current_workflow_id)\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"classification\": {
        \"category\": \"$error_category\",
        \"severity\": \"$severity\",
        \"type\": \"$error_type\",
        \"scope\": \"$(get_component_scope)\",
        \"recoverable\": $(determine_recoverability "$error_type")
      },
      \"context\": {
        \"component\": \"$(get_component_id)\",
        \"operation\": \"$(get_current_operation)\",
        \"phase\": \"$(get_current_phase)\",
        \"additional_context\": $context
      },
      \"details\": {
        \"error_message\": \"$error_message\",
        \"technical_details\": \"$(get_technical_details)\",
        \"related_events\": $(get_related_events)
      },
      \"impact_assessment\": $(assess_error_impact "$error_type"),
      \"recovery_suggestions\": $(generate_recovery_suggestions "$error_category" "$error_type")
    }
  }"

  # Publish error event
  publish_workflow_event "ERROR_ENCOUNTERED" "$(get_current_workflow_id)" "$(get_current_phase)" "$error_report"

  # Send to coordination hub for centralized error handling
  send_coordination_request "coordination-hub" "handle-error" "$error_report"
}

# Function: handle_error_recovery
handle_error_recovery() {
  local error_report="$1"
  local recovery_strategy="$2"

  local error_id=$(echo "$error_report" | jq -r '.error_report.error_id')
  local error_type=$(echo "$error_report" | jq -r '.error_report.classification.type')

  log_info "Initiating error recovery for $error_id using strategy: $recovery_strategy"

  case "$recovery_strategy" in
    "retry_operation")
      retry_failed_operation "$error_report"
      ;;
    "agent_reallocation")
      reallocate_failed_agent "$error_report"
      ;;
    "checkpoint_rollback")
      rollback_to_checkpoint "$error_report"
      ;;
    "graceful_degradation")
      enable_graceful_degradation "$error_report"
      ;;
    *)
      log_error "Unknown recovery strategy: $recovery_strategy"
      return 1
      ;;
  esac
}
```

### 2. Recovery Coordination

#### Template Implementation

```bash
# Function: coordinate_recovery_operation
coordinate_recovery_operation() {
  local workflow_id="$1"
  local recovery_type="$2"
  local recovery_parameters="$3"

  # Create recovery coordination request
  local recovery_request="{
    \"recovery_operation\": {
      \"recovery_id\": \"rec_$(uuidgen)\",
      \"workflow_id\": \"$workflow_id\",
      \"recovery_type\": \"$recovery_type\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"coordinator\": \"$(get_component_id)\",
      \"parameters\": $recovery_parameters,
      \"affected_components\": $(identify_affected_components "$workflow_id"),
      \"coordination_required\": true
    }
  }"

  # Notify all affected components
  publish_workflow_event "RECOVERY_INITIATED" "$workflow_id" "$(get_current_phase)" "$recovery_request"

  # Execute recovery operation
  execute_recovery_operation "$recovery_type" "$recovery_parameters"

  # Validate recovery success
  if validate_recovery_success "$workflow_id"; then
    publish_workflow_event "RECOVERY_COMPLETED" "$workflow_id" "$(get_current_phase)" "{\"recovery_id\": \"$(echo "$recovery_request" | jq -r '.recovery_operation.recovery_id')\"}"
  else
    publish_workflow_event "RECOVERY_FAILED" "$workflow_id" "$(get_current_phase)" "{\"recovery_id\": \"$(echo "$recovery_request" | jq -r '.recovery_operation.recovery_id')\"}"
  fi
}
```

## Performance Monitoring Integration

### Template Implementation

```bash
# Function: report_performance_metrics
report_performance_metrics() {
  local workflow_id="$1"
  local metrics="$2"
  local component="${3:-$(get_component_id)}"

  local performance_report="{
    \"performance_metrics\": {
      \"report_id\": \"perf_$(uuidgen)\",
      \"workflow_id\": \"$workflow_id\",
      \"component\": \"$component\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"metrics\": $metrics,
      \"collection_period\": \"$(get_collection_period)\",
      \"baseline_comparison\": $(get_baseline_comparison "$workflow_id" "$metrics")
    }
  }"

  # Send to performance monitor
  send_coordination_request "performance-monitor" "record-metrics" "$performance_report"
}

# Function: request_performance_analysis
request_performance_analysis() {
  local workflow_id="$1"
  local analysis_type="$2"
  local parameters="${3:-{}}"

  local analysis_request="{
    \"analysis_type\": \"$analysis_type\",
    \"workflow_id\": \"$workflow_id\",
    \"requester\": \"$(get_component_id)\",
    \"parameters\": $parameters,
    \"priority\": \"medium\"
  }"

  send_coordination_request "performance-monitor" "analyze" "$analysis_request"
}
```

## Component Lifecycle Management

### Template Implementation

```bash
# Function: register_component
register_component() {
  local component_id="$1"
  local component_type="$2"
  local capabilities="$3"

  local registration="{
    \"component_registration\": {
      \"component_id\": \"$component_id\",
      \"component_type\": \"$component_type\",
      \"version\": \"$(get_component_version)\",
      \"capabilities\": $capabilities,
      \"dependencies\": $(get_component_dependencies),
      \"event_subscriptions\": $(get_event_subscriptions),
      \"event_publications\": $(get_event_publications),
      \"health_check_endpoint\": \"/health\",
      \"performance_metrics\": $(get_performance_metrics),
      \"startup_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }
  }"

  send_coordination_request "coordination-hub" "register-component" "$registration"
}

# Function: report_health_status
report_health_status() {
  local component_id="$1"

  local health_status="{
    \"health_status\": {
      \"component_id\": \"$component_id\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"status\": \"$(get_component_health_status)\",
      \"uptime\": \"$(get_component_uptime)\",
      \"last_activity\": \"$(get_last_activity_time)\",
      \"performance_metrics\": $(get_current_performance_metrics),
      \"active_operations\": $(get_active_operations_count),
      \"queue_size\": $(get_queue_size),
      \"dependencies\": $(check_dependency_health)
    }
  }"

  send_coordination_request "coordination-hub" "report-health" "$health_status"
}
```

## Utility Functions

### Message Validation

```bash
# Function: validate_coordination_message
validate_coordination_message() {
  local message="$1"
  local expected_schema="$2"

  # Validate JSON structure
  if ! echo "$message" | jq empty 2>/dev/null; then
    log_error "Invalid JSON format in coordination message"
    return 1
  fi

  # Validate required fields
  local required_fields=("message_type" "timestamp")
  for field in "${required_fields[@]}"; do
    if ! echo "$message" | jq -e ".$field" >/dev/null 2>&1; then
      log_error "Missing required field: $field"
      return 1
    fi
  done

  # Validate against schema if provided
  if [ -n "$expected_schema" ]; then
    if ! validate_against_schema "$message" "$expected_schema"; then
      log_error "Message does not conform to expected schema"
      return 1
    fi
  fi

  return 0
}
```

### Event Type Validation

```bash
# Function: validate_event_type
validate_event_type() {
  local event_type="$1"

  local valid_events=(
    "WORKFLOW_CREATED" "WORKFLOW_STARTED" "WORKFLOW_PAUSED" "WORKFLOW_RESUMED"
    "WORKFLOW_COMPLETED" "WORKFLOW_FAILED" "WORKFLOW_CANCELLED"
    "PHASE_STARTED" "PHASE_COMPLETED" "PHASE_FAILED" "PHASE_SKIPPED" "PHASE_PROGRESS"
    "TASK_ASSIGNED" "TASK_STARTED" "TASK_COMPLETED" "TASK_FAILED" "TASK_TIMEOUT" "TASK_REASSIGNED"
    "AGENT_ALLOCATED" "AGENT_DEALLOCATED" "AGENT_PERFORMANCE_ALERT" "AGENT_ERROR" "AGENT_TIMEOUT"
    "RESOURCE_ALLOCATED" "RESOURCE_DEALLOCATED" "RESOURCE_CONFLICT" "RESOURCE_THRESHOLD" "RESOURCE_OPTIMIZED"
    "SYSTEM_STARTUP" "SYSTEM_SHUTDOWN" "SYSTEM_THRESHOLD" "SYSTEM_ERROR" "SYSTEM_MAINTENANCE"
    "ERROR_ENCOUNTERED" "RECOVERY_INITIATED" "RECOVERY_COMPLETED" "RECOVERY_FAILED"
  )

  for valid_event in "${valid_events[@]}"; do
    if [ "$event_type" = "$valid_event" ]; then
      return 0
    fi
  done

  log_error "Invalid event type: $event_type"
  return 1
}
```

### Configuration Management

```bash
# Function: load_coordination_config
load_coordination_config() {
  local component_id="$1"

  local config_file="${COORDINATION_CONFIG_DIR:-/home/benjamin/.dotfiles/.claude/config}/${component_id}.json"

  if [ -f "$config_file" ]; then
    cat "$config_file"
  else
    # Return default configuration
    echo "{
      \"coordination\": {
        \"hub_endpoint\": \"coordination-hub\",
        \"heartbeat_interval\": \"30s\",
        \"event_queue_size\": 1000,
        \"max_retry_attempts\": 3,
        \"timeout_default\": \"30s\"
      },
      \"performance\": {
        \"max_concurrent_operations\": 50,
        \"cache_size_mb\": 128,
        \"optimization_interval\": \"5m\"
      },
      \"monitoring\": {
        \"metrics_collection\": true,
        \"performance_tracking\": true,
        \"health_check_interval\": \"60s\"
      }
    }"
  fi
}
```

## Implementation Checklist

When implementing coordination protocols in a helper command:

### ✅ Required Implementations

- [ ] **Event Publishing**: Implement standardized event publishing using `publish_workflow_event`
- [ ] **Event Subscription**: Subscribe to relevant events using `subscribe_to_events`
- [ ] **Request-Response**: Implement request-response pattern for synchronous operations
- [ ] **Error Reporting**: Use standardized error reporting with `report_coordination_error`
- [ ] **Health Monitoring**: Implement health status reporting with `report_health_status`
- [ ] **Message Validation**: Validate all incoming messages using `validate_coordination_message`
- [ ] **Component Registration**: Register component capabilities and dependencies
- [ ] **State Synchronization**: Implement state sync for stateful components
- [ ] **Performance Metrics**: Report performance metrics to monitoring system
- [ ] **Configuration Loading**: Load coordination configuration from standard location

### ✅ Testing Requirements

- [ ] **Unit Tests**: Test individual coordination functions
- [ ] **Integration Tests**: Test cross-component communication
- [ ] **Error Scenarios**: Test error handling and recovery
- [ ] **Performance Tests**: Validate performance requirements
- [ ] **Protocol Compliance**: Verify protocol format compliance

### ✅ Documentation

- [ ] **API Documentation**: Document coordination interfaces
- [ ] **Event Schemas**: Document published and subscribed events
- [ ] **Error Conditions**: Document error scenarios and recovery
- [ ] **Performance Characteristics**: Document performance expectations
- [ ] **Configuration Options**: Document configuration parameters

---

This integration framework ensures consistent and reliable coordination across all helper commands while maintaining the flexibility needed for diverse command functionalities.