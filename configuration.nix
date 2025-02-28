# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:
# let
#   unstable = import <nixpkgs-unstable> {};
# in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # # Use both stable and unstable channels
  # nixpkgs.overlays = [
  #   (self: super: {
  #     unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixpkgs-unstable.tar.gz") {};
  #   })
  # ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nandi"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    # xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.benjamin = {
    isNormalUser = true;
    description = "Benjamin";
    extraGroups = [ "networkmanager" "wheel" ];
    # packages = with pkgs; [
    #   firefox
    # #  thunderbird
    # ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.input-fonts.acceptLicense = true;


  environment.systemPackages = 
    (with pkgs; [
      # Terminals and Shells
      alacritty
      kitty
      tmux
      fish
      oh-my-fish
      zoxide

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
