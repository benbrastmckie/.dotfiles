{
  description = "system config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    lean4.url = "github:leanprover/lean4";
    # nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-23.11";  
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, ... }:
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    username = "benjamin";
    name = "Ben";
  in {
    # Add ISO configuration
    nixosConfigurations.iso = lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
        ./configuration.nix
        ({ pkgs, lib, ... }: {
          # ISO-specific configurations
          isoImage.edition = "custom-nandi";
          isoImage.compressImage = true;
          # Include your home-manager configuration
          home-manager.users.${username} = import ./home.nix;
        })
      ];
      specialArgs = {
        inherit username;
        inherit name;
        inherit pkgs-unstable;
      };
    };
    nixosConfigurations = {
      nandi = lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit username;
          inherit name;
          inherit pkgs-unstable;
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
