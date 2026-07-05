# System services: printing, network discovery, keyboard layout, and input.
_: {
  services = {
    # Enable CUPS to print documents.
    # Using IPP Everywhere (driverless) - HPLIP removed as it conflicts with IPP
    printing = {
      enable = true;
      # drivers = with pkgs; [ hplip ];  # Removed - causes blank pages with IPP
    };

    # Enable network printer discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Configure keymap in X11
    xserver = {
      xkb.layout = "us";
      xkb.options = "caps:swapescape,ctrl:swap_lalt_lctl";
    };

    # Enable touchpad support (enabled default in most desktopManager).
    libinput.enable = true;
  };
}
