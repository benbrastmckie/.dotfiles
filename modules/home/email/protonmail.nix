# Protonmail Bridge systemd service for local IMAP/SMTP.
{ ... }:
{
  # ProtonMail Bridge systemd service for local IMAP/SMTP
  services.protonmail-bridge = {
    enable = true;
    logLevel = "info";
  };
}
