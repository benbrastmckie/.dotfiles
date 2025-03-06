{ config, pkgs, pkgs-unstable, ... }:

{
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
    package = pkgs.neovim-unwrapped;  # Ensure you're using the latest neovim
  };

  home.stateVersion = "24.11"; # Please read the comment before changing.
  # home.stateVersion = "24.05"; # Please read the comment before changing.
  # home.stateVersion = "23.11"; # Please read the comment before changing.

  # home.packages allows you to install Nix packages into your environment.
  home.packages = with pkgs; [
    niri
    (python312.withPackages(p: with p; [
      z3 
      setuptools 
      pyinstrument
      build
      twine
      pytest
      pytest-timeout
      model-checker
      tqdm
      pip
      # pynvim 
      # pylint 
      # black  
      # isort  
    ]))
    (nerdfonts.override { fonts = [ "RobotoMono" ]; })
  ];

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
  };

  # Manage niri configuration file directly
  home.file.".config/niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
            repeat-delay 60
            repeat-rate 30
        }
        
        touchpad {
            natural-scroll true
            tap true
            dwt false  # disable while typing
        }
    }

    layout {
        gaps 16
        border.width 4
        focus-ring {
            width 4
            active.color "#0077ff"
            inactive.color "#5f676a"
        }
    }

    binds {
        Mod+T { spawn "kitty" }
        Mod+Q { close-window }
        Mod+D { spawn "fuzzel" }
        
        # Window focus
        Mod+h { focus-column-left }
        Mod+j { focus-window-down }
        Mod+k { focus-window-up }
        Mod+l { focus-column-right }
        
        # Window movement
        Mod+Shift+h { move-column-left }
        Mod+Shift+j { move-window-down }
        Mod+Shift+k { move-window-up }
        Mod+Shift+l { move-column-right }
        
        # Workspaces
        Mod+1 { focus-workspace 1 }
        Mod+2 { focus-workspace 2 }
        Mod+3 { focus-workspace 3 }
        Mod+4 { focus-workspace 4 }
        Mod+5 { focus-workspace 5 }
        
        # Move windows to workspaces
        Mod+Shift+1 { move-window-to-workspace 1 }
        Mod+Shift+2 { move-window-to-workspace 2 }
        Mod+Shift+3 { move-window-to-workspace 3 }
        Mod+Shift+4 { move-window-to-workspace 4 }
        Mod+Shift+5 { move-window-to-workspace 5 }
        
        # Layout management
        Mod+f { toggle-fullscreen }
        Mod+Space { toggle-floating }
    }

    spawn-at-startup "waybar"
    spawn-at-startup "mako"
  '';

  # programs.pylint.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
