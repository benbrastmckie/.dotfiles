# Video Editing Workflow

Record clips on iPhone, transcribe them, mark what to keep, and let Claude Code assemble the final video.

## Software

All installed via Home Manager (`home.nix`):

| Tool | Purpose |
|------|---------|
| `ffmpeg` | Audio extraction, video trimming, concatenation |
| `whisper-cli` | Speech-to-text with timestamps (whisper.cpp) |
| `obs-studio` | Webcam recording with live preview (optional) |
| `moviepy` | Python-scripted editing for complex operations |

Whisper model location: `~/.local/share/whisper/ggml-base.bin`

## Workflow

### 1. Transfer clips

Copy `.MOV` files from iPhone to a working directory (AirDrop, USB, or cloud sync).

### 2. Extract audio and transcribe

For each clip, extract 16kHz mono WAV and run whisper:

```bash
ffmpeg -y -i clip_01.MOV -ar 16000 -ac 1 -c:a pcm_s16le clip_01.wav
whisper-cli -m ~/.local/share/whisper/ggml-base.bin -f clip_01.wav --output-srt --output-file clip_01
```

This produces `clip_01.srt` with timed segments:

```
1
00:00:00,000 --> 00:00:08,260
 AI systems can generate anything, legal briefs, medical advice.

2
00:00:08,260 --> 00:00:13,840
 Their outputs are compelling yet unverified.
```

### 3. Mark the transcript

Open the `.srt` file and add `>>>KEEP` or `>>>CUT` markers above each segment (or group of segments) to indicate what stays and what goes:

```
>>>KEEP
1
00:00:00,000 --> 00:00:08,260
 AI systems can generate anything, legal briefs, medical advice.

>>>CUT
2
00:00:08,260 --> 00:00:13,840
 Their outputs are compelling yet unverified.

>>>KEEP
3
00:00:13,840 --> 00:00:19,080
 But human attention does not scale with compute.
```

Unmarked segments at the top default to `>>>KEEP`. A marker applies to all segments below it until the next marker.

### 4. Let Claude Code edit

Give Claude Code the marked transcript and source video. It will:

1. Parse the `>>>KEEP` ranges from the SRT
2. Trim the source video into keep segments using `ffmpeg -c copy` (no re-encoding, fast)
3. Concatenate the segments into the final video

### 5. Review and iterate

Watch the result. If a cut needs adjusting, update the markers and re-run.

## Quick reference

```bash
# Inspect a clip
ffprobe -v quiet -show_entries stream=codec_name,width,height,duration -of compact input.MOV

# Extract audio for whisper
ffmpeg -y -i input.MOV -ar 16000 -ac 1 -c:a pcm_s16le audio.wav

# Transcribe
whisper-cli -m ~/.local/share/whisper/ggml-base.bin -f audio.wav --output-srt --output-file transcript

# Trim without re-encoding
ffmpeg -i input.MOV -ss 00:00:05.000 -to 00:01:30.000 -c copy segment.mp4

# Concatenate segments
ffmpeg -f concat -safe 0 -i filelist.txt -c copy final.mp4
```

The `filelist.txt` for concatenation uses the format:

```
file 'segment_01.mp4'
file 'segment_02.mp4'
file 'segment_03.mp4'
```
