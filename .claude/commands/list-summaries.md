---
allowed-tools: Bash, Glob, Read
argument-hint: [search-pattern] [--json] [--orchestration-ready] [--workflow-context=<workflow-id>]
description: List all implementation summaries showing plans executed and reports used
command-type: dependent
parent-commands: implement
---

# List Implementation Summaries

I'll find and list all implementation summaries across the codebase, showing the connections between plans, implementations, and research reports.

## Arguments
- `search-pattern` (optional): Filter summaries by pattern
- `--json`: Output in machine-readable JSON format
- `--orchestration-ready`: Filter to show only orchestration-compatible summaries
- `--workflow-context=<workflow-id>`: Filter summaries by workflow context

## Process

I'll search for all summaries in `specs/summaries/` directories and provide:

### 1. Summary Inventory
- Location of each summary
- Feature implemented
- Plan executed (with link)
- Reports referenced (with links)
- Date completed
- Success metrics
- Orchestration compatibility status
- Workflow context associations
- Integration impact assessment

### 2. Relationships
For each summary, I'll show:
- **Plan → Summary**: Which plan was executed
- **Reports → Plan**: Which reports informed the plan
- **Summary → Reports**: Which reports were updated

### 3. Statistics
- Total implementations completed
- Most referenced reports
- Implementation success rate
- Common patterns across summaries
- Orchestration readiness distribution
- Cross-workflow implementation impacts
- Resource utilization patterns

### 4. Cross-References
- Plans without summaries (not yet implemented)
- Reports without implementations (research only)
- Summaries without reports (direct implementation)

### 5. Orchestration Features
When orchestration flags are used:
- **JSON Output**: Machine-readable format for automation
- **Readiness Assessment**: Summaries from orchestration-compatible implementations
- **Workflow Context**: Summaries tagged for specific workflows
- **Impact Analysis**: Cross-workflow effects and dependencies
- **Pattern Recognition**: Common orchestration patterns and best practices

Let me search for all implementation summaries in your codebase.