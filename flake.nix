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
    pkgs = nixpkgs.legacyPackages.${system};
    pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    username = "benjamin";
    name = "Ben";
    
    # # Override to use unstable for specific packages
    # finalPkgs = pkgs.extend (final: prev: {
    #   niri = pkgs-unstable.niri;
    # });
  in {
    nixosConfigurations = {
      nandi = lib.nixosSystem {
        inherit system;
        modules = [ 
          ./configuration.nix
          ./hosts/nandi/hardware-configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = {
              inherit pkgs-unstable;
              inherit lectic;
            };
          }
          ({ config, pkgs, ... }: {
            nixpkgs.overlays = [
              (final: prev: {
                niri = pkgs-unstable.niri;
              })
            ];
          })
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
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home.nix;
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
        modules = [ ./home.nix ];
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
