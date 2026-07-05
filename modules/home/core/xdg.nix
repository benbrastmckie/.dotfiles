# XDG base directories, MIME associations, and desktop integration.
_: {
  xdg = {
    # Enable XDG base directories
    enable = true;

    # Sioyek PDF viewer - custom desktop entry in ~/.local/share/applications
    # This location is fully respected by GNOME Files (unlike ~/.nix-profile/share/applications)
    # Uses the Wayland-wrapped binary from configuration.nix (QT_WAYLAND_DISABLE_WINDOWDECORATION=1)
    dataFile."applications/sioyek.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Sioyek
      GenericName=PDF Viewer
      Comment=PDF viewer for reading research papers and technical books
      Exec=/run/current-system/sw/bin/sioyek --reuse-window %f
      Icon=sioyek-icon-linux
      Terminal=false
      Categories=Office;Viewer;
      MimeType=application/pdf;
    '';

    # MIME type associations - browser defaults only, PDF managed via GNOME
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
      };
    };
  };
}
