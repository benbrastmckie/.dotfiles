# SF-1 hub runner (per-person build, "ben").
#
# The worker half of SF-1 delegation. A background runner reads task cards from the shared
# Oliver + Ben room on app.spnc.ai and runs each one in a throwaway git worktree under
# ~/.local/state/sf1-hub-ben/hub/runner/work/, driven by this machine's own Claude Code login. A
# per-repo guard, installed as Claude Code hooks plus three .git hooks, blocks edits and commits
# that break a rule both parties accepted in the room, and fails closed when it cannot reach the
# rules.
#
# This is the missing piece recorded as an open question in the Linux install writeup kept with
# the client project: `/v1/sf1/delegate` answers 404 from here and no runner module is served
# alongside the client payload, so the worker side is distributed out of band. This module
# packages that out-of-band distribution.
#
# ## Why this module exists rather than the upstream flake
#
# The package ships its own flake plus a home-manager module. Both are declined, for two
# reasons that are specific to this machine:
#
#   - Its flake pins nixpkgs to nixos-25.05 while this configuration tracks nixos-26.05.
#     Consumed as an input it would evaluate and realise a second nixpkgs for a derivation whose
#     entire closure is python3 and git.
#   - A `path:` input aimed at a directory inside this very repository is fragile: it records an
#     absolute path in flake.lock and complains about a dirty tree.
#
# So the derivation and the unit are restated here, against the vendored source tree in
# packages/sf1-hub-ben/. The vendored bytes themselves are untouched, and the sha256 manifest
# the upstream build checks is checked here too, so a corrupted or edited vendor file fails the
# build rather than reaching the runner.
#
# ## Why install.sh is not used
#
# The package's plain-script route writes a systemd user unit into ~/.config/systemd/user. That
# directory is home-manager's, every entry in it a store symlink, so install.sh detects the
# conflict and refuses to write the unit -- after having already scattered a non-declarative
# copy of the binary under ~/.local/state. The flake/home-manager route, which this module is,
# is the only clean one here.
#
# ## What stays manual
#
# Everything that grants consent or holds a credential. `sf1-hub-ben token`, `attach`, `enable`
# and `golive` refuse to run without a real terminal -- `enable` additionally refuses to run
# from inside Claude Code or a script, and once a repo's guard is attached no Claude Code
# session can write that repo's consent marker at all. None of it belongs in an activation
# script, and none of it is attempted here. See packages/sf1-hub-ben/INSTALL-BEN.md for the
# sequence, and docs/sf1-hub.md for how it lands on this machine.
#
# ## What this module does and does not start
#
# Nothing. `autoStart` is false by default, so `home-manager switch` declares the unit and puts
# the CLI on PATH, and that is all. The runner makes zero network and zero model calls until
# `sf1-hub-ben golive` is run by hand, and refuses to serve at all (exit 78, which
# RestartPreventExitStatus turns into a clean stop rather than a restart loop) without a
# consented repo and an attached guard.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.sf1-hub-ben;

  # The vendored upstream tree, runtime files only: Oliver's test/ and tests/ directories (a
  # 96KB NixOS container build log among them) are not carried in this repository. Dropping
  # them changes nothing about the build -- vendor.lock.json covers vendor/ alone.
  src = ../../../packages/sf1-hub-ben;

  sf1-hub-ben = pkgs.stdenvNoCC.mkDerivation {
    pname = "sf1-hub-ben";
    version = lib.removeSuffix "\n" (builtins.readFile (src + "/VERSION"));
    inherit src;

    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/sf1-hub-ben $out/bin
      cp -R sf1-hub-ben hub_core_linux.py VERSION vendor vendor.lock.json $out/share/sf1-hub-ben/
      chmod 755 $out/share/sf1-hub-ben/sf1-hub-ben

      # Integrity gate, same contract as the upstream flake's: every file under vendor/ must
      # hash to what vendor.lock.json records, which is what pins these bytes to the ones
      # Oliver runs. A mismatch fails the build.
      ${pkgs.jq}/bin/jq -r '.files | to_entries[] | "\(.value)  vendor/\(.key)"' \
        vendor.lock.json > vendor.sha256
      ( cd $out/share/sf1-hub-ben && sha256sum -c "$NIX_BUILD_TOP/$sourceRoot/vendor.sha256" )

      # python3 is the interpreter and also what the payload shells out to; git is the only
      # other binary any of it invokes. Prefixed rather than set, so a card's own environment
      # still resolves its toolchain.
      makeWrapper ${pkgs.python3}/bin/python3 $out/bin/sf1-hub-ben \
        --add-flags $out/share/sf1-hub-ben/sf1-hub-ben \
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs.git
            pkgs.python3
          ]
        }

      runHook postInstall
    '';

    meta = {
      description = "SF-1 hub runner: room task cards run in worktrees, with a per-repo rule guard";
      platforms = lib.platforms.linux;
      mainProgram = "sf1-hub-ben";
    };
  };

  cfgDir = "${config.xdg.configHome}/sf1-hub-ben";
in
{
  options.services.sf1-hub-ben = {
    enable = lib.mkEnableOption ''
      the SF-1 hub runner. Declaring it installs the CLI and the unit; it refuses to serve
      without a per-repo consent marker typed by hand, and makes no network call before
      `sf1-hub-ben golive`
    '';

    claudeBin = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/etc/profiles/per-user/benjamin/bin/claude";
      description = ''
        Absolute path to the claude CLI the runner drives, exported as SF1_CLAUDE_BIN. Worth
        setting rather than leaving to PATH resolution: packages/claude-code.nix is an npx
        wrapper, so a bare `claude` can resolve into an ~/.npm/_npx/ cache path that moves
        whenever the cache is rebuilt.
      '';
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to start the runner at login (WantedBy=default.target). Off deliberately: the
        unit is meant to be started by hand after the consent and go-live steps, and a card
        runs Claude Code against a real checkout.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ sf1-hub-ben ];

    systemd.user.services.sf1-hub-ben = {
      Unit = {
        Description = "SF-1 hub runner (per person, Ben)";
        Documentation = "file://${sf1-hub-ben}/share/sf1-hub-ben/VERSION";
        # The kill switch is a file, so it holds across a restart, a relogin and a switch.
        # `sf1-hub-ben kill` writes it -- anyone may, an agent included -- and only
        # `sf1-hub-ben unkill`, in a terminal, removes it.
        ConditionPathExists = "!${cfgDir}/KILL";
        After = [ "network-online.target" ];
      };

      Service = {
        Type = "simple";
        # Restore owner-write on the staged runner copies before the core's `prepare` runs.
        #
        # `prepare` stages the three vendored hub-runner files into
        # <state>/hub/runner/bin/ with shutil.copy2, which preserves the source mode. Those
        # sources live in the Nix store, where every file is r-xr-xr-x -- Nix strips the write
        # bit from build output -- so the staged copies land read-only and the NEXT start's
        # copy2 cannot overwrite them: `PermissionError: [Errno 13]` on runner.py, which the
        # platform layer reports as `core prepare failed` and exits 78. The first start always
        # works and every later one fails, which makes it look like a consent or config fault
        # rather than a mode fault.
        #
        # This cannot happen on the package's own install route, where the sources sit in an
        # ordinary directory with write bits, so it is a NixOS-only consequence of packaging it
        # into the store rather than an upstream defect. The leading "-" keeps a first start,
        # when the directory does not exist yet, from failing the unit.
        ExecStartPre = "-${pkgs.coreutils}/bin/chmod -R u+w ${config.xdg.stateHome}/sf1-hub-ben/hub/runner/bin";
        ExecStart = "${sf1-hub-ben}/bin/sf1-hub-ben serve";
        Restart = "on-failure";
        RestartSec = 30;
        # Exit 78 (EX_CONFIG) is the runner's deliberate refusal -- no consented repo, kill
        # switch on, guard not attached, or the core cannot run cards with the guard hook.
        # Treating it as terminal is what keeps a refusal from becoming a restart loop.
        RestartPreventExitStatus = 78;
        KillMode = "control-group";
        TimeoutStopSec = 20;
        NoNewPrivileges = true;
        # Holds SAPIENCE_TOKEN (the runner reads the room with it) and any optional overrides:
        # SF1_HUB_CARD_REPO, SF1_HUB_PERSON, SF1_HUB_BASE. Written by `sf1-hub-ben token` at
        # mode 600, outside the store. The leading "-" keeps the unit startable before it
        # exists. The runner never hands a *_TOKEN or *_KEY variable down to a card.
        EnvironmentFile = "-${cfgDir}/env";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.git
              pkgs.python3
            ]
          }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
        ]
        ++ lib.optional (cfg.claudeBin != null) "SF1_CLAUDE_BIN=${cfg.claudeBin}";
      };

      Install = lib.mkIf cfg.autoStart { WantedBy = [ "default.target" ]; };
    };
  };
}
