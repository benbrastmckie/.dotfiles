# Documentation Refactor Plan

## Objective
Systematically refactor all documentation to be complete, concise, and perfectly tailored to the factory's purpose: providing a system for creating, storing, and exporting `.opencode/` setups.

## Current State Analysis

### dev/ (7 files, 7,919 lines)
**Purpose**: OpenCode-specific technical documentation
- `building-plugins.md` (1,273 lines) - Plugin development guide
- `logging-and-session-storage.md` (1,692 lines) - Session debugging
- `cheatsheet-context-symbols.md` (1,801 lines) - Context system reference
- `context/CONTEXT-DEEP-DIVE.md` (1,835 lines) - Deep context explanation
- `context/how-context-works.md` (416 lines) - Context basics
- `slash-commands-and-subagents.md` (538 lines) - Command/subagent creation
- `docs/context-reference-convention.md` (364 lines) - Context file conventions

### docs/ (21 files, 8,172 lines)
**Purpose**: Product documentation (installation, features, contributing)
- **getting-started/** - Installation, platform compatibility, collision handling
- **features/** - System builder, agent blueprint, prompt library
- **agents/** - General, Coder guides, prompt design
- **contributing/** - Contributing, development, code of conduct, evaluators
- **github/** - GitHub settings
- **guides/** - Building with OpenCode
- **model-providers/** - LM Studio setup

## Relevance Assessment

### ✅ KEEP & MIGRATE (Factory-Relevant)

**From dev/ai-tools/opencode/**:
1. `building-plugins.md` - Essential for extending agents
2. `context/how-context-works.md` - Core concept for factory users
3. `slash-commands-and-subagents.md` - Creating custom commands/subagents
4. `cheatsheet-context-symbols.md` - Quick reference for context system

**From docs/**:
1. `agents/general.md` - Understanding the primary agent
2. `agents/coder.md` - Understanding the coding agent
3. `agents/research-backed-prompt-design.md` - Prompt engineering principles
4. `features/agent-system-blueprint.md` - Architecture patterns

### ⚠️ ADAPT (Needs Modification)

**From dev/**:
1. `context/CONTEXT-DEEP-DIVE.md` - Too detailed, extract essentials
2. `logging-and-session-storage.md` - Extract debugging section only
3. `docs/context-reference-convention.md` - Merge into context guide

**From docs/**:
1. `contributing/DEVELOPMENT.md` - Adapt for factory development
2. `guides/building-with-opencode.md` - Adapt for factory workflow

### ❌ REMOVE (Not Factory-Relevant)

**From docs/**:
1. `getting-started/installation.md` - Product installation (not factory)
2. `getting-started/collision-handling.md` - Installer-specific
3. `getting-started/platform-compatibility.md` - Installer-specific
4. `features/builder/*` - Meta-level tool (not core factory)
5. `github/GITHUB_SETTINGS.md` - Repository management
6. `model-providers/*` - Model setup (user's responsibility)
7. `contributing/ADDING_EVALUATOR.md` - Framework development
8. `contributing/CODE_OF_CONDUCT.md` - Community management
9. `contributing/CONTRIBUTING.md` - Product contribution
10. `features/prompt-library-system.md` - Unused feature

## New Documentation Structure

```
docs/
├── README.md                          # Factory documentation index
├── getting-started/
│   ├── quick-start.md                 # 5-minute factory intro
│   └── factory-workflow.md            # Design → Test → Export workflow
├── core-concepts/
│   ├── agents.md                      # General & Coder overview
│   ├── context-system.md              # How context works (merged from dev/)
│   └── architecture.md                # Agent system blueprint
├── guides/
│   ├── creating-agents.md             # Custom agent creation
│   ├── creating-subagents.md          # Subagent patterns
│   ├── creating-commands.md           # Slash command creation
│   ├── building-plugins.md            # Plugin development
│   └── prompt-engineering.md          # Prompt design principles
├── reference/
│   ├── context-symbols.md             # Context @ symbol reference
│   ├── test-framework.md              # Using evals/ to test agents
│   └── debugging.md                   # Session debugging techniques
└── development/
    └── contributing.md                # Contributing to the factory
```

## Migration Strategy

### Phase 1: Create New Structure
1. Create new `docs/` directory structure
2. Create `docs/README.md` as the documentation hub

### Phase 2: Migrate & Consolidate
1. **Core Concepts**:
   - Merge `dev/ai-tools/opencode/context/how-context-works.md` + `CONTEXT-DEEP-DIVE.md` → `docs/core-concepts/context-system.md`
   - Copy `docs/agents/general.md` + `coder.md` → `docs/core-concepts/agents.md` (condensed)
   - Copy `docs/features/agent-system-blueprint.md` → `docs/core-concepts/architecture.md`

2. **Guides**:
   - Copy `dev/ai-tools/opencode/building-plugins.md` → `docs/guides/building-plugins.md`
   - Extract from `dev/ai-tools/opencode/slash-commands-and-subagents.md` → `docs/guides/creating-commands.md` + `creating-subagents.md`
   - Copy `docs/agents/research-backed-prompt-design.md` → `docs/guides/prompt-engineering.md`
   - Create `docs/guides/creating-agents.md` (new, based on factory workflow)

3. **Reference**:
   - Copy `dev/ai-tools/opencode/cheatsheet-context-symbols.md` → `docs/reference/context-symbols.md`
   - Extract from `dev/ai-tools/opencode/logging-and-session-storage.md` → `docs/reference/debugging.md`
   - Link to `evals/README.md` from `docs/reference/test-framework.md`

4. **Getting Started**:
   - Create `docs/getting-started/quick-start.md` (new)
   - Create `docs/getting-started/factory-workflow.md` (new)

5. **Development**:
   - Adapt `docs/contributing/DEVELOPMENT.md` → `docs/development/contributing.md`

### Phase 3: Remove Old Structure
1. Delete `dev/` directory
2. Delete irrelevant files from `docs/`
3. Update all internal links

### Phase 4: Update Root README
1. Update documentation links to point to new structure
2. Add "Documentation" section with clear navigation

## Success Criteria

- ✅ All documentation serves the factory purpose
- ✅ No installation/product-specific docs
- ✅ Clear path: Quick Start → Core Concepts → Guides → Reference
- ✅ Total documentation reduced by ~50% while maintaining completeness
- ✅ Every doc answers: "How does this help me build custom .opencode/ setups?"

## Estimated Impact

**Before**:
- 28 files, ~16,000 lines
- Mixed product/factory documentation
- Scattered across dev/ and docs/

**After**:
- ~15 files, ~8,000 lines
- 100% factory-focused
- Logical hierarchy in docs/

## Next Steps

1. Review and approve this plan
2. Execute Phase 1 (create structure)
3. Execute Phase 2 (migrate content)
4. Execute Phase 3 (cleanup)
5. Execute Phase 4 (update root README)
