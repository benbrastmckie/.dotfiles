# Application Configurations

## Discord Bot (OpenCode Relay)

Nextcord Discord bot that bridges Discord to a headless OpenCode agent server. Systemd services (`opencode-serve` + `discord-bot`) handle the bot lifecycle with secrets injected from sops-nix.

**Complete documentation**: [`docs/discord-bot.md`](discord-bot.md)

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
- Custom wrapper forces X11 (`GDK_BACKEND=x11`) for consistency

### Sioyek (Qt6-based)

- Runs as native Wayland app with Qt CSD disabled (`QT_WAYLAND_DISABLE_WINDOWDECORATION=1`)
- GNOME does not add server-side decorations to Wayland apps, so no titlebar is shown
- Previous approach (`QT_QPA_PLATFORM=xcb`) broke in GNOME 49, which ignores `_MOTIF_WM_HINTS` for XWayland windows
- Original package excluded to prevent conflicts with the wrapper

## Chat (Zulip)

CLI and TUI tools for Zulip team chat.

**Packages**: `zulip` (Python SDK + `zulip-send` CLI), `zulip-term` (interactive TUI)
**Config**: `~/.zuliprc` (seeded via activation script; fill in API key after first rebuild)

**Setup**:
1. Run `home-manager switch` to seed `~/.zuliprc`
2. Get your API key from Zulip web UI: **Personal Settings > Account & Privacy > API key**
3. Edit `~/.zuliprc` with your real `key` and `site` values

**Usage**:
```bash
# Send to a stream
zulip-send --stream "general" --subject "topic" --message "Hello"

# Direct message
zulip-send --user someone@example.com --message "Hey"

# Interactive TUI
zulip-term
```

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

Fast, local, fully offline neural text-to-speech with the `en_US-lessac-medium` voice.
Installed via a prebuilt Linux x86_64 release binary (`packages/piper-bin.nix`, fetchurl +
autoPatchelfHook) so the bundled onnxruntime is never compiled from source (task 70).

**Package**: `piper` (custom `packages/piper-bin.nix`, rhasspy/piper release 2023.11.14-2)
**Model**: `piper-voice-en-us-lessac-medium` (symlinked to `~/.local/share/piper/`)

**Setup**: `nixos-rebuild switch` installs `piper`; `home-manager switch` links the voice model.

**Usage**:
```bash
echo "Hello, world!" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | aplay
```

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