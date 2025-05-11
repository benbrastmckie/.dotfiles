{
  description = "system config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    lean4.url = "github:leanprover/lean4";
    niri = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lectic = {
      url = "github:gleachkr/lectic";
    };
    utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-23.11";  
    # };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, niri, lectic, utils, ... }@inputs:

  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    
    # Configure unstable packages with allowUnfree
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
          "claude-code"
        ];
      };
    };
    
    # Create an overlay for unstable packages
    unstablePackagesOverlay = final: prev: {
      # Window Manager
      niri = pkgs-unstable.niri; # Active development with frequent improvements
      
      # Applications
      claude-code = pkgs-unstable.claude-code; # Latest AI capabilities
      
      # Add other packages that benefit from using unstable below
      # Format: package-name = pkgs-unstable.package-name; # Reason for using unstable
    };
    
    # Create an overlay for MCP-Hub
    mcphubOverlay = final: prev: {
      mcp-hub-cli = prev.writeShellScriptBin "mcp-hub" ''
        #!/bin/sh
        
        # This script finds and runs the MCP-Hub binary
        # First, try to use the bundled binary that comes with the mcphub.nvim plugin
        # This approach is more reliable as it uses the exact version that the plugin expects
        
        # Check if the plugin is installed in the default location
        PLUGIN_DIR="$HOME/.local/share/nvim/lazy/mcphub.nvim"
        if [ -d "$PLUGIN_DIR" ]; then
          # Look for the binary
          if [ -f "$PLUGIN_DIR/mcp-hub/index.js" ]; then
            exec ${prev.nodejs_20}/bin/node "$PLUGIN_DIR/mcp-hub/index.js" "$@"
            exit 0
          fi
        fi
        
        # If the plugin wasn't found, use npm to install and run mcp-hub
        echo "MCP-Hub plugin not found in expected location. Attempting to install..."
        export HOME=$HOME
        TEMP_DIR=$(mktemp -d)
        cd $TEMP_DIR
        ${prev.nodePackages.npm}/bin/npm install mcp-hub
        if [ -d "$TEMP_DIR/node_modules/mcp-hub" ]; then
          echo "Running MCP-Hub from npm installation..."
          exec ${prev.nodejs_20}/bin/node "$TEMP_DIR/node_modules/mcp-hub/index.js" "$@"
        else
          echo "Failed to install MCP-Hub. Please install the mcphub.nvim plugin in Neovim."
          exit 1
        fi
      '';
    };
    
    # Common nixpkgs configuration
    nixpkgsConfig = {
      inherit system;
      config = {
        allowUnfree = true;
      };
      overlays = [
        unstablePackagesOverlay
        mcphubOverlay
      ];
    };
    
    # Apply the unstable overlay to the stable package set
    pkgs = import nixpkgs nixpkgsConfig;
    
    username = "benjamin";
    name = "Ben";
  in {
    nixosConfigurations = {
      nandi = lib.nixosSystem {
        inherit system;
        modules = [ 
          ./configuration.nix
          ./hosts/nandi/hardware-configuration.nix
          
          # Apply our unstable packages overlay globally
          { nixpkgs = nixpkgsConfig; }
          
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = {
              inherit pkgs-unstable;
              inherit lectic;
            };
          }
        ];
        specialArgs = {
          inherit username;
          inherit name;
          inherit pkgs-unstable;
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
      # ISO configuration
      iso = lib.nixosSystem {
        inherit system;
        modules = [ 
          ./configuration.nix
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          
          # Apply our unstable packages overlay globally
          { nixpkgs = nixpkgsConfig; }
          
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = {
              inherit pkgs-unstable;
              inherit lectic;
            };
          }
          ({ pkgs, lib, lectic, ... }: {
            # ISO-specific configurations
            isoImage.edition = lib.mkForce "nandi";
            isoImage.compressImage = true;
            # Enable copy-on-write for the ISO
            isoImage.squashfsCompression = "zstd";
            # Make the ISO compatible with most systems
            nixpkgs.hostPlatform = system;
            # Configure networking for ISO with NetworkManager only
            networking = {
              networkmanager = {
                enable = true;
                wifi.backend = "iwd";  # Use iwd backend for better performance
              };
              # Explicitly disable wpa_supplicant
              wireless.enable = false;
            };
            # Enable basic system utilities for the live environment
            environment.systemPackages = with pkgs; [
              vim
              git
              wget
              curl
              # Add networking tools that might be helpful during installation
              iw
              wirelesstools
              networkmanager
            ];
          })
        ];
        specialArgs = {
          inherit username;
          inherit name;
          inherit pkgs-unstable;
          inherit niri;
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
    };
    homeConfigurations = {
      benjamin = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          # Apply our unstable packages overlay when using standalone home-manager
          {
            nixpkgs = {
              overlays = [ 
                unstablePackagesOverlay 
                mcphubOverlay
              ];
              config = { allowUnfree = true; };
            };
          }
        ];
        extraSpecialArgs = {
          inherit username;
          inherit name;
          inherit pkgs-unstable;
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
    };
  };
}
