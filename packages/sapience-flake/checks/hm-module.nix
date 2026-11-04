# Module-level checks: evaluate `homeManagerModules.sapience` across a matrix of option
# combinations and assert on what it actually generates.
#
# WHY this is separate from the wrapper checks: everything in ../lib/wrappers.nix is reachable by
# running a script, but the module's real work is *configuration* -- which units exist, which
# activation steps run, what the payload seeder fetches and from where. Those are eval-time facts,
# and the failure mode they guard against is an option that silently stops taking effect. Nothing
# in a built script would notice.
#
# The matrix exists because this module's options interact. backgroundSync chooses between two
# help texts AND whether a timer exists AND whether the WSL notice is installed; the backend
# interacts with apiKeyFile to produce a warning; registerMcpServer gates an activation step that
# writes to a file shared with another module. Testing one configuration tests none of that.
#
# `activationPackage` is BUILT, not merely evaluated, for the default configuration: evaluation
# proves the options typecheck, while building proves home-manager can actually assemble the
# generation -- which is the step a consumer's `home-manager switch` performs first.
{
  pkgs,
  lib,
  home-manager,
  module,
}:
let
  mkHome =
    extra:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        module
        {
          home.username = "testuser";
          home.homeDirectory = "/home/testuser";
          home.stateVersion = "26.05";
        }
        extra
      ];
    };

  configs = {
    defaults = mkHome { programs.sapience.enable = true; };

    syncOn = mkHome {
      programs.sapience = {
        enable = true;
        backgroundSync = true;
        syncInterval = "*:0/30";
      };
    };

    noMcp = mkHome {
      programs.sapience = {
        enable = true;
        registerMcpServer = false;
      };
    };

    # The stub-host configuration, which is what makes a hermetic end-to-end install test
    # possible: if `host` ever stops reaching the payload seeder, ../tests/install-test.sh would
    # silently hit the live vendor instead of its local stub and pass for the wrong reason.
    stubHost = mkHome {
      programs.sapience = {
        enable = true;
        host = "http://127.0.0.1:8099";
      };
    };

    # A provider backend with no key file: the module is expected to WARN rather than fail, since
    # the timer has no shell environment to pick a key up from.
    openaiNoKey = mkHome {
      programs.sapience = {
        enable = true;
        backend = "openai";
      };
    };

    disabled = mkHome { programs.sapience.enable = false; };
  };

  # Reduce each evaluated configuration to plain data, so the assertions below read as data
  # assertions rather than as Nix gymnastics.
  factsOf = cfg: {
    packages = map (p: p.name or "?") cfg.config.home.packages;
    activations = lib.filter (lib.hasPrefix "sapience") (lib.attrNames cfg.config.home.activation);
    hasSyncService = cfg.config.systemd.user.services ? sapience-sync;
    hasTimer = cfg.config.systemd.user.timers ? sapience-sync;
    onCalendar =
      if cfg.config.systemd.user.timers ? sapience-sync then
        cfg.config.systemd.user.timers.sapience-sync.Timer.OnCalendar
      else
        null;
    warnings = cfg.config.warnings;
    payloadSeed =
      if cfg.config.home.activation ? sapiencePayload then
        cfg.config.home.activation.sapiencePayload.data
      else
        "";
  };

  facts = pkgs.writeText "sapience-module-facts.json" (
    builtins.toJSON (lib.mapAttrs (_: factsOf) configs)
  );
in
pkgs.runCommand "sapience-check-hm-module"
  {
    nativeBuildInputs = [ pkgs.jq ];
    # Built, not just evaluated -- see the header.
    defaultGeneration = configs.defaults.activationPackage;
    syncOnGeneration = configs.syncOn.activationPackage;
  }
  ''
    fail=0
    ok()  { echo "  ok   $1"; }
    bad() { echo "  FAIL $1" >&2; fail=1; }

    # want <jq-filter> <expected> <description>
    want() {
      local got
      got="$(jq -cr "$1" ${facts})"
      if [ "$got" = "$2" ]; then
        ok "$3"
      else
        bad "$3"
        echo "         filter:   $1" >&2
        echo "         expected: $2" >&2
        echo "         got:      $got" >&2
      fi
    }

    echo "==> the generation builds, not merely evaluates"
    for g in "$defaultGeneration" "$syncOnGeneration"; do
      if [ -e "$g/activate" ]; then
        ok "$(basename "$g") has an activate script"
      else
        bad "$g has no activate script"
      fi
    done

    # home.packages is not this module's alone -- home-manager puts its own baseline in there
    # (man-db, hm-session-vars.sh, the xdg-mime dummies), so the assertion is about which
    # SAPIENCE packages are present, not about the length of the list.
    OURS='map(select(startswith("sapience") or . == "sf1")) | sort | join(",")'

    echo "==> enable = true installs the three wrappers"
    want ".defaults.packages | $OURS" \
      "sapience,sapience-bootstrap,sf1" \
      "home.packages holds sapience, sf1 and sapience-bootstrap"

    echo "==> enable = false is inert"
    want ".disabled.packages | $OURS"        ''''''  "no sapience packages"
    want '.disabled.activations | length'    '0'     "no activation steps"
    want '.disabled.hasSyncService'          'false' "no sync service"
    want '.disabled.hasTimer'                'false' "no timer"

    echo "==> the sync service is always defined; the timer is opt-in"
    want '.defaults.hasSyncService' 'true'  "service exists with backgroundSync off"
    want '.defaults.hasTimer'       'false' "timer absent with backgroundSync off"
    want '.syncOn.hasSyncService'   'true'  "service exists with backgroundSync on"
    want '.syncOn.hasTimer'         'true'  "timer present with backgroundSync on"

    echo "==> syncInterval reaches the timer verbatim"
    want '.syncOn.onCalendar' '*:0/30' "OnCalendar is the configured expression"

    echo "==> the WSL notice is installed exactly when the timer is"
    want '.defaults.activations | index("sapienceWslSyncNotice") != null' 'false' \
      "absent with backgroundSync off"
    want '.syncOn.activations   | index("sapienceWslSyncNotice") != null' 'true' \
      "present with backgroundSync on"

    echo "==> registerMcpServer gates the ~/.claude.json merge"
    want '.defaults.activations | index("sapienceMcpServer") != null' 'true' \
      "present by default"
    want '.noMcp.activations    | index("sapienceMcpServer") != null' 'false' \
      "absent when registerMcpServer = false"

    echo "==> host parameterises the payload seeder (the stub-host mechanism)"
    want '.stubHost.payloadSeed | contains("http://127.0.0.1:8099/extract_local.py")' 'true' \
      "an overridden host is what gets fetched"
    want '.stubHost.payloadSeed | contains("https://app.spnc.ai/")' 'false' \
      "and the live vendor is NOT also fetched"
    want '.defaults.payloadSeed | contains("https://app.spnc.ai/extract_local.py")' 'true' \
      "the default host is the vendor"

    echo "==> a provider backend with no key file warns rather than failing"
    want '.openaiNoKey.warnings | length > 0' 'true' "a warning is emitted"
    want '.openaiNoKey.warnings | join(" ") | contains("apiKeyFile")' 'true' \
      "and it names the option to set"
    want '.defaults.warnings | length' '0' "the relay default warns about nothing"

    if [ "$fail" -ne 0 ]; then
      echo "hm-module check FAILED" >&2
      exit 1
    fi
    echo "all module-matrix assertions pass"
    touch $out
  ''
