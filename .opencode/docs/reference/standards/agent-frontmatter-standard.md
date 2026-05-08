# Agent Frontmatter Standard

**Created**: 2026-02-24
**Updated**: 2026-04-16
**Purpose**: Define YAML frontmatter requirements for agent files

## Overview

Agent files in `.opencode/agents/` use YAML frontmatter to declare metadata that the OpenCode system and invoking skills use for agent selection, model enforcement, and capability discovery.

## Required Fields

```yaml
---
name: {agent-name}
description: {brief description of agent purpose}
---
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Agent identifier (e.g., `general-research-agent`) |
| `description` | string | Yes | Brief description of agent purpose and capabilities |

## Optional Fields

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
---
```

Currently no optional frontmatter fields are supported in OpenCode agent files.

## Model Field (NOT Supported in OpenCode)

**IMPORTANT**: The `model` field is NOT supported in OpenCode frontmatter. Including it causes "Model not found" errors because OpenCode's `parseModel()` function splits model strings by `/`, so bare aliases like `"opus"` produce `{providerID: "opus", modelID: ""}` which fails model resolution.

### How Model Selection Works in OpenCode

OpenCode uses the session model selected via the TUI model picker. All commands and agents inherit the user's session model selection. There is no per-command or per-agent model override via frontmatter.

### Claude Code Compatibility Note

In Claude Code (`.claude/` system), the `model` field IS supported as a short alias (`opus`, `sonnet`, `haiku`). When porting from Claude Code to OpenCode, the `model:` line must be removed from all frontmatter.

### Runtime Model Selection

Users control model selection via:
1. The OpenCode TUI model picker (session-level)
2. Model flags at invocation time (`--haiku`, `--sonnet`, `--opus`) which are passed as `model_flag` in the delegation context

### Runtime Override Flags

Users can override the agent's default model at invocation time using flags on `/research`, `/plan`, and `/implement` commands. There are two independent flag dimensions:

**Effort flags** (how deeply the model reasons):

| Flag | Behavior |
|------|----------|
| `--fast` | Low-effort mode: lighter reasoning, faster responses |
| `--hard` | High-effort mode: deeper reasoning, more thorough analysis |

**Model flags** (which model family to use):

| Flag | Maps to | Behavior |
|------|---------|----------|
| `--haiku` | `haiku` | Use Haiku model (fastest, lowest cost) |
| `--sonnet` | `sonnet` | Use Sonnet model (balanced cost/quality) |
| `--opus` | `opus` | Use Opus model (highest quality, same as default) |

Effort and model flags are independent and can be combined. For example, `--fast --opus` uses Opus with low-effort reasoning. If no model flag is provided, the agent's frontmatter default is used (currently opus for all agents). If no effort flag is provided, normal effort is used.

If multiple flags of the same dimension are provided, the last one wins. These flags are passed as `model_flag` and `effort_flag` in the delegation context to the skill and subagent.

**Examples**:
```
/research 42 --opus        # Force Opus (same as default)
/research 42 --sonnet      # Use Sonnet for cost savings
/research 42 --haiku       # Use Haiku for speed
/implement 42 --hard       # Deep reasoning with default model (Opus)
/implement 42 --fast       # Light reasoning with default model (Opus)
/plan 42 --fast --sonnet   # Light reasoning with Sonnet
```

### Examples

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
---
```

**Rationale**: All agents use Opus as the default for highest quality. Use `--sonnet` or `--haiku` at invocation time for cost savings on simpler tasks.

```yaml
---
name: lean-research-agent
description: Research and prove Lean4 theorems
---
```

**Rationale**: Lean4 proof work requires deep mathematical reasoning; Opus provides superior capabilities for formal verification.

## Validation

Agent frontmatter is validated during:
1. Agent file creation (via `/meta` command)
2. Agent invocation (by skill preflight)

### Validation Rules

1. `name` must be present and non-empty
2. `description` must be present and non-empty
3. `model` field must NOT be present (OpenCode does not support it; remove if found)

## Examples

### Research Agent

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
---
```

### Implementation Agent

```yaml
---
name: general-implementation-agent
description: Implement general, meta, and markdown tasks from plans
---
```

### Planning Agent

```yaml
---
name: planner-agent
description: Create phased implementation plans from research findings
---
```

### Lean4 Research Agent

```yaml
---
name: lean-research-agent
description: Research and prove Lean4 theorems using Mathlib
---
```

## Migration from Claude Code

When porting agent or command files from `.claude/` to `.opencode/`:

1. Remove the `model:` line entirely from the YAML frontmatter
2. Do not convert to `provider/model` format (hard-coding a provider defeats OpenCode's model-agnostic design)
3. Verify that the remaining frontmatter fields (`name`, `description`, `allowed-tools`, etc.) are valid

Model selection in OpenCode is handled by the user's session model picker, not by per-file frontmatter.

## Related Documentation

- [Creating Agents Guide](.opencode/docs/guides/creating-agents.md)
- [Agent Template](.opencode/docs/templates/agent-template.md)
- [Context Discovery Patterns](.opencode/context/patterns/context-discovery.md)
