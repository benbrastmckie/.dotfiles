# Checkpoint-Based Recovery System

## Purpose
Comprehensive checkpoint creation, validation, and restoration system for reliable workflow recovery.

## Usage
```markdown
{{module:orchestration/recovery/checkpoint-system.md}}
```

## Checkpoint Management

### 1. Automatic Checkpoint Creation

```bash
# Create automatic checkpoint with comprehensive state capture
create_automatic_checkpoint() {
  local workflow_id="$1"
  local phase="$2"
  local checkpoint_type="${3:-automatic}"

  log_info "Creating automatic checkpoint for workflow: $workflow_id, phase: $phase"

  # Generate checkpoint metadata
  local checkpoint_id="checkpoint_$(date +%s)_${workflow_id}_${phase}"
  local checkpoint_metadata="{
    \"checkpoint_id\": \"$checkpoint_id\",
    \"workflow_id\": \"$workflow_id\",
    \"phase\": \"$phase\",
    \"type\": \"$checkpoint_type\",
    \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"created_by\": \"$(basename "$0")\"
  }"

  # Capture comprehensive workflow state
  local workflow_state=$(capture_comprehensive_workflow_state "$workflow_id")
  local file_state=$(capture_file_system_state "$workflow_id")
  local resource_state=$(capture_resource_state "$workflow_id")
  local dependency_state=$(capture_dependency_state "$workflow_id")

  # Create checkpoint package
  local checkpoint_data="{
    \"metadata\": $checkpoint_metadata,
    \"workflow_state\": $workflow_state,
    \"file_state\": $file_state,
    \"resource_state\": $resource_state,
    \"dependency_state\": $dependency_state,
    \"integrity_hash\": \"$(calculate_checkpoint_hash "$workflow_state" "$file_state" "$resource_state")\"
  }"

  # Store checkpoint
  if store_checkpoint "$checkpoint_id" "$checkpoint_data"; then
    log_info "Checkpoint created successfully: $checkpoint_id"

    # Register checkpoint
    register_checkpoint "$workflow_id" "$checkpoint_id" "$checkpoint_metadata"

    # Cleanup old checkpoints if necessary
    cleanup_old_checkpoints "$workflow_id"

    echo "$checkpoint_id"
  else
    log_error "Failed to create checkpoint for workflow: $workflow_id"
    return 1
  fi
}

# Create manual checkpoint with custom parameters
create_manual_checkpoint() {
  local workflow_id="$1"
  local checkpoint_name="$2"
  local checkpoint_options="$3"

  log_info "Creating manual checkpoint: $checkpoint_name for workflow: $workflow_id"

  # Parse checkpoint options
  local include_files=$(echo "$checkpoint_options" | jq -r '.include_files // true')
  local include_resources=$(echo "$checkpoint_options" | jq -r '.include_resources // true')
  local compression_enabled=$(echo "$checkpoint_options" | jq -r '.compression // true')
  local verification_level=$(echo "$checkpoint_options" | jq -r '.verification_level // "standard"')

  # Create enhanced checkpoint with custom options
  local checkpoint_id="manual_$(date +%s)_${workflow_id}"
  create_enhanced_checkpoint "$checkpoint_id" "$workflow_id" "$checkpoint_name" "{
    \"include_files\": $include_files,
    \"include_resources\": $include_resources,
    \"compression\": $compression_enabled,
    \"verification_level\": \"$verification_level\"
  }"
}
```

### 2. Enhanced Checkpoint Storage

```bash
# Store checkpoint with compression and integrity verification
store_checkpoint() {
  local checkpoint_id="$1"
  local checkpoint_data="$2"

  local checkpoint_dir="/tmp/checkpoints"
  local checkpoint_file="${checkpoint_dir}/${checkpoint_id}.checkpoint"

  # Ensure checkpoint directory exists
  mkdir -p "$checkpoint_dir"

  # Compress checkpoint data if large
  local data_size=$(echo "$checkpoint_data" | wc -c)
  if [ $data_size -gt 1048576 ]; then  # 1MB threshold
    log_info "Compressing large checkpoint: $checkpoint_id"
    checkpoint_data=$(echo "$checkpoint_data" | gzip -c | base64 -w 0)
    local compressed_flag=true
  else
    local compressed_flag=false
  fi

  # Create checkpoint file with metadata
  local checkpoint_package="{
    \"checkpoint_data\": \"$checkpoint_data\",
    \"compressed\": $compressed_flag,
    \"stored_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"storage_location\": \"$checkpoint_file\",
    \"size_bytes\": $data_size
  }"

  # Write checkpoint to file
  if echo "$checkpoint_package" > "$checkpoint_file"; then
    # Verify checkpoint integrity
    verify_checkpoint_integrity "$checkpoint_file"
  else
    log_error "Failed to write checkpoint file: $checkpoint_file"
    return 1
  fi
}

# Load checkpoint with integrity verification
load_checkpoint() {
  local checkpoint_id="$1"

  local checkpoint_dir="/tmp/checkpoints"
  local checkpoint_file="${checkpoint_dir}/${checkpoint_id}.checkpoint"

  if [[ ! -f "$checkpoint_file" ]]; then
    log_error "Checkpoint file not found: $checkpoint_file"
    return 1
  fi

  # Verify checkpoint integrity before loading
  if ! verify_checkpoint_integrity "$checkpoint_file"; then
    log_error "Checkpoint integrity verification failed: $checkpoint_id"
    return 1
  fi

  # Load checkpoint package
  local checkpoint_package=$(cat "$checkpoint_file")
  local checkpoint_data=$(echo "$checkpoint_package" | jq -r '.checkpoint_data')
  local is_compressed=$(echo "$checkpoint_package" | jq -r '.compressed')

  # Decompress if necessary
  if [[ "$is_compressed" == "true" ]]; then
    checkpoint_data=$(echo "$checkpoint_data" | base64 -d | gunzip)
  fi

  echo "$checkpoint_data"
}
```

### 3. Checkpoint Validation and Verification

```bash
# Comprehensive checkpoint validation
validate_checkpoint() {
  local checkpoint_id="$1"
  local validation_level="${2:-standard}"

  log_info "Validating checkpoint: $checkpoint_id with level: $validation_level"

  # Load checkpoint for validation
  local checkpoint_data=$(load_checkpoint "$checkpoint_id")
  if [[ -z "$checkpoint_data" ]]; then
    log_error "Failed to load checkpoint for validation: $checkpoint_id"
    return 1
  fi

  # Extract checkpoint components
  local metadata=$(echo "$checkpoint_data" | jq '.metadata')
  local workflow_state=$(echo "$checkpoint_data" | jq '.workflow_state')
  local file_state=$(echo "$checkpoint_data" | jq '.file_state')
  local resource_state=$(echo "$checkpoint_data" | jq '.resource_state')
  local integrity_hash=$(echo "$checkpoint_data" | jq -r '.integrity_hash')

  # Perform validation based on level
  case "$validation_level" in
    "basic")
      validate_checkpoint_basic "$metadata" "$workflow_state"
      ;;
    "standard")
      validate_checkpoint_standard "$metadata" "$workflow_state" "$file_state" "$integrity_hash"
      ;;
    "comprehensive")
      validate_checkpoint_comprehensive "$metadata" "$workflow_state" "$file_state" "$resource_state" "$integrity_hash"
      ;;
    *)
      log_error "Unknown validation level: $validation_level"
      return 1
      ;;
  esac
}

# Standard checkpoint validation
validate_checkpoint_standard() {
  local metadata="$1"
  local workflow_state="$2"
  local file_state="$3"
  local integrity_hash="$4"

  local validation_results="{"

  # Validate metadata structure
  if validate_checkpoint_metadata "$metadata"; then
    validation_results+='"metadata_valid": true,'
  else
    validation_results+='"metadata_valid": false,'
  fi

  # Validate workflow state consistency
  if validate_workflow_state_consistency "$workflow_state"; then
    validation_results+='"workflow_state_valid": true,'
  else
    validation_results+='"workflow_state_valid": false,'
  fi

  # Validate file state if present
  if [[ "$file_state" != "null" ]]; then
    if validate_file_state_consistency "$file_state"; then
      validation_results+='"file_state_valid": true,'
    else
      validation_results+='"file_state_valid": false,'
    fi
  else
    validation_results+='"file_state_valid": true,'
  fi

  # Validate integrity hash
  local calculated_hash=$(calculate_checkpoint_hash "$workflow_state" "$file_state" "null")
  if [[ "$calculated_hash" == "$integrity_hash" ]]; then
    validation_results+='"integrity_valid": true'
  else
    validation_results+='"integrity_valid": false'
  fi

  validation_results+="}"

  # Check overall validation status
  local validation_passed=$(echo "$validation_results" | jq '[.[] | select(. == false)] | length == 0')
  if [[ "$validation_passed" == "true" ]]; then
    log_info "Checkpoint validation passed"
    return 0
  else
    log_error "Checkpoint validation failed: $validation_results"
    return 1
  fi
}
```

## State Capture and Restoration

### 1. Comprehensive State Capture

```bash
# Capture comprehensive workflow state
capture_comprehensive_workflow_state() {
  local workflow_id="$1"

  log_debug "Capturing comprehensive state for workflow: $workflow_id"

  # Capture different state components
  local phase_state=$(capture_phase_state "$workflow_id")
  local task_state=$(capture_task_state "$workflow_id")
  local agent_state=$(capture_agent_state "$workflow_id")
  local progress_state=$(capture_progress_state "$workflow_id")
  local configuration_state=$(capture_configuration_state "$workflow_id")

  local comprehensive_state="{
    \"workflow_id\": \"$workflow_id\",
    \"captured_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"phase_state\": $phase_state,
    \"task_state\": $task_state,
    \"agent_state\": $agent_state,
    \"progress_state\": $progress_state,
    \"configuration_state\": $configuration_state
  }"

  echo "$comprehensive_state"
}

# Capture file system state
capture_file_system_state() {
  local workflow_id="$1"

  # Get workflow working directory
  local work_dir=$(get_workflow_working_directory "$workflow_id")

  if [[ -d "$work_dir" ]]; then
    # Capture file checksums and metadata
    local file_manifest=$(create_file_manifest "$work_dir")
    local directory_structure=$(capture_directory_structure "$work_dir")

    local file_state="{
      \"working_directory\": \"$work_dir\",
      \"captured_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"file_manifest\": $file_manifest,
      \"directory_structure\": $directory_structure
    }"
  else
    local file_state="{
      \"working_directory\": null,
      \"captured_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"error\": \"Working directory not found\"
    }"
  fi

  echo "$file_state"
}

# Create file manifest with checksums
create_file_manifest() {
  local directory="$1"

  local manifest="[]"

  # Find all files and calculate checksums
  while IFS= read -r -d '' file; do
    local relative_path=$(realpath --relative-to="$directory" "$file")
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local file_mtime=$(stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null)
    local file_checksum=$(md5sum "$file" | cut -d' ' -f1)

    local file_entry="{
      \"path\": \"$relative_path\",
      \"size\": $file_size,
      \"mtime\": $file_mtime,
      \"checksum\": \"$file_checksum\"
    }"

    manifest=$(echo "$manifest" | jq ". += [$file_entry]")
  done < <(find "$directory" -type f -print0)

  echo "$manifest"
}
```

### 2. State Restoration

```bash
# Restore workflow state from checkpoint
restore_workflow_state() {
  local checkpoint_id="$1"
  local workflow_id="$2"
  local restore_options="$3"

  log_info "Restoring workflow state from checkpoint: $checkpoint_id"

  # Load checkpoint data
  local checkpoint_data=$(load_checkpoint "$checkpoint_id")
  if [[ -z "$checkpoint_data" ]]; then
    log_error "Failed to load checkpoint for restoration: $checkpoint_id"
    return 1
  fi

  # Extract state components
  local workflow_state=$(echo "$checkpoint_data" | jq '.workflow_state')
  local file_state=$(echo "$checkpoint_data" | jq '.file_state')
  local resource_state=$(echo "$checkpoint_data" | jq '.resource_state')

  # Parse restore options
  local restore_files=$(echo "$restore_options" | jq -r '.restore_files // true')
  local restore_resources=$(echo "$restore_options" | jq -r '.restore_resources // true')
  local verify_restoration=$(echo "$restore_options" | jq -r '.verify // true')

  # Restore workflow state
  if ! restore_workflow_state_component "$workflow_id" "$workflow_state"; then
    log_error "Failed to restore workflow state"
    return 1
  fi

  # Restore file state if requested
  if [[ "$restore_files" == "true" && "$file_state" != "null" ]]; then
    if ! restore_file_state_component "$workflow_id" "$file_state"; then
      log_error "Failed to restore file state"
      return 1
    fi
  fi

  # Restore resource state if requested
  if [[ "$restore_resources" == "true" && "$resource_state" != "null" ]]; then
    if ! restore_resource_state_component "$workflow_id" "$resource_state"; then
      log_warning "Failed to restore resource state (continuing)"
    fi
  fi

  # Verify restoration if requested
  if [[ "$verify_restoration" == "true" ]]; then
    if verify_state_restoration "$workflow_id" "$checkpoint_data"; then
      log_info "State restoration verified successfully"
    else
      log_warning "State restoration verification failed"
    fi
  fi

  log_info "Workflow state restoration completed"
  return 0
}

# Restore workflow state component
restore_workflow_state_component() {
  local workflow_id="$1"
  local workflow_state="$2"

  # Restore phase state
  local phase_state=$(echo "$workflow_state" | jq '.phase_state')
  restore_phase_state "$workflow_id" "$phase_state"

  # Restore task state
  local task_state=$(echo "$workflow_state" | jq '.task_state')
  restore_task_state "$workflow_id" "$task_state"

  # Restore progress state
  local progress_state=$(echo "$workflow_state" | jq '.progress_state')
  restore_progress_state "$workflow_id" "$progress_state"

  # Restore configuration state
  local configuration_state=$(echo "$workflow_state" | jq '.configuration_state')
  restore_configuration_state "$workflow_id" "$configuration_state"

  return 0
}
```

## Checkpoint Lifecycle Management

### 1. Checkpoint Cleanup and Retention

```bash
# Cleanup old checkpoints based on retention policy
cleanup_old_checkpoints() {
  local workflow_id="$1"
  local retention_policy="${2:-default}"

  log_info "Cleaning up old checkpoints for workflow: $workflow_id"

  # Get retention parameters
  local retention_params=$(get_retention_parameters "$retention_policy")
  local max_checkpoints=$(echo "$retention_params" | jq -r '.max_checkpoints')
  local max_age_days=$(echo "$retention_params" | jq -r '.max_age_days')

  # Get list of checkpoints for workflow
  local checkpoints=$(list_workflow_checkpoints "$workflow_id")

  # Sort checkpoints by creation time (newest first)
  local sorted_checkpoints=$(echo "$checkpoints" | jq 'sort_by(.created_at) | reverse')

  # Apply retention rules
  local checkpoints_to_delete="[]"

  # Rule 1: Keep only max_checkpoints most recent
  if [[ "$max_checkpoints" != "null" ]]; then
    local excess_checkpoints=$(echo "$sorted_checkpoints" | jq ".[${max_checkpoints}:]")
    checkpoints_to_delete=$(echo "$checkpoints_to_delete $excess_checkpoints" | jq -s 'add')
  fi

  # Rule 2: Delete checkpoints older than max_age_days
  if [[ "$max_age_days" != "null" ]]; then
    local cutoff_date=$(date -d "${max_age_days} days ago" -u +%Y-%m-%dT%H:%M:%SZ)
    local old_checkpoints=$(echo "$sorted_checkpoints" | jq --arg cutoff "$cutoff_date" '[.[] | select(.created_at < $cutoff)]')
    checkpoints_to_delete=$(echo "$checkpoints_to_delete $old_checkpoints" | jq -s 'add | unique_by(.checkpoint_id)')
  fi

  # Delete identified checkpoints
  while IFS= read -r checkpoint; do
    local checkpoint_id=$(echo "$checkpoint" | jq -r '.checkpoint_id')
    delete_checkpoint "$checkpoint_id"
  done < <(echo "$checkpoints_to_delete" | jq -c '.[]')

  log_info "Checkpoint cleanup completed for workflow: $workflow_id"
}

# Delete checkpoint and associated files
delete_checkpoint() {
  local checkpoint_id="$1"

  log_debug "Deleting checkpoint: $checkpoint_id"

  local checkpoint_dir="/tmp/checkpoints"
  local checkpoint_file="${checkpoint_dir}/${checkpoint_id}.checkpoint"

  # Remove checkpoint file
  if [[ -f "$checkpoint_file" ]]; then
    rm -f "$checkpoint_file"
  fi

  # Remove checkpoint registration
  unregister_checkpoint "$checkpoint_id"

  log_debug "Checkpoint deleted: $checkpoint_id"
}
```

### 2. Checkpoint Integrity Monitoring

```bash
# Monitor checkpoint integrity over time
monitor_checkpoint_integrity() {
  local workflow_id="$1"
  local monitoring_interval="${2:-3600}"  # 1 hour default

  log_info "Starting checkpoint integrity monitoring for workflow: $workflow_id"

  while true; do
    # Get all checkpoints for workflow
    local checkpoints=$(list_workflow_checkpoints "$workflow_id")

    # Verify each checkpoint
    while IFS= read -r checkpoint; do
      local checkpoint_id=$(echo "$checkpoint" | jq -r '.checkpoint_id')

      if ! verify_checkpoint_integrity_file "$checkpoint_id"; then
        log_error "Checkpoint integrity violation detected: $checkpoint_id"
        handle_checkpoint_corruption "$checkpoint_id" "$workflow_id"
      fi
    done < <(echo "$checkpoints" | jq -c '.[]')

    sleep "$monitoring_interval"
  done
}

# Handle checkpoint corruption
handle_checkpoint_corruption() {
  local checkpoint_id="$1"
  local workflow_id="$2"

  log_critical "Handling checkpoint corruption: $checkpoint_id"

  # Mark checkpoint as corrupted
  mark_checkpoint_corrupted "$checkpoint_id"

  # Attempt recovery from backup if available
  local backup_checkpoint=$(find_backup_checkpoint "$checkpoint_id")
  if [[ -n "$backup_checkpoint" ]]; then
    log_info "Attempting recovery from backup checkpoint"
    restore_checkpoint_from_backup "$checkpoint_id" "$backup_checkpoint"
  else
    # Remove corrupted checkpoint
    log_warning "No backup available, removing corrupted checkpoint"
    delete_checkpoint "$checkpoint_id"
  fi

  # Notify administrators
  notify_checkpoint_corruption "$checkpoint_id" "$workflow_id"
}
```

## Utility Functions

```bash
# Calculate checkpoint hash for integrity verification
calculate_checkpoint_hash() {
  local workflow_state="$1"
  local file_state="$2"
  local resource_state="$3"

  local combined_data="${workflow_state}${file_state}${resource_state}"
  echo "$combined_data" | md5sum | cut -d' ' -f1
}

# Get retention parameters for policy
get_retention_parameters() {
  local policy="$1"

  case "$policy" in
    "minimal")
      echo '{"max_checkpoints": 3, "max_age_days": 7}'
      ;;
    "standard")
      echo '{"max_checkpoints": 10, "max_age_days": 30}'
      ;;
    "extended")
      echo '{"max_checkpoints": 50, "max_age_days": 90}'
      ;;
    *)
      echo '{"max_checkpoints": 10, "max_age_days": 30}'
      ;;
  esac
}

# List workflow checkpoints
list_workflow_checkpoints() {
  local workflow_id="$1"

  local checkpoint_dir="/tmp/checkpoints"
  local checkpoints="[]"

  if [[ -d "$checkpoint_dir" ]]; then
    # Find checkpoint files for this workflow
    while IFS= read -r -d '' checkpoint_file; do
      local checkpoint_data=$(cat "$checkpoint_file")
      local metadata=$(echo "$checkpoint_data" | jq '.checkpoint_data' | jq '.metadata')

      if [[ "$(echo "$metadata" | jq -r '.workflow_id')" == "$workflow_id" ]]; then
        checkpoints=$(echo "$checkpoints" | jq ". += [$metadata]")
      fi
    done < <(find "$checkpoint_dir" -name "*.checkpoint" -print0)
  fi

  echo "$checkpoints"
}
```