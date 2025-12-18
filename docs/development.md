# Development and Setup Notes

This document contains development notes, workflows, and initial setup procedures.

## API Configuration

LLM API keys are kept in private shell configuration files (e.g., `private.fish`) and are not tracked in git for security.

## USB Installer

For creating bootable USB installers with your complete configuration, see the dedicated guide:

**[USB Installer Guide](usb-installer.md)** - Complete instructions for building and using USB installers

Quick reference:
```bash
# Build USB installer ISO
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# Decompress and write to USB
zstd -d result/iso/nixos-*.iso.zst -o /tmp/nixos-installer.iso
sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

## Development Workflow

### Clean up build results

1. **Remove build symlinks:**
   ```bash
   rm -f ./result
   ```

2. **Clean up old generations:**
   ```bash
   # Full garbage collection
   nix-store --gc
   
   # Or targeted cleanup
   nix-collect-garbage -d
   ```

### ISO Contents

The custom ISO includes:
- GNOME desktop environment
- System configuration from `configuration.nix`
- Home-manager configuration
- Niri window manager
- All specified packages from the configuration

## Initial System Setup

### First Build Process

1. **Copy hardware configuration:**
   ```bash
   cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/hosts/HOST_NAME/hardware-configuration.nix
   ```

2. **First system build (specify hostname):**
   ```bash
   sudo nixos-rebuild switch --flake ~/.dotfiles#nandi
   ```

3. **Subsequent rebuilds can use:**
   ```bash
   sudo nixos-rebuild switch --flake ~/.dotfiles/
   ```

4. **Apply home-manager configuration:**
   ```bash
   home-manager switch --flake ~/.dotfiles/
   ```

5. **Configure fish shell keybindings:**
   ```bash
   fish_vi_key_bindings
   ```

## Window Manager (Niri)

### Checking Niri Logs

To debug Niri window manager issues:

```bash
journalctl -b -u niri
```

This shows boot logs specific to the Niri service.

## OAuth2 Example URL

For reference, here's an example of what a Google OAuth2 authorization URL looks like (from NOTES.md):

```
https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com&state=JG-dxurfv1CAtSGA9Q7afg&code_challenge=vDgC6ctcdQi0ucIfdY3kehoLEA5yzvZn98IATf2TXcY&code_challenge_method=S256&redirect_uri=http%3A%2F%2Flocalhost%3A49152&scope=https%3A%2F%2Fmail.google.com%2F+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcontacts+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcarddav
```

This can be helpful for understanding the OAuth2 flow for email configuration.

## Host-Specific Configuration

For adding new hosts:

1. Generate hardware configuration on the new machine
2. Copy to `hosts/[hostname]/hardware-configuration.nix`
3. Update `flake.nix` to include the new host
4. Reference host-specific settings in `configuration.nix`

## Related Documentation

- [Installation Guide](installation.md) - Detailed setup instructions
- [Testing](testing.md) - Configuration testing procedures
- [Applications](applications.md) - Application-specific configurations