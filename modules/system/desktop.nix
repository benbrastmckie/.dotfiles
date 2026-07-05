# Desktop environment: GNOME, niri, GDM, XDG portal, and dconf configuration.
# deadnix: skip
{ pkgs, lib, ... }:
{
  services = {
    # Enable the X11 windowing system and display manager
    xserver.enable = true;

    displayManager.gdm = {
      enable = true;
    };

    # Enable full GNOME desktop environment
    desktopManager.gnome = {
      enable = true;
      extraGSettingsOverrides = ''
        [org.gnome.desktop.interface]
        enable-hot-corners=false
      '';
    };

    # Ensure proper Wayland and GNOME integration
    displayManager.sessionPackages = [ pkgs.niri ]; # Enables niri session in GDM

    # Enable GNOME services
    gnome = {
      gnome-settings-daemon.enable = true;
      gnome-online-accounts.enable = true;
      evolution-data-server.enable = true;
      gnome-keyring.enable = true;
      gnome-remote-desktop.enable = true;
      # core-network.enable = true;  # Ensure GNOME network components are enabled

      # Disable tracker services to reduce background CPU load
      # localsearch (formerly tracker-miner) indexes files for GNOME search
      # tinysparql (formerly tracker) provides the database backend
      # These cause CPU spikes during file indexing
      # See: specs/40_investigate_laptop_high_fan_optimize_system
      localsearch.enable = false;
      tinysparql.enable = false;
    };

    # Additional GNOME services that are useful for both environments
    # Nautilus required for GNOME portal FileChooser implementation
    dbus.packages = [
      pkgs.dconf
      pkgs.nautilus
    ];

    # Enable GNOME Virtual File System
    gvfs.enable = true;
  };

  # Hide root user from GDM login screen and GNOME user settings
  # This prevents "System administrator" from appearing in the user list
  environment.etc."accountsservice/users/root".text = ''
    [User]
    SystemAccount=true
  '';

  environment.etc."wallpapers/riverside.jpg".source = ../../wallpapers/riverside.jpg;

  programs = {
    # Set GDM login screen background using proper NixOS dconf profiles
    # This ensures the dconf database is properly compiled for GDM
    dconf.profiles.gdm.databases = [
      {
        settings = {
          "org/gnome/desktop/background" = {
            picture-uri = "file:///etc/wallpapers/riverside.jpg";
            picture-uri-dark = "file:///etc/wallpapers/riverside.jpg"; # Required for dark mode
            picture-options = "zoom";
          };
          "org/gnome/desktop/screensaver" = {
            picture-uri = "file:///etc/wallpapers/riverside.jpg";
          };
        };
      }
    ];

    # Niri Wayland compositor - ENABLED (dual-session with GNOME)
    # Both GNOME and niri sessions available at GDM login
    niri = {
      enable = true;
      package = pkgs.niri;
    };

    # Ensure proper Wayland and GNOME integration
    xwayland.enable = true;

    dconf.enable = true;
  };

  # Configure Wayland properly
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.polkit.enable = true;

  # XDG Desktop Portal Configuration
  # Enables screen sharing, file chooser, and GNOME Settings integration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [
          "gnome"
          "gtk"
        ];
      };
      # Niri-specific portal configuration - uses GNOME portals
      # This ensures screen sharing, file picker work in niri session
      # See: specs/reports/012_niri_with_gnome_integration.md
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Settings" = [ "gnome" ];
      };
    };
  };
}
