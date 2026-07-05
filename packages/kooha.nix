# Custom kooha override: adds gst-plugins-bad (AAC encoders for MP4) and gst-libav
# (extra codec support) to nixpkgs' kooha via overrideAttrs. Positional-arg style
# (kooha, gst_all_1), wired via prev.kooha in overlays/unstable-packages.nix — same
# self-referential-override pattern as sioyek-wayland.nix/zathura-x11.nix.
kooha: gst_all_1:

kooha.overrideAttrs (oldAttrs: {
  buildInputs = oldAttrs.buildInputs ++ [
    gst_all_1.gst-plugins-bad # AAC audio encoders for MP4
    gst_all_1.gst-libav # Additional codec support
  ];
})
