# Documentation Refactor - Detailed Implementation Plan

## Executive Summary

This plan refactors all documentation to be factory-focused while **preserving and improving** builder documentation, which is a core factory component for generating custom `.opencode/` setups.

## Key Insight: Meta Builder IS the Factory

The meta builder agent is not a "meta-level tool" to remove—it's **the automated factory mechanism**. Users can either:
1. **Manual approach**: Hand-craft agents by editing files in `.opencode/agent/`
2. **Automated approach**: Use meta builder to generate complete `.opencode/` setups via interview

Both approaches are core to the factory's purpose.

---

## Current Documentation Inventory

### Meta Builder Components (KEEP ALL)

**Agent Files** (`.opencode/agent/`):
- `meta.md` - Main orchestrator (1,000+ lines)
- `subagents/meta-builder/domain-analyzer.md`
- `subagents/meta-builder/agent-generator.md`
- `subagents/meta-builder/context-organizer.md`
- `subagents/meta-builder/workflow-designer.md`
- `subagents/meta-builder/command-creator.md`

**Command Files** (`.opencode/command/`):
- `build-meta-system.md` - Interactive interview command

**Templates** (`.opencode/context/meta-builder-templates/`):
- `orchestrator-template.md` - Template for generated orchestrators
- `subagent-template.md` - Template for generated subagents
- `SYSTEM-BUILDER-GUIDE.md` - Complete usage guide
- `README.md` - Template overview

**Documentation** (`docs/meta-builder/`):
- `README.md` - Installation and overview
- `guide.md` - Complete guide
- `quick-start.md` - Quick start guide

### Other Documentation

**dev/** (7 files, 7,919 lines):
- OpenCode technical docs (plugins, context, commands, debugging)

**docs/** (18 files excluding builder):
- Agent guides, contributing, installation, features, etc.

---

## New Documentation Structure

```
docs/
├── README.md                                    # Documentation hub
│
├── getting-started/
│   ├── quick-start.md                          # NEW: 5-min factory intro
│   ├── manual-workflow.md                      # NEW: Hand-crafting agents
│   └── automated-workflow.md                   # NEW: Using builder
│
├── core-concepts/
│   ├── what-is-the-factory.md                  # NEW: Factory purpose & approaches
│   ├── agents-overview.md                      # ADAPTED: General + Coder
│   ├── context-system.md                       # MERGED: From dev/
│   └── architecture-patterns.md                # ADAPTED: Agent system blueprint
│
├── meta-builder/                             # REORGANIZED & ENHANCED
│   ├── README.md                               # Overview & when to use
│   ├── quick-start.md                          # 5-min tutorial
│   ├── complete-guide.md                       # Full documentation
│   ├── interview-questions.md                  # NEW: Question reference
│   ├── generated-structure.md                  # NEW: What gets created
│   ├── templates-reference.md                  # NEW: Template documentation
│   └── examples/                               # NEW: Example systems
│       ├── ecommerce-system.md
│       ├── content-management-system.md
│       └── data-pipeline-system.md
│
├── guides/
│   ├── creating-agents.md                      # NEW: Manual agent creation
│   ├── creating-subagents.md                   # EXTRACTED: From dev/
│   ├── creating-commands.md                    # EXTRACTED: From dev/
│   ├── building-plugins.md                     # MIGRATED: From dev/
│   ├── context-files.md                        # NEW: Creating context files
│   └── prompt-engineering.md                   # MIGRATED: From docs/agents/
│
├── reference/
│   ├── context-symbols.md                      # MIGRATED: From dev/
│   ├── agent-frontmatter.md                    # NEW: YAML frontmatter reference
│   ├── testing-agents.md                       # NEW: Using evals/ framework
│   ├── debugging-sessions.md                   # EXTRACTED: From dev/
│   └── api-reference.md                        # NEW: Tool/hook reference
│
└── development/
    ├── contributing.md                         # ADAPTED: Factory contribution
    └── adding-evaluators.md                    # MIGRATED: From docs/contributing/
```

---

## Detailed Migration Plan

### Phase 1: Create Structure & Core Docs

#### 1.1 Create Directory Structure
```bash
mkdir -p docs/{getting-started,core-concepts,builder/examples,guides,reference,development}
```

#### 1.2 Create Documentation Hub (`docs/README.md`)
**Content**:
- Factory purpose and two approaches (manual vs automated)
- Quick navigation to all sections
- "I want to..." decision tree
- Links to getting started paths

**Length**: ~150 lines

#### 1.3 Create `docs/core-concepts/what-is-the-factory.md`
**Content**:
- Factory purpose: Design, test, export `.opencode/` setups
- Two approaches:
  - **Manual**: Hand-craft by editing agent files
  - **Automated**: Use builder to generate via interview
- When to use each approach
- Factory workflow: Design → Test → Export

**Length**: ~100 lines

---

### Phase 2: Meta Builder Documentation (ENHANCE)

#### 2.1 Reorganize Existing Docs

**`docs/meta-builder/README.md`**:
- **Source**: Current `docs/meta-builder/README.md`
- **Changes**: 
  - Remove installation instructions (not relevant to factory)
  - Add "When to use builder vs manual approach"
  - Add link to examples
- **Length**: ~150 lines

**`docs/meta-builder/quick-start.md`**:
- **Source**: Current `docs/meta-builder/quick-start.md`
- **Changes**:
  - Remove installation section
  - Focus on running `/build-meta-system` in factory
  - Add "What happens next" section
- **Length**: ~120 lines

**`docs/meta-builder/complete-guide.md`**:
- **Source**: Current `docs/meta-builder/complete-guide.md` + `.opencode/context/meta-builder-templates/SYSTEM-BUILDER-GUIDE.md`
- **Changes**:
  - Merge both guides into comprehensive documentation
  - Add architecture diagrams
  - Document all 5 subagents
  - Explain template system
- **Length**: ~600 lines

#### 2.2 Create New Meta Builder Docs

**`docs/meta-builder/interview-questions.md`** (NEW):
- **Content**:
  - Complete list of interview questions
  - What each question determines
  - Example answers for different domains
  - Tips for effective responses
- **Length**: ~200 lines

**`docs/meta-builder/generated-structure.md`** (NEW):
- **Content**:
  - Detailed breakdown of generated files
  - Orchestrator structure and patterns
  - Subagent patterns
  - Context file organization
  - Workflow definitions
  - Command structure
- **Length**: ~250 lines

**`docs/meta-builder/templates-reference.md`** (NEW):
- **Content**:
  - Document `orchestrator-template.md`
  - Document `subagent-template.md`
  - Explain template variables
  - Customization guide
- **Source**: `.opencode/context/builder-templates/`
- **Length**: ~200 lines

**`docs/meta-builder/examples/`** (NEW):
- **Content**: 3 complete example systems
  - E-commerce operations system
  - Content management system
  - Data pipeline system
- Each example shows:
  - Interview responses
  - Generated structure
  - Key files with explanations
- **Length**: ~150 lines each (450 total)

---

### Phase 3: Migrate Core Concepts

#### 3.1 Context System Documentation

**`docs/core-concepts/context-system.md`**:
- **Sources**:
  - `dev/ai-tools/opencode/context/how-context-works.md` (416 lines)
  - `dev/ai-tools/opencode/context/CONTEXT-DEEP-DIVE.md` (1,835 lines) - extract essentials
  - `dev/docs/context-reference-convention.md` (364 lines)
- **Content**:
  - What is the context system
  - The `@` symbol and context loading
  - Context file structure
  - Context levels (0-3)
  - Creating context files
  - Best practices
- **Length**: ~500 lines (condensed from 2,615)

#### 3.2 Agents Overview

**`docs/core-concepts/agents-overview.md`**:
- **Sources**:
  - `docs/agents/general.md` (1,245 lines) - condense
  - `docs/agents/coder.md` (441 lines) - condense
- **Content**:
  - What are agents
  - General: Universal coordinator
  - Coder: Development specialist
  - When to use each
  - How they work together
  - Subagent delegation
- **Length**: ~400 lines (condensed from 1,686)

#### 3.3 Architecture Patterns

**`docs/core-concepts/architecture-patterns.md`**:
- **Source**: `docs/features/agent-system-blueprint.md` (515 lines)
- **Changes**:
  - Focus on patterns applicable to factory
  - Remove product-specific sections
  - Add factory-specific patterns
- **Length**: ~400 lines

---

### Phase 4: Create Practical Guides

#### 4.1 Manual Agent Creation

**`docs/guides/creating-agents.md`** (NEW):
- **Content**:
  - Agent file structure
  - YAML frontmatter reference
  - Prompt engineering basics
  - Context loading patterns
  - Tool configuration
  - Testing your agent
  - Example: Creating a simple agent
- **Length**: ~350 lines

#### 4.2 Subagents & Commands

**`docs/guides/creating-subagents.md`**:
- **Source**: Extract from `dev/ai-tools/opencode/slash-commands-and-subagents.md` (538 lines)
- **Content**:
  - What are subagents
  - When to create subagents
  - Subagent patterns
  - Delegation patterns
  - Example subagents
- **Length**: ~250 lines

**`docs/guides/creating-commands.md`**:
- **Source**: Extract from `dev/ai-tools/opencode/slash-commands-and-subagents.md` (538 lines)
- **Content**:
  - What are slash commands
  - Command structure
  - Routing to agents
  - Parameter handling
  - Example commands
- **Length**: ~200 lines

#### 4.3 Other Guides

**`docs/guides/building-plugins.md`**:
- **Source**: `dev/ai-tools/opencode/building-plugins.md` (1,273 lines)
- **Changes**: Minor - already well-structured
- **Length**: ~1,200 lines

**`docs/guides/context-files.md`** (NEW):
- **Content**:
  - Creating domain context
  - Creating process context
  - Creating standards context
  - Creating templates
  - Context file patterns
- **Length**: ~300 lines

**`docs/guides/prompt-engineering.md`**:
- **Source**: `docs/agents/research-backed-prompt-design.md` (303 lines)
- **Changes**: Adapt for factory context
- **Length**: ~300 lines

---

### Phase 5: Reference Documentation

#### 5.1 Context Symbols Reference

**`docs/reference/context-symbols.md`**:
- **Source**: `dev/ai-tools/opencode/cheatsheet-context-symbols.md` (1,801 lines)
- **Changes**: 
  - Keep as comprehensive reference
  - Add factory-specific examples
- **Length**: ~1,800 lines

#### 5.2 New Reference Docs

**`docs/reference/agent-frontmatter.md`** (NEW):
- **Content**:
  - Complete YAML frontmatter reference
  - All available fields
  - Tool configuration
  - Permission configuration
  - Examples
- **Length**: ~200 lines

**`docs/reference/testing-agents.md`** (NEW):
- **Content**:
  - Overview of evals/ framework
  - Running core tests
  - Creating custom tests
  - Test YAML structure
  - Link to `evals/README.md`
- **Length**: ~250 lines

**`docs/reference/debugging-sessions.md`**:
- **Source**: Extract from `dev/ai-tools/opencode/logging-and-session-storage.md` (1,692 lines)
- **Content**:
  - Session storage structure
  - Debugging techniques
  - Common issues
  - Using check-context-logs scripts
- **Length**: ~300 lines

**`docs/reference/api-reference.md`** (NEW):
- **Content**:
  - Available tools (read, write, edit, bash, task, etc.)
  - Tool parameters
  - Plugin hooks
  - SDK reference
- **Length**: ~400 lines

---

### Phase 6: Getting Started Guides

#### 6.1 Quick Start

**`docs/getting-started/quick-start.md`** (NEW):
- **Content**:
  - 5-minute factory introduction
  - Clone and setup
  - Two approaches overview
  - First steps for each approach
  - Next steps
- **Length**: ~150 lines

#### 6.2 Workflow Guides

**`docs/getting-started/manual-workflow.md`** (NEW):
- **Content**:
  - When to use manual approach
  - Step-by-step: Create agent → Add context → Test → Export
  - Example walkthrough
  - Tips and best practices
- **Length**: ~250 lines

**`docs/getting-started/automated-workflow.md`** (NEW):
- **Content**:
  - When to use builder
  - Step-by-step: Run interview → Review generated files → Customize → Test → Export
  - Example walkthrough
  - Tips for effective interviews
- **Length**: ~250 lines

---

### Phase 7: Development Documentation

**`docs/development/contributing.md`**:
- **Source**: Adapt `docs/contributing/DEVELOPMENT.md` (760 lines)
- **Content**:
  - Contributing to the factory
  - Adding new agents
  - Improving documentation
  - Testing changes
  - Submitting PRs
- **Length**: ~400 lines

**`docs/development/adding-evaluators.md`**:
- **Source**: `docs/contributing/ADDING_EVALUATOR.md` (264 lines)
- **Changes**: Minor updates for factory context
- **Length**: ~250 lines

---

## Phase 8: Cleanup & Finalization

### 8.1 Remove Obsolete Documentation

**Delete entirely**:
- `docs/getting-started/installation.md` - Product installation
- `docs/getting-started/collision-handling.md` - Installer-specific
- `docs/getting-started/platform-compatibility.md` - Installer-specific
- `docs/getting-started/context-aware-system/` - Duplicate of builder
- `docs/github/GITHUB_SETTINGS.md` - Repository management
- `docs/model-providers/` - User's responsibility
- `docs/contributing/CODE_OF_CONDUCT.md` - Community management
- `docs/contributing/CONTRIBUTING.md` - Product contribution
- `docs/features/prompt-library-system.md` - Unused feature
- `docs/guides/building-with-opencode.md` - Product-specific

**Delete directory**:
- `dev/` - All content migrated to `docs/`

### 8.2 Update Root README

**Changes to `README.md`**:
- Update "Documentation" section with new structure
- Add clear navigation to both approaches
- Link to `docs/README.md` as documentation hub
- Update "Directory Structure" section

### 8.3 Update Internal Links

- Update all `@context` references in agent files
- Update links in `.opencode/context/index.md`
- Update links in `evals/README.md`
- Update links in `QUICK_START.md`

---

## Summary Statistics

### Before Refactor
- **Total files**: 28 documentation files
- **Total lines**: ~16,000 lines
- **Structure**: Scattered across `dev/` and `docs/`
- **Focus**: Mixed product/factory

### After Refactor
- **Total files**: ~35 documentation files (more organized, not more content)
- **Total lines**: ~11,000 lines (31% reduction)
- **Structure**: Unified in `docs/` with clear hierarchy
- **Focus**: 100% factory-focused

### Meta Builder Documentation
- **Before**: 3 files, ~1,200 lines
- **After**: 10 files, ~2,200 lines (enhanced with examples and references)
- **Improvement**: More comprehensive, better organized, includes examples

---

## Implementation Checklist

### Phase 1: Structure (30 min)
- [ ] Create directory structure
- [ ] Create `docs/README.md`
- [ ] Create `docs/core-concepts/what-is-the-factory.md`

### Phase 2: Meta Builder (3 hours)
- [ ] Reorganize existing meta-builder docs
- [ ] Create interview questions reference
- [ ] Create generated structure guide
- [ ] Create templates reference
- [ ] Create 3 example systems

### Phase 3: Core Concepts (2 hours)
- [ ] Merge and condense context system docs
- [ ] Condense agents overview
- [ ] Adapt architecture patterns

### Phase 4: Guides (3 hours)
- [ ] Create manual agent creation guide
- [ ] Extract and create subagents guide
- [ ] Extract and create commands guide
- [ ] Migrate plugins guide
- [ ] Create context files guide
- [ ] Adapt prompt engineering guide

### Phase 5: Reference (2 hours)
- [ ] Migrate context symbols reference
- [ ] Create frontmatter reference
- [ ] Create testing reference
- [ ] Extract debugging guide
- [ ] Create API reference

### Phase 6: Getting Started (1 hour)
- [ ] Create quick start
- [ ] Create manual workflow guide
- [ ] Create automated workflow guide

### Phase 7: Development (1 hour)
- [ ] Adapt contributing guide
- [ ] Migrate evaluators guide

### Phase 8: Cleanup (1 hour)
- [ ] Delete obsolete docs
- [ ] Delete `dev/` directory
- [ ] Update root README
- [ ] Update all internal links
- [ ] Verify all links work

**Total estimated time**: 13-15 hours

---

## Success Criteria

- ✅ Meta-builder documentation is comprehensive and enhanced
- ✅ Clear distinction between manual and automated approaches
- ✅ All documentation serves factory purpose
- ✅ No product/installation documentation remains
- ✅ Logical hierarchy: Getting Started → Core Concepts → Guides → Reference
- ✅ All internal links work
- ✅ Documentation reduced by ~30% while improving completeness
- ✅ Every doc answers: "How does this help me build custom .opencode/ setups?"

---

## Next Steps

1. **Review this plan** - Approve or request changes
2. **Execute Phase 1** - Create structure and core docs
3. **Execute Phase 2** - Enhance meta-builder documentation (priority)
4. **Execute Phases 3-7** - Migrate and create remaining docs
5. **Execute Phase 8** - Cleanup and finalization
6. **Verify** - Test all links and ensure completeness
