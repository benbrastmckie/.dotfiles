# Workflow Analysis Engine

## Purpose
Comprehensive workflow analysis and planning capabilities for intelligent orchestration of multi-agent development workflows.

## Usage
```markdown
{{module:orchestration/workflow-analysis.md}}
```

## Workflow Classification and Analysis

### 1. Workflow Type Analysis

```bash
# Analyze workflow description to determine type and requirements
analyze_workflow_description() {
  local workflow_description="$1"
  local analysis_options="${2:-{}}"

  log_info "Analyzing workflow description for orchestration planning"

  # Extract workflow characteristics
  local workflow_keywords=$(extract_workflow_keywords "$workflow_description")
  local complexity_indicators=$(identify_complexity_indicators "$workflow_description")
  local domain_requirements=$(identify_domain_requirements "$workflow_description")

  # Determine workflow type
  local workflow_type=$(classify_workflow_type "$workflow_keywords" "$complexity_indicators")

  # Assess complexity and resource requirements
  local complexity_assessment=$(assess_workflow_complexity "$workflow_description" "$complexity_indicators")
  local resource_requirements=$(estimate_workflow_resources "$workflow_type" "$complexity_assessment")

  # Identify required phases
  local required_phases=$(determine_required_phases "$workflow_type" "$workflow_description")

  # Analyze dependencies and constraints
  local dependency_analysis=$(analyze_workflow_dependencies "$workflow_description" "$required_phases")

  local analysis_result="{
    \"workflow_type\": \"$workflow_type\",
    \"complexity_assessment\": $complexity_assessment,
    \"resource_requirements\": $resource_requirements,
    \"required_phases\": $required_phases,
    \"dependency_analysis\": $dependency_analysis,
    \"domain_requirements\": $domain_requirements,
    \"parallelization_potential\": \"$(assess_parallelization_potential "$required_phases" "$dependency_analysis")\",
    \"estimated_duration\": \"$(estimate_workflow_duration "$workflow_type" "$complexity_assessment" "$required_phases")\",
    \"analyzed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }"

  echo "$analysis_result"
}

# Classify workflow type based on keywords and indicators
classify_workflow_type() {
  local keywords="$1"
  local complexity_indicators="$2"

  # Check for feature development patterns
  if echo "$keywords" | grep -qi "implement\|feature\|develop\|build\|create"; then
    if echo "$keywords" | grep -qi "api\|endpoint\|service"; then
      echo "api_development"
    elif echo "$keywords" | grep -qi "ui\|interface\|frontend"; then
      echo "frontend_development"
    elif echo "$keywords" | grep -qi "database\|schema\|migration"; then
      echo "database_development"
    else
      echo "feature_development"
    fi
  # Check for bug fix patterns
  elif echo "$keywords" | grep -qi "fix\|bug\|issue\|problem\|resolve"; then
    echo "bug_fix"
  # Check for research patterns
  elif echo "$keywords" | grep -qi "research\|investigate\|analyze\|study\|explore"; then
    echo "research_project"
  # Check for documentation patterns
  elif echo "$keywords" | grep -qi "document\|readme\|guide\|manual"; then
    echo "documentation_update"
  # Check for testing patterns
  elif echo "$keywords" | grep -qi "test\|testing\|coverage\|validation"; then
    echo "testing_project"
  # Check for refactoring patterns
  elif echo "$keywords" | grep -qi "refactor\|cleanup\|optimize\|improve"; then
    echo "refactoring_project"
  else
    echo "general_development"
  fi
}

# Assess workflow complexity
assess_workflow_complexity() {
  local workflow_description="$1"
  local complexity_indicators="$2"

  local base_complexity=1.0
  local complexity_score=$base_complexity

  # Analyze complexity factors
  local word_count=$(echo "$workflow_description" | wc -w)
  local technical_terms=$(echo "$complexity_indicators" | jq '.technical_terms | length')
  local integration_points=$(echo "$complexity_indicators" | jq '.integration_points | length')
  local risk_factors=$(echo "$complexity_indicators" | jq '.risk_factors | length')

  # Adjust complexity based on description length
  if [[ $word_count -gt 100 ]]; then
    complexity_score=$(echo "$complexity_score + 0.5" | bc)
  fi

  # Adjust for technical complexity
  if [[ $technical_terms -gt 5 ]]; then
    complexity_score=$(echo "$complexity_score + 0.3" | bc)
  fi

  # Adjust for integration complexity
  if [[ $integration_points -gt 2 ]]; then
    complexity_score=$(echo "$complexity_score + 0.4" | bc)
  fi

  # Adjust for risk factors
  if [[ $risk_factors -gt 1 ]]; then
    complexity_score=$(echo "$complexity_score + 0.2" | bc)
  fi

  # Determine complexity level
  local complexity_level
  if (( $(echo "$complexity_score <= 1.5" | bc -l) )); then
    complexity_level="low"
  elif (( $(echo "$complexity_score <= 2.5" | bc -l) )); then
    complexity_level="medium"
  elif (( $(echo "$complexity_score <= 3.5" | bc -l) )); then
    complexity_level="high"
  else
    complexity_level="very_high"
  fi

  local assessment="{
    \"complexity_score\": $complexity_score,
    \"complexity_level\": \"$complexity_level\",
    \"factors\": {
      \"description_length\": $word_count,
      \"technical_terms\": $technical_terms,
      \"integration_points\": $integration_points,
      \"risk_factors\": $risk_factors
    }
  }"

  echo "$assessment"
}
```

### 2. Phase Requirement Analysis

```bash
# Determine required phases for workflow type
determine_required_phases() {
  local workflow_type="$1"
  local workflow_description="$2"

  local base_phases
  case "$workflow_type" in
    "feature_development"|"api_development"|"frontend_development"|"database_development")
      base_phases='["research", "planning", "implementation", "testing", "documentation"]'
      ;;
    "bug_fix")
      base_phases='["research", "diagnosis", "implementation", "testing"]'
      ;;
    "research_project")
      base_phases='["research", "analysis", "documentation"]'
      ;;
    "documentation_update")
      base_phases='["planning", "documentation", "review"]'
      ;;
    "testing_project")
      base_phases='["planning", "implementation", "testing", "analysis"]'
      ;;
    "refactoring_project")
      base_phases='["analysis", "planning", "implementation", "testing", "validation"]'
      ;;
    *)
      base_phases='["research", "planning", "implementation", "testing", "documentation"]'
      ;;
  esac

  # Analyze description for additional phase requirements
  local additional_phases="[]"

  if echo "$workflow_description" | grep -qi "deploy\|deployment\|release"; then
    additional_phases=$(echo "$additional_phases" | jq '. += ["deployment"]')
  fi

  if echo "$workflow_description" | grep -qi "monitor\|monitoring\|metrics"; then
    additional_phases=$(echo "$additional_phases" | jq '. += ["monitoring"]')
  fi

  if echo "$workflow_description" | grep -qi "migration\|upgrade\|transition"; then
    additional_phases=$(echo "$additional_phases" | jq '. += ["migration"]')
  fi

  # Combine base and additional phases
  local all_phases=$(echo "$base_phases $additional_phases" | jq -s 'add | unique')

  echo "$all_phases"
}

# Analyze workflow dependencies
analyze_workflow_dependencies() {
  local workflow_description="$1"
  local required_phases="$2"

  local dependencies="{
    \"external_dependencies\": [],
    \"phase_dependencies\": [],
    \"resource_dependencies\": [],
    \"knowledge_dependencies\": []
  }"

  # Identify external dependencies
  local external_deps=$(identify_external_dependencies "$workflow_description")
  dependencies=$(echo "$dependencies" | jq ".external_dependencies = $external_deps")

  # Analyze phase dependencies
  local phase_deps=$(analyze_phase_dependencies "$required_phases")
  dependencies=$(echo "$dependencies" | jq ".phase_dependencies = $phase_deps")

  # Identify resource dependencies
  local resource_deps=$(identify_resource_dependencies "$workflow_description")
  dependencies=$(echo "$dependencies" | jq ".resource_dependencies = $resource_deps")

  # Identify knowledge dependencies
  local knowledge_deps=$(identify_knowledge_dependencies "$workflow_description")
  dependencies=$(echo "$dependencies" | jq ".knowledge_dependencies = $knowledge_deps")

  echo "$dependencies"
}
```

## Resource Estimation and Planning

### 1. Resource Requirement Estimation

```bash
# Estimate workflow resource requirements
estimate_workflow_resources() {
  local workflow_type="$1"
  local complexity_assessment="$2"

  local complexity_score=$(echo "$complexity_assessment" | jq '.complexity_score')
  local complexity_level=$(echo "$complexity_assessment" | jq -r '.complexity_level')

  # Base resource requirements by workflow type
  local base_resources
  case "$workflow_type" in
    "feature_development"|"api_development")
      base_resources='{
        "agents": 3,
        "cpu_cores": 4,
        "memory_gb": 8,
        "storage_gb": 20
      }'
      ;;
    "frontend_development")
      base_resources='{
        "agents": 2,
        "cpu_cores": 3,
        "memory_gb": 6,
        "storage_gb": 15
      }'
      ;;
    "database_development")
      base_resources='{
        "agents": 2,
        "cpu_cores": 3,
        "memory_gb": 8,
        "storage_gb": 25
      }'
      ;;
    "bug_fix")
      base_resources='{
        "agents": 1,
        "cpu_cores": 2,
        "memory_gb": 4,
        "storage_gb": 10
      }'
      ;;
    "research_project")
      base_resources='{
        "agents": 1,
        "cpu_cores": 2,
        "memory_gb": 4,
        "storage_gb": 5
      }'
      ;;
    *)
      base_resources='{
        "agents": 2,
        "cpu_cores": 3,
        "memory_gb": 6,
        "storage_gb": 15
      }'
      ;;
  esac

  # Apply complexity multiplier
  local complexity_multiplier
  case "$complexity_level" in
    "low") complexity_multiplier=1.0 ;;
    "medium") complexity_multiplier=1.5 ;;
    "high") complexity_multiplier=2.0 ;;
    "very_high") complexity_multiplier=2.5 ;;
    *) complexity_multiplier=1.0 ;;
  esac

  # Calculate adjusted resources
  local agents=$(echo "$base_resources" | jq ".agents * $complexity_multiplier" | jq 'floor')
  local cpu_cores=$(echo "$base_resources" | jq ".cpu_cores * $complexity_multiplier" | jq 'floor')
  local memory_gb=$(echo "$base_resources" | jq ".memory_gb * $complexity_multiplier" | jq 'floor')
  local storage_gb=$(echo "$base_resources" | jq ".storage_gb * $complexity_multiplier" | jq 'floor')

  local resource_requirements="{
    \"agents\": $agents,
    \"cpu_cores\": $cpu_cores,
    \"memory_gb\": $memory_gb,
    \"storage_gb\": $storage_gb,
    \"complexity_multiplier\": $complexity_multiplier,
    \"estimated_for\": \"$workflow_type\",
    \"complexity_level\": \"$complexity_level\"
  }"

  echo "$resource_requirements"
}

# Estimate workflow duration
estimate_workflow_duration() {
  local workflow_type="$1"
  local complexity_assessment="$2"
  local required_phases="$3"

  local complexity_score=$(echo "$complexity_assessment" | jq '.complexity_score')
  local phase_count=$(echo "$required_phases" | jq '. | length')

  # Base duration by workflow type (in hours)
  local base_duration
  case "$workflow_type" in
    "feature_development"|"api_development") base_duration=24 ;;
    "frontend_development") base_duration=20 ;;
    "database_development") base_duration=18 ;;
    "bug_fix") base_duration=8 ;;
    "research_project") base_duration=12 ;;
    "documentation_update") base_duration=6 ;;
    "testing_project") base_duration=16 ;;
    "refactoring_project") base_duration=20 ;;
    *) base_duration=16 ;;
  esac

  # Adjust for complexity and phase count
  local adjusted_duration=$(echo "$base_duration * $complexity_score * ($phase_count / 4)" | bc)

  # Convert to human-readable format
  local duration_hours=$(echo "$adjusted_duration" | jq 'floor')
  local duration_days=$(echo "$duration_hours / 8" | bc)

  local duration_estimate="{
    \"hours\": $duration_hours,
    \"days\": $duration_days,
    \"human_readable\": \"$(format_duration "$duration_hours")\",
    \"base_duration\": $base_duration,
    \"complexity_factor\": $complexity_score,
    \"phase_factor\": $(echo "$phase_count / 4" | bc -l)
  }"

  echo "$duration_estimate"
}
```

## Parallelization Analysis

### 1. Parallelization Potential Assessment

```bash
# Assess parallelization potential for workflow
assess_parallelization_potential() {
  local required_phases="$1"
  local dependency_analysis="$2"

  local phase_dependencies=$(echo "$dependency_analysis" | jq '.phase_dependencies')
  local parallelizable_phases="[]"
  local sequential_phases="[]"

  # Analyze each phase for parallelization potential
  while IFS= read -r phase; do
    local phase_name=$(echo "$phase" | jq -r '.')
    local has_dependencies=$(check_phase_dependencies "$phase_name" "$phase_dependencies")

    if [[ "$has_dependencies" == "false" ]]; then
      parallelizable_phases=$(echo "$parallelizable_phases" | jq ". += [\"$phase_name\"]")
    else
      sequential_phases=$(echo "$sequential_phases" | jq ". += [\"$phase_name\"]")
    fi
  done < <(echo "$required_phases" | jq -c '.[]')

  # Calculate parallelization score
  local total_phases=$(echo "$required_phases" | jq '. | length')
  local parallel_phases=$(echo "$parallelizable_phases" | jq '. | length')
  local parallelization_score=0

  if [[ $total_phases -gt 0 ]]; then
    parallelization_score=$(echo "scale=2; $parallel_phases * 100 / $total_phases" | bc)
  fi

  # Determine parallelization level
  local parallelization_level
  if (( $(echo "$parallelization_score >= 70" | bc -l) )); then
    parallelization_level="high"
  elif (( $(echo "$parallelization_score >= 40" | bc -l) )); then
    parallelization_level="medium"
  else
    parallelization_level="low"
  fi

  local potential_assessment="{
    \"parallelization_score\": $parallelization_score,
    \"parallelization_level\": \"$parallelization_level\",
    \"parallelizable_phases\": $parallelizable_phases,
    \"sequential_phases\": $sequential_phases,
    \"total_phases\": $total_phases,
    \"parallel_phases\": $parallel_phases
  }"

  echo "$potential_assessment"
}

# Check if phase has dependencies
check_phase_dependencies() {
  local phase_name="$1"
  local phase_dependencies="$2"

  # Check if this phase appears as a dependent in any dependency relationship
  local dependency_count=$(echo "$phase_dependencies" | jq --arg phase "$phase_name" '
    map(select(.dependent_phase == $phase)) | length
  ')

  if [[ $dependency_count -gt 0 ]]; then
    echo "true"
  else
    echo "false"
  fi
}
```

## Workflow Optimization

### 1. Workflow Optimization Strategies

```bash
# Generate workflow optimization strategies
generate_optimization_strategies() {
  local workflow_analysis="$1"

  local parallelization_potential=$(echo "$workflow_analysis" | jq '.parallelization_potential')
  local complexity_assessment=$(echo "$workflow_analysis" | jq '.complexity_assessment')
  local resource_requirements=$(echo "$workflow_analysis" | jq '.resource_requirements')

  local optimization_strategies="[]"

  # Parallelization optimizations
  local parallel_level=$(echo "$parallelization_potential" | jq -r '.parallelization_level')
  if [[ "$parallel_level" == "high" || "$parallel_level" == "medium" ]]; then
    local parallel_strategy='{
      "type": "parallelization",
      "description": "Execute independent phases in parallel to reduce overall duration",
      "expected_improvement": "25-40% time reduction",
      "implementation": "phase_parallel_execution"
    }'
    optimization_strategies=$(echo "$optimization_strategies" | jq ". += [$parallel_strategy]")
  fi

  # Resource optimization
  local complexity_level=$(echo "$complexity_assessment" | jq -r '.complexity_level')
  if [[ "$complexity_level" == "high" || "$complexity_level" == "very_high" ]]; then
    local resource_strategy='{
      "type": "resource_scaling",
      "description": "Scale resources dynamically based on phase requirements",
      "expected_improvement": "15-25% efficiency gain",
      "implementation": "dynamic_resource_allocation"
    }'
    optimization_strategies=$(echo "$optimization_strategies" | jq ". += [$resource_strategy]")
  fi

  # Caching optimization
  local caching_strategy='{
    "type": "intelligent_caching",
    "description": "Cache intermediate results and reuse across phases",
    "expected_improvement": "10-20% time reduction",
    "implementation": "workflow_result_caching"
  }'
  optimization_strategies=$(echo "$optimization_strategies" | jq ". += [$caching_strategy]")

  echo "$optimization_strategies"
}
```

## Utility Functions

```bash
# Extract workflow keywords from description
extract_workflow_keywords() {
  local description="$1"

  # Convert to lowercase and extract meaningful words
  local keywords=$(echo "$description" | tr '[:upper:]' '[:lower:]' | \
    grep -oE '\b[a-z]{3,}\b' | \
    grep -v -E '^(the|and|for|with|this|that|from|have|will|can|may)$' | \
    sort | uniq)

  # Convert to JSON array
  local keywords_json="[]"
  while IFS= read -r keyword; do
    if [[ -n "$keyword" ]]; then
      keywords_json=$(echo "$keywords_json" | jq ". += [\"$keyword\"]")
    fi
  done <<< "$keywords"

  echo "$keywords_json"
}

# Identify complexity indicators
identify_complexity_indicators() {
  local description="$1"

  local technical_terms="[]"
  local integration_points="[]"
  local risk_factors="[]"

  # Identify technical terms
  local tech_patterns=("api" "database" "algorithm" "architecture" "framework" "library" "service" "microservice")
  for pattern in "${tech_patterns[@]}"; do
    if echo "$description" | grep -qi "$pattern"; then
      technical_terms=$(echo "$technical_terms" | jq ". += [\"$pattern\"]")
    fi
  done

  # Identify integration points
  local integration_patterns=("integrate" "connect" "sync" "webhook" "oauth" "sso" "external")
  for pattern in "${integration_patterns[@]}"; do
    if echo "$description" | grep -qi "$pattern"; then
      integration_points=$(echo "$integration_points" | jq ". += [\"$pattern\"]")
    fi
  done

  # Identify risk factors
  local risk_patterns=("legacy" "deprecated" "experimental" "beta" "migration" "breaking")
  for pattern in "${risk_patterns[@]}"; do
    if echo "$description" | grep -qi "$pattern"; then
      risk_factors=$(echo "$risk_factors" | jq ". += [\"$pattern\"]")
    fi
  done

  local indicators="{
    \"technical_terms\": $technical_terms,
    \"integration_points\": $integration_points,
    \"risk_factors\": $risk_factors
  }"

  echo "$indicators"
}

# Format duration in human-readable format
format_duration() {
  local hours="$1"

  if [[ $hours -lt 1 ]]; then
    echo "Less than 1 hour"
  elif [[ $hours -eq 1 ]]; then
    echo "1 hour"
  elif [[ $hours -lt 8 ]]; then
    echo "$hours hours"
  elif [[ $hours -eq 8 ]]; then
    echo "1 day"
  else
    local days=$(echo "$hours / 8" | bc)
    local remaining_hours=$(echo "$hours % 8" | bc)

    if [[ $remaining_hours -eq 0 ]]; then
      echo "$days days"
    else
      echo "$days days, $remaining_hours hours"
    fi
  fi
}
```