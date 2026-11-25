# Overlay supplying `voxcpm` from a nixpkgs instance built with config.rocmSupport = true.
#
# The caller (flake.nix) passes that package set. It exists as a separate instance for one
# reason: `torchWithRocm` on its own is `torch.override { rocmSupport = true; }`, so a python
# env holding both it and `torchaudio` ends up with two different torches -- torchaudio is
# built against the DEFAULT torch, not the override. Only moving the whole package set makes
# torch, torchaudio and torchcodec agree, and `config.rocmSupport` is how that is done.
#
# Scoping it to its own instance rather than adding the flag to flake.nix's shared
# nixpkgsConfig is the point of this file. That flag changes build defaults across nixpkgs: in
# the shared config it would mass-rebuild the system closure, and the plain `torch` in
# modules/home/packages/python.nix would quietly become a 5 GiB ROCm build in every user
# profile, for consumers that have no use for it.
#
# This follows overlays/himalaya-pin.nix, which takes a whole frozen package set for the same
# shape of reason -- that one to pin a version, this one to move a build flag.
#
# The instance deliberately carries NO overlays of its own. It needs stock python3Packages and
# nothing from overlays/python-packages.nix, and leaving the overlay list empty keeps this out
# of the overlay graph it is itself a member of.
#
# See docs/voxcpm.md.
pkgs-rocm: _final: _prev: {
  voxcpm = pkgs-rocm.callPackage ../packages/voxcpm.nix { };
}
