# Mako notification daemon configuration.
{ ... }:
{
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      background-color = "#2e3440";
      text-color = "#eceff4";
      border-color = "#5e81ac";
      border-size = 2;
      icons = true;
      max-icon-size = 64;
    };
  };
}
