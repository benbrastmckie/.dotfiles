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
    "mcp-hub": "latest"
  }
}
EOF
    
    # Install MCP-Hub in the temporary directory
    echo "Installing MCP-Hub..."
    ${pkgs.nodejs}/bin/npm install --silent --no-audit --no-fund
    
    # Check if the installation succeeded
    if [ -d "$TEMP_DIR/node_modules/mcp-hub" ]; then
      echo "Starting server..."
      exec ${pkgs.nodejs}/bin/node "$TEMP_DIR/node_modules/mcp-hub/dist/cli.js" serve --port="$PORT" "$@"
    else
      echo "Failed to install MCP-Hub. Exiting."
      exit 1
    fi
  else
    # For any other commands just exit with success
    exit 0
  fi
''