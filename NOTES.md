# NOTES

## API

- LLM API key is kept in private.fish

## Build ISO

- Navigate to your dotfiles directory:
    ```
    cd ~/.dotfiles
    ```

- Build your regular system with:
    ```
    sudo nixos-rebuild switch --flake .#$(hostname)
    ```
  Or use the update script:
    ```
    ./update.sh
    ```

- Build the ISO with:
    ```
    nix build .#nixosConfigurations.iso.config.system.build.isoImage
    ```

- The ISO will be available at:
    ```
    ./result/iso/nixos.iso
    ```

- Find the name of the `zst` file and decompress it with:

    ```
    zstd -d ./result/iso/nixos-24.11.20250123.035f8c0-x86_64-linux.iso.zst -o ~/Downloads/nixos.iso
    ```     

- Check available drives before burning:
    ```
    lsblk
    ```
  This will list all block devices and their mount points. Make sure to identify the correct USB drive.

- You can burn it to a USB drive using:
    ```
    sudo dd if=/home/benjamin/Downloads/nixos.iso of=/dev/sdX bs=4M status=progress conv=fsync
    ```
  (Replace sdX with your USB drive device, be very careful to use the correct device!)

- Delete the ISO symlink with:
    ```
    rm -f ./result
    ```  

- Clean up the build result with:

    ```
    nix-store --gc
    ```

  Or for a more targeted cleanup:

    ```
    nix-collect-garbage -d
    ```  

- The ISO includes:
  - GNOME desktop environment
  - Your system configuration from configuration.nix
  - Your home-manager configuration
  - Niri window manager
  - All your specified packages

## First Build

- move `hardware-configuration.nix` into the hosts directory replacing `HOST_NAME`:
    ```
    cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/hosts/HOST_NAME/hardware-configuration.nix
    ```  
 **⚠️ First build must explicitly specify the hostname** (not `$(hostname)`):

    sudo nixos-rebuild switch --flake ~/.dotfiles#your-hostname

  After this, `$(hostname)` will return the correct value for subsequent builds.

- subsequent rebuilds can use the update script:

    ./update.sh

- run `home-manager switch --flake ~/.dotfiles/`
- run `fish_vi_key_bindings`

## Niri

- You can check the logs by running:
    ```bash
    journalctl -b -u niri
    ```

