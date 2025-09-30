# Standard Error Handling and Recovery

## Purpose
Standardized error classification, handling, and recovery patterns for consistent error management across all commands.

## Usage
```markdown
{{module:shared/error-handling/standard-recovery.md}}
```

## Error Classification System

### 1. Error Categories

```bash
# Standard error categories
ERROR_CATEGORIES=(
  "RECOVERABLE"      # Can be automatically recovered
  "RETRYABLE"        # Can be retried with backoff
  "USER_ACTION"      # Requires user intervention
  "CRITICAL"         # System-critical errors
  "CONFIGURATION"    # Configuration errors
  "DEPENDENCY"       # Dependency unavailable
  "TIMEOUT"          # Operation timeout
  "RESOURCE"         # Resource exhaustion
)

# Error severity levels
ERROR_SEVERITIES=(
  "LOW"              # Minor issues, degraded performance
  "MEDIUM"           # Moderate impact, some functionality affected
  "HIGH"             # Major impact, significant functionality lost
  "CRITICAL"         # System failure, immediate attention required
)
```

### 2. Error Classification Function

```bash
# Classify errors for appropriate handling
classify_error() {
  local error_message="$1"
  local error_code="$2"
  local context="$3"

  local category="UNKNOWN"
  local severity="MEDIUM"
  local recovery_strategy="manual"

  # Analyze error patterns
  case "$error_code" in
    124)  # Timeout
      category="TIMEOUT"
      severity="MEDIUM"
      recovery_strategy="retry_with_backoff"
      ;;
    127)  # Command not found
      category="DEPENDENCY"
      severity="HIGH"
      recovery_strategy="check_dependencies"
      ;;
    130)  # Process interrupted
      category="USER_ACTION"
      severity="LOW"
      recovery_strategy="graceful_shutdown"
      ;;
    137)  # Process killed
      category="RESOURCE"
      severity="HIGH"
      recovery_strategy="resource_cleanup"
      ;;
    *)
      # Analyze error message patterns
      category=$(analyze_error_message "$error_message")
      severity=$(determine_error_severity "$error_message" "$context")
      recovery_strategy=$(determine_recovery_strategy "$category" "$severity")
      ;;
  esac

  local classification="{
    \"category\": \"$category\",
    \"severity\": \"$severity\",
    \"recovery_strategy\": \"$recovery_strategy\",
    \"error_code\": $error_code,
    \"message\": \"$error_message\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"context\": \"$context\"
  }"

  echo "$classification"
}

# Analyze error message for classification
analyze_error_message() {
  local message="$1"

  case "$message" in
    *"connection refused"*|*"connection timeout"*)
      echo "DEPENDENCY"
      ;;
    *"permission denied"*|*"access denied"*)
      echo "CONFIGURATION"
      ;;
    *"no space left"*|*"out of memory"*)
      echo "RESOURCE"
      ;;
    *"file not found"*|*"directory not found"*)
      echo "CONFIGURATION"
      ;;
    *"syntax error"*|*"invalid"*)
      echo "USER_ACTION"
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}
```

## Recovery Strategies

### 1. Automatic Recovery

```bash
# Attempt automatic error recovery
attempt_automatic_recovery() {
  local error_classification="$1"
  local operation_context="$2"

  local category=$(echo "$error_classification" | jq -r '.category')
  local severity=$(echo "$error_classification" | jq -r '.severity')
  local recovery_strategy=$(echo "$error_classification" | jq -r '.recovery_strategy')

  case "$recovery_strategy" in
    "retry_with_backoff")
      retry_with_exponential_backoff "$operation_context"
      ;;
    "resource_cleanup")
      perform_resource_cleanup "$operation_context"
      ;;
    "check_dependencies")
      verify_and_restore_dependencies "$operation_context"
      ;;
    "graceful_shutdown")
      perform_graceful_shutdown "$operation_context"
      ;;
    "state_recovery")
      recover_operation_state "$operation_context"
      ;;
    *)
      log_warning "No automatic recovery available for strategy: $recovery_strategy"
      return 1
      ;;
  esac
}

# Retry with exponential backoff
retry_with_exponential_backoff() {
  local operation_context="$1"
  local max_attempts="${2:-3}"
  local base_delay="${3:-1}"

  local attempt=1
  local delay=$base_delay

  while [ $attempt -le $max_attempts ]; do
    log_info "Retry attempt $attempt of $max_attempts"

    if execute_operation_from_context "$operation_context"; then
      log_info "Operation succeeded on retry attempt $attempt"
      return 0
    fi

    if [ $attempt -lt $max_attempts ]; then
      log_info "Waiting $delay seconds before retry..."
      sleep $delay
      delay=$((delay * 2))
    fi

    attempt=$((attempt + 1))
  done

  log_error "All retry attempts failed"
  return 1
}
```

### 2. Resource Recovery

```bash
# Perform resource cleanup and recovery
perform_resource_cleanup() {
  local operation_context="$1"

  log_info "Performing resource cleanup"

  # Extract resource information from context
  local resource_info=$(extract_resource_info "$operation_context")
  local cleanup_tasks=$(generate_cleanup_tasks "$resource_info")

  # Execute cleanup tasks
  while IFS= read -r cleanup_task; do
    execute_cleanup_task "$cleanup_task"
  done < <(echo "$cleanup_tasks" | jq -c '.[]')

  # Verify cleanup success
  if verify_cleanup_success "$resource_info"; then
    log_info "Resource cleanup completed successfully"
    return 0
  else
    log_error "Resource cleanup failed"
    return 1
  fi
}

# Generate cleanup tasks based on resource type
generate_cleanup_tasks() {
  local resource_info="$1"

  local cleanup_tasks="[]"

  # Process each resource type
  while IFS= read -r resource; do
    local resource_type=$(echo "$resource" | jq -r '.type')
    local resource_id=$(echo "$resource" | jq -r '.id')

    case "$resource_type" in
      "process")
        cleanup_tasks=$(echo "$cleanup_tasks" | jq ". += [{\"type\": \"kill_process\", \"pid\": \"$resource_id\"}]")
        ;;
      "file")
        cleanup_tasks=$(echo "$cleanup_tasks" | jq ". += [{\"type\": \"remove_file\", \"path\": \"$resource_id\"}]")
        ;;
      "network")
        cleanup_tasks=$(echo "$cleanup_tasks" | jq ". += [{\"type\": \"close_connection\", \"connection_id\": \"$resource_id\"}]")
        ;;
      "memory")
        cleanup_tasks=$(echo "$cleanup_tasks" | jq ". += [{\"type\": \"free_memory\", \"allocation_id\": \"$resource_id\"}]")
        ;;
    esac
  done < <(echo "$resource_info" | jq -c '.resources[]?')

  echo "$cleanup_tasks"
}
```

### 3. State Recovery

```bash
# Recover operation state from checkpoints
recover_operation_state() {
  local operation_context="$1"

  local operation_id=$(echo "$operation_context" | jq -r '.operation_id')
  local checkpoint_dir=$(echo "$operation_context" | jq -r '.checkpoint_dir // "/tmp/checkpoints"')

  # Find latest checkpoint
  local latest_checkpoint=$(find_latest_checkpoint "$operation_id" "$checkpoint_dir")

  if [[ -n "$latest_checkpoint" ]]; then
    log_info "Recovering from checkpoint: $latest_checkpoint"

    # Restore state from checkpoint
    if restore_from_checkpoint "$latest_checkpoint" "$operation_context"; then
      log_info "State recovery successful"
      return 0
    else
      log_error "State recovery failed"
      return 1
    fi
  else
    log_warning "No checkpoint found for operation: $operation_id"
    return 1
  fi
}

# Find the latest checkpoint for an operation
find_latest_checkpoint() {
  local operation_id="$1"
  local checkpoint_dir="$2"

  if [[ -d "$checkpoint_dir" ]]; then
    find "$checkpoint_dir" -name "${operation_id}_*.checkpoint" -type f -exec ls -t {} + | head -1
  fi
}

# Restore operation state from checkpoint
restore_from_checkpoint() {
  local checkpoint_file="$1"
  local operation_context="$2"

  if [[ -f "$checkpoint_file" ]]; then
    # Load checkpoint data
    local checkpoint_data=$(cat "$checkpoint_file")

    # Validate checkpoint integrity
    if validate_checkpoint_integrity "$checkpoint_data"; then
      # Restore operation state
      restore_operation_state_from_data "$checkpoint_data" "$operation_context"
    else
      log_error "Checkpoint integrity validation failed: $checkpoint_file"
      return 1
    fi
  else
    log_error "Checkpoint file not found: $checkpoint_file"
    return 1
  fi
}
```

## Error Reporting and Escalation

### 1. Error Reporting

```bash
# Report errors with appropriate detail level
report_error() {
  local error_classification="$1"
  local operation_context="$2"
  local recovery_attempts="$3"

  local error_report="{
    \"error_classification\": $error_classification,
    \"operation_context\": $operation_context,
    \"recovery_attempts\": $recovery_attempts,
    \"reported_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"reporter\": \"$(basename "$0")\",
    \"environment\": $(gather_environment_info)
  }"

  # Log error locally
  log_error_report "$error_report"

  # Report to coordination system if available
  if command_exists "coordination-hub"; then
    report_to_coordination_hub "$error_report"
  fi

  # Escalate if necessary
  local severity=$(echo "$error_classification" | jq -r '.severity')
  if [[ "$severity" == "CRITICAL" ]]; then
    escalate_error "$error_report"
  fi
}

# Gather environment information for error reports
gather_environment_info() {
  local env_info="{
    \"hostname\": \"$(hostname)\",
    \"os\": \"$(uname -s)\",
    \"kernel\": \"$(uname -r)\",
    \"load_average\": \"$(uptime | awk '{print $NF}')\",
    \"disk_usage\": \"$(df -h . | tail -1 | awk '{print $5}')\",
    \"memory_usage\": \"$(free | grep Mem | awk '{printf \"%.1f%%\", $3/$2 * 100.0}')\",
    \"working_directory\": \"$(pwd)\"
  }"

  echo "$env_info"
}
```

### 2. Error Escalation

```bash
# Escalate critical errors
escalate_error() {
  local error_report="$1"

  local escalation_level=$(determine_escalation_level "$error_report")
  local escalation_targets=$(get_escalation_targets "$escalation_level")

  # Send escalation notifications
  while IFS= read -r target; do
    send_escalation_notification "$target" "$error_report"
  done < <(echo "$escalation_targets" | jq -c '.[]')

  # Log escalation
  log_info "Error escalated to level: $escalation_level"
}

# Determine appropriate escalation level
determine_escalation_level() {
  local error_report="$1"

  local severity=$(echo "$error_report" | jq -r '.error_classification.severity')
  local category=$(echo "$error_report" | jq -r '.error_classification.category')
  local recovery_attempts=$(echo "$error_report" | jq -r '.recovery_attempts | length')

  if [[ "$severity" == "CRITICAL" ]]; then
    echo "IMMEDIATE"
  elif [[ "$severity" == "HIGH" && "$recovery_attempts" -gt 2 ]]; then
    echo "URGENT"
  elif [[ "$category" == "RESOURCE" && "$severity" == "HIGH" ]]; then
    echo "URGENT"
  else
    echo "STANDARD"
  fi
}
```

## Logging and Monitoring

### 1. Error Logging

```bash
# Log error with structured format
log_error_structured() {
  local level="$1"
  local message="$2"
  local context="$3"

  local log_entry="{
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"level\": \"$level\",
    \"message\": \"$message\",
    \"context\": $context,
    \"source\": \"$(basename "$0")\",
    \"pid\": $$
  }"

  # Output to stderr for errors and warnings
  if [[ "$level" == "ERROR" || "$level" == "WARNING" ]]; then
    echo "$log_entry" >&2
  else
    echo "$log_entry"
  fi

  # Also log to file if log file is configured
  if [[ -n "${ERROR_LOG_FILE:-}" ]]; then
    echo "$log_entry" >> "$ERROR_LOG_FILE"
  fi
}
```

### 2. Error Monitoring

```bash
# Monitor error patterns and trends
monitor_error_patterns() {
  local monitoring_period="${1:-1h}"
  local error_threshold="${2:-10}"

  # Collect error data for the period
  local error_data=$(collect_error_data "$monitoring_period")
  local error_patterns=$(analyze_error_patterns "$error_data")

  # Check for concerning patterns
  local high_frequency_errors=$(identify_high_frequency_errors "$error_patterns" "$error_threshold")

  if [[ -n "$high_frequency_errors" ]]; then
    # Generate alert for high error frequency
    generate_error_frequency_alert "$high_frequency_errors"
  fi

  # Check for new error types
  local new_error_types=$(identify_new_error_types "$error_patterns")

  if [[ -n "$new_error_types" ]]; then
    generate_new_error_alert "$new_error_types"
  fi
}
```

## Utility Functions

```bash
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Validate checkpoint integrity
validate_checkpoint_integrity() {
  local checkpoint_data="$1"

  # Basic JSON validation
  if ! echo "$checkpoint_data" | jq . >/dev/null 2>&1; then
    return 1
  fi

  # Check required fields
  local required_fields=("operation_id" "timestamp" "state")
  for field in "${required_fields[@]}"; do
    if ! echo "$checkpoint_data" | jq -e ".$field" >/dev/null 2>&1; then
      log_error "Missing required field in checkpoint: $field"
      return 1
    fi
  done

  return 0
}

# Execute cleanup task
execute_cleanup_task() {
  local cleanup_task="$1"

  local task_type=$(echo "$cleanup_task" | jq -r '.type')

  case "$task_type" in
    "kill_process")
      local pid=$(echo "$cleanup_task" | jq -r '.pid')
      if kill "$pid" 2>/dev/null; then
        log_info "Process $pid terminated"
      fi
      ;;
    "remove_file")
      local file_path=$(echo "$cleanup_task" | jq -r '.path')
      if rm -f "$file_path" 2>/dev/null; then
        log_info "File removed: $file_path"
      fi
      ;;
    *)
      log_warning "Unknown cleanup task type: $task_type"
      ;;
  esac
}
```