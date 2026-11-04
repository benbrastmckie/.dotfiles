{
  description = "system config";

  inputs = {
    # Pinned to the stable release channel for near-100% binary cache hits
    # (Hydra fully builds the stable channel). nixpkgs-unstable stays on
    # unstable to feed pkgs-unstable + nix-ai-tools.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # NOTE: this input floats on leanprover/lean4's default branch and is NOT the toolchain
    # source for the Comparator proof-verification packaging (packages/comparator.nix,
    # packages/lean-toolchain-bin.nix). That packaging fetches a specific, pinned release
    # tarball for the exact tag Comparator's own lean-toolchain file names
    # (v4.34.0-rc2) directly via fetchurl, since building Lean 4 from source via this input
    # is unnecessary weight for that use case. This input is kept, unpinned, for a possible
    # future consumer that wants to build Lean HEAD from source; it is currently unused.
    lean4 = {
      url = "github:leanprover/lean4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Niri input - ENABLED (dual-session with GNOME)
    niri = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lectic = {
      url = "github:gleachkr/lectic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Aeneas (Charon + Aeneas): Rust MIR -> LLBC -> Lean/Coq/F*/HOL4 verification pipeline.
    # Deliberately NOT `inputs.nixpkgs.follows`-ed: upstream pins its own nixpkgs for the
    # OCaml 5.2 toolchain Aeneas needs, and Charon pins its own Rust nightly; following our
    # nixpkgs (nixos-26.05) would break the build. Pinned to the exact revision the Logos
    # Verification toolchain expects (its charon-pin names charon a5591f6), so any move is
    # deliberate and made in lockstep with Verification's own pin. Binaries are substituted
    # from hacl.cachix.org (configured in modules/system/nix.nix) rather than compiled.
    aeneas.url = "github:AeneasVerif/aeneas/227f4e7ac70d687a6b1a4871b3304f5a1c6994bf";
    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix for age-based secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    # Note: MCPHub is loaded via lazy.nvim, not as a flake input
    # home-manager = {
    #   url = "github:nix-community/home-manager/release-23.11";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      niri,
      lectic,
      nix-ai-tools,
      sops-nix,
      aeneas,
      ...
    }:

    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";

      # Configure unstable packages with allowUnfree
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "claude-code"
            ];
        };
      };

      # Import overlays from dedicated files
      claudeSquadOverlay = import ./overlays/claude-squad.nix;
      # unstable-packages overlay is curried: it needs pkgs-unstable partially applied
      unstablePackagesOverlay = import ./overlays/unstable-packages.nix pkgs-unstable;
      pythonPackagesOverlay = import ./overlays/python-packages.nix;

      # Common nixpkgs configuration
      nixpkgsConfig = {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          claudeSquadOverlay
          unstablePackagesOverlay
          pythonPackagesOverlay
        ];
      };

      # Apply the overlays to the stable package set
      pkgs = import nixpkgs nixpkgsConfig;

      username = "benjamin";
      name = "Ben";

      # Shared specialArgs for both NixOS-integrated and standalone home-manager.
      # Both paths receive identical extraSpecialArgs so home.nix evaluates consistently.
      hmExtraSpecialArgs = {
        inherit pkgs-unstable;
        lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
        inherit nix-ai-tools;
        # Resolved Aeneas-flake packages, named to avoid shadowing pkgs.charon/pkgs.aeneas
        # (nixpkgs may carry same-named attributes).
        aeneas-charon = aeneas.packages.${system}.charon;
        aeneas-aeneas = aeneas.packages.${system}.aeneas;
      };

      # mkHost: factory for standard NixOS host configurations.
      # Accepts { hostname, extraModules ? [], extraSpecialArgs ? {} }.
      mkHost = import ./lib/mkHost.nix {
        inherit nixpkgs home-manager sops-nix;
        inherit
          nixpkgsConfig
          username
          name
          pkgs-unstable
          lectic
          nix-ai-tools
          aeneas
          system
          ;
        root = self;
      };
    in
    {
      # Two home-manager paths exist in parallel:
      #   1. NixOS-integrated (below): manages /etc/profiles/per-user/<user>/
      #      Updated by: sudo nixos-rebuild switch --flake .#<host>
      #   2. Standalone homeConfigurations (bottom of file): manages ~/.nix-profile/
      #      Updated by: home-manager switch --flake .#benjamin
      # Both evaluate home.nix with the same overlays. update.sh runs both
      # in sequence to keep them in sync. ~/.nix-profile/ takes PATH priority.
      nixosConfigurations = {
        nandi = mkHost {
          hostname = "nandi";
          extraModules = [ ./hosts/nandi/default.nix ];
        };

        hamsa = mkHost {
          hostname = "hamsa";
          extraModules = [ ./hosts/hamsa/default.nix ];
        };

        garuda = mkHost { hostname = "garuda"; };

        # ISO configuration — uses nixpkgs CD template; kept explicit (not via mkHost)
        # because it needs the installer module and custom iso specialArgs (niri).
        iso = lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            { networking.hostName = "nixos-iso"; }

            # sops-nix for age-based secrets management
            sops-nix.nixosModules.sops

            # Apply our unstable packages overlay globally
            { nixpkgs = nixpkgsConfig; }

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${username} = import ./home.nix;
                extraSpecialArgs = hmExtraSpecialArgs;
              };
            }
            ./hosts/iso/default.nix
          ];
          specialArgs = {
            inherit username;
            inherit name;
            inherit pkgs-unstable;
            inherit niri; # Enabled for dual-session with GNOME
            inherit system; # Consumed by hosts/iso/default.nix (nixpkgs.hostPlatform)
            lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
          };
        };

        # USB Installer configuration
        usb-installer = mkHost {
          hostname = "usb-installer";
          extraModules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./hosts/usb-installer/default.nix
          ];
          extraSpecialArgs = {
            inherit niri;
          };
        };
      };

      # Standalone home-manager: manages ~/.nix-profile/
      # Enables quick home-only rebuilds without sudo (home-manager switch --flake .#benjamin).
      # Must stay in sync with the NixOS-integrated home-manager above — update.sh runs both.
      homeConfigurations = {
        benjamin = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
          ];
          extraSpecialArgs = {
            inherit username;
            inherit name;
          }
          // hmExtraSpecialArgs;
          # Both the NixOS-integrated and standalone paths now resolve lectic to the built
          # package via hmExtraSpecialArgs (see the shared `lectic = lectic.packages.${system}...`
          # expression above); no per-path override is needed.
        };
      };

      # RFC 166 official formatter. pkgs.nixfmt-rfc-style is a deprecated alias of this same
      # derivation in this repo's pinned nixpkgs (nixos-26.05) — use pkgs.nixfmt directly to
      # avoid the deprecation warning. Run via `nix fmt`.
      formatter.${system} = pkgs.nixfmt;

      # -------------------------------------------------------------------------------------
      # The CI gate, expressed as flake checks rather than as steps in .github/workflows/ci.yml.
      #
      # WHY HERE AND NOT THERE: a lint that exists only in a workflow file cannot be run locally
      # without re-typing it, so the first time you learn it is unhappy is after the push. That
      # is precisely how this repo went five consecutive pushes red. As checks, `nix flake check`
      # becomes ONE command that reproduces CI exactly -- by hand, from the pre-push hook
      # (scripts/install-git-hooks.sh), or on a runner, where ci.yml now does nothing else.
      #
      # The same argument is already written out in packages/sapience-flake/checks/default.nix
      # for that flake ("evidence only the CI can reproduce is not evidence"); this is the root
      # flake catching up to its own sub-flake.
      #
      # DELIBERATELY NOT COVERED: building a host's system closure or the home-manager
      # generation. `nix flake check` already EVALUATES every nixosConfigurations.* entry, which
      # is what catches a mistyped option or a broken module; BUILDING them pulls multi-gigabyte
      # closures that do not fit a GitHub runner's disk. The real build is what
      # scripts/update.sh does on the machine itself.
      # -------------------------------------------------------------------------------------
      checks.${system} =
        let
          # Each check sees only the files its linter actually reads, so it is rerun when those
          # change and reused from the store otherwise.
          nixSrc = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              (lib.fileset.fileFilter (f: f.hasExt "nix") ./.)
              ./statix.toml # statix reads its config from the working directory
            ];
          };

          shellSrc = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              (lib.fileset.fileFilter (f: f.hasExt "sh") ./scripts)
              (lib.fileset.fileFilter (f: f.hasExt "sh") ./tests)
              ./.githooks # tracked git hooks; named for git, so they carry no .sh extension
            ];
          };

          mkCheck =
            name: src: deps: script:
            pkgs.runCommandLocal "check-${name}" { nativeBuildInputs = deps; } ''
              cd ${src}
              ${script}
              touch "$out"
            '';
        in
        {
          statix = mkCheck "statix" nixSrc [ pkgs.statix ] "statix check";

          # Two things here are LOAD-BEARING, and the step this replaces had neither, which is
          # why deadnix never once reported anything in this repo:
          #
          #   1. --fail. Without it deadnix prints its findings and still exits 0.
          #   2. Feeding paths via `find` rather than `--exclude <glob> .`. `--exclude` takes a
          #      VARIADIC list, so a trailing `.` is parsed as one more exclude pattern (which
          #      excludes the entire tree), and its matching is literal-path, not glob -- so
          #      'hosts/*/hardware-configuration.nix' never matched anything either way.
          #
          # hosts/*/hardware-configuration.nix is skipped because nixos-generate-config writes
          # it and stamps it "Do not modify this file!"; its unused `pkgs` argument is upstream's
          # to make. The find predicate covers any host added later with no edit here.
          deadnix = mkCheck "deadnix" nixSrc [ pkgs.deadnix ] ''
            find . -name '*.nix' -not -path './hosts/*/hardware-configuration.nix' -print0 \
              | xargs -0 deadnix --fail
          '';

          # An explicit file list, not a directory argument: nixfmt deprecated the latter.
          nixfmt = mkCheck "nixfmt" nixSrc [ pkgs.nixfmt ] ''
            find . -name '*.nix' -print0 | xargs -0 nixfmt --check
          '';

          # `nix flake check` traverses nixosConfigurations, so home.nix IS evaluated -- but only
          # through the NixOS-integrated home-manager path. `homeConfigurations` is not a
          # standard flake output, so Nix prints "checking flake output 'homeConfigurations'"
          # and then traverses nothing. scripts/update.sh builds that standalone path too (it is
          # what owns ~/.nix-profile), so without this check a `home-manager switch --flake
          # .#benjamin` could break with CI fully green.
          #
          # unsafeDiscardStringContext is what keeps this an EVALUATION check. Reading .drvPath
          # forces the generation to be evaluated end to end -- which is the coverage wanted,
          # since that is where a bad option or missing attribute surfaces -- but interpolating
          # it with its string context intact would make the check depend on the derivation's
          # OUTPUTS, i.e. actually build the multi-gigabyte closure. Discarding the context
          # keeps the evaluation and drops the build.
          home-eval = pkgs.runCommandLocal "check-home-eval" { } ''
            printf '%s\n' ${lib.escapeShellArg (builtins.unsafeDiscardStringContext self.homeConfigurations.benjamin.activationPackage.drvPath)} > "$out"
          '';

          # scripts/ and tests/ had no static analysis at all before this. The first run found a
          # silently inert --no-check flag in scripts/update.sh (SC2034).
          shellcheck = mkCheck "shellcheck" shellSrc [ pkgs.shellcheck ] ''
            find . -type f \( -name '*.sh' -o -path './.githooks/*' \) -print0 \
              | xargs -0 shellcheck --external-sources
          '';
        };

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
