# Phase Execution Framework

## Purpose
Comprehensive phase execution framework for systematic implementation of plan phases with orchestration support.

## Usage
```markdown
{{module:utilities/phase-execution.md}}
```

## Phase Execution Engine

### 1. Phase Execution Orchestration

```bash
# Execute implementation phases with orchestration support
execute_implementation_phases() {
  local execution_context="$1"
  local starting_phase="$2"
  local orchestration_mode="$3"

  log_info "Starting phase execution in $orchestration_mode mode"

  # Extract execution information
  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')
  local execution_phases=$(echo "$execution_context" | jq '.execution_phases')

  # Initialize execution environment
  initialize_execution_environment "$execution_context" "$orchestration_mode"

  # Execute phases sequentially or in parallel based on dependencies
  local phase_results="[]"
  local execution_success=true

  # Filter phases from starting point
  local phases_to_execute=$(echo "$execution_phases" | jq --arg start "$starting_phase" '
    map(select(.phase_number >= ($start | tonumber)))
  ')

  # Execute each phase
  while IFS= read -r phase; do
    local phase_number=$(echo "$phase" | jq -r '.phase_number')
    local phase_title=$(echo "$phase" | jq -r '.title')

    log_info "Executing Phase $phase_number: $phase_title"

    # Execute phase with appropriate mode
    local phase_result
    if [[ "$orchestration_mode" == "orchestrated" ]]; then
      phase_result=$(execute_orchestrated_phase "$execution_id" "$phase" "$execution_context")
    else
      phase_result=$(execute_standalone_phase "$execution_id" "$phase" "$execution_context")
    fi

    # Check phase execution result
    if [[ "$(echo "$phase_result" | jq -r '.success')" != "true" ]]; then
      log_error "Phase $phase_number execution failed"
      execution_success=false
      break
    fi

    phase_results=$(echo "$phase_results" | jq ". += [$phase_result]")

    # Create checkpoint after successful phase
    if [[ "$orchestration_mode" == "orchestrated" ]]; then
      create_phase_checkpoint "$execution_id" "$phase_number" "$phase_result"
    fi

  done < <(echo "$phases_to_execute" | jq -c '.[]')

  # Generate execution summary
  generate_execution_summary "$execution_id" "$phase_results" "$execution_success"
}

# Execute phase in orchestrated mode
execute_orchestrated_phase() {
  local execution_id="$1"
  local phase="$2"
  local execution_context="$3"

  local phase_number=$(echo "$phase" | jq -r '.phase_number')
  local phase_title=$(echo "$phase" | jq -r '.title')

  # Notify coordination hub of phase start
  publish_coordination_event "phase.started" "$execution_id" "$phase_number" "{
    \"phase_title\": \"$phase_title\",
    \"estimated_duration\": $(echo "$phase" | jq '.estimated_duration')
  }"

  # Request resources for phase
  local resource_requirements=$(calculate_phase_resource_requirements "$phase")
  request_phase_resources "$execution_id" "$phase_number" "$resource_requirements"

  # Execute phase tasks
  local phase_result=$(execute_phase_tasks "$execution_id" "$phase" "orchestrated")

  # Report phase completion
  if [[ "$(echo "$phase_result" | jq -r '.success')" == "true" ]]; then
    publish_coordination_event "phase.completed" "$execution_id" "$phase_number" "$phase_result"
  else
    publish_coordination_event "phase.failed" "$execution_id" "$phase_number" "$phase_result"
  fi

  # Release phase resources
  release_phase_resources "$execution_id" "$phase_number"

  echo "$phase_result"
}

# Execute phase in standalone mode
execute_standalone_phase() {
  local execution_id="$1"
  local phase="$2"
  local execution_context="$3"

  local phase_number=$(echo "$phase" | jq -r '.phase_number')

  log_info "Executing phase $phase_number in standalone mode"

  # Execute phase tasks
  local phase_result=$(execute_phase_tasks "$execution_id" "$phase" "standalone")

  echo "$phase_result"
}
```

### 2. Task Execution Framework

```bash
# Execute tasks within a phase
execute_phase_tasks() {
  local execution_id="$1"
  local phase="$2"
  local execution_mode="$3"

  local phase_number=$(echo "$phase" | jq -r '.phase_number')
  local tasks=$(echo "$phase" | jq '.tasks')
  local task_count=$(echo "$tasks" | jq '. | length')

  log_info "Executing $task_count tasks for phase $phase_number"

  local task_results="[]"
  local completed_tasks=0
  local failed_tasks=0

  # Execute each task
  local task_index=0
  while [[ $task_index -lt $task_count ]]; do
    local task=$(echo "$tasks" | jq ".[$task_index]")
    local task_text=$(echo "$task" | jq -r '.text')

    log_info "Executing task: $task_text"

    # Execute task based on its type
    local task_result=$(execute_individual_task "$execution_id" "$phase_number" "$task" "$execution_mode")

    # Update progress
    if [[ "$(echo "$task_result" | jq -r '.success')" == "true" ]]; then
      completed_tasks=$((completed_tasks + 1))
    else
      failed_tasks=$((failed_tasks + 1))
    fi

    task_results=$(echo "$task_results" | jq ". += [$task_result]")

    # Update phase progress
    local progress_percentage=$(echo "scale=2; $completed_tasks * 100 / $task_count" | bc)
    update_phase_progress "$execution_id" "$phase_number" "{
      \"completed_tasks\": $completed_tasks,
      \"failed_tasks\": $failed_tasks,
      \"progress_percentage\": $progress_percentage
    }"

    task_index=$((task_index + 1))
  done

  # Generate phase result
  local phase_success=true
  if [[ $failed_tasks -gt 0 ]]; then
    phase_success=false
  fi

  local phase_result="{
    \"phase_number\": $phase_number,
    \"success\": $phase_success,
    \"completed_tasks\": $completed_tasks,
    \"failed_tasks\": $failed_tasks,
    \"total_tasks\": $task_count,
    \"task_results\": $task_results,
    \"execution_time\": \"$(calculate_phase_execution_time "$execution_id" "$phase_number")\",
    \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  echo "$phase_result"
}

# Execute individual task
execute_individual_task() {
  local execution_id="$1"
  local phase_number="$2"
  local task="$3"
  local execution_mode="$4"

  local task_text=$(echo "$task" | jq -r '.text')
  local task_start_time=$(date +%s)

  # Determine task type and execution strategy
  local task_type=$(determine_task_type "$task_text")
  local execution_strategy=$(determine_task_execution_strategy "$task_type" "$execution_mode")

  log_debug "Executing task type: $task_type with strategy: $execution_strategy"

  # Execute task based on strategy
  local task_execution_result
  case "$execution_strategy" in
    "file_operation")
      task_execution_result=$(execute_file_operation_task "$task_text")
      ;;
    "code_modification")
      task_execution_result=$(execute_code_modification_task "$task_text")
      ;;
    "test_execution")
      task_execution_result=$(execute_test_task "$task_text")
      ;;
    "configuration_update")
      task_execution_result=$(execute_configuration_task "$task_text")
      ;;
    "documentation_update")
      task_execution_result=$(execute_documentation_task "$task_text")
      ;;
    "validation")
      task_execution_result=$(execute_validation_task "$task_text")
      ;;
    *)
      task_execution_result=$(execute_generic_task "$task_text")
      ;;
  esac

  # Calculate execution time
  local task_end_time=$(date +%s)
  local execution_time=$((task_end_time - task_start_time))

  # Create task result
  local task_result="{
    \"task_text\": \"$task_text\",
    \"task_type\": \"$task_type\",
    \"execution_strategy\": \"$execution_strategy\",
    \"success\": $(echo "$task_execution_result" | jq '.success'),
    \"execution_time\": $execution_time,
    \"output\": $(echo "$task_execution_result" | jq '.output'),
    \"error_message\": $(echo "$task_execution_result" | jq '.error_message // null'),
    \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  echo "$task_result"
}
```

### 3. Resource Management for Phases

```bash
# Calculate resource requirements for phase
calculate_phase_resource_requirements() {
  local phase="$1"

  local task_count=$(echo "$phase" | jq '.task_count')
  local estimated_duration=$(echo "$phase" | jq -r '.estimated_duration')
  local phase_complexity=$(assess_phase_complexity "$phase")

  # Base resource calculation
  local base_cpu=1
  local base_memory=1
  local base_agents=1

  # Scale based on task count and complexity
  local cpu_requirement=$(echo "$base_cpu * $task_count * $phase_complexity" | bc)
  local memory_requirement=$(echo "$base_memory * $task_count * $phase_complexity" | bc)
  local agent_requirement=$(echo "$base_agents + ($task_count / 5)" | bc)

  local requirements="{
    \"cpu_cores\": $cpu_requirement,
    \"memory_gb\": $memory_requirement,
    \"agents\": $agent_requirement,
    \"estimated_duration\": \"$estimated_duration\",
    \"priority\": \"medium\"
  }"

  echo "$requirements"
}

# Request resources for phase execution
request_phase_resources() {
  local execution_id="$1"
  local phase_number="$2"
  local requirements="$3"

  local resource_request="{
    \"execution_id\": \"$execution_id\",
    \"phase_number\": $phase_number,
    \"resource_type\": \"phase_execution\",
    \"requirements\": $requirements
  }"

  coordinate_with_resource_manager "allocate" "$resource_request"
}

# Release resources after phase completion
release_phase_resources() {
  local execution_id="$1"
  local phase_number="$2"

  local release_request="{
    \"execution_id\": \"$execution_id\",
    \"phase_number\": $phase_number,
    \"resource_type\": \"phase_execution\"
  }"

  coordinate_with_resource_manager "release" "$release_request"
}
```

### 4. Phase Checkpoint Management

```bash
# Create checkpoint after successful phase
create_phase_checkpoint() {
  local execution_id="$1"
  local phase_number="$2"
  local phase_result="$3"

  log_info "Creating checkpoint for phase $phase_number"

  local checkpoint_name="phase_${phase_number}_complete"
  local checkpoint_data="{
    \"execution_id\": \"$execution_id\",
    \"phase_number\": $phase_number,
    \"phase_result\": $phase_result,
    \"checkpoint_type\": \"phase_completion\",
    \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  # Create checkpoint using recovery system
  if command_exists "workflow-recovery"; then
    send_coordination_request "workflow-recovery" "create-checkpoint" "{
      \"workflow_id\": \"$execution_id\",
      \"checkpoint_name\": \"$checkpoint_name\",
      \"checkpoint_data\": $checkpoint_data
    }"
  else
    # Fallback to local checkpoint
    create_local_checkpoint "$execution_id" "$checkpoint_name" "$checkpoint_data"
  fi
}

# Create local checkpoint as fallback
create_local_checkpoint() {
  local execution_id="$1"
  local checkpoint_name="$2"
  local checkpoint_data="$3"

  local checkpoint_dir="/tmp/phase_checkpoints/$execution_id"
  mkdir -p "$checkpoint_dir"

  local checkpoint_file="$checkpoint_dir/${checkpoint_name}.checkpoint"
  echo "$checkpoint_data" > "$checkpoint_file"

  log_debug "Local checkpoint created: $checkpoint_file"
}
```

## Task Type Handlers

### 1. File Operation Tasks

```bash
# Execute file operation tasks
execute_file_operation_task() {
  local task_text="$1"

  # Parse file operation from task text
  local operation=$(extract_file_operation "$task_text")
  local file_path=$(extract_file_path "$task_text")

  case "$operation" in
    "create")
      create_file_from_task "$file_path" "$task_text"
      ;;
    "modify"|"edit"|"update")
      modify_file_from_task "$file_path" "$task_text"
      ;;
    "delete"|"remove")
      delete_file_from_task "$file_path"
      ;;
    *)
      execute_generic_file_task "$task_text"
      ;;
  esac
}

# Create file from task description
create_file_from_task() {
  local file_path="$1"
  local task_text="$2"

  # Extract file content from task if specified
  local file_content=$(extract_file_content_from_task "$task_text")

  if [[ -n "$file_content" ]]; then
    echo "$file_content" > "$file_path"
  else
    touch "$file_path"
  fi

  if [[ -f "$file_path" ]]; then
    echo '{"success": true, "output": "File created successfully"}'
  else
    echo '{"success": false, "error_message": "Failed to create file"}'
  fi
}
```

### 2. Code Modification Tasks

```bash
# Execute code modification tasks
execute_code_modification_task() {
  local task_text="$1"

  # Determine modification type
  local modification_type=$(determine_code_modification_type "$task_text")

  case "$modification_type" in
    "function_creation")
      create_function_from_task "$task_text"
      ;;
    "function_modification")
      modify_function_from_task "$task_text"
      ;;
    "configuration_update")
      update_configuration_from_task "$task_text"
      ;;
    "dependency_addition")
      add_dependency_from_task "$task_text"
      ;;
    *)
      execute_generic_code_task "$task_text"
      ;;
  esac
}
```

### 3. Test Execution Tasks

```bash
# Execute test tasks
execute_test_task() {
  local task_text="$1"

  # Determine test type
  local test_type=$(determine_test_type "$task_text")
  local test_target=$(extract_test_target "$task_text")

  case "$test_type" in
    "unit_test")
      run_unit_tests "$test_target"
      ;;
    "integration_test")
      run_integration_tests "$test_target"
      ;;
    "validation_test")
      run_validation_tests "$test_target"
      ;;
    "performance_test")
      run_performance_tests "$test_target"
      ;;
    *)
      run_generic_tests "$task_text"
      ;;
  esac
}

# Run unit tests
run_unit_tests() {
  local test_target="$1"

  log_info "Running unit tests for: $test_target"

  # Determine test command based on project type
  local test_command=$(determine_test_command "$test_target" "unit")

  if [[ -n "$test_command" ]]; then
    local test_output=$(eval "$test_command" 2>&1)
    local test_exit_code=$?

    if [[ $test_exit_code -eq 0 ]]; then
      echo "{\"success\": true, \"output\": \"$(echo "$test_output" | jq -R -s .)\"}"
    else
      echo "{\"success\": false, \"error_message\": \"$(echo "$test_output" | jq -R -s .)\"}"
    fi
  else
    echo '{"success": false, "error_message": "Unable to determine test command"}'
  fi
}
```

## Execution State Management

### 1. Progress Tracking

```bash
# Update phase progress
update_phase_progress() {
  local execution_id="$1"
  local phase_number="$2"
  local progress_data="$3"

  # Update local progress tracking
  local current_progress=$(load_progress_tracking "$execution_id")
  local updated_progress=$(echo "$current_progress" | jq --arg phase "$phase_number" --argjson data "$progress_data" '
    .phase_progress[$phase] = (.phase_progress[$phase] + $data)
  ')

  store_progress_tracking "$execution_id" "$updated_progress"

  # Publish progress update if in orchestrated mode
  if command_exists "coordination-hub"; then
    publish_coordination_event "phase.progress" "$execution_id" "$phase_number" "$progress_data"
  fi
}

# Calculate phase execution time
calculate_phase_execution_time() {
  local execution_id="$1"
  local phase_number="$2"

  local progress_data=$(load_progress_tracking "$execution_id")
  local phase_progress=$(echo "$progress_data" | jq ".phase_progress[\"$phase_number\"]")

  local start_time=$(echo "$phase_progress" | jq -r '.start_time')
  local current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ "$start_time" != "null" ]]; then
    local start_timestamp=$(date -d "$start_time" +%s)
    local current_timestamp=$(date -d "$current_time" +%s)
    local duration=$((current_timestamp - start_timestamp))

    echo "${duration}s"
  else
    echo "0s"
  fi
}
```

## Utility Functions

```bash
# Determine task type from task text
determine_task_type() {
  local task_text="$1"

  case "$task_text" in
    *"create file"*|*"add file"*|*"new file"*)
      echo "file_operation"
      ;;
    *"modify"*|*"update"*|*"edit"*|*"change"*)
      echo "code_modification"
      ;;
    *"test"*|*"verify"*|*"validate"*)
      echo "test_execution"
      ;;
    *"configure"*|*"config"*|*"setting"*)
      echo "configuration_update"
      ;;
    *"document"*|*"readme"*|*"doc"*)
      echo "documentation_update"
      ;;
    *)
      echo "generic"
      ;;
  esac
}

# Assess phase complexity
assess_phase_complexity() {
  local phase="$1"

  local task_count=$(echo "$phase" | jq '.task_count')
  local phase_title=$(echo "$phase" | jq -r '.title')

  # Base complexity factor
  local complexity=1.0

  # Increase complexity based on task count
  if [[ $task_count -gt 10 ]]; then
    complexity=$(echo "$complexity + 0.5" | bc)
  fi

  # Increase complexity based on phase type
  if echo "$phase_title" | grep -qi "critical\|complex\|advanced\|integration"; then
    complexity=$(echo "$complexity + 0.3" | bc)
  fi

  echo "$complexity"
}

# Initialize execution environment
initialize_execution_environment() {
  local execution_context="$1"
  local orchestration_mode="$2"

  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')
  local working_directory=$(echo "$execution_context" | jq -r '.working_directory')

  # Set up working directory
  if [[ ! -d "$working_directory" ]]; then
    mkdir -p "$working_directory"
  fi

  cd "$working_directory" || {
    log_error "Failed to change to working directory: $working_directory"
    return 1
  }

  # Initialize progress tracking
  initialize_phase_progress "$execution_context"

  # Setup orchestration if needed
  if [[ "$orchestration_mode" == "orchestrated" ]]; then
    initialize_orchestration_environment "$execution_id"
  fi

  log_info "Execution environment initialized in: $working_directory"
}
```