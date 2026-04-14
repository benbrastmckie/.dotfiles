# .claude/ Directory Diff Report

**Compared**: Working tree vs HEAD (`0b9c657`)
**Date**: 2026-04-14
**Total**: 39 files changed, 4,716 insertions, 15,354 deletions (net -10,638 lines)

---

## Summary of Changes

Six major categories of work:

1. **Spreadsheet agent split** -- Monolithic `spreadsheet-agent` split into `filetypes-spreadsheet-agent` and `founder-spreadsheet-agent`
2. **Backup file purge** -- All `.backup` files removed; backup mechanism deprecated in favor of git recovery
3. **Batch dispatch simplification** -- Removed `skill-batch-dispatch` indirection; commands handle their own multi-task orchestration directly
4. **Extension manifest schema update** -- `manifest.json` format modernized with structured `provides`, `routing`, and `merge_targets` objects; `language` field renamed to `task_type`
5. **Tag command/skill simplification** -- Massive reduction from verbose example-heavy documentation to concise specification
6. **Pre-delegation boundary enforcement** -- New explicit rules preventing lead skills from reading source files before spawning sub-agents
7. **Artifact link format change** -- Switched from markdown `[text](url)` to bracket-only `[path]` format in TODO.md

---

## Deleted Files (5 files, -10,357 lines)

| File | Lines Removed | Reason |
|------|--------------|--------|
| `.claude/CLAUDE.md.backup` | -908 | Backup mechanism deprecated |
| `.claude/context/index.json.backup` | -8,426 | Backup mechanism deprecated |
| `.claude/settings.local.json.backup` | -93 | Backup mechanism deprecated |
| `.claude/agents/spreadsheet-agent.md` | -578 | Split into two specialized agents |
| `.claude/skills/skill-spreadsheet/SKILL.md` | -352 | Replaced by two specialized skills |

---

## Modified Files Detail

### CLAUDE.md (+7, -6)

- **Added** `skill-fix-it` and `/review` entries to skill-to-agent mapping table
- **Added** `## Syncprotect` section documenting `.syncprotect` file for protecting artifacts from sync overwrites
- **Web Extension**: Removed `/tag` from web extension skill table; added note that `/tag` is a core command, not extension-specific

### Agents

- **general-implementation-agent.md** (+5): Added `model: opus` to frontmatter; added "Codebase Exploration Responsibility" section stating this agent is the exclusive owner of all codebase exploration during implementation -- the lead skill deliberately does NOT read source files before spawning this agent
- **meta-builder-agent.md** (+1): Added `model: opus` to frontmatter

### Commands

#### research.md, plan.md, implement.md (+9/-19 each, same pattern)

All three commands received identical refactoring:
- **Removed**: `skill-batch-dispatch` invocation pattern (Skill tool call with batch parameters)
- **Replaced with**: Direct orchestrator loop description (extract task type, route per task, spawn agents via parallel Task tool calls)
- **Added note**: "Batch dispatch is handled directly by this command's orchestrator loop, not by a separate skill."

#### tag.md (+46, -233)

Major simplification:
- Added proper YAML frontmatter (`description`, `argument-hint`, `model: opus`)
- Removed ~200 lines of verbose example output (interactive flow, dry run, error handling examples)
- Condensed to concise specification: Usage, Examples, Workflow steps, Requirements, Agent Restrictions

#### sheet.md (+5, -5)

- Renamed `skill-spreadsheet` references to `skill-founder-spreadsheet`
- Renamed `spreadsheet-agent` references to `founder-spreadsheet-agent`

#### table.md (+2, -2)

- Renamed `skill-spreadsheet` to `skill-filetypes-spreadsheet`
- Renamed `spreadsheet-agent` to `filetypes-spreadsheet-agent`

#### merge.md (+1)

- Added `model: opus` to frontmatter

#### refresh.md (+2)

- Added `argument-hint: [--dry-run] [--force]` and `model: opus` to frontmatter

### Skills

#### skill-implementer/SKILL.md (+19)

- **Added** "CRITICAL: No Source Reading Before Delegation" callout at Stage 4 -- lead skill must not read/grep/glob source files between preparing delegation context and spawning sub-agent
- **Added** "Pre-Delegation Boundary" section listing 5 prohibited actions (read source files, grep/glob, MCP tools, analyze code, run builds) and 5 permitted actions (read plan, read state, prepare context, read format spec, spawn agent)

#### skill-team-implement/SKILL.md (+23)

- **Added** "CRITICAL: Plan-Text-Only Analysis" callout at Stage 5 -- dependency analysis uses plan text only, not source file reading
- **Added** "CRITICAL: Template Population from Plan Text Only" callout at Stage 7 -- template variables populated from plan file, not source exploration
- **Added** "MUST NOT (Pre-Delegation Boundary)" section with same 5 prohibited actions pattern

#### skill-refresh/SKILL.md (+28, -2)

- **Added Step 4**: "Clean Stale Backup Files" -- scans `.claude/` for `*.backup` files and removes them
- Renumbered subsequent steps (old Step 4 -> Step 5, old Step 5 -> Step 6)

#### skill-tag/SKILL.md (-165)

- Removed ~133 lines of "Example Execution Flows" (interactive, dry-run, force examples)
- Removed "Push Failed" and "Detached HEAD" error handling examples
- Removed git-workflow rules reference and related documentation links
- Simplified agent restrictions section

#### skill-reviser/SKILL.md (-1)

- Removed `model: opus` from skill frontmatter (model declaration moved elsewhere)

#### skill-spawn/SKILL.md (-2)

- Removed `version` and `author` fields from frontmatter (metadata cleanup)

### Context Files

#### context/guides/extension-development.md (+70, -67)

Major manifest schema update:
- **Old format**: Flat arrays for `task_types`, `agents`, `skills`, `merge_targets`
- **New format**: Structured objects:
  - `task_type` (singular string, replaces `language`)
  - `dependencies` array
  - `provides` object (agents, skills, commands, rules, context, scripts, hooks)
  - `routing` object (research/plan/implement -> task_type -> skill mapping)
  - `merge_targets` object with `claudemd` and `index` sub-objects (source/target/section_id)
- Removed merge script references (`merge-extensions.sh --verify`)
- Extension loading via `<leader>ac` now discovers extensions by scanning directories automatically (no central registry)

#### context/patterns/artifact-linking-todo.md (+20, -22)

Switched artifact link format from markdown links to bracket-only:
- **Old**: `[artifact_filename](todo_link_path)` (e.g., `[01_initial-research.md](398_extract_artifact/reports/01_initial-research.md)`)
- **New**: `[todo_link_path]` (e.g., `[398_extract_artifact/reports/01_initial-research.md]`)
- Added blank line preservation logic for Cases 1 and 3 (insert before blank line to maintain spacing)
- Removed `artifact_filename` extraction step (no longer needed)

#### context/reference/state-management-schema.md (+11, -9)

- Updated all artifact linking examples to bracket-only format `[path]`
- Updated TODO.md entry template to use bracket-only format
- Updated detection pattern regex from `\[.*\]\(.*\)` to `\[.*\]`

#### context/patterns/multi-task-operations.md (+8, -18)

- Removed `skill-batch-dispatch` Skill tool invocation example
- Replaced with description of orchestrator loop built into each command file
- Added: "This approach keeps dispatch logic co-located with each command's validation and routing rules"

#### context/repo/self-healing-implementation-details.md (+4, -6)

- Replaced `.backup` file usage in test cases with `rm` + `git checkout HEAD --` recovery pattern

### Documentation Files

#### docs/architecture/extension-system.md (+13, -6)

- Changed `language` field to `task_type` in manifest example
- Added `routing` object to manifest example with research/implement mappings
- Replaced "Backup System" section (backing up to `.backup` files) with "Recovery" section (using git for file recovery)

#### docs/guides/adding-domains.md (+15, -7)

- Changed `language` to `task_type` throughout
- Added `routing` object to manifest template
- Updated routing diagram labels from `language:` to `task_type:`
- Updated validation checklist from `--language` to `--task-type`

#### docs/guides/creating-agents.md (+2, -2)

- Changed `language` to `task_type` in delegation context example

#### docs/guides/creating-extensions.md (+9, -1)

- Changed `language` to `task_type` in manifest template
- Added `routing` object to manifest template

#### docs/guides/creating-skills.md (+2, -2)

- Changed `language` to `task_type` in delegation context and invocation examples

#### docs/reference/standards/agent-frontmatter-standard.md (+4, -4)

- Changed `model: sonnet` recommendation from "Implementation agents with clear plans" to "Team orchestration skills (lightweight coordination)"
- Updated example from `neovim-implementation-agent` with `model: sonnet` to `general-implementation-agent` with `model: opus`

#### docs/reference/standards/extension-slim-standard.md (+1, -1)

- Updated filetypes extension table: `skill-spreadsheet`/`spreadsheet-agent` -> `skill-filetypes-spreadsheet`/`filetypes-spreadsheet-agent`

### Scripts

#### scripts/link-artifact-todo.sh (+23, -9)

- Switched all link generation from `[filename](path)` to `[path]` format
- Updated Case 2 regex detection from `^\[.*\]\(.*\)$` to `^\[.*\](\(.*\))?$` (accepts both old and new formats)
- Added blank line preservation in Cases 1 and 3: checks if line before insertion point is blank and adjusts insertion position accordingly

### Rules

#### rules/artifact-formats.md (+2, -2)

- Updated cross-reference from `.claude/rules/state-management.md` to `.claude/context/reference/state-management-schema.md`
- Updated inline link example to bracket-only format

#### rules/state-management.md (+1, -1)

- Changed "Create backup of overwritten version" to "Use git for recovery of overwritten versions"

### Large Files (bulk changes)

#### context/index.json (+3,820, -3,820)

Equal add/remove count indicates a full regeneration/reformat of the context index entries. Key changes are field reordering within JSON objects (e.g., `keywords` and `domain` moved before `summary`), not content changes.

#### extensions.json (+546, -548)

Similar near-equal add/remove: regenerated extension registry with minor schema adjustments.

---

## Architectural Themes

### 1. Backup Deprecation

The `.backup` file pattern is systematically eliminated:
- 3 backup files deleted
- `/refresh` gains backup cleanup step
- Test cases updated to use git recovery
- State management rule updated
- Extension system docs: "Backup System" replaced with "Recovery" (use git)

### 2. Agent Specialization

The `spreadsheet-agent` split follows single-responsibility:
- **filetypes-spreadsheet-agent**: Format conversion (spreadsheet -> LaTeX/Typst table)
- **founder-spreadsheet-agent**: Business cost analysis (forcing questions -> XLSX with formulas)

### 3. Dispatch Simplification

Removing `skill-batch-dispatch` eliminates one level of indirection. Each command (`/research`, `/plan`, `/implement`) now directly orchestrates its own multi-task dispatch, keeping routing logic co-located with validation.

### 4. Pre-Delegation Boundary

New pattern enforced across `skill-implementer` and `skill-team-implement`: lead skills must NOT read source files, grep, glob, or use MCP tools before spawning sub-agents. All codebase exploration is the exclusive responsibility of the implementation agent. This prevents the lead from duplicating work and bloating its context.

### 5. Artifact Link Simplification

TODO.md links changed from `[filename](path)` to `[path]` bracket-only format. This is simpler, avoids redundant filename extraction, and the link-artifact script gained blank line preservation logic.

### 6. `language` -> `task_type` Rename

Consistent rename across all extension-related docs: manifest `language` field is now `task_type`, routing diagrams use `task_type:` labels, and delegation contexts pass `task_type` instead of `language`.

### 7. Model Enforcement

Several agents and commands gain explicit `model: opus` frontmatter. The agent-frontmatter-standard now recommends `model: opus` for implementation agents (previously `model: sonnet`).
