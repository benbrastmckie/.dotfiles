#!/bin/bash

set -e

echo "===> Updating dotfiles..."

# Flag parsing (task 93): a single scan over "$@" so flags work regardless of
# order or position. Fixes a pre-existing bug where --update was only checked
# at $1/$2 and --no-check only at $1, so `./update.sh --update --no-check`
# silently ignored --no-check.
DO_UPDATE=0
DO_NO_CHECK=0
CHECKPOINT="${UPDATE_CHECKPOINT:-0}"
for arg in "$@"; do
  case "$arg" in
    --update)
      DO_UPDATE=1
      ;;
    --no-check)
      DO_NO_CHECK=1
      ;;
    --checkpoint)
      CHECKPOINT=1
      ;;
  esac
done

# Git checkpoint is opt-in only (task 93). The prior unconditional
# `git add -A && git commit` swept unrelated concurrent-session changes into
# misattributed commits during orchestration (incidents 6ba1f4e, 02f806d).
# Pass --checkpoint or set UPDATE_CHECKPOINT=1 to auto-commit a dirty tree
# before updating; otherwise the script refuses to proceed on a dirty tree so
# unrelated changes are never swept into an auto-commit.
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  if [ "$CHECKPOINT" = "1" ]; then
    echo "===> Creating git checkpoint before update..."
    git add -A
    git commit -m "checkpoint: auto-commit before update

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
    echo "===> Checkpoint created"
  else
    echo "===> ERROR: working tree is dirty; refusing to proceed without an explicit checkpoint opt-in." >&2
    echo "===> Pass --checkpoint or set UPDATE_CHECKPOINT=1 to auto-commit the dirty tree first," >&2
    echo "===> or commit/stash your changes manually and re-run." >&2
    exit 1
  fi
else
  echo "===> No uncommitted changes, skipping checkpoint"
fi

# Update flake inputs — opt-in only (task 61). Auto-updating on every rebuild
# outran Hydra and forced local source builds. Run `./update.sh --update` to
# deliberately bump inputs (respecting Hydra cadence); the default path keeps
# the pinned flake.lock.
if [ "$DO_UPDATE" = "1" ]; then
  echo "===> Updating flake inputs..."
  nix flake update
else
  echo "===> Keeping pinned flake.lock (pass --update to bump inputs)"
fi

# Get the hostname
HOSTNAME=$(hostname)
echo "===> Detected hostname: $HOSTNAME"

# Cap concurrent build jobs to avoid OOM on heavy C++ packages (task 60).
# Override per-invocation with: NIX_MAX_JOBS=1 ./update.sh
MAX_JOBS="${NIX_MAX_JOBS:-4}"
echo "===> Build job cap: --max-jobs $MAX_JOBS"

# Option to skip checks (useful for testing problematic packages)
SKIP_CHECK=""
if [ "$DO_NO_CHECK" = "1" ]; then
  echo "===> Skipping build checks for problematic packages..."
  SKIP_CHECK="--option allow-import-from-derivation false"
fi

# Rebuild NixOS configuration (includes NixOS-integrated home-manager -> /etc/profiles/per-user/)
echo "===> Rebuilding NixOS configuration..."
sudo nixos-rebuild switch --flake .#$HOSTNAME --max-jobs "$MAX_JOBS" --option allow-import-from-derivation false

# Rebuild standalone home-manager (-> ~/.nix-profile/, takes PATH priority)
# Both paths evaluate the same home.nix; running both keeps them in sync.
echo "===> Rebuilding Home Manager configuration..."
home-manager switch --flake .#benjamin --max-jobs "$MAX_JOBS" --option allow-import-from-derivation false

echo "===> Dotfiles update complete!"
