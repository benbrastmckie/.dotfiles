# Unit tests for the two platform helpers, `sapience_is_wsl` and `sapience_has_user_manager`.
#
# The second test group is a REGRESSION TEST with a specific history. The first implementation of
# the user-manager probe used `systemctl --user is-system-running --quiet`, which is the obvious
# choice and the wrong one: it reports the manager's HEALTH, so it exits non-zero and prints
# "degraded" whenever any unrelated user unit anywhere has failed, on a session that is otherwise
# alive and running timers perfectly well. Shipped, that would have printed WSL prerequisites to
# users whose setup already worked -- advice both false and unfalsifiable from where they stood.
# `show --property=Version` fails on exactly one condition, the one being asked about: no bus, no
# manager, nothing to talk to.
#
# The "degraded but live" case cannot be tested against real systemd here, because a Nix build
# sandbox has no user manager at all. It is tested against a stub that reproduces the
# distinguishing behaviour -- `is-system-running` failing while `show` succeeds -- which is
# precisely what makes a regression to the old subcommand fail this check. Real-systemd
# confirmation is recorded in ../lib/wrappers.nix's comment and belongs to a VM test or a real
# machine, not to a sandbox.
#
# Every case runs the helper inside a SUBSHELL with the environment set explicitly, rather than
# with a `VAR=x helper` assignment prefix: a prefix on a shell function has scoping that differs
# between bash and POSIX mode, and a test harness is the last place to rely on it.
{ pkgs, syncOff }:
pkgs.runCommand "sapience-check-wsl-probe"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    ${syncOff.wslDetect}
    ${syncOff.userManagerProbe}

    fail=0
    ok()  { echo "  ok   $1"; }
    bad() { echo "  FAIL $1" >&2; fail=1; }

    # is_wsl <wsl-distro-name> <osrelease-path>  (empty distro name stands for "unset")
    is_wsl() (
      export WSL_DISTRO_NAME="$1" SAPIENCE_OSRELEASE="$2"
      sapience_is_wsl
    )

    # has_manager -- runs the probe against whatever stub is currently installed in $TMPDIR/stub.
    has_manager() (
      export PATH="$TMPDIR/stub:$PATH"
      sapience_has_user_manager
    )

    # mk_systemctl <exit-for-show> <exit-for-is-system-running>
    #
    # Written with printf rather than a heredoc: this file is a Nix indented string, where a
    # heredoc body's leading whitespace is reindented by Nix before the shell ever sees it, and a
    # shebang that does not start at column 0 is not a shebang.
    mk_systemctl() {
      {
        printf '#!/bin/sh\n'
        printf 'case "$*" in\n'
        printf '  *"show --property=Version"*) echo "Version=260.4"; exit %s ;;\n' "$1"
        printf '  *is-system-running*) echo stubbed-state; exit %s ;;\n' "$2"
        printf '  *) exit 1 ;;\n'
        printf 'esac\n'
      } > "$TMPDIR/stub/systemctl"
      chmod +x "$TMPDIR/stub/systemctl"
    }

    printf 'Linux version 6.12.0-generic\n'                     > "$TMPDIR/osrelease-linux"
    printf 'Linux version 5.15.167.4-microsoft-standard-WSL2\n' > "$TMPDIR/osrelease-wsl"
    printf 'Linux version 5.10.0-Microsoft-Standard\n'          > "$TMPDIR/osrelease-wsl-caps"
    mkdir -p "$TMPDIR/stub"

    echo "==> sapience_is_wsl: the env-var signal (a wsl.exe-launched shell)"
    if is_wsl "Ubuntu-24.04" "$TMPDIR/osrelease-linux"
    then ok "WSL_DISTRO_NAME detects WSL even when osrelease looks like plain Linux"
    else bad "WSL_DISTRO_NAME was ignored"
    fi

    echo "==> sapience_is_wsl: the kernel-marker signal (a unit or cron job, no wsl.exe ancestor)"
    if is_wsl "" "$TMPDIR/osrelease-wsl"
    then ok "osrelease marker detects WSL with WSL_DISTRO_NAME unset"
    else bad "osrelease marker was not matched"
    fi

    # The -i on that grep is load-bearing: the marker's capitalisation has varied across WSL
    # kernel builds, and a case-sensitive match would silently stop detecting WSL on some of them.
    if is_wsl "" "$TMPDIR/osrelease-wsl-caps"
    then ok "osrelease match is case-insensitive"
    else bad "capitalised Microsoft marker was not matched"
    fi

    echo "==> sapience_is_wsl: negative cases must not false-positive"
    if is_wsl "" "$TMPDIR/osrelease-linux"
    then bad "plain Linux was misreported as WSL (and an empty WSL_DISTRO_NAME read as set)"
    else ok "plain Linux is not WSL, and an empty WSL_DISTRO_NAME reads as unset"
    fi

    # A missing osrelease path must be a quiet "no", not an error: the probe runs inside scripts
    # that have `set -e`, and a kernel need not expose that file at all.
    if is_wsl "" "$TMPDIR/does-not-exist"
    then bad "a missing osrelease file reported WSL"
    else ok "a missing osrelease file is a quiet no"
    fi

    echo "==> sapience_has_user_manager: a live manager (show succeeds)"
    mk_systemctl 0 0
    if has_manager
    then ok "a reachable manager is detected"
    else bad "a reachable manager was reported absent"
    fi

    echo "==> REGRESSION: a DEGRADED but live manager must still count as present"
    mk_systemctl 0 1
    if has_manager
    then ok "degraded-but-live manager counts as present (no false WSL advice)"
    else bad "degraded manager misreported as absent -- probe regressed to is-system-running"
    fi

    echo "==> sapience_has_user_manager: no manager at all (nothing answers)"
    mk_systemctl 1 1
    if has_manager
    then bad "an unreachable bus was reported as a live manager"
    else ok "an unreachable bus reads as absent"
    fi

    echo "==> sapience_has_user_manager: systemctl missing from PATH entirely"
    rm -f "$TMPDIR/stub/systemctl"
    if ( export PATH="$TMPDIR/stub"; sapience_has_user_manager )
    then bad "absent systemctl reported a live manager"
    else ok "absent systemctl reads as absent, without erroring out"
    fi

    if [ "$fail" -ne 0 ]; then
      echo "wsl-probe check FAILED" >&2
      exit 1
    fi
    echo "all platform-probe cases pass"
    touch $out
  ''
