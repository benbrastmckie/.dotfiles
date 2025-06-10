{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.neovim.mcp-hub;
in {
  options.programs.neovim.mcp-hub = {
    enable = mkEnableOption "mcp-hub for neovim";
    
    package = mkOption {
      type = types.package;
      description = "The mcp-hub package to use (provided by flake input)";
    };
    
    port = mkOption {
      type = types.int;
      default = 37373;
      description = "Port on which MCP-Hub will listen";
    };
  };

  config = mkIf cfg.enable {
    # Install the MCP-Hub package from flake input
    home.packages = [ cfg.package ];
    
    # Set environment variables for NeoVim to detect the binary
    home.sessionVariables = {
      MCP_HUB_PATH = "${cfg.package}/bin/mcp-hub";
      MCP_HUB_PORT = toString cfg.port;
    };
    
    # Create mcphub config directory
    xdg.configFile."mcphub/.keep".text = "";
  };
}