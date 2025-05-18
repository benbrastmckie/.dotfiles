#!/usr/bin/env bash

# Script to test MCP-Hub and Context7 installation

# Set default API keys (replace these with your actual keys)
# If you have keys set in your environment, they will be used instead
: "${ANTHROPIC_API_KEY:=}"
: "${OPENAI_API_KEY:=}"

echo "===== MCP-Hub Test Script ====="
echo "This script will test if MCP-Hub and Context7 are working correctly."

# Check if MCP-Hub executable exists
if command -v mcp-hub &> /dev/null; then
    echo "✅ MCP-Hub executable found"
    echo "Version: $(mcp-hub --version)"
else
    echo "❌ MCP-Hub executable not found"
    exit 1
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

# Create a test directory
TEST_DIR=$(mktemp -d)
echo "Created temporary test directory: $TEST_DIR"

cd "$TEST_DIR" || exit 1

# Create a minimal test package.json
cat > package.json << EOF
{
  "name": "mcp-hub-test",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "mcp-hub": "latest",
    "@upstash/context7-mcp": "latest"
  }
}
EOF

echo "Installing MCP-Hub and Context7 (this may take a moment)..."
npm install --silent

# Check if installation succeeded
if [ -d "$TEST_DIR/node_modules/mcp-hub" ]; then
    echo "✅ MCP-Hub installed successfully"
    
    if [ -d "$TEST_DIR/node_modules/@upstash/context7-mcp" ]; then
        echo "✅ Context7 installed successfully"
        
        # Check the version
        CONTEXT7_VERSION=$(grep -o '"version": "[^"]*"' "$TEST_DIR/node_modules/@upstash/context7-mcp/package.json" | cut -d'"' -f4)
        echo "Context7 version: $CONTEXT7_VERSION"
    else
        echo "❌ Context7 installation failed"
    fi
else
    echo "❌ MCP-Hub installation failed"
fi

# Offer to run MCP-Hub
echo
echo "Would you like to try running MCP-Hub server? [y/N]"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Starting MCP-Hub server (press Ctrl+C to stop)..."
    echo "Any errors will be displayed below:"
    echo "---------------------------------------"
    
    # Set necessary environment variables
    export DEBUG=mcp-hub*
    export NODE_ENV=development
    
    # Run MCP-Hub
    "$TEST_DIR/node_modules/.bin/mcp-hub" serve --port=37373
else
    echo "Skipping MCP-Hub server test"
fi

# Clean up
echo "Cleaning up test directory..."
rm -rf "$TEST_DIR"
echo "Test completed."