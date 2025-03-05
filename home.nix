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
  home.packages = 
    (with pkgs; [
      # Add niri to home packages for better integration
      niri.packages.${system}.default
      
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
  ]);

  # ++
  #
  # (with pkgs-unstable; [
  #   neovim
  #   # (python311.withPackages(p: with p; [
  #   #   p.model-checker
  #   # ]))
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
    # # symlink to the Nix store copy. All files must at least be staged in git.

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    # # Wayland-specific
    # MOZ_ENABLE_WAYLAND = "1";
    # QT_QPA_PLATFORM = "wayland";
    # SDL_VIDEODRIVER = "wayland";
    # _JAVA_AWT_WM_NONREPARENTING = "1";
    # Prefer Wayland over X11
    NIXOS_OZONE_WL = "1";
  };
    input {
        keyboard {
            repeat-delay = 60
            repeat-rate = 30
        }
        
        # Add touchpad configuration
        touchpad {
            natural-scroll = true
            tap = true
            dwt = false  # disable while typing
        }
    }

    # Add default preferences
    preferences {
        border-width = 2
        gaps = 8
        cursor {
            xcursor-theme = "default"
            xcursor-size = 24
        }
    }
            repeat-rate = 30
        }
    }

    layout {
        focus-ring {
            width = 2
            active-color = { red = 0.0 green = 0.5 blue = 1.0 alpha = 1.0 }
            inactive-color = { red = 0.5 green = 0.5 blue = 0.5 alpha = 1.0 }
        }
    }

    binds {
        # Basic window management
        Mod+Return "exec kitty"
        Mod+q "close"
        Mod+Shift+q "exit"
        Mod+p "exec fuzzel"
        
        # Screenshots
        Mod+Shift+s "screenshot"
        Mod+Alt+s "screenshot-screen"
        
        # Window focus
        Mod+h "focus left"
        Mod+j "focus down"
        Mod+k "focus up"
        Mod+l "focus right"
        
        # Window movement
        Mod+Shift+h "move left"
        Mod+Shift+j "move down"
        Mod+Shift+k "move up"
        Mod+Shift+l "move right"
        
        # Workspaces
        Mod+1 "workspace 1"
        Mod+2 "workspace 2"
        Mod+3 "workspace 3"
        Mod+4 "workspace 4"
        Mod+5 "workspace 5"
        
        # Move windows to workspaces
        Mod+Shift+1 "move-to-workspace 1"
        Mod+Shift+2 "move-to-workspace 2"
        Mod+Shift+3 "move-to-workspace 3"
        Mod+Shift+4 "move-to-workspace 4"
        Mod+Shift+5 "move-to-workspace 5"
        
        # Layout management
        Mod+f "toggle-fullscreen"
        Mod+space "toggle-floating"
    }

    prefer-no-csd true

    cursor {
        theme "Adwaita"
        size 24
    }

    animations {
        enabled = true
    }

  '';

  # programs.pylint.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
