# User accounts and input device configuration.
{ ... }:
{
  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.benjamin = {
    isNormalUser = true;
    description = "Benjamin";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" ];
  };

  # Enable uinput for ydotool (dictation feature)
  hardware.uinput.enable = true;
}
