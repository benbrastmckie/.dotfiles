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

  # Create and setup venv if it doesn't exist
  if [ ! -d "$VENV_DIR" ]; then
    echo "Setting up markitdown virtual environment (first run)..."
    ${pythonWithPackages}/bin/python -m venv "$VENV_DIR"
    # Disable any pip config that might force --user
    unset PIP_USER
    "$VENV_DIR/bin/pip" install --no-user --upgrade pip setuptools wheel
    "$VENV_DIR/bin/pip" install --no-user markitdown
  fi

  # Provide system libraries for numpy/onnxruntime
  export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc ]}:$LD_LIBRARY_PATH"

  # Run markitdown from the venv
  exec "$VENV_DIR/bin/markitdown" "$@"
''
