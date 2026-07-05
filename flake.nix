{
  description = "system config";

  inputs = {
    # Pinned to the stable release channel for near-100% binary cache hits
    # (Hydra fully builds the stable channel). nixpkgs-unstable stays on
    # unstable to feed pkgs-unstable + nix-ai-tools. See task 61.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    lean4 = {
      url = "github:leanprover/lean4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Niri input - ENABLED (dual-session with GNOME)
    niri = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lectic = {
      url = "github:gleachkr/lectic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix for age-based secrets management (Task 53)
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    # Note: MCPHub is loaded via lazy.nvim, not as a flake input
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-23.11";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      niri,
      lectic,
      nix-ai-tools,
      sops-nix,
      ...
    }:

    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      # Configure unstable packages with allowUnfree
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "claude-code"
            ];
        };
      };

      # Import overlays from dedicated files
      claudeSquadOverlay = import ./overlays/claude-squad.nix;
      # unstable-packages overlay is curried: it needs pkgs-unstable partially applied
      unstablePackagesOverlay = import ./overlays/unstable-packages.nix pkgs-unstable;
      pythonPackagesOverlay = import ./overlays/python-packages.nix;

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

      # Apply the overlays to the stable package set
      pkgs = import nixpkgs nixpkgsConfig;

      username = "benjamin";
      name = "Ben";

      # Shared specialArgs for both NixOS-integrated and standalone home-manager.
      # Both paths receive identical extraSpecialArgs so home.nix evaluates consistently.
      hmExtraSpecialArgs = {
        inherit pkgs-unstable;
        lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        inherit nix-ai-tools;
      };

      # mkHost: factory for standard NixOS host configurations.
      # Accepts { hostname, extraModules ? [], extraSpecialArgs ? {} }.
      mkHost = import ./lib/mkHost.nix {
        inherit nixpkgs home-manager sops-nix;
        inherit
          nixpkgsConfig
          username
          name
          pkgs-unstable
          lectic
          nix-ai-tools
          system
          ;
        root = self;
      };
    in
    {
      # Two home-manager paths exist in parallel:
      #   1. NixOS-integrated (below): manages /etc/profiles/per-user/<user>/
      #      Updated by: sudo nixos-rebuild switch --flake .#<host>
      #   2. Standalone homeConfigurations (bottom of file): manages ~/.nix-profile/
      #      Updated by: home-manager switch --flake .#benjamin
      # Both evaluate home.nix with the same overlays. update.sh runs both
      # in sequence to keep them in sync. ~/.nix-profile/ takes PATH priority.
      nixosConfigurations = {
        nandi = mkHost {
          hostname = "nandi";
          extraModules = [ ./hosts/nandi/default.nix ];
        };

        hamsa = mkHost { hostname = "hamsa"; };

        garuda = mkHost { hostname = "garuda"; };

        # ISO configuration — uses nixpkgs CD template; kept explicit (not via mkHost)
        # because it needs the installer module and custom iso specialArgs (niri).
        iso = lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            { networking.hostName = "nixos-iso"; }

            # sops-nix for age-based secrets management (Task 53)
            sops-nix.nixosModules.sops

            # Apply our unstable packages overlay globally
            { nixpkgs = nixpkgsConfig; }

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${username} = import ./home.nix;
              home-manager.extraSpecialArgs = hmExtraSpecialArgs;
            }
            ./hosts/iso/default.nix
          ];
          specialArgs = {
            inherit username;
            inherit name;
            inherit pkgs-unstable;
            inherit niri; # Enabled for dual-session with GNOME
            inherit system; # Consumed by hosts/iso/default.nix (nixpkgs.hostPlatform)
            lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
          };
        };

        # USB Installer configuration
        usb-installer = mkHost {
          hostname = "usb-installer";
          extraModules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./hosts/usb-installer/default.nix
          ];
          extraSpecialArgs = {
            inherit niri;
          };
        };
      };

      # Standalone home-manager: manages ~/.nix-profile/
      # Enables quick home-only rebuilds without sudo (home-manager switch --flake .#benjamin).
      # Must stay in sync with the NixOS-integrated home-manager above — update.sh runs both.
      homeConfigurations = {
        benjamin = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
          ];
          extraSpecialArgs = {
            inherit username;
            inherit name;
          }
          // hmExtraSpecialArgs;
          # Both the NixOS-integrated and standalone paths now resolve lectic to the built
          # package via hmExtraSpecialArgs (see the shared `lectic = lectic.packages.${system}...`
          # expression above); no per-path override is needed.
        };
      };

      # RFC 166 official formatter. pkgs.nixfmt-rfc-style is a deprecated alias of this same
      # derivation in this repo's pinned nixpkgs (nixos-26.05) — use pkgs.nixfmt directly to
      # avoid the deprecation warning. Run via `nix fmt`.
      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
