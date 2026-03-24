# Agent System

Task management and agent orchestration for project development. For comprehensive documentation, see @.claude/README.md.

## Quick Reference

- **Task List**: @specs/TODO.md
- **Machine State**: @specs/state.json
- **Error Tracking**: @specs/errors.json
- **Architecture**: @.claude/README.md

## Project Structure

```
.                         # Repository root
├── specs/               # Task management artifacts
│   ├── TODO.md         # Task list
│   ├── state.json      # Task state
│   └── {NNN}_{SLUG}/   # Task directories
└── .claude/             # Claude Code configuration
    ├── commands/       # Slash commands
    ├── skills/         # Skill definitions
    ├── agents/         # Agent definitions
    ├── rules/          # Auto-applied rules
    └── context/        # Domain knowledge
```

**Project-specific structure**: See `.claude/context/project/repo/project-overview.md` for details about this repository's layout.

**New repository setup**: If project-overview.md doesn't exist, see `.claude/context/project/repo/update-project.md` for guidance on generating project-appropriate documentation.

## Task Management

### Status Markers
- `[NOT STARTED]` - Initial state
- `[RESEARCHING]` -> `[RESEARCHED]` - Research phase
- `[PLANNING]` -> `[PLANNED]` - Planning phase
- `[IMPLEMENTING]` -> `[COMPLETED]` - Implementation phase
- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states

### Artifact Paths
```
specs/{NNN}_{SLUG}/
├── reports/MM_{short-slug}.md
├── plans/MM_{short-slug}.md
└── summaries/MM_{short-slug}-summary.md
```
`{NNN}` = 3-digit zero-padded task directory numbers, `{DATE}` = YYYYMMDD.

**Naming Convention**: Artifacts use `MM_{short-slug}.md` format:
- `MM` = Zero-padded sequence number within task (01, 02, 03...)
- `{short-slug}` = 3-5 word kebab-case description extracted from task title
- Examples: `01_configure-lsp-python.md`, `02_implementation-plan.md`, `03_execution-summary.md`

**Note**: Task numbers remain unpadded (`{N}`) in TODO.md entries, state.json values, and commit messages. Only directory names and artifact sequence numbers use zero-padding for lexicographic sorting.

**System-Specific Naming**: Task directories use different prefixes by system:
- **Claude Code** (.claude/): `specs/{NNN}_{SLUG}/` (no prefix)
- **OpenCode** (.opencode/): `specs/OC_{NNN}_{SLUG}/` (OC_ prefix)

This distinction enables identification of which system created each task.

### Language-Based Routing

**Core Languages** (always available):

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `general` | `skill-researcher` | `skill-implementer` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `meta` | `skill-researcher` | `skill-implementer` | Read, Grep, Glob, Write, Edit |
| `markdown` | `skill-researcher` | `skill-implementer` | Read, Write, Edit |

**Extension Languages** (available when extensions are loaded via `<leader>ac`):

Extensions provide additional language support (neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal, etc.). See `.claude/extensions/*/manifest.json` for available extensions and their capabilities.

When an extension is loaded, its routing entries are merged into the command tables and context index.

## Command Reference

All commands use checkpoint-based execution: GATE IN (preflight) -> DELEGATE (skill/agent) -> GATE OUT (postflight) -> COMMIT.

| Command | Usage | Description |
|---------|-------|-------------|
| `/task` | `/task "Description"` | Create task |
| `/task` | `/task --recover N`, `--expand N`, `--sync`, `--abandon N` | Manage tasks |
| `/research` | `/research N [focus] [--team]` | Research task, route by language |
| `/plan` | `/plan N [--team]` | Create implementation plan |
| `/implement` | `/implement N [--team]` | Execute plan, resume from incomplete phase |
| `/revise` | `/revise N` | Create new plan version |
| `/review` | `/review` | Analyze codebase |
| `/todo` | `/todo` | Archive completed/abandoned tasks, sync repository metrics |
| `/errors` | `/errors` | Analyze error patterns, create fix plans |
| `/meta` | `/meta` | System builder for .claude/ changes |
| `/fix-it` | `/fix-it [PATH...]` | Scan for FIX:/NOTE:/TODO: tags |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and old files |
| `/tag` | `/tag [--patch|--minor|--major]` | Create semantic version tag (user-only) |
| `/spawn` | `/spawn N [blocker description]` | Spawn new tasks to unblock a blocked task |

### Utility Scripts

- `.claude/scripts/export-to-markdown.sh` - Export .claude/ directory to consolidated markdown file

## State Synchronization

TODO.md and state.json must stay synchronized. Update state.json first (machine state), then TODO.md (user-facing).

### state.json Structure
```json
{
  "next_project_number": 1,
  "active_projects": [{
    "project_number": 1,
    "project_name": "task_slug",
    "status": "planned",
    "language": "neovim",
    "completion_summary": "Required when status=completed",
    "roadmap_items": ["Optional explicit roadmap items"]
  }],
  "repository_health": {
    "last_assessed": "ISO8601 timestamp",
    "status": "healthy"
  }
}
```

### Completion Workflow
- Non-meta tasks: `completion_summary` + optional `roadmap_items` -> /todo annotates ROAD_MAP.md
- Meta tasks: `completion_summary` + `claudemd_suggestions` -> /todo displays for user review

### Vault Operation (Task Number Reset)

When `next_project_number` exceeds 1000, the `/todo` command initiates vault archival:

1. **Trigger**: `next_project_number > 1000` detected during /todo execution
2. **User Confirmation**: AskUserQuestion with renumbering preview
3. **Vault Creation**: Move `specs/archive/` to `specs/vault/{NN-vault}/`
4. **Renumbering**: Tasks > 1000 renumbered by subtracting 1000 (e.g., 1003 -> 3)
5. **State Reset**: `next_project_number` set to max(renumbered) + 1

**Vault Fields** in state.json:
- `vault_count`: Number of completed vault operations
- `vault_history`: Array of vault metadata entries

See `.claude/rules/state-management.md` for complete vault schema documentation.

## Git Commit Conventions

Format: `task {N}: {action}` with session ID in body.
```
task 1: complete research

Session: sess_1736700000_abc123

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Standard actions: `create`, `complete research`, `create implementation plan`, `phase {P}: {name}`, `complete implementation`.

## Skill-to-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-researcher | general-research-agent | opus | General web/codebase research |
| skill-planner | planner-agent | opus | Implementation plan creation |
| skill-implementer | general-implementation-agent | - | General file implementation |
| skill-meta | meta-builder-agent | - | System building and task creation |
| skill-status-sync | (direct execution) | - | Atomic status updates |
| skill-refresh | (direct execution) | - | Process and file cleanup |
| skill-todo | (direct execution) | - | Archive completed tasks with CHANGE_LOG updates |
| skill-tag | (user-only) | - | Semantic version tagging for deployment |
| skill-team-research | (team orchestration) | sonnet | Multi-agent parallel research (--team flag) |
| skill-team-plan | (team orchestration) | sonnet | Multi-agent parallel planning (--team flag) |
| skill-team-implement | (team orchestration) | sonnet | Multi-agent parallel implementation (--team flag) |
| skill-spawn | spawn-agent | opus | Analyze blockers and spawn new tasks |

### Agents

| Agent | Purpose |
|-------|---------|
| general-research-agent | General web/codebase research |
| general-implementation-agent | General file implementation |
| planner-agent | Implementation plan creation |
| meta-builder-agent | System building and meta tasks |
| code-reviewer-agent | Code quality assessment and review |
| spawn-agent | Blocker analysis and task decomposition |

**Model Enforcement**: Agents declare preferred models via `model:` frontmatter field. Research and planning agents use `opus` for superior reasoning. Implementation agents use default model. See `.claude/docs/reference/standards/agent-frontmatter-standard.md` for details.

**User-Only Skills**: Skills marked as "user-only" cannot be invoked by agents. These are for human-controlled operations like deployment (`skill-tag`).

**Extension Skills**: When extensions are loaded, additional skill-to-agent mappings are added (e.g., skill-neovim-research -> neovim-research-agent).

**Team Mode Skills**: When `--team` flag is passed to `/research`, `/plan`, or `/implement`, routing overrides to team skills which spawn multiple parallel teammates. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. Gracefully degrades to single-agent if unavailable.

| Flag | Team Skill | Teammates | Purpose |
|------|------------|-----------|---------|
| `--team` | skill-team-research | 2-4 | Parallel investigation with synthesis |
| `--team` | skill-team-plan | 2-3 | Parallel plan generation with trade-offs |
| `--team` | skill-team-implement | 2-4 | Parallel phase execution with debugger |

**Note**: Team mode uses ~5x tokens compared to single-agent. Default team_size=2 minimizes cost.

## Rules References

Core rules (auto-applied by file path):
- @.claude/rules/state-management.md - Task state patterns (specs/**)
- @.claude/rules/git-workflow.md - Commit conventions
- @.claude/rules/error-handling.md - Error recovery (.claude/**)
- @.claude/rules/artifact-formats.md - Report/plan formats (specs/**)
- @.claude/rules/workflows.md - Command lifecycle (.claude/**)

**Extension Rules**: When extensions are loaded, additional rules are added (e.g., neovim-lua.md for Lua development).

## Context Discovery

Agents use `index.json` for automated context discovery instead of hardcoded file lists:

```bash
# Find context files for an agent
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | .path' .claude/context/index.json

# Find context by task language
jq -r '.entries[] | select(.load_when.languages[]? == "lean4") | .path' .claude/context/index.json

# Get line counts for budget calculation
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | "\(.line_count)\t\(.path)"' .claude/context/index.json
```

See `.claude/context/core/patterns/context-discovery.md` for query patterns.

**Extension Context**: When extensions are loaded, their index entries are merged into `index.json`, enabling dynamic context discovery for extension-specific agents and languages.

## Context Imports

Core context (always available):
- @.claude/context/project/repo/project-overview.md
- @.claude/context/project/meta/meta-guide.md

**Extension Context**: Available when extensions are loaded via `<leader>ac`. Query `index.json` for extension-specific context files.

## Multi-Task Creation Standards

Commands that create multiple tasks follow a standardized 8-component pattern. See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the complete specification.

**Commands Using Multi-Task Creation**:
| Command | Compliance | Notes |
|---------|------------|-------|
| `/meta` | Full (Reference) | All 8 components, Kahn's algorithm, DAG visualization |
| `/fix-it` | Full | Interactive selection, topic grouping, internal dependencies |
| `/review` | Partial | Tier-based selection, grouping; no dependencies |
| `/errors` | Partial | Automatic mode (intentional); no interactive selection |
| `/task --review` | Partial | Numbered selection, parent_task linking |

**Required Components** (all multi-task creators):
- Item Discovery - Identify potential tasks
- Interactive Selection - AskUserQuestion with multiSelect
- User Confirmation - Explicit "Yes, create tasks" before creation
- State Updates - Atomic state.json + TODO.md updates

**Optional Components** (for 3+ tasks):
- Topic Grouping - Cluster related items
- Dependency Declaration - Ask about task relationships
- Topological Sorting - Kahn's algorithm for ordering
- Visualization - Linear chain or layered DAG display

## Error Handling

- **On failure**: Keep task in current status, log to errors.json, preserve partial progress
- **On timeout**: Mark phase [PARTIAL], next /implement resumes
- **Git failures**: Non-blocking (logged, not fatal)

## jq Command Safety

Claude Code Issue #1132 causes jq parse errors when using `!=` operator (escaped as `\!=`).

**Safe pattern**: Use `select(.type == "X" | not)` instead of `select(.type != "X")`

```bash
# SAFE - use "| not" pattern
select(.type == "plan" | not)

# UNSAFE - gets escaped as \!=
select(.type != "plan")
```

Full documentation: @.claude/context/core/patterns/jq-escaping-workarounds.md

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading via @-references
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits

<!-- SECTION: extension_memory -->
## Memory Extension

This project includes the memory vault extension for knowledge capture and retrieval.

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/learn` | `/learn "text"` | Add text as memory (with content mapping and deduplication) |
| `/learn` | `/learn /path/to/file` | Add file content as memory |
| `/learn` | `/learn /path/to/dir/` | Scan directory for learnable content |
| `/learn` | `/learn --task N` | Review task artifacts and create memories |

All input modes flow through content mapping, MCP-based memory search (or grep fallback), and three memory operations (UPDATE, EXTEND, CREATE).

### Memory-Augmented Research

The `--remember` flag on `/research` enables memory-augmented research:

```bash
/research N --remember
```

When the memory extension is loaded, this flag:
1. Searches the memory vault for relevant prior knowledge
2. Includes top matching memories in research context
3. Adds "Prior Knowledge from Memory Vault" section to the report

**Note**: The `--remember` flag requires this extension to be loaded. If the extension is not loaded, the flag is ignored gracefully.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-memory | (direct execution) | Memory creation and management |

### MCP Integration

The `obsidian-memory` MCP server provides memory search via the two-tool pattern:

| Tool | Usage | Description |
|------|-------|-------------|
| `execute("search", {...})` | `execute("search", {query: "...", vault: ".memory", limit: 5})` | Search memories by keywords |
| `execute("read", {...})` | `execute("read", {path: "..."})` | Retrieve full memory content |
| `execute("write", {...})` | `execute("write", {path: "...", content: "..."})` | Create new memory |
| `execute("list", {...})` | `execute("list", {vault: ".memory"})` | Enumerate all memories |

**Setup**: See memory-setup.md context file for MCP server configuration.

**Graceful Degradation**: If MCP is unavailable, grep-based search on .memory/10-Memories/*.md still works.

### Memory Vault Structure

```
.memory/
+-- .obsidian/           # Obsidian configuration
+-- 00-Inbox/            # Quick capture for new memories
+-- 10-Memories/         # Stored memory entries
+-- 20-Indices/          # Navigation and organization
+-- 30-Templates/        # Memory entry templates
```

### Memory Classification

When using `/learn --task N`, memories are classified into categories:

- **[TECHNIQUE]** - Reusable method or approach
- **[PATTERN]** - Design or implementation pattern
- **[CONFIG]** - Configuration or setup knowledge
- **[WORKFLOW]** - Process or procedure
- **[INSIGHT]** - Key learning or understanding

### Memory Operations

The `/learn` command uses three memory operations based on overlap scoring:

| Operation | Overlap | Description |
|-----------|---------|-------------|
| **UPDATE** | >60% | Replace existing memory content (old content preserved in History section) |
| **EXTEND** | 30-60% | Append dated section to existing memory |
| **CREATE** | <30% | Create new memory file |

### Topic Organization

Memories now include a `topic` field in frontmatter with slash-separated hierarchical paths:

```yaml
topic: "neovim/plugins/telescope"
```

The index.md includes both "By Category" and "By Topic" sections for navigation.

<!-- END_SECTION: extension_memory -->

<!-- SECTION: extension_nix -->
## Nix Extension

This project includes NixOS and Home Manager configuration support via the nix extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `nix` | MCP-NixOS, WebSearch, WebFetch, Read | Read, Write, Edit, Bash (nix flake check, nixos-rebuild, home-manager) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-nix-research | nix-research-agent | NixOS/Home Manager/flakes research with MCP-NixOS |
| skill-nix-implementation | nix-implementation-agent | Nix configuration implementation with verification |

### Key Technologies

- **NixOS**: Declarative Linux distribution with reproducible system configurations
- **Home Manager**: User-level declarative configuration management
- **Nix Flakes**: Reproducible, hermetic package management with lockfiles
- **MCP-NixOS**: Model Context Protocol server for package/option search and validation

### Build Verification

```bash
# Check flake syntax and evaluate outputs
nix flake check

# Show flake outputs
nix flake show

# Build NixOS configuration
nixos-rebuild build --flake .#hostname

# Build Home Manager configuration
home-manager build --flake .#user

# Evaluate specific expression
nix eval .#path
```

### Context Categories

- **Domain**: Core Nix concepts (Nix language, flakes, NixOS modules, Home Manager)
- **Patterns**: Implementation patterns (modules, overlays, derivations)
- **Standards**: Coding conventions (style guide)
- **Tools**: Tool-specific guides (nixos-rebuild, home-manager)

### MCP-NixOS Integration

The MCP-NixOS server provides enhanced package and option validation:

```bash
# Available via MCP tools when configured:
mcp__nixos__nix(action="search", query="pkgname", source="nixpkgs")
mcp__nixos__nix(action="options", query="services.X", source="nixos-options")
mcp__nixos__nix_versions(package="nodejs")
```

Agents gracefully degrade to WebSearch and CLI commands when MCP is unavailable.

<!-- END_SECTION: extension_nix -->

<!-- SECTION: extension_nvim -->
## Neovim Extension

This project includes Neovim configuration development support via the nvim extension.

### Language Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `neovim` | `skill-neovim-research` | `skill-neovim-implementation` | WebSearch, WebFetch, Read, Bash (nvim --headless) |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | opus | Neovim/plugin research |
| skill-neovim-implementation | neovim-implementation-agent | - | Neovim configuration implementation |

### Rules

- neovim-lua.md - Neovim Lua development (lua/**/*.lua, after/**/*.lua)

### Neovim Patterns

- Use `vim.keymap.set` with description for all keymaps
- Use `vim.opt` over `vim.o` for options
- Always use augroups with `clear = true` for autocommands
- Use `pcall` for optional module loading

### Common Operations

- **Keymaps**: `vim.keymap.set("n", "<leader>x", fn, { desc = "Description" })`
- **Options**: `vim.opt.number = true`
- **Autocommands**: `vim.api.nvim_create_augroup("Name", { clear = true })`
- **Plugin specs**: lazy.nvim table format with event/cmd/ft/keys triggers

### Context Imports

Domain knowledge (load as needed):
- @.claude/context/project/neovim/domain/neovim-api.md
- @.claude/context/project/neovim/patterns/plugin-spec.md
- @.claude/context/project/neovim/tools/lazy-nvim-guide.md

<!-- END_SECTION: extension_nvim -->

<!-- SECTION: extension_python -->
## Python Extension

This project includes Python development support via the python extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `python` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (python, pytest) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-python-research | python-research-agent | Python/library research |
| skill-python-implementation | python-implementation-agent | Python implementation |

### Testing

- Run tests: `pytest`
- Run specific test: `pytest path/to/test.py::test_function`
- Coverage: `pytest --cov=src`
- Watch mode: `pytest-watch`

### Code Quality

- Type checking: `mypy src/`
- Linting: `ruff check src/`
- Formatting: `ruff format src/`
- All checks: `make lint` or `nox -s lint`

<!-- END_SECTION: extension_python -->
