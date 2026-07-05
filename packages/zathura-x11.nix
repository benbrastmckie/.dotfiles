# Custom zathura wrapper: force GDK_BACKEND=x11 for consistent server-side
# window decorations (the Unite GTK extension does not decorate Wayland clients).
# Self-referential: wraps nixpkgs `zathura` under the same name, so it is wired in
# overlays/unstable-packages.nix via `prev.zathura` (NOT callPackage) to avoid recursion.
zathura: writeShellScriptBin:

writeShellScriptBin "zathura" ''
  #!/bin/sh
  export GDK_BACKEND=x11
  exec ${zathura}/bin/zathura "$@"
''
