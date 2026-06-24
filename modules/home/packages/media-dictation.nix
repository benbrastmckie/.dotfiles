# Media, dictation, screenshot, and notification tools
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    espeak-ng # Text-to-speech for notifications
    obs-studio

    # Dictation tools
    whisper-cpp # Fast offline speech-to-text (renamed from openai-whisper-cpp)
    ydotool # Universal input tool (works with GNOME/Wayland)
    libnotify # Desktop notifications

    # Screenshot and annotation tools (for Niri)
    satty # Screenshot annotation tool
    grim # Wayland screenshot utility
    slurp # Region selection tool for Wayland
    inotify-tools # Filesystem event monitoring (used by screenshot-path-copy service)

    # Clipboard history manager (for niri session)
    wl-clipboard
    cliphist
  ];
}
