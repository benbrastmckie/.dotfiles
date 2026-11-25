# Overlay supplying `himalaya` from a frozen nixpkgs revision.
#
# The caller (flake.nix) passes the package set of the `nixpkgs-himalaya` input, which is
# locked to one revision and is not moved by `nix flake update`. That holds the CLI at
# v1.2.0, the release whose command tree and `--output json` shape the email wrappers in
# modules/home/email/agent-tools/ call directly, and whose `oauth2` and `keyring` cargo
# features config/himalaya-config.toml relies on. Taking the whole package set from that
# revision freezes the Rust toolchain together with the source, so the derivation is
# reproduced exactly rather than rebuilt against a newer compiler.
pkgs-himalaya: _final: _prev: {
  himalaya = pkgs-himalaya.himalaya.overrideAttrs (old: {
    cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=oauth2,keyring" ];
  });
}
