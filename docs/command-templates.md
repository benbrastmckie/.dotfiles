# Command Type Templates

This document defines formal YAML frontmatter templates for all command types in the orchestration ecosystem.

## Template Standards

All command files must follow these standardized templates for consistent metadata and integration.

### Field Ordering
All commands must maintain this exact field order:
1. `allowed-tools`
2. `argument-hint`
3. `description`
4. `command-type`
5. `dependent-commands`

### Field Requirements

#### allowed-tools
- Array format: `tool1, tool2, tool3`
- Core tools for all commands: `SlashCommand, TodoWrite, Read, Write`
- Additional tools by command type (see templates below)

#### argument-hint
- String format with exact parameter placeholders
- Use angle brackets for required: `<required-param>`
- Use square brackets for optional: `[optional-param]`
- Include common flags and options

#### description
- Single line, descriptive but concise
- Follow command-type specific patterns (see templates below)
- End with relevant context or purpose

#### command-type
- One of: `orchestration`, `primary`, `utility`, `dependent`
- Must match template classification

#### dependent-commands
- Comma-separated list of related commands
- Include commands this command depends on or coordinates with
- Order by importance/frequency of use

## Command Type Templates

### Orchestration Template

Commands that coordinate complete multi-agent workflows.

```yaml
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob
argument-hint: "\"<workflow-description>\" [--dry-run] [--template=<template-name>] [--priority=<high|medium|low>]"
description: "Multi-agent workflow orchestration for complete [workflow-type] workflows"
command-type: orchestration
dependent-commands: coordination-hub, resource-manager, workflow-status, [relevant-primary-commands], subagents
```

**Pattern Notes:**
- **allowed-tools**: Core tools + Bash + search tools for comprehensive coordination
- **argument-hint**: Workflow description + orchestration flags
- **description**: Must include "Multi-agent workflow orchestration for complete"
- **dependent-commands**: Infrastructure commands first, then primary commands, then utilities

### Primary Template

Commands that perform core development tasks and can be orchestrated.

```yaml
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, [task-specific-tools]
argument-hint: "\"<primary-argument>\" [report-path1] [report-path2] ... [--orchestrated]"
description: "[Action] [target] following project standards, optionally guided by [context]"
command-type: primary
dependent-commands: [dependent-commands], [utility-commands], [related-primary-commands]
```

**Pattern Notes:**
- **allowed-tools**: Core tools + search tools + task-specific tools (Task, Edit, etc.)
- **argument-hint**: Primary argument + optional report paths + orchestration flag
- **description**: Action verb + target + "following project standards" + optional guidance
- **dependent-commands**: Mix of dependent, utility, and related primary commands

**Action Verbs by Command:**
- `implement`: "Execute implementation plan"
- `plan`: "Create detailed implementation plan"
- `report`: "Research topic and create comprehensive report"
- `debug`: "Investigate issues and create diagnostic report"
- `refactor`: "Analyze code for refactoring opportunities"
- `test`: "Run project-specific tests"
- `document`: "Update all relevant documentation"
- `cleanup`: "Cleanup and optimize CLAUDE.md"
- `revise`: "Revise implementation plan"
- `setup`: "Setup or improve CLAUDE.md"

### Utility Template

Commands that provide services for orchestration workflows.

```yaml
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: "\"<utility-context>\" [--options]"
description: "[Service] for [purpose] in orchestration workflows"
command-type: utility
dependent-commands: [core-infrastructure], [related-utilities]
```

**Pattern Notes:**
- **allowed-tools**: Core tools + Bash for system operations
- **argument-hint**: Context object or identifier + options
- **description**: Service description + "for [purpose] in orchestration workflows"
- **dependent-commands**: Core infrastructure commands first, then related utilities

**Service Descriptions:**
- `coordination-hub`: "Central coordination service"
- `resource-manager`: "Resource allocation and conflict management"
- `subagents`: "Enhanced parallel task execution with cross-workflow coordination"
- `performance-monitor`: "Real-time workflow performance monitoring"
- `workflow-recovery`: "Automated error recovery and workflow restoration"
- `progress-aggregator`: "Cross-workflow progress tracking and aggregation"
- `dependency-resolver`: "Dynamic dependency resolution and workflow ordering"

### Dependent Template

Commands that provide information or list functionality for other commands.

```yaml
allowed-tools: SlashCommand, Read, Write, TodoWrite
argument-hint: "[search-pattern] [--options]"
description: "[Action] [scope] showing [information-type]"
command-type: dependent
dependent-commands: [parent-commands]
```

**Pattern Notes:**
- **allowed-tools**: Minimal toolset - core tools only, no Bash or complex tools
- **argument-hint**: Optional search pattern + optional flags
- **description**: Action + scope + "showing" + information type
- **dependent-commands**: Commands that call or depend on this command

**Action + Scope Patterns:**
- `list-plans`: "List all implementation plans"
- `list-reports`: "List all existing research reports"
- `list-summaries`: "List all implementation summaries"
- `workflow-status`: "Display real-time workflow status and progress"
- `workflow-template`: "Generate workflow templates"
- `test-all`: "Run complete test suite"
- `update-plan`: "Update existing implementation plan"
- `update-report`: "Update existing research report"
- `validate-setup`: "Validate CLAUDE.md setup and check all linked standards files"

## Template Application Examples

### Example: Orchestration Command
```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob
argument-hint: "\"<workflow-description>\" [--dry-run] [--template=<template-name>] [--priority=<high|medium|low>]"
description: "Multi-agent workflow orchestration for complete research → planning → implementation workflows"
command-type: orchestration
dependent-commands: coordination-hub, resource-manager, workflow-status, report, plan, implement, debug, refactor, document, test, test-all, subagents
---
```

### Example: Primary Command
```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task
argument-hint: "[plan-file] [starting-phase] [--orchestrated]"
description: "Execute implementation plan with automated testing and commits (auto-resumes most recent incomplete plan if no args)"
command-type: primary
dependent-commands: list-plans, update-plan, list-summaries, revise, debug, document, subagents, coordination-hub, resource-manager
---
```

### Example: Utility Command
```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: "<phase-context> <task-list> [options]"
description: "Enhanced parallel task execution with cross-workflow coordination for orchestration"
command-type: utility
dependent-commands: implement, coordination-hub, resource-manager
---
```

### Example: Dependent Command
```yaml
---
allowed-tools: SlashCommand, Read, Write, TodoWrite
argument-hint: "[search-pattern] [--json] [--orchestration-ready] [--workflow-context=<workflow-id>]"
description: "List all implementation plans in the codebase"
command-type: dependent
dependent-commands: implement
---
```

## Validation Rules

### Mandatory Fields
All commands must have all five fields in the specified order.

### Field Format Validation
- `allowed-tools`: Comma-separated, no square brackets
- `argument-hint`: String with proper parameter syntax
- `description`: Single line, follows template pattern
- `command-type`: Must be one of the four types
- `dependent-commands`: Comma-separated list

### Content Validation
- **Orchestration**: Must include infrastructure commands in dependent-commands
- **Primary**: Must include orchestration flag in argument-hint
- **Utility**: Must mention "orchestration workflows" in description
- **Dependent**: Must be minimal in allowed-tools

### Cross-Reference Validation
- Commands listed in dependent-commands must exist
- Circular dependencies should be avoided
- Infrastructure commands (coordination-hub, resource-manager) should be listed early

## Migration Guide

To update existing commands to comply with these templates:

1. **Check field order** - Reorder fields to match standard
2. **Validate allowed-tools** - Ensure proper format and appropriate tools
3. **Update argument-hint** - Use standard parameter syntax
4. **Standardize description** - Match template pattern for command type
5. **Verify command-type** - Ensure correct classification
6. **Update dependent-commands** - Use comma-separated format, order by importance

## Template Compliance Checklist

For each command:
- [ ] Fields in correct order (allowed-tools, argument-hint, description, command-type, dependent-commands)
- [ ] allowed-tools matches command type template
- [ ] argument-hint uses proper parameter syntax
- [ ] description follows command type pattern
- [ ] command-type is one of: orchestration, primary, utility, dependent
- [ ] dependent-commands are comma-separated and exist
- [ ] Overall format matches appropriate template example