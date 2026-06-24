{ config, pkgs, pkgs-unstable, lectic, ... }:

{
  # Import our custom modules
  imports = [
    # ./home-modules/mcp-hub.nix  # Disabled - using lazy.nvim approach

    # Core modules
    ./modules/home/core/git.nix
    ./modules/home/core/neovim.nix
    ./modules/home/core/shell.nix
    ./modules/home/core/xdg.nix

    # Desktop modules
    ./modules/home/desktop/gnome.nix
    ./modules/home/desktop/waybar.nix
    ./modules/home/desktop/mako.nix
    ./modules/home/desktop/kanshi.nix
    ./modules/home/desktop/swaylock.nix

    # Email modules
    ./modules/home/email/mbsync.nix
    ./modules/home/email/protonmail.nix
    ./modules/home/email/notmuch.nix
    ./modules/home/email/aerc.nix
  ];

  # Note: Python packages overlay (including cvc5) is defined in flake.nix

  home.username = "benjamin";
  home.homeDirectory = "/home/benjamin";

  # Fish shell configuration is managed through home.file below
  # OMF has been removed - fish greeting disabled in config.fish

  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.

  # home.packages allows you to install Nix packages into your environment.
  home.packages = with pkgs; [
    claude-code # Using overlaid unstable package
    claude-squad # Terminal app for managing multiple AI agents
    gemini-cli # Google Gemini AI CLI tool
    gh # GitHub CLI (required by claude-squad)
    lectic # Formal logic and proof tool
    loogle # Lean 4 Mathlib search tool (wrapper script)
    stylua # Lua formatter for Neovim
    wezterm # GPU-accelerated terminal emulator
    zulip-term # Terminal UI client for Zulip chat
    espeak-ng # Text-to-speech for notifications
    slidev # Presentation slides from Markdown (sli.dev)
    # sioyek is installed via configuration.nix (Wayland wrapper, CSD disabled)

    # GNOME Shell Extensions
    gnomeExtensions.activate-window-by-title # For cross-window WezTerm tab navigation

    # Sioyek theme toggle script - toggles between Gruvbox (light) and Nord (dark)
    (pkgs.writeShellScriptBin "sioyek-theme-toggle" ''
      STATE_FILE="$HOME/.cache/sioyek-theme-state"
      mkdir -p "$(dirname "$STATE_FILE")"

      # Default to gruvbox if state file doesn't exist
      if [ ! -f "$STATE_FILE" ]; then
        echo "gruvbox" > "$STATE_FILE"
      fi

      CURRENT_THEME=$(cat "$STATE_FILE")

      if [ "$CURRENT_THEME" = "gruvbox" ]; then
        # Switch to Nord
        sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.180 0.204 0.251"
        sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.847 0.871 0.914"
        echo "nord" > "$STATE_FILE"
      else
        # Switch to Gruvbox
        sioyek --execute-command setconfig_custom_background_color --execute-command-data "0.922 0.859 0.698"
        sioyek --execute-command setconfig_custom_text_color --execute-command-data "0.235 0.220 0.212"
        echo "gruvbox" > "$STATE_FILE"
      fi
    '')

    # Web Development & API Tools
    httpie # User-friendly HTTP client (better than curl for APIs)
    fx # Interactive JSON viewer

    # Git Enhancement Tools
    glab # GitLab CLI
    delta # Better git diff viewer

    # System Monitoring
    btop # Modern, beautiful system monitor
    htop # Interactive process viewer
    bandwhich # Network bandwidth monitor

    # Documentation Tools
    vale # Prose linting for documentation
    marksman # Markdown language server (LSP)
    mdl # Markdown linter
    prettier # Code formatter (JS/TS/JSON/MD/YAML/CSS)

    # Image Optimization
    imagemagick # Image manipulation
    optipng # PNG optimizer
    jpegoptim # JPEG optimizer

    # Email Testing Tools
    swaks # Swiss Army Knife for SMTP testing
    mailutils # Email utilities
    # protonmail-bridge is now managed by services.protonmail-bridge

    # Video recording/editing
    obs-studio
    # Dictation tools
    whisper-cpp # Fast offline speech-to-text (renamed from openai-whisper-cpp)
    ydotool # Universal input tool (works with GNOME/Wayland)
    libnotify # Desktop notifications

    # Screenshot and annotation tools (for Niri)
    satty # Screenshot annotation tool
    grim # Wayland screenshot utility
    slurp # Region selection tool for Wayland
    inotify-tools # Filesystem event monitoring (used by screenshot-path-copy service)

    # OAuth2 token refresh script
    (pkgs.writeShellScriptBin "refresh-gmail-oauth2" ''
      #!/bin/bash

      # Check if refresh token exists
      if ! secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-refresh-token >/dev/null 2>&1; then
        echo "No refresh token found. Please run: himalaya account configure gmail"
        exit 1
      fi

      # Get current tokens
      CLIENT_ID="$GMAIL_CLIENT_ID"
      CLIENT_SECRET=$(secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-client-secret 2>/dev/null)
      REFRESH_TOKEN=$(secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-refresh-token 2>/dev/null)

      if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ] || [ -z "$REFRESH_TOKEN" ]; then
        echo "Missing OAuth2 credentials. Please reconfigure: himalaya account configure gmail"
        exit 1
      fi

      # Refresh the access token
      RESPONSE=$(curl -s -X POST https://www.googleapis.com/oauth2/v4/token \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$CLIENT_ID" \
        -d "client_secret=$CLIENT_SECRET" \
        -d "refresh_token=$REFRESH_TOKEN" \
        -d "grant_type=refresh_token")

      # Parse the new access token
      NEW_ACCESS_TOKEN=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.access_token // empty')

      if [ -n "$NEW_ACCESS_TOKEN" ] && [ "$NEW_ACCESS_TOKEN" != "null" ]; then
        # Store the new access token
        echo "$NEW_ACCESS_TOKEN" | secret-tool store --label="Gmail OAuth2 Access Token (auto-refreshed)" \
          service himalaya-cli username gmail-smtp-oauth2-access-token
        echo "OAuth2 access token refreshed successfully"

        # Also update refresh token if provided
        NEW_REFRESH_TOKEN=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.refresh_token // empty')
        if [ -n "$NEW_REFRESH_TOKEN" ] && [ "$NEW_REFRESH_TOKEN" != "null" ]; then
          echo "$NEW_REFRESH_TOKEN" | secret-tool store --label="Gmail OAuth2 Refresh Token (auto-refreshed)" \
            service himalaya-cli username gmail-smtp-oauth2-refresh-token
          echo "OAuth2 refresh token updated"
        fi

        exit 0
      else
        echo "Failed to refresh OAuth2 token. Response: $RESPONSE"
        echo "You may need to re-authenticate: himalaya account configure gmail"
        exit 1
      fi
    '')

    # Himalaya email client with full feature set
    (pkgs-unstable.himalaya.overrideAttrs (oldAttrs: {
      cargoBuildFlags = (oldAttrs.cargoBuildFlags or [ ]) ++ [ "--features=oauth2,keyring" ];
    })) # Himalaya with OAuth2 support

    # Custom cyrus-sasl with XOAUTH2 plugin built-in and mbsync with proper linking
    (let
      cyrus-sasl-with-xoauth2 = pkgs.cyrus_sasl.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [ pkgs.cyrus-sasl-xoauth2 ];
        postInstall = (oldAttrs.postInstall or "") + ''
          # Copy XOAUTH2 plugin to the main SASL plugin directory
          cp ${pkgs.cyrus-sasl-xoauth2}/lib/sasl2/* $out/lib/sasl2/
        '';
      });

      mbsync-with-xoauth2 = pkgs-unstable.isync.override {
        cyrus_sasl = cyrus-sasl-with-xoauth2;
      };
    in mbsync-with-xoauth2)

    pkgs.cyrus-sasl-xoauth2 # Keep for reference
    msmtp # For sending emails via SMTP
    pass # Password manager for storing OAuth2 tokens
    gnupg # Required for pass to work
    w3m # Terminal web browser for viewing HTML emails
    curl # For OAuth2 token refresh
    jq # For parsing JSON responses
    # Note: libsecret is already installed system-wide in configuration.nix
    # Required for running mcp-hub JavaScript tools
    # MCP-Hub is now managed by the home module
    nodejs # Required runtime dependency
    (python3.withPackages (p: (with p; [
      zulip # Zulip API client and zulip-send CLI
      z3-solver # Renamed from z3 in nixos-unstable
      setuptools
      pyinstrument
      build
      cvc5
      twine
      pytest
      pytest-cov
      pytest-timeout
      # model-checker  # don't install when in development
      tqdm
      pip
      pylatexenc
      pyyaml
      requests
      markdown
      jupyter
      jupyter-core
      notebook
      ipywidgets
      matplotlib
      networkx
      pynvim
      numpy
      pandas
      datasets
      huggingface-hub
      torch # PyTorch for machine learning and AI
      moviepy

      # Scientific computing stack (added for R/Quarto interop)
      scipy
      statsmodels
      seaborn
      pyarrow
      # pylint
      # black
      # isort

      # Jupyter Notebooks
      # jupytext               # DISABLED: 1.18.1 has 2 failing tests (async/sync ContentsManager mismatch). Re-enable once fixed upstream.
      ipython
      google-generativeai # Google Gemini API client (pip: google-genai)
      # pymupdf4llm          # LLM-optimized PDF extraction (custom package) - TEMPORARILY DISABLED: requires PyMuPDF 1.26.6, nixpkgs has 1.24.10
      # pdf2docx           # Convert PDF to DOCX - DISABLED: pulls python-docx 1.2.0 -> behave -> cucumber-expressions 18.1.0 -> uv_build<0.10.0 (nixpkgs has 0.10.0). Re-enable once fixed upstream.
      python-docx # Create/modify Word documents
      vosk # Offline speech recognition (custom package)
      pymupdf # PDF manipulation library
      # markitdown removed - depends on magika->onnxruntime; use: nix shell nixpkgs#python3Packages.markitdown
    ]) ++ [
      p.scikit-learn # Machine learning (hyphen requires dotted form outside with block)
    ]))

    # Clipboard history manager (for niri session)
    wl-clipboard
    cliphist

    nerd-fonts.roboto-mono # Nerd Fonts with Roboto Mono (nixos-unstable uses new nerd-fonts structure)
    jetbrains-mono

    # Whisper dictation script for Wayland
    (pkgs.writeShellScriptBin "whisper-dictate" ''
      #!/usr/bin/env bash

      # Configuration
      MODEL_SIZE="''${WHISPER_MODEL_SIZE:-base}"  # tiny, base, small, medium, large
      TEMP_DIR="/tmp/whisper-dictation"
      AUDIO_FILE="$TEMP_DIR/recording.wav"
      TEXT_FILE="$TEMP_DIR/transcription.txt"
      LOCK_FILE="$TEMP_DIR/dictation.lock"

      mkdir -p "$TEMP_DIR"

      # Check if already running (toggle functionality)
      if [ -f "$LOCK_FILE" ]; then
        # Stop recording
        pkill -f "pw-record.*$AUDIO_FILE"
        rm -f "$LOCK_FILE"

        # Send notification
        ${pkgs.libnotify}/bin/notify-send "Dictation" "Processing..." -t 2000 -i audio-input-microphone

        # Wait a moment for file to finalize
        sleep 0.5

        # Transcribe with whisper.cpp
        if [ -f "$AUDIO_FILE" ]; then
          ${pkgs.whisper-cpp}/bin/whisper-cpp \
            -m ~/.local/share/whisper/ggml-''${MODEL_SIZE}.bin \
            -f "$AUDIO_FILE" \
            -otxt -of "$TEMP_DIR/transcription" \
            --no-timestamps 2>/dev/null

          # Extract text and type it
          if [ -f "$TEXT_FILE" ]; then
            # Remove leading/trailing whitespace
            TEXT=$(cat "$TEXT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ -n "$TEXT" ]; then
              # Small delay to ensure window focus is stable
              sleep 0.2

              # Type the text using ydotool (works on both Wayland and X11)
              ${pkgs.ydotool}/bin/ydotool type "$TEXT"

              TYPE_EXIT=$?
              if [ $TYPE_EXIT -eq 0 ]; then
                ${pkgs.libnotify}/bin/notify-send "Dictation" "Typed: $TEXT" -t 3000 -i edit-paste
              else
                ${pkgs.libnotify}/bin/notify-send "Dictation Error" "Failed to type text. Make sure ydotoold service is running." -t 5000 -i dialog-error
              fi
            else
              ${pkgs.libnotify}/bin/notify-send "Dictation" "No speech detected" -t 3000 -i dialog-warning
            fi
          fi

          # Cleanup
          rm -f "$AUDIO_FILE" "$TEXT_FILE"
        fi
      else
        # Start recording
        touch "$LOCK_FILE"
        ${pkgs.libnotify}/bin/notify-send "Dictation" "Recording... (press again to stop)" -t 2000 -i audio-input-microphone

        # Record audio (using PipeWire)
        ${pkgs.pipewire}/bin/pw-record --format=s16 --rate=16000 --channels=1 "$AUDIO_FILE" &
      fi
    '')

    # Model downloader script
    (pkgs.writeShellScriptBin "whisper-download-models" ''
      #!/usr/bin/env bash

      MODEL_DIR="$HOME/.local/share/whisper"
      mkdir -p "$MODEL_DIR"

      echo "Downloading Whisper models to $MODEL_DIR"
      echo "Available sizes: tiny (~75MB), base (~150MB), small (~500MB), medium (~1.5GB)"
      echo ""

      # Default to base model
      MODEL="''${1:-base}"

      if [ ! -f "$MODEL_DIR/ggml-$MODEL.bin" ]; then
        echo "Downloading $MODEL model..."
        ${pkgs.wget}/bin/wget -P "$MODEL_DIR" \
          "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL.bin"
        echo "Downloaded $MODEL model successfully!"
      else
        echo "$MODEL model already exists at $MODEL_DIR/ggml-$MODEL.bin"
      fi
    '')

    # ==========================================================================
    # Memory Monitoring Scripts
    # ==========================================================================
    # Continuous memory monitoring with threshold-based desktop alerts.
    # Part of the three-tier memory monitoring system:
    #   Tier 1: earlyoom (system-level OOM prevention in configuration.nix)
    #   Tier 2: memory-monitor (user-level logging and alerts)
    #   Tier 3: claude-memory-tracker (process-specific tracking)
    #
    # See: specs/26_memory_monitoring_systemd_services_nixos
    # ==========================================================================

    # Memory monitor script - logs memory usage and sends desktop notifications
    (pkgs.writeShellScriptBin "memory-monitor" ''
      #!/usr/bin/env bash

      # Configuration
      LOG_DIR="$HOME/.local/share/memory-monitor"
      LOG_FILE="$LOG_DIR/system.log"
      COOLDOWN_FILE="$LOG_DIR/.cooldown"
      WARNING_THRESHOLD=80    # Percentage - send warning notification
      CRITICAL_THRESHOLD=90   # Percentage - send critical notification
      CHECK_INTERVAL=30       # Seconds between checks
      COOLDOWN_PERIOD=300     # Seconds between notifications (5 minutes)
      MAX_LOG_SIZE=10485760   # 10MB - rotate log when exceeded

      # Create log directory
      mkdir -p "$LOG_DIR"

      # Function to get memory usage percentage
      get_memory_usage() {
        ${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/Mem:/ {printf "%.0f", ($3/$2) * 100}'
      }

      # Function to get swap usage percentage
      get_swap_usage() {
        ${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/Swap:/ {if ($2 > 0) printf "%.0f", ($3/$2) * 100; else print "0"}'
      }

      # Function to check cooldown
      check_cooldown() {
        local level="$1"
        local cooldown_marker="$COOLDOWN_FILE.$level"

        if [ -f "$cooldown_marker" ]; then
          local last_notify=$(cat "$cooldown_marker")
          local now=$(date +%s)
          local elapsed=$((now - last_notify))

          if [ "$elapsed" -lt "$COOLDOWN_PERIOD" ]; then
            return 1  # Still in cooldown
          fi
        fi
        return 0  # Not in cooldown
      }

      # Function to set cooldown
      set_cooldown() {
        local level="$1"
        local cooldown_marker="$COOLDOWN_FILE.$level"
        date +%s > "$cooldown_marker"
      }

      # Function to send notification
      send_notification() {
        local level="$1"
        local mem_pct="$2"
        local swap_pct="$3"

        if check_cooldown "$level"; then
          case "$level" in
            warning)
              ${pkgs.libnotify}/bin/notify-send \
                --urgency=normal \
                --icon=dialog-warning \
                "Memory Warning" \
                "Memory usage: ''${mem_pct}% | Swap: ''${swap_pct}%"
              ;;
            critical)
              ${pkgs.libnotify}/bin/notify-send \
                --urgency=critical \
                --icon=dialog-error \
                "Critical Memory Alert" \
                "Memory usage: ''${mem_pct}% | Swap: ''${swap_pct}%\nConsider closing applications."
              ;;
          esac
          set_cooldown "$level"
        fi
      }

      # Function to rotate log file if too large
      rotate_log() {
        if [ -f "$LOG_FILE" ]; then
          local size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
          if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            echo "$(date -Iseconds) Log rotated (size exceeded $MAX_LOG_SIZE bytes)" > "$LOG_FILE"
          fi
        fi
      }

      # Main monitoring loop
      echo "$(date -Iseconds) Memory monitor started" >> "$LOG_FILE"

      while true; do
        MEM_PCT=$(get_memory_usage)
        SWAP_PCT=$(get_swap_usage)
        TIMESTAMP=$(date -Iseconds)

        # Log memory usage
        echo "$TIMESTAMP,mem=$MEM_PCT%,swap=$SWAP_PCT%" >> "$LOG_FILE"

        # Check thresholds and send notifications
        if [ "$MEM_PCT" -ge "$CRITICAL_THRESHOLD" ]; then
          send_notification "critical" "$MEM_PCT" "$SWAP_PCT"
        elif [ "$MEM_PCT" -ge "$WARNING_THRESHOLD" ]; then
          send_notification "warning" "$MEM_PCT" "$SWAP_PCT"
        fi

        # Rotate log if needed
        rotate_log

        sleep "$CHECK_INTERVAL"
      done
    '')

    # Claude memory tracker script - tracks Claude process memory usage
    (pkgs.writeShellScriptBin "claude-memory-tracker" ''
      #!/usr/bin/env bash

      # Configuration
      LOG_DIR="$HOME/.local/share/memory-monitor"
      LOG_FILE="$LOG_DIR/claude.csv"
      CHECK_INTERVAL=60       # Seconds between checks
      MAX_LOG_SIZE=10485760   # 10MB - rotate log when exceeded

      # Create log directory
      mkdir -p "$LOG_DIR"

      # Create CSV header if file doesn't exist
      if [ ! -f "$LOG_FILE" ]; then
        echo "timestamp,pid,command,rss_kb,vsz_kb,mem_pct" > "$LOG_FILE"
      fi

      # Function to rotate log file if too large
      rotate_log() {
        if [ -f "$LOG_FILE" ]; then
          local size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
          if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            echo "timestamp,pid,command,rss_kb,vsz_kb,mem_pct" > "$LOG_FILE"
          fi
        fi
      }

      # Main monitoring loop
      while true; do
        TIMESTAMP=$(date -Iseconds)

        # Find all Claude-related processes
        # Matches: claude, claude-code, @anthropics/claude-code, node processes with claude
        PIDS=$(${pkgs.procps}/bin/pgrep -f "(claude|@anthropic|opencode)" 2>/dev/null)

        if [ -n "$PIDS" ]; then
          for PID in $PIDS; do
            # Get process details: RSS (resident set size), VSZ (virtual memory), %MEM, command
            PROC_INFO=$(${pkgs.procps}/bin/ps -o rss=,vsz=,%mem=,comm= -p "$PID" 2>/dev/null)

            if [ -n "$PROC_INFO" ]; then
              RSS=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $1}')
              VSZ=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $2}')
              MEM_PCT=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $3}')
              COMM=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $4}')

              # Log to CSV
              echo "$TIMESTAMP,$PID,$COMM,$RSS,$VSZ,$MEM_PCT" >> "$LOG_FILE"
            fi
          done
        fi

        # Rotate log if needed
        rotate_log

        sleep "$CHECK_INTERVAL"
      done
    '')
  ];

  # Create mail directory for Himalaya with proper structure
  home.activation.createMailDir = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /home/benjamin/Mail/Gmail/INBOX/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Sent"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Drafts"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Trash"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/All Mail"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Spam"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/EuroTrip"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/CrazyTown"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Letters"/{cur,new,tmp}
    # Logos Labs maildir structure
    mkdir -p /home/benjamin/Mail/Logos/INBOX/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Sent"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Drafts"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Trash"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Archive"/{cur,new,tmp}
  '';

  # Systemd user services for ydotool daemon (required for dictation)
  systemd.user.services.screenshot-path-copy = {
    Unit = {
      Description = "Copy screenshot file path to clipboard on creation";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = toString (pkgs.writeShellScript "screenshot-path-copy" ''
        DIR="$HOME/Pictures/Screenshots"
        mkdir -p "$DIR"
        ${pkgs.inotify-tools}/bin/inotifywait -m -e close_write --format '%f' "$DIR" | while read -r filename; do
          filepath="$DIR/$filename"
          printf '%s' "$filepath" | ${pkgs.wl-clipboard}/bin/wl-copy
        done
      '');
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.ydotool = {
    Unit = {
      Description = "ydotool daemon for input automation";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
      # Allow access to /dev/uinput
      Environment = "PATH=/run/current-system/sw/bin";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Systemd user services for OAuth2 token refresh
  systemd.user.services.gmail-oauth2-refresh = {
    Unit = {
      Description = "Refresh Gmail OAuth2 tokens";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/refresh-gmail-oauth2";
      EnvironmentFile = "%h/.config/gmail-oauth2.env";
    };
  };

  systemd.user.timers.gmail-oauth2-refresh = {
    Unit = {
      Description = "Timer for Gmail OAuth2 token refresh";
      Requires = [ "gmail-oauth2-refresh.service" ];
    };
    Timer = {
      OnCalendar = "*:0/45"; # Every 45 minutes
      Persistent = true;
      RandomizedDelaySec = 300; # Random delay up to 5 minutes
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # ==========================================================================
  # Memory Monitoring User Services
  # ==========================================================================
  # Part of the three-tier memory monitoring system:
  #   Tier 1: earlyoom (system-level OOM prevention in configuration.nix)
  #   Tier 2: memory-monitor (user-level logging and alerts)
  #   Tier 3: claude-memory-tracker (process-specific tracking)
  #
  # See: specs/26_memory_monitoring_systemd_services_nixos
  # ==========================================================================

  # Memory monitor service - logs system memory and sends desktop alerts
  systemd.user.services.memory-monitor = {
    Unit = {
      Description = "System memory monitor with desktop alerts";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/memory-monitor";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Claude memory tracker service - tracks Claude process memory usage
  systemd.user.services.claude-memory-tracker = {
    Unit = {
      Description = "Claude process memory tracker";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/claude-memory-tracker";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # DISABLED: pgrep -f 'claude' self-matches inhibitor script, memory-tracker,
  # earlyoom, etc., causing sleep to be permanently blocked. See task 50.
  # systemd.user.services.claude-sleep-inhibitor = { ... };

  # Weekly cleanup of regenerable package-manager caches (pip/uv/npm) so they
  # don't regrow unbounded. Nix store GC is handled by nix.gc (configuration.nix)
  # and home-manager generation expiry by services.home-manager.autoExpire below.
  # See task 64. (systemd.user.tmpfiles.rules avoided due to HM issue #8125.)
  systemd.user.services.cache-cleanup = {
    Unit = {
      Description = "Purge regenerable package-manager caches (pip/uv/npm)";
    };
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script = pkgs.writeShellScript "cache-cleanup" ''
            export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
            echo "cache-cleanup: starting"
            command -v pip >/dev/null 2>&1 && pip cache purge || true
            command -v uv  >/dev/null 2>&1 && uv cache clean || true
            command -v npm >/dev/null 2>&1 && npm cache clean --force || true
            ${pkgs.coreutils}/bin/rm -rf "${config.home.homeDirectory}/.npm/_npx" || true
            echo "cache-cleanup: done"
          '';
        in
        "${script}";
    };
  };

  systemd.user.timers.cache-cleanup = {
    Unit = {
      Description = "Weekly timer for regenerable cache cleanup";
      Requires = [ "cache-cleanup.service" ];
    };
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = 3600;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Automatic user-level home-manager generation expiry + store GC. The
  # system-level nix.gc (configuration.nix) only collects root profiles and
  # never touches user HM generations, which were pinning months of old
  # closures in the store. See task 63.
  services.home-manager.autoExpire = {
    enable = true;
    timestamp = "-30 days";
    frequency = "weekly";
    store = {
      cleanup = true;
      options = "--delete-older-than 30d";
    };
  };

  # Add systemd user session variables for broader availability
  systemd.user.sessionVariables = {
    SASL_PATH = "${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2";
    LITERATURE_DIR = "/home/benjamin/Projects/Literature";
  };

  # Enable systemd integration
  systemd.user.startServices = "sd-switch";
}
