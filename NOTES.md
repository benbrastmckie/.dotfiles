# NOTES

## API

- LLM API key is kept in private.fish

## Build Iso

- Navigate to your dotfiles directory:
    ```
    cd ~/.dotfiles
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

- The ISO includes:
  - GNOME desktop environment
  - Your system configuration from configuration.nix
  - Your home-manager configuration
  - Niri window manager
  - All your specified packages

## Rebuild

- first build should mention system name as in:

    sudo nixos-rebuild switch --flake ~/.dotfiles#nandi

- we can then run the following on subsequent rebuilds:

    sudo nixos-rebuild switch --flake ~/.dotfiles/

- run `home-manager switch --flake ~/.dotfiles/`
- run `fish_vi_key_bindings`
