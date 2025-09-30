# Plan Parsing Engine

## Purpose
Comprehensive plan parsing and validation engine for processing implementation plans and extracting execution phases.

## Usage
```markdown
{{module:utilities/plan-parsing.md}}
```

## Plan Detection and Loading

### 1. Auto-Resume Plan Detection

```bash
# Find most recent incomplete implementation plan
find_most_recent_incomplete_plan() {
  local search_paths=("./specs/plans" "./plans" ".")
  local most_recent_plan=""
  local most_recent_time=0

  log_info "Searching for most recent incomplete implementation plan"

  # Search in known plan directories
  for search_path in "${search_paths[@]}"; do
    if [[ -d "$search_path" ]]; then
      # Find plan files
      while IFS= read -r -d '' plan_file; do
        # Check if plan is incomplete
        if is_plan_incomplete "$plan_file"; then
          local file_time=$(stat -f%m "$plan_file" 2>/dev/null || stat -c%Y "$plan_file" 2>/dev/null)

          if [[ $file_time -gt $most_recent_time ]]; then
            most_recent_time=$file_time
            most_recent_plan="$plan_file"
          fi
        fi
      done < <(find "$search_path" -maxdepth 2 -name "*plan*.md" -type f -print0)
    fi
  done

  if [[ -n "$most_recent_plan" ]]; then
    log_info "Found most recent incomplete plan: $most_recent_plan"
    echo "$most_recent_plan"
  else
    log_info "No incomplete plans found"
    return 1
  fi
}

# Check if implementation plan is incomplete
is_plan_incomplete() {
  local plan_file="$1"

  if [[ ! -f "$plan_file" ]]; then
    return 1
  fi

  # Parse plan and check completion status
  local plan_content=$(cat "$plan_file")
  local completion_markers=$(extract_completion_markers "$plan_content")

  # Check for incomplete phases or tasks
  if has_incomplete_phases "$completion_markers"; then
    return 0  # Plan is incomplete
  else
    return 1  # Plan is complete
  fi
}

# Extract completion markers from plan content
extract_completion_markers() {
  local plan_content="$1"

  # Extract checkboxes and completion indicators
  local checkboxes=$(echo "$plan_content" | grep -E "^\s*-\s*\[[ x]\]" | sed 's/.*\[\(.\)\].*/\1/')
  local status_indicators=$(echo "$plan_content" | grep -i "status:" | sed 's/.*status:\s*\(.*\)/\1/')

  local markers="{
    \"checkboxes\": [$(echo "$checkboxes" | sed 's/./\"&\"/g' | tr '\n' ',' | sed 's/,$//')],
    \"status_indicators\": [$(echo "$status_indicators" | sed 's/.*/\"&\"/' | tr '\n' ',' | sed 's/,$//')],
    \"total_checkboxes\": $(echo "$checkboxes" | wc -l),
    \"completed_checkboxes\": $(echo "$checkboxes" | grep -c "x")
  }"

  echo "$markers"
}
```

### 2. Plan Content Parsing

```bash
# Parse implementation plan structure
parse_implementation_plan() {
  local plan_file="$1"

  if [[ ! -f "$plan_file" ]]; then
    log_error "Plan file not found: $plan_file"
    return 1
  fi

  log_info "Parsing implementation plan: $plan_file"

  local plan_content=$(cat "$plan_file")

  # Extract plan metadata
  local plan_metadata=$(extract_plan_metadata "$plan_content")

  # Extract implementation phases
  local phases=$(extract_implementation_phases "$plan_content")

  # Extract dependencies and requirements
  local dependencies=$(extract_plan_dependencies "$plan_content")

  # Extract testing strategy
  local testing_strategy=$(extract_testing_strategy "$plan_content")

  # Create parsed plan structure
  local parsed_plan="{
    \"plan_file\": \"$plan_file\",
    \"parsed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"metadata\": $plan_metadata,
    \"phases\": $phases,
    \"dependencies\": $dependencies,
    \"testing_strategy\": $testing_strategy,
    \"total_phases\": $(echo "$phases" | jq '. | length')
  }"

  echo "$parsed_plan"
}

# Extract plan metadata from content
extract_plan_metadata() {
  local plan_content="$1"

  # Extract title
  local title=$(echo "$plan_content" | grep -m1 "^# " | sed 's/^# //')

  # Extract date
  local date=$(echo "$plan_content" | grep -i "date:" | head -1 | sed 's/.*date:\s*//')

  # Extract objective
  local objective=$(echo "$plan_content" | awk '/^## Objective/,/^##/ {if(!/^##/) print}' | sed '/^$/d')

  # Extract estimated duration
  local duration=$(echo "$plan_content" | grep -i "duration\|estimate" | head -1 | grep -o '[0-9]\+[hdm]')

  local metadata="{
    \"title\": \"$title\",
    \"date\": \"$date\",
    \"objective\": \"$objective\",
    \"estimated_duration\": \"$duration\"
  }"

  echo "$metadata"
}

# Extract implementation phases from plan
extract_implementation_phases() {
  local plan_content="$1"

  local phases="[]"
  local phase_counter=1

  # Find phase sections (looking for numbered headers or "Phase" headers)
  while IFS= read -r line; do
    if [[ "$line" =~ ^###\s+([0-9]+\.|Phase\s+[0-9]+|Step\s+[0-9]+) ]]; then
      local phase_title=$(echo "$line" | sed 's/^###\s*//')
      local phase_content=$(extract_phase_content "$plan_content" "$line")
      local phase_tasks=$(extract_phase_tasks "$phase_content")
      local phase_completion=$(check_phase_completion "$phase_content")

      local phase="{
        \"phase_number\": $phase_counter,
        \"title\": \"$phase_title\",
        \"content\": \"$phase_content\",
        \"tasks\": $phase_tasks,
        \"completed\": $phase_completion,
        \"task_count\": $(echo "$phase_tasks" | jq '. | length')
      }"

      phases=$(echo "$phases" | jq ". += [$phase]")
      phase_counter=$((phase_counter + 1))
    fi
  done <<< "$plan_content"

  echo "$phases"
}

# Extract phase content between headers
extract_phase_content() {
  local plan_content="$1"
  local phase_header="$2"

  # Use awk to extract content between this header and the next
  echo "$plan_content" | awk -v header="$phase_header" '
    $0 == header { found=1; next }
    found && /^###/ && $0 != header { exit }
    found { print }
  '
}

# Extract tasks from phase content
extract_phase_tasks() {
  local phase_content="$1"

  local tasks="[]"

  # Extract numbered tasks or bullet points
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*[0-9]+\.|^[[:space:]]*[-*] ]]; then
      local task_text=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[.*-][[:space:]]*//')
      local task_completed=false

      # Check for completion indicators
      if [[ "$line" =~ \[x\]|\[X\]|✓|✔|DONE|COMPLETED ]]; then
        task_completed=true
      fi

      local task="{
        \"text\": \"$task_text\",
        \"completed\": $task_completed,
        \"original_line\": \"$line\"
      }"

      tasks=$(echo "$tasks" | jq ". += [$task]")
    fi
  done <<< "$phase_content"

  echo "$tasks"
}
```

## Plan Validation

### 1. Comprehensive Plan Validation

```bash
# Validate implementation plan structure and content
validate_implementation_plan() {
  local parsed_plan="$1"

  log_info "Validating implementation plan structure"

  local validation_results="{
    \"structure_valid\": false,
    \"phases_valid\": false,
    \"dependencies_valid\": false,
    \"testing_valid\": false,
    \"errors\": [],
    \"warnings\": []
  }"

  # Validate plan structure
  if validate_plan_structure "$parsed_plan"; then
    validation_results=$(echo "$validation_results" | jq '.structure_valid = true')
  else
    validation_results=$(echo "$validation_results" | jq '.errors += ["Invalid plan structure"]')
  fi

  # Validate phases
  local phases=$(echo "$parsed_plan" | jq '.phases')
  if validate_plan_phases "$phases"; then
    validation_results=$(echo "$validation_results" | jq '.phases_valid = true')
  else
    validation_results=$(echo "$validation_results" | jq '.errors += ["Invalid phase structure"]')
  fi

  # Validate dependencies
  local dependencies=$(echo "$parsed_plan" | jq '.dependencies')
  if validate_plan_dependencies "$dependencies"; then
    validation_results=$(echo "$validation_results" | jq '.dependencies_valid = true')
  else
    validation_results=$(echo "$validation_results" | jq '.warnings += ["Dependency validation issues"]')
  fi

  # Validate testing strategy
  local testing_strategy=$(echo "$parsed_plan" | jq '.testing_strategy')
  if validate_testing_strategy "$testing_strategy"; then
    validation_results=$(echo "$validation_results" | jq '.testing_valid = true')
  else
    validation_results=$(echo "$validation_results" | jq '.warnings += ["Testing strategy validation issues"]')
  fi

  # Calculate overall validation status
  local error_count=$(echo "$validation_results" | jq '.errors | length')
  local overall_valid=false
  if [[ $error_count -eq 0 ]]; then
    overall_valid=true
  fi

  validation_results=$(echo "$validation_results" | jq ".overall_valid = $overall_valid")

  echo "$validation_results"
}

# Validate plan structure
validate_plan_structure() {
  local parsed_plan="$1"

  # Check required fields
  local required_fields=("plan_file" "metadata" "phases")
  for field in "${required_fields[@]}"; do
    if ! echo "$parsed_plan" | jq -e ".$field" >/dev/null; then
      log_error "Missing required field: $field"
      return 1
    fi
  done

  # Check metadata structure
  local metadata=$(echo "$parsed_plan" | jq '.metadata')
  if ! echo "$metadata" | jq -e '.title' >/dev/null; then
    log_error "Missing plan title in metadata"
    return 1
  fi

  return 0
}

# Validate plan phases
validate_plan_phases() {
  local phases="$1"

  local phase_count=$(echo "$phases" | jq '. | length')
  if [[ $phase_count -eq 0 ]]; then
    log_error "No phases found in plan"
    return 1
  fi

  # Validate each phase
  local phase_index=0
  while [[ $phase_index -lt $phase_count ]]; do
    local phase=$(echo "$phases" | jq ".[$phase_index]")

    # Check required phase fields
    if ! echo "$phase" | jq -e '.title' >/dev/null; then
      log_error "Phase $((phase_index + 1)) missing title"
      return 1
    fi

    if ! echo "$phase" | jq -e '.tasks' >/dev/null; then
      log_error "Phase $((phase_index + 1)) missing tasks"
      return 1
    fi

    # Check if phase has at least one task
    local task_count=$(echo "$phase" | jq '.tasks | length')
    if [[ $task_count -eq 0 ]]; then
      log_warning "Phase $((phase_index + 1)) has no tasks"
    fi

    phase_index=$((phase_index + 1))
  done

  return 0
}
```

## Plan Execution Preparation

### 1. Execution Context Preparation

```bash
# Prepare execution context for plan implementation
prepare_execution_context() {
  local parsed_plan="$1"
  local starting_phase="${2:-1}"
  local execution_options="$3"

  log_info "Preparing execution context for plan implementation"

  # Extract plan information
  local plan_file=$(echo "$parsed_plan" | jq -r '.plan_file')
  local plan_metadata=$(echo "$parsed_plan" | jq '.metadata')
  local phases=$(echo "$parsed_plan" | jq '.phases')

  # Determine execution mode
  local orchestration_mode=$(determine_orchestration_mode "$execution_options")

  # Calculate execution phases
  local execution_phases=$(calculate_execution_phases "$phases" "$starting_phase")

  # Prepare working directory
  local working_directory=$(prepare_plan_working_directory "$plan_file")

  # Create execution context
  local execution_context="{
    \"plan_file\": \"$plan_file\",
    \"plan_metadata\": $plan_metadata,
    \"execution_phases\": $execution_phases,
    \"starting_phase\": $starting_phase,
    \"working_directory\": \"$working_directory\",
    \"orchestration_mode\": $orchestration_mode,
    \"execution_options\": $execution_options,
    \"prepared_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"execution_id\": \"exec_$(date +%s)_$(basename "$plan_file" .md)\"
  }"

  echo "$execution_context"
}

# Determine orchestration mode
determine_orchestration_mode() {
  local execution_options="$1"

  # Check for explicit orchestration flag
  if echo "$execution_options" | grep -q -- "--orchestrated"; then
    echo "orchestrated"
    return
  fi

  # Check environment variables
  if [[ -n "${ORCHESTRATED_MODE:-}" ]]; then
    echo "orchestrated"
    return
  fi

  # Check for coordination hub availability
  if command -v coordination-hub >/dev/null 2>&1; then
    # Test coordination hub connectivity
    if send_coordination_request "coordination-hub" "ping" "{}" >/dev/null 2>&1; then
      echo "orchestrated"
      return
    fi
  fi

  # Default to standalone mode
  echo "standalone"
}

# Calculate execution phases from starting point
calculate_execution_phases() {
  local phases="$1"
  local starting_phase="$2"

  # Filter phases from starting point
  local execution_phases=$(echo "$phases" | jq --arg start "$starting_phase" '
    map(select(.phase_number >= ($start | tonumber)))
  ')

  # Add execution metadata to each phase
  execution_phases=$(echo "$execution_phases" | jq '
    map(. + {
      "execution_order": (. | keys | length) + 1,
      "estimated_duration": (if .task_count then (.task_count * 5) else 15 end),
      "prepared_for_execution": true
    })
  ')

  echo "$execution_phases"
}
```

### 2. Phase Dependencies Resolution

```bash
# Resolve phase dependencies and execution order
resolve_phase_dependencies() {
  local execution_phases="$1"
  local plan_dependencies="$2"

  log_info "Resolving phase dependencies and execution order"

  local resolved_phases="[]"
  local dependency_graph=$(create_dependency_graph "$execution_phases" "$plan_dependencies")

  # Topological sort of phases based on dependencies
  local sorted_phases=$(topological_sort_phases "$dependency_graph")

  # Add dependency information to each phase
  while IFS= read -r phase; do
    local phase_number=$(echo "$phase" | jq -r '.phase_number')
    local phase_dependencies=$(get_phase_dependencies "$phase_number" "$dependency_graph")
    local blocking_dependencies=$(get_blocking_dependencies "$phase_number" "$dependency_graph")

    local enhanced_phase=$(echo "$phase" | jq --argjson deps "$phase_dependencies" --argjson blocking "$blocking_dependencies" '
      . + {
        "dependencies": $deps,
        "blocking_dependencies": $blocking,
        "can_execute_parallel": (.dependencies | length == 0),
        "dependency_count": (.dependencies | length)
      }
    ')

    resolved_phases=$(echo "$resolved_phases" | jq ". += [$enhanced_phase]")
  done <<< "$sorted_phases"

  echo "$resolved_phases"
}

# Create dependency graph from phases and dependencies
create_dependency_graph() {
  local phases="$1"
  local plan_dependencies="$2"

  local dependency_graph="{
    \"nodes\": [],
    \"edges\": []
  }"

  # Add phase nodes
  while IFS= read -r phase; do
    local phase_number=$(echo "$phase" | jq -r '.phase_number')
    local phase_title=$(echo "$phase" | jq -r '.title')

    local node="{
      \"id\": $phase_number,
      \"title\": \"$phase_title\",
      \"type\": \"phase\"
    }"

    dependency_graph=$(echo "$dependency_graph" | jq ".nodes += [$node]")
  done < <(echo "$phases" | jq -c '.[]')

  # Add dependency edges from plan dependencies
  if [[ "$plan_dependencies" != "null" ]]; then
    while IFS= read -r dependency; do
      local from_phase=$(echo "$dependency" | jq -r '.from_phase')
      local to_phase=$(echo "$dependency" | jq -r '.to_phase')
      local dependency_type=$(echo "$dependency" | jq -r '.type // "sequential"')

      local edge="{
        \"from\": $from_phase,
        \"to\": $to_phase,
        \"type\": \"$dependency_type\"
      }"

      dependency_graph=$(echo "$dependency_graph" | jq ".edges += [$edge]")
    done < <(echo "$plan_dependencies" | jq -c '.[]')
  fi

  echo "$dependency_graph"
}
```

## Progress Tracking and State Management

### 1. Phase Progress Tracking

```bash
# Initialize phase progress tracking
initialize_phase_progress() {
  local execution_context="$1"

  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')
  local execution_phases=$(echo "$execution_context" | jq '.execution_phases')

  # Create progress tracking structure
  local progress_tracking="{
    \"execution_id\": \"$execution_id\",
    \"initialized_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"phase_progress\": {},
    \"overall_progress\": {
      \"total_phases\": $(echo "$execution_phases" | jq '. | length'),
      \"completed_phases\": 0,
      \"current_phase\": null,
      \"start_time\": null,
      \"estimated_completion\": null
    }
  }"

  # Initialize progress for each phase
  while IFS= read -r phase; do
    local phase_number=$(echo "$phase" | jq -r '.phase_number')
    local task_count=$(echo "$phase" | jq -r '.task_count')

    local phase_progress="{
      \"phase_number\": $phase_number,
      \"status\": \"pending\",
      \"completed_tasks\": 0,
      \"total_tasks\": $task_count,
      \"start_time\": null,
      \"completion_time\": null,
      \"progress_percentage\": 0
    }"

    progress_tracking=$(echo "$progress_tracking" | jq ".phase_progress[\"$phase_number\"] = $phase_progress")
  done < <(echo "$execution_phases" | jq -c '.[]')

  # Store progress tracking
  store_progress_tracking "$execution_id" "$progress_tracking"

  echo "$progress_tracking"
}

# Update phase progress
update_phase_progress() {
  local execution_id="$1"
  local phase_number="$2"
  local progress_update="$3"

  # Load current progress
  local current_progress=$(load_progress_tracking "$execution_id")

  # Update phase progress
  local updated_progress=$(echo "$current_progress" | jq --arg phase "$phase_number" --argjson update "$progress_update" '
    .phase_progress[$phase] = (.phase_progress[$phase] + $update) |
    .phase_progress[$phase].progress_percentage = ((.phase_progress[$phase].completed_tasks / .phase_progress[$phase].total_tasks) * 100)
  ')

  # Update overall progress
  local completed_phases=$(echo "$updated_progress" | jq '[.phase_progress[] | select(.status == "completed")] | length')
  updated_progress=$(echo "$updated_progress" | jq --arg completed "$completed_phases" '
    .overall_progress.completed_phases = ($completed | tonumber)
  ')

  # Store updated progress
  store_progress_tracking "$execution_id" "$updated_progress"

  echo "$updated_progress"
}
```

## Utility Functions

```bash
# Store progress tracking data
store_progress_tracking() {
  local execution_id="$1"
  local progress_data="$2"

  local progress_file="/tmp/plan_progress/${execution_id}.progress"

  # Ensure directory exists
  mkdir -p "$(dirname "$progress_file")"

  # Store progress data
  echo "$progress_data" > "$progress_file"
}

# Load progress tracking data
load_progress_tracking() {
  local execution_id="$1"

  local progress_file="/tmp/plan_progress/${execution_id}.progress"

  if [[ -f "$progress_file" ]]; then
    cat "$progress_file"
  else
    echo "{}"
  fi
}

# Prepare plan working directory
prepare_plan_working_directory() {
  local plan_file="$1"

  local plan_dir=$(dirname "$plan_file")
  local working_dir="$plan_dir/.execution"

  # Create working directory if it doesn't exist
  mkdir -p "$working_dir"

  # Copy plan file to working directory
  cp "$plan_file" "$working_dir/"

  echo "$working_dir"
}

# Check phase completion status
check_phase_completion() {
  local phase_content="$1"

  # Look for completion indicators
  if echo "$phase_content" | grep -q -i "completed\|done\|✓\|✔"; then
    echo "true"
  else
    echo "false"
  fi
}
```