# Networking, firewall, security, and related service timeout configuration.
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

  # ==========================================================================
  # Service Timeout and Reliability Configuration
  # ==========================================================================
  # Reduce shutdown timeout cascade during NetworkManager deadlocks
  # See: specs/reports/019_system_freeze_shutdown_analysis.md
  # ==========================================================================
  systemd.services = {
    # NetworkManager timeout configuration
    NetworkManager = {
      serviceConfig = {
        TimeoutStopSec = "30s"; # Reduce from 2min to force faster kill on deadlock
        # Watchdog removed - was causing crashes when NM became temporarily unresponsive
        # Restart = "on-failure";  # Disabled - let systemd handle failures normally
      };
    };

    # Reduce timeout for services that wait on NetworkManager
    avahi-daemon = {
      serviceConfig = {
        TimeoutStopSec = "20s"; # Reduce from 90s
      };
    };
  };
}
