#\!/bin/bash

set -e

echo "===> Updating dotfiles..."

# Create git checkpoint if there are uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "===> Creating git checkpoint before update..."
  git add -A
  git commit -m "checkpoint: auto-commit before update

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
  echo "===> Checkpoint created"
else
  echo "===> No uncommitted changes, skipping checkpoint"
fi

# Update flake inputs — opt-in only (task 61). Auto-updating on every rebuild
# outran Hydra and forced local source builds. Run `./update.sh --update` to
# deliberately bump inputs (respecting Hydra cadence); the default path keeps
# the pinned flake.lock.
if [ "$1" == "--update" ] || [ "$2" == "--update" ]; then
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
if [ "$1" == "--no-check" ]; then
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

echo "===> Dotfiles update complete\!"
