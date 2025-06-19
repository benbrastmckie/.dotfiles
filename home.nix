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

  programs.himalaya = {
    enable = true;
    package = pkgs-unstable.himalaya;
  };

  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.

  # home.packages allows you to install Nix packages into your environment.
  home.packages = with pkgs; [
    claude-code  # Using overlaid unstable package
    lectic
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

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".config/neofetch/config.conf".source = ./config/neofetch.conf;
    ".config/niri/config.kdl".source = ./config/config.kdl;
    ".config/himalaya/config.toml".text = ''
      [accounts.personal]
      email = "benbrastmckie@gmail.com"
      display-name = "Benjamin Brast-McKie"
      default = true

      [accounts.personal.backend]
      type = "imap"
      host = "imap.gmail.com"
      port = 993
      encryption = "tls"
      login = "benbrastmckie@gmail.com"

      [accounts.personal.backend.auth]
      type = "oauth2"
      client-id = "$GMAIL_CLIENT_ID"
      client-secret = { keyring = "gmail-oauth2-client-secret" }
      access-token = { keyring = "gmail-oauth2-access-token" }
      refresh-token = { keyring = "gmail-oauth2-refresh-token" }
      auth-url = "https://accounts.google.com/o/oauth2/v2/auth"
      token-url = "https://www.googleapis.com/oauth2/v3/token"
      pkce = true
      scope = "https://mail.google.com/"

      [accounts.personal.message]
      [accounts.personal.message.send]
      [accounts.personal.message.send.backend]
      type = "smtp"
      host = "smtp.gmail.com"
      port = 465
      encryption = "ssl"
      login = "benbrastmckie@gmail.com"

      [accounts.personal.message.send.backend.auth]
      type = "oauth2"
      client-id = "$GMAIL_CLIENT_ID"
      client-secret = { keyring = "gmail-oauth2-client-secret" }
      access-token = { keyring = "gmail-oauth2-access-token" }
      refresh-token = { keyring = "gmail-oauth2-refresh-token" }
      auth-url = "https://accounts.google.com/o/oauth2/v2/auth"
      token-url = "https://www.googleapis.com/oauth2/v3/token"
      pkce = true
      scope = "https://mail.google.com/"

      [accounts.personal.folder]
      [accounts.personal.folder.aliases]
      inbox = "INBOX"
      sent = "[Gmail]/Sent Mail"
      drafts = "[Gmail]/Drafts"
      trash = "[Gmail]/Trash"
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