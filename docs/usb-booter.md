# NixOS USB Installer Guide

## Overview

This guide provides step-by-step instructions for creating a bootable NixOS USB installer that contains your complete dotfiles configuration, enabling reproduction of your current system on any machine. The installer includes both GNOME and Niri Wayland compositor sessions, all your custom packages, and your complete development environment.

## Prerequisites

### Hardware Requirements
- USB drive: 8GB minimum (16GB recommended for full package cache)
- Target system: x86_64 architecture (most modern PCs/laptops)
- Internet connection for initial setup and package downloads

### Software Requirements
- Existing NixOS system (for building the ISO)
- Git access to your dotfiles repository
- Sudo/root access for system operations

## System Architecture Analysis

Your current configuration includes:

### Core Components
- **NixOS 24.11** with flakes enabled
- **Dual session setup**: GNOME + Niri Wayland compositor
- **Custom overlays**: claude-squad, unstable packages, Python packages
- **Home Manager**: User environment management
- **Custom packages**: claude-code, markitdown, python-cvc5, pymupdf4llm

### Key Features
- **Audio EMI fix** for Realtek ALC256 codec
- **OAuth2 email setup** with Himalaya
- **AI development tools**: Claude Code, Gemini CLI, Goose CLI
- **Development environment**: Python, Go, Node.js, Neovim
- **Dictation system**: Whisper with ydotool integration
- **Custom shell**: Fish with oh-my-fish

## Step 1: Prepare the Environment

### 1.1 Update Current System
```bash
cd ~/.dotfiles
./update.sh
```

### 1.2 Verify Configuration
```bash
# Check flake configuration
nix flake show

# Test build without applying
nixos-rebuild dry-build --flake .#nandi
```

### 1.3 Create New Host Configuration
Since this will be a portable installer, create a generic host configuration:

```bash
# Create new host directory
mkdir -p ~/.dotfiles/hosts/usb-installer

# Generate generic hardware configuration
sudo nixos-generate-config --no-filesystems --dir /tmp/usb-config

# Copy the base hardware configuration
cp /tmp/usb-config/hardware-configuration.nix ~/.dotfiles/hosts/usb-installer/
```

## Step 2: Create USB Installer Configuration

### 2.1 Update flake.nix
Add the USB installer configuration to your `flake.nix`:

```nix
# Add to nixosConfigurations section
usb-installer = lib.nixosSystem {
  inherit system;
  modules = [ 
    ./configuration.nix
    ./hosts/usb-installer/hardware-configuration.nix
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    
    # Apply our unstable packages overlay globally
    { nixpkgs = nixpkgsConfig; }
    
    home-manager.nixosModules.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = import ./home.nix;
      home-manager.extraSpecialArgs = {
        inherit pkgs-unstable;
        inherit lectic;
        inherit nix-ai-tools;
      };
    }
    
    ({ pkgs, lib, ... }: {
      # USB-specific configurations
      isoImage.edition = lib.mkForce "nandi-usb";
      isoImage.compressImage = true;
      isoImage.squashfsCompression = "zstd -Xcompression-level 19";
      
      # Generic hostname for USB
      networking.hostName = "nandi-usb";
      
      # Enable copy-on-write for the ISO
      isoImage.makeEfiBootable = true;
      isoImage.makeUsbBootable = true;
      
      # Configure networking for installer with NetworkManager
      networking = {
        networkmanager = {
          enable = true;
          wifi.backend = "iwd";
        };
        wireless.enable = false;
        # Enable DHCP for automatic network configuration
        useDHCP = lib.mkDefault true;
      };
      
      # Include essential system utilities for installation
      environment.systemPackages = with pkgs; [
        vim
        git
        wget
        curl
        gnumake
        parted
        dosfstools
        e2fsprogs
        # Networking tools
        iw
        wirelesstools
        networkmanager
        # Hardware tools
        lshw
        pciutils
        usbutils
        # Filesystem tools
        ntfs3g
        exfat
        # Your custom tools
        kitty
        tmux
        fish
      ];
      
      # Enable SSH for remote installation (optional)
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = true;
        };
      };
      
      # Auto-login to GNOME for easier setup
      services.displayManager.autoLogin = {
        enable = true;
        user = "benjamin";
      };
      
      # Ensure proper permissions for auto-login
      users.users.benjamin = {
        isNormalUser = true;
        description = "Benjamin";
        extraGroups = [ "networkmanager" "wheel" "audio" "video" "input" ];
        initialPassword = "nixos";  # Change after first boot
      };
      
      # Include dotfiles in the ISO
      system.copyToRoot = {
        "/home/benjamin/.dotfiles" = {
          source = ./.;
          recursive = true;
        };
      };
    })
  ];
  specialArgs = {
    inherit username;
    inherit name;
    inherit pkgs-unstable;
    inherit niri;
    lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
  };
};
```

### 2.2 Create Generic Hardware Configuration
Edit `~/.dotfiles/hosts/usb-installer/hardware-configuration.nix`:

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Generic boot configuration for USB installer
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "ohci_pci" "ehci_pci" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # No filesystems defined - will be set during installation
  fileSystems = { };

  swapDevices = [ ];

  # Generic networking configuration
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
```

## Step 3: Build the USB Installer

### 3.1 Build the ISO
```bash
cd ~/.dotfiles

# Build the USB installer ISO
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage
```

This process will:
- Download and build all required packages
- Create a bootable ISO with your complete configuration
- Include your dotfiles in `/home/benjamin/.dotfiles/`
- Compress the image for optimal size

### 3.2 Alternative: Build Directly to USB
If you want to write directly to a USB drive (faster, saves disk space):

```bash
# WARNING: This will erase the target drive!
# Replace /dev/sdX with your USB device
sudo umount /dev/sdX*
sudo nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

## Step 4: Create Bootable USB Drive

### 4.1 Using dd (Linux)
```bash
# Find your USB device
lsblk

# Write ISO to USB (replace /dev/sdX with your device)
sudo umount /dev/sdX*
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

### 4.2 Using BalenaEtcher (Cross-platform)
1. Download BalenaEtcher from https://etcher.balena.io/
2. Select the ISO file from `result/iso/nixos-*.iso`
3. Select your USB drive
4. Flash the image

### 4.3 Using Ventoy (Multi-boot option)
1. Install Ventoy on your USB drive
2. Copy the ISO file to the Ventoy partition
3. Boot from USB and select the NixOS ISO

## Step 5: Boot from USB Installer

### 5.1 Boot Configuration
1. Insert USB drive into target machine
2. Power on and enter boot menu (usually F12, F10, or ESC)
3. Select USB drive as boot device
4. Choose "NixOS" from the boot menu

### 5.2 Initial Setup
The system will boot into:
- **Auto-logged GNOME session** as user `benjamin`
- **Password**: `nixos` (change immediately)
- **Terminal**: Access your dotfiles at `/home/benjamin/.dotfiles/`

## Step 6: Install NixOS on Target Machine

### 6.1 Prepare Target Disk
```bash
# Open terminal in the live environment
# Identify disks
lsblk

# Example: Partition /dev/sda (adjust as needed)
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sda -- mkpart primary 512MiB 100%
sudo parted /dev/sda -- set 1 esp on

# Format partitions
sudo mkfs.fat -F 32 /dev/sda1
sudo mkfs.ext4 /dev/sda2

# Mount filesystems
sudo mount /dev/sda2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sda1 /mnt/boot
```

### 6.2 Generate Hardware Configuration
```bash
# Generate hardware-specific configuration
sudo nixos-generate-config --root /mnt

# Copy to your dotfiles structure
sudo cp /mnt/etc/nixos/hardware-configuration.nix /home/benjamin/.dotfiles/hosts/[new-hostname]/
```

### 6.3 Update Configuration for New Host
1. Edit `~/.dotfiles/flake.nix` to add the new host
2. Update `networking.hostName` in the new host configuration
3. Adjust any hardware-specific settings

### 6.4 Install System
```bash
cd /home/benjamin/.dotfiles

# Install NixOS with your configuration
sudo nixos-install --flake .#[new-hostname]

# Set root password
sudo passwd

# Reboot into new system
sudo reboot
```

## Step 7: Post-Installation Setup

### 7.1 First Boot Configuration
```bash
# Login as benjamin
cd ~/.dotfiles

# Update system with latest changes
./update.sh

# Set up Home Manager
home-manager switch --flake .#benjamin

# Configure Git (if not already set)
git config --global user.name "benbrastmckie"
git config --global user.email "benbrastmckie@gmail.com"
```

### 7.2 Configure Hardware-Specific Settings
- **Audio**: Test audio and apply EMI fix if needed
- **Graphics**: Configure GPU drivers if necessary
- **Network**: Set up WiFi and network profiles
- **Input**: Configure keyboard and input devices

### 7.3 Restore Personal Data
```bash
# If you have a backup of personal data
rsync -av /path/to/backup/ /home/benjamin/

# Or restore from git repository
cd ~/.dotfiles
git pull origin main
```

## Step 8: Synchronize Changes

### 8.1 Commit New Host Configuration
```bash
cd ~/.dotfiles

# Add new host configuration
git add hosts/[new-hostname]/
git add flake.nix

# Commit changes
git commit -m "feat: add [new-hostname] host configuration"

# Push to repository
git push origin main
```

### 8.2 Update Documentation
```bash
# Update hosts/README.md with new host information
echo "[new-hostname]: [Description of machine]" >> hosts/README.md
git add hosts/README.md
git commit -m "docs: update hosts README with [new-hostname]"
git push origin main
```

## Troubleshooting

### Common Issues

#### USB Won't Boot
- **Check BIOS settings**: Enable UEFI boot, disable Secure Boot
- **Recreate USB**: Try different USB drive or writing method
- **Verify ISO**: Check if the ISO was built successfully

#### Network Issues
- **WiFi not working**: Check if firmware is missing
- **Ethernet issues**: Verify cable and driver support
- **NetworkManager**: Restart with `sudo systemctl restart NetworkManager`

#### Package Build Failures
- **Disk space**: Ensure at least 20GB free for building
- **Memory**: Minimum 4GB RAM recommended
- **Internet**: Stable connection required for downloads

#### Hardware Detection
- **Graphics**: May need proprietary drivers
- **Audio**: Check codec-specific configurations
- **Input**: Verify device compatibility

### Recovery Commands

#### Emergency Shell
```bash
# If system fails to boot, boot from USB and chroot
sudo mount /dev/sda2 /mnt
sudo mount /dev/sda1 /mnt/boot
sudo chroot /mnt /nix/var/nix/profiles/system/bin/bash
```

#### Configuration Rollback
```bash
# List previous generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

## Advanced Configuration

### Customizing the Installer

#### Add Additional Packages
Edit the USB installer configuration in `flake.nix`:
```nix
environment.systemPackages = with pkgs; [
  # Add your preferred tools
  htop
  btop
  neofetch
  # ... more packages
];
```

#### Enable SSH Access
```nix
services.openssh = {
  enable = true;
  settings = {
    PermitRootLogin = "yes";
    PasswordAuthentication = true;
  };
};
```

#### Pre-configure Users
```nix
users.users.benjamin = {
  isNormalUser = true;
  description = "Benjamin";
  extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
  initialPassword = "nixos";
  openssh.authorizedKeys.keys = [
    # Add your SSH public keys
  ];
};
```

### Automation Scripts

#### Automated Installation Script
Create `scripts/install-automated.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:-nandi-new}"
DISK="${2:-/dev/sda}"

# Partition disk
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 512MiB
parted "$DISK" -- mkpart primary 512MiB 100%
parted "$DISK" -- set 1 esp on

# Format filesystems
mkfs.fat -F 32 "${DISK}1"
mkfs.ext4 "${DISK}2"

# Mount filesystems
mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# Generate hardware config
nixos-generate-config --root /mnt

# Copy to dotfiles
cp /mnt/etc/nixos/hardware-configuration.nix "/home/benjamin/.dotfiles/hosts/$HOSTNAME/"

# Install system
cd /home/benjamin/.dotfiles
nixos-install --flake ".#$HOSTNAME"
```

## Maintenance

### Updating the USB Installer
```bash
cd ~/.dotfiles

# Rebuild with latest changes
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# Re-flash USB drive
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

### Version Control
```bash
# Tag installer versions
git tag -a "usb-installer-v1.0" -m "USB installer version 1.0"
git push origin "usb-installer-v1.0"

# Create release notes
echo "# USB Installer v1.0\n\n- Initial release\n- Includes full development environment" > docs/usb-installer-v1.0.md
git add docs/usb-installer-v1.0.md
git commit -m "docs: add USB installer v1.0 release notes"
```

## Security Considerations

### Password Management
- Change default passwords immediately after installation
- Use unique passwords for each machine
- Consider using SSH keys instead of passwords

### Sensitive Data
- Remove sensitive files from the USB installer
- Use environment variables for secrets
- Consider encrypted partitions for sensitive data

### Network Security
- Disable SSH after installation if not needed
- Configure firewall appropriately
- Keep system updated regularly

## Conclusion

This USB installer provides a complete, reproducible NixOS environment with your entire development setup. By maintaining your dotfiles in version control and using this installer, you can quickly replicate your environment on any machine while keeping all systems synchronized.

The key advantages of this approach:
- **Reproducibility**: Same configuration everywhere
- **Version control**: Track changes and roll back if needed
- **Portability**: Complete environment on a USB drive
- **Consistency**: All machines stay in sync
- **Flexibility**: Easy to customize for different hardware

Regular updates to the dotfiles repository will automatically be available to all machines through the standard `./update.sh` script, ensuring your entire fleet stays current with minimal effort.