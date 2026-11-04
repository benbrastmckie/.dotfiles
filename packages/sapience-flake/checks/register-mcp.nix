# Tests for `sapience-register-mcp`, the MCP registration command.
#
# The case that matters most is PRESERVATION. ~/.claude.json is not this flake's file: Claude Code
# owns it, other tools register servers in it, and the user has their own settings there. A
# registration that replaced the file, or replaced `.mcpServers`, would silently delete someone
# else's configuration -- a loss the user would not connect to having installed Sapience. So the
# merge is asserted to leave every sibling key and every other server untouched.
#
# The malformed-input case is the other half of that: a file jq cannot parse must leave the
# original exactly as it was, because truncating a config Claude Code refuses to load is worse
# than not registering at all.
{ pkgs, mcpTest }:
pkgs.runCommand "sapience-check-register-mcp"
  {
    nativeBuildInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
  }
  ''
    REG=${mcpTest.sapience-register-mcp}/bin/sapience-register-mcp

    fail=0
    ok()  { echo "  ok   $1"; }
    bad() { echo "  FAIL $1" >&2; fail=1; }

    # The wrapper under test was built with stateDir and claudeJson left as unexpanded shell
    # variable references, so each case points them wherever it needs.
    export SAP_STATE="$TMPDIR/state"
    export SAP_CLAUDE="$TMPDIR/claude.json"
    mkdir -p "$SAP_STATE"

    echo "==> --print emits a valid, complete entry with no token stored"
    entry="$($REG --print)"
    if printf '%s' "$entry" | jq -e . >/dev/null 2>&1; then
      ok "output is valid JSON"
    else
      bad "output is not valid JSON: $entry"
    fi
    [ "$(printf '%s' "$entry" | jq -r '.type')" = "stdio" ] \
      && ok "type is stdio" || bad "type is not stdio"
    [ "$(printf '%s' "$entry" | jq -r '.args[0]')" = "$SAP_STATE/mcp.py" ] \
      && ok "args points at mcp.py in the state dir" || bad "args is wrong"
    [ "$(printf '%s' "$entry" | jq -r '.env.SAPIENCE_HOST')" = "https://app.spnc.ai" ] \
      && ok "SAPIENCE_HOST is set" || bad "SAPIENCE_HOST is wrong"
    # Absent, not empty: an empty SAPIENCE_TOKEN in the environment would have the client treat
    # itself as configured and fail against the server instead of prompting.
    [ "$(printf '%s' "$entry" | jq -r '.env | has("SAPIENCE_TOKEN")')" = "false" ] \
      && ok "SAPIENCE_TOKEN is absent, not empty" || bad "SAPIENCE_TOKEN should be absent"

    echo "==> --print picks the token up from config.json when there is one"
    printf '{"token":"tok_abcdefgh12345678"}\n' > "$SAP_STATE/config.json"
    entry="$($REG --print)"
    [ "$(printf '%s' "$entry" | jq -r '.env.SAPIENCE_TOKEN')" = "tok_abcdefgh12345678" ] \
      && ok "the stored token reaches the entry" || bad "the token did not reach the entry"

    echo "==> --print changes nothing on disk"
    if [ -e "$SAP_CLAUDE" ]; then
      bad "--print created $SAP_CLAUDE"
    else
      ok "no file was written"
    fi

    echo "==> registering with no existing file creates one"
    $REG > "$TMPDIR/out1" 2>&1 || bad "exited non-zero: $(cat "$TMPDIR/out1")"
    if jq -e '.mcpServers.sapience.type == "stdio"' "$SAP_CLAUDE" >/dev/null; then
      ok "mcpServers.sapience was written"
    else
      bad "mcpServers.sapience is missing: $(cat "$SAP_CLAUDE")"
    fi

    echo "==> PRESERVATION: a sibling server and unrelated keys survive the merge"
    cat > "$SAP_CLAUDE" <<'EXISTING'
    {
      "numStartups": 42,
      "theme": "dark",
      "mcpServers": {
        "other-tool": { "type": "stdio", "command": "/usr/bin/other", "args": ["--serve"] }
      }
    }
    EXISTING
    sed -i 's/^    //' "$SAP_CLAUDE"
    $REG > "$TMPDIR/out2" 2>&1 || bad "exited non-zero: $(cat "$TMPDIR/out2")"
    [ "$(jq -r '.numStartups' "$SAP_CLAUDE")" = "42" ] \
      && ok "unrelated top-level key preserved" || bad "numStartups was lost"
    [ "$(jq -r '.theme' "$SAP_CLAUDE")" = "dark" ] \
      && ok "a second unrelated key preserved" || bad "theme was lost"
    [ "$(jq -r '.mcpServers["other-tool"].command' "$SAP_CLAUDE")" = "/usr/bin/other" ] \
      && ok "another tool's MCP server preserved" || bad "other-tool was clobbered"
    [ "$(jq -r '.mcpServers.sapience.type' "$SAP_CLAUDE")" = "stdio" ] \
      && ok "and sapience was added alongside it" || bad "sapience was not added"

    echo "==> re-running is idempotent"
    cp "$SAP_CLAUDE" "$TMPDIR/before"
    $REG > /dev/null 2>&1 || bad "second run exited non-zero"
    if jq -S . "$TMPDIR/before" > "$TMPDIR/a" && jq -S . "$SAP_CLAUDE" > "$TMPDIR/b" \
       && cmp -s "$TMPDIR/a" "$TMPDIR/b"; then
      ok "a second run leaves the file unchanged"
    else
      bad "a second run changed the file"
      diff -u "$TMPDIR/a" "$TMPDIR/b" >&2 || true
    fi

    echo "==> a malformed file is refused, not truncated"
    printf '{ this is not json\n' > "$SAP_CLAUDE"
    cp "$SAP_CLAUDE" "$TMPDIR/malformed-before"
    if $REG > "$TMPDIR/out3" 2>&1; then
      bad "should have failed on a malformed file"
    else
      ok "exits non-zero"
    fi
    if cmp -s "$TMPDIR/malformed-before" "$SAP_CLAUDE"; then
      ok "the original file is byte-identical (nothing was truncated)"
    else
      bad "the malformed file was modified"
    fi
    # No stray temp files left behind next to it.
    if [ -z "$(find "$TMPDIR" -maxdepth 1 -name '.claude.json.*' -print -quit)" ]; then
      ok "no temporary file left behind"
    else
      bad "a .claude.json.* temp file was left behind"
    fi

    echo "==> the argument surface"
    $REG --help > /dev/null 2>&1 && ok "--help exits 0" || bad "--help should exit 0"
    if $REG --nope > /dev/null 2>&1; then
      bad "an unknown argument should fail"
    else
      [ "$?" -eq 2 ] && ok "an unknown argument exits 2" || ok "an unknown argument exits non-zero"
    fi

    if [ "$fail" -ne 0 ]; then
      echo "register-mcp check FAILED" >&2
      exit 1
    fi
    echo "all MCP registration cases pass"
    touch $out
  ''
