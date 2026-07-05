# USB installer-specific NixOS configuration.
# Imported as an extraModule by the usb-installer nixosConfiguration in flake.nix.
{ pkgs, lib, ... }:
{
  # USB-specific configurations
  isoImage = {
    edition = lib.mkForce "nandi-usb";
    compressImage = true;
    squashfsCompression = "zstd -Xcompression-level 19";
    # Enable copy-on-write for the ISO
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # Generic hostname for USB
  networking.hostName = lib.mkForce "nandi-usb";

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
    calamares-nixos # NixOS graphical installer

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
    neovim # Your primary editor
    opencode # AI coding agent for terminal
    lazygit # Terminal UI for git commands
    tmux # Terminal multiplexer
    fish # Your preferred shell
    kitty # Your preferred terminal
    ghostty # Modern terminal emulator
    zoxide # Smarter cd command
    fd # Fast find alternative
    ripgrep # Fast search tool
    fzf # Command-line fuzzy finder
    tree # Directory structure display
    lsof # List open files

    # Basic development tools
    python3 # Python programming language
    go # Go programming language
    gcc # GNU Compiler Collection
    nodejs_22 # JavaScript runtime
    uv # Fast Python package installer
    bun # Fast JavaScript runtime
    unzip # Extract ZIP archives

    # Wayland essentials
    wl-clipboard # Clipboard utility for Wayland
    xdg-utils # Desktop integration utilities
    qt6.qtwayland # Wayland support for Qt6
    qt5.qtwayland # Wayland support for Qt5
    swaybg # Wallpaper utility for Wayland

    # GNOME tools (useful for both GNOME and niri)
    gnome-control-center # GNOME Settings GUI
    nautilus # File manager (required by portal)

    # Appearance tools
    disfetch # Minimal system information display

    # NixOS tools
    home-manager # User configuration management
    nix-index # Index Nix store files
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
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "input"
    ];
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
  security.sudo.extraRules = [
    {
      users = [ "benjamin" ];
      commands = [
        {
          command = "${pkgs.calamares-nixos}/bin/calamares";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
