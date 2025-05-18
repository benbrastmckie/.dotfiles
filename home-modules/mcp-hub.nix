{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.neovim.mcp-hub;
in {
  options.programs.neovim.mcp-hub = {
    enable = mkEnableOption "mcp-hub for neovim";
    
    package = mkOption {
      type = types.package;
      default = pkgs.mcp-hub-cli;
      description = "The mcp-hub package to use";
    };
    
    port = mkOption {
      type = types.int;
      default = 37373;
      description = "Port on which MCP-Hub will listen";
    };
    
    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings for MCP-Hub configuration";
    };
  };

  config = mkIf cfg.enable {
    # Install the MCP-Hub package
    home.packages = [ cfg.package ];
    
    # Set environment variables
    home.sessionVariables = {
      MCP_HUB_PATH = "${cfg.package}/bin/mcp-hub";
    };
    
    # Create an autoload script that will be loaded by Neovim at startup
    # A much simpler approach that just provides a direct command to run MCP-Hub
    home.file.".config/nvim/after/plugin/mcp_home_manager.lua".text = ''
      -- MCP-Hub Home Manager integration
      -- This file is automatically loaded by Neovim after all plugins
      
      -- Create the MCPNix command
      vim.api.nvim_create_user_command("MCPNix", function()
        local cmd = "${cfg.package}/bin/mcp-hub"
        
        -- Display what we're doing
        vim.notify("Starting MCP-Hub server via Nix...", vim.log.levels.INFO)
        
        -- Create config file if it doesn't exist
        local config_dir = vim.fn.expand("~/.config/mcphub")
        if vim.fn.isdirectory(config_dir) == 0 then
          vim.fn.mkdir(config_dir, "p")
        end
        
        local config_file = config_dir .. "/config.json"
        if vim.fn.filereadable(config_file) == 0 then
          local default_config = {
            port = ${toString cfg.port},
            debug = true,
            apiKeys = {""},
            logLevel = "debug"
          }
          
          local file = io.open(config_file, "w")
          if file then
            file:write(vim.json.encode(default_config))
            file:close()
          end
        end
        
        -- Start the server with the serve command and config file
        local jobid = vim.fn.jobstart({cmd, "serve", "--port=${toString cfg.port}", "--config=" .. config_file}, {
          env = {
            ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY"),
            OPENAI_API_KEY = os.getenv("OPENAI_API_KEY"),
            MCP_HUB_DEBUG = "true",
            NODE_ENV = "development",
            DEBUG = "mcp-hub*"
          }
        })
        
        if jobid > 0 then
          vim.notify("MCP-Hub server started (job: " .. jobid .. ")", vim.log.levels.INFO)
          
          -- Update global state if it exists
          if _G.mcp_hub_state then
            _G.mcp_hub_state.running = true
            _G.mcp_hub_state.port = ${toString cfg.port}
          end
        else
          vim.notify("Failed to start MCP-Hub", vim.log.levels.ERROR)
        end
      end, { desc = "Start MCP-Hub server using Nix binary" })
      
      -- Create servers.json if it doesn't exist
      local config_dir = vim.fn.expand("~/.config/mcphub")
      if vim.fn.isdirectory(config_dir) == 0 then
        vim.fn.mkdir(config_dir, "p")
      end
      
      -- No longer managing servers.json from NixOS
      -- This allows your Neovim config to manage it without conflicts
      -- The mcphub.nvim plugin will create the appropriate file if needed
      
      -- Notify that the command is available
      vim.notify("MCPNix command available - use :MCPNix to start MCP-Hub", vim.log.levels.INFO)
    '';
    
    # Add a patch for the mcphub.nvim plugin to use our Nix binary
    # This will be loaded by the plugin manager
    home.file.".config/nvim/lua/neotex/plugins/ai/mcp_patch.lua".text = ''
      -- MCP-Hub Nix integration patch
      return {
        "ravitemer/mcphub.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
        },
        -- No build to prevent bundled binary usage
        build = function() end,
        cmd = { "MCPHub", "MCPHubStatus", "MCPHubSettings" },
        config = function()
          -- Get the mcp-hub binary path
          local mcp_hub_path = "${cfg.package}/bin/mcp-hub"
          
          -- Load and configure mcphub
          local ok, mcphub = pcall(require, "mcphub")
          if not ok then
            vim.notify("MCPHub plugin not loaded", vim.log.levels.WARN)
            return
          end
          
          -- Configure with our Nix binary
          mcphub.setup({
            use_bundled_binary = false,
            cmd = mcp_hub_path,
            cmdArgs = {"serve"},
            port = ${toString cfg.port},
            debug = true,
            logLevel = "debug",
            auto_approve = ${if cfg.settings.auto_approve or false then "true" else "false"},
            env = {
              ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY"),
              OPENAI_API_KEY = os.getenv("OPENAI_API_KEY"),
              DEBUG = "true",
              MCP_HUB_DEBUG = "true",
              NODE_ENV = "development"
            },
            extensions = {
              avante = {},
              codecompanion = {
                show_result_in_chat = false,
                make_vars = true,
              },
            },
            ui = {
              window = {
                width = 0.8,
                height = 0.8,
                border = "rounded",
              },
            },
            log = {
              level = vim.log.levels.DEBUG,
              to_file = true,
              file_path = vim.fn.expand("~/.config/mcphub/mcp-hub.log")
            }
          })
        end,
      }
    '';
  };
}