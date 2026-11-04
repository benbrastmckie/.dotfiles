# Standalone, shareable packaging of the Sapience (https://app.spnc.ai) client for
# NixOS/Home Manager: a generalized fork of a working flake maintained elsewhere, copied out so
# this directory evaluates and builds entirely on its own -- copy it anywhere, point a flake at
# it, and it works with no other input from the repository it was forked from.
#
# Two output sets:
#   - `homeManagerModules.sapience` -- CLI wrappers, an opt-in sync timer, activation-time
#     payload seeding, and MCP server registration into `~/.claude.json`. The full experience.
#   - `packages.<system>.{sapience,sf1,sapience-bootstrap}` -- the same three CLI wrappers alone,
#     for a consumer who does not use home-manager. This path installs NO systemd timer and
#     performs NO MCP registration -- both are home-manager-module-only concerns with no
#     equivalent here. See `README.md`'s "Using it" section.
#
# The vendor payload (`~/.sapience/*.py`) is deliberately NEVER packaged as a Nix derivation --
# upstream ships no releases, tags or content hashes and self-updates in the background, so a
# pinned `fetchurl` would break on the vendor's next edit and fight the client's own updater. Both
# output sets instead seed the payload with a plain `curl`, only when a file is absent. See
# `README.md`'s "The payload is deliberately mutable" section for why this is a property to
# document, not a defect to fix.
{
  description = "Sapience (app.spnc.ai) client packaging for NixOS/Home Manager -- a standalone, shareable fork";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Vendor defaults for the packages.<system>.* output set, matching
      # ./modules/sapience.nix's own option defaults exactly (relay backend, memory files on,
      # no token/API key file, sync timer off -- there is no timer here to turn on anyway).
      # stateDir is a literal, UNINTERPOLATED shell string: this output set has no evaluation-time
      # home directory to read, so path resolution happens entirely at runtime inside the
      # generated scripts, via the shell's own $HOME.
      mkWrappers =
        pkgs:
        import ./lib/wrappers.nix {
          inherit pkgs;
          inherit (pkgs) lib;
          stateDir = "$HOME/.sapience";
          host = "https://app.spnc.ai";
          backend = "relay";
          model = "";
          memoryFiles = true;
          tokenFile = null;
          backgroundSync = false;
          syncInterval = "hourly";
          # Left at its default `false`: this output set has no eval-time config to probe for an
          # Ollama server at all, so the ticker's runtime `systemctl --user is-active` probe
          # (inside ./lib/wrappers.nix) is the only gate that can ever apply to it.
        };
    in
    {
      homeManagerModules.sapience = ./modules/sapience.nix;
      homeManagerModules.default = self.homeManagerModules.sapience;

      # Lets a consumer build the wrappers with their own values directly, without going through
      # either output set above.
      lib.mkSapienceWrappers = import ./lib/wrappers.nix;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          wrappers = mkWrappers pkgs;
        in
        {
          inherit (wrappers) sapience sf1;
          sapience-bootstrap = wrappers.sapience-bootstrap;
          default = wrappers.sapience;
        }
      );
    };
}
