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

  # ==========================================================================
  # Framework 13 AMD AI 300 - Phantom Audio Interface Fix
  # ==========================================================================
  # The Framework BIOS incorrectly reports the ACP device as a wired audio
  # device. This causes snd_acp70 and snd_acp_pci to load and create phantom
  # UCM audio interfaces that can cause hardware polling and IRQ noise.
  # Blacklisting matches the nixos-hardware framework-amd-ai-300-series module.
  # See: https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/amd-ai-300-series
  # ==========================================================================
  boot.blacklistedKernelModules = [ "snd_acp70" "snd_acp_pci" ];

  # Kernel parameters for Ryzen AI 300 suspend/resume and deadlock detection
  boot.kernelParams = [
    "amd_pstate=active"           # Enable AMD P-state driver for better power management
    "amdgpu.dcdebugmask=0x10"     # Disable problematic GPU features during suspend
    "rtc_cmos.use_acpi_alarm=1"   # Better ACPI wake support
    "hung_task_timeout_secs=60"   # Detect deadlocks faster (default: 120s)
  ];

  # Audio and WiFi kernel module options
  # snd_hda_intel power_save=1: allow codec to idle after 1s of silence.
  #   Previously set to 0, but the EAPD speaker-amp is already disabled by the
  #   disable-speaker-amp service, so clicks from power-state transitions won't
  #   come through internal speakers. Enabling saves meaningful battery.
  # battery cache_time=10000: poll battery hardware every 10s (default ~1s).
  #   At 1s the kernel fires power_supply change events ~60/min, keeping udevd
  #   and journald busy. 10s gives accurate-enough readings while cutting
  #   that wakeup rate by 10x.
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1 power_save_controller=N
    options mt7925e disable_aspm=1 power_save=0
    options battery cache_time=10000
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
  # Enable WiFi-based location detection (uses BeaconDB)
  enableWifi = lib.mkForce true;
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

# California default with forced priority to ensure /etc/localtime always exists
# Problem: automatic-timezoned sets time.timeZone = null (priority ~1000), which
# overrides lib.mkDefault (~1500) and causes NixOS to not create /etc/localtime.
# Applications like leanls fail with "no such file or directory: /etc/localtime".
# Solution: lib.mkForce (~50) ensures the symlink always exists at boot, while
# automatic-timezoned can still update the timezone via timedatectl when geolocation works.
time.timeZone = lib.mkForce "America/Los_Angeles";

# Enable automatic timezone detection (will override the default above)
services.automatic-timezoned.enable = true;

  # QMK keyboard support - creates plugdev group, adds udev rules
  # Using the NixOS QMK module instead of manual udev packages to avoid
  # "Failed to resolve group 'plugdev'" spam from systemd-udevd (every 3-4s).
  # That spam was keeping journald at 4-5% CPU and preventing CPU idle states.
  hardware.keyboard.qmk.enable = true;

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

    # Disable tracker services to reduce background CPU load
    # localsearch (formerly tracker-miner) indexes files for GNOME search
    # tinysparql (formerly tracker) provides the database backend
    # These cause CPU spikes during file indexing
    # See: specs/40_investigate_laptop_high_fan_optimize_system
    localsearch.enable = false;
    tinysparql.enable = false;
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
  # cpuFreqGovernor removed - power-profiles-daemon manages governor dynamically
  # Setting both causes a conflict where PPD's powersave is overridden on boot
  powerManagement = {
    enable = true;
  };

  # Power profiles daemon for Waybar integration and system-wide power management
  services.power-profiles-daemon.enable = true;

  # ==========================================================================
  # Automatic Power Profile Switching - AC vs Battery
  # ==========================================================================
  # The HX 370 at "balanced" platform profile can draw 45W+ and runs the fan
  # continuously. Switching to "low-power" on battery: reduces CPU TDP, limits
  # boost, and significantly quiets the fan (GPU+CPU both power-gate more).
  #
  # Implementation: udev rules write directly to the ACPI platform_profile sysfs
  # node on AC state change. We do NOT call powerprofilesctl because udev rules
  # run outside the D-Bus session. PPD will not override these sysfs writes.
  #
  # The GPU DPM performance level is also set per ArchWiki Framework 13 guidance:
  # https://wiki.archlinux.org/title/Framework_Laptop_13
  # ==========================================================================
  services.udev.extraRules = lib.mkAfter ''
    # On battery: low-power platform profile + GPU low performance level
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="${pkgs.bash}/bin/bash -c 'echo low-power > /sys/firmware/acpi/platform_profile'"
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="${pkgs.bash}/bin/bash -c 'echo low > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level'"
    # On AC: balanced platform profile + GPU auto performance level
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="${pkgs.bash}/bin/bash -c 'echo balanced > /sys/firmware/acpi/platform_profile'"
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="${pkgs.bash}/bin/bash -c 'echo auto > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level'"
  '';

  # Apply the correct profile at boot based on current AC state
  systemd.services.init-power-profile = {
    description = "Set initial power profile based on AC state";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'if [ \"$(cat /sys/class/power_supply/ACAD/online)\" = \"1\" ]; then echo balanced > /sys/firmware/acpi/platform_profile; echo auto > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level; else echo low-power > /sys/firmware/acpi/platform_profile; echo low > /sys/bus/pci/devices/0000:c1:00.0/power_dpm_force_performance_level; fi'";
    };
  };

  # Firmware updates via fwupd - recommended for Framework laptops.
  # BIOS >= 3.05 is required to fix standby power drain (Framework community).
  # Run: fwupdmgr refresh && fwupdmgr update
  services.fwupd.enable = true;

  # ==========================================================================
  # Memory Management - earlyoom for OOM Prevention
  # ==========================================================================
  # earlyoom monitors memory usage and kills processes before the system
  # becomes unresponsive due to memory exhaustion. It operates in userspace
  # before the kernel OOM killer, providing faster and more controllable
  # intervention.
  #
  # See: specs/26_memory_monitoring_systemd_services_nixos
  # ==========================================================================
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10;         # Kill process when free RAM drops below 10%
    freeSwapThreshold = 10;        # Also consider swap usage
    enableNotifications = true;    # Send desktop notifications when process is killed
    extraArgs = [
      "--avoid" "^(gnome-shell|Xwayland|niri)$"   # Avoid killing desktop essentials
      "--prefer" "^(lean|lake|claude|node|npm)$"  # Prefer killing memory-heavy processes first
    ];
  };

  # ==========================================================================
  # Swap Configuration - Memory Safety Buffer
  # ==========================================================================
  # Three-tier memory management:
  # 1. Normal operation: Applications use RAM freely
  # 2. Memory pressure: Kernel moves inactive pages to swap
  # 3. Critical: earlyoom terminates memory-hungry processes at 10% free
  #
  # 16GB swap provides buffer before earlyoom intervention, especially useful
  # for memory spikes from development tools (Claude, Node.js, browsers).
  #
  # Note: For hibernation support, swap must be >= RAM size (32GB+).
  # Current configuration is for memory safety only, not hibernation.
  #
  # See: specs/25_configure_swap_space_nixos
  # ==========================================================================
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 16 * 1024;  # 16GB in MiB
    discardPolicy = "once";  # TRIM on activation for SSD optimization
  }];

  # ==========================================================================
  # zram Compressed Swap - Fast In-Memory Swap
  # ==========================================================================
  # zram provides compressed swap in RAM, which is faster than disk swap.
  # Priority 5 ensures zram is used before the swapfile (priority -2).
  # The zstd algorithm offers best compression/speed ratio.
  #
  # Swap hierarchy:
  # 1. zram (priority 5) - Fast, compressed RAM swap
  # 2. swapfile (priority -2) - Disk-based fallback
  #
  # See: specs/39_analyze_memory_logs_optimize_system
  # ==========================================================================
  zramSwap = {
    enable = true;
    algorithm = "zstd";       # Best compression/speed ratio
    memoryPercent = 50;       # Use up to 50% of RAM (16GB of 32GB)
    priority = 5;             # Higher than swapfile (-2)
  };

  # ==========================================================================
  # VM Parameters - Desktop Memory Optimization
  # ==========================================================================
  # Tuned for desktop responsiveness with zram swap:
  # - Lower swappiness: Keep more in RAM, desktop feels snappier
  # - Watermark tuning: Better memory reclaim behavior
  # - Disable page-cluster: zram doesn't benefit from readahead
  #
  # See: specs/39_analyze_memory_logs_optimize_system
  # ==========================================================================
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;                 # Prefer RAM over swap (default: 60)
    "vm.watermark_boost_factor" = 0;      # Disable watermark boosting
    "vm.watermark_scale_factor" = 125;    # Better memory reclaim (default: 10)
    "vm.page-cluster" = 0;                # Disable readahead for zram (default: 3)
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

      # Niri essential packages (for dual-session with GNOME)
      xwayland-satellite   # X11 compatibility layer for Niri (auto-detected since 25.08)
      fuzzel               # Lightweight application launcher for Wayland
      wdisplays            # GUI monitor configuration tool for wlr-output-management

      # # For use with Niri without Gnome utilities
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
      fastfetch            # Command-line system information tool with ASCII art
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
      pnpm_9               # Fast, disk space efficient package manager
      wrangler             # Cloudflare Workers CLI for serverless deployment
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
      git-filter-repo      # For deleting elements from git history

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
      svg-text-to-path     # Convert SVG text elements to paths

      # GNOME Extensions and Tools
      gnome-tweaks         # Tool to customize advanced GNOME settings
      gnomeExtensions.unite # GNOME extension to remove title bars and merge elements
      kooha                # Screen recorder (custom override with MP4 support via overlay)

      # Multimedia
      alsa-tools           # HDA codec tools (hda-verb) for audio hardware control
      webcamoid            # Full-featured webcam recording suite
      vlc                  # Cross-platform multimedia player
      zoom-us              # Video conferencing tool
      spotify              # Music streaming service client
      signal-desktop       # Signal message app
      ffmpeg

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

      # DNS & Network Tools
      bind                 # DNS tools (dig, nslookup, host)
      dnsutils             # Additional DNS utilities
      whois                # Domain registration lookup
      traceroute           # Network path diagnosis
      mtr                  # Better traceroute (combines ping + traceroute)

      # SSL/TLS Tools
      # openssl is already available system-wide
      mkcert               # Local SSL certificates for development

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

      # Custom sioyek (disable Qt client-side decorations on Wayland)
      # Note: GNOME 49 ignores _MOTIF_WM_HINTS for XWayland windows, so forcing
      # X11 (QT_QPA_PLATFORM=xcb) no longer works. Instead, run as native Wayland
      # and tell Qt not to render CSD - GNOME doesn't add server-side decorations
      # to Wayland apps, resulting in a clean decoration-free window.
      (writeShellScriptBin "sioyek" ''
        #!/bin/sh
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
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
# Memory Management - Disable systemd-oomd (earlyoom preferred)
# ==========================================================================
# systemd-oomd conflicts with earlyoom. earlyoom is more configurable and
# provides desktop notifications. Disabling systemd-oomd to avoid dual OOM
# killer confusion.
#
# See: specs/39_analyze_memory_logs_optimize_system
# ==========================================================================
systemd.oomd.enable = false;

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

  # Note: automatic-timezoned-geoclue-agent already has Restart = "on-failure"
  # defined by the NixOS module, which is sufficient for handling D-Bus
  # disconnections when geoclue2 shuts down. No override needed.
};

# Do not change this value after initial installation
system.stateVersion = "24.11";

}
