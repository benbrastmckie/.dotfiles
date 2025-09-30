# Orchestration Command YAML Template

## Purpose
Standard YAML frontmatter template for orchestration commands that coordinate multiple workflows and manage complex operations.

## Usage
```markdown
{{template:orchestration_yaml:command-name,description,dependent-commands}}
```

## Template

```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob
argument-hint: "\"<workflow-description>\" [--dry-run] [--template=<template-name>] [--priority=<high|medium|low>]"
description: "{description}"
command-type: orchestration
dependent-commands: coordination-hub, resource-manager, workflow-status, performance-monitor, workflow-recovery, progress-aggregator, dependency-resolver, {dependent-commands}
---
```

## Parameters
- `command-name`: Name of the command
- `description`: Brief description of command functionality
- `dependent-commands`: Comma-separated list of additional dependent commands

## Standard Dependencies
Orchestration commands automatically include these dependencies:
- `coordination-hub`: Central coordination and state management
- `resource-manager`: Resource allocation and management
- `workflow-status`: Status tracking and reporting
- `performance-monitor`: Performance monitoring and optimization
- `workflow-recovery`: Recovery and rollback capabilities
- `progress-aggregator`: Progress tracking across phases
- `dependency-resolver`: Dependency analysis and resolution

## Example Usage

```markdown
{{template:orchestration_yaml:orchestrate,Multi-agent workflow orchestration for complete research → planning → implementation workflows,report,plan,implement,debug,refactor,document,test,test-all,subagents}}
```

Results in:
```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob
argument-hint: "\"<workflow-description>\" [--dry-run] [--template=<template-name>] [--priority=<high|medium|low>]"
description: "Multi-agent workflow orchestration for complete research → planning → implementation workflows"
command-type: orchestration
dependent-commands: coordination-hub, resource-manager, workflow-status, performance-monitor, workflow-recovery, progress-aggregator, dependency-resolver, report, plan, implement, debug, refactor, document, test, test-all, subagents
---
```