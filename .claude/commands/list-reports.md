---
allowed-tools: SlashCommand, Read, Write, TodoWrite
argument-hint: "[search-pattern] [--json] [--orchestration-ready] [--workflow-context=<workflow-id>]"
description: "List all existing research reports in the codebase"
command-type: dependent
dependent-commands: plan, report
---

# List Research Reports

I'll find and list all research reports in the codebase.

## Arguments
- `search-pattern` (optional): Filter reports by pattern
- `--json`: Output in machine-readable JSON format
- `--orchestration-ready`: Filter to show only orchestration-compatible reports
- `--workflow-context=<workflow-id>`: Filter reports by workflow context

## Process

I'll search for all reports in `specs/reports/` directories throughout the codebase and provide:

1. **Report Inventory**:
   - Location of each report
   - Report title and date
   - Topic/scope covered
   - File size and last modified date
   - Orchestration compatibility assessment
   - Workflow context associations
   - Integration readiness status

2. **Organization**:
   - Group by directory/module
   - Sort by date (most recent first)
   - Highlight reports matching the search pattern

3. **Summary Statistics**:
   - Total number of reports
   - Coverage by module/area
   - Most recent reports
   - Largest/most comprehensive reports
   - Orchestration readiness metrics
   - Cross-workflow reference counts
   - Implementation dependency analysis

4. **Orchestration Features**:
   When orchestration flags are used:
   - **JSON Output**: Machine-readable format for automation
   - **Readiness Assessment**: Reports suitable for parallel workflow consumption
   - **Workflow Context**: Reports tagged for specific workflows
   - **Dependency Mapping**: Cross-report references and dependencies
   - **Implementation Links**: Connection to plans and summaries

Let me search for all existing reports in your codebase.
