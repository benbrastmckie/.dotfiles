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

## Neovim

The nvim configuration lives in `~/.config/nvim/` and is maintained as a
separate git repository — it is not part of this dotfiles repo.

`programs.neovim.enable = true` is kept in `home.nix` for two reasons:

1. **Provider wrapping** — Home Manager wraps the neovim binary to inject
   Nix-store paths for the Python3 and Ruby providers (`python3_host_prog`,
   `ruby_host_prog`), which would otherwise be unavailable on NixOS.
2. **`extraPackages`** — makes `jsregexp` available on neovim's runtime path,
   which LuaSnip requires.

### Why `sideloadInitLua = true` is required

By default (introduced in a home-manager update, May 2026), the neovim module
writes its generated provider config to `~/.config/nvim/init.lua` as a
Home Manager-managed symlink into the nix store. This overwrites the user's
actual `init.lua`.

`sideloadInitLua = true` tells the module to inject that provider config via
`--cmd` wrapper arguments on the neovim binary instead. The result is
identical — Python/Ruby providers work — but `~/.config/nvim/` is left
completely unmanaged by Home Manager.

**Without this option**, after any `nixos-rebuild switch`, `~/.config/nvim/init.lua`
becomes a read-only nix store symlink containing only the four provider lines,
and neovim shows the default startup screen instead of loading your config.

## Niri

- You can check the logs by running:
    ```bash
    journalctl -b -u niri
    ```

## Secrets Management

Secrets (Discord bot tokens, server passwords) are managed with sops-nix using age encryption. See [`docs/discord-bot.md`](docs/discord-bot.md) for full documentation.

Quick reference:
```bash
sops secrets/secrets.yaml              # Edit secrets interactively
sops --decrypt secrets/secrets.yaml    # View plaintext (read-only)
```

The age private key lives at `~/.config/sops/age/keys.txt` and is **never committed** to git. Backup this file securely — if lost, secrets cannot be decrypted and must be re-encrypted with a new key.

