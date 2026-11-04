#!/usr/bin/env bash
# End-to-end install test against a STUBBED vendor, for a Linux machine that is not NixOS.
#
# WHAT THIS PROVES, and why it is not a `checks.<system>.*` derivation: this is the only test that
# performs a real `home-manager` activation against a real $HOME -- it seeds the payload, writes
# config.json, and merges mcpServers.sapience into ~/.claude.json. Those are filesystem effects on
# a live home directory, which a Nix build sandbox has no $HOME for and no network access to
# reach a server from. So it lives here, runs on an ordinary Linux box or a CI runner, and
# `nix flake check` covers everything that CAN be hermetic.
#
# WHY IT IS HERMETIC ANYWAY: the vendor is stubbed. `programs.sapience.host` parameterises every
# payload fetch, so this points it at a local HTTP server serving placeholder .py files. Nothing
# contacts app.spnc.ai, no token is needed, and the test cannot flake on a vendor outage or be
# rate-limited. `checks/hm-module.nix` asserts that the host option really does redirect every
# fetch, so this test cannot silently start hitting the live vendor and pass for the wrong reason.
#
# WHAT IT DOES NOT PROVE: that the vendor's real client works. The payload here is a stub. The
# Sapience service is an invite-only private beta with no CI-accessible credentials, so no
# automated test anywhere can cover the other side of that boundary. See ../README.md.
#
# Usage:  bash tests/install-test.sh          # from the flake root
# Needs:  nix (flakes enabled), curl, python3. Leaves the real $HOME untouched -- everything
#         happens under a temporary directory that is removed on exit.
set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
PORT="${SAPIENCE_TEST_PORT:-8099}"
SERVER_PID=""

cleanup() {
  local rc=$?
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  rm -rf "$WORK"
  exit "$rc"
}
trap cleanup EXIT

fail=0
ok()  { echo "  ok   $1"; }
bad() { echo "  FAIL $1" >&2; fail=1; }

echo "flake:   $FLAKE_DIR"
echo "sandbox: $WORK"

# ----------------------------------------------------------------- stub vendor
# One placeholder per file the module seeds. The content only has to be fetchable and
# identifiable; nothing executes it in this test.
mkdir -p "$WORK/vendor"
for f in upload.py extract_local.py sapience_redact.py sapience_filter.py \
         sapience_capture.py sapience_adddir.py mcp.py \
         sapience_devin.py sf1.py sapience_upkeep.py; do
  printf '# stub payload: %s\n' "$f" > "$WORK/vendor/$f"
done

( cd "$WORK/vendor" && python3 -m http.server "$PORT" --bind 127.0.0.1 ) >"$WORK/server.log" 2>&1 &
SERVER_PID=$!

echo "==> waiting for the stub vendor on 127.0.0.1:$PORT"
for _ in $(seq 1 50); do
  if curl -fsS -m 2 "http://127.0.0.1:$PORT/mcp.py" >/dev/null 2>&1; then break; fi
  sleep 0.2
done
if curl -fsS -m 2 "http://127.0.0.1:$PORT/mcp.py" >/dev/null 2>&1; then
  ok "stub vendor is serving"
else
  echo "FAIL stub vendor never came up; log follows" >&2
  cat "$WORK/server.log" >&2
  exit 1
fi

# ------------------------------------------------------- a home-manager generation
# Resolved through the flake's OWN locked home-manager and nixpkgs inputs, so this test runs
# against the same pinned versions `nix flake check` uses. --impure is required only because
# builtins.getFlake takes a path; the inputs it reaches are still those in flake.lock.
export HOME="$WORK/home"
mkdir -p "$HOME"
printf 'tok_abcdefgh12345678\n' > "$WORK/token"

cat > "$WORK/config.nix" <<NIXEOF
let
  flake = builtins.getFlake "path:$FLAKE_DIR";
  pkgs = flake.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
in
flake.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    flake.homeManagerModules.sapience
    {
      home.username = "$(id -un)";
      home.homeDirectory = "$HOME";
      home.stateVersion = "26.05";
      programs.sapience = {
        enable = true;
        host = "http://127.0.0.1:$PORT";
        tokenFile = "$WORK/token";
      };
    }
  ];
}
NIXEOF

echo "==> building the home-manager generation"
nix build --impure --no-link --print-out-paths \
  -f "$WORK/config.nix" activationPackage > "$WORK/gen-path"
GEN="$(cat "$WORK/gen-path")"
ok "generation built: $GEN"

echo "==> activating it against a throwaway \$HOME"
# home-manager's own systemd step needs a user manager, which a CI runner generally has not got.
# That is not what this test is about, so its failure must not mask the filesystem assertions
# below -- the activation output is captured and reported, and the assertions run regardless.
if "$GEN/activate" >"$WORK/activate.log" 2>&1; then
  ok "activation exited 0"
else
  echo "  note activation exited non-zero (often just the systemd user step on a runner):"
  sed 's/^/        /' "$WORK/activate.log" | tail -20
fi

# ------------------------------------------------------------------- assertions
echo "==> the payload is seeded from the stub, not from the vendor"
missing=0
for f in upload.py extract_local.py sapience_redact.py sapience_filter.py \
         sapience_capture.py sapience_adddir.py mcp.py; do
  if [ -f "$HOME/.sapience/$f" ]; then
    grep -q "stub payload: $f" "$HOME/.sapience/$f" || { bad "$f is not the stub content"; }
  else
    bad "required payload file not seeded: $f"
    missing=1
  fi
done
[ "$missing" -eq 0 ] && ok "all seven required payload files present"

echo "==> the state directory is private"
mode="$(stat -c '%a' "$HOME/.sapience" 2>/dev/null || echo '?')"
if [ "$mode" = "700" ]; then ok "the state dir is mode 700"; else bad "the state dir is mode $mode, expected 700"; fi

# The division of labour between activation and the bootstrap, asserted in both directions:
# activation seeds the payload and registers the MCP server, while `sapience-bootstrap` is what
# creates config.json and consumes tokenFile, when the user runs it. Easy to misread as
# activation's job, so both halves are pinned here.
echo "==> activation does NOT write config.json (the bootstrap owns it)"
if [ -e "$HOME/.sapience/config.json" ]; then
  bad "activation wrote config.json; the contract is that sapience-bootstrap creates it"
else
  ok "no config.json after activation, as documented"
fi

echo "==> tokenFile is wired into the bootstrap, ready for a non-interactive run"
BOOT="$HOME/.nix-profile/bin/sapience-bootstrap"
if [ -x "$BOOT" ]; then
  if grep -q "$WORK/token" "$BOOT"; then
    ok "sapience-bootstrap reads the configured tokenFile path"
  else
    bad "sapience-bootstrap does not reference the configured tokenFile"
  fi
else
  bad "sapience-bootstrap was not installed onto the profile"
fi

echo "==> the MCP registration command is installed"
if [ -x "$HOME/.nix-profile/bin/sapience-register-mcp" ]; then
  ok "sapience-register-mcp is on the profile"
  if "$HOME/.nix-profile/bin/sapience-register-mcp" --print | python3 -c        "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('type')=='stdio' else 1)"; then
    ok "--print emits a well-formed stdio entry"
  else
    bad "--print did not emit a well-formed entry"
  fi
else
  bad "sapience-register-mcp was not installed onto the profile"
fi

echo "==> the MCP server was registered for Claude Code"
if [ -f "$HOME/.claude.json" ]; then
  if python3 -c "
import json,sys
d=json.load(open('$HOME/.claude.json'))
s=d.get('mcpServers',{}).get('sapience')
sys.exit(0 if s else 1)
"; then
    ok "$HOME/.claude.json has mcpServers.sapience"
  else
    bad "$HOME/.claude.json exists but lacks mcpServers.sapience: $(cat "$HOME/.claude.json")"
  fi
else
  bad "$HOME/.claude.json was not created"
fi

echo "==> the installed wrappers run"
BIN="$HOME/.nix-profile/bin"
if [ -x "$BIN/sapience" ]; then
  ok "sapience is on the profile"
  if "$BIN/sapience" help >"$WORK/help.log" 2>&1; then
    ok "sapience help exits 0"
    if grep -q 'Linux notes' "$WORK/help.log"; then
      ok "help prints the Linux notes block"
    else
      bad "help is missing the Linux notes block"
    fi
  else
    bad "sapience help failed: $(cat "$WORK/help.log")"
  fi
  # The WSL branch, forced. A real WSL2 machine is not needed to prove the text appears; what a
  # real machine proves is that DETECTION fires there, which is what ../README.md records.
  if SAPIENCE_OSRELEASE=/dev/null WSL_DISTRO_NAME=Ubuntu-24.04 "$BIN/sapience" help 2>&1 \
       | grep -q 'loginctl enable-linger'; then
    ok "the WSL branch prints the enable-linger prerequisite"
  else
    bad "the WSL branch did not print the prerequisites"
  fi
else
  bad "sapience was not installed onto the profile ($BIN)"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "install test FAILED" >&2
  exit 1
fi
echo "install test PASSED (stubbed vendor; nothing contacted app.spnc.ai)"
