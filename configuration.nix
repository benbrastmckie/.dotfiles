# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, lib, pkgs, pkgs-unstable, lectic, ... }:
let
  # Discord Bot Python environment (Task 53)
  # Dedicated Python 3 environment for the Nextcord bot service
  # (nextcord: Discord library, aiohttp: local HTTP API, anyio: structured concurrency)
  discordBotPython = pkgs.python3.withPackages (p: with p; [
    nextcord
    aiohttp
    anyio
  ]);
in
{
  imports = [
    # Hardware configuration is imported in flake.nix (via mkHost)

    # System modules — split from the monolithic configuration.nix
    ./modules/system/boot.nix
    ./modules/system/networking.nix
    ./modules/system/locale.nix
    ./modules/system/desktop.nix
    ./modules/system/services.nix
    ./modules/system/audio.nix
    ./modules/system/power.nix
  ];

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

  # ==========================================================================
  # Discord Bot Prerequisites (Task 53)
  # ==========================================================================
  # sops-nix decryption: injects bot token and OpenCode password into
  # systemd services via LoadCredential (never on disk unencrypted).
  # Bot project: ~/.dotfiles/opencode-discord-bot/src/bot.py (Nextcord)
  # See: specs/053_nixos_discord_bot_prerequisites/reports/01_nixos-discord-bot-prerequisites.md
  # ==========================================================================

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/home/benjamin/.config/sops/age/keys.txt";

    secrets = {
      "discord_bot_token" = {
        owner = config.users.users.benjamin.name;
      };
      "opencode_server_password" = {
        owner = config.users.users.benjamin.name;
      };
      "discord_channel_id" = {
        owner = config.users.users.benjamin.name;
      };
      "link_api_token" = {
        owner = config.users.users.benjamin.name;
      };
      "ollama_api_key" = {
        owner = config.users.users.benjamin.name;
      };
    };
  };

  environment.systemPackages =
    (with pkgs; [
      # GNOME Tools (useful for both GNOME and niri if re-enabled)
      gnome-control-center # GNOME Settings GUI
      nautilus # File manager (required by portal)

      # Wayland essentials (kept for future niri testing)
      # wl-clipboard is managed by home-manager (home.packages)
      xdg-utils # Standard desktop integration utilities
      qt6.qtwayland # Wayland support for Qt6 applications
      qt5.qtwayland # Wayland support for Qt5 applications
      swaybg # Simple wallpaper utility for Wayland

      # Niri essential packages (for dual-session with GNOME)
      xwayland-satellite # X11 compatibility layer for Niri (auto-detected since 25.08)
      fuzzel # Lightweight application launcher for Wayland
      wdisplays # GUI monitor configuration tool for wlr-output-management

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
      kitty # GPU-accelerated terminal emulator
      tmux # Terminal multiplexer for managing multiple terminal sessions
      fish # User-friendly command line shell
      oh-my-fish # Framework to manage fish shell configuration
      zoxide # Smarter cd command with learning capabilities
      ghostty # Modern terminal emulator with GPU acceleration
      libsecret # Tool for managing secrets (provides secret-tool command)

      # Browsers & Communication
      vivaldi # Feature-rich web browser with built-in tools
      brave # Privacy-focused web browser based on Chromium
      discord # Voice, video, and text chat platform

      # Appearance
      fastfetch # Command-line system information tool with ASCII art
      disfetch # Minimal system information display tool

      # Development Tools
      git # Distributed version control system
      # python3 is provided via python3.withPackages below (includes vosk)
      go # Go programming language
      gcc # GNU Compiler Collection for C/C++
      unzip # Extract files from ZIP archives
      gnumake # Build automation tool
      nodejs_22 # JavaScript runtime environment
      uv # Fast Python package installer and resolver
      bun # Fast all-in-one JavaScript runtime
      pnpm_9 # Fast, disk space efficient package manager
      wrangler # Cloudflare Workers CLI for serverless deployment
      sqlite # SQL database engine library and CLI
      fd # Simple, fast alternative to 'find'
      ripgrep # Fast line-oriented search tool (alternative to grep)
      fzf # Command-line fuzzy finder
      lazygit # Terminal UI for git commands
      tree-sitter # Parsing library for code highlighting and navigation
      lua-language-server # Language server for Lua development
      # stylua is managed by home-manager (home.packages)
      tree # Display directory structure in a tree-like format
      # cvc5 is managed by home-manager (python environment via overlay)
      opencode # AI coding agent for terminal
      aristotle # AI theorem prover with Lean
      lsof # Tool to list open files
      # u-root-cmds
      git-filter-repo # For deleting elements from git history
      rclone # Command-line cloud storage sync and management tool
      sox # Audio processing and playback (play, rec, sox)
      cloc # Tools to check the size of a repo
      # R environment with all packages composed via wrapper
      # (flat rPackages.* entries don't expose packages to R's library path)
      # Sourced from pkgs-unstable: stable nixpkgs-26.05 ships a broken r-V8
      # (8.0.1 expects ICU 78 but stable provides 76.1, with no standalone v8
      # package to bridge it), which fails to link and breaks gt -> gtsummary.
      # Unstable's r-V8 8.2.0 is version-matched and builds cleanly. See task 61.
      (pkgs-unstable.rWrapper.override {
        packages = with pkgs-unstable.rPackages; [
          # P0: Core statistical packages
          survival
          MASS
          nlme
          lme4
          # P1: Analysis packages
          tidyverse
          broom
          gtsummary
          mice
          knitr
          rmarkdown
          # P2: Tooling (LSP, formatter, linter)
          languageserver
          styler
          lintr
        ];
      })
      ruff # Python linter/formatter

      # Lean
      # lean4              # Theorem prover and programming language
      # mathlibtools       # Removed - archived upstream in 2023
      elan # Version manager for Lean

      # Editors
      obsidian # Markdown-based knowledge base and note-taking app
      # neovim is managed by home-manager (programs.neovim.enable)
      zed-editor # Modern code editor with GPU-accelerated rendering
      neovim-remote # Tool for controlling Neovim processes
      vscodium # Open source build of VS Code without Microsoft telemetry
      # lectic is managed by home-manager (home.packages)

      # PDF and Document Tools
      zotero # Reference management software
      typst # Typesetting language for generating PDFs
      texlive.combined.scheme-full # Complete TeX Live distribution for document preparation
      texlab # Language server for LaTeX
      kdePackages.okular # Universal document viewer (moved from libsForQt5 in nixos-unstable)
      pdftk # PDF toolkit for manipulating PDF documents
      pdfannots # Extract annotations from PDF files
      xsel # Command-line tool for getting/setting X selection
      pstree # Display running processes as a tree
      pandoc # Universal document converter
      quarto # Scientific and technical publishing system
      zathura # Light-weight PDF/document viewer
      libreoffice # RTF word processor with signature support
      evince # GNOME document viewer (handles PDF, PS, DVI, etc.)
      tinymist # Typst language server with bundled formatter
      svg-text-to-path # Convert SVG text elements to paths

      # GNOME Extensions and Tools
      gnome-tweaks # Tool to customize advanced GNOME settings
      gnomeExtensions.unite # GNOME extension to remove title bars and merge elements
      kooha # Screen recorder (custom override with MP4 support via overlay)

      # Multimedia
      alsa-tools # HDA codec tools (hda-verb) for audio hardware control
      webcamoid # Full-featured webcam recording suite
      vlc # Cross-platform multimedia player
      zoom-us # Video conferencing tool
      spotify # Music streaming service client
      signal-desktop # Signal message app
      ffmpeg

      # Text-to-Speech and Speech-to-Text
      picotts # SVOX Pico text-to-speech engine (pico2wave command)
      pulseaudio # PulseAudio client tools (parecord for audio recording)
      # vosk is installed via home-manager Python environment

      # File Transfer and Torrent
      wget # Tool for retrieving files using HTTP, HTTPS, and FTP
      transmission_4-gtk # BitTorrent client with GTK interface (v4)
      # torrential         # Removed from nixos-unstable

      # Email tools
      vdirsyncer
      khard

      # Input Tools
      qmk # Quantum Mechanical Keyboard firmware utilities
      via # Keyboard configuration tool for QMK-powered keyboards

      # Miscellaneous
      xdotool # Command-line X11 automation tool
      xwayland # X server for running X11 applications on Wayland

      # DNS & Network Tools
      bind # DNS tools (dig, nslookup, host)
      dnsutils # Additional DNS utilities
      whois # Domain registration lookup
      traceroute # Network path diagnosis
      mtr # Better traceroute (combines ping + traceroute)

      # SSL/TLS Tools
      openssl # SSL/TLS toolkit and cryptography library
      mkcert # Local SSL certificates for development

      # NixOS
      home-manager # Tool for managing user configuration
      nix-index # Utility for indexing Nix store files

      # Discord Bot Prerequisites (Task 53)
      sops # Secrets encryption/decryption (3.12.2)
      age # Encryption backend for sops (age 1.3.1)



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

      # Discord bot link token for Neovim integration (read from sops-nix secret)
      if test -r /run/secrets/link_api_token
        set -gx DISCORD_BOT_LINK_TOKEN (cat /run/secrets/link_api_token)
      end
    '';
  };

  # Font configuration
  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji # Renamed from noto-fonts-emoji in nixos-unstable
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
      auto-optimise-store = true; # Optimize the Nix store automatically
      # Resource limits to prevent OOM on heavy C++ builds (24-core / 30GB box).
      # max-jobs * cores caps concurrent compile units at 12, within the ~26GB
      # build budget (~2GB/unit for onnxruntime-class packages). See task 60.
      max-jobs = 2;
      cores = 6;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Enable nix-ld for running unpatched dynamic binaries
  # (required for elan/Lean toolchains, Playwright/Chromium, and other foreign binaries)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Core C/C++ runtime
      stdenv.cc.cc.lib
      zlib
      gmp
      # Chromium/Playwright dependencies
      glib
      nss
      nspr
      atk
      at-spi2-atk
      cups
      dbus
      libdrm
      gtk3
      pango
      cairo
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libgbm
      expat
      alsa-lib
      libxkbcommon
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
        TimeoutStopSec = "30s"; # Reduce from 2min to force faster kill on deadlock
        # Watchdog removed - was causing crashes when NM became temporarily unresponsive
        # Restart = "on-failure";  # Disabled - let systemd handle failures normally
      };
    };

    # Reduce timeout for services that wait on NetworkManager
    avahi-daemon = {
      serviceConfig = {
        TimeoutStopSec = "20s"; # Reduce from 90s
      };
    };

    geoclue = {
      serviceConfig = {
        TimeoutStopSec = "15s"; # Reduce from 90s
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

    # ==========================================================================
    # Discord Bot Infrastructure Services (Task 53)
    # ==========================================================================
    # opencode-serve: headless OpenCode agent server binding to localhost.
    # Server password is injected from sops-nix via systemd LoadCredential.
    # ==========================================================================
    opencode-serve = {
      description = "OpenCode headless agent server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'OPENCODE_SERVER_PASSWORD=$(cat %d/opencode_server_password) OLLAMA_API_KEY=$(cat %d/ollama_api_key) exec ${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port 4096'";
        Restart = "always";
        RestartSec = "10s";
        LoadCredential = [
          "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
          "ollama_api_key:${config.sops.secrets."ollama_api_key".path}"
        ];
        # Working directory where .opencode/ config lives
        WorkingDirectory = "/home/benjamin/.dotfiles";
        User = config.users.users.benjamin.name;
        Group = "users";
      };
    };

    # ==========================================================================
    # discord-bot: Nextcord Discord bot relay for OpenCode agent management.
    # Depends on opencode-serve. Uses dedicated discordBotPython environment.
    # PYTHONPATH points to bot project at ~/.dotfiles/opencode-discord-bot/.
    # ==========================================================================
    discord-bot = {
      description = "Discord bot relay for OpenCode agent management";
      after = [ "network-online.target" "opencode-serve.service" ];
      wants = [ "network-online.target" "opencode-serve.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        ExecStart = "${discordBotPython}/bin/python -m opencode_discord_bot.src.bot";
        WatchdogSec = "120s";
        Restart = "always";
        RestartSec = "10s";
        LoadCredential = [
          "discord_bot_token:${config.sops.secrets."discord_bot_token".path}"
          "opencode_server_password:${config.sops.secrets."opencode_server_password".path}"
          "discord_channel_id:${config.sops.secrets."discord_channel_id".path}"
          "link_api_token:${config.sops.secrets."link_api_token".path}"
        ];
        Environment = [
          "DISCORD_BOT_TOKEN=%d/discord_bot_token"
          "OPENCODE_SERVER_PASSWORD=%d/opencode_server_password"
          "OPENCODE_SERVER_URL=http://127.0.0.1:4096"
          "DISCORD_CHANNEL_ID=%d/discord_channel_id"
          "WHITELISTED_USER_IDS="
          "LINK_API_TOKEN=%d/link_api_token"
          "LOG_LEVEL=info"
          "PYTHONPATH=/home/benjamin/.dotfiles/opencode-discord-bot"
        ];
        WorkingDirectory = "/home/benjamin/.dotfiles";
        User = config.users.users.benjamin.name;
        Group = "users";
      };
    };
  };

  # Do not change this value after initial installation
  system.stateVersion = "24.11";

}
