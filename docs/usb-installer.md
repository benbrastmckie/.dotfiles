# NixOS USB Installer Guide

Create a bootable USB installer containing your complete NixOS configuration for easy system reproduction on any machine.

**Note**: This installer uses `nixos-unstable` for the latest hardware drivers and kernel, providing better support for modern hardware like Framework laptops and AMD Ryzen AI processors.

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

## Why NixOS Unstable?

This installer uses `nixos-unstable` instead of a stable release for several important reasons:

- **Latest Hardware Support**: Newest kernel and drivers for modern hardware (Framework laptops, AMD Ryzen AI, etc.)
- **Current Firmware**: Up-to-date firmware packages for WiFi, Bluetooth, and other devices
- **Better Compatibility**: Improved support for cutting-edge hardware that may not work on stable releases
- **Rolling Updates**: Always get the latest packages and security fixes
- **Stability**: Despite the name, nixos-unstable is quite stable and well-tested

**Trade-off**: Slightly more frequent updates and occasional breaking changes (rare).

## What's Included

The USB installer contains your complete environment:

- **Base**: NixOS unstable (rolling release with latest drivers)
- **Installer**: Calamares graphical installer (easy point-and-click installation)
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
- Builds ~400+ derivations (includes Calamares installer)
- Creates compressed ISO (~8.7GB)
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
# - sdb1 (8.7G): iso9660, label "nixos-nandi-usb-26.05-x86_64"
# - sdb2 (3M): vfat, label "EFIBOOT"
```

### Step 4: Clean Up

```bash
# Remove temporary ISO (frees 8.7GB)
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

### Partition Your Disk

Before installing NixOS, you need to partition your disk. Choose one of the methods below:

#### Method 1: Command Line (parted)

Open a terminal and partition your disk manually:

```bash
# Step 1: Identify your disk (usually /dev/nvme0n1 for NVMe or /dev/sda for SATA)
lsblk

# Step 2: Create GPT partition table (erases disk!)
# Replace /dev/nvme0n1 with your actual disk
# Note: You may see a warning about updating /etc/fstab - you can safely ignore this
sudo parted /dev/nvme0n1 -- mklabel gpt

# Step 3: Create EFI boot partition (512MB)
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/nvme0n1 -- set 1 esp on

# Step 4: Create NixOS partition (exactly half of remaining space)
# Using 50% ensures equal split with the next partition
sudo parted /dev/nvme0n1 -- mkpart primary ext4 512MiB 50%

# Step 5: Create storage/other OS partition (remaining half)
sudo parted /dev/nvme0n1 -- mkpart primary ext4 50% 100%

# Step 6: Format the partitions
sudo mkfs.fat -F 32 /dev/nvme0n1p1  # EFI partition
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2  # NixOS partition
sudo mkfs.ext4 -L storage /dev/nvme0n1p3  # Storage/other OS partition

# Step 7: Verify partitions were created correctly
lsblk /dev/nvme0n1
```

**Expected result:**
```
nvme0n1           1TB  disk
├─nvme0n1p1     512M  part  (EFI boot)
├─nvme0n1p2     500G  part  (NixOS)
└─nvme0n1p3     500G  part  (Storage/Other OS)
```

#### Method 2: GNOME Disks (GUI - Recommended for Beginners)

GNOME Disks provides a user-friendly graphical interface for partitioning.

**Step 1: Launch GNOME Disks**

- Click the **Activities** button (top-left corner) or press `Super` key
- Type "Disks" in the search bar
- Click on **Disks** application icon

**Step 2: Select Your Target Disk**

⚠️ **CRITICAL**: Make sure you select the correct disk! Partitioning will erase all data.

1. In the left sidebar, you'll see all connected disks
2. Identify your target disk by:
   - **Size**: Match the capacity (e.g., "1.0 TB", "512 GB")
   - **Model**: Look for your drive's brand/model name
   - **Device path**: Usually `/dev/nvme0n1` (NVMe) or `/dev/sda` (SATA)
3. **DO NOT select**:
   - Your USB installer drive (usually labeled "nixos-nandi-usb")
   - Any external drives you want to keep

**Step 3: Create Partition Table (Erases All Data!)**

⚠️ **WARNING**: This step will permanently erase everything on the selected disk!

1. Click the **☰** (menu) button in the top-right corner
2. Select **Format Disk...**
3. In the dialog:
   - **Erase**: Select "Overwrite existing data with zeroes (Slow)" for security, or "Don't overwrite existing data (Quick)" for speed
   - **Partitioning**: Select **GPT** (required for UEFI boot)
4. Click **Format...**
5. Type "DELETE" to confirm (yes, in all caps)
6. Click **Format** again

You should now see "Free Space" with the full disk capacity.

**Step 4: Create EFI Boot Partition (512 MB)**

1. Click the **+** button below the disk diagram (or click "Free Space" and press **+**)
2. In the "Create Partition" dialog:
   - **Partition Size**: Enter **512** MB (or use the slider)
   - **Type**: Select **FAT** (or "FAT32")
   - **Name**: Enter **EFI** (optional but helpful)
3. Click **Create**
4. **Set boot flag**:
   - Click on the newly created partition (should show "512 MB FAT")
   - Click the **⚙** (gear) icon below
   - Select **Edit Partition...**
   - Check the box for **ESP** (EFI System Partition)
   - Click **Change**

**Step 5: Create NixOS Partition**

1. Click on the remaining **Free Space**
2. Click the **+** button
3. In the "Create Partition" dialog:
   - **Partition Size**: 
     - For **full disk NixOS**: Leave at maximum (uses all remaining space)
     - For **dual-boot**: Enter half the remaining space (or use 50% if available)
   - **Type**: Select **Ext4**
   - **Name**: Enter **nixos**
4. Click **Create**

**Step 6: Create Storage/Other OS Partition (Optional)**

If you're setting up dual-boot or want a separate storage partition:

1. Click on the remaining **Free Space** (if any)
2. Click the **+** button
3. In the "Create Partition" dialog:
   - **Partition Size**: Leave at maximum (uses all remaining space)
   - **Type**: 
     - Select **Ext4** for Linux storage
     - Select **Unformatted** if installing another OS later
   - **Name**: Enter **storage** or **other-os**
4. Click **Create**

**Step 7: Verify Your Partitions**

Your disk should now show:

```
Partition 1: 512 MB    FAT      EFI       [Boot flag: ESP]
Partition 2: ~500 GB   Ext4     nixos
Partition 3: ~500 GB   Ext4     storage   (optional)
```

**Visual Check:**
- The disk diagram shows colored blocks for each partition
- No "Free Space" remains (unless intentional)
- The EFI partition is small (512 MB) and shows FAT filesystem
- The NixOS partition is large and shows Ext4 filesystem

**Common Mistakes to Avoid:**

- ❌ Forgetting to set the ESP flag on the EFI partition → Boot failure
- ❌ Making the EFI partition too small (< 512 MB) → Boot issues
- ❌ Using MBR instead of GPT → Won't boot on UEFI systems
- ❌ Selecting the wrong disk → Data loss on wrong drive
- ❌ Creating only one partition → Need separate EFI + root partitions

**Troubleshooting:**

**"Format Disk" is greyed out:**
- The disk might be mounted. Click the **■** (stop) button to unmount all partitions first.

**Can't set ESP flag:**
- Make sure you created a GPT partition table (not MBR)
- The partition must be FAT32 formatted

**Partition creation fails:**
- Try unmounting all partitions on the disk first
- Ensure no other programs are accessing the disk
- Reboot and try again

**Want to start over:**
- Go back to Step 3 and format the disk again
- All partitions will be erased and you can start fresh

### Install NixOS - Graphical Method (Recommended)

The USB installer includes **Calamares**, a user-friendly graphical installer that **automatically launches** when you boot from the USB.

#### Running the Installer

**1. Calamares auto-launches:**
- The installer appears automatically after login
- If you closed it, look for the **"Install NixOS"** icon on the desktop
- Or open the application menu and search for "Install NixOS"

**2. Follow the installation wizard:**
- **Welcome**: Select your language
- **Location**: Choose timezone and region
- **Keyboard**: Select keyboard layout
- **Partitions**: 
  - Select "Manual partitioning"
  - Choose your NixOS partition (e.g., `/dev/nvme0n1p2`)
  - Set mount point to `/`
  - Choose your EFI partition (e.g., `/dev/nvme0n1p1`)
  - Set mount point to `/boot`
  - Leave the storage partition unselected
- **Users**: Create your user account and set password
- **Summary**: Review your choices
- **Install**: Click "Install" and wait (10-20 minutes)

**3. Reboot:**
- Remove the USB drive when prompted
- Boot into your new NixOS installation

**Note**: The graphical installer provides a basic NixOS installation. To use your dotfiles configuration, see the "Advanced Installation" section below.

#### Dual-Boot Tips

If you're setting up dual-boot:
- Install NixOS first (on the first partition)
- The second partition can be used for:
  - **Another Linux distro**: Install it after NixOS, it will detect NixOS and add it to GRUB
  - **Storage**: Mount it in NixOS at `/mnt/storage` or `/home/storage`
  - **Windows**: Install Windows last (it may overwrite the bootloader, requiring GRUB repair)

### Install NixOS - Manual Method (Advanced)

**Prerequisites:** 
- Your disk must already be partitioned (see "Partition Your Disk" section above)
- WiFi connection (to clone your dotfiles repository)

**1. Mount filesystems:**
```bash
# Mount the NixOS partition (adjust device names as needed)
sudo mount /dev/nvme0n1p2 /mnt

# Create boot directory and mount EFI partition
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot

# Verify mounts
lsblk
```

**2. Generate hardware configuration:**
```bash
# Generate config for target machine
sudo nixos-generate-config --root /mnt

# This creates /mnt/etc/nixos/hardware-configuration.nix
```

**3. Clone your dotfiles repository:**

**Prerequisites:** Make sure you're connected to WiFi. The USB installer includes NetworkManager - click the WiFi icon in the top-right to connect.

```bash
# Clone your dotfiles (replace with your actual repository URL)
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

**4. Add new host configuration:**

```bash
# Replace "framework" with your chosen hostname for this machine
NEW_HOSTNAME="framework"

# Create directory and copy hardware config
mkdir -p hosts/$NEW_HOSTNAME/
sudo cp /mnt/etc/nixos/hardware-configuration.nix hosts/$NEW_HOSTNAME/

# Example: if you chose "thinkpad" as hostname, this creates:
# hosts/thinkpad/hardware-configuration.nix
```

**5. Edit flake.nix to register the new host:**

```bash
nvim flake.nix
```

In the editor:
1. Search for `nixosConfigurations = {` (press `/` then type the search term)
2. Find an existing host entry (like `nandi`)
3. Copy that entire entry and paste it below
4. Change the hostname in two places:
   - The entry name: `framework = lib.nixosSystem {`
   - The hardware config path: `./hosts/framework/hardware-configuration.nix`

Example of what to add:

```nix
framework = lib.nixosSystem {
  inherit system;
  modules = [ 
    ./configuration.nix
    ./hosts/framework/hardware-configuration.nix  # ← Update this path
    
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
  ];
  specialArgs = {
    inherit username;
    inherit name;
    inherit pkgs-unstable;
    lectic = lectic.packages.${system}.lectic or lectic.packages.${system}.default or lectic;
  };
};
```

Save and exit (`:wq` in vim).

**6. Install with your dotfiles configuration:**
```bash
cd ~/.dotfiles

# Install NixOS with your full configuration (replace "framework" with your hostname)
sudo nixos-install --flake .#framework
```

**7. Commit and push changes (optional but recommended):**

Before rebooting, commit your changes so they're saved:

```bash
# Add the new host configuration
git add hosts/framework/
git add flake.nix

# Commit the changes
git commit -m "Add framework host configuration"

# Push to your repository
git push
```

**8. Reboot:**
```bash
sudo reboot
```

**9. Post-installation:**

After booting into your new system:

```bash
# Clone your dotfiles (they should now include the new host config)
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Your system is already installed with the configuration, but you can update if needed
./update.sh
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

### Installation Issues

**Calamares shows "No partitions available":**

This means your disk needs to be partitioned first. See the "Partition Your Disk" section above for detailed instructions using either the command line (parted) or GUI (GNOME Disks) methods.

**Calamares won't launch:**

If the installer doesn't appear automatically:
```bash
# Launch manually
sudo calamares

# Or check if it's already running
ps aux | grep calamares
```

**Installation fails with "Cannot mount /boot":**

Make sure you selected the EFI partition (usually the small 512MB FAT32 partition) and set its mount point to `/boot`.

**Want to preserve existing data:**

⚠️ **Warning**: Installing NixOS will erase the selected partition. To preserve data:
1. Back up your data first
2. Use the "Partition Your Disk" section to create separate partitions
3. Only select the NixOS partition during installation
4. Leave your data partition unselected

### Build Issues (nixos-unstable)

**Package not found errors:**

Since we're using `nixos-unstable`, packages occasionally get renamed or removed. If you encounter build errors:

```bash
# Update to latest unstable
cd ~/.dotfiles
nix flake update

# Try building again
./build-usb-installer.sh
```

**Common package renames in unstable:**
- `openai-whisper-cpp` → `whisper-cpp`
- `nerdfonts` → `nerd-fonts.<font-name>`
- `z3` → `z3-solver` (Python package)
- `libsForQt5.okular` → `kdePackages.okular`
- `noto-fonts-emoji` → `noto-fonts-color-emoji`

**Build takes too long:**

The first build downloads and compiles many packages (~30-60 minutes). Subsequent builds are much faster due to caching.

```bash
# Monitor build progress
ps aux | grep "nix build"

# Check what's being built
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage --dry-run
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
./build-usb-installer.sh  # Build new ISO
# Then write to USB as described above
```

**Note**: Building the installer downloads the latest packages from `nixos-unstable`, so you'll always get the newest drivers and kernel.

### Version Control

```bash
# Tag installer versions
git tag -a "usb-installer-v2.1" -m "USB installer with Calamares graphical installer"
git push origin "usb-installer-v2.1"
```

## See Also

- [Installation Guide](installation.md) - General NixOS installation
- [Configuration Guide](configuration.md) - System configuration details
- [Ryzen AI 300 Compatibility](ryzen-ai-300-compatibility.md) - Modern hardware support
- [Development Notes](development.md) - ISO building and development
