# System-wide packages (environment.systemPackages).
# Packages owned by home-manager are documented inline with ownership comments.
{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
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
    brightnessctl # Laptop backlight control (XF86MonBrightness keys in niri; uses logind SetBrightness, no udev/video-group needed)

    # # For use with Niri without Gnome utilities
    # (mako, waybar, kanshi, swaylock are now configured as home-manager modules —
    #  see modules/home/desktop/{mako,waybar,kanshi,swaylock}.nix — removed from this list)
    # grim                 # Screenshot utility for Wayland
    # slurp                # Area selection tool for Wayland screenshots
    # swayidle             # Idle management daemon for Wayland
    # network-manager-applet  # GUI for NetworkManager connections
    # blueman              # Bluetooth management utility
    # wl-clipboard-x11     # X11 clipboard compatibility for Wayland
    # clipman              # Clipboard manager for Wayland

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
    sioyek # PDF viewer with focus on academic paper reading (custom Wayland CSD wrapper via overlay)
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
    piper # Fast, local neural text-to-speech with natural voice quality (prebuilt binary, no onnxruntime compile)
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

    # Polkit authentication agent for the niri session (GNOME session uses gnome-shell's own).
    # Custom wrapper (overlay) exposes the libexec binary on PATH under its conventional bin name.
    polkit-gnome-authentication-agent-1
  ];
}
