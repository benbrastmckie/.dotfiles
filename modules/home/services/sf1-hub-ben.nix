# SF-1 hub runner (per-person build, "ben").
#
# The worker half of SF-1 delegation. A background runner reads task cards from the shared
# Oliver + Ben room on app.spnc.ai and runs each one in a throwaway git worktree under
# ~/.local/state/sf1-hub-ben/hub/runner/work/, driven by this machine's own Claude Code login. A
# per-repo guard, installed as Claude Code hooks plus three .git hooks, blocks edits and commits
# that break a rule both parties accepted in the room. When it cannot reach the rules it
# suspends: the action is blocked and stays blocked until a person runs `guard.py unstop`.
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

  # Guard network knobs, declared durably here rather than left to `attach`'s installer
  # defaults (1.0 / 2.0 / 8.0, hardcoded in the vendored install.sh, guard.py's own
  # missing-config fallback, and whatever `sf1-hub-ben attach` writes) or a one-off hand edit
  # to a live config.json, which a future re-`attach` would silently revert.
  #
  #   - `guardNetTimeoutS = 15`: the guard's measured initiating admission failures are all
  #     `TimeoutError` against a 2-second socket timeout on a hosted TLS endpoint that was
  #     reachable both seconds before and seconds after each one -- a transient blip, not an
  #     outage. 15s gives the round trip real headroom without threatening `guardDeadlineS`
  #     (which must exceed it, below).
  #   - `guardCoalesceS = 300`: coalescing, not the timeout, is the lever on failure *volume*.
  #     At the installer default of 1.0s nearly every controlled action makes its own network
  #     round trip; at 300s a several-hundred-tool-call agent dispatch makes roughly one. The
  #     cost is freshness, paid deliberately: a rule accepted in the room does not bind here
  #     until the window expires, up to 5 minutes. Once the room's rule set stops being empty
  #     this should drop to roughly 60s by hand (cutting the freshness lag to at most 1 minute,
  #     at ~5x the round trips and so ~5x the exposure to the same per-round-trip failure rate)
  #     -- deliberately not automated, since Nix evaluation cannot see the room's live `n_kos`.
  #   - `guardDeadlineS = 20`: an internal SIGALRM around the whole rules-evaluation call, so
  #     it must stay above `guardNetTimeoutS` (otherwise the alarm pre-empts the socket
  #     timeout) and below the Claude Code hook's own 30s timeout (an attached repo's
  #     `.claude/settings.local.json` hook entries carry `"timeout": 30`).
  #   - The vendored guard's own `MIN_PULL_GAP_S = 10` floor, and its docstring's "network
  #     pulls are at least 10 s apart" claim, are enforced only in the legacy (pre-attached)
  #     `get_rules()` path -- attached mode's `admit()` never references `MIN_PULL_GAP_S`, so
  #     it is not a protective floor for this configuration. `guardCoalesceS` stays above it
  #     at both 300 and the eventual ~60 regardless, but that is this module's own choice, not
  #     an upstream guarantee -- see docs/sf1-hub.md for the upstream defect this is reported
  #     against.
  guardCoalesceS = 300;
  guardNetTimeoutS = 15;
  guardDeadlineS = 20;
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

    # Force-sets coalesce_s/net_timeout_s/deadline_s in every attached checkout's
    # oliver-ben-guard/config.json on every switch, so a re-`attach` (which rewrites
    # config.json from the installer defaults) cannot silently revert the chosen values.
    # Every other key -- me/source/sink/since_ts/key_file/require_accept/mode -- is left
    # untouched; this writes no consent marker, reads no token, and never opens key_file.
    # Same fail-safe shape as modules/home/core/dotfiles.nix's `claudeSettings`: a parse
    # guard before touching anything, write to a `mktemp` sibling, `mv` only on success, and
    # skip (never error) a checkout that is missing, unattached, or carries an unparseable
    # file. Honors `DRY_RUN` like that block and the reaper/watch scripts below.
    home.activation.sf1HubBenGuardConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      manifest="${config.xdg.stateHome}/sf1-hub-ben/manifest.json"

      if [[ -v DRY_RUN ]]; then
        echo "Would force coalesce_s=${toString guardCoalesceS} net_timeout_s=${toString guardNetTimeoutS} deadline_s=${toString guardDeadlineS} into every attached checkout's oliver-ben-guard/config.json"
      else
        if [ -f "$manifest" ] && ${pkgs.jq}/bin/jq -e . "$manifest" >/dev/null 2>&1; then
          checkouts=$(${pkgs.jq}/bin/jq -r '.checkouts // {} | keys[]' "$manifest" 2>/dev/null) || checkouts=""
          for co in $checkouts; do
            [ -d "$co" ] || continue
            gitCommonDir=$(${pkgs.git}/bin/git -C "$co" rev-parse --git-common-dir 2>/dev/null) || continue
            case "$gitCommonDir" in
              /*) ;;
              *) gitCommonDir="$co/$gitCommonDir" ;;
            esac
            cfgFile="$gitCommonDir/oliver-ben-guard/config.json"
            # Missing config.json: this checkout was never attached (or was detached since).
            # Nothing here should create one.
            [ -f "$cfgFile" ] || continue
            ${pkgs.jq}/bin/jq -e . "$cfgFile" >/dev/null 2>&1 || continue
            tmpFile="$(mktemp "$(dirname "$cfgFile")/config.json.XXXXXX")"
            if ${pkgs.jq}/bin/jq \
              --argjson c ${toString guardCoalesceS} \
              --argjson n ${toString guardNetTimeoutS} \
              --argjson d ${toString guardDeadlineS} \
              '.coalesce_s = $c | .net_timeout_s = $n | .deadline_s = $d' \
              "$cfgFile" > "$tmpFile" 2>/dev/null && [ -s "$tmpFile" ]; then
              mv "$tmpFile" "$cfgFile"
            else
              rm -f "$tmpFile"
            fi
          done
        fi
      fi
    '';

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

    # Makes a fail-closed marker visible without reading log.jsonl. Both `stopped.json`
    # (admission suspend, written by `admit()`) and `breaker.json` (sender breaker, written by
    # `send()`) are the same no-retry shape, one network error away -- see
    # docs/sf1-hub.md and the upstream write-up for the defect this surface works around.
    # Notify-only by design (D7): no one-click action, since mako's single-default-action
    # idiom needs `notify-send --wait -t 0`, which inside a timer-driven oneshot would hold the
    # unit active indefinitely and block later timer activations. The notification instead
    # carries the exact remediation command to paste. Module shape and failure discipline
    # modeled on claude-session-reaper.nix: explicit PATH export, every external call guarded,
    # the script always exits 0.
    systemd.user.services.sf1-hub-ben-guard-watch = {
      Unit = {
        Description = "Notify on a new oliver-ben-guard stopped.json/breaker.json marker (notify-only)";
      };
      Service = {
        Type = "oneshot";
        ExecStart =
          let
            script = pkgs.writeShellScript "sf1-hub-ben-guard-watch" ''
                            export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
                            # Deliberately no `set -e`: every external call below is individually guarded so
                            # a single race or missing tool can never trip the whole script into a `failed`
                            # unit state. The script always reaches `exit 0`.

                            echo "sf1-hub-ben-guard-watch: starting"

                            manifest="${config.xdg.stateHome}/sf1-hub-ben/manifest.json"
                            watchDir="${config.xdg.stateHome}/sf1-hub-ben/watch"
                            mkdir -p "$watchDir" 2>/dev/null || true

                            if [ ! -f "$manifest" ] || ! ${pkgs.jq}/bin/jq -e . "$manifest" >/dev/null 2>&1; then
                              echo "sf1-hub-ben-guard-watch: no (or unparseable) manifest, nothing to watch"
                              echo "sf1-hub-ben-guard-watch: done"
                              exit 0
                            fi

                            checkouts=$(${pkgs.jq}/bin/jq -r '.checkouts // {} | keys[]' "$manifest" 2>/dev/null) || checkouts=""

                            for co in $checkouts; do
                              [ -d "$co" ] || continue
                              gitCommonDir=$(${pkgs.git}/bin/git -C "$co" rev-parse --git-common-dir 2>/dev/null) || continue
                              case "$gitCommonDir" in
                                /*) ;;
                                *) gitCommonDir="$co/$gitCommonDir" ;;
                              esac
                              guardStateDir="$gitCommonDir/oliver-ben-guard"
                              safeCo=''${co//\//_}

                              for marker in stopped.json breaker.json; do
                                markerFile="$guardStateDir/$marker"
                                [ -f "$markerFile" ] || continue

                                mtime=$(${pkgs.coreutils}/bin/stat -c %Y "$markerFile" 2>/dev/null) || continue
                                stateFile="$watchDir/$safeCo.$marker.mtime"
                                lastMtime=$(cat "$stateFile" 2>/dev/null) || lastMtime=""

                                # Same mtime as last run: already notified, nothing new.
                                if [ "$mtime" = "$lastMtime" ]; then
                                  continue
                                fi

                                markerError=$(${pkgs.jq}/bin/jq -r '.error // "unknown error"' "$markerFile" 2>/dev/null) || markerError="unknown error"
                                if [ "$marker" = "stopped.json" ]; then
                                  remedy="python3 ${sf1-hub-ben}/share/sf1-hub-ben/vendor/guard/guard.py unstop --root $co"
                                  kind="admission suspended"
                                else
                                  remedy="python3 ${sf1-hub-ben}/share/sf1-hub-ben/vendor/guard/guard.py send --reset --root $co"
                                  kind="sender breaker open"
                                fi

                                # Record the mtime regardless of whether the notification itself reaches a
                                # bus -- an unreachable DBus session is not a reason to re-raise the same
                                # marker on every future run.
                                echo "$mtime" > "$stateFile" 2>/dev/null || true

                                if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
                                  ${pkgs.libnotify}/bin/notify-send -a sf1-hub-ben -u critical -t 0 \
                                    "sf1-hub-ben: $kind ($co)" \
                                    "$markerError

              $remedy" 2>/dev/null || true
                                  echo "sf1-hub-ben-guard-watch: notified $marker for $co"
                                else
                                  echo "sf1-hub-ben-guard-watch: no DBus session bus, skipping notification for $marker on $co"
                                fi
                              done
                            done

                            echo "sf1-hub-ben-guard-watch: done"
                            exit 0
            '';
          in
          "${script}";
      };
    };

    systemd.user.timers.sf1-hub-ben-guard-watch = {
      Unit = {
        Description = "Timer for periodic sf1-hub-ben guard marker watch (notify-only)";
        # Note: no `Requires = [ "sf1-hub-ben-guard-watch.service" ]` here -- same reasoning as
        # claude-session-reaper.nix's timer: Requires= stop-propagates, so
        # `systemctl --user stop sf1-hub-ben-guard-watch.service` would also deactivate this
        # timer and silently end the schedule.
      };
      Timer = {
        OnCalendar = "*:0/2";
        Persistent = true;
        RandomizedDelaySec = 20;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
