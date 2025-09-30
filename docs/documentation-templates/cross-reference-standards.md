# Cross-Reference Standards

## Standardized Cross-Referencing System for Documentation

This document defines the standardized approach to cross-referencing between documentation files, ensuring consistent navigation and relationship clarity across the entire orchestration ecosystem.

## Reference Types and Formats

### Internal Command References
References between command documentation files:

```markdown
# Standard Format
[/command-name](../commands/command-name.md)

# Examples
[/orchestrate](../commands/orchestrate.md) - Main orchestration command
[/coordination-hub](../commands/coordination-hub.md) - Workflow coordination
[/resource-manager](../commands/resource-manager.md) - Resource allocation
[/subagents](../commands/subagents.md) - Parallel execution
```

### Section References
References to specific sections within documents:

```markdown
# Standard Format
[Section Name](#section-anchor)

# Examples
[Error Handling](#error-handling-and-recovery) - Local section reference
[Integration Patterns](../commands/orchestrate.md#integration-patterns) - External section reference
[Performance Monitoring](../commands/performance-monitor.md#metrics-collection) - Specific section
```

### Template References
References to documentation templates and standards:

```markdown
# Standard Format
[Template Name](../templates/template-name.md)

# Examples
[Command Documentation Template](../documentation-templates/command-documentation-template.md)
[Integration Examples Template](../documentation-templates/integration-examples-template.md)
[Cross-Reference Standards](../documentation-templates/cross-reference-standards.md)
```

### Protocol and Standards References
References to formal protocols and standards:

```markdown
# Standard Format
[Protocol Name](../standards/protocol-name.md)

# Examples
[Command Coordination Protocols](../standards/command-protocols.md)
[Event Message Standards](../standards/event-formats.md)
[Resource Allocation Protocols](../standards/resource-protocols.md)
```

### Architecture References
References to architectural documentation:

```markdown
# Standard Format
[Architecture Doc](../architecture/doc-name.md)

# Examples
[Orchestration Architecture](../architecture/orchestration-overview.md)
[Event System Architecture](../architecture/event-system.md)
[Resource Management Architecture](../architecture/resource-management.md)
```

## Specs Directory References

### Plan References
References to implementation plans:

```markdown
# Standard Format
[Plan Name](../../specs/plans/NNN_plan-name.md)

# Examples
[Orchestration Ecosystem Plan](../../specs/plans/001_orchestration_ecosystem.md)
[Performance Optimization Plan](../../specs/plans/002_performance_optimization.md)
[Documentation Enhancement Plan](../../specs/plans/003_documentation_enhancement.md)
```

### Report References
References to research reports:

```markdown
# Standard Format
[Report Name](../../specs/reports/NNN_report-name.md)

# Examples
[Workflow Coordination Research](../../specs/reports/001_workflow_coordination.md)
[Resource Management Analysis](../../specs/reports/002_resource_management.md)
[Performance Benchmarking Report](../../specs/reports/003_performance_benchmarks.md)
```

### Summary References
References to implementation summaries:

```markdown
# Standard Format
[Summary Name](../../specs/summaries/NNN_summary-name.md)

# Examples
[Phase 1 Implementation Summary](../../specs/summaries/001_phase_1_orchestration.md)
[Phase 2 Implementation Summary](../../specs/summaries/002_phase_2_coordination.md)
[Phase 3 Implementation Summary](../../specs/summaries/003_phase_3_optimization.md)
```

## Context-Aware Cross-Referencing

### Command Dependency References
Show command dependencies and relationships:

```markdown
### Related Commands
This command integrates with:
- **Primary Dependencies**: [/coordination-hub](../commands/coordination-hub.md), [/resource-manager](../commands/resource-manager.md)
- **Secondary Dependencies**: [/workflow-status](../commands/workflow-status.md), [/performance-monitor](../commands/performance-monitor.md)
- **Helper Commands**: [/progress-aggregator](../commands/progress-aggregator.md), [/dependency-resolver](../commands/dependency-resolver.md)

### Coordination Flow
For complete workflow understanding, see:
1. [Workflow Initialization](../commands/coordination-hub.md#workflow-creation-and-initialization)
2. [Resource Allocation](../commands/resource-manager.md#dynamic-allocation)
3. [Progress Monitoring](../commands/progress-aggregator.md#real-time-tracking)
```

### Integration Pattern References
Reference common integration patterns:

```markdown
### Integration Patterns
- **Event-Driven Coordination**: See [Event System Integration](../patterns/event-driven-coordination.md)
- **Resource Sharing**: See [Resource Coordination Patterns](../patterns/resource-coordination.md)
- **Error Recovery**: See [Recovery Patterns](../patterns/error-recovery.md)
```

### Workflow References
Reference complete workflow examples:

```markdown
### Complete Workflows
For end-to-end examples, see:
- **Feature Development**: [Complete Feature Workflow](../workflows/feature-development.md)
- **Bug Fix Process**: [Bug Fix Workflow](../workflows/bug-fix-process.md)
- **Performance Optimization**: [Optimization Workflow](../workflows/performance-optimization.md)
```

## Bidirectional Reference Standards

### Automatic Back-References
When referencing a document, ensure the referenced document includes a back-reference:

```markdown
# In source document
See [Resource Allocation Strategies](../commands/resource-manager.md#allocation-strategies) for details.

# In target document (resource-manager.md)
### Related Documentation
This section is referenced by:
- [Orchestration Command](../commands/orchestrate.md#resource-coordination)
- [Performance Optimization](../workflows/performance-optimization.md#resource-tuning)
```

### Reference Maintenance
Maintain reference accuracy through:

```markdown
### Reference Validation
- **Automated Checks**: Use link checkers to validate references
- **Regular Audits**: Manual review of cross-references quarterly
- **Update Triggers**: Update references when files are moved or renamed
```

## Reference Categorization

### By Relationship Type
Categorize references by their relationship:

```markdown
### Dependencies
- **Required**: [/coordination-hub](../commands/coordination-hub.md) - Required for workflow management
- **Optional**: [/performance-monitor](../commands/performance-monitor.md) - Optional for performance tracking

### Related Concepts
- **Similar**: [/implement](../commands/implement.md) - Similar implementation patterns
- **Complementary**: [/test](../commands/test.md) - Complementary testing functionality
- **Alternative**: [/debug](../commands/debug.md) - Alternative diagnostic approach
```

### By Usage Context
Categorize by when references are used:

```markdown
### Usage Context References
- **Prerequisites**: Read [Setup Requirements](../setup/prerequisites.md) before using this command
- **Follow-up**: After completion, see [Testing Procedures](../workflows/testing.md)
- **Troubleshooting**: If issues occur, see [Common Problems](../troubleshooting/common-issues.md)
```

## Special Reference Types

### Code References
References to specific code locations:

```markdown
# Standard Format
[Description](file-path#line-number)

# Examples
[Event Handler Implementation](../../.claude/command-modules/coordination-hub.sh#L45-L60)
[Resource Allocation Logic](../../.claude/command-modules/resource-manager.sh#L120-L150)
```

### Configuration References
References to configuration sections:

```markdown
# Standard Format
[Config Section](../../config/file.conf#section-name)

# Examples
[Orchestration Settings](../../config/orchestration.conf#workflow-defaults)
[Performance Tuning](../../config/performance.conf#optimization-parameters)
```

### External References
References to external documentation:

```markdown
# Standard Format with Context
For more information on [concept], see [External Documentation](https://external-url.com) (Note: External link)

# Examples
For Docker orchestration concepts, see [Docker Compose Documentation](https://docs.docker.com/compose/) (Note: External link)
For Kubernetes patterns, see [Kubernetes Documentation](https://kubernetes.io/docs/) (Note: External link)
```

## Reference Quality Standards

### Clarity Requirements
- **Descriptive Text**: Use descriptive link text, not "click here" or "see here"
- **Context**: Provide context for why the reference is relevant
- **Specificity**: Link to specific sections rather than entire documents when possible

### Maintenance Standards
- **Currency**: Ensure all references point to current versions
- **Accuracy**: Verify that referenced content actually covers the stated topic
- **Completeness**: Include all necessary references for comprehensive understanding

### Accessibility Standards
- **Alt Text**: Provide meaningful descriptions for reference purposes
- **Structure**: Use consistent heading levels for reference sections
- **Navigation**: Include "return to" links for complex reference chains

## Reference Automation

### Automated Reference Checking
```bash
# Command to validate all references
/validate-references --scope=documentation --fix-broken --report-missing

# Output format for reference validation
Reference Validation Report:
✓ Valid: 245 references
✗ Broken: 3 references
⚠ Missing: 7 potential references
📝 Suggestions: 12 optimization opportunities
```

### Reference Generation
```bash
# Auto-generate reference sections
/generate-references --target=command-doc --type=bidirectional --format=standard

# Auto-update references after file moves
/update-references --moved-file=old-path.md --new-path=new-path.md --cascade
```

This standardized cross-referencing system ensures consistent navigation, clear relationships, and maintainable documentation across the entire orchestration ecosystem.