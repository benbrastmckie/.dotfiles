# Email client tooling: himalaya, cyrus-sasl/xoauth2, msmtp, and utilities
{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs; [
    # Email Testing Tools
    swaks # Swiss Army Knife for SMTP testing
    mailutils # Email utilities
    # protonmail-bridge is now managed by services.protonmail-bridge

    # Himalaya email client with full feature set
    (pkgs-unstable.himalaya.overrideAttrs (oldAttrs: {
      cargoBuildFlags = (oldAttrs.cargoBuildFlags or [ ]) ++ [ "--features=oauth2,keyring" ];
    })) # Himalaya with OAuth2 support

    # Custom cyrus-sasl with XOAUTH2 plugin built-in and mbsync with proper linking
    (let
      cyrus-sasl-with-xoauth2 = pkgs.cyrus_sasl.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [ pkgs.cyrus-sasl-xoauth2 ];
        postInstall = (oldAttrs.postInstall or "") + ''
          # Copy XOAUTH2 plugin to the main SASL plugin directory
          cp ${pkgs.cyrus-sasl-xoauth2}/lib/sasl2/* $out/lib/sasl2/
        '';
      });

      mbsync-with-xoauth2 = pkgs-unstable.isync.override {
        cyrus_sasl = cyrus-sasl-with-xoauth2;
      };
    in mbsync-with-xoauth2)

    pkgs.cyrus-sasl-xoauth2 # Keep for reference
    msmtp # For sending emails via SMTP
    pass # Password manager for storing OAuth2 tokens
    gnupg # Required for pass to work
    w3m # Terminal web browser for viewing HTML emails
    curl # For OAuth2 token refresh
    jq # For parsing JSON responses
    # Note: libsecret is already installed system-wide in configuration.nix
    # Required for running mcp-hub JavaScript tools
    # MCP-Hub is now managed by the home module
  ];
}
