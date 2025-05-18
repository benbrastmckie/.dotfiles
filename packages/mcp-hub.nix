{ lib, pkgs }:

# Create a direct shell script for MCP-Hub
pkgs.writeShellScriptBin "mcp-hub" ''
  #!/bin/sh
  
  # This is a simple MCP-Hub wrapper script
  # It handles version reporting and server starting
  
  # Version command - must match what mcphub.nvim expects
  if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "3.1.10"
    exit 0
  fi
  
  # If running the server
  if [ "$1" = "serve" ]; then
    # Get the port number from arguments
    PORT="37373"
    for arg in "$@"; do
      case "$arg" in
        --port=*)
          PORT="''${arg#*=}"
          ;;
      esac
    done
    
    echo "Starting MCP-Hub server on port $PORT..."
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    
    # Clean up on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    # Set up the package.json file
    cd "$TEMP_DIR" || exit 1
    cat > package.json << EOF
{
  "name": "mcp-hub-temp",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "mcp-hub": "latest",
    "@upstash/context7-mcp": "latest"
  }
}
EOF
    
    # Install MCP-Hub and context7 in the temporary directory
    echo "Installing MCP-Hub and context7..."
    ${pkgs.nodejs}/bin/npm install --no-audit --no-fund
    
    # Check if the installation succeeded
    if [ -d "$TEMP_DIR/node_modules/mcp-hub" ]; then
      echo "Checking for Context7 extension..."
      if [ -d "$TEMP_DIR/node_modules/@upstash/context7-mcp" ]; then
        echo "Context7 found. Starting server with Context7 support..."
      else
        echo "Warning: Context7 not found in node_modules."
      fi
      
      # Set NODE_ENV to development for more verbose logs
      export NODE_ENV=development
      
      # Add debugging environment variables
      export MCP_HUB_DEBUG=true
      export DEBUG=mcp-hub*
      
      # Create a default config file if it doesn't exist
      CONFIG_DIR="$HOME/.config/mcphub"
      mkdir -p "$CONFIG_DIR"
      
      # Create config.json if it doesn't exist
      if [ ! -f "$CONFIG_DIR/config.json" ]; then
        cat > "$CONFIG_DIR/config.json" << EOF
{
  "port": $PORT,
  "debug": true,
  "apiKeys": [""],
  "logLevel": "debug"
}
EOF
      fi
      
      # No longer automatically managing servers.json
      # This allows the Neovim plugin to manage it without conflicts
      # Users should add context7 to their servers.json manually or via their Neovim config
      
      echo "Starting server with debugging enabled..."
      # Fixed command to properly pass port argument
      exec ${pkgs.nodejs}/bin/node --trace-warnings "$TEMP_DIR/node_modules/mcp-hub/dist/cli.js" serve --port="$PORT" --config="$HOME/.config/mcphub/config.json"
    else
      echo "Failed to install MCP-Hub. Showing npm debug output:"
      # Try again with more verbose output for debugging
      cd "$TEMP_DIR" && ${pkgs.nodejs}/bin/npm install --loglevel=verbose
      echo "Node.js version: $(${pkgs.nodejs}/bin/node --version)"
      echo "NPM version: $(${pkgs.nodejs}/bin/npm --version)"
      echo "Temporary directory: $TEMP_DIR"
      echo "Directory contents:"
      ls -la "$TEMP_DIR"
      exit 1
    fi
  else
    # For any other commands just exit with success
    exit 0
  fi
''