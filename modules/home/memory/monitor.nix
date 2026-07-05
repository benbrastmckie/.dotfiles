# Memory monitoring scripts
# Part of the three-tier memory monitoring system:
#   Tier 1: earlyoom (system-level OOM prevention in configuration.nix)
#   Tier 2: memory-monitor (user-level logging and alerts)
#   Tier 3: claude-memory-tracker (process-specific tracking)
#
# See: specs/26_memory_monitoring_systemd_services_nixos
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

    # Claude memory tracker script - tracks Claude process memory usage
    (pkgs.writeShellScriptBin "claude-memory-tracker" ''
      #!/usr/bin/env bash

      # Configuration
      LOG_DIR="$HOME/.local/share/memory-monitor"
      LOG_FILE="$LOG_DIR/claude.csv"
      CHECK_INTERVAL=60       # Seconds between checks
      MAX_LOG_SIZE=10485760   # 10MB - rotate log when exceeded

      # Create log directory
      mkdir -p "$LOG_DIR"

      # Create CSV header if file doesn't exist
      if [ ! -f "$LOG_FILE" ]; then
        echo "timestamp,pid,command,rss_kb,vsz_kb,mem_pct" > "$LOG_FILE"
      fi

      # Function to rotate log file if too large
      rotate_log() {
        if [ -f "$LOG_FILE" ]; then
          local size=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
          if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            echo "timestamp,pid,command,rss_kb,vsz_kb,mem_pct" > "$LOG_FILE"
          fi
        fi
      }

      # Main monitoring loop
      while true; do
        TIMESTAMP=$(date -Iseconds)

        # Find all Claude-related processes
        # Matches: claude, claude-code, @anthropics/claude-code, node processes with claude
        PIDS=$(${pkgs.procps}/bin/pgrep -f "(claude|@anthropic|opencode)" 2>/dev/null)

        if [ -n "$PIDS" ]; then
          for PID in $PIDS; do
            # Get process details: RSS (resident set size), VSZ (virtual memory), %MEM, command
            PROC_INFO=$(${pkgs.procps}/bin/ps -o rss=,vsz=,%mem=,comm= -p "$PID" 2>/dev/null)

            if [ -n "$PROC_INFO" ]; then
              RSS=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $1}')
              VSZ=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $2}')
              MEM_PCT=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $3}')
              COMM=$(echo "$PROC_INFO" | ${pkgs.gawk}/bin/awk '{print $4}')

              # Log to CSV
              echo "$TIMESTAMP,$PID,$COMM,$RSS,$VSZ,$MEM_PCT" >> "$LOG_FILE"
            fi
          done
        fi

        # Rotate log if needed
        rotate_log

        sleep "$CHECK_INTERVAL"
      done
    '')
  ];
}
