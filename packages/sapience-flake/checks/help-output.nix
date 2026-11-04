# Golden-output tests for `sapience help`, across both scheduling configurations and both
# platforms.
#
# Golden files rather than a keyword grep, because the help text IS the user-facing contract on a
# platform where the scheduler may not run, and the failure guarded against is advice that is
# confidently wrong -- the right words shown to the wrong audience. A grep for "WSL" passes on
# output that names the prerequisites to someone whose timer already fires; a byte-for-byte diff
# of the whole block does not.
#
# Determinism: USER is pinned (the text interpolates it into `loginctl enable-linger $USER`) and
# platform detection is driven through SAPIENCE_OSRELEASE rather than the host's real
# /proc/sys/kernel/osrelease, so these goldens hold identically on an ordinary Linux host and
# inside WSL. See the seam's rationale in ../lib/wrappers.nix.
{
  pkgs,
  syncOff,
  syncOn,
}:
pkgs.runCommand "sapience-check-help-output" { } ''
  export USER=testuser
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"

  printf 'Linux version 6.12.0-generic\n'                     > "$TMPDIR/osrelease-linux"
  printf 'Linux version 5.15.167.4-microsoft-standard-WSL2\n' > "$TMPDIR/osrelease-wsl"

  fail=0

  # compare <name> <golden> <osrelease-file> <wsl-distro-name> <cmd...>
  #
  # The two environment values are passed as positional arguments and applied as an assignment
  # prefix on the real command inside the process substitution, NOT as a prefix on this function
  # -- `VAR=x somefunction` has subtle and shell-dependent scoping, while `VAR=x realcommand` is
  # unambiguous. An empty wsl-distro-name stands for "unset": the detector tests it with
  # [ -n "''${WSL_DISTRO_NAME:-}" ], which treats empty and unset alike.
  compare() {
    local name="$1" golden="$2" osrel="$3" distro="$4"
    shift 4
    if diff -u "$golden" <(SAPIENCE_OSRELEASE="$osrel" WSL_DISTRO_NAME="$distro" "$@" 2>&1); then
      echo "  ok   $name"
    else
      echo "  FAIL $name (left: expected golden, right: actual)" >&2
      fail=1
    fi
  }

  echo "==> help text, backgroundSync = false"
  compare "plain Linux" ${./golden/help-sync-off.txt} \
    "$TMPDIR/osrelease-linux" "" ${syncOff.sapience}/bin/sapience help
  compare "WSL via osrelease" ${./golden/help-sync-off-wsl.txt} \
    "$TMPDIR/osrelease-wsl" "" ${syncOff.sapience}/bin/sapience help

  echo "==> help text, backgroundSync = true"
  compare "plain Linux" ${./golden/help-sync-on.txt} \
    "$TMPDIR/osrelease-linux" "" ${syncOn.sapience}/bin/sapience help
  compare "WSL via osrelease" ${./golden/help-sync-on-wsl.txt} \
    "$TMPDIR/osrelease-wsl" "" ${syncOn.sapience}/bin/sapience help

  # The second detection signal, independently. WSL_DISTRO_NAME is what a wsl.exe-launched shell
  # has and a systemd unit or cron job does not; osrelease is what survives every launch path.
  # Asserting the two produce the SAME text is what keeps them from drifting into differently
  # worded advice -- note the osrelease here is the plain-Linux one, so only the env var fires.
  echo "==> detection via WSL_DISTRO_NAME must equal detection via osrelease"
  compare "env-var signal" ${./golden/help-sync-on-wsl.txt} \
    "$TMPDIR/osrelease-linux" "Ubuntu-24.04" ${syncOn.sapience}/bin/sapience help

  # Help must work BEFORE the payload exists -- it is where a user who has not bootstrapped yet
  # is told what to do, so it deliberately short-circuits the payload guard. A regression here
  # would leave a new install with no reachable instructions at all.
  echo "==> help short-circuits the payload guard (nothing seeded in \$HOME)"
  if [ -e "$HOME/.sapience/extract_local.py" ]; then
    echo "  FAIL test fixture is wrong: payload should not exist" >&2
    fail=1
  elif SAPIENCE_OSRELEASE="$TMPDIR/osrelease-linux" \
       ${syncOff.sapience}/bin/sapience help >/dev/null 2>&1; then
    echo "  ok   help exits 0 with no payload present"
  else
    echo "  FAIL help should exit 0 with no payload present" >&2
    fail=1
  fi

  # The converse: any real subcommand must refuse, name the missing file, and exit non-zero
  # rather than invoking a python interpreter against a path that is not there.
  echo "==> a real subcommand refuses when the payload is absent"
  # NOT named `out`: that is the derivation's own output path, and shadowing it makes the final
  # `touch $out` write the captured message instead of the result.
  msg="$(${syncOff.sapience}/bin/sapience pending 2>&1 || true)"
  if ${syncOff.sapience}/bin/sapience pending >/dev/null 2>&1; then
    echo "  FAIL 'sapience pending' should fail with no payload" >&2
    fail=1
  elif printf '%s' "$msg" | grep -q 'extract_local.py is missing -- run: sapience-bootstrap'; then
    echo "  ok   refuses and points at sapience-bootstrap"
  else
    echo "  FAIL unexpected message: $msg" >&2
    fail=1
  fi

  if [ "$fail" -ne 0 ]; then
    echo "help-output check FAILED" >&2
    exit 1
  fi
  echo "help output matches all goldens"
  touch $out
''
