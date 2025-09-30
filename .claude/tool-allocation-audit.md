# Tool Allocation Audit Report
Date: 2025-01-15

## Standard Tool Allocation Patterns

Based on the refactoring plan, commands should follow these patterns:

### Orchestration Commands
**Standard Tools**: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob]
- Commands that coordinate complex multi-agent workflows

### Primary Commands
**Standard Tools**: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task]
- High-level commands that manage complete workflows

### Utility Commands
**Standard Tools**: [SlashCommand, TodoWrite, Read, Write, Bash]
- Helper commands that support orchestration and primary commands

### Dependent Commands
**Standard Tools**: [SlashCommand, Read, Write, TodoWrite]
- Commands that depend on other commands for functionality

## Current Tool Allocation Analysis

### Orchestration Commands
1. **orchestrate.md** - Type: orchestration
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob] ✅ COMPLIANT

### Primary Commands
1. **plan.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

2. **cleanup.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

3. **revise.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

4. **test.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

5. **document.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

6. **setup.md** - Type: primary
   - Current: [Read, Write, Edit, MultiEdit, Bash, Grep, Glob, TodoWrite] ❌ MISSING SlashCommand

7. **validate-setup.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

8. **test-all.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

9. **update-plan.md** - Type: primary
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

10. **update-report.md** - Type: primary
    - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

11. **debug.md** - Type: primary
    - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

12. **report.md** - Type: primary
    - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

13. **refactor.md** - Type: primary
    - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

14. **implement.md** - Type: primary
    - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task] ✅ COMPLIANT

### Utility Commands
1. **coordination-hub.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob] ❌ EXTRA TOOLS (Grep, Glob)

2. **resource-manager.md** - Type: utility
   - Current: [Read, Write, Bash] ❌ MISSING SlashCommand, TodoWrite

3. **workflow-status.md** - Type: utility
   - Current: [Read, Bash] ❌ MISSING SlashCommand, TodoWrite, Write

4. **subagents.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob] ❌ EXTRA TOOLS (Grep, Glob)

5. **list-plans.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash] ✅ COMPLIANT

6. **list-reports.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash] ✅ COMPLIANT

7. **list-summaries.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash] ✅ COMPLIANT

8. **dependency-resolver.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash] ✅ COMPLIANT

9. **workflow-template.md** - Type: utility
   - Current: [SlashCommand, TodoWrite, Read, Write, Bash] ✅ COMPLIANT

10. **performance-monitor.md** - Type: utility
    - Current: [Read, Write, Bash] ❌ MISSING SlashCommand, TodoWrite

11. **workflow-recovery.md** - Type: utility
    - Current: [Read, Write, Bash, TodoWrite] ❌ MISSING SlashCommand

12. **progress-aggregator.md** - Type: utility
    - Current: [Read, TodoWrite] ❌ MISSING SlashCommand, Write, Bash

## Summary of Issues

### Critical Issues
1. **Missing SlashCommand Tools** (6 commands):
   - setup.md
   - resource-manager.md
   - workflow-status.md
   - performance-monitor.md
   - workflow-recovery.md
   - progress-aggregator.md

2. **Missing Core Utility Tools**:
   - resource-manager.md: Missing TodoWrite
   - workflow-status.md: Missing TodoWrite, Write
   - progress-aggregator.md: Missing Write, Bash

3. **Extra Tools in Utility Commands**:
   - coordination-hub.md: Has extra Grep, Glob (should be removed)
   - subagents.md: Has extra Grep, Glob (should be removed)

### Tool Allocation Compliance Rate
- **Orchestration Commands**: 1/1 (100%) ✅
- **Primary Commands**: 13/14 (93%) - 1 missing SlashCommand
- **Utility Commands**: 5/12 (42%) - 7 commands need updates

### Overall Compliance: 19/27 (70%)

## Recommendations

1. **Immediate Actions**:
   - Add SlashCommand tool to 6 commands missing it
   - Add missing TodoWrite, Write, Bash tools to utility commands
   - Remove extra Grep, Glob tools from coordination-hub and subagents

2. **Standardization Priority**:
   - HIGH: Fix utility commands (most inconsistent)
   - MEDIUM: Fix setup.md (primary command missing SlashCommand)
   - LOW: Remove extra tools from working commands

3. **Validation Strategy**:
   - Implement automated tool allocation validation
   - Create tool allocation templates by command type
   - Add tool allocation checks to CI/CD pipeline

## Next Steps

1. Update all non-compliant commands to match standard patterns
2. Validate all tool allocations after updates
3. Create documentation explaining tool allocation rationale
4. Implement automated compliance checking