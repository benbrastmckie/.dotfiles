# MCP Server Setup for Memory Vault

This guide explains how to set up the MCP (Model Context Protocol) server for advanced memory vault features like search and retrieval.

## Multi-System Architecture

The memory extension is designed to work across both Claude Code and OpenCode:

### Shared Components
- `.memory/` vault at project root (single source of truth)
- Memory filename format: `MEM-{semantic-slug}.md` (e.g., `MEM-telescope-custom-pickers.md`)
- Index regeneration from filesystem

### System-Specific Components
- MCP server configuration (different ports, different protocols)
- Context reference paths (`.claude/` vs `.opencode/`)
- Extension loading mechanics

### Concurrent Usage Safety

| Scenario | Safety | Notes |
|----------|--------|-------|
| Both reading memories | Safe | No conflicts |
| One writing, one reading | Safe | Atomic file writes |
| Both writing different memories | Safe | Unique IDs per write |
| Both updating same memory | Last-write-wins | Rare edge case |
| Both using MCP | Avoid | Use one system's MCP at a time |

## Prerequisites

- Obsidian desktop app installed (available at [obsidian.md](https://obsidian.md))
- `.memory/` vault created (located at `.opencode/memory/` in this project)
- Node.js/npm installed (for npx)

## Installation Steps

### 1. Open the Vault in Obsidian

1. Launch Obsidian desktop app
2. Click "Open folder as vault"
3. Navigate to `.opencode/memory/` and select it
4. The vault should open successfully

### 2. Install Local REST API Plugin

The MCP server (`@dsebastien/obsidian-cli-rest-mcp`) connects to the **Local REST API** plugin by coddingtonbear.

1. In Obsidian, open Settings (gear icon)
2. Go to "Community Plugins"
3. Turn off "Safe mode" if prompted
4. Click "Browse" community plugins
5. Search for: **"Local REST API"** (by coddingtonbear)
6. Click "Install", then "Enable"

### 3. Get the API Key

1. Open the **Local REST API** plugin settings
2. The API key is auto-generated and shown on the settings page
3. Copy it — you'll need it in the next step

### 4. Set the API Key as an Environment Variable

The MCP server config uses `${OBSIDIAN_API_KEY}` (see `extensions/memory/settings-fragment.json`), so set it in your shell:

**Fish** (`~/.config/fish/config.fish`):
```fish
set -gx OBSIDIAN_API_KEY "your-api-key-here"
```

**Bash/Zsh** (`~/.bashrc` or `~/.zshrc`):
```bash
export OBSIDIAN_API_KEY="your-api-key-here"
```

### 5. Enable the MCP Server in OpenCode

Merge the MCP config from `extensions/memory/settings-fragment.json` into your project's `settings.json`:

```json
{
  "mcpServers": {
    "obsidian-memory": {
      "command": "npx",
      "args": ["-y", "@dsebastien/obsidian-cli-rest-mcp@latest"],
      "env": {
        "OBSIDIAN_API_KEY": "${OBSIDIAN_API_KEY}",
        "OBSIDIAN_PORT": "27124"
      }
    }
  }
}
```

The `${OBSIDIAN_API_KEY}` placeholder is substituted from your environment at runtime — never hardcode the key in the config file.

### 6. Test the Connection

```bash
curl -H "Authorization: Bearer $OBSIDIAN_API_KEY" \
  http://127.0.0.1:27124/vault/
```

You should see a list of vault files. If Obsidian is not running, you'll get "connection refused".

### 7. Test with OpenCode

Run a memory-augmented research query:
```
/research OC_136 --remember
```

If configured correctly, the system will:
1. Search existing memories
2. Include relevant memories in the research context
3. Show "memory-augmented" status

## Troubleshooting

### Connection Refused
- **Cause**: Obsidian not running
- **Solution**: Start Obsidian and open the memory vault

### Port Already in Use
- **Cause**: Another service using port 27124
- **Solution**: Change port in Obsidian plugin settings and MCP config

### API Key Issues
- **Cause**: Wrong API key or key regenerated
- **Solution**: Copy the correct API key from Obsidian plugin settings

### Plugin Not Found
- **Cause**: Plugin not in community list, or searching wrong name
- **Solution**: Ensure "Safe mode" is off; search for **"Local REST API"** by coddingtonbear

## MCP Tools Available

When connected, these tools are available:

- `search_notes` - Search memories by keywords
- `read_note` - Retrieve full memory content
- `write_note` - Create new memory (alternative to direct file write)
- `list_notes` - Enumerate all memories

## Graceful Degradation

If the MCP server is unavailable:
- Direct file access still works
- Memory search is skipped during research
- System continues with reduced functionality

## Security Notes

- Keep your API key private (don't commit it)
- The MCP server only works when Obsidian is running
- Port 27124 is local-only (not exposed to network)
- Consider using environment variables for API keys
