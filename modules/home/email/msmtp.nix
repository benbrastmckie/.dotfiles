# Sendmail-style outgoing mail: generates ~/.config/msmtp/config and installs the package.
#
# Cross-file contract:
#   - The two accounts mirror the outgoing settings in modules/home/email/aerc.nix (host,
#     port, user, and the keyring lookup used for the password). Change them together.
#   - Each account's `from` line is what envelope-from selection matches on. A caller that
#     runs the binary with `-t --read-envelope-from` gets the account whose `from` equals
#     the message's From address; an address matching neither account falls through to the
#     default, which is gmail.
#   - The logos account talks to Proton Bridge on the loopback interface: plaintext connect,
#     then STARTTLS. The Bridge certificate is self-signed and carries an IP subject
#     alternative name only, so `host` must stay the literal 127.0.0.1 (not `localhost`),
#     and verification succeeds only on a host whose system bundle trusts the Bridge CA,
#     as hosts/hamsa/default.nix does.
#   - The generated file holds no secret: passwords are read from the keyring at send time.
_: {
  programs.msmtp = {
    enable = true;
    configContent = ''
      defaults
      auth on
      tls on
      tls_trust_file /etc/ssl/certs/ca-certificates.crt

      account gmail
      host smtp.gmail.com
      port 465
      tls_starttls off
      from benbrastmckie@gmail.com
      user benbrastmckie@gmail.com
      passwordeval "secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com"

      account logos
      host 127.0.0.1
      port 1025
      tls_starttls on
      from benjamin@logos-labs.ai
      user benjamin@logos-labs.ai
      passwordeval "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"

      account default : gmail
    '';
  };
}
