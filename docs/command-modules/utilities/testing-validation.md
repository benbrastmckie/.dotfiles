# Testing and Validation Framework

## Purpose
Comprehensive testing and validation framework for implementation verification with automated test execution and reporting.

## Usage
```markdown
{{module:utilities/testing-validation.md}}
```

## Test Execution Engine

### 1. Automated Test Execution

```bash
# Execute comprehensive test suite for implementation
execute_implementation_tests() {
  local execution_context="$1"
  local test_scope="${2:-all}"
  local test_options="$3"

  log_info "Executing implementation tests with scope: $test_scope"

  # Extract context information
  local execution_id=$(echo "$execution_context" | jq -r '.execution_id')
  local working_directory=$(echo "$execution_context" | jq -r '.working_directory')

  # Initialize test environment
  initialize_test_environment "$working_directory" "$test_options"

  # Execute tests based on scope
  local test_results
  case "$test_scope" in
    "all")
      test_results=$(execute_all_tests "$execution_context" "$test_options")
      ;;
    "unit")
      test_results=$(execute_unit_tests "$execution_context" "$test_options")
      ;;
    "integration")
      test_results=$(execute_integration_tests "$execution_context" "$test_options")
      ;;
    "validation")
      test_results=$(execute_validation_tests "$execution_context" "$test_options")
      ;;
    "smoke")
      test_results=$(execute_smoke_tests "$execution_context" "$test_options")
      ;;
    *)
      log_error "Unknown test scope: $test_scope"
      return 1
      ;;
  esac

  # Generate test report
  generate_test_report "$execution_id" "$test_results" "$test_scope"

  echo "$test_results"
}

# Execute all available tests
execute_all_tests() {
  local execution_context="$1"
  local test_options="$2"

  local all_test_results="{
    \"test_suites\": [],
    \"overall_success\": true,
    \"total_tests\": 0,
    \"passed_tests\": 0,
    \"failed_tests\": 0,
    \"execution_time\": 0
  }"

  # Execute different test types in sequence
  local test_types=("unit" "integration" "validation" "smoke")

  for test_type in "${test_types[@]}"; do
    log_info "Executing $test_type tests"

    local test_suite_result=$(execute_test_suite "$test_type" "$execution_context" "$test_options")
    all_test_results=$(echo "$all_test_results" | jq ".test_suites += [$test_suite_result]")

    # Update overall statistics
    local suite_success=$(echo "$test_suite_result" | jq -r '.success')
    local suite_total=$(echo "$test_suite_result" | jq '.total_tests')
    local suite_passed=$(echo "$test_suite_result" | jq '.passed_tests')
    local suite_failed=$(echo "$test_suite_result" | jq '.failed_tests')
    local suite_time=$(echo "$test_suite_result" | jq '.execution_time')

    all_test_results=$(echo "$all_test_results" | jq "
      .total_tests += $suite_total |
      .passed_tests += $suite_passed |
      .failed_tests += $suite_failed |
      .execution_time += $suite_time |
      .overall_success = (.overall_success and $suite_success)
    ")
  done

  echo "$all_test_results"
}
```

### 2. Test Suite Execution

```bash
# Execute specific test suite
execute_test_suite() {
  local test_type="$1"
  local execution_context="$2"
  local test_options="$3"

  local working_directory=$(echo "$execution_context" | jq -r '.working_directory')
  local start_time=$(date +%s)

  log_info "Executing $test_type test suite"

  # Discover tests for this type
  local test_files=$(discover_test_files "$test_type" "$working_directory")
  local test_count=$(echo "$test_files" | jq '. | length')

  if [[ $test_count -eq 0 ]]; then
    log_warning "No $test_type tests found"
    echo "{
      \"test_type\": \"$test_type\",
      \"success\": true,
      \"total_tests\": 0,
      \"passed_tests\": 0,
      \"failed_tests\": 0,
      \"test_results\": [],
      \"execution_time\": 0,
      \"message\": \"No tests found\"
    }"
    return 0
  fi

  # Execute test files
  local test_results="[]"
  local passed_tests=0
  local failed_tests=0

  while IFS= read -r test_file; do
    local file_path=$(echo "$test_file" | jq -r '.file_path')
    local test_command=$(echo "$test_file" | jq -r '.test_command')

    log_debug "Executing test file: $file_path"

    local file_result=$(execute_test_file "$file_path" "$test_command" "$test_options")
    test_results=$(echo "$test_results" | jq ". += [$file_result]")

    # Update counters
    local file_passed=$(echo "$file_result" | jq '.passed_tests')
    local file_failed=$(echo "$file_result" | jq '.failed_tests')

    passed_tests=$((passed_tests + file_passed))
    failed_tests=$((failed_tests + file_failed))

  done < <(echo "$test_files" | jq -c '.[]')

  # Calculate execution time
  local end_time=$(date +%s)
  local execution_time=$((end_time - start_time))

  # Determine overall success
  local suite_success=true
  if [[ $failed_tests -gt 0 ]]; then
    suite_success=false
  fi

  local suite_result="{
    \"test_type\": \"$test_type\",
    \"success\": $suite_success,
    \"total_tests\": $((passed_tests + failed_tests)),
    \"passed_tests\": $passed_tests,
    \"failed_tests\": $failed_tests,
    \"test_results\": $test_results,
    \"execution_time\": $execution_time
  }"

  echo "$suite_result"
}

# Execute individual test file
execute_test_file() {
  local file_path="$1"
  local test_command="$2"
  local test_options="$3"

  local file_start_time=$(date +%s)

  # Prepare test command with options
  local full_command=$(prepare_test_command "$test_command" "$file_path" "$test_options")

  log_debug "Executing command: $full_command"

  # Execute test command and capture output
  local test_output
  local test_exit_code
  if test_output=$(eval "$full_command" 2>&1); then
    test_exit_code=0
  else
    test_exit_code=$?
  fi

  # Parse test output to extract results
  local parsed_results=$(parse_test_output "$test_output" "$test_exit_code")

  # Calculate execution time
  local file_end_time=$(date +%s)
  local file_execution_time=$((file_end_time - file_start_time))

  local file_result="{
    \"file_path\": \"$file_path\",
    \"test_command\": \"$test_command\",
    \"exit_code\": $test_exit_code,
    \"execution_time\": $file_execution_time,
    \"output\": \"$(echo "$test_output" | jq -R -s .)\",
    \"parsed_results\": $parsed_results,
    \"passed_tests\": $(echo "$parsed_results" | jq '.passed_tests'),
    \"failed_tests\": $(echo "$parsed_results" | jq '.failed_tests')
  }"

  echo "$file_result"
}
```

## Test Discovery and Configuration

### 1. Test File Discovery

```bash
# Discover test files for specific test type
discover_test_files() {
  local test_type="$1"
  local working_directory="$2"

  local test_files="[]"

  case "$test_type" in
    "unit")
      test_files=$(discover_unit_test_files "$working_directory")
      ;;
    "integration")
      test_files=$(discover_integration_test_files "$working_directory")
      ;;
    "validation")
      test_files=$(discover_validation_test_files "$working_directory")
      ;;
    "smoke")
      test_files=$(discover_smoke_test_files "$working_directory")
      ;;
  esac

  echo "$test_files"
}

# Discover unit test files
discover_unit_test_files() {
  local working_directory="$1"

  local test_files="[]"

  # Look for common unit test patterns
  local test_patterns=(
    "test_*.py"
    "*_test.py"
    "tests/*.py"
    "test/*.js"
    "*_test.js"
    "*.test.js"
    "test_*.sh"
    "*_test.sh"
  )

  for pattern in "${test_patterns[@]}"; do
    while IFS= read -r -d '' test_file; do
      local relative_path=$(realpath --relative-to="$working_directory" "$test_file")
      local test_command=$(determine_test_command "$test_file")

      local file_entry="{
        \"file_path\": \"$relative_path\",
        \"absolute_path\": \"$test_file\",
        \"test_command\": \"$test_command\",
        \"test_type\": \"unit\"
      }"

      test_files=$(echo "$test_files" | jq ". += [$file_entry]")
    done < <(find "$working_directory" -name "$pattern" -type f -print0 2>/dev/null)
  done

  echo "$test_files"
}

# Determine test command for file
determine_test_command() {
  local test_file="$1"

  local file_extension="${test_file##*.}"
  local file_name=$(basename "$test_file")

  case "$file_extension" in
    "py")
      if command -v pytest >/dev/null 2>&1; then
        echo "pytest"
      elif command -v python >/dev/null 2>&1; then
        echo "python -m unittest"
      else
        echo "python"
      fi
      ;;
    "js")
      if [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1; then
        echo "npm test"
      elif command -v node >/dev/null 2>&1; then
        echo "node"
      else
        echo "echo 'No JavaScript test runner found'"
      fi
      ;;
    "sh")
      echo "bash"
      ;;
    "ts")
      if command -v npm >/dev/null 2>&1; then
        echo "npm run test:ts"
      elif command -v npx >/dev/null 2>&1; then
        echo "npx ts-node"
      else
        echo "echo 'No TypeScript test runner found'"
      fi
      ;;
    *)
      echo "echo 'Unknown test file type'"
      ;;
  esac
}
```

### 2. Test Command Preparation

```bash
# Prepare test command with options and parameters
prepare_test_command() {
  local base_command="$1"
  local file_path="$2"
  local test_options="$3"

  local full_command="$base_command"

  # Add file path if needed
  case "$base_command" in
    "pytest")
      full_command="$base_command \"$file_path\""
      ;;
    "python -m unittest")
      # Convert file path to module path
      local module_path=$(echo "$file_path" | sed 's/\.py$//' | sed 's/\//./g')
      full_command="$base_command $module_path"
      ;;
    "node"|"bash")
      full_command="$base_command \"$file_path\""
      ;;
    "npm test"|"npm run test:ts")
      # Use npm test command as-is
      full_command="$base_command"
      ;;
  esac

  # Add test options
  local verbose=$(echo "$test_options" | jq -r '.verbose // false')
  local coverage=$(echo "$test_options" | jq -r '.coverage // false')

  if [[ "$verbose" == "true" ]]; then
    case "$base_command" in
      "pytest")
        full_command="$full_command -v"
        ;;
      "npm test")
        full_command="$full_command -- --verbose"
        ;;
    esac
  fi

  if [[ "$coverage" == "true" ]]; then
    case "$base_command" in
      "pytest")
        full_command="$full_command --cov"
        ;;
      "npm test")
        full_command="$full_command -- --coverage"
        ;;
    esac
  fi

  echo "$full_command"
}
```

## Test Output Parsing

### 1. Universal Test Output Parser

```bash
# Parse test output to extract results
parse_test_output() {
  local test_output="$1"
  local exit_code="$2"

  # Try different parsing strategies based on output format
  local parsed_results

  if echo "$test_output" | grep -q "pytest"; then
    parsed_results=$(parse_pytest_output "$test_output")
  elif echo "$test_output" | grep -q "TAP version"; then
    parsed_results=$(parse_tap_output "$test_output")
  elif echo "$test_output" | grep -q "PASS\|FAIL"; then
    parsed_results=$(parse_generic_pass_fail_output "$test_output")
  else
    parsed_results=$(parse_exit_code_output "$test_output" "$exit_code")
  fi

  echo "$parsed_results"
}

# Parse pytest output
parse_pytest_output() {
  local output="$1"

  # Extract test counts from pytest output
  local passed_tests=0
  local failed_tests=0
  local error_tests=0

  if echo "$output" | grep -q "passed"; then
    passed_tests=$(echo "$output" | grep -o "[0-9]\+ passed" | grep -o "[0-9]\+" || echo "0")
  fi

  if echo "$output" | grep -q "failed"; then
    failed_tests=$(echo "$output" | grep -o "[0-9]\+ failed" | grep -o "[0-9]\+" || echo "0")
  fi

  if echo "$output" | grep -q "error"; then
    error_tests=$(echo "$output" | grep -o "[0-9]\+ error" | grep -o "[0-9]\+" || echo "0")
  fi

  local total_tests=$((passed_tests + failed_tests + error_tests))

  local results="{
    \"parser_type\": \"pytest\",
    \"total_tests\": $total_tests,
    \"passed_tests\": $passed_tests,
    \"failed_tests\": $((failed_tests + error_tests)),
    \"details\": {
      \"passed\": $passed_tests,
      \"failed\": $failed_tests,
      \"errors\": $error_tests
    }
  }"

  echo "$results"
}

# Parse generic pass/fail output
parse_generic_pass_fail_output() {
  local output="$1"

  local passed_tests=$(echo "$output" | grep -c "PASS\|✓\|✔" || echo "0")
  local failed_tests=$(echo "$output" | grep -c "FAIL\|✗\|✘" || echo "0")

  local total_tests=$((passed_tests + failed_tests))

  local results="{
    \"parser_type\": \"generic\",
    \"total_tests\": $total_tests,
    \"passed_tests\": $passed_tests,
    \"failed_tests\": $failed_tests,
    \"details\": {
      \"passed\": $passed_tests,
      \"failed\": $failed_tests
    }
  }"

  echo "$results"
}

# Fallback parser based on exit code
parse_exit_code_output() {
  local output="$1"
  local exit_code="$2"

  local success=1
  local failure=0

  if [[ $exit_code -eq 0 ]]; then
    success=1
    failure=0
  else
    success=0
    failure=1
  fi

  local results="{
    \"parser_type\": \"exit_code\",
    \"total_tests\": 1,
    \"passed_tests\": $success,
    \"failed_tests\": $failure,
    \"details\": {
      \"exit_code\": $exit_code,
      \"inferred_from_exit_code\": true
    }
  }"

  echo "$results"
}
```

## Validation Framework

### 1. Implementation Validation

```bash
# Validate implementation against requirements
validate_implementation() {
  local execution_context="$1"
  local validation_criteria="$2"

  log_info "Validating implementation against criteria"

  local validation_results="{
    \"validation_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"criteria_checks\": [],
    \"overall_valid\": true,
    \"validation_score\": 0
  }"

  # Execute validation checks
  while IFS= read -r criterion; do
    local criterion_type=$(echo "$criterion" | jq -r '.type')
    local criterion_description=$(echo "$criterion" | jq -r '.description')

    log_debug "Validating criterion: $criterion_description"

    local check_result=$(execute_validation_check "$criterion" "$execution_context")
    validation_results=$(echo "$validation_results" | jq ".criteria_checks += [$check_result]")

    # Update overall validation status
    local check_passed=$(echo "$check_result" | jq -r '.passed')
    if [[ "$check_passed" != "true" ]]; then
      validation_results=$(echo "$validation_results" | jq '.overall_valid = false')
    fi

  done < <(echo "$validation_criteria" | jq -c '.[]')

  # Calculate validation score
  local total_checks=$(echo "$validation_results" | jq '.criteria_checks | length')
  local passed_checks=$(echo "$validation_results" | jq '[.criteria_checks[] | select(.passed == true)] | length')

  if [[ $total_checks -gt 0 ]]; then
    local validation_score=$(echo "scale=2; $passed_checks * 100 / $total_checks" | bc)
    validation_results=$(echo "$validation_results" | jq ".validation_score = $validation_score")
  fi

  echo "$validation_results"
}

# Execute individual validation check
execute_validation_check() {
  local criterion="$1"
  local execution_context="$2"

  local criterion_type=$(echo "$criterion" | jq -r '.type')
  local check_start_time=$(date +%s)

  local check_result
  case "$criterion_type" in
    "file_exists")
      check_result=$(validate_file_exists "$criterion")
      ;;
    "function_exists")
      check_result=$(validate_function_exists "$criterion")
      ;;
    "configuration_valid")
      check_result=$(validate_configuration "$criterion")
      ;;
    "performance_benchmark")
      check_result=$(validate_performance_benchmark "$criterion")
      ;;
    "security_check")
      check_result=$(validate_security_requirements "$criterion")
      ;;
    *)
      check_result=$(validate_custom_criterion "$criterion")
      ;;
  esac

  # Add timing and metadata
  local check_end_time=$(date +%s)
  local check_duration=$((check_end_time - check_start_time))

  check_result=$(echo "$check_result" | jq ". + {
    \"criterion\": $criterion,
    \"execution_time\": $check_duration,
    \"validated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }")

  echo "$check_result"
}
```

## Test Reporting

### 1. Comprehensive Test Report Generation

```bash
# Generate comprehensive test report
generate_test_report() {
  local execution_id="$1"
  local test_results="$2"
  local test_scope="$3"

  local report_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local report_file="/tmp/test_reports/${execution_id}_${test_scope}_report.json"

  # Ensure report directory exists
  mkdir -p "$(dirname "$report_file")"

  # Create comprehensive report
  local test_report="{
    \"execution_id\": \"$execution_id\",
    \"test_scope\": \"$test_scope\",
    \"generated_at\": \"$report_timestamp\",
    \"test_results\": $test_results,
    \"summary\": $(generate_test_summary "$test_results"),
    \"recommendations\": $(generate_test_recommendations "$test_results")
  }"

  # Write report to file
  echo "$test_report" > "$report_file"

  log_info "Test report generated: $report_file"

  echo "$test_report"
}

# Generate test summary
generate_test_summary() {
  local test_results="$1"

  # Extract overall statistics
  local overall_success=$(echo "$test_results" | jq -r '.overall_success')
  local total_tests=$(echo "$test_results" | jq '.total_tests')
  local passed_tests=$(echo "$test_results" | jq '.passed_tests')
  local failed_tests=$(echo "$test_results" | jq '.failed_tests')
  local execution_time=$(echo "$test_results" | jq '.execution_time')

  # Calculate success rate
  local success_rate=0
  if [[ $total_tests -gt 0 ]]; then
    success_rate=$(echo "scale=2; $passed_tests * 100 / $total_tests" | bc)
  fi

  local summary="{
    \"overall_success\": $overall_success,
    \"total_tests\": $total_tests,
    \"passed_tests\": $passed_tests,
    \"failed_tests\": $failed_tests,
    \"success_rate\": $success_rate,
    \"total_execution_time\": $execution_time,
    \"average_test_time\": $(echo "scale=2; $execution_time / $total_tests" | bc 2>/dev/null || echo "0")
  }"

  echo "$summary"
}
```

## Utility Functions

```bash
# Initialize test environment
initialize_test_environment() {
  local working_directory="$1"
  local test_options="$2"

  # Change to working directory
  cd "$working_directory" || {
    log_error "Failed to change to working directory: $working_directory"
    return 1
  }

  # Set up test environment variables
  export TEST_ENV="automated"
  export TEST_EXECUTION_MODE="implementation_validation"

  # Initialize test databases or fixtures if needed
  local setup_required=$(echo "$test_options" | jq -r '.setup_required // false')
  if [[ "$setup_required" == "true" ]]; then
    setup_test_fixtures "$test_options"
  fi

  log_debug "Test environment initialized in: $working_directory"
}

# Setup test fixtures
setup_test_fixtures() {
  local test_options="$1"

  local fixture_commands=$(echo "$test_options" | jq -r '.fixture_commands[]?' 2>/dev/null)

  if [[ -n "$fixture_commands" ]]; then
    while IFS= read -r command; do
      log_debug "Setting up test fixture: $command"
      eval "$command"
    done <<< "$fixture_commands"
  fi
}
```