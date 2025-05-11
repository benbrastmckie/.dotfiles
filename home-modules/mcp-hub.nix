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
    
    # Create configuration directory and files
    home.file.".config/mcphub/servers.json".text = builtins.toJSON {
      servers = [
        {
          name = "default";
          description = "Default MCP Hub server";
          url = "http://localhost:${toString cfg.port}";
          apiKey = "";
          default = true;
        }
      ];
    };
    
    # Set environment variables
    home.sessionVariables = {
      MCP_HUB_PATH = "${cfg.package}/bin/mcp-hub";
    };
    
    # Neovim plugin configuration
    programs.neovim.plugins = mkIf (config.programs.neovim.enable) [{
      plugin = pkgs.vimPlugins.mcphub-nvim or pkgs.vimPlugins.vim-nix; # Fallback to prevent errors
      config = ''
        lua << EOF
        local mcp_settings = ${builtins.toJSON cfg.settings}
        
        require('mcphub').setup({
          use_bundled_binary = false,
          cmd = os.getenv("MCP_HUB_PATH") or "${cfg.package}/bin/mcp-hub",
          cmdArgs = {},
          port = ${toString cfg.port},
          config = vim.fn.expand("~/.config/mcphub/servers.json"),
          debug = mcp_settings.debug or true,
          native_servers = mcp_settings.native_servers or {},
          auto_approve = mcp_settings.auto_approve or false,
          extensions = mcp_settings.extensions or {
            avante = {},
            codecompanion = {
              show_result_in_chat = false,
              make_vars = true,
            },
          },
          ui = mcp_settings.ui or {
            window = {
              width = 0.8,
              height = 0.8,
              relative = "editor",
              zindex = 50,
              border = "rounded",
            },
          },
          log = mcp_settings.log or {
            level = vim.log.levels.WARN,
            to_file = false,
          },
        })
        EOF
      '';
    }];
  };
}