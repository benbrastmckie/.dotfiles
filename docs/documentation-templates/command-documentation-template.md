# Command Documentation Template

## Standard Structure for All Commands

This template ensures consistent documentation quality and structure across all slash commands in the orchestration ecosystem.

### Header Section
Every command documentation should begin with:
- **Command name and brief description** (1-2 sentences)
- **Usage syntax and argument patterns** (clear command format)
- **Integration context and dependencies** (ecosystem position)

### Core Functionality
Detailed description of primary operations including:
- **Primary operations and capabilities** (what the command does)
- **Input/output specifications** (expected inputs, outputs, formats)
- **Configuration options and parameters** (available options, defaults)

### Integration Patterns
How the command coordinates with the ecosystem:
- **Coordination with other commands** (dependencies, workflow integration)
- **Event publishing and subscription** (what events it generates/consumes)
- **Resource requirements and allocation** (computational needs, constraints)

### Examples Section
Comprehensive usage examples with escalating complexity:
- **Basic usage examples** (simple, standalone usage)
- **Integration scenarios** (coordination with other commands)
- **Error handling examples** (common failure modes and recovery)
- **Performance optimization examples** (tuning for efficiency)

### Advanced Features
Extended capabilities and customization:
- **Extended capabilities** (advanced features, special modes)
- **Customization options** (configuration, personalization)
- **Performance tuning** (optimization strategies, monitoring)

### Troubleshooting
Problem resolution guidance:
- **Common issues and solutions** (frequently encountered problems)
- **Error message interpretation** (understanding error output)
- **Debug information access** (diagnostic capabilities, logging)

## Example Format Standards

### Basic Example Format
```markdown
### Example: [Example Name]

**Scenario**: [Brief description of use case]

**Command**:
```bash
/command "argument" --option=value
```

**Expected Output**:
```
[Sample output with explanations]
```

**Integration Context**:
- **Dependencies**: [Required commands/resources]
- **Coordination**: [How it integrates with other commands]
- **Follow-up**: [Typical next steps]
```

### Integration Example Format
```markdown
### Integration Example: [Integration Name]

**Scenario**: [Multi-command workflow description]

**Command Sequence**:
```bash
# Step 1: [Description]
/command-1 "argument" --option=value

# Step 2: [Description]
/command-2 "argument" --option=value

# Step 3: [Description]
/command-3 "argument" --option=value
```

**Coordination Flow**:
1. [Step-by-step workflow description]
2. [Including event flows and dependencies]
3. [Resource coordination details]

**Expected Results**:
- [Concrete outcomes]
- [File changes, state updates]
- [Performance metrics]
```

### Error Handling Example Format
```markdown
### Error Handling: [Error Scenario]

**Error Type**: [Classification of the error]

**Symptoms**:
```
[Error message or behavior description]
```

**Diagnosis Steps**:
1. [How to identify the issue]
2. [Diagnostic commands to run]
3. [What to look for in output]

**Resolution**:
```bash
# Recovery command sequence
/command --recovery-option
/secondary-command --fix-mode
```

**Prevention**:
- [How to avoid this error in future]
- [Best practices and recommendations]
```

## Cross-Reference Standards

### Internal References
- **Command References**: [/command-name](../commands/command-name.md)
- **Section References**: [Section Name](#section-anchor)
- **Template References**: [Template Name](../templates/template-name.md)

### External References
- **Protocol References**: [Protocol Name](../standards/protocol-name.md)
- **Architecture References**: [Architecture Doc](../architecture/doc-name.md)
- **Specs References**: [Spec Name](../../specs/category/spec-name.md)

### Workflow References
- **Plan References**: [Plan Name](../../specs/plans/plan-name.md)
- **Report References**: [Report Name](../../specs/reports/report-name.md)
- **Summary References**: [Summary Name](../../specs/summaries/summary-name.md)

## Content Quality Standards

### Writing Style
- **Clarity**: Use clear, concise language
- **Consistency**: Maintain consistent terminology
- **Completeness**: Cover all major use cases
- **Accuracy**: Ensure technical accuracy and up-to-date information

### Code Examples
- **Functionality**: All examples must be functional and tested
- **Completeness**: Include necessary context and setup
- **Clarity**: Add comments explaining complex operations
- **Realism**: Use realistic scenarios and data

### Integration Documentation
- **Dependencies**: Clearly document all dependencies
- **Event Flows**: Describe event publishing and consumption
- **Error Scenarios**: Cover common failure modes
- **Performance**: Include performance considerations