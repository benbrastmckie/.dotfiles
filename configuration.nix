# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:
{
  imports =
    [ # Hardware configuration is now imported in flake.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nandi"; # Define your hostname.
  
  # Networking configuration
  networking = {
    networkmanager = {
      enable = true;  # Use NetworkManager for all networking
      wifi.backend = "iwd";  # Use iwd backend for better performance
    };
    # Disable wpa_supplicant completely in the main system
    wireless.enable = false;
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Security hardening
  security.pam.services.swaylock = {};  # Enable screen locking
  security.sudo.wheelNeedsPassword = true;  # Require password for sudo
  
  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];  # HTTP/HTTPS
    allowedUDPPorts = [ ];
  };

  # Enable automatic timezone detection based on location
  services.automatic-timezoned.enable = true;
  services.geoclue2.enable = true;

  # Set your static time zone
  # time.timeZone = "America/Los_Angeles";
  # time.timeZone = "America/New_York";

  # Update to local time
  # services.localtimed.enable = true;

  # makes the split mechanical keyboard recognized
  services.udev = {
    enable = true;
    packages = [
      pkgs.qmk-udev-rules
    ];
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Set environment variables for Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";  # Helps with cursor issues
  };

  # Enable the X11 windowing system and display manager
  services.xserver = {
    enable = true;
    
    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
    };
    
    # Enable full GNOME desktop environment
    desktopManager.gnome = {
      enable = true;
      extraGSettingsOverrides = ''
        [org.gnome.desktop.interface]
        enable-hot-corners=false
      '';
    };
  };

  # Enable niri Wayland compositor
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # # NOTE: note needed with config.kdl in /.config/niri
  # # Create niri config directory and configuration
  # environment.etc."niri/config.kdl".text = ''
  #   spawn_at_startup = [
  #       { command = "gnome-session --session=gnome" }
  #   ]
  # '';

  # Enable GNOME services
  services.gnome = {
    gnome-settings-daemon.enable = true;
    gnome-online-accounts.enable = true;
    evolution-data-server.enable = true;
    gnome-keyring.enable = true;
  };

  # Additional GNOME services that are useful for both environments
  services.dbus.packages = [ pkgs.dconf ];
  programs.dconf.enable = true;

  # Enable GNOME Virtual File System
  services.gvfs.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    # xkbVariant = "";
    
    # # Configure key repeat delay and rate
    # autoRepeatDelay = 50;    # Delay before key repeat starts (milliseconds)
    # autoRepeatInterval = 30;  # Interval between key repeats (milliseconds)
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  # services.blueman.enable = true;  # Save for Niri without Gnome

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.benjamin = {
    isNormalUser = true;
    description = "Benjamin";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.input-fonts.acceptLicense = true;


  environment.systemPackages = 
    (with pkgs; [
      # Wayland and Niri essentials
      wl-clipboard  # Still useful for command-line clipboard operations
      wayland-utils  # Useful for debugging Wayland issues
      xdg-utils  # Required for basic desktop integration
      qt6.qtwayland  # Required for Qt6 apps
      libsForQt5.qt5.qtwayland  # Required for Qt5 apps
      swaybg  # Needed for niri wallpaper

      # # For use with Niri on without Gnome
      # fuzzel  # Application launcher
      # mako    # Notification daemon
      # grim    # Screenshot utility
      # slurp   # Region selection
      # swaylock  # Screen locker
      # waybar  # Status bar
      # swayidle  # Idle management
      # network-manager-applet  # nm-applet
      # blueman  # Bluetooth management
      # polkit_gnome  # Authentication agent
      # wl-clipboard-x11  # Extended clipboard support
      # clipman  # Clipboard manager
      # kanshi  # Output management

      # Terminals and Shells
      kitty
      tmux
      fish
      oh-my-fish
      zoxide
      ghostty
      

      # Browsers
      vivaldi
      brave

      # Appearance
      neofetch
      disfetch

      # Development Tools
      git
      python3
      gcc
      unzip
      gnumake
      nodejs_20
      fd
      ripgrep
      fzf
      lazygit
      tree-sitter
      lua-language-server
      stylua
      tree

      # Lean
      # lean4
      mathlibtools
      elan

      # Editors
      neovim
      neovim-remote
      vscodium

      # PDF and Document Tools
      zotero
      texlive.combined.scheme-full
      texlab
      libsForQt5.okular
      pdftk
      pdfannots
      xsel
      pstree
      pandoc
      zathura

      # GNOME Extensions and Tools
      gnome-tweaks
      gnomeExtensions.unite

      # Multimedia
      vlc
      zoom-us
      spotify

      # File Transfer and Torrent
      wget
      torrential

      # Input Tools
      qmk
      via

      # Miscellaneous
      xdotool
      xwayland

      # NixOS
      home-manager
      nix-index

      # Custom zathura (Xwayland)
      (writeShellScriptBin "zathura" ''
        #!/bin/sh
        export GDK_BACKEND=x11
        exec ${pkgs.zathura}/bin/zathura "$@"
      '')
    ]);

    # ++
    #
    # (with pkgs-unstable; [
    #   neovim  # Unstable package
    # ]);

  programs.fish.enable = true;

  fonts.fontDir.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # system.stateVersion = "unstable"; # man configuration.nix or on https://nixos.org/nixos/options.html
  system.stateVersion = "24.11"; # man configuration.nix or on https://nixos.org/nixos/options.html
  # system.stateVersion = "24.05"; # man configuration.nix or on https://nixos.org/nixos/options.html
  # system.stateVersion = "23.11"; # man configuration.nix or on https://nixos.org/nixos/options.html

}
