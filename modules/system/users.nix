# User accounts and input device configuration.
{ username, ... }:
{
  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.${username} = {
    isNormalUser = true;
    description = "Benjamin";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "uinput"
    ];

    # The declarative equivalent of `loginctl enable-linger`: lets a systemd user timer
    # (systemd.user.timers.*, Sapience's sapience-sync.timer among them) fire with no login
    # session open. Scoped to the account above and reusable by every user timer in this tree,
    # not only Sapience's. Has no bearing on the WSL2 case, where `/etc/wsl.conf`'s
    # `[boot] systemd=true` is a host-level setting outside this flake's reach entirely -- see
    # modules/home/services/sapience.nix's sapienceLingerNotice for that remaining case.
    linger = true;
  };

  # Enable uinput for ydotool (dictation feature)
  hardware.uinput.enable = true;
}
