# Primary Command YAML Template

## Purpose
Standard YAML frontmatter template for primary commands that serve as main entry points for user interactions and coordinate complex operations.

## Usage
```markdown
{{template:primary_yaml:command-name,description,argument-hint,dependent-commands}}
```

## Template

```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task
argument-hint: "{argument-hint}"
description: "{description}"
command-type: primary
dependent-commands: {dependent-commands}
---
```

## Parameters
- `command-name`: Name of the command
- `description`: Brief description of command functionality
- `argument-hint`: Format hint for command arguments
- `dependent-commands`: Comma-separated list of dependent commands

## Standard Tool Set
Primary commands typically have access to all core tools:
- `SlashCommand`: Execute other commands
- `TodoWrite`: Task management
- `Read`, `Write`: File operations
- `Bash`: System operations
- `Grep`, `Glob`: Search operations
- `Task`: Complex task management

## Example Usage

```markdown
{{template:primary_yaml:implement,Execute implementation plan with automated testing and commits (auto-resumes most recent incomplete plan if no args),[plan-file] [starting-phase] [--orchestrated],list-plans,update-plan,list-summaries,revise,debug,document,subagents}}
```

Results in:
```yaml
---
allowed-tools: SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task
argument-hint: "[plan-file] [starting-phase] [--orchestrated]"
description: "Execute implementation plan with automated testing and commits (auto-resumes most recent incomplete plan if no args)"
command-type: primary
dependent-commands: list-plans, update-plan, list-summaries, revise, debug, document, subagents
---
```