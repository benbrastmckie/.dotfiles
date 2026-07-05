# Audio (PipeWire), Bluetooth, and sound hardware configuration.
{
  pkgs,
  lib,
  config,
  ...
}:
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

  # Audio Static Fix: Disable speaker amplifier (EAPD) at boot
  # This systemd service runs hda-verb to disable the speaker amplifier on the
  # Realtek ALC256 codec. This eliminates idle static/hiss from internal speakers
  # but means internal speakers will NOT work until re-enabled.
  #
  # To re-enable internal speakers temporarily:
  #   sudo hda-verb /dev/snd/hwC0D0 0x14 SET_EAPD_BTLENABLE 2
  #
  # To disable again (stop static):
  #   sudo hda-verb /dev/snd/hwC0D0 0x14 SET_EAPD_BTLENABLE 0
  #
  # Node 0x14 = Speaker pin on ALC256
  # EAPD bit 1 (value 2) = amplifier enabled, bit 0 (value 0) = disabled
  systemd.services.disable-speaker-amp = {
    description = "Disable internal speaker amplifier to prevent EMI static";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.alsa-tools}/bin/hda-verb /dev/snd/hwC0D0 0x14 SET_EAPD_BTLENABLE 0";
    };
  };
}
