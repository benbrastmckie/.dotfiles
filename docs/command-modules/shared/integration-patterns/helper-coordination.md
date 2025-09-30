# Helper Command Coordination Pattern

## Purpose
Standard pattern for coordinating with helper commands, including request formatting, response handling, and error management.

## Usage
```markdown
{{module:shared/integration-patterns/helper-coordination.md}}
```

## Coordination Protocol

### 1. Command Execution Pattern

```bash
# Standard helper command execution
execute_helper_command() {
  local helper_command="$1"
  local operation="$2"
  local parameters="$3"
  local timeout="${4:-60}"

  # Validate helper command availability
  if ! validate_helper_command "$helper_command"; then
    log_error "Helper command '$helper_command' not available"
    return 1
  fi

  # Execute with timeout and error handling
  local result
  if ! result=$(timeout "$timeout" "/$helper_command" "$operation" "$parameters" 2>&1); then
    local exit_code=$?
    handle_helper_command_error "$helper_command" "$operation" "$exit_code" "$result"
    return $exit_code
  fi

  # Validate and return result
  validate_helper_response "$result" && echo "$result"
}
```

### 2. Request Formatting

```bash
# Format request for helper commands
format_helper_request() {
  local operation="$1"
  local data="$2"
  local metadata="${3:-{}}"

  local request="{
    \"operation\": \"$operation\",
    \"data\": $data,
    \"metadata\": $metadata,
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"request_id\": \"$(generate_request_id)\"
  }"

  echo "$request"
}
```

### 3. Response Validation

```bash
# Validate helper command responses
validate_helper_response() {
  local response="$1"

  # Check if response is valid JSON
  if ! echo "$response" | jq . >/dev/null 2>&1; then
    log_warning "Helper response is not valid JSON: $response"
    return 1
  fi

  # Check for error indicators
  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    local error=$(echo "$response" | jq -r '.error')
    log_error "Helper command returned error: $error"
    return 1
  fi

  return 0
}
```

### 4. Error Handling

```bash
# Handle helper command errors
handle_helper_command_error() {
  local helper_command="$1"
  local operation="$2"
  local exit_code="$3"
  local error_output="$4"

  case $exit_code in
    124)
      log_error "Helper command '$helper_command' timed out during operation '$operation'"
      ;;
    127)
      log_error "Helper command '$helper_command' not found"
      ;;
    *)
      log_error "Helper command '$helper_command' failed with exit code $exit_code: $error_output"
      ;;
  esac

  # Attempt recovery if appropriate
  attempt_helper_recovery "$helper_command" "$operation" "$exit_code"
}
```

## Common Helper Operations

### Coordination Hub Integration

```bash
# Coordinate with coordination-hub
coordinate_with_hub() {
  local operation="$1"
  local workflow_data="$2"

  local request=$(format_helper_request "$operation" "$workflow_data")
  execute_helper_command "coordination-hub" "$operation" "$request"
}

# Publish coordination event
publish_coordination_event() {
  local event_type="$1"
  local workflow_id="$2"
  local phase="$3"
  local event_data="$4"

  local event="{
    \"event_type\": \"$event_type\",
    \"workflow_id\": \"$workflow_id\",
    \"phase\": \"$phase\",
    \"data\": $event_data,
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  coordinate_with_hub "publish-event" "$event"
}
```

### Resource Manager Integration

```bash
# Coordinate with resource-manager
coordinate_with_resource_manager() {
  local operation="$1"
  local resource_data="$2"

  local request=$(format_helper_request "$operation" "$resource_data")
  execute_helper_command "resource-manager" "$operation" "$request"
}

# Request resource allocation
request_resource_allocation() {
  local workflow_id="$1"
  local resource_requirements="$2"

  local allocation_request="{
    \"workflow_id\": \"$workflow_id\",
    \"requirements\": $resource_requirements,
    \"priority\": \"${WORKFLOW_PRIORITY:-medium}\",
    \"estimated_duration\": \"${ESTIMATED_DURATION:-1h}\"
  }"

  coordinate_with_resource_manager "allocate" "$allocation_request"
}
```

### Status and Monitoring

```bash
# Update workflow status
update_workflow_status() {
  local workflow_id="$1"
  local status="$2"
  local progress_data="$3"

  local status_update="{
    \"workflow_id\": \"$workflow_id\",
    \"status\": \"$status\",
    \"progress\": $progress_data,
    \"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  execute_helper_command "workflow-status" "update" "$status_update"
}

# Report performance metrics
report_performance_metrics() {
  local workflow_id="$1"
  local metrics="$2"

  local metrics_report="{
    \"workflow_id\": \"$workflow_id\",
    \"metrics\": $metrics,
    \"reported_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  execute_helper_command "performance-monitor" "report-metrics" "$metrics_report"
}
```

## Error Recovery Patterns

### Retry Logic

```bash
# Retry helper command with exponential backoff
retry_helper_command() {
  local helper_command="$1"
  local operation="$2"
  local parameters="$3"
  local max_attempts="${4:-3}"
  local base_delay="${5:-1}"

  local attempt=1
  local delay=$base_delay

  while [ $attempt -le $max_attempts ]; do
    if execute_helper_command "$helper_command" "$operation" "$parameters"; then
      return 0
    fi

    if [ $attempt -lt $max_attempts ]; then
      log_info "Retry attempt $attempt failed, waiting $delay seconds..."
      sleep $delay
      delay=$((delay * 2))
    fi

    attempt=$((attempt + 1))
  done

  log_error "All retry attempts failed for $helper_command $operation"
  return 1
}
```

### Graceful Degradation

```bash
# Attempt graceful degradation when helper fails
attempt_graceful_degradation() {
  local helper_command="$1"
  local operation="$2"
  local parameters="$3"

  case "$helper_command" in
    "coordination-hub")
      # Use local state tracking
      log_warning "Using local state tracking due to coordination-hub failure"
      track_state_locally "$operation" "$parameters"
      ;;
    "resource-manager")
      # Use default resource allocation
      log_warning "Using default resource allocation due to resource-manager failure"
      use_default_allocation "$parameters"
      ;;
    "workflow-status")
      # Use local status tracking
      log_warning "Using local status tracking due to workflow-status failure"
      track_status_locally "$operation" "$parameters"
      ;;
  esac
}
```

## Best Practices

### Request Preparation
1. Always validate input parameters before making requests
2. Include timeout specifications for long-running operations
3. Add request IDs for tracking and debugging
4. Use consistent JSON formatting for structured data

### Response Handling
1. Validate all responses before processing
2. Check for error conditions in responses
3. Log all interactions for debugging purposes
4. Handle partial responses gracefully

### Error Management
1. Implement appropriate retry logic for transient failures
2. Provide meaningful error messages and context
3. Attempt graceful degradation when possible
4. Log all errors with sufficient detail for troubleshooting

### Performance Considerations
1. Use timeouts to prevent hanging operations
2. Cache responses when appropriate
3. Batch requests when possible
4. Monitor helper command performance and availability