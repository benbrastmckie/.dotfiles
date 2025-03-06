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
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-23.11";  
    # };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, niri, ... }@inputs:
  # outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, niri, ... }:

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
        };
      };
      # ISO configuration
      iso = lib.nixosSystem {
        inherit system;
        modules = [ 
          ./configuration.nix
          /etc/nixos/hardware-configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home.nix;
          }
          ({ pkgs, lib, ... }: {
            # ISO-specific configurations
            isoImage.edition = lib.mkForce "nandi";
            isoImage.compressImage = true;
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
        };
      };
    };
  };
}
