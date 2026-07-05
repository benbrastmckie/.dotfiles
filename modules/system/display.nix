# Font configuration and display settings.
{ pkgs, ... }:
{
  # Font configuration
  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji # Renamed from noto-fonts-emoji in nixos-unstable
      liberation_ttf
      fira-code
      fira-code-symbols
    ];
    fontconfig = {
      defaultFonts = {
        serif = [
          "Liberation Serif"
          "Noto Serif"
        ];
        sansSerif = [
          "Liberation Sans"
          "Noto Sans"
        ];
        monospace = [
          "Fira Code"
          "Liberation Mono"
        ];
      };
    };
  };
}
