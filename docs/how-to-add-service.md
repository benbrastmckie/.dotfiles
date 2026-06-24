# How to Add a Service

This guide explains how to add system services and user-level systemd services.

## Decision Tree

```
Does the service need root privileges or affect all users?
  YES → System service in configuration.nix (services.<name> or systemd.services.<name>)
  NO  ↓

Is it a background process for the benjamin user only?
  YES → User systemd unit in home.nix (systemd.user.services.<name>)
  NO  ↓

Does an official NixOS module exist for it?
  YES → Use the module (services.<name>.enable = true) rather than a raw systemd unit
  NO  ↓

Use a raw systemd.services or systemd.user.services entry (see below)
```

## System Services

System services run as root (or a dedicated service user) and are declared in `configuration.nix`.

### Using an Existing NixOS Module

```nix
# configuration.nix
services.openssh = {
  enable = true;
  settings.PermitRootLogin = "no";
};
```

### Raw systemd Service (system-level)

```nix
# configuration.nix
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
# configuration.nix — declare the secret
sops.secrets."my-api-key" = {
  owner = config.users.users.benjamin.name;
};

# configuration.nix — reference the secret in the service
systemd.services.my-daemon = {
  serviceConfig = {
    EnvironmentFile = config.sops.secrets."my-api-key".path;
  };
};
```

Secrets are stored encrypted in `secrets/secrets.yaml` and decrypted at activation time.
The key file must be present at `/etc/sops/age/keys.txt` on the target host.

## User Services (Home Manager)

User systemd services run as the `benjamin` user and are declared in `home.nix`.

### Raw User Service

```nix
# home.nix
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

Home Manager must have `systemd.user.startServices = "sd-switch"` set (already configured)
for user services to be started automatically on activation.

## Current Services in This Config

### System Services (configuration.nix)

| Service | Module | Purpose |
|---------|--------|---------|
| `services.openssh` | NixOS | SSH daemon |
| `services.protonmail-bridge` | NixOS | ProtonMail bridge for email |
| `services.pipewire` | NixOS | Audio/video routing |
| `services.gnome.*` | NixOS | GNOME desktop services |
| `systemd.services.discord-bot` | Raw | Discord AI bot (sops secrets) |
| `systemd.services.opencode-serve` | Raw | OpenCode API server |

### User Services (home.nix)

| Service | Purpose |
|---------|---------|
| `systemd.user.services.ydotool` | Universal input tool daemon (Wayland) |
| `systemd.user.services.screenshot-*` | Screenshot path copy service |
| `systemd.user.services.memory-monitor` | System memory monitoring |

## Adding a Discord-Bot Style Service (sops + systemd)

The `discord-bot` service uses sops secrets. Pattern:

1. Add secret to `secrets/secrets.yaml` (encrypted with `sops`).
2. Declare the secret in `configuration.nix`:
   ```nix
   sops.secrets."my-secret" = {
     owner = config.users.users.benjamin.name;
   };
   ```
3. Add the systemd service:
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
