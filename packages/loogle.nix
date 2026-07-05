# loogle - Lean 4 Mathlib search tool. Self-bootstrapping wrapper: clones and builds
# nomeata/loogle into ~/.cache/loogle on first run via its own flake, since loogle
# has no nixpkgs package.
{ writeShellScriptBin }:

writeShellScriptBin "loogle" ''
  LOOGLE_DIR="$HOME/.cache/loogle"

  # First-time setup
  if [ ! -d "$LOOGLE_DIR" ]; then
    echo "==> First-time setup: Cloning loogle repository..."
    git clone https://github.com/nomeata/loogle.git "$LOOGLE_DIR"
    cd "$LOOGLE_DIR"
    echo "==> Building loogle (this may take a few minutes)..."
    nix develop . --command sh -c "lake exe cache get && lake build loogle"
  fi

  # Run loogle
  cd "$LOOGLE_DIR"
  nix develop . --command lake exe loogle "$@"
''
