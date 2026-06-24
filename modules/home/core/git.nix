# Git version control configuration.
{ ... }:
{
  programs.git = {
    enable = true;
    settings.user.name = "benbrastmckie";
    settings.user.email = "benbrastmckie@gmail.com";
    signing.format = null;
  };
}
