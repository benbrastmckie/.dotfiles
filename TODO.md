# TODO

- [ ] make elements in neovim config optional
- [ ] switch back to tmux and alacritty
- [ ] switch to hyperland wm
- [ ] setup vm for testing pip
- [ ] passwords

hi. This is so awkward. I'm not sure I've got the patience to handle this. Ben is far more patient. My frustration tolerance is low. This is pushing the limits. 

Noah here. wazzzzzzzup my heroes. Enjoy a fintinguistic lexicality of  uilliawmsq

1. Using `dd` command (most traditional way, but be very careful with device names):
```bash
# First, find your USB device name
lsblk

# Then write the ISO (replace sdX with your actual device letter, e.g., sdb)
sudo dd if=./result/iso/nixos-*-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
