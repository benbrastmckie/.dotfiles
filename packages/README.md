# Package Integrations

This directory contains custom package definitions and integrations for the dotfiles configuration.

## Current Packages

### neovim.nix
A wrapper around Neovim unstable that fixes missing maintainers metadata to prevent build errors.

### test-mcphub.sh
A diagnostic script for verifying MCPHub installation and configuration. This script is useful for debugging MCPHub issues when using the lazy.nvim plugin approach.

## MCPHub Integration (Final Implementation)

MCPHub integration has been **significantly simplified** after extensive refactoring. The final approach uses standard lazy.nvim plugin loading for maximum simplicity and reliability.

### Final Architecture: Lazy.nvim Only

After testing multiple approaches including Nix flake integration, the cleanest solution is:

**NixOS Side**: No special configuration needed - clean separation of concerns
**NeoVim Side**: Standard lazy.nvim plugin loading with simple configuration

### Why This Approach Wins

1. **MCPHub is a vim plugin first** - The official flake provides plugin packaging, not a standalone binary
2. **Avoids complexity** - No environment variables, home-manager modules, or dual loading needed
3. **Standard approach** - How most users install MCPHub via their plugin manager
4. **No collisions** - Single source of truth for plugin loading
5. **Easier maintenance** - Standard lazy.nvim troubleshooting and updates

### Current Implementation

MCPHub is loaded via lazy.nvim in `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/mcp-hub.lua`:

```lua
return {
  "ravitemer/mcphub.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  lazy = true,
  cmd = { "MCPHub", "MCPHubStatus" },
  event = { "User AvantePreLoad" },
  config = function()
    require("mcphub").setup({
      port = 37373,
      config = vim.fn.expand("~/.config/mcphub/servers.json"),
      extensions = { avante = { ... } },
      -- ... other settings
    })
  end,
}
```

### What Was Removed

During the refactoring process, the following complex components were removed:

- **Custom Nix packages** (`packages/mcp-hub.nix`) - No longer needed
- **Flake inputs** - MCPHub not included as flake dependency  
- **Home-manager modules** (`home-modules/mcp-hub.nix`) - Disabled
- **Environment variables** - No `MCP_HUB_PATH` or `MCP_HUB_PORT` needed
- **Complex state management** - Simplified to essential functionality
- **NixOS-specific workarounds** - ~200 lines of complex code removed

### Benefits Achieved

- ✅ **Clean separation** - NixOS handles system, NeoVim handles plugins
- ✅ **No collisions** - Single source of plugin loading  
- ✅ **Standard troubleshooting** - Use normal lazy.nvim debugging
- ✅ **Easier updates** - Standard plugin manager handles updates
- ✅ **Less maintenance** - No custom Nix packaging to maintain

### Testing with test-mcphub.sh

Use `test-mcphub.sh` to verify MCPHub installation and troubleshoot any issues:

```bash
bash ~/.dotfiles/packages/test-mcphub.sh
```

**Note**: The test script may show warnings about missing environment variables - this is expected and normal with the new lazy.nvim approach.

#### What the test script checks:

1. **Basic MCPHub Detection**:
   - Tests if MCPHub binary is accessible via standard detection
   - Falls back to PATH detection (normal for lazy.nvim approach)

2. **Configuration Files**:
   - Checks for `~/.config/mcphub/` directory
   - Verifies `servers.json` exists and contains expected servers

3. **Optional Server Test**:
   - Offers to start MCPHub server for live testing
   - Shows any startup errors or warnings

#### When to use:

- **Troubleshooting**: Debug MCPHub connection issues in NeoVim
- **After plugin updates**: Verify MCPHub still works after lazy.nvim updates
- **Configuration issues**: Test MCPHub server functionality

The script is designed to be safe and non-destructive - it only reads configuration and tests basic functionality.