# Kanshi dynamic display configuration for the Niri Wayland compositor session.
# Note: Uses niri.service target so it only runs in Niri session
_: {
  services.kanshi = {
    enable = true;
    systemdTarget = "niri.service";
    settings = [
      {
        profile.name = "undocked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
            mode = "2560x1600@120Hz";
            scale = 1.25;
          }
        ];
      }
      # Add docked profiles when external monitors are available
      # Example:
      # {
      #   profile.name = "docked-home";
      #   profile.outputs = [
      #     { criteria = "eDP-1"; status = "disable"; }
      #     { criteria = "DP-1"; status = "enable"; mode = "3840x2160@60Hz"; scale = 1.5; }
      #   ];
      # }
    ];
  };
}
