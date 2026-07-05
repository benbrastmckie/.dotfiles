# Protonmail Bridge systemd service for local IMAP/SMTP.
_: {
  # ProtonMail Bridge systemd service for local IMAP/SMTP
  services.protonmail-bridge = {
    enable = true;
    logLevel = "info";
  };
}
