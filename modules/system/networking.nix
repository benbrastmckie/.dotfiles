# Networking, firewall, and security configuration.
{ ... }:
{
  # NOTE: networking.hostName is set per-host in flake.nix (via mkHost)

  # WiFi Configuration (see docs/wifi.md for details)
  # - Uses NetworkManager with default wpa_supplicant backend (mt7925e WiFi 6E/7)
  # - Do NOT enable "wifi.backend = iwd" (doesn't work with this hardware)
  # - Do NOT set "wireless.enable" manually (NetworkManager manages it automatically)
  networking = {
    networkmanager.enable = true;
    # networkmanager.wifi.backend = "iwd";  # DO NOT UNCOMMENT - breaks WiFi
  };

  # Security hardening
  security.pam.services.swaylock = { }; # Enable screen locking
  security.sudo.wheelNeedsPassword = true; # Require password for sudo

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ]; # HTTP/HTTPS
    allowedUDPPorts = [ ];
  };
}
