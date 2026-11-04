# Standalone, shareable packaging of the Sapience (https://app.spnc.ai) client for
# NixOS/Home Manager. This directory evaluates and builds entirely on its own -- copy it
# anywhere, point a flake at it, and it works with no other inputs.
#
# Platforms: Linux (x86_64, aarch64), including Windows via WSL2, which reports those same
# systems. Not macOS -- see the comment on `systems` below. Scheduled sync carries two
# WSL-only prerequisites this flake cannot set for the user; ./lib/wrappers.nix probes for WSL
# at runtime and names them rather than printing timer commands that would silently never fire.
#
# Two output sets:
#   - `homeManagerModules.sapience` -- CLI wrappers, an opt-in sync timer, activation-time
#     payload seeding, and MCP server registration into `~/.claude.json`. The full experience.
#   - `packages.<system>.{sapience,sf1,sapience-bootstrap,sapience-register-mcp}` -- the same CLI
#     wrappers alone, for a consumer who does not use home-manager. MCP registration is available
#     here as a command the user runs; what this path has no equivalent for is the systemd timer,
#     which is a home-manager concern. See `README.md`'s "Using it" section.
#
# The vendor payload (`~/.sapience/*.py`) is deliberately NEVER packaged as a Nix derivation --
# upstream ships no releases, tags or content hashes and self-updates in the background, so a
# pinned `fetchurl` would break on the vendor's next edit and fight the client's own updater. Both
# output sets instead seed the payload with a plain `curl`, only when a file is absent. See
# `README.md`'s "The payload is deliberately mutable" section for why this is a property to
# document, not a defect to fix.
{
  description = "Standalone Sapience (app.spnc.ai) client packaging for Linux/NixOS/Home Manager, WSL2 included";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  # TEST-ONLY input, reached from `checks.<system>.hm-module` and from nowhere else. Neither
  # output set touches it: `homeManagerModules.sapience` is a bare module file that the
  # consumer's OWN home-manager evaluates, and `packages.<system>.*` has nothing to do with
  # home-manager at all.
  #
  # It is an input rather than an ad-hoc `builtins.getFlake` so the module test is PINNED by
  # flake.lock and reproducible, which is the whole claim these checks are making. Nix fetches
  # inputs lazily, so building a package does not download it. A consumer who would rather not
  # carry a second home-manager node in their own lock can collapse it onto theirs:
  #
  #   inputs.sapience-flake.inputs.home-manager.follows = "home-manager";
  inputs.home-manager.url = "github:nix-community/home-manager/release-26.05";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      # Linux only -- which is also the whole Windows story, not a gap in it. There is no
      # native-Windows Nix (the upstream project ships none; nova-nix and libnix are third-party
      # reimplementations that do not run nixpkgs' stdenv), so a Windows consumer runs this under
      # WSL2, whose kernel reports x86_64-linux, or aarch64-linux on an ARM Windows machine. Both
      # are already in this list, so WSL2 needs no entry of its own.
      #
      # Darwin is absent deliberately, not merely untested: `runtimePath` in ./lib/wrappers.nix
      # carries pkgs.systemd, which REFUSES TO EVALUATE off Linux ("not available on the
      # requested hostPlatform"), so packages.*-darwin.* could never have built; and every
      # scheduling path here is systemd.user, with no launchd equivalent written. Re-adding
      # Darwin means guarding that dependency, branching the help text, and writing launchd
      # agents -- not extending this list. See README.md's "Platforms" section.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
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
          inherit (wrappers)
            sapience
            sf1
            sapience-bootstrap
            sapience-register-mcp
            ;
          default = wrappers.sapience;
        }
      );

      # Hermetic behavioural tests of the generated wrappers: shellcheck + bash -n, golden help
      # output on both platforms and both scheduling configurations, and unit tests for the token
      # and platform helpers. `nix flake check` runs all of them, which is the point -- the
      # evidence is reproducible by anyone evaluating this flake, not just by its CI.
      # ./checks/default.nix documents what these deliberately do NOT cover (the vendor, a timer
      # actually firing, WSL end-to-end).
      checks = forAllSystems (
        system:
        import ./checks {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (nixpkgs) lib;
          inherit home-manager;
          module = self.homeManagerModules.sapience;
        }
      );
    };
}
