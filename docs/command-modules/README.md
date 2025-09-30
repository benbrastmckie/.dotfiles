# Command Module System

The command module system provides a structured approach to organizing and reusing common components across command files, addressing maintainability issues with large command files.

## Purpose

This modular system:
- Reduces large command files by 40-60% through modularization
- Provides reusable components for common patterns
- Maintains consistency across commands
- Improves maintainability and understanding

## Directory Structure

```
docs/command-modules/
├── README.md                    # Module system overview (this file)
├── shared/                      # Shared components across all commands
│   ├── yaml-templates/          # YAML frontmatter templates
│   ├── integration-patterns/    # Standard integration patterns
│   ├── coordination-protocols/  # Protocol implementation patterns
│   └── error-handling/         # Error handling patterns
├── orchestration/              # Orchestration-specific modules
│   ├── workflow-coordination/   # Workflow management modules
│   ├── resource-management/     # Resource allocation modules
│   ├── monitoring/             # Monitoring and status modules
│   └── recovery/               # Recovery operation modules
└── utilities/                  # Utility command modules
    ├── status-reporting/       # Status and progress modules
    ├── performance/            # Performance monitoring modules
    └── validation/             # Validation and testing modules
```

## Module Inclusion System

### Reference Syntax

Modules are included using standardized reference patterns:

#### Basic Module Reference
```markdown
{{module:path/to/module.md}}
```
Includes the entire module content at the reference point.

#### Section Include
```markdown
{{include:module:section_name}}
```
Includes a specific section from a module.

#### Template Expansion
```markdown
{{template:template_name:parameters}}
```
Expands a template with provided parameters.

### Example Usage

```markdown
# My Command

{{template:orchestration_yaml:command-name=my-command,type=utility}}

## Process Overview

{{module:shared/integration-patterns/helper-coordination.md}}

## Error Handling

{{include:shared/error-handling/standard-recovery.md:recovery_procedures}}
```

## Module Categories

### Shared Components
**Location**: `shared/`
**Purpose**: Common patterns used across multiple command types

- **YAML Templates**: Standardized frontmatter for different command types
- **Integration Patterns**: Helper command coordination, event handling
- **Coordination Protocols**: Standard message schemas and protocols
- **Error Handling**: Standard error classification and recovery patterns

### Orchestration Modules
**Location**: `orchestration/`
**Purpose**: Components specific to orchestration commands

- **Workflow Coordination**: Workflow analysis, phase management
- **Resource Management**: Resource allocation and coordination
- **Monitoring**: Status tracking and performance monitoring
- **Recovery**: Recovery operations and rollback procedures

### Utility Modules
**Location**: `utilities/`
**Purpose**: Components for utility and support commands

- **Status Reporting**: Progress tracking and status generation
- **Performance**: Performance analysis and optimization
- **Validation**: Testing and validation frameworks

## Creating New Modules

### Module Structure

Each module should follow this structure:

```markdown
# Module Name

## Purpose
Brief description of the module's purpose and usage.

## Usage
How to include and use this module.

## Dependencies
Any dependencies on other modules or commands.

## Content
[Module content here]
```

### Naming Conventions

- Use kebab-case for file names: `helper-coordination.md`
- Use descriptive names that indicate purpose
- Group related modules in appropriate subdirectories
- Include version/type suffixes when needed: `yaml-template-v2.md`

## Best Practices

### Module Design
- Keep modules focused on a single responsibility
- Design for reusability across multiple commands
- Include clear documentation and usage examples
- Maintain backward compatibility when updating

### Integration
- Test module references before committing
- Validate that all referenced modules exist
- Ensure parameters are properly documented
- Use meaningful variable names in templates

### Maintenance
- Regular review of module usage across commands
- Update shared modules when patterns change
- Deprecate unused modules with clear migration paths
- Version modules when breaking changes are necessary

## Implementation Status

This system is designed to support the modularization of large command files:

- **workflow-recovery.md**: Target reduction from 1128 to 450-500 lines
- **implement.md**: Target reduction from 991 to 600-700 lines
- **orchestrate.md**: Apply modular structure for improved organization

The module system enables maintaining full functionality while significantly improving maintainability and code organization.