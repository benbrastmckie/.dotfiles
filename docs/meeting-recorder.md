# Meeting Recorder

Unattended meeting capture. While a call is in progress the machine records it; when the call
ends it transcribes the recording locally and leaves a Markdown transcript in `~/Meetings`.
Nothing is sent anywhere.

## Where it is declared

| Piece | Location |
|-------|----------|
| Module | `modules/home/services/meeting-recorder.nix` |
| Enabled in | `home.nix` (`services.meetingRecorder`) |
| Model weights | `packages/whisper-ggml-models.nix`, via `overlays/unstable-packages.nix` |
| Call detection | `modules/home/services/lib/video-call-active.nix` (shared, unmodified) |
| Audio prerequisite | `services.pipewire.pulse.enable` in `modules/system/audio.nix` |

## Why it does not use Meetily

[meetily.md](meetily.md) documents the app itself, which is the obvious tool for this and cannot
do it. Meetily's recording is reachable only from its GUI. Verified against the shipped binary:

- `meetily --help` prints nothing and exits 0 — there is no CLI.
- The tray has `Tray: Stopping recording...`, pause and resume, but no start.
- The only external IPC is `org.SingleInstance.DBus` `ExecuteCallback`, which forwards argv to
  the running instance to focus its window.

So no systemd unit can tell Meetily to record. Synthetic clicks through `ydotool` would mean
clicking blind at fixed coordinates inside a webview, which is not worth building on.

Meetily still has a role on the other end — see [Handing a recording to Meetily](#handing-a-recording-to-meetily).

## How it decides a meeting is happening

It reuses `lib/video-call-active.nix` unmodified, becoming that predicate's third consumer
alongside the keepalive and the screen-blank watchdog. That file's own header explains why an
active microphone *capture stream* is the right signal: it is app-agnostic (Zoom, Meet, Jitsi
and anything else), it distinguishes a call from passive video playback, and it excludes
PipeWire's permanently-running internal nodes structurally rather than by name.

Two properties come along for free:

- **The 2-hour idle cap.** A call left open in an empty room stops being recorded once there has
  been no keyboard or pointer input for two hours. Without that, a forgotten meeting would record
  until the disk filled.
- **One definition of "in a call".** A second, drifting copy of that logic would let the recorder
  and the keepalive disagree. The module must never grow its own.

## Units

Three units and two timers, following the shape of `video-call-keepalive.nix` for the same
reason: capturing needs a live process, deciding whether to capture does not.

| Unit | Role |
|------|------|
| `meeting-record-monitor.timer` | Fires every `interval` (15s) |
| `meeting-record-monitor.service` | Oneshot; starts or stops the recorder to match the call state |
| `meeting-record.service` | Holds the `ffmpeg` capture for the duration of the call |
| `meeting-transcribe.service` | Oneshot; drains the staging directory |
| `meeting-transcribe.timer` | Hourly backstop for audio a crash or reboot left behind |

Letting systemd own the recorder's lifetime is what makes the stop reliable: `systemctl --user
stop` tears down the control group, so `ffmpeg` cannot be orphaned holding a capture stream after
the call. That matters doubly here — an orphaned capture stream would make the detection
predicate see a call that is not happening.

The normal transcription trigger is `ExecStopPost` on the recorder, not the timer.

## Audio layout, and why the channels are split

Recording captures two sources into one stereo file: **your microphone on the left channel, the
far end on the right**, at 16 kHz signed 16-bit — exactly what Whisper wants.

The far end comes from the default sink's *monitor* source, the loopback of what the speakers are
playing. Both devices are resolved at the moment recording starts, never baked into the unit: the
default sink genuinely moves during normal use (connecting a Bluetooth headset switches it), and
recording the monitor of a sink that is not playing the call yields a silent far-end channel.

Each channel is then transcribed **separately** and the two results merged chronologically.

### Do not switch back to whisper's own diarization

`whisper-cli --diarize` looks like the obvious shortcut and gives wrong answers. It assigns a
speaker by comparing per-channel energy *within each segment it has already chosen*, so when
Whisper merges two speakers' consecutive utterances into one segment — which it readily does —
the louder or longer party wins the whole segment and the other's words are attributed to them.
Measured on a two-speaker fixture, both utterances came back as `(speaker 0)`.

The channel is ground truth. Splitting first means attribution is never inferred at all.

### VAD is not optional

Each channel is mostly silence by construction, since only one side talks at a time — and Whisper
*hallucinates over silence*. The same fixture produced an invented " Thank you." in a quiet
stretch of the far-end channel. Silero VAD (shipped in the model derivation) makes Whisper skip
the silence rather than inventing dialogue for it.

It also pays for the second pass: with VAD, transcribing both channels separately measured
*faster* than one stereo pass over the whole file (2.4s vs 3.3s on a 100s fixture), because the
silence is never decoded.

## Dictation and push-to-talk do not trigger it

The predicate fires on *any* microphone capture, which is what makes it work across Zoom, Meet
and Jitsi without special-casing — and it originally meant speech-to-text looked like a meeting.
Measured: with `whisper-dictate` running, the predicate reported `call active (pw-cat)` and the
recorder started 12 seconds later, capturing the room and the system audio until dictation
stopped.

Two guards now prevent that, for two different kinds of capture.

**Capture this configuration owns marks itself.** `whisper-dictate` tags its stream
`media.role=dictation` and the predicate skips it, the same mechanism the recorder uses on its
own ffmpeg. Anything else you want excluded can opt in the same way — but note the two audio APIs
put the property in different places, and the predicate checks both:

| How the capture is started | Tag with | Lands on |
|---|---|---|
| libpulse (`ffmpeg -f pulse`, most apps) | `PULSE_PROP=media.role=dictation` | the Client object |
| native PipeWire (`pw-record`, `pw-cat`) | `-P '{ media.role = dictation }'` | the Node object |

Add the value to the ignore list in `lib/video-call-active.nix` if you introduce a new one.

**Capture this configuration does not own cannot be marked.** Claude Code's hold-to-talk voice
mode opens the microphone itself and cannot be told to tag anything. `sustainedSeconds` (30s)
covers it: a call must be detected continuously for that long before recording starts, so a
hold-to-talk press never produces a recording. A meeting trivially clears it.

This is a different guard from `minimumSeconds`, and the difference matters: `minimumSeconds`
discards a short recording *after* it has been written to disk, while `sustainedSeconds` stops
it being made. For audio you would rather never capture, only the second one helps.

The cost is the opening of a real meeting — up to `sustainedSeconds` plus one `interval`, so
about 45 seconds. Set `sustainedSeconds = 0` to record from the first tick instead.

## Output

One file per meeting in `~/Meetings`, named for the recording's start time:

```markdown
# Meeting 2026-11-24T16-40-00

- Duration: 1m 40s
- Model: base.en (local, whisper.cpp with silero VAD)
- Speakers: **Me** is this microphone, **Them** is the far end

---

[00:00:00] **Me:** Thanks everyone for joining. I want to walk through the quarterly numbers.
[00:00:12] **Them:** Sounds good.
[00:00:13] **Them:** Before we start, could you confirm whether the deployment window moved?
```

Timestamps are offsets from the start of the recording.

## What gets thrown away

The predicate fires on any microphone capture, so not everything it catches is a meeting. Four
filters, each logged with its reason:

| Condition | Action |
|-----------|--------|
| Shorter than `minimumSeconds` (default 90) | Discarded untranscribed — a "can you hear me?", a dictation command, a mis-clicked call |
| No readable duration | Discarded — a truncated or corrupt file |
| Silence throughout | Transcribed, found empty, discarded — a muted call, or a capture stream that was not a meeting |
| Transcript already exists | Skipped |

That last one is load-bearing rather than an optimisation. With `audioRetentionDays > 0` the
`.wav` deliberately outlives its transcript, so without the guard every hourly backstop pass
would decode it again and overwrite the `.md`, discarding any edits made to it.

Deleting a transcript is therefore the supported way to force a re-transcribe, which is what
makes `meeting-transcribe-now` useful after changing `model`.

## Handing a recording to Meetily

Meetily has `start_import_audio_command` and `validate_audio_file_command`, so a recording made
here can be imported afterwards for its summaries, templates and speaker handling — without
Meetily having been running during the call. Import from its UI; the audio is in
`~/.local/share/meeting-recorder/staging`.

`audioRetentionDays` (default 3) is what keeps that possible. **Note the tension**: setting it to
`0` reclaims disk as soon as the transcript is written, and in exchange permanently forecloses
Meetily's summaries for any meeting it did not record itself. The default keeps a window wide
enough to notice a meeting mattered and act on it. Audio is roughly 115 MB per hour.

## Options

All under `services.meetingRecorder` in `home.nix`:

| Option | Default | Notes |
|--------|---------|-------|
| `transcriptDir` | `~/Meetings` | Plain directory, not a Nix-managed tree |
| `stagingDir` | `~/.local/share/meeting-recorder/staging` | Audio awaiting or retained after transcription |
| `model` | `base.en` | Or `small.en` — better on crosstalk and poor mics, ~3x the decode time |
| `microphone` | `null` | `null` resolves the default source at start; set to `mic_boosted` for the boosted filter chain |
| `threads` | `8` | Well under this host's 24 cores; the unit is also `Nice`d |
| `minimumSeconds` | `90` | Floor below which a recording is discarded after the fact |
| `sustainedSeconds` | `30` | How long a call must hold before recording starts; blocks push-to-talk |
| `audioRetentionDays` | `3` | `0` discards audio immediately after transcription |
| `interval` | `15s` | How often to re-check the call state |

## Operating it

```bash
# Is a call being detected right now, and why?
video-call-active --explain

# What is the recorder doing?
systemctl --user status meeting-record.service
journalctl --user -u meeting-record.service -u meeting-transcribe.service -n 50

# Force a transcription pass (after changing model, or over leftover audio)
meeting-transcribe-now

# Stop recording for the rest of the day without a rebuild
systemctl --user stop meeting-record-monitor.timer
systemctl --user stop meeting-record.service
```

The monitor timer comes back on the next login or rebuild; to disable it durably, set
`services.meetingRecorder.enable = false` in `home.nix`.

## Troubleshooting

**A short call was not recorded at all.** Expected: `sustainedSeconds` requires 30 seconds of
continuous detection before recording starts, so nothing under roughly 45 seconds is captured.

**Nothing is being recorded.** Run `video-call-active --explain` during a call. If it reports
nothing capturing the microphone, the conferencing app is not holding a capture stream the way
the predicate expects; if it reports the idle cap exceeded, there has been no keyboard or pointer
input for two hours.

**The far-end channel is silent.** The call is playing through a sink other than the default one.
`pactl get-default-sink` shows which monitor was recorded.

**Recordings are too quiet.** Set `microphone = "mic_boosted"` to record through the filter chain
in `modules/system/audio.nix`; [screen-recording.md](screen-recording.md) measures why that
exists.

**Transcripts are poor.** Switch `model` to `small.en`, delete the affected `.md` files, and run
`meeting-transcribe-now` — but only within the retention window, since that needs the audio.

**A transcription is pegging the CPU.** It should not be noticeable: the unit runs at `Nice = 15`
with `CPUWeight = 20`. If it is, lower `threads`.

## Privacy

Everything stays on the machine. The weights are a Nix store path, so no model is contacted over
the network and the first run needs no download. Recording, transcription and filing all happen
locally.

Worth stating plainly, because the module records without being asked each time: a meeting
recording may capture other people, and consent and legality vary by jurisdiction and by who is
on the call. The module decides *when* to record; whether you should is not a decision it can
make.

[← Back to documentation index](README.md)
