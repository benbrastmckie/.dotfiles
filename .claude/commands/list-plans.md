---
allowed-tools: SlashCommand, Read, Write, TodoWrite
argument-hint: "[search-pattern] [--json] [--orchestration-ready] [--workflow-context=<workflow-id>]"
description: "List all implementation plans in the codebase"
command-type: dependent
dependent-commands: implement
---

# List Implementation Plans

I'll find and list all implementation plans across the codebase.

## Arguments
- `search-pattern` (optional): Filter plans by pattern
- `--json`: Output in machine-readable JSON format
- `--orchestration-ready`: Filter to show only orchestration-compatible plans
- `--workflow-context=<workflow-id>`: Filter plans by workflow context

## Process

I'll search for all plans in `specs/plans/` directories and provide:

### 1. Plan Inventory
- Location of each plan
- Plan number and title
- Creation date
- Implementation status (if trackable)
- Number of phases
- Orchestration compatibility status
- Resource requirements assessment
- Workflow context associations

### 2. Organization
- Group by directory/module
- Sort by number (chronological order)
- Show completion status where available
- Highlight plans matching search pattern

### 3. Summary Statistics
- Total number of plans
- Plans by status (pending, in-progress, completed)
- Most recent plans
- Module coverage
- Orchestration readiness metrics
- Cross-workflow dependencies
- Integration complexity assessment

### 4. Quick Access
For each plan, I'll show:
- Full path for easy access
- Brief description from overview
- Phase count and complexity
- `/implement` command to execute
- Orchestration metadata and compatibility flags
- Workflow integration recommendations

### 5. Orchestration Features
When orchestration flags are used:
- **JSON Output**: Machine-readable format for automation
- **Readiness Assessment**: Compatibility with parallel execution
- **Workflow Context**: Plans tagged for specific workflows
- **Dependency Analysis**: Cross-plan dependencies and conflicts
- **Resource Planning**: Memory, CPU, and tool requirements

Let me search for all implementation plans in your codebase.