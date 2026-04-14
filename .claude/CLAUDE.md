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

**Project-specific structure**: See `.claude/context/repo/project-overview.md` for details about this repository's layout.

**New repository setup**: If project-overview.md doesn't exist, see `.claude/context/repo/update-project.md` for guidance on generating project-appropriate documentation.

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

### Task-Type-Based Routing

**Core Task Types** (always available):

| Task Type | Research Skill | Implementation Skill | Tools |
|-----------|----------------|---------------------|-------|
| `general` | `skill-researcher` | `skill-implementer` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `meta` | `skill-researcher` | `skill-implementer` | Read, Grep, Glob, Write, Edit |
| `markdown` | `skill-researcher` | `skill-implementer` | Read, Write, Edit |

**Extension Task Types** (available when extensions are loaded via `<leader>ac`):

Extensions provide additional task type support (neovim, lean4, latex, typst, python, nix, web, z3, epi, formal, founder, present, etc.). See `.claude/extensions/*/manifest.json` for available extensions and their capabilities.

When an extension is loaded, its routing entries are merged into the command tables and context index.

## Command Reference

All commands use checkpoint-based execution: GATE IN (preflight) -> DELEGATE (skill/agent) -> GATE OUT (postflight) -> COMMIT.

| Command | Usage | Description |
|---------|-------|-------------|
| `/task` | `/task "Description"` | Create task |
| `/task` | `/task --recover N`, `--expand N`, `--sync`, `--abandon N` | Manage tasks |
| `/research` | `/research N[,N-N] [focus] [--team]` | Research task(s), route by task type |
| `/plan` | `/plan N[,N-N] [--team]` | Create implementation plan(s) |
| `/implement` | `/implement N[,N-N] [--team] [--force]` | Execute plan(s), resume from incomplete phase |
| `/revise` | `/revise N` | Create new plan version |
| `/review` | `/review` | Analyze codebase |
| `/todo` | `/todo` | Archive completed/abandoned tasks, sync repository metrics |
| `/errors` | `/errors` | Analyze error patterns, create fix plans |
| `/meta` | `/meta` | System builder for .claude/ changes |
| `/fix-it` | `/fix-it [PATH...]` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and old files |
| `/tag` | `/tag [--patch|--minor|--major]` | Create semantic version tag (user-only) |
| `/spawn` | `/spawn N [blocker description]` | Spawn new tasks to unblock a blocked task |
| `/merge` | `/merge` | Create pull/merge request for current branch |

**Multi-task syntax**: `/research`, `/plan`, and `/implement` accept multiple task numbers using commas and ranges (e.g., `/research 7, 22-24, 59`). Each task is processed by a separate agent in parallel. Flags like `--team` and `--force` apply to all tasks. See `.claude/context/patterns/multi-task-operations.md` for the full specification.

### Utility Scripts

- `.claude/scripts/export-to-markdown.sh` - Export .claude/ directory to consolidated markdown file
- `.claude/scripts/check-extension-docs.sh` - Doc-lint: validate extension READMEs, manifests, and cross-references (exits non-zero on failures)

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
    "task_type": "neovim",
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
- Non-meta tasks: `completion_summary` + optional `roadmap_items` -> /todo annotates ROADMAP.md
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
| skill-reviser | reviser-agent | opus | Plan revision and description update |
| skill-spawn | spawn-agent | opus | Analyze blockers and spawn new tasks |
| skill-orchestrator | (direct execution) | - | Route commands to appropriate workflows |
| skill-git-workflow | (direct execution) | - | Create scoped git commits for task operations |
| skill-fix-it | (direct execution) | - | Scan for FIX:/TODO:/NOTE: tags and create tasks |
| /review | (direct execution) | - | Codebase analysis; code-reviewer-agent available for future skill integration |

### Agents

| Agent | Purpose |
|-------|---------|
| general-research-agent | General web/codebase research |
| general-implementation-agent | General file implementation |
| planner-agent | Implementation plan creation |
| meta-builder-agent | System building and meta tasks |
| code-reviewer-agent | Code quality assessment and review |
| reviser-agent | Plan revision with research synthesis |
| spawn-agent | Blocker analysis and task decomposition |

**Model Enforcement**: Agents declare preferred models via `model:` frontmatter field. Research and planning agents use `opus` for superior reasoning. Implementation agents use default model. See `.claude/docs/reference/standards/agent-frontmatter-standard.md` for details.

**User-Only Skills**: Skills marked as "user-only" cannot be invoked by agents. These are for human-controlled operations like deployment (`skill-tag`).

**Extension Skills**: When extensions are loaded, additional skill-to-agent mappings are added (e.g., skill-neovim-research -> neovim-research-agent). Extension task types use bare values (e.g., `neovim`) or compound values (e.g., `present:grant`) for sub-routing.

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
- @.claude/rules/plan-format-enforcement.md - Plan format checklist (specs/**)

**Extension Rules**: When extensions are loaded, additional rules are added (e.g., neovim-lua.md for Lua development).

## Context Discovery

Context is discovered from three independent layers, loaded in parallel:

| Layer | Source | Notes |
|-------|--------|-------|
| Agent context | `.claude/context/index.json` | Core + extensions (merged by loader) |
| Project context | `.context/index.json` | User conventions (may be empty) |
| Project memory | `.memory/` files | Loaded directly, no index needed |

```bash
# Combined adaptive query (recommended) - loads matching context from all dimensions
jq -r --arg agent "planner-agent" --arg task_type "meta" --arg cmd "/plan" '
  .entries[] | select(
    (.load_when.always == true) or
    any(.load_when.agents[]?; . == $agent) or
    any(.load_when.task_types[]?; . == $task_type) or
    any(.load_when.commands[]?; . == $cmd)
  ) | .path' .claude/context/index.json

# Get line counts for budget calculation
jq -r '.entries[] | select(.load_when.agents[]? == "planner-agent") | "\(.line_count)\t\(.path)"' .claude/context/index.json
```

**Empty Array Semantics**: Empty `load_when` arrays mean "never match". Use `"always": true` for universal files.

See `.claude/context/patterns/context-discovery.md` for full query patterns including multi-layer discovery.

**Extension Context**: Extension index entries are merged into `.claude/context/index.json` by the loader -- no separate extension query needed.

## Context Architecture

Five layers provide context to agents. Each has a distinct owner and purpose.

| Layer | Location | Owner | Contains |
|-------|----------|-------|----------|
| Agent context | `.claude/context/` | Extension loader | Core agent patterns + extension domain knowledge |
| Extensions | `.claude/extensions/*/context/` | Extension loader | Language-specific standards, tools, patterns |
| Project context | `.context/` | User (via index.json) | Project conventions not covered by extensions |
| Project memory | `.memory/` | Agents over time | Learned facts, discoveries, decisions |
| Auto-memory | `~/.claude/projects/` | Claude Code | User preferences, behavioral corrections |

### Where to store new content

```
Language-specific standard, pattern, or tool reference?
  YES --> extension context (.claude/extensions/*/context/)

Agent system pattern (orchestration, format, workflow)?
  YES --> .claude/context/

Project convention (coding style, naming, domain knowledge)?
  YES --> .context/

Learned fact from development (discovery, decision, pattern)?
  YES --> .memory/

User preference or behavioral correction?
  YES --> auto-memory (automatic, no action needed)
```

Full details: `.claude/context/architecture/context-layers.md`

## Context Imports

Core context (always available):
- @.claude/context/repo/project-overview.md
- @.claude/context/meta/meta-guide.md

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

Full documentation: @.claude/context/patterns/jq-escaping-workarounds.md

## Syncprotect

The `.syncprotect` file lives at the **project root** (not inside `.claude/`) and lists relative paths (one per line) of artifacts that should never be overwritten during sync operations. Lines starting with `#` are comments, blank lines are ignored. Paths are relative to the base directory (e.g., `rules/my-custom-rule.md`). Protected files are skipped during both full "Load Core" syncs and individual artifact updates via `Ctrl-l`. The picker preview shows a "Protected Files" section listing which files will be skipped.

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading via @-references
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits

<!-- SECTION: extension_epidemiology -->
## Epidemiology Extension

Epidemiology research and implementation support using R. Covers study design, statistical modeling, causal inference, missing data, and Bayesian analysis.

### Task Type Routing

| Task Type Key | Research | Plan | Implement |
|---------------|----------|------|-----------|
| `epi` | skill-epi-research | skill-planner | skill-epi-implement |
| `epi:study` | skill-epi-research | skill-planner | skill-epi-implement |
| `epidemiology` | skill-epi-research | skill-planner | skill-epi-implement |

### Command

`/epi` -- Stage 0 interactive routing. Presents study design options and routes to appropriate task type (`epi` or `epi:study`).

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-epi-research | epi-research-agent | Study design, analysis planning, causal inference, literature review |
| skill-epi-implement | epi-implement-agent | R code implementation, statistical modeling, data analysis |

### Context Files

**Domain** (research agent):
- `project/epidemiology/domain/study-designs.md` -- Study design reference
- `project/epidemiology/domain/causal-inference.md` -- DAGs, propensity scores, mediation
- `project/epidemiology/domain/missing-data.md` -- MICE, sensitivity analysis
- `project/epidemiology/domain/data-management.md` -- Tidyverse workflows, validation
- `project/epidemiology/domain/reporting-standards.md` -- STROBE, CONSORT, PRISMA
- `project/epidemiology/domain/r-workflow.md` -- renv, targets, Quarto

**Patterns** (both agents):
- `project/epidemiology/patterns/statistical-modeling.md` -- GLM, mixed effects, Bayesian
- `project/epidemiology/patterns/observational-methods.md` -- Bias control, confounding
- `project/epidemiology/patterns/analysis-phases.md` -- Descriptive to sensitivity
- `project/epidemiology/patterns/strobe-checklist.md` -- STROBE reporting checklist

**Templates** (implement agent):
- `project/epidemiology/templates/analysis-plan.md` -- Study protocol template
- `project/epidemiology/templates/findings-report.md` -- Results reporting template

**Tools** (both agents):
- `project/epidemiology/tools/r-packages.md` -- R package documentation
- `project/epidemiology/tools/mcp-guide.md` -- Optional rmcp MCP server integration

<!-- END_SECTION: extension_epidemiology -->

<!-- SECTION: extension_filetypes -->
## Filetypes Extension

File format conversion and manipulation: documents, spreadsheets, presentations, PDF annotations.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-filetypes | filetypes-router-agent | Format detection and routing |
| skill-filetypes | document-agent | Document format conversion (PDF/DOCX/Markdown) |
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst table conversion |
| skill-presentation | presentation-agent | Presentation extraction and slide generation |
| skill-scrape | scrape-agent | PDF annotation extraction |
| skill-docx-edit | docx-edit-agent | In-place DOCX editing with tracked changes (SuperDoc MCP) |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/convert` | `/convert file.pdf` | Convert between document formats; `/convert deck.pptx --format beamer` for slide output |
| `/table` | `/table data.xlsx` | Convert spreadsheets to LaTeX/Typst tables |
| `/scrape` | `/scrape paper.pdf` | Extract PDF annotations to Markdown/JSON |
| `/edit` | `/edit file.docx "instruction"` | Edit Office documents in-place |

<!-- END_SECTION: extension_filetypes -->

<!-- SECTION: extension_formal -->
## Formal Reasoning Extension

Language routing and context for formal mathematical reasoning including logic, mathematics, and physics.

### Language Routing

| Language | Description | Use Cases |
|----------|-------------|-----------|
| `formal` | General formal reasoning | Multi-domain formal tasks |
| `logic` | Mathematical logic | Modal logic, Kripke semantics, proof theory |
| `math` | Mathematics | Algebra, lattice theory, category theory, topology |
| `physics` | Physics | Dynamical systems, formalization |

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-formal-research | formal-research-agent | Multi-domain formal research coordination |
| skill-logic-research | logic-research-agent | Modal logic and Kripke semantics research |
| skill-math-research | math-research-agent | Mathematics research (algebra, lattices, categories) |
| skill-physics-research | physics-research-agent | Physics formalization research |

### Domain Routing

Automatic routing based on task keywords:

**Logic Domain** (triggers logic-research-agent):
- Modal logic, Kripke, accessibility, possible worlds
- Proof theory, sequent calculus, natural deduction
- Completeness, soundness, decidability
- Temporal logic, epistemic logic

**Math Domain** (triggers math-research-agent):
- Lattice, partial order, complete lattice
- Group, ring, field, monoid
- Category, functor, natural transformation
- Topology, metric space, topological space

**Physics Domain** (triggers physics-research-agent):
- Dynamical systems, fixed points, orbits
- Flow, trajectory, ergodic
- Chaos, Lyapunov, bifurcation

### Context Import References

Load context files on-demand:

```
Logic domain:
@.claude/context/project/logic/README.md
@.claude/context/project/logic/domain/kripke-semantics-overview.md

Math domain:
@.claude/context/project/math/README.md
@.claude/context/project/math/lattice-theory/lattices.md

Physics domain:
@.claude/context/project/physics/README.md
@.claude/context/project/physics/dynamical-systems/dynamical-systems.md
```

<!-- END_SECTION: extension_formal -->

<!-- SECTION: extension_founder -->
## Founder Extension (v3.0)

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-market | market-agent | Market sizing research (uses forcing_data) |
| skill-analyze | analyze-agent | Competitive analysis research (uses forcing_data) |
| skill-strategy | strategy-agent | GTM strategy research (uses forcing_data) |
| skill-legal | legal-council-agent | Contract review research (uses forcing_data) |
| skill-project | project-agent | Project timeline research: WBS, PERT, resources |
| skill-spreadsheet | spreadsheet-agent | Cost breakdown spreadsheet generation (uses forcing_data) |
| skill-finance | finance-agent | Financial analysis and verification (uses forcing_data) |
| skill-deck-research | deck-research-agent | Pitch deck material synthesis (no forcing questions) |
| skill-deck-plan | deck-planner-agent | Pitch deck planning with interactive questions |
| skill-deck-implement | deck-builder-agent | Pitch deck typst generation from plan |
| skill-founder-plan | founder-plan-agent | Shared task planning (content-aware) |
| skill-founder-implement | founder-implement-agent | Shared task implementation (type-aware) |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/market` | `/market "fintech payments"` | Market sizing with forcing questions |
| `/analyze` | `/analyze "competitor landscape"` | Competitive analysis with forcing questions |
| `/strategy` | `/strategy "B2B launch"` | GTM strategy with forcing questions |
| `/legal` | `/legal "SaaS vendor agreement"` | Contract review with forcing questions |
| `/project` | `/project "Mobile App Redesign"` | Project timeline with forcing questions |
| `/sheet` | `/sheet "Q1 launch costs"` | Cost breakdown spreadsheet with forcing questions |
| `/finance` | `/finance "Q1 revenue verification"` | Financial analysis and verification with forcing questions |
| `/deck` | `/deck "Seed round pitch"` | Pitch deck creation with material synthesis |

All commands accept: description string (create task), task number (run research), file path (read context), or `--quick` (legacy standalone).

### Language Routing

Tasks with `language: founder` use `task_type` for research routing (`founder:{task_type}`). Planning uses shared founder agents for most task types, except deck tasks which route to a dedicated `deck-planner-agent` with interactive template/content/ordering selection. Implementation uses shared founder agents for most task types, except deck tasks which route to `deck-builder-agent` for typst pitch deck generation.

<!-- END_SECTION: extension_founder -->

<!-- SECTION: extension_latex -->
## LaTeX Extension

This project includes LaTeX document development support via the latex extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `latex` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (pdflatex, latexmk) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-latex-implementation | latex-implementation-agent | LaTeX document implementation |

### VimTeX Integration

- Compile: `:VimtexCompile` (`<leader>lc`)
- View PDF: `:VimtexView` (`<leader>lv`)
- Clean: `:VimtexClean` (`<leader>lk`)
- TOC: `:VimtexTocOpen` (`<leader>li`)

### Document Structure

- Use `\documentclass` appropriate for document type
- Organize with `\input{}` for modular documents
- Use `build/` directory for output files
- Keep `.bib` files organized by project

<!-- END_SECTION: extension_latex -->

<!-- SECTION: extension_lean -->
## Lean 4 Extension

This project includes Lean 4 theorem prover support via the lean extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `lean4` | WebSearch, WebFetch, Read, Lean MCP | Read, Write, Edit, Bash (lake), Lean MCP |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-lean-research | lean-research-agent | Lean/Mathlib research |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |
| skill-lake-repair | lean-implementation-agent | Lake build repair |
| skill-lean-version | (direct execution) | Lean version management |

### MCP Integration

The `lean-lsp` MCP server provides:
- Goal state inspection (`lean_goal`)
- Proof search (`lean_state_search`, `lean_hammer_premise`)
- Mathlib lookup (`lean_loogle`, `lean_leansearch`, `lean_leanfinder`)
- Code actions and diagnostics

### Commands

- `/lake` - Build management and error handling
- `/lean` - Lean-specific proof assistance

<!-- END_SECTION: extension_lean -->

<!-- SECTION: extension_memory -->
## Memory Extension

Knowledge capture and retrieval via the memory vault. Supports text, file, directory, and task-based memory creation with MCP-backed search and deduplication.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-memory | (direct execution) | Memory creation and management |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/learn` | `/learn "text"` | Add text as memory (with content mapping and deduplication) |
| `/learn` | `/learn /path/to/file` | Add file content as memory |
| `/learn` | `/learn /path/to/dir/` | Scan directory for learnable content |
| `/learn` | `/learn --task N` | Review task artifacts and create memories |

### Memory-Augmented Research

The `--remember` flag on `/research` searches the memory vault for relevant prior knowledge and includes matches in the research context. Requires this extension to be loaded; ignored gracefully if not.

```bash
/research N --remember
```

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

<!-- SECTION: extension_present -->
## Present Extension

Structured proposal development (grants) and research presentation creation (talks) in Typst and Slidev formats.

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-grant | grant-agent | opus | Grant proposal research and drafting |
| skill-budget | budget-agent | opus | Grant budget spreadsheet generation (XLSX) |
| skill-timeline | timeline-agent | opus | Research project timeline planning |
| skill-funds | funds-agent | opus | Research funding landscape analysis |
| skill-slides | slides-research-agent | opus | Research talk material synthesis |
| skill-slides | pptx-assembly-agent | opus | PowerPoint presentation assembly |
| skill-slides | slidev-assembly-agent | opus | Slidev presentation assembly |
| skill-slide-planning | slide-planner-agent | opus | Slide plan with design questions |
| skill-slide-critic | slide-critic-agent | opus | Interactive slide critique with rubric evaluation |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/grant` | `/grant "Description"` | Create grant task (stops at [NOT STARTED]) |
| `/grant` | `/grant N --draft ["focus"]` | Draft narrative sections (exploratory) |
| `/grant` | `/grant N --budget ["guidance"]` | Develop budget with justification |
| `/grant` | `/grant --revise N "description"` | Create revision task for existing grant |
| `/budget` | `/budget "Description"` | Create grant budget task with forcing questions |
| `/budget` | `/budget N` | Resume budget generation for existing task |
| `/timeline` | `/timeline "Description"` | Create research timeline task |
| `/timeline` | `/timeline N` | Resume timeline planning for existing task |
| `/funds` | `/funds "Description"` | Create funding analysis task with forcing questions |
| `/funds` | `/funds N` | Resume funding analysis for existing task |
| `/slides` | `/slides "Description"` | Create research talk task with forcing questions |
| `/slides` | `/slides N` | Resume research on existing talk task |
| `/slides` | `/slides /path/to/file` | Use file as primary source material for talk |
| `/slides` | `/slides N --critic [path\|prompt]` | Critique slide materials with interactive feedback loop |

### Language Routing

| Language | Task Type | Research Skill | Implementation Skill | Tools |
|----------|-----------|----------------|---------------------|-------|
| `present` | `grant` | `skill-grant` | `skill-grant` | WebSearch, WebFetch, Read, Write, Edit |
| `present` | `budget` | `skill-budget` | `skill-budget` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present` | `timeline` | `skill-timeline` | `skill-timeline` | WebSearch, WebFetch, Read, Write, Edit |
| `present` | `funds` | `skill-funds` | `skill-funds` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present` | `slides` | `skill-slides` | `skill-slides` | WebSearch, WebFetch, Read, Write, Edit |

### Talk Modes

| Mode | Duration | Slides | Use Case |
|------|----------|--------|----------|
| CONFERENCE | 15-20 min | 12-18 | Conference platform presentations |
| SEMINAR | 45-60 min | 30-45 | Departmental seminars, job talks |
| DEFENSE | 30-60 min | 25-40 | Grant defense, thesis defense |
| POSTER | N/A | 1 | Poster session presentations |
| JOURNAL_CLUB | 15-30 min | 10-15 | Paper review for journal club |

### Talk Library

The talk library at `context/project/present/talk/` contains:
- **Patterns**: Slide structure definitions for each talk mode
- **Content Templates**: Slidev-compatible markdown templates for slide types
- **Components**: Vue components (FigurePanel, DataTable, CitationBlock, StatResult, FlowDiagram)
- **Themes**: Academic-clean and clinical-teal visual themes

<!-- END_SECTION: extension_present -->

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

<!-- SECTION: extension_typst -->
## Typst Extension

This project includes Typst document development support via the typst extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `typst` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (typst compile) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-typst-research | typst-research-agent | Typst documentation research |
| skill-typst-implementation | typst-implementation-agent | Typst document implementation |

### Typst vs LaTeX

- Typst uses single-pass compilation (faster)
- Modern scripting syntax with `#` prefix
- Built-in bibliography management
- Simpler package import with `#import`

### Common Operations

- Compile: `typst compile main.typ`
- Watch: `typst watch main.typ`
- Format: Use consistent indentation for readability
- Diagrams: Use `fletcher` package for commutative diagrams

<!-- END_SECTION: extension_typst -->

<!-- SECTION: extension_web -->
## Web Extension

Web development support for Astro/Tailwind/TypeScript sites deployed to Cloudflare Pages.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `web` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (pnpm build/check) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-web-research | web-research-agent | Astro/Tailwind/Cloudflare research |
| skill-web-implementation | web-implementation-agent | Web (Astro/Tailwind/TypeScript) implementation |

**Note**: The `/tag` command is provided by the core agent system, not this extension.

### Context

- @context/project/web/domain/web-reference.md - Technologies, build commands, deployment tracking
- @context/project/web/domain/astro-framework.md - Astro 5/6 framework reference
- @context/project/web/domain/tailwind-v4.md - Tailwind CSS v4 configuration
- @context/project/web/standards/web-style-guide.md - Naming conventions and coding standards

<!-- END_SECTION: extension_web -->

<!-- SECTION: extension_z3 -->
## Z3 Extension

This project includes Z3 SMT solver development support via the z3 extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `z3` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (python, z3) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-z3-research | z3-research-agent | Z3/SMT research |
| skill-z3-implementation | z3-implementation-agent | Z3 constraint implementation |

### Z3 Patterns

- Use `z3.Solver()` for constraint solving
- BitVec for finite-domain state representation
- Incremental solving with `push()`/`pop()` for efficiency
- Use `simplify()` on expressions before adding to solver

### Common Operations

- Model checking: Define constraints, check `sat`, extract model
- Theory exploration: Use quantifiers sparingly, prefer ground terms
- Optimization: Use `z3.Optimize()` for objective functions

<!-- END_SECTION: extension_z3 -->
