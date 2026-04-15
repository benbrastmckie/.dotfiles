# Project Overview

## Purpose

This file describes the repository structure for agent context. When extensions are loaded, they provide project-specific domain knowledge (technology stack, development workflows, verification commands).

## Repository Structure

```
specs/                       # Task management
├── TODO.md                 # Task list
├── state.json              # Task state
└── {NNN}_{SLUG}/           # Task artifacts
    ├── reports/
    ├── plans/
    └── summaries/

.claude/                     # Claude Code configuration
├── CLAUDE.md               # Main reference
├── commands/               # Slash commands
├── skills/                 # Skill definitions
├── agents/                 # Agent definitions
├── rules/                  # Auto-applied rules
├── context/                # Domain knowledge
└── extensions/             # Extension modules
    └── */                  # Per-extension directories
        ├── manifest.json   # Extension metadata
        ├── index-entries.json  # Context index entries
        └── context/        # Extension-specific context
```

## Extension-Provided Context

Extensions supply project-specific knowledge:
- Technology stack and language details
- Development workflows and verification commands
- Coding standards and patterns
- Tool-specific guides

See `.claude/extensions/*/manifest.json` for available extensions and their capabilities.

## AI-Assisted Workflow

1. **Research**: `/research` - Gather documentation and patterns
2. **Planning**: `/plan` - Create implementation plan
3. **Implementation**: `/implement` - Execute the plan
4. **Review**: `/review` - Analyze changes

## Related Documentation

- `.claude/CLAUDE.md` - Agent system configuration
- `.claude/extensions/` - Extension modules with project-specific context
- `CLAUDE.md` (project root) - Project-specific coding standards
