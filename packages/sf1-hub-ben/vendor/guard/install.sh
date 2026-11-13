#!/bin/sh
# Install the oliver-ben guard into ONE git checkout. Writes only inside that checkout's .git directory
# (hooks + guard state); never a tracked file, never a Claude Code settings file.
#   legacy (2026-11-11):  sh install.sh <checkout> <oliver|ben> <source>
#   phase A attached:     sh install.sh <checkout> <oliver|ben> <hub-rules:<path>|hub-route:<url>> attached <local-events:<path>|hosted-events:<url>>
set -eu
CO=${1:?checkout path}; ME=${2:?oliver or ben}; SRC=${3:?rule source}; MODE=${4:-legacy}; SINK=${5:-}
GUARD="$(cd "$(dirname "$0")" && pwd)/guard.py"
PY=$(command -v python3)
GD=$(git -C "$CO" rev-parse --git-common-dir); case "$GD" in /*) ;; *) GD="$CO/$GD";; esac
HP=$(git -C "$CO" config --get core.hooksPath || true)
HOOKS=${HP:-$GD/hooks}; case "$HOOKS" in /*) ;; *) HOOKS="$CO/$HOOKS";; esac
mkdir -p "$GD/oliver-ben-guard" "$HOOKS"
put_hook() {  # name, guard args
  if [ -e "$HOOKS/$1" ] && ! grep -q oliver-ben-guard "$HOOKS/$1"; then
    echo "A $1 hook already exists at $HOOKS/$1. Not overwriting: add this line to it:"
    echo "  \"$PY\" \"$GUARD\" $2 || exit 1"
  else
    printf '#!/bin/sh\n# oliver-ben-guard\nexec "%s" "%s" %s\n' "$PY" "$GUARD" "$2" > "$HOOKS/$1"; chmod +x "$HOOKS/$1"
  fi
}
if [ "$MODE" = attached ]; then
  [ -n "$SINK" ] || { echo "attached mode needs an event sink (5th argument)"; exit 1; }
  put_hook pre-commit 'precommit --attached'
  put_hook post-commit 'postcommit'
  put_hook post-rewrite 'postrewrite "$1"'
  printf '{"me": "%s", "mode": "attached", "source": "%s", "sink": "%s", "coalesce_s": 1.0, "net_timeout_s": 2.0, "deadline_s": 8.0, "require_accept": true, "since_ts": %s}\n' \
    "$ME" "$SRC" "$SINK" "$(date +%s)" > "$GD/oliver-ben-guard/config.json"
  echo "installed (attached): pre-commit, post-commit, post-rewrite -> $HOOKS ; config -> $GD/oliver-ben-guard/config.json"
  echo "Claude Code: $CO/.claude/settings.local.json needs PreToolUse and PostToolUse entries (INSTALL.md, phase A):"
  echo "  PreToolUse  command: \"$PY\" \"$GUARD\" hook --attached || exit 2"
  echo "  PostToolUse command: \"$PY\" \"$GUARD\" posthook --attached"
  echo "The '|| exit 2' matters: Claude Code 2.1.322 admits the action when a hook exits 1 or times out (measured, G1a/G1c)."
  (cd "$CO" && "$PY" "$GUARD" refresh && "$PY" "$GUARD" status)
else
  put_hook pre-commit precommit
  printf '{"me": "%s", "source": "%s", "ttl_s": 600, "fail": "open"}\n' "$ME" "$SRC" > "$GD/oliver-ben-guard/config.json"
  echo "installed: pre-commit -> $HOOKS/pre-commit ; config -> $GD/oliver-ben-guard/config.json"
  echo "now add the PreToolUse block from INSTALL.md to $CO/.claude/settings.local.json (or settings.json)"
  (cd "$CO" && "$PY" "$GUARD" status)
fi
