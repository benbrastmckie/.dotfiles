---
allowed-tools: Read, Write, Edit, MultiEdit, Bash, Grep, Glob, TodoWrite
argument-hint: [project-directory] [--orchestration-ready] [--validate-only] [--generate-templates]
description: Setup or improve CLAUDE.md with links to standards and specs directory protocols, including orchestration readiness validation
command-type: primary
dependent-commands: validate-setup, workflow-template, coordination-hub
---

# Setup Project Standards with Orchestration Support

I'll create or improve the CLAUDE.md file to properly document project standards, establish protocols for specs directories, and ensure orchestration readiness for advanced workflow coordination.

## Target Directory
$1 (or current directory)

## Command Options
- `--orchestration-ready`: Focus on orchestration compatibility validation and setup
- `--validate-only`: Only validate existing setup without making changes
- `--generate-templates`: Generate workflow templates based on project analysis

## Process

### 1. Analyze Project Structure
I'll examine the project to find:
- Existing CLAUDE.md file
- Standards documentation (GUIDELINES.md, STANDARDS.md, etc.)
- Testing configuration files and documentation
- Documentation standards or templates
- Existing specs/ directories

#### Orchestration Readiness Analysis
When `--orchestration-ready` is specified, I'll also analyze:
- **Workflow Infrastructure**: Check for specs/plans/, specs/reports/, specs/summaries/
- **Command Integration**: Verify presence of helper commands (coordination-hub, resource-manager, etc.)
- **Testing Protocols**: Validate testing procedures for orchestration workflows
- **Documentation Coverage**: Ensure critical documentation sections exist
- **Configuration Templates**: Check for workflow and template configurations
- **Resource Management**: Verify system resource monitoring capabilities

### 2. Discover Standards Files
I'll search for common standards patterns:

#### Code Standards
- `GUIDELINES.md`, `STANDARDS.md`, `STYLE.md`
- `docs/standards/`, `docs/guidelines/`
- `.editorconfig`, `.prettierrc`, `.eslintrc`
- Language-specific style guides

#### Testing Standards
- `TESTING.md`, `docs/testing/`
- Test configuration files
- CI/CD test configurations
- Test directory structures

#### Documentation Standards
- `CONTRIBUTING.md`, `docs/documentation/`
- README templates
- API documentation patterns
- Comment style guides

### 3. Create/Update CLAUDE.md
The CLAUDE.md file will be concise with links to detailed standards:

```markdown
# Project Standards and Protocols

## Quick Reference
- **Code Standards**: [Link to standards file]
- **Testing Protocols**: [Link to testing docs]
- **Documentation Guidelines**: [Link to docs standards]

## Commands
[Project-specific commands for common tasks]

## Specs Directory Protocol

### Structure
Create `specs/` directories at the deepest relevant level containing:
- `plans/` - Implementation plans (NNN_*.md format)
- `reports/` - Research reports (NNN_*.md format)
- `summaries/` - Implementation summaries (NNN_*.md format)

### Numbering Convention
All specs files use `NNN_descriptive_name.md` format:
- Three-digit numbers with leading zeros (001, 002, etc.)
- Increment from highest existing number
- Lowercase with underscores for names

### Location Guidelines
Place specs/ in the most specific directory that encompasses all relevant files:
- Feature-specific: In the feature's root directory
- Module-wide: In the module's directory
- Project-wide: In the project root

## Project-Specific Configuration
[Any project-specific settings or overrides]
```

### 4. Interactive Standards Creation
If standards files don't exist, I'll:
1. Prompt for code style preferences
2. Ask about testing framework and commands
3. Request documentation format preferences
4. Create appropriate standards files
5. Link them in CLAUDE.md

### 5. Create Missing Standards Files
Based on project type and user input:

#### Code Standards Template
```markdown
# Code Standards

## Style Guide
[Language-specific style rules]

## File Organization
[Project structure guidelines]

## Naming Conventions
[Variable, function, file naming rules]

## Best Practices
[Project-specific patterns]
```

#### Testing Standards Template
```markdown
# Testing Standards

## Test Organization
[Test file structure and naming]

## Test Commands
- Unit tests: [command]
- Integration tests: [command]
- Full suite: [command]

## Coverage Requirements
[Minimum coverage expectations]

## CI/CD Integration
[How tests run in CI]
```

#### Documentation Standards Template
```markdown
# Documentation Standards

## Code Comments
[Comment style and requirements]

## README Structure
[Template for README files]

## API Documentation
[How to document APIs]

## Specs Documentation
[How to write plans, reports, summaries]
```

### 6. Orchestration Configuration Setup
When orchestration features are requested, I'll:

#### 6.1 Create Orchestration Configuration
```yaml
# .claude/orchestration.yml
orchestration:
  enabled: true
  max_concurrent_workflows: 3
  max_agents_per_workflow: 5
  default_timeout: 1800  # 30 minutes

  resource_limits:
    cpu_threshold: 80
    memory_threshold: 85
    disk_threshold: 90

  workflow_defaults:
    auto_recovery: true
    checkpoint_interval: 300  # 5 minutes
    progress_reporting: true

  templates:
    default_workflow: "feature-development"
    available_templates:
      - "feature-development"
      - "bug-fix"
      - "research-implementation"
      - "documentation-update"
```

#### 6.2 Interactive Documentation Prompts
If critical sections are missing, I'll prompt for:

**Code Standards Configuration:**
```
Missing: Code style configuration
Options:
1. Generate from project analysis (recommended)
2. Use language-specific defaults
3. Interactive setup
4. Skip for now

Choice: [1-4]
```

**Testing Protocol Setup:**
```
Missing: Testing procedures documentation
Current test framework detected: [framework name]
Options:
1. Generate testing protocols for detected framework
2. Configure custom testing procedures
3. Use minimal testing template
4. Skip testing setup

Choice: [1-4]
```

**Workflow Template Generation:**
```
Project type detected: [type] (confidence: [percentage])
Available workflow templates:
1. Standard development workflow (recommended)
2. Research-heavy workflow
3. Configuration-focused workflow
4. Custom workflow design

Choice: [1-4]
```

#### 6.3 Template Generation
Based on project analysis, I'll create:

**Workflow Templates** (in `specs/templates/`):
```markdown
# Template: Feature Development Workflow
Type: feature-development
Estimated Duration: 2-4 hours

## Phases
1. **Research**: Investigate requirements and existing solutions
2. **Planning**: Create detailed implementation plan
3. **Implementation**: Execute plan with testing
4. **Documentation**: Update relevant documentation
5. **Integration**: Ensure compatibility and performance

## Resource Requirements
- Agents: 3-5
- Time: 2-4 hours
- Dependencies: testing framework, documentation tools

## Success Criteria
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Performance benchmarks met
- [ ] Integration tests successful
```

**Code Standards Templates** (if missing):
```markdown
# Code Standards (Generated)
Based on project analysis

## Detected Patterns
[Analysis results]

## Recommended Standards
[Generated standards based on existing code]

## Testing Integration
[Testing procedures for code quality]
```

### 7. Orchestration Compliance Validation
I'll verify orchestration readiness by checking:

#### 7.1 Infrastructure Requirements
- [ ] **Specs Directory Structure**: specs/plans/, specs/reports/, specs/summaries/
- [ ] **Helper Commands**: Verify orchestration command availability
- [ ] **Configuration Files**: Check orchestration configuration validity
- [ ] **Resource Monitoring**: Validate system resource tracking capabilities

#### 7.2 Documentation Completeness
- [ ] **Standards Documentation**: Code, testing, documentation standards present
- [ ] **Workflow Templates**: At least one workflow template available
- [ ] **Command Integration**: Helper command documentation complete
- [ ] **Process Documentation**: Clear workflows for common development tasks

#### 7.3 Integration Testing
- [ ] **Command Compatibility**: Test orchestration command integration
- [ ] **Resource Management**: Verify resource allocation and monitoring
- [ ] **Workflow Execution**: Test basic workflow execution capabilities
- [ ] **Error Handling**: Validate error recovery and reporting

### 8. Validate Setup
After creation/update, I'll:
- Verify all linked files exist
- Check that paths are correct
- Ensure specs protocol is clear
- Test that commands work

#### Enhanced Validation for Orchestration
When orchestration features are enabled, I'll also:
- Test helper command integration
- Verify resource management capabilities
- Validate workflow template functionality
- Check configuration file integrity
- Test orchestration command compatibility

## Interactive Prompts

### Standard Setup Prompts
If standards don't exist, I'll ask:

1. **Code Style**
   - Indentation (spaces/tabs, size)
   - Line length limits
   - Naming conventions preference

2. **Testing**
   - Test framework/runner
   - Test file patterns
   - Coverage tools

3. **Documentation**
   - Comment style preference
   - README requirements
   - API doc format

### Orchestration-Specific Prompts
When `--orchestration-ready` is used, I'll also prompt for:

4. **Workflow Configuration**
   - Maximum concurrent workflows (default: 3)
   - Agents per workflow (default: 5)
   - Default timeout settings (default: 30 minutes)

5. **Resource Management**
   - CPU usage thresholds (default: 80%)
   - Memory usage limits (default: 85%)
   - Disk space monitoring (default: 90%)

6. **Template Preferences**
   - Default workflow template type
   - Custom template requirements
   - Integration with existing tools

7. **Monitoring and Recovery**
   - Auto-recovery settings (default: enabled)
   - Checkpoint frequency (default: 5 minutes)
   - Progress reporting preferences

## Output

### Standard Setup Output
I'll create/update:
1. `CLAUDE.md` - Main configuration file with project standards
2. Standards files (if needed) - Code, testing, documentation standards
3. Directory structure documentation
4. Command reference for common tasks

### Enhanced Orchestration Output
When orchestration features are enabled, I'll also create:

5. **Orchestration Configuration**
   - `.claude/orchestration.yml` - Orchestration settings and limits
   - `.claude/workflow-defaults.yml` - Default workflow configurations

6. **Workflow Templates** (in `specs/templates/`)
   - `feature-development.yml` - Standard development workflow
   - `bug-fix.yml` - Bug fix workflow template
   - `research-implementation.yml` - Research-heavy workflow
   - `documentation-update.yml` - Documentation workflow

7. **Enhanced CLAUDE.md Sections**
   - **Orchestration Configuration**: Settings and capabilities
   - **Workflow Templates**: Available templates and usage
   - **Resource Management**: Resource limits and monitoring
   - **Helper Commands**: Integration with orchestration ecosystem

8. **Compliance Reports**
   - `specs/reports/orchestration-readiness.md` - Readiness assessment
   - `specs/reports/setup-validation.md` - Setup validation results

9. **Integration Documentation**
   - Helper command usage examples
   - Orchestration workflow patterns
   - Troubleshooting and debugging guides

## Validation and Testing

### Standard Validation
- Verify all linked files exist and are accessible
- Check that paths are correct and functional
- Ensure specs protocol is clearly documented
- Test that common commands work as expected

### Orchestration Validation
When orchestration features are configured:
- Test helper command integration and communication
- Verify resource management and monitoring capabilities
- Validate workflow template functionality and execution
- Check configuration file integrity and settings
- Test orchestration command compatibility and coordination

## Usage Examples

### Basic Setup
```bash
/setup /path/to/project
```

### Orchestration-Ready Setup
```bash
/setup /path/to/project --orchestration-ready
```

### Validation Only
```bash
/setup /path/to/project --validate-only
```

### Generate Templates
```bash
/setup /path/to/project --generate-templates
```

### Combined Options
```bash
/setup /path/to/project --orchestration-ready --generate-templates
```

Let me analyze your project and set up proper standards documentation with orchestration capabilities.
