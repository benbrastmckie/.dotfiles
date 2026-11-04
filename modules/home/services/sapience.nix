# Sapience (https://app.spnc.ai) on NixOS: CLI wrappers, bootstrap, hourly sync timer and MCP
# registration, replacing the vendor's macOS-only installer.
#
# Critical: do not "fix" the payload into a fetchurl derivation. Upstream ships no releases or
# hashes and self-updates in the background, so ~/.sapience/*.py is deliberately mutable state
# that activation seeds only when absent. See docs/sapience.md.
#
# Note: the token is the entire credential for the account, so it never enters the Nix store or
# this repo -- every client falls back to ~/.sapience/config.json when SAPIENCE_TOKEN is unset.
# See docs/sapience.md.
#
# Note: the Claude Code hooks and mcp__sapience__* grants live in config/claude/settings.json
# because `hooks` and `permissions` are enforced keys in home.activation.claudeSettings;
# `statusLine` is deliberately left to hooks/statusline-push.sh. See docs/sapience.md.
#
# Module shape follows services/cache-cleanup.nix and services/claude-session-reaper.nix:
# oneshot plus timer, explicit PATH export, and every external call guarded so a transient
# network failure cannot leave the unit `failed` (the scripts/gmail-oauth2.nix precedent).
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
    pkgs.gawk
    pkgs.gitMinimal
    pkgs.gnugrep
    pkgs.procps
    pkgs.python3
    pkgs.systemd
    pkgs.util-linux
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

  # Interactive first-run: mint config.json, seed the payload, then hand off to the vendor's own
  # folder-selection flow. Writing config.json directly is what lets this skip the vendor
  # installer's invite claim, exactly as their published one-liner does. See docs/sapience.md.
  sapienceBootstrap = pkgs.writeShellScriptBin "sapience-bootstrap" ''
    set -euo pipefail
    export PATH="${runtimePath}:$PATH"

    mkdir -p "${stateDir}"

    # Note: a dedicated lock, NOT the vendor's shared .run.lock, so the only thing that can turn
    # a bootstrap away is another bootstrap. flock releases on process exit by any route --
    # normal, Ctrl-C, crash, SIGKILL -- so an interrupted run never leaves this held and there is
    # never a cooldown before retrying. See docs/sapience.md.
    if [ -z "''${SAPIENCE_BOOTSTRAP_LOCKED:-}" ]; then
      if ! flock -n "${stateDir}/.bootstrap.lock" true 2>/dev/null; then
        echo "sapience-bootstrap: another sapience-bootstrap is running; only one at a time." >&2
        echo "  Nothing to wait out: this lock is held by that live process and frees the" >&2
        echo "  instant it exits." >&2
        exit 1
      fi
      exec env SAPIENCE_BOOTSTRAP_LOCKED=1 \
        flock -n "${stateDir}/.bootstrap.lock" "$0" "$@"
    fi

    # An interactive run the user just typed takes precedence over the background one: stopping
    # the scheduled sync loses no work (the vendor leaves its files un-marked, so the next run
    # re-reads them) and frees the local model, rather than making the user wait or compete.
    if systemctl --user is-active --quiet sapience-sync.service 2>/dev/null; then
      echo "sapience-bootstrap: stopping the scheduled sync so this run has the model to itself"
      echo "  (its work is not lost; the timer picks it up again on schedule)."
      systemctl --user stop sapience-sync.service 2>/dev/null || true
    fi

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

    # Note: the vendor's extraction prints nothing between "Extracting knowledge from N sources"
    # and its result, and writes the staging queue only at the end, so a run that is working is
    # indistinguishable from one that has hung. This ticker is the stand-in: the ollama journal
    # logs one `release:` per completed model call, which is the only live signal there is.
    #
    # It writes a single rewritten line to stderr so it cannot corrupt the vendor's stdout, and
    # stays silent until the first call completes -- which keeps it out of the way of the
    # interactive folder picker that runs first.
    ticker() {
      started="$1"
      while :; do
        sleep 10
        jlog="$(journalctl --user -u ollama --no-pager -o cat --since "@$started" 2>/dev/null || true)"
        ended="$(printf '%s' "$jlog" | grep -cE 'slot[[:space:]]+release:' 2>/dev/null || true)"
        [ -n "$ended" ] || ended=0
        [ "$ended" -gt 0 ] || continue
        avg="$(printf '%s' "$jlog" \
          | grep -oE 'total time =[[:space:]]*[0-9.]+' \
          | grep -oE '[0-9.]+' \
          | tail -20 \
          | awk '{ t += $1; n++ } END { if (n) printf "%.0f", t / n / 1000 }' 2>/dev/null || true)"
        elapsed=$(($(date +%s) - started))
        printf '\r  extracting: %s chunks done%s, %dm%02ds elapsed   ' \
          "$ended" \
          "$([ -n "$avg" ] && printf ' (~%ss each)' "$avg")" \
          "$((elapsed / 60))" "$((elapsed % 60))" >&2
      done
    }

    ticker_pid=""
    cleanup() {
      if [ -n "$ticker_pid" ]; then
        kill "$ticker_pid" 2>/dev/null || true
        wait "$ticker_pid" 2>/dev/null || true
        printf '\r%*s\r' 60 "" >&2
      fi
    }
    trap cleanup EXIT INT TERM

    # Only when stderr is a terminal: a rewritten line is noise in a pipe or a log.
    if [ -t 2 ]; then
      ticker "$(date +%s)" &
      ticker_pid=$!
    fi

    # Hold the vendor's own .run.lock for the extraction only, so a timer firing mid-run is
    # skipped by the vendor's guard instead of competing. Best-effort: if it cannot be had we
    # continue anyway, because being slow beats refusing a run the user asked for.
    runner=()
    if flock -n "${stateDir}/.run.lock" true 2>/dev/null; then
      runner=(flock -n "${stateDir}/.run.lock")
    else
      echo "  note: a scheduled run holds .run.lock; continuing anyway (both will be slower)." >&2
    fi

    rc=0
    SAPIENCE_HOST="${cfg.host}" "''${runner[@]}" ${python} "${stateDir}/extract_local.py" \
      --backend "${cfg.backend}" \
      ${lib.optionalString (cfg.model != "") ''--model "${cfg.model}"''} || rc=$?
    cleanup
    ticker_pid=""
    exit "$rc"
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

    apiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/home/benjamin/.config/sapience/openai-key";
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
        still accept `max_tokens` work without editing vendor code. See docs/sapience.md.
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
        Whether to let Sapience ingest "curated memory files" (CLAUDE.md, AGENTS.md,
        .claude/rules/*.md and similar) alongside session transcripts. When false,
        NO_MEMFILES=1 is exported for every client invocation.

        Defaults to false, against the vendor default: every .claude/ tree here is a generated
        deploy artifact from the agent-system source store, duplicated across 20+ repositories,
        and Sapience would import all of them at its highest trust tier, outranking real
        findings. See docs/sapience.md.
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
        + "no inference server on 127.0.0.1:11434 and the hourly sync will extract nothing. "
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

    # Merges the provider key into config.json as the api_key/api_key_env pair the client reads.
    # Takes the vendor's .run.lock first: an extraction persists its own config.json (folders,
    # capture map), so an unsynchronised read-modify-write here could drop those choices.
    home.activation.sapienceApiKey = lib.mkIf (cfg.apiKeyFile != "") (
      config.lib.dag.entryAfter [ "writeBoundary" "sapiencePayload" ] ''
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
    # is correct, the edge just makes that independence intentional. See docs/sapience.md.
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

    # Replaces the vendor's launchd plist. `--sync --yes` extracts and redacts on-device and
    # stages findings; it only posts when auto_approve is on in config.json. No token is passed,
    # matching the vendor plist, so config.json stays the single source of truth.
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

    systemd.user.timers.sapience-sync = {
      Unit = {
        Description = "Timer for the Sapience on-device transcript sync";
        # Critical: deliberately NO `Requires = [ "sapience-sync.service" ]`, which the sibling
        # timer modules here do carry. Requires= stop-propagates, so `systemctl --user stop
        # sapience-sync.service` -- which sapience-bootstrap itself runs to claim the model --
        # would also deactivate this timer and silently end background learning. A timer
        # activates its same-named service through Timer.Unit by default, so the dependency buys
        # nothing. See docs/sapience.md.
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
