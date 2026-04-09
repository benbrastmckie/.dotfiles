{ lib, writeShellScriptBin, python312, stdenv }:

let
  pythonWithPackages = python312.withPackages (ps: with ps; [
    pip
    virtualenv
    pandas
    numpy
  ]);
in
writeShellScriptBin "markitdown" ''
  # Markitdown virtual environment path
  VENV_DIR="$HOME/.local/share/markitdown-venv"

  PYTHON_STORE_PATH="${pythonWithPackages}"
  MARKER="$VENV_DIR/.python-store-path"

  # Recreate venv if missing or built against a different Python store path
  if [ ! -d "$VENV_DIR" ] || [ ! -f "$MARKER" ] || [ "$(cat "$MARKER")" != "$PYTHON_STORE_PATH" ]; then
    echo "Setting up markitdown virtual environment..."
    rm -rf "$VENV_DIR"
    ${pythonWithPackages}/bin/python -m venv "$VENV_DIR"
    # Disable any pip config that might force --user
    unset PIP_USER
    "$VENV_DIR/bin/pip" install --no-user --upgrade pip setuptools wheel
    "$VENV_DIR/bin/pip" install --no-user 'markitdown[pdf]'
    printf '%s' "$PYTHON_STORE_PATH" > "$MARKER"
  fi

  # Provide system libraries for numpy/onnxruntime
  export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc ]}:$LD_LIBRARY_PATH"

  # Run markitdown from the venv
  exec "$VENV_DIR/bin/markitdown" "$@"
''
