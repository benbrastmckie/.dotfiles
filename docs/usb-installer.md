# NixOS USB Installer Guide

Create a bootable USB installer containing your complete NixOS configuration for easy system reproduction on any machine.

## Quick Start

```bash
# 1. Build the ISO (~30-60 minutes)
cd ~/.dotfiles
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# 2. Decompress the ISO
zstd -d result/iso/nixos-*.iso.zst -o /tmp/nixos-installer.iso

# 3. Write to USB drive (replace /dev/sdX with your USB device)
lsblk  # Identify your USB drive
sudo umount /dev/sdX*
sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress
sync

# 4. Clean up and eject
rm /tmp/nixos-installer.iso
sudo eject /dev/sdX
```

## Prerequisites

- **USB drive**: 8GB minimum (16GB recommended)
- **Build time**: 30-60 minutes
- **Disk space**: ~20GB free for building
- **Internet**: Required for package downloads

## What's Included

The USB installer contains your complete environment:

- **Desktop**: GNOME + Niri Wayland compositor with auto-login
- **Development**: Neovim, OpenCode, Python, Go, Node.js, GCC
- **Shell**: Fish, Tmux, Kitty, Ghostty terminals
- **Tools**: LazyGit, fd, ripgrep, fzf, zoxide, tree
- **AI Tools**: Claude Code, Gemini CLI, Goose CLI
- **Networking**: NetworkManager with WiFi support
- **User**: `benjamin` (password: `nixos`)

## Step-by-Step Guide

### Step 1: Build the ISO

```bash
cd ~/.dotfiles
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage
```

**What happens:**
- Builds ~169 derivations
- Creates compressed ISO (~8.5GB)
- Takes 30-60 minutes
- Result: `result/iso/nixos-*.iso.zst`

**Monitor progress:**
```bash
# Check if build is running
ps aux | grep "nix build.*usb-installer"

# Watch CPU usage
top
```

### Step 2: Prepare USB Drive

**Identify your USB device:**
```bash
lsblk
# Look for your USB drive (usually /dev/sdb or /dev/sdc)
# Verify the size matches your USB drive
```

**⚠️ WARNING**: The next steps will erase all data on the USB drive!

### Step 3: Write to USB

```bash
# Decompress the ISO
zstd -d result/iso/nixos-*.iso.zst -o /tmp/nixos-installer.iso

# Unmount USB partitions
sudo umount /dev/sdX*

# Write ISO to USB (shows progress, takes ~5-10 minutes)
sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress

# Ensure all data is written
sync
```

**Expected output:**
- Write speed: ~25-35 MB/s
- Total: 9,121,140,736 bytes (8.5 GiB)
- Time: ~5-10 minutes

**Verify:**
```bash
lsblk /dev/sdX
# Should show:
# - sdb1 (8.5G): iso9660, label "nixos-nandi-usb-24.11-x86_64"
# - sdb2 (3M): vfat, label "EFIBOOT"
```

### Step 4: Clean Up

```bash
# Remove temporary ISO (frees 8.5GB)
rm /tmp/nixos-installer.iso

# Eject USB drive
sudo eject /dev/sdX
```

You can now safely remove the USB drive!

## Using the USB Installer

### Boot from USB

1. Insert USB drive into target machine
2. Power on and enter boot menu (F12, F10, or ESC)
3. Select USB drive as boot device
4. System boots into GNOME (auto-logged in as `benjamin`)

### Install NixOS

**1. Partition target disk:**
```bash
# Identify disks
lsblk

# Example: Partition /dev/sda
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

**2. Generate hardware configuration:**
```bash
# Generate config for target machine
sudo nixos-generate-config --root /mnt

# Copy to dotfiles (replace "new-hostname" with your machine name)
sudo cp /mnt/etc/nixos/hardware-configuration.nix /home/benjamin/.dotfiles/hosts/new-hostname/
```

**3. Add host to flake.nix:**

Edit `~/.dotfiles/flake.nix` and add:

```nix
new-hostname = lib.nixosSystem {
  inherit system;
  modules = [ 
    ./configuration.nix
    ./hosts/new-hostname/hardware-configuration.nix
    { nixpkgs = nixpkgsConfig; }
    home-manager.nixosModules.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = import ./home.nix;
      home-manager.extraSpecialArgs = {
        inherit pkgs-unstable lectic nix-ai-tools;
      };
    }
  ];
  specialArgs = {
    inherit username name pkgs-unstable niri;
    lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
  };
};
```

**4. Install:**
```bash
cd /home/benjamin/.dotfiles
sudo nixos-install --flake .#new-hostname
sudo reboot
```

**5. Post-installation:**
```bash
# Login as benjamin
cd ~/.dotfiles
./update.sh
home-manager switch --flake .#benjamin
```

## Alternative Methods

### Using Ventoy (Multi-boot)

Ventoy can boot `.iso.zst` files directly without decompression:

```bash
# Install Ventoy on USB: https://www.ventoy.net/
# Copy compressed ISO to Ventoy partition
cp result/iso/nixos-*.iso.zst /path/to/ventoy/partition/
```

**Advantage**: No decompression needed, multiple ISOs on one drive

### Using BalenaEtcher (GUI)

1. Decompress ISO first: `zstd -d result/iso/nixos-*.iso.zst -o /tmp/nixos-installer.iso`
2. Download Etcher: https://etcher.balena.io/
3. Select `/tmp/nixos-installer.iso`
4. Select USB drive and flash

## Troubleshooting

### Build Issues

**"option does not exist" error:**
```bash
# Ensure flake.nix is up to date
cd ~/.dotfiles
git pull origin main
```

**"conflicting definition values" for hostname:**
```bash
# Check flake.nix uses lib.mkForce for hostname:
# networking.hostName = lib.mkForce "nandi-usb";
```

**Build appears stuck:**
```bash
# Check if still running
ps aux | grep "nix build.*usb-installer"

# If no CPU activity for 10+ minutes, restart:
pkill -f "nix build.*usb-installer"
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage
```

**Out of disk space:**
```bash
# Clean up (need ~20GB free)
nix-collect-garbage -d
sudo nix-collect-garbage -d
rm -f ~/.dotfiles/result
```

### USB Writing Issues

**Device is busy:**
```bash
# Force unmount
sudo umount -f /dev/sdX*

# Or lazy unmount
sudo umount -l /dev/sdX*
```

**dd hangs:**
```bash
# Try smaller block size
sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=1M conv=fsync status=progress

# Or use cp
sudo cp -v /tmp/nixos-installer.iso /dev/sdX
sync
```

**USB shows wrong size after writing:**

This is normal - the ISO is 8.5GB but your USB might be larger. To reclaim space later, reformat the drive.

### Boot Issues

**USB won't boot:**
- Enable UEFI boot in BIOS
- Disable Secure Boot
- Try different USB port
- Verify partition structure: `lsblk /dev/sdX`

**Network not working:**
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Check WiFi firmware
lspci -k | grep -A 3 Network
```

## Configuration Details

### Hardware Configuration

The USB installer uses a generic hardware configuration that works on most x86_64 systems:

**Supported hardware:**
- AMD Ryzen (including AI 300 series)
- Intel Core (12th gen+)
- NVMe, SATA, USB storage
- USB 3.0/3.1/4.0, Thunderbolt
- Modern WiFi and Ethernet

**Boot modules included:**
- `xhci_pci`, `ahci`, `nvme` - Storage controllers
- `usb_storage`, `usbhid` - USB devices
- `thunderbolt` - Thunderbolt support
- `kvm-amd`, `kvm-intel` - Virtualization

### Customization

**Add packages to installer:**

Edit `flake.nix` in the `usb-installer` configuration:

```nix
environment.systemPackages = with pkgs; [
  # Add your tools here
  htop
  btop
];
```

**Change auto-login user:**

```nix
services.displayManager.autoLogin = {
  enable = true;
  user = "your-username";
};
```

**Enable SSH with keys:**

```nix
services.openssh = {
  enable = true;
  settings.PasswordAuthentication = false;
};

users.users.benjamin.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA..."
];
```

## Maintenance

### Update USB Installer

```bash
cd ~/.dotfiles
./update.sh  # Update system first
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage
# Then write to USB as described above
```

### Version Control

```bash
# Tag installer versions
git tag -a "usb-installer-v1.0" -m "USB installer version 1.0"
git push origin "usb-installer-v1.0"
```

## See Also

- [Installation Guide](installation.md) - General NixOS installation
- [Configuration Guide](configuration.md) - System configuration details
- [Ryzen AI 300 Compatibility](ryzen-ai-300-compatibility.md) - Modern hardware support
- [Development Notes](development.md) - ISO building and development
