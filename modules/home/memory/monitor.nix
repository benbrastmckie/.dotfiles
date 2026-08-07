# Memory monitoring scripts
# Part of the three-tier memory monitoring system:
#   Tier 1: earlyoom (system-level OOM prevention in modules/system/power.nix)
#   Tier 2: memory-monitor (aggregate usage logging and desktop alerts)
#   Tier 3: process-memory-tracker (top-N per-process attribution)
#
# Tier 2 answers "when was the system under pressure"; Tier 3 answers "what
# caused it". See docs/memory-monitoring.md for the log schemas and analysis
# recipes.
{ pkgs, ... }:
{
  home.packages = [
    # Memory monitor script - logs memory usage and sends desktop notifications
    (pkgs.writeShellScriptBin "memory-monitor" ''
      #!/usr/bin/env bash

      # Configuration
      LOG_DIR="$HOME/.local/share/memory-monitor"
      LOG_FILE="$LOG_DIR/system.log"
      COOLDOWN_FILE="$LOG_DIR/.cooldown"
      WARNING_THRESHOLD=80    # Percentage - send warning notification
      CRITICAL_THRESHOLD=90   # Percentage - send critical notification
      CHECK_INTERVAL=30       # Seconds between checks
      COOLDOWN_PERIOD=300     # Seconds between notifications (5 minutes)
      MAX_LOG_SIZE=10485760   # 10MB - rotate log when exceeded

      # Create log directory
      mkdir -p "$LOG_DIR"

      # Function to get memory usage percentage
      get_memory_usage() {
        ${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/Mem:/ {printf "%.0f", ($3/$2) * 100}'
      }

      # Function to get swap usage percentage
      get_swap_usage() {
        ${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/Swap:/ {if ($2 > 0) printf "%.0f", ($3/$2) * 100; else print "0"}'
      }

      # Function to check cooldown
      check_cooldown() {
        local level="$1"
        local cooldown_marker="$COOLDOWN_FILE.$level"

        if [ -f "$cooldown_marker" ]; then
          local last_notify=$(cat "$cooldown_marker")
          local now=$(date +%s)
          local elapsed=$((now - last_notify))

          if [ "$elapsed" -lt "$COOLDOWN_PERIOD" ]; then
            return 1  # Still in cooldown
          fi
        fi
        return 0  # Not in cooldown
      }

      # Function to set cooldown
      set_cooldown() {
        local level="$1"
        local cooldown_marker="$COOLDOWN_FILE.$level"
        date +%s > "$cooldown_marker"
      }

      # Function to send notification
      send_notification() {
        local level="$1"
        local mem_pct="$2"
        local swap_pct="$3"

        if check_cooldown "$level"; then
          case "$level" in
            warning)
              ${pkgs.libnotify}/bin/notify-send \
                --urgency=normal \
                --icon=dialog-warning \
                "Memory Warning" \
                "Memory usage: ''${mem_pct}% | Swap: ''${swap_pct}%"
              ;;
            critical)
              ${pkgs.libnotify}/bin/notify-send \
                --urgency=critical \
                --icon=dialog-error \
                "Critical Memory Alert" \
                "Memory usage: ''${mem_pct}% | Swap: ''${swap_pct}%\nConsider closing applications."
              ;;
          esac
          set_cooldown "$level"
        fi
      }

      # Function to rotate log file if too large
      rotate_log() {
        if [ -f "$LOG_FILE" ]; then
          local size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
          if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            echo "$(date -Iseconds) Log rotated (size exceeded $MAX_LOG_SIZE bytes)" > "$LOG_FILE"
          fi
        fi
      }

      # Main monitoring loop
      echo "$(date -Iseconds) Memory monitor started" >> "$LOG_FILE"

      while true; do
        MEM_PCT=$(get_memory_usage)
        SWAP_PCT=$(get_swap_usage)
        TIMESTAMP=$(date -Iseconds)

        # Log memory usage
        echo "$TIMESTAMP,mem=$MEM_PCT%,swap=$SWAP_PCT%" >> "$LOG_FILE"

        # Check thresholds and send notifications
        if [ "$MEM_PCT" -ge "$CRITICAL_THRESHOLD" ]; then
          send_notification "critical" "$MEM_PCT" "$SWAP_PCT"
        elif [ "$MEM_PCT" -ge "$WARNING_THRESHOLD" ]; then
          send_notification "warning" "$MEM_PCT" "$SWAP_PCT"
        fi

        # Rotate log if needed
        rotate_log

        sleep "$CHECK_INTERVAL"
      done
    '')

    # Process memory tracker - logs the top RSS consumers system-wide
    #
    # Replaces the earlier claude-memory-tracker, which matched a hardcoded
    # pgrep pattern of "(claude|@anthropic|opencode)". That pattern missed the
    # processes that actually drive this machine's memory exhaustion: earlyoom's
    # journal records lean workers at 19 GB and pytest at 22 GB, neither of which
    # the old pattern selected. (lean appeared in the old CSV only by accident,
    # when its source path happened to live under a /tmp/claude-1000 scratchpad.)
    #
    # This version takes no allowlist. It snapshots the top N processes by RSS,
    # so whatever the next offender turns out to be, it is already being logged.
    (pkgs.writeShellScriptBin "process-memory-tracker" ''
      #!/usr/bin/env bash

      # Configuration
      LOG_DIR="$HOME/.local/share/memory-monitor"
      LOG_FILE="$LOG_DIR/processes.csv"
      TOP_N=10                # Number of processes to record per sample
      MIN_RSS_KB=51200        # 50MB - ignore processes smaller than this
      INTERVAL_NORMAL=60      # Seconds between samples under normal pressure
      INTERVAL_BURST=5        # Seconds between samples once BURST_THRESHOLD is crossed
      BURST_THRESHOLD=75      # Memory % at which to switch to high-resolution sampling
      MAX_LOG_SIZE=52428800   # 50MB - rotate log when exceeded (~2 weeks at normal rate)

      CSV_HEADER="timestamp,mem_pct,swap_pct,mode,rank,pid,comm,rss_kb,cmdline"

      # Create log directory
      mkdir -p "$LOG_DIR"

      # Create CSV header if file doesn't exist
      if [ ! -f "$LOG_FILE" ]; then
        echo "$CSV_HEADER" > "$LOG_FILE"
      fi

      # Function to rotate log file if too large
      rotate_log() {
        if [ -f "$LOG_FILE" ]; then
          local size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
          if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            echo "$CSV_HEADER" > "$LOG_FILE"
          fi
        fi
      }

      # Main monitoring loop
      while true; do
        TIMESTAMP=$(date -Iseconds)
        MEM_PCT=$(${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/Mem:/ {printf "%.0f", ($3/$2) * 100}')
        SWAP_PCT=$(${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/Swap:/ {if ($2 > 0) printf "%.0f", ($3/$2) * 100; else print "0"}')

        # Under pressure, sample far more often - the ramp into a spike is the
        # part worth having, and a 60s interval routinely misses it entirely.
        if [ "$MEM_PCT" -ge "$BURST_THRESHOLD" ]; then
          MODE="burst"
          SLEEP_FOR="$INTERVAL_BURST"
        else
          MODE="normal"
          SLEEP_FOR="$INTERVAL_NORMAL"
        fi

        # Snapshot the top consumers. Fields are pid, rss, then the full argv;
        # comm is derived from argv[0] rather than requested separately, because
        # ps truncates comm to 15 chars and it may itself contain spaces
        # (e.g. "npm exec @anthr"), which would misalign a whitespace split.
        ${pkgs.procps}/bin/ps -eo pid=,rss=,args= --sort=-rss 2>/dev/null \
          | head -n "$TOP_N" \
          | ${pkgs.gawk}/bin/awk \
              -v ts="$TIMESTAMP" -v mem="$MEM_PCT" -v swp="$SWAP_PCT" \
              -v mode="$MODE" -v min_rss="$MIN_RSS_KB" '
              {
                pid = $1
                rss = $2
                if (rss + 0 < min_rss + 0) next

                # argv[0] basename becomes the command label
                n = split($3, path_parts, "/")
                comm = path_parts[n]

                # Reassemble the full argv, then make it CSV-safe and bounded
                cmdline = ""
                for (i = 3; i <= NF; i++) cmdline = cmdline (i > 3 ? " " : "") $i
                gsub(/,/, ";", cmdline)
                gsub(/"/, "", cmdline)
                if (length(cmdline) > 160) cmdline = substr(cmdline, 1, 160)

                printf "%s,%s,%s,%s,%d,%s,%s,%s,%s\n", ts, mem, swp, mode, NR, pid, comm, rss, cmdline
              }' >> "$LOG_FILE"

        # Rotate log if needed
        rotate_log

        sleep "$SLEEP_FOR"
      done
    '')
  ];
}
