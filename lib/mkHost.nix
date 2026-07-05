# lib/mkHost.nix — centralizes the repeated nixpkgs.lib.nixosSystem pattern.
#
# Usage in flake.nix:
#   mkHost = import ./lib/mkHost.nix { ... inherit (inputs) nixpkgs home-manager sops-nix; ... };
#   nandi = mkHost { hostname = "nandi"; extraModules = []; extraSpecialArgs = {}; };
{
  nixpkgs,
  home-manager,
  sops-nix,
  nixpkgsConfig,
  username,
  name,
  pkgs-unstable,
  lectic,
  nix-ai-tools,
  system,
  # root: absolute path to the dotfiles repository root (pass as `self` or `./.` from flake.nix)
  root,
}:

{
  hostname,
  extraModules ? [ ],
  extraSpecialArgs ? { },
}:

nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    "${root}/configuration.nix"
    "${root}/hosts/${hostname}/hardware-configuration.nix"
    { networking.hostName = hostname; }

    # sops-nix for age-based secrets management (Task 53)
    sops-nix.nixosModules.sops

    # Apply our overlays globally
    { nixpkgs = nixpkgsConfig; }

    home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${username} = import "${root}/home.nix";
        extraSpecialArgs = {
          inherit pkgs-unstable;
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
          inherit nix-ai-tools;
        };
      };
    }
  ]
  ++ extraModules;
  specialArgs = {
    inherit username;
    inherit name;
    inherit pkgs-unstable;
    lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
  }
  // extraSpecialArgs;
}
