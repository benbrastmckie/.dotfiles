# Audio (PipeWire), Bluetooth, and sound hardware configuration.
{ lib, config, ... }:
{
  # Enable Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # Automatically power on Bluetooth adapter at boot
  };
  services.blueman.enable = lib.mkIf (!config.services.desktopManager.gnome.enable) true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    # Use the system-wide installation
    systemWide = false;
  };
}
