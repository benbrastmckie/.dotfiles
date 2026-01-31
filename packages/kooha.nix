kooha: gst_all_1:

kooha.overrideAttrs (oldAttrs: {
  buildInputs = oldAttrs.buildInputs ++ [
    gst_all_1.gst-plugins-bad   # AAC audio encoders for MP4
    gst_all_1.gst-libav         # Additional codec support
  ];
})
