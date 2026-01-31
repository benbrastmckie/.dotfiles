# Application Configurations

## Email (Himalaya)

Modern CLI email client with Gmail OAuth2 authentication and mbsync synchronization. 

**Complete documentation**: [`docs/himalaya.md`](himalaya.md)

## MCP-Hub Integration

Model Context Protocol Hub for enhanced AI tool integration with Neovim.

### Setup

MCP-Hub is configured as a standard Neovim plugin using lazy.nvim:
- Port: 37373
- Configuration: `~/.config/mcphub/servers.json`
- Integration with Avante for AI functionality

Use `~/.dotfiles/packages/test-mcphub.sh` to verify installation and troubleshoot issues.

## PDF Viewers

### Zathura (GTK-based)

- Uses server-side decorations
- Compatible with Unite GNOME extension for title bar removal
- Custom wrapper forces X11 for consistency

### Sioyek (Qt6-based)

- Uses client-side decorations on Wayland
- Custom wrapper forces X11 (`QT_QPA_PLATFORM=xcb`)
- Enables server-side decorations for Unite compatibility
- Original package excluded to prevent conflicts

## Terminal Configuration

Multiple terminal emulators configured:

- **Alacritty**: GPU-accelerated terminal
- **Kitty**: Feature-rich terminal with tabs and splits
- **Zellij**: Terminal multiplexer (configured via config.kdl)

## Shell Configuration

Fish shell with custom configuration:

- Aliases and functions in `config/config.fish`
- Integration with various CLI tools
- Custom prompt and completions

## Text-to-Speech & Speech-to-Text

System-wide TTS and STT tools for Claude Code notifications and Neovim integration.

### TTS: Piper

Fast, local neural text-to-speech with natural voice quality.

**Package**: `piper-tts` (from nixpkgs)
**Dependencies**: `espeak-ng`
**Models**: Declaratively managed via `packages/piper-voices.nix`

**Setup**: Voice models are automatically installed to `~/.local/share/piper/` after `home-manager switch` - no manual download needed!

**Usage**:
```bash
echo "Hello, world!" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file output.wav
aplay output.wav
```

**Available voices**: https://huggingface.co/rhasspy/piper-voices/tree/main

### STT: Vosk

Offline speech recognition with lightweight models (~50MB).

**Package**: `vosk` (custom Python package in `packages/python-vosk.nix`)
**Location**: Available in system Python via `python3.withPackages`
**Models**: Declaratively managed via `packages/vosk-models.nix`

**Setup**: Language models are automatically installed to `~/.local/share/vosk/vosk-model-small-en-us-0.15/` after `home-manager switch` - no manual download needed!

**Usage**:
```python
import vosk
import wave

model = vosk.Model("~/.local/share/vosk/vosk-model-small-en-us-0.15")
wf = wave.open("audio.wav", "rb")
rec = vosk.KaldiRecognizer(model, wf.getframerate())

while True:
    data = wf.readframes(4000)
    if len(data) == 0:
        break
    rec.AcceptWaveform(data)

print(rec.Result())
```

**Available models**: https://alphacephei.com/vosk/models

### Audio Recording

PulseAudio client tools for audio capture.

**Package**: `pulseaudio` (provides `parecord`)

**Usage**:
```bash
# Record 10 seconds at 16kHz (optimal for STT)
timeout 10s parecord --channels=1 --rate=16000 --file-format=wav recording.wav
```

### Integration Use Cases

- **Claude Code**: TTS notifications via Stop hooks
- **Neovim**: STT for voice-to-text input using Lua async jobs
- **WezTerm**: Tab-aware notifications

**Research & Implementation**: See `/home/benjamin/Projects/ProofChecker/specs/761_tts_stt_integration_for_claude_code_and_neovim/`

**Package documentation**: See [`packages/README.md`](../packages/README.md#text-to-speech-and-speech-to-text-setup)