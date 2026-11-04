# Sapience (https://app.spnc.ai) on NixOS: CLI wrappers, bootstrap, an opt-in sync timer and MCP
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
# network failure cannot leave the unit `failed`, which would degrade the whole systemd --user
# session rather than just this unit.
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
        ${
          if cfg.backgroundSync then
            ''
              echo "NixOS notes: scheduled sync is systemd.user (sapience-sync.timer), not launchd."
              echo "  schedule: ${cfg.syncInterval}"
              echo "  status:   systemctl --user status sapience-sync.timer"
              echo "  pause:    systemctl --user disable --now sapience-sync.timer"
              echo "  run now:  systemctl --user start sapience-sync.service"
            ''
          else
            ''
              echo "NixOS notes: nothing syncs on a schedule -- extraction runs only when you ask."
              echo "  run now:  sapience sync"
              echo "  detached: systemctl --user start sapience-sync.service"
              echo "  schedule: set programs.sapience.backgroundSync = true in home.nix"
            ''
        }
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

    # Reduce a paste to a bare token. Accepts the token itself, the whole private link
    # ("https://app.spnc.ai/?token=XXXX"), a quoted paste, or a <...>-wrapped one, because the
    # link is what the invite email actually puts on the clipboard. Prints "" when nothing
    # token-shaped can be recovered.
    sap_token_clean() {
      printf '%s' "$1" \
        | tr -d '[:space:]' \
        | sed -e 's/^[<"'"'"']*//' -e 's/[>"'"'"']*$//' \
        | sed -e 's/.*[?&]token=//' -e 's/^token=//' -e 's/[&#].*$//'
    }

    # A token is letters, digits and underscores only. This is what separates a real token from
    # a pasted link: a URL keeps its ':' '/' '?' '=' and fails here.
    sap_token_ok() {
      printf '%s' "$1" | grep -qE '^[A-Za-z0-9_-]{8,}$'
    }

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

    # Note: the stored-token guard VALIDATES rather than merely testing for non-emptiness.
    # Pasting the whole private link ("https://app.spnc.ai/?token=XXXX") instead of its token=
    # value writes a 43-character URL into the token field. Every client then authenticates with
    # it: /v1/stats answers 401 and /ingest-kos answers 403 "an invite code is needed to build a
    # new Sapience", because a token that opens no brain reads server-side as a request to make
    # one. A bare length test called that a token and left it in place forever, so the failure
    # only surfaced after a full extraction had already run. See docs/sapience.md.
    if [ -f "${configFile}" ] && \
        TOKEN="$(${pkgs.jq}/bin/jq -r '.token // ""' "${configFile}" 2>/dev/null)" && \
        [ -n "$TOKEN" ] && sap_token_ok "$TOKEN"; then
      echo "sapience-bootstrap: ${configFile} already carries a token; leaving it alone."
    else
      if [ -n "''${TOKEN:-}" ]; then
        # A stored token that failed the shape test: repair it in place when the paste was a
        # link, rather than making the user find and re-enter it.
        REPAIRED="$(sap_token_clean "$TOKEN")"
        if [ -n "$REPAIRED" ] && sap_token_ok "$REPAIRED"; then
          echo "sapience-bootstrap: ${configFile} stored a link rather than a token; repairing it."
          TOKEN="$REPAIRED"
        else
          echo "sapience-bootstrap: ${configFile} stores something that is not a token; replacing it."
          TOKEN=""
        fi
      fi

      if [ -z "''${TOKEN:-}" ]; then
        TOKEN="''${SAPIENCE_TOKEN:-}"
      fi
      ${lib.optionalString (cfg.tokenFile != null) ''
        if [ -z "$TOKEN" ] && [ -r "${toString cfg.tokenFile}" ]; then
          TOKEN="$(tr -d '[:space:]' < "${toString cfg.tokenFile}")"
        fi
      ''}
      if [ -z "$TOKEN" ]; then
        echo "Paste your Sapience token, or the whole private app.spnc.ai link -- either works."
        printf "Token or link: "
        read -r TOKEN
      fi

      # Normalise before validating: accept the bare token, the full link, a quoted paste, or a
      # <...>-wrapped one, so the single most likely first-run mistake is simply absorbed.
      TOKEN="$(sap_token_clean "$TOKEN")"

      if [ -z "$TOKEN" ]; then
        echo "sapience-bootstrap: no token given; nothing written." >&2
        exit 1
      fi
      if ! sap_token_ok "$TOKEN"; then
        echo "sapience-bootstrap: that does not look like a Sapience token." >&2
        echo "  Expected the token= value from your private app.spnc.ai link (letters, digits" >&2
        echo "  and underscores only), or that whole link so this can read the value out of it." >&2
        exit 1
      fi

      # Verify against the server BEFORE writing anything, so a token the server does not
      # recognise costs a second here rather than a full extraction that fails at the upload.
      printf "sapience-bootstrap: checking the token with %s ... " "${cfg.host}"
      code="$(curl -sS -o /dev/null -w '%{http_code}' -m 20 \
        -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) sapience-client/1.0' \
        "${cfg.host}/v1/stats?token=$TOKEN" 2>/dev/null || echo "000")"
      case "$code" in
        200)
          echo "ok."
          ;;
        000)
          echo "could not reach the host."
          echo "sapience-bootstrap: ${cfg.host} is unreachable, so the token could not be checked."
          echo "  Continuing anyway -- the token looks well formed and an outage must not block setup."
          ;;
        *)
          echo "rejected (HTTP $code)."
          echo "sapience-bootstrap: the server does not recognise that token, so nothing was written." >&2
          echo "  Open your private app.spnc.ai link again and copy the token= value (or the whole" >&2
          echo "  link). A token that opens no Sapience cannot upload: extraction would run for" >&2
          echo "  minutes and then fail with HTTP 403 at the end." >&2
          exit 1
          ;;
      esac

      tmp="$(mktemp "${stateDir}/config.json.XXXXXX")"
      if [ -f "${configFile}" ]; then
        # Preserve the folder selection, capture map and auto_approve choice when only the token
        # was wrong; a fresh object would silently discard the onboarding work.
        ${pkgs.jq}/bin/jq \
          --arg token "$TOKEN" \
          --arg backend "${cfg.backend}" \
          --arg host "${cfg.host}" \
          '.token = $token | .backend = $backend | .host = $host
           | .auto_approve = (.auto_approve // false) | .hooks = (.hooks // true)' \
          "${configFile}" > "$tmp"
      else
        ${pkgs.jq}/bin/jq -n \
          --arg token "$TOKEN" \
          --arg backend "${cfg.backend}" \
          --arg host "${cfg.host}" \
          '{token: $token, backend: $backend, host: $host, auto_approve: false, hooks: true}' \
          > "$tmp"
      fi
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

    # The vendor's extraction prints nothing between "Extracting knowledge from N sources" and
    # its result, and writes the staging queue only at the end, so a run that is working is
    # indistinguishable from one that has hung. This ticker is the stand-in.
    #
    # It writes to stderr, so it cannot corrupt the vendor's stdout, and stays quiet until the
    # first call completes -- which keeps it clear of the interactive folder picker that runs
    # first.
    #
    # APPEND-ONLY, and only when the count has moved. Both properties are load-bearing, because
    # the vendor's extraction ends with an interactive review() whose input() prompt carries no
    # trailing newline: a carriage-return-rewritten line would contend with that prompt for one
    # physical line and erase the question, making a finished run look like a hung one. Whole
    # lines cannot erase anything, and printing only on a change means the ticker falls silent
    # by itself once the last call lands -- so nothing follows the prompt and there is no
    # plateau threshold, timer or liveness probe that could stop the display for the wrong
    # reason. A slow call simply produces no line until it completes.
    #
    # SIGNAL: the ollama journal's GIN access log, one line per completed HTTP call. A
    # `slot release:` grep would not do, because only a LOCAL inference slot emits it -- under a
    # ":cloud" model nothing is scheduled on this machine. Every call transits this daemon in
    # either mode, so its access log is the signal that holds for both.
    #
    # ESTIMATE, marked "~" and clamped, because it is a FLOOR and not a cap. A run makes one
    # model call per session to classify it work-vs-personal (extract_local.py:2199), then one
    # or more per chunk in a loop capped at MAXCH (:166, 50 unless --backfill raises it, which
    # bootstrap never passes). The cap counts CHUNKS, not calls: _extract_chunk (:1606) issues
    # one call per split_long_text window and, when a reply stops at num_predict (8000),
    # re-extracts the chunk as two halves recursively to depth 2, so one chunk costs 1, 3 or 7
    # calls. Sessions chunk at 10000 characters against a 12000 character window, making
    # windowing a no-op for them and truncation recursion the whole excess; memory files chunk
    # differently and can split as well.
    #
    # So a run can pass its own denominator, and "284/~255" is a correct reading rather than a
    # defect. What the display must not do is claim completion before the run is over, which is
    # why the percentage is capped at 99 and only the closing message declares a run finished.
    #
    # The source count is resolved lazily on the first completed call, never up front: the
    # folder picker runs first and a selection made there changes it. Cached, since it walks
    # every candidate file. If it cannot be parsed the line degrades to a bare count.
    ticker() {
      started="$1"
      watch_pid="$2"   # this script's own shell; see the launch site below
      total=""
      srcs_n=0
      budget="''${MAX_CHUNKS:-50}"
      shown=-1
      while kill -0 "$watch_pid" 2>/dev/null; do
        sleep 30
        jlog="$(journalctl --user -u ollama --no-pager -o cat --since "@$started" 2>/dev/null || true)"
        chat="$(printf '%s' "$jlog" | grep -E '\[GIN\].*POST +"/api/chat"' 2>/dev/null || true)"
        calls="$(printf '%s' "$chat" | grep -c . 2>/dev/null || true)"
        [ -n "$calls" ] || calls=0

        # Nothing completed yet, or nothing new since the last line: say nothing. This is what
        # makes the ticker self-silencing once extraction is over.
        [ "$calls" -gt 0 ] || continue
        [ "$calls" -ne "$shown" ] || continue
        shown="$calls"

        # Lazy, cached: onboarding has certainly finished by the first completed call.
        if [ -z "$total" ]; then
          srcs="$(SAPIENCE_HOST="${cfg.host}" ${python} "${stateDir}/extract_local.py" --coverage \
            2>/dev/null \
            | grep -oE 'would ingest now:[[:space:]]*[0-9]+' \
            | grep -oE '[0-9]+' \
            | head -1)"
          if [ -n "$srcs" ]; then
            srcs_n="$srcs"
            total=$((srcs + budget))
          else
            srcs_n=0
            total=0
          fi
        fi

        # Mean latency of the last 20 calls, normalised from GIN's own unit suffix.
        avg="$(printf '%s' "$chat" \
          | sed -E 's/.*\| *([0-9.]+)(µs|ms|s) +\|.*/\1 \2/' \
          | tail -20 \
          | awk '{ v = $1
                   if ($2 == "µs") v /= 1000000
                   else if ($2 == "ms") v /= 1000
                   t += v; n++ }
                 END { if (n) printf "%.1f", t / n }' 2>/dev/null || true)"

        # Which phase, because the two differ in cost by an order of magnitude and the label is
        # what makes a sudden rate change legible rather than alarming. A run classifies every
        # source first, one call each at max_tokens=6 (extract_local.py:1630, tenths of a
        # second), and only then enters the chunk loop at max_tokens=8000 (:1612, seconds).
        phase="extracting"
        if [ "$srcs_n" -gt 0 ] && [ "$calls" -le "$srcs_n" ]; then
          phase="classifying"
        fi

        # Clamped to 99 while the run is live. The denominator is an estimate the run can
        # exceed, so only the completion message gets to say a run finished -- a progress line
        # that reads 100% while work continues is the one thing worse than no percentage.
        if [ "$total" -gt 0 ]; then
          pct=$((calls * 100 / total))
          [ "$pct" -le 99 ] || pct=99
          prog="$(printf '%s/~%d (%d%%)' "$calls" "$total" "$pct")"
        else
          prog="$(printf '%s model calls' "$calls")"
        fi

        elapsed=$(($(date +%s) - started))
        printf '  %s: %s%s, %dm%02ds elapsed\n' \
          "$phase" \
          "$prog" \
          "$([ -n "$avg" ] && printf ' ~%ss each' "$avg")" \
          "$((elapsed / 60))" "$((elapsed % 60))" >&2
      done
    }

    ticker_pid=""
    cleanup() {
      if [ -n "$ticker_pid" ]; then
        kill "$ticker_pid" 2>/dev/null || true
        wait "$ticker_pid" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT INT TERM

    run_started="$(date +%s)"

    # Only when stderr is a terminal: progress lines are noise in a pipe or a log.
    #
    # Only on the ollama backend: the signal is the local daemon's own access log, so on
    # relay/anthropic/openai -- where no call transits this machine -- there is nothing to count
    # and the ticker would never have anything to say.
    #
    # The extraction itself stays in the FOREGROUND, because it reads stdin: backgrounding it
    # would take it out of the terminal's foreground process group and its first prompt would
    # raise SIGTTIN. The ticker therefore watches this shell rather than the extraction, which
    # bounds it to the run and also reaps it if this script is killed outright and the EXIT trap
    # never fires.
    ${lib.optionalString (cfg.backend == "ollama") ''
      if [ -t 2 ]; then
        ticker "$run_started" "$$" &
        ticker_pid=$!
      fi
    ''}

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

    # Say how it ended. The vendor's own last word is either a review prompt or an upload error,
    # and neither states what the run achieved or what to do next; a bootstrap that simply
    # returned to the shell left the user unable to tell success from silent failure.
    #
    # The staged count is the honest measure of a run's yield: extraction is local, so findings
    # survive a failed upload, and "staged but not sent" is a normal outcome rather than a loss.
    staged=""
    if [ -f "${stateDir}/extract_local.py" ]; then
      staged="$(SAPIENCE_HOST="${cfg.host}" ${python} "${stateDir}/extract_local.py" --pending \
        2>/dev/null | grep -oE '^[0-9]+' | head -1 || true)"
    fi
    total_elapsed=$(($(date +%s) - run_started))

    echo ""
    if [ "$rc" -eq 0 ]; then
      printf 'sapience-bootstrap: done in %dm%02ds.\n' \
        "$((total_elapsed / 60))" "$((total_elapsed % 60))"
    else
      printf 'sapience-bootstrap: extraction exited %d after %dm%02ds.\n' \
        "$rc" "$((total_elapsed / 60))" "$((total_elapsed % 60))"
      echo "  Nothing extracted so far is lost: the ledger only advances over work that was"
      echo "  staged, so the next run re-reads whatever this one did not finish."
    fi

    if [ -n "$staged" ] && [ "$staged" -gt 0 ] 2>/dev/null; then
      echo "  $staged findings are staged on this machine, waiting for your review."
      echo "  Next: sapience review        approve them and upload to your Sapience"
    elif [ "$rc" -eq 0 ]; then
      echo "  Nothing is staged: every finding this run produced was already approved and sent,"
      echo "  or the window held no new work."
    fi

    ${
      if cfg.backgroundSync then
        ''echo "  Scheduled sync is live (${cfg.syncInterval}): systemctl --user status sapience-sync.timer"''
      else
        ''echo "  Nothing syncs on a schedule; run sapience sync when you want another pass."''
    }
    exit "$rc"
  '';

  # `sapience adddir` over the directories named in sourceDirs, which is the only ingestion
  # route that takes a path AND can reach a hidden one.
  #
  # Why the relocated HOME: sapience_capture.deny_reason refuses any path whose first component
  # under $HOME begins with a dot -- "hidden settings and credentials, never read" -- exempting
  # only ~/.claude and ~/.codex as session folders. That rule is a macOS premise (there, real
  # config lives in ~/Library, which is separately denied); on NixOS it locks out ~/.config and
  # ~/.dotfiles, which is where configuration-as-source actually lives. sapience_adddir.main
  # resolves the home it checks against as `home or os.path.expanduser('~')`, so a $HOME pointed
  # at denyHome for this one call puts the named directory outside "home" entirely, and
  # deny_reason returns allowed for it (a path under neither $HOME nor a system root).
  #
  # This narrows ONE over-broad path test. It does not disable the deny list: deny_below still
  # prunes Personal-type folder names, Photos/keychain suffixes and secrets files (.env, ssh
  # keys, *.pem) beneath each named root, per file, on every run.
  #
  # denyHome is persistent, not a tempdir, because adddir keys its incremental ledger by content
  # sha at $HOME/.sapience/adddir-<sha>.json. A throwaway home would re-send every file on every
  # run; this way a re-run sends only what changed, which is the point for a store under active
  # edit. Its config.json is the capture map's scratch copy -- the real one at configFile is
  # read once for the token and never written, so the account credential stays untouched.
  sapienceAddDirSources = pkgs.writeShellScriptBin "sapience-adddir-sources" ''
    set -euo pipefail
    export PATH="${runtimePath}:$PATH"
    export SAPIENCE_HOST="${cfg.host}"

    # Not a memory-file route: adddir never consults NO_MEMFILES, so memoryFiles is irrelevant
    # here and deliberately not exported. See docs/sapience.md.

    denyHome="${stateDir}/adddir-home"

    if [ ! -f "${stateDir}/sapience_adddir.py" ]; then
      echo "sapience-adddir-sources: ${stateDir}/sapience_adddir.py is missing" >&2
      echo "  run: sapience-bootstrap" >&2
      exit 1
    fi

    # Env wins over config.json in every client, and mcp.py's own _saved_config() reads
    # ~/.sapience/config.json through expanduser, which the relocated HOME would redirect. So
    # the token is read from the real path here and handed over explicitly.
    if [ -z "''${SAPIENCE_TOKEN:-}" ]; then
      SAPIENCE_TOKEN="$(${python} -c \
        'import json,sys; print(json.load(open(sys.argv[1])).get("token",""))' \
        "${configFile}" 2>/dev/null || true)"
      export SAPIENCE_TOKEN
    fi

    if [ -z "''${SAPIENCE_TOKEN:-}" ]; then
      echo "sapience-adddir-sources: no token in ${configFile} -- run: sapience-bootstrap" >&2
      exit 1
    fi

    mkdir -p "$denyHome/.sapience"
    chmod 700 "$denyHome" "$denyHome/.sapience"

    rc=0
    ${lib.concatMapStringsSep "\n" (dir: ''
      if [ ! -d "${dir}" ]; then
        echo "sapience-adddir-sources: skipping ${dir} (not a directory)" >&2
        rc=1
      else
        echo "sapience-adddir-sources: ${dir}"
        if ! HOME="$denyHome" ${python} "${stateDir}/mcp.py" --adddir "${dir}" \
          --include "${cfg.sourceDirInclude}" "$@"; then
          echo "sapience-adddir-sources: ${dir} did not complete" >&2
          rc=1
        fi
      fi
    '') cfg.sourceDirs}
    exit "$rc"
  '';
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

    sourceDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/home/you/.config/nvim/agent-system" ];
      description = ''
        Directories to feed to the vault with `sapience adddir`, via the
        `sapience-adddir-sources` wrapper this option installs. Run it by hand; nothing here is
        scheduled and activation never ingests anything.

        This is the counterpart to `memoryFiles`, not a variant of it. `memoryFiles` is the
        vendor's implicit walk (every enabled capture project's own CLAUDE.md, AGENTS.md and
        .claude/rules/*.md), which here would mean the 20+ generated deploy trees; the vendor
        exposes no way to aim it at a path, since NO_MEMFILES is its only knob. `adddir` takes an
        explicit path instead, so one authored source store can be ingested while every
        generated copy of it stays out. Leave `memoryFiles` false and name the source here.

        A hidden path is fine and is the expected case -- see the wrapper's own comment for how
        the deny list's home test is narrowed, and what stays enforced.

        Each run uploads file text to the hosted brain's /extract-doc endpoint, which is a
        different path from `backend`-driven extraction: that is local, this is not. Findings
        still wait for `sapience review` unless auto-approve is on for the project. Pass
        `--dry-run` to see what would be sent, or `--max-files N` to cap a first pass.
      '';
    };

    sourceDirInclude = lib.mkOption {
      type = lib.types.str;
      default = "md";
      example = "md,tex,pdf";
      description = ''
        Comma-separated file extensions `sapience-adddir-sources` passes to `adddir --include`
        for every entry in `sourceDirs`. Narrower than the vendor default
        (tex,pdf,md,html,txt) because a configuration source store's prose is markdown; its
        .py/.sh/.nix files are not a supported document type in any case.
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

    desktopEntry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install a `Sapience` application launcher (and its icon) under
        $XDG_DATA_HOME/applications, so the vault is reachable from the GNOME Activities search
        and the app grid rather than only from a shell.

        The entry runs `sf1`, the interactive session, because it is the only client subcommand
        that holds a window open on its own: bare `sapience` prints its help and exits, and the
        rest (`review`, `sync`, `stats`) are one-shot commands that would close the terminal the
        moment they finished.
      '';
    };

    terminal = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${pkgs.wezterm}/bin/wezterm"
        "start"
        "--always-new-process"
        "--class"
        "sapience"
        "--"
      ];
      defaultText = lib.literalExpression ''
        [ "''${pkgs.wezterm}/bin/wezterm" "start" "--always-new-process" "--class" "sapience" "--" ]
      '';
      description = ''
        argv prefix the `desktopEntry` launcher puts in front of `sf1`. A terminal emulator is
        needed because `sf1` is a readline REPL with no GUI of its own, and a desktop entry is
        launched by the session with no terminal attached.

        Two details in the default are load-bearing rather than decorative, and a replacement
        wants the equivalents. `--always-new-process` keeps wezterm from handing the command to
        an already-running GUI instance, which would otherwise own the window and its class.
        `--class sapience` then matches `StartupWMClass` in the entry, so the window GNOME shows
        in the dash is attributed to Sapience instead of to the terminal.
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

    home = {
      packages = [
        sapienceCli
        sf1Cli
        sapienceBootstrap
      ]
      ++ lib.optional (cfg.sourceDirs != [ ]) sapienceAddDirSources;

      activation = {
        # Seed only what is absent -- see the MUTABLE STATE note in this file's header. A failed
        # fetch is reported and skipped, never fatal: activation must not break on a vendor
        # outage, and sapience-bootstrap / `sapience update` can always complete the set later.
        sapiencePayload = config.lib.dag.entryAfter [ "writeBoundary" ] ''
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
        # See docs/sapience.md.
        sapienceTokenRepair = config.lib.dag.entryAfter [ "writeBoundary" "sapiencePayload" ] ''
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
        sapienceApiKey = lib.mkIf (cfg.apiKeyFile != "") (
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
        # is correct, the edge just makes that independence intentional. See docs/sapience.md.
        sapienceMcpServer = lib.mkIf cfg.registerMcpServer (
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
      };
    };

    # A launcher rather than just a binary on PATH: GNOME indexes .desktop entries, not $PATH, so
    # a wrapper in home.packages is invisible to the Activities search no matter how it is named.
    #
    # Written to $XDG_DATA_HOME/applications, the location core/xdg.nix also uses for its sioyek
    # entry for the reason recorded there, rather than to a share/applications directory inside
    # the wrapper derivation -- the profile's own share/applications is not dependably on the
    # GNOME session's XDG_DATA_DIRS.
    xdg = lib.mkIf cfg.desktopEntry {
      dataFile = {
        "applications/sapience.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Sapience
          GenericName=Knowledge Vault
          Comment=Ask your Sapience vault about your own decisions, findings and open threads
          Exec=${lib.concatStringsSep " " (cfg.terminal ++ [ "${sf1Cli}/bin/sf1" ])}
          Icon=sapience
          Terminal=false
          StartupNotify=true
          StartupWMClass=sapience
          Categories=Utility;
          Keywords=sapience;sf1;knowledge;memory;vault;notes;recall;
        '';

        # Hand-drawn because the vendor ships no Linux icon, and the stock Adwaita candidates
        # (accessories-dictionary, applications-science) exist only as symbolic variants, which
        # render as a flat monochrome glyph in the app grid next to every full-colour neighbour.
        "icons/hicolor/scalable/apps/sapience.svg".text = ''
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
            <defs>
              <linearGradient id="sapience-bg" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stop-color="#5b4bdb"/>
                <stop offset="1" stop-color="#8b3fd4"/>
              </linearGradient>
            </defs>
            <rect x="4" y="4" width="120" height="120" rx="28" fill="url(#sapience-bg)"/>
            <g stroke="#ffffff" stroke-width="6" stroke-linecap="round" opacity="0.92" fill="none">
              <path d="M64 64 L64 36"/>
              <path d="M64 64 L37 91"/>
              <path d="M64 64 L91 91"/>
            </g>
            <g fill="#ffffff">
              <circle cx="64" cy="64" r="8"/>
              <circle cx="64" cy="36" r="10"/>
              <circle cx="37" cy="91" r="10"/>
              <circle cx="91" cy="91" r="10"/>
            </g>
          </svg>
        '';
      };
    };

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
              # leave this unit `failed` -- see the failure-discipline note in the header.
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
