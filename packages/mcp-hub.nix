{ lib, pkgs }:

pkgs.writeShellScriptBin "mcp-hub" ''
  #!/bin/sh
  
  # Enhanced MCP-Hub wrapper script for NixOS
  # This script reliably finds and executes the MCP-Hub binary,
  # handling path resolution and Node.js integration properly
  
  # Log helper function
  log() {
    echo "MCP-Hub wrapper: $1" >&2
  }
  
  # Use the specified Node.js version with proper path resolution
  export NODE_PATH="${pkgs.nodejs}/lib/node_modules"
  NODE_BIN="${pkgs.nodejs}/bin/node"
  
  # First check: try to find the binary from mcphub.nvim plugin
  PLUGIN_DIR="$HOME/.local/share/nvim/lazy/mcphub.nvim"
  if [ -d "$PLUGIN_DIR" ]; then
    # Look for the binary in node_modules
    BINARY_PATH="$PLUGIN_DIR/bundled/mcp-hub/node_modules/.bin/mcp-hub"
    
    if [ -f "$BINARY_PATH" ]; then
      log "Using plugin bundled binary at $BINARY_PATH"
      # Handle the case where the binary is a shell script (resolve the Node.js script inside)
      SCRIPT_PATH=$(grep -o '[^ ]*index.js' "$BINARY_PATH" 2>/dev/null || echo "")
      
      if [ -n "$SCRIPT_PATH" ]; then
        # If we found an index.js path in the script, use that directly
        if [ -f "$SCRIPT_PATH" ]; then
          log "Resolved to Node.js script: $SCRIPT_PATH"
          exec "$NODE_BIN" "$SCRIPT_PATH" "$@"
        fi
      else
        # Otherwise try to execute the binary directly
        chmod +x "$BINARY_PATH" 2>/dev/null
        exec "$BINARY_PATH" "$@"
      fi
    fi
    
    # Check for index.js directly
    INDEX_PATH="$PLUGIN_DIR/bundled/mcp-hub/node_modules/mcp-hub/index.js"
    if [ -f "$INDEX_PATH" ]; then
      log "Using plugin index.js at $INDEX_PATH"
      exec "$NODE_BIN" "$INDEX_PATH" "$@"
    fi
  fi
  
  # Second check: try globally installed mcp-hub via npm
  NPM_GLOBAL_DIR="$(npm root -g 2>/dev/null || echo "")"
  if [ -n "$NPM_GLOBAL_DIR" ] && [ -d "$NPM_GLOBAL_DIR/mcp-hub" ]; then
    GLOBAL_INDEX="$NPM_GLOBAL_DIR/mcp-hub/index.js"
    if [ -f "$GLOBAL_INDEX" ]; then
      log "Using globally installed mcp-hub at $GLOBAL_INDEX"
      exec "$NODE_BIN" "$GLOBAL_INDEX" "$@"
    fi
  fi
  
  # Last resort: Install mcp-hub on demand in a temporary directory
  log "Binary not found in expected locations, installing temporarily..."
  TEMP_DIR=$(mktemp -d)
  
  cleanup() {
    log "Cleaning up temporary directory"
    rm -rf "$TEMP_DIR"
  }
  
  trap cleanup EXIT
  
  cd "$TEMP_DIR"
  
  # Create package.json
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
  
  # Use npm to install
  log "Installing mcp-hub with npm in $TEMP_DIR"
  ${pkgs.nodePackages.npm}/bin/npm install --no-audit --no-fund --no-package-lock --silent
  
  if [ -d "$TEMP_DIR/node_modules/mcp-hub" ]; then
    TEMP_INDEX="$TEMP_DIR/node_modules/mcp-hub/index.js"
    if [ -f "$TEMP_INDEX" ]; then
      log "Using temporary installation at $TEMP_INDEX"
      exec "$NODE_BIN" "$TEMP_INDEX" "$@"
    fi
  fi
  
  log "Failed to find or install mcp-hub"
  exit 1
''