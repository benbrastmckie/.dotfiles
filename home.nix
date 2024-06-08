{ config, pkgs, ... }:

{
  # manage.
  home.username = "benjamin";
  home.homeDirectory = "/home/benjamin";

  programs.git = {
    enable = true;
    userName = "benbrastmckie";
    userEmail = "benbrastmckie@gmail.com";
  };

  home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.

  # home.packages allows you to install Nix packages into your environment.
  home.packages = 
    (with pkgs; [
      (python312.withPackages(p: with p; [
        z3 
        setuptools 
        pyinstrument
        build
        twine
        pytest
        pytest-timeout
        model-checker
        # pip
        # pynvim 
        # pylint 
        # black  
        # isort  
      ]))
    (nerdfonts.override { fonts = [ "RobotoMono" ]; })
  ]);

  # ++
  #
  # (with unstable; [
  #   (python311.withPackages(p: with p; [
  #     p.model-checker
  #   ]))
  # ]);

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # ".config/fish/config.fish".source = config/config.fish;
    # ".config/kitty/kitty.conf".source = config/kitty.conf;
    # ".config/zathura/zathurarc".source = config/zathurarc;
    ".config/neofetch/config.conf".source = config/neofetch.conf;
    ".config/alacritty/alacritty.toml".source = config/alacritty.toml;
    ".tmux.conf".source = config/.tmux.conf;
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # programs.pylint.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
