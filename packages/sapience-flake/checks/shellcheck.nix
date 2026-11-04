# shellcheck over every generated wrapper, in BOTH scheduling configurations.
#
# Run at shellcheck's default severity with no `--exclude` and no `--severity` relaxation, which
# is the point: a check tuned down until it passes is not evidence. The one suppression in the
# tree is a local `# shellcheck disable=SC2329` on the ollama ticker in ../lib/wrappers.nix,
# stated at the definition with its reason, where a reader meets it alongside the code.
#
# This matters more than it looks for a flake that generates shell: the scripts are assembled by
# Nix string interpolation, so a quoting mistake in a `${...}` is invisible in the .nix source and
# only becomes shell at build time. This check reads what is actually produced.
{
  pkgs,
  syncOff,
  syncOn,
}:
pkgs.runCommand "sapience-check-shellcheck"
  {
    nativeBuildInputs = [ pkgs.shellcheck ];
  }
  ''
    status=0
    for f in \
      ${syncOff.sapience}/bin/sapience \
      ${syncOff.sf1}/bin/sf1 \
      ${syncOff.sapience-bootstrap}/bin/sapience-bootstrap \
      ${syncOff.sapience-register-mcp}/bin/sapience-register-mcp \
      ${syncOn.sapience}/bin/sapience \
      ${syncOn.sf1}/bin/sf1 \
      ${syncOn.sapience-bootstrap}/bin/sapience-bootstrap \
      ${syncOn.sapience-register-mcp}/bin/sapience-register-mcp
    do
      echo "==> shellcheck $(basename "$f") ($(dirname "$(dirname "$f")" | sed 's|.*-||'))"
      if ! shellcheck "$f"; then
        status=1
      fi
      # bash -n as well: shellcheck parses, but a hard syntax error in generated code should
      # fail against the real interpreter that will run it, not only against a linter's parser.
      if ! ${pkgs.bash}/bin/bash -n "$f"; then
        echo "   bash -n FAILED on $f" >&2
        status=1
      fi
    done
    # The install-test script is hand-written rather than generated, but it is shipped in this
    # flake and run by CI, so it is held to the same bar.
    echo "==> shellcheck tests/install-test.sh"
    if ! shellcheck ${../tests/install-test.sh}; then
      status=1
    fi

    if [ "$status" -ne 0 ]; then
      echo "shellcheck/bash -n found problems" >&2
      exit 1
    fi
    echo "generated wrappers and tests/install-test.sh pass shellcheck (default severity) and bash -n"
    touch $out
  ''
