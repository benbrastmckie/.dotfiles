# Specs Directory

This directory contains implementation plans, research reports, and summaries for significant changes to the dotfiles configuration.

## Directory Structure

- **`plans/`** - Implementation plans for new features or significant changes
- **`reports/`** - Research reports and investigations
- **`summaries/`** - Post-implementation summaries and retrospectives

## File Naming Convention

All files follow the format: `NNN_descriptive_name.md`

- `NNN` - Three-digit number with leading zeros (001, 002, etc.)
- Increment from the highest existing number in each category
- Use lowercase with underscores for descriptions
- Examples: `001_nix_flake_migration.md`, `002_email_oauth_setup.md`

## When to Create Specs

### Plans (plans/)
Create before implementing:
- Major features or integrations
- System architecture changes
- Breaking configuration changes
- Complex multi-step implementations

### Reports (reports/)
Create when researching:
- Technology evaluations
- Problem investigations
- Comparison of alternatives
- Feasibility studies

### Summaries (summaries/)
Create after completing:
- Major implementations
- Significant troubleshooting
- Complex configurations
- Lessons learned from issues

## Templates

See [`CLAUDE.md`](../CLAUDE.md#specs-directory-protocol) for detailed templates for each document type.

## Current Documents

### Plans
(None yet)

### Reports
- [`001_claude_squad_research.md`](reports/001_claude_squad_research.md) - Research on Claude Squad implementation

### Summaries
(None yet)