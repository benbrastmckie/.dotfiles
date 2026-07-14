# GNOME desktop environment settings via dconf, unclutter, and cursor theme.
{ pkgs, ... }:
{
  # GNOME settings via dconf
  dconf.settings = {
    # GNOME Shell extensions
    "org/gnome/shell" = {
      enabled-extensions = [
        "activate-window-by-title@lucaswerkmeister.de"
        "unite@hardpixel.eu"
        "mouse-follows-focus@crisidev.org"
      ];
    };

    # Unite extension settings
    "org/gnome/shell/extensions/unite" = {
      desktop-name-text = "Hamsa";
      extend-left-box = true;
      hide-window-titlebars = "always";
      reduce-panel-spacing = true;
      show-window-buttons = "never";
      show-window-title = "never";
      window-buttons-theme = "auto";
    };

    # Interface preferences
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      toolkit-accessibility = false;
    };

    # Power management and sleep settings
    "org/gnome/desktop/session" = {
      idle-delay = 300; # 5 minutes - when screen dims/blanks
    };

    "org/gnome/settings-daemon/plugins/power" = {
      # Never auto-suspend on AC — headless agents keep running.
      # See docs/no-sleep-agents.md.
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-ac-timeout = 3600; # 60 minutes on AC power (inert with type "nothing")
      # Battery idle-suspend after 60 minutes. Fires ONLY when no logind block
      # inhibitor is held: an open Claude Code session (even idle) blocks it
      # entirely, in which case the 10% battery-suspend-backstop timer in
      # modules/system/power.nix is the only protection (accepted limitation,
      # task 117 decision 1).
      sleep-inactive-battery-timeout = 3600; # 60 minutes on battery
      # Explicit rather than riding the schema default: after deliberately
      # setting the AC type to "nothing" above, leaving the battery type
      # implicit invites drift.
      sleep-inactive-battery-type = "suspend";
      idle-dim = true; # Dim screen before blanking
    };

    # Desktop background
    "org/gnome/desktop/background" = {
      picture-uri = "file:///etc/wallpapers/riverside.jpg";
      picture-uri-dark = "file:///etc/wallpapers/riverside.jpg";
      picture-options = "zoom";
    };

    # Lock screen background
    "org/gnome/desktop/screensaver" = {
      picture-uri = "file:///etc/wallpapers/riverside.jpg";
      picture-options = "zoom";
    };

    # Mouse and touchpad
    "org/gnome/desktop/peripherals/mouse" = {
      speed = 0.34188034188034178;
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      speed = 0.48717948717948723;
      two-finger-scrolling-enabled = true;
    };

    # Window manager preferences
    "org/gnome/desktop/wm/preferences" = {
      focus-mode = "sloppy";
    };

    # Window manager keybindings (vim-style)
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
      cycle-windows = [ "<Super>space" ];
      cycle-windows-backward = [ "<Shift><Super>space" ];
      maximize = [ "<Shift><Control>k" ];
      move-to-monitor-down = [ "<Shift><Super>j" ];
      move-to-monitor-left = [ "<Shift><Super>h" ];
      move-to-monitor-right = [ "<Shift><Super>l" ];
      move-to-monitor-up = [ "<Shift><Super>k" ];
      move-to-workspace-left = [ "<Shift><Alt>h" ];
      move-to-workspace-right = [ "<Shift><Alt>l" ];
      switch-to-workspace-left = [ "<Super>h" ];
      switch-to-workspace-right = [ "<Super>l" ];
      unmaximize = [ "<Shift><Control>j" ];
    };

    # Mutter settings
    "org/gnome/mutter" = {
      focus-change-on-pointer-rest = false;
    };
    "org/gnome/mutter/keybindings" = {
      toggle-tiled-left = [ "<Shift><Control>h" ];
      toggle-tiled-right = [ "<Shift><Control>l" ];
    };

    # Media keys
    "org/gnome/settings-daemon/plugins/media-keys" = {
      control-center = [ "<Super>backslash" ];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
      ];
      home = [ "<Super>f" ];
      screensaver = [ "<Super>grave" ];
      www = [ "<Super>b" ];
    };

    # Custom keybindings - WezTerm terminal
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>t";
      command = "wezterm";
      name = "Terminal";
    };

    # Custom keybindings - Zotero
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>z";
      command = "zotero";
      name = "Zotero";
    };

    # Custom keybindings - Whisper dictation
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super>d";
      command = "whisper-dictate";
      name = "Dictation";
    };
  };

  services.unclutter = {
    enable = true;
    timeout = 3;
  };

  # Configure cursor theme properly
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    x11.enable = true;
    gtk.enable = true;
  };
}
