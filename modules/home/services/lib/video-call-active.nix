# Shared predicate: "is a video call in progress right now, and should the screen stay lit?"
#
# Imported by BOTH consumers so there is exactly one definition of "in a call":
#   - modules/home/services/video-call-keepalive.nix  (holds the inhibitors)
#   - modules/home/services/screen-blank-watchdog.nix (stands down)
# A second, drifting copy of this logic would let the two disagree, which shows up as a screen
# that blanks while the inhibitors claim it should not.
#
# Exit 0 = carve-out applies (a call is live AND the idle cap below has not been exceeded).
# Exit 1 = it does not. Never exits non-zero for any other reason: an unreadable PipeWire or a
# missing DBus name is reported as "no call", because the fail-safe direction here is to let the
# ordinary blank/suspend behaviour stand rather than pin the screen on from a broken probe.
#
# == Why the microphone, and not an idle inhibitor ==
#
# The obvious signal is the GNOME SessionManager idle inhibitor (flag 8) that a conferencing app
# registers -- and Zoom does exactly that, with the unusually honest app-id "zoom" and reason
# "in a meeting". But that signal cannot carry this on its own, for two independent reasons:
#
#   1. Google Meet has no equivalent. In a Chromium-family browser a Meet call surfaces as the
#      generic "Video Wake Lock" inhibitor -- byte-identical to the one the same browser holds
#      while playing YouTube or Netflix. Trusting it would re-admit precisely the forgotten-tab
#      pin that docs/no-sleep-agents.md mechanism 5 exists to defeat.
#   2. It would make the carve-out hostage to each app's own good behaviour.
#
# An active microphone *capture stream* separates the two cleanly: a Meet/Zoom/Jitsi call
# captures the mic, and passive video playback does not. It is also app-agnostic, so it covers
# conferencing tools nobody has thought to special-case yet.
#
# The camera is deliberately NOT part of the test -- joining with video off is normal, and on
# this host the camera node sits "suspended" through an entire call.
#
# == The internal-node trap ==
#
# "Any running capture stream" is NOT a usable test, and getting this wrong fails in the worst
# possible direction -- permanently true, screen never blanks again, no visible cause. PipeWire
# keeps internal capture nodes running at all times. On this host (verified from a live
# `pw-dump`):
#
#   capture.mic_boosted                   the mic-boost filter chain from modules/system/audio.nix
#   bluez_capture_internal.<addr>         a bluez loopback
#
# Both are permanently "running". They are excluded structurally rather than by name, by
# resolving each node's `client.id` to the owning client's `application.process.binary` and
# dropping the ones owned by the PipeWire/WirePlumber daemons themselves. Verified live: the
# filter chain resolves to `pipewire`, a real app resolves to its own binary (`zoom` over the
# pipewire-pulse API, `pw-cat` over the native API). The `node.link-group` prefix test is
# belt-and-braces for a future filter chain loaded by a non-daemon process.
#
# Note that `application.process.binary` on the *node* is not usable for this: it is populated
# for pipewire-pulse clients (Zoom) and null for native PipeWire clients, so a node-level test
# silently misses whole classes of app. The client-object lookup is what makes it uniform.
#
# == The self-recording trap ==
#
# services/meeting-recorder.nix records a call by capturing the microphone, which means ITS OWN
# capture stream satisfies the test above. Measured consequence, before the exclusion below
# existed: the recorder started on a real call, the call ended, the monitor re-ran this predicate,
# saw the recorder's own ffmpeg, kept the recording running, and the recording never stopped --
# a 110-second call produced a 6m40s file still growing when it was killed by hand, and would
# have run to the idle cap. The keepalive has the milder form of the same bug, holding the screen
# lit after a call because the recorder is still recording.
#
# So the recorder marks its own stream with `media.role=meeting-recorder` (via `PULSE_PROP`, which
# libpulse merges into the client proplist -- verified reaching the Client object in a live
# `pw-dump`) and that marker is excluded here. This is the right place for it: the exclusion is
# correct for EVERY consumer, since a recording made because a call was detected is never itself
# evidence of a call. It is also structural rather than a binary-name blacklist -- excluding
# `ffmpeg` by name would break any legitimate ffmpeg capture, which is exactly the failure mode
# the daemon exclusion above is written to avoid.
{ pkgs }:
let
  # Upper bound on the carve-out, in seconds of continuous *real input* idleness (keyboard and
  # pointer only, straight from mutter's idle monitor -- background activity does not reset it).
  #
  # This exists so the carve-out cannot become the very thing mechanism 5 was built to kill: an
  # unbounded, invisible pin on the screen. A conferencing app left sitting in an empty meeting
  # holds its capture stream open indefinitely, and without a bound that would disable blanking
  # until someone noticed.
  #
  # The bound is on idle time rather than call duration on purpose. A real meeting -- however
  # long -- gets a keypress or a mouse movement far more often than once every two hours, so each
  # touch re-arms the full window and a genuine all-day call is never interrupted. Two hours of a
  # live call with zero input, by contrast, means nobody is at the machine. Past the cap the
  # ordinary 5-minute blank resumes; the next real input restores the carve-out immediately.
  idleCapSeconds = 7200;
in
pkgs.writeShellScript "video-call-active" ''
  set -u

  busctl=${pkgs.systemd}/bin/busctl
  jq=${pkgs.jq}/bin/jq
  pw_dump=${pkgs.pipewire}/bin/pw-dump

  explain=0
  [ "''${1:-}" = "--explain" ] && explain=1

  say() { [ "$explain" -eq 1 ] && echo "$@"; return 0; }

  # ----------------------------------------------------------------------------------------
  # 1. Which real applications are capturing the microphone right now?
  # ----------------------------------------------------------------------------------------
  holders=$("$pw_dump" 2>/dev/null | "$jq" -r '
    . as $all
    | [ $all[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["media.class"] == "Stream/Input/Audio")
        | select(.info.state == "running")
        | select((.info.props["node.link-group"] // "") | test("^(filter-chain|loopback)") | not)
        | .info.props["client.id"] as $cid
        | ( [ $all[]
              | select(.type == "PipeWire:Interface:Client")
              | select(.id == $cid) ][0] ) as $client
        | ( $client.info.props["application.process.binary"] ) as $bin
        | select($bin != null)
        | select(["pipewire", "wireplumber", "pipewire-pulse"] | index($bin) | not)
        | select(($client.info.props["media.role"] // "") == "meeting-recorder" | not)
        | $bin
      ] | unique | .[]
  ' 2>/dev/null) || holders=""

  if [ -z "$holders" ]; then
    say "no call: nothing is capturing the microphone"
    exit 1
  fi

  # ----------------------------------------------------------------------------------------
  # 2. Bound it (see idleCapSeconds above).
  # ----------------------------------------------------------------------------------------
  # A missing idle monitor means no GNOME session, i.e. niri -- where the screen-blank watchdog
  # no-ops anyway and there is no idle auto-suspend at all, so the cap has nothing to bound and
  # is skipped rather than being treated as exceeded.
  idle_ms=$("$busctl" --user call org.gnome.Mutter.IdleMonitor \
    /org/gnome/Mutter/IdleMonitor/Core org.gnome.Mutter.IdleMonitor GetIdletime \
    2>/dev/null | ${pkgs.gnused}/bin/sed 's/^t //') || idle_ms=""

  case "$idle_ms" in
    "" | *[!0-9]*)
      say "call active ($(echo $holders)); no idle monitor, cap not applicable"
      exit 0
      ;;
  esac

  if [ "$idle_ms" -ge $(( ${toString idleCapSeconds} * 1000 )) ]; then
    say "call active ($(echo $holders)) but idle ''${idle_ms}ms exceeds the ${toString idleCapSeconds}s cap: standing down"
    exit 1
  fi

  say "call active ($(echo $holders)), idle ''${idle_ms}ms within the ${toString idleCapSeconds}s cap"
  exit 0
''
