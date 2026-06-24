# Waybar status bar configuration for the Niri Wayland compositor session.
{ ... }:
{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "idle_inhibitor" "tray" "bluetooth" "pulseaudio" "network" "battery" ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1:web" = "";
            "2:code" = "";
            "3:term" = "";
            "4:docs" = "";
            "5:media" = "";
            "6:chat" = "";
            "7:misc" = "";
            "8:extra" = "";
            "9:bg" = "";
            default = "";
          };
        };

        "niri/window" = {
          max-length = 50;
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        battery = {
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-icons = [ "" "" "" "" "" ];
          states = {
            warning = 30;
            critical = 15;
          };
        };

        network = {
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ifname}";
          format-disconnected = " Disconnected";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          on-click = "gnome-control-center wifi";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = " Muted";
          format-icons = {
            default = [ "" "" "" ];
            headphone = "";
            headset = "";
          };
          on-click = "gnome-control-center sound";
        };

        bluetooth = {
          format = " {status}";
          format-connected = " {device_alias}";
          format-disabled = "";
          tooltip-format = "{controller_alias}\t{controller_address}";
          on-click = "gnome-control-center bluetooth";
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
          tooltip-format-activated = "Idle inhibitor: ON";
          tooltip-format-deactivated = "Idle inhibitor: OFF";
        };

        tray = {
          spacing = 10;
        };
      };
    };
  };
}
