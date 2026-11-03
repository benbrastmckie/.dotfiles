# Sapience (https://app.spnc.ai) on NixOS: CLI wrappers, payload bootstrap, hourly sync timer,
# and MCP registration -- a Linux-native replacement for the vendor's macOS-only installer
# (`bash <(curl -sL 'https://app.spnc.ai/install-local')`).
#
# Imported but OFF by default (the services/zotero-translation-server.nix precedent), because
# enabling it is a privacy decision about who processes this machine's AI transcripts. Enable
# with:
#   programs.sapience.enable = true;
#   programs.sapience.backend = "ollama";   # or "relay" / "anthropic" / "openai"
# then run `sapience-bootstrap` once to mint ~/.sapience/config.json and pick folders, and
# `home-manager switch` again so the MCP registration picks up the token.
#
# The Claude Code hooks (SessionStart briefing, SessionEnd receipt, Stop effect line) and the
# mcp__sapience__* permission grants live in config/claude/settings.json, NOT here: `hooks` and
# `permissions` are enforced keys in home.activation.claudeSettings (modules/home/core/
# dotfiles.nix), so anything the vendor installer wrote into the live file would be reverted on
# the next switch. They are guarded to be inert no-ops until sapience-bootstrap has run.
#
# WHY NOT A DERIVATION (do not "fix" this into a fetchurl package in a future pass): upstream
# ships no releases, tags, or hashes. The payload is ten .py files served live from
# app.spnc.ai/<name>.py, and the client self-updates two ways -- `sapience update` and a
# background `sapience_upkeep.py --auto-update` that mcp.py spawns on its own. A pinned
# fetchurl derivation would break its hash on every upstream push AND be fought by the
# self-updater on every run. So ~/.sapience/*.py is deliberately MUTABLE STATE here: the
# activation script below seeds the files only when they are ABSENT and never overwrites them.
# Nix owns the wrappers, the timer, and the registration; upstream owns the payload.
#
# The payload itself needs no packaging work: all ten files are pure Python 3 stdlib (urllib for
# HTTP, no third-party imports -- the `import mcp` lines refer to the vendor's own
# ~/.sapience/mcp.py, not the MCP SDK). The only external binary any of them invokes is an
# optional `git rev-parse` for a branch name, hence gitMinimal on the wrapper PATH.
#
# TOKEN HANDLING: the token is the ENTIRE credential for the account (app.spnc.ai/?token=<tok>
# signs you in with no second factor), so it is never placed in the Nix store or in this repo.
# Every client resolves it from ~/.sapience/config.json (mode 600) when SAPIENCE_TOKEN is unset
# -- see mcp.py:44, upload.py:57 -- so the wrappers and the timer pass no token at all, and the
# `tokenFile` option below is read at ACTIVATION time from a path outside the store.
#
# NOT WIRED (deliberate): the vendor installer also sets settings.json `statusLine` to
# `mcp.py --statusline`. That slot is already taken by hooks/statusline-push.sh, and the
# composite would have to be edited in the agent-system source store rather than the deployed
# .claude/ artifact (see rules/source-store-deploy-boundary.md). The three Claude Code hooks
# ARE wired, in config/claude/settings.json. To add the status segment by hand later, append
# `python3 ~/.sapience/mcp.py --statusline` output to that script in its source store.
#
# Module shape follows the services/cache-cleanup.nix and services/claude-session-reaper.nix
# precedent: oneshot service + timer, explicit PATH export, `starting`/`done` echo bracketing,
# and -- per the scripts/gmail-oauth2.nix cautionary precedent noted in claude-session-reaper.nix
# -- every external call guarded so a transient network failure can never leave the unit in a
# `failed` state and degrade the user systemd session.
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
  python = "${pkgs.python3}/bin/python3";

  # Fetched into stateDir when absent. The vendor installer treats the first group as fatal
  # (plain `curl -fsSL`) and the second as best-effort (`|| true`); that split is preserved so a
  # partial seed fails loudly instead of yielding a half-installed client.
  requiredPayload = [
    "upload.py"
    "extract_local.py"
    "sapience_redact.py"
    "sapience_filter.py"
    "sapience_capture.py"
    "sapience_adddir.py"
    "mcp.py"
  ];

  optionalPayload = [
    "sapience_devin.py"
    "sf1.py"
    "sapience_upkeep.py"
  ];

  # PATH for every wrapper and unit. gitMinimal backs upload.py's optional branch probe;
  # coreutils/curl back the payload seed and the client's own self-update path.
  runtimePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.curl
    pkgs.gitMinimal
    pkgs.python3
  ];

  # Mirrors the subcommand dispatch of the vendor's ~/bin/sapience shim, with the interpreter
  # and PATH resolved from the store instead of inherited from an interactive shell.
  sapienceCli = pkgs.writeShellScriptBin "sapience" ''
    export PATH="${runtimePath}:$PATH"
    export SAPIENCE_HOST="${cfg.host}"
    ${lib.optionalString (!cfg.memoryFiles) "export NO_MEMFILES=1"}

    SUB="''${1:-}"
    [ $# -gt 0 ] && shift

    # Help short-circuits the payload guard: unlike the vendor shim, this text carries the
    # NixOS-specific systemd instructions, which are exactly what is needed BEFORE bootstrap.
    case "$SUB" in
      ""|help|-h|--help) SAP_HELP=1 ;;
      *)                 SAP_HELP=0 ;;
    esac

    if [ "$SAP_HELP" = 0 ] && [ ! -f "${stateDir}/extract_local.py" ]; then
      echo "sapience: ${stateDir}/extract_local.py is missing -- run: sapience-bootstrap" >&2
      exit 1
    fi

    case "$SUB" in
      review)       exec ${python} "${stateDir}/extract_local.py" --review "$@" ;;
      pending)      exec ${python} "${stateDir}/extract_local.py" --pending "$@" ;;
      sync)         exec ${python} "${stateDir}/extract_local.py" --sync --yes "$@" ;;
      coverage)     exec ${python} "${stateDir}/extract_local.py" --coverage "$@" ;;
      backfill)     exec ${python} "${stateDir}/extract_local.py" --backfill "$@" ;;
      auto-approve) exec ${python} "${stateDir}/extract_local.py" --set-auto-approve "$@" ;;
      projects)     exec ${python} "${stateDir}/extract_local.py" --projects "$@" ;;
      reset)        exec ${python} "${stateDir}/extract_local.py" --reset "$@" ;;
      share)        exec ${python} "${stateDir}/extract_local.py" --share "$@" ;;
      join)         exec ${python} "${stateDir}/extract_local.py" --join "$@" ;;
      shares)       exec ${python} "${stateDir}/extract_local.py" --shares "$@" ;;
      unshare)      exec ${python} "${stateDir}/extract_local.py" --unshare "$@" ;;
      company)      exec ${python} "${stateDir}/extract_local.py" --company "$@" ;;
      recall)       exec ${python} "${stateDir}/extract_local.py" --recall "$@" ;;
      update)       exec ${python} "${stateDir}/extract_local.py" --update "$@" ;;
      stats)        exec ${python} "${stateDir}/mcp.py" --stats "$@" ;;
      status)       exec ${python} "${stateDir}/mcp.py" --status "$@" ;;
      adddoc)       exec ${python} "${stateDir}/mcp.py" --adddoc "$@" ;;
      adddir)       exec ${python} "${stateDir}/mcp.py" --adddir "$@" ;;
      sf1)          exec ${python} "${stateDir}/sf1.py" "$@" ;;
      ""|help|-h|--help)
        echo "sapience review [--all]       review pending notes and sync approved notes"
        echo "sapience pending              how many new findings are waiting"
        echo "sapience sync                 extract from new work now (stages for review)"
        echo "sapience coverage             see which work was read or skipped, and why"
        echo "sapience backfill [days]      catch up over a wide window (default 365)"
        echo "sapience auto-approve on|off  sync new notes without review"
        echo "sapience projects             choose which projects sync and require review"
        echo "sapience reset                fresh local start (hosted Sapience untouched)"
        echo "sapience stats                see how your Sapience is helping you"
        echo "sapience status               per-surface token check (terminal / Claude Code / Codex)"
        echo "sapience adddoc <file>        add a PDF/.txt/.md to your Sapience"
        echo "sapience adddir <dir>         add a directory of papers and notes"
        echo "sapience share <project> --with <name>   sync a workstream with a collaborator"
        echo "sapience join <channel-id> <project>     join a workstream shared with you"
        echo "sapience shares               list your sync channels"
        echo "sapience unshare <channel-id> leave a channel (pauses it for both sides)"
        echo "sapience recall <channel-id>  withdraw what you shared through a channel"
        echo "sapience company              your team workspace membership"
        echo "sapience update               fetch the latest client files from the vendor"
        echo "sf1 [\"question\"]              chat with your Sapience in the terminal"
        echo ""
        echo "NixOS notes: hourly sync is systemd.user (sapience-sync.timer), not launchd."
        echo "  status:  systemctl --user status sapience-sync.timer"
        echo "  pause:   systemctl --user disable --now sapience-sync.timer"
        echo "  run now: systemctl --user start sapience-sync.service"
        ;;
      -*)           exec ${python} "${stateDir}/extract_local.py" "$SUB" "$@" ;;
      *)
        echo "sapience: unknown command '$SUB' (see: sapience help)" >&2
        exit 2
        ;;
    esac
  '';

  sf1Cli = pkgs.writeShellScriptBin "sf1" ''
    export PATH="${runtimePath}:$PATH"
    export SAPIENCE_HOST="${cfg.host}"
    ${lib.optionalString (!cfg.memoryFiles) "export NO_MEMFILES=1"}

    if [ ! -f "${stateDir}/sf1.py" ]; then
      echo "sf1: ${stateDir}/sf1.py is missing -- run: sapience update" >&2
      exit 1
    fi

    exec ${python} "${stateDir}/sf1.py" "$@"
  '';

  # Interactive first-run: mint config.json (token + backend), seed the payload, then hand off to
  # the vendor's own folder-selection flow. Replaces install-local's macOS half entirely.
  #
  # The vendor's generic install-local carries INV="" / INVITE_OK="0" and REFUSES to run without
  # an invite code -- their published one-liner only works because it pre-writes config.json with
  # the token, which sends the installer down its REINSTALL=1 path. This does the same thing
  # directly, so no invite claim or install-report telemetry round-trip is involved.
  sapienceBootstrap = pkgs.writeShellScriptBin "sapience-bootstrap" ''
    set -euo pipefail
    export PATH="${runtimePath}:$PATH"

    umask 077
    mkdir -p "${stateDir}"
    chmod 700 "${stateDir}"

    if [ -f "${configFile}" ] && ${pkgs.jq}/bin/jq -e '.token // "" | length > 0' \
        "${configFile}" >/dev/null 2>&1; then
      echo "sapience-bootstrap: ${configFile} already carries a token; leaving it alone."
    else
      TOKEN="''${SAPIENCE_TOKEN:-}"
      ${lib.optionalString (cfg.tokenFile != null) ''
        if [ -z "$TOKEN" ] && [ -r "${toString cfg.tokenFile}" ]; then
          TOKEN="$(tr -d '[:space:]' < "${toString cfg.tokenFile}")"
        fi
      ''}
      if [ -z "$TOKEN" ]; then
        echo "Paste your Sapience token (the token= value from your private app.spnc.ai link)."
        printf "Token: "
        read -r TOKEN
      fi
      if [ -z "$TOKEN" ]; then
        echo "sapience-bootstrap: no token given; nothing written." >&2
        exit 1
      fi

      tmp="$(mktemp "${stateDir}/config.json.XXXXXX")"
      ${pkgs.jq}/bin/jq -n \
        --arg token "$TOKEN" \
        --arg backend "${cfg.backend}" \
        --arg host "${cfg.host}" \
        '{token: $token, backend: $backend, host: $host, auto_approve: false, hooks: true}' \
        > "$tmp"
      mv "$tmp" "${configFile}"
      chmod 600 "${configFile}"
      echo "sapience-bootstrap: wrote ${configFile} (backend ${cfg.backend})."
    fi

    echo "sapience-bootstrap: seeding client payload..."
    ${lib.concatMapStringsSep "\n" (f: ''
      if [ ! -f "${stateDir}/${f}" ]; then
        curl -fsSL "${cfg.host}/${f}" -o "${stateDir}/${f}"
        echo "  fetched ${f}"
      fi
    '') (requiredPayload ++ optionalPayload)}

    echo ""
    echo "Next: choose which projects Sapience may read (vendor's own interactive flow)."
    echo "Then run 'home-manager switch' once so the MCP server picks up the token."
    echo ""
    ${lib.optionalString (!cfg.memoryFiles) "export NO_MEMFILES=1"}
    SAPIENCE_HOST="${cfg.host}" exec ${python} "${stateDir}/extract_local.py" \
      --backend "${cfg.backend}"
  '';
in
{
  options.programs.sapience = {
    enable = lib.mkEnableOption "Sapience client (CLI wrappers, hourly sync timer, MCP server)";

    backend = lib.mkOption {
      type = lib.types.enum [
        "relay"
        "anthropic"
        "openai"
        "ollama"
      ];
      default = "ollama";
      description = ''
        Where transcript text is processed into knowledge objects. "relay" (the vendor default)
        sends redacted chunks through app.spnc.ai to Anthropic at the vendor's expense;
        "anthropic"/"openai" send raw text from this machine to that provider on your own API
        key; "ollama" keeps conversation text on this machine entirely and requires an Ollama
        server on 127.0.0.1:11434. Defaults to "ollama" here rather than the vendor's "relay"
        because this repository's Claude Code transcripts are the input corpus.
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
        Optional path to a file containing only the account token, read at activation time for a
        non-interactive bootstrap. Must be a path OUTSIDE the Nix store (a sops secret, or a
        mode-600 file in $HOME): the token is the whole credential for the account, so a store
        path would make it world-readable. When null, sapience-bootstrap prompts instead.
      '';
    };

    syncInterval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = ''
        systemd OnCalendar expression for the background extract-and-redact sync, matching the
        vendor LaunchAgent's StartInterval of 3600 seconds.
      '';
    };

    memoryFiles = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to let Sapience ingest "curated memory files" alongside session transcripts.
        When false, NO_MEMFILES=1 is exported for every client invocation.

        Defaults to FALSE here, against the vendor default, for a reason specific to this setup.
        Sapience's memory_files() (upload.py) walks each selected project root and ingests
        CLAUDE.md, MEMORY.md, AGENTS.md, EXTRACTED_MEMORY.md, docs/BACKLOG.md and
        .claude/rules/*.md, then tags the result with MEMFILE_CONF = 0.9 -- a confidence tier
        its own comment describes as "curated truth: rank/trust above session-extracted KOs".

        In this configuration those files are not curated truth. Every .claude/ tree in every
        repository is a generated deploy artifact, produced from the single source store at
        ~/.config/nvim/agent-system by the extension loader in
        ~/.config/nvim/lua/neotex/plugins/ai/shared/extensions/ -- which is exactly what
        rules/source-store-deploy-boundary.md is about. Over 20 repositories on this machine
        carry such a tree, and the generated CLAUDE.md even says so in its own header ("This
        file is generated automatically from loaded extensions"). Leaving this on would import
        twenty-odd near-identical copies of generated agent-system boilerplate at the HIGHEST
        trust tier, outranking real findings extracted from actual work. The transcripts are
        the signal here; the memory files are duplicated scaffolding.

        Turn this on only if the agent-system source store itself becomes the single selected
        project, where the files are authored rather than deployed.
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
    warnings = lib.optional (cfg.backend == "ollama" && !config.services.ollama.enable) (
      "programs.sapience.backend is \"ollama\" but services.ollama.enable is false, so there is "
      + "no inference server on 127.0.0.1:11434 and the hourly sync will extract nothing. "
      + "Enable services.ollamaModels (modules/home/services/ollama.nix), or pick another "
      + "backend."
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

    # Registers WITHOUT the token when config.json has none yet, since mcp.py falls back to
    # config.json (mcp.py:44); the env entry exists so `sapience status` can report a matching
    # per-surface token prefix, which it reads back out of this file (mcp.py:1713).
    #
    # Ordered after claudeMcpServers (modules/home/core/dotfiles.nix), which mutates the same
    # ~/.claude.json: activation entries run sequentially and both are read-modify-write jq
    # merges that preserve every other key, so either order is correct -- the explicit edge just
    # makes that independence intentional rather than incidental on DAG tie-breaking.
    home.activation.sapienceMcpServer = lib.mkIf cfg.registerMcpServer (
      config.lib.dag.entryAfter [ "writeBoundary" "claudeMcpServers" "sapiencePayload" ] ''
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

    # Replaces ~/Library/LaunchAgents/ai.coretx.sapience.plist. `--sync --yes` extracts and
    # redacts on-device and STAGES findings for review; it only posts when auto_approve is on in
    # config.json (`sapience auto-approve on|off`).
    #
    # No token is passed, exactly as the vendor LaunchAgent does it: its plist writer pops
    # SAPIENCE_TOKEN from the environment on purpose (install-local.sh:178) so the client reads
    # the single source of truth in config.json.
    systemd.user.services.sapience-sync = {
      Unit = {
        Description = "Sapience: extract and redact new AI session transcripts on-device";
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
                --sync --yes --backend "${cfg.backend}" || \
                echo "sapience-sync: sync returned non-zero (will retry next interval)"

              echo "sapience-sync: done"
              exit 0
            '';
          in
          "${script}";
      };
    };

    systemd.user.timers.sapience-sync = {
      Unit = {
        Description = "Timer for the Sapience on-device transcript sync";
        Requires = [ "sapience-sync.service" ];
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
