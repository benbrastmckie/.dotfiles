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
    
    # Himalaya email client with full feature set
    (pkgs-unstable.himalaya.overrideAttrs (oldAttrs: {
      cargoBuildFlags = (oldAttrs.cargoBuildFlags or []) ++ [ "--features=oauth2,keyring" ];
    }))     # Himalaya with OAuth2 support
    pkgs-unstable.isync  # For mbsync (IMAP synchronization) with OAuth2 support via cyrus-sasl
    cyrus-sasl-xoauth2   # XOAUTH2 SASL plugin for OAuth2 authentication
    msmtp        # For sending emails via SMTP
    pass         # Password manager for storing OAuth2 tokens
    gnupg        # Required for pass to work
    w3m          # Terminal web browser for viewing HTML emails
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

  # Create mail directory for Himalaya
  home.activation.createMailDir = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p /home/benjamin/Mail/Gmail
  '';

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
      message.send.backend.auth.client-id = "$GMAIL_CLIENT_ID"
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
    '';
    
    # mbsync configuration for IMAP synchronization
    ".mbsyncrc".text = ''
      # Gmail IMAP account
      IMAPAccount gmail
      Host imap.gmail.com
      Port 993
      User benbrastmckie@gmail.com
      AuthMechs XOAUTH2
      PassCmd "secret-tool lookup keyring gmail-smtp-oauth2-access-token"
      TLSType IMAPS

      # Gmail remote store
      IMAPStore gmail-remote
      Account gmail

      # Gmail local store
      MaildirStore gmail-local
      Path ~/Mail/Gmail/
      Inbox ~/Mail/Gmail/INBOX
      SubFolders Verbatim

      # Gmail sync channel
      Channel gmail
      Far :gmail-remote:
      Near :gmail-local:
      Patterns *
      Create Both
      SyncState *
      Expunge Both
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
    # Set SASL plugin path for XOAUTH2 support
    SASL_PATH = "${pkgs.cyrus-sasl-xoauth2}/lib/sasl2";
  };

  # programs.pylint.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}