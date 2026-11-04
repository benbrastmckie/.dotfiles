# Table-driven unit tests for the paste-reduction pair, `sap_token_clean` and `sap_token_ok`.
#
# WHY these are worth more than their size suggests: every single install funnels a clipboard
# through them, and the thing being defended against is a genuinely confusing failure. A user who
# pastes the whole private link instead of its token= value gets a config that LOOKS populated,
# and the server answers 401 on /v1/stats and 403 "an invite code is needed to build a new
# Sapience" on /ingest-kos -- neither of which names the real cause. ../modules/sapience.nix
# carries a whole activation-time repair step for exactly this. These two functions are the first
# line of that defence, they are pure, and they need no network, no systemd and no vendor to test,
# which makes them the single highest-value-per-line check in the flake.
#
# The functions are injected from ../lib/wrappers.nix's exported `tokenShellHelpers` rather than
# copied here, so a change to the real implementation cannot silently diverge from what is tested.
{ pkgs, syncOff }:
pkgs.runCommand "sapience-check-token-functions"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
    ];
  }
  ''
    ${syncOff.tokenShellHelpers}

    fail=0

    # expect_clean <input> <expected-output>
    expect_clean() {
      local got
      got="$(sap_token_clean "$1")"
      if [ "$got" = "$2" ]; then
        echo "  ok   clean  $1"
      else
        echo "  FAIL clean  $1" >&2
        echo "         expected: [$2]" >&2
        echo "         got:      [$got]" >&2
        fail=1
      fi
    }

    # expect_verdict <input> <accept|reject> -- runs the input through BOTH functions, the way
    # sapience-bootstrap actually composes them.
    expect_verdict() {
      local cleaned verdict
      cleaned="$(sap_token_clean "$1")"
      if sap_token_ok "$cleaned"; then verdict=accept; else verdict=reject; fi
      if [ "$verdict" = "$2" ]; then
        echo "  ok   $2  $1"
      else
        echo "  FAIL expected $2, got $verdict for: $1 (cleaned: [$cleaned])" >&2
        fail=1
      fi
    }

    TOK=abcd1234WXYZ

    echo "==> sap_token_clean recovers the token from every paste shape the invite email yields"
    expect_clean "$TOK"                                       "$TOK"
    expect_clean "https://app.spnc.ai/?token=$TOK"            "$TOK"
    expect_clean "token=$TOK"                                 "$TOK"
    expect_clean "<https://app.spnc.ai/?token=$TOK>"           "$TOK"
    expect_clean "\"$TOK\""                                    "$TOK"
    expect_clean "'$TOK'"                                      "$TOK"
    # A trailing query parameter and a URL fragment must both be dropped -- a browser address bar
    # supplies either without warning.
    expect_clean "https://app.spnc.ai/?token=$TOK&ref=email"  "$TOK"
    expect_clean "https://app.spnc.ai/?token=$TOK#section"    "$TOK"
    # token= as a NON-first parameter: the greedy .*[?&] is what makes this work.
    expect_clean "https://app.spnc.ai/?a=1&token=$TOK"        "$TOK"
    # Surrounding whitespace, including a trailing newline from a terminal paste.
    expect_clean "   $TOK   "                                 "$TOK"
    expect_clean "$TOK
    "                                                        "$TOK"
    # Documented consequence of stripping ALL whitespace rather than only the ends: interior
    # spaces are removed too, so a token broken across a line wrap is recovered rather than
    # rejected. Asserted so the behaviour is a decision on record, not an accident.
    expect_clean "abcd 1234 WXYZ"                             "$TOK"

    echo "==> the pair accepts real tokens"
    expect_verdict "$TOK"                                      accept
    expect_verdict "https://app.spnc.ai/?token=$TOK"           accept
    expect_verdict "<https://app.spnc.ai/?token=$TOK>"          accept
    expect_verdict "tok-with-dash-99"                          accept
    expect_verdict "tok_with_underscore_99"                    accept

    echo "==> and rejects what is not a token"
    # The whole point: a link with no token= survives cleaning as a link, and its ':' and '/'
    # fail the character class. This is the case that produces the misleading 401/403 if let
    # through.
    expect_verdict "https://app.spnc.ai/"                      reject
    expect_verdict "short"                                     reject
    expect_verdict ""                                          reject
    expect_verdict "seven77"                                   reject
    expect_verdict "has/slash/1234"                            reject
    expect_verdict "has.dots.1234"                             reject

    # The 8-character floor, exactly at the boundary.
    echo "==> the minimum length is 8, checked on both sides of the boundary"
    expect_verdict "abcdefg"                                   reject
    expect_verdict "abcdefgh"                                  accept

    if [ "$fail" -ne 0 ]; then
      echo "token-functions check FAILED" >&2
      exit 1
    fi
    echo "all token-function cases pass"
    touch $out
  ''
