#!/usr/bin/env bash
# ============================================================================
# install-git-hooks.sh -- activate this repo's tracked git hooks
# ============================================================================
# Points core.hooksPath at the tracked .githooks/ directory, so the hooks are
# version-controlled rather than hand-copied into .git/hooks/ (which no clone
# ever inherits, and which nothing keeps in sync).
#
# Idempotent. Run once per clone:
#
#   ./scripts/install-git-hooks.sh
#
# To undo:
#
#   git config --unset core.hooksPath
#
# NOTE: setting core.hooksPath makes git ignore .git/hooks/ entirely. This repo
# has no hooks there beyond git's own .sample files, but if you add one later,
# add it to .githooks/ instead.
# ============================================================================
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

current="$(git config --get core.hooksPath || true)"
if [ "$current" = ".githooks" ]; then
  echo "git hooks already installed (core.hooksPath=.githooks)"
else
  git config core.hooksPath .githooks
  echo "installed: core.hooksPath=.githooks"
  [ -n "$current" ] && echo "note: replaced previous core.hooksPath=$current"
fi

echo
echo "Active hooks:"
for h in .githooks/*; do
  [ -f "$h" ] || continue
  if [ -x "$h" ]; then
    echo "  $(basename "$h")"
  else
    echo "  $(basename "$h")  -- NOT EXECUTABLE, will not run (chmod +x it)"
  fi
done
