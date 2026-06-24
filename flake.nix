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
    
    # Apply the unstable overlay to the stable package set
    pkgs = import nixpkgs nixpkgsConfig;
    
    username = "benjamin";
    name = "Ben";
  in {
    # Two home-manager paths exist in parallel:
    #   1. NixOS-integrated (below): manages /etc/profiles/per-user/<user>/
    #      Updated by: sudo nixos-rebuild switch --flake .#<host>
    #   2. Standalone homeConfigurations (bottom of file): manages ~/.nix-profile/
    #      Updated by: home-manager switch --flake .#benjamin
    # Both evaluate home.nix with the same overlays. update.sh runs both
    # in sequence to keep them in sync. ~/.nix-profile/ takes PATH priority.
    nixosConfigurations = {
      nandi = lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./hosts/nandi/hardware-configuration.nix
          { networking.hostName = "nandi"; }
          
          # sops-nix for age-based secrets management (Task 53)
          sops-nix.nixosModules.sops
          
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
      
      hamsa = lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          ./hosts/hamsa/hardware-configuration.nix
          { networking.hostName = "hamsa"; }
          
          # sops-nix for age-based secrets management (Task 53)
          sops-nix.nixosModules.sops
          
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
          { networking.hostName = "nixos-iso"; }
          
          # sops-nix for age-based secrets management (Task 53)
          sops-nix.nixosModules.sops
          
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
          inherit niri;  # Enabled for dual-session with GNOME
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
      # USB Installer configuration
      usb-installer = lib.nixosSystem {
        inherit system;
        modules = [ 
          ./configuration.nix
          ./hosts/usb-installer/hardware-configuration.nix
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          
          # sops-nix for age-based secrets management (Task 53)
          sops-nix.nixosModules.sops
          
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
            # USB-specific configurations
            isoImage.edition = lib.mkForce "nandi-usb";
            isoImage.compressImage = true;
            isoImage.squashfsCompression = "zstd -Xcompression-level 19";
            
            # Generic hostname for USB
            networking.hostName = lib.mkForce "nandi-usb";
            
            # Enable copy-on-write for the ISO
            isoImage.makeEfiBootable = true;
            isoImage.makeUsbBootable = true;
            
            # Configure networking for installer with NetworkManager
            networking = {
              networkmanager = {
                enable = true;
                wifi.backend = "iwd";
              };
              wireless.enable = false;
              # Enable DHCP for automatic network configuration
              useDHCP = lib.mkDefault true;
            };
            
            # Include essential system utilities for installation
            environment.systemPackages = with pkgs; [
              # Graphical installer
              calamares-nixos      # NixOS graphical installer
              
              # System utilities for installation
              git
              wget
              curl
              gnumake
              parted
              dosfstools
              e2fsprogs
              # Networking tools
              iw
              wirelesstools
              networkmanager
              # Hardware tools
              lshw
              pciutils
              usbutils
              # Filesystem tools
              ntfs3g
              exfat
              
              # Essential development tools (from your configuration.nix)
              neovim               # Your primary editor
              opencode             # AI coding agent for terminal
              lazygit              # Terminal UI for git commands
              tmux                 # Terminal multiplexer
              fish                 # Your preferred shell
              kitty                # Your preferred terminal
              ghostty              # Modern terminal emulator
              zoxide               # Smarter cd command
              fd                   # Fast find alternative
              ripgrep              # Fast search tool
              fzf                  # Command-line fuzzy finder
              tree                 # Directory structure display
              lsof                 # List open files
              
              # Basic development tools
              python3              # Python programming language
              go                   # Go programming language
              gcc                  # GNU Compiler Collection
               nodejs_22            # JavaScript runtime
              uv                   # Fast Python package installer
              bun                  # Fast JavaScript runtime
              unzip                # Extract ZIP archives
              
              # Wayland essentials
              wl-clipboard         # Clipboard utility for Wayland
              xdg-utils            # Desktop integration utilities
              qt6.qtwayland        # Wayland support for Qt6
              qt5.qtwayland             # Wayland support for Qt5
              swaybg               # Wallpaper utility for Wayland
              
              # GNOME tools (useful for both GNOME and niri)
              gnome-control-center  # GNOME Settings GUI
              nautilus              # File manager (required by portal)
              
              # Appearance tools
              disfetch             # Minimal system information display
              
              # NixOS tools
              home-manager         # User configuration management
              nix-index            # Index Nix store files
            ];
            
            # Enable SSH for remote installation (optional)
            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
              };
            };
            
            # Auto-login to GNOME for easier setup
            services.displayManager.autoLogin = {
              enable = true;
              user = "benjamin";
            };
            
            # Ensure proper permissions for auto-login
            users.users.benjamin = {
              isNormalUser = true;
              description = "Benjamin";
              extraGroups = [ "networkmanager" "wheel" "audio" "video" "input" ];
              initialHashedPassword = "$6$f2PeXbxhEnBAOWaK$M7TR7eFN2ICFm1y9qwcSHgWeYMRLICTtBOfC5njquaWXsYcIawkHvkHZJzzO3acoaa7/7iKdeZiwiK/LQfnpX0";
            };
            
            # Auto-launch Calamares installer on boot
            environment.etc."xdg/autostart/calamares.desktop".text = ''
              [Desktop Entry]
              Type=Application
              Name=Install NixOS
              Comment=Graphical installer for NixOS
              Exec=sudo -E calamares
              Icon=system-software-install
              Terminal=false
              Categories=System;
              X-GNOME-Autostart-enabled=true
              AutostartCondition=unless-exists ~/.config/calamares-launched
            '';
            
            # Create a script to mark Calamares as launched (prevents re-launch on subsequent logins)
            system.activationScripts.calamaresAutostart = ''
              mkdir -p /home/benjamin/.config
              # Don't create the marker file - let Calamares create it after first launch
            '';
            
            # Allow passwordless sudo for calamares during installation
            security.sudo.extraRules = [{
              users = [ "benjamin" ];
              commands = [{
                command = "${pkgs.calamares-nixos}/bin/calamares";
                options = [ "NOPASSWD" ];
              }];
            }];
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
          inherit pkgs-unstable;
          inherit nix-ai-tools;
          lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        };
      };
    };
  };
}
