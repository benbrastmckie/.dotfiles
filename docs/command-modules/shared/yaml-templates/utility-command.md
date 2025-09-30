# Utility Command YAML Template

## Purpose
Standard YAML frontmatter template for utility commands that provide supporting functionality and are typically called by other commands.

## Usage
```markdown
{{template:utility_yaml:command-name,description,argument-hint,dependent-commands}}
```

## Template

```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: "{argument-hint}"
description: "{description}"
command-type: utility
dependent-commands: {dependent-commands}
---
```

## Parameters
- `command-name`: Name of the command
- `description`: Brief description of command functionality
- `argument-hint`: Format hint for command arguments
- `dependent-commands`: Comma-separated list of dependent commands

## Example Usage

```markdown
{{template:utility_yaml:workflow-recovery,Advanced workflow recovery and rollback capabilities for orchestration workflows,"<recovery-operation>" [workflow-id] [checkpoint],coordination-hub,resource-manager,workflow-status,performance-monitor}}
```

Results in:
```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash
argument-hint: "<recovery-operation>" [workflow-id] [checkpoint]
description: "Advanced workflow recovery and rollback capabilities for orchestration workflows"
command-type: utility
dependent-commands: coordination-hub, resource-manager, workflow-status, performance-monitor
---
```