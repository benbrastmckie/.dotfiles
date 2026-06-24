# System services: printing, network discovery, keyboard layout, and input.
{ ... }:
{
  # Enable CUPS to print documents.
  # Using IPP Everywhere (driverless) - HPLIP removed as it conflicts with IPP
  services.printing = {
    enable = true;
    # drivers = with pkgs; [ hplip ];  # Removed - causes blank pages with IPP
  };

  # Enable network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.options = "caps:swapescape,ctrl:swap_lalt_lctl";
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
}
