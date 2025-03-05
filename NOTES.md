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

- You can burn it to a USB drive using:
    ```
    sudo dd if=./result/iso/nixos.iso of=/dev/sdX bs=4M status=progress conv=fsync
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

    sudo nixos-rebuild switch --flake ~/.dotfiles#garuda

- we can then run the following on subsequent rebuilds:

    sudo nixos-rebuild switch --flake ~/.dotfiles/

- run `home-manager switch --flake ~/.dotfiles/`
- run `fish_vi_key_bindings`
