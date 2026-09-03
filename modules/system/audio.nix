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
  security.rtkit.enable = true;
  services = {
    blueman.enable = lib.mkIf (!config.services.desktopManager.gnome.enable) true;

    pulseaudio.enable = false;
    pipewire = {
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

      # LADSPA plugins made available to PipeWire filter chains via LADSPA_PATH.
      # pkgs.ladspaPlugins is the SWH plugin set, which provides SC4 (compressor)
      # and the fast lookahead limiter used by the mic chain below. Plugins are
      # referenced by bare filename (no path, no .so) because PipeWire resolves
      # them against LADSPA_PATH, not as absolute paths.
      extraLadspaPackages = [ pkgs.ladspaPlugins ];

      # Virtual source "Mic (Boosted)": compressor + limiter over the HyperX
      # SoloCast. The raw mic measures ~-35 dB mean / ~-13.5 dB peak on normal
      # speech -- roughly 15 dB below a usable level, but with a ~21 dB crest
      # factor, so flat gain would clip the peaks before the mean got loud
      # enough. SC4 compresses 4:1 above -26 dB (pulling peaks down) and then
      # applies +16 dB makeup, landing mean near -19 dB and peaks near -7 dB.
      # The limiter is a hard backstop at -2 dB so nothing ever clips.
      #
      # This is a separate source, NOT a replacement for the raw device: any app
      # (Kooha, gpu-screen-recorder, OBS, Zoom) can select "Mic (Boosted)", and
      # the untouched SoloCast stays available for A/B comparison.
      extraConfig.pipewire."99-mic-boost" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "Mic (Boosted)";
              "media.name" = "Mic (Boosted)";
              "filter.graph" = {
                nodes = [
                  {
                    type = "ladspa";
                    name = "compressor";
                    plugin = "sc4_1882";
                    label = "sc4";
                    control = {
                      "RMS/peak" = 0; # 0 = RMS detection, smoother on voice
                      "Attack time (ms)" = 10;
                      "Release time (ms)" = 150;
                      "Threshold level (dB)" = -26;
                      "Ratio (1:n)" = 4;
                      "Knee radius (dB)" = 3;
                      "Makeup gain (dB)" = 16;
                    };
                  }
                  {
                    type = "ladspa";
                    name = "limiter";
                    plugin = "fast_lookahead_limiter_1913";
                    label = "fastLookaheadLimiter";
                    control = {
                      "Input gain (dB)" = 0;
                      "Limit (dB)" = -2;
                      "Release time (s)" = 0.2;
                    };
                  }
                ];
                links = [
                  {
                    output = "compressor:Left output";
                    input = "limiter:Input 1";
                  }
                  {
                    output = "compressor:Right output";
                    input = "limiter:Input 2";
                  }
                ];
                inputs = [
                  "compressor:Left input"
                  "compressor:Right input"
                ];
                outputs = [
                  "limiter:Output 1"
                  "limiter:Output 2"
                ];
              };
              "capture.props" = {
                "node.name" = "capture.mic_boosted";
                "node.passive" = true;
                "target.object" = "alsa_input.usb-HP__Inc_HyperX_SoloCast-00.analog-stereo";
                "audio.position" = [
                  "FL"
                  "FR"
                ];
              };
              "playback.props" = {
                "node.name" = "mic_boosted";
                "node.description" = "Mic (Boosted)";
                "media.class" = "Audio/Source";
                "audio.position" = [
                  "FL"
                  "FR"
                ];
              };
            };
          }
        ];
      };
    };
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
