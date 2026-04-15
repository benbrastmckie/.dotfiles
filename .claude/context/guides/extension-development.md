# Extension Development Guide

Guide for creating and managing domain extensions in the Claude Code system.

## Overview

Extensions provide task-type-specific and domain-specific capabilities to the core system. They include agents, skills, context, and rules tailored to specific domains.

## Extension Structure

```
.claude/extensions/{name}/
├── manifest.json           # Extension metadata
├── context/                # Domain-specific context
│   ├── index.json          # Context discovery entries
│   └── project/
│       └── {domain}/
├── agents/                 # Domain agents
│   ├── {domain}-research-agent.md
│   └── {domain}-implementation-agent.md
└── skills/                 # Domain skills
    └── skill-{domain}-research/SKILL.md
```

## Manifest Format

```json
{
  "name": "python",
  "version": "1.0.0",
  "description": "Python development support",
  "task_type": "python",
  "dependencies": [],
  "provides": {
    "agents": ["python-research-agent.md", "python-implementation-agent.md"],
    "skills": ["skill-python-research", "skill-python-implementation"],
    "commands": [],
    "rules": [],
    "context": ["project/python"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": { "python": "skill-python-research" },
    "plan": { "python": "skill-planner" },
    "implement": { "python": "skill-python-implementation" }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_python"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  }
}
```

### Manifest Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Extension identifier |
| `version` | string | Semver version |
| `description` | string | Brief description |
| `task_type` | string | Task type this extension handles |
| `dependencies` | array | Other extensions required |
| `provides` | object | Agents, skills, commands, rules, context, scripts, hooks |
| `routing` | object | Task-type to skill mapping for research/plan/implement |
| `merge_targets` | object | Source-to-target file mappings for system integration |

## Merge Process

Extensions are loaded via the extension picker. The loader reads each extension's `manifest.json` and merges content according to `merge_targets`:

### 1. Context Index Merging

Extension context entries from `index-entries.json` are merged into `.claude/context/index.json`:

```json
{
  "entries": [
    {
      "path": "extensions/python/context/project/python/coding-patterns.md",
      "domain": "project",
      "subdomain": "python",
      "load_when": {
        "task_types": ["python"]
      }
    }
  ]
}
```

### 2. CLAUDE.md Merging

Extension `EXTENSION.md` content is merged into `.claude/CLAUDE.md` at the section identified by `section_id`.

## Creating an Extension

### Step 1: Create Directory Structure

```bash
mkdir -p .claude/extensions/{name}/{context,agents,skills}
```

### Step 2: Create Manifest

```json
{
  "name": "myextension",
  "version": "1.0.0",
  "description": "My domain extension",
  "task_type": "mydomain",
  "dependencies": [],
  "provides": {
    "agents": ["mydomain-research-agent.md"],
    "skills": ["skill-mydomain-research"],
    "commands": [],
    "rules": [],
    "context": ["project/mydomain"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": { "mydomain": "skill-mydomain-research" },
    "plan": { "mydomain": "skill-planner" },
    "implement": { "mydomain": "skill-implementer" }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_mydomain"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  }
}
```

### Step 3: Create Agents

Create research and implementation agents in `agents/`.

### Step 4: Create Skills

Create skills in `skills/skill-{name}/SKILL.md`.

### Step 5: Create Context

Add domain knowledge to `context/project/{domain}/`.

### Step 6: Load Extension

Extensions are loaded via the extension picker. The loader discovers extensions by scanning `.claude/extensions/*/manifest.json` directories automatically -- no central registry is needed.

## Best Practices

1. **Lazy Loading**: Extensions should not load context until needed
2. **Agent Separation**: Always create both research and implementation agents
3. **Context Organization**: Follow the `context/project/{domain}/` structure
4. **Merge Safety**: Always verify after merging
5. **Documentation**: Document domain-specific patterns in context files

## Example: Minimal Extension

See `extensions/template/` for a minimal extension structure.

## Troubleshooting

### Load Failures

If loading fails:
1. Check manifest.json syntax
2. Verify all referenced files exist
3. Ensure merge_targets point to valid source files

### Context Not Loading

1. Check index.json has correct load_when conditions
2. Verify path is relative to context/ directory
3. Test with jq query

### Routing Not Working

1. Verify task_type is set in manifest
2. Check agent names match skill mappings
3. Ensure routing entries map task_type to correct skills
