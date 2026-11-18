#!/usr/bin/env bash
# ============================================================================
# check-sapience-hooks.sh -- detect a vendor-written Sapience hook in
# ~/.claude/settings.json
# ============================================================================
# ~/.sapience/sapience_upkeep.py's wire_hooks() writes three machine-wide
# Claude Code hooks (SessionStart --briefing-text, SessionEnd --receipt, Stop
# --effect-line, each invoking ~/.sapience/mcp.py) into this repository's live
# ~/.claude/settings.json whenever ~/.sapience/config.json's "hooks" key is
# not explicitly false. modules/home/services/sapience.nix defaults that key
# to false, which should make this injection impossible -- this script is the
# detector that confirms it stayed impossible. It is invoked two ways: as a
# standalone/CI check (hard-failing exit 1 on a finding) and, non-fatally,
# from home.activation's sapienceHooksGuard, which must run before
# claudeSettings resets the `hooks` key and hides the evidence -- see that
# entry's ordering comment in sapience.nix and docs/sapience.md.
#
# SIGNATURE: an entry under hooks.SessionStart / hooks.SessionEnd / hooks.Stop
# whose command contains ".sapience/mcp.py" together with one of
# --briefing-text / --receipt / --effect-line. The legitimate, durable
# SessionStart entry (sapience-mcp-register-project.sh, installed by the
# sapience extension) carries neither the path nor any of the three flags, so
# it never trips this detector.
#
# Usage:
#   check-sapience-hooks.sh [SETTINGS_PATH] [--quiet-ok]
#
# SETTINGS_PATH defaults to ~/.claude/settings.json. --quiet-ok suppresses the
# "no finding" confirmation line (the activation call site uses it so a clean
# switch stays quiet); a positive finding is always reported regardless of
# --quiet-ok. Order of the two arguments does not matter.
#
# Exit 0: no finding -- including a missing file, unparseable JSON, or a
#         valid file with no `hooks` key (none of these is itself evidence of
#         an injection).
# Exit 1: one or more offending entries found; each is named on stderr with
#         its event, its full command string, and the remedy.
# ============================================================================
set -uo pipefail

settings_path="${HOME}/.claude/settings.json"
quiet_ok=0

for arg in "$@"; do
  case "$arg" in
    --quiet-ok) quiet_ok=1 ;;
    *) settings_path="$arg" ;;
  esac
done

note() {
  [ "$quiet_ok" = 1 ] || echo "check-sapience-hooks: $1"
}

if [ ! -f "$settings_path" ]; then
  note "$settings_path does not exist; nothing to check."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  note "jq is not on PATH; cannot check $settings_path."
  exit 0
fi

if ! jq -e . "$settings_path" >/dev/null 2>&1; then
  note "$settings_path is not valid JSON; nothing to check."
  exit 0
fi

# One TSV line per (event, command) pair under the three event names, event
# first so a tab-split read survives a command string that itself contains
# no tab (command strings are shell one-liners; a literal tab in one would be
# unusual enough that losing it from the display is an acceptable trade for
# not having to escape it).
findings="$(
  jq -r '
    (.hooks // {}) as $h
    | ["SessionStart", "SessionEnd", "Stop"][] as $event
    | (($h[$event] // [])[]?.hooks[]?) as $entry
    | ($entry.command // empty) as $cmd
    | [$event, $cmd] | @tsv
  ' "$settings_path" 2>/dev/null
)"

offenders=()
while IFS=$'\t' read -r event command; do
  [ -n "$event" ] || continue
  [ -n "$command" ] || continue
  if printf '%s' "$command" | grep -qF '.sapience/mcp.py' \
      && printf '%s' "$command" | grep -qE -- '--briefing-text|--receipt|--effect-line'; then
    offenders+=("$event"$'\t'"$command")
  fi
done <<< "$findings"

if [ "${#offenders[@]}" -eq 0 ]; then
  note "$settings_path carries no ~/.sapience injection hook."
  exit 0
fi

{
  echo "check-sapience-hooks: FOUND a vendor-written Sapience hook in $settings_path:"
  for entry in "${offenders[@]}"; do
    event="${entry%%$'\t'*}"
    command="${entry#*$'\t'}"
    echo "  hooks.$event: $command"
  done
  echo "  Remedy:"
  echo "    1. Remove the offending entry/entries from $settings_path by hand."
  echo "    2. Confirm ~/.sapience/config.json holds \"hooks\": false"
  echo "       (jq '.hooks' ~/.sapience/config.json)."
  echo "    3. Re-run: home-manager switch --flake .#benjamin"
  echo "       (home.activation.claudeSettings strips this on every switch; if it reappears"
  echo "       after that, the opt-out itself has regressed -- see docs/sapience.md)."
} >&2

exit 1
