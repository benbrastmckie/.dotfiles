#!/usr/bin/env bash

# Script to test MCP-Hub installation (simplified for new flake-based approach)

# Set default API keys (replace these with your actual keys)
# If you have keys set in your environment, they will be used instead
: "${ANTHROPIC_API_KEY:=}"
: "${OPENAI_API_KEY:=}"

echo "===== MCP-Hub Test Script (Simplified) ====="
echo "This script will test if MCP-Hub is working correctly with the new flake-based integration."

# Check environment variables set by Nix
if [ -n "$MCP_HUB_PATH" ]; then
    echo "✅ MCP_HUB_PATH is set: $MCP_HUB_PATH"
    if [ -x "$MCP_HUB_PATH" ]; then
        echo "✅ MCP-Hub executable is accessible"
        echo "Version: $($MCP_HUB_PATH --version 2>/dev/null || echo 'Version check failed')"
    else
        echo "❌ MCP-Hub executable not accessible at $MCP_HUB_PATH"
    fi
else
    echo "⚠️ MCP_HUB_PATH not set, trying fallback detection..."
    # Fallback to standard command detection
    if command -v mcp-hub &> /dev/null; then
        echo "✅ MCP-Hub executable found via PATH"
        echo "Version: $(mcp-hub --version)"
    else
        echo "❌ MCP-Hub executable not found"
        echo "Make sure you have enabled programs.neovim.mcp-hub in your home-manager config"
        exit 1
    fi
fi

# Check port environment variable
if [ -n "$MCP_HUB_PORT" ]; then
    echo "✅ MCP_HUB_PORT is set: $MCP_HUB_PORT"
else
    echo "⚠️ MCP_HUB_PORT not set, using default: 37373"
fi

# Check API Keys
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "⚠️ Warning: ANTHROPIC_API_KEY is not set or empty"
    echo "You should set this environment variable for MCP-Hub to work properly."
    echo "Example: export ANTHROPIC_API_KEY=your_key_here"
else
    echo "✅ ANTHROPIC_API_KEY is set"
fi

# Check if servers.json exists
CONFIG_DIR="$HOME/.config/mcphub"
if [ -d "$CONFIG_DIR" ]; then
    echo "✅ Config directory exists: $CONFIG_DIR"
    
    if [ -f "$CONFIG_DIR/servers.json" ]; then
        echo "✅ servers.json file exists"
        
        # Check if context7 is in servers.json
        if grep -q "context7-mcp" "$CONFIG_DIR/servers.json"; then
            echo "✅ Context7 is configured in servers.json"
        else
            echo "❌ Context7 not found in servers.json"
            echo "Consider updating your servers.json to include Context7:"
            echo '{
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"],
      "env": {
        "API_KEY": "",
        "SERVER_URL": null,
        "DEBUG": "true"
      }
    },
    "github.com/upstash/context7-mcp": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"],
      "env": {
        "DEFAULT_MINIMUM_TOKENS": "10000"
      }
    }
  }
}'
        fi
    else
        echo "❌ servers.json file not found"
    fi
else
    echo "❌ Config directory not found: $CONFIG_DIR"
fi

# Test basic functionality
echo
echo "Testing basic MCP-Hub functionality..."

# Determine which binary to use
MCPHUB_BIN="${MCP_HUB_PATH:-mcp-hub}"
PORT="${MCP_HUB_PORT:-37373}"

# Offer to run MCP-Hub
echo
echo "Would you like to try running MCP-Hub server? [y/N]"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Starting MCP-Hub server on port $PORT (press Ctrl+C to stop)..."
    echo "Any errors will be displayed below:"
    echo "---------------------------------------"
    
    # Set necessary environment variables
    export DEBUG=mcp-hub*
    export NODE_ENV=development
    
    # Run MCP-Hub using the detected binary
    "$MCPHUB_BIN" serve --port="$PORT"
else
    echo "Skipping MCP-Hub server test"
fi

echo "Test completed."