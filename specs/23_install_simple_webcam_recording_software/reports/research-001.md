# Research Report: Task #23

**Task**: 23 - install_simple_webcam_recording_software
**Started**: 2026-02-09T12:00:00Z
**Completed**: 2026-02-09T12:15:00Z
**Effort**: Low
**Dependencies**: None
**Sources/Inputs**: Nix package search, web documentation, community reviews
**Artifacts**: - specs/23_install_simple_webcam_recording_software/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Cheese** is the simplest, most user-friendly webcam recording application available in nixpkgs
- Cheese is part of GNOME and integrates well with the existing GNOME configuration
- Installation requires adding a single package (`cheese`) to home.packages
- No additional configuration is required for basic webcam recording

## Context & Scope

The user requested the simplest free webcam recording software available in nixpkgs. Research focused on evaluating available options for ease of use, integration with the existing NixOS/GNOME setup, and minimal configuration requirements.

## Findings

### Available Webcam Recording Packages in nixpkgs

| Package | Version | Description | Complexity |
|---------|---------|-------------|------------|
| **cheese** | 44.1 | GNOME webcam app with photo/video capture | **Simplest** |
| **guvcview** | 2.2.2 | GTK+ UVC viewer with more controls | Moderate |
| **webcamoid** | 9.3.0 | Full-featured webcam suite with effects | Complex |
| **kamoso** | 25.12.2 | KDE webcam app | Moderate (KDE deps) |
| **obs-studio** | 32.0.4 | Professional streaming/recording | Overkill for simple use |

### Recommendation: Cheese

**Cheese** is the optimal choice for simple webcam recording because:

1. **Simplest interface**: One-click video recording - select Video mode, click Record button
2. **GNOME integration**: Already part of the GNOME desktop environment used in this configuration
3. **Zero configuration**: Works out of the box with V4L2-compatible webcams
4. **Automatic file saving**: Recordings saved to `~/Videos/Webcam/` as WebM files
5. **Lightweight**: Minimal resource usage compared to alternatives
6. **Fun effects**: Optional photo booth-style effects if desired

**How to use Cheese**:
1. Launch Cheese from the application menu
2. Select "Video" mode (camera icon switches to video camera)
3. Click the red circular Record button to start
4. Click again (now a square Stop button) to finish
5. Recording is automatically saved to `~/Videos/Webcam/`

### Alternative: Guvcview

If more control is needed later, **guvcview** offers:
- Finer control over video/audio settings
- Multiple output formats (MKV, AVI, WebM)
- Resolution and frame rate adjustments
- Better support for older/unusual webcams

However, guvcview uses a two-window interface and has more settings, making it slightly more complex.

### Rejected Options

- **OBS Studio**: Professional-grade, significant learning curve, overkill for "small videos"
- **Webcamoid**: Feature-rich but complex, some reported audio sync issues
- **Kamoso**: KDE application, would pull in KDE dependencies

### Installation Method

Add to `home.packages` in `home.nix`:

```nix
home.packages = with pkgs; [
  # ... existing packages ...
  cheese  # Simple webcam recording
];
```

Rebuild with:
```bash
home-manager switch --flake .#benjamin
```

### Webcam Access

NixOS typically handles webcam access automatically through the `video` group. The current configuration already uses GNOME with PipeWire, which provides proper webcam support. No additional configuration should be required.

If webcam access issues occur, verify the user is in the `video` group:
```bash
groups benjamin | grep video
```

## Decisions

1. **Selected Package**: `cheese` - prioritizing simplicity over features
2. **Installation Method**: Home Manager package in home.nix (user-level)
3. **No NixOS module**: Cheese works as a simple package, no system configuration needed

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Webcam not detected | Low | Cheese auto-detects V4L2 devices; verify with `ls /dev/video*` |
| Video format incompatibility | Low | WebM is widely supported; can convert with ffmpeg if needed |
| Need more features later | Low | Can add guvcview alongside cheese if advanced controls needed |

## Appendix

### Search Queries Used
- `nix search nixpkgs webcam`
- `nix search nixpkgs cheese`
- `nix search nixpkgs guvcview`
- Web: "cheese gnome webcam recording linux simple tutorial"
- Web: "guvcview webcam recording simple linux comparison cheese"

### References
- [Cheese GNOME Documentation](https://help.gnome.org/users/cheese/stable/)
- [Cheese Wikipedia](https://en.wikipedia.org/wiki/Cheese_(software))
- [Guvcview SourceForge](https://guvcview.sourceforge.net/)
- [Webcamoid GitHub](https://github.com/webcamoid/webcamoid)
- [LinuxLinks Webcam Tools](https://www.linuxlinks.com/webcam/)
- [Baeldung Linux Webcam Capture](https://www.baeldung.com/linux/webcam-video-capture)
