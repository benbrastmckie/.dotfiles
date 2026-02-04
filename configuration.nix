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

  # ==========================================================================
  # Suspend/Resume and NetworkManager Deadlock Fixes for Ryzen AI 300 Series
  # ==========================================================================
  # Problem: System fails to suspend due to MediaTek WiFi (mt7925e) timeout
  # and AMD GPU VPE (Video Processing Engine) reset failure.
  # Also: NetworkManager deadlocks caused by WiFi driver kernel worker threads.
  #
  # Solution:
  # 1. Use latest kernel for best Ryzen AI 300 hardware support
  # 2. Add AMD-specific kernel parameters for better power management
  # 3. Disable problematic WiFi power management during suspend AND runtime
  # 4. Work around AMD GPU VPE suspend issues
  # 5. Reduce hung task timeout for earlier deadlock detection
  #
  # See: specs/reports/019_system_freeze_shutdown_analysis.md
  # ==========================================================================

  # Use latest kernel for best Ryzen AI 300 series support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Kernel parameters for Ryzen AI 300 suspend/resume and deadlock detection
  boot.kernelParams = [
    "amd_pstate=active"           # Enable AMD P-state driver for better power management
    "amdgpu.dcdebugmask=0x10"     # Disable problematic GPU features during suspend
    "rtc_cmos.use_acpi_alarm=1"   # Better ACPI wake support
    "hung_task_timeout_secs=60"   # Detect deadlocks faster (default: 120s)
  ];

  # Disable power management for audio and WiFi stability
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=0 power_save_controller=N
    options mt7925e disable_aspm=1 power_save=0  # WiFi 6E/7 stability
  '';

  # NOTE: networking.hostName is set per-host in flake.nix

# WiFi Configuration (see docs/wifi.md for details)
# - Uses NetworkManager with default wpa_supplicant backend (mt7925e WiFi 6E/7)
# - Do NOT enable "wifi.backend = iwd" (doesn't work with this hardware)
# - Do NOT set "wireless.enable" manually (NetworkManager manages it automatically)
networking = {
  networkmanager.enable = true;
  # networkmanager.wifi.backend = "iwd";  # DO NOT UNCOMMENT - breaks WiFi
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
  # Enable static source as fallback when network geolocation fails
  # Coordinates for California (approximate location for timezone detection)
  # This provides a backup location when BeaconDB or WiFi geolocation is unavailable
  enableStatic = true;
  staticLatitude = 37.77;   # San Francisco area
  staticLongitude = -122.42;
  staticAltitude = 50;      # 50 meters (approximate elevation for San Francisco Bay Area)
  staticAccuracy = 100000;  # 100km accuracy (sufficient for timezone detection)
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

# California default with automatic detection override
# The lib.mkDefault allows automatic-timezoned to override when geolocation works
time.timeZone = lib.mkDefault "America/Los_Angeles";

# Enable automatic timezone detection (will override the default above)
services.automatic-timezoned.enable = true;

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
  services.xserver.enable = true;

  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  # Hide root user from GDM login screen and GNOME user settings
  # This prevents "System administrator" from appearing in the user list
  environment.etc."accountsservice/users/root".text = ''
    [User]
    SystemAccount=true
  '';

  # Set GDM login screen background using proper NixOS dconf profiles
  # This ensures the dconf database is properly compiled for GDM
  programs.dconf.profiles.gdm.databases = [{
    settings = {
      "org/gnome/desktop/background" = {
        picture-uri = "file:///etc/wallpapers/riverside.jpg";
        picture-uri-dark = "file:///etc/wallpapers/riverside.jpg";  # Required for dark mode
        picture-options = "zoom";
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri = "file:///etc/wallpapers/riverside.jpg";
      };
    };
  }];

  environment.etc."wallpapers/riverside.jpg".source = ./wallpapers/riverside.jpg;

  # Enable full GNOME desktop environment
  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverrides = ''
      [org.gnome.desktop.interface]
      enable-hot-corners=false
    '';
  };

  # Niri Wayland compositor - ENABLED (dual-session with GNOME)
  # Both GNOME and niri sessions available at GDM login
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
  services.displayManager.sessionPackages = [ pkgs.niri ];  # Enables niri session in GDM
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
  # Nautilus required for GNOME portal FileChooser implementation
  services.dbus.packages = [ pkgs.dconf pkgs.nautilus ];
  programs.dconf.enable = true;

  # Enable GNOME Virtual File System
  services.gvfs.enable = true;

  # XDG Desktop Portal Configuration
  # Enables screen sharing, file chooser, and GNOME Settings integration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = ["gnome" "gtk"];
      };
      # Niri-specific portal configuration - uses GNOME portals
      # This ensures screen sharing, file picker work in niri session
      # See: specs/reports/012_niri_with_gnome_integration.md
      niri = {
        default = ["gnome" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gnome"];
        "org.freedesktop.impl.portal.Screenshot" = ["gnome"];
        "org.freedesktop.impl.portal.Screencast" = ["gnome"];
        "org.freedesktop.impl.portal.Settings" = ["gnome"];
      };
    };
  };

# Configure keymap in X11
services.xserver = {
  xkb.layout = "us";
  xkb.options = "caps:swapescape,ctrl:swap_lalt_lctl";
};

  # Enable CUPS to print documents.
  # Using IPP Everywhere (driverless) - HPLIP removed as it conflicts with IPP
  services.printing = {
    enable = true;
    # drivers = with pkgs; [ hplip ];  # Removed - causes blank pages with IPP
  };

  # Enable network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

# Enable Bluetooth
hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;  # Automatically power on Bluetooth adapter at boot
};
services.blueman.enable = lib.mkIf (!config.services.desktopManager.gnome.enable) true;

  services.pulseaudio.enable = false;
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

  # Power management configuration for Ryzen AI 300
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";  # Balance performance and power saving
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.benjamin = {
    isNormalUser = true;
    description = "Benjamin";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];
  };

  # Enable uinput for ydotool (dictation feature)
  hardware.uinput.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.input-fonts.acceptLicense = true;
  
  environment.systemPackages =
    (with pkgs; [
      # GNOME Tools (useful for both GNOME and niri if re-enabled)
      gnome-control-center  # GNOME Settings GUI
      nautilus              # File manager (required by portal)

      # Wayland essentials (kept for future niri testing)
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
      # python3 is provided via python3.withPackages below (includes vosk)
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
      cvc5                 # Modern SMT solver
      opencode             # AI coding agent for terminal
      aristotle            # AI theorem prover with Lean
      lsof                 # Tool to list open files
      # u-root-cmds           

      # Lean
      # lean4              # Theorem prover and programming language
      # mathlibtools       # Removed - archived upstream in 2023
      elan                 # Version manager for Lean

      # Editors
      neovim               # Highly configurable text editor (Vim-fork)
      neovim-remote        # Tool for controlling Neovim processes
      vscodium             # Open source build of VS Code without Microsoft telemetry
      lectic               # Custom editor or tool (appears to be a local package)

      # PDF and Document Tools
      zotero               # Reference management software
      typst                # Typesetting language for generating PDFs
      texlive.combined.scheme-full  # Complete TeX Live distribution for document preparation
      texlab               # Language server for LaTeX
      kdePackages.okular   # Universal document viewer (moved from libsForQt5 in nixos-unstable)
      pdftk                # PDF toolkit for manipulating PDF documents
      pdfannots            # Extract annotations from PDF files
      xsel                 # Command-line tool for getting/setting X selection
      pstree               # Display running processes as a tree
      pandoc               # Universal document converter
      zathura              # Light-weight PDF/document viewer
      libreoffice          # RTF word processor with signature support
      evince               # GNOME document viewer (handles PDF, PS, DVI, etc.)
      tinymist             # Typst language server with bundled formatter

      # GNOME Extensions and Tools
      gnome-tweaks         # Tool to customize advanced GNOME settings
      gnomeExtensions.unite # GNOME extension to remove title bars and merge elements
      kooha                # Screen recorder (custom override with MP4 support via overlay)

      # Multimedia
      alsa-tools           # HDA codec tools (hda-verb) for audio hardware control
      vlc                  # Cross-platform multimedia player
      zoom-us              # Video conferencing tool
      spotify              # Music streaming service client
      signal-desktop       # Signal message app

      # Text-to-Speech and Speech-to-Text
      piper-tts            # Fast, local neural text-to-speech with natural voice quality
      espeak-ng            # Text-to-speech synthesizer (dependency for piper-tts)
      pulseaudio           # PulseAudio client tools (parecord for audio recording)
      # vosk is installed via home-manager Python environment

      # File Transfer and Torrent
      wget                 # Tool for retrieving files using HTTP, HTTPS, and FTP
      transmission_4-gtk   # BitTorrent client with GTK interface (v4)
      # torrential         # Removed from nixos-unstable

      # Email tools
      vdirsyncer
      khard

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
    noto-fonts-color-emoji  # Renamed from noto-fonts-emoji in nixos-unstable
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

# Enable nix-ld for running unpatched dynamic binaries (required for elan/Lean toolchains)
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    gmp
  ];
};

# ==========================================================================
# Service Timeout and Reliability Configuration
# ==========================================================================
# Reduce shutdown timeout cascade during NetworkManager deadlocks
# See: specs/reports/019_system_freeze_shutdown_analysis.md
# ==========================================================================
systemd.services = {
  # Audio Static Fix: Disable speaker amplifier (EAPD) at boot
  # This systemd service runs hda-verb to disable the speaker amplifier on the
  # Realtek ALC256 codec. This eliminates idle static/hiss from internal speakers
  # but means internal speakers will NOT work until re-enabled.
  #
  # To re-enable internal speakers temporarily:
  #   sudo hda-verb /dev/snd/hwC0D0 0x14 SET_EAPD_BTLENABLE 2
  #
  # To disable again (stop static):
  #   sudo hda-verb /dev/snd/hwC0D0 0x14 SET_EAPD_BTLENABLE 0
  #
  # Node 0x14 = Speaker pin on ALC256
  # EAPD bit 1 (value 2) = amplifier enabled, bit 0 (value 0) = disabled
  disable-speaker-amp = {
    description = "Disable internal speaker amplifier to prevent EMI static";
    wantedBy = [ "multi-user.target" "post-resume.target" ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x14 SET_EAPD_BTLENABLE 0";
    };
  };

  # NetworkManager timeout configuration
  NetworkManager = {
    serviceConfig = {
      TimeoutStopSec = "30s";  # Reduce from 2min to force faster kill on deadlock
      # Watchdog removed - was causing crashes when NM became temporarily unresponsive
      # Restart = "on-failure";  # Disabled - let systemd handle failures normally
    };
  };

  # Reduce timeout for services that wait on NetworkManager
  avahi-daemon = {
    serviceConfig = {
      TimeoutStopSec = "20s";  # Reduce from 90s
    };
  };

  geoclue = {
    serviceConfig = {
      TimeoutStopSec = "15s";  # Reduce from 90s
      # Prevent restart loop during normal operation
      Restart = "on-failure";
      RestartSec = "60s";
    };
  };

  # ==========================================================================
  # automatic-timezoned Service Restart Configuration
  # ==========================================================================
  # Problem: automatic-timezoned crashes when geoclue2 shuts down after its
  # 60-second idle timeout, causing a D-Bus disconnection error.
  #
  # Solution: Configure automatic-timezoned to restart on failure with rate
  # limiting to prevent restart loops.
  #
  # See: specs/16_troubleshoot_automatic_timezoned_geoclue2_dbus_timeout
  # ==========================================================================
  automatic-timezoned = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
    };
    # Prevent restart loop: max 10 restarts per 5 minutes
    startLimitBurst = 10;
    startLimitIntervalSec = 300;
  };

  # Geoclue agent for automatic-timezoned
  # Keep the agent running to maintain location update attempts
  automatic-timezoned-geoclue-agent = {
    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
    };
    # Prevent restart loop: max 10 restarts per 5 minutes
    startLimitBurst = 10;
    startLimitIntervalSec = 300;
  };
};

# Do not change this value after initial installation
system.stateVersion = "24.11";

}
