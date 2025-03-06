# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "garuda"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

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
    
    # Enable GNOME Desktop Environment
    desktopManager.gnome.enable = true;
  };

  # Enable niri Wayland compositor
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

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
  services.xserver.libinput.enable = true;

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
      wl-clipboard
      wayland-utils
      wayland
      xdg-utils
      qt6.qtwayland
      libsForQt5.qt5.qtwayland
      fuzzel  # Application launcher
      # wofi    # Application launcher (alternative to fuzzel)
      mako    # Notification daemon
      grim    # Screenshot utility
      slurp   # Region selection
      swaylock  # Screen locker
      waybar  # Status bar

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
