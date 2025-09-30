{{template:primary_yaml:implement,Execute implementation plan with automated testing and commits (auto-resumes most recent incomplete plan if no args),[plan-file] [starting-phase] [--orchestrated],list-plans,update-plan,list-summaries,revise,debug,document,subagents}}

# Execute Implementation Plan

I'll help you systematically implement the plan file with automated testing and commits at each phase.

## Plan Information
- **Plan file**: $1 (or I'll find the most recent incomplete plan)
- **Starting phase**: $2 (default: resume from last incomplete phase or 1)
- **Orchestration mode**: $3 (--orchestrated flag enables orchestration features)

## Auto-Resume Feature
If no plan file is provided, I will:
1. Search for the most recently modified implementation plan
2. Check if it has incomplete phases or tasks
3. Resume from the first incomplete phase
4. If all recent plans are complete, show a list to choose from

## Plan Processing Framework

Let me detect the execution mode and process your implementation plan:

{{module:utilities/plan-parsing.md}}

## Orchestration Mode Integration

{{module:shared/integration-patterns/helper-coordination.md}}

## Implementation Execution Engine

{{module:utilities/phase-execution.md}}

## Testing and Validation Framework

{{module:utilities/testing-validation.md}}

## Error Handling and Recovery

{{module:shared/error-handling/standard-recovery.md}}

## Implementation Process

Based on your parameters, I'll execute the complete implementation workflow:

```bash
# Main implementation handler
execute_implementation() {
  local plan_file="$1"
  local starting_phase="${2:-1}"
  local orchestration_flag="$3"

  log_info "Starting implementation execution"

  # Step 1: Plan detection and loading
  if [[ -z "$plan_file" ]]; then
    plan_file=$(find_most_recent_incomplete_plan)
    if [[ -z "$plan_file" ]]; then
      log_error "No incomplete plans found. Please specify a plan file."
      return 1
    fi
    log_info "Auto-resuming plan: $plan_file"
  fi

  # Step 2: Parse and validate plan
  local parsed_plan=$(parse_implementation_plan "$plan_file")
  local validation_results=$(validate_implementation_plan "$parsed_plan")

  if [[ "$(echo "$validation_results" | jq -r '.overall_valid')" != "true" ]]; then
    log_error "Plan validation failed: $(echo "$validation_results" | jq -r '.errors[]')"
    return 1
  fi

  # Step 3: Prepare execution context
  local execution_options="$orchestration_flag"
  local execution_context=$(prepare_execution_context "$parsed_plan" "$starting_phase" "$execution_options")
  local orchestration_mode=$(echo "$execution_context" | jq -r '.orchestration_mode')

  log_info "Execution mode: $orchestration_mode"

  # Step 4: Initialize orchestration if needed
  if [[ "$orchestration_mode" == "orchestrated" ]]; then
    initialize_orchestration "$execution_context"
  fi

  # Step 5: Execute implementation phases
  execute_implementation_phases "$execution_context" "$starting_phase" "$orchestration_mode"

  # Step 6: Generate implementation summary
  generate_implementation_summary "$execution_context"

  # Step 7: Cleanup and finalization
  finalize_implementation "$execution_context" "$orchestration_mode"
}

# Initialize orchestration environment
initialize_orchestration() {
  local execution_context="$1"

  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')
  local plan_metadata=$(echo "$execution_context" | jq '.plan_metadata')

  # Register workflow with coordination hub
  coordinate_with_hub "create-workflow" "{
    \"workflow_id\": \"$execution_id\",
    \"workflow_type\": \"implementation\",
    \"plan_metadata\": $plan_metadata,
    \"status\": \"initialized\"
  }"

  # Request resource allocation
  local resource_requirements=$(calculate_implementation_resource_requirements "$execution_context")
  request_resource_allocation "$execution_id" "$resource_requirements"

  log_info "Orchestration environment initialized"
}

# Calculate implementation resource requirements
calculate_implementation_resource_requirements() {
  local execution_context="$1"

  local execution_phases=$(echo "$execution_context" | jq '.execution_phases')
  local total_phases=$(echo "$execution_phases" | jq '. | length')
  local total_tasks=$(echo "$execution_phases" | jq '[.[].task_count] | add')

  # Base resource calculation
  local cpu_requirement=$(echo "$total_tasks / 5 + 1" | bc)
  local memory_requirement=$(echo "$total_tasks / 3 + 2" | bc)
  local agent_requirement=$(echo "$total_phases / 2 + 1" | bc)

  local requirements="{
    \"cpu_cores\": $cpu_requirement,
    \"memory_gb\": $memory_requirement,
    \"agents\": $agent_requirement,
    \"estimated_duration\": \"$(estimate_implementation_duration "$execution_context")\",
    \"priority\": \"medium\"
  }"

  echo "$requirements"
}

# Generate implementation summary
generate_implementation_summary() {
  local execution_context="$1"

  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')
  local plan_file=$(echo "$execution_context" | jq -r '.plan_file')

  # Load final progress data
  local final_progress=$(load_progress_tracking "$execution_id")

  # Create implementation summary
  local summary="{
    \"execution_id\": \"$execution_id\",
    \"plan_file\": \"$plan_file\",
    \"execution_summary\": $final_progress,
    \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"total_execution_time\": \"$(calculate_total_execution_time "$execution_id")\"
  }"

  # Store summary
  local summary_file="/tmp/implementation_summaries/${execution_id}_summary.json"
  mkdir -p "$(dirname "$summary_file")"
  echo "$summary" > "$summary_file"

  log_info "Implementation summary generated: $summary_file"
}

# Finalize implementation
finalize_implementation() {
  local execution_context="$1"
  local orchestration_mode="$2"

  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')

  # Orchestration cleanup
  if [[ "$orchestration_mode" == "orchestrated" ]]; then
    # Notify completion
    coordinate_with_hub "complete-workflow" "{
      \"workflow_id\": \"$execution_id\",
      \"status\": \"completed\",
      \"completion_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }"

    # Release resources
    coordinate_with_resource_manager "release" "{
      \"workflow_id\": \"$execution_id\",
      \"resource_type\": \"implementation\"
    }"
  fi

  # Cleanup temporary files
  cleanup_execution_artifacts "$execution_id"

  log_info "Implementation finalized successfully"
}
```

## Git Integration and Commit Management

```bash
# Create structured git commits for phases
create_phase_commit() {
  local execution_id="$1"
  local phase_number="$2"
  local phase_result="$3"

  local phase_title=$(echo "$phase_result" | jq -r '.phase_title // "Phase ' + $phase_number + '"')
  local completed_tasks=$(echo "$phase_result" | jq '.completed_tasks')
  local total_tasks=$(echo "$phase_result" | jq '.total_tasks')

  # Create structured commit message
  local commit_message="feat: implement $phase_title

- Completed $completed_tasks of $total_tasks tasks
- Phase execution time: $(echo "$phase_result" | jq -r '.execution_time')
- Implementation validated and tested

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

  # Stage changes and commit
  git add .
  git commit -m "$commit_message"

  log_info "Phase $phase_number committed successfully"
}
```

## Status and Progress Reporting

```bash
# Report implementation progress
report_implementation_progress() {
  local execution_id="$1"

  local current_progress=$(load_progress_tracking "$execution_id")
  local overall_progress=$(echo "$current_progress" | jq '.overall_progress')

  local progress_report="{
    \"execution_id\": \"$execution_id\",
    \"overall_progress\": $overall_progress,
    \"phase_details\": $(echo "$current_progress" | jq '.phase_progress'),
    \"reported_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  echo "$progress_report"
}
```

The implementation system provides:

- **Intelligent Plan Detection**: Auto-resume from most recent incomplete plan
- **Dual Execution Modes**: Standalone and orchestrated execution
- **Comprehensive Testing**: Automated test execution and validation
- **Progress Tracking**: Real-time progress monitoring and reporting
- **Error Recovery**: Robust error handling with recovery options
- **Git Integration**: Structured commits with implementation tracking
- **Resource Management**: Intelligent resource allocation in orchestrated mode

Execute with `/implement [plan-file] [starting-phase] [--orchestrated]` to begin systematic implementation.