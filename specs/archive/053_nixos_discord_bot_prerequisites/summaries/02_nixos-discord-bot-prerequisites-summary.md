# Implementation Summary: NixOS Discord Bot Prerequisites

**Task**: 53 - nixos_discord_bot_prerequisites
**Completed**: 2026-05-08T06:20:00Z
**Session**: sess_1778212736_18723d

## Changes Made

All five phases implemented successfully. sops-nix integrated for age-based secrets management, dedicated Python 3.12 environment created for the Discord bot, and both systemd services (opencode-serve and discord-bot) defined with proper credential wiring and dependency chains.

## Files Modified/Created

### Modified
- `flake.nix` - Added sops-nix flake input, passed through outputs destructor, imported sops-nix NixOS module on all 4 hosts (hamsa, nandi, iso, usb-installer)
- `flake.lock` - Auto-updated with sops-nix entry
- `configuration.nix` - Added `discordBotPython` let-binding (python312 with nextcord, aiohttp, anyio), sops config block (defaultSopsFile, age key path, secrets for discord_bot_token and opencode_server_password), added sops+age to environment.systemPackages, added opencode-serve and discord-bot systemd services

### Created
- `.sops.yaml` - Age key configuration with creation rules for secrets/*.yaml
- `secrets/secrets.yaml` - Encrypted secrets file (discord_bot_token, opencode_server_password, whitelisted_user_ids, link_api_token)
- `~/.config/sops/age/keys.txt` - Age private key (never committed, public key: age173cp99...)

## Verification Results

| Check | Result |
|-------|--------|
| `nix flake check` | PASS - all 4 nixosConfigurations + homeConfigurations |
| `nix flake show` | PASS - all 4 hosts visible |
| `nixos-rebuild build --flake .#hamsa` | PASS - /nix/store/0dav5s...-nixos-system-hamsa |
| `nixos-rebuild build --flake .#nandi` | PASS - /nix/store/3zvra1...-nixos-system-nandi |
| `sops --decrypt secrets/secrets.yaml` | PASS - plaintext readable |
| `.sops.yaml` valid YAML | PASS |
| sops secrets paths | PASS - /run/secrets/discord_bot_token, /run/secrets/opencode_server_password |
| opencode-serve unit: ExecStart | Correct: opencode serve --hostname 127.0.0.1 |
| opencode-serve unit: LoadCredential | Correct: opencode_server_password:/run/secrets/opencode_server_password |
| discord-bot unit: ExecStart | Correct: discordBotPython/bin/python -m opencode_discord_bot.src.bot |
| discord-bot unit: PYTHONPATH | Correct: /home/benjamin/.dotfiles/opencode-discord-bot |
| discord-bot unit: Requires | Correct: Requires=opencode-serve.service |
| discord-bot unit: After | Correct: After=network-online.target opencode-serve.service |

## Manual Steps Required Before Live Switch

1. **Replace placeholder secrets**: Edit `secrets/secrets.yaml` with real values:
   ```bash
   sops secrets/secrets.yaml
   ```
   - Replace `PLACEHOLDER_DISCORD_BOT_TOKEN` with actual Discord bot token
   - Replace `PLACEHOLDER_OPENSCODE_SERVER_PASSWORD` with a generated password
   - Set `whitelisted_user_ids` and `link_api_token` as needed

2. **Back up age private key**: `~/.config/sops/age/keys.txt` should be backed up securely

3. **Create bot project**: The bot source at `~/.dotfiles/opencode-discord-bot/` must exist (external task 547) before the discord-bot service can start

4. **Apply**: `sudo nixos-rebuild switch --flake .#hamsa` (on hamsa) or `.#nandi` (on nandi)

## Notes

- The discord-bot service will fail to start until the bot Python source code exists at `~/.dotfiles/opencode-discord-bot/src/bot.py` (external task 547)
- The opencode-serve service should start successfully after secrets are in place
- Existing services (disable-speaker-amp, init-power-profile, etc.) are unaffected
