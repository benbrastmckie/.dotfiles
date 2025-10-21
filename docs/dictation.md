# Whisper Dictation Setup

## Overview

System-wide speech-to-text dictation using OpenAI's Whisper model (whisper.cpp). Works offline and integrates with both GNOME and Niri sessions via Wayland.

## Features

- **Offline Processing**: All speech recognition happens locally
- **Fast Inference**: whisper.cpp is 2-5x faster than Python Whisper
- **Universal Input**: Uses `ydotool` for text input (works with GNOME/Wayland/X11)
- **Toggle Mode**: Press once to start, again to stop and transcribe
- **Visual Feedback**: Desktop notifications show status and transcribed text
- **System-wide**: Works in any application (browser, editor, terminal, etc.)

## Installation

The dictation tools are already configured in `home.nix`:

- `openai-whisper-cpp`: Fast C++ implementation of Whisper
- `ydotool`: Universal input tool (works with GNOME on Wayland)
- `whisper-dictate`: Custom script that ties everything together
- `whisper-download-models`: Helper to download AI models

**Note**: ydotool requires a background daemon (`ydotoold`) which is automatically started as a systemd user service.

## Setup (First Time Only)

### 1. Rebuild System and Home Manager

```bash
cd ~/.dotfiles

# Rebuild system (adds you to 'input' group for ydotool)
sudo nixos-rebuild switch --flake .#$(hostname)

# Rebuild home manager (installs dictation tools)
home-manager switch --flake .#benjamin

# Log out and back in (to apply group membership)
```

**Important**: You must log out and back in for the `input` group membership to take effect.

### 2. Download Whisper Model

Choose a model size based on your needs:

| Model | Size | Accuracy | Speed | RAM Usage |
|-------|------|----------|-------|-----------|
| `tiny` | ~75MB | Basic | Very Fast | ~1GB |
| `base` | ~150MB | Good | Fast | ~1.5GB |
| `small` | ~500MB | Better | Medium | ~2.5GB |
| `medium` | ~1.5GB | Best | Slow | ~5GB |

**Download the base model (recommended):**
```bash
whisper-download-models base
```

**Or download a different size:**
```bash
# For fastest speed (lower accuracy)
whisper-download-models tiny

# For best accuracy (slower)
whisper-download-models small
```

Models are stored in `~/.local/share/whisper/`

### 3. Test Your Microphone

Verify your microphone is working:

```bash
# Record 5 seconds of audio and play it back
pw-record --format=s16 --rate=16000 test.wav &
PID=$!
sleep 5
kill $PID
pw-play test.wav
rm test.wav
```

You should hear your voice played back.

## Usage

### Niri Session

Press **Mod+d** (Super+d) to start/stop dictation:

1. **First press**: Start recording (notification appears)
2. **Speak**: Say what you want to type
3. **Second press**: Stop recording and transcribe
4. **Result**: Text is automatically typed at cursor position

### GNOME Session

**Step-by-Step Keybinding Setup:**

1. **Open GNOME Settings**:
   ```bash
   gnome-control-center keyboard
   ```
   Or: Activities → Search "Keyboard" → Click "Keyboard"

2. **Scroll down to "Custom Shortcuts"** section at the bottom

3. **Click "Add Custom Shortcut" (+ button)**

4. **Fill in the dialog**:
   - **Name**: `Dictation`
   - **Command**: `whisper-dictate`
   - **Shortcut**: Click "Set Shortcut..." then press your keys

5. **Recommended Keybindings** (choose one that doesn't conflict):
   - **Super+D** - Simple and memorable (may conflict with "Show Desktop")
   - **Super+Shift+D** - Less likely to conflict
   - **Super+Ctrl+Space** - Similar to voice input on macOS
   - **Super+Period** - Easy to reach

6. **Test it**: Press your keybinding in any text field!

## Configuration

### Change Model Size

Set environment variable in your shell config (`~/.config/fish/config.fish`):

```fish
set -x WHISPER_MODEL_SIZE small  # or tiny, base, medium, large
```

Or set it temporarily:
```bash
WHISPER_MODEL_SIZE=small whisper-dictate
```

### Customize Keybinding (Niri)

Edit `~/.config/niri/config.kdl`:

```kdl
binds {
    # Change Mod+d to something else
    Mod+Shift+d { spawn "whisper-dictate" }
}
```

Then reload config: **Mod+Shift+r**

## How It Works

1. **Start Recording**: `pw-record` captures audio from your microphone
2. **Stop Recording**: Kill the recording process, save audio to `/tmp/whisper-dictation/recording.wav`
3. **Transcribe**: `whisper-cpp` converts speech to text
4. **Type**: `ydotool` simulates keyboard input to type the transcribed text

All processing happens locally on your machine.

**Why ydotool?** GNOME's compositor (Mutter) doesn't support the virtual keyboard protocol that other tools like `wtype` need. ydotool works at a lower level using Linux's uinput system, which works with all compositors.

## Troubleshooting

### No Microphone Input

**Check PipeWire is running:**
```bash
systemctl --user status pipewire
```

**List available audio sources:**
```bash
pw-cli list-objects | grep -i node.name
```

**Test recording:**
```bash
pw-record --format=s16 --rate=16000 test.wav
# Speak for a few seconds, then Ctrl+C
pw-play test.wav
```

### Model Not Found Error

**Download the model first:**
```bash
whisper-download-models base
```

**Verify model exists:**
```bash
ls -lh ~/.local/share/whisper/
```

### Text Not Typing

**Check if ydotoold daemon is running:**
```bash
systemctl --user status ydotool
```

Should show "active (running)". If not:
```bash
systemctl --user start ydotool
systemctl --user enable ydotool
```

**Verify you're in the input group:**
```bash
groups | grep input
```

If not listed, you need to log out and back in after rebuilding.

**Test ydotool manually:**
```bash
# Click in a text field first, then:
ydotool type "Hello World"
```

This should type "Hello World" at your cursor.

### Poor Accuracy

**Try a larger model:**
```bash
whisper-download-models small
WHISPER_MODEL_SIZE=small whisper-dictate
```

**Speak clearly:**
- Use a quiet environment
- Speak at normal pace (not too fast/slow)
- Stay close to microphone
- Use full sentences

### Notifications Not Showing

**Check Mako (Niri) or GNOME notifications are working:**
```bash
# Test notification
notify-send "Test" "This is a test"
```

## Advanced Usage

### Command-Line Transcription

You can use whisper.cpp directly for transcribing audio files:

```bash
whisper-cpp -m ~/.local/share/whisper/ggml-base.bin -f audio.wav
```

### Multiple Languages

Whisper supports auto-detection of 100+ languages:

```bash
# Transcribe non-English audio
whisper-cpp -m ~/.local/share/whisper/ggml-base.bin -f audio.wav -l auto
```

The dictation script uses auto-detection by default.

### Customizing the Script

The script is defined in `home.nix` (home.nix:183-264). You can:

- Change audio format/quality
- Add punctuation post-processing
- Filter specific words
- Change notification behavior

After editing, rebuild:
```bash
home-manager switch --flake .#benjamin
```

## Performance Tips

### Best Quality

- Use the `small` or `medium` model
- Use a good quality USB microphone
- Record in a quiet room
- Speak clearly and naturally

### Best Speed

- Use the `tiny` or `base` model
- Reduce audio quality (change rate to 8000 in script)
- Use a faster CPU or dedicated GPU (requires rebuilding whisper.cpp with CUDA)

## Privacy

**All processing is offline:**
- No internet connection required
- No data sent to external servers
- Audio files are stored temporarily in `/tmp/` and deleted after transcription
- Models run entirely on your local machine

## Resources

- **Whisper.cpp GitHub**: https://github.com/ggerganov/whisper.cpp
- **OpenAI Whisper**: https://github.com/openai/whisper
- **Model Downloads**: https://huggingface.co/ggerganov/whisper.cpp
- **wtype Documentation**: https://github.com/atx/wtype

## Quick Reference

| Command | Description |
|---------|-------------|
| `whisper-dictate` | Toggle dictation on/off |
| `whisper-download-models [size]` | Download AI model |
| `notify-send "Test" "Message"` | Test notifications |
| `pw-record test.wav` | Test microphone |
| `echo "text" \| wtype -` | Test text input |

**Niri Keybinding**: **Mod+d** (Super+d)

**Status Files**: `/tmp/whisper-dictation/`
- `recording.wav` - Current audio recording
- `transcription.txt` - Transcribed text
- `dictation.lock` - Lock file (indicates recording in progress)
