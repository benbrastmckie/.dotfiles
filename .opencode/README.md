# OpenAgents `.opencode/` Directory

This directory contains the complete context-aware AI agent system for the OpenAgents project. It provides a hierarchical agent architecture with specialized subagents, custom commands, context files, plugins, and tools.

## Quick Navigation

- [Directory Structure](#directory-structure)
- [Agents](#agents)
  - [Primary Agents](#primary-agents)
  - [Subagents](#subagents)
- [Commands](#commands)
- [Context Files](#context-files)
- [Plugins](#plugins)
- [Tools](#tools)
- [Prompts](#prompts)

---

## Directory Structure

```
.opencode/
├── agent/                          # Agent definitions
│   ├── AGENT.md                    # Default/fallback agent (General)
│   ├── meta.md                     # Meta Builder orchestrator
│   ├── coder.md                    # Development agent
│   ├── general.md                  # Universal primary agent
│   ├── repository.md               # Repository-focused development agent
│   └── subagents/                  # Specialized subagents
│       ├── code/                   # Code-focused subagents
│       ├── core/                   # Core workflow subagents
│       ├── meta-builder/          # System generation subagents
│       └── utils/                  # Utility subagents
│
├── command/                        # Custom slash commands
│   ├── openagents/                 # OpenAgents-specific commands
│   │   └── new-agents/             # Agent creation commands
│   ├── prompt-engineering/         # Prompt optimization commands
│   └── *.md                        # General commands
│
├── context/                        # Context files for agents
│   ├── core/                       # Core standards and workflows
│   │   ├── standards/              # Code, docs, tests, patterns standards
│   │   ├── system/                 # System guides
│   │   └── workflows/              # Delegation, review, sessions workflows
│   ├── project/                    # Project-specific context
│   └── meta-builder-templates/    # Templates for system generation
│
├── plugin/                         # Custom plugins
│   ├── docs/                       # Plugin documentation
│   ├── lib/                        # Plugin libraries
│   └── tests/                      # Plugin tests
│
├── prompts/                        # Model-specific prompts
│   ├── openagent/                  # OpenAgent prompts for various models
│   └── opencoder/                  # OpenCoder prompts for various models
│
├── specs/                          # Specification documents
│
└── tool/                           # Custom tools
    ├── env/                        # Environment variable tools
    ├── gemini/                     # Gemini AI integration
    └── template/                   # Tool templates
```

---

## Agents

### Primary Agents

Primary agents are the main entry points for user interactions. They coordinate workflows and delegate to specialized subagents.

| Agent | File | Description |
|-------|------|-------------|
| **General** | [`agent/general.md`](agent/general.md) | Universal agent for questions, tasks, and workflow coordination. Handles code, docs, tests, reviews, and delegates to specialists. |
| **Coder** | [`agent/coder.md`](agent/coder.md) | Development specialist focused on clean, maintainable code. Follows plan-and-approve workflow with incremental implementation. |
| **Meta Builder** | [`agent/meta.md`](agent/meta.md) | Meta Builder orchestrator that creates complete `.opencode` architectures from user requirements. |
| **Repository** | [`agent/repository.md`](agent/repository.md) | Repository-focused development agent for codebase operations. |
| **AGENT** | [`agent/AGENT.md`](agent/AGENT.md) | Default/fallback agent (alias for General). |

### Subagents

Subagents are specialized agents invoked by primary agents via the `task` tool.

#### Code Subagents (`agent/subagents/code/`)

| Subagent | File | Description |
|----------|------|-------------|
| **Build Agent** | [`build-agent.md`](agent/subagents/code/build-agent.md) | Type check and build validation. Detects project language and runs appropriate checks (tsc, mypy, go build, cargo check). |
| **Codebase Pattern Analyst** | [`codebase-pattern-analyst.md`](agent/subagents/code/codebase-pattern-analyst.md) | Finds similar implementations and patterns in the codebase. Provides quality-scored examples with file:line references. |
| **Coder Agent** | [`coder-agent.md`](agent/subagents/code/coder-agent.md) | Executes coding subtasks in sequence. Follows subtask plans precisely, one task at a time. |
| **Reviewer** | [`reviewer.md`](agent/subagents/code/reviewer.md) | Code review, security, and quality assurance. Checks clarity, correctness, style, and security vulnerabilities. |
| **Tester** | [`tester.md`](agent/subagents/code/tester.md) | Test authoring and TDD. Creates positive and negative tests using Arrange-Act-Assert pattern. |

#### Core Subagents (`agent/subagents/core/`)

| Subagent | File | Description |
|----------|------|-------------|
| **Documentation** | [`documentation.md`](agent/subagents/core/documentation.md) | Documentation authoring. Creates/updates README, specs, and developer docs. |
| **Task Manager** | [`task-manager.md`](agent/subagents/core/task-manager.md) | Context-aware task breakdown specialist. Transforms complex features into atomic, verifiable subtasks with dependency tracking. |

#### Meta Builder Subagents (`agent/subagents/meta-builder/`)

| Subagent | File | Description |
|----------|------|-------------|
| **Agent Generator** | [`agent-generator.md`](agent/subagents/meta-builder/agent-generator.md) | Generates XML-optimized agent files following Stanford/Anthropic research patterns. |
| **Command Creator** | [`command-creator.md`](agent/subagents/meta-builder/command-creator.md) | Creates custom slash commands with clear syntax, routing, and examples. |
| **Context Organizer** | [`context-organizer.md`](agent/subagents/meta-builder/context-organizer.md) | Organizes and generates context files (domain, processes, standards, templates). |
| **Domain Analyzer** | [`domain-analyzer.md`](agent/subagents/meta-builder/domain-analyzer.md) | Analyzes user domains to identify core concepts, recommended agents, and context structure. |
| **Workflow Designer** | [`workflow-designer.md`](agent/subagents/meta-builder/workflow-designer.md) | Designs complete workflow definitions with context dependencies and success criteria. |

#### Utility Subagents (`agent/subagents/utils/`)

| Subagent | File | Description |
|----------|------|-------------|
| **Image Specialist** | [`image-specialist.md`](agent/subagents/utils/image-specialist.md) | Image editing and analysis using Gemini AI. Supports generation, editing, and analysis. |

---

## Commands

Custom slash commands provide quick access to common operations.

### General Commands

| Command | File | Description |
|---------|------|-------------|
| `/build-meta-system` | [`build-meta-system.md`](command/build-meta-system.md) | Interactive meta builder that creates complete context-aware AI architectures. Guides through requirements gathering and generates `.opencode` systems. |
| `/clean` | [`clean.md`](command/clean.md) | Code quality cleanup via Prettier, Import Sorter, ESLint, and TypeScript Compiler. Removes debug code, formats, optimizes imports. |
| `/commit` | [`commit.md`](command/commit.md) | Create well-formatted commits with conventional commit messages and emoji. Auto-stages, analyzes changes, generates messages. |
| `/context` | [`context.md`](command/context.md) | Analyze and understand complete project context and structure. Discovers tech stack, structure, and current state. |
| `/optimize` | [`optimize.md`](command/optimize.md) | Analyze and optimize code for performance, security, and potential issues. Comprehensive review with prioritized recommendations. |
| `/test` | [`test.md`](command/test.md) | Run complete testing pipeline (type:check, lint, test). Reports and fixes failures. |
| `/validate-repo` | [`validate-repo.md`](command/validate-repo.md) | Comprehensive validation of OpenAgents repository. Checks registry, components, profiles, documentation, and cross-references. |
| `/worktrees` | [`worktrees.md`](command/worktrees.md) | Manage git worktrees for parallel development. Create worktrees for PRs, branches, or cleanup. |

### Prompt Engineering Commands (`command/prompt-engineering/`)

| Command | File | Description |
|---------|------|-------------|
| `/prompt-enhancer` | [`prompt-enhancer.md`](command/prompt-engineering/prompt-enhancer.md) | Research-backed prompt optimizer applying Stanford/Anthropic patterns. Improves position sensitivity, nesting, instruction ratio. |
| `/prompt-optimizer` | [`prompt-optimizer.md`](command/prompt-engineering/prompt-optimizer.md) | Advanced prompt optimizer with token efficiency. Achieves 30-50% token reduction with 100% semantic preservation. |

### OpenAgents Commands (`command/openagents/`)

| Command | File | Description |
|---------|------|-------------|
| `/create-agent` | [`new-agents/create-agent.md`](command/openagents/new-agents/create-agent.md) | Create new OpenCode agents following Anthropic 2025 research-backed best practices. Generates minimal ~500 token prompts. |
| `/create-tests` | [`new-agents/create-tests.md`](command/openagents/new-agents/create-tests.md) | Generate comprehensive test suites for agents with 8 essential test types. |

---

## Context Files

Context files provide project-specific standards and knowledge that agents load before execution.

### Context Index

The main context index is at [`context/index.md`](context/index.md). Quick reference:

| Context | Path | Priority | Triggers |
|---------|------|----------|----------|
| **Code Standards** | `core/standards/code.md` | Critical | implement, refactor, architecture |
| **Docs Standards** | `core/standards/docs.md` | Critical | write docs, README, documentation |
| **Tests Standards** | `core/standards/tests.md` | Critical | write tests, testing, TDD |
| **Patterns** | `core/standards/patterns.md` | High | error handling, security, validation |
| **Analysis** | `core/standards/analysis.md` | High | analyze, investigate, debug |
| **Delegation** | `core/workflows/delegation.md` | High | delegate, task tool, subagent |
| **Review** | `core/workflows/review.md` | High | review code, audit |
| **Task Breakdown** | `core/workflows/task-breakdown.md` | High | break down, 4+ files |
| **Sessions** | `core/workflows/sessions.md` | Medium | session management, cleanup |

### Context Categories

#### Standards (`context/core/standards/`)

Project-wide quality standards for code, documentation, testing, and patterns.

#### Workflows (`context/core/workflows/`)

Process templates for delegation, code review, task breakdown, and session management.

#### System (`context/core/system/`)

System-level guides and documentation.

#### Project (`context/project/`)

Project-specific context and configuration.

#### Meta Builder Templates (`context/meta-builder-templates/`)

Templates for generating new `.opencode` systems.

---

## Plugins

Custom plugins extend agent capabilities.

| Plugin | File | Description |
|--------|------|-------------|
| **Agent Validator** | [`agent-validator.ts`](plugin/agent-validator.ts) | Validates agent sessions against defined rules and patterns. |
| **Notify** | [`notify.ts`](plugin/notify.ts) | Notification system for agent events. |
| **Telegram Notify** | [`telegram-notify.ts`](plugin/telegram-notify.ts) | Telegram bot integration for notifications. |

See [`plugin/README.md`](plugin/README.md) and [`plugin/docs/VALIDATOR_GUIDE.md`](plugin/docs/VALIDATOR_GUIDE.md) for documentation.

---

## Tools

Custom tools provide additional capabilities to agents.

| Tool | Directory | Description |
|------|-----------|-------------|
| **Environment** | [`tool/env/`](tool/env/) | Environment variable management tools. |
| **Gemini** | [`tool/gemini/`](tool/gemini/) | Gemini AI integration for image generation and editing. |
| **Template** | [`tool/template/`](tool/template/) | Tool creation templates. |

See [`tool/README.md`](tool/README.md) for documentation.

---

## Prompts

Model-specific prompt configurations for different LLM providers.

### OpenAgent Prompts (`prompts/openagent/`)

Prompts optimized for different models:
- `gemini.md` - Google Gemini
- `gpt.md` - OpenAI GPT
- `grok.md` - xAI Grok
- `llama.md` - Meta Llama

### OpenCoder Prompts (`prompts/opencoder/`)

Coder-specific prompts for different models.

---

## Key Concepts

### Agent Invocation

Subagents are invoked via the `task` tool:

```javascript
task(
  subagent_type="subagents/core/task-manager",
  description="Brief description",
  prompt="Detailed instructions for the subagent"
)
```

### Context Loading

Agents must load relevant context files before execution:

1. **Code tasks** → Load `standards/code.md`
2. **Docs tasks** → Load `standards/docs.md`
3. **Tests tasks** → Load `standards/tests.md`
4. **Review tasks** → Load `workflows/review.md`
5. **Delegation** → Load `workflows/delegation.md`

### Delegation Criteria

Agents delegate to subagents when:
- Task spans **4+ files**
- Estimated time **>60 minutes**
- Requires **specialized knowledge**
- Needs **multi-component review**
- User **explicitly requests** delegation

### Workflow Pattern

All agents follow: **Plan → Approve → Load Context → Execute → Validate → Summarize**

---

## Related Documentation

- [Agents Overview](../docs/core-concepts/agents-overview.md)
- [Architecture Patterns](../docs/core-concepts/architecture-patterns.md)
- [Context System](../docs/core-concepts/context-system.md)
- [Creating Agents](../docs/guides/creating-agents.md)
- [Creating Commands](../docs/guides/creating-commands.md)
- [Creating Subagents](../docs/guides/creating-subagents.md)
- [Prompt Engineering](../docs/guides/prompt-engineering.md)
- [Evaluation Framework](../evals/README.md)

---

## Quick Start

1. **Use the General agent** for most tasks - it will delegate as needed
2. **Use the Coder agent** for focused development work
3. **Run `/context`** to understand a new project
4. **Run `/build-meta-system`** to create a new `.opencode` system
5. **Run `/create-agent`** to create new agents following best practices

---

*This README is auto-generated. For updates, see the individual component files.*
