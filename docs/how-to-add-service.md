# How to Add a Service

This guide explains how to add system services and user-level systemd services.

## Decision Tree

```
Does the service need root privileges or affect all users?
  YES → System service in modules/system/*.nix (services.<name> or systemd.services.<name>)
  NO  ↓

Is it a background process for the benjamin user only?
  YES → User systemd unit in modules/home/services/*.nix (systemd.user.services.<name>)
  NO  ↓

Does an official NixOS module exist for it?
  YES → Use the module (services.<name>.enable = true) rather than a raw systemd unit
  NO  ↓

Should the service apply to some hosts but not others?
  YES → Optional/host-toggled module: options.<path>.enable + lib.mkIf, under
        modules/system/optional/ (see below)
  NO  ↓

Use a raw systemd.services or systemd.user.services entry (see below)
```

## System Services

System services run as root (or a dedicated service user) and are declared in the relevant
`modules/system/*.nix` file (e.g. `modules/system/services.nix`, `modules/system/audio.nix`,
`modules/system/desktop.nix`), imported unconditionally via `modules/system/default.nix`.

### Using an Existing NixOS Module

```nix
# modules/system/services.nix
services.openssh = {
  enable = true;
  settings.PermitRootLogin = "no";
};
```

### Raw systemd Service (system-level)

```nix
# modules/system/services.nix (or the most fitting category file)
systemd.services.my-daemon = {
  description = "My background daemon";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.my-package}/bin/my-daemon";
    Restart = "on-failure";
    User = "my-user";  # run as dedicated user, not root
  };
};
```

### Wiring sops-nix Secrets to a Service

```nix
# declare the secret (e.g. in the module owning the service)
sops.secrets."my-api-key" = {
  owner = config.users.users.benjamin.name;
};

# reference the secret in the service
systemd.services.my-daemon = {
  serviceConfig = {
    EnvironmentFile = config.sops.secrets."my-api-key".path;
  };
};
```

Secrets are stored encrypted in `secrets/secrets.yaml` and decrypted at activation time.
The key file must be present at `/etc/sops/age/keys.txt` on the target host.

## Optional/Host-Toggled System Services

Not every system service should apply to every host. `modules/system/optional/` holds services
that are opt-in per host, using the pattern: define `options.<path>.enable` (an
`lib.mkEnableOption`) and gate the entire `config` block under `lib.mkIf cfg.enable`. The module
is then imported explicitly only by the hosts that need it — never wired into
`modules/system/default.nix`.

`modules/system/optional/discord-bot.nix` is the worked example (this is also the same code the
"Discord-Bot Style Service" section below uses): it defines
`options.services.discordBot.enable`, gates both its `opencode-serve` and `discord-bot`
`systemd.services` entries under `lib.mkIf cfg.enable`, and is imported + enabled only by
`hosts/nandi/default.nix` (wired through `extraModules` in `flake.nix`) — `hamsa`, `garuda`, and
`iso` never import it.

## User Services (Home Manager)

User systemd services run as the `benjamin` user and are declared in `modules/home/services/*.nix`
(most cases) or a more specific category subtree (e.g. `modules/home/memory/services.nix` for
memory-monitoring units), imported via `modules/home/default.nix`.

### Raw User Service

```nix
# modules/home/services/my-app.nix
systemd.user.services.my-app = {
  Unit = {
    Description = "My user-level app";
    After = [ "graphical-session.target" ];
  };
  Service = {
    ExecStart = "${pkgs.my-app}/bin/my-app";
    Restart = "on-failure";
    # Use %h for $HOME in systemd user units (more idiomatic than /home/benjamin)
    RuntimeDirectory = "my-app";
  };
  Install = {
    WantedBy = [ "graphical-session.target" ];
  };
};
```

### Enabling systemd Integration

Home Manager must have `systemd.user.startServices = "sd-switch"` set (already configured, in
`modules/home/misc.nix`) for user services to be started automatically on activation.

## Current Services in This Config

### System Services (modules/system/)

| Service | File | Purpose |
|---------|------|---------|
| `services.pipewire` | `modules/system/audio.nix` | Audio/video routing |
| `services.gnome.*` | `modules/system/desktop.nix` | GNOME desktop services |
| `services.openssh` | `hosts/usb-installer/default.nix` | SSH daemon (usb-installer host only, not always-on) |
| `systemd.services.discord-bot` | `modules/system/optional/discord-bot.nix` | Discord AI bot (sops secrets); optional, nandi only |
| `systemd.services.opencode-serve` | `modules/system/optional/discord-bot.nix` | OpenCode API server; optional, nandi only |

### User Services (modules/home/)

| Service | File | Purpose |
|---------|------|---------|
| `systemd.user.services.ydotool` | `modules/home/services/ydotool.nix` | Universal input tool daemon (Wayland) |
| `systemd.user.services.screenshot-path-copy` | `modules/home/services/screenshot.nix` | Screenshot path copy service |
| `systemd.user.services.memory-monitor` | `modules/home/memory/services.nix` | System memory monitoring |

Note: `services.protonmail-bridge` (ProtonMail bridge for email) is actually a Home Manager
service, declared in `modules/home/email/protonmail.nix` — not a system service, despite its
NixOS-style option name.

## Adding a Discord-Bot Style Service (sops + systemd)

The `discord-bot` service uses sops secrets and the optional/host-toggled module pattern
described above. Pattern:

1. Add secret to `secrets/secrets.yaml` (encrypted with `sops`).
2. Declare the secret in the optional module (e.g. `modules/system/optional/discord-bot.nix`):
   ```nix
   sops.secrets."my-secret" = {
     owner = config.users.users.benjamin.name;
   };
   ```
3. Add the systemd service, gated under `lib.mkIf cfg.enable`:
   ```nix
   systemd.services.my-service = {
     description = "My service";
     wantedBy = [ "multi-user.target" ];
     serviceConfig = {
       ExecStart = "${pkgs.my-package}/bin/start";
       EnvironmentFile = config.sops.secrets."my-secret".path;
       User = "benjamin";
       WorkingDirectory = "/home/benjamin";
       Restart = "on-failure";
       RestartSec = "10s";
     };
   };
   ```

## Notes

- Avoid hardcoding `/home/benjamin` in systemd unit `WorkingDirectory` or path fields.
  Use `%h` (home directory) in systemd unit fields — it's idiomatic and avoids username coupling.
- For services that need the Wayland display, add `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`
  to the `Environment` list and ensure the unit is after `graphical-session.target`.
