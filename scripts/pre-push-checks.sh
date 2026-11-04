#!/usr/bin/env bash
# ============================================================================
# pre-push-checks.sh -- the fast half of `nix flake check`, before a push
# ============================================================================
# Invoked by .githooks/pre-push (installed via scripts/install-git-hooks.sh).
#
# WHY ONLY THE LINT CHECKS: the four lint checks are the ones that have actually
# broken this repo's CI, and they finish in seconds because each reads only
# .nix or .sh files. The rest of `nix flake check` -- evaluating five host
# configurations and the standalone home-manager generation -- takes minutes,
# which is a reasonable thing for CI to spend and an unreasonable thing to put
# in front of every push. CI still runs the full set.
#
# Escape hatches, in order of preference:
#   git push --no-verify          skip every hook, once
#   SKIP_FLAKE_CHECK=1 git push   skip just this check, once
# ============================================================================
set -euo pipefail

if [ "${SKIP_FLAKE_CHECK:-0}" = "1" ]; then
  echo "pre-push: SKIP_FLAKE_CHECK=1 -- skipping lint checks" >&2
  exit 0
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "pre-push: no 'nix' on PATH -- skipping lint checks" >&2
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"

CHECKS=(statix deadnix nixfmt shellcheck)

# builtins.currentSystem needs --impure; it is only used to name an attribute path.
system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"

targets=()
for c in "${CHECKS[@]}"; do
  targets+=(".#checks.${system}.${c}")
done

echo "pre-push: running ${CHECKS[*]}"
if nix build --no-link "${targets[@]}"; then
  echo "pre-push: lint checks passed"
  exit 0
fi

cat >&2 <<'MSG'

pre-push: lint checks FAILED -- nothing was pushed.

  See the findings:  nix flake check -L
  Fix formatting:    nix fmt
  Fix lints:         nix develop --command statix fix
  Push anyway:       git push --no-verify

MSG
exit 1
