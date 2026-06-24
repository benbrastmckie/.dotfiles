# Whisper dictation scripts for Wayland
{ pkgs, ... }:
{
  home.packages = [
    # Whisper dictation script for Wayland
    (pkgs.writeShellScriptBin "whisper-dictate" ''
      #!/usr/bin/env bash

      # Configuration
      MODEL_SIZE="''${WHISPER_MODEL_SIZE:-base}"  # tiny, base, small, medium, large
      TEMP_DIR="/tmp/whisper-dictation"
      AUDIO_FILE="$TEMP_DIR/recording.wav"
      TEXT_FILE="$TEMP_DIR/transcription.txt"
      LOCK_FILE="$TEMP_DIR/dictation.lock"

      mkdir -p "$TEMP_DIR"

      # Check if already running (toggle functionality)
      if [ -f "$LOCK_FILE" ]; then
        # Stop recording
        pkill -f "pw-record.*$AUDIO_FILE"
        rm -f "$LOCK_FILE"

        # Send notification
        ${pkgs.libnotify}/bin/notify-send "Dictation" "Processing..." -t 2000 -i audio-input-microphone

        # Wait a moment for file to finalize
        sleep 0.5

        # Transcribe with whisper.cpp
        if [ -f "$AUDIO_FILE" ]; then
          ${pkgs.whisper-cpp}/bin/whisper-cpp \
            -m ~/.local/share/whisper/ggml-''${MODEL_SIZE}.bin \
            -f "$AUDIO_FILE" \
            -otxt -of "$TEMP_DIR/transcription" \
            --no-timestamps 2>/dev/null

          # Extract text and type it
          if [ -f "$TEXT_FILE" ]; then
            # Remove leading/trailing whitespace
            TEXT=$(cat "$TEXT_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ -n "$TEXT" ]; then
              # Small delay to ensure window focus is stable
              sleep 0.2

              # Type the text using ydotool (works on both Wayland and X11)
              ${pkgs.ydotool}/bin/ydotool type "$TEXT"

              TYPE_EXIT=$?
              if [ $TYPE_EXIT -eq 0 ]; then
                ${pkgs.libnotify}/bin/notify-send "Dictation" "Typed: $TEXT" -t 3000 -i edit-paste
              else
                ${pkgs.libnotify}/bin/notify-send "Dictation Error" "Failed to type text. Make sure ydotoold service is running." -t 5000 -i dialog-error
              fi
            else
              ${pkgs.libnotify}/bin/notify-send "Dictation" "No speech detected" -t 3000 -i dialog-warning
            fi
          fi

          # Cleanup
          rm -f "$AUDIO_FILE" "$TEXT_FILE"
        fi
      else
        # Start recording
        touch "$LOCK_FILE"
        ${pkgs.libnotify}/bin/notify-send "Dictation" "Recording... (press again to stop)" -t 2000 -i audio-input-microphone

        # Record audio (using PipeWire)
        ${pkgs.pipewire}/bin/pw-record --format=s16 --rate=16000 --channels=1 "$AUDIO_FILE" &
      fi
    '')

    # Model downloader script
    (pkgs.writeShellScriptBin "whisper-download-models" ''
      #!/usr/bin/env bash

      MODEL_DIR="$HOME/.local/share/whisper"
      mkdir -p "$MODEL_DIR"

      echo "Downloading Whisper models to $MODEL_DIR"
      echo "Available sizes: tiny (~75MB), base (~150MB), small (~500MB), medium (~1.5GB)"
      echo ""

      # Default to base model
      MODEL="''${1:-base}"

      if [ ! -f "$MODEL_DIR/ggml-$MODEL.bin" ]; then
        echo "Downloading $MODEL model..."
        ${pkgs.wget}/bin/wget -P "$MODEL_DIR" \
          "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL.bin"
        echo "Downloaded $MODEL model successfully!"
      else
        echo "$MODEL model already exists at $MODEL_DIR/ggml-$MODEL.bin"
      fi
    '')
  ];
}
