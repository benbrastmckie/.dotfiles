# Research Report: Text-to-Speech Solutions for NixOS
Date: 2025-10-01

## Metadata
- **Scope**: Comparison of text-to-speech (TTS) solutions for NixOS/Linux with focus on espeak-ng
- **Primary Directory**: `/home/benjamin/.dotfiles`
- **Files Analyzed**: home.nix, nixpkgs search results
- **Use Case**: Simple command-line TTS for notifications and task completion alerts

## Executive Summary

After comprehensive research into TTS solutions available in NixOS, **espeak-ng is the recommended choice** for simple command-line text-to-speech needs. While it produces robotic-sounding output, it offers unmatched simplicity, speed, zero maintenance, and immediate availability in nixpkgs. Alternative neural TTS solutions like Piper and Coqui TTS provide superior voice quality but add significant complexity and resource requirements that aren't justified for basic notification use cases.

## Background

The user is considering installing a text-to-speech package for simple command-line notifications, such as announcing task completion. The initial consideration was between `espeak` (legacy) and `espeak-ng` (Next Generation), with provided pros/cons highlighting:
- **Pros**: Widely available, simple CLI, fast/low latency, 40+ languages, lightweight
- **Cons**: Robotic voice quality, less natural sounding

## Current State Analysis

### NixOS Package Availability

**espeak-ng (Recommended)**:
- Package: `pkgs.espeak-ng`
- Version: 1.51.1
- Status: Actively maintained, first-class support in nixpkgs
- Size: ~20 MB with dependencies

**Legacy espeak**:
- Package: `pkgs.espeak`
- Version: 1.51.1 (same as espeak-ng)
- Status: Legacy package, superseded by espeak-ng

**Piper TTS**:
- Package: `pkgs.piper-tts`
- Version: 2023.11.14-2
- Status: Available in nixpkgs, neural TTS

**Coqui TTS**:
- Package: `pkgs.tts` (python package)
- Version: 0.25.1
- Status: Available but project was shut down in Dec 2024, forked by Idiap

## Key Findings

### 1. espeak vs espeak-ng

**Project History**:
- espeak-ng forked from espeak in December 2015 after 8 months of developer inactivity
- First release: v1.49.0 on September 10, 2016
- Goal: Clean up codebase, add features, improve language support

**Compatibility**:
- espeak-ng is a **drop-in replacement** for espeak
- Command-line interface remains compatible
- C API maintains ABI compatibility with libespeak.so
- In nixpkgs, both packages are version 1.51.1 (espeak points to espeak-ng)

**Technical Improvements**:
- Active maintenance and bug fixes
- Code cleanup and modernization
- Replaced audio APIs with PCAudioLib for better portability
- Removed espeakedit (voice data built via CLI)
- Language improvements and ongoing updates

**Verdict**: Use espeak-ng—it's the actively maintained version with all espeak functionality plus improvements.

### 2. Voice Quality Comparison

**espeak-ng**:
- Formant synthesis method
- Clear speech at high speeds
- Robotic, unnatural sound
- Described as "not as natural or smooth as larger synthesizers"
- Community consensus: Basic but functional

**Piper TTS**:
- Neural network-based synthesis (VITS models exported to ONNX)
- Significantly better quality than espeak-ng
- Natural-sounding voices
- Privacy-friendly (runs locally, no cloud)
- Optimized for devices like Raspberry Pi 4

**Coqui TTS**:
- State-of-the-art neural TTS
- "Most technically advanced open-source TTS framework" (2025)
- High-quality, natural voices
- Multiple pre-trained models available
- **Project shutdown**: December 2024 (after securing $3.3M funding)
- **Current status**: Forked and maintained by Idiap Research Institute

**pico2wave (SVOX)**:
- Mentioned in research as "better sounding than espeak or mbrola"
- "Very minimalistic TTS... sounds really good (natural)"
- Not found in standard nixpkgs search results

### 3. Performance & Resource Requirements

**espeak-ng**:
- Fast, low latency (near-instant response)
- Minimal CPU usage
- Tiny footprint (few megabytes with all languages)
- No model loading time
- Works on constrained hardware

**Piper TTS**:
- Fast neural TTS optimized for edge devices
- Requires model files (additional storage)
- Initial model loading time
- Higher CPU usage than espeak-ng but still efficient
- Designed for Raspberry Pi 4-class devices

**Coqui TTS**:
- Heavy resource requirements
- User reported: "too slow to be useable" (5+ minutes for 3.5K text)
- Requires model downloads and setup
- Benefits from GPU acceleration
- Performance varies by model selection

### 4. Installation & Maintenance Complexity

**espeak-ng**:
```nix
# System-wide (configuration.nix)
environment.systemPackages = [ pkgs.espeak-ng ];

# User-level (home.nix)
home.packages = [ pkgs.espeak-ng ];
```

**Usage**:
```bash
espeak-ng "Task completed successfully"
espeak-ng -v en-us "Hello from the command line"
espeak-ng -s 150 "Faster speech rate"  # Speed: 80-450 (default: 175)
```

**Piper TTS**:
```nix
# Installation
home.packages = [ pkgs.piper-tts ];

# Also available as wyoming-piper service
services.wyoming.piper.servers.<name>.enable = true;
```

**Usage** (requires model files):
```bash
# Download voice models separately
# More complex setup than espeak-ng
piper --model <path-to-model> --output_file output.wav < input.txt
```

**Coqui TTS**:
- Requires Python environment
- `pip install coqui-tts` (via nixpkgs: `pkgs.tts`)
- **Dependency**: Requires espeak-ng as backend for phoneme generation
- Complex setup with model management
- "No espeak backend found" error if espeak-ng not installed

### 5. Language Support

**espeak-ng**:
- 100+ languages and accents
- Verified voices include:
  - English variants: GB, US, Scotland, Caribbean, RP, West Midlands
  - Major languages: Spanish, French, German, Italian, Portuguese, Russian
  - Asian languages: Chinese (Mandarin), Japanese, Hindi, Arabic
  - And 90+ more
- All languages included in base package

**Piper TTS**:
- Wide language support
- English (US/UK), Spanish, French, German, and many others
- Requires separate model download per language/voice

**Coqui TTS**:
- Extensive language support
- Multiple voices per language
- Model-dependent (download required)

### 6. espeak-ng Features

**Command-Line Options**:
- `-v <voice>`: Select voice (e.g., en-us, en-gb, es, fr-fr)
- `-s <speed>`: Speech rate (80-450, default 175)
- `-p <pitch>`: Pitch adjustment (0-99, default 50)
- `-a <amplitude>`: Volume (0-200, default 100)
- `-g <gap>`: Word gap in 10ms units
- `-w <file>`: Write output to WAV file
- `--stdout`: Output to stdout (for piping)
- `-m`: SSML markup support
- `-b`: Input encoding (1=UTF8, 4=8bit)

**Advanced Features**:
- SSML (Speech Synthesis Markup Language) support
- HTML markup partial support
- Phoneme code translation
- MBROLA diphone voice frontend support
- Klatt formant synthesis option
- IPA phoneme output

**Voice Customization**:
- Pitch adjustment (-p flag)
- Speed control (-s flag)
- Amplitude/volume (-a flag)
- Multiple voice variants per language
- Different accent options within languages

## Analysis: Use Case Considerations

### When to Use espeak-ng

✅ **Best for**:
- Simple command-line notifications
- Task completion alerts
- Quick feedback messages
- Shell scripts and automation
- Systems with limited resources
- Zero-configuration requirement
- Maximum reliability and simplicity

✅ **Advantages**:
- Instant startup (no model loading)
- Zero configuration needed
- Minimal resource usage
- Reliable and battle-tested
- Simple integration into any script
- Works offline (no downloads needed)
- Comprehensive language support built-in

❌ **Limitations**:
- Robotic voice quality
- Not suitable for long-form content
- Limited naturalness and expression

### When to Use Piper TTS

✅ **Best for**:
- Voice assistants (Home Assistant integration)
- Longer text-to-speech needs
- Public-facing applications
- When voice quality matters
- Projects where natural speech is important

❌ **Trade-offs**:
- Additional complexity (model management)
- Initial setup required
- Larger storage footprint
- Model loading time
- Higher CPU usage

### When to Avoid Coqui TTS

❌ **Not recommended because**:
- Project officially shut down (Dec 2024)
- Uncertain long-term maintenance (fork status unclear)
- Heavy resource requirements
- Complex setup and configuration
- Performance issues reported
- Requires espeak-ng anyway (as dependency)
- Overkill for simple notification use cases

## Recommendations

### Primary Recommendation: espeak-ng

**For the stated use case** (command-line notifications like "Session completed. Ready for next task"), **espeak-ng is the clear choice**:

1. **Simplicity**: Single package, zero configuration
2. **Speed**: Instant response, perfect for notifications
3. **Reliability**: Mature, stable, actively maintained
4. **Resource-friendly**: Minimal CPU/memory footprint
5. **Complete**: All features and languages included
6. **NixOS Integration**: First-class support, no special handling needed

**Installation**:
```nix
# Add to home.nix
home.packages = with pkgs; [
  espeak-ng  # Text-to-speech for notifications
  # ... other packages
];
```

**Usage Examples**:
```bash
# Basic usage
espeak-ng "Task completed successfully"

# With voice selection
espeak-ng -v en-us "Using American English voice"

# Adjust speed (lower = slower, higher = faster)
espeak-ng -s 140 "Speaking a bit slower"

# Save to file
espeak-ng -w output.wav "Save this to a file"

# In scripts
function notify_complete() {
  echo "$1"
  espeak-ng "Task complete: $1"
}
```

### Alternative Consideration: Piper TTS

**Only consider Piper if**:
- Voice quality is critical
- Willing to manage model files
- Building a more complex TTS application
- Have storage space for models
- Can tolerate initial loading delay

**Not recommended for**: Simple command-line notifications

### Do Not Use: Coqui TTS

**Avoid Coqui TTS** for this use case:
- Project uncertainty (shutdown/fork)
- Massive overkill for notifications
- Performance issues
- Complex setup
- Requires espeak-ng anyway

## Integration with Existing Dotfiles

The user's current setup (from home.nix analysis):
- Uses home.packages for CLI tools
- Prefers simple, reliable tools (stylua, wezterm, gh, claude-code)
- Emphasizes maintainability and simplicity

**espeak-ng fits perfectly** with this philosophy:
- Simple addition to home.packages
- No configuration or services needed
- Works immediately after rebuild
- Zero maintenance burden
- Reliable and stable

**Recommended Addition**:
```nix
home.packages = with pkgs; [
  claude-code
  claude-squad
  gh
  lectic
  stylua
  wezterm
  espeak-ng    # Add here for TTS notifications
  # ... rest of packages
];
```

## Conclusion

**Final Recommendation**: Install `espeak-ng` from nixpkgs.

**Rationale**:
1. Perfectly suited for command-line notification use case
2. Zero-configuration, instant availability
3. Fast, lightweight, reliable
4. Actively maintained successor to espeak
5. Comprehensive language support built-in
6. Simple nixpkgs integration
7. No ongoing maintenance required

**Voice quality trade-off**: While espeak-ng sounds robotic, this is acceptable for brief notifications. The simplicity and reliability far outweigh the naturalness benefits of neural TTS for this specific use case.

**If voice quality becomes important later**: Can easily switch to Piper TTS, but start with espeak-ng for immediate, simple notification needs.

## References

### Documentation
- eSpeak NG GitHub: https://github.com/espeak-ng/espeak-ng
- eSpeak NG data location: `/nix/store/.../share/espeak-ng-data`
- Built-in help: `espeak-ng --help`
- Voice list: `espeak-ng --voices`

### NixOS Packages
- espeak-ng: `legacyPackages.x86_64-linux.espeak-ng` (1.51.1)
- piper-tts: `legacyPackages.x86_64-linux.piper-tts` (2023.11.14-2)
- Coqui TTS: `legacyPackages.x86_64-linux.tts` (0.25.1)

### Related Files
- Configuration: `/home/benjamin/.dotfiles/home.nix` (line 39+)
- Package docs: `/home/benjamin/.dotfiles/docs/packages.md`

### External Resources
- espeak-ng Wikipedia: https://en.wikipedia.org/wiki/ESpeak
- Piper TTS project: https://github.com/rhasspy/piper
- MyNixOS package search: https://mynixos.com/nixpkgs/package/piper-tts
