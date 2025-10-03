{
  description = "system config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    lean4.url = "github:leanprover/lean4";
    # Niri input - DISABLED (using GNOME + PaperWM instead)
    # Uncomment to re-enable niri
    # niri = {
    #   url = "github:YaLTeR/niri";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    lectic = {
      url = "github:gleachkr/lectic";
    };
    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Note: MCPHub is loaded via lazy.nvim, not as a flake input
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-23.11";  
    # };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, lectic, nix-ai-tools, utils, ... }@inputs:
  # Note: niri removed from outputs (using GNOME + PaperWM instead)

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

    # Create an overlay for unstable packages
    unstablePackagesOverlay = final: prev: {
      # Window Manager - DISABLED (using GNOME + PaperWM instead)
      # niri = pkgs-unstable.niri; # Active development with frequent improvements

      # Applications
      claude-code = final.callPackage ./packages/claude-code.nix {}; # Latest AI capabilities (custom build)

      # Add other packages that benefit from using unstable below
      # Format: package-name = pkgs-unstable.package-name; # Reason for using unstable
    };

    # Create an overlay for custom Python packages
    pythonPackagesOverlay = final: prev: {
      python312 = prev.python312.override {
        packageOverrides = pySelf: pySuper: {
          cvc5 = pySelf.callPackage ./packages/python-cvc5.nix { };
        };
      };
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
        unstablePackagesOverlay
        pythonPackagesOverlay
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
              inherit nix-ai-tools;
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
              inherit nix-ai-tools;
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
          # inherit niri;  # DISABLED: using GNOME + PaperWM instead
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
    };
    homeConfigurations = {
      benjamin = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          # Note: overlays are already applied to pkgs (defined in nixpkgsConfig)
        ];
        extraSpecialArgs = {
          inherit username;
          inherit name;
          inherit pkgs-unstable;
          inherit nix-ai-tools;
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
    };
  };
}
