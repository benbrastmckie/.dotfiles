# Miscellaneous home-manager settings:
# - home.activation (mail directory setup)
# - services.home-manager.autoExpire (HM generation GC)
# - systemd.user.sessionVariables
# - systemd.user.startServices
{ config, pkgs, ... }:
{
  # Create mail directory for Himalaya with proper structure
  home.activation.createMailDir = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p /home/benjamin/Mail/Gmail/INBOX/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Sent"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Drafts"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Trash"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/All Mail"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Spam"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/EuroTrip"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/CrazyTown"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Gmail/Letters"/{cur,new,tmp}
    # Logos Labs maildir structure
    mkdir -p /home/benjamin/Mail/Logos/INBOX/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Sent"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Drafts"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Trash"/{cur,new,tmp}
    mkdir -p "/home/benjamin/Mail/Logos/Archive"/{cur,new,tmp}
  '';

  # Automatic user-level home-manager generation expiry + store GC. The
  # system-level nix.gc (configuration.nix) only collects root profiles and
  # never touches user HM generations, which were pinning months of old
  # closures in the store. See task 63.
  services.home-manager.autoExpire = {
    enable = true;
    timestamp = "-30 days";
    frequency = "weekly";
    store = {
      cleanup = true;
      options = "--delete-older-than 30d";
    };
  };

  # Add systemd user session variables for broader availability
  systemd.user.sessionVariables = {
    SASL_PATH = "${pkgs.cyrus-sasl-xoauth2}/lib/sasl2:${pkgs.cyrus_sasl}/lib/sasl2";
    LITERATURE_DIR = "/home/benjamin/Projects/Literature";
  };

  # Enable systemd integration
  systemd.user.startServices = "sd-switch";
}
