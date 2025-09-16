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
    # Note: MCPHub is loaded via lazy.nvim, not as a flake input
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
    
    # Create an overlay for claude-squad
    claudeSquadOverlay = final: prev: {
      claude-squad = final.buildGoModule rec {
        pname = "claude-squad";
        version = "1.0.8";
        
        src = final.fetchFromGitHub {
          owner = "smtg-ai";
          repo = "claude-squad";
          rev = "v${version}";
          sha256 = "sha256-mzW9Z+QN4EQ3JLFD3uTDT2/c+ZGLzMqngl3o5TVBZN0=";
        };
        
        vendorHash = "sha256-BduH6Vu+p5iFe1N5svZRsb9QuFlhf7usBjMsOtRn2nQ=";
        
        nativeBuildInputs = with final; [ go ];
        
        buildInputs = with final; [ tmux gh ];
        
        postInstall = ''
          # Create 'cs' alias
          ln -s $out/bin/claude-squad $out/bin/cs
        '';
        
        meta = with final.lib; {
          description = "Terminal app that manages multiple AI terminal agents";
          homepage = "https://github.com/smtg-ai/claude-squad";
          license = licenses.agpl3Only;
          maintainers = [ ];
          platforms = platforms.linux ++ platforms.darwin;
        };
      };
    };

    # Create an overlay for opencode v0.9.1  
    opencodeOverlay = final: prev: {
      opencode = final.buildGoModule.override { go = final.go_1_24; } rec {
        pname = "opencode";
        version = "0.9.1";
        
        src = final.fetchFromGitHub {
          owner = "sst";
          repo = "opencode";
          rev = "v${version}";
          hash = "sha256-ZMHEvcMpMgwj9Tzb788xUF9nnPLnrSlr6LzcUg7+MDg=";
        };
        
        # Patch go.mod to remove the tool directive that's causing issues
        postPatch = ''
          # Remove the tool directive from go.mod
          sed -i '/^tool (/,/^)/d' packages/tui/go.mod
        '';
        
        vendorHash = null; # Use null to disable vendor hash checking
        
        # Set the correct working directory for the Go module
        modRoot = "./packages/tui";
        
        # Build the opencode binary from the tui directory
        subPackages = [ "." ];
        
        meta = with final.lib; {
          description = "AI coding agent built for the terminal (v0.9.1)";
          homepage = "https://github.com/sst/opencode";
          license = licenses.mit;
        };
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
    
    # Note: MCPHub is now handled via official flake input instead of custom overlay
    
    # Common nixpkgs configuration
    nixpkgsConfig = {
      inherit system;
      config = {
        allowUnfree = true;
      };
      overlays = [
        claudeSquadOverlay
        opencodeOverlay
        unstablePackagesOverlay
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
                claudeSquadOverlay
                opencodeOverlay
                unstablePackagesOverlay 
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
