# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, lectic, ... }:
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
    # Uncomment for better WiFi performance
    # wifi.backend = "iwd";
  };
  # Explicitly disable wpa_supplicant when using NetworkManager
  wireless.enable = false;
};

  # Security hardening
  security.pam.services.swaylock = {};  # Enable screen locking
  security.sudo.wheelNeedsPassword = true;  # Require password for sudo
  
  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];  # HTTP/HTTPS
    allowedUDPPorts = [ ];
  };

# Time and location configuration
services.geoclue2 = {
  enable = true;
  appConfig = {
    "org.gnome.Shell.LocationServices" = {
      isAllowed = true;
      isSystem = true;
    };
    automatic-timezone = {
      isAllowed = true;
      isSystem = true;
    };
  };
};

# Enable location services
location.provider = "geoclue2";

# Choose ONE of the following approaches:
# Option 1: Use automatic timezone detection (recommended with GNOME)
services.automatic-timezoned.enable = true;
# services.localtimed.enable = true;  # Don't enable both services

# Option 2: Or set a static timezone (uncomment if you prefer this)
# time.timeZone = "America/New_York";

# Configure time synchronization (independent of timezone setting)
services.timesyncd.enable = true;

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

  # Configure Wayland properly
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.polkit.enable = true;

  # Ensure proper Wayland and GNOME integration
  services.displayManager.sessionPackages = [ pkgs.niri ];
  programs.xwayland.enable = true;

  # Enable GNOME services
  services.gnome = {
    gnome-settings-daemon.enable = true;
    gnome-online-accounts.enable = true;
    evolution-data-server.enable = true;
    gnome-keyring.enable = true;
    gnome-remote-desktop.enable = true;
    # core-network.enable = true;  # Ensure GNOME network components are enabled
  };

  # Additional GNOME services that are useful for both environments
  services.dbus.packages = [ pkgs.dconf ];
  programs.dconf.enable = true;

  # Enable GNOME Virtual File System
  services.gvfs.enable = true;

# Configure keymap in X11
services.xserver = {
  xkb.layout = "us";
  # Uncomment to set key repeat settings
  # xkb.options = "caps:escape";  # Optional: remap caps lock to escape
};

  # Enable CUPS to print documents.
  services.printing.enable = true;

# Enable Bluetooth
hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;  # Automatically power on Bluetooth adapter at boot
};
services.blueman.enable = lib.mkIf (!config.services.xserver.desktopManager.gnome.enable) true;

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    # Use the system-wide installation
    systemWide = false;
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
      wl-clipboard         # Clipboard utility for Wayland compositors
      xdg-utils            # Standard desktop integration utilities
      qt6.qtwayland        # Wayland support for Qt6 applications
      libsForQt5.qt5.qtwayland  # Wayland support for Qt5 applications
      swaybg               # Simple wallpaper utility for Wayland

      # # For use with Niri without Gnome utilities
      # fuzzel               # Lightweight application launcher for Wayland
      # mako                 # Lightweight notification daemon for Wayland
      # grim                 # Screenshot utility for Wayland
      # slurp                # Area selection tool for Wayland screenshots
      # swaylock             # Screen locker for Wayland compositors
      # waybar               # Customizable status bar for Wayland
      # swayidle             # Idle management daemon for Wayland
      # network-manager-applet  # GUI for NetworkManager connections
      # blueman              # Bluetooth management utility
      # polkit_gnome         # PolicyKit authentication agent for GNOME
      # wl-clipboard-x11     # X11 clipboard compatibility for Wayland
      # clipman              # Clipboard manager for Wayland
      # kanshi               # Dynamic display configuration tool

      # Terminals and Shells
      kitty                # GPU-accelerated terminal emulator
      tmux                 # Terminal multiplexer for managing multiple terminal sessions
      fish                 # User-friendly command line shell
      oh-my-fish           # Framework to manage fish shell configuration
      zoxide               # Smarter cd command with learning capabilities
      ghostty              # Modern terminal emulator with GPU acceleration
      libsecret            # Tool for managing secrets (provides secret-tool command)
      
      # Browsers
      vivaldi              # Feature-rich web browser with built-in tools
      brave                # Privacy-focused web browser based on Chromium

      # Appearance
      neofetch             # Command-line system information tool with ASCII art
      disfetch             # Minimal system information display tool

      # Development Tools
      git                  # Distributed version control system
      python3              # Python programming language
      go                   # Go programming language
      gcc                  # GNU Compiler Collection for C/C++
      unzip                # Extract files from ZIP archives
      gnumake              # Build automation tool
      nodejs_20            # JavaScript runtime environment
      uv                   # Fast Python package installer and resolver
      bun                  # Fast all-in-one JavaScript runtime
      fd                   # Simple, fast alternative to 'find'
      ripgrep              # Fast line-oriented search tool (alternative to grep)
      fzf                  # Command-line fuzzy finder
      lazygit              # Terminal UI for git commands
      tree-sitter          # Parsing library for code highlighting and navigation
      lua-language-server  # Language server for Lua development
      stylua               # Opinionated Lua code formatter
      tree                 # Display directory structure in a tree-like format
      # u-root-cmds           

      # Lean
      # lean4              # Theorem prover and programming language
      mathlibtools         # Tools for working with mathlib (Lean math library)
      elan                 # Version manager for Lean

      # Editors
      neovim               # Highly configurable text editor (Vim-fork)
      neovim-remote        # Tool for controlling Neovim processes
      vscodium             # Open source build of VS Code without Microsoft telemetry
      lectic               # Custom editor or tool (appears to be a local package)

      # PDF and Document Tools
      zotero               # Reference management software
      texlive.combined.scheme-full  # Complete TeX Live distribution for document preparation
      texlab               # Language server for LaTeX
      libsForQt5.okular    # Universal document viewer
      pdftk                # PDF toolkit for manipulating PDF documents
      pdfannots            # Extract annotations from PDF files
      xsel                 # Command-line tool for getting/setting X selection
      pstree               # Display running processes as a tree
      pandoc               # Universal document converter
      zathura              # Light-weight PDF/document viewer
      libreoffice          # RTF word processor with signature support
      evince               # GNOME document viewer (handles PDF, PS, DVI, etc.)

      # GNOME Extensions and Tools
      gnome-tweaks         # Tool to customize advanced GNOME settings
      gnomeExtensions.unite # GNOME extension to remove title bars and merge elements
      kooha

      # Multimedia
      vlc                  # Cross-platform multimedia player
      zoom-us              # Video conferencing tool
      spotify              # Music streaming service client
      signal-desktop       # Signal message app

      # File Transfer and Torrent
      wget                 # Tool for retrieving files using HTTP, HTTPS, and FTP
      torrential           # GTK4 BitTorrent client

      # Input Tools
      qmk                  # Quantum Mechanical Keyboard firmware utilities
      via                  # Keyboard configuration tool for QMK-powered keyboards

      # Miscellaneous
      xdotool              # Command-line X11 automation tool
      xwayland             # X server for running X11 applications on Wayland

      # NixOS
      home-manager         # Tool for managing user configuration
      nix-index            # Utility for indexing Nix store files

      # Custom zathura (force X11 for consistency)
      # Note: Zathura uses GTK with server-side decorations, so Unite extension
      # can hide title bars regardless. This wrapper ensures consistent X11 behavior.
      (writeShellScriptBin "zathura" ''
        #!/bin/sh
        export GDK_BACKEND=x11
        exec ${pkgs.zathura}/bin/zathura "$@"
      '')

      # Custom sioyek (force X11 for title bar removal)
      # Note: Sioyek uses Qt6 with client-side decorations that Unite extension
      # cannot hide on Wayland. Forcing X11 enables server-side decorations
      # that Unite can control. Original sioyek package removed to avoid conflicts.
      (writeShellScriptBin "sioyek" ''
        #!/bin/sh
        export QT_QPA_PLATFORM=xcb
        exec ${pkgs.sioyek}/bin/sioyek "$@"
      '')
    ]);

# Shell configuration
programs.fish = {
  enable = true;
  interactiveShellInit = ''
    # Initialize zoxide for better directory navigation
    zoxide init fish | source
  '';
};

# Font configuration
fonts = {
  fontDir.enable = true;
  enableDefaultPackages = true;
  packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
  ];
  fontconfig = {
    defaultFonts = {
      serif = [ "Liberation Serif" "Noto Serif" ];
      sansSerif = [ "Liberation Sans" "Noto Sans" ];
      monospace = [ "Fira Code" "Liberation Mono" ];
    };
  };
};

# Enable useful Nix features
nix = {
  settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;  # Optimize the Nix store automatically
  };
  gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
};

# Do not change this value after initial installation
system.stateVersion = "24.11";

}
