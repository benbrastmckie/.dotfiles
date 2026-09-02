# Wrapper that fetches the Playwright MCP server via npx on each invocation, then points it at
# an already-installed Chromium build under ~/.cache/ms-playwright instead of letting Playwright
# resolve (and potentially download) a browser by revision.
#
# Why an npx wrapper instead of nixpkgs' own `playwright-mcp` derivation: as of this writing,
# nixpkgs pins `playwright-mcp` at 0.0.69 (npm's registry is already at 0.0.79+), and — more
# importantly — its generated wrapper script hardcodes `PLAYWRIGHT_BROWSERS_PATH` to a
# nix-store-only browser set, pulling in ~1.2 GiB of `playwright-chromium`/`playwright-browsers`
# store paths that duplicate the cache this wrapper reuses. nixpkgs' `playwright-mcp` remains a
# viable, more hermetic fallback for a future maintainer who prioritizes reproducibility over
# currency; the same `--executable-path` override applies to it too.
#
# To pin a version, replace @latest with @X.Y.Z (e.g. @0.0.79).
# After changing this file, rebuild with: home-manager switch --flake .#<user>
#
# Browser resolution: rather than hardcoding a Chromium revision directory (which would go stale
# the next time `playwright install` populates a newer one), this script resolves the newest
# `chromium-*` directory under the browsers path at invocation time (`sort -V`, last match with
# an existing, executable `chrome-linux64/chrome`) and passes it via `--executable-path`. This
# bypasses Playwright's internal revision-based browser resolution entirely, so no browser is
# ever downloaded regardless of which `playwright-core` version the MCP server package pins.
# `PLAYWRIGHT_BROWSERS_PATH` is also exported to the resolved cache root as a self-documenting
# safety net (a no-op today, since it already matches Playwright's Linux default) in case some
# MCP tool call path ever falls back to revision-based resolution.
#
# Screen blanking: the browser is launched with `--disable-blink-features=ScreenWakeLock` via a
# generated `--config` file. A page that calls `navigator.wakeLock` makes Chromium register a
# GNOME SessionManager idle inhibitor (flag 8), which suppresses the 5-minute screen blank for
# the whole session -- and an MCP-driven browser is exactly the case where nobody is watching to
# notice or dismiss it. The same flag is applied to the interactive Brave build in
# modules/system/packages.nix. See docs/no-sleep-agents.md (mechanism 5).
{
  writeShellScriptBin,
  writeText,
  nodejs,
}:

let
  # browser.launchOptions is Playwright's LaunchOptions; --config is the only route the MCP
  # server (0.0.80) exposes for browser flags -- it has no --browser-arg equivalent.
  #
  # headless is the load-bearing setting for screen blanking. A headed Chromium owns a Wayland
  # surface, and any Wayland client can pin the screen awake through `zwp_idle_inhibitor_v1`,
  # which mutter relays into a GNOME SessionManager idle inhibitor (flag 8). Because GNOME needs
  # an uninterrupted, inhibitor-free idle stretch to reach the blank timeout, agents launching
  # short-lived headed browsers on a loop can hold the screen on indefinitely without ever
  # showing a persistent inhibitor in a point-in-time check. A headless browser has no surface at
  # all, so it cannot inhibit by any route -- this is a structural fix rather than a
  # flag-by-flag one. Navigation, snapshots, and screenshots all work headless.
  #
  # To get a visible browser back for debugging, drop `headless` here and rebuild, or point the
  # server at a different config with `playwright-mcp --config /path/to/other.json` (the
  # wrapper's trailing "$@" means a later --config wins).
  #
  # disable-blink-features=ScreenWakeLock is kept as defence in depth: it blocks the
  # `navigator.wakeLock` route specifically, and still applies if headless is ever turned off.
  mcpConfig = writeText "playwright-mcp-config.json" (builtins.toJSON {
    browser.launchOptions = {
      headless = true;
      args = [ "--disable-blink-features=ScreenWakeLock" ];
    };
  });
in

writeShellScriptBin "playwright-mcp" ''
  browsers_path="''${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
  export PLAYWRIGHT_BROWSERS_PATH="$browsers_path"

  chrome=""
  if [ -d "$browsers_path" ]; then
    for dir in $(find "$browsers_path" -maxdepth 1 -type d -name 'chromium-*' 2>/dev/null | sort -V); do
      candidate="$dir/chrome-linux64/chrome"
      if [ -x "$candidate" ]; then
        chrome="$candidate"
      fi
    done
  fi

  if [ -n "$chrome" ]; then
    exec ${nodejs}/bin/npx @playwright/mcp@latest --config ${mcpConfig} --executable-path "$chrome" "$@"
  else
    echo "playwright-mcp: no cached Chromium executable found under $browsers_path/chromium-*/chrome-linux64/chrome; falling back to Playwright's default browser resolution (may download a browser)" >&2
    exec ${nodejs}/bin/npx @playwright/mcp@latest --config ${mcpConfig} "$@"
  fi
''
