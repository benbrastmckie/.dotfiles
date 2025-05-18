# Package Integrations

This directory contains custom package definitions and integrations for the dotfiles configuration.

## MCP-Hub

MCP-Hub is integrated with Neovim using a custom Nix wrapper defined in `mcp-hub.nix`. The wrapper provides a seamless integration with the Neovim environment.

### Implementation Details

The MCP-Hub integration works as follows:

1. The package is defined in `mcp-hub.nix` as a shell script that:
   - Creates a temporary directory for installation
   - Installs MCP-Hub and its dependencies via NPM
   - Provides a command-line interface compatible with the Neovim plugin

2. The integration is managed through:
   - An overlay in `flake.nix` that makes the package available
   - A home-manager module in `home-modules/mcp-hub.nix` that configures the Neovim integration

## MCP-Hub Extensions

MCP-Hub supports various extensions and tools that enhance its capabilities. These extensions are installed as dependencies when MCP-Hub is launched, making them automatically available for use.

### Extension Architecture

The MCP-Hub integration is designed with the following principles:

1. **Runtime Dependencies**: Extensions are added as dependencies in the `package.json` created by `mcp-hub.nix`:
   ```json
   {
     "dependencies": {
       "mcp-hub": "latest",
       "extension-package-name": "latest"
     }
   }
   ```

2. **Dynamic Installation**: Extensions are installed on-demand when MCP-Hub is launched, ensuring they're always available when needed without requiring permanent installation.

3. **Configuration Independence**: The NixOS configuration avoids modifying user-specific configuration files like `servers.json`, allowing your Neovim configuration to manage these files without conflicts.

### Benefits of This Approach

- **No Separate Packaging**: Extensions don't require separate Nix packaging
- **Seamless Version Management**: Always uses the latest compatible versions
- **Clean Integration**: Minimal system modifications needed
- **User Control**: Your Neovim configuration maintains full control over which extensions are active

### Configuration Management

The MCP-Hub server configuration follows these principles:

1. The NixOS module provides the core MCP-Hub server binary through the system
2. Your Neovim configuration controls which extensions are active through `servers.json`
3. This separation ensures rebuilding your NixOS configuration won't interfere with your tools setup

## Usage

MCP-Hub (with Context7) can be launched from within Neovim using the `:MCPHub` or `:MCPNix` commands, depending on which integration path is used.

## Configuration

The MCP-Hub integration can be configured through the `programs.neovim.mcp-hub` options in your `home.nix` file:

```nix
programs.neovim.mcp-hub = {
  enable = true;
  port = 37373;  # Optional, defaults to 37373
  settings = {
    debug = true;
    auto_approve = true;
    # Additional settings as needed
  };
};
```

These settings will be applied to both the MCP-Hub server and the Neovim plugin integration.

## Troubleshooting

### SSE Connection Failed with Code 7

If you encounter an "SSE connection failed with code 7" error when starting MCP-Hub in Neovim, this is typically caused by MCP-Hub server configuration issues or Neovim plugin integration problems.

#### MCP-Hub Server Configuration

1. **Check the servers.json Format**:
   - MCP-Hub can work with two different configuration formats
   - For plugin setup (using the mcphub.nvim plugin directly), the format should be:
   ```json
   {
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
   }
   ```

2. **Set Environment Variables**:
   ```bash
   export ANTHROPIC_API_KEY=your_anthropic_api_key
   export OPENAI_API_KEY=your_openai_api_key  # If using OpenAI
   ```

#### Fix Neovim Plugin Configuration

If you're still experiencing issues, you might need to update your Neovim plugin configuration:

1. **Update mcphub.nvim Configuration**:

Create or edit your mcphub.nvim plugin configuration in your Neovim config. Here's a template for a proper setup:

```lua
-- In your plugins configuration
{
  "ravitemer/mcphub.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  cmd = { "MCPHub", "MCPHubStatus", "MCPHubSettings" },
  config = function()
    local ok, mcphub = pcall(require, "mcphub")
    if not ok then
      vim.notify("MCPHub plugin not loaded", vim.log.levels.WARN)
      return
    end
    
    -- Configure with environment variable for the API key
    mcphub.setup({
      use_bundled_binary = false,  -- Use system-installed MCP-Hub
      cmd = vim.env.MCP_HUB_PATH or "mcp-hub",
      cmdArgs = {"serve"},
      port = 37373,
      debug = true,
      auto_approve = true,
      env = {
        ANTHROPIC_API_KEY = vim.env.ANTHROPIC_API_KEY,
        OPENAI_API_KEY = vim.env.OPENAI_API_KEY,
        DEBUG = "true"
      },
      extensions = {
        avante = {},
        codecompanion = {
          show_result_in_chat = false,
          make_vars = true,
        },
      },
      log = {
        level = vim.log.levels.DEBUG,
        to_file = true,
        file_path = vim.fn.expand("~/.config/mcphub/mcphub.log")
      }
    })
  end,
}
```

2. **Use MCPHub Commands Directly**:
   - Instead of using `:MCPNix`, use the `:MCPHub` command provided by the plugin
   - Check the log file at `~/.config/mcphub/mcphub.log` for detailed error information

3. **Restart Neovim**: After making these changes, restart Neovim completely

#### Direct Testing

If the issue persists, test MCP-Hub directly from the command line:
```bash
# Add API key to environment
export ANTHROPIC_API_KEY=your_key_here

# Start server in debug mode
~/.nix-profile/bin/mcp-hub serve --port=37373
```