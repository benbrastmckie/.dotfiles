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
    
    # Common nixpkgs configuration
    nixpkgsConfig = {
      inherit system;
      config = {
        allowUnfree = true;
      };
      overlays = [
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
          # inherit lectic;
          lectic = lectic.packages.${system}.default;
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
              overlays = [ unstablePackagesOverlay ];
              config = { allowUnfree = true; };
            };
          }
        ];
        extraSpecialArgs = {
          inherit username;
          inherit name;
          inherit pkgs-unstable;
          lectic = lectic.packages.${system}.default;
          # lectic = lectic.defaultPackage.${system};
        };
      };
    };
  };
}
