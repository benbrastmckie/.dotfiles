# Sapience (https://app.spnc.ai) client packaging for NixOS/Home Manager: CLI wrappers, bootstrap,
# an opt-in sync timer and MCP registration, replacing the vendor's macOS-only installer.
#
# Critical: do not "fix" the payload into a fetchurl derivation. Upstream ships no releases or
# hashes and self-updates in the background, so ~/.sapience/*.py is deliberately mutable state
# that activation seeds only when absent. See ../README.md.
#
# Note: the token is the entire credential for the account, so it never enters the Nix store --
# every client falls back to ~/.sapience/config.json when SAPIENCE_TOKEN is unset. See
# ../README.md.
#
# Note: this module does not deliver Claude Code's SessionStart/SessionEnd/Stop hooks or the
# mcp__sapience__* permission grants -- those are Claude Code *settings* concerns with no
# equivalent delivery mechanism in this flake. See ../README.md's "Known gap" section for the
# exact commands to add them to your own settings file yourself.
#
# Module shape: oneshot service plus timer, explicit PATH export, and every external call guarded
# so a transient network failure cannot leave the unit `failed`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.sapience;

  stateDir = "${config.home.homeDirectory}/.sapience";
  configFile = "${stateDir}/config.json";

  # The three CLI wrappers, plus the handful of constants (python/runtimePath/the payload lists)
  # that this module's OWN config glue below (payload-seed activation, MCP server registration,
  # the sync systemd service) also needs. All of it lives in ../lib/wrappers.nix, parameterized
  # by plain arguments rather than by module reads, so one set of script bodies backs both this
  # home-manager module and this flake's standalone packages.<system>.* outputs.
  wrappers = import ../lib/wrappers.nix {
    inherit pkgs lib stateDir;
    inherit (cfg)
      host
      backend
      model
      memoryFiles
      tokenFile
      backgroundSync
      syncInterval
      ;
    # Eval-time half of the ticker gate (see ../lib/wrappers.nix for the runtime half) --
    # mirrors the existing `warnings` predicate below exactly.
    ollamaEnabled = config.services.ollama.enable;
  };

  inherit (wrappers)
    python
    runtimePath
    requiredPayload
    optionalPayload
    wslDetect
    userManagerProbe
    wslPrereqLines
    ;

  sapienceCli = wrappers.sapience;
  sf1Cli = wrappers.sf1;
  sapienceBootstrap = wrappers.sapience-bootstrap;
in
{
  options.programs.sapience = {
    enable = lib.mkEnableOption "Sapience client (CLI wrappers, sync unit, MCP server)";

    backend = lib.mkOption {
      type = lib.types.enum [
        "relay"
        "anthropic"
        "openai"
        "ollama"
      ];
      default = "relay";
      description = ''
        Where transcript text is processed into knowledge objects. "relay" (this default, and
        the vendor's own default) sends redacted chunks through app.spnc.ai to Anthropic at the
        vendor's expense -- no local server and no API key required, the zero-setup choice for a
        stranger enabling this module. "anthropic"/"openai" send raw text from this machine to
        that provider on your own API key; "ollama" keeps conversation text on this machine
        entirely and requires an Ollama server on 127.0.0.1:11434. "relay" is also the one
        backend where the vendor itself sees redacted transcript chunks before any review gate --
        see ../README.md's "Privacy" section.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "https://app.spnc.ai";
      description = "Sapience API host, used for the payload seed and all client sync calls.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/sapience_token";
      description = ''
        Optional path to a file containing only the account token, which makes
        `sapience-bootstrap` non-interactive. Read by `sapience-bootstrap` WHEN YOU RUN IT, not
        during home-manager activation: activation seeds the payload and registers the MCP
        server, while ~/.sapience/config.json is created by the bootstrap. Setting this option
        alone therefore leaves no token on disk until the bootstrap runs once.

        Must be a path OUTSIDE the Nix store (a sops secret, or a mode-600 file in $HOME): the
        token is the whole credential for the account, so a store path would make it
        world-readable. When null, sapience-bootstrap prompts instead.
      '';
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/run/secrets/sapience_openai_key";
      description = ''
        Path to a file containing ONLY the provider API key, for the "openai" and "anthropic"
        backends. Read at activation time and merged into ~/.sapience/config.json as the
        api_key / api_key_env pair the client expects -- which is the vendor's own mechanism
        (_config_api_key in extract_local.py) and the only one that reaches every invocation
        path, including the timer, which has no shell environment.

        Typed as str, not path, on purpose: a Nix path literal would be copied into the
        world-readable store. Give an absolute path as a quoted string -- a mode-600 file in
        $HOME, or a sops-nix secret under /run/secrets.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "gpt-4o-mini";
      description = ''
        Passed as --model, overriding the client's per-backend default (llama3.1 for ollama,
        gpt-4o-mini for openai, claude-haiku-4-5 for anthropic). Empty keeps the default.

        Critical for openai: the client sends the deprecated `max_tokens` parameter, which
        reasoning models (o-series and the GPT-5 family) reject with HTTP 400. Only models that
        still accept `max_tokens` work without editing vendor code. See ../README.md.
      '';
    };

    backgroundSync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to install the timer that runs extraction on a schedule. When false, nothing
        reads a transcript unless you ask: run `sapience sync` in the terminal, or start
        `sapience-sync.service` by hand for a run that does not tie up a shell. The unit itself
        is always defined, so that manual trigger exists either way.

        Defaults to false, against the vendor's hourly LaunchAgent. Extraction spends real
        money or real CPU on every run and reads whatever the folder picker has selected, so it
        happens on request rather than because the module was enabled.

        On WSL2 this option alone is not sufficient: WSL starts no systemd user manager by
        default, so the timer is created but never fires until `[boot] systemd=true` is set in
        /etc/wsl.conf and `loginctl enable-linger $USER` has been run. Activation detects this
        and prints both steps. See ../README.md's "Platforms" section.
      '';
    };

    syncInterval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = ''
        systemd OnCalendar expression for the background extract-and-redact sync, matching the
        vendor LaunchAgent's StartInterval of 3600 seconds. Takes effect only when
        `backgroundSync` is true; on its own it schedules nothing.
      '';
    };

    memoryFiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to let Sapience ingest "curated memory files" (CLAUDE.md, AGENTS.md,
        .claude/rules/*.md and similar) alongside session transcripts. When false,
        NO_MEMFILES=1 is exported for every client invocation.

        Defaults to true, matching the vendor default. Consider setting this false if your own
        CLAUDE.md/AGENTS.md files are generated scaffolding rather than hand-authored "curated
        truth" -- Sapience ingests memory files at its highest trust tier, outranking
        session-extracted findings, which is the wrong call for scaffolding duplicated across
        many repositories. See ../README.md.
      '';
    };

    registerMcpServer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Merge mcpServers.sapience into ~/.claude.json at user scope, so Claude Code sessions can
        search and ask the vault. Token is read at activation from config.json, never from the
        store. Set false to leave ~/.claude.json untouched.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # A warning, not an assertion: the sync unit already degrades gracefully (it logs a non-zero
    # return and retries next interval rather than failing), so a missing inference server must
    # not block an unrelated rebuild. This surfaces the cross-module dependency without the
    # modules being coupled -- services/ollama.nix is never auto-enabled from here.
    warnings =
      lib.optional (cfg.backend == "ollama" && !config.services.ollama.enable) (
        "programs.sapience.backend is \"ollama\" but services.ollama.enable is false, so there is "
        + "no inference server on 127.0.0.1:11434, so every sync will extract nothing. "
        + "Enable services.ollamaModels (modules/home/services/ollama.nix), or pick another "
        + "backend."
      )
      ++ lib.optional ((cfg.backend == "openai" || cfg.backend == "anthropic") && cfg.apiKeyFile == "") (
        "programs.sapience.backend is \""
        + cfg.backend
        + "\" but apiKeyFile is unset, so no "
        + "provider key reaches the timer (which has no shell environment) and every sync will "
        + "exit \"needs a key\". Set programs.sapience.apiKeyFile."
      );

    home.packages = [
      sapienceCli
      sf1Cli
      sapienceBootstrap
    ];

    # Seed only what is absent -- see the MUTABLE STATE note in this file's header. A failed
    # fetch is reported and skipped, never fatal: activation must not break on a vendor outage,
    # and sapience-bootstrap / `sapience update` can always complete the set later.
    home.activation.sapiencePayload = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [[ -v DRY_RUN ]]; then
        echo "Would seed missing Sapience client files into ${stateDir}"
      else
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${stateDir}"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod 700 "${stateDir}"
        ${lib.concatMapStringsSep "\n" (f: ''
          if [ ! -f "${stateDir}/${f}" ]; then
            if ${pkgs.curl}/bin/curl -fsSL -m 30 "${cfg.host}/${f}" \
                -o "${stateDir}/${f}.tmp" 2>/dev/null; then
              ${pkgs.coreutils}/bin/mv "${stateDir}/${f}.tmp" "${stateDir}/${f}"
            else
              ${pkgs.coreutils}/bin/rm -f "${stateDir}/${f}.tmp"
              echo "sapience: could not fetch ${f} (run 'sapience update' later)"
            fi
          fi
        '') (requiredPayload ++ optionalPayload)}
      fi
    '';

    # Self-heal a token field that holds the private LINK rather than its token= value.
    #
    # sapience-bootstrap rejects that paste at the source, but config.json is mutable state the
    # vendor client and the web onboarding also write, so the repair belongs here too. Every
    # consumer reads the field verbatim -- including sapienceMcpServer below, which copies it
    # into ~/.claude.json -- so one link-shaped value breaks Claude Code's sapience tools as
    # well as the sync, and the server's answers name neither cause: 401 on /v1/stats, and 403
    # "an invite code is needed to build a new Sapience" on /ingest-kos, because a token that
    # opens no brain reads server-side as a request to create one. Ordered before
    # sapienceMcpServer so the registration always copies a repaired value.
    # See ../README.md.
    home.activation.sapienceTokenRepair =
      config.lib.dag.entryAfter [ "writeBoundary" "sapiencePayload" ]
        ''
          if [[ -v DRY_RUN ]]; then
            echo "Would repair a link-shaped token in ${configFile}"
          elif [ -f "${configFile}" ]; then
            raw="$(${pkgs.jq}/bin/jq -r '.token // ""' "${configFile}" 2>/dev/null || true)"
            if [ -n "$raw" ] && ! printf '%s' "$raw" | ${pkgs.gnugrep}/bin/grep -qE '^[A-Za-z0-9_-]+$'; then
              fixed="$(printf '%s' "$raw" \
                | ${pkgs.coreutils}/bin/tr -d '[:space:]' \
                | ${pkgs.gnused}/bin/sed -e 's/.*[?&]token=//' -e 's/^token=//' -e 's/[&#].*$//')"
              if printf '%s' "$fixed" | ${pkgs.gnugrep}/bin/grep -qE '^[A-Za-z0-9_-]{8,}$'; then
                tmp="$(${pkgs.coreutils}/bin/mktemp "${stateDir}/config.json.XXXXXX")"
                if ${pkgs.jq}/bin/jq --arg t "$fixed" '.token = $t' "${configFile}" > "$tmp" \
                  && [ -s "$tmp" ]; then
                  ${pkgs.coreutils}/bin/mv "$tmp" "${configFile}"
                  ${pkgs.coreutils}/bin/chmod 600 "${configFile}"
                  echo "sapience: ${configFile} stored a link rather than a token; repaired it."
                else
                  ${pkgs.coreutils}/bin/rm -f "$tmp"
                  echo "sapience: could not repair the token in ${configFile}"
                fi
              else
                echo "sapience: ${configFile} holds a token that is not token-shaped and could not"
                echo "  be repaired automatically. Re-run sapience-bootstrap to replace it."
              fi
            fi
          fi
        '';

    # Merges the provider key into config.json as the api_key/api_key_env pair the client reads.
    # Takes the vendor's .run.lock first: an extraction persists its own config.json (folders,
    # capture map), so an unsynchronised read-modify-write here could drop those choices.
    home.activation.sapienceApiKey = lib.mkIf (cfg.apiKeyFile != "") (
      config.lib.dag.entryAfter [ "writeBoundary" "sapiencePayload" "sapienceTokenRepair" ] ''
        keyFile="${cfg.apiKeyFile}"
        keyEnv="${
          if cfg.backend == "openai" then
            "OPENAI_API_KEY"
          else if cfg.backend == "anthropic" then
            "ANTHROPIC_API_KEY"
          else
            ""
        }"
        if [[ -v DRY_RUN ]]; then
          echo "Would merge $keyEnv from $keyFile into ${configFile}"
        elif [ -z "$keyEnv" ]; then
          echo "sapience: backend ${cfg.backend} takes no provider key; ignoring apiKeyFile"
        elif [ ! -r "$keyFile" ]; then
          echo "sapience: $keyFile is not readable yet; no provider key written."
          echo "  Create it (mode 600, key only), then re-run home-manager switch."
        elif [ ! -f "${configFile}" ]; then
          echo "sapience: ${configFile} does not exist yet; run sapience-bootstrap first,"
          echo "  then re-run home-manager switch to store the provider key."
        else
          key="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$keyFile")"
          if [ -z "$key" ]; then
            echo "sapience: $keyFile is empty; no provider key written."
          elif ! ${pkgs.util-linux}/bin/flock -w 10 "${stateDir}/.run.lock" true 2>/dev/null; then
            echo "sapience: an extraction holds .run.lock; provider key not written."
            echo "  Re-run home-manager switch once it finishes."
          else
            tmp="$(${pkgs.coreutils}/bin/mktemp "${stateDir}/config.json.XXXXXX")"
            if ${pkgs.util-linux}/bin/flock -w 10 "${stateDir}/.run.lock" \
              ${pkgs.jq}/bin/jq --arg k "$key" --arg e "$keyEnv" \
                '.api_key = $k | .api_key_env = $e' "${configFile}" > "$tmp" \
              && [ -s "$tmp" ]; then
              ${pkgs.coreutils}/bin/mv "$tmp" "${configFile}"
              ${pkgs.coreutils}/bin/chmod 600 "${configFile}"
              echo "sapience: stored $keyEnv in ${configFile} (mode 600)"
            else
              ${pkgs.coreutils}/bin/rm -f "$tmp"
              echo "sapience: could not write the provider key into ${configFile}"
            fi
          fi
        fi
      ''
    );

    # Registers without a token until config.json has one, since mcp.py falls back to that file;
    # the env entry exists so `sapience status` reports matching per-surface fingerprints.
    # Ordered after claudeMcpServers, which merges into the same ~/.claude.json -- either order
    # is correct, the edge just makes that independence intentional. See ../README.md.
    home.activation.sapienceMcpServer = lib.mkIf cfg.registerMcpServer (
      config.lib.dag.entryAfter
        [
          "writeBoundary"
          "claudeMcpServers"
          "sapiencePayload"
          "sapienceTokenRepair"
        ]
        ''
          claudeJson="${config.home.homeDirectory}/.claude.json"
          if [[ -v DRY_RUN ]]; then
            echo "Would merge mcpServers.sapience into $claudeJson"
          else
            sapToken=""
            if [ -r "${configFile}" ]; then
              sapToken="$(${pkgs.jq}/bin/jq -r '.token // ""' "${configFile}" 2>/dev/null || true)"
            fi
            [ -f "$claudeJson" ] || echo '{}' > "$claudeJson"
            tmpFile="$(${pkgs.coreutils}/bin/mktemp "${config.home.homeDirectory}/.claude.json.XXXXXX")"
            if ${pkgs.jq}/bin/jq \
              --arg tok "$sapToken" \
              --arg py "${python}" \
              --arg script "${stateDir}/mcp.py" \
              --arg host "${cfg.host}" \
              '.mcpServers.sapience = ({
                 type: "stdio",
                 command: $py,
                 args: [$script],
                 env: ({ SAPIENCE_HOST: $host }
                       + (if ($tok | length) > 0 then { SAPIENCE_TOKEN: $tok } else {} end))
               })' \
              "$claudeJson" > "$tmpFile"; then
              ${pkgs.coreutils}/bin/mv "$tmpFile" "$claudeJson"
              ${pkgs.coreutils}/bin/chmod u+w "$claudeJson"
            else
              ${pkgs.coreutils}/bin/rm -f "$tmpFile"
              echo "sapience: could not merge mcpServers.sapience into $claudeJson"
            fi
          fi
        ''
    );

    # Tell a WSL2 user, at activation, that the timer they just turned on will not fire yet.
    #
    # This is the one place where the home-manager module cannot deliver what the option
    # promises. `backgroundSync = true` defines a systemd.user timer, and under WSL2 a user
    # manager exists only after two steps that are both outside this module's reach:
    # `[boot] systemd=true` in /etc/wsl.conf (the Windows side of the boundary, not a path
    # home-manager owns) and `loginctl enable-linger $USER` (a host-level grant a user activation
    # cannot make for itself). home-manager will report the timer as created either way, so
    # without this warning the failure mode is silent and slow: weeks of nothing syncing, with a
    # config that looks correct and a `home-manager switch` that reported success.
    #
    # Deliberately NOT fatal and deliberately not a `warnings` entry. Eval-time `warnings` cannot
    # see the WSL kernel marker at all -- whether a user manager is up is a property of the
    # machine at activation, not of the configuration -- so the probe has to run here. Read-only,
    # so no $DRY_RUN_CMD: there is nothing to not-do in a dry run, and a dry run is exactly when
    # a user most wants to see this.
    home.activation.sapienceWslSyncNotice = lib.mkIf cfg.backgroundSync (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${runtimePath}:$PATH"

        ${wslDetect}
        ${userManagerProbe}

        if sapience_is_wsl && ! sapience_has_user_manager; then
          echo "sapience: backgroundSync is on, but no systemd user manager is running (WSL2)."
          echo "  sapience-sync.timer is defined and will NOT fire until this is fixed."
        ${wslPrereqLines}
          echo "  Meanwhile 'sapience sync' works normally and loses nothing."
        fi
      ''
    );

    # The on-demand run, and what the timer activates when backgroundSync is on. Always defined,
    # so `systemctl --user start sapience-sync.service` is available with no schedule in place.
    # `--sync --yes` extracts and redacts on-device and stages findings; it only posts when
    # auto_approve is on in config.json. No token is passed, matching the vendor plist, so
    # config.json stays the single source of truth.
    systemd.user.services.sapience-sync = {
      Unit = {
        Description = "Sapience: extract and redact new AI session transcripts on-device";
        # Critical: `keep-old`, so sd-switch does not restart this on every activation. It is a
        # long oneshot (a capped run is ~50 model calls at tens of seconds each on CPU), and a
        # restart both kills an in-flight extraction and blocks `home-manager switch` until the
        # new one finishes. The timer picks up a changed definition on its next fire.
        X-SwitchMethod = "keep-old";
        # No token means no account to sync; a condition failure is reported without entering an
        # active state, and systemd re-evaluates it on every start, so bootstrapping later
        # recovers cleanly rather than latching a bogus success.
        ConditionPathExists = configFile;
      };
      Service = {
        Type = "oneshot";
        ExecStart =
          let
            script = pkgs.writeShellScript "sapience-sync" ''
              export PATH="${runtimePath}:$PATH"
              export SAPIENCE_HOST="${cfg.host}"
              ${lib.optionalString (!cfg.memoryFiles) "export NO_MEMFILES=1"}
              # Deliberately no `set -e`: a vendor outage or an in-progress self-update must not
              # leave this unit `failed` (see the gmail-oauth2.nix precedent cited in the header).
              # The script always reaches `exit 0`.

              echo "sapience-sync: starting (backend ${cfg.backend})"

              if [ ! -f "${stateDir}/extract_local.py" ]; then
                echo "sapience-sync: client payload missing, nothing to do"
                echo "sapience-sync: done"
                exit 0
              fi

              ${python} "${stateDir}/extract_local.py" \
                --sync --yes --backend "${cfg.backend}" \
                ${lib.optionalString (cfg.model != "") ''--model "${cfg.model}"''} || \
                echo "sapience-sync: sync returned non-zero (will retry next interval)"

              echo "sapience-sync: done"
              exit 0
            '';
          in
          "${script}";
      };
    };

    # Opt-in, via backgroundSync. The service above stays defined regardless, so a manual
    # `systemctl --user start sapience-sync.service` works without a schedule existing.
    systemd.user.timers.sapience-sync = lib.mkIf cfg.backgroundSync {
      Unit = {
        Description = "Timer for the Sapience on-device transcript sync";
        # Critical: deliberately NO `Requires = [ "sapience-sync.service" ]`, which the sibling
        # timer modules here do carry. Requires= stop-propagates, so `systemctl --user stop
        # sapience-sync.service` -- which sapience-bootstrap itself runs to claim the model --
        # would also deactivate this timer and silently end background learning. A timer
        # activates its same-named service through Timer.Unit by default, so the dependency buys
        # nothing. See ../README.md.
      };
      Timer = {
        OnCalendar = cfg.syncInterval;
        Persistent = true;
        RandomizedDelaySec = 300;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
