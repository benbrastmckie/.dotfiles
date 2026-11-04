# Builds the three Sapience CLI wrapper derivations (`sapience`, `sf1`, `sapience-bootstrap`)
# from plain arguments, with no home-manager dependency, so one set of script bodies backs both
# ../modules/sapience.nix's `homeManagerModules.sapience` and this flake's standalone
# `packages.<system>.*` outputs.
#
# Every value this file needs arrives as an argument rather than being read from a module option,
# which is what lets the non-home-manager output set exist at all.
#
# `stateDir` is a STRING, not a Nix path: the home-manager module passes an evaluation-time
# absolute path (its home-directory option joined with `/.sapience`), while the standalone
# package output passes a shell-expanded `"$HOME/.sapience"`, resolved at runtime. Nothing here
# is shell-expanded at the Nix level, so every interpolation of it below must stay
# double-quoted -- that holds for either caller.
{
  pkgs,
  lib,
  stateDir,
  host,
  backend,
  model,
  memoryFiles,
  tokenFile,
  backgroundSync,
  syncInterval,
  # Eval-time half of the ollama progress-ticker gate (see the ticker launch site below): true
  # only when the caller's own Ollama server is a systemd --user unit the ticker's
  # `journalctl --user -u ollama` signal source can actually see. The home-manager module passes
  # its own `services.ollama.enable` value here; the standalone package output has no such
  # option to read and passes the default `false`, deferring entirely to the runtime
  # `systemctl --user is-active` probe at the launch site.
  ollamaEnabled ? false,
}:
let
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

  # PATH for every wrapper. gitMinimal backs upload.py's optional branch probe; coreutils/curl
  # back the payload seed and the client's own self-update path.
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

  # Two single-purpose shell helpers -- "am I on WSL2?" and "is a systemd user manager
  # reachable?" -- injected into the wrappers that would otherwise print `systemctl --user`
  # instructions as though they were guaranteed to work. Separate rather than one block because
  # the call sites differ: sapienceCli's help needs only the detector, while the bootstrap
  # summary and the module's activation notice need both. Each is injected only where it has a
  # call site, so no wrapper carries an uncallable definition.
  #
  # WHY this exists: Windows consumers reach this flake through WSL2 (there is no native-Windows
  # Nix), and under WSL2 a systemd USER manager is not a given the way it is on any ordinary
  # Linux. It requires `[boot] systemd=true` in /etc/wsl.conf plus a `wsl --shutdown`, and then,
  # on most builds, `loginctl enable-linger $USER` before `systemctl --user` has a session bus
  # and a manager to talk to at all. Neither is anything this flake can set: /etc/wsl.conf
  # belongs to the Windows side of the boundary, and lingering is a host-level grant. So the
  # honest behavior is to detect the platform and NAME the two prerequisites, rather than print
  # timer commands that a WSL user would run to no visible effect.
  #
  # Two independent signals, because neither alone is sufficient: WSL_DISTRO_NAME is set only for
  # processes descended from a `wsl.exe` launch (a systemd unit or a cron job has no such
  # ancestor and sees it unset), while the osrelease marker is written by the WSL kernel itself
  # and survives every launch path. Both are cheap and neither can false-positive on real Linux.
  # SAPIENCE_OSRELEASE is a test seam, not a user-facing knob: it lets ../checks/ drive platform
  # detection deterministically instead of reading the host's real kernel marker, which is what
  # makes the golden files hold both on an ordinary Linux host and inside WSL. Unset in all
  # normal use, where it falls back to /proc/sys/kernel/osrelease.
  wslDetect = ''
    sapience_is_wsl() {
      [ -n "''${WSL_DISTRO_NAME:-}" ] && return 0
      grep -qi microsoft "''${SAPIENCE_OSRELEASE:-/proc/sys/kernel/osrelease}" 2>/dev/null && return 0
      return 1
    }
  '';

  userManagerProbe = ''
    # True when a systemd USER manager is REACHABLE, which is the only question that bears on
    # whether a user timer can fire.
    #
    # Must stay `show --property=Version`, never `is-system-running`: the latter answers with the
    # manager's HEALTH, so it exits non-zero and prints "degraded" whenever any unrelated user
    # unit has failed, on a session that is otherwise alive and running timers on schedule. That
    # would print the WSL prerequisites to users whose setup already works. `show` fails on one
    # condition only -- no bus, no manager, nothing to answer ("Failed to connect to user scope
    # bus") -- which is the condition being asked about. ../checks/wsl-probe.nix pins this.
    sapience_has_user_manager() {
      systemctl --user show --property=Version >/dev/null 2>&1
    }
  '';

  # The paste-reduction pair, kept out of sapienceBootstrap's body so
  # ../checks/token-functions.nix can exercise them as the pure functions they are, against a
  # table of real pastes, without running the bootstrap around them. Every install passes a
  # clipboard through these two.
  tokenShellHelpers = ''
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

    # A token is letters, digits, underscores and hyphens, at least 8 of them. This is what
    # separates a real token from a pasted link: a URL keeps its ':' '/' '?' '=' and fails here.
    sap_token_ok() {
      printf '%s' "$1" | grep -qE '^[A-Za-z0-9_-]{8,}$'
    }
  '';

  # The two WSL prerequisites, as printed lines. One definition, reused by the help text and the
  # bootstrap summary, so the two can never drift apart.
  wslPrereqLines = ''
    echo "  WSL needs two one-time steps before any systemd --user timer can fire:"
    echo "    1. put [boot] systemd=true in /etc/wsl.conf, then run: wsl --shutdown"
    echo "    2. loginctl enable-linger $USER"
  '';

  # Mirrors the subcommand dispatch of the vendor's ~/bin/sapience shim, with the interpreter
  # and PATH resolved from the store instead of inherited from an interactive shell.
  sapienceCli = pkgs.writeShellScriptBin "sapience" ''
    export PATH="${runtimePath}:$PATH"
    export SAPIENCE_HOST="${host}"

    ${wslDetect}
    ${lib.optionalString (!memoryFiles) "export NO_MEMFILES=1"}

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
          if backgroundSync then
            ''
              echo "Linux notes: scheduled sync is systemd.user (sapience-sync.timer), not launchd."
              echo "  schedule: ${syncInterval}"
              echo "  status:   systemctl --user status sapience-sync.timer"
              echo "  pause:    systemctl --user disable --now sapience-sync.timer"
              echo "  run now:  systemctl --user start sapience-sync.service"
              if sapience_is_wsl; then
                echo ""
                echo "WSL2 detected. The timer above is DEFINED but may never FIRE here."
                ${wslPrereqLines}
                echo "  Until both are done, 'systemctl --user status' reports no user manager"
                echo "  and the only sync that happens is the one you run: sapience sync"
              fi
            ''
          else
            ''
              echo "Linux notes: nothing syncs on a schedule -- extraction runs only when you ask."
              echo "  run now:  sapience sync"
              echo "  detached: systemctl --user start sapience-sync.service"
              echo "  schedule: set programs.sapience.backgroundSync = true in home.nix"
              if sapience_is_wsl; then
                echo ""
                echo "WSL2 detected. 'sapience sync' works normally; the detached form above needs"
                echo "a systemd user manager, which WSL does not start by default."
                ${wslPrereqLines}
              fi
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
    export SAPIENCE_HOST="${host}"
    ${lib.optionalString (!memoryFiles) "export NO_MEMFILES=1"}

    if [ ! -f "${stateDir}/sf1.py" ]; then
      echo "sf1: ${stateDir}/sf1.py is missing -- run: sapience update" >&2
      exit 1
    fi

    exec ${python} "${stateDir}/sf1.py" "$@"
  '';

  # Interactive first-run: mint configFile, seed the payload, then hand off to the vendor's own
  # folder-selection flow. Writing configFile directly is what lets this skip the vendor
  # installer's invite claim, exactly as their published one-liner does. See ../README.md.
  sapienceBootstrap = pkgs.writeShellScriptBin "sapience-bootstrap" ''
    set -euo pipefail
    export PATH="${runtimePath}:$PATH"

    ${lib.optionalString backgroundSync (wslDetect + userManagerProbe)}
    ${tokenShellHelpers}

    mkdir -p "${stateDir}"

    # Note: a dedicated lock, NOT the vendor's shared .run.lock, so the only thing that can turn
    # a bootstrap away is another bootstrap. flock releases on process exit by any route --
    # normal, Ctrl-C, crash, SIGKILL -- so an interrupted run never leaves this held and there is
    # never a cooldown before retrying. See ../README.md.
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
    # only surfaced after a full extraction had already run. See ../README.md.
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
      ${lib.optionalString (tokenFile != null) ''
        if [ -z "$TOKEN" ] && [ -r "${toString tokenFile}" ]; then
          TOKEN="$(tr -d '[:space:]' < "${toString tokenFile}")"
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
      printf "sapience-bootstrap: checking the token with %s ... " "${host}"
      code="$(curl -sS -o /dev/null -w '%{http_code}' -m 20 \
        -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) sapience-client/1.0' \
        "${host}/v1/stats?token=$TOKEN" 2>/dev/null || echo "000")"
      case "$code" in
        200)
          echo "ok."
          ;;
        000)
          echo "could not reach the host."
          echo "sapience-bootstrap: ${host} is unreachable, so the token could not be checked."
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
          --arg backend "${backend}" \
          --arg host "${host}" \
          '.token = $token | .backend = $backend | .host = $host
           | .auto_approve = (.auto_approve // false) | .hooks = (.hooks // true)' \
          "${configFile}" > "$tmp"
      else
        ${pkgs.jq}/bin/jq -n \
          --arg token "$TOKEN" \
          --arg backend "${backend}" \
          --arg host "${host}" \
          '{token: $token, backend: $backend, host: $host, auto_approve: false, hooks: true}' \
          > "$tmp"
      fi
      mv "$tmp" "${configFile}"
      chmod 600 "${configFile}"
      echo "sapience-bootstrap: wrote ${configFile} (backend ${backend})."
    fi

    echo "sapience-bootstrap: seeding client payload..."
    ${lib.concatMapStringsSep "\n" (f: ''
      if [ ! -f "${stateDir}/${f}" ]; then
        curl -fsSL "${host}/${f}" -o "${stateDir}/${f}"
        echo "  fetched ${f}"
      fi
    '') (requiredPayload ++ optionalPayload)}

    echo ""
    echo "Next: choose which projects Sapience may read (vendor's own interactive flow)."
    echo "Then run 'home-manager switch' once so the MCP server picks up the token."
    echo ""
    ${lib.optionalString (!memoryFiles) "export NO_MEMFILES=1"}

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
    # shellcheck disable=SC2329
    # Invoked only from the `backend == "ollama" && ollamaEnabled` branch below, which is omitted
    # at EVAL time on every other backend -- so on the default relay backend this definition is
    # genuinely never called and shellcheck is right to say so. Suppressed rather than wrapped in
    # the same lib.optionalString, which would re-indent 70-odd lines for a cosmetic gain.
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
          srcs="$(SAPIENCE_HOST="${host}" ${python} "${stateDir}/extract_local.py" --coverage \
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
    # Gated two ways, both required. Eval-time: backend == "ollama" AND ollamaEnabled (the
    # home-manager module passes its own services.ollama.enable value here; the standalone
    # package output has no such option and passes the default `false`), mirroring the module's
    # build-time `warnings` predicate exactly -- the ticker's signal source,
    # journalctl --user -u ollama, is a systemd --user unit's log, which exists only when a
    # home-manager-managed services.ollama module is what's running. A NixOS SYSTEM-level
    # services.ollama (a different, system-scope option of the same dotted name) logs to the
    # system journal under a system-scope unit instead, so journalctl --user -u ollama against
    # that setup finds nothing and the ticker would fork a 30-second polling loop for the whole
    # run with nothing to ever print -- functionally dead code that still costs a background
    # process and a trap/cleanup path. Runtime: a `systemctl --user is-active` probe immediately
    # below, because the eval-time gate only proves the unit is *defined*, not that it is
    # currently *running* (stopped, not yet started, or started-then-crashed all evaluate to
    # `true` for ollamaEnabled but would still leave the ticker printing nothing), and because
    # this standalone package output has no eval-time config at all to probe in the first place.
    # The negative branch prints one notice instead of silently starting a loop that will never
    # emit, and deliberately leaves ticker_pid empty so the existing cleanup/trap path stays a
    # no-op.
    #
    # On relay/anthropic/openai, where no call transits this machine at all, there is nothing to
    # count either and the whole block below is omitted from the generated script (not merely
    # skipped at runtime), since backend == "ollama" is already false at eval time.
    #
    # The extraction itself stays in the FOREGROUND, because it reads stdin: backgrounding it
    # would take it out of the terminal's foreground process group and its first prompt would
    # raise SIGTTIN. The ticker therefore watches this shell rather than the extraction, which
    # bounds it to the run and also reaps it if this script is killed outright and the EXIT trap
    # never fires.
    ${lib.optionalString (backend == "ollama" && ollamaEnabled) ''
      if [ -t 2 ]; then
        if systemctl --user is-active --quiet ollama.service 2>/dev/null; then
          ticker "$run_started" "$$" &
          ticker_pid=$!
        else
          echo "  progress ticker unavailable: no user-scope ollama.service found" >&2
        fi
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
    SAPIENCE_HOST="${host}" "''${runner[@]}" ${python} "${stateDir}/extract_local.py" \
      --backend "${backend}" \
      ${lib.optionalString (model != "") ''--model "${model}"''} || rc=$?
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
      staged="$(SAPIENCE_HOST="${host}" ${python} "${stateDir}/extract_local.py" --pending \
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
      if backgroundSync then
        ''
          if sapience_is_wsl && ! sapience_has_user_manager; then
            # Defined-but-dead is the WSL default, not an error the user caused. Say so here,
            # at the end of the one run every new install performs, rather than leaving them to
            # discover weeks later that nothing ever synced.
            echo "  Scheduled sync (${syncInterval}) is configured but NOT running: this is WSL2,"
            echo "  and no systemd user manager is up to carry the timer."
            ${wslPrereqLines}
            echo "  Until then: run sapience sync when you want a pass."
          else
            echo "  Scheduled sync is live (${syncInterval}): systemctl --user status sapience-sync.timer"
          fi
        ''
      else
        ''echo "  Nothing syncs on a schedule; run sapience sync when you want another pass."''
    }
    exit "$rc"
  '';
in
{
  sapience = sapienceCli;
  sf1 = sf1Cli;
  sapience-bootstrap = sapienceBootstrap;

  # Exposed in addition to the three wrapper derivations above (beyond this builder's stated
  # `{ sapience, sf1, sapience-bootstrap }` contract) so a home-manager-module caller can reuse
  # these same constants for its OWN config glue that falls outside the three wrappers --
  # payload seeding at activation time, the MCP server registration, and the background sync
  # systemd service all need `python`/`runtimePath`/the payload lists too, and sourcing them from
  # here rather than redefining them in the caller is what keeps there being exactly one
  # definition of each.
  #
  # `wslDetect`/`userManagerProbe`/`wslPrereqLines` are exported for the same reason:
  # ../modules/sapience.nix warns about the same defined-but-dead timer at activation time, and a
  # second copy of the detection logic or of the two prerequisite steps there is exactly the
  # drift this block exists to prevent. `tokenShellHelpers` is exported for ../checks/, which
  # tests those two functions directly.
  inherit
    python
    runtimePath
    requiredPayload
    optionalPayload
    wslDetect
    userManagerProbe
    wslPrereqLines
    tokenShellHelpers
    ;
}
