# User accounts and input device configuration.
{ username, ... }:
{
  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.${username} = {
    isNormalUser = true;
    description = "Benjamin";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];
  };

  # Enable uinput for ydotool (dictation feature)
  hardware.uinput.enable = true;
}
