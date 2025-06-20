{ config, pkgs, pkgs-unstable, lectic, ... }:

{
  # Import our custom modules
  imports = [
    # ./home-modules/mcp-hub.nix  # Disabled - using lazy.nvim approach
  ];

  # manage.
  home.username = "benjamin";
  home.homeDirectory = "/home/benjamin";

  programs.git = {
    enable = true;
    userName = "benbrastmckie";
    userEmail = "benbrastmckie@gmail.com";
  };

  programs.neovim = {
    enable = true;
    package = pkgs-unstable.neovim-unwrapped;  # Use neovim-unwrapped directly from unstable
    extraPackages = [
      pkgs.luajitPackages.jsregexp  # Add jsregexp package here
      # pkgs.tree-sitter-grammars.tree-sitter-latex  # Add latex grammar for tree-sitter
    ];
    
    # Note: MCP-Hub is managed via lazy.nvim in NeoVim config
  };

  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.

  # home.packages allows you to install Nix packages into your environment.
  home.packages = with pkgs; [
    claude-code  # Using overlaid unstable package
    lectic
    
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
      cargoBuildFlags = (oldAttrs.cargoBuildFlags or []) ++ [ "--features=oauth2,keyring" ];
    }))     # Himalaya with OAuth2 support
    # mbsync (isync) with XOAUTH2 support
    # Option 1: Wrapper script (simpler, recommended)
    (pkgs.writeShellScriptBin "mbsync" ''
      export SASL_PATH="${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2"
      exec ${pkgs-unstable.isync}/bin/mbsync "$@"
    '')
    
    # Option 2: If you prefer, you can use this instead of the wrapper above:
    # (pkgs-unstable.isync.overrideAttrs (oldAttrs: {
    #   buildInputs = oldAttrs.buildInputs ++ [ pkgs.cyrus-sasl-xoauth2 ];
    #   postInstall = (oldAttrs.postInstall or "") + ''
    #     wrapProgram $out/bin/mbsync \
    #       --set SASL_PATH "${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2"
    #   '';
    # }))
    
    cyrus-sasl-xoauth2   # XOAUTH2 SASL plugin for OAuth2 authentication
    msmtp        # For sending emails via SMTP
    pass         # Password manager for storing OAuth2 tokens
    gnupg        # Required for pass to work
    w3m          # Terminal web browser for viewing HTML emails
    curl         # For OAuth2 token refresh
    jq           # For parsing JSON responses
    # Note: libsecret is already installed system-wide in configuration.nix
    # Required for running mcp-hub JavaScript tools
    # MCP-Hub is now managed by the home module
    nodejs    # Required runtime dependency
    (python312.withPackages(p: with p; [
      z3 
      setuptools 
      pyinstrument
      build
      twine
      pytest
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

      # Jupyter Notebooks
      jupytext
      ipython


      # pylint 
      # black  
      # isort  
    ]))
    (nerdfonts.override { fonts = [ "RobotoMono" ]; })
  ];

  # Create mail directory for Himalaya with proper structure
  home.activation.createMailDir = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p /home/benjamin/Mail/Gmail
    # Ensure Gmail special folders exist (they should be created by mbsync)
    # Creating them here ensures they're available even before first sync
    mkdir -p "/home/benjamin/Mail/Gmail/.[Gmail].Sent Mail"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/.[Gmail].Drafts"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/.[Gmail].Trash"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/.[Gmail].Spam"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/.[Gmail].All Mail"/{cur,new,tmp}
    
    # Create compatibility symlinks for applications expecting standard folder names
    # This ensures maximum compatibility while maintaining Gmail's folder structure
    ln -sfn "/home/benjamin/Mail/Gmail/.[Gmail].Sent Mail" "/home/benjamin/Mail/Gmail/.Sent"
    ln -sfn "/home/benjamin/Mail/Gmail/.[Gmail].Drafts" "/home/benjamin/Mail/Gmail/.Drafts"
    ln -sfn "/home/benjamin/Mail/Gmail/.[Gmail].Trash" "/home/benjamin/Mail/Gmail/.Trash"
  '';

  # Systemd user services for OAuth2 token refresh
  systemd.user.services.gmail-oauth2-refresh = {
    Unit = {
      Description = "Refresh Gmail OAuth2 tokens";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/refresh-gmail-oauth2";
      EnvironmentFile = "${config.home.homeDirectory}/.config/gmail-oauth2.env";
    };
  };

  systemd.user.timers.gmail-oauth2-refresh = {
    Unit = {
      Description = "Timer for Gmail OAuth2 token refresh";
      Requires = [ "gmail-oauth2-refresh.service" ];
    };
    Timer = {
      OnCalendar = "*:0/45";  # Every 45 minutes
      Persistent = true;
      RandomizedDelaySec = 300;  # Random delay up to 5 minutes
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".config/neofetch/config.conf".source = ./config/neofetch.conf;
    ".config/niri/config.kdl".source = ./config/config.kdl;
    ".config/himalaya/config.toml".text = ''
      [accounts.gmail]
      default = true
      email = "benbrastmckie@gmail.com"
      display-name = "benbrastmckie"
      downloads-dir = "/home/benjamin/Downloads"
      
      backend.type = "maildir"
      backend.root-dir = "/home/benjamin/Mail/Gmail"
      backend.maildirpp = true
      
      message.send.backend.type = "smtp"
      message.send.backend.host = "smtp.gmail.com"
      message.send.backend.port = 465
      message.send.backend.login = "benbrastmckie@gmail.com"
      message.send.backend.encryption.type = "tls"
      message.send.backend.auth.type = "oauth2"
      message.send.backend.auth.method = "xoauth2"
      message.send.backend.auth.client-id = "''${GMAIL_CLIENT_ID}"
      message.send.backend.auth.auth-url = "https://accounts.google.com/o/oauth2/auth"
      message.send.backend.auth.token-url = "https://www.googleapis.com/oauth2/v3/token"
      message.send.backend.auth.pkce = true
      message.send.backend.auth.redirect-scheme = "http"
      message.send.backend.auth.redirect-host = "localhost"
      message.send.backend.auth.redirect-port = 49152
      message.send.backend.auth.scopes = ["https://mail.google.com/", "https://www.googleapis.com/auth/contacts", "https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/auth/carddav"]
      message.send.backend.auth.client-secret.keyring = "gmail-smtp-oauth2-client-secret"
      message.send.backend.auth.access-token.keyring = "gmail-smtp-oauth2-access-token"
      message.send.backend.auth.refresh-token.keyring = "gmail-smtp-oauth2-refresh-token"
      
      # Folder configuration for Gmail's special folders
      folder.alias.inbox = "INBOX"
      folder.alias.sent = "[Gmail].Sent Mail"
      folder.alias.drafts = "[Gmail].Drafts"
      folder.alias.trash = "[Gmail].Trash"
      folder.alias.spam = "[Gmail].Spam"
      folder.alias.all = "[Gmail].All Mail"
      
      # Configure sent message handling
      message.send.save-copy = true
      folder.sent.name = "[Gmail].Sent Mail"
    '';
    
    # mbsync configuration for IMAP synchronization
    ".mbsyncrc".text = ''
      # Gmail IMAP account
      IMAPAccount gmail
      Host imap.gmail.com
      Port 993
      User benbrastmckie@gmail.com
      AuthMechs XOAUTH2
      PassCmd "secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-access-token"
      TLSType IMAPS

      # Gmail remote store
      IMAPStore gmail-remote
      Account gmail

      # Gmail local store
      MaildirStore gmail-local
      Inbox ~/Mail/Gmail/
      SubFolders Maildir++

      # Gmail sync channel
      Channel gmail
      Far :gmail-remote:
      Near :gmail-local:
      Patterns *
      Create Both
      SyncState *
      Expunge Both
    '';
    
    # Gmail OAuth2 environment file for systemd service
    ".config/gmail-oauth2.env".text = ''
      GMAIL_CLIENT_ID=$GMAIL_CLIENT_ID
    '';
    
    # NOTE: The following are excluded since they belong to .config for others to use
    # ".config/fish/config.fish".source = ./config/config.fish;
    # ".config/kitty/kitty.conf".source = ./config/kitty.conf;
    # ".config/zathura/zathurarc".source = ./config/zathurarc;
    # ".config/alacritty/alacritty.toml".source = ./config/alacritty.toml;
    # ".tmux.conf".source = ./config/.tmux.conf;
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy. All files must at least be staged in git.

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    # Prefer Wayland over X11
    NIXOS_OZONE_WL = "1";
    # MCP_HUB_PATH is now managed by the MCP-Hub module
  };

  # programs.pylint.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}