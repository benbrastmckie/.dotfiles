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

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lean4, niri, lectic, nix-ai-tools, utils, sops-nix, ... }@inputs:

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

    # Import overlays from dedicated files
    claudeSquadOverlay = import ./overlays/claude-squad.nix;
    # unstable-packages overlay is curried: it needs pkgs-unstable partially applied
    unstablePackagesOverlay = import ./overlays/unstable-packages.nix pkgs-unstable;
    pythonPackagesOverlay = import ./overlays/python-packages.nix;

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

    # Apply the overlays to the stable package set
    pkgs = import nixpkgs nixpkgsConfig;

    username = "benjamin";
    name = "Ben";

    # Shared specialArgs for both NixOS-integrated and standalone home-manager.
    # Both paths receive identical extraSpecialArgs so home.nix evaluates consistently.
    hmExtraSpecialArgs = {
      inherit pkgs-unstable;
      inherit lectic;
      inherit nix-ai-tools;
    };

    # mkHost: factory for standard NixOS host configurations.
    # Accepts { hostname, extraModules ? [], extraSpecialArgs ? {} }.
    mkHost = import ./lib/mkHost.nix {
      inherit nixpkgs home-manager sops-nix;
      inherit nixpkgsConfig username name pkgs-unstable lectic nix-ai-tools system;
      root = self;
    };
  in {
    # Two home-manager paths exist in parallel:
    #   1. NixOS-integrated (below): manages /etc/profiles/per-user/<user>/
    #      Updated by: sudo nixos-rebuild switch --flake .#<host>
    #   2. Standalone homeConfigurations (bottom of file): manages ~/.nix-profile/
    #      Updated by: home-manager switch --flake .#benjamin
    # Both evaluate home.nix with the same overlays. update.sh runs both
    # in sequence to keep them in sync. ~/.nix-profile/ takes PATH priority.
    nixosConfigurations = {
      nandi = mkHost { hostname = "nandi"; };

      hamsa = mkHost { hostname = "hamsa"; };

      garuda = mkHost {
        hostname = "garuda";
        extraModules = [ ./hosts/garuda/default.nix ];
      };

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
                wifi.backend = "iwd"; # Use iwd backend for better performance
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
          inherit niri; # Enabled for dual-session with GNOME
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
        } // hmExtraSpecialArgs // {
          # Standalone home installs the BUILT lectic package (home.packages gets the
          # derivation), matching pre-refactor behavior. The NixOS-integrated path keeps
          # the raw lectic input via hmExtraSpecialArgs, so do not unify these.
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
    };
  };
}
