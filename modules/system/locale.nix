# Time zone, locale, geolocation, and internationalisation configuration.
{ lib, ... }:
{
  # Time and location configuration
  services.geoclue2 = {
    enable = true;
    # Enable WiFi-based location detection (uses BeaconDB)
    enableWifi = lib.mkForce true;
    # Enable static source as fallback when network geolocation fails
    # Coordinates for California (approximate location for timezone detection)
    # This provides a backup location when BeaconDB or WiFi geolocation is unavailable
    enableStatic = true;
    staticLatitude = 37.77; # San Francisco area
    staticLongitude = -122.42;
    staticAltitude = 50; # 50 meters (approximate elevation for San Francisco Bay Area)
    staticAccuracy = 100000; # 100km accuracy (sufficient for timezone detection)
    appConfig = {
      "org.gnome.Shell.LocationServices" = {
        isAllowed = true;
        isSystem = true;
      };
      automatic-timezone = {
        isAllowed = true;
        isSystem = true;
      };
    };
  };

  # Enable location services
  location.provider = "geoclue2";

  # California default with forced priority to ensure /etc/localtime always exists
  # Problem: automatic-timezoned sets time.timeZone = null (priority ~1000), which
  # overrides lib.mkDefault (~1500) and causes NixOS to not create /etc/localtime.
  # Applications like leanls fail with "no such file or directory: /etc/localtime".
  # Solution: lib.mkForce (~50) ensures the symlink always exists at boot, while
  # automatic-timezoned can still update the timezone via timedatectl when geolocation works.
  time.timeZone = lib.mkForce "America/Los_Angeles";

  # Enable automatic timezone detection (will override the default above)
  services.automatic-timezoned.enable = true;

  # QMK keyboard support - creates plugdev group, adds udev rules
  # Using the NixOS QMK module instead of manual udev packages to avoid
  # "Failed to resolve group 'plugdev'" spam from systemd-udevd (every 3-4s).
  # That spam was keeping journald at 4-5% CPU and preventing CPU idle states.
  hardware.keyboard.qmk.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Set environment variables for Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1"; # Helps with cursor issues
  };
}
