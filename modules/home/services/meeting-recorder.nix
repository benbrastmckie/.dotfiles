# Unattended meeting capture: records a call while one is in progress, transcribes it locally
# once it ends, and leaves a Markdown transcript in a designated folder.
#
# == Why this is not driven through Meetily ==
#
# Meetily (packages/meetily.nix, docs/meetily.md) is the interactive tool for this job, but its
# recording cannot be started from outside its GUI. Verified against the shipped binary:
# `meetily --help` prints nothing and exits 0, so there is no CLI; the tray exposes
# "Tray: Stopping recording...", pause and resume but has no start; and the only external IPC is
# tauri-plugin-single-instance's `org.SingleInstance.DBus` `ExecuteCallback`, which forwards argv
# to the running instance to focus its window and nothing more. An `autoStartRecording` string
# exists in the binary exactly once with no verifiable wiring to a file preference. So no systemd
# unit can tell Meetily to record, and the alternative -- synthetic clicks via ydotool at fixed
# coordinates inside a webview -- is not a foundation worth building on.
#
# Meetily keeps its place by taking the audio afterwards: it has `start_import_audio_command` and
# `validate_audio_file_command`, so a recording made here can be imported for its summaries and
# templates without it having been running during the call. That is what `audioRetentionDays`
# below is for.
#
# == Shape ==
#
# Two units plus a timer, the pattern services/video-call-keepalive.nix establishes and for the
# same reason: capturing needs a live process, deciding whether to capture does not.
#
#   meeting-record.service          Holds the ffmpeg capture for as long as it is active. Never
#                                   started by a target -- only by the monitor below.
#   meeting-record-monitor.service  A oneshot, fired by a timer, that starts or stops the
#                                   recorder to match the current call state.
#   meeting-transcribe.service      A oneshot that drains the staging directory.
#
# Letting systemd own the recorder's lifetime is what makes the stop reliable: `systemctl --user
# stop` tears down the control group, so ffmpeg cannot be orphaned and left holding a capture
# stream after the call -- which would also make lib/video-call-active.nix see a call that is not
# happening, since an open capture stream is exactly what it looks for.
#
# == What decides "a meeting is happening" ==
#
# lib/video-call-active.nix, unmodified and shared with the keepalive and screen-blank-watchdog
# consumers. It is the right predicate here for the reasons its own header gives (an active
# microphone capture stream, app-agnostic, with internal PipeWire nodes excluded structurally
# rather than by name), and its 2-hour continuous-input-idleness cap carries over for free: a
# meeting left open in an empty room stops being recorded rather than filling the disk
# unattended.
#
# Critical: this file must NOT grow its own copy of that predicate. Three consumers agreeing is
# the whole point of the shared script.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.meetingRecorder;
  videoCallActive = import ./lib/video-call-active.nix { inherit pkgs; };

  # Resolved once here so the recorder and the transcriber cannot disagree about where audio is
  # handed over.
  staging = cfg.stagingDir;
in
{
  options.services.meetingRecorder = {
    enable = lib.mkEnableOption "unattended meeting recording and local transcription";

    transcriptDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Meetings";
      description = ''
        Directory the finished Markdown transcripts are written to. Created on activation.
        One file per meeting, named for the recording's start time.
      '';
    };

    stagingDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/meeting-recorder/staging";
      description = ''
        Where raw audio waits between the end of a recording and the end of its transcription.
        A separate directory from `transcriptDir` on purpose: the transcriber treats every .wav
        it finds here as outstanding work, so a recording interrupted by a crash or a reboot is
        picked up on the next pass rather than lost.
      '';
    };

    model = lib.mkOption {
      type = lib.types.enum [
        "base.en"
        "small.en"
      ];
      default = "base.en";
      description = ''
        Which Whisper model to transcribe with, from packages/whisper-ggml-models.nix.
        `base.en` runs several times faster than real time on this host and is adequate for
        clear, one-speaker-at-a-time audio. `small.en` is noticeably better on crosstalk and
        poor headset microphones at roughly 3x the decode time. Adding a size means adding it
        to the model derivation first.
      '';
    };

    microphone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "mic_boosted";
      description = ''
        PulseAudio source name for your voice. `null` resolves the default source at the moment
        recording starts, which is almost always what you want.

        Set it to `mic_boosted` to record through the filter chain in modules/system/audio.nix
        instead -- worth doing if recordings come out too quiet, for the reasons
        docs/screen-recording.md measures.
      '';
    };

    threads = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = ''
        Threads for the transcription pass. Deliberately well under this host's 24 cores: the
        pass runs unattended and must stay in the background, which the unit also enforces with
        Nice and CPUWeight.
      '';
    };

    minimumSeconds = lib.mkOption {
      type = lib.types.int;
      default = 90;
      description = ''
        Recordings shorter than this are discarded untranscribed. The predicate fires on any
        microphone capture, so a brief "can you hear me?" check, a dictation command or a
        mis-clicked call all produce short files that are not meetings.
      '';
    };

    audioRetentionDays = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = ''
        How long the source .wav is kept after it has been transcribed successfully. `0` deletes
        it as soon as the transcript is written.

        Note the trade this setting IS: the retained audio is the only thing that makes
        Meetily's audio import usable after the fact, so `0` buys disk back at the cost of
        never being able to get Meetily's summaries for a meeting it did not record itself. The
        default keeps a few days, which covers "that meeting turned out to matter, run it
        through Meetily" without accumulating. Audio is 16 kHz stereo PCM, roughly 115 MB per
        hour.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = ''
        How often to re-check whether a call is in progress. Looser than the keepalive's 15s
        because nothing here is racing a 5-minute screen blank -- the cost of a slow tick is
        only up to this much missing from the start of a recording.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # On-demand transcription pass, for draining the staging directory by hand after changing
      # the model or inspecting a recording that failed.
      (pkgs.writeShellScriptBin "meeting-transcribe-now" ''
        exec ${pkgs.systemd}/bin/systemctl --user start meeting-transcribe.service
      '')
    ];

    # Both directories exist before any unit runs. home.file would need a tracked file inside
    # each; an activation step is the lighter way to assert a bare directory.
    home.activation.meetingRecorderDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg cfg.transcriptDir} \
        ${lib.escapeShellArg staging}
    '';

    # Note: one `services` attribute and one `timers` attribute rather than five dotted paths.
    # statix's repeated-keys check rejects re-opening the same key three times, the same
    # constraint services/video-call-keepalive.nix documents.
    systemd.user = {
      services = {
        meeting-record = {
          Unit = {
            Description = "Capture meeting audio while a call is in progress";
            # Tear down with the session rather than recording into a logged-out session.
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";

            # Critical: ffmpeg must be allowed to finish on SIGTERM. A WAV header carries the
            # data length, which is only patched in when the file is closed, so a killed ffmpeg
            # leaves a file whose header claims zero samples. ffmpeg handles SIGTERM gracefully;
            # this just gives it room to.
            TimeoutStopSec = "30s";

            ExecStart =
              let
                script = pkgs.writeShellScript "meeting-record" ''
                  set -u
                  export PATH="${
                    lib.makeBinPath [
                      pkgs.coreutils
                      pkgs.ffmpeg
                      pkgs.pulseaudio # pactl
                    ]
                  }:$PATH"

                  mkdir -p ${lib.escapeShellArg staging}

                  # Resolved at start, never baked in: the default sink genuinely moves during
                  # normal use (a Bluetooth headset connecting switches it), and recording the
                  # monitor of a sink that is not playing the call yields silence on the far-end
                  # channel.
                  ${
                    if cfg.microphone == null then
                      ''mic="$(pactl get-default-source 2>/dev/null)"''
                    else
                      "mic=${lib.escapeShellArg cfg.microphone}"
                  }
                  sink="$(pactl get-default-sink 2>/dev/null)"

                  if [ -z "$mic" ]; then
                    echo "meeting-record: no microphone source resolved; not recording"
                    exit 0
                  fi

                  out="${staging}/$(date +%Y-%m-%dT%H-%M-%S).wav"
                  echo "meeting-record: mic=$mic sink=$sink -> $out"

                  # Mic on the left channel, far-end on the right, 16 kHz s16 stereo.
                  #
                  # The channel split is not cosmetic: whisper-cli's --diarize compares
                  # per-channel energy to label segments, so this layout turns "which channel was
                  # louder" into "me vs. everyone else" and the transcript comes out attributed.
                  # Mixing to mono would throw that away for no saving that matters.
                  #
                  # `join` rather than `amerge`: amerge warns about overlapping input layouts on
                  # every start and leaves the output layout implied by channel count, which is
                  # noise in a unit that runs unattended.
                  #
                  # A missing sink is not fatal -- record the microphone alone, duplicated across
                  # both channels so the file shape stays constant for the transcriber.
                  # Diarization then has nothing to separate, which is honest: there was no
                  # far-end audio.
                  if [ -n "$sink" ]; then
                    exec ffmpeg -nostdin -hide_banner -loglevel warning \
                      -f pulse -i "$mic" \
                      -f pulse -i "$sink.monitor" \
                      -filter_complex "[0:a]aresample=16000,aformat=sample_fmts=s16:channel_layouts=mono[mic];[1:a]aresample=16000,aformat=sample_fmts=s16:channel_layouts=mono[sys];[mic][sys]join=inputs=2:channel_layout=stereo[out]" \
                      -map "[out]" -c:a pcm_s16le "$out"
                  fi

                  echo "meeting-record: no default sink; recording the microphone only"
                  exec ffmpeg -nostdin -hide_banner -loglevel warning \
                    -f pulse -i "$mic" \
                    -ac 2 -ar 16000 -c:a pcm_s16le "$out"
                '';
              in
              "${script}";

            # Hand off as soon as the capture stops, however it stopped. --no-block so a long
            # transcription does not hold this unit in `deactivating`, and so a transcription
            # failure cannot mark the recorder failed.
            ExecStopPost = "${pkgs.systemd}/bin/systemctl --user start --no-block meeting-transcribe.service";
          };
        };

        meeting-record-monitor = {
          Unit = {
            Description = "Start/stop meeting recording to match the current call state";
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart =
              let
                script = pkgs.writeShellScript "meeting-record-monitor" ''
                  set -u
                  systemctl=${pkgs.systemd}/bin/systemctl

                  # start/stop are idempotent and silent on a no-op, so this runs every tick
                  # without logging churn -- systemd records only a real state transition.
                  if ${videoCallActive}; then
                    exec "$systemctl" --user start meeting-record.service
                  fi
                  exec "$systemctl" --user stop meeting-record.service
                '';
              in
              "${script}";
          };
        };

        meeting-transcribe = {
          Unit = {
            Description = "Transcribe finished meeting recordings and retire their audio";
          };
          Service = {
            Type = "oneshot";

            # A transcription pass is minutes of saturated CPU. It is background work by
            # definition, so it yields to anything the user is actually doing.
            Nice = 15;
            CPUWeight = 20;
            IOWeight = 20;

            # A cold pass over several recordings after a reboot can be long; the default would
            # kill it partway and leave the audio to be retried.
            TimeoutStartSec = "6h";

            ExecStart =
              let
                models = "${pkgs.whisper-ggml-models}/share/whisper-models";
                model = "${models}/ggml-${cfg.model}.bin";
                vadModel = "${models}/ggml-silero-v5.1.2.bin";
                script = pkgs.writeShellScript "meeting-transcribe" ''
                  export PATH="${
                    lib.makeBinPath [
                      pkgs.coreutils
                      pkgs.ffmpeg # ffprobe, and the channel split
                      pkgs.findutils
                      pkgs.jq
                      pkgs.psmisc # fuser
                      pkgs.whisper-cpp
                    ]
                  }:$PATH"
                  # Deliberately no `set -e`: one unreadable recording must not abandon the rest,
                  # and this unit always reaches exit 0. A failed user unit degrades the whole
                  # `systemd --user` session rather than just itself, and the work is retried on
                  # the next pass anyway because the audio stays in staging until it succeeds.

                  staging=${lib.escapeShellArg staging}
                  dest=${lib.escapeShellArg cfg.transcriptDir}
                  mkdir -p "$staging" "$dest"

                  echo "meeting-transcribe: starting"

                  for wav in "$staging"/*.wav; do
                    [ -e "$wav" ] || continue
                    base="$(basename "$wav" .wav)"

                    # Skip anything still being written: the recorder holds the file open for the
                    # length of the call, and the backstop timer can fire a pass while that is
                    # happening.
                    if fuser -s "$wav" 2>/dev/null; then
                      echo "meeting-transcribe: $base is still being recorded, leaving it"
                      continue
                    fi

                    # Critical: already-transcribed audio must be skipped, not re-transcribed.
                    # With audioRetentionDays > 0 the .wav deliberately outlives its transcript,
                    # so without this guard every backstop pass (hourly) would decode it again
                    # -- burning CPU and, worse, overwriting the .md and discarding any edits
                    # made to it. Deleting the .md is therefore also the supported way to force
                    # a re-transcribe, which is what makes `meeting-transcribe-now` useful after
                    # changing `model`.
                    if [ -e "$dest/$base.md" ]; then
                      continue
                    fi

                    secs="$(ffprobe -v error -show_entries format=duration \
                      -of default=nw=1:nk=1 "$wav" 2>/dev/null | cut -d. -f1)"
                    case "$secs" in
                      "" | *[!0-9]*)
                        echo "meeting-transcribe: $base has no readable duration, discarding"
                        rm -f "$wav"
                        continue
                        ;;
                    esac

                    if [ "$secs" -lt ${toString cfg.minimumSeconds} ]; then
                      echo "meeting-transcribe: $base is ''${secs}s, under the ${toString cfg.minimumSeconds}s floor, discarding"
                      rm -f "$wav"
                      continue
                    fi

                    echo "meeting-transcribe: transcribing $base (''${secs}s) with ${cfg.model}"

                    # Each channel is transcribed SEPARATELY, then merged chronologically.
                    #
                    # Critical: do not be tempted back to whisper-cli's own `--diarize` on the
                    # stereo file. It assigns a speaker by comparing per-channel energy within
                    # each segment it has already chosen, so when whisper merges two speakers'
                    # consecutive utterances into one segment -- which it readily does -- the
                    # louder or longer party wins the whole segment and the other's words are
                    # attributed to them. Measured on a two-speaker fixture, both utterances came
                    # back as `(speaker 0)`. The channel is ground truth here; splitting first
                    # means attribution is never inferred at all.
                    #
                    # `--vad` is what makes the split affordable and correct. Each channel is
                    # mostly silence (only one side talks at a time), and whisper hallucinates
                    # over silence -- the same fixture produced an invented " Thank you." in a
                    # quiet stretch. VAD skips the silence, so the second pass costs far less
                    # than the first did and neither invents dialogue. `-sns` additionally
                    # suppresses non-speech tokens.
                    rm -f "$staging/$base.ch-"*.wav "$staging/$base.ch-"*.json

                    if ! ffmpeg -nostdin -hide_banner -loglevel error -y -i "$wav" \
                      -filter_complex "[0:a]pan=mono|c0=c0[l];[0:a]pan=mono|c0=c1[r]" \
                      -map "[l]" -c:a pcm_s16le "$staging/$base.ch-me.wav" \
                      -map "[r]" -c:a pcm_s16le "$staging/$base.ch-them.wav" 2>/dev/null; then
                      echo "meeting-transcribe: could not split channels for $base, keeping audio"
                      continue
                    fi

                    ok=1
                    for side in me them; do
                      if ! whisper-cli \
                        -m ${model} \
                        --vad -vm ${vadModel} \
                        -t ${toString cfg.threads} \
                        -np -sns -oj \
                        -of "$staging/$base.ch-$side" \
                        "$staging/$base.ch-$side.wav" >/dev/null 2>&1; then
                        echo "meeting-transcribe: whisper-cli failed on $base ($side channel)"
                        ok=0
                        break
                      fi
                    done

                    if [ "$ok" -ne 1 ] \
                      || [ ! -s "$staging/$base.ch-me.json" ] \
                      || [ ! -s "$staging/$base.ch-them.json" ]; then
                      echo "meeting-transcribe: $base produced no transcript, keeping audio for the next pass"
                      rm -f "$staging/$base.ch-"*.wav "$staging/$base.ch-"*.json
                      continue
                    fi

                    # Interleave both channels by start offset. `| not` rather than `!=` for the
                    # negated test, per the jq-escaping hazard in CLAUDE.md.
                    jq -rs '
                      [ (.[0].transcription[] | {t: .offsets.from, who: "Me",   text: (.text | gsub("^\\s+|\\s+$"; ""))}),
                        (.[1].transcription[] | {t: .offsets.from, who: "Them", text: (.text | gsub("^\\s+|\\s+$"; ""))}) ]
                      | map(select((.text | length) > 0))
                      | map(select(.text | test("^\\[(BLANK_AUDIO|SOUND|MUSIC)") | not))
                      | sort_by(.t)
                      | .[]
                      | "[\((.t / 1000) | floor | strftime("%H:%M:%S"))] **\(.who):** \(.text)"
                    ' "$staging/$base.ch-me.json" "$staging/$base.ch-them.json" \
                      > "$staging/$base.body" 2>/dev/null

                    rm -f "$staging/$base.ch-"*.wav "$staging/$base.ch-"*.json

                    # Nobody spoke: a muted call, or a capture stream held open by something that
                    # turned out not to be a meeting. With VAD there is no [BLANK_AUDIO] filler
                    # to look past -- an empty body means an empty recording.
                    if [ ! -s "$staging/$base.body" ]; then
                      echo "meeting-transcribe: $base is silence throughout, discarding"
                      rm -f "$wav" "$staging/$base.body"
                      continue
                    fi

                    {
                      echo "# Meeting $base"
                      echo
                      echo "- Duration: $((secs / 60))m $((secs % 60))s"
                      echo "- Model: ${cfg.model} (local, whisper.cpp with silero VAD)"
                      echo "- Speakers: **Me** is this microphone, **Them** is the far end"
                      echo
                      echo "---"
                      echo
                      cat "$staging/$base.body"
                    } > "$dest/$base.md"

                    rm -f "$staging/$base.body"
                    echo "meeting-transcribe: wrote $dest/$base.md"

                    ${
                      if cfg.audioRetentionDays == 0 then
                        ''
                          rm -f "$wav"
                          echo "meeting-transcribe: discarded audio for $base (audioRetentionDays = 0)"
                        ''
                      else
                        ''
                          echo "meeting-transcribe: keeping audio for $base, importable into Meetily for ${toString cfg.audioRetentionDays}d"
                        ''
                    }
                  done

                  ${lib.optionalString (cfg.audioRetentionDays > 0) ''
                    # Retire audio whose transcript was filed more than the retention window ago.
                    # Guarded on the .md existing so an untranscribed recording is never aged out
                    # from under the transcriber.
                    for wav in "$staging"/*.wav; do
                      [ -e "$wav" ] || continue
                      base="$(basename "$wav" .wav)"
                      [ -e "$dest/$base.md" ] || continue
                      if [ -n "$(find "$wav" -mtime +${toString cfg.audioRetentionDays} -print -quit 2>/dev/null)" ]; then
                        rm -f "$wav"
                        echo "meeting-transcribe: retired audio for $base past the ${toString cfg.audioRetentionDays}d window"
                      fi
                    done
                  ''}

                  echo "meeting-transcribe: done"
                  exit 0
                '';
              in
              "${script}";
          };
        };
      };

      timers = {
        meeting-record-monitor = {
          Unit = {
            Description = "Periodic check for a meeting to record";
            # No Requires= on the service: Requires= stop-propagates, so stopping the service by
            # hand would silently deactivate this timer too. Timer.Unit already pulls in the
            # same-named service. (Same reasoning as services/video-call-keepalive.nix.)
          };
          Timer = {
            OnBootSec = "1min";
            OnUnitActiveSec = cfg.interval;
            AccuracySec = "5s";
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };

        # A backstop, not the main path: ExecStopPost on the recorder is what normally triggers a
        # pass. This catches audio left in staging by a crash, a reboot mid-call, or a
        # whisper-cli failure that is retried.
        meeting-transcribe = {
          Unit = {
            Description = "Backstop timer to drain any un-transcribed meeting audio";
          };
          Timer = {
            OnBootSec = "10min";
            OnUnitActiveSec = "1h";
            Persistent = true;
            RandomizedDelaySec = "5min";
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      };
    };
  };
}
