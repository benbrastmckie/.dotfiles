# Event Publishing Protocol

## Purpose
Standardized event publishing and subscription protocols for workflow coordination and state synchronization across commands.

## Usage
```markdown
{{module:shared/coordination-protocols/event-publishing.md}}
```

## Event Schema Standards

### 1. Base Event Structure

```json
{
  "event_type": "string",
  "workflow_id": "string",
  "phase": "string",
  "timestamp": "ISO8601",
  "source_command": "string",
  "event_id": "uuid",
  "data": {},
  "metadata": {}
}
```

### 2. Standard Event Types

#### Workflow Events
- `workflow.created`: New workflow initiated
- `workflow.started`: Workflow execution began
- `workflow.paused`: Workflow temporarily halted
- `workflow.resumed`: Workflow execution resumed
- `workflow.completed`: Workflow finished successfully
- `workflow.failed`: Workflow terminated with errors
- `workflow.cancelled`: Workflow cancelled by user/system

#### Phase Events
- `phase.started`: Phase execution began
- `phase.progress`: Progress update within phase
- `phase.completed`: Phase finished successfully
- `phase.failed`: Phase terminated with errors
- `phase.skipped`: Phase skipped due to conditions

#### Resource Events
- `resource.requested`: Resource allocation requested
- `resource.allocated`: Resources allocated successfully
- `resource.released`: Resources freed/deallocated
- `resource.insufficient`: Insufficient resources available
- `resource.conflict`: Resource allocation conflict detected

#### Error Events
- `error.recoverable`: Recoverable error occurred
- `error.critical`: Critical error requiring intervention
- `error.resolved`: Error condition resolved
- `error.escalated`: Error escalated to higher level

## Event Publishing Functions

### 1. Core Publishing Function

```bash
# Publish standardized coordination event
publish_coordination_event() {
  local event_type="$1"
  local workflow_id="$2"
  local phase="$3"
  local event_data="$4"
  local metadata="${5:-{}}"

  local event_id=$(generate_uuid)
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local source_command=$(basename "$0")

  local event="{
    \"event_type\": \"$event_type\",
    \"workflow_id\": \"$workflow_id\",
    \"phase\": \"$phase\",
    \"timestamp\": \"$timestamp\",
    \"source_command\": \"$source_command\",
    \"event_id\": \"$event_id\",
    \"data\": $event_data,
    \"metadata\": $metadata
  }"

  # Publish to coordination hub
  send_coordination_request "coordination-hub" "publish-event" "$event"

  # Log event for debugging
  log_event "$event_type" "$workflow_id" "$event_id"
}
```

### 2. Specialized Publishing Functions

```bash
# Publish workflow lifecycle events
publish_workflow_event() {
  local event_type="$1"  # created, started, completed, failed, cancelled
  local workflow_id="$2"
  local workflow_data="$3"

  publish_coordination_event "workflow.$event_type" "$workflow_id" "workflow" "$workflow_data"
}

# Publish phase progress events
publish_phase_event() {
  local event_type="$1"  # started, progress, completed, failed, skipped
  local workflow_id="$2"
  local phase="$3"
  local phase_data="$4"

  publish_coordination_event "phase.$event_type" "$workflow_id" "$phase" "$phase_data"
}

# Publish resource allocation events
publish_resource_event() {
  local event_type="$1"  # requested, allocated, released, insufficient, conflict
  local workflow_id="$2"
  local resource_data="$3"

  local current_phase=$(get_current_phase "$workflow_id")
  publish_coordination_event "resource.$event_type" "$workflow_id" "$current_phase" "$resource_data"
}

# Publish error events
publish_error_event() {
  local error_type="$1"  # recoverable, critical, resolved, escalated
  local workflow_id="$2"
  local error_data="$3"

  local current_phase=$(get_current_phase "$workflow_id")
  local error_metadata="{
    \"severity\": \"$error_type\",
    \"recovery_attempted\": $(has_recovery_been_attempted "$workflow_id"),
    \"escalation_level\": $(get_escalation_level "$error_type")
  }"

  publish_coordination_event "error.$error_type" "$workflow_id" "$current_phase" "$error_data" "$error_metadata"
}
```

### 3. Batch Event Publishing

```bash
# Publish multiple events as a batch
publish_event_batch() {
  local events_json="$1"
  local batch_id=$(generate_uuid)

  local batch_event="{
    \"batch_id\": \"$batch_id\",
    \"events\": $events_json,
    \"batch_size\": $(echo "$events_json" | jq '. | length'),
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  send_coordination_request "coordination-hub" "publish-batch" "$batch_event"
}

# Aggregate and publish progress events
publish_progress_batch() {
  local workflow_id="$1"
  local progress_data_array="$2"

  local events=()
  while IFS= read -r progress_item; do
    local phase=$(echo "$progress_item" | jq -r '.phase')
    local progress=$(echo "$progress_item" | jq '.progress')

    local event="{
      \"event_type\": \"phase.progress\",
      \"workflow_id\": \"$workflow_id\",
      \"phase\": \"$phase\",
      \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
      \"data\": $progress
    }"

    events+=("$event")
  done < <(echo "$progress_data_array" | jq -c '.[]')

  local events_json=$(printf '%s\n' "${events[@]}" | jq -s '.')
  publish_event_batch "$events_json"
}
```

## Event Subscription Patterns

### 1. Event Subscription Setup

```bash
# Subscribe to specific event types
subscribe_to_events() {
  local event_types="$1"  # JSON array of event types
  local callback_function="$2"
  local filter_criteria="${3:-{}}"

  local subscription="{
    \"event_types\": $event_types,
    \"callback\": \"$callback_function\",
    \"filter\": $filter_criteria,
    \"subscriber_id\": \"$(generate_uuid)\",
    \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  send_coordination_request "coordination-hub" "subscribe" "$subscription"
}

# Subscribe to workflow-specific events
subscribe_to_workflow() {
  local workflow_id="$1"
  local callback_function="$2"

  local filter="{
    \"workflow_id\": \"$workflow_id\"
  }"

  subscribe_to_events '["workflow.*", "phase.*", "resource.*"]' "$callback_function" "$filter"
}
```

### 2. Event Processing Callbacks

```bash
# Process incoming workflow events
process_workflow_event() {
  local event="$1"

  local event_type=$(echo "$event" | jq -r '.event_type')
  local workflow_id=$(echo "$event" | jq -r '.workflow_id')
  local data=$(echo "$event" | jq '.data')

  case "$event_type" in
    "workflow.started")
      handle_workflow_started "$workflow_id" "$data"
      ;;
    "workflow.completed")
      handle_workflow_completed "$workflow_id" "$data"
      ;;
    "workflow.failed")
      handle_workflow_failed "$workflow_id" "$data"
      ;;
    "phase.completed")
      handle_phase_completed "$workflow_id" "$data"
      ;;
    "resource.allocated")
      handle_resource_allocated "$workflow_id" "$data"
      ;;
    "error.critical")
      handle_critical_error "$workflow_id" "$data"
      ;;
  esac
}

# Process phase transition events
process_phase_event() {
  local event="$1"

  local phase=$(echo "$event" | jq -r '.phase')
  local event_type=$(echo "$event" | jq -r '.event_type')
  local data=$(echo "$event" | jq '.data')

  if [[ "$event_type" == "phase.completed" ]]; then
    # Update phase tracking
    update_phase_completion "$phase" "$data"

    # Trigger next phase if appropriate
    trigger_next_phase_if_ready "$phase"
  fi
}
```

## Event Filtering and Routing

### 1. Event Filters

```bash
# Create event filter criteria
create_event_filter() {
  local workflow_pattern="${1:-.*}"
  local event_type_pattern="${2:-.*}"
  local phase_pattern="${3:-.*}"
  local priority="${4:-}"

  local filter="{
    \"workflow_pattern\": \"$workflow_pattern\",
    \"event_type_pattern\": \"$event_type_pattern\",
    \"phase_pattern\": \"$phase_pattern\""

  if [[ -n "$priority" ]]; then
    filter+=", \"priority\": \"$priority\""
  fi

  filter+="}"
  echo "$filter"
}

# Apply event filtering
filter_event() {
  local event="$1"
  local filter_criteria="$2"

  # Extract event properties
  local workflow_id=$(echo "$event" | jq -r '.workflow_id')
  local event_type=$(echo "$event" | jq -r '.event_type')
  local phase=$(echo "$event" | jq -r '.phase')

  # Apply filter patterns
  local workflow_pattern=$(echo "$filter_criteria" | jq -r '.workflow_pattern // ".*"')
  local event_type_pattern=$(echo "$filter_criteria" | jq -r '.event_type_pattern // ".*"')
  local phase_pattern=$(echo "$filter_criteria" | jq -r '.phase_pattern // ".*"')

  # Check if event matches filter
  if [[ "$workflow_id" =~ $workflow_pattern ]] && \
     [[ "$event_type" =~ $event_type_pattern ]] && \
     [[ "$phase" =~ $phase_pattern ]]; then
    return 0  # Event passes filter
  else
    return 1  # Event filtered out
  fi
}
```

### 2. Event Routing

```bash
# Route events to appropriate handlers
route_event() {
  local event="$1"

  local event_type=$(echo "$event" | jq -r '.event_type')
  local category=$(echo "$event_type" | cut -d'.' -f1)

  case "$category" in
    "workflow")
      route_to_workflow_handler "$event"
      ;;
    "phase")
      route_to_phase_handler "$event"
      ;;
    "resource")
      route_to_resource_handler "$event"
      ;;
    "error")
      route_to_error_handler "$event"
      ;;
    *)
      log_warning "Unknown event category: $category"
      ;;
  esac
}

# Intelligent event routing based on context
intelligent_route_event() {
  local event="$1"
  local context="$2"

  # Analyze event priority and context
  local priority=$(determine_event_priority "$event" "$context")
  local handlers=$(get_available_handlers "$event")

  # Route based on priority and load
  case "$priority" in
    "critical")
      route_to_priority_handler "$event" "$handlers"
      ;;
    "high")
      route_to_high_priority_handler "$event" "$handlers"
      ;;
    *)
      route_to_standard_handler "$event" "$handlers"
      ;;
  esac
}
```

## Performance and Reliability

### 1. Event Persistence

```bash
# Persist events for reliability
persist_event() {
  local event="$1"
  local persistence_level="${2:-standard}"

  case "$persistence_level" in
    "critical")
      # Persist to multiple locations
      persist_to_primary_storage "$event"
      persist_to_backup_storage "$event"
      ;;
    "standard")
      persist_to_primary_storage "$event"
      ;;
    "temporary")
      persist_to_memory_cache "$event"
      ;;
  esac
}
```

### 2. Event Replay and Recovery

```bash
# Replay events from a specific point
replay_events() {
  local workflow_id="$1"
  local from_timestamp="$2"
  local to_timestamp="${3:-now}"

  local events=$(get_persisted_events "$workflow_id" "$from_timestamp" "$to_timestamp")

  while IFS= read -r event; do
    replay_single_event "$event"
  done < <(echo "$events" | jq -c '.[]')
}

# Recover workflow state from events
recover_workflow_state() {
  local workflow_id="$1"

  log_info "Recovering workflow state for $workflow_id"

  # Get all events for workflow
  local events=$(get_workflow_events "$workflow_id")

  # Replay events to rebuild state
  replay_events "$workflow_id" "0"

  log_info "Workflow state recovery completed for $workflow_id"
}
```

## Utility Functions

```bash
# Generate UUID for event IDs
generate_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    # Fallback UUID generation
    cat /proc/sys/kernel/random/uuid 2>/dev/null || \
    date +%s%N | md5sum | head -c 32
  fi
}

# Get current phase for workflow
get_current_phase() {
  local workflow_id="$1"

  send_coordination_request "coordination-hub" "get-current-phase" "{\"workflow_id\": \"$workflow_id\"}" | \
    jq -r '.current_phase // "unknown"'
}

# Log event for debugging
log_event() {
  local event_type="$1"
  local workflow_id="$2"
  local event_id="$3"

  log_debug "Published event: $event_type [workflow: $workflow_id, id: $event_id]"
}
```